# Hound.gd - Updated to use modern equipment system
extends Unit
class_name Hound

# =============================================
# DEBUG: Simple AI Toggle - Change this to enable/disable AI
# =============================================
var AI_ENABLED: bool = true  # Set to false to disable all Hound AI

# AI Configuration
const AI_MOVE_DELAY = 0.2  # Seconds between AI actions
const AI_THINK_DELAY = 0.5  # Brief pause before starting AI turn

# AI State tracking
var ai_active: bool = false
var ai_timer: Timer
var current_target: Unit = null

func _ready():
	print("Creating a Hound unit with equipment system")
	
	# Set base identity
	unit_name = "Hound"
	unit_class = "hound"
	unit_color = Color.BLACK  # Dark color for hounds
	team = "enemy"  # Always enemy team
	
	# Set WRVSS stats (Hounds favor physical attributes and aggression)
	wisdom = 8    # Limited tactical awareness
	rage = 16     # High combat intensity - very aggressive
	virtue = 10   # Standard precision
	strength = 14 # Good physical power
	steel = 12    # Good endurance for pursuit
	
	# Set up AI timer before calling parent
	setup_ai_timer()
	
	# Equipment will be set by equip_default_loadout() in parent
	super()  # Call parent _ready() which handles equipment setup
	
	print("Hound unit created successfully with AI %s" % ("ENABLED" if AI_ENABLED else "DISABLED"))

func setup_ai_timer():
	"""Create and configure the AI action timer"""
	ai_timer = Timer.new()
	ai_timer.one_shot = true
	ai_timer.timeout.connect(_on_ai_timer_timeout)
	add_child(ai_timer)

# =============================================
# HOUND EQUIPMENT SETUP - Similar to Assassin but more aggressive
# =============================================
func equip_default_loadout():
	"""Override to give hounds specialized combat gear"""
	# Use a basic combat core (or create hound-specific core)
	core_equipment = Core.create_warrior_core()  # Reuse warrior core for now
	if core_equipment:
		core_equipment.equipment_name = "Hound Combat Core"
		core_equipment.description = "Core optimized for aggressive close combat"
		
	# Hounds prefer close combat weapons
	primary_weapon = null  # No primary weapon - prefer close combat
	sidearm = Weapon.create_knife()  # Enhanced for combat
	
	# Enhance the knife for hound use
	if sidearm:
		sidearm.equipment_name = "Hound Claws"
		sidearm.description = "Razor-sharp combat claws designed for hunting"
		sidearm.min_damage += 5  # More damage than assassin knife
		sidearm.max_damage += 8
		sidearm.crit_chance += 5   # Some crit chance
		sidearm.strength_scaling += 1.0  # Hounds use strength more than virtue
		sidearm.rage_scaling += 1.5      # Benefit from rage stat
	
	# Standard equipment with modifications for pursuit/combat
	reactor = Reactor.create_basic_reactor()
	
	# Enhanced booster for chase capability
	booster = Booster.create_basic_booster()
	if booster:
		booster.equipment_name = "Hunter Booster"
		booster.speed_bonus += 1  # Extra speed for chasing
		booster.description = "Booster optimized for pursuit and combat mobility"
	
	sensors = Sensor.create_basic_sensor()
	if sensors:
		sensors.equipment_name = "Predator Sensors"
		sensors.description = "Enhanced sensors for target tracking"
	
	# Medium armor - balance between protection and mobility
	armor_equipment = ArmorEquipment.create_basic_armor()
	if armor_equipment:
		armor_equipment.equipment_name = "Combat Carapace"
		armor_equipment.description = "Durable armor plating for frontline combat"
		armor_equipment.armor_bonus += 3  # More armor than assassin
		armor_equipment.health_bonus += 15  # More health
		armor_equipment.evasion_bonus -= 3  # Less evasion than assassin
	
	# Combat accessory
	accessory_1 = Accessory.create_basic_accessory()
	if accessory_1:
		accessory_1.equipment_name = "Combat Stimulant"
		accessory_1.description = "Enhances combat performance and aggression"
		accessory_1.accuracy_bonus = 5

# =============================================
# HOUND SPECIAL ABILITIES
# =============================================
func calculate_pack_bonus(target: Unit, base_damage: int) -> int:
	"""Calculate bonus damage when multiple hounds are near the target"""
	var pack_bonus = 0
	var nearby_hounds = count_nearby_hounds(target)
	
	if nearby_hounds >= 2:
		pack_bonus = int(base_damage * 0.25)  # 25% pack bonus
		print("%s gets pack hunting bonus with %d nearby hounds!" % [unit_name, nearby_hounds])
	
	return base_damage + pack_bonus

