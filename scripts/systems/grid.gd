# This script inherits from Node3D (makes it a 3D object in the scene)
extends Node3D

# Creates a custom class called "Grid" - other scripts can reference this type
class_name Grid

# SIGNAL: This grid can send messages when tiles are selected
# Other objects (like CombatScene) can listen for this signal
signal tile_selected(tile)

# EXPORTED VARIABLES:
@export var grid_width: int = 10     # How many tiles wide the grid is
@export var grid_height: int = 10  # How many tiles tall the grid is  
@export var grid_depth: int = 5  # number of vertical layers
@export var tile_size: float = 1.0    # Size of each tile in world units (1.0 = 1 meter)


# INTERNAL VARIABLES: Used by the script but not visible in Inspector
@export var tiles: Array = []  # 3D array tiles[x][y][z]
var current_layer: int = 0

# Pre-loads the Tile scene file so we can create instances of it
# preload() happens at compile time - more efficient than load()
var tile_scene = preload("res://scenes/maps/tile.tscn")


# Reference to the "Tiles" child node that will hold all our tile instances
@onready var tiles_container = $Tiles
@onready var building_spawner = CityBuildingSpawner.new()

# _ready() runs once when this Grid is added to the scene
func _ready():
	generate_grid()    # Create all the tiles immediately
		
		

	# Pass grid data to spawner
	building_spawner.tiles = tiles
	building_spawner.grid_height = grid_height
	building_spawner.grid_width = grid_width

	building_spawner.tile_size = tile_size

	add_child(building_spawner)
	building_spawner.spawn_city_buildings()
	
	
	
	set_visible_layer(0)




# Creates the entire grid of tiles
func generate_grid():
	# --- CLEANUP ---
	for child in tiles_container.get_children():
		child.queue_free()

	tiles.clear()
	tiles.resize(grid_width)

	# --- GRID CREATION ---
	for x in range(grid_width):
		tiles[x] = []
		for y in range(grid_depth):
			tiles[x].append([])
			for z in range(grid_height):

				var tile_instance = tile_scene.instantiate()

				# Store logical grid position as pure integers
				var grid_pos = Vector3i(x, y, z)
				tile_instance.grid_position = grid_pos

				# Place in world space (scaled by tile_size)
				tile_instance.position = Vector3(
					x * tile_size,
					y * tile_size,
					z * tile_size
				)

				# Walkability rules
				#if y == 0:
					#if randf() < 0.2:
						#tile_instance.is_walkable = false
						#tile_instance.movement_cost = 999
						#print("🟥 Blocked tile at ", grid_pos)
					#else:
						#tile_instance.is_walkable = true
						#tile_instance.movement_cost = 1
						#print("🟩 Walkable tile at ", grid_pos)
				#else:
					#tile_instance.is_walkable = false
					#tile_instance.movement_cost = 999
					


				# Add tile to container
				tiles_container.add_child(tile_instance)

				# Connect signals only if not already connected
				if not tile_instance.tile_clicked.is_connected(_on_tile_clicked):
					tile_instance.tile_clicked.connect(_on_tile_clicked)
				if not tile_instance.tile_hovered.is_connected(_on_tile_hovered):
					tile_instance.tile_hovered.connect(_on_tile_hovered)
				if not tile_instance.tile_unhovered.is_connected(_on_tile_unhovered):
					tile_instance.tile_unhovered.connect(_on_tile_unhovered)

				# Store tile in 3D array
				tiles[x][y].append(tile_instance)




# Called automatically when any tile in the grid is clicked
# The tile parameter is the specific tile that was clicked
func _on_tile_clicked(tile: Tile):
	print("=== GRID RECEIVED CLICK ===")
	print("✓ Tile position: ", tile.grid_position)
	print("✓ Emitting tile_selected signal to CombatScene")
	tile_selected.emit(tile)



# Called automatically when mouse hovers over any tile
func _on_tile_hovered(tile: Tile):

	if not tile.is_highlighted:
		tile.mesh_instance.material_override = tile.hover_material



# Called automatically when mouse stops hovering over any tile  
func _on_tile_unhovered(tile: Tile):
	if not tile.is_highlighted:
		tile.update_appearance()


# UTILITY FUNCTION: Get a specific tile by grid coordinates
# Returns the Tile object at position (grid_pos.x, grid_pos.y) or null if invalid
func get_tile(grid_pos: Vector3i) -> Tile:
	if grid_pos.x >= 0 and grid_pos.x < grid_width \
	and grid_pos.y >= 0 and grid_pos.y < grid_depth \
	and grid_pos.z >= 0 and grid_pos.z < grid_height:
		return tiles[grid_pos.x][grid_pos.y][grid_pos.z]
	return null
	
	
# UTILITY FUNCTION: Check if grid coordinates are within the grid boundaries
func is_valid_position(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height
	# Returns true only if: x is 0 or greater AND x is less than grid_width
	#                  AND: y is 0 or greater AND y is less than grid_height


# COORDINATE CONVERSION: Convert grid coordinates to world position (3D space)  
# Useful for positioning units or camera focus
func grid_to_world(grid_pos: Vector3i) -> Vector3:
	return Vector3(
		grid_pos.x * tile_size,    # Grid X becomes world X
		0,                         # Y is always 0 (ground level)
		grid_pos.y * tile_size)     # Grid Y becomes world Z

# COORDINATE CONVERSION: Convert world position (3D space) to grid coordinates
# Useful for placing units or converting mouse clicks to grid positions
func world_to_grid(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(world_pos.x / tile_size)),
		0,
		int(floor(world_pos.z / tile_size))
	)

