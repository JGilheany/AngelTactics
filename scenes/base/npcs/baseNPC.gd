# BaseNPC.gd - Base class for all room NPCs
class_name BaseNPC
extends Node3D

signal npc_interacted(npc: BaseNPC)
signal dialogue_changed(new_dialogue: String)

# NPC Data
@export var npc_name: String = "Unknown NPC"
@export var npc_role: String = "Assistant"
@export var npc_color: Color = Color.GRAY
@export var dialogue_lines: Array[String] = []

# Components
var mesh_instance: MeshInstance3D
var head_instance: MeshInstance3D
var interaction_area: Area3D
var material: StandardMaterial3D

# State
var current_dialogue_index: int = 0
var room_key: String = ""
var is_interactable: bool = true

func _ready():
	"""Initialize the NPC"""
	create_npc_geometry()
	setup_interaction_area(Vector3(0, 0.3, 0))  # lifts collision up by 0.5 on Y for the collision
	setup_default_dialogue()

func create_npc_geometry():
	"""Create the basic NPC visual representation"""
	# Main body (cylinder)
	mesh_instance = MeshInstance3D.new()
	var cylinder_mesh = CylinderMesh.new()
	cylinder_mesh.height = 0.3
	cylinder_mesh.top_radius = 0.1
	cylinder_mesh.bottom_radius = 0.1
	mesh_instance.mesh = cylinder_mesh
	add_child(mesh_instance)
	
	# Head (sphere)
	head_instance = MeshInstance3D.new()
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.05
	sphere_mesh.height = 0.1
	head_instance.mesh = sphere_mesh
	head_instance.position = Vector3(0, 0.2, 0)
	add_child(head_instance)
	
	# Apply material
	update_appearance()

func setup_interaction_area(offset: Vector3 = Vector3.ZERO):
	"""Create interaction area for the NPC"""
	interaction_area = Area3D.new()
	interaction_area.name = "InteractionArea"
	add_child(interaction_area)

	var collision_shape = CollisionShape3D.new()
	var shape = CylinderShape3D.new()
	shape.height = 0.3
	shape.radius = 0.75
	collision_shape.shape = shape
	
	# ✅ Apply an offset
	collision_shape.position = offset  

	interaction_area.add_child(collision_shape)

	# Connect signals
	interaction_area.input_event.connect(_on_interaction_area_input_event)
	interaction_area.mouse_entered.connect(_on_mouse_entered)
	interaction_area.mouse_exited.connect(_on_mouse_exited)



func setup_default_dialogue():
	"""Setup default dialogue if none provided"""
	if dialogue_lines.is_empty():
		dialogue_lines = [
			"Hello there!",
			"How can I assist you today?",
			"Is there anything you need help with?"
		]

func update_appearance():
	"""Update NPC visual appearance"""
	material = StandardMaterial3D.new()
	material.albedo_color = npc_color
	
	if mesh_instance:
		mesh_instance.material_override = material
	if head_instance:
		head_instance.material_override = material

func interact():
	"""Handle NPC interaction"""
	if not is_interactable:
		return
	
	# Cycle dialogue
	cycle_dialogue()
	
	# Emit interaction signal
	npc_interacted.emit(self)
	
	# Override in subclasses for specific behavior
	on_interact()

func on_interact():
	"""Override this in subclasses for specific interaction behavior"""
	pass

func cycle_dialogue():
	"""Move to next dialogue line"""
	if dialogue_lines.size() > 0:
		current_dialogue_index = (current_dialogue_index + 1) % dialogue_lines.size()
		dialogue_changed.emit(get_current_dialogue())

func get_current_dialogue() -> String:
	"""Get current dialogue line"""
	if dialogue_lines.size() > 0 and current_dialogue_index < dialogue_lines.size():
		return dialogue_lines[current_dialogue_index]
	return "..."

func set_dialogue(new_dialogue: Array):
	"""Set new dialogue lines - accepts regular Array and converts to Array[String]"""
	dialogue_lines.clear()
	for line in new_dialogue:
		if line is String:
			dialogue_lines.append(line)
		else:
			dialogue_lines.append(str(line))  # Convert to string if needed
	current_dialogue_index = 0
	dialogue_changed.emit(get_current_dialogue())

func add_dialogue_line(line: String):
	"""Add a new dialogue line"""
	dialogue_lines.append(line)

func set_room_key(key: String):
	"""Set the room this NPC belongs to"""
	room_key = key

func set_interactable(interactable: bool):
	"""Enable/disable interaction"""
	is_interactable = interactable

func get_npc_data() -> Dictionary:
	"""Get NPC data for UI systems"""
	return {
		"name": npc_name,
		"role": npc_role,
		"dialogue": get_current_dialogue(),
		"color": npc_color,
		"room_key": room_key
	}

# Signal handlers
func _on_interaction_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	"""Handle click interaction"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		interact()

func _on_mouse_entered():
	"""Handle mouse hover enter"""
	# Optional: Add hover effects
	if material:
		material.albedo_color = npc_color.lightened(0.2)

func _on_mouse_exited():
	"""Handle mouse hover exit"""
	# Restore normal appearance
	if material:
		material.albedo_color = npc_color
