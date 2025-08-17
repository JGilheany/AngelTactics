extends Node
class_name CitySpawner

var tiles
var grid_width
var grid_height
var tile_size
@onready var grid: Grid = get_node("/root/CombatScene/Grid") # adjust path if needed

@export var road_color := Color(0.2, 0.2, 0.2, 1.0) # asphalt grey

# Make sure you have a global grid_occupancy dictionary
# grid_occupancy[Vector2(x, z)] = true means this tile is blocked (road/pavement/building)




var road_tiles_array: Array[Vector2i] = [] # store positions for flexibility
var pavement_tiles_array: Array[Vector2i] = [] # store pavement positions


func _ready():
	generate_roads()
	generate_pavements()
	spawn_city_buildings()

# City block road generation with proper spacing
func generate_roads():
	var road_tiles := {}
	
	# Create a grid-based road system for city blocks
	var block_size = 10  # Size of each city block (including roads and pavements)
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

# Optional: Get the size of buildable areas between roads
func get_block_size() -> int:
	return 12 - 2 - 2  # block_size - road_width - (pavement_width * 2) = 8 tiles for buildings


# Your base building definitions
var base_buildings = [
	{"scene": preload("res://scenes/maps/city/Building2x4x1.tscn"), "height": 2, "width": 1},
	{"scene": preload("res://scenes/maps/city/Building2x1x2.tscn"), "height": 2, "width": 2},
	{"scene": preload("res://scenes/maps/city/Building1x4x2.tscn"), "height": 1, "width": 2}
]

# How many of each building you want
var building_counts = [10, 3, 15]  # 5 of first, 3 of second, 8 of third etc, add as necessary

# The final array that gets populated
var building_data = []

func populate_building_data():
	building_data.clear()  # Clear any existing data
	
	for i in range(base_buildings.size()):
		var building = base_buildings[i]
		var count = building_counts[i]
		
		# Add this building 'count' number of times
		for j in range(count):
			building_data.append(building)
	
	print("Total buildings: ", building_data.size())


func spawn_city_buildings():
	populate_building_data()
	for building in building_data:
		print("What have we here: ",building)
		spawn_random_building(building)


#if not aligned to grid, check out the 3d inspector for the building and adjust in transformation tab
func spawn_random_building(building_info: Dictionary) -> bool:
	var building = building_info.scene.instantiate()
	var scale_factor = 1.0
	
	# Building footprint in tiles
	var height_tiles = building_info.height
	var width_tiles = building_info.width
	
	# Try multiple times to find a valid position
	var max_attempts = 50
	for attempt in range(max_attempts):
		var spawn_x = randi() % (grid_width - width_tiles - 1)
		var spawn_z = randi() % (grid_height - height_tiles - 1)
		
		# Check if this position collides with roads/pavements
		if is_position_valid(spawn_x, spawn_z, width_tiles, height_tiles):
			var buildingspawnx = spawn_x * tile_size
			var buildingspawnz = spawn_z * tile_size
			var tile_position = Vector3(buildingspawnx, 0, buildingspawnz)
			
			print("Spawning at coordinates: ", tile_position)
			building.scale = Vector3(scale_factor, 1, scale_factor)
			building.position = tile_position
			add_child(building)
			return true  # Successfully spawned
		
		
	# If we get here, we couldn't find a valid position
	building.queue_free()  # Clean up the unused building instance
	print("Could not find valid position for building after ", max_attempts, " attempts")
	return false

# Add this alongside your other tile arrays
var non_walkable_tiles_array = []  # Populate this with non-walkable tile positions

func is_position_valid(start_x: int, start_z: int, width: int, height: int) -> bool:
	for dx in range(width+1):
		for dz in range(height+1): #offset stops it colliding with roads + pavements, possibly due to starting at0?
			var check_tile = Vector2i(start_x + dx, start_z + dz)
			
			# Check if this tile is a road, pavement, or non-walkable
			if (road_tiles_array.has(check_tile) or 
				pavement_tiles_array.has(check_tile) or 
				non_walkable_tiles_array.has(check_tile)):
				return false
	
	return true
