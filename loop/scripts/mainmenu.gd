extends Control

@onready var play_button = %play  # Adjust path as needed
@onready var highscore = %highscore

func _ready():
	if play_button:
		play_button.pressed.connect(_on_play_button_pressed)
	
	# Display the current highscore
	if highscore:
		var best_score = Global.get_highscore() if has_node("/root/Global") else 0
		highscore.text = "BEST DISTANCE: [color=green]" + str(best_score)

func _on_play_button_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")
