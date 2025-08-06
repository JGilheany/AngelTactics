extends Node3D
class_name Unit

# =============================================
# SIGNALS - Let other parts of the game know when things happen
# =============================================
signal unit_selected(unit)
signal unit_moved(unit, from_tile, to_tile)
signal unit_died(unit)
signal unit_turn_started(unit)
signal unit_turn_ended(unit)

# =============================================
# UNIT STATS - Designer can change these in Inspector
# =============================================
@export_group("Unit Stats")
@export var unit_name: String = "Unit"
@export var max_health: int = 100
@export var movement_range: int = 3
@export var attack_range: int = 1
@export var attack_damage: int = 25
@export var armor: int = 0
@export var initiative: int = 10
@export var has_acted: bool = false  # Track if unit has acted this turn

@export_group("Unit Type")
@export var team: String = "player"
@export var unit_class: String = "warrior"

@export_group("Visual")
@export var unit_color: Color = Color.BLUE
@export var unit_mesh: Mesh

# =============================================
# GAME STATE VARIABLES - Track what's happening during gameplay
# =============================================
var current_health: int
var current_tile: Tile
var grid_position: Vector2i
var has_moved: bool = false
var is_selected: bool = false


# =============================================
# VISUAL COMPONENTS - Connect to the 3D objects we see
# =============================================
@onready var mesh_instance = $MeshInstance3D
@onready var health_bar = $HealthBar
@onready var selection_indicator = $SelectionIndicator

# CLICK DETECTION: References to collision detection components
# We use both StaticBody3D and Area3D for maximum compatibility
@onready var static_body = $StaticBody3D
@onready var static_collision = $StaticBody3D/CollisionShape3D
@onready var area_3d = $Area3D
@onready var area_collision = $Area3D/CollisionShape3D

# =============================================
# MATERIALS - Different "paint jobs" for different states
# =============================================
var default_material: StandardMaterial3D
var selected_material: StandardMaterial3D
var dead_material: StandardMaterial3D

# =============================================
# INITIALIZATION - Set up the unit when it's first created
# =============================================
func _ready():
	current_health = max_health    # Start with full health
	setup_materials()              # Create the visual styles
	setup_visual()                 # Set up the 3D appearance
	setup_click_detection()        # Set up mouse click handling (FIXED!)
	update_health_bar()            # Initialize health bar display
	position.y = 0.5               # Hover slightly above ground
	
	print("✓ Unit ", unit_name, " fully initialized at ", position)

# =============================================
# CLICK DETECTION SETUP - Make the unit clickable (COMPLETELY REWRITTEN!)
# =============================================
func setup_click_detection():
	#print("UNIT ", unit_name, ": Setting up IMPROVED click detection...")
	
	# METHOD 1: StaticBody3D click detection (most reliable)
	if static_body and static_collision:
		# Connect the input event signal
		var connection_result = static_body.input_event.connect(_on_static_body_clicked)
		if connection_result == OK:
			print("  ✓ StaticBody3D click detection connected")
		else:
			print("  ✗ Failed to connect StaticBody3D signals")
		
		# Set up collision layers (layer 2 for units, different from tiles)
		static_body.collision_layer = 2
		static_body.collision_mask = 0
		
		# Make sure collision shape exists
		if not static_collision.shape:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(0.8, 1.0, 0.8)
			static_collision.shape = box_shape
			print("  ✓ Created collision shape for StaticBody3D")
	else:
		print("  ✗ ERROR: StaticBody3D or CollisionShape3D not found!")
	
	# METHOD 2: Area3D detection (backup method)
	if area_3d and area_collision:
		# Connect area signals for additional detection
		var connection1 = area_3d.input_event.connect(_on_area_input_event)
		var connection2 = area_3d.mouse_entered.connect(_on_unit_mouse_entered)  
		var connection3 = area_3d.mouse_exited.connect(_on_unit_mouse_exited)
		
		if connection1 == OK and connection2 == OK and connection3 == OK:
			print("  ✓ Area3D detection connected")
		else:
			print("  ✗ Some Area3D connections failed")
		
		# Set up area collision
		area_3d.collision_layer = 2
		area_3d.collision_mask = 0
		
		# Make sure area collision shape exists
		if not area_collision.shape:
			var box_shape = BoxShape3D.new()
			box_shape.size = Vector3(1.0, 1.2, 1.0)  # Slightly larger for easier clicking
			area_collision.shape = box_shape
			print("  ✓ Created collision shape for Area3D")
	else:
		print("  ✗ WARNING: Area3D or its CollisionShape3D not found!")
	
	print("  ✓ Click detection setup complete for ", unit_name)

