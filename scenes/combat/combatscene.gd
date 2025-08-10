# This script inherits from Node3D (makes it a 3D scene)
# This is the main scene that manages tactical combat
extends Node3D

# NODE REFERENCE: Get reference to the camera for controlling the view
# @onready waits until scene is fully loaded before finding the camera
# The path $CameraRig/Camera3D means: find child "CameraRig", then its child "Camera3D"
@onready var camera = $CameraRig/Camera3D

# VARIABLE: Will hold reference to our Grid object once it's created
# We declare it as type Grid for better code completion and error checking
var grid: Grid
enum GameState { SELECTING, MOVING, ATTACKING, ENEMY_TURN }
var game_state: GameState = GameState.SELECTING
var selected_action: String = ""  # "move" or "attack"


# UNIT MANAGEMENT: Arrays to keep track of all units in the game
var player_units: Array[Unit] = []    # Units controlled by the player
var enemy_units: Array[Unit] = []     # Units controlled by AI/opponent
var all_units: Array[Unit] = []       # All units combined for easy access

# SELECTION SYSTEM: Track what the player has selected
var selected_unit: Unit = null        # Currently selected unit (null = nothing selected)
var current_team: String = "player"   # Whose turn it is

# UNIT SCENES: Pre-load the unit scene files so we can create instances
var warrior_scene = preload("res://scenes/units/warrior.tscn")
var archer_scene = preload("res://scenes/units/archer.tscn") 
var mage_scene = preload("res://scenes/units/mage.tscn")
var hound_scene = preload("res://scenes/units/hound.tscn")

# _ready() runs once when this CombatScene is added to the scene tree
func _ready():
	
	# Enable input processing for this node
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# CREATE AND ADD GRID: Dynamically load and create the grid
	# preload() loads the Grid scene file at compile time (more efficient)
	var grid_scene = preload("res://scenes/maps/grid.tscn")
	
	# instantiate() creates a new instance of the Grid scene
	# Like making a copy of the Grid blueprint
	grid = grid_scene.instantiate()
	
	# add_child() adds the grid instance as a child of this CombatScene
	# Now the grid becomes part of this scene and will be visible
	add_child(grid)
	
	# CONNECT GRID SIGNALS: Listen for events from the grid
	# When grid sends tile_selected signal, call our _on_tile_selected function
	# This creates communication between Grid and CombatScene
	grid.tile_selected.connect(_on_tile_selected)
	
	# SETUP CAMERA: Position camera to have a good view of the grid
	setup_camera()

	# SPAWN UNITS: Add units to the battlefield after grid is ready
	spawn_initial_units()

	print("Combat scene: OK")
	grid.test_debug()

# UNIT SPAWNING: Create and place initial units on the battlefield
func spawn_initial_units():
	print("=== SPAWNING INITIAL UNITS ===")
	
	# SPAWN PLAYER UNITS (left side of battlefield)
	# We'll try multiple positions for each unit until we find a walkable spot
	spawn_unit_with_fallback("warrior", "player", [Vector3i(1, 0, 2), Vector3i(0, 0, 2), Vector3i(2, 0, 2), Vector3i(1, 0, 1)])
	spawn_unit_with_fallback("archer", "player", [Vector3i(0, 0, 4), Vector3i(1, 0, 4), Vector3i(0, 0, 3), Vector3i(0, 0, 5)])
	spawn_unit_with_fallback("mage", "player", [Vector3i(2, 0, 6), Vector3i(1, 0, 6), Vector3i(0, 0, 6), Vector3i(2, 0, 5)])
	spawn_unit_with_fallback("warrior", "player", [Vector3i(1, 0, 8), Vector3i(0, 0, 8), Vector3i(2, 0, 8), Vector3i(1, 0, 7)])
	
	# SPAWN ENEMY UNITS (right side of battlefield)  
	spawn_unit_with_fallback("hound", "enemy", [Vector3i(8, 0, 2), Vector3i(9, 0, 2), Vector3i(7, 0, 2), Vector3i(8, 0, 1)])
	spawn_unit_with_fallback("hound", "enemy", [Vector3i(9, 0, 4), Vector3i(8, 0, 4), Vector3i(9, 0, 3), Vector3i(9, 0, 5)])
	spawn_unit_with_fallback("hound", "enemy", [Vector3i(7, 0, 6), Vector3i(8, 0, 6), Vector3i(9, 0, 6), Vector3i(7, 0, 5)])
	spawn_unit_with_fallback("hound", "enemy", [Vector3i(8, 0, 8), Vector3i(9, 0, 8), Vector3i(7, 0, 8), Vector3i(8, 0, 7)])
	
	
	# BACKUP: If we still don't have enough units, spawn them anywhere safe
	ensure_minimum_units()
	
	# CONNECT UNIT SIGNALS: Listen for when units are selected
	connect_unit_signals()
	print("Units spawned - Player: %d, Enemy: %d" % [player_units.size(), enemy_units.size()])



