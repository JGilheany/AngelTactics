# SquadManager.gd - Fixed version with proper unit_id handling
extends Node

signal squad_changed
signal unit_added(unit: Unit)
signal unit_removed(unit: Unit)
signal unit_modified(unit: Unit)

# Squad storage
var squad_units: Array[Dictionary] = []  # Store as dictionaries for persistence
var max_squad_size: int = 8
var next_unit_id: int = 1

# Mission integration
var deployed_squad: Array[Dictionary] = []  # Squad sent on current mission

func _ready():
	"""Initialize squad manager"""
	print("SquadManager initialized as singleton")

# =============================================
# SQUAD MANAGEMENT
# =============================================

func add_unit_to_squad(unit_data: Dictionary) -> bool:
	"""Add a unit to the squad"""
	print("SquadManager: Adding unit to squad - ", unit_data.get("unit_name", "Unknown"))
	
	if squad_units.size() >= max_squad_size:
		print("SquadManager: Squad is full, cannot add unit")
		return false
	
	# Assign unique ID if not present
	if not unit_data.has("unit_id") or unit_data.get("unit_id", -1) <= 0:
		unit_data["unit_id"] = next_unit_id
		next_unit_id += 1
		print("SquadManager: Assigned unique ID: ", unit_data["unit_id"])
	
	squad_units.append(unit_data)
	print("SquadManager: Squad size now: ", squad_units.size())
	
	squad_changed.emit()
	print("SquadManager: Emitted squad_changed signal")
	return true

func remove_unit_from_squad(unit_id: int) -> bool:
	"""Remove a unit from the squad by ID"""
	print("SquadManager: Removing unit with ID: ", unit_id)
	
	for i in range(squad_units.size()):
		if squad_units[i].get("unit_id", -1) == unit_id:
			var removed_unit_data = squad_units[i]
			squad_units.remove_at(i)
			print("SquadManager: Removed unit: ", removed_unit_data.get("unit_name", "Unknown"))
			squad_changed.emit()
			return true
	
	print("SquadManager: Warning - Could not find unit to remove with ID: ", unit_id)
	return false

func update_unit_in_squad(unit: Unit) -> bool:
	"""Update a unit's data in the squad"""
	print("SquadManager: Updating unit: ", unit.unit_name, " (ID: ", unit.unit_id, ")")
	
	if unit.unit_id <= 0:
		print("SquadManager: Unit has invalid ID, cannot update")
		return false
	
	for i in range(squad_units.size()):
		var stored_id = squad_units[i].get("unit_id", -1)
		if stored_id == unit.unit_id:
			print("SquadManager: Found unit to update at index: ", i)
			squad_units[i] = unit_to_dictionary(unit)
			squad_changed.emit()
			print("SquadManager: Unit updated successfully")
			return true
	
	print("SquadManager: Could not find unit with ID: ", unit.unit_id)
	print("SquadManager: Available units in squad:")
	for unit_data in squad_units:
		print("  - Name: ", unit_data.get("unit_name", "Unknown"), ", ID: ", unit_data.get("unit_id", -1))
	return false

func get_squad_units() -> Array[Dictionary]:
	"""Get copy of all squad units as dictionaries"""
	print("SquadManager: Getting squad units, count: ", squad_units.size())
	return squad_units.duplicate(true)

func get_squad_unit_objects() -> Array[Unit]:
	"""Get squad units as Unit objects (for immediate use)"""
	print("SquadManager: Converting ", squad_units.size(), " units to objects")
	var units: Array[Unit] = []
	for unit_data in squad_units:
		var unit = create_unit_from_data(unit_data)
		units.append(unit)
	return units

func get_squad_size() -> int:
	"""Get current squad size"""
	return squad_units.size()

func is_squad_full() -> bool:
	"""Check if squad is at capacity"""
	return squad_units.size() >= max_squad_size

func clear_squad():
	"""Clear all units from squad"""
	squad_units.clear()
	squad_changed.emit()

# =============================================
# UNIT DATA CONVERSION
# =============================================

