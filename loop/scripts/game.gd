extends Node2D

var is_paused = false

func _ready():
	# Ensure the game starts unpaused
	get_tree().paused = false

func _input(event):
	if event.is_action_pressed("pause"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	
	if is_paused:
		print("Game paused")
	else:
		print("Game unpaused")