# PATHFINDING HELPER: Get all tiles adjacent to a given position
# Returns array of up to 4 neighboring tiles (North, East, South, West)
func get_neighbors(grid_pos: Vector2i) -> Array[Tile]:
	var neighbors: Array[Tile] = []      # Array to store neighbor tiles
	
	# Define the 4 cardinal directions as coordinate offsets
	var directions = [
		Vector2i(0, 1),   # North: same X, Y+1
		Vector2i(1, 0),   # East:  X+1, same Y  
		Vector2i(0, -1),  # South: same X, Y-1
		Vector2i(-1, 0),  # West:  X-1, same Y
	]
	
	# Check each direction
	for direction in directions:
		var neighbor_pos = grid_pos + direction    # Calculate neighbor's position
		var neighbor = get_tile(neighbor_pos)      # Try to get tile at that position
		if neighbor:                               # If tile exists (not null)
			neighbors.append(neighbor)             # Add it to neighbors array
	
	return neighbors    # Return all valid neighbors found

# MOVEMENT SYSTEM: Highlight all tiles within movement range of a position
# Shows green for walkable tiles, red for blocked tiles
# MOVEMENT SYSTEM: Highlight all walkable tiles in range
func highlight_walkable_tiles(from_position: Vector3i, movement_range: int):
	clear_all_highlights()

	var walkable_tiles = get_tiles_in_range(from_position, movement_range)
	if walkable_tiles.is_empty():
		print("✗ No tiles found in range from ", from_position)
		return

	var layer_y = from_position.y
	for x in range(from_position.x - movement_range, from_position.x + movement_range + 1):
		for z in range(from_position.z - movement_range, from_position.z + movement_range + 1):
			var distance = abs(x - from_position.x) + abs(z - from_position.z)
			if distance <= movement_range:
				var check_pos = Vector3i(x, layer_y, z)
				var tile = get_tile(check_pos)
				if tile:
					if tile.is_walkable:
						tile.highlight_walkable()
					else:
						tile.highlight_blocked()



# RANGE CALCULATION: Get all tiles within movement range from a specific position
func get_tiles_in_range(from_position: Vector3i, movement_range: int) -> Array[Tile]:
	var tiles_in_range: Array[Tile] = []

	for x in range(from_position.x - movement_range, from_position.x + movement_range + 1):
		for z in range(from_position.z - movement_range, from_position.z + movement_range + 1):

			var distance = abs(x - from_position.x) + abs(z - from_position.z)

			if distance <= movement_range:
				var check_pos = Vector3i(x, from_position.y, z)
				var tile = get_tile(check_pos)
				if tile:
					tiles_in_range.append(tile)

	return tiles_in_range


# UTILITY FUNCTION: Remove highlighting from all tiles in the grid
# Useful for clearing movement range displays
func clear_all_highlights():
	for x in range(grid_width):
		for y in range(grid_depth):
			for z in range(grid_height):
				var tile = tiles[x][y][z]
				if tile:
					tile.clear_highlight()


func test_debug():
	print("Grid script: OK")



func set_visible_layer(layer_y: int):
	for x in range(grid_width):
		for y in range(grid_depth):
			for z in range(grid_height):
				var tile = tiles[x][y][z]
				if not tile:
					continue

				var mesh = tile.mesh_instance
				var staticb = tile.static_body
				var area = tile.area

				# Active layer = fully visible + interactive
				if y == layer_y:
					tile.visible = true
					if mesh: mesh.visible = true
					if staticb:
						staticb.collision_layer = 1
						staticb.collision_mask = 0
					if area:
						area.collision_layer = 1
						area.monitoring = true
						area.monitorable = true

				# Above layers = hidden and non-interactive
				elif y > layer_y:
					tile.visible = false
					if mesh: mesh.visible = false
					if staticb:
						staticb.collision_layer = 0
						staticb.collision_mask = 0
					if area:
						area.collision_layer = 0
						area.monitoring = false
						area.monitorable = false

				# Below layers = hidden and non-interactive
				else:
					tile.visible = false
					if mesh: mesh.visible = false
					if staticb:
						staticb.collision_layer = 0
						staticb.collision_mask = 0
					if area:
						area.collision_layer = 0
						area.monitoring = false
						area.monitorable = false


func switch_layer(delta: int):
	current_layer = clamp(current_layer + delta, 0, grid_depth - 1)
	set_visible_layer(current_layer)
	print("📐 Now viewing layer %d" % current_layer)




func world_to_tile(world_pos: Vector3) -> Vector3i:
	var tile_x = int(floor(world_pos.x / tile_size))
	var tile_y = int(floor(world_pos.y / tile_size)) # if you care about vertical tiles
	var tile_z = int(floor(world_pos.z / tile_size))
	return Vector3i(tile_x, tile_y, tile_z)
