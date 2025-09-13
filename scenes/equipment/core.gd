# Core.gd - Defines unit's primary class and abilities
# =============================================
class_name Core
extends Equipment

@export_group("Core Properties")
@export var unit_class: String = "warrior"  # The class this core provides
@export var primary_ability: String = ""   # Special ability name
@export var ability_description: String = ""
@export var ability_cooldown: int = 0      # Turns between ability uses
@export var restricts_primary_weapon: bool = false  # Some cores are integrated weapons

# REMOVED: @export var allowed_unit_classes: Array[String] = []
# This property is already inherited from Equipment.gd

# Core stats - these define the base capabilities of the unit class
@export_group("Base Stats")
@export var base_health: int = 100
@export var base_movement: int = 3
@export var base_armor: int = 0
@export var base_initiative: int = 10

static func create_warrior_core() -> Core:
	"""Factory method for warrior core"""
	var core = Core.new()
	core.equipment_name = "Warrior Combat Core"
	core.manufacturer = "MilSpec Industries"
	core.description = "Standard infantry combat systems and training"
	core.cost = 0  # Cores typically aren't purchased separately
	core.power_draw = 0
	
	core.unit_class = "warrior"
	core.primary_ability = "Battle Fury"
	core.ability_description = "Increases damage and accuracy for 3 turns"
	core.ability_cooldown = 5
	
	core.base_health = 120
	core.base_movement = 3
	core.base_armor = 2
	core.base_initiative = 10
	
	# Warrior bonuses
	core.health_bonus = 20
	core.armor_bonus = 2
	
	# This property is inherited from Equipment.gd - no need to redeclare
	core.allowed_unit_classes = ["warrior"]  # Only warriors can use warrior cores
	return core

static func create_archer_core() -> Core:
	"""Factory method for archer core"""
	var core = Core.new()
	core.equipment_name = "Ranger Combat Core"
	core.manufacturer = "Precision Systems"
	core.description = "Advanced targeting and mobility systems"
	core.cost = 0
	core.power_draw = 0
	
	core.unit_class = "archer"
	core.primary_ability = "Eagle Eye"
	core.ability_description = "Grants bonus accuracy and range for next shot"
	core.ability_cooldown = 4
	
	core.base_health = 90
	core.base_movement = 4
	core.base_armor = 1
	core.base_initiative = 12
	
	# Archer bonuses
	core.speed_bonus = 1
	core.accuracy_bonus = 10
	core.range_bonus = 1
	
	core.allowed_unit_classes = ["archer"]
	return core

static func create_assassin_core() -> Core:
	"""Factory method for new assassin core"""
	var core = Core.new()
	core.equipment_name = "Stealth Combat Core"
	core.manufacturer = "Shadow Operations"
	core.description = "Advanced stealth and precision strike systems"
	core.cost = 0
	core.power_draw = 0
	
	core.unit_class = "assassin"
	core.primary_ability = "Shadow Strike"
	core.ability_description = "Teleport to target and deal massive damage"
	core.ability_cooldown = 6
	
	core.base_health = 80
	core.base_movement = 5
	core.base_armor = 0
	core.base_initiative = 15
	
	# Assassin bonuses - high mobility, high crit, low armor
	core.speed_bonus = 2
	core.evasion_bonus = 15
	core.accuracy_bonus = 5
	
	core.allowed_unit_classes = ["assassin"]
	return core

static func create_hound_core() -> Core:
	"""Factory method for hound core"""
	var core = Core.new()
	core.equipment_name = "Predator Combat Core"
	core.manufacturer = "BioWar Systems"
	core.description = "Enhanced combat instincts and pack coordination"
	core.cost = 0
	core.power_draw = 0
	
	core.unit_class = "hound"
	core.primary_ability = "Pack Hunt"
	core.ability_description = "Coordinate attacks with nearby pack members"
	core.ability_cooldown = 4
	
	core.base_health = 110
	core.base_movement = 3
	core.base_armor = 1
	core.base_initiative = 11
	
	# Hound bonuses - balanced combat stats
	core.health_bonus = 15
	core.armor_bonus = 1
	core.accuracy_bonus = 3
	
	core.allowed_unit_classes = ["hound"]
	return core
