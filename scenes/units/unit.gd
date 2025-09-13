# Updated Unit.gd - Now supports modular equipment system
extends Node3D
class_name Unit

# =============================================
# SIGNALS
# =============================================
signal unit_selected(unit)
signal unit_moved(unit, from_tile, to_tile)
signal unit_died(unit)
signal unit_turn_started(unit)
signal unit_turn_ended(unit)
signal mouse_entered(unit)
signal mouse_exited(unit)

# =============================================
# WRVSS STATS - The core attribute system
# =============================================
@export_group("WRVSS Stats")
@export var wisdom: int = 10      # Mental clarity, tactical awareness
@export var rage: int = 10        # Combat fury, damage potential
@export var virtue: int = 10      # Precision, critical hit chance
@export var strength: int = 10    # Physical power, carry capacity
@export var steel: int = 10       # Endurance, resistance to effects

# =============================================
# BASIC UNIT PROPERTIES - Still needed for identification
# =============================================
@export_group("Unit Identity")
@export var unit_name: String = "Unit"
@export var team: String = "player"
@export var unit_class: String = "warrior"  # Can be overridden by Core equipment
@export var experience: int = 0
@export var unit_color: Color = Color.BLUE

# =============================================
# EQUIPMENT SLOTS - The new modular system
# =============================================
@export_group("Equipment Slots")
var core_equipment: Core = null
var primary_weapon: Weapon = null
var sidearm: Weapon = null
var booster: Booster = null
var reactor: Reactor = null
var sensors: Sensor = null
var armor_equipment: ArmorEquipment = null
var accessory_1: Accessory = null
var accessory_2: Accessory = null

# =============================================
# CALCULATED STATS - Computed from equipment + WRVSS
# =============================================
var current_health: int
var max_health: int
var movement_range: int
var armor: int
var evasion: int
var accuracy: int
var initiative: int

# Turn-based tracking
var movement_points_remaining: int
var has_acted: bool = false
var has_moved: bool = false

# =============================================
# GAME STATE VARIABLES
# =============================================
var current_tile: Tile
var grid_position: Vector3i
var is_selected: bool = false

# =============================================
# VISUAL COMPONENTS
# =============================================
@onready var mesh_instance = $MeshInstance3D
@onready var health_bar = $HealthBar
@onready var selection_indicator = $SelectionIndicator
@onready var static_body = $StaticBody3D
@onready var static_collision = $StaticBody3D/CollisionShape3D
@onready var area_3d = $Area3D
@onready var area_collision = $Area3D/CollisionShape3D

# Materials for different states
var default_material: StandardMaterial3D
var selected_material: StandardMaterial3D
var dead_material: StandardMaterial3D

# =============================================
# INITIALIZATION
# =============================================
func _ready():
	# Apply default equipment if none specified
	if not core_equipment:
		equip_default_loadout()
	
	# Calculate all stats from equipment
	recalculate_all_stats()
	
	# Initialize health and movement
	current_health = max_health
	movement_points_remaining = movement_range
	
	# Set up visuals and interaction
	setup_materials()
	setup_visual()
	setup_click_detection()
	update_health_bar()
	position.y = 0.5
	
	print("✓ Unit ", unit_name, " initialized with equipment system")

# =============================================
# EQUIPMENT MANAGEMENT SYSTEM
# =============================================
func equip_default_loadout():
	"""Equip basic starter gear based on unit class"""
	match unit_class:
		"warrior":
			core_equipment = Core.create_warrior_core()
			primary_weapon = Weapon.create_assault_rifle()
			sidearm = Weapon.create_knife()
		"archer":
			core_equipment = Core.create_archer_core()
			primary_weapon = Weapon.create_assault_rifle()
			sidearm = Weapon.create_knife()
		"assassin":
			core_equipment = Core.create_assassin_core()
			primary_weapon = null  # Assassins might rely on stealth/sidearms
			sidearm = Weapon.create_knife()
		"hound":
			# Hounds use natural weapons
			primary_weapon = Weapon.create_hound_claws()
			sidearm = null
		_:
			# Default warrior loadout
			core_equipment = Core.create_warrior_core()
			primary_weapon = Weapon.create_assault_rifle()
			sidearm = Weapon.create_knife()
	
	# Standard equipment for all units
	reactor = Reactor.create_basic_reactor()
	booster = Booster.create_basic_booster()
	sensors = Sensor.create_basic_sensor()
	armor_equipment = ArmorEquipment.create_basic_armor()
	accessory_1 = Accessory.create_basic_accessory()

