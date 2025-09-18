extends Control
@onready var city_button = $VBoxContainer/CityButton
@onready var base_button = $VBoxContainer/BaseButton
@onready var forest_button = $VBoxContainer/ForestButton
@onready var desert_button = $VBoxContainer/DesertButton
@onready var mountain_button = $VBoxContainer/MountainButton
@onready var back_button = $VBoxContainer/BackButton

func _ready():
	# Connect button signals
	city_button.pressed.connect(_on_city_button_pressed)
	base_button.pressed.connect(_on_base_button_pressed)  # Fixed this line
	forest_button.pressed.connect(_on_forest_button_pressed)
	desert_button.pressed.connect(_on_desert_button_pressed)
	mountain_button.pressed.connect(_on_mountain_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)
	
	# Set focus to city button for keyboard navigation
	city_button.grab_focus()
	
	# Enabled base button now that it's implemented(ish)
	city_button.disabled = false
	base_button.disabled = false  # Enable base button
	forest_button.disabled = true
	desert_button.disabled = true
	mountain_button.disabled = true

func _on_city_button_pressed():
	# Load the city combat scene (what we have at the moment lmao)
	get_tree().change_scene_to_file("res://scenes/combat/combatscene.tscn")

func _on_base_button_pressed():
	"""Navigate to the 3D base scene"""
	print("Opening 3D Base...")
	get_tree().change_scene_to_file("res://scenes/base/base_scene.tscn")

func _on_forest_button_pressed():
	# Placeholder - you can implement different maps later
	print("Forest map not yet implemented")

func _on_desert_button_pressed():
	# Placeholder - you can implement different maps later
	print("Desert map not yet implemented")

func _on_mountain_button_pressed():
	# Placeholder - you can implement different maps later
	print("Mountain map not yet implemented")

func _on_back_button_pressed():
	# Return to start menu
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")
