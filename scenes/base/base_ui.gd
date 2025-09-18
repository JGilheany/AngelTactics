# BaseUI.gd - UI controller for the base scene
extends Control

@onready var room_info_panel = $RoomInfoPanel
@onready var room_name_label = $RoomInfoPanel/VBoxContainer/RoomNameLabel
@onready var room_description_label = $RoomInfoPanel/VBoxContainer/RoomDescriptionLabel
@onready var interact_button = $RoomInfoPanel/VBoxContainer/InteractButton
@onready var navigation_panel = $NavigationPanel
@onready var back_button = $NavigationPanel/VBoxContainer/BackButton

var base_scene: Node3D
var current_room: String = ""

var room_descriptions = {
	"central_hub": {
		"name": "Central Hub",
		"description": "The heart of your underground base. All tunnels connect through here."
	},
	"command_center": {
		"name": "Command Center", 
		"description": "Mission planning and strategic overview. Plan your next moves here."
	},
	"barracks": {
		"name": "Barracks",
		"description": "Living quarters and unit management. Train and organize your team."
	},
	"workshop": {
		"name": "Workshop",
		"description": "Equipment crafting and modification station. Upgrade your gear."
	},
	"storage": {
		"name": "Storage Bay",
		"description": "Inventory and resource management. Store your equipment and supplies."
	},
	"medical": {
		"name": "Medical Bay",
		"description": "Unit recovery and medical research. Heal wounded team members."
	},
	"research": {
		"name": "Research Lab",
		"description": "Technology development and analysis. Unlock new capabilities."
	},
	"communications": {
		"name": "Communications",
		"description": "Intel gathering and external communications. Monitor the outside world."
	},
	"recreation": {
		"name": "Recreation",
		"description": "Spending downtime together."
	}
}

func _ready():
	# Get reference to base scene
	base_scene = get_node("../..")
	
	# Setup UI panels
	setup_navigation_panel()
	setup_room_info_panel()
	
	# Connect signals
	connect_ui_signals()

func connect_ui_signals():
	"""Connect UI element signals"""
	if interact_button and not interact_button.pressed.is_connected(_on_interact_button_pressed):
		interact_button.pressed.connect(_on_interact_button_pressed)
	
	if back_button and not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)

func setup_room_info_panel():
	"""Setup room information display"""
	if not room_info_panel:
		# Create room info panel if it doesn't exist
		room_info_panel = Panel.new()
		room_info_panel.name = "RoomInfoPanel"
		room_info_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		room_info_panel.size = Vector2(300, 150)
		room_info_panel.position = Vector2(-320, 20)
		add_child(room_info_panel)
		
		var vbox = VBoxContainer.new()
		room_info_panel.add_child(vbox)
		
		room_name_label = Label.new()
		room_name_label.name = "RoomNameLabel"
		room_name_label.add_theme_font_size_override("font_size", 18)
		room_name_label.text = "Select a Room"
		vbox.add_child(room_name_label)
		
		room_description_label = Label.new()
		room_description_label.name = "RoomDescriptionLabel"
		room_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		room_description_label.text = "Click on a room or use number keys 1-8"
		vbox.add_child(room_description_label)
		
		interact_button = Button.new()
		interact_button.name = "InteractButton"
		interact_button.text = "Enter Room"
		interact_button.visible = false
		vbox.add_child(interact_button)
	
	if room_info_panel:
		room_info_panel.visible = true

func setup_navigation_panel():
	"""Create room navigation buttons"""
	if not navigation_panel:
		# Create navigation panel if it doesn't exist
		navigation_panel = Panel.new()
		navigation_panel.name = "NavigationPanel"
		navigation_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		navigation_panel.size = Vector2(250, 300)
		navigation_panel.position = Vector2(20, 20)
		add_child(navigation_panel)
		
		var main_vbox = VBoxContainer.new()
		navigation_panel.add_child(main_vbox)
		
		var title_label = Label.new()
		title_label.text = "Base Navigation"
		title_label.add_theme_font_size_override("font_size", 16)
		main_vbox.add_child(title_label)
		
		back_button = Button.new()
		back_button.name = "BackButton"
		back_button.text = "Return to Map"
		main_vbox.add_child(back_button)
		
		var button_container = VBoxContainer.new()
		main_vbox.add_child(button_container)
		
		# Create room buttons
		var room_keys = ["central_hub", "command_center", "barracks", "workshop", 
						"storage", "medical", "research", "communications", "recreation"]
		
		for i in range(room_keys.size()):
			var room_key = room_keys[i]
			var button = Button.new()
			button.text = "%d. %s" % [i + 1, room_descriptions[room_key].name]
			button.pressed.connect(_on_room_button_pressed.bind(room_key))
			button_container.add_child(button)

func update_room_info(room_name: String):
	"""Update the room information display"""
	current_room = room_name
	
	if not room_descriptions.has(room_name):
		print("Warning: No description for room: ", room_name)
		return
	
	var room_data = room_descriptions[room_name]
	
	if room_name_label:
		room_name_label.text = room_data.name
	
	if room_description_label:
		room_description_label.text = room_data.description
	
	if interact_button:
		interact_button.text = "Enter " + room_data.name
		interact_button.visible = true

func _on_room_button_pressed(room_name: String):
	"""Handle room navigation button presses"""
	if base_scene and base_scene.has_method("focus_room"):
		base_scene.focus_room(room_name)

func _on_interact_button_pressed():
	"""Handle room interaction"""
	if current_room != "" and base_scene and base_scene.has_method("interact_with_room"):
		base_scene.interact_with_room(current_room)

func _on_back_button_pressed():
	"""Return to map select"""
	if base_scene and base_scene.has_method("return_to_map_select"):
		base_scene.return_to_map_select()

func show_room_menu(room_name: String):
	"""Show specific room menu (placeholder for future implementation)"""
	print("Opening menu for: ", room_name)
	
	# This is where you would open specific room interfaces
	# For now, just show a simple notification
	if room_name_label:
		room_name_label.text = room_descriptions[room_name].name + " (Active)"