func equip_item(equipment: Equipment, slot: String) -> Dictionary:
	"""
	Equip an item to specified slot
	Returns: {success: bool, message: String}
	"""
	var result = {"success": false, "message": ""}
	
	# Check if equipment can be used by this unit
	var can_equip = equipment.can_be_equipped_by_unit(self)
	if not can_equip.can_equip:
		result.message = can_equip.reason
		return result
	
	# Check power requirements
	var old_equipment = get_equipment_in_slot(slot)
	var power_change = equipment.power_draw - (old_equipment.power_draw if old_equipment else 0)
	if get_total_power_consumption() + power_change > get_total_power_generation():
		result.message = "Insufficient power capacity"
		return result
	
	# Unequip old item if present
	if old_equipment:
		old_equipment.on_unequipped(self)
	
	# Equip new item
	match slot:
		"core":
			core_equipment = equipment as Core
		"primary_weapon":
			primary_weapon = equipment as Weapon
		"sidearm":
			sidearm = equipment as Weapon
		"booster":
			booster = equipment as Booster
		"reactor":
			reactor = equipment as Reactor
		"sensors":
			sensors = equipment as Sensor
		"armor":
			armor_equipment = equipment as ArmorEquipment
		"accessory_1":
			accessory_1 = equipment as Accessory
		"accessory_2":
			accessory_2 = equipment as Accessory
		_:
			result.message = "Invalid equipment slot"
			return result
	
	# Apply equipment effects
	equipment.on_equipped(self)
	
	# Recalculate stats
	recalculate_all_stats()
	
	result.success = true
	result.message = "Equipped %s successfully" % equipment.equipment_name
	return result

func get_equipment_in_slot(slot: String) -> Equipment:
	"""Get the equipment currently in the specified slot"""
	match slot:
		"core": return core_equipment
		"primary_weapon": return primary_weapon
		"sidearm": return sidearm
		"booster": return booster
		"reactor": return reactor
		"sensors": return sensors
		"armor": return armor_equipment
		"accessory_1": return accessory_1
		"accessory_2": return accessory_2
		_: return null

func get_total_power_consumption() -> int:
	"""Calculate total power draw from all equipment"""
	var total = 0
	var equipment_list = [core_equipment, primary_weapon, sidearm, booster, reactor, 
						  sensors, armor_equipment, accessory_1, accessory_2]
	
	for equipment in equipment_list:
		if equipment:
			total += equipment.power_draw
	
	return total

func get_total_power_generation() -> int:
	"""Calculate total power generation (negative power draw)"""
	if reactor:
		return reactor.power_output
	return 0  # No reactor = no power

