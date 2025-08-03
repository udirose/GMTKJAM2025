extends Node2D

# Planet scenes and their spawn weights (higher = more common)
@export var planet_scenes: Array[PackedScene] = []
@export var planet_weights: Array[float] = []

# Pickup scenes and their spawn weights
@export var fuel_scenes: Array[PackedScene] = []
@export var health_scenes: Array[PackedScene] = []
@export var fuel_spawn_chance: float = 0.3  # 30% chance to spawn fuel pickup
@export var health_spawn_chance: float = 0.2  # 20% chance to spawn health pickup

# Spawning parameters
@export var spawn_distance_ahead: float = 1000.0  # How far ahead to spawn planets
@export var spawn_distance_behind: float = 500.0  # How far behind to keep planets before removing
@export var min_spawn_interval_y: float = 200.0   # Minimum vertical distance between planets
@export var max_spawn_interval_y: float = 500.0   # Maximum vertical distance between planets
@export var viewport_margin_x: float = 100.0      # Margin from screen edges on X axis

# Internal variables
var last_spawn_y: float = 0.0
var last_pickup_spawn_y: float = 0.0  # Track pickup spawning separately
var spawned_planets: Array[Node2D] = []
var spawned_pickups: Array[Node2D] = []  # Track pickups separately
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
	last_pickup_spawn_y = last_spawn_y  # Initialize pickup spawning
	call_deferred("spawn_initial_planets")

func _process(_delta):
	if not camera:
		camera = get_viewport().get_camera_2d()
		return
	
	check_spawn_planets()
	cleanup_old_planets()
	cleanup_old_pickups()

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
	
	# Spawn pickups independently (not tied to planet spawning)
	attempt_spawn_pickups_independently(camera_y, spawn_threshold)

func spawn_planet_at_y(y_position: float):
	if planet_scenes.is_empty():
		print("No planet scenes configured!")
		return
	
	# Check if there's already a planet too close to this position
	if is_position_too_close_to_existing_planet(y_position):
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

func is_position_too_close_to_existing_planet(y_position: float) -> bool:
	var min_distance = min_spawn_interval_y * 0.8  # Use 80% of min interval as safety buffer
	
	for planet in spawned_planets:
		if not is_instance_valid(planet):
			continue
		
		var distance = abs(planet.global_position.y - y_position)
		if distance < min_distance:
			return true
	
	return false

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

# New functions for pickup spawning (avoiding planets)
func attempt_spawn_pickups_independently(_camera_y: float, spawn_threshold: float):
	# Spawn pickups independently with their own interval
	var pickup_interval = get_random_spawn_interval() * 1.5  # Spawn pickups less frequently
	
	while last_pickup_spawn_y > spawn_threshold:
		last_pickup_spawn_y -= pickup_interval
		
		# Try to spawn fuel pickup
		if rng.randf() < fuel_spawn_chance and not fuel_scenes.is_empty():
			spawn_pickup_avoiding_planets(last_pickup_spawn_y, "fuel")
		
		# Try to spawn health pickup (with offset to avoid overlapping with fuel)
		if rng.randf() < health_spawn_chance and not health_scenes.is_empty():
			spawn_pickup_avoiding_planets(last_pickup_spawn_y + rng.randf_range(50, 150), "health")

func spawn_pickup_avoiding_planets(y_position: float, pickup_type: String):
	var pickup_scene: PackedScene = null
	
	# Choose the appropriate pickup scene
	if pickup_type == "fuel" and not fuel_scenes.is_empty():
		pickup_scene = fuel_scenes[rng.randi() % fuel_scenes.size()]
	elif pickup_type == "health" and not health_scenes.is_empty():
		pickup_scene = health_scenes[rng.randi() % health_scenes.size()]
	
	if not pickup_scene:
		return
	
	# Try to find a position that doesn't conflict with planets
	var max_attempts = 10
	var final_position: Vector2
	
	for attempt in range(max_attempts):
		# Set random X position within viewport bounds
		var viewport_width = get_viewport().get_visible_rect().size.x
		var camera_x = camera.global_position.x if camera else 0.0
		var min_x = camera_x - viewport_width/2 + viewport_margin_x
		var max_x = camera_x + viewport_width/2 - viewport_margin_x
		var random_x = rng.randf_range(min_x, max_x)
		
		final_position = Vector2(random_x, y_position)
		
		# Check if this position conflicts with any planets
		if not is_position_too_close_to_planet(final_position):
			break  # Found a good position
		
		# If we failed all attempts, add some Y offset for the last try
		if attempt == max_attempts - 1:
			final_position.y += rng.randf_range(-50, 50)
	
	# Instantiate and position the pickup
	var pickup = pickup_scene.instantiate()
	pickup.global_position = final_position
	
	# Add to scene and track it
	get_parent().call_deferred("add_child", pickup)
	spawned_pickups.append(pickup)
	
	# Add to appropriate group for collision detection
	pickup.call_deferred("add_to_group", pickup_type)

func is_position_too_close_to_planet(pickup_position: Vector2) -> bool:
	var min_distance = 80.0  # Minimum distance from any planet
	
	for planet in spawned_planets:
		if not is_instance_valid(planet):
			continue
		
		var distance = pickup_position.distance_to(planet.global_position)
		if distance < min_distance:
			return true
	
	return false

func cleanup_old_pickups():
	if not camera:
		return
	
	var camera_y = camera.global_position.y
	var cleanup_threshold = camera_y + spawn_distance_behind
	
	# Remove pickups that are too far behind
	for i in range(spawned_pickups.size() - 1, -1, -1):
		var pickup = spawned_pickups[i]
		if not is_instance_valid(pickup):
			spawned_pickups.remove_at(i)
			continue
		
		if pickup.global_position.y > cleanup_threshold:
			pickup.queue_free()
			spawned_pickups.remove_at(i)
