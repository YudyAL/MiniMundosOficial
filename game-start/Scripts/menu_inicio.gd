extends Control
# Menú de inicio con fondo galáctico animado, puntuaciones y medallas.

const ESCENA_JUEGO := "res://Escenas/isla.tscn"
const UI = preload("res://Scripts/estilo_ui.gd")

const FONDO_ARRIBA := Color(0.03, 0.01, 0.1)
const FONDO_ABAJO := Color(0.24, 0.09, 0.4)
const PASTO := Color(0.42, 0.82, 0.35)
const PASTO_OSCURO := Color(0.28, 0.62, 0.3)
const TIERRA := Color(0.5, 0.33, 0.22)
const TRONCO := Color(0.42, 0.26, 0.15)

@onready var titulo: Label = $VBox/Titulo
@onready var btn_jugar: Button = $VBox/Jugar
@onready var btn_puntuaciones: Button = $VBox/Puntuaciones
@onready var btn_medallas: Button = $VBox/Medallas
@onready var btn_salir: Button = $VBox/Salir

var estrellas: Array = []      # [posición 0..1, tamaño, fase]
var t := 0.0
var ventana: Control


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resized.connect(queue_redraw)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 240:
		estrellas.append([Vector2(rng.randf(), rng.randf()), rng.randf_range(0.6, 2.4), rng.randf() * TAU])

	UI.texto(titulo, 86, UI.DORADO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_constant_override("outline_size", 20)

	var subtitulo := UI.texto(Label.new(), 26, Color(0.8, 0.85, 1.0))
	subtitulo.text = "~  Galaxia del Bosque Estelar  ~"
	subtitulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$VBox.add_child(subtitulo)
	$VBox.move_child(subtitulo, 1)
	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 18)
	$VBox.add_child(espacio)
	$VBox.move_child(espacio, 2)

	for b: Button in [btn_jugar, btn_puntuaciones, btn_medallas, btn_salir]:
		UI.boton(b, 300.0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_jugar.add_theme_font_size_override("font_size", 30)

	btn_jugar.pressed.connect(_on_jugar)
	btn_puntuaciones.pressed.connect(_mostrar_puntuaciones)
	btn_medallas.pressed.connect(_mostrar_medallas)
	btn_salir.pressed.connect(func(): get_tree().quit())
	btn_jugar.grab_focus()


func _process(delta: float) -> void:
	t += delta
	titulo.pivot_offset = titulo.size * 0.5
	titulo.scale = Vector2.ONE * (1.0 + sin(t * 2.0) * 0.025)
	queue_redraw()


func _on_jugar() -> void:
	Game.reset()
	get_tree().change_scene_to_file(ESCENA_JUEGO)


# ---------- Ventanas de puntuaciones y medallas ----------

func _mostrar_puntuaciones() -> void:
	var contenido := VBoxContainer.new()
	contenido.add_theme_constant_override("separation", 8)
	if Game.records.is_empty():
		var vacio := UI.texto(Label.new(), 22)
		vacio.text = "Aún no hay partidas.\n¡Juega para marcar tu primer récord!"
		vacio.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		contenido.add_child(vacio)
	else:
		var tabla := GridContainer.new()
		tabla.columns = 4
		tabla.add_theme_constant_override("h_separation", 40)
		tabla.add_theme_constant_override("v_separation", 8)
		for encabezado in ["#", "PUNTOS", "MEDALLA", "TIEMPO"]:
			var l := UI.texto(Label.new(), 20, Color(0.8, 0.75, 1.0))
			l.text = encabezado
			tabla.add_child(l)
		for i in Game.records.size():
			var r: Dictionary = Game.records[i]
			var medalla := str(r.get("medalla", "Sin medalla"))
			var color_fila := UI.DORADO if i == 0 else UI.CREMA
			var celdas := [
				"%d." % (i + 1),
				str(r.get("puntos", 0)),
				medalla if bool(r.get("victoria", false)) else "Derrota",
				Game.tiempo_texto(float(r.get("tiempo", 0))),
			]
			for j in celdas.size():
				var l := UI.texto(Label.new(), 24, color_fila)
				l.text = celdas[j]
				if j == 2 and bool(r.get("victoria", false)):
					l.add_theme_color_override("font_color", UI.color_medalla(medalla).lightened(0.2))
				tabla.add_child(l)
		contenido.add_child(tabla)
	_abrir_ventana("PUNTUACIONES", contenido)


func _mostrar_medallas() -> void:
	var contenido := HBoxContainer.new()
	contenido.add_theme_constant_override("separation", 36)
	var mejor: int = Game.MEDALLAS.find(Game.mejor_medalla)
	var datos := [
		["Bronce", "Completa el nivel"],
		["Plata", "%d puntos o más" % Game.PUNTOS_PLATA],
		["Oro", "%d puntos o más" % Game.PUNTOS_ORO],
	]
	for i in datos.size():
		var nombre: String = datos[i][0]
		var conseguida: bool = mejor >= i + 1
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		var centro := CenterContainer.new()
		centro.add_child(UI.Medalla.new(UI.color_medalla(nombre), not conseguida))
		col.add_child(centro)
		var l_nombre := UI.texto(Label.new(), 26, UI.color_medalla(nombre).lightened(0.2) if conseguida else Color(0.6, 0.58, 0.7))
		l_nombre.text = nombre.to_upper()
		l_nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l_nombre)
		var l_req := UI.texto(Label.new(), 16, Color(0.85, 0.82, 0.95))
		l_req.text = ("¡Conseguida!" if conseguida else "Bloqueada") + "\n" + str(datos[i][1])
		l_req.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l_req)
		contenido.add_child(col)
	_abrir_ventana("MEDALLAS", contenido)


