extends CanvasLayer
# HUD del Bosque Estelar: puntos, destellos, racha, vidas, tiempo,
# objetivo, avisos, pista de acción, barra del jefe y viñeta de daño.

const UI = preload("res://Scripts/estilo_ui.gd")

const SHADER_VINETA := """
shader_type canvas_item;
uniform float fuerza = 0.0;
void fragment() {
	vec2 c = UV - vec2(0.5);
	float d = length(c) * 1.5;
	COLOR = vec4(0.9, 0.05, 0.18, smoothstep(0.35, 1.05, d) * fuerza);
}
"""

var panel_info := PanelContainer.new()
var label_puntos := Label.new()
var label_destellos := Label.new()
var barra_destellos := ProgressBar.new()
var label_sombras := Label.new()
var label_racha := Label.new()
var barra_racha := ProgressBar.new()

var panel_vida := PanelContainer.new()
var corazones := Corazones.new()
var label_tiempo := Label.new()

var panel_objetivo := PanelContainer.new()
var label_objetivo := Label.new()

var panel_pista := PanelContainer.new()
var label_pista := Label.new()

var avisos := VBoxContainer.new()

var panel_jefe := PanelContainer.new()
var barra_jefe := ProgressBar.new()

var vineta := ColorRect.new()
var mat_vineta := ShaderMaterial.new()
var fuerza_vineta := 0.0


# Fila de corazones dibujados a mano.
class Corazones extends Control:
	var vidas := 5
	var max_vidas := 5
	var latido := 0.0

	func _draw() -> void:
		for i in max_vidas:
			var c := Vector2(24 + i * 44, 24)
			var lleno := i < vidas
			var s := 1.0
			if lleno and i == vidas - 1:
				s = 1.0 + sin(latido * 6.0) * 0.07
			_corazon(c + Vector2(2, 3), 17.0 * s, Color(0, 0, 0, 0.4))
			_corazon(c, 17.0 * s, Color(1.0, 0.3, 0.45) if lleno else Color(0.32, 0.28, 0.48, 0.85))
			if lleno:
				draw_circle(c + Vector2(-7, -6) * s, 3.6 * s, Color(1, 1, 1, 0.75))

	func _corazon(c: Vector2, r: float, col: Color) -> void:
		var rr := r * 0.55
		draw_circle(c + Vector2(-rr * 0.9, -rr * 0.35), rr, col)
		draw_circle(c + Vector2(rr * 0.9, -rr * 0.35), rr, col)
		draw_colored_polygon(PackedVector2Array([
			c + Vector2(-r * 0.98, -r * 0.1),
			c + Vector2(r * 0.98, -r * 0.1),
			c + Vector2(0, r * 0.98),
		]), col)


func _ready() -> void:
	layer = 1

	# Viñeta roja al recibir daño
	var sh := Shader.new()
	sh.code = SHADER_VINETA
	mat_vineta.shader = sh
	vineta.material = mat_vineta
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vineta)
	vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Panel de información (arriba a la izquierda)
	UI.panel(panel_info)
	panel_info.position = Vector2(20, 16)
	panel_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_info)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 6)
	panel_info.add_child(caja)
	caja.add_child(UI.texto(label_puntos, 40, UI.DORADO))
	caja.add_child(UI.texto(label_destellos, 21))
	caja.add_child(UI.barra(barra_destellos, Color(0.55, 0.85, 1.0), Vector2(250, 12)))
	caja.add_child(UI.texto(label_sombras, 19, Color(0.85, 0.75, 1.0)))
	caja.add_child(UI.texto(label_racha, 22, Color(1.0, 0.7, 0.3)))
	UI.barra(barra_racha, Color(1.0, 0.75, 0.2), Vector2(250, 10))
	barra_racha.max_value = Game.STREAK_WINDOW
	caja.add_child(barra_racha)

	# Vidas y tiempo (arriba a la derecha)
	UI.panel(panel_vida)
	add_child(panel_vida)
	var caja_vida := VBoxContainer.new()
	caja_vida.add_theme_constant_override("separation", 4)
	panel_vida.add_child(caja_vida)
	corazones.custom_minimum_size = Vector2(5 * 44 + 4, 48)
	caja_vida.add_child(corazones)
	label_tiempo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	caja_vida.add_child(UI.texto(label_tiempo, 20))

	# Objetivo (arriba al centro)
	UI.panel(panel_objetivo, Color(0.1, 0.05, 0.25, 0.75), Color(1.0, 0.86, 0.35, 0.8))
	add_child(panel_objetivo)
	panel_objetivo.add_child(UI.texto(label_objetivo, 20))

	# Avisos centrales
	avisos.custom_minimum_size = Vector2(1000, 0)
	avisos.add_theme_constant_override("separation", 4)
	avisos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(avisos)

	# Pista de acción (abajo)
	UI.panel(panel_pista, Color(0.12, 0.06, 0.3, 0.85), UI.DORADO)
	panel_pista.visible = false
	add_child(panel_pista)
	panel_pista.add_child(UI.texto(label_pista, 24, UI.DORADO))

	# Barra del jefe
	UI.panel(panel_jefe, Color(0.15, 0.02, 0.08, 0.85), Color(1.0, 0.35, 0.3, 0.9))
	panel_jefe.visible = false
	add_child(panel_jefe)
	var caja_jefe := VBoxContainer.new()
	panel_jefe.add_child(caja_jefe)
	var nombre_jefe := UI.texto(Label.new(), 22, Color(1.0, 0.75, 0.7))
	nombre_jefe.text = "REY SOMBRA"
	nombre_jefe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja_jefe.add_child(nombre_jefe)
	caja_jefe.add_child(UI.barra(barra_jefe, Color(0.95, 0.2, 0.35), Vector2(520, 18)))

	Game.destello_calmado.connect(_on_destello)
	Game.enemigo_derrotado.connect(_on_enemigo)
	Game.objetivo_cumplido.connect(_on_objetivo)
	Game.jugador_herido.connect(_on_herido)
	Game.pista_cambiada.connect(_on_pista)
	Game.mensaje.connect(_on_mensaje)


