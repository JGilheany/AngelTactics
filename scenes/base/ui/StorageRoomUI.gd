# StorageRoomUI.gd - Simplified version for scene-based UI
extends Control

# UI References - connected to scene nodes
@onready var room_panel = $RoomPanel
@onready var npc_name_label = $RoomPanel/MainContainer/ContentContainer/NPCPanel/NPCContainer/NPCNameLabel
@onready var npc_portrait = $RoomPanel/MainContainer/ContentContainer/NPCPanel/NPCContainer/NPCPortrait
@onready var dialogue_label = $RoomPanel/MainContainer/ContentContainer/NPCPanel/NPCContainer/DialogueLabel

@onready var money_label = $RoomPanel/MainContainer/ContentContainer/InventoryPanel/InventoryContainer/MoneyLabel
@onready var category_tabs = $RoomPanel/MainContainer/ContentContainer/InventoryPanel/InventoryContainer/CategoryTabs
@onready var search_field = $RoomPanel/MainContainer/ContentContainer/InventoryPanel/InventoryContainer/ControlsContainer/SearchField
@onready var sort_dropdown = $RoomPanel/MainContainer/ContentContainer/InventoryPanel/InventoryContainer/ControlsContainer/SortDropdown
@onready var inventory_list = $RoomPanel/MainContainer/ContentContainer/InventoryPanel/InventoryContainer/ScrollContainer/InventoryList

# These will be found using find_child() in _ready()
var actions_panel: HBoxContainer
var close_button: Button


# References
var base_scene: Node3D
var camera_controller: Node3D
var inventory_manager: InventoryManager
var storage_npc: BaseNPC

# State tracking
var is_initialized: bool = false

# Current state
var current_category: String = "all"
var current_sort_mode: String = "name"
var search_text: String = ""
var selected_equipment: String = ""

signal room_closed

func _ready():
	
		# Find nodes that couldn't be found with @onready paths
	actions_panel = find_child("ActionsPanel")
	close_button = find_child("CloseButton")
	
	if not actions_panel:
		print("Warning: ActionsPanel not found")
	if not close_button:
		print("Warning: CloseButton not found")
		
		
	# Connect UI signals
	connect_ui_signals()
	
	# Setup UI elements that don't need external references
	setup_category_tabs()
	setup_sort_dropdown()
	
	# Initially hidden
	visible = false
	
	# Note: Don't try to get external references here
	# They will be provided via initialize() method

func initialize(base_scene_ref: Node3D, camera_ref: Node3D, inventory_ref: InventoryManager):
	"""Initialize with external references - called by BaseScene"""
	base_scene = base_scene_ref
	camera_controller = camera_ref
	inventory_manager = inventory_ref
	is_initialized = true
	
	# Connect inventory signals
	if inventory_manager:
		# Disconnect any existing connections to avoid duplicates
		if inventory_manager.inventory_changed.is_connected(_on_inventory_changed):
			inventory_manager.inventory_changed.disconnect(_on_inventory_changed)
		if inventory_manager.money_changed.is_connected(_on_money_changed):
			inventory_manager.money_changed.disconnect(_on_money_changed)
		
		# Connect signals
		inventory_manager.inventory_changed.connect(_on_inventory_changed)
		inventory_manager.money_changed.connect(_on_money_changed)
	
	# Update display now that we have inventory manager
	update_display()
	
	print("StorageRoomUI initialized successfully")

func connect_ui_signals():
	"""Connect UI element signals"""
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	if search_field:
		search_field.text_changed.connect(_on_search_text_changed)
	
	if sort_dropdown:
		sort_dropdown.item_selected.connect(_on_sort_changed)

# Remove the old get_inventory_manager function since we now get it via initialize()
# func get_inventory_manager() -> InventoryManager: ← DELETE THIS ENTIRE FUNCTION

func setup_category_tabs():
	"""Setup category filter tabs"""
	if not category_tabs:
		return
	
	# Clear existing tabs
	for child in category_tabs.get_children():
		child.queue_free()
	
	var categories = ["All", "Weapons", "Armor", "Cores", "Accessories", "Other"]
	var button_group = ButtonGroup.new()
	
	for i in range(categories.size()):
		var category = categories[i]
		var button = Button.new()
		button.text = category
		button.toggle_mode = true
		button.button_group = button_group
		button.pressed.connect(_on_category_selected.bind(category.to_lower()))
		category_tabs.add_child(button)
		
		if category == "All":
			button.button_pressed = true