# SIGNAL CONNECTIONS: Set up communication with all units
func connect_unit_signals():
	print("=== CONNECTING UNIT SIGNALS ===")
	
	for unit in all_units:
	
		unit.unit_selected.connect(_on_unit_selected)
		unit.unit_died.connect(_on_unit_died) 

# SMART UNIT SPAWNING: Try multiple positions until we find a walkable tile
func spawn_unit_with_fallback(unit_type: String, team: String, preferred_positions: Array[Vector3i]):
	print("Trying to spawn ", unit_type, " (", team, ") with ", preferred_positions.size(), " fallback positions")
	
	# TRY EACH POSITION: Go through the list until we find one that works
	for grid_pos in preferred_positions:
		var unit = spawn_unit(unit_type, team, grid_pos)
		if unit:  # If spawn was successful
			print("✓ Successfully spawned at position ", grid_pos)
			return unit
	
	# IF ALL POSITIONS FAILED: Find any walkable tile in the team's area
	print("⚠ All preferred positions failed, searching for any walkable tile...")
	var backup_position = find_safe_spawn_area(team)
	if backup_position != Vector3i(-1, 0, -1):
		return spawn_unit(unit_type, team, backup_position)
	else:
		print("✗ CRITICAL ERROR: Could not find any walkable tile for ", unit_type, " (", team, ")")
		return null

# AREA SEARCH: Find any walkable tile in the team's side of the battlefield
func find_safe_spawn_area(team: String) -> Vector3i:
	# DEFINE TEAM AREAS: Different search zones for each team
	var search_columns: Array[int] = []
	
	if team == "player":
		search_columns = [0, 1, 2, 3]  # Left side of battlefield
	else:
		search_columns = [6, 7, 8, 9]  # Right side of battlefield
	
	# SEARCH SYSTEMATICALLY: Check every tile in the team's area
	for x in search_columns:
		for z in range(grid.grid_height):
			var tile = grid.get_tile(Vector3i(x, 0, z))
			if tile and tile.is_walkable and not tile.occupied_unit:
				print("✓ Found safe spawn area at ", Vector3i(x, 0, z))
				return Vector3i(x, 0, z)
	
	print("✗ No safe spawn area found for team ", team)
	return Vector3i(-1, 0, -1)  # Return invalid position if nothing found

# BACKUP SYSTEM: Make sure each team has at least some units
func ensure_minimum_units():
	var min_units_per_team = 2  # Each team should have at least 2 units
	
	# CHECK PLAYER UNITS: Add more if needed
	if player_units.size() < min_units_per_team:
		print("⚠ Player has only ", player_units.size(), " units, adding more...")
		var needed = min_units_per_team - player_units.size()
		for i in range(needed):
			spawn_emergency_unit("warrior", "player")
	
	# CHECK ENEMY UNITS: Add more if needed  
	if enemy_units.size() < min_units_per_team:
		print("⚠ Enemy has only ", enemy_units.size(), " units, adding more...")
		var needed = min_units_per_team - enemy_units.size()
		for i in range(needed):
			spawn_emergency_unit("warrior", "enemy")

# EMERGENCY SPAWNING: Place a unit anywhere on the battlefield as last resort
func spawn_emergency_unit(unit_type: String, team: String):
	print("🚨 Emergency spawning ", unit_type, " for ", team)
	
	# SEARCH ENTIRE BATTLEFIELD: Look for any walkable tile
	for x in range(grid.grid_width):
		for z in range(grid.grid_height):
			var tile = grid.get_tile(Vector3i(x, 0, z))
			if tile and tile.is_walkable and not tile.occupied_unit:
				print("🚨 Emergency spawn at ", Vector3i(x, 0, z))
				return spawn_unit(unit_type, team, Vector3i(x, 0, z))
	
	print("🚨 CRITICAL: Cannot spawn emergency unit - no walkable tiles!")
	return null

