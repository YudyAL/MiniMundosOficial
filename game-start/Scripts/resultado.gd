extends CanvasLayer

var fondo := ColorRect.new()
var titulo := Label.new()
var detalle := Label.new()
var medalla := Label.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	fondo.color = Color(0, 0, 0, 0.7)
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caja.grow_vertical = Control.GROW_DIRECTION_BOTH
	caja.add_theme_constant_override("separation", 14)
	add_child(caja)

	for l in [titulo, detalle, medalla]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caja.add_child(l)
	titulo.add_theme_font_size_override("font_size", 56)

	var b1 := Button.new()
	b1.text = "Reintentar"
	b1.pressed.connect(_reintentar)
	caja.add_child(b1)
	var b2 := Button.new()
	b2.text = "Menú de inicio"
	b2.pressed.connect(_menu)
	caja.add_child(b2)

	Game.won.connect(func(): _mostrar(true))
	Game.lost.connect(func(): _mostrar(false))

func _mostrar(victoria: bool) -> void:
	titulo.text = "¡Victoria!" if victoria else "Derrota"
	detalle.text = "Puntos: %d   Mejor racha: x%d   Destellos: %d/%d" % [
		Game.score, Game.best_streak, Game.calmed, Game.TOTAL_DESTELLOS]
	medalla.text = "Medalla: " + Game.medal()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true

func _reintentar() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().reload_current_scene()

func _menu() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().change_scene_to_file("res://Escenas/MenuInicio.tscn")
