extends CanvasLayer

var panel := PanelContainer.new()
var caja := VBoxContainer.new()
var label_destellos := Label.new()
var label_puntos := Label.new()
var label_racha := Label.new()
var bar := ProgressBar.new()

func _ready() -> void:
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.05, 0.1, 0.2, 0.65)
	estilo.set_corner_radius_all(12)
	estilo.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", estilo)
	panel.position = Vector2(20, 16)
	add_child(panel)

	caja.add_theme_constant_override("separation", 6)
	panel.add_child(caja)

	for l in [label_puntos, label_destellos, label_racha]:
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 4)
		caja.add_child(l)
	label_puntos.add_theme_font_size_override("font_size", 32)

	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(1, 1, 1, 0.15)
	fondo.set_corner_radius_all(7)
	var relleno := StyleBoxFlat.new()
	relleno.bg_color = Color(1, 0.78, 0.2)
	relleno.set_corner_radius_all(7)
	bar.add_theme_stylebox_override("background", fondo)
	bar.add_theme_stylebox_override("fill", relleno)
	bar.custom_minimum_size = Vector2(240, 14)
	bar.max_value = Game.STREAK_WINDOW
	bar.show_percentage = false
	caja.add_child(bar)

func _process(_delta: float) -> void:
	label_puntos.text = "★ %d" % Game.score
	label_destellos.text = "Destellos  %d / %d" % [Game.calmed, Game.TOTAL_DESTELLOS]
	label_racha.text = "Racha x%d" % Game.streak
	label_racha.visible = Game.streak > 0
	bar.visible = Game.streak_left > 0.0
	bar.value = Game.streak_left
