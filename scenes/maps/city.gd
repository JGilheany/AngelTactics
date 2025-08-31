extends Node
class_name CitySpawner

var tiles
var grid_width
var grid_height
var tile_size
@onready var grid: Grid = get_node("/root/CombatScene/Grid") # adjust path if needed

@export var road_color := Color(0.2, 0.2, 0.2, 1.0) # asphalt grey

var road_tiles_array: Array[Vector2i] = [] # store positions for flexibility
var pavement_tiles_array: Array[Vector2i] = [] # store pavement positions
var building_tiles_array: Array[Vector2i] = [] # Track where buildings are placed

# Building dictionaries organized by facing direction
# Each dictionary contains buildings that should face that direction
# "facing_south" means the door faces positive Z (towards higher Z values)
var buildings_facing_south = []  # Door faces +Z
var buildings_facing_north = []  # Door faces -Z
var buildings_facing_east = []   # Door faces +X
var buildings_facing_west = []   # Door faces -X


# Initialize building data for each direction
func init_building_data():
	# Organise buildings by their intended facing

	
	# Buildings that face SOUTH (+Z direction)
	buildings_facing_south = [
		{"scene": preload("res://scenes/maps/city/SApartment1.tscn"), "height": 2, "width": 2},
		{"scene": preload("res://scenes/maps/city/SBlock1.tscn"), "height": 3, "width": 5},
		{"scene": preload("res://scenes/maps/city/SBlock2.tscn"), "height": 2, "width": 2}
		]
	
	# Buildings that face NORTH (-Z direction)
	buildings_facing_north = [
		{"scene": preload("res://scenes/maps/city/NApartment2.tscn"), "height": 2, "width": 2},
		{"scene": preload("res://scenes/maps/city/NBlock1.tscn"), "height": 2, "width": 2},
		{"scene": preload("res://scenes/maps/city/NBlock2.tscn"), "height": 2, "width": 2},
	
	]
	
	# Buildings that face EAST (+X direction)
	buildings_facing_east = [
		{"scene": preload("res://scenes/maps/city/EBlock2.tscn"), "height": 2, "width": 2},
		{"scene": preload("res://scenes/maps/city/EBlock1.tscn"), "height": 5, "width": 2},
		{"scene": preload("res://scenes/maps/city/EApartment2.tscn"), "height": 2, "width": 2},
	
	]
	
	# Buildings that face WEST (-X direction)
	buildings_facing_west = [
		{"scene": preload("res://scenes/maps/city/WApartment2.tscn"), "height": 2, "width": 2},
		{"scene": preload("res://scenes/maps/city/WBlock1.tscn"), "height": 2, "width": 2},
		{"scene": preload("res://scenes/maps/city/WBlock2.tscn"), "height": 2, "width": 2}
	]

func _ready():
	init_building_data()
	print("Generating roads...")
	generate_roads()
	print("Generating pavements...")
	generate_pavements()
	print("Generating buildings...")
	spawn_city_buildings_smart()

# City block road generation with proper spacing
func generate_roads():
	var road_tiles := {}
	
	# Create a grid-based road system for city blocks
	var block_size = 12  # Size of each city block (including roads and pavements)
	var road_width = 2   # Width of roads in tiles
	var pavement_width = 1  # Width of pavements bordering roads
	
	# Generate horizontal roads
	var y = pavement_width + road_width  # Start after first pavement strip
	while y < grid_height - pavement_width - road_width:
		create_horizontal_road(y, road_width, road_tiles)
		y += block_size
	
	# Generate vertical roads
	var x = pavement_width + road_width  # Start after first pavement strip
	while x < grid_width - pavement_width - road_width:
		create_vertical_road(x, road_width, road_tiles)
		x += block_size
	
	# Create road meshes
	for tile in road_tiles.keys():
		mark_as_road(tile.x, tile.y)

# Create a horizontal road spanning the full width
func create_horizontal_road(start_y: int, width: int, road_tiles: Dictionary) -> void:
	for x in range(grid_width):
		for w in range(width):
			var y = start_y + w
			if in_bounds(Vector2i(x, y)):
				road_tiles[Vector2i(x, y)] = true

# Create a vertical road spanning the full height
func create_vertical_road(start_x: int, width: int, road_tiles: Dictionary) -> void:
	for y in range(grid_height):
		for w in range(width):
			var x = start_x + w
			if in_bounds(Vector2i(x, y)):
				road_tiles[Vector2i(x, y)] = true

# Marks a tile as a road (dark grey debug mesh)
func mark_as_road(x: int, y: int) -> void:
	if x >= 0 and x < grid_width and y >= 0 and y < grid_height:
		var tile := Vector2i(x, y)
		if not road_tiles_array.has(tile):
			road_tiles_array.append(tile)
			
			var debug_mesh := MeshInstance3D.new()
			debug_mesh.mesh = BoxMesh.new()
			debug_mesh.scale = Vector3(1, 0.05, 1)
			debug_mesh.position = Vector3(x, 0.05, y)
			
			var material := StandardMaterial3D.new()
			material.albedo_color = road_color  # Darker grey for roads
			debug_mesh.mesh.surface_set_material(0, material)
			add_child(debug_mesh)

