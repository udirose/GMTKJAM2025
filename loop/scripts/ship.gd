extends CharacterBody2D

@export var orbit_speed := 2.0 # radians per second
@onready var ship_sprite = $Sprite2D

# Fuel system
signal fuel_changed(new_fuel_amount)
@export var max_fuel := 100.0
@export var fuel_consumption_rate := 10.0 # fuel per second when moving
@export var orbit_fuel_consumption := 5.0 # fuel per second when orbiting
var current_fuel := 100.0

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

@onready var camera = $Camera2D


func _ready():
	camera_fixed_x = camera.global_position.x

	var area = $Area2D
	if area:
		area.body_entered.connect(_on_body_entered)

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
		rotation -= PI / 8
		orbit_velocity = orbit_velocity.rotated(-PI / 8)
		dash_vector = Vector2.LEFT.rotated(rotation)
		dash_remaining = dash_distance
		consume_fuel(100.0 / 3.0)

	elif Input.is_action_just_pressed("move_right"):
		rotation += PI / 8
		orbit_velocity = orbit_velocity.rotated(PI / 8)
		dash_vector = Vector2.RIGHT.rotated(rotation)
		dash_remaining = dash_distance
		consume_fuel(100.0 / 3.0)

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

	# Camera only follows player's Y, X is fixed
	camera.global_position.x = camera_fixed_x
	camera.global_position.y = global_position.y


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

func _on_body_entered(body):
	print("Body entered: ", body.name)
	if body.is_in_group("planet"):
		print("hit planet")
		# Stop all movement
		orbit_velocity = Vector2.ZERO
		velocity = Vector2.ZERO
		forward_speed = 0.0
