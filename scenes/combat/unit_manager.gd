# Unit Manager - Handles all unit-related logic for tactical combat
class_name UnitManager
extends RefCounted

# Core references
var combat_scene: Node3D
var grid: Grid

# Unit tracking arrays - maintain separate lists for easy management
var player_units: Array[Unit] = []    # Player-controlled units
var enemy_units: Array[Unit] = []     # AI/opponent units  
var all_units: Array[Unit] = []       # Combined array for operations affecting all units

# Selection and turn management
var selected_unit: Unit = null        # Currently selected unit (null = none selected)
var current_team: String = "player"   # Which team's turn it is

# Pre-loaded unit scenes for instantiation
var warrior_scene = preload("res://scenes/units/warrior.tscn")
var archer_scene = preload("res://scenes/units/archer.tscn") 
var mage_scene = preload("res://scenes/units/mage.tscn")
var hound_scene = preload("res://scenes/units/hound.tscn")

# Game state tracking
enum GameState { SELECTING, MOVING, ATTACKING, ENEMY_TURN, PLACING_UNITS }
var game_state: GameState = GameState.PLACING_UNITS

# Unit placement system
var placement_ui: Control
var is_placement_active: bool = true

# =============================================
# LINE OF SIGHT SYSTEM - NEW FUNCTIONALITY
# =============================================

# Line of sight configuration
const LOS_HEIGHT_OFFSET = 1.0  # How high above ground to cast the ray
const LOS_COLLISION_MASK = 4   # Layer 3 (buildings/obstacles) = 2^2 = 4

func can_attack_with_line_of_sight(attacker: Unit, target: Unit) -> Dictionary:
	"""
	Check if attacker can attack target considering both range and line of sight
	Returns a dictionary with 'can_attack' bool and 'blocked_by' info
	"""
	var result = {
		"can_attack": false,
		"blocked_by": null,
		"hit_point": Vector3.ZERO,
		"block_percentage": 0.0  # For future partial cover system
	}
	
	# First check if target is in attack range (existing logic)
	if not attacker.can_attack_target(target):
		return result  # Out of range
	
	# Get world positions with height offset for realistic line of sight
	var attacker_pos = attacker.global_position + Vector3(0, LOS_HEIGHT_OFFSET, 0)
	var target_pos = target.global_position + Vector3(0, LOS_HEIGHT_OFFSET, 0)
	
	# Cast ray from attacker to target
	var space_state = combat_scene.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(attacker_pos, target_pos)
	
	# Only check for obstacles/buildings (Layer 3)
	query.collision_mask = LOS_COLLISION_MASK
	
	# Exclude the attacker and target from collision
	var attacker_body = attacker.get_node_or_null("StaticBody3D")
	var target_body = target.get_node_or_null("StaticBody3D")
	
	if attacker_body:
		query.exclude.append(attacker_body.get_rid())
	if target_body:
		query.exclude.append(target_body.get_rid())
	
	var ray_result = space_state.intersect_ray(query)
	
	if ray_result.is_empty():
		# No obstacles in the way
		result.can_attack = true
	else:
		# Something is blocking the shot
		result.blocked_by = ray_result.collider
		result.hit_point = ray_result.position
		
		# For future enhancement: calculate partial cover percentage
		var total_distance = attacker_pos.distance_to(target_pos)
		var blocked_distance = attacker_pos.distance_to(ray_result.position)
		result.block_percentage = (blocked_distance / total_distance) * 100.0
	
	return result

func show_line_of_sight_visual(attacker: Unit, target: Unit, is_clear: bool, hit_point: Vector3 = Vector3.ZERO):
	"""Create visual feedback for line of sight checking"""
	print("=== LINE OF SIGHT VISUAL DEBUG ===")
	print("Creating line from ", attacker.unit_name, " to ", target.unit_name)
	print("Is clear: ", is_clear)
	
	# Clear any existing line visuals
	clear_line_of_sight_visuals()
	
	var start_pos = attacker.global_position + Vector3(0, 0.5, 0)
	var end_pos = target.global_position + Vector3(0, 0.5, 0)
	
	print("Start pos: ", start_pos)
	print("End pos: ", end_pos)
	
	# If blocked, draw line only to the blocking point
	if not is_clear and hit_point != Vector3.ZERO:
		end_pos = hit_point
		print("Blocked - drawing to hit point: ", hit_point)
	
	# Create line visual - but add to scene FIRST
	var line_visual = MeshInstance3D.new()
	combat_scene.add_child(line_visual)  # Add to tree BEFORE setting transforms
	line_visual.add_to_group("los_indicators")
	
	print("Line visual added to scene, configuring mesh...")
	
	# Now configure the mesh and positioning
	setup_line_mesh(line_visual, start_pos, end_pos, is_clear)
	
	print("Line visual setup complete")
	
	# Auto-remove after 3 seconds
	create_auto_remove_timer(line_visual, 3.0)

