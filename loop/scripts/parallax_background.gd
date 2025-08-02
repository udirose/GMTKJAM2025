extends ParallaxBackground

@export var background_texture: Texture2D
@onready var camera = get_viewport().get_camera_2d()

func _ready():
	create_alternating_layers()

func _process(_delta):
	if camera:
		scroll_offset.y = camera.global_position.y

func create_alternating_layers():
	# Normal layer
	var layer1 = ParallaxLayer.new()
	var sprite1 = Sprite2D.new()
	sprite1.texture = background_texture
	layer1.motion_mirroring.y = background_texture.get_height() * 2  # Double height for alternating
	layer1.add_child(sprite1)
	add_child(layer1)
	
	# Flipped layer offset by texture height
	var layer2 = ParallaxLayer.new()
	var sprite2 = Sprite2D.new()
	sprite2.texture = background_texture
	sprite2.flip_v = true  # Flip vertically
	sprite2.position.y = background_texture.get_height()
	layer2.motion_mirroring.y = background_texture.get_height() * 2
	layer2.add_child(sprite2)
	add_child(layer2)
