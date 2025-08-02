extends Node2D

# Planet scenes and their spawn weights (higher = more common)
@export var planet_scenes: Array[PackedScene] = []
@export var planet_weights: Array[float] = []

# Spawning parameters
@export var spawn_distance_ahead: float = 1000.0  # How far ahead to spawn planets
@export var spawn_distance_behind: float = 500.0  # How far behind to keep planets before removing
@export var min_spawn_interval_y: float = 200.0   # Minimum vertical distance between planets
@export var max_spawn_interval_y: float = 500.0   # Maximum vertical distance between planets
@export var viewport_margin_x: float = 100.0      # Margin from screen edges on X axis

# Internal variables
var last_spawn_y: float = 0.0
var spawned_planets: Array[Node2D] = []
var camera: Camera2D
var rng: RandomNumberGenerator

func _ready():
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# Find the camera - adjust path as needed
	camera = get_viewport().get_camera_2d()
	
	# Set up default planet weights if not configured
	if planet_weights.is_empty() and not planet_scenes.is_empty():
		setup_default_weights()
	
	# Spawn initial planets (deferred to avoid scene setup conflicts)
	last_spawn_y = camera.global_position.y if camera else 0.0
	call_deferred("spawn_initial_planets")

func _process(_delta):
	if not camera:
		camera = get_viewport().get_camera_2d()
		return
	
	check_spawn_planets()
	cleanup_old_planets()

func setup_default_weights():
	# Set up weights where first few planets are more common
	planet_weights.clear()
	for i in range(planet_scenes.size()):
		if i < 3:
			planet_weights.append(3.0)  # Common planets
		elif i < 6:
			planet_weights.append(2.0)  # Uncommon planets
		else:
			planet_weights.append(1.0)  # Rare planets

func spawn_initial_planets():
	# Spawn planets behind and ahead of starting position
	var start_y = last_spawn_y
	for i in range(5):  # Spawn 5 planets initially
		var spawn_y = start_y - (i + 1) * get_random_spawn_interval()
		spawn_planet_at_y(spawn_y)

func check_spawn_planets():
	var camera_y = camera.global_position.y
	var spawn_threshold = camera_y - spawn_distance_ahead
	
	# Spawn planets ahead of the camera
	while last_spawn_y > spawn_threshold:
		last_spawn_y -= get_random_spawn_interval()
		spawn_planet_at_y(last_spawn_y)

func spawn_planet_at_y(y_position: float):
	if planet_scenes.is_empty():
		print("No planet scenes configured!")
		return
	
	# Get a random planet scene based on weights
	var planet_scene = get_weighted_random_planet()
	if not planet_scene:
		return
	
	# Instantiate the planet
	var planet = planet_scene.instantiate()
	
	# Set random X position within viewport bounds
	var viewport_width = get_viewport().get_visible_rect().size.x
	var camera_x = camera.global_position.x if camera else 0.0
	var min_x = camera_x - viewport_width/2 + viewport_margin_x
	var max_x = camera_x + viewport_width/2 - viewport_margin_x
	var random_x = rng.randf_range(min_x, max_x)
	
	# Position the planet
	planet.global_position = Vector2(random_x, y_position)
	
	# Add to scene and track it (deferred to avoid conflicts)
	get_parent().call_deferred("add_child", planet)
	spawned_planets.append(planet)
	
	# Add to planet group for collision detection (deferred)
	planet.call_deferred("add_to_group", "planet")

func get_weighted_random_planet() -> PackedScene:
	if planet_scenes.is_empty():
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for weight in planet_weights:
		total_weight += weight
	
	# Get random value
	var random_value = rng.randf() * total_weight
	
	# Find the selected planet
	var current_weight = 0.0
	for i in range(planet_scenes.size()):
		current_weight += planet_weights[i] if i < planet_weights.size() else 1.0
		if random_value <= current_weight:
			return planet_scenes[i]
	
	# Fallback to first planet
	return planet_scenes[0]

func get_random_spawn_interval() -> float:
	return rng.randf_range(min_spawn_interval_y, max_spawn_interval_y)

func cleanup_old_planets():
	if not camera:
		return
	
	var camera_y = camera.global_position.y
	var cleanup_threshold = camera_y + spawn_distance_behind
	
	# Remove planets that are too far behind
	for i in range(spawned_planets.size() - 1, -1, -1):
		var planet = spawned_planets[i]
		if not is_instance_valid(planet):
			spawned_planets.remove_at(i)
			continue
		
		if planet.global_position.y > cleanup_threshold:
			planet.queue_free()
			spawned_planets.remove_at(i)

# Function to add planet scenes and weights from the editor or code
func add_planet_type(scene: PackedScene, weight: float = 1.0):
	planet_scenes.append(scene)
	planet_weights.append(weight)

# Function to configure planet spawn rates
func set_planet_rarity(planet_index: int, weight: float):
	if planet_index < planet_weights.size():
		planet_weights[planet_index] = weight