# =============================================
# CLICK HANDLERS - Multiple methods for maximum compatibility
# =============================================

# Method 1: StaticBody3D click handler (primary method)
func _on_static_body_clicked(_camera, event, _click_position, _click_normal, _shape_idx):
	print("=== STATIC BODY CLICK DEBUG ===")
	print("Unit: ", unit_name, " at ", grid_position)
	print("Event: ", event)
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("✓ LEFT CLICK on ", unit_name, " via StaticBody3D")
			handle_unit_selection()
		else:
			print("✗ Not a left click or not pressed")
	else:
		print("✗ Not a mouse button event")

# Method 2: Area3D click handler (backup method)
func _on_area_input_event(_camera, event, _click_position, _click_normal, _shape_idx):
	#print("=== AREA3D CLICK DEBUG ===")
	#print("Unit: ", unit_name, " backup click detection")
	
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			#print("✓ LEFT CLICK on ", unit_name, " via Area3D (backup)")
			handle_unit_selection()

# Mouse hover effects (visual feedback)
func _on_unit_mouse_entered():
	if not is_selected:
		# Make unit slightly brighter when mouse hovers over it
		mesh_instance.material_override = selected_material.duplicate()
		var hover_material = mesh_instance.material_override
		hover_material.albedo_color = unit_color.lightened(0.1)
		#print("Mouse entered ", unit_name)

func _on_unit_mouse_exited():
	if not is_selected:
		# Return to normal color when mouse leaves
		mesh_instance.material_override = default_material
		#print("Mouse exited ", unit_name)

# Centralized selection handler
func handle_unit_selection():
	print("🎯 UNIT SELECTED: ", unit_name, " emitting signal...")
	unit_selected.emit(self)
	print("✓ unit_selected signal emitted!")

# =============================================
# VISUAL SETUP - Create materials for different unit states
# =============================================
func setup_materials():
	# Create normal appearance
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = unit_color
	
	# Create bright/glowing appearance for when selected
	selected_material = StandardMaterial3D.new()
	selected_material.albedo_color = unit_color.lightened(0.3)
	selected_material.emission = unit_color * 0.3
	selected_material.emission_enabled = true
	
	# Create gray/faded appearance for when dead
	dead_material = StandardMaterial3D.new()
	dead_material.albedo_color = Color.GRAY
	dead_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dead_material.albedo_color.a = 0.5
	
	# Set up health bar colors (only if health bar nodes exist)
	if health_bar and health_bar.has_node("Background") and health_bar.has_node("Foreground"):
		var health_bg_material = StandardMaterial3D.new()
		health_bg_material.albedo_color = Color.DARK_GRAY
		
		var health_fg_material = StandardMaterial3D.new()
		health_fg_material.albedo_color = Color.GREEN
		health_fg_material.emission = Color.GREEN * 0.2
		health_fg_material.emission_enabled = true
		
		health_bar.get_node("Background").material_override = health_bg_material
		health_bar.get_node("Foreground").material_override = health_fg_material

# =============================================
# 3D MODEL SETUP - Create the unit's shape and apply default colors
# =============================================
func setup_visual():
	# Use custom mesh if provided, otherwise create a simple box
	if unit_mesh:
		mesh_instance.mesh = unit_mesh
	else:
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.8, 1.0, 0.8)
		mesh_instance.mesh = box_mesh
	
	# Apply the normal color
	mesh_instance.material_override = default_material
	
	# Hide selection ring until unit is selected
	if selection_indicator:
		selection_indicator.visible = false

