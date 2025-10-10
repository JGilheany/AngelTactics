# BarracksUI.gd - Squad management and unit equipment interface
extends Control

signal room_closed

# References from base scene
var base_scene: Node3D
var camera_controller: Node3D
var inventory_manager: InventoryManager

# Squad management
var squad_units: Array[Unit] = []
var selected_unit: Unit = null
var max_squad_size: int = 8
var is_loading_squad: bool = false #should prevent signal loops during loading

# UI References
@onready var room_panel = $RoomPanel
@onready var title_label = $RoomPanel/MainContainer/HeaderContainer/TitleLabel
@onready var squad_info_label = $RoomPanel/MainContainer/HeaderContainer/SquadInfoLabel

# Squad panel
@onready var unit_list = $RoomPanel/MainContainer/ContentContainer/SquadPanel/SquadContainer/ScrollContainer/UnitList
@onready var add_unit_button = $RoomPanel/MainContainer/ContentContainer/SquadPanel/SquadContainer/SquadActionsContainer/AddUnitButton
@onready var remove_unit_button = $RoomPanel/MainContainer/ContentContainer/SquadPanel/SquadContainer/SquadActionsContainer/RemoveUnitButton

# Unit details panel
@onready var unit_name_label = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/UnitNameContainer/UnitNameLabel
@onready var edit_name_button = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/UnitNameContainer/EditNameButton
@onready var class_label = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/UnitStatsContainer/ClassLabel
@onready var health_label = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/UnitStatsContainer/HealthLabel
@onready var speed_label = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/UnitStatsContainer/SpeedLabel
@onready var armor_label = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/UnitStatsContainer/ArmorLabel
@onready var power_label = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/UnitStatsContainer/PowerLabel

# Equipment slots
@onready var equipment_slots_container = $RoomPanel/MainContainer/ContentContainer/UnitDetailsPanel/UnitDetailsContainer/EquipmentSlotsContainer

# NPC elements
@onready var npc_name_label = $RoomPanel/MainContainer/ContentContainer/NPCPanel/NPCContainer/NPCNameLabel
@onready var npc_portrait = $RoomPanel/MainContainer/ContentContainer/NPCPanel/NPCContainer/NPCPortrait
@onready var dialogue_label = $RoomPanel/MainContainer/ContentContainer/NPCPanel/NPCContainer/DialogueLabel

# Unit display panel
@onready var unit_viewport = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/UnitViewport
@onready var unit_model_3d = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/UnitViewport/UnitModel3D
@onready var unit_mesh = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/UnitViewport/UnitModel3D/UnitMesh

# WRVSS stats
@onready var wisdom_value = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/WRVSSStatsContainer/WisdomContainer/WisdomValue
@onready var rage_value = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/WRVSSStatsContainer/RageContainer/RageValue
@onready var virtue_value = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/WRVSSStatsContainer/VirtueContainer/VirtueValue
@onready var strength_value = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/WRVSSStatsContainer/StrengthContainer/StrengthValue
@onready var steel_value = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/WRVSSStatsContainer/SteelContainer/SteelValue

# Relationships (placeholder for now)
@onready var relationships_list = $RoomPanel/MainContainer/ContentContainer/UnitDisplayPanel/UnitDisplayContainer/RelationshipsContainer/RelationshipScrollContainer/RelationshipsList


# Action buttons
@onready var focus_unit_button = $RoomPanel/MainContainer/ActionsPanel/FocusUnitButton
@onready var validate_loadout_button = $RoomPanel/MainContainer/ActionsPanel/ValidateLoadoutButton
@onready var close_button = $RoomPanel/MainContainer/ActionsPanel/CloseButton

# Equipment selection dialog
@onready var equipment_dialog = $EquipmentSelectionDialog
@onready var dialog_title = $EquipmentSelectionDialog/DialogContainer/DialogTitle
@onready var search_field = $EquipmentSelectionDialog/DialogContainer/SearchContainer/SearchField
@onready var filter_dropdown = $EquipmentSelectionDialog/DialogContainer/SearchContainer/FilterDropdown
@onready var equipment_list = $EquipmentSelectionDialog/DialogContainer/EquipmentScrollContainer/EquipmentList
@onready var confirm_button = $EquipmentSelectionDialog/DialogContainer/DialogActions/ConfirmButton
@onready var cancel_button = $EquipmentSelectionDialog/DialogContainer/DialogActions/CancelButton

# Equipment selection state
var current_equipment_slot: String = ""
var available_equipment: Array[Dictionary] = []
var filtered_equipment: Array[Dictionary] = []
var selected_equipment_name: String = ""


