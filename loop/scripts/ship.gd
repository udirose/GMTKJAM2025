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

# Thrust movement system
@export var thrust_power := 400.0
@export var max_thrust_velocity := 600.0
var thrust_velocity := Vector2.ZERO
@export var thrust_decay := 2.0  # How quickly thrust velocity decays

# Player always moves up at this speed
@export var forward_speed := 200.0
# Store the camera's fixed X position
var camera_fixed_x := 0.0
# Camera smoothing
@export var camera_smooth_speed := 1.0

@onready var camera = $Camera2D

# Trail system
@export var trail_length := -1  # -1 means unlimited trail length
@export var trail_width := 8.0  # Width of the trail
@export var trail_update_distance := 5.0  # Minimum distance before adding new trail point
var trail_points: Array[Vector2] = []
var trail_line: Line2D
var glow_trail_line: Line2D  # Second layer for glow effect


func _ready():
	camera_fixed_x = camera.global_position.x

	var area = $Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.area_entered.connect(_on_area_entered)
	
	# Setup trail
	setup_trail()

func _physics_process(delta):
	# Apply thrust decay when not actively thrusting
	thrust_velocity = thrust_velocity.move_toward(Vector2.ZERO, thrust_decay * delta)
	
	# Apply thrust movement
	position += thrust_velocity * delta
	
	# Apply orbital momentum
	position += orbit_velocity * delta

func _process(delta):
	# Orbit input handling
	if Input.is_action_just_pressed("orbit"):
		var planet = get_closest_planet()
		if planet:
			start_orbit(planet)

	elif Input.is_action_just_released("orbit") and is_orbiting:
		stop_orbit()
	
	# Thrust input handling
	var thrust_input := Vector2.ZERO
	
	if Input.is_action_pressed("move_up"):
		thrust_input.y -= 1.0
	if Input.is_action_pressed("move_down"):
		thrust_input.y += 1.0
	if Input.is_action_pressed("move_left"):
		thrust_input.x -= 1.0
	if Input.is_action_pressed("move_right"):
		thrust_input.x += 1.0
	
	# Apply thrust if there's input and fuel
	if thrust_input.length() > 0.0 and current_fuel > 0.0:
		var thrust_force = thrust_input.normalized() * thrust_power * delta
		thrust_velocity += thrust_force
		thrust_velocity = thrust_velocity.limit_length(max_thrust_velocity)
		
		# Consume fuel based on thrust usage
		consume_fuel(fuel_consumption_rate * thrust_input.length() * delta)

	# Movement update
	if is_orbiting:
		update_orbit(delta)
		if orbit_direction > 0:
			rotation = orbit_angle - PI
		else:
			rotation = orbit_angle
		rotation = wrapf(rotation, -PI, PI) # Ensure rotation is within -PI to PI range
	else:
		# Always move up (negative Y in Godot by default) - base forward movement
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
	
	# Update trail
	update_trail()

func setup_trail():
	# Create Line2D node for the trail
	trail_line = Line2D.new()
	trail_line.name = "ShipTrail"
	trail_line.width = trail_width
	trail_line.default_color = Color.ORANGE  # Bright cyan - more visible
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.z_index = 10  # Draw in front of everything for testing
	trail_line.z_as_relative = false  # Absolute z-index
	
	# Create flame gradient effect
	var flame_gradient = Gradient.new()
	flame_gradient.add_point(0.0, Color(0.8, 0.3, 0.1, 0.1))  # Very faint dark orange at start (oldest trail)
	flame_gradient.add_point(0.4, Color(1.0, 0.4, 0.1, 0.4))  # Dark orange
	flame_gradient.add_point(0.7, Color(1.0, 0.6, 0.2, 0.7))  # Bright orange
	flame_gradient.add_point(1.0, Color(1.0, 0.7, 0.3, 1.0))  # Bright orange-yellow at end (newest trail from ship)
	trail_line.gradient = flame_gradient
	
	# Create glow layer (wider, more transparent)
	glow_trail_line = Line2D.new()
	glow_trail_line.name = "ShipTrailGlow"
	glow_trail_line.width = trail_width * 2.5  # Much wider for glow effect
	glow_trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	glow_trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	glow_trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	glow_trail_line.z_index = 9  # Behind the main trail
	glow_trail_line.z_as_relative = false
	
	# Glow gradient (more transparent, redder)
	var glow_gradient = Gradient.new()
	glow_gradient.add_point(0.0, Color(0.6, 0.1, 0.0, 0.02))  # Very faint dark red at start
	glow_gradient.add_point(0.5, Color(0.9, 0.3, 0.1, 0.1))   # Faint orange-red
	glow_gradient.add_point(1.0, Color(1.0, 0.5, 0.2, 0.25))  # Bright orange glow at ship
	glow_trail_line.gradient = glow_gradient
		
	# Add to the game scene (parent of ship) so it doesn't move with the ship
	# Use call_deferred to avoid "busy setting up children" error
	var game_scene = get_tree().get_first_node_in_group("game")
	if game_scene:
		game_scene.call_deferred("add_child", glow_trail_line)  # Add glow first (behind)
		game_scene.call_deferred("add_child", trail_line)      # Add main trail on top
	else:
		# Fallback to parent if game group not found
		get_parent().call_deferred("add_child", glow_trail_line)
		get_parent().call_deferred("add_child", trail_line)
		
	# Initialize with ship position (deferred as well)
	call_deferred("initialize_trail_position")

func initialize_trail_position():
	# Initialize trail with ship position once everything is set up
	if trail_line and glow_trail_line:
		trail_points.append(global_position)
		trail_line.add_point(global_position)
		var _parent_name = "NO PARENT"
		if trail_line.get_parent():
			_parent_name = trail_line.get_parent().name

	else:
		print("ERROR: trail_line is null in initialize_trail_position")

func update_trail():
	# Check if trail_line exists
	if not trail_line or not glow_trail_line:
		setup_trail()
		return
	
	# Only add new point if ship has moved far enough
	if trail_points.size() == 0 or global_position.distance_to(trail_points[-1]) > trail_update_distance:
		trail_points.append(global_position)
		trail_line.add_point(global_position)
		glow_trail_line.add_point(global_position)

func update_trail_gradient():
	# Don't update gradient every frame for performance
	if trail_line and trail_line.get_point_count() > 1:
		# Create a simple gradient that fades the trail
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(0.5, 0.8, 1.0, 0.2))  # More transparent at start
		gradient.add_point(1.0, Color(0.5, 0.8, 1.0, 0.8))  # More opaque at end
		
		# Apply gradient to trail
		trail_line.gradient = gradient

func check_off_screen_death():
	var viewport_width = get_viewport().get_visible_rect().size.x
	var camera_left_bound = camera_fixed_x - viewport_width / 2
	var camera_right_bound = camera_fixed_x + viewport_width / 2
	
	# If ship is outside screen bounds while not orbiting, kill them
	if global_position.x < camera_left_bound or global_position.x > camera_right_bound:
		clear_trail()  # Clear trail on death
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

	# Calculate tangent velocity for slingshot direction (much slower)
	var tangent := Vector2.RIGHT.rotated(orbit_angle + orbit_direction * PI / 2)
	orbit_velocity = tangent * orbit_speed * orbit_radius * 0.5  # Reduce slingshot speed by 70%

func stop_orbit():
	is_orbiting = false

func clear_trail():
	if trail_line:
		trail_line.clear_points()
	if glow_trail_line:
		glow_trail_line.clear_points()
	trail_points.clear()

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
		clear_trail()  # Clear trail on death
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
