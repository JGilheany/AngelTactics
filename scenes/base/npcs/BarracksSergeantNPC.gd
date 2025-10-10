# BarracksSergeantNPC.gd - Barracks NPC extending BaseNPC
class_name BarracksSergeantNPC
extends BaseNPC

signal barracks_interface_requested(npc: BarracksSergeantNPC)

func _ready():
	"""Initialize the barracks sergeant"""
	# Set NPC properties
	npc_name = "Sergeant"
	npc_role = "Squad Commander" 
	npc_color = Color.GREEN
	
	# Set barracks-specific dialogue
	dialogue_lines = [
		"Your units are ready for deployment. Need to check their status?",
		"All personnel accounted for and combat-ready.",
		"Training schedules are up to date, Commander.",
		"Want to review the squad roster and equipment loadouts?",
		"I can help you organize your units for the next mission.",
		"Every soldier under my command is equipped and prepared."
	]
	
	super._ready()

func on_interact():
	"""Handle barracks-specific interaction"""
	print("Sergeant: ", get_current_dialogue())
	
	# Request barracks interface to be opened
	barracks_interface_requested.emit(self)

func get_unit_specific_dialogue(unit: Unit) -> String:
	"""Get dialogue specific to a unit"""
	var unit_dialogues = {
		"warrior": "That's a solid warrior. Good for frontline combat operations.",
		"archer": "An archer with excellent range capabilities. Perfect for support roles.",
		"assassin": "A stealth specialist. They excel at precision elimination missions.",
		"hound": "Fast and aggressive. These units are excellent for reconnaissance."
	}
	
	if unit_dialogues.has(unit.unit_class):
		return unit_dialogues[unit.unit_class]
	else:
		return "That's a fine soldier. They'll serve the squad well."

func provide_squad_summary(squad_units: Array[Unit]) -> String:
	"""Generate dialogue about current squad status"""
	if squad_units.is_empty():
		return "No units assigned yet. We should recruit some soldiers for the squad."
	
	var total_units = squad_units.size()
	var class_counts = {}
	
	# Count units by class
	for unit in squad_units:
		if class_counts.has(unit.unit_class):
			class_counts[unit.unit_class] += 1
		else:
			class_counts[unit.unit_class] = 1
	
	var summary_dialogues = [
		"Squad roster shows %d soldiers ready for deployment." % total_units,
		"We have %d operatives in the current squad composition." % total_units,
		"Current squad strength: %d personnel, all combat-ready." % total_units
	]
	
	# Add composition details
	if class_counts.has("warrior") and class_counts["warrior"] > 0:
		summary_dialogues.append("Good warrior presence in the squad - %d frontline fighters." % class_counts["warrior"])
	if class_counts.has("archer") and class_counts["archer"] > 0:
		summary_dialogues.append("We have %d archers for ranged support." % class_counts["archer"])
	if class_counts.has("assassin") and class_counts["assassin"] > 0:
		summary_dialogues.append("%d stealth specialists for covert operations." % class_counts["assassin"])
	
	return summary_dialogues[randi() % summary_dialogues.size()]

func get_equipment_validation_dialogue(validation: Dictionary) -> String:
	"""Generate dialogue for equipment validation results"""
	if validation.is_valid:
		var positive_responses = [
			"All equipment checks out. Your soldiers are combat-ready.",
			"Loadouts validated. Everyone's gear is properly configured.",
			"Equipment status: green across the board. Well done.",
			"All units properly equipped and powered. Ready for deployment."
		]
		return positive_responses[randi() % positive_responses.size()]
	else:
		var issue_count = validation.issues.size()
		var negative_responses = [
			"I see %d equipment issues that need addressing." % issue_count,
			"Equipment validation failed. We have %d problems to resolve." % issue_count,
			"Some gear needs attention. %d critical issues detected." % issue_count,
			"Can't deploy with these equipment problems. %d items need fixing." % issue_count
		]
		return negative_responses[randi() % negative_responses.size()]

func provide_loadout_advice(unit: Unit) -> String:
	"""Generate dialogue with loadout advice for specific units"""
	if not unit.core_equipment:
		return "That soldier needs a core unit first. Can't function without one."
	
	var power_consumption = unit.get_total_power_consumption()
	var power_generation = unit.get_total_power_generation()
	
	if power_consumption > power_generation:
		return "Power draw is too high on that unit. Need a better reactor or less equipment."
	
	var weapon = unit.get_active_weapon()
	if not weapon:
		return "That soldier has no weapons equipped. They'll be sitting ducks out there."
	
	match unit.unit_class:
		"warrior":
			if not unit.armor_equipment:
				return "Warriors need proper armor. They'll be taking fire on the frontlines."
			else:
				return "That warrior looks ready for combat. Good armor and weapon setup."
		"archer":
			if not unit.sensors:
				return "Archers benefit from enhanced sensors for long-range targeting."
			else:
				return "Solid archer configuration. Range and sensors optimized."
		"assassin":
			if not unit.booster:
				return "Assassins need mobility boosters for stealth positioning."
			else:
				return "Good stealth setup. That assassin should be highly effective."
		_:
			return "Decent loadout overall. Should perform well in standard operations."

func react_to_squad_changes(old_count: int, new_count: int) -> String:
	"""React to changes in squad size"""
	if new_count > old_count:
		return "New soldier added to the roster. I'll make sure they're briefed and ready."
	elif new_count < old_count:
		return "Soldier removed from active duty. Updating squad compositions accordingly."
	else:
		return "Squad roster updated. All personnel accounted for."

func get_mission_readiness_assessment(squad_units: Array[Unit]) -> String:
	"""Assess squad readiness for missions"""
	if squad_units.is_empty():
		return "Can't deploy without any soldiers. Recruit some personnel first."
	
	var ready_units = 0
	var total_units = squad_units.size()
	
	for unit in squad_units:
		var validation = EquipmentManager.validate_loadout(unit)
		if validation.is_valid:
			ready_units += 1
	
	var readiness_percent = (ready_units * 100) / total_units
	
	if readiness_percent == 100:
		return "Full squad operational readiness. All units cleared for deployment."
	elif readiness_percent >= 75:
		return "Squad mostly ready. %d of %d soldiers fully equipped." % [ready_units, total_units]
	elif readiness_percent >= 50:
		return "Partial readiness. %d soldiers ready, but we need to fix the others." % ready_units
	else:
		return "Squad not ready for deployment. Too many equipment issues to resolve."

func provide_training_dialogue(unit: Unit) -> String:
	"""Generate dialogue about unit training and experience"""
	var training_responses = [
		"That soldier has been drilling with their current loadout. Combat effectiveness improved.",
		"Regular training keeps the squad sharp. %s is showing good progress." % unit.unit_name,
		"Training exercises completed. %s is ready for field operations." % unit.unit_name,
		"Combat drills finished. That soldier knows their equipment inside and out."
	]
	
	return training_responses[randi() % training_responses.size()]
