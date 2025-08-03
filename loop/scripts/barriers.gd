extends Node2D

@onready var camera = get_viewport().get_camera_2d()
var initial_y_offset: float

func _ready():
	# Store the initial Y offset relative to camera
	if camera:
		initial_y_offset = global_position.y - camera.global_position.y
	else:
		initial_y_offset = 0.0

func _process(_delta):
	if not camera:
		camera = get_viewport().get_camera_2d()
		return
	
	# Keep barriers at the same relative position to camera
	global_position.y = camera.global_position.y + initial_y_offset