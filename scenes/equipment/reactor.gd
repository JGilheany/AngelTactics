# Reactor.gd - Power generation equipment
class_name Reactor
extends Equipment

@export_group("Reactor Properties")
@export var power_output: int = 10  # How much power this reactor provides
@export var efficiency: float = 1.0  # Power efficiency multiplier

func _init():
	# Reactors have negative power_draw since they provide power
	power_draw = -power_output
	# Reactors typically make units slower due to weight
	speed_bonus = -1

static func create_basic_reactor() -> Reactor:
	"""Factory method for basic reactor"""
	var reactor = Reactor.new()
	reactor.equipment_name = "Basic Reactor"
	reactor.manufacturer = "PowerCore Systems"
	reactor.description = "Standard fusion reactor providing reliable power"
	reactor.cost = 300
	reactor.power_output = 12
	reactor.speed_bonus = -1  # Weight penalty
	return reactor
