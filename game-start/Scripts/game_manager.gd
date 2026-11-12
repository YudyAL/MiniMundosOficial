extends Node


signal won
signal lost
var result_won := false

const TOTAL_DESTELLOS := 12
const STREAK_WINDOW := 5.0   # segundos para encadenar la racha
const BASE_POINTS := 100

var score := 0
var streak := 0
var best_streak := 0
var calmed := 0
var streak_left := 0.0
var finished := false

func _process(delta: float) -> void:
	if streak_left > 0.0:
		streak_left -= delta
		if streak_left <= 0.0:
			streak_left = 0.0
			streak = 0   # se acabó el tiempo: reinicia la racha

func register_calm() -> void:
	calmed += 1
	if streak_left > 0.0:
		streak += 1
	else:
		streak = 1
	streak_left = STREAK_WINDOW
	best_streak = max(best_streak, streak)
	score += BASE_POINTS * streak   # más racha = más puntos
	if calmed >= TOTAL_DESTELLOS and not finished:
		finished = true
		result_won = true
		won.emit()

func reset() -> void:
	score = 0
	streak = 0
	best_streak = 0
	calmed = 0
	streak_left = 0.0
	finished = false
	result_won = false
	
func lose() -> void:
	if finished:
		return
	finished = true
	lost.emit()

func medal() -> String:
	if not result_won:
		return "Sin medalla"
	if score >= 5000:
		return "Oro"
	if score >= 2500:
		return "Plata"
	return "Bronce"
