# Mages extend the base Unit class
extends Unit
class_name Mage

func _ready():
	print("Creating a Mage unit")
	
	# Set mage-specific stats
	# Mages are fragile but powerful ranged attackers
	unit_name = "Mage"           # Display name
	max_health = 80              # Low health (fragile)
	movement_range = 2           # Low movement (not very athletic)
	attack_range = 3             # Long range (magic spells)
	attack_damage = 45           # Very high damage (powerful magic)
	armor = 0                    # No armor (cloth robes don't protect much)
	unit_color = Color.BLUE    # Blue color to represent magic
	unit_class = "mage"          # Class identifier
	
	# Call parent setup
	super()
	print("Mage unit created successfully")
