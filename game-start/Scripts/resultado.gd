extends CanvasLayer
# Pantalla de resultado: victoria o derrota, estadísticas y medalla.

const UI = preload("res://Scripts/estilo_ui.gd")
const MENU := "res://Escenas/MenuInicio.tscn"

var fondo := ColorRect.new()
var panel := PanelContainer.new()
var titulo := Label.new()
var subtitulo := Label.new()
var detalle := Label.new()
var record := Label.new()
var label_medalla := Label.new()
var caja_medalla := CenterContainer.new()


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	fondo.color = Color(0.03, 0.01, 0.1, 0.78)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	UI.panel(panel)
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 12)
	panel.add_child(caja)

	for l: Label in [titulo, subtitulo, record, detalle, label_medalla]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(UI.texto(titulo, 64, UI.DORADO))
	caja.add_child(UI.texto(subtitulo, 22, Color(0.85, 0.8, 1.0)))
	caja.add_child(caja_medalla)
	caja.add_child(UI.texto(label_medalla, 28, UI.CREMA))
	caja.add_child(UI.texto(record, 26, Color(1.0, 0.6, 0.35)))
	caja.add_child(UI.texto(detalle, 22, UI.CREMA))

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 18)
	caja.add_child(botones)
	var b1 := UI.boton(Button.new(), 240.0)
	b1.text = "REINTENTAR"
	b1.pressed.connect(_reintentar)
	botones.add_child(b1)
	var b2 := UI.boton(Button.new(), 240.0)
	b2.text = "MENÚ DE INICIO"
	b2.pressed.connect(_menu)
	botones.add_child(b2)

	Game.won.connect(_on_won)
	Game.lost.connect(_on_lost)


func _on_won() -> void:
	_mostrar(true)


func _on_lost() -> void:
	_mostrar(false)


func _mostrar(victoria: bool) -> void:
	titulo.text = "¡VICTORIA!" if victoria else "DERROTA"
	titulo.add_theme_color_override("font_color", UI.DORADO if victoria else Color(1.0, 0.45, 0.5))
	subtitulo.text = "¡Recuperaste la Gran Estrella del Bosque Estelar!" if victoria \
			else "Las sombras te vencieron... ¡inténtalo de nuevo!"

	var lineas := "Puntos   %d\nMejor racha   x%d\nDestellos   %d / %d\nSombras derrotadas   %d\nTiempo   %s" % [
		Game.score, Game.best_streak, Game.calmed, Game.total_destellos,
		Game.enemigos_derrotados, Game.tiempo_texto(Game.tiempo)]
	if victoria and Game.bonus_tiempo > 0:
		lineas += "\nBonus de tiempo   +%d" % Game.bonus_tiempo
	detalle.text = lineas

	var nombre: String = Game.medal()
	label_medalla.text = "Medalla: " + nombre
	for h in caja_medalla.get_children():
		h.queue_free()
	caja_medalla.add_child(UI.Medalla.new(UI.color_medalla(nombre), nombre == "Sin medalla"))

	record.text = "¡NUEVO RÉCORD!"
	record.visible = Game.nuevo_record

	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

	panel.modulate.a = 0.0
	fondo.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(fondo, "modulate:a", 1.0, 0.4)
	tw.tween_property(panel, "modulate:a", 1.0, 0.5).set_delay(0.15)


func _reintentar() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().reload_current_scene()


func _menu() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().change_scene_to_file(MENU)
