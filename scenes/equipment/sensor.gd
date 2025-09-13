# Sensor.gd - Detection and targeting equipment
# =============================================
class_name Sensor
extends Equipment

@export_group("Sensor Properties")
@export var detection_range: int = 0  # Bonus to detecting hidden enemies
@export var targeting_assist: int = 0  # Bonus to accuracy calculations

static func create_basic_sensor() -> Sensor:
	"""Factory method for basic sensor"""
	var sensor = Sensor.new()
	sensor.equipment_name = "Basic Sensor Array"
	sensor.manufacturer = "OptiTech"
	sensor.description = "Standard targeting and detection system"
	sensor.cost = 250
	sensor.power_draw = 2
	sensor.accuracy_bonus = 10
	sensor.range_bonus = 1
	sensor.detection_range = 2
	sensor.targeting_assist = 5
	return sensor
