extends Node2D
class_name BestDistanceMarker

# Visual marker for best distance
var marker_line: Line2D
var marker_label: Label
var camera: Camera2D
var ship: Node2D

# Best distance tracking
var best_distance_y: float = 0.0
var starting_y: float = 0.0

func _ready():
	# Find references
	camera = get_viewport().get_camera_2d()
	ship = get_tree().get_first_node_in_group("ship") if get_tree().has_group("ship") else null
	
	# Get the best distance from Global
	if has_node("/root/Global"):
		var global_node = get_node("/root/Global")
		var best_score = global_node.get_highscore()
		# Convert score to Y position (score is distance traveled upward)
		if ship:
			starting_y = ship.global_position.y
			best_distance_y = starting_y - (best_score * 50.0)  # 50 units per score point
	
	create_marker()

func create_marker():
	if Global.get_highscore() <= 0:
		return  # No best distance to show yet
	
	# Create line marker that spans across the screen
	marker_line = Line2D.new()
	marker_line.name = "BestDistanceLine"
	marker_line.width = 4.0
	marker_line.default_color = Color.GOLD
	marker_line.z_index = 15  # Draw on top
	marker_line.z_as_relative = false
	
	# Create a dashed pattern effect
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color.GOLD)
	gradient.add_point(0.5, Color(1.0, 1.0, 0.0, 0.5))  # Semi-transparent
	gradient.add_point(1.0, Color.GOLD)
	marker_line.gradient = gradient
	
	# Add points for the line (will update in _process)
	update_marker_position()
	
	# Create label
	marker_label = Label.new()
	marker_label.name = "BestDistanceLabel"
	marker_label.text = "BEST: " + str(Global.get_highscore())
	marker_label.add_theme_color_override("font_color", Color.GOLD)
	marker_label.z_index = 16
	marker_label.z_as_relative = false
	
	# Add to scene
	get_parent().add_child(marker_line)
	get_parent().add_child(marker_label)

func _process(_delta):
	if marker_line and camera:
		update_marker_position()

func update_marker_position():
	if not marker_line or not camera:
		return
	
	# Get viewport width to span the line across screen
	var viewport_width = get_viewport().get_visible_rect().size.x
	var camera_x = camera.global_position.x
	
	# Clear and redraw line points
	marker_line.clear_points()
	marker_line.add_point(Vector2(camera_x - viewport_width, best_distance_y))
	marker_line.add_point(Vector2(camera_x + viewport_width, best_distance_y))
	
	# Update label position
	if marker_label:
		marker_label.global_position = Vector2(camera_x - viewport_width/2 + 20, best_distance_y - 30)

func update_best_distance(new_best_score: int):
	if ship:
		best_distance_y = starting_y - (new_best_score * 50.0)
		if marker_label:
			marker_label.text = "BEST: " + str(new_best_score)

func cleanup():
	if marker_line:
		marker_line.queue_free()
	if marker_label:
		marker_label.queue_free()
