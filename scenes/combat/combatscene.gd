# Combat Scene - Main tactical combat controller
extends Node3D

# Core references
@onready var camera = $CameraRig/Camera3D
var grid: Grid
var unit_manager: UnitManager

# UI management
@onready var pause_menu_scene = preload("res://scenes/ui/pause_menu.tscn")
var pause_menu_instance
var ui_layer

# Camera movement settings
var camera_speed: float = 15.0
var camera_rig_position: Vector3
var zoom_level: float = 10.0

# Camera zoom settings
var zoom_distance := 10.0
var min_zoom := 5.0
var max_zoom := 20.0
var zoom_speed := 1.0

# Camera rotation settings
var target_yaw: float = 0.0
var is_rotating: bool = false
var rotation_speed: float = 10.0   # radians per second

func _ready():
	add_to_group("combat_scene")
	
	# Create UI layer for interface elements
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UILayer" 
	ui_layer.layer = 100  # High layer number ensures UI renders on top
	add_child(ui_layer)
	
	# Create and add pause menu to UI layer
	pause_menu_instance = pause_menu_scene.instantiate()
	ui_layer.add_child(pause_menu_instance)
	
	# Enable input processing
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# Create and setup the tactical grid
	var grid_scene = preload("res://scenes/maps/grid.tscn")
	grid = grid_scene.instantiate()
	add_child(grid)
	
	# Connect grid interaction signals
	grid.tile_selected.connect(_on_tile_selected)
	
	# Setup camera for tactical overview
	setup_camera()
	init_camera_rotation()
	
	# Initialize camera movement variables
	var camera_rig = $CameraRig
	camera_rig_position = camera_rig.position
	zoom_level = camera_rig.position.y

	# Create unit management system and begin placement phase
	unit_manager = UnitManager.new(self, grid)
	unit_manager.spawn_initial_units()

func _on_tile_selected(tile: Tile):
	"""Forward tile selection to unit manager"""
	unit_manager.handle_tile_click(tile)

func setup_camera():
	"""Position camera for optimal tactical view of the battlefield"""
	var camera_rig = $CameraRig
	camera_rig.position = Vector3(5, 10, 10)
	camera_rig.look_at(Vector3(5, 0, 5), Vector3.UP)

func _input(event):
	"""Handle all input events with proper priority for UI vs gameplay"""
	# Handle escape key to toggle pause menu
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if pause_menu_instance:
			pause_menu_instance.toggle_pause_menu()
		return  # Don't process any other input after escape
	
	# Block game input when paused
	if pause_menu_instance and pause_menu_instance.is_paused:
		return  # Ignore game input while paused

	# During placement phase, handle UI clicks carefully
	if unit_manager and unit_manager.is_placement_active:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is over UI elements first
			if is_click_over_ui(event.position):
				return  # Let UI handle the click
			# Otherwise process as world click
		else:
			# Non-left-click events go to UI during placement
			return

	# Handle gameplay input
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_3d_click(event)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		# End turn (only during gameplay, not placement)
		if unit_manager and not unit_manager.is_placement_active:
			unit_manager.end_turn()
	# Handle floor switching with bracket keys
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:
			grid.switch_layer(-1)
		elif event.keycode == KEY_BRACKETRIGHT:
			grid.switch_layer(1)

func is_click_over_ui(mouse_position: Vector2) -> bool:
	"""Check if mouse click is over UI elements to prevent world interaction"""
	if unit_manager and unit_manager.placement_ui and unit_manager.placement_ui.visible:
		var ui = unit_manager.placement_ui
		var ui_rect = Rect2(ui.global_position, ui.size)
		
		# Check UI bounds
		if ui_rect.has_point(mouse_position):
			return true
		
		# Also check individual buttons
		for button in get_all_buttons(ui):
			var button_rect = Rect2(button.global_position, button.size)
			if button_rect.has_point(mouse_position):
				return true
	
	return false

func get_all_buttons(node: Node) -> Array[Button]:
	"""Recursively find all Button nodes in the UI hierarchy"""
	var buttons: Array[Button] = []
	for child in node.get_children():
		if child is Button:
			buttons.append(child)
		buttons.append_array(get_all_buttons(child))
	return buttons

