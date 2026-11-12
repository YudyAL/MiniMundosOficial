extends Node
# AUTOLOAD: Proyecto > Configuración > Autoload, nombre "Game"
# Maneja racha, puntaje y contador de Destellos.

const TOTAL_DESTELLOS := 12
const STREAK_WINDOW := 5.0   # segundos para encadenar la racha
const BASE_POINTS := 100

var score := 0
var streak := 0
var calmed := 0
var streak_left := 0.0

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
	score += BASE_POINTS * streak   # más racha = más puntos

func reset() -> void:
	score = 0
	streak = 0
	calmed = 0
	streak_left = 0.0
