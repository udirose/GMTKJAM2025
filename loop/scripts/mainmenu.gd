extends Control

@onready var play_button = %play  # Adjust path as needed
@onready var highscore = %highscore
@onready var sound_manager = get_node("/root/SoundManager")

func _ready():
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	
	# Display the current highscore
	if highscore:
		var best_score = Global.get_highscore() if has_node("/root/Global") else 0
		highscore.text = "BEST DISTANCE: [color=green]" + str(best_score)

func _on_play_button_pressed():
	# Play select sound
	if sound_manager:
		sound_manager.play_select()
		# Start background music
		sound_manager.start_music()
	
	get_tree().change_scene_to_file("res://scenes/game.tscn")