func _ready():
	"""Initialize the barracks UI"""
	visible = false
	setup_ui_connections()
	setup_equipment_dialog()
	
	test_squad_manager_connection()


func initialize(base_scene_ref: Node3D, camera_controller_ref: Node3D, inventory_manager_ref: InventoryManager):
	"""Initialize with references from base scene"""
	base_scene = base_scene_ref
	camera_controller = camera_controller_ref
	inventory_manager = inventory_manager_ref
	
	# Connect to inventory changes
	if inventory_manager:
		inventory_manager.inventory_changed.connect(_on_inventory_changed)
	
	# Connect to squad manager changes
	if SquadManager:
		SquadManager.squad_changed.connect(_on_squad_changed)


func show_barracks(npc: BaseNPC = null):
	"""Show the barracks interface with optional NPC"""
	print("BarracksUI: Showing barracks interface")
	
	visible = true
	load_squad_from_base()
	update_squad_display()
	
	print("BarracksUI: Squad loaded, display updated")
	
	# Initialize 3D viewport
	setup_unit_viewport()
	
	# Clear unit selection initially
	selected_unit = null
	update_unit_details()
	update_unit_display()

func setup_unit_viewport():
	"""Setup the 3D viewport for unit display"""
	if not unit_viewport:
		print("Warning: Unit viewport not found")
		return
	
	# Set viewport size
	unit_viewport.size = Vector2(260, 200)
	
	# Create a simple placeholder mesh if unit_mesh exists
	if unit_mesh:
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.8, 1.0, 0.8)
		unit_mesh.mesh = box_mesh
		
		# Create default material
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.GRAY
		unit_mesh.material_override = material

func setup_ui_connections():
	"""Connect all UI signals"""
	add_unit_button.pressed.connect(_on_add_unit_pressed)
	remove_unit_button.pressed.connect(_on_remove_unit_pressed)
	edit_name_button.pressed.connect(_on_edit_name_pressed)
	focus_unit_button.pressed.connect(_on_focus_unit_pressed)
	validate_loadout_button.pressed.connect(_on_validate_loadout_pressed)
	close_button.pressed.connect(_on_close_pressed)

func setup_equipment_dialog():
	"""Setup equipment selection dialog"""
	if not equipment_dialog:
		print("Error: EquipmentSelectionDialog not found in scene")
		return
	
	if not filter_dropdown:
		print("Error: FilterDropdown not found in scene")
		return
	
	# Setup filter dropdown
	filter_dropdown.add_item("All Equipment")
	filter_dropdown.add_item("Weapons")
	filter_dropdown.add_item("Armor")
	filter_dropdown.add_item("Cores")
	filter_dropdown.add_item("Accessories")
	filter_dropdown.add_item("Other")
	
	# Connect dialog signals - with null checks
	if search_field:
		search_field.text_changed.connect(_on_equipment_search_changed)
	else:
		print("Warning: SearchField not found")
	
	if filter_dropdown:
		filter_dropdown.item_selected.connect(_on_equipment_filter_changed)
	else:
		print("Warning: FilterDropdown not found")
	
	if confirm_button:
		confirm_button.pressed.connect(_on_equipment_confirm_pressed)
	else:
		print("Warning: ConfirmButton not found")
	
	if cancel_button:
		cancel_button.pressed.connect(_on_equipment_cancel_pressed)
	else:
		print("Warning: CancelButton not found")
	
	if equipment_dialog:
		equipment_dialog.canceled.connect(_on_equipment_cancel_pressed)
	else:
		print("Warning: EquipmentDialog not found")

func load_squad_from_base():
	"""Load current squad from SquadManager"""
	squad_units.clear()
	
	# Get squad data from SquadManager
	var squad_data = SquadManager.get_squad_units()
	
	# Convert dictionary data to Unit objects
	for unit_data in squad_data:
		var unit = SquadManager.create_unit_from_data(unit_data)
		squad_units.append(unit)
	
	# If no squad exists, create demo units for initial setup
	if squad_units.is_empty():
		create_initial_squad()

