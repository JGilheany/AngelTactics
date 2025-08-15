# This script inherits from Node3D (makes it a 3D object)
extends Node3D

# Creates a custom class called "Tile" that can be used throughout the project
# This lets us reference Tile objects with proper type checking
class_name Tile

# SIGNALS: These are messages this tile can send to other objects
# Other scripts can "listen" for these signals and react accordingly
signal tile_clicked(tile)    # Sent when player clicks this tile
signal tile_hovered(tile)    # Sent when mouse enters this tile
signal tile_unhovered(tile)  # Sent when mouse leaves this tile

# EXPORTED VARIABLES: These appear in the Godot Inspector and can be changed per-tile
@export var grid_position: Vector3i    # Where this tile is on the grid (x, y, z coordinates)
@export var is_walkable: bool = true   # Can units move through this tile?
@export var movement_cost: int = 1     # How many movement points to enter this tile


# INTERNAL VARIABLES: Used by the script but not visible in Inspector
var occupied_unit: Node3D = null       # Which unit is standing on this tile (null = empty)
var is_highlighted: bool = false       # Is this tile currently highlighted for movement/selection?

# NODE REFERENCES: Get references to child nodes when the scene loads
# @onready means "set this variable when _ready() is called"
# The $ syntax finds child nodes by name
@onready var mesh_instance = $MeshInstance3D  # The visual part of the tile
@onready var static_body = $StaticBody3D      # Handles mouse clicks
@onready var area = $Area3D                   # Handles mouse hover detection

# MATERIALS: Different visual appearances for different tile states
var default_material: StandardMaterial3D      # Normal appearance (white)
var hover_material: StandardMaterial3D        # When mouse is over tile (yellow)
var walkable_material: StandardMaterial3D     # When showing movement range (green)
var blocked_material: StandardMaterial3D      # When tile is blocked (red)
var occupied_material: StandardMaterial3D     # When unit is on tile (orange)

# _ready() runs once when this tile is added to the scene
func _ready():
	setup_materials()
	
	if area:
		#print("Connecting area signals...")
		area.mouse_entered.connect(_on_mouse_entered)
		area.mouse_exited.connect(_on_mouse_exited)
	
	update_appearance()
	
	
# Creates all the different colored materials for tile states
func setup_materials():
	#print("TILE ", grid_position, ": Setting up materials...")
	
	# Default material
	default_material = StandardMaterial3D.new()
	default_material.albedo_color = Color.WHITE
	#print("  ✓ Default material created (white)")
	
	# Hover material  
	hover_material = StandardMaterial3D.new()
	hover_material.albedo_color = Color.YELLOW
	hover_material.emission = Color.YELLOW * 0.5
	#print("  ✓ Hover material created (yellow)")
	
	# Walkable material - make it VERY green to be obvious
	walkable_material = StandardMaterial3D.new()
	walkable_material.albedo_color = Color.GREEN
	walkable_material.emission = Color.GREEN * 0.8  # Strong glow
	#print("  ✓ Walkable material created (bright green)")
	
	# Blocked material - for permanently impassable terrain
	blocked_material = StandardMaterial3D.new()
	blocked_material.albedo_color = Color.RED
	blocked_material.emission = Color.RED * 0.5
	#print("  ✓ Blocked material created (red)")
	
	# NEW: Occupied material - for tiles with units on them
	occupied_material = StandardMaterial3D.new()
	occupied_material.albedo_color = Color.ORANGE
	occupied_material.emission = Color.ORANGE * 0.4  # Subtle glow
	print("  ✓ Occupied material created (orange)")
	
	# Apply default immediately
	if mesh_instance:
		mesh_instance.material_override = default_material
		#print("  ✓ Default material applied to mesh")
	#else:
		#print("  ✗ ERROR: mesh_instance is null!")


	
# Called automatically when player clicks on this tile
# Parameters are provided by Godot's input system
func _on_tile_clicked(_camera, event, _click_position, _click_normal, _shape_idx):
	#print("=== TILE CLICK DEBUG ===")
	#print("Event type: ", event.get_class())
	#print("Event details: ", event)
	if event is InputEventMouseButton:
		#print("Mouse button: ", event.button_index)
		#print("Pressed: ", event.pressed)
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			#print("✓ LEFT CLICK CONFIRMED - emitting tile_clicked signal")
			tile_clicked.emit(self)
			#print("✓ Signal emitted!")
		#else:
			#print("✗ Not a left click or not pressed")
	#else:
		#print("✗ Not a mouse button event")
# Called automatically when mouse cursor enters this tile's area


func _on_mouse_entered():
	# Tell other objects that this tile is being hovered over
	tile_hovered.emit(self)


# Called automatically when mouse cursor leaves this tile's area
func _on_mouse_exited():
	# Tell other objects that mouse left this tile
	tile_unhovered.emit(self)


# Called by other scripts when a unit moves onto this tile
func set_occupied(unit: Node3D):
	occupied_unit = unit        # Remember which unit is here
	# NOTE: Don't change is_walkable here - we want to show orange but keep movement logic separate
	update_appearance()        # Change visual to show it's occupied
	print("TILE ", grid_position, ": Now occupied by ", unit.name, " - showing ORANGE")

# Called by other scripts when a unit leaves this tile
func set_free():
	print("TILE ", grid_position, ": Unit left - returning to normal appearance")
	occupied_unit = null       # No unit here anymore
	update_appearance()       # Change visual back to normal

# Called by Grid script to show this tile is within movement range
func highlight_walkable():
	#print("TILE ", grid_position, ": Setting walkable highlight (GREEN)")
	is_highlighted = true
	
	# Verify the material exists
	if walkable_material == null:
		#print("  ✗ ERROR: walkable_material is null!")
		return
	
	# Apply the material
	mesh_instance.material_override = walkable_material
	#print("  ✓ Green material applied to mesh_instance")
	
	# Verify it was applied
	#if mesh_instance.material_override == walkable_material:
		#print("  ✓ Material application confirmed")
	#else:
		#print("  ✗ Material application FAILED")

# Called by Grid script to show this tile is blocked but in range
func highlight_blocked():
	#print("TILE ", grid_position, ": Setting blocked highlight (RED)")
	is_highlighted = true
	
	if blocked_material == null:
		print("  ✗ ERROR: blocked_material is null!")
		return
	
	mesh_instance.material_override = blocked_material
	#print("  ✓ Red material applied to mesh_instance")



# Called by Grid script to remove movement range highlighting
func clear_highlight():
	is_highlighted = false     # No longer highlighted
	update_appearance()        # Return to normal appearance

# Updates the tile's visual appearance based on its current state
func update_appearance():
	# If tile is highlighted (showing movement range), don't change it
	if is_highlighted:
		return # Exit function early
	
	# PRIORITY ORDER: Check states from most specific to most general
	
	# 1. OCCUPIED BY UNIT: Show orange (highest priority for occupied tiles)
	if occupied_unit != null:
		mesh_instance.material_override = occupied_material
		return
	
	# 2. PERMANENTLY BLOCKED: Show red (for terrain/obstacles)
	if not is_walkable:
		mesh_instance.material_override = blocked_material
		return
	
	# 3. DEFAULT: Show white (normal walkable tile)
	mesh_instance.material_override = default_material
	
func test_tile():
	print("Tile script is working!") #debug
