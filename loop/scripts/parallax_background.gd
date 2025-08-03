extends ParallaxBackground

@export var background_texture: Texture2D
@onready var camera = get_viewport().get_camera_2d()

func _ready():
	create_alternating_layers()

func _process(_delta):
	if camera:
		scroll_offset.y = camera.global_position.y

func create_alternating_layers():
	# Left side layer
	var layer1 = ParallaxLayer.new()
	var sprite1 = Sprite2D.new()
	sprite1.texture = background_texture
	sprite1.position.x = -background_texture.get_width() / 2.0
	layer1.motion_mirroring.y = background_texture.get_height()
	layer1.motion_mirroring.x = background_texture.get_width() * 2  # Wide horizontal mirroring
	layer1.add_child(sprite1)
	add_child(layer1)
	
	# Right side layer
	var layer2 = ParallaxLayer.new()
	var sprite2 = Sprite2D.new()
	sprite2.texture = background_texture
	sprite2.position.x = background_texture.get_width() / 2.0
	layer2.motion_mirroring.y = background_texture.get_height()
	layer2.motion_mirroring.x = background_texture.get_width() * 2  # Wide horizontal mirroring
	layer2.add_child(sprite2)
	add_child(layer2)