func setup_sort_dropdown():
	"""Setup sort dropdown options"""
	if not sort_dropdown:
		return
	
	sort_dropdown.clear()
	sort_dropdown.add_item("Name")
	sort_dropdown.add_item("Quantity") 
	sort_dropdown.add_item("Value")
	sort_dropdown.add_item("Type")

func show_storage_room(npc_node: BaseNPC = null):
	"""Show the storage room UI and focus on NPC"""
	storage_npc = npc_node
	visible = true
	
	# Make sure we're initialized
	if not is_initialized:
		print("Warning: StorageRoomUI not properly initialized!")
		return
	
	# Update NPC info
	update_npc_display()
	
	# Focus camera on NPC if available
	if camera_controller and storage_npc:
		focus_camera_on_npc()
	
	# Update inventory display
	update_display()
	
	# Connect to NPC dialogue changes
	if storage_npc:
		if not storage_npc.dialogue_changed.is_connected(_on_npc_dialogue_changed):
			storage_npc.dialogue_changed.connect(_on_npc_dialogue_changed)

func focus_camera_on_npc():
	"""Focus camera on the storage NPC"""
	if not camera_controller or not storage_npc:
		return
	
	# Get NPC position and create camera target
	var npc_pos = storage_npc.global_position
	var camera_offset = Vector3(2, 1, 2)  # Offset for good viewing angle
	var target_pos = npc_pos + camera_offset
	var target_rot = Vector3(-15, 45, 0)
	
	if camera_controller.has_method("move_to_position"):
		camera_controller.move_to_position(target_pos, target_rot)

func update_npc_display():
	"""Update NPC information display"""
	if not storage_npc:
		return
	
	var npc_data = storage_npc.get_npc_data()
	
	if npc_name_label:
		npc_name_label.text = npc_data.name + " - " + npc_data.role
	
	if dialogue_label:
		dialogue_label.text = npc_data.dialogue
	
	# Update portrait color to match NPC
	if npc_portrait:
		var style = StyleBoxFlat.new()
		style.bg_color = npc_data.get("color", Color.ORANGE)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		npc_portrait.add_theme_stylebox_override("panel", style)

func _on_npc_dialogue_changed(new_dialogue: String):
	"""Handle NPC dialogue changes"""
	if dialogue_label:
		dialogue_label.text = new_dialogue

func update_display():
	"""Update the entire inventory display"""
	update_money_display()
	update_inventory_list()

func update_money_display():
	"""Update money/credits display"""
	if money_label and inventory_manager:
		money_label.text = "Credits: " + str(inventory_manager.get_money())

func update_inventory_list():
	"""Update the inventory list based on current filters"""
	if not inventory_list or not inventory_manager:
		return
	
	# Clear existing items
	for child in inventory_list.get_children():
		child.queue_free()
	
	# Get filtered and sorted equipment
	var equipment_data = get_filtered_equipment()
	
	# Create UI elements for each item
	for item_data in equipment_data:
		create_inventory_item_ui(item_data)

func get_filtered_equipment() -> Array:
	"""Get equipment filtered by category and search, then sorted"""
	var all_equipment = inventory_manager.get_all_equipment()
	var filtered_equipment = []
	
	# Filter by category and search
	for equipment_name in all_equipment.keys():
		var quantity = all_equipment[equipment_name]
		var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
		
		if not equipment:
			continue
		
		# Category filter
		if current_category != "all":
			var equipment_category = get_equipment_category(equipment)
			if equipment_category != current_category:
				continue
		
		# Search filter
		if search_text != "" and not equipment_name.to_lower().contains(search_text.to_lower()):
			continue
		
		filtered_equipment.append({
			"name": equipment_name,
			"quantity": quantity,
			"equipment": equipment,
			"value": equipment.cost * quantity
		})
	
	# Sort equipment
	filtered_equipment.sort_custom(_compare_equipment)
	
	return filtered_equipment

func get_equipment_category(equipment) -> String:
	"""Determine equipment category"""
	if equipment is Weapon:
		return "weapons"
	elif equipment.has_method("has_tag"):
		if equipment.has_tag("armor"):
			return "armor"
		elif equipment.has_tag("core"):
			return "cores"
		elif equipment.has_tag("accessory"):
			return "accessories"
	
	# Fallback: check equipment name patterns
	var _name = equipment.equipment_name.to_lower()
	if "armor" in name:
		return "armor"
	elif "core" in name:
		return "cores"
	elif "booster" in name or "sensor" in name or "reactor" in name or "accessory" in name:
		return "accessories"
	
	return "other"