func setup_line_mesh(line_visual: MeshInstance3D, start_pos: Vector3, end_pos: Vector3, is_clear: bool):
	"""Configure a line mesh that's already in the scene tree"""
	print("Setting up line mesh...")
	print("  Start: ", start_pos)
	print("  End: ", end_pos)
	print("  Distance: ", start_pos.distance_to(end_pos))
	
	var mesh = BoxMesh.new()
	
	# Calculate line properties
	var direction = end_pos - start_pos
	var distance = direction.length()
	var midpoint = start_pos + direction * 0.5
	
	print("  Midpoint: ", midpoint)
	print("  Direction: ", direction)
	
	# Set up thin line mesh
	mesh.size = Vector3(0.1, 0.1, distance)  # Made thicker for visibility
	line_visual.mesh = mesh
	
	print("  Mesh assigned, setting position...")
	
	# Position and orient the line (now that it's in the tree)
	line_visual.global_position = midpoint
	print("  Position set, applying look_at...")
	line_visual.look_at(end_pos, Vector3.UP)
	
	print("  Orientation set, applying material...")
	
	# Set color based on line of sight status
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.GREEN if is_clear else Color.RED
	material.emission = material.albedo_color * 0.4
	material.emission_enabled = true
	line_visual.material_override = material
	
	print("  Line mesh setup complete!")

func create_auto_remove_timer(target_node: Node, delay: float):
	"""Create a timer that removes the target node after delay"""
	var timer = Timer.new()
	timer.wait_time = delay
	timer.one_shot = true
	timer.timeout.connect(func(): 
		if is_instance_valid(target_node):
			target_node.queue_free()
	)
	target_node.add_child(timer)
	timer.start()

func clear_line_of_sight_visuals():
	"""Remove all existing line of sight visual indicators"""
	var indicators = combat_scene.get_tree().get_nodes_in_group("los_indicators")
	for indicator in indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()

func show_attack_blocked_feedback(attacker: Unit, target: Unit, blocker):
	"""Show feedback when an attack is blocked by line of sight"""
	var blocker_name = "obstacle"
	if blocker:
		if blocker.has_method("get_name"):
			blocker_name = blocker.name
		elif blocker.get_parent() and blocker.get_parent().has_method("get_display_name"):
			blocker_name = blocker.get_parent().get_display_name()
	
	# For now, just print to console - you could show a UI message instead
	print("%s cannot attack %s - line of sight blocked by %s" % [attacker.unit_name, target.unit_name, blocker_name])

# =============================================
# UPDATED METHODS - Modified to use line of sight
# =============================================

# Modified highlight_attack_targets to show line of sight status
func highlight_attack_targets():
	"""Highlight enemies within attack range, showing line of sight status"""
	if not selected_unit:
		return
		
	var enemy_list = enemy_units if selected_unit.team == "player" else player_units
	
	for enemy in enemy_list:
		if enemy.mesh_instance:
			var los_result = can_attack_with_line_of_sight(selected_unit, enemy)
			
			if los_result.can_attack:
				# Clear line of sight - attackable (red)
				var attack_material = StandardMaterial3D.new()
				attack_material.albedo_color = Color.RED
				attack_material.emission = Color.RED * 0.5
				attack_material.emission_enabled = true
				enemy.mesh_instance.material_override = attack_material
			elif selected_unit.can_attack_target(enemy):  # In range but blocked
				# Blocked line of sight (orange)
				var blocked_material = StandardMaterial3D.new()
				blocked_material.albedo_color = Color.ORANGE
				blocked_material.emission = Color.ORANGE * 0.3
				blocked_material.emission_enabled = true
				enemy.mesh_instance.material_override = blocked_material
			# Units out of range get no highlighting

