# This script inherits from Node3D (makes it a 3D object in the scene)
extends Node3D

# Creates a custom class called "Grid" - other scripts can reference this type
class_name Grid

# SIGNAL: This grid can send messages when tiles are selected
# Other objects (like CombatScene) can listen for this signal
signal tile_selected(tile)

# EXPORTED VARIABLES: These appear in Godot Inspector and can be tweaked per-grid
@export var grid_width: int = 10     # How many tiles wide the grid is
@export var grid_height: int = 10  # How many tiles tall the grid is  
@export var tile_size: float = 1.0    # Size of each tile in world units (1.0 = 1 meter)

# INTERNAL VARIABLES: Used by the script but not visible in Inspector
# 2D array to store all tile references - tiles[x][y] gives you the tile at position (x,y)
var tiles: Array[Array] = []

# Pre-loads the Tile scene file so we can create instances of it
# preload() happens at compile time - more efficient than load()
var tile_scene = preload("res://scenes/maps/tile.tscn")

# Reference to the "Tiles" child node that will hold all our tile instances
@onready var tiles_container = $Tiles

# _ready() runs once when this Grid is added to the scene
func _ready():
		generate_grid()    # Create all the tiles immediately

# Creates the entire grid of tiles
func generate_grid():
#	print("=== GENERATING GRID DEBUG ===")
	
	# CLEANUP: Remove any existing tiles (useful if regenerating grid)
	for child in tiles_container.get_children():
		child.queue_free()    # Safely removes child nodes next frame
	
	# INITIALIZE 2D ARRAY: Prepare the tiles array structure
	tiles.clear()                # Remove any old data
	tiles.resize(grid_width)     # Make array have 'grid_width' rows
	# ... existing setup code ...
	
	for x in range(grid_width):
		tiles[x] = []
		tiles[x].resize(grid_height)
		
		for z in range(grid_height):
			var tile_instance = tile_scene.instantiate()
			tile_instance.position = Vector3(x * tile_size, 0, z * tile_size)
			tile_instance.grid_position = Vector2i(x, z)
			
		# RANDOMLY BLOCK 20% OF TILES
			if randf() < 0.2:  # 20% chance
				tile_instance.is_walkable = false
				tile_instance.movement_cost = 999  # High cost = blocked
				print("🟥 Blocked tile at ", Vector2i(x, z))
			else:
				tile_instance.is_walkable = true
				tile_instance.movement_cost = 1
				print("🟩 Walkable tile at ", Vector2i(x, z))
		
			tiles_container.add_child(tile_instance)
			
			
			# DEBUG: Verify signal connections
			var _connection_result1 = tile_instance.tile_clicked.connect(_on_tile_clicked)
			var _connection_result2 = tile_instance.tile_hovered.connect(_on_tile_hovered)  
			var _connection_result3 = tile_instance.tile_unhovered.connect(_on_tile_unhovered)
			
			#print("  Signal connections - clicked:", connection_result1 == OK, " hovered:", connection_result2 == OK, " unhovered:", connection_result3 == OK)
			
			tiles[x][z] = tile_instance

	#print("=== GRID GENERATION COMPLETE ===")
	#print("Total tiles created: ", grid_width * grid_height)
	#print("Tiles container children: ", tiles_container.get_child_count())


# Called automatically when any tile in the grid is clicked
# The tile parameter is the specific tile that was clicked
func _on_tile_clicked(tile: Tile):
	#print("=== GRID RECEIVED CLICK ===")
	#print("✓ Tile position: ", tile.grid_position)
	#print("✓ Emitting tile_selected signal to CombatScene")
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
func get_tile(grid_pos: Vector2i) -> Tile:
	if is_valid_position(grid_pos):           # Check if coordinates are within grid bounds
		return tiles[grid_pos.x][grid_pos.y]  # Return the tile at that position
	return null                               # Return null for invalid positions

# UTILITY FUNCTION: Check if grid coordinates are within the grid boundaries
func is_valid_position(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height
	# Returns true only if: x is 0 or greater AND x is less than grid_width
	#                  AND: y is 0 or greater AND y is less than grid_height

# COORDINATE CONVERSION: Convert world position (3D space) to grid coordinates
# Useful for placing units or converting mouse clicks to grid positions
func world_to_grid(world_pos: Vector3) -> Vector2i:
	return Vector2i(
		int(round(world_pos.x / tile_size)),    # Convert X world position to grid X
		int(round(world_pos.z / tile_size))     # Convert Z world position to grid Y
	)
	# round() handles floating point precision, int() converts to integer

# COORDINATE CONVERSION: Convert grid coordinates to world position (3D space)  
# Useful for positioning units or camera focus
func grid_to_world(grid_pos: Vector2i) -> Vector3:
	return Vector3(
		grid_pos.x * tile_size,    # Grid X becomes world X
		0,                         # Y is always 0 (ground level)
		grid_pos.y * tile_size     # Grid Y becomes world Z
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
func highlight_walkable_tiles(from_position: Vector2i, movement_range: int):
	#print("=== HIGHLIGHT WALKABLE TILES DEBUG ===")
	#print("From position: ", from_position)
	#print("Movement range: ", movement_range)
	
	# Clear previous highlights
	clear_all_highlights()
	#print("✓ Cleared all previous highlights")
	
	# Get tiles in range
	var walkable_tiles = get_tiles_in_range(from_position, movement_range)
	#print("✓ Found ", walkable_tiles.size(), " tiles in range")
	
	if walkable_tiles.size() == 0:
		#print("✗ ERROR: No tiles found in range!")
		print("✗ Check if from_position ", from_position, " is valid")
		print("✗ Grid size: ", grid_width, "x", grid_height)
		return
	
	# Process each tile
	for i in range(walkable_tiles.size()):
		var tile = walkable_tiles[i]
		#print("Processing tile ", i+1, "/", walkable_tiles.size(), " at ", tile.grid_position)
		
		if tile.is_walkable:
			#print("  ✓ Tile is walkable - highlighting GREEN")
			tile.highlight_walkable()
		else:
			#print("  ✗ Tile is blocked - highlighting RED")
			tile.highlight_blocked()
	
	#print("✓ All tiles processed for highlighting")
	
	
# RANGE CALCULATION: Get all tiles within a specific distance from a position
# Uses "Manhattan distance" (sum of horizontal and vertical distance)
func get_tiles_in_range(from_position: Vector2i, movement_range: int) -> Array[Tile]:
	var tiles_in_range: Array[Tile] = []    # Array to store tiles in range
	
	# Check all tiles in a square area around the from_position
	for x in range(from_position.x - movement_range, from_position.x + movement_range + 1):
		for y in range(from_position.y - movement_range, from_position.y + movement_range + 1):
			# Calculate Manhattan distance: |x1-x2| + |y1-y2|
			var distance = abs(x - from_position.x) + abs(y - from_position.y)
			
			# Only include tiles within the specified range
			if distance <= movement_range:
				var tile = get_tile(Vector2i(x, y))    # Try to get tile at this position
				if tile:                               # If tile exists
					tiles_in_range.append(tile)        # Add it to our results
	
	return tiles_in_range    # Return all tiles found within range

# UTILITY FUNCTION: Remove highlighting from all tiles in the grid
# Useful for clearing movement range displays
func clear_all_highlights():
	# Loop through every tile in the 2D array
	for row in tiles:              # For each row (Array of tiles)
		for tile in row:           # For each tile in that row
			if tile:               # Make sure tile exists (safety check)
				tile.clear_highlight()    # Tell tile to return to normal appearance

func test_debug():
	print("Grid script: OK")
