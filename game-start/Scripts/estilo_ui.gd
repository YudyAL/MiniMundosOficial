extends RefCounted
# Estilo visual compartido de la interfaz (HUD, pausa, resultados y menú).
# Uso: const UI = preload("res://Scripts/estilo_ui.gd")

const DORADO := Color(1.0, 0.86, 0.35)
const CREMA := Color(1.0, 0.96, 0.86)
const MORADO := Color(0.34, 0.2, 0.72)
const MORADO_CLARO := Color(0.5, 0.36, 0.95)
const NOCHE := Color(0.06, 0.03, 0.16, 0.86)
const BORDE := Color(0.64, 0.5, 1.0, 0.9)
const CONTORNO := Color(0.1, 0.02, 0.22, 0.95)


static func caja(fondo: Color, borde: Color, radio: int = 18, grosor: int = 3, margen: float = 16.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(radio)
	s.set_content_margin_all(margen)
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 8
	s.anti_aliasing = true
	return s


static func panel(p: PanelContainer, fondo: Color = NOCHE, borde: Color = BORDE) -> PanelContainer:
	p.add_theme_stylebox_override("panel", caja(fondo, borde, 20, 3, 20.0))
	return p


static func texto(l: Label, tam: int, color: Color = CREMA) -> Label:
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", CONTORNO)
	l.add_theme_constant_override("outline_size", maxi(4, int(tam * 0.22)))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, int(tam * 0.07)))
	return l


static func boton(b: Button, ancho: float = 300.0) -> Button:
	b.custom_minimum_size = Vector2(ancho, 58)
	b.add_theme_font_size_override("font_size", 25)
	b.add_theme_color_override("font_color", CREMA)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", DORADO)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	b.add_theme_color_override("font_outline_color", CONTORNO)
	b.add_theme_constant_override("outline_size", 5)
	b.add_theme_stylebox_override("normal", caja(MORADO, DORADO, 29, 3, 10.0))
	b.add_theme_stylebox_override("hover", caja(MORADO_CLARO, Color(1.0, 0.95, 0.65), 29, 4, 10.0))
	b.add_theme_stylebox_override("pressed", caja(MORADO.darkened(0.3), DORADO, 29, 3, 10.0))
	b.add_theme_stylebox_override("focus", caja(Color(0, 0, 0, 0), Color(1, 1, 1, 0.85), 29, 2, 10.0))
	b.add_theme_stylebox_override("disabled", caja(Color(0.28, 0.25, 0.38), Color(0.5, 0.47, 0.6), 29, 3, 10.0))
	return b


static func barra(p: ProgressBar, relleno: Color, tam: Vector2) -> ProgressBar:
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(1, 1, 1, 0.12)
	fondo.border_color = Color(1, 1, 1, 0.25)
	fondo.set_border_width_all(1)
	fondo.set_corner_radius_all(int(tam.y * 0.5))
	var lleno := StyleBoxFlat.new()
	lleno.bg_color = relleno
	lleno.set_corner_radius_all(int(tam.y * 0.5))
	p.add_theme_stylebox_override("background", fondo)
	p.add_theme_stylebox_override("fill", lleno)
	p.custom_minimum_size = tam
	p.show_percentage = false
	return p


static func color_medalla(nombre: String) -> Color:
	match nombre:
		"Oro":
			return Color(1.0, 0.8, 0.22)
		"Plata":
			return Color(0.82, 0.86, 0.94)
		"Bronce":
			return Color(0.86, 0.52, 0.27)
	return Color(0.4, 0.37, 0.5)


# Medalla dibujada (círculo con estrella y cintas).
class Medalla extends Control:
	var color_base := Color(0.4, 0.37, 0.5)
	var bloqueada := false

	func _init(c: Color = Color(0.4, 0.37, 0.5), b: bool = false) -> void:
		color_base = c
		bloqueada = b
		custom_minimum_size = Vector2(110, 130)

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.6)
		var col := color_base
		if bloqueada:
			col = Color(0.3, 0.28, 0.4)
		var cinta_a := PackedVector2Array([c + Vector2(-34, -78), c + Vector2(-12, -78), c + Vector2(6, -30), c + Vector2(-16, -30)])
		var cinta_b := PackedVector2Array([c + Vector2(12, -78), c + Vector2(34, -78), c + Vector2(16, -30), c + Vector2(-6, -30)])
		draw_colored_polygon(cinta_a, Color(0.45, 0.3, 0.95) if not bloqueada else Color(0.25, 0.23, 0.33))
		draw_colored_polygon(cinta_b, Color(0.95, 0.32, 0.55) if not bloqueada else Color(0.22, 0.2, 0.3))
		draw_circle(c, 44.0, col.darkened(0.4))
		draw_circle(c, 37.0, col)
		draw_circle(c + Vector2(-12, -14), 9.0, Color(1, 1, 1, 0.25))
		draw_colored_polygon(_estrella(c, 22.0, 9.0), col.lightened(0.45) if not bloqueada else col.lightened(0.15))

	func _estrella(c: Vector2, r: float, ri: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI * 0.5 + TAU * i / 10.0
			var rr := r if i % 2 == 0 else ri
			pts.append(c + Vector2(cos(a), sin(a)) * rr)
		return pts
