extends Control

@onready var score = $score
@onready var fuel_bar = $fuel_bar

var current_score = 0
var max_fuel = 100.0
var current_fuel = 100.0

func _ready():
	update_score_display()
	update_fuel_display()

func increase_score(amount = 1):
	current_score += amount
	update_score_display()

func update_score_display():
	score.text = "EST DIST: "+str(current_score)

func update_fuel(new_fuel_amount: float):
	current_fuel = clamp(new_fuel_amount, 0.0, max_fuel)
	update_fuel_display()

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


