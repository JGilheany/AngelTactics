
extends Node3D

@export var size_x: int = 2   # tiles along X (east–west)
@export var floors: int = 1   # how many Y layers to block (0 = ground only => set to 1)
@export var size_z: int = 2   # tiles along Z (north–south)


func _ready():
	_block_footprint()

func _block_footprint():
	var grid: Grid = get_node("/root/CombatScene/Grid") # adjust path if needed
	if grid == null:
		push_error("Grid node not found in scene tree.")
		return

	# Convert this building's world pos -> grid x/z. Your tile_size is ~1, so floor() is fine.
	var origin_x := int(floor(global_transform.origin.x / grid.tile_size) + 1 ) #The one is here because without it, the building blockage shifts a tile to the left
	
	var origin_z := int(floor(global_transform.origin.z / grid.tile_size))


	# Choose which Y layers to block. For ground only, use 0..0. For N floors, 0..(floors-1).
	var y_start := 0
	var y_end_exclusive: int = max(1, floors)

	for y in range(y_start, y_end_exclusive):
		for dx in range(size_x):
			for dz in range(size_z):
				var gp := Vector3i(origin_x + dx, y, origin_z + dz)
				var tile := grid.get_tile(gp)  # <-- the safe, canonical way
				if tile:
					tile.is_walkable = false
					tile.movement_cost = 999
					tile.update_appearance()
