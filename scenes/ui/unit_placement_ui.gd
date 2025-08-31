# Unit Placement UI - Interactive unit spawning before combat
extends Control

signal unit_placement_complete

var unit_manager: UnitManager
var grid: Grid
var selected_unit_type: String = ""

# Double-click detection for unit removal
var last_click_time: float = 0.0
var last_clicked_unit: Unit = null
var double_click_threshold: float = 0.5

# Unit budget system - defines how many of each unit type can be placed
var unit_limits: Dictionary = {
	"warrior": 2,  # Allow 2 warriors
	"archer": 1,   # Allow 1 archer  
	"mage": 1      # Allow 1 mage
}

# Track how many units have been placed
var units_placed: Dictionary = {
	"warrior": 0,
	"archer": 0, 
	"mage": 0
}

# UI button references
@onready var warrior_button: Button
@onready var archer_button: Button  
@onready var mage_button: Button
@onready var finish_button: Button

func _ready():
	# Find and connect UI buttons
	setup_button_references()
	setup_button_connections()
	
	# Initially hide finish button until all units are placed
	if finish_button:
		finish_button.hide()

func setup_button_references():
	"""Find button references using multiple fallback methods"""
	# Try direct node paths first
	warrior_button = get_node_or_null("WarriorButton")
	archer_button = get_node_or_null("ArcherButton")
	mage_button = get_node_or_null("MageButton")
	finish_button = get_node_or_null("FinishButton")
	
	# Fallback: search by name pattern
	if not warrior_button:
		warrior_button = find_child("*Warrior*", true, false)
	if not archer_button:
		archer_button = find_child("*Archer*", true, false)
	if not mage_button:
		mage_button = find_child("*Mage*", true, false)
	if not finish_button:
		finish_button = find_child("*Finish*", true, false)
	
	# Final fallback: recursive search by button text
	if not warrior_button or not archer_button or not mage_button:
		search_for_buttons_recursive(self)

func search_for_buttons_recursive(node: Node):
	"""Recursively search for buttons by examining their text content"""
	for child in node.get_children():
		if child is Button:
			var text = child.text.to_lower()
			if "warrior" in text and not warrior_button:
				warrior_button = child
			elif "archer" in text and not archer_button:
				archer_button = child
			elif "mage" in text and not mage_button:
				mage_button = child
			elif "finish" in text and not finish_button:
				finish_button = child
		search_for_buttons_recursive(child)

func setup_button_connections():
	"""Connect button signals to their respective handlers"""
	if warrior_button:
		# Disconnect any existing connections to prevent duplicates
		if warrior_button.pressed.is_connected(_on_warrior_selected):
			warrior_button.pressed.disconnect(_on_warrior_selected)
		warrior_button.pressed.connect(_on_warrior_selected)
	
	if archer_button:
		if archer_button.pressed.is_connected(_on_archer_selected):
			archer_button.pressed.disconnect(_on_archer_selected)
		archer_button.pressed.connect(_on_archer_selected)
	
	if mage_button:
		if mage_button.pressed.is_connected(_on_mage_selected):
			mage_button.pressed.disconnect(_on_mage_selected)
		mage_button.pressed.connect(_on_mage_selected)
	
	if finish_button:
		if finish_button.pressed.is_connected(_on_finish_placement):
			finish_button.pressed.disconnect(_on_finish_placement)
		finish_button.pressed.connect(_on_finish_placement)

# Button signal handlers - set the selected unit type for placement
func _on_warrior_selected():
	if units_placed["warrior"] < unit_limits["warrior"]:
		selected_unit_type = "warrior"
		update_button_highlights()

func _on_archer_selected():
	if units_placed["archer"] < unit_limits["archer"]:
		selected_unit_type = "archer"
		update_button_highlights()

func _on_mage_selected():
	if units_placed["mage"] < unit_limits["mage"]:
		selected_unit_type = "mage"
		update_button_highlights()