func create_initial_squad():
	"""Create initial demo squad and store in SquadManager"""
	print("BarracksUI: Creating initial demo squad")
	
	is_loading_squad = true  # Prevent signal loops
	
	var demo_units: Array[Unit] = []
	
	for i in range(3):
		print("BarracksUI: Creating demo unit ", i + 1)
		
		var unit = Unit.new()
		# Don't set unit_id here - let SquadManager assign it
		unit.unit_name = "Soldier " + str(i + 1)
		unit.team = "player"
		
		# Assign different classes
		match i:
			0:
				unit.unit_class = "warrior"
				unit.unit_color = Color.BLUE
			1:
				unit.unit_class = "archer"
				unit.unit_color = Color.GREEN
			2:
				unit.unit_class = "assassin"
				unit.unit_color = Color.RED
		
		print("BarracksUI: Unit configured - ", unit.unit_name, " (", unit.unit_class, ")")
		
		# Apply default equipment based on class
		unit.equip_default_loadout()
		print("BarracksUI: Default loadout applied")
		
		# Add to SquadManager - this will assign the unique ID
		var unit_data = SquadManager.unit_to_dictionary(unit)
		var success = SquadManager.add_unit_to_squad(unit_data)
		print("BarracksUI: Added to SquadManager - Success: ", success, " with ID: ", unit.unit_id)
		
		demo_units.append(unit)
	
	print("BarracksUI: Demo units created: ", demo_units.size())
	squad_units = demo_units
	print("BarracksUI: Local squad_units assigned")
	
	is_loading_squad = false  # Re-enable signal handling



func update_squad_display():
	"""Update the squad roster display"""
	print("BarracksUI: Updating squad display")
	
	# Clear existing unit buttons
	var old_button_count = unit_list.get_child_count()
	for child in unit_list.get_children():
		child.queue_free()
	print("BarracksUI: Removed ", old_button_count, " old unit buttons")
	
	# Create button for each unit
	var button_count = 0
	for i in range(squad_units.size()):
		var unit = squad_units[i]
		print("BarracksUI: Creating button for unit: ", unit.unit_name)
		var unit_button = create_unit_button(unit, i)
		unit_list.add_child(unit_button)
		button_count += 1
	
	print("BarracksUI: Created ", button_count, " unit buttons")
	
	# Update squad info
	squad_info_label.text = "Units: %d/%d" % [squad_units.size(), max_squad_size]
	print("BarracksUI: Squad info updated: ", squad_info_label.text)
	
	# Update button states
	add_unit_button.disabled = squad_units.size() >= max_squad_size
	remove_unit_button.disabled = selected_unit == null or squad_units.is_empty()
	print("BarracksUI: Button states updated")


func create_unit_button(unit: Unit, index: int) -> Button:
	"""Create a button for a unit in the squad list"""
	var button = Button.new()
	button.text = "%s (%s)" % [unit.unit_name, unit.unit_class]
	button.custom_minimum_size = Vector2(0, 40)
	
	# Style the button based on unit class
	var style = StyleBoxFlat.new()
	style.bg_color = unit.unit_color.darkened(0.5)
	style.border_width_left = 3
	style.border_color = unit.unit_color
	button.add_theme_stylebox_override("normal", style)
	
	# Connect button press
	button.pressed.connect(func(): _on_unit_selected(unit))
	
	return button

func _on_unit_selected(unit: Unit):
	"""Handle unit selection from squad list"""
	print("BarracksUI: Unit selected: ", unit.unit_name, " (ID: ", unit.unit_id, ")")
	selected_unit = unit
	debug_unit_ids()  # Debug call to see all IDs
	update_unit_details()
	update_squad_display()


func update_unit_details():
	"""Update the unit details panel"""
	if not selected_unit:
		unit_name_label.text = "Select a unit..."
		class_label.text = "Class: -"
		health_label.text = "Health: -"
		speed_label.text = "Speed: -"
		armor_label.text = "Armor: -"
		power_label.text = "Power: -/-"
		clear_equipment_display()
		clear_unit_display()
		return
	
	# Update basic info
	unit_name_label.text = selected_unit.unit_name
	class_label.text = "Class: " + selected_unit.unit_class.capitalize()
	health_label.text = "Health: %d" % selected_unit.max_health
	speed_label.text = "Speed: %d" % selected_unit.movement_range
	armor_label.text = "Armor: %d" % selected_unit.armor
	
	var power_consumption = selected_unit.get_total_power_consumption()
	var power_generation = selected_unit.get_total_power_generation()
	power_label.text = "Power: %d/%d" % [power_consumption, power_generation]
	
	# Color code power display
	if power_consumption > power_generation:
		power_label.modulate = Color.RED
	elif power_consumption == power_generation:
		power_label.modulate = Color.YELLOW
	else:
		power_label.modulate = Color.GREEN
	
	# Update equipment display
	update_equipment_display()
	
	# Update unit display (3D model and WRVSS)
	update_unit_display()


