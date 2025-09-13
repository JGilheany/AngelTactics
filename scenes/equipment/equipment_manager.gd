# EquipmentManager.gd - Manages equipment creation, validation, and inventory
class_name EquipmentManager
extends RefCounted

# =============================================
# EQUIPMENT FACTORY METHODS
# =============================================
static func create_equipment_by_name(equipment_name: String) -> Equipment:
	"""Factory method to create equipment by name string"""
	match equipment_name:
		# Weapons
		"assault_rifle": return Weapon.create_assault_rifle()
		"knife": return Weapon.create_knife() 
		"grenade_launcher": return Weapon.create_grenade_launcher()
		"hound_claws": return Weapon.create_hound_claws()
		
		# Armor
		"basic_armor": return ArmorEquipment.create_basic_armor()
		
		# Boosters
		"basic_booster": return Booster.create_basic_booster()
		
		# Reactors
		"basic_reactor": return Reactor.create_basic_reactor()
		
		# Sensors
		"basic_sensor": return Sensor.create_basic_sensor()
		
		# Accessories
		"basic_accessory": return Accessory.create_basic_accessory()
		"health_regen_accessory": return Accessory.create_health_regen_accessory()
		
		# Cores
		"warrior_core": return Core.create_warrior_core()
		"archer_core": return Core.create_archer_core()
		"assassin_core": return Core.create_assassin_core()
		
		_:
			push_error("Unknown equipment name: " + equipment_name)
			return null

static func get_all_weapon_names() -> Array[String]:
	"""Get list of all available weapon names"""
	return ["assault_rifle", "knife", "grenade_launcher", "hound_claws"]

static func get_all_armor_names() -> Array[String]:
	"""Get list of all available armor names"""
	return ["basic_armor"]

static func get_all_equipment_names() -> Array[String]:
	"""Get list of all available equipment names"""
	return ["assault_rifle", "knife", "grenade_launcher", "hound_claws",
			"basic_armor", "basic_booster", "basic_reactor", "basic_sensor",
			"basic_accessory", "health_regen_accessory",
			"warrior_core", "archer_core", "assassin_core"]

# =============================================
# EQUIPMENT VALIDATION
# =============================================
static func validate_loadout(unit: Unit) -> Dictionary:
	"""
	Validate a unit's equipment loadout for conflicts and power consumption
	Returns: {is_valid: bool, issues: Array[String], warnings: Array[String]}
	"""
	var result = {
		"is_valid": true,
		"issues": [],
		"warnings": []
	}
	
	# Check power consumption vs generation
	var power_consumption = unit.get_total_power_consumption()
	var power_generation = unit.get_total_power_generation()
	
	if power_consumption > power_generation:
		result.is_valid = false
		result.issues.append("Power consumption (%d) exceeds generation (%d)" % [power_consumption, power_generation])
	elif power_consumption == power_generation:
		result.warnings.append("Power consumption at maximum capacity")
	
	# Check for equipment conflicts
	var equipment_list = [
		{"equipment": unit.core_equipment, "slot": "core"},
		{"equipment": unit.primary_weapon, "slot": "primary_weapon"},
		{"equipment": unit.sidearm, "slot": "sidearm"},
		{"equipment": unit.booster, "slot": "booster"},
		{"equipment": unit.reactor, "slot": "reactor"},
		{"equipment": unit.sensors, "slot": "sensors"},
		{"equipment": unit.armor_equipment, "slot": "armor"},
		{"equipment": unit.accessory_1, "slot": "accessory_1"},
		{"equipment": unit.accessory_2, "slot": "accessory_2"}
	]
	
	for item in equipment_list:
		if item.equipment:
			var can_equip = item.equipment.can_be_equipped_by_unit(unit)
			if not can_equip.can_equip:
				result.is_valid = false
				result.issues.append("%s in %s slot: %s" % [item.equipment.equipment_name, item.slot, can_equip.reason])
	
	# Check for missing critical equipment
	if not unit.reactor:
		result.warnings.append("No reactor equipped - limited power available")
	
	if not unit.core_equipment:
		result.is_valid = false
		result.issues.append("No core equipment - unit class undefined")
	
	# Check weapon availability
	if not unit.primary_weapon and not unit.sidearm:
		result.warnings.append("No weapons equipped - unit cannot attack")
	
	return result

