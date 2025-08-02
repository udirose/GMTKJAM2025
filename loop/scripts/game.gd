extends Node2D

var is_paused = false

# Score tracking variables
signal score_increase(amount)
signal game_over
@onready var ui_node = $UI/UI # Adjust path as needed
@onready var ship_node = $ship
var last_ship_y_position = 0.0
var position_threshold = 50.0 # How much vertical movement needed for score increase

func _ready():
	# Ensure the game starts unpaused
	get_tree().paused = false
	
	# Connect score signal to UI
	if ui_node:
		score_increase.connect(ui_node.increase_score)
		game_over.connect(ui_node.show_game_over)
	
	# Connect fuel signal from ship to UI
	if ship_node and ui_node:
		ship_node.fuel_changed.connect(ui_node.update_fuel)
		ship_node.health_changed.connect(ui_node.update_health)
	
	# Find the ship node (adjust the path as needed)
	if ship_node:
		last_ship_y_position = ship_node.global_position.y

func _process(_delta):
	if not is_paused and ship_node:
		track_vertical_movement()
		# check_fuel_status() #restarts scene if out of fuel TODO: replace with gameover screen
		check_health_status()
		# Restart scene
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func track_vertical_movement():
	var current_y = ship_node.global_position.y
	var y_difference = last_ship_y_position - current_y
 
	# Only increase score if player has moved up (y decreased in Godot)
	if y_difference >= position_threshold:
		var score_points = int(y_difference / position_threshold)
		score_increase.emit(score_points)
		last_ship_y_position -= score_points * position_threshold

func check_fuel_status():
	if ship_node.current_fuel <= 0:
		print("Game Over - Out of Fuel!")
		is_paused = true
		get_tree().paused = true
		game_over.emit()

func check_health_status():
	if ship_node.current_health <= 0:
		print("Game Over - Ship Destroyed!")
		is_paused = true
		get_tree().paused = true
		game_over.emit()

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
