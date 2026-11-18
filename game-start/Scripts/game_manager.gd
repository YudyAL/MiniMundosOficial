extends Node
# Estado global de la partida (autoload "Game"):
# puntos, rachas, objetivos del nivel, récords guardados y medallas.

signal won
signal lost
signal destello_calmado(racha: int, puntos: int)
signal enemigo_derrotado(puntos: int, es_jefe: bool)
signal objetivo_cumplido          # destellos + jefe listos: aparece la Gran Estrella
signal jugador_herido
signal pista_cambiada(texto: String)
signal mensaje(texto: String)

const STREAK_WINDOW := 5.0        # segundos para encadenar la racha
const BASE_POINTS := 100
const PUNTOS_SOMBRA := 250
const PUNTOS_JEFE := 1500
const TIEMPO_PAR := 420.0         # segundos de referencia para el bonus de tiempo
const BONUS_POR_SEGUNDO := 10
const PUNTOS_PLATA := 6000
const PUNTOS_ORO := 9000
const ARCHIVO := "user://minimundos_records.cfg"
const MEDALLAS := ["Sin medalla", "Bronce", "Plata", "Oro"]

var total_destellos := 12
var score := 0
var streak := 0
var best_streak := 0
var calmed := 0
var streak_left := 0.0
var finished := false
var result_won := false

var enemigos_derrotados := 0
var hay_jefe := false
var jefe_derrotado := false
var usa_estrella := false         # si es true, se gana tocando la Gran Estrella
var estrella_lista := false
var jugando := false
var tiempo := 0.0
var bonus_tiempo := 0
var nuevo_record := false

var records: Array = []           # [{puntos, medalla, tiempo, victoria}]
var mejor_medalla := "Sin medalla"


func _ready() -> void:
	_cargar()


func _process(delta: float) -> void:
	if jugando and not finished:
		tiempo += delta
	if streak_left > 0.0:
		streak_left -= delta
		if streak_left <= 0.0:
			streak_left = 0.0
			streak = 0   # se acabó el tiempo: reinicia la racha


func register_calm() -> void:
	if finished:
		return
	calmed += 1
	if streak_left > 0.0:
		streak += 1
	else:
		streak = 1
	streak_left = STREAK_WINDOW
	best_streak = maxi(best_streak, streak)
	var puntos := BASE_POINTS * streak   # más racha = más puntos
	score += puntos
	destello_calmado.emit(streak, puntos)
	_revisar_objetivo()


func register_enemy(es_jefe: bool) -> void:
	if finished:
		return
	enemigos_derrotados += 1
	var puntos := PUNTOS_JEFE if es_jefe else PUNTOS_SOMBRA
	score += puntos
	if es_jefe:
		jefe_derrotado = true
	enemigo_derrotado.emit(puntos, es_jefe)
	_revisar_objetivo()


func _revisar_objetivo() -> void:
	if estrella_lista or finished:
		return
	if calmed < total_destellos:
		return
	if hay_jefe and not jefe_derrotado:
		return
	estrella_lista = true
	objetivo_cumplido.emit()
	if not usa_estrella:
		win()


func win() -> void:
	if finished:
		return
	finished = true
	result_won = true
	jugando = false
	if usa_estrella:
		bonus_tiempo = maxi(0, int((TIEMPO_PAR - tiempo) * BONUS_POR_SEGUNDO))
	score += bonus_tiempo
	_guardar_resultado()
	won.emit()


func lose() -> void:
	if finished:
		return
	finished = true
	jugando = false
	_guardar_resultado()
	lost.emit()


func reset() -> void:
	score = 0
	streak = 0
	best_streak = 0
	calmed = 0
	streak_left = 0.0
	finished = false
	result_won = false
	total_destellos = 12
	enemigos_derrotados = 0
	hay_jefe = false
	jefe_derrotado = false
	usa_estrella = false
	estrella_lista = false
	jugando = false
	tiempo = 0.0
	bonus_tiempo = 0
	nuevo_record = false


func medal() -> String:
	if not result_won:
		return "Sin medalla"
	if score >= PUNTOS_ORO:
		return "Oro"
	if score >= PUNTOS_PLATA:
		return "Plata"
	return "Bronce"


func mostrar_pista(texto: String) -> void:
	pista_cambiada.emit(texto)


func mostrar_mensaje(texto: String) -> void:
	mensaje.emit(texto)


func tiempo_texto(segundos: float) -> String:
	var s := int(segundos)
	return "%02d:%02d" % [s / 60, s % 60]


# ---------- Récords ----------

func _guardar_resultado() -> void:
	var mejor_previo := 0
	if not records.is_empty():
		mejor_previo = int(records[0]["puntos"])
	nuevo_record = result_won and score > mejor_previo
	records.append({
		"puntos": score,
		"medalla": medal(),
		"tiempo": int(tiempo),
		"victoria": result_won,
	})
	records.sort_custom(func(a, b): return int(a["puntos"]) > int(b["puntos"]))
	if records.size() > 5:
		records.resize(5)
	if MEDALLAS.find(medal()) > MEDALLAS.find(mejor_medalla):
		mejor_medalla = medal()
	_escribir()


func _escribir() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("records", "lista", records)
	cfg.set_value("records", "mejor_medalla", mejor_medalla)
	cfg.save(ARCHIVO)


func _cargar() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(ARCHIVO) != OK:
		return
	var lista = cfg.get_value("records", "lista", [])
	if lista is Array:
		records = lista
	mejor_medalla = str(cfg.get_value("records", "mejor_medalla", "Sin medalla"))