func _compare_equipment(a: Dictionary, b: Dictionary) -> bool:
	"""Compare function for sorting equipment"""
	match current_sort_mode:
		"name":
			return a.name < b.name
		"quantity":
			return a.quantity > b.quantity
		"value":
			return a.value > b.value
		"type":
			var a_category = get_equipment_category(a.equipment)
			var b_category = get_equipment_category(b.equipment)
			if a_category == b_category:
				return a.name < b.name
			return a_category < b_category
		_:
			return a.name < b.name

func create_inventory_item_ui(item_data: Dictionary):
	"""Create UI for a single inventory item"""
	var item_panel = Panel.new()
	item_panel.custom_minimum_size.y = 80  # Slightly taller for more buttons
	
	# Create item background style
	var item_style = StyleBoxFlat.new()
	item_style.bg_color = Color(0.15, 0.15, 0.15)
	item_style.border_width_left = 1
	item_style.border_width_top = 1
	item_style.border_width_right = 1
	item_style.border_width_bottom = 1
	item_style.border_color = Color(0.3, 0.3, 0.3)
	item_style.corner_radius_top_left = 4
	item_style.corner_radius_top_right = 4
	item_style.corner_radius_bottom_left = 4
	item_style.corner_radius_bottom_right = 4
	item_panel.add_theme_stylebox_override("panel", item_style)
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 10)
	margin_container.add_theme_constant_override("margin_right", 10)
	margin_container.add_theme_constant_override("margin_top", 5)
	margin_container.add_theme_constant_override("margin_bottom", 5)
	item_panel.add_child(margin_container)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	margin_container.add_child(hbox)
	
	# Item icon (colored rectangle)
	var icon = Panel.new()
	icon.custom_minimum_size = Vector2(60, 60)
	var icon_color = get_equipment_color(item_data.equipment)
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = icon_color
	icon_style.corner_radius_top_left = 4
	icon_style.corner_radius_top_right = 4
	icon_style.corner_radius_bottom_left = 4
	icon_style.corner_radius_bottom_right = 4
	icon.add_theme_stylebox_override("panel", icon_style)
	hbox.add_child(icon)
	
	# Item info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_label = Label.new()
	name_label.text = item_data.name.capitalize().replace("_", " ")
	name_label.add_theme_font_size_override("font_size", 14)
	info_vbox.add_child(name_label)
	
	var details_label = Label.new()
	var equipment = item_data.equipment
	var details_text = "Qty: %d | Unit Value: %d | Total: %d credits" % [item_data.quantity, equipment.cost, item_data.value]
	details_label.text = details_text
	details_label.add_theme_font_size_override("font_size", 10)
	details_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	info_vbox.add_child(details_label)
	
	# Equipment description if available
	if equipment.has_method("get_description") and equipment.get_description() != "":
		var desc_label = Label.new()
		desc_label.text = equipment.get_description()
		desc_label.add_theme_font_size_override("font_size", 9)
		desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_label)
	
	# Action buttons
	var actions_vbox = VBoxContainer.new()
	actions_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(actions_vbox)
	
	var inspect_button = Button.new()
	inspect_button.text = "Inspect"
	inspect_button.custom_minimum_size = Vector2(80, 25)
	inspect_button.pressed.connect(_on_inspect_item.bind(item_data.name))
	actions_vbox.add_child(inspect_button)
	
	var sell_button = Button.new()
	sell_button.text = "Sell (1)"
	sell_button.custom_minimum_size = Vector2(80, 25)
	var sell_value = inventory_manager.get_sell_value(item_data.name, 1)
	sell_button.tooltip_text = "Sell 1 for %d credits" % sell_value
	sell_button.pressed.connect(_on_sell_item.bind(item_data.name, 1))
	actions_vbox.add_child(sell_button)
	
	# Add sell all button if quantity > 1
	if item_data.quantity > 1:
		var sell_all_button = Button.new()
		sell_all_button.text = "Sell All"
		sell_all_button.custom_minimum_size = Vector2(80, 25)
		var sell_all_value = inventory_manager.get_sell_value(item_data.name, item_data.quantity)
		sell_all_button.tooltip_text = "Sell all %d for %d credits" % [item_data.quantity, sell_all_value]
		sell_all_button.pressed.connect(_on_sell_item.bind(item_data.name, item_data.quantity))
		actions_vbox.add_child(sell_all_button)
	
	# Add to inventory list
	inventory_list.add_child(item_panel)

