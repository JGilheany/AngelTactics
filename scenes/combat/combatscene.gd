# This script inherits from Node3D (makes it a 3D scene)
# This is the main scene that manages tactical combat
extends Node3D

# NODE REFERENCE: Get reference to the camera for controlling the view
@onready var camera = $CameraRig/Camera3D

# VARIABLE: Will hold reference to our Grid object once it's created
var grid: Grid

# Unit Manager - handles all unit-related logic
var unit_manager: UnitManager

#camera variables
var camera_speed: float = 15.0
var zoom_speed: float = 2.0
var min_zoom: float = 8.0
var max_zoom: float = 40.0
var camera_rig_position: Vector3
var zoom_level: float = 10.0

# _ready() runs once when this CombatScene is added to the scene tree
func _ready():
	
	# Enable input processing for this node
	set_process_input(true)
	set_process_unhandled_input(true)
	
	# CREATE AND ADD GRID: Dynamically load and create the grid
	var grid_scene = preload("res://scenes/maps/grid.tscn")
	grid = grid_scene.instantiate()
	add_child(grid)
	
	# CONNECT GRID SIGNALS: Listen for events from the grid
	grid.tile_selected.connect(_on_tile_selected)
	
	# SETUP CAMERA: Position camera to have a good view of the grid
	setup_camera()
	# Initialize camera movement variables after camera setup
	var camera_rig = $CameraRig
	camera_rig_position = camera_rig.position
	zoom_level = camera_rig.position.y

	# CREATE UNIT MANAGER: Initialize unit management system
	unit_manager = UnitManager.new(self, grid)
	unit_manager.spawn_initial_units()

	print("Combat scene: OK")
	grid.test_debug()

# Called automatically when any tile in the grid is selected (clicked)
func _on_tile_selected(tile: Tile):
	unit_manager.handle_tile_click(tile)

# Positions the camera to get a good tactical overview of the battlefield
func setup_camera():
	var camera_rig = $CameraRig
	camera_rig.position = Vector3(5, 10, 10)
	camera_rig.look_at(Vector3(5, 0, 5), Vector3.UP)

	print("=== CAMERA DEBUG ===")
	print("Camera position: ", camera.position)
	print("Camera is current: ", camera.current)
	
	# Test raycast from camera
	var space_state = get_world_3d().direct_space_state
	var mouse_pos = get_viewport().size / 2  # Center of screen
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000
	
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 3  # Check both layer 1 (tiles) and layer 2 (units)
	var _result = space_state.intersect_ray(query)

# INPUT HANDLER: Handle mouse clicks and keyboard input
func _input(event):
	# Handle mouse clicks
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		
		# Check if camera exists
		if not camera:
			print("❌ ERROR: Camera not found!")
			return
			
		var space_state = get_world_3d().direct_space_state
		if not space_state:
			print("❌ ERROR: No space state!")
			return
			
		var from = camera.project_ray_origin(event.position)
		var to = from + camera.project_ray_normal(event.position) * 1000
		
		print("Ray from: ", from)
		print("Ray to: ", to)
		
		var query = PhysicsRayQueryParameters3D.create(from, to)
		query.collision_mask = 3  # Check layers 1 and 2
		
		var result = space_state.intersect_ray(query)
		
		# Check if we hit anything - result is a Dictionary
		if result.is_empty():
			print("❌ No raycast hit - clicking empty space")
			return
		
		# Safe collision detection
		if not result.has("collider") or not result.collider:
			print("❌ ERROR: No collider in result")
			return
			
		var hit_object = result.collider
		
		if not result.is_empty():
			var collider = result.collider
			print("DEBUG RAY HIT:", collider, " class:", collider.get_class())
			var cur = collider
			var depth = 0
			while cur and depth < 6:
				print("  parent[", depth, "]:", cur, " class:", cur.get_class())
				if cur is Tile:
					print("    -> Tile grid_position:", cur.grid_position, " mesh.visible:", (cur.get_node_or_null('MeshInstance3D') != null and cur.get_node_or_null('MeshInstance3D').visible))
					break
				cur = cur.get_parent()
				depth += 1
		
		# Handle unit clicks (collision layer 2)
		if hit_object.collision_layer == 2:
			print("→ Clicked on UNIT layer")
			var unit = hit_object.get_parent()
			if unit is Unit:
				print("✓ Found Unit: ", unit.unit_name)
				unit_manager.handle_unit_click(unit)
			else:
				print("❌ Parent is not a Unit: ", unit)
		
		# Handle tile clicks (collision layer 1)
		elif hit_object.collision_layer == 1:
			print("→ Clicked on TILE layer")
			var tile = hit_object.get_parent()
			if tile is Tile:
				print("✓ Found Tile at: ", tile.grid_position)
				_on_tile_selected(tile)
			else:
				print("❌ Parent is not a Tile: ", tile)
		
		else:
			print("❌ Unknown collision layer: ", hit_object.collision_layer)
	
	# Handle spacebar for ending turn
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("SPACEBAR pressed - ending turn")
		unit_manager.end_turn()
		
	#scroll up and down floors with [ and ]
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_BRACKETLEFT:
			grid.switch_layer(-1)
		elif event.keycode == KEY_BRACKETRIGHT:
			grid.switch_layer(1)

