# Assassin.gd - New unit class with equipment system
extends Unit
class_name Assassin

func _ready():
	print("Creating an Assassin unit with equipment system")
	
	# Set base identity
	unit_name = "Assassin"
	unit_class = "assassin"
	unit_color = Color.DARK_GRAY
	team = "player"  # Will be set by spawner
	
	# Set WRVSS stats (Assassins favor precision and speed)
	wisdom = 12   # Good tactical awareness
	rage = 14     # High combat intensity
	virtue = 16   # Excellent precision for critical hits
	strength = 8  # Lower raw strength
	steel = 10    # Standard endurance
	
	# Equipment will be set by equip_default_loadout() in parent
	super()  # Call parent _ready() which handles equipment setup
	
	print("Assassin unit created successfully")

# =============================================
# ASSASSIN SPECIAL ABILITIES
# =============================================
func can_use_shadow_strike(target: Unit) -> Dictionary:
	"""Check if assassin can use shadow strike ability on target"""
	var result = {"can_use": false, "reason": ""}
	
	if has_acted:
		result.reason = "Already acted this turn"
		return result
	
	if not target or target.team == team:
		result.reason = "Invalid target"
		return result
	
	# Shadow strike has longer range than normal attacks
	var distance = abs(target.grid_position.x - grid_position.x) + abs(target.grid_position.z - grid_position.z)
	if distance > 6:  # Shadow strike range
		result.reason = "Target too far for shadow strike"
		return result
	
	# Check if core has the ability (cooldown managed elsewhere)
	if not core_equipment or core_equipment.primary_ability != "Shadow Strike":
		result.reason = "Shadow Strike not available"
		return result
	
	result.can_use = true
	return result

func shadow_strike(target: Unit) -> bool:
	"""Execute shadow strike ability - teleport to target and attack"""
	var can_use_result = can_use_shadow_strike(target)
	if not can_use_result.can_use:
		print("Cannot use Shadow Strike: %s" % can_use_result.reason)
		return false
	
	print("%s uses Shadow Strike on %s!" % [unit_name, target.unit_name])
	
	# Find adjacent tile to target for teleportation
	var target_tile = find_teleport_position(target)
	if not target_tile:
		print("No valid position to teleport to near target")
		return false
	
	# Teleport effect
	teleport_to_tile(target_tile)
	
	# Enhanced attack with shadow strike bonuses
	var weapon = get_active_weapon()
	if weapon:
		var damage_result = weapon.calculate_damage(self, target)
		# Shadow strike gets damage bonus and guaranteed crit
		var shadow_damage = int(damage_result.scaled_damage * 1.5)  # 50% damage bonus
		var final_damage = apply_damage_reduction(shadow_damage, weapon, target)
		
		target.take_damage(final_damage)
		print("Shadow Strike deals %d damage (enhanced)!" % final_damage)
		
		# Show special effect or animation here
		create_shadow_strike_effect(target)
	
	has_acted = true
	return true

func find_teleport_position(target: Unit) -> Tile:
	"""Find a valid adjacent tile to teleport to near the target"""
	var target_pos = target.grid_position
	
	# Check all adjacent positions
	var adjacent_positions = [
		Vector3i(target_pos.x + 1, target_pos.y, target_pos.z),
		Vector3i(target_pos.x - 1, target_pos.y, target_pos.z),
		Vector3i(target_pos.x, target_pos.y, target_pos.z + 1),
		Vector3i(target_pos.x, target_pos.y, target_pos.z - 1),
	]
	
	# Get grid reference (you'll need to pass this or get it from combat scene)
	var grid = get_node("/root/CombatScene").grid  # Adjust path as needed
	
	for pos in adjacent_positions:
		var tile = grid.get_tile(pos)
		if tile and tile.is_walkable and not tile.occupied_unit:
			return tile
	
	return null  # No valid position found

func teleport_to_tile(target_tile: Tile):
	"""Instantly move to target tile (teleportation, not normal movement)"""
	if current_tile:
		current_tile.occupied_unit = null
	
	var old_tile = current_tile
	place_on_tile(target_tile)
	
	# Don't consume movement points for teleportation
	unit_moved.emit(self, old_tile, target_tile)
	
	print("%s teleports to %s" % [unit_name, target_tile.grid_position])

func create_shadow_strike_effect(target: Unit):
	"""Create visual effect for shadow strike (placeholder)"""
	# You could add particle effects, screen flash, etc. here
	print("*Shadow energy swirls around %s as %s strikes!*" % [target.unit_name, unit_name])

# =============================================
# ASSASSIN PASSIVE ABILITIES
# =============================================
func calculate_backstab_damage(target: Unit, base_damage: int) -> int:
	"""Calculate bonus damage if attacking from behind or flanking"""
	# Simple flanking bonus - you could make this more sophisticated
	# based on unit facing direction
	var flanking_bonus = 0
	
	# Check if target is engaged with other units (flanking)
	var adjacent_enemies = count_adjacent_enemies(target)
	if adjacent_enemies >= 2:
		flanking_bonus = int(base_damage * 0.3)  # 30% flanking bonus
		print("%s gets flanking bonus against %s!" % [unit_name, target.unit_name])
	
	return base_damage + flanking_bonus

func count_adjacent_enemies(target: Unit) -> int:
	"""Count how many enemy units are adjacent to the target"""
	var count = 0
	var target_pos = target.grid_position
	
	# Check all adjacent positions
	var adjacent_positions = [
		Vector3i(target_pos.x + 1, target_pos.y, target_pos.z),
		Vector3i(target_pos.x - 1, target_pos.y, target_pos.z),
		Vector3i(target_pos.x, target_pos.y, target_pos.z + 1),
		Vector3i(target_pos.x, target_pos.y, target_pos.z - 1),
	]
	
	var grid = get_node("/root/CombatScene").grid  # Adjust path as needed
	
	for pos in adjacent_positions:
		var tile = grid.get_tile(pos)
		if tile and tile.occupied_unit:
			var unit = tile.occupied_unit
			if unit.team != target.team:  # Enemy of the target
				count += 1
	
	return count

# =============================================
# OVERRIDE COMBAT METHODS FOR ASSASSIN BONUSES
# =============================================
func attack_unit(target: Unit) -> int:
	"""Override to add assassin-specific combat bonuses"""
	if not can_attack_target(target):
		return 0
	
	var weapon = get_active_weapon()
	if not weapon:
		return 0
	
	# Calculate weapon damage
	var damage_result = weapon.calculate_damage(self, target)
	var final_damage = damage_result.final_damage
	
	# Apply assassin backstab bonus
	final_damage = calculate_backstab_damage(target, final_damage)
	
	# Apply target's armor and resistances
	final_damage = apply_damage_reduction(final_damage, weapon, target)
	
	# Deal damage
	target.take_damage(final_damage)
	has_acted = true
	
	# Print combat feedback
	var damage_text = "%s strikes %s with %s for %d damage" % [unit_name, target.unit_name, weapon.equipment_name, final_damage]
	if damage_result.is_crit:
		damage_text += " (CRITICAL HIT!)"
	print(damage_text)
	
	return final_damage