# =============================================
# EQUIPMENT COMPARISON AND STATS
# =============================================
static func compare_equipment(equipment1: Equipment, equipment2: Equipment) -> Dictionary:
	"""
	Compare two pieces of equipment and return the differences
	Returns: {better_stats: Array, worse_stats: Array, same_stats: Array}
	"""
	var comparison = {
		"better_stats": [],
		"worse_stats": [],
		"same_stats": []
	}
	
	if not equipment1 or not equipment2:
		return comparison
	
	# Compare common stats
	var stats_to_compare = [
		{"name": "Power Draw", "stat1": equipment1.power_draw, "stat2": equipment2.power_draw, "lower_is_better": true},
		{"name": "Cost", "stat1": equipment1.cost, "stat2": equipment2.cost, "lower_is_better": true},
		{"name": "Health Bonus", "stat1": equipment1.health_bonus, "stat2": equipment2.health_bonus, "lower_is_better": false},
		{"name": "Speed Bonus", "stat1": equipment1.speed_bonus, "stat2": equipment2.speed_bonus, "lower_is_better": false},
		{"name": "Armor Bonus", "stat1": equipment1.armor_bonus, "stat2": equipment2.armor_bonus, "lower_is_better": false},
		{"name": "Evasion Bonus", "stat1": equipment1.evasion_bonus, "stat2": equipment2.evasion_bonus, "lower_is_better": false},
		{"name": "Accuracy Bonus", "stat1": equipment1.accuracy_bonus, "stat2": equipment2.accuracy_bonus, "lower_is_better": false},
		{"name": "Range Bonus", "stat1": equipment1.range_bonus, "stat2": equipment2.range_bonus, "lower_is_better": false}
	]
	
	# Add weapon-specific stats if both are weapons
	if equipment1 is Weapon and equipment2 is Weapon:
		var weapon1 = equipment1 as Weapon
		var weapon2 = equipment2 as Weapon
		stats_to_compare.append_array([
			{"name": "Min Damage", "stat1": weapon1.min_damage, "stat2": weapon2.min_damage, "lower_is_better": false},
			{"name": "Max Damage", "stat1": weapon1.max_damage, "stat2": weapon2.max_damage, "lower_is_better": false},
			{"name": "Weapon Range", "stat1": weapon1.weapon_range, "stat2": weapon2.weapon_range, "lower_is_better": false},
			{"name": "Crit Chance", "stat1": weapon1.crit_chance, "stat2": weapon2.crit_chance, "lower_is_better": false}
		])
	
	# Compare each stat
	for stat in stats_to_compare:
		if stat.stat1 > stat.stat2:
			if stat.lower_is_better:
				comparison.worse_stats.append(stat.name)
			else:
				comparison.better_stats.append(stat.name)
		elif stat.stat1 < stat.stat2:
			if stat.lower_is_better:
				comparison.better_stats.append(stat.name)
			else:
				comparison.worse_stats.append(stat.name)
		else:
			comparison.same_stats.append(stat.name)
	
	return comparison

# =============================================
# EQUIPMENT UPGRADE SYSTEM
# =============================================
static func calculate_upgrade_cost(base_equipment: Equipment, upgrade_level: int) -> int:
	"""Calculate cost to upgrade equipment to specified level"""
	if upgrade_level <= 0:
		return 0
	
	var base_cost = base_equipment.cost
	var upgrade_cost = 0
	
	for level in range(1, upgrade_level + 1):
		upgrade_cost += int(base_cost * (0.5 * level))  # Each level costs 50% of base per level
	
	return upgrade_cost

static func create_upgraded_equipment(base_equipment: Equipment, upgrade_level: int) -> Equipment:
	"""Create an upgraded version of the base equipment"""
	if upgrade_level <= 0:
		return base_equipment
	
	# This is a simplified upgrade system - you could make it more sophisticated
	var upgraded = base_equipment.duplicate()
	
	# Apply upgrades based on equipment type
	if upgraded is Weapon:
		var weapon = upgraded as Weapon
		weapon.min_damage += upgrade_level * 2
		weapon.max_damage += upgrade_level * 3
		weapon.weapon_accuracy += upgrade_level
		weapon.crit_chance += upgrade_level
		weapon.equipment_name += " +" + str(upgrade_level)
		
	elif upgraded is ArmorEquipment:
		var armor = upgraded as ArmorEquipment
		armor.health_bonus += upgrade_level * 5
		armor.armor_bonus += upgrade_level
		armor.damage_reduction += upgrade_level
		armor.equipment_name += " +" + str(upgrade_level)
		
	elif upgraded is Booster:
		var booster = upgraded as Booster
		booster.speed_bonus += upgrade_level
		booster.evasion_bonus += upgrade_level * 2
		if booster.has_method("movement_bonus"):
			booster.movement_bonus += upgrade_level
		booster.equipment_name += " +" + str(upgrade_level)
	
	# Update cost to reflect upgrade
	upgraded.cost = base_equipment.cost + calculate_upgrade_cost(base_equipment, upgrade_level)
	
	return upgraded