# =============================================
# STAT CALCULATION SYSTEM
# =============================================
func recalculate_all_stats():
	"""Recalculate all unit stats based on WRVSS, equipment, and core"""
	# Start with base values from core (if equipped)
	if core_equipment:
		max_health = core_equipment.base_health
		movement_range = core_equipment.base_movement
		armor = core_equipment.base_armor
		initiative = core_equipment.base_initiative
		unit_class = core_equipment.unit_class  # Core determines class
	else:
		# Fallback values if no core
		max_health = 100
		movement_range = 3
		armor = 0
		initiative = 10
	
	# Reset calculated values
	evasion = 0
	accuracy = 0
	
	# Apply equipment bonuses
	var equipment_list = [core_equipment, primary_weapon, sidearm, booster, reactor, 
						  sensors, armor_equipment, accessory_1, accessory_2]
	
	for equipment in equipment_list:
		if equipment:
			max_health += equipment.health_bonus
			movement_range += equipment.speed_bonus
			armor += equipment.armor_bonus
			evasion += equipment.evasion_bonus
			accuracy += equipment.accuracy_bonus
			
			# Special booster movement bonus
			if equipment is Booster and equipment.has_method("movement_bonus"):
				movement_range += equipment.movement_bonus
	
	# Apply WRVSS modifiers (examples - need adjustment)
	max_health += strength * 2  # Strength increases health
	evasion += (wisdom + virtue) / 2  # Mental stats help with evasion
	accuracy += virtue  # Virtue improves accuracy
	initiative += steel  # Steel improves initiative
	
	# Ensure minimums
	max_health = max(1, max_health)
	movement_range = max(1, movement_range)
	armor = max(0, armor)
	evasion = max(0, evasion)
	accuracy = max(0, accuracy)
	initiative = max(1, initiative)
	
	# Update current health if it exceeds new max
	if current_health > max_health:
		current_health = max_health
	
	print("Unit %s stats updated: HP=%d, Move=%d, Armor=%d, Evasion=%d, Accuracy=%d" % 
		  [unit_name, max_health, movement_range, armor, evasion, accuracy])

# =============================================
# COMBAT SYSTEM - Updated for equipment
# =============================================
func can_attack_target(target: Unit) -> bool:
	"""Check if this unit can attack the target using equipped weapons"""
	if not target or target.team == team or has_acted:
		return false
	
	# Check if we have any weapons to attack with
	var weapon = get_active_weapon()
	if not weapon:
		return false
	
	var distance = abs(target.grid_position.x - grid_position.x) + abs(target.grid_position.z - grid_position.z)
	var weapon_check = weapon.can_attack_target(self, target, distance)
	
	return weapon_check.can_attack

func get_active_weapon() -> Weapon:
	"""Get the weapon to use for attacks (primary first, then sidearm)"""
	if primary_weapon:
		return primary_weapon
	elif sidearm:
		return sidearm
	else:
		return null

func attack_unit(target: Unit) -> int:
	"""Attack another unit using equipped weapon"""
	if not can_attack_target(target):
		return 0
	
	var weapon = get_active_weapon()
	if not weapon:
		return 0
	
	# Calculate weapon damage
	var damage_result = weapon.calculate_damage(self, target)
	var final_damage = damage_result.final_damage
	
	# Apply target's armor and resistances
	final_damage = apply_damage_reduction(final_damage, weapon, target)
	
	# Deal damage
	target.take_damage(final_damage)
	has_acted = true
	
	# Print combat feedback
	var damage_text = "%s attacks %s with %s for %d damage" % [unit_name, target.unit_name, weapon.equipment_name, final_damage]
	if damage_result.is_crit:
		damage_text += " (CRITICAL HIT!)"
	print(damage_text)
	
	return final_damage

func apply_damage_reduction(damage: int, weapon: Weapon, target: Unit) -> int:
	"""Apply armor and damage resistance calculations"""
	var reduced_damage = damage
	
	# Apply flat armor reduction (but never reduce below 1)
	reduced_damage -= target.armor
	if target.armor_equipment and target.armor_equipment.damage_reduction > 0:
		reduced_damage -= target.armor_equipment.damage_reduction
	
	# Weapon tags that bypass armor
	if weapon.has_tag("armor_piercing"):
		reduced_damage = damage  # Ignore armor completely
	
	# Apply damage type resistance
	if target.armor_equipment and target.armor_equipment.damage_resistance:
		for damage_type in weapon.damage_types:
			if damage_type in target.armor_equipment.damage_resistance:
				var resistance = target.armor_equipment.damage_resistance[damage_type]
				reduced_damage = int(reduced_damage * (1.0 - resistance))
	
	# Ensure minimum 1 damage (unless completely immune)
	return max(1, reduced_damage)

func get_attack_range() -> int:
	"""Get effective attack range from equipped weapon"""
	var weapon = get_active_weapon()
	if weapon:
		return weapon.get_effective_range(self)
	return 1  # Default melee range