func handle_3d_click(event: InputEventMouseButton):
	"""Handle clicks in the 3D world - units, tiles, etc."""
	# Validate camera and physics state
	if not camera:
		return
		
	var space_state = get_world_3d().direct_space_state
	if not space_state:
		return
	
	# Cast ray from camera through mouse position
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3  # Check layers 1 (tiles) and 2 (units)
	
	var result = space_state.intersect_ray(query)
	
	# Check if we hit anything
	if result.is_empty():
		return  # Clicked on empty space
	
	# Validate collision result
	if not result.has("collider") or not result.collider:
		return
		
	var hit_object = result.collider
	
	# Handle unit clicks (collision layer 2)
	if hit_object.collision_layer == 2:
		var unit = hit_object.get_parent()
		if unit is Unit:
			# During placement, handle unit clicks for removal
			if unit_manager and unit_manager.is_placement_active:
				if unit.current_tile:
					unit_manager.placement_ui.handle_tile_click(unit.current_tile)
				return
			
			# During gameplay, handle unit selection/attacking
			unit_manager.handle_unit_click(unit)
	
	# Handle tile clicks (collision layer 1)
	elif hit_object.collision_layer == 1:
		var tile = hit_object.get_parent()
		if tile is Tile:
			# Let unit manager handle based on current game state
			unit_manager.handle_tile_click(tile)

# Camera system - runs every frame
var current_zoom := 10.0

func _process(delta):
	"""Update camera movement, zoom, and rotation each frame"""
	handle_camera_movement(delta)
	handle_camera_zoom_input_map()
	handle_camera_rotation_input()
	update_camera_rotation(delta)
	
	# Smooth zoom interpolation
	current_zoom = lerp(current_zoom, zoom_distance, delta * 8.0)
	$CameraRig/Camera3D.transform.origin = Vector3(0, 0, current_zoom)

func handle_camera_movement(delta: float):
	"""Handle WASD camera movement with bounds checking"""
	var camera_rig = $CameraRig
	if not camera_rig:
		return
	
	var input_vector = Vector2.ZERO
	var move_speed = camera_speed * delta
	
	# Gather input
	if Input.is_key_pressed(KEY_W):
		input_vector.y += 1
	if Input.is_key_pressed(KEY_S):
		input_vector.y -= 1
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1
	
	# Apply speed boost for shift
	if Input.is_key_pressed(KEY_SHIFT):
		move_speed *= 2.0
	
	# Process movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		
		# Move in camera rig's local space (respects rotation)
		var forward = -camera_rig.transform.basis.z
		var right = camera_rig.transform.basis.x
		var move_vec = (right * input_vector.x + forward * input_vector.y) * move_speed
		
		camera_rig_position += move_vec
		
		# Clamp to grid boundaries with padding
		camera_rig_position.x = clamp(camera_rig_position.x, -5, grid.grid_width + 5)
		camera_rig_position.z = clamp(camera_rig_position.z, -5, grid.grid_height + 5)
		
		# Apply position (rotation handled separately)
		camera_rig.position = Vector3(camera_rig_position.x, zoom_level, camera_rig_position.z)

func handle_camera_zoom_input_map():
	"""Handle mouse wheel or key-based zoom input"""
	if not camera:
		return
	
	# Check for zoom input
	if Input.is_action_just_pressed("camera_zoom_in"):
		zoom_distance -= zoom_speed
	elif Input.is_action_just_pressed("camera_zoom_out"):
		zoom_distance += zoom_speed
	
	# Clamp zoom distance
	zoom_distance = clamp(zoom_distance, min_zoom, max_zoom)

func init_camera_rotation():
	"""Initialize camera rotation to nearest 90-degree angle"""
	var camera_rig = $CameraRig
	if camera_rig:
		# Snap to nearest 90-degree increment
		target_yaw = round(camera_rig.rotation.y / (PI/2)) * (PI/2)
		camera_rig.rotation.y = target_yaw

func handle_camera_rotation_input():
	"""Handle Q/E key rotation input"""
	if Input.is_action_just_pressed("camera_rotate_left"):
		queue_camera_rotation(-PI/2)  # Rotate left
	elif Input.is_action_just_pressed("camera_rotate_right"):
		queue_camera_rotation(PI/2)   # Rotate right

func queue_camera_rotation(delta_angle: float):
	"""Set up a new rotation target for smooth interpolation"""
	var camera_rig = $CameraRig
	if not camera_rig:
		return
	target_yaw += delta_angle
	is_rotating = true

func update_camera_rotation(delta: float):
	"""Smoothly interpolate camera rotation toward target"""
	var camera_rig = $CameraRig
	if not camera_rig or not is_rotating:
		return

	var current_yaw = camera_rig.rotation.y
	var diff = target_yaw - current_yaw

	# Snap to target when close enough
	if abs(diff) < 0.01:
		camera_rig.rotation.y = target_yaw
		is_rotating = false
	else:
		# Smooth interpolation toward target
		camera_rig.rotation.y = lerp(current_yaw, target_yaw, rotation_speed * delta)