func update_equipment_display():
	"""Update all equipment slot displays"""
	if not selected_unit:
		return
	
	update_equipment_slot("core", selected_unit.core_equipment)
	update_equipment_slot("primary_weapon", selected_unit.primary_weapon)
	update_equipment_slot("sidearm", selected_unit.sidearm)
	update_equipment_slot("armor", selected_unit.armor_equipment)
	update_equipment_slot("reactor", selected_unit.reactor)
	update_equipment_slot("booster", selected_unit.booster)
	update_equipment_slot("sensors", selected_unit.sensors)
	update_equipment_slot("accessory_1", selected_unit.accessory_1)
	update_equipment_slot("accessory_2", selected_unit.accessory_2)

func update_equipment_slot(slot_name: String, equipment: Equipment):
	"""Update a specific equipment slot display"""
	# Map slot names to UI element names
	var slot_mapping = {
		"core": "Core",
		"primary_weapon": "PrimaryWeapon", 
		"sidearm": "Sidearm",
		"armor": "Armor",
		"reactor": "Reactor",
		"booster": "Booster",
		"sensors": "Sensors",
		"accessory_1": "Accessory1",
		"accessory_2": "Accessory2"
	}
	
	var ui_name = slot_mapping.get(slot_name, "")
	if ui_name == "":
		return
	
	# Get UI elements
	var slot_container = equipment_slots_container.get_node_or_null(ui_name + "Slot")
	if not slot_container:
		return
	
	var equipment_label = slot_container.get_node_or_null(ui_name + "EquipmentLabel")
	var change_button = slot_container.get_node_or_null(ui_name + "ChangeButton")
	
	if not equipment_label or not change_button:
		return
	
	# Update display
	if equipment:
		equipment_label.text = equipment.equipment_name
		equipment_label.modulate = Color.WHITE
	else:
		equipment_label.text = "None"
		equipment_label.modulate = Color.GRAY
	
	# Connect button if not already connected
	if not change_button.pressed.is_connected(_on_equipment_change_pressed):
		change_button.pressed.connect(func(): _on_equipment_change_pressed(slot_name))

func clear_equipment_display():
	"""Clear all equipment slot displays"""
	var slot_names = ["core", "primary_weapon", "sidearm", "armor", "reactor", "booster", "sensors", "accessory_1", "accessory_2"]
	for slot_name in slot_names:
		update_equipment_slot(slot_name, null)

func _on_add_unit_pressed():
	"""Handle add unit button press"""
	if SquadManager.is_squad_full():
		return
	
	# Create new unit with dialog for class selection
	var new_unit = Unit.new()
	new_unit.unit_name = "Recruit " + str(SquadManager.get_squad_size() + 1)
	new_unit.team = "player"
	new_unit.unit_class = "warrior"  # Default class
	new_unit.unit_color = Color.BLUE
	
	# Apply default equipment
	new_unit.equip_default_loadout()
	
	# Add to SquadManager
	var unit_data = SquadManager.unit_to_dictionary(new_unit)
	if SquadManager.add_unit_to_squad(unit_data):
		# Reload squad from manager
		load_squad_from_base()
		update_squad_display()
		
		# Auto-select new unit
		_on_unit_selected(squad_units[-1])



func _on_remove_unit_pressed():
	"""Handle remove unit button press"""
	if not selected_unit or squad_units.is_empty():
		return
	
	# Get unit ID for SquadManager
	var unit_id = selected_unit.unit_id
	
	if SquadManager.remove_unit_from_squad(unit_id):
		# Reload squad from manager
		load_squad_from_base()
		selected_unit = null
		update_unit_details()
		update_squad_display()


func _on_edit_name_pressed():
	"""Handle edit name button press"""
	print("BarracksUI: Edit name button pressed")
	
	if not selected_unit:
		return
	
	print("BarracksUI: Selected unit ID before rename: ", selected_unit.unit_id)
	
	# Create simple input dialog for name change
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Unit"
	
	var line_edit = LineEdit.new()
	line_edit.text = selected_unit.unit_name
	line_edit.custom_minimum_size = Vector2(200, 30)
	dialog.add_child(line_edit)
	
	add_child(dialog)
	dialog.popup_centered()
	
	# Handle confirmation
	dialog.confirmed.connect(func():
		var old_name = selected_unit.unit_name
		selected_unit.unit_name = line_edit.text
		print("BarracksUI: Unit name changed from '", old_name, "' to '", selected_unit.unit_name, "'")
		print("BarracksUI: Unit ID during rename: ", selected_unit.unit_id)
		
		# Update SquadManager
		var update_success = SquadManager.update_unit_in_squad(selected_unit)
		print("BarracksUI: SquadManager update result: ", update_success)
		
		update_unit_details()
		update_squad_display()
		dialog.queue_free()
	)
	
	# Handle cancellation
	dialog.canceled.connect(func(): dialog.queue_free())