# =============================================
# TURN MANAGEMENT - Updated for equipment
# =============================================
func start_turn():
	"""Start unit's turn, including equipment effects"""
	has_moved = false
	has_acted = false
	movement_points_remaining = movement_range
	
	# Trigger equipment turn start effects
	var equipment_list = [core_equipment, primary_weapon, sidearm, booster, reactor, 
						  sensors, armor_equipment, accessory_1, accessory_2]
	
	for equipment in equipment_list:
		if equipment:
			equipment.on_turn_start(self)
	
	unit_turn_started.emit(self)

func end_turn():
	"""End unit's turn, including equipment effects"""
	has_acted = true
	
	# Trigger equipment turn end effects
	var equipment_list = [core_equipment, primary_weapon, sidearm, booster, reactor, 
						  sensors, armor_equipment, accessory_1, accessory_2]
	
	for equipment in equipment_list:
		if equipment:
			equipment.on_turn_end(self)
	
	unit_turn_ended.emit(self)

func reset_turn():
	"""Reset for new turn"""
	has_acted = false
	movement_points_remaining = movement_range  # reset each turn

# =============================================
# EXISTING METHODS - Keep compatibility
# =============================================

# Keep all your existing visual, movement, and interaction code
func setup_materials():
	# Create normal appearance  
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = unit_color
	
	# Create bright/glowing appearance for when selected
	selected_material = StandardMaterial3D.new()
	selected_material.albedo_color = unit_color.lightened(0.3)
	selected_material.emission = unit_color * 0.3
	selected_material.emission_enabled = true
	
	# Create gray/faded appearance for when dead
	dead_material = StandardMaterial3D.new()
	dead_material.albedo_color = Color.GRAY
	dead_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dead_material.albedo_color.a = 0.5

func setup_visual():
	var box_mesh = BoxMesh.new()
	box_mesh.size = Vector3(0.8, 1.0, 0.8)
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = default_material
	
	if selection_indicator:
		selection_indicator.visible = false

func setup_click_detection():
	if static_body and static_collision:
		var connection_result = static_body.input_event.connect(_on_static_body_clicked)
		static_body.collision_layer = 2
		static_body.collision_mask = 0
		
		if not static_collision.shape:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.8, 1.0, 0.8)
			static_collision.shape = box_shape

func _on_static_body_clicked(_camera, event, _click_position, _click_normal, _shape_idx):
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			handle_unit_selection()

func handle_unit_selection():
	unit_selected.emit(self)

func select():
	is_selected = true
	mesh_instance.material_override = selected_material
	if selection_indicator:
		selection_indicator.visible = true

func deselect():
	is_selected = false
	mesh_instance.material_override = default_material
	if selection_indicator:
		selection_indicator.visible = false

func place_on_tile(tile: Tile) -> void:
	if current_tile:
		current_tile.occupied_unit = null
	
	current_tile = tile
	grid_position = tile.grid_position
	position = Vector3(grid_position.x, grid_position.y + 0.5, grid_position.z)
	tile.occupied_unit = self

func move_to_tile(target_tile: Tile) -> bool:
	if not target_tile.is_walkable or (target_tile.occupied_unit and target_tile.occupied_unit != self):
		return false
	
	var distance = abs(target_tile.grid_position.x - grid_position.x) + abs(target_tile.grid_position.z - grid_position.z)
	if distance > movement_points_remaining:
		return false
	
	if current_tile:
		current_tile.occupied_unit = null
	
	var old_tile = current_tile
	place_on_tile(target_tile)
	movement_points_remaining -= distance
	unit_moved.emit(self, old_tile, target_tile)
	has_moved = true
	
	return true

func take_damage(damage: int):
	current_health -= damage
	current_health = max(0, current_health)
	update_health_bar()
	
	if current_health <= 0:
		die()

func heal(amount: int):
	current_health = min(max_health, current_health + amount)
	update_health_bar()

func update_health_bar():
	if health_bar:
		var health_percent = float(current_health) / float(max_health)
		var foreground = health_bar.get_node_or_null("Foreground")
		if foreground:
			foreground.scale.x = health_percent

func die():
	if current_tile:
		current_tile.occupied_unit = null
	unit_died.emit(self)
	queue_free()