# UNIT CREATION: Create a specific unit type at a specific position
func spawn_unit(unit_type: String, team: String, grid_pos: Vector3i):
	var target_tile = grid.get_tile(grid_pos)
	if not target_tile or not target_tile.is_walkable: 
		print("❌ Cannot spawn at %s - tile not walkable" % str(grid_pos))
		return null
	
	var unit_instance: Unit = null
	
	# Handle unit type selection
	match unit_type:
		"warrior":
			unit_instance = warrior_scene.instantiate()
		"archer":
			unit_instance = archer_scene.instantiate()
		"mage":
			unit_instance = mage_scene.instantiate()
		"hound":
			unit_instance = hound_scene.instantiate()
		_:
			print("❌ Unknown unit type: %s" % unit_type)
			return null
	
	# Set team (though hounds should always be enemy)
	unit_instance.team = team
	
	# Add visual distinction for enemy units (darkening)
	if team == "enemy" and unit_type != "hound":  # Hounds handle their own color
		unit_instance.unit_color = unit_instance.unit_color.darkened(0.4)
	
	add_child(unit_instance)
	unit_instance.place_on_tile(target_tile)
	
	# Add to appropriate arrays
	all_units.append(unit_instance)
	if team == "player":
		player_units.append(unit_instance)
	else:
		enemy_units.append(unit_instance)
	
	print("✓ Spawned %s (%s) at %s" % [unit_type, team, str(grid_pos)])
	return unit_instance

# UNIT SELECTION HANDLER: Called when any unit is clicked
func _on_unit_selected(unit: Unit):
	if unit.team != current_team: 
		return
	if unit.has_acted:
		print("Unit has already acted this turn!")
		return
		
	if selected_unit and selected_unit != unit:
		selected_unit.deselect()
		grid.clear_all_highlights()
	
	selected_unit = unit
	unit.select()
	game_state = GameState.SELECTING
	show_unit_options()

func show_unit_options():
	"""Show what the selected unit can do"""
	if not selected_unit:
		return
		
	print("\n=== %s SELECTED ===" % selected_unit.unit_name)
	print("Health: %d/%d" % [selected_unit.current_health, selected_unit.max_health])
	print("Actions available:")
	print("1. MOVE (click tile)")
	print("2. ATTACK (click enemy)")
	print("3. END TURN (press SPACE)")
	
	# Highlight movement options
	grid.highlight_walkable_tiles(selected_unit.grid_position, selected_unit.movement_points_remaining)
	
	# Highlight attack targets
	highlight_attack_targets()

func highlight_attack_targets():
	"""Highlight enemies within attack range"""
	if not selected_unit:
		return
		
	var targets = get_units_in_attack_range(selected_unit)
	for target in targets:
		# Add red glow to attackable enemies
		if target.mesh_instance:
			var attack_material = StandardMaterial3D.new()
			attack_material.albedo_color = Color.RED
			attack_material.emission = Color.RED * 0.5
			attack_material.emission_enabled = true
			target.mesh_instance.material_override = attack_material

func get_units_in_attack_range(attacker: Unit) -> Array[Unit]:
	"""Get all enemy units within attack range"""
	var targets: Array[Unit] = []
	var enemy_list = enemy_units if attacker.team == "player" else player_units
	
	for enemy in enemy_list:
		if attacker.can_attack_target(enemy):
			targets.append(enemy)
	
	return targets



# MOVEMENT VISUALIZATION: Show where the selected unit can move
func show_unit_movement_options(unit: Unit):
	print("=== SHOWING MOVEMENT OPTIONS ===")
	print("Unit at ", unit.grid_position, " has movement range: ", unit.movement_range)
	
	# Use the grid's highlighting system to show movement range
	grid.highlight_walkable_tiles(unit.grid_position, unit.movement_range)
	
	print("✓ Movement options displayed")