func _on_focus_unit_pressed():
	"""Handle focus on unit button press"""
	if not selected_unit:
		return
	
	print("Focusing camera on unit: ", selected_unit.unit_name)
	# Here you would tell the camera to focus on the unit's position
	# This requires the unit to be placed in the 3D scene first

func _on_unit_equipment_changed():
	"""Handle when a unit's equipment changes"""
	if selected_unit:
		# Update the unit in SquadManager
		SquadManager.update_unit_in_squad(selected_unit)

func _on_validate_loadout_pressed():
	"""Handle validate loadout button press"""
	if not selected_unit:
		return
	
	var validation = EquipmentManager.validate_loadout(selected_unit)
	show_validation_results(validation)

func show_validation_results(validation: Dictionary):
	"""Show loadout validation results"""
	var dialog = AcceptDialog.new()
	dialog.title = "Loadout Validation"
	
	var label = Label.new()
	var text = ""
	
	if validation.is_valid:
		text += "✓ Loadout is valid!\n\n"
	else:
		text += "✗ Loadout has issues:\n\n"
		for issue in validation.issues:
			text += "• " + issue + "\n"
		text += "\n"
	
	if not validation.warnings.is_empty():
		text += "Warnings:\n"
		for warning in validation.warnings:
			text += "• " + warning + "\n"
	
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 200)
	dialog.add_child(label)
	
	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func(): dialog.queue_free())

func _on_equipment_change_pressed(slot_name: String):
	"""Handle equipment change button press"""
	if not selected_unit or not inventory_manager:
		return
	
	current_equipment_slot = slot_name
	show_equipment_selection_dialog(slot_name)

func show_equipment_selection_dialog(slot_name: String):
	"""Show equipment selection dialog for specified slot"""
	# Check if dialog components exist
	if not equipment_dialog or not dialog_title:
		print("Error: Equipment selection dialog not properly set up")
		print("equipment_dialog exists: ", equipment_dialog != null)
		print("dialog_title exists: ", dialog_title != null)
		return
	
	dialog_title.text = "Choose equipment for %s slot:" % slot_name.replace("_", " ").capitalize()
	
	# Load available equipment from inventory
	load_available_equipment(slot_name)
	filter_equipment_list()
	
	# Clear previous selection
	selected_equipment_name = ""
	if confirm_button:
		confirm_button.disabled = true
	
	# Show dialog
	equipment_dialog.popup_centered()

func load_available_equipment(slot_name: String):
	"""Load equipment available in inventory for the specified slot"""
	available_equipment.clear()
	
	# Debug output
	print("Loading equipment for slot: ", slot_name)
	print("Inventory manager exists: ", inventory_manager != null)
	
	if not inventory_manager:
		print("Error: No inventory manager available")
		return
	
	# Add "None" option to remove equipment
	available_equipment.append({
		"name": "",
		"display_name": "None (Remove Equipment)",
		"equipment": null,
		"quantity": 1
	})
	
	# Get all equipment from inventory
	var inventory_items = inventory_manager.get_all_equipment()
	print("Inventory items found: ", inventory_items.size())
	
	for equipment_name in inventory_items.keys():
		var quantity = inventory_items[equipment_name]
		if quantity <= 0:
			continue
		
		print("Checking equipment: ", equipment_name, " (quantity: ", quantity, ")")
		
		var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
		if not equipment:
			print("Warning: Could not create equipment: ", equipment_name)
			continue
		
		# Check if equipment can fit in this slot
		var can_fit = can_equipment_fit_slot(equipment, slot_name)
		print("Can ", equipment_name, " fit in ", slot_name, "? ", can_fit)
		
		if can_fit:
			available_equipment.append({
				"name": equipment_name,
				"display_name": equipment.equipment_name,
				"equipment": equipment,
				"quantity": quantity
			})
	
	print("Total available equipment for slot: ", available_equipment.size())

func can_equipment_fit_slot(equipment: Equipment, slot_name: String) -> bool:
	"""Check if equipment can be equipped in the specified slot"""
	match slot_name:
		"core":
			return equipment is Core
		"primary_weapon", "sidearm":
			return equipment is Weapon
		"armor":
			return equipment is ArmorEquipment
		"reactor":
			return equipment is Reactor
		"booster":
			return equipment is Booster
		"sensors":
			return equipment is Sensor
		"accessory_1", "accessory_2":
			return equipment is Accessory
		_:
			return false