func count_nearby_hounds(target: Unit) -> int:
	"""Count how many other hounds are adjacent to the target"""
	var count = 0
	var target_pos = target.grid_position
	
	# Check all adjacent positions
	var adjacent_positions = [
		Vector3i(target_pos.x + 1, target_pos.y, target_pos.z),
		Vector3i(target_pos.x - 1, target_pos.y, target_pos.z),
		Vector3i(target_pos.x, target_pos.y, target_pos.z + 1),
		Vector3i(target_pos.x, target_pos.y, target_pos.z - 1),
	]
	
	var unit_manager = get_unit_manager()
	if not unit_manager:
		return 0
	
	for pos in adjacent_positions:
		var tile = unit_manager.grid.get_tile(pos)
		if tile and tile.occupied_unit:
			var unit = tile.occupied_unit
			if unit is Hound and unit != self and unit.team == team:  # Other hounds on same team
				count += 1
	
	return count

# =============================================
# OVERRIDE COMBAT METHODS FOR HOUND BONUSES
# =============================================
func attack_unit(target: Unit) -> int:
	"""Override to add hound-specific combat bonuses"""
	if not can_attack_target(target):
		return 0
	
	var weapon = get_active_weapon()
	if not weapon:
		return 0
	
	# Calculate weapon damage
	var damage_result = weapon.calculate_damage(self, target)
	var final_damage = damage_result.final_damage
	
	# Apply hound pack bonus
	final_damage = calculate_pack_bonus(target, final_damage)
	
	# Apply target's armor and resistances
	final_damage = apply_damage_reduction(final_damage, weapon, target)
	
	# Deal damage
	target.take_damage(final_damage)
	has_acted = true
	
	# Print combat feedback
	var damage_text = "%s mauls %s with %s for %d damage" % [unit_name, target.unit_name, weapon.equipment_name, final_damage]
	if damage_result.is_crit:
		damage_text += " (CRITICAL HIT!)"
	print(damage_text)
	
	return final_damage

# =============================================
# VISUAL SETUP - Make hounds look different
# =============================================
func setup_visual():
	"""Override visual setup to make hounds look different from assassins"""
	super.setup_visual()  # Call parent setup first
	
	# Make the hound slightly larger and more menacing
	if mesh_instance and mesh_instance.mesh:
		var mesh = mesh_instance.mesh as BoxMesh
		mesh.size = Vector3(0.9, 1.1, 0.9)  # Slightly bigger than regular units
	
	# Darker, more menacing appearance
	if default_material:
		default_material.albedo_color = unit_color.darkened(0.2)
		default_material.metallic = 0.3  # Slight metallic sheen
		default_material.roughness = 0.7

# =============================================
# AI SYSTEM - Main AI Logic (Updated for new equipment system)
# =============================================

func start_ai_turn():
	"""Called by UnitManager when it's this hound's turn to act"""
	if has_acted or current_health <= 0:
		return
	
	# DEBUG: Check if AI is disabled
	if not AI_ENABLED:
		print("=== HOUND AI DISABLED: %s - Skipping turn ===" % unit_name)
		end_ai_turn()
		return
	
	print("=== HOUND AI TURN START: %s ===" % unit_name)
	ai_active = true
	
	# Brief thinking delay before acting
	ai_timer.wait_time = AI_THINK_DELAY
	ai_timer.start()

func _on_ai_timer_timeout():
	"""Handle AI timer - execute next AI action"""
	if not ai_active or has_acted:
		end_ai_turn()
		return
	
	execute_ai_behavior()

func execute_ai_behavior():
	"""Main AI decision-making logic - simple but effective"""
	print("Hound %s thinking..." % unit_name)
	
	# Step 1: Find target (closest player unit)
	current_target = find_closest_player_unit()
	
	if not current_target:
		print("No valid targets found - ending turn")
		end_ai_turn()
		return
	
	print("Target acquired: %s at %s" % [current_target.unit_name, current_target.grid_position])
	
	# Step 2: Check if we can attack the target immediately
	if can_attack_target(current_target):
		print("Target in range - attacking!")
		attempt_attack(current_target)
		return
	
	# Step 3: Try to move closer to target
	print("Target out of range - moving closer")
	attempt_move_toward_target(current_target)

func find_closest_player_unit() -> Unit:
	"""Find the closest player unit using Manhattan distance"""
	var closest_unit: Unit = null
	var shortest_distance: int = 999999
	
	# Get reference to UnitManager through the scene
	var unit_manager = get_unit_manager()
	if not unit_manager:
		print("ERROR: Cannot find UnitManager!")
		return null
	
	# Check all player units
	for player_unit in unit_manager.player_units:
		if player_unit.current_health <= 0:
			continue  # Skip dead units
		
		var distance = calculate_manhattan_distance(grid_position, player_unit.grid_position)
		if distance < shortest_distance:
			shortest_distance = distance
			closest_unit = player_unit
	
	return closest_unit

func get_unit_manager():
	"""Get reference to the UnitManager"""
	var combat_scene = get_tree().current_scene
	if combat_scene.has_method("get_unit_manager"):
		return combat_scene.get_unit_manager()
	elif combat_scene.has_method("unit_manager"):
		return combat_scene.unit_manager
	return null

func calculate_manhattan_distance(from_pos: Vector3i, to_pos: Vector3i) -> int:
	"""Calculate grid-based Manhattan distance"""
	return abs(from_pos.x - to_pos.x) + abs(from_pos.z - to_pos.z)

