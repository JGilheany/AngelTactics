# Weapon.gd - Base class for all weapons
class_name Weapon
extends Equipment

# =============================================
# WEAPON-SPECIFIC PROPERTIES
# =============================================
@export_group("Damage")
@export var min_damage: int = 1
@export var max_damage: int = 10
@export var damage_types: Array = ["ballistic"]  # ballistic, energy, explosive

@export_group("Accuracy & Range")
@export var weapon_accuracy: int = 0  # Bonus/penalty to hit chance
@export var weapon_range: int = 1     # Base attack range
@export var max_range: int = 1        # Maximum effective range

@export_group("Critical Hits")
@export var crit_chance: int = 5      # Base crit chance percentage
@export var crit_modifier: float = 1.5 # Damage multiplier on crit

@export_group("WRVSS Scaling")
# How much each WRVSS stat contributes to weapon effectiveness
#5 = S, 4 = A, 3 = B, 2 = C, 1 = D
@export var wisdom_scaling: float = 1
@export var rage_scaling: float = 1
@export var virtue_scaling: float = 1
@export var strength_scaling: float = 1
@export var steel_scaling: float = 1

# =============================================
# WEAPON TAGS - Define special weapon behaviors
# =============================================
# Common weapon tags:
# - "loading": Must reload after each shot
# - "long_range": Penalty at close range, bonus at long range
# - "close_quarters": Bonus at close range, penalty at long range
# - "splash": Hits multiple enemies in area
# - "smart": Ignores cover bonuses
# - "armor_piercing": Ignores armor
# - "melee": Close combat weapon
# - "ranged": Projectile weapon
# - "primary": Can be equipped as primary weapon
# - "sidearm": Can be equipped as sidearm

# =============================================
# WEAPON CALCULATIONS
# =============================================
func calculate_damage(unit, _target = null) -> Dictionary:
	"""
	Calculate weapon damage with WRVSS scaling and randomization
	Returns: {base_damage: int, scaled_damage: int, is_crit: bool, final_damage: int}
	"""
	var result = {
		"base_damage": 0,
		"scaled_damage": 0,
		"is_crit": false,
		"final_damage": 0
	}
	
	# Base random damage
	result.base_damage = randi_range(min_damage, max_damage)
	
	# Apply WRVSS scaling
	var scaling_bonus = 0.0
	scaling_bonus += unit.wisdom * wisdom_scaling
	scaling_bonus += unit.rage * rage_scaling
	scaling_bonus += unit.virtue * virtue_scaling
	scaling_bonus += unit.strength * strength_scaling
	scaling_bonus += unit.steel * steel_scaling
	
	result.scaled_damage = int(result.base_damage + scaling_bonus)
	
	# Check for critical hit
	var crit_roll = randi_range(1, 100)
	var total_crit_chance = crit_chance + calculate_crit_bonus(unit)
	
	if crit_roll <= total_crit_chance:
		result.is_crit = true
		result.final_damage = int(result.scaled_damage * crit_modifier)
	else:
		result.final_damage = result.scaled_damage
	
	return result

func calculate_accuracy_bonus(_unit, _target = null, distance: int = 1) -> int:
	"""Calculate total accuracy bonus from weapon + range modifiers"""
	var total_accuracy = weapon_accuracy + accuracy_bonus
	
	# Apply range-based modifiers
	if has_tag("long_range"):
		if distance <= 2:
			total_accuracy -= 15  # Penalty at close range
		elif distance >= 4:
			total_accuracy += 10  # Bonus at long range
	
	if has_tag("close_quarters"):
		if distance <= 2:
			total_accuracy += 15  # Bonus at close range
		elif distance >= 4:
			total_accuracy -= 10  # Penalty at long range
	
	return total_accuracy

func calculate_crit_bonus(unit) -> int:
	"""Calculate critical hit chance bonuses from unit stats"""
	# Example: Virtue increases crit chance for precise shots
	return int(unit.virtue * 0.5)  #placeholder

func get_effective_range(_unit) -> int:
	"""Get weapon's effective range including bonuses"""
	return weapon_range + range_bonus

func get_max_effective_range(_unit) -> int:
	"""Get weapon's maximum range including bonuses"""
	return max_range + range_bonus

# =============================================
# WEAPON SPECIAL ABILITIES
# =============================================
func can_attack_target(unit, _target, distance: int) -> Dictionary:
	"""
	Check if weapon can attack target at given distance
	Returns: {can_attack: bool, reason: String}
	"""
	var result = {"can_attack": true, "reason": ""}
	
	# Check range
	if distance > get_max_effective_range(unit):
		result.can_attack = false
		result.reason = "Target out of range"
		return result
	
	# Check weapon-specific restrictions
	if has_tag("melee") and distance > 1:
		result.can_attack = false
		result.reason = "Melee weapon requires adjacent target"
		return result
	
	# Check loading tag
	if has_tag("loading") and needs_reload(unit):
		result.can_attack = false
		result.reason = "Weapon needs to be reloaded"
		return result
	
	return result