func get_equipment_color(equipment) -> Color:
	"""Get color based on equipment type"""
	if equipment is Weapon:
		return Color.ORANGE_RED
	elif equipment.has_tag("armor"):
		return Color.STEEL_BLUE
	elif equipment.has_tag("core"):
		return Color.GOLD
	elif equipment.has_tag("accessory"):
		return Color.LIME_GREEN
	else:
		return Color.GRAY

# Signal handlers
func _on_close_button_pressed():
	"""Close the storage room"""
	visible = false
	
	# Return camera to room overview
	if camera_controller and camera_controller.has_method("focus_on_room"):
		camera_controller.focus_on_room("storage")
	
	room_closed.emit()

func _on_category_selected(category: String):
	"""Handle category tab selection"""
	current_category = category
	update_inventory_list()

func _on_search_text_changed(new_text: String):
	"""Handle search text change"""
	search_text = new_text
	update_inventory_list()

func _on_sort_changed(index: int):
	"""Handle sort dropdown change"""
	match index:
		0: current_sort_mode = "name"
		1: current_sort_mode = "quantity"
		2: current_sort_mode = "value"
		3: current_sort_mode = "type"
	
	update_inventory_list()

func _on_inspect_item(equipment_name: String):
	"""Handle item inspection"""
	selected_equipment = equipment_name
	
	# Get specific dialogue from storage keeper if it's a StorageKeeperNPC
	if storage_npc and storage_npc is StorageKeeperNPC:
		var storage_keeper = storage_npc as StorageKeeperNPC
		var item_dialogue = storage_keeper.get_item_specific_dialogue(equipment_name)
		if dialogue_label:
			dialogue_label.text = item_dialogue
	else:
		# Cycle dialogue for generic NPCs
		if storage_npc:
			storage_npc.cycle_dialogue()

func _on_sell_item(equipment_name: String, quantity: int):
	"""Handle selling equipment"""
	if not inventory_manager:
		return
	
	# Check if we have enough to sell
	if not inventory_manager.has_equipment(equipment_name, quantity):
		if storage_npc and storage_npc is StorageKeeperNPC:
			var _storage_keeper = storage_npc as StorageKeeperNPC
			if dialogue_label:
				dialogue_label.text = "You don't have enough " + equipment_name.replace("_", " ") + " to sell."
		return
	
	# Calculate sell value
	var sell_value = inventory_manager.get_sell_value(equipment_name, quantity)
	
	# Perform the sale
	var success = inventory_manager.sell_equipment(equipment_name, quantity)
	
	if success:
		# Update NPC dialogue
		if storage_npc and storage_npc is StorageKeeperNPC:
			var _storage_keeper = storage_npc as StorageKeeperNPC
			var response_dialogues = [
				"Sold %d %s for %d credits. Fair price." % [quantity, equipment_name.replace("_", " "), sell_value],
				"Transaction complete. %d credits added to your account." % sell_value,
				"Good choice. That equipment will find a new home." % [],
				"Sale processed. Your current balance is %d credits." % inventory_manager.get_money()
			]
			if dialogue_label:
				dialogue_label.text = response_dialogues[randi() % response_dialogues.size()]
		
		# Inventory will update automatically via signal
		print("Sold %d %s for %d credits" % [quantity, equipment_name, sell_value])
	else:
		print("Failed to sell equipment")

func _on_use_item(equipment_name: String):
	"""Handle using/consuming equipment (for future implementation)"""
	# This could be used for consumables, repair kits, etc.
	print("Use item functionality not yet implemented for: ", equipment_name)

func show_item_comparison(equipment_name: String):
	"""Show comparison with similar equipment (for future implementation)"""
	var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
	if not equipment:
		return
	
	# This could show stats comparison with other similar items
	print("Item comparison not yet implemented for: ", equipment_name)

# Inventory manager event handlers
func _on_inventory_changed():
	"""Handle inventory change"""
	update_display()

func _on_money_changed(_old_amount: int, _new_amount: int):
	"""Handle money change"""
	update_money_display()
