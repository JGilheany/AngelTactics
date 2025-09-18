# StorageKeeperNPC.gd - Specific NPC for storage room
class_name StorageKeeperNPC
extends BaseNPC

signal storage_interface_requested(npc: StorageKeeperNPC)

func _ready():
	"""Initialize storage keeper"""
	# Set NPC properties
	npc_name = "Storage Keeper"
	npc_role = "Inventory Manager"
	npc_color = Color.ORANGE
	
	# Set specific dialogue
	dialogue_lines = [
		"Welcome to the storage bay. All your equipment and supplies are catalogued here.",
		"Need to check your inventory? I've got everything organized for you.",
		"Don't worry about losing anything - I keep track of every piece of gear.",
		"Looking for something specific? I can help you find it in the system.",
		"All equipment is sorted by type and condition. Very efficient!"
	]
	
	super._ready()

func on_interact():
	"""Handle storage keeper specific interaction"""
	print("Storage Keeper: ", get_current_dialogue())
	
	# Request storage interface to be opened
	storage_interface_requested.emit(self)

func get_item_specific_dialogue(equipment_name: String) -> String:
	"""Get dialogue specific to an equipment item"""
	var item_dialogues = {
		"assault_rifle": "That's a reliable assault rifle. Standard issue for warriors.",
		"knife": "A trusty combat knife. Every operative should carry one.",
		"basic_armor": "Basic protective gear. It'll keep you safe in light combat.",
		"warrior_core": "A warrior core unit. These provide excellent combat capabilities.",
		"archer_core": "An archer core with enhanced targeting systems.",
		"grenade_launcher": "Heavy ordinance. Use with extreme caution!"
	}
	
	if item_dialogues.has(equipment_name):
		return item_dialogues[equipment_name]
	else:
		return "That's a " + equipment_name.replace("_", " ") + ". A solid piece of equipment."

func provide_inventory_summary(inventory_manager: InventoryManager) -> String:
	"""Generate dialogue about current inventory status"""
	if not inventory_manager:
		return "I can't access the inventory system right now."
	
	var summary = inventory_manager.get_inventory_summary()
	var total_items = summary.total_equipment_items
	var total_value = summary.total_inventory_value
	var money = summary.current_money
	
	var dialogue_options = [
		"You currently have %d items worth %d credits, plus %d in cash." % [total_items, total_value, money],
		"Your storage contains %d pieces of equipment. Total inventory value is %d credits." % [total_items, total_value],
		"Everything's accounted for: %d items catalogued and secured." % [total_items]
	]
	
	return dialogue_options[randi() % dialogue_options.size()]

func get_category_dialogue(category: String) -> String:
	"""Get dialogue for equipment categories"""
	var category_dialogues = {
		"weapons": "Ah, looking at the weapons cache. All firearms are cleaned and maintained.",
		"armor": "The armor section. All protective gear is inspected and ready for deployment.",
		"cores": "Core units are our most valuable assets. Each one is individually tracked.",
		"accessories": "Accessories and support gear. The small things that make a big difference.",
		"other": "Miscellaneous equipment. Sometimes the most useful items are the unexpected ones."
	}
	
	return category_dialogues.get(category, "That's a good section to browse.")

func react_to_low_inventory(equipment_name: String, quantity: int) -> String:
	"""React when inventory is running low"""
	if quantity <= 1:
		return "You're running low on " + equipment_name.replace("_", " ") + ". Might want to requisition more."
	elif quantity <= 3:
		return "Only %d %s left in storage. Consider restocking soon." % [quantity, equipment_name.replace("_", " ")]
	else:
		return "Good stock of " + equipment_name.replace("_", " ") + " available."

func provide_sell_dialogue(equipment_name: String, quantity: int, sell_value: int) -> String:
	"""Generate dialogue for selling equipment"""
	var item_display_name = equipment_name.replace("_", " ")
	
	var sell_dialogues = [
		"Fair price for the %s. %d credits added to your account." % [item_display_name, sell_value],
		"I can move that %s easily. %d credits, as agreed." % [item_display_name, sell_value],
		"Good choice selling the %s. Market rate is %d credits." % [item_display_name, sell_value],
		"Transaction processed. %d credits for %d %s." % [sell_value, quantity, item_display_name]
	]
	
	# Special cases for certain equipment
	match equipment_name:
		"assault_rifle":
			return "That rifle will find a good home. %d credits transferred." % sell_value
		"knife":
			if quantity > 1:
				return "Those knives are always in demand. %d credits for the lot." % sell_value
			else:
				return "A good blade. %d credits, fair and square." % sell_value
		"warrior_core", "archer_core", "assassin_core":
			return "Core units are valuable. %d credits - you made a smart sale." % sell_value
		"basic_armor":
			return "Armor's always needed. %d credits, standard rate." % sell_value
		_:
			return sell_dialogues[randi() % sell_dialogues.size()]

func provide_inventory_status_dialogue(total_items: int, total_value: int) -> String:
	"""Generate dialogue about overall inventory status"""
	var status_dialogues = [
		"You've got %d items worth %d credits total. Well stocked!" % [total_items, total_value],
		"Current inventory: %d pieces, valued at %d credits." % [total_items, total_value],
		"Storage status: %d items catalogued, %d credits in equipment value." % [total_items, total_value]
	]
	
	# Add contextual comments based on inventory size
	if total_items < 5:
		status_dialogues.append("Running light on supplies. Might want to stock up soon.")
	elif total_items > 50:
		status_dialogues.append("Quite the collection you have there. Storage efficiency at maximum!")
	
	if total_value < 1000:
		status_dialogues.append("Starting inventory. Build it up as you complete missions.")
	elif total_value > 10000:
		status_dialogues.append("Impressive equipment value. You're well prepared for anything.")
	
	return status_dialogues[randi() % status_dialogues.size()]

func get_low_stock_warning(equipment_name: String, quantity: int) -> String:
	"""Generate warning dialogue for low stock items"""
	if quantity <= 0:
		return "You're completely out of %s. Better requisition more soon." % equipment_name.replace("_", " ")
	elif quantity <= 2:
		return "Only %d %s left. Consider that when planning missions." % [quantity, equipment_name.replace("_", " ")]
	else:
		return ""  # No warning needed
