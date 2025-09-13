# Unit Placement UI - Updated for sci-fi units with flexible expansion
extends Control

signal unit_placement_complete

var unit_manager: UnitManager
var grid: Grid
var selected_unit_type: String = ""

# Double-click detection for unit removal
var last_click_time: float = 0.0
var last_clicked_unit: Unit = null
var double_click_threshold: float = 0.5

# UPDATED: Flexible unit configuration system
# Define available PLAYER units with their limits and display info
var available_units: Dictionary = {
	"assassin": {
		"limit": 4,          # Allow 4 assassins
		"display_name": "Assassin",
		"description": "Stealth unit with high mobility and critical strikes"
	}
	# Easy to add more player units later:
	# "sniper": {
	#     "limit": 2,
	#     "display_name": "Sniper", 
	#     "description": "Long-range precision unit"
	# },
	# "heavy": {
	#     "limit": 1,
	#     "display_name": "Heavy Trooper",
	#     "description": "Heavily armored frontline unit"
	# }
}

# Track how many units have been placed
var units_placed: Dictionary = {}

# UI references - now dynamic based on available units
var unit_buttons: Dictionary = {}
var finish_button: Button

func _ready():
	# Initialize placement counters
	for unit_type in available_units.keys():
		units_placed[unit_type] = 0
	
	# Create UI dynamically
	setup_dynamic_ui()

func setup_dynamic_ui():
	"""Create UI buttons dynamically based on available units"""
	# Clear any existing children (in case of restart)
	for child in get_children():
		child.queue_free()
	
	unit_buttons.clear()
	
	# Create main container
	var main_container = VBoxContainer.new()
	add_child(main_container)
	
	# Create title label
	var title_label = Label.new()
	title_label.text = "Deploy Your Units"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Create button container
	var button_container = VBoxContainer.new()
	main_container.add_child(button_container)
	
	# Create buttons for each available unit type
	for unit_type in available_units.keys():
		var unit_data = available_units[unit_type]
		
		var button = Button.new()
		button.text = "%s (0/%d)" % [unit_data.display_name, unit_data.limit]
		button.custom_minimum_size = Vector2(200, 40)
		
		# Store reference and connect signal
		unit_buttons[unit_type] = button
		button.pressed.connect(_on_unit_button_pressed.bind(unit_type))
		
		button_container.add_child(button)
		
		# Add description label
		var desc_label = Label.new()
		desc_label.text = unit_data.description
		desc_label.modulate = Color.GRAY
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button_container.add_child(desc_label)
		
		# Add spacing
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 10)
		button_container.add_child(spacer)
	
	# Create finish button (initially hidden)
	finish_button = Button.new()
	finish_button.text = "Start Battle!"
	finish_button.custom_minimum_size = Vector2(200, 50)
	finish_button.pressed.connect(_on_finish_placement)
	main_container.add_child(finish_button)
	finish_button.hide()
	
	# Initial button state update
	update_button_states()

func _on_unit_button_pressed(unit_type: String):
	"""Handle unit button press - select unit type if available"""
	if units_placed[unit_type] < available_units[unit_type].limit:
		selected_unit_type = unit_type
		update_button_states()

func update_button_states():
	"""Update button visual states to show selection and availability"""
	for unit_type in unit_buttons.keys():
		var button = unit_buttons[unit_type]
		var unit_data = available_units[unit_type]
		var placed = units_placed[unit_type]
		var limit = unit_data.limit
		var can_place = placed < limit
		
		# Update button text
		button.text = "%s (%d/%d)" % [unit_data.display_name, placed, limit]
		
		# Update button appearance
		if not can_place:
			button.disabled = true
			button.modulate = Color.GRAY
		else:
			button.disabled = false
			if selected_unit_type == unit_type:
				button.modulate = Color.YELLOW  # Selected
			else:
				button.modulate = Color.WHITE   # Available

func start_unit_placement(manager: UnitManager, grid_ref: Grid):
	"""Initialize the placement system and show the UI"""
	unit_manager = manager
	grid = grid_ref
	
	update_button_states()
	show()

