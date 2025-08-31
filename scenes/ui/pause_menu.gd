# Pause Menu - Handles game pausing and menu navigation
extends Control

@onready var resume_button = $Panel/VBoxContainer/ResumeButton
@onready var main_menu_button = $Panel/VBoxContainer/MainMenuButton
@onready var quit_button = $Panel/VBoxContainer/QuitButton

var is_paused = false

func _ready():
	# Hide the menu initially
	hide()
	
	# Make sure this menu is processed even when paused
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Ensure this menu can receive mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Wait a frame for nodes to be ready, then connect signals
	call_deferred("connect_buttons")

func connect_buttons():
	"""Connect button signals with error checking"""
	# Check if buttons exist and connect them
	if resume_button:
		resume_button.pressed.connect(_on_resume_button_pressed)
	
	if main_menu_button:
		main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

func _gui_input(event):
	"""Capture GUI input to prevent it from reaching the game"""
	if event is InputEventMouseButton:
		accept_event()  # Consume the event so it doesn't reach the game

func toggle_pause_menu():
	"""Toggle pause menu visibility and game pause state"""
	is_paused = !is_paused
	
	if is_paused:
		# Show pause menu
		show()
		get_tree().paused = true
		if resume_button:
			resume_button.grab_focus()
	else:
		# Hide pause menu
		hide()
		get_tree().paused = false

func _on_resume_button_pressed():
	"""Resume the game"""
	toggle_pause_menu()

func _on_main_menu_button_pressed():
	"""Return to main menu"""
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")

func _on_quit_button_pressed():
	"""Quit the game"""
	get_tree().quit()