func _process(delta: float) -> void:
	var vp := get_viewport().get_visible_rect().size

	label_puntos.text = "★ %d" % Game.score
	label_destellos.text = "Destellos  %d / %d" % [Game.calmed, Game.total_destellos]
	barra_destellos.max_value = maxi(Game.total_destellos, 1)
	barra_destellos.value = Game.calmed
	label_sombras.text = "Sombras derrotadas  %d" % Game.enemigos_derrotados
	label_racha.text = "¡Racha x%d!" % Game.streak
	label_racha.visible = Game.streak > 0
	barra_racha.visible = Game.streak_left > 0.0
	barra_racha.value = Game.streak_left

	var p := get_tree().get_first_node_in_group("player")
	if p:
		corazones.vidas = int(p.get("health"))
		corazones.max_vidas = int(p.get("max_health"))
		corazones.custom_minimum_size = Vector2(corazones.max_vidas * 44 + 4, 48)
	corazones.latido += delta
	corazones.queue_redraw()
	label_tiempo.text = "Tiempo  " + Game.tiempo_texto(Game.tiempo)

	if Game.estrella_lista:
		label_objetivo.text = "★  ¡Toca la Gran Estrella en la Cima Estelar!  ★"
	else:
		var t := "Calma los destellos  %d / %d" % [Game.calmed, Game.total_destellos]
		if Game.hay_jefe and not Game.jefe_derrotado:
			t += "     ·     Derrota al Rey Sombra"
		label_objetivo.text = t

	# Posiciones que dependen del tamaño de la ventana
	panel_vida.position = Vector2(vp.x - panel_vida.size.x - 20, 16)
	panel_objetivo.position = Vector2((vp.x - panel_objetivo.size.x) * 0.5, 16)
	avisos.position = Vector2((vp.x - avisos.size.x) * 0.5, vp.y * 0.2)
	panel_pista.position = Vector2((vp.x - panel_pista.size.x) * 0.5, vp.y - panel_pista.size.y - 110)
	panel_jefe.position = Vector2((vp.x - panel_jefe.size.x) * 0.5, vp.y - panel_jefe.size.y - 24)

	# Barra del jefe cuando estás cerca
	var jefe := get_tree().get_first_node_in_group("jefe") as Node3D
	var ver_jefe := false
	if jefe and p is Node3D:
		var vida_jefe := int(jefe.get("health"))
		if vida_jefe > 0 and jefe.global_position.distance_to((p as Node3D).global_position) < 26.0:
			ver_jefe = true
			barra_jefe.max_value = int(jefe.get("max_health"))
			barra_jefe.value = lerpf(barra_jefe.value, vida_jefe, minf(delta * 8.0, 1.0))
	panel_jefe.visible = ver_jefe

	# Viñeta de daño que se desvanece
	fuerza_vineta = move_toward(fuerza_vineta, 0.0, delta * 1.6)
	mat_vineta.set_shader_parameter("fuerza", fuerza_vineta)


func _aviso(texto: String, color: Color = UI.DORADO, tam: int = 30) -> void:
	var l := UI.texto(Label.new(), tam, color)
	l.text = texto
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate.a = 0.0
	avisos.add_child(l)
	while avisos.get_child_count() > 4:
		var viejo := avisos.get_child(0)
		avisos.remove_child(viejo)
		viejo.queue_free()
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _on_destello(racha: int, puntos: int) -> void:
	if racha > 1:
		_aviso("¡Destello calmado!  +%d   Racha x%d" % [puntos, racha], Color(1.0, 0.8, 0.35), 30)
	else:
		_aviso("¡Destello calmado!  +%d" % puntos, Color(0.7, 0.95, 1.0), 28)


func _on_enemigo(puntos: int, es_jefe: bool) -> void:
	if es_jefe:
		_aviso("¡Derrotaste al Rey Sombra!  +%d" % puntos, Color(1.0, 0.55, 0.5), 40)
	else:
		_aviso("¡Sombra derrotada!  +%d" % puntos, Color(0.85, 0.7, 1.0), 30)


func _on_objetivo() -> void:
	_aviso("★ ¡La Gran Estrella apareció en la Cima Estelar! ★", UI.DORADO, 38)


func _on_herido() -> void:
	fuerza_vineta = 1.0


func _on_pista(texto: String) -> void:
	label_pista.text = texto
	panel_pista.visible = texto != ""


func _on_mensaje(texto: String) -> void:
	_aviso(texto, UI.CREMA, 32)