func _abrir_ventana(nombre: String, contenido: Control) -> void:
	_cerrar_ventana()
	var fondo := ColorRect.new()
	fondo.color = Color(0.02, 0.0, 0.08, 0.7)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ventana = fondo

	var centro := CenterContainer.new()
	fondo.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := UI.panel(PanelContainer.new())
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 18)
	panel.add_child(caja)

	var l := UI.texto(Label.new(), 44, UI.DORADO)
	l.text = nombre
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(l)
	caja.add_child(contenido)
	var cerrar := UI.boton(Button.new(), 220.0)
	cerrar.text = "CERRAR"
	cerrar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cerrar.pressed.connect(_cerrar_ventana)
	caja.add_child(cerrar)
	cerrar.grab_focus()


func _cerrar_ventana() -> void:
	if ventana and is_instance_valid(ventana):
		ventana.queue_free()
	ventana = null
	if is_inside_tree() and btn_jugar:
		btn_jugar.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if ventana and event.is_action_pressed("ui_cancel"):
		_cerrar_ventana()


# ---------- Fondo dibujado ----------

func _draw() -> void:
	var w := size.x
	var h := size.y

	# Cielo espacial en franjas
	var franjas := 48
	for i in franjas:
		var k := float(i) / (franjas - 1)
		draw_rect(Rect2(0, i * h / franjas, w, h / franjas + 1), FONDO_ARRIBA.lerp(FONDO_ABAJO, pow(k, 1.3)))

	# Nebulosas
	_nebulosa(Vector2(w * 0.22, h * 0.32), h * 0.38, Color(0.8, 0.22, 0.72, 0.045))
	_nebulosa(Vector2(w * 0.8, h * 0.2), h * 0.32, Color(0.2, 0.45, 1.0, 0.05))
	_nebulosa(Vector2(w * 0.55, h * 0.55), h * 0.25, Color(0.5, 0.3, 1.0, 0.035))

	# Estrellas titilando
	for e in estrellas:
		var p: Vector2 = e[0]
		var tam: float = e[1]
		var fase: float = e[2]
		var brillo := 0.5 + 0.5 * sin(t * 2.0 + fase)
		var pos := Vector2(p.x * w, p.y * h * 0.9)
		draw_circle(pos, tam * (0.7 + 0.3 * brillo), Color(1.0, 0.95, 0.85, 0.35 + 0.65 * brillo))
		if tam > 2.0:
			var largo := tam * 3.5 * brillo
			draw_line(pos - Vector2(largo, 0), pos + Vector2(largo, 0), Color(1, 1, 1, 0.5 * brillo), 1.0)
			draw_line(pos - Vector2(0, largo), pos + Vector2(0, largo), Color(1, 1, 1, 0.5 * brillo), 1.0)

	# Estrella fugaz cada pocos segundos
	var ciclo := fmod(t, 5.0)
	if ciclo < 0.8:
		var k := ciclo / 0.8
		var inicio := Vector2(w * 0.15, h * 0.08)
		var cabeza := inicio + Vector2(w * 0.45, h * 0.22) * k
		draw_line(cabeza - Vector2(w * 0.09, h * 0.044), cabeza, Color(1, 0.95, 0.8, 0.8 * (1.0 - k)), 3.0)
		draw_circle(cabeza, 3.0, Color(1, 1, 1, 1.0 - k))

	# Planeta anillado
	var pa := Vector2(w * 0.86, h * 0.17)
	var ra := h * 0.07
	draw_circle(pa, ra * 1.25, Color(1.0, 0.6, 0.35, 0.08))
	draw_circle(pa, ra, Color(0.98, 0.62, 0.36))
	draw_circle(pa + Vector2(-ra * 0.3, -ra * 0.3), ra * 0.35, Color(1, 1, 1, 0.12))
	draw_set_transform(pa, -0.35, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, ra * 1.7, 0.0, TAU, 64, Color(1.0, 0.85, 0.6, 0.85), ra * 0.18)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Luna pequeña
	draw_circle(Vector2(w * 0.1, h * 0.14), h * 0.03, Color(0.78, 0.74, 0.92))
	draw_circle(Vector2(w * 0.105, h * 0.135), h * 0.008, Color(0.6, 0.56, 0.78))

	# Mini planeta con bosque (abajo)
	var centro := Vector2(w * 0.5, h * 1.42)
	var radio := h * 0.78
	for i in 6:
		draw_circle(centro, radio + h * 0.02 * (6 - i), Color(0.5, 0.75, 1.0, 0.035))
	draw_circle(centro, radio, TIERRA)
	draw_circle(centro, radio - h * 0.012, PASTO_OSCURO)
	draw_circle(centro, radio - h * 0.03, PASTO)
	# Árboles en la curva del planeta (dejando libre el centro)
	for i in 22:
		var a := lerpf(-1.05, 1.05, float(i) / 21.0)
		if absf(a) < 0.24:
			continue
		var escala := 0.8 + 0.4 * absf(sin(i * 3.7))
		var base := centro + Vector2(sin(a), -cos(a)) * (radio - h * 0.01)
		draw_set_transform(base, a, Vector2.ONE * escala)
		_arbolito(h, i)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _nebulosa(c: Vector2, r: float, col: Color) -> void:
	for i in 8:
		draw_circle(c, r * (1.0 - i * 0.11), col)


