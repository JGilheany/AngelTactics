# NPCManager.gd - Manages all base NPCs
class_name NPCManager
extends Node

signal npc_interaction_requested(room_key: String, npc: BaseNPC)

# NPC instances
var npcs: Dictionary = {}
var rooms_container: Node3D
var base_scene: Node3D

# NPC class mappings
var npc_classes = {
	"storage": StorageKeeperNPC,
	# Add more as you create them:
	# "command_center": CommanderNPC,
	# "barracks": SergeantNPC,
	# "workshop": EngineerNPC,
	# "medical": MedicNPC,
	# "research": ScientistNPC,
	# "communications": OperatorNPC
}

# Default NPC configurations
var npc_configs = {
	"storage": {
		"position": Vector3(0, -0.75, -1.2),  
		"color": Color.ORANGE
	},
	"command_center": {
		"position": Vector3(0, -0.75, -1.2),  # Adjust Y values as needed
		"color": Color.BLUE,
		"name": "Commander",
		"role": "Strategic Operations",
		"dialogue": [
			"Welcome, Commander. Ready to plan the next mission?",
			"All units report ready for deployment.",
			"Strategic overview shows all sectors secure."
		]
	},
	"barracks": {
		"position": Vector3(0, -0.75, -1.2),
		"color": Color.GREEN,
		"name": "Sergeant",
		"role": "Unit Management",
		"dialogue": [
			"Your units are ready for deployment. Need to check their status?",
			"All personnel accounted for and combat-ready.",
			"Training schedules are up to date, Commander."
		]
	},
	"workshop": {
		"position": Vector3(0, -0.75, -1.2),
		"color": Color.RED,
		"name": "Engineer",
		"role": "Equipment Specialist",
		"dialogue": [
			"Got some equipment that needs upgrading? I'm your engineer.",
			"All fabrication systems are online and ready.",
			"I can modify any gear you bring me."
		]
	},
	"medical": {
		"position": Vector3(0, -0.75, -1.2),
		"color": Color.WHITE,
		"name": "Medic",
		"role": "Medical Officer",
		"dialogue": [
			"All units are in good health. Any injuries to tend to?",
			"Medical bay is fully stocked and operational.",
			"I've prepared treatment protocols for all mission types."
		]
	},
	"research": {
		"position": Vector3(0, -0.75, -1.2),
		"color": Color.PURPLE,
		"name": "Scientist",
		"role": "Research Specialist",
		"dialogue": [
			"The latest prototypes are almost ready. Want to see the data?",
			"Research is progressing ahead of schedule.",
			"I've discovered some fascinating applications for this technology."
		]
	},
	"communications": {
		"position": Vector3(0, -0.75, -1.2),
		"color": Color.YELLOW,
		"name": "Operator",
		"role": "Communications",
		"dialogue": [
			"All channels are clear. Any messages to send?",
			"Intelligence reports are coming in regularly.",
			"Communication networks are secure and operational."
		]
	},
	"central_hub": {
		"position": Vector3(0, -0.75, -1.2),  # Adjust as needed
		"color": Color.CYAN,
		"name": "Colonel Samedi", 
		"role": "Commanding officer",
		"dialogue": [
			"Lieutenant.",
			"Something the matter, lieutenant?"
		]
	}
}

func initialize(base_scene_ref: Node3D, rooms_container_ref: Node3D):
	"""Initialize the NPC manager"""
	base_scene = base_scene_ref
	rooms_container = rooms_container_ref

func create_all_npcs(room_nodes: Dictionary):
	"""Create NPCs for all rooms"""
	for room_key in room_nodes.keys():
		create_npc_for_room(room_key, room_nodes[room_key])

func create_npc_for_room(room_key: String, room_node: Node3D) -> BaseNPC:
	"""Create an NPC for a specific room"""
	# Check if NPC already exists
	if npcs.has(room_key):
		return npcs[room_key]
	
	# Get or create NPC instance
	var npc: BaseNPC
	if npc_classes.has(room_key):
		# Use specific NPC class
		npc = npc_classes[room_key].new()
	else:
		# Use generic NPC
		npc = BaseNPC.new()
		
		# Configure generic NPC
		if npc_configs.has(room_key):
			var config = npc_configs[room_key]
			npc.npc_name = config.get("name", "Assistant")
			npc.npc_role = config.get("role", "Helper")
			npc.npc_color = config.get("color", Color.GRAY)
			if config.has("dialogue"):
				# Use set_dialogue method instead of direct assignment
				npc.set_dialogue(config.dialogue)
	
	# Set room key
	npc.set_room_key(room_key)
	npc.name = "NPC_" + room_key
	
	# Position NPC in room
	if npc_configs.has(room_key):
		var config = npc_configs[room_key]
		if config.has("position"):
			if config.position is Vector3:
				npc.position = config.position
			elif config.position is Vector2:
				# Legacy support for Vector2 positions
				var pos_2d = config.position
				npc.position = Vector3(pos_2d.x, 0, pos_2d.y)
			else:
				print("Warning: Invalid position type for NPC ", room_key)
	
	# Add to room
	room_node.add_child(npc)
	
	# Connect signals
	npc.npc_interacted.connect(_on_npc_interacted)
	
	# Connect specific signals for specialized NPCs
	if npc is StorageKeeperNPC:
		(npc as StorageKeeperNPC).storage_interface_requested.connect(_on_storage_interface_requested)
	
	# Store reference
	npcs[room_key] = npc
	
	print("Created NPC for room: ", room_key, " (", npc.npc_name, ")")
	return npc

func get_npc(room_key: String) -> BaseNPC:
	"""Get NPC for a specific room"""
	return npcs.get(room_key)

func get_all_npcs() -> Dictionary:
	"""Get all NPCs"""
	return npcs.duplicate()

func remove_npc(room_key: String):
	"""Remove NPC from a room"""
	if npcs.has(room_key):
		var npc = npcs[room_key]
		if is_instance_valid(npc):
			npc.queue_free()
		npcs.erase(room_key)

func update_npc_dialogue(room_key: String, new_dialogue: Array[String]):
	"""Update dialogue for a specific NPC"""
	if npcs.has(room_key):
		npcs[room_key].set_dialogue(new_dialogue)

func set_npc_interactable(room_key: String, interactable: bool):
	"""Enable/disable NPC interaction"""
	if npcs.has(room_key):
		npcs[room_key].set_interactable(interactable)

# Signal handlers
func _on_npc_interacted(npc: BaseNPC):
	"""Handle generic NPC interaction"""
	npc_interaction_requested.emit(npc.room_key, npc)

func _on_storage_interface_requested(npc: StorageKeeperNPC):
	"""Handle storage interface request"""
	# This will be handled by the base scene
	npc_interaction_requested.emit("storage", npc)

# Utility functions
func get_npc_count() -> int:
	"""Get total number of NPCs"""
	return npcs.size()

func get_npcs_by_role(role: String) -> Array[BaseNPC]:
	"""Get NPCs by their role"""
	var filtered_npcs: Array[BaseNPC] = []
	for npc in npcs.values():
		if npc.npc_role == role:
			filtered_npcs.append(npc)
	return filtered_npcs

func broadcast_message_to_all_npcs(message: String):
	"""Send a message to all NPCs (for events, etc.)"""
	for npc in npcs.values():
		npc.add_dialogue_line(message)

func add_npc_class(room_key: String, npc_class):
	"""Register a new NPC class for a room type"""
	npc_classes[room_key] = npc_class

func add_npc_config(room_key: String, config: Dictionary):
	"""Add configuration for a room's NPC"""
	npc_configs[room_key] = config
