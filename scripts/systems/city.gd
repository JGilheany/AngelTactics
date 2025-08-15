extends Node
class_name CityBuildingSpawner

var tiles
var grid_width
var grid_height
var tile_size

#input buildings that you want to load (their verticality doesn't matter
var building_data = [
	{"scene": preload("res://scenes/maps/city/Building2x4x1.tscn"), "height": 2, "width": 1},
	{"scene": preload("res://scenes/maps/city/Building2x1x2.tscn"), "height": 2, "width": 2},
	{"scene": preload("res://scenes/maps/city/Building1x4x2.tscn"), "height": 1, "width": 2}
]

func spawn_city_buildings():
	for building in building_data:
		print("What have we here: ",building)
		spawn_random_building(building)


#if not aligned to grid, check out the 3d inspector for the building and adjust in transformation tab
func spawn_random_building(building_info: Dictionary):
	var building = building_info.scene.instantiate()
	var scale_factor = 1.0

	# Building footprint in tiles
	var height_tiles = building_info.height
	var width_tiles = building_info.width
	
	var spawn_x = randi() % (grid_height - height_tiles)
	print("Spawning at ",spawn_x)
	var spawn_z = randi() % (grid_width - width_tiles)
	print("Spawning at ",spawn_z)


	var buildingspawnx = spawn_x * tile_size #tile_size does equal 1 but still
	var buildingspawnz = spawn_z * tile_size
	# Convert tile coordinates to world coordinates
	var tile_position = Vector3((buildingspawnx), 0, (buildingspawnz)) #hardcoded 0.5 to counteract weird offset
	print("Spawning at ", tile_position)
	building.scale = Vector3(scale_factor, 1, scale_factor)
	building.position = tile_position  # ✅ Use actual world position
	
	add_child(building)
