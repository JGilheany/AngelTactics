extends Node3D

func _ready():
	# Load the start menu instead of going directly to combat
	call_deferred("load_start_menu")

func load_start_menu():
	get_tree().change_scene_to_file("res://scenes/ui/start_menu.tscn")
