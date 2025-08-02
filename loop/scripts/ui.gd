extends Control

@onready var score = $score

var current_score = 0

func _ready():
	update_score_display()

func increase_score(amount = 1):
	current_score += amount
	update_score_display()

func update_score_display():
	score.text = "EST DIST: "+str(current_score)


