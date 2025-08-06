extends Node3D
func _ready():
	# Use call_deferred to change scene after current frame
	call_deferred("load_combat_scene")


func load_combat_scene():
	get_tree().change_scene_to_file("res://scenes/combat/combatscene.tscn")