# =============================================
# EQUIPMENT PRESET LOADOUTS
# =============================================
static func get_preset_loadout(loadout_name: String) -> Dictionary:
	"""
	Get predefined equipment loadouts for different roles
	Returns: {equipment_names: Dictionary, description: String}
	"""
	match loadout_name:
		"balanced_warrior":
			return {
				"description": "Well-rounded warrior setup for frontline combat",
				"equipment_names": {
					"core": "warrior_core",
					"primary_weapon": "assault_rifle",
					"sidearm": "knife",
					"reactor": "basic_reactor",
					"booster": "basic_booster",
					"sensors": "basic_sensor",
					"armor": "basic_armor",
					"accessory_1": "basic_accessory"
				}
			}
		
		"stealth_assassin":
			return {
				"description": "Optimized for stealth operations and critical strikes",
				"equipment_names": {
					"core": "assassin_core",
					"primary_weapon": null,  # Assassins rely on stealth
					"sidearm": "knife",
					"reactor": "basic_reactor",
					"booster": "basic_booster", 
					"sensors": "basic_sensor",
					"armor": "basic_armor",  # Would be modified for stealth
					"accessory_1": "basic_accessory"
				}
			}
		
		"support_archer":
			return {
				"description": "Long-range support with mobility focus",
				"equipment_names": {
					"core": "archer_core",
					"primary_weapon": "assault_rifle",
					"sidearm": "knife",
					"reactor": "basic_reactor",
					"booster": "basic_booster",
					"sensors": "basic_sensor",
					"armor": "basic_armor",
					"accessory_1": "basic_accessory"
				}
			}
		
		"heavy_weapons":
			return {
				"description": "Area denial specialist with explosive weapons",
				"equipment_names": {
					"core": "warrior_core",
					"primary_weapon": "grenade_launcher",
					"sidearm": "knife",
					"reactor": "basic_reactor",
					"booster": "basic_booster",
					"sensors": "basic_sensor", 
					"armor": "basic_armor",
					"accessory_1": "basic_accessory"
				}
			}
		
		_:
			return {"description": "Unknown loadout", "equipment_names": {}}

static func apply_preset_loadout(unit: Unit, loadout_name: String) -> bool:
	"""Apply a preset loadout to a unit"""
	var loadout = get_preset_loadout(loadout_name)
	if loadout.equipment_names.is_empty():
		return false
	
	var equipment_names = loadout.equipment_names
	
	# Equip each piece of equipment
	for slot in equipment_names:
		var equipment_name = equipment_names[slot]
		if equipment_name:
			var equipment = create_equipment_by_name(equipment_name)
			if equipment:
				var result = unit.equip_item(equipment, slot)
				if not result.success:
					print("Failed to equip %s to %s: %s" % [equipment_name, slot, result.message])
					return false
	
	return true

# =============================================
# EQUIPMENT RANDOMIZATION
# =============================================
static func create_random_weapon(weapon_type: String, quality_level: int = 1) -> Weapon:
	"""Create a randomized weapon with variable stats"""
	var base_weapon: Weapon
	
	match weapon_type:
		"rifle": base_weapon = Weapon.create_assault_rifle()
		"melee": base_weapon = Weapon.create_knife()
		"explosive": base_weapon = Weapon.create_grenade_launcher()
		_: base_weapon = Weapon.create_assault_rifle()
	
	# Apply random variations based on quality level
	var damage_variance = quality_level * 2
	var accuracy_variance = quality_level * 3
	
	base_weapon.min_damage += randi_range(-damage_variance, damage_variance)
	base_weapon.max_damage += randi_range(-damage_variance, damage_variance + 2)
	base_weapon.weapon_accuracy += randi_range(-accuracy_variance, accuracy_variance)
	base_weapon.crit_chance += randi_range(-2, quality_level)
	
	# Ensure minimum values
	base_weapon.min_damage = max(1, base_weapon.min_damage)
	base_weapon.max_damage = max(base_weapon.min_damage + 1, base_weapon.max_damage)
	base_weapon.crit_chance = max(1, base_weapon.crit_chance)
	
	# Add random manufacturer and name variation
	var manufacturers = ["MilTech Corp", "Precision Arms", "Thunder Industries", "Elite Systems"]
	var weapon_prefixes = ["Standard", "Enhanced", "Military", "Tactical", "Advanced"]
	
	base_weapon.manufacturer = manufacturers[randi() % manufacturers.size()]
	base_weapon.equipment_name = weapon_prefixes[randi() % weapon_prefixes.size()] + " " + base_weapon.equipment_name
	
	return base_weapon