# Generate pavements that border all roads
func generate_pavements() -> void:
	var pavement_color := Color(0.7, 0.7, 0.7, 1.0)  # Lighter grey for pavements
	
	for road_tile in road_tiles_array:
		# Check all 8 directions around each road tile (including diagonals for corners)
		var directions = [
			Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),  # Cardinal
			Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)  # Diagonal
		]
		
		for dir in directions:
			var neighbor = road_tile + dir
			# Only add pavement if inside grid and not already a road or pavement
			if in_bounds(neighbor) and not road_tiles_array.has(neighbor) and not pavement_tiles_array.has(neighbor):
				pavement_tiles_array.append(neighbor)
				create_pavement_mesh(neighbor.x, neighbor.y, pavement_color)

# Create a pavement mesh at the given position
func create_pavement_mesh(x: int, y: int, color: Color) -> void:
	var debug_mesh := MeshInstance3D.new()
	debug_mesh.mesh = BoxMesh.new()
	debug_mesh.scale = Vector3(1, 0.01, 1)  # Slightly lower than roads
	debug_mesh.position = Vector3(x, 0.025, y)
	
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	debug_mesh.mesh.surface_set_material(0, material)
	add_child(debug_mesh)

# Check if a tile position is within grid bounds
func in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 0 and tile.x < grid_width and tile.y >= 0 and tile.y < grid_height

# Enum for building facing directions
enum FacingDirection {
	NORTH,  # Door faces -Z
	SOUTH,  # Door faces +Z
	EAST,   # Door faces +X
	WEST    # Door faces -X
}

# Get the appropriate building list based on facing direction
func get_buildings_for_direction(direction: FacingDirection) -> Array:
	match direction:
		FacingDirection.SOUTH:
			return buildings_facing_south
		FacingDirection.EAST:
			return buildings_facing_east
		FacingDirection.WEST:
			return buildings_facing_west
		FacingDirection.NORTH:
			return buildings_facing_north
		_:
			return []

# Determine which direction a building should face based on adjacent pavement
func get_facing_direction(tile: Vector2i) -> FacingDirection:
	# Check which side has pavement/road (where the building should face)
	var north_tile = Vector2i(tile.x, tile.y - 1)
	var south_tile = Vector2i(tile.x, tile.y + 1)
	var east_tile = Vector2i(tile.x + 1, tile.y)
	var west_tile = Vector2i(tile.x - 1, tile.y)
	
	# Priority order: Check immediate neighbors for pavement/road
	if pavement_tiles_array.has(south_tile) or road_tiles_array.has(south_tile):
		return FacingDirection.SOUTH  # Face towards positive Z
	elif pavement_tiles_array.has(north_tile) or road_tiles_array.has(north_tile):
		return FacingDirection.NORTH  # Face towards negative Z
	elif pavement_tiles_array.has(east_tile) or road_tiles_array.has(east_tile):
		return FacingDirection.EAST   # Face towards positive X
	elif pavement_tiles_array.has(west_tile) or road_tiles_array.has(west_tile):
		return FacingDirection.WEST   # Face towards negative X
	
	# Default to south if no adjacent pavement found
	return FacingDirection.NORTH

# Check if a building can fit at the given position
func can_place_building(start_x: int, start_z: int, width: int, height: int, direction: FacingDirection) -> bool:
	# Adjust dimensions based on rotation (East/West swap width and height)
	var check_width = width
	var check_height = height
	if direction == FacingDirection.EAST or direction == FacingDirection.WEST:
		check_width = width
		check_height = height
	
	# Check all tiles the building would occupy
	for dx in range(check_width):
		for dz in range(check_height):
			var check_tile = Vector2i(start_x + dx, start_z + dz)
			
			# Check bounds
			if not in_bounds(check_tile):
				return false
			
			# Check if tile is already occupied
			if (road_tiles_array.has(check_tile) or 
				pavement_tiles_array.has(check_tile) or 
				building_tiles_array.has(check_tile)):
				return false
	
	return true

# Try to place a building at the given position
func try_place_building(tile: Vector2i, direction: FacingDirection) -> bool:
	var available_buildings = get_buildings_for_direction(direction)
	if available_buildings.is_empty():
		return false
	
	# Shuffle buildings to add variety
	available_buildings.shuffle()
	
	# Try each building type to see if it fits
	for building_info in available_buildings:
		var width = building_info.width
		var height = building_info.height
		
		# Check different positions where this building could be placed
		# to have its door face the pavement from this tile
		var positions_to_try = get_building_positions_to_try(tile, width, height, direction)
		
		for pos in positions_to_try:
			if can_place_building(pos.x, pos.y, width, height, direction):
				spawn_building_at_position(building_info, pos, direction)
				return true
	
	return false

