extends Control

const ESCENA_JUEGO := "res://Escenas/isla.tscn"

const CIELO_ARRIBA := Color("4fa8e8")
const CIELO_ABAJO := Color("b5e2f7")
const PASTO := Color("5dbb3f")
const PASTO_OSCURO := Color("3f9a2c")
const TIERRA := Color("8a5a33")
const PINO := Color("2d7a3a")
const PINO_OSCURO := Color("1f5a2b")
const TRONCO := Color("6b4423")

@onready var titulo: Label = $VBox/Titulo
@onready var btn_jugar: Button = $VBox/Jugar
@onready var btn_puntuaciones: Button = $VBox/Puntuaciones
@onready var btn_medallas: Button = $VBox/Medallas
@onready var btn_salir: Button = $VBox/Salir

func _ready() -> void:
	resized.connect(queue_redraw)

	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 64)
	titulo.add_theme_color_override("font_color", Color("fff3c4"))
	titulo.add_theme_color_override("font_outline_color", Color("5a3a1c"))
	titulo.add_theme_constant_override("outline_size", 12)

	for b: Button in [btn_jugar, btn_puntuaciones, btn_medallas, btn_salir]:
		_estilo_madera(b)

	# Hasta el avance 2
	btn_puntuaciones.disabled = true
	btn_medallas.disabled = true

	btn_jugar.pressed.connect(_on_jugar)
	btn_salir.pressed.connect(func(): get_tree().quit())

func _on_jugar() -> void:
	get_tree().change_scene_to_file(ESCENA_JUEGO)

func _estilo_madera(b: Button) -> void:
	b.custom_minimum_size = Vector2(260, 52)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color("fff3c4"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_stylebox_override("normal", _caja(Color("a0693a")))
	b.add_theme_stylebox_override("hover", _caja(Color("bd7f48")))
	b.add_theme_stylebox_override("pressed", _caja(Color("7d4e28")))
	b.add_theme_stylebox_override("disabled", _caja(Color("8a7a6a")))

func _caja(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = Color("4a2c14")
	s.set_border_width_all(4)
	s.set_corner_radius_all(6)
	return s

# ---------- Fondo ----------
func _draw() -> void:
	var w := size.x
	var h := size.y
	var suelo := h * 0.78

	# Cielo en franjas
	var franjas := 24
	for i in franjas:
		var c := CIELO_ARRIBA.lerp(CIELO_ABAJO, float(i) / (franjas - 1))
		draw_rect(Rect2(0, i * suelo / franjas, w, suelo / franjas + 1), c)

	# Nubes
	_nube(Vector2(w * 0.20, h * 0.15), h * 0.05)
	_nube(Vector2(w * 0.55, h * 0.10), h * 0.06)
	_nube(Vector2(w * 0.80, h * 0.22), h * 0.045)

	# Pinos a los lados
	for x in [0.04, 0.11, 0.18, 0.82, 0.89, 0.96]:
		_pino(Vector2(w * x, suelo), h * 0.34)

	# Pasto y tierra
	draw_rect(Rect2(0, suelo, w, h * 0.05), PASTO)
	draw_rect(Rect2(0, suelo + h * 0.05, w, h * 0.02), PASTO_OSCURO)
	draw_rect(Rect2(0, suelo + h * 0.07, w, h - suelo - h * 0.07), TIERRA)

func _nube(centro: Vector2, r: float) -> void:
	var blanco := Color(1, 1, 1, 0.95)
	draw_circle(centro, r, blanco)
	draw_circle(centro + Vector2(r * 1.0, r * 0.2), r * 0.8, blanco)
	draw_circle(centro + Vector2(-r * 1.0, r * 0.25), r * 0.7, blanco)
	draw_circle(centro + Vector2(r * 0.2, -r * 0.4), r * 0.7, blanco)

func _pino(base: Vector2, alto: float) -> void:
	var ancho := alto * 0.45
	draw_rect(Rect2(base.x - ancho * 0.07, base.y - alto * 0.15, ancho * 0.14, alto * 0.15), TRONCO)
	for i in 3:
		var y_base := base.y - alto * 0.12 - i * alto * 0.26
		var a := ancho * (1.0 - i * 0.22)
		var puntas := PackedVector2Array([
			Vector2(base.x - a * 0.5, y_base),
			Vector2(base.x + a * 0.5, y_base),
			Vector2(base.x, y_base - alto * 0.38),
		])
		draw_colored_polygon(puntas, PINO if i % 2 == 0 else PINO_OSCURO)
