# Archers extend the base Unit class
extends Unit
class_name Archer

func _ready():
	print("Creating an Archer unit")
	
	# Set archer-specific stats
	# Archers are mobile ranged attackers with moderate stats
	unit_name = "Archer"         # Display name
	max_health = 90              # Medium health
	movement_range = 3           # High movement (mobile and agile)
	attack_range = 4             # Very long range (bows have good range)
	attack_damage = 30           # Medium damage (less than magic, more than melee)
	armor = 2                    # Light armor (leather protection)
	unit_color = Color.GREEN     # Green color to represent nature/hunting
	unit_class = "archer"        # Class identifier
	
	# Call parent setup
	super()
	print("Archer unit created successfully")