func _arbolito(h: float, i: int) -> void:
	var alto := h * 0.1
	draw_rect(Rect2(-alto * 0.06, -alto * 0.45, alto * 0.12, alto * 0.45), TRONCO)
	if i % 3 == 0:
		# Pino
		for k in 3:
			var y := -alto * (0.35 + k * 0.22)
			var a := alto * (0.38 - k * 0.08)
			draw_colored_polygon(PackedVector2Array([Vector2(-a, y), Vector2(a, y), Vector2(0, y - alto * 0.4)]),
					Color(0.2, 0.5, 0.3) if k % 2 == 0 else Color(0.26, 0.6, 0.34))
	else:
		# Árbol redondo con copa de colores
		var copa := Color(0.3, 0.72, 0.35) if i % 2 == 0 else Color(0.95, 0.55, 0.75)
		draw_circle(Vector2(0, -alto * 0.7), alto * 0.32, copa.darkened(0.15))
		draw_circle(Vector2(-alto * 0.18, -alto * 0.58), alto * 0.22, copa)
		draw_circle(Vector2(alto * 0.18, -alto * 0.62), alto * 0.22, copa)
		draw_circle(Vector2(0, -alto * 0.85), alto * 0.2, copa.lightened(0.15))
		draw_circle(Vector2(alto * 0.12, -alto * 0.75), alto * 0.05, Color(1.0, 0.9, 0.4))
