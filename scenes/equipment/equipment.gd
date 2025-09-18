# Equipment.gd - Base class for all equipment
class_name Equipment
extends Resource

# =============================================
# CORE EQUIPMENT PROPERTIES - Every piece of equipment has these
# =============================================
@export_group("Basic Info")
@export var equipment_name: String = "Basic Equipment"
@export var manufacturer: String = "NA"
@export_multiline var description: String = "NA"
@export var cost: int = 0
@export var power_draw: int = 0

@export_group("Equipment Restrictions")
# Which unit classes can use this equipment (empty array = all units can use it)
@export var allowed_unit_classes: Array = []
# Minimum WRVSS stats required to use this equipment
@export var min_wisdom: int = 0
@export var min_rage: int = 0
@export var min_virtue: int = 0
@export var min_strength: int = 0
@export var min_steel: int = 0

# Equipment tags for special behaviors and restrictions
@export var tags: Array[String] = []

# =============================================
# STAT BONUSES - What this equipment provides to the unit
# =============================================
@export_group("Stat Bonuses")
@export var health_bonus: int = 0
@export var speed_bonus: int = 0
@export var armor_bonus: int = 0
@export var evasion_bonus: int = 0
@export var accuracy_bonus: int = 0
@export var range_bonus: int = 0

# =============================================
# EQUIPMENT VALIDATION
# =============================================
func can_be_equipped_by_unit(unit) -> Dictionary:
	"""
	Check if this equipment can be equipped by the given unit
	Returns: {can_equip: bool, reason: String}
	"""
	var result = {"can_equip": true, "reason": ""}
	
	# Check unit class restrictions
	if not allowed_unit_classes.is_empty():
		if not unit.unit_class in allowed_unit_classes:
			result.can_equip = false
			result.reason = "Unit class '%s' cannot use this equipment" % unit.unit_class
			return result
	
	# Check WRVSS requirements
	if unit.wisdom < min_wisdom:
		result.can_equip = false
		result.reason = "Requires %d Wisdom (unit has %d)" % [min_wisdom, unit.wisdom]
		return result
		
	if unit.rage < min_rage:
		result.can_equip = false
		result.reason = "Requires %d Rage (unit has %d)" % [min_rage, unit.rage]
		return result
		
	if unit.virtue < min_virtue:
		result.can_equip = false
		result.reason = "Requires %d Virtue (unit has %d)" % [min_virtue, unit.virtue]
		return result
		
	if unit.strength < min_strength:
		result.can_equip = false
		result.reason = "Requires %d Strength (unit has %d)" % [min_strength, unit.strength]
		return result
		
	if unit.steel < min_steel:
		result.can_equip = false
		result.reason = "Requires %d Steel (unit has %d)" % [min_steel, unit.steel]
		return result
	
	return result

func has_tag(tag: String) -> bool:
	"""Check if this equipment has a specific tag"""
	return tag in tags

func get_display_name() -> String:
	"""Get formatted display name for UI"""
	return "%s (%s)" % [equipment_name, manufacturer]

# =============================================
# VIRTUAL METHODS - Override in subclasses for special behaviors
# =============================================
func on_equipped(_unit) -> void:
	"""Called when this equipment is equipped to a unit"""
	pass

func on_unequipped(_unit) -> void:
	"""Called when this equipment is removed from a unit"""
	pass

func on_turn_start(_unit) -> void:
	"""Called at the start of each turn while equipped"""
	pass

func on_turn_end(_unit) -> void:
	"""Called at the end of each turn while equipped"""
	pass