func unit_to_dictionary(unit: Unit) -> Dictionary:
	"""Convert Unit object to dictionary for storage"""
	print("SquadManager: Converting unit to dictionary: ", unit.unit_name, " (current ID: ", unit.unit_id, ")")
	
	# Always ensure unit has a valid unique ID
	if unit.unit_id <= 0:
		unit.unit_id = next_unit_id
		next_unit_id += 1
		print("SquadManager: Assigned new unique ID: ", unit.unit_id)
	
	var unit_data = {
		"unit_id": unit.unit_id,
		"unit_name": unit.unit_name,
		"team": unit.team,
		"unit_class": unit.unit_class,
		"experience": unit.experience,
		"unit_color": {
			"r": unit.unit_color.r,
			"g": unit.unit_color.g,
			"b": unit.unit_color.b,
			"a": unit.unit_color.a
		},
		"wrvss": {
			"wisdom": unit.wisdom,
			"rage": unit.rage,
			"virtue": unit.virtue,
			"strength": unit.strength,
			"steel": unit.steel
		},
		"equipment": {}
	}
	
	# Store equipment names for recreation with debug output
	if unit.core_equipment:
		var name = find_equipment_name(unit.core_equipment)
		unit_data.equipment["core"] = name
		print("SquadManager: Stored core equipment: ", name, " (", unit.core_equipment.equipment_name, ")")
	if unit.primary_weapon:
		var name = find_equipment_name(unit.primary_weapon)
		unit_data.equipment["primary_weapon"] = name
		print("SquadManager: Stored primary weapon: ", name, " (", unit.primary_weapon.equipment_name, ")")
	if unit.sidearm:
		var name = find_equipment_name(unit.sidearm)
		unit_data.equipment["sidearm"] = name
		print("SquadManager: Stored sidearm: ", name, " (", unit.sidearm.equipment_name, ")")
	if unit.booster:
		var name = find_equipment_name(unit.booster)
		unit_data.equipment["booster"] = name
		print("SquadManager: Stored booster: ", name, " (", unit.booster.equipment_name, ")")
	if unit.reactor:
		var name = find_equipment_name(unit.reactor)
		unit_data.equipment["reactor"] = name
		print("SquadManager: Stored reactor: ", name, " (", unit.reactor.equipment_name, ")")
	if unit.sensors:
		var name = find_equipment_name(unit.sensors)
		unit_data.equipment["sensors"] = name
		print("SquadManager: Stored sensors: ", name, " (", unit.sensors.equipment_name, ")")
	if unit.armor_equipment:
		var name = find_equipment_name(unit.armor_equipment)
		unit_data.equipment["armor"] = name
		print("SquadManager: Stored armor: ", name, " (", unit.armor_equipment.equipment_name, ")")
	if unit.accessory_1:
		var name = find_equipment_name(unit.accessory_1)
		unit_data.equipment["accessory_1"] = name
		print("SquadManager: Stored accessory_1: ", name, " (", unit.accessory_1.equipment_name, ")")
	if unit.accessory_2:
		var name = find_equipment_name(unit.accessory_2)
		unit_data.equipment["accessory_2"] = name
		print("SquadManager: Stored accessory_2: ", name, " (", unit.accessory_2.equipment_name, ")")
	
	print("SquadManager: Unit dictionary created with ID: ", unit_data.unit_id)
	return unit_data

func create_unit_from_data(unit_data: Dictionary) -> Unit:
	"""Create Unit object from dictionary data"""
	var unit_name = unit_data.get("unit_name", "Unknown")
	var stored_id = unit_data.get("unit_id", -1)
	print("SquadManager: Creating unit from data: ", unit_name, " with stored ID: ", stored_id)
	
	var unit = Unit.new()
	
	# CRITICAL: Set the unit_id FIRST and verify it worked
	unit.unit_id = stored_id
	print("SquadManager: Set unit_id to: ", unit.unit_id, " for unit: ", unit_name)
	
	# Set basic properties
	unit.unit_name = unit_name
	unit.team = unit_data.get("team", "player")
	unit.unit_class = unit_data.get("unit_class", "warrior")
	unit.experience = unit_data.get("experience", 0)
	
	# Restore color
	var color_data = unit_data.get("unit_color", {"r": 0, "g": 0, "b": 1, "a": 1})
	unit.unit_color = Color(color_data.r, color_data.g, color_data.b, color_data.a)
	
	# Restore WRVSS stats
	var wrvss = unit_data.get("wrvss", {})
	unit.wisdom = wrvss.get("wisdom", 10)
	unit.rage = wrvss.get("rage", 10)
	unit.virtue = wrvss.get("virtue", 10)
	unit.strength = wrvss.get("strength", 10)
	unit.steel = wrvss.get("steel", 10)
	
	# Restore equipment in the correct order (reactor first for power)
	var equipment_data = unit_data.get("equipment", {})
	print("SquadManager: Restoring equipment for ", unit_name, " in power-safe order:")
	
	# Order: reactor first (for power), then core, then everything else
	var equipment_order = ["reactor", "core", "primary_weapon", "sidearm", "booster", "sensors", "armor", "accessory_1", "accessory_2"]
	
	for slot in equipment_order:
		if equipment_data.has(slot):
			var equipment_name = equipment_data[slot]
			print("SquadManager: Attempting to restore ", slot, " with factory name: ", equipment_name)
			var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
			if equipment:
				var result = unit.equip_item(equipment, slot)
				if result.success:
					print("SquadManager: Successfully equipped ", equipment_name, " to ", slot, " -> ", equipment.equipment_name)
				else:
					print("SquadManager: Failed to equip ", equipment_name, " to ", slot, ": ", result.message)
			else:
				print("SquadManager: ERROR - Could not create equipment from factory name: ", equipment_name)
	
	print("SquadManager: Final unit created - Name: ", unit.unit_name, ", ID: ", unit.unit_id)
	return unit

