extends Node3D

@onready var camera_controller = $CameraController
@onready var rooms_container = $Rooms
@onready var base_ui = $UI/BaseUI

# Storage room UI will be loaded as a scene
var storage_room_ui: Control

# Room references (will be populated from scene)
var room_nodes: Dictionary = {}
var current_room: String = ""
var inventory_manager: InventoryManager
var npc_manager: NPCManager

func _ready():
	setup_room_references()
	setup_room_interactions()
	setup_inventory_manager()
	setup_npc_manager()
	setup_lighting()
	
	# Start in central hub
	focus_room("central_hub")

func setup_inventory_manager():
	"""Setup inventory manager"""
	inventory_manager = InventoryManager.new()
	# Add some test items
	inventory_manager.add_debug_items()

func setup_npc_manager():
	"""Setup NPC management system"""
	npc_manager = NPCManager.new()
	npc_manager.name = "NPCManager"
	add_child(npc_manager)
	
	# Initialize with room references
	npc_manager.initialize(self, rooms_container)
	
	# Create all NPCs
	npc_manager.create_all_npcs(room_nodes)
	
	# Connect signals
	npc_manager.npc_interaction_requested.connect(_on_npc_interaction_requested)

func setup_room_references():
	"""Get references to all manually created rooms"""
	if not rooms_container:
		print("Warning: Rooms container not found!")
		return
	
	# Map node names to our room keys
	var room_mapping = {
		"CentralHub": "central_hub",
		"CommandCenter": "command_center", 
		"Barracks": "barracks",
		"Workshop": "workshop",
		"Storage": "storage",
		"Medical": "medical",
		"Research": "research",
		"Communications": "communications"
	}
	
	# Get room nodes from the scene
	for node_name in room_mapping.keys():
		var room_node = rooms_container.get_node_or_null(node_name)
		if room_node:
			var room_key = room_mapping[node_name]
			room_nodes[room_key] = room_node
			print("Found room: ", room_key)
		else:
			print("Warning: Room not found: ", node_name)

func _on_npc_interaction_requested(room_key: String, npc: BaseNPC):
	"""Handle NPC interaction requests from the NPC manager"""
	print("NPC interaction requested for room: ", room_key, " - ", npc.npc_name)
	
	match room_key:
		"central_hub":
			show_central_hub_npc(npc)
		"storage":
			open_storage_room(npc)
		"command_center":
			show_command_center_npc(npc)
		"barracks":
			show_barracks_npc(npc)
		"workshop":
			show_workshop_npc(npc)
		"medical":
			show_medical_npc(npc)
		"research":
			show_research_npc(npc)
		"communications":
			show_communications_npc(npc)
			
		_:
			print("No specific interaction defined for room: ", room_key)

func open_storage_room(npc: BaseNPC = null):
	"""Open the storage room interface"""
	if not storage_room_ui:
		# Load the storage room UI scene
		var storage_scene = preload("res://scenes/base/ui/StorageRoomUI.tscn")
		storage_room_ui = storage_scene.instantiate()
		storage_room_ui.name = "StorageRoomUI"
		$UI.add_child(storage_room_ui)
		storage_room_ui.room_closed.connect(_on_storage_room_closed)
		
		# Initialize the StorageRoomUI with required references
		storage_room_ui.initialize(self, camera_controller, inventory_manager)
	
	# Show storage room UI with NPC
	storage_room_ui.show_storage_room(npc)
	
	# Hide base UI while in room interface
	if base_ui:
		base_ui.visible = false

func _on_storage_room_closed():
	"""Handle storage room UI closing"""
	if base_ui:
		base_ui.visible = true

func show_central_hub_npc(npc: BaseNPC):
	print(npc.npc_name, ": ", npc.get_current_dialogue())



# Placeholder NPC interactions for other rooms (now receive NPC parameter)
func show_command_center_npc(npc: BaseNPC):
	print(npc.npc_name, ": ", npc.get_current_dialogue())

func show_barracks_npc(npc: BaseNPC):
	print(npc.npc_name, ": ", npc.get_current_dialogue())

func show_workshop_npc(npc: BaseNPC):
	print(npc.npc_name, ": ", npc.get_current_dialogue())

func show_medical_npc(npc: BaseNPC):
	print(npc.npc_name, ": ", npc.get_current_dialogue())

func show_research_npc(npc: BaseNPC):
	print(npc.npc_name, ": ", npc.get_current_dialogue())

func show_communications_npc(npc: BaseNPC):
	print(npc.npc_name, ": ", npc.get_current_dialogue())
		#base_ui.visible = false


# Alternative: Use a single handler and identify the room by the area node
func setup_room_interactions():
	"""Setup click interactions for each room"""
	for room_key in room_nodes.keys():
		var room_node = room_nodes[room_key]
		var area = room_node.get_node_or_null("Area3D")
		if area:
			# Store room name in the area node's name or as metadata
			area.name = "Area3D_" + room_key
			
			# Disconnect ALL existing connections to this area's signals
			var input_connections = area.input_event.get_connections()
			for connection in input_connections:
				area.input_event.disconnect(connection.callable)
			
			var mouse_connections = area.mouse_entered.get_connections()
			for connection in mouse_connections:
				area.mouse_entered.disconnect(connection.callable)
			
			# Connect to generic handlers (no bind needed)
			area.input_event.connect(_on_any_area_input_event)
			area.mouse_entered.connect(_on_any_area_mouse_entered)
			
			print("Connected signals for room: ", room_key)
		else:
			print("Warning: No Area3D found for room: ", room_key)

