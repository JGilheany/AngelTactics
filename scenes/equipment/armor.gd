# Armor.gd - Defensive equipment
# =============================================
class_name ArmorEquipment  # Avoiding name conflict with Unit.armor property
extends Equipment

@export_group("Armor Properties")
@export var damage_reduction: int = 0  # Flat damage reduction
@export var damage_resistance: Dictionary = {}  # Resistance to damage types {"ballistic": 0.1}

static func create_basic_armor() -> ArmorEquipment:
	"""Factory method for basic armor"""
	var armor = ArmorEquipment.new()
	armor.equipment_name = "Basic Combat Armor"
	armor.manufacturer = "DefenseTech"
	armor.description = "Standard issue protective plating"
	armor.cost = 400
	armor.power_draw = 1
	armor.health_bonus = 20
	armor.armor_bonus = 5
	armor.evasion_bonus = -2  # Armor makes you less agile
	armor.damage_reduction = 2
	armor.damage_resistance = {"ballistic": 0.1}  # 10% ballistic resistance
	return armor
