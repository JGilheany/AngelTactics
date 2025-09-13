# InventoryManager.gd - Manages base inventory, equipment storage, and resources
class_name InventoryManager
extends RefCounted
signal inventory_changed
signal money_changed(old_amount: int, new_amount: int)
signal equipment_added(equipment_name: String, quantity: int)
signal equipment_removed(equipment_name: String, quantity: int)
signal loot_collected(loot_items: Array)

# =============================================
# INVENTORY STORAGE
# =============================================
# Dictionary storing equipment name -> quantity
var equipment_inventory: Dictionary = {}
# Current money/credits
var money: int = 1000
# Loot items with additional metadata (rarity, source, etc.)
var loot_inventory: Array[Dictionary] = []
# Maximum storage capacity (0 = unlimited)
var max_inventory_slots: int = 0
var max_money: int = 999999

# =============================================
# INITIALIZATION
# =============================================
func _init():
	"""Initialize inventory with starting equipment"""
	# Give player some starting equipment
	add_equipment("assault_rifle", 2)
	add_equipment("knife", 4)
	add_equipment("basic_armor", 3)
	add_equipment("basic_reactor", 2)
	add_equipment("warrior_core", 1)
	add_equipment("archer_core", 1)

# =============================================
# MONEY MANAGEMENT
# =============================================
func add_money(amount: int) -> bool:
	"""Add money to inventory, returns true if successful"""
	if amount <= 0:
		return false
	
	var old_money = money
	money = min(money + amount, max_money)
	money_changed.emit(old_money, money)
	return true

func remove_money(amount: int) -> bool:
	"""Remove money from inventory, returns true if successful"""
	if amount <= 0 or money < amount:
		return false
	
	var old_money = money
	money -= amount
	money_changed.emit(old_money, money)
	return true

func can_afford(cost: int) -> bool:
	"""Check if player can afford the given cost"""
	return money >= cost

func get_money() -> int:
	"""Get current money amount"""
	return money

func set_money(amount: int) -> void:
	"""Set money to specific amount (for save/load)"""
	var old_money = money
	money = clamp(amount, 0, max_money)
	money_changed.emit(old_money, money)

# =============================================
# EQUIPMENT INVENTORY
# =============================================
func add_equipment(equipment_name: String, quantity: int = 1) -> bool:
	"""Add equipment to inventory"""
	if quantity <= 0:
		return false
	
	# Check inventory space if limited
	if max_inventory_slots > 0:
		var current_slots = get_total_equipment_count()
		if current_slots + quantity > max_inventory_slots:
			return false
	
	if equipment_inventory.has(equipment_name):
		equipment_inventory[equipment_name] += quantity
	else:
		equipment_inventory[equipment_name] = quantity
	
	equipment_added.emit(equipment_name, quantity)
	inventory_changed.emit()
	return true

func remove_equipment(equipment_name: String, quantity: int = 1) -> bool:
	"""Remove equipment from inventory"""
	if quantity <= 0:
		return false
	
	if not equipment_inventory.has(equipment_name):
		return false
	
	if equipment_inventory[equipment_name] < quantity:
		return false
	
	equipment_inventory[equipment_name] -= quantity
	
	# Remove entry if quantity reaches 0
	if equipment_inventory[equipment_name] <= 0:
		equipment_inventory.erase(equipment_name)
	
	equipment_removed.emit(equipment_name, quantity)
	inventory_changed.emit()
	return true

func has_equipment(equipment_name: String, quantity: int = 1) -> bool:
	"""Check if inventory contains specified equipment and quantity"""
	if not equipment_inventory.has(equipment_name):
		return false
	return equipment_inventory[equipment_name] >= quantity

func get_equipment_count(equipment_name: String) -> int:
	"""Get quantity of specific equipment"""
	if equipment_inventory.has(equipment_name):
		return equipment_inventory[equipment_name]
	return 0

func get_total_equipment_count() -> int:
	"""Get total number of equipment items"""
	var total = 0
	for quantity in equipment_inventory.values():
		total += quantity
	return total

func get_all_equipment() -> Dictionary:
	"""Get copy of equipment inventory"""
	return equipment_inventory.duplicate()

func get_equipment_by_type(equipment_type: String) -> Array[String]:
	"""Get all equipment names of specific type"""
	var filtered_equipment: Array[String] = []
	
	for equipment_name in equipment_inventory.keys():
		var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
		if equipment and equipment.has_tag(equipment_type):
			filtered_equipment.append(equipment_name)
	
	return filtered_equipment