func handle_tile_click(tile: Tile):
	"""Handle tile clicks during placement - either place units or remove them"""
	# Handle unit removal via double-click on existing units
	if tile.occupied_unit and tile.occupied_unit.team == "player":
		handle_unit_click_for_removal(tile.occupied_unit)
		return
	
	# Validate placement requirements
	if selected_unit_type == "":
		return  # No unit type selected
	
	if not tile or not tile.is_walkable:
		return  # Invalid tile
	
	if tile.occupied_unit:
		return  # Tile already occupied
	
	# Check unit limit
	if units_placed[selected_unit_type] >= available_units[selected_unit_type].limit:
		return  # Limit reached
	
	# Place the unit
	var unit = unit_manager.spawn_unit(selected_unit_type, "player", tile.grid_position)
	
	if unit:
		# Update placement counts
		units_placed[selected_unit_type] += 1
		
		# Update UI state
		update_button_states()
		
		# Clear selection if limit reached
		if units_placed[selected_unit_type] >= available_units[selected_unit_type].limit:
			selected_unit_type = ""
		
		# Check if all units are now placed
		check_placement_completion()

func handle_unit_click_for_removal(unit: Unit):
	"""Handle clicking on existing units - remove them with double-click"""
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check for double-click
	if last_clicked_unit == unit and (current_time - last_click_time) < double_click_threshold:
		# Double-click detected - remove the unit
		remove_unit(unit)
		# Reset click tracking
		last_clicked_unit = null
		last_click_time = 0.0
	else:
		# Single click - track for potential double-click
		last_clicked_unit = unit
		last_click_time = current_time

func remove_unit(unit: Unit):
	"""Remove a placed unit and refund it to the placement budget"""
	if not unit or unit.team != "player":
		return  # Only remove player units
	
	# Determine unit type from the unit
	var unit_type = get_unit_type_from_unit(unit)
	if unit_type == "":
		return  # Unknown unit type
	
	# Update placement counts
	if units_placed.has(unit_type):
		units_placed[unit_type] -= 1
	
	# Clear tile occupation
	var tile = unit.current_tile
	if tile:
		tile.occupied_unit = null
	
	# Remove from unit manager arrays
	unit_manager.all_units.erase(unit)
	unit_manager.player_units.erase(unit)
	
	# Remove from scene
	unit.queue_free()
	
	# Update UI state
	update_button_states()
	
	# Update finish button visibility
	check_placement_completion()

func get_unit_type_from_unit(unit: Unit) -> String:
	"""Determine unit type from unit instance"""
	# Check unit class first
	if unit.unit_class and available_units.has(unit.unit_class):
		return unit.unit_class
	
	# Fallback to name matching
	var unit_name = unit.unit_name.to_lower()
	for unit_type in available_units.keys():
		if unit_type in unit_name:
			return unit_type
	
	# Last resort: check scene filename
	var scene_file = unit.scene_file_path
	if scene_file:
		for unit_type in available_units.keys():
			if unit_type in scene_file:
				return unit_type
	
	return ""  # Could not determine type

func check_placement_completion():
	"""Check if all units are placed and show/hide finish button accordingly"""
	var total_placed = 0
	var total_allowed = 0
	
	# Calculate totals
	for unit_type in available_units.keys():
		total_placed += units_placed[unit_type]
		total_allowed += available_units[unit_type].limit
	
	# Show finish button if all units placed, hide otherwise
	if total_placed >= total_allowed:
		finish_button.show()
	else:
		finish_button.hide()

func _on_finish_placement():
	"""Complete unit placement and transition to battle phase"""
	# Spawn enemy units
	unit_manager.spawn_enemy_units()
	
	# Connect all unit signals for combat
	unit_manager.connect_unit_signals()
	
	# Hide this UI
	hide()
	
	# Signal that placement is complete
	unit_placement_complete.emit()

# UTILITY FUNCTIONS FOR EASY UNIT EXPANSION
# =========================================

func add_new_unit_type(unit_type: String, limit: int, display_name: String, description: String):
	"""Dynamically add a new unit type (useful for DLC/updates)"""
	available_units[unit_type] = {
		"limit": limit,
		"display_name": display_name,
		"description": description
	}
	units_placed[unit_type] = 0
	
	# Rebuild UI if already created
	if unit_buttons.size() > 0:
		setup_dynamic_ui()

func set_unit_limit(unit_type: String, new_limit: int):
	"""Change the deployment limit for a unit type"""
	if available_units.has(unit_type):
		available_units[unit_type].limit = new_limit
		update_button_states()

# Debug function for testing new units
func debug_add_test_units():
	"""Add some test units for development"""
	add_new_unit_type("sniper", 2, "Sniper", "Long-range precision unit")
	add_new_unit_type("heavy", 1, "Heavy Trooper", "Heavily armored frontline unit")
