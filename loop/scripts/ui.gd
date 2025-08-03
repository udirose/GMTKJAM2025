extends Control

@onready var score = $score
@onready var fuel_bar = $fuel_bar
@onready var health_bar = $health_bar
@onready var game_over_screen = %GameOver
@onready var loop_button = %loop
@onready var quit_button = %quit

var current_score = 0
var max_fuel = 100.0
var current_fuel = 100.0
var max_health = 100.0
var current_health = 100.0

func _ready():
	update_score_display()
	update_fuel_display()
	update_health_display()

	# Hide game over screen initially
	if game_over_screen:
		game_over_screen.visible = false
	
	# Connect button signals
	if loop_button:
		loop_button.pressed.connect(_on_loop_button_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_button_pressed)

func increase_score(amount = 1):
	current_score += amount
	update_score_display()

func update_score_display():
	score.text = "EST DIST: "+str(current_score)

func update_fuel(new_fuel_amount: float):
	current_fuel = clamp(new_fuel_amount, 0.0, max_fuel)
	update_fuel_display()

func update_health(new_health_amount: float):
	current_health = clamp(new_health_amount, 0.0, max_health)
	update_health_display()

func update_fuel_display():
	if fuel_bar:
		var fuel_percentage = current_fuel / max_fuel
		fuel_bar.value = fuel_percentage * 100.0
		
		# Change color based on fuel level
		if fuel_percentage <= 0.25:  # Less than 1/4 - Red
			fuel_bar.modulate = Color.RED
		elif fuel_percentage <= 0.67:  # Less than 2/3 - Yellow
			fuel_bar.modulate = Color.YELLOW
		else:  # More than 2/3 - Green
			fuel_bar.modulate = Color.GREEN

func update_health_display():
	if health_bar:
		var health_percentage = current_health / max_health
		health_bar.value = health_percentage * 100.0
		
		# Change color based on health level
		if health_percentage <= 0.25:  # Less than 1/4 - Red
			health_bar.modulate = Color.RED
		elif health_percentage <= 0.67:  # Less than 2/3 - Yellow
			health_bar.modulate = Color.YELLOW
		else:  # More than 2/3 - Green
			health_bar.modulate = Color.GREEN

func show_game_over():
	# Update global highscore when game ends
	if has_node("/root/Global"):
		var global_node = get_node("/root/Global")
		global_node.update_highscore(current_score)
	
	# Restart background music on death
	if has_node("/root/SoundManager"):
		var sound_manager = get_node("/root/SoundManager")
		sound_manager.restart_music()
	
	if game_over_screen:
		game_over_screen.visible = true

func _on_loop_button_pressed():
	# Unpause the game before restarting
	get_tree().paused = false
	# Restart the current scene
	get_tree().reload_current_scene()

func _on_quit_button_pressed():
	# Unpause before quitting (just in case)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


