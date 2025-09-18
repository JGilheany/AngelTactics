# BaseCameraController.gd - Camera controller for 3D base navigation
extends Node3D

@onready var camera = $Camera3D
@onready var base_scene = get_parent()

# Camera movement settings
@export var move_speed: float = 10.0
@export var rotation_speed: float = 2.0
@export var zoom_speed: float = 2.0
@export var smooth_time: float = 1.0

# Camera limits
@export var min_distance: float = 5.0
@export var max_distance: float = 50.0
@export var min_elevation: float = -45.0
@export var max_elevation: float = 45.0

# Current camera state
var is_moving: bool = false
var target_position: Vector3
var target_rotation: Vector3
var current_tween: Tween

# Input handling
var mouse_sensitivity: float = 0.01
var is_mouse_captured: bool = false
var last_mouse_position: Vector2

# Predefined camera positions for each room
var room_positions: Dictionary = {
	"central_hub": {
		"position": Vector3(0, 0.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"command_center": {
		"position": Vector3(0, 1.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"barracks": {
		"position": Vector3(2, -0.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"workshop": {
		"position": Vector3(-2, 0.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"storage": {
		"position": Vector3(0, -0.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"medical": {
		"position": Vector3(-2, 1.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"research": {
		"position": Vector3(-2, -0.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"communications": {
		"position": Vector3(2, 1.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	},
	"recreation": {
		"position": Vector3(2, 0.5, 0.2),
		"rotation": Vector3(-20, 0, 0)
	}
}

func _ready():
	# Ensure we have a camera
	if not camera:
		camera = Camera3D.new()
		add_child(camera)
	
	# Set initial position
	move_to_room("central_hub")

func _input(event):
	"""Handle camera input"""
	# Handle mouse look (right mouse button)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				start_mouse_look()
			else:
				stop_mouse_look()
	
	# Handle mouse movement for looking around
	elif event is InputEventMouseMotion and is_mouse_captured:
		handle_mouse_look(event.relative)
	
	# Handle mouse wheel for zooming
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()

func _process(delta):
	"""Handle continuous input"""
	if not is_moving:
		handle_keyboard_movement(delta)

func handle_keyboard_movement(delta):
	"""Handle WASD movement when not transitioning between rooms"""
	var input_vector = Vector3.ZERO
	
	# Get input
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		input_vector.y += 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		input_vector.y -= 1
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		input_vector.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		input_vector.x += 1
	if Input.is_key_pressed(KEY_Q):
		input_vector.z -= 1
	if Input.is_key_pressed(KEY_E):
		input_vector.z += 1
	
	# Apply movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		# Move relative to camera's current orientation
		var camera_transform = transform
		var movement = (camera_transform.basis * input_vector) * move_speed * delta
		position += movement

func start_mouse_look():
	"""Start mouse look mode"""
	is_mouse_captured = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	last_mouse_position = get_viewport().get_mouse_position()

func stop_mouse_look():
	"""Stop mouse look mode"""
	is_mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func handle_mouse_look(mouse_delta: Vector2):
	"""Handle mouse look rotation"""
	if is_moving:
		return
	
	# Horizontal rotation (Y axis)
	rotation_degrees.y -= mouse_delta.x * mouse_sensitivity * 100
	
	# Vertical rotation (X axis) with limits
	rotation_degrees.x -= mouse_delta.y * mouse_sensitivity * 100
	rotation_degrees.x = clamp(rotation_degrees.x, min_elevation, max_elevation)

func zoom_in():
	"""Zoom camera closer"""
	if is_moving:
		return
	
	var forward = -transform.basis.z
	var new_position = position + forward * zoom_speed
	
	# Check distance limits (simple distance from origin)
	if new_position.length() > min_distance:
		position = new_position

func zoom_out():
	"""Zoom camera further"""
	if is_moving:
		return
	
	var forward = -transform.basis.z
	var new_position = position - forward * zoom_speed
	
	# Check distance limits
	if new_position.length() < max_distance:
		position = new_position

func move_to_room(room_name: String):
	"""Move camera to predefined room position"""
	if not room_positions.has(room_name):
		print("Warning: No camera position defined for room: ", room_name)
		return
	
	var room_data = room_positions[room_name]
	move_to_position(room_data.position, room_data.rotation)

func move_to_position(target_pos: Vector3, target_rot: Vector3):
	"""Smoothly move camera to target position and rotation"""
	if is_moving and current_tween:
		current_tween.kill()
	
	is_moving = true
	target_position = target_pos
	target_rotation = target_rot
	
	# Stop mouse look during transition
	if is_mouse_captured:
		stop_mouse_look()
	
	# Create smooth transition
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# Animate position
	current_tween.tween_property(self, "position", target_position, smooth_time)
	
	# Animate rotation
	current_tween.tween_property(self, "rotation_degrees", target_rotation, smooth_time)
	
	# Set easing
	current_tween.set_ease(Tween.EASE_OUT)
	current_tween.set_trans(Tween.TRANS_CUBIC)
	
	# Wait for completion
	await current_tween.finished
	is_moving = false

func look_at_point(target: Vector3):
	"""Make camera look at a specific point"""
	if is_moving:
		return
	
	look_at(target, Vector3.UP)

func get_camera_forward() -> Vector3:
	"""Get the forward direction of the camera"""
	return -transform.basis.z

func get_camera_right() -> Vector3:
	"""Get the right direction of the camera"""
	return transform.basis.x

func get_camera_up() -> Vector3:
	"""Get the up direction of the camera"""
	return transform.basis.y

# Public interface for the base scene
func focus_on_room(room_name: String):
	"""Public method to focus camera on a room"""
	move_to_room(room_name)

func is_camera_moving() -> bool:
	"""Check if camera is currently transitioning"""
	return is_moving

func set_camera_settings(new_move_speed: float = -1, new_rotation_speed: float = -1, new_smooth_time: float = -1):
	"""Update camera settings"""
	if new_move_speed > 0:
		move_speed = new_move_speed
	if new_rotation_speed > 0:
		rotation_speed = new_rotation_speed
	if new_smooth_time > 0:
		smooth_time = new_smooth_time

# Room position management
func add_room_position(room_name: String, pos: Vector3, rot: Vector3):
	"""Add a new room position"""
	room_positions[room_name] = {
		"position": pos,
		"rotation": rot
	}

func update_room_position(room_name: String, pos: Vector3, rot: Vector3):
	"""Update existing room position"""
	if room_positions.has(room_name):
		room_positions[room_name].position = pos
		room_positions[room_name].rotation = rot

func get_room_position(room_name: String) -> Dictionary:
	"""Get room camera position data"""
	if room_positions.has(room_name):
		return room_positions[room_name]
	return {}

# Debug helpers
func print_current_camera_info():
	"""Print current camera position and rotation for debugging"""
	print("Camera Position: ", position)
	print("Camera Rotation: ", rotation_degrees)