# =============================================
# GRID MOVEMENT - Handle placing and moving units on the game board
# =============================================
func place_on_tile(tile: Tile):
	print("UNIT ", unit_name, ": Placing on tile at ", tile.grid_position)
	
	# Free up the old tile if we were on one
	if current_tile:
		current_tile.set_free()
	
	# Move to the new tile
	current_tile = tile
	grid_position = tile.grid_position
	
	# Position the unit in 3D space
	# Add 0.5 to Y so unit hovers above the ground
	position = Vector3(tile.grid_position.x, 0.5, tile.grid_position.y)
	
	# Tell the tile it's now occupied
	tile.set_occupied(self)
	
	print("✓ Unit placed at world position: ", position)

func move_to_tile(target_tile: Tile) -> bool:
	print("UNIT ", unit_name, ": Attempting to move to ", target_tile.grid_position)
	
	# Check if we can move there
	if not target_tile or not target_tile.is_walkable:
		print("✗ Cannot move - tile not walkable")
		return false
	
	if target_tile.occupied_unit and target_tile.occupied_unit != self:
		print("✗ Cannot move - tile occupied by ", target_tile.occupied_unit.unit_name)
		return false
	
	# Perform the move
	var old_tile = current_tile
	place_on_tile(target_tile)
	has_moved = true
	
	# Tell other systems about the move
	unit_moved.emit(self, old_tile, target_tile)
	print("✓ Move successful!")
	return true

# =============================================
# SELECTION SYSTEM - Visual feedback when player clicks on unit
# =============================================
func select():
	print("UNIT ", unit_name, ": Selected - applying glow effect")
	is_selected = true
	mesh_instance.material_override = selected_material  # Make unit glow
	if selection_indicator:
		selection_indicator.visible = true               # Show selection ring

func deselect():
	print("UNIT ", unit_name, ": Deselected - returning to normal appearance")
	is_selected = false
	mesh_instance.material_override = default_material  # Return to normal color
	if selection_indicator:
		selection_indicator.visible = false             # Hide selection ring

# =============================================
# COMBAT SYSTEM - Handle damage, healing, and death
# =============================================

func heal(amount: int):
	# Add health but don't exceed maximum
	current_health = min(max_health, current_health + amount)
	update_health_bar()



# =============================================
# TURN MANAGEMENT - Handle beginning and ending turns
# =============================================
func start_turn():
	# Reset actions for new turn
	has_moved = false
	has_acted = false
	unit_turn_started.emit(self)

func end_turn():
	# Mark turn as complete
	has_acted = true
	unit_turn_ended.emit(self)


func can_attack_target(target: Unit) -> bool:
	"""Check if this unit can attack the target"""
	if not target or target.team == team:
		return false
	if has_acted:
		return false
	var distance = abs(target.grid_position.x - grid_position.x) + abs(target.grid_position.y - grid_position.y)
	return distance <= attack_range

func attack_unit(target: Unit) -> int:
	"""Attack another unit and return damage dealt"""
	if not can_attack_target(target):
		return 0
	
	var damage = max(1, attack_damage - target.armor)  # Minimum 1 damage
	target.take_damage(damage)
	has_acted = true  # Mark as acted
	
	print("%s attacks %s for %d damage!" % [unit_name, target.unit_name, damage])
	return damage

func take_damage(damage: int):
	"""Take damage and handle death"""
	current_health -= damage
	current_health = max(0, current_health)
	update_health_bar()
	
	print("%s takes %d damage! Health: %d/%d" % [unit_name, damage, current_health, max_health])
	
	if current_health <= 0:
		die()

func update_health_bar():
	"""Update visual health bar"""
	if health_bar:
		var health_percent = float(current_health) / float(max_health)
		var foreground = health_bar.get_node_or_null("Foreground")
		if foreground:
			foreground.scale.x = health_percent
			# Color coding: Green -> Yellow -> Red
			var material = foreground.get_surface_override_material(0)
			if material:
				if health_percent > 0.6:
					material.albedo_color = Color.GREEN
				elif health_percent > 0.3:
					material.albedo_color = Color.YELLOW
				else:
					material.albedo_color = Color.RED

func die():
	"""Handle unit death"""
	print("%s has died!" % unit_name)
	if current_tile:
		current_tile.set_free()
	unit_died.emit(self)
	queue_free()

func reset_turn():
	"""Reset for new turn"""
	has_acted = false