# Modified handle_unit_click to use line of sight
func handle_unit_click(unit: Unit):
	"""Handle clicking on units - either select or attack with line of sight check"""
	if is_placement_active:
		return  # No unit interaction during placement
		
	if unit.team == current_team:
		# Select friendly unit
		_on_unit_selected(unit)
	else:
		# Attempt to attack enemy unit with line of sight check
		if selected_unit:
			var los_result = can_attack_with_line_of_sight(selected_unit, unit)
			
			if los_result.can_attack:
				# Clear shot - show line FIRST, then attack after delay
				show_line_of_sight_visual(selected_unit, unit, true)
				
				# Create a timer to delay the attack so we can see the line
				var attack_timer = Timer.new()
				attack_timer.wait_time = 1.0  # Show line for 1 second
				attack_timer.one_shot = true
				attack_timer.timeout.connect(func():
					if is_instance_valid(selected_unit) and is_instance_valid(unit):
						selected_unit.attack_unit(unit)
					attack_timer.queue_free()
					end_unit_action()
				)
				combat_scene.add_child(attack_timer)
				attack_timer.start()
			else:
				# Blocked shot - show visual feedback
				show_line_of_sight_visual(selected_unit, unit, false, los_result.hit_point)
				show_attack_blocked_feedback(selected_unit, unit, los_result.blocked_by)

# =============================================
# EXISTING METHODS - Keep all your current functionality
# =============================================

func _init(combat_scene_ref: Node3D, grid_ref: Grid):
	"""Initialize the unit manager with scene and grid references"""
	combat_scene = combat_scene_ref
	grid = grid_ref

func spawn_initial_units():
	"""Start interactive unit placement phase instead of automatic spawning"""
	# Load and instantiate the placement UI
	var placement_ui_scene = preload("res://scenes/ui/unit_placement_ui.tscn")
	placement_ui = placement_ui_scene.instantiate()
	
	# Add UI to the scene
	combat_scene.add_child(placement_ui)
	
	# Connect completion signal
	placement_ui.unit_placement_complete.connect(_on_unit_placement_complete)
	
	# Begin placement process
	placement_ui.start_unit_placement(self, grid)

func _on_unit_placement_complete():
	"""Transition from placement phase to gameplay phase"""
	is_placement_active = false
	game_state = GameState.SELECTING

func spawn_enemy_units():
	"""Spawn enemy units after player placement is complete"""
	# Define enemy spawn positions on the right side of the battlefield
	var enemy_positions = [
		Vector3i(8, 0, 2),
		Vector3i(9, 0, 4), 
		Vector3i(7, 0, 6),
		Vector3i(8, 0, 8)
	]
	
	# Spawn hounds at each position with fallback positioning
	for pos in enemy_positions:
		spawn_unit_with_fallback("hound", "enemy", [pos])

func connect_unit_signals():
	"""Set up signal connections for all units after spawning is complete"""
	for unit in all_units:
		unit.unit_selected.connect(_on_unit_selected)
		unit.unit_died.connect(_on_unit_died)

func spawn_unit_with_fallback(unit_type: String, team: String, preferred_positions: Array[Vector3i]):
	"""Attempt to spawn a unit at preferred positions, with fallback logic for occupied tiles"""
	# Try each preferred position in order
	for grid_pos in preferred_positions:
		var unit = spawn_unit(unit_type, team, grid_pos)
		if unit:  # Spawn succeeded
			return unit
	
	# All preferred positions failed - find any safe position in team area
	var backup_position = find_safe_spawn_area(team)
	if backup_position != Vector3i(-1, 0, -1):
		return spawn_unit(unit_type, team, backup_position)
	else:
		push_error("Could not find any valid spawn position for %s (%s)" % [unit_type, team])
		return null

func find_safe_spawn_area(team: String) -> Vector3i:
	"""Find any walkable, unoccupied tile in the team's designated area"""
	var search_columns: Array[int] = []
	
	# Define search areas by team
	if team == "player":
		search_columns = [0, 1, 2, 3]  # Left side of battlefield
	else:
		search_columns = [6, 7, 8, 9]  # Right side of battlefield
	
	# Search systematically through the team's area
	for x in search_columns:
		for z in range(grid.grid_height):
			var tile = grid.get_tile(Vector3i(x, 0, z))
			if tile and tile.is_walkable and not tile.occupied_unit:
				return Vector3i(x, 0, z)
	
	# No safe area found
	return Vector3i(-1, 0, -1)

func spawn_unit(unit_type: String, team: String, grid_pos: Vector3i):
	"""Create and place a specific unit type at the specified grid position"""
	# Validate target tile
	var target_tile = grid.get_tile(grid_pos)
	if not target_tile or not target_tile.is_walkable: 
		return null
	
	if target_tile.occupied_unit:
		return null
	
	# Instantiate the appropriate unit scene
	var unit_instance: Unit = null
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
			push_error("Unknown unit type: %s" % unit_type)
			return null
	
	# Configure unit properties
	unit_instance.team = team
	
	# Apply visual distinction for enemy units (except hounds which handle their own appearance)
	if team == "enemy" and unit_type != "hound":
		unit_instance.unit_color = unit_instance.unit_color.darkened(0.4)
	
	# Add to scene and position on grid
	combat_scene.add_child(unit_instance)
	unit_instance.place_on_tile(target_tile)
	
	# Add to tracking arrays
	all_units.append(unit_instance)
	if team == "player":
		player_units.append(unit_instance)
	else:
		enemy_units.append(unit_instance)
	
	return unit_instance