func filter_equipment_list():
	"""Filter equipment list based on search and category"""
	filtered_equipment.clear()
	
	# Get search text, but ignore placeholder text
	var search_text = ""
	if search_field and search_field.text != "" and search_field.text != search_field.placeholder_text:
		search_text = search_field.text.to_lower()
	
	var filter_index = filter_dropdown.selected if filter_dropdown else 0
	
	print("Filtering equipment - search: '", search_text, "', filter index: ", filter_index)
	print("Available equipment to filter: ", available_equipment.size())
	
	for item in available_equipment:
		# Apply search filter
		if search_text != "" and not item.display_name.to_lower().contains(search_text):
			print("Filtered out by search: ", item.display_name)
			continue
		
		# Apply category filter
		if filter_index > 0 and item.equipment:  # 0 = "All Equipment"
			var equipment = item.equipment
			var matches_filter = false
			
			match filter_index:
				1:  # Weapons
					matches_filter = equipment is Weapon
				2:  # Armor
					matches_filter = equipment is ArmorEquipment
				3:  # Cores
					matches_filter = equipment is Core
				4:  # Accessories
					matches_filter = equipment is Accessory
				5:  # Other
					matches_filter = not (equipment is Weapon or equipment is ArmorEquipment or equipment is Core or equipment is Accessory)
			
			if not matches_filter:
				print("Filtered out by category: ", item.display_name)
				continue
		
		filtered_equipment.append(item)
		print("Added to filtered list: ", item.display_name)
	
	print("Final filtered equipment count: ", filtered_equipment.size())
	update_equipment_list_display()

func update_equipment_list_display():
	"""Update the equipment list display in the dialog"""
	# Clear existing buttons
	for child in equipment_list.get_children():
		child.queue_free()
	
	# Create button for each filtered item
	for item in filtered_equipment:
		var button = create_equipment_button(item)
		equipment_list.add_child(button)

func create_equipment_button(item: Dictionary) -> Button:
	"""Create a button for an equipment item"""
	var button = Button.new()
	var display_text = item.display_name
	
	if item.quantity > 1:
		display_text += " (%d)" % item.quantity
	
	button.text = display_text
	button.custom_minimum_size = Vector2(0, 40)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# Style button based on equipment type
	if item.equipment:
		var style = StyleBoxFlat.new()
		style.bg_color = get_equipment_color(item.equipment).darkened(0.7)
		style.border_width_left = 3
		style.border_color = get_equipment_color(item.equipment)
		button.add_theme_stylebox_override("normal", style)
	
	# Connect selection
	button.pressed.connect(func(): _on_equipment_item_selected(item))
	
	return button

func get_equipment_color(equipment: Equipment) -> Color:
	"""Get color for equipment type"""
	if equipment is Weapon:
		return Color.RED
	elif equipment is ArmorEquipment:
		return Color.BLUE
	elif equipment is Core:
		return Color.GOLD
	elif equipment is Reactor:
		return Color.ORANGE
	elif equipment is Booster:
		return Color.GREEN
	elif equipment is Sensor:
		return Color.CYAN
	elif equipment is Accessory:
		return Color.MAGENTA
	else:
		return Color.GRAY

func _on_equipment_item_selected(item: Dictionary):
	"""Handle equipment item selection"""
	selected_equipment_name = item.name
	confirm_button.disabled = false
	
	# Highlight selected button (simple approach)
	update_equipment_list_display()

func _on_equipment_search_changed(new_text: String):
	"""Handle search field text change"""
	filter_equipment_list()

func _on_equipment_filter_changed(index: int):
	"""Handle filter dropdown change"""
	filter_equipment_list()