# =============================================
# LOOT SYSTEM
# =============================================
func add_loot(loot_data: Dictionary) -> bool:
	"""
	Add loot item with metadata
	loot_data format: {
		equipment_name: String,
		quantity: int,
		rarity: String,
		source: String,
		value_modifier: float
	}
	"""
	if not loot_data.has("equipment_name") or not loot_data.has("quantity"):
		return false
	
	# Add to regular inventory
	var success = add_equipment(loot_data.equipment_name, loot_data.quantity)
	if success:
		# Store loot metadata
		var loot_entry = {
			"equipment_name": loot_data.equipment_name,
			"quantity": loot_data.quantity,
			"rarity": loot_data.get("rarity", "common"),
			"source": loot_data.get("source", "unknown"),
			"value_modifier": loot_data.get("value_modifier", 1.0),
			"timestamp": Time.get_unix_time_from_system()
		}
		loot_inventory.append(loot_entry)
	
	return success

func collect_enemy_loot(enemy_unit, loot_table: Dictionary = {}) -> Array[Dictionary]:
	"""
	Generate and collect loot from defeated enemy
	Returns array of loot items collected
	"""
	var collected_loot: Array[Dictionary] = []
	
	# Default loot table if none provided
	if loot_table.is_empty():
		loot_table = get_default_loot_table(enemy_unit)
	
	# Generate loot based on probability
	for loot_item in loot_table.keys():
		var loot_chance = loot_table[loot_item].get("chance", 0.1)
		var loot_quantity = loot_table[loot_item].get("quantity", 1)
		var loot_rarity = loot_table[loot_item].get("rarity", "common")
		
		if randf() <= loot_chance:
			var loot_data = {
				"equipment_name": loot_item,
				"quantity": loot_quantity,
				"rarity": loot_rarity,
				"source": enemy_unit.unit_name if enemy_unit else "enemy",
				"value_modifier": get_rarity_value_modifier(loot_rarity)
			}
			
			if add_loot(loot_data):
				collected_loot.append(loot_data)
	
	if not collected_loot.is_empty():
		loot_collected.emit(collected_loot)
	
	return collected_loot

func get_default_loot_table(enemy_unit) -> Dictionary:
	"""Generate default loot table based on enemy type"""
	var loot_table = {}
	
	# Basic loot for all enemies
	loot_table["knife"] = {"chance": 0.3, "quantity": 1, "rarity": "common"}
	loot_table["basic_accessory"] = {"chance": 0.2, "quantity": 1, "rarity": "common"}
	
	# Unit-class specific loot
	if enemy_unit and enemy_unit.has_method("get") and enemy_unit.unit_class:
		match enemy_unit.unit_class:
			"warrior":
				loot_table["assault_rifle"] = {"chance": 0.15, "quantity": 1, "rarity": "uncommon"}
				loot_table["basic_armor"] = {"chance": 0.25, "quantity": 1, "rarity": "common"}
			"archer":
				loot_table["basic_sensor"] = {"chance": 0.2, "quantity": 1, "rarity": "common"}
				loot_table["basic_booster"] = {"chance": 0.15, "quantity": 1, "rarity": "uncommon"}
			"hound":
				# Hounds drop money instead of equipment
				return {}
	
	return loot_table

func get_rarity_value_modifier(rarity: String) -> float:
	"""Get value multiplier based on rarity"""
	match rarity:
		"common": return 1.0
		"uncommon": return 1.5
		"rare": return 2.0
		"epic": return 3.0
		"legendary": return 5.0
		_: return 1.0

func get_loot_history(limit: int = -1) -> Array[Dictionary]:
	"""Get recent loot history, optionally limited"""
	if limit > 0:
		return loot_inventory.slice(-limit)
	return loot_inventory.duplicate()

func clear_loot_history() -> void:
	"""Clear loot history (keeps items in inventory)"""
	loot_inventory.clear()

# =============================================
# BUYING AND SELLING
# =============================================
func buy_equipment(equipment_name: String, quantity: int = 1) -> bool:
	"""Buy equipment from shop"""
	var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
	if not equipment:
		return false
	
	var total_cost = equipment.cost * quantity
	if not can_afford(total_cost):
		return false
	
	if not add_equipment(equipment_name, quantity):
		return false
	
	remove_money(total_cost)
	return true

