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
	
	# Highlight attack targets
	highlight_attack_targets()

func highlight_attack_targets():
	"""Add visual highlighting to enemies within attack range"""
	if not selected_unit:
		return
		
	var targets = get_units_in_attack_range(selected_unit)
	for target in targets:
		# Apply red highlighting to attackable enemies
		if target.mesh_instance:
			var attack_material = StandardMaterial3D.new()
			attack_material.albedo_color = Color.RED
			attack_material.emission = Color.RED * 0.5
			attack_material.emission_enabled = true
			target.mesh_instance.material_override = attack_material

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
		selected_unit.deselect()
		selected_unit = null

func end_unit_action():
	"""Clean up UI state after any unit action"""
	grid.clear_all_highlights()
	clear_attack_highlights()
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

func handle_unit_click(unit: Unit):
	"""Handle clicking on units - either select friendly or attack enemy"""
	if is_placement_active:
		return  # No unit interaction during placement
		
	if unit.team == current_team:
		# Select friendly unit
		_on_unit_selected(unit)
	else:
		# Attempt to attack enemy unit
		if selected_unit and selected_unit.can_attack_target(unit):
			selected_unit.attack_unit(unit)
			end_unit_action()

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
