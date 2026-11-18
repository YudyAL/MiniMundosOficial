extends CanvasLayer
# Menú de pausa (ESC): continuar, reiniciar o volver al menú.

const UI = preload("res://Scripts/estilo_ui.gd")
const MENU := "res://Escenas/MenuInicio.tscn"

var fondo := ColorRect.new()


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	fondo.color = Color(0.03, 0.01, 0.1, 0.72)
	add_child(fondo)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var centro := CenterContainer.new()
	add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := UI.panel(PanelContainer.new())
	centro.add_child(panel)
	var caja := VBoxContainer.new()
	caja.add_theme_constant_override("separation", 14)
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(caja)

	var titulo := UI.texto(Label.new(), 54, UI.DORADO)
	titulo.text = "PAUSA"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(titulo)

	var controles := UI.texto(Label.new(), 18, Color(0.85, 0.8, 1.0))
	controles.text = "WASD  mover     ·     SHIFT  correr\nESPACIO  girar (calma destellos, golpea sombras y activa lanzadores)\nRATÓN  mover la cámara     ·     ESC  pausa"
	controles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caja.add_child(controles)

	var espacio := Control.new()
	espacio.custom_minimum_size = Vector2(0, 8)
	caja.add_child(espacio)

	var b_continuar := UI.boton(Button.new())
	b_continuar.text = "CONTINUAR"
	b_continuar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_continuar.pressed.connect(_continuar)
	caja.add_child(b_continuar)

	var b_reiniciar := UI.boton(Button.new())
	b_reiniciar.text = "REINICIAR NIVEL"
	b_reiniciar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_reiniciar.pressed.connect(_reiniciar)
	caja.add_child(b_reiniciar)

	var b_menu := UI.boton(Button.new())
	b_menu.text = "MENÚ DE INICIO"
	b_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b_menu.pressed.connect(_menu)
	caja.add_child(b_menu)


func _input(event: InputEvent) -> void:
	if Game.finished:
		return
	if event.is_action_pressed("ui_cancel"):
		if visible:
			_continuar()
		else:
			_pausar()
		get_viewport().set_input_as_handled()
	elif not visible and event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Clic en la ventana: vuelve a capturar el ratón
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _pausar() -> void:
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _continuar() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _reiniciar() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().reload_current_scene()


func _menu() -> void:
	get_tree().paused = false
	Game.reset()
	get_tree().change_scene_to_file(MENU)