func find_equipment_name(equipment: Equipment) -> String:
	"""Find the equipment name for a given Equipment object"""
	print("SquadManager: Looking for equipment name for: ", equipment.equipment_name)
	
	for equipment_name in EquipmentManager.get_all_equipment_names():
		var test_equipment = EquipmentManager.create_equipment_by_name(equipment_name)
		if test_equipment and test_equipment.equipment_name == equipment.equipment_name:
			print("SquadManager: Found match! Factory name: ", equipment_name, " -> Display name: ", equipment.equipment_name)
			return equipment_name
	
	print("SquadManager: ERROR - No factory name found for equipment: ", equipment.equipment_name)
	return ""

# =============================================
# MISSION INTEGRATION
# =============================================

func deploy_squad_for_mission() -> Array[Dictionary]:
	"""Prepare squad for mission deployment"""
	deployed_squad = squad_units.duplicate(true)
	return deployed_squad

func get_deployed_squad() -> Array[Dictionary]:
	"""Get the currently deployed squad"""
	return deployed_squad.duplicate(true)

func return_squad_from_mission(updated_squad: Array[Dictionary]):
	"""Update squad with post-mission data"""
	if updated_squad.size() != deployed_squad.size():
		print("Warning: Squad size changed during mission")
	
	# Update squad with mission results
	squad_units = updated_squad.duplicate(true)
	deployed_squad.clear()
	squad_changed.emit()

func is_squad_deployed() -> bool:
	"""Check if squad is currently on a mission"""
	return not deployed_squad.is_empty()

# =============================================
# SAVE/LOAD SYSTEM
# =============================================

func save_squad_data() -> Dictionary:
	"""Save squad data for persistence"""
	return {
		"squad_units": squad_units.duplicate(true),
		"max_squad_size": max_squad_size,
		"next_unit_id": next_unit_id,
		"deployed_squad": deployed_squad.duplicate(true)
	}

func load_squad_data(data: Dictionary):
	"""Load squad data from save file"""
	squad_units = data.get("squad_units", [])
	max_squad_size = data.get("max_squad_size", 8)
	next_unit_id = data.get("next_unit_id", 1)
	deployed_squad = data.get("deployed_squad", [])
	squad_changed.emit()

# =============================================
# UTILITY FUNCTIONS
# =============================================

func get_squad_composition() -> Dictionary:
	"""Get squad composition by class"""
	var composition = {}
	for unit_data in squad_units:
		var unit_class = unit_data.get("unit_class", "unknown")
		if composition.has(unit_class):
			composition[unit_class] += 1
		else:
			composition[unit_class] = 1
	return composition

func validate_squad() -> Dictionary:
	"""Validate entire squad for deployment"""
	var validation = {
		"is_valid": true,
		"issues": [],
		"warnings": []
	}
	
	if squad_units.is_empty():
		validation.is_valid = false
		validation.issues.append("No units in squad")
		return validation
	
	# Validate each unit
	for unit_data in squad_units:
		var unit = create_unit_from_data(unit_data)
		var unit_validation = EquipmentManager.validate_loadout(unit)
		
		if not unit_validation.is_valid:
			validation.is_valid = false
			for issue in unit_validation.issues:
				validation.issues.append("%s: %s" % [unit.unit_name, issue])
		
		for warning in unit_validation.warnings:
			validation.warnings.append("%s: %s" % [unit.unit_name, warning])
	
	return validation

func get_total_squad_value() -> int:
	"""Calculate total value of all squad equipment"""
	var total_value = 0
	for unit_data in squad_units:
		var unit = create_unit_from_data(unit_data)
		var equipment_list = [unit.core_equipment, unit.primary_weapon, unit.sidearm,
							  unit.booster, unit.reactor, unit.sensors, unit.armor_equipment,
							  unit.accessory_1, unit.accessory_2]
		
		for equipment in equipment_list:
			if equipment:
				total_value += equipment.cost
	
	return total_value