func _process(delta):
	handle_camera_movement(delta)
	handle_camera_zoom_input_map()

# Camera movement handling
func handle_camera_movement(delta: float):
	var camera_rig = $CameraRig
	if not camera_rig:
		return
	
	var input_vector = Vector2.ZERO
	var move_speed = camera_speed * delta
	
	# Get WASD input
	if Input.is_key_pressed(KEY_W):
		input_vector.y -= 1
	if Input.is_key_pressed(KEY_S):
		input_vector.y += 1
	if Input.is_key_pressed(KEY_A):
		input_vector.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_vector.x += 1
	
	# Optional: Hold Shift for faster movement
	if Input.is_key_pressed(KEY_SHIFT):
		move_speed *= 2.0
	
	# Normalize diagonal movement and apply
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		
		# Move camera rig (assuming top-down tactical view)
		camera_rig_position.x += input_vector.x * move_speed
		camera_rig_position.z += input_vector.y * move_speed
		
		# Optional: Add boundaries to keep camera over your battlefield
		camera_rig_position.x = clamp(camera_rig_position.x, -5, 15)
		camera_rig_position.z = clamp(camera_rig_position.z, -5, 15)
		
		# Apply position while maintaining current zoom level
		camera_rig.position = Vector3(camera_rig_position.x, zoom_level, camera_rig_position.z)
		
		# Keep camera pointing at the same relative position
		var look_target = Vector3(camera_rig_position.x, 0, camera_rig_position.z - 5)
		camera_rig.look_at(look_target, Vector3.UP)

func handle_camera_zoom_input_map():
	var camera_rig = $CameraRig
	if not camera_rig:
		return
	
	var zoom_change = 0.0
	
	if Input.is_action_just_pressed("camera_zoom_in"):
		zoom_change = -zoom_speed
		print("Zooming in, new level will be: ", zoom_level + zoom_change)
	elif Input.is_action_just_pressed("camera_zoom_out"):
		zoom_change = zoom_speed
		print("Zooming out, new level will be: ", zoom_level + zoom_change)
	
	if zoom_change != 0.0:
		zoom_level += zoom_change
		zoom_level = clamp(zoom_level, min_zoom, max_zoom)
		print("Applied zoom level: ", zoom_level)
		
		camera_rig.position.y = zoom_level
		camera_rig_position.y = zoom_level
		
		var look_target = Vector3(camera_rig_position.x, 0, camera_rig_position.z - (zoom_level * 0.3))
		camera_rig.look_at(look_target, Vector3.UP)
