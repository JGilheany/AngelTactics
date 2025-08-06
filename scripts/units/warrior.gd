
# This script extends the base Unit class
# This means Warrior gets all the functions and variables from Unit,
# but can override or add to them
extends Unit

# This creates a custom class called "Warrior"
class_name Warrior

# _ready() runs when the Warrior is created
# We override the parent's _ready() to set warrior-specific stats
func _ready():
	print("Creating a Warrior unit")
	
	# Set warrior-specific stats BEFORE calling the parent's setup
	# Warriors are tough melee fighters with high health and armor
	unit_name = "Warrior"        # Display name
	max_health = 120             # High health (tanky)
	movement_range = 2           # Low movement (heavy armor slows them down)
	attack_range = 1             # Melee only (must be adjacent to attack)
	attack_damage = 35           # High damage (strong attacks)
	armor = 5                    # High armor (reduces incoming damage)
	unit_color = Color.RED       # Red color to represent strength/aggression
	unit_class = "warrior"       # Class identifier
	
	# Call the parent's _ready() function to do all the setup work
	# super() = "call the parent class's version of this function"
	super()
	print("Warrior unit created successfully")
