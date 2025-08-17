# Unit Manager - Handles all unit-related logic for combat
class_name UnitManager
extends RefCounted

# References
var combat_scene: Node3D
var grid: Grid

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

# Game state enum for reference
enum GameState { SELECTING, MOVING, ATTACKING, ENEMY_TURN }
var game_state: GameState = GameState.SELECTING

func _init(combat_scene_ref: Node3D, grid_ref: Grid):
	combat_scene = combat_scene_ref
	grid = grid_ref

# UNIT SPAWNING: Create and place initial units on the battlefield
func spawn_initial_units():
	print("=== SPAWNING INITIAL UNITS ===")
	
	# SPAWN PLAYER UNITS (left side of battlefield)
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
	
	combat_scene.add_child(unit_instance)
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

func handle_tile_click(tile: Tile):
	"""Handle tile selection for unit movement"""
	print("=== TILE CLICKED ===")
	print("Tile position: ", tile.grid_position)
	
	# CHECK IF WE HAVE A SELECTED UNIT: Only proceed if a unit is selected
	if not selected_unit:
		print("✗ No unit selected")
		return
	
	# CHECK MOVEMENT RANGE: Is the tile within the unit's movement range?
	var distance = abs(tile.grid_position.x - selected_unit.grid_position.x) + abs(tile.grid_position.z - selected_unit.grid_position.z)
	if distance > selected_unit.movement_points_remaining:
		print("✗ Cannot move to ", tile.grid_position, " - too far (distance: ", distance, ", range: ", selected_unit.movement_range, ")")
		return
	
	# PERFORM MOVEMENT: Move the selected unit to the clicked tile
	print("✓ Moving ", selected_unit.unit_name, " from ", selected_unit.grid_position, " to ", tile.grid_position)
	move_selected_unit_to_tile(tile)

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
		combat_scene.get_tree().paused = true
	elif enemy_units.is_empty():
		print("PLAYER WINS!")
		combat_scene.get_tree().paused = true

# Handle when a unit dies:
func _on_unit_died(unit: Unit):
	"""Handle when a unit dies"""
	all_units.erase(unit)
	if unit.team == "player":
		player_units.erase(unit)
	else:
		enemy_units.erase(unit)
	
	print("Unit removed from game: %s" % unit.unit_name)