func _on_any_area_input_event(camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	"""Handle input events from any area - identify room from sender"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Find which room this area belongs to
		var area = get_area_from_camera_ray(camera, _position)
		if area:
			var room_name = get_room_name_from_area(area)
			if room_name:
				print("Room clicked: ", room_name)
				focus_room(room_name)

func _on_any_area_mouse_entered():
	"""Handle mouse entered from any area"""
	# Get the area that sent this signal by checking recent connections
	for room_key in room_nodes.keys():
		var room_node = room_nodes[room_key]
		var area = room_node.get_node_or_null("Area3D")
		if area:
			print("Room hovered: ", room_key)
			break  # For now just print the first one, you can improve this logic

func get_room_name_from_area(area: Area3D) -> String:
	"""Get room name from area node"""
	var area_name = area.name
	if area_name.begins_with("Area3D_"):
		return area_name.substr(7)  # Remove "Area3D_" prefix
	return ""

func get_area_from_camera_ray(_camera: Node, _position: Vector3) -> Area3D:
	"""Find area from camera ray"""
	for room_key in room_nodes.keys():
		var room_node = room_nodes[room_key]
		var area = room_node.get_node_or_null("Area3D")
		if area:
			# Simple check - you could do more sophisticated ray casting here
			return area
	return null

func _on_area_input_event(room_name: String, _camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	"""Handle area input events with room name as first parameter"""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Room clicked: ", room_name)
		focus_room(room_name)

func _on_area_mouse_entered(room_name: String):
	"""Handle area mouse entered events with room name"""
	print("Room hovered: ", room_name)

# Legacy method stubs to prevent errors from old connections
func _on_room_input_event(_camera: Node, _event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int):
	"""Legacy method - should not be called"""
	print("Warning: Legacy _on_room_input_event called - this should be disconnected")

func _on_room_mouse_entered():
	"""Legacy method - should not be called"""
	print("Warning: Legacy _on_room_mouse_entered called - this should be disconnected")

func setup_lighting():
	"""Setup environmental lighting"""
	# Create directional light if it doesn't exist
	if not get_node_or_null("DirectionalLight3D"):
		var directional_light = DirectionalLight3D.new()
		directional_light.name = "DirectionalLight3D"
		directional_light.position = Vector3(0, 10, 5)
		directional_light.rotation_degrees = Vector3(-45, -30, 0)
		directional_light.light_energy = 0.8
		add_child(directional_light)
	
	# Create environment if it doesn't exist
	if not get_node_or_null("WorldEnvironment"):
		var world_env = WorldEnvironment.new()
		world_env.name = "WorldEnvironment"
		
		var environment = Environment.new()
		environment.background_mode = Environment.BG_SKY
		environment.sky = Sky.new()
		environment.sky.sky_material = ProceduralSkyMaterial.new()
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		environment.ambient_light_energy = 0.3
		
		world_env.environment = environment
		add_child(world_env)

func _input(event):
	"""Handle input for camera movement and room selection"""
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1: focus_room("central_hub")
			KEY_2: focus_room("command_center")
			KEY_3: focus_room("barracks")
			KEY_4: focus_room("workshop")
			KEY_5: focus_room("storage")
			KEY_6: focus_room("medical")
			KEY_7: focus_room("research")
			KEY_8: focus_room("communications")
			KEY_SPACE: interact_with_room(current_room)
			KEY_ESCAPE: return_to_map_select()

func focus_room(room_name: String):
	"""Move camera to focus on specific room"""
	if not room_nodes.has(room_name):
		print("Warning: Room node not found: ", room_name)
		return
	
	current_room = room_name
	print("Focusing on room: ", room_name)
	
	# Use camera controller to move to room
	if camera_controller and camera_controller.has_method("focus_on_room"):
		camera_controller.focus_on_room(room_name)
	
	# Update UI
	if base_ui and base_ui.has_method("update_room_info"):
		base_ui.update_room_info(room_name)

func interact_with_room(room_name: String):
	"""Handle room interaction (open specific UI)"""
	if room_name == "":
		return
		
	print("Interacting with: ", room_name)
	
	# Show room-specific menus
	match room_name:
		"central_hub":
			show_central_hub_menu()
		"command_center":
			show_command_center_menu()
		"barracks":
			show_barracks_menu()
		"workshop":
			show_workshop_menu()
		"storage":
			open_storage_room()
		"medical":
			show_medical_menu()
		"research":
			show_research_menu()
		"communications":
			show_communications_menu()

# Room interaction methods (expand these later)
func show_central_hub_menu():
	print("Central Hub - Base overview and status")

func show_command_center_menu():
	print("Command Center - Mission planning")

func show_barracks_menu():
	print("Barracks - Unit management")

func show_workshop_menu():
	print("Workshop - Equipment crafting")

func show_medical_menu():
	print("Medical - Unit healing")

func show_research_menu():
	print("Research - Technology upgrades")

func show_communications_menu():
	print("Communications - Intel and contacts")

func return_to_map_select():
	"""Return to map selection screen"""
	print("Returning to map select...")
	get_tree().change_scene_to_file("res://scenes/ui/map_select.tscn")

# Helper functions
func get_room_position(room_name: String) -> Vector3:
	"""Get the world position of a room"""
	if room_nodes.has(room_name):
		return room_nodes[room_name].global_position
	return Vector3.ZERO

func get_room_node(room_name: String) -> StaticBody3D:
	"""Get a room node by name"""
	if room_nodes.has(room_name):
		return room_nodes[room_name]
	return null

func get_room_npc(room_name: String) -> BaseNPC:
	"""Get NPC for a specific room"""
	if npc_manager:
		return npc_manager.get_npc(room_name)
	return null