# Called automatically when any tile in the grid is selected (clicked)
# The tile parameter is the specific Tile object that was clicked
func _on_tile_selected(tile: Tile):
	print("=== TILE CLICKED ===")
	print("Tile position: ", tile.grid_position)
	
	# CHECK IF WE HAVE A SELECTED UNIT: Only proceed if a unit is selected
	if not selected_unit:
		print("✗ No unit selected")
		#print("✗ No unit selected - showing movement range from clicked tile")
		# For debugging: still show range from clicked tile
		#grid.highlight_walkable_tiles(tile.grid_position, 3)
		return
	
	# CHECK IF TILE IS WALKABLE: Can the unit move there?
	#if not tile.is_walkable or tile.occupied_unit:
		#print("✗ Cannot move to ", tile.grid_position, " - tile blocked or occupied")
		#return
	
	# CHECK MOVEMENT RANGE: Is the tile within the unit's movement range?
	var distance = abs(tile.grid_position.x - selected_unit.grid_position.x)  + abs(tile.grid_position.z - selected_unit.grid_position.z)
	if distance > selected_unit.movement_points_remaining:
		print("✗ Cannot move to ", tile.grid_position, " - too far (distance: ", distance, ", range: ", selected_unit.movement_range, ")")
		return
	
	# PERFORM MOVEMENT: Move the selected unit to the clicked tile
	print("✓ Moving ", selected_unit.unit_name, " from ", selected_unit.grid_position, " to ", tile.grid_position)
	move_selected_unit_to_tile(tile)

# UNIT MOVEMENT: Move the currently selected unit to a target tile
func move_selected_unit_to_tile(target_tile: Tile):
	if not selected_unit:
		print("✗ ERROR: No unit selected for movement")
		return
	
	print("=== MOVING UNIT ===")
	print("Moving ", selected_unit.unit_name, " to ", target_tile.grid_position)
	
	# Perform the actual movement
	var success = selected_unit.move_to_tile(target_tile)
	
	if success:
		print("✓ Movement successful!")
		
		# CLEAN UP AFTER MOVEMENT: Clear highlights and deselect
		grid.clear_all_highlights()
		selected_unit.deselect()
		selected_unit = null
		
		print("✓ Unit deselected and highlights cleared")
	else:
		print("✗ Movement failed!")

func end_unit_action():
	"""Clean up after unit action"""
	grid.clear_all_highlights()
	clear_attack_highlights()
	if selected_unit:
		selected_unit.deselect()
	selected_unit = null
	game_state = GameState.SELECTING

func clear_attack_highlights():
	"""Remove red attack highlighting from enemies"""
	for unit in all_units:
		if unit.team != current_team:
			# Restore original material
			unit.setup_visual()  # This resets to default material




func handle_unit_click(unit: Unit):
	"""Handle clicking on units - either select or attack"""
	if unit.team == current_team:
		# Select friendly unit
		_on_unit_selected(unit)
	else:
		# Attack enemy unit
		if selected_unit and selected_unit.can_attack_target(unit):
			selected_unit.attack_unit(unit)
			end_unit_action()
		else:
			print("Cannot attack that target!")

func end_turn():
	"""End current player's turn"""
	print("\n=== ENDING %s TURN ===" % current_team.to_upper())
	
	# Reset all units for next turn
	var current_units = player_units if current_team == "player" else enemy_units
	for unit in current_units:
		unit.reset_turn()
	
	# Switch teams
	current_team = "enemy" if current_team == "player" else "player"
	
	# Clear selections
	if selected_unit:
		selected_unit.deselect()
	selected_unit = null
	grid.clear_all_highlights()
	clear_attack_highlights()
	
	print("=== %s TURN BEGINS ===" % current_team.to_upper())
	
	# Check win conditions
	check_victory_conditions()

func check_victory_conditions():
	"""Check if game is over"""
	if player_units.is_empty():
		print("ENEMY WINS!")
		get_tree().paused = true
	elif enemy_units.is_empty():
		print("PLAYER WINS!")
		get_tree().paused = true

# Add this function to handle unit death:
func _on_unit_died(unit: Unit):
	"""Handle when a unit dies"""
	all_units.erase(unit)
	if unit.team == "player":
		player_units.erase(unit)
	else:
		enemy_units.erase(unit)
	
	print("Unit removed from game: %s" % unit.unit_name)