func needs_reload(unit) -> bool:
	"""Check if weapon needs reloading (for loading tag)"""
	if not has_tag("loading"):
		return false
	
	# Check if unit has fired this turn (need to track this in Unit)!!!! TBD
	return unit.has_fired_weapon if unit.has_method("has_fired_weapon") else false

func get_splash_targets(_unit, primary_target, _combat_scene) -> Array: #very placeholder TBD
	"""Get all targets affected by splash damage"""
	var targets = []
	
	if not has_tag("splash"):
		return [primary_target]  # Only primary target
	
	# Find all units within splash range (implement based on grid system)
	# This is a placeholder - need to implement based on Grid class
	targets.append(primary_target)
	
	# Add splash logic here when ready !!!! TBD
	# for neighbor_tile in get_adjacent_tiles(primary_target.current_tile):
	#     if neighbor_tile.occupied_unit:
	#         targets.append(neighbor_tile.occupied_unit)
	
	return targets

# =============================================
# WEAPON TYPES - Presets for common weapons
# =============================================
static func create_assault_rifle() -> Weapon:
	"""Factory method to create a basic assault rifle"""
	var arifle = Weapon.new()
	arifle.equipment_name = "Assault Rifle"
	arifle.manufacturer = "MilTech Corp"
	arifle.description = "Standard military rifle with selective fire capability"
	arifle.cost = 500
	arifle.power_draw = 2
	
	arifle.min_damage = 15
	arifle.max_damage = 25
	arifle.weapon_accuracy = 5
	arifle.weapon_range = 4
	arifle.max_range = 6
	arifle.crit_chance = 8
	arifle.damage_types = ["ballistic"]
	
	# Scales with Strength (B) and Steel (A)
	arifle.strength_scaling = 3.0
	arifle.steel_scaling = 4.0
	
	#arifle.tags = ["ranged", "primary", "sidearm"]
	return arifle

static func create_knife() -> Weapon:
	"""Factory method to create a combat knife"""
	var knife = Weapon.new()
	knife.equipment_name = "Combat Knife"
	knife.manufacturer = "EdgeWorks"
	knife.description = "Sharp tactical knife for close combat"
	knife.cost = 100
	knife.power_draw = 0
	
	knife.min_damage = 10
	knife.max_damage = 20
	knife.weapon_accuracy = 10
	knife.weapon_range = 1
	knife.max_range = 1
	knife.crit_chance = 15
	knife.damage_types = ["ballistic"]
	
	# Scales with Strength and Rage
	knife.strength_scaling = 1
	knife.rage_scaling = 1
	
	#knife.tags = ["melee", "sidearm"]
	return knife

static func create_grenade_launcher() -> Weapon:
	"""Factory method to create a grenade launcher"""
	var launcher = Weapon.new()
	launcher.equipment_name = "Grenade Launcher"
	launcher.manufacturer = "Boom Industries"
	launcher.description = "Explosive launcher with area effect"
	launcher.cost = 800
	launcher.power_draw = 4
	
	launcher.min_damage = 25
	launcher.max_damage = 40
	launcher.weapon_accuracy = -5  # Less accurate but splash damage
	launcher.weapon_range = 3
	launcher.max_range = 5
	launcher.crit_chance = 3
	launcher.damage_types = ["explosive"]
	
	# Scales with Steel and Virtue
	launcher.steel_scaling = 1.5
	launcher.virtue_scaling = 1.0
	
	#launcher.tags = ["ranged", "primary", "splash", "loading"]
	return launcher

static func create_hound_claws() -> Weapon:
	"""Factory method to create hound claws (natural weapon)"""
	var claws = Weapon.new()
	claws.equipment_name = "Natural Claws"
	claws.manufacturer = "Outsider"
	claws.description = "Sharpened enamel claws for tearing enemies"
	claws.cost = 0  # Can't be bought
	claws.power_draw = 0
	
	claws.min_damage = 12
	claws.max_damage = 18
	claws.weapon_accuracy = 15  # Natural weapons are very accurate
	claws.weapon_range = 1
	claws.max_range = 1
	claws.crit_chance = 20
	claws.damage_types = ["ballistic"]
	
	# Scales with Rage and Strength
	claws.rage_scaling = 1
	claws.strength_scaling = 1
	
	claws.allowed_unit_classes = ["hound"]  # Only hounds can use
	#claws.tags = ["melee", "primary", "close_quarters", "natural"]
	return claws
