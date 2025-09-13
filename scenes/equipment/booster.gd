# Booster.gd - Movement and evasion enhancement

class_name Booster
extends Equipment

@export_group("Booster Properties")
@export var movement_bonus: int = 0  # Additional movement points per turn

static func create_basic_booster() -> Booster:
	"""Factory method for basic booster"""
	var booster = Booster.new()
	booster.equipment_name = "Basic Booster"
	booster.manufacturer = "Swift Systems"
	booster.description = "Enhances mobility and evasion capabilities"
	booster.cost = 200
	booster.power_draw = 3
	booster.speed_bonus = 1
	booster.evasion_bonus = 5
	booster.movement_bonus = 1
	return booster