# Positions the camera to get a good tactical overview of the battlefield
func setup_camera():
	# Get reference to the CameraRig node (parent of the actual camera)
	# Using a rig allows us to move/rotate the camera as a unit
	var camera_rig = $CameraRig
	
	# POSITION CAMERA: Set camera position in 3D world space
	# Vector3(5, 10, 10) means:
	#   X = 5: Positioned 5 units to the right (halfway across a 10x10 grid)
	#   Y = 10: Positioned 10 units up (elevated for overhead view)
	#   Z = 10: Positioned 10 units forward (away from origin)
	camera_rig.position = Vector3(5, 10, 10)
	
	# POINT CAMERA: Make camera look at the center of the grid
	# look_at() rotates the camera to point toward a target position
	# Vector3(5, 0, 5) is center of 10x10 grid (halfway point)
	# Vector3.UP tells Godot which direction is "up" for the camera orientation
	camera_rig.look_at(Vector3(5, 0, 5), Vector3.UP)

	# DEBUG: Check camera configuration
	print("=== CAMERA DEBUG ===")
	print("Camera position: ", camera.position)
	print("Camera is current: ", camera.current)
	
	# Test raycast from camera
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().size / 2  # Center of screen
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	#print("Raycast from: ", from, " to: ", to)
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3  # Check both layer 1 (tiles) and layer 2 (units)
	var _result = space_state.intersect_ray(query)
	
	#if result:
		#print("✓ Raycast hit something at: ", result.position)
		#print("✓ Hit object: ", result.collider)
	#else:
		#print("⚠ Raycast hit nothing - check collision layers!")

# INPUT HANDLER: Handle mouse clicks for both units and tiles
# ===== COMBATSCENE.GD - FIXED _input FUNCTION =====
# Replace your _input function with this corrected version:

func _input(event):
	# Handle mouse clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		#print("\n=== MOUSE CLICK DEBUG ===")
		#print("Mouse position: ", event.position)
		
		# Check if camera exists
		if not camera:
			print("❌ ERROR: Camera not found!")
			return
			
		var space_state = get_world_3d().direct_space_state
		if not space_state:
			print("❌ ERROR: No space state!")
			return
			
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		
		print("Ray from: ", from)
		print("Ray to: ", to)
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 3  # Check layers 1 and 2
		
		var result = space_state.intersect_ray(query)
		
		# Check if we hit anything - result is a Dictionary
		if result.is_empty():
			print("❌ No raycast hit - clicking empty space")
			return
		
		#print("✓ Raycast hit something!")
		#print("Hit position: ", result.position)
		
		# Safe collision detection
		if not result.has("collider") or not result.collider:
			print("❌ ERROR: No collider in result")
			return
			
		var hit_object = result.collider
		#print("Hit object: ", hit_object)
		#print("Hit object type: ", hit_object.get_class())
		#print("Hit object collision layer: ", hit_object.collision_layer)
		if not result.is_empty():
			var collider = result.collider
			print("DEBUG RAY HIT:", collider, " class:", collider.get_class())
			var cur = collider
			var depth = 0
			while cur and depth < 6:
				print("  parent[", depth, "]:", cur, " class:", cur.get_class())
				if cur is Tile:
					print("    -> Tile grid_position:", cur.grid_position, " mesh.visible:", (cur.get_node_or_null('MeshInstance3D') != null and cur.get_node_or_null('MeshInstance3D').visible))
					break
				cur = cur.get_parent()
				depth += 1
		
		
		# Handle unit clicks (collision layer 2)
		if hit_object.collision_layer == 2:
			print("→ Clicked on UNIT layer")
			var unit = hit_object.get_parent()
			if unit is Unit:
				print("✓ Found Unit: ", unit.unit_name)
				handle_unit_click(unit)
			else:
				print("❌ Parent is not a Unit: ", unit)
		
		# Handle tile clicks (collision layer 1)
		elif hit_object.collision_layer == 1:
			print("→ Clicked on TILE layer")
			var tile = hit_object.get_parent()
			if tile is Tile:
				print("✓ Found Tile at: ", tile.grid_position)
				_on_tile_selected(tile)
			else:
				print("❌ Parent is not a Tile: ", tile)
		
		else:
			print("❌ Unknown collision layer: ", hit_object.collision_layer)
	
	# Handle spacebar for ending turn
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("SPACEBAR pressed - ending turn")
		end_turn()
		
	#scroll up and down floors with [ and ]
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:
			grid.switch_layer(-1)
		elif event.keycode == KEY_BRACKETRIGHT:
			grid.switch_layer(1)
