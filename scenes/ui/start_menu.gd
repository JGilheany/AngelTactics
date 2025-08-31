extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var settings_button = $VBoxContainer/SettingsButton
@onready var quit_button = $VBoxContainer/QuitButton

func _ready():
	# Connect button signals
	start_button.pressed.connect(_on_start_button_pressed)
	settings_button.pressed.connect(_on_settings_button_pressed)
	quit_button.pressed.connect(_on_quit_button_pressed)
	
	# Set focus to start button for keyboard navigation
	start_button.grab_focus()

func _on_start_button_pressed():
	# Load the map selection menu
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")

func _on_settings_button_pressed():
	# Placeholder for settings menu
	# You can create a settings scene later and load it here
	print("Settings button pressed - implement settings menu")

func _on_quit_button_pressed():
	# Quit the game
	get_tree().quit()
