extends CharacterBody2D

@export var orbit_speed := 2.0 # radians per second
@onready var ship_sprite = $Sprite2D

# Fuel system
signal fuel_changed(new_fuel_amount)
signal health_changed(new_health_amount)
@export var max_fuel := 100.0
@export var max_health := 100.0
@export var fuel_consumption_rate := 33.0 # fuel per second when moving
var current_fuel := 100.0
var current_health := 100.0

var is_orbiting := false
var orbit_center := Vector2.ZERO
var orbit_radius := 0.0
var orbit_angle := 0.0
var orbit_velocity := Vector2.ZERO
var orbit_direction := 1 # 1 for clockwise, -1 for counterclockwise

var dash_vector: Vector2 = Vector2.ZERO
var dash_speed := 800.0
var dash_distance := 100.0
var dash_remaining := 0.0

# Player always moves up at this speed
@export var forward_speed := 200.0
# Store the camera's fixed X position
var camera_fixed_x := 0.0
# Camera smoothing
@export var camera_smooth_speed := 1.0

@onready var camera = $Camera2D


func _ready():
	camera_fixed_x = camera.global_position.x

	var area = $Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.area_entered.connect(_on_area_entered)

func _physics_process(delta):
	# Apply dash movement if in progress
	if dash_remaining > 0.0:
		var dash_step = min(dash_speed * delta, dash_remaining)
		var dash_move = dash_vector.normalized() * dash_step
		position += dash_move
		dash_remaining -= dash_step

		# Apply momentum
		position += orbit_velocity * delta

func _process(delta):
	# Orbit input handling
	if Input.is_action_just_pressed("orbit"):
		var planet = get_closest_planet()
		if planet:
			start_orbit(planet)

	elif Input.is_action_just_released("orbit") and is_orbiting:
		stop_orbit()
	
	if Input.is_action_just_pressed("move_left"):
		if current_fuel <= fuel_consumption_rate:
			return  # No fuel to move left
		rotation -= PI / 8
		orbit_velocity = orbit_velocity.rotated(-PI / 8)
		dash_vector = Vector2.LEFT.rotated(rotation)
		dash_remaining = dash_distance
		consume_fuel(fuel_consumption_rate)

	elif Input.is_action_just_pressed("move_right"):
		if current_fuel <= fuel_consumption_rate:
			return  # No fuel to move right
		rotation += PI / 8
		orbit_velocity = orbit_velocity.rotated(PI / 8)
		dash_vector = Vector2.RIGHT.rotated(rotation)
		dash_remaining = dash_distance
		consume_fuel(fuel_consumption_rate)

	# Movement update
	if is_orbiting:
		update_orbit(delta)
		if orbit_direction > 0:
			rotation = orbit_angle - PI
		else:
			rotation = orbit_angle
		rotation = wrapf(rotation, -PI, PI) # Ensure rotation is within -PI to PI range
	else:
		# Always move up (negative Y in Godot by default)
		position.y -= forward_speed * delta
		position += orbit_velocity * delta

	# Camera follows player's Y, and X if orbiting off-screen
	camera.global_position.y = global_position.y
	
	if is_orbiting:
		# Check if ship is out of bounds horizontally based on CURRENT camera position
		var viewport_width = get_viewport().get_visible_rect().size.x
		var camera_left_bound = camera.global_position.x - viewport_width / 2
		var camera_right_bound = camera.global_position.x + viewport_width / 2
		
		# Use faster smoothing when orbiting to reduce jitter
		var orbit_smooth_speed = camera_smooth_speed
		
		# Smoothly follow X if ship is outside the current camera view
		if global_position.x < camera_left_bound or global_position.x > camera_right_bound:
			camera.global_position.x = lerp(camera.global_position.x, global_position.x, orbit_smooth_speed * delta)
		else:
			# When ship is in view, gently pull camera back toward fixed position
			var target_x = lerp(camera.global_position.x, camera_fixed_x, 0.3)
			camera.global_position.x = lerp(camera.global_position.x, target_x, orbit_smooth_speed * delta)
	else:
		# Smoothly return to fixed X when not orbiting
		camera.global_position.x = lerp(camera.global_position.x, camera_fixed_x, camera_smooth_speed * delta)
		
		# Check if player is off-screen while not orbiting - kill them
		check_off_screen_death()

func check_off_screen_death():
	var viewport_width = get_viewport().get_visible_rect().size.x
	var camera_left_bound = camera_fixed_x - viewport_width / 2
	var camera_right_bound = camera_fixed_x + viewport_width / 2
	
	# If ship is outside screen bounds while not orbiting, kill them
	if global_position.x < camera_left_bound or global_position.x > camera_right_bound:
		print("Player went off-screen while not orbiting - Game Over!")
		reduce_health(current_health)  # Kill the player


func get_closest_planet() -> Node2D:
	var closest: Node2D = null
	var min_dist := INF
	for planet in get_tree().get_nodes_in_group("planet"):
		var dist := position.distance_to(planet.global_position)
		if dist < min_dist:
			min_dist = dist
			closest = planet
	return closest

func start_orbit(planet: Node2D):
	is_orbiting = true
	orbit_center = planet.global_position
	orbit_radius = position.distance_to(orbit_center)
	orbit_speed = max(1.5, -0.03 * orbit_radius + 12.0)
	orbit_angle = (position - orbit_center).angle()
	var to_center = orbit_center - position
	var tangential_direction = orbit_velocity.cross(to_center)

	if tangential_direction > 0:
		orbit_direction = 1 # Counterclockwise
	else:
		orbit_direction = -1 # Clockwise

func update_orbit(delta):
	orbit_angle += orbit_speed * delta * orbit_direction
	position = orbit_center + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius

	# Calculate tangent velocity for slingshot direction
	var tangent := Vector2.RIGHT.rotated(orbit_angle + orbit_direction * PI / 2)
	orbit_velocity = tangent * orbit_speed * orbit_radius

func stop_orbit():
	is_orbiting = false

func consume_fuel(amount: float):
	current_fuel = max(0.0, current_fuel - amount)
	fuel_changed.emit(current_fuel)

func add_fuel(amount: float):
	current_fuel = min(max_fuel, current_fuel + amount)
	fuel_changed.emit(current_fuel)

func reduce_health(amount: float):
	current_health = max(0.0, current_health - amount)
	health_changed.emit(current_health)
	# if current_health <= 0.0:
	# 	die()

func add_health(amount: float):
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health)

func _on_body_entered(body):
	print("Body entered: ", body.name)
	if body.is_in_group("planet"):
		print("hit planet")
		# Stop all movement
		orbit_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		forward_speed = 0.0
		reduce_health(100.0)  # Example damage on collision

func _on_area_entered(area):
	print("Area entered: ", area.name)
	if area.is_in_group("barrier") and not is_orbiting:
		print("Hit barrier while not orbiting!")
		# Damage the ship
		reduce_health(20.0)
		
		# Determine which side barrier was hit and bounce in opposite direction
		var barrier_x = area.global_position.x
		var ship_x = global_position.x
		
		if ship_x > barrier_x:
			# Hit left barrier, push right
			orbit_velocity.x += 150.0
		else:
			# Hit right barrier, push left
			orbit_velocity.x -= 150.0
		
		# Add some upward velocity to help escape
		orbit_velocity.y -= 50.0