func sell_equipment(equipment_name: String, quantity: int = 1, sell_price_modifier: float = 0.5) -> bool:
	"""Sell equipment for money"""
	if not has_equipment(equipment_name, quantity):
		return false
	
	var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
	if not equipment:
		return false
	
	var sell_value = int(equipment.cost * quantity * sell_price_modifier)
	
	if remove_equipment(equipment_name, quantity):
		add_money(sell_value)
		return true
	
	return false

func get_sell_value(equipment_name: String, quantity: int = 1, sell_price_modifier: float = 0.5) -> int:
	"""Calculate sell value for equipment"""
	var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
	if not equipment:
		return 0
	
	return int(equipment.cost * quantity * sell_price_modifier)

# =============================================
# INVENTORY ANALYSIS
# =============================================
func get_inventory_value() -> int:
	"""Calculate total value of all equipment in inventory"""
	var total_value = 0
	
	for equipment_name in equipment_inventory.keys():
		var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
		if equipment:
			total_value += equipment.cost * equipment_inventory[equipment_name]
	
	return total_value

func get_inventory_summary() -> Dictionary:
	"""Get summary statistics of inventory"""
	var summary = {
		"total_equipment_items": get_total_equipment_count(),
		"unique_equipment_types": equipment_inventory.size(),
		"total_inventory_value": get_inventory_value(),
		"current_money": money,
		"total_wealth": money + get_inventory_value(),
		"loot_items_collected": loot_inventory.size(),
		"inventory_slots_used": get_total_equipment_count(),
		"inventory_slots_remaining": max(0, max_inventory_slots - get_total_equipment_count()) if max_inventory_slots > 0 else -1
	}
	return summary

func get_equipment_by_category() -> Dictionary:
	"""Group equipment by type/category"""
	var categories = {
		"weapons": [],
		"armor": [],
		"cores": [],
		"accessories": [],
		"other": []
	}
	
	for equipment_name in equipment_inventory.keys():
		var equipment = EquipmentManager.create_equipment_by_name(equipment_name)
		if equipment:
			if equipment is Weapon:
				categories.weapons.append({
					"name": equipment_name,
					"quantity": equipment_inventory[equipment_name],
					"equipment": equipment
				})
			elif equipment.has_tag("armor"):
				categories.armor.append({
					"name": equipment_name,
					"quantity": equipment_inventory[equipment_name],
					"equipment": equipment
				})
			elif equipment.has_tag("core"):
				categories.cores.append({
					"name": equipment_name,
					"quantity": equipment_inventory[equipment_name],
					"equipment": equipment
				})
			elif equipment.has_tag("accessory"):
				categories.accessories.append({
					"name": equipment_name,
					"quantity": equipment_inventory[equipment_name],
					"equipment": equipment
				})
			else:
				categories.other.append({
					"name": equipment_name,
					"quantity": equipment_inventory[equipment_name],
					"equipment": equipment
				})
	
	return categories

# =============================================
# SAVE/LOAD SUPPORT
# =============================================
func to_dict() -> Dictionary:
	"""Convert inventory to dictionary for saving"""
	return {
		"equipment_inventory": equipment_inventory,
		"money": money,
		"loot_inventory": loot_inventory,
		"max_inventory_slots": max_inventory_slots,
		"max_money": max_money
	}

func from_dict(data: Dictionary) -> void:
	"""Load inventory from dictionary"""
	equipment_inventory = data.get("equipment_inventory", {})
	money = data.get("money", 0)
	loot_inventory = data.get("loot_inventory", [])
	max_inventory_slots = data.get("max_inventory_slots", 0)
	max_money = data.get("max_money", 999999)
	inventory_changed.emit()

# =============================================
# DEBUG AND TESTING
# =============================================
func add_debug_items() -> void:
	"""Add various items for testing"""
	add_equipment("assault_rifle", 5)
	add_equipment("grenade_launcher", 2)
	add_equipment("basic_armor", 10)
	add_equipment("warrior_core", 3)
	add_equipment("archer_core", 2)
	add_equipment("assassin_core", 1)
	add_money(5000)

func print_inventory() -> void:
	"""Debug print current inventory"""
	print("=== INVENTORY ===")
	print("Money: ", money)
	print("Equipment:")
	for equipment_name in equipment_inventory.keys():
		print("  ", equipment_name, ": ", equipment_inventory[equipment_name])
	print("Total Value: ", get_inventory_value())
	print("================")


func _on_timer_timeout() -> void:
	pass # Replace with function body.
