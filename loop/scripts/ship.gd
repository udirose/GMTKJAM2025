extends Node2D

@export var orbit_speed := 2.0 # radians per second

var is_orbiting := false
var orbit_center := Vector2.ZERO
var orbit_radius := 0.0
var orbit_angle := 0.0
var orbit_velocity := Vector2.ZERO
var orbit_direction := 1 # 1 for clockwise, -1 for counterclockwise

@onready var camera = $Camera2D
var normal_zoom = Vector2(1, 1)
var zoomed_out = Vector2(1.5, 1.5)  # adjust zoom level here

func _process(delta):
	# Orbit input handling
	if Input.is_action_just_pressed("orbit"):
		var planet = get_closest_planet()
		if planet:
			start_orbit(planet)

	elif Input.is_action_just_released("orbit") and is_orbiting:
		stop_orbit()

	# Movement update
	if is_orbiting:
		update_orbit(delta)
	else:
		position += orbit_velocity * delta

	# Restart scene
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	# Camera zoom smoothing
	if is_orbiting:
		camera.zoom = camera.zoom.lerp(zoomed_out, 5 * delta)
	else:
		camera.zoom = camera.zoom.lerp(normal_zoom, 5 * delta)


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
	orbit_angle = (position - orbit_center).angle()
	orbit_direction = 1 # Optional: can be dynamic

func update_orbit(delta):
	orbit_angle += orbit_speed * delta * orbit_direction
	position = orbit_center + Vector2.RIGHT.rotated(orbit_angle) * orbit_radius

	# Calculate tangent velocity for slingshot direction
	var tangent := Vector2.UP.rotated(orbit_angle) * orbit_direction
	orbit_velocity = tangent * orbit_speed * orbit_radius

func stop_orbit():
	is_orbiting = false