func update_button_highlights():
	"""Update button visual states to show selection and availability"""
	# Update warrior button
	if warrior_button:
		var can_place_warrior = units_placed["warrior"] < unit_limits["warrior"]
		warrior_button.modulate = Color.WHITE if selected_unit_type != "warrior" else Color.YELLOW
		warrior_button.disabled = not can_place_warrior
		if not can_place_warrior:
			warrior_button.modulate = Color.GRAY
		warrior_button.text = "Warrior (%d/%d)" % [units_placed["warrior"], unit_limits["warrior"]]
	
	# Update archer button
	if archer_button:
		var can_place_archer = units_placed["archer"] < unit_limits["archer"]
		archer_button.modulate = Color.WHITE if selected_unit_type != "archer" else Color.YELLOW
		archer_button.disabled = not can_place_archer
		if not can_place_archer:
			archer_button.modulate = Color.GRAY
		archer_button.text = "Archer (%d/%d)" % [units_placed["archer"], unit_limits["archer"]]
	
	# Update mage button
	if mage_button:
		var can_place_mage = units_placed["mage"] < unit_limits["mage"]
		mage_button.modulate = Color.WHITE if selected_unit_type != "mage" else Color.YELLOW
		mage_button.disabled = not can_place_mage
		if not can_place_mage:
			mage_button.modulate = Color.GRAY
		mage_button.text = "Mage (%d/%d)" % [units_placed["mage"], unit_limits["mage"]]

func start_unit_placement(manager: UnitManager, grid_ref: Grid):
	"""Initialize the placement system and show the UI"""
	unit_manager = manager
	grid = grid_ref
	
	# Set initial button states to show unit limits
	update_button_highlights()
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
	if units_placed[selected_unit_type] >= unit_limits[selected_unit_type]:
		return  # Limit reached
	
	# Place the unit
	var unit = unit_manager.spawn_unit(selected_unit_type, "player", tile.grid_position)
	
	if unit:
		# Update placement counts
		units_placed[selected_unit_type] += 1
		
		# Update UI state
		update_button_highlights()
		
		# Clear selection if limit reached
		if units_placed[selected_unit_type] >= unit_limits[selected_unit_type]:
			selected_unit_type = ""
		
		# Check if all units are now placed
		check_placement_completion()

func show_finish_button():
	"""Show the finish placement button when all units are placed"""
	if finish_button:
		finish_button.show()
	else:
		# Create finish button dynamically if not found in scene
		finish_button = Button.new()
		finish_button.text = "Start Battle!"
		finish_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(finish_button)
		finish_button.pressed.connect(_on_finish_placement)

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
	update_button_highlights()
	
	# Update finish button visibility
	check_placement_completion()

func get_unit_type_from_unit(unit: Unit) -> String:
	"""Determine unit type from unit instance by examining name or scene path"""
	var unit_name = unit.unit_name.to_lower()
	
	# Try to match by unit name first
	if "warrior" in unit_name:
		return "warrior"
	elif "archer" in unit_name:
		return "archer"
	elif "mage" in unit_name:
		return "mage"
	else:
		# Fallback: try to match by scene filename
		var scene_file = unit.scene_file_path
		if scene_file:
			if "warrior" in scene_file:
				return "warrior"
			elif "archer" in scene_file:
				return "archer"
			elif "mage" in scene_file:
				return "mage"
	
	return ""  # Could not determine type

func check_placement_completion():
	"""Check if all units are placed and show/hide finish button accordingly"""
	var total_placed = 0
	var total_allowed = 0
	
	# Calculate totals
	for unit_type in units_placed.keys():
		total_placed += units_placed[unit_type]
		total_allowed += unit_limits[unit_type]
	
	# Show finish button if all units placed, hide otherwise
	if total_placed >= total_allowed:
		show_finish_button()
	else:
		if finish_button:
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

# Debug function for manual testing
func test_buttons():
	"""Manual test function for button connectivity"""
	if warrior_button:
		_on_warrior_selected()
	if archer_button:
		_on_archer_selected()
	if mage_button:
		_on_mage_selected()