# Get potential positions to try placing a building
func get_building_positions_to_try(tile: Vector2i, width: int, height: int, direction: FacingDirection) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	
	# Adjust for rotation
	var actual_width = width
	var actual_height = height
	if direction == FacingDirection.EAST or direction == FacingDirection.WEST:
		actual_width = height
		actual_height = width
	
	# Try different offsets to center the building or align it properly
	match direction:
		FacingDirection.SOUTH:
			# Building faces south, so it should be north of the pavement
			positions.append(Vector2i(tile.x, tile.y - actual_height +1)) #+1 here is to offset grid starting at 0
			positions.append(Vector2i(tile.x - 1, tile.y - actual_height))
			positions.append(Vector2i(tile.x - actual_width , tile.y - actual_height+1)) #+1 here is to offset grid starting at 0
		FacingDirection.NORTH:
			# Building faces north, so it should be south of the pavement
			positions.append(tile)
			positions.append(Vector2i(tile.x - 1, tile.y))
			positions.append(Vector2i(tile.x - actual_width + 1, tile.y))
		FacingDirection.EAST:
			# Building faces east, so it should be west of the pavement
			positions.append(Vector2i(tile.x - actual_width +1 , tile.y))  #+1 here is to offset grid starting at 0
			positions.append(Vector2i(tile.x - actual_width, tile.y - 1))
			positions.append(Vector2i(tile.x - actual_width, tile.y - actual_height + 1))
		FacingDirection.WEST:
			# Building faces west, so it should be east of the pavement
			positions.append(tile)
			positions.append(Vector2i(tile.x, tile.y - 1))
			positions.append(Vector2i(tile.x, tile.y - actual_height + 1))
	
	return positions

# Spawn a building at a specific position with rotation
func spawn_building_at_position(building_info: Dictionary, position: Vector2i, direction: FacingDirection) -> void:
	var building = building_info.scene.instantiate()
	
	# Calculate world position
	var world_x = position.x * tile_size
	var world_z = position.y * tile_size
	var tile_position = Vector3(world_x, 0, world_z)
	
	# Apply rotation based on direction
	#var rotation_y = 0.0
	#match direction:
		#FacingDirection.NORTH:
			#rotation_y = PI  # 180 degrees
		#FacingDirection.SOUTH:
			#rotation_y = 0.0  # 0 degrees (default)
		#FacingDirection.EAST:
			#rotation_y = -PI/2  # -90 degrees
		#FacingDirection.WEST:
			#rotation_y = PI/2  # 90 degrees
	
	building.position = tile_position
	#building.rotation.y = rotation_y
	add_child(building)
	
	# Mark tiles as occupied (accounting for rotation)
	var actual_width = building_info.width
	var actual_height = building_info.height
	if direction == FacingDirection.EAST or direction == FacingDirection.WEST:
		actual_width = building_info.height
		actual_height = building_info.width
	
	mark_building_area_as_occupied(position.x, position.y, actual_width, actual_height)
	
	print("Spawned building at ", position, " facing ", direction)

# Smart building spawning that examines tiles adjacent to pavements
func spawn_city_buildings_smart():
	# Create a list of potential building sites (tiles adjacent to pavement but not on pavement/road)
	var potential_sites = []
	
	for pavement_tile in pavement_tiles_array:
		# Check all 4 cardinal directions from each pavement
		var directions = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
		]
		
		for dir in directions:
			var adjacent_tile = pavement_tile + dir
			
			# Check if this tile could be a building site
			if (in_bounds(adjacent_tile) and 
				not road_tiles_array.has(adjacent_tile) and 
				not pavement_tiles_array.has(adjacent_tile) and 
				not building_tiles_array.has(adjacent_tile)):
				
				if not potential_sites.has(adjacent_tile):
					potential_sites.append(adjacent_tile)
	
	# Shuffle for variety
	potential_sites.shuffle()
	
	# Try to place buildings at potential sites
	var buildings_placed = 0
	var max_buildings = 20  # Adjust as needed
	
	for site in potential_sites:
		if buildings_placed >= max_buildings:
			break
			
		# Skip if this tile has been occupied by a previous building
		if building_tiles_array.has(site):
			continue
		
		# Determine facing direction
		var facing = get_facing_direction(site)
		
		# Try to place a building
		if try_place_building(site, facing):
			buildings_placed += 1
	
	print("Placed ", buildings_placed, " buildings")

# Mark all tiles that a building occupies
func mark_building_area_as_occupied(start_x: int, start_z: int, width: int, height: int):
	for dx in range(width):
		for dz in range(height):
			var occupied_tile = Vector2i(start_x + dx, start_z + dz)
			if not building_tiles_array.has(occupied_tile):
				building_tiles_array.append(occupied_tile)
	
	print("Marked building area as occupied: ", Vector2i(start_x, start_z), " size: ", width, "x", height)

# Clear all buildings (for regeneration)
func clear_all_buildings():
	# Remove all building nodes
	for child in get_children():
		if child.has_method("queue_free") and child != grid:  # Don't delete the grid!
			child.queue_free()
	
	# Clear the occupancy array 
	building_tiles_array.clear()
	
	print("All buildings cleared, ready for respawn")
