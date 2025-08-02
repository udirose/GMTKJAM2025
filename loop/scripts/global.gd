extends Node

# Simple global highscore tracking
var highscore: int = 0

func update_highscore(new_score: int):
	if new_score > highscore:
		highscore = new_score

func get_highscore() -> int:
	return highscore
