# Accessory.gd - Special effect equipment
# =============================================
class_name Accessory
extends Equipment

@export_group("Accessory Properties")
@export var special_effects: Array[String] = []  # List of special effect IDs

# Override virtual methods for special behaviors
func on_turn_start(unit) -> void:
	"""Apply accessory effects at turn start"""
	for effect in special_effects:
		apply_special_effect(effect, unit, "turn_start")

func on_turn_end(unit) -> void:
	"""Apply accessory effects at turn end"""
	for effect in special_effects:
		apply_special_effect(effect, unit, "turn_end")

func apply_special_effect(effect_id: String, unit, timing: String) -> void:
	"""Apply special effects - extend this in custom accessories"""
	match effect_id:
		"health_regen":
			if timing == "turn_start" and unit.current_health < unit.max_health:
				unit.heal(2)
				print("%s regenerates 2 health from %s" % [unit.unit_name, equipment_name])
		
		"accuracy_boost":
			if timing == "turn_start":
				# Temporary accuracy bonus - you'd implement this in Unit
				print("%s gains accuracy boost from %s" % [unit.unit_name, equipment_name])
		
		_:
			# Unknown effect
			pass

static func create_basic_accessory() -> Accessory:
	"""Factory method for basic accessory"""
	var accessory = Accessory.new()
	accessory.equipment_name = "Basic Utility Pack"
	accessory.manufacturer = "GenTech"
	accessory.description = "Basic utility accessory with minimal effects"
	accessory.cost = 150
	accessory.power_draw = 1
	# No bonuses for basic accessory
	return accessory

static func create_health_regen_accessory() -> Accessory:
	"""Factory method for health regeneration accessory"""
	var accessory = Accessory.new()
	accessory.equipment_name = "Nanites"
	accessory.manufacturer = "BHCorp"
	accessory.description = "Microscopic repair bots that slowly repair equipment"
	accessory.cost = 500
	accessory.power_draw = 2
	accessory.health_bonus = 10
	accessory.special_effects = ["health_regen"]
	return accessory