func handle_tile_click(tile: Tile):
	"""Route tile clicks to appropriate handler based on game state"""
	if is_placement_active and placement_ui:
		# During placement, let the placement UI handle clicks
		placement_ui.handle_tile_click(tile)
	else:
		# During normal gameplay, handle as movement/selection
		handle_tile_click_gameplay(tile)

func handle_tile_click_gameplay(tile: Tile):
	"""Handle tile clicks during normal gameplay for unit movement"""
	# Require a selected unit for movement
	if not selected_unit:
		return
	
	# Check if tile is within movement range
	var distance = abs(tile.grid_position.x - selected_unit.grid_position.x) + abs(tile.grid_position.z - selected_unit.grid_position.z)
	if distance > selected_unit.movement_points_remaining:
		return
	
	# Execute movement
	move_selected_unit_to_tile(tile)

func _on_unit_selected(unit: Unit):
	"""Handle unit selection during gameplay"""
	if is_placement_active:
		return  # No selection during placement
		
	if unit.team != current_team: 
		return  # Can only select own units
		
	if unit.has_acted:
		return  # Unit has already acted this turn
		
	# Deselect previous unit if different
	if selected_unit and selected_unit != unit:
		selected_unit.deselect()
		grid.clear_all_highlights()
		clear_line_of_sight_visuals()  # Clear any existing line visuals
	
	# Select new unit
	selected_unit = unit
	unit.select()
	game_state = GameState.SELECTING
	show_unit_options()

func show_unit_options():
	"""Display available actions for the selected unit and highlight valid targets"""
	if not selected_unit:
		return
	
	# Highlight movement options
	grid.highlight_walkable_tiles(selected_unit.grid_position, selected_unit.movement_points_remaining)
	
	# Highlight attack targets with line of sight
	highlight_attack_targets()

func get_units_in_attack_range(attacker: Unit) -> Array[Unit]:
	"""Get all enemy units within the attacker's range"""
	var targets: Array[Unit] = []
	var enemy_list = enemy_units if attacker.team == "player" else player_units
	
	for enemy in enemy_list:
		if attacker.can_attack_target(enemy):
			targets.append(enemy)
	
	return targets

func move_selected_unit_to_tile(target_tile: Tile):
	"""Move the currently selected unit to the specified tile"""
	if not selected_unit:
		return
	
	# Attempt movement
	var success = selected_unit.move_to_tile(target_tile)
	
	if success:
		# Clean up UI state after successful movement
		grid.clear_all_highlights()
		clear_line_of_sight_visuals()
		selected_unit.deselect()
		selected_unit = null

func end_unit_action():
	"""Clean up UI state after any unit action"""
	grid.clear_all_highlights()
	clear_attack_highlights()
	clear_line_of_sight_visuals()
	if selected_unit:
		selected_unit.deselect()
	selected_unit = null
	game_state = GameState.SELECTING

func clear_attack_highlights():
	"""Remove attack highlighting from all units"""
	for unit in all_units:
		if unit.team != current_team:
			# Restore original visual appearance
			unit.setup_visual()

func end_turn():
	"""End current player's turn and switch to the other team"""
	if is_placement_active:
		return  # Can't end turn during placement
	
	# Reset all units for the ending team
	var current_units = player_units if current_team == "player" else enemy_units
	for unit in current_units:
		unit.reset_turn()
	
	# Switch active team
	current_team = "enemy" if current_team == "player" else "player"
	
	# Clear UI state
	if selected_unit:
		selected_unit.deselect()
	selected_unit = null
	grid.clear_all_highlights()
	clear_attack_highlights()
	clear_line_of_sight_visuals()
	
	# Check for victory conditions
	check_victory_conditions()

func check_victory_conditions():
	"""Check if either team has won the battle"""
	if player_units.is_empty():
		combat_scene.get_tree().paused = true
		# Could emit a signal here for game over UI
	elif enemy_units.is_empty():
		combat_scene.get_tree().paused = true
		# Could emit a signal here for victory UI

func _on_unit_died(unit: Unit):
	"""Handle unit death - remove from all tracking arrays"""
	all_units.erase(unit)
	if unit.team == "player":
		player_units.erase(unit)
	else:
		enemy_units.erase(unit)
