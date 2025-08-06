extends Unit
class_name Hound

func _ready():
	# Set hound-specific stats (based on warrior stats)
	unit_name = "Hound"
	max_health = 120
	movement_range = 2
	attack_range = 1  # Melee attacker
	attack_damage = 25
	armor = 2  # Slightly more armored than basic warrior
	unit_color = Color.BLACK  # Dark color for hounds
	team = "enemy"  # Always enemy team
	
	# Call parent _ready to initialize everything
	super._ready()
	
	print("Hound spawned: %s with %d HP" % [unit_name, max_health])

func setup_visual():
	"""Override visual setup to make hounds look different"""
	super.setup_visual()  # Call parent setup first
	
	# Make the hound slightly larger and darker
	if mesh_instance and mesh_instance.mesh:
		var mesh = mesh_instance.mesh as BoxMesh
		mesh.size = Vector3(0.9, 1.1, 0.9)  # Slightly bigger than regular units
	
	# Darker, more menacing appearance
	if default_material:
		default_material.albedo_color = unit_color.darkened(0.2)
		default_material.metallic = 0.3  # Slight metallic sheen
		default_material.roughness = 0.7