func attempt_attack(target: Unit):
	"""Try to attack the target with line of sight check"""
	var unit_manager = get_unit_manager()
	if not unit_manager:
		end_ai_turn()
		return
	
	# Check line of sight using UnitManager's system
	var los_result = unit_manager.can_attack_with_line_of_sight(self, target)
	
	if los_result.can_attack:
		print("%s attacks %s!" % [unit_name, target.unit_name])
		
		# Show visual line of sight
		unit_manager.show_line_of_sight_visual(self, target, true)
		
		# Execute attack after brief delay to show the line
		# Disconnect any existing connections first
		if ai_timer.timeout.is_connected(_on_ai_timer_timeout):
			ai_timer.timeout.disconnect(_on_ai_timer_timeout)
		
		ai_timer.wait_time = 1.0
		ai_timer.timeout.connect(_execute_delayed_attack.bind(target), CONNECT_ONE_SHOT)
		ai_timer.start()
	else:
		print("%s cannot attack %s - line of sight blocked" % [unit_name, target.unit_name])
		# Show blocked line
		unit_manager.show_line_of_sight_visual(self, target, false, los_result.hit_point)
		# Try to move to a better position
		attempt_move_toward_target(target)

func _execute_delayed_attack(target: Unit):
	"""Execute the actual attack after visual delay"""
	if is_instance_valid(target) and target.current_health > 0:
		attack_unit(target)
	end_ai_turn()

func attempt_move_toward_target(target: Unit):
	"""Try to move closer to the target using pathfinding"""
	if movement_points_remaining <= 0:
		print("No movement points remaining")
		end_ai_turn()
		return
	
	var best_tile = find_best_move_toward_target(target)
	
	if best_tile:
		print("%s moving toward %s" % [unit_name, target.unit_name])
		var success = move_to_tile(best_tile)
		
		if success:
			# After moving, check if we can now attack
			# Disconnect any existing connections first
			if ai_timer.timeout.is_connected(_on_ai_timer_timeout):
				ai_timer.timeout.disconnect(_on_ai_timer_timeout)
			
			ai_timer.wait_time = AI_MOVE_DELAY
			ai_timer.timeout.connect(_check_post_move_attack.bind(target), CONNECT_ONE_SHOT)
			ai_timer.start()
		else:
			print("Move failed - ending turn")
			end_ai_turn()
	else:
		print("No valid moves found - ending turn")
		end_ai_turn()

func _check_post_move_attack(target: Unit):
	"""After moving, check if we can now attack the target"""
	if not is_instance_valid(target) or target.current_health <= 0:
		end_ai_turn()
		return
	
	if can_attack_target(target):
		attempt_attack(target)
	else:
		end_ai_turn()

func find_best_move_toward_target(target: Unit) -> Tile:
	"""Find the best tile to move to get closer to target"""
	var unit_manager = get_unit_manager()
	if not unit_manager or not unit_manager.grid:
		return null
	
	var grid = unit_manager.grid
	var best_tile: Tile = null
	var best_distance: int = 999999
	
	# Check all tiles within movement range
	for x_offset in range(-movement_points_remaining, movement_points_remaining + 1):
		for z_offset in range(-movement_points_remaining, movement_points_remaining + 1):
			var manhattan_dist = abs(x_offset) + abs(z_offset)
			if manhattan_dist == 0 or manhattan_dist > movement_points_remaining:
				continue
			
			var test_pos = Vector3i(
				grid_position.x + x_offset,
				grid_position.y,
				grid_position.z + z_offset
			)
			
			var test_tile = grid.get_tile(test_pos)
			if not test_tile or not test_tile.is_walkable or test_tile.occupied_unit:
				continue
			
			# Calculate distance from this position to target
			var distance_to_target = calculate_manhattan_distance(test_pos, target.grid_position)
			
			# Prefer tiles that get us closer AND potentially give us line of sight
			if distance_to_target < best_distance:
				best_distance = distance_to_target
				best_tile = test_tile
	
	return best_tile

func end_ai_turn():
	"""Clean up and end the AI's turn"""
	print("=== HOUND AI TURN END: %s ===" % unit_name)
	ai_active = false
	has_acted = true
	
	# Clean up timer connections to prevent errors
	if ai_timer.timeout.is_connected(_on_ai_timer_timeout):
		ai_timer.timeout.disconnect(_on_ai_timer_timeout)
	
	# Reconnect the main timer handler for future turns
	if not ai_timer.timeout.is_connected(_on_ai_timer_timeout):
		ai_timer.timeout.connect(_on_ai_timer_timeout)
	
	# Notify the unit manager that this unit is done
	var unit_manager = get_unit_manager()
	if unit_manager:
		unit_manager.on_ai_unit_finished(self)

# =============================================
# INTEGRATION HELPERS
# =============================================

func can_act() -> bool:
	"""Check if this AI unit can take actions"""
	return not has_acted and current_health > 0 and not ai_active and AI_ENABLED