func _on_equipment_confirm_pressed():
	"""Handle equipment confirmation"""
	print("BarracksUI: Equipment confirm pressed")
	
	if not selected_unit:
		equipment_dialog.hide()
		return
	
	print("BarracksUI: Selected unit ID before equipment change: ", selected_unit.unit_id)
	
	# Get currently equipped item to return to inventory
	var current_equipment = selected_unit.get_equipment_in_slot(current_equipment_slot)
	var current_equipment_name = ""
	if current_equipment:
		# Find the equipment name by checking all possible equipment
		for equipment_name in EquipmentManager.get_all_equipment_names():
			var test_equipment = EquipmentManager.create_equipment_by_name(equipment_name)
			if test_equipment and test_equipment.equipment_name == current_equipment.equipment_name:
				current_equipment_name = equipment_name
				break
	
	print("BarracksUI: Current equipment: ", current_equipment_name if current_equipment_name != "" else "None")
	print("BarracksUI: Selected new equipment: ", selected_equipment_name if selected_equipment_name != "" else "None")
	
	# Handle equipment change
	var equipment_changed = false
	
	if selected_equipment_name == "":  # Remove equipment
		if current_equipment:
			print("BarracksUI: Removing equipment from slot: ", current_equipment_slot)
			# Return to inventory
			inventory_manager.add_equipment(current_equipment_name, 1)
			# Remove from unit
			var result = selected_unit.remove_equipment_from_slot(current_equipment_slot)
			if result.success:
				equipment_changed = true
				print("BarracksUI: Equipment removed successfully")
			else:
				print("BarracksUI: Failed to remove equipment: ", result.message)
	else:
		# Check if we have the equipment in inventory
		if not inventory_manager.has_equipment(selected_equipment_name, 1):
			print("BarracksUI: Error - Equipment not in inventory: ", selected_equipment_name)
			equipment_dialog.hide()
			return
		
		print("BarracksUI: Equipping new equipment: ", selected_equipment_name)
		
		# Create and equip new equipment
		var new_equipment = EquipmentManager.create_equipment_by_name(selected_equipment_name)
		if new_equipment:
			var result = selected_unit.equip_item(new_equipment, current_equipment_slot)
			if result.success:
				# Remove from inventory
				inventory_manager.remove_equipment(selected_equipment_name, 1)
				# Return old equipment to inventory if any
				if current_equipment and current_equipment_name != "":
					inventory_manager.add_equipment(current_equipment_name, 1)
				equipment_changed = true
				print("BarracksUI: Equipment equipped successfully")
			else:
				print("BarracksUI: Failed to equip equipment: ", result.message)
	
	# Update SquadManager if equipment changed
	if equipment_changed:
		print("BarracksUI: Updating unit in SquadManager due to equipment change")
		print("BarracksUI: Unit ID during equipment update: ", selected_unit.unit_id)
		var update_success = SquadManager.update_unit_in_squad(selected_unit)
		print("BarracksUI: SquadManager update result: ", update_success)
	
	# Update displays
	update_unit_details()
	equipment_dialog.hide()



func _on_equipment_cancel_pressed():
	"""Handle equipment dialog cancellation"""
	equipment_dialog.hide()

func _on_close_pressed():
	"""Handle close button press"""
	visible = false
	room_closed.emit()

func _on_inventory_changed():
	"""Handle inventory changes to refresh equipment lists"""
	if equipment_dialog.visible and current_equipment_slot != "":
		load_available_equipment(current_equipment_slot)
		filter_equipment_list()

# Camera integration methods
func focus_on_unit_in_3d(unit: Unit):
	"""Focus camera on unit in 3D scene (when units are placed in base)"""
	if not camera_controller or not unit:
		return
	
	# This would require the unit to exist in the base 3D scene
	# For now, just print debug info
	print("Would focus camera on unit at position: ", unit.position)
	
	# Future implementation:
	# camera_controller.move_to_position(unit.position + Vector3(2, 2, 2), Vector3(-20, 45, 0))

func get_squad_units() -> Array[Unit]:
	"""Get current squad units for external systems"""
	return SquadManager.get_squad_unit_objects()


func save_squad_data() -> Dictionary:
	"""Save squad data for persistence (now handled by SquadManager)"""
	return SquadManager.save_squad_data()


func load_squad_data(data: Dictionary):
	"""Load squad data from save (now handled by SquadManager)"""
	SquadManager.load_squad_data(data)
	load_squad_from_base()
	update_squad_display()


func _on_squad_changed():
	"""Handle squad changes from SquadManager"""
	print("BarracksUI: Received squad_changed signal from SquadManager")
	
	# Only reload if we're currently visible
	if visible and not is_loading_squad:
		print("BarracksUI: UI is visible, reloading squad")
		load_squad_from_base()
		update_squad_display()
		
		# Clear selection if unit no longer exists
		if selected_unit:
			var unit_still_exists = false
			for unit in squad_units:
				if unit.unit_id == selected_unit.unit_id:
					unit_still_exists = true
					# Update selected_unit reference to new object
					selected_unit = unit
					break
			
			if not unit_still_exists:
				print("BarracksUI: Selected unit no longer exists, clearing selection")
				selected_unit = null
				update_unit_details()
	else:
		print("BarracksUI: UI not visible or loading, skipping reload")

func test_squad_manager_connection():
	"""Test SquadManager connectivity"""
	print("BarracksUI: Testing SquadManager connection")
	
	if SquadManager:
		print("BarracksUI: SquadManager exists")
		print("BarracksUI: Current squad size in manager: ", SquadManager.get_squad_size())
		print("BarracksUI: Squad is full: ", SquadManager.is_squad_full())
		
		var squad_data = SquadManager.get_squad_units()
		print("BarracksUI: Squad data from manager: ", squad_data.size(), " units")
		for unit_data in squad_data:
			print("  - ", unit_data.get("unit_name", "Unknown"), " (ID: ", unit_data.get("unit_id", -1), ")")
	else:
		print("BarracksUI: ERROR - SquadManager not found!")


func debug_unit_ids():
	"""Debug method to check all unit IDs"""
	print("BarracksUI: === UNIT ID DEBUG ===")
	print("Local squad_units array:")
	for i in range(squad_units.size()):
		var unit = squad_units[i]
		print("  Index ", i, ": ", unit.unit_name, " (ID: ", unit.unit_id, ")")
	
	print("SquadManager stored units:")
	var stored_units = SquadManager.get_squad_units()
	for i in range(stored_units.size()):
		var unit_data = stored_units[i]
		print("  Index ", i, ": ", unit_data.get("unit_name", "Unknown"), " (ID: ", unit_data.get("unit_id", -1), ")")
	print("========================")


func update_unit_display():
	"""Update the unit display panel (3D model, WRVSS, relationships)"""
	if not selected_unit:
		clear_unit_display()
		return
	
	# Update 3D model
	update_unit_3d_model()
	
	# Update WRVSS stats
	update_wrvss_display()
	
	# Update relationships (placeholder for now)
	update_relationships_display()

func update_unit_3d_model():
	"""Update the 3D model representation of the unit"""
	if not unit_mesh or not selected_unit:
		return
	
	# Create or update the mesh material based on unit
	var material = StandardMaterial3D.new()
	material.albedo_color = selected_unit.unit_color
	
	# Add some visual variation based on class
	match selected_unit.unit_class:
		"warrior":
			material.metallic = 0.3
			material.roughness = 0.7
		"archer":
			material.metallic = 0.1
			material.roughness = 0.5
		"assassin":
			material.albedo_color = material.albedo_color.darkened(0.2)
			material.metallic = 0.0
			material.roughness = 0.8
		_:
			material.metallic = 0.2
			material.roughness = 0.6
	
	unit_mesh.material_override = material
	
	print("BarracksUI: Updated 3D model for ", selected_unit.unit_name, " (", selected_unit.unit_class, ")")

func update_wrvss_display():
	"""Update the WRVSS stats display"""
	if not selected_unit:
		return
	
	# Update WRVSS values
	if wisdom_value:
		wisdom_value.text = str(selected_unit.wisdom)
	if rage_value:
		rage_value.text = str(selected_unit.rage)
	if virtue_value:
		virtue_value.text = str(selected_unit.virtue)
	if strength_value:
		strength_value.text = str(selected_unit.strength)
	if steel_value:
		steel_value.text = str(selected_unit.steel)
	
	print("BarracksUI: Updated WRVSS stats for ", selected_unit.unit_name)

func update_relationships_display():
	"""Update the relationships display (placeholder for future features)"""
	if not relationships_list or not selected_unit:
		return
	
	# Clear existing relationships
	for child in relationships_list.get_children():
		child.queue_free()
	
	# For now, just show a placeholder message
	var placeholder_label = Label.new()
	placeholder_label.text = "No relationships yet"
	placeholder_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	relationships_list.add_child(placeholder_label)
	
	# Future: Add relationship entries here
	# create_relationship_entry("Soldier 1", "Trusted", 0.8)
	# create_relationship_entry("Soldier 2", "Rival", -0.3)
	
func clear_unit_display():
	"""Clear the unit display panel"""
	# Reset 3D model to default
	if unit_mesh:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.GRAY
		unit_mesh.material_override = material
	
	# Clear WRVSS stats
	if wisdom_value: wisdom_value.text = "-"
	if rage_value: rage_value.text = "-"
	if virtue_value: virtue_value.text = "-"
	if strength_value: strength_value.text = "-"
	if steel_value: steel_value.text = "-"
	
	# Clear relationships
	if relationships_list:
		for child in relationships_list.get_children():
			child.queue_free()

# Future method for creating relationship entries:
func create_relationship_entry(unit_name: String, relationship_type: String, value: float):
	"""Create a relationship entry (for future use)"""
	var container = HBoxContainer.new()
	
	var name_label = Label.new()
	name_label.text = unit_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var type_label = Label.new()
	type_label.text = relationship_type
	type_label.custom_minimum_size.x = 60
	
	# Color based on relationship value
	if value > 0.5:
		type_label.add_theme_color_override("font_color", Color.GREEN)
	elif value < -0.5:
		type_label.add_theme_color_override("font_color", Color.RED)
	else:
		type_label.add_theme_color_override("font_color", Color.YELLOW)
	
	container.add_child(name_label)
	container.add_child(type_label)
	
	if relationships_list:
		relationships_list.add_child(container)
