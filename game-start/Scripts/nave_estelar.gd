extends Node3D
# Nave Estelar: párate junto a ella y pulsa E para subir.
#   WASD           -> volar sobre la isla (según hacia dónde mira la cámara)
#   Clic izq. o F  -> disparar láseres (apuntan solos a la Sombra más cercana)
#   E              -> bajar de la nave
# Mientras Lumi va en la nave, el Rey Sombra le lanza bolas de fuego.

const Formas = preload("res://Scripts/formas.gd")
const Laser = preload("res://Scripts/laser_estelar.gd")
const COLOR := Color(0.4, 1.0, 0.85)

@export var velocidad := 9.0
@export var altura_vuelo := 5.0       # metros sobre la isla mientras vuela
@export var cadencia := 0.35          # segundos entre disparos
@export var alcance := 30.0           # distancia máxima para apuntar a una Sombra

var centro_zona := Vector3.ZERO       # centro de la isla: la nave no sale de este círculo
var radio_zona := 11.0

var jugador: CharacterBody3D
var jugador_cerca := false
var pilotando := false
var cambiando := false                # true mientras sube o baja
var altura_suelo := 0.0
var t_disparo := 0.0
var lado_disparo := 1.0               # alterna el cañón izquierdo y el derecho
var t := 0.0

var modelo: Node3D
var mat_cuerpo: StandardMaterial3D
var propulsores: Array[GPUParticles3D] = []


func _ready() -> void:
	altura_suelo = global_position.y
	_asegurar_accion("interact", KEY_E)
	_asegurar_accion("disparar", KEY_F)
	_construir_modelo()

	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 2.8
	cs.shape = esfera
	cs.position.y = 1.0
	area.add_child(cs)
	add_child(area)
	area.body_entered.connect(_al_entrar)
	area.body_exited.connect(_al_salir)

	Game.jugador_herido.connect(_al_herir_jugador)


func _asegurar_accion(accion: String, tecla: Key) -> void:
	if InputMap.has_action(accion):
		return
	InputMap.add_action(accion)
	var ev := InputEventKey.new()
	ev.physical_keycode = tecla
	InputMap.action_add_event(accion, ev)


# ---------- Modelo ----------

func _construir_modelo() -> void:
	modelo = Node3D.new()
	modelo.position.y = 0.9
	add_child(modelo)

	# Cuerpo (la nariz apunta hacia +Z, igual que los demás personajes)
	mat_cuerpo = Formas.mat(Color(0.85, 0.88, 1.0), 0.0, 0.5, 0.35)
	mat_cuerpo.metallic = 0.6
	mat_cuerpo.emission_enabled = true
	mat_cuerpo.emission = Color(1.0, 0.2, 0.2)
	mat_cuerpo.emission_energy_multiplier = 0.0
	var cuerpo := Formas.esfera(0.7, mat_cuerpo, Vector3.ZERO, 24)
	cuerpo.scale = Vector3(1.0, 0.55, 1.9)
	modelo.add_child(cuerpo)

	# Cabina de vidrio
	var cabina := Formas.esfera(0.42, Formas.mat_transparente(Color(0.4, 0.85, 1.0, 0.55)), Vector3(0, 0.3, 0.25), 18)
	cabina.scale = Vector3(1.0, 0.8, 1.4)
	modelo.add_child(cabina)

	# Alas con puntas brillantes
	var mat_ala := Formas.mat(Color(0.45, 0.3, 0.9), 0.0, 0.4, 0.4)
	var mat_luz := Formas.mat(COLOR, 4.0, 0.0)
	for lado: float in [-1.0, 1.0]:
		var ala := Formas.caja(Vector3(1.6, 0.08, 0.9), mat_ala, Vector3(1.1 * lado, -0.05, -0.2))
		ala.rotation.z = 0.12 * lado
		ala.rotation.y = -0.25 * lado
		modelo.add_child(ala)
		modelo.add_child(Formas.esfera(0.12, mat_luz, Vector3(1.85 * lado, 0.05, -0.45), 10))
		# Cañones
		var canon := Formas.cilindro(0.07, 0.09, 0.8, Formas.mat(Color(0.3, 0.3, 0.4), 0.0, 0.3, 0.4), Vector3(0.9 * lado, -0.15, 0.5), 10)
		canon.rotation.x = PI * 0.5
		modelo.add_child(canon)

	# Aleta de cola
	var aleta := Formas.prisma(Vector3(0.08, 0.6, 0.7), mat_ala, Vector3(0, 0.4, -1.0))
	modelo.add_child(aleta)

	# Propulsores con fuego azul
	var mat_motor := Formas.mat(Color(0.35, 0.35, 0.45), 0.0, 0.3, 0.4)
	for lado: float in [-1.0, 1.0]:
		var motor := Formas.cilindro(0.18, 0.24, 0.6, mat_motor, Vector3(0.45 * lado, -0.05, -1.15), 14)
		motor.rotation.x = PI * 0.5
		modelo.add_child(motor)
		modelo.add_child(Formas.esfera(0.16, Formas.mat(COLOR, 5.0, 0.0), Vector3(0.45 * lado, -0.05, -1.45), 10))
		var fuego := Formas.particulas(COLOR, 30, 0.4, 0.1, 0.07, Vector3(0, 0, -6.0), 1.0, 5.0)
		fuego.position = Vector3(0.45 * lado, -0.05, -1.5)
		fuego.local_coords = false
		fuego.emitting = false
		modelo.add_child(fuego)
		propulsores.append(fuego)

	var luz := OmniLight3D.new()
	luz.light_color = COLOR
	luz.light_energy = 1.0
	luz.omni_range = 4.0
	modelo.add_child(luz)


# ---------- Subir y bajar ----------

func _al_entrar(body: Node3D) -> void:
	if body.is_in_group("player"):
		jugador = body as CharacterBody3D
		jugador_cerca = true
		if not pilotando:
			Game.mostrar_pista("Pulsa E para subir a la Nave Estelar")


func _al_salir(body: Node3D) -> void:
	if body.is_in_group("player"):
		jugador_cerca = false
		if not pilotando:
			Game.mostrar_pista("")


func _process(delta: float) -> void:
	t += delta
	# Flota suavemente
	modelo.position.y = 0.9 + sin(t * 2.0) * (0.15 if pilotando else 0.06)

	if cambiando or Game.finished or jugador == null:
		return
	if Input.is_action_just_pressed("interact"):
		if pilotando:
			_bajar()
		elif jugador_cerca:
			_subir()


func _subir() -> void:
	pilotando = true
	cambiando = true
	jugador.set("controls_locked", true)
	jugador.set("en_nave", true)
	jugador.velocity = Vector3.ZERO
	_mostrar_lumi(false)
	for p in propulsores:
		p.emitting = true
	Formas.estallido(get_parent(), global_position + Vector3(0, 1.0, 0), COLOR, 40)
	Game.mostrar_mensaje("¡A bordo de la Nave Estelar!")
	Game.mostrar_pista("WASD volar  ·  Clic o F disparar  ·  E bajar")

	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + (centro_zona.y + altura_vuelo - global_position.y), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): cambiando = false)


func _bajar() -> void:
	cambiando = true
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + (altura_suelo - global_position.y), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.parallel().tween_property(modelo, "rotation:z", 0.0, 0.4)
	tw.tween_callback(_salir_de_la_nave)


func _salir_de_la_nave() -> void:
	pilotando = false
	cambiando = false
	for p in propulsores:
		p.emitting = false
	# Lumi aparece al lado de la nave, del lado que mira al centro de la isla
	var hacia_centro := centro_zona - global_position
	hacia_centro.y = 0.0
	if hacia_centro.length() < 0.1:
		hacia_centro = Vector3(0, 0, 1)
	jugador.global_position = global_position + hacia_centro.normalized() * 2.2 + Vector3(0, 0.3, 0)
	jugador.velocity = Vector3.ZERO
	jugador.set("knockback", Vector3.ZERO)
	jugador.set("en_nave", false)
	jugador.set("controls_locked", false)
	_mostrar_lumi(true)
	Game.mostrar_pista("Pulsa E para subir a la Nave Estelar" if jugador_cerca else "")


func _mostrar_lumi(visible_: bool) -> void:
	for nombre in ["Model", "Estilo"]:
		var n := jugador.get_node_or_null(nombre) as Node3D
		if n:
			n.visible = visible_


# ---------- Vuelo y disparo ----------

func _physics_process(delta: float) -> void:
	if not pilotando or jugador == null:
		return
	# Lumi va "sentada" en la nave: la cámara (que es hija de Lumi) la sigue
	jugador.global_position = global_position + Vector3(0, 0.3, 0)
	jugador.velocity = Vector3.ZERO
	if cambiando or Game.finished:
		return

	var entrada := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var brazo := jugador.get_node_or_null("SpringArm3D") as Node3D
	var yaw := brazo.rotation.y if brazo else 0.0
	var dir := Basis(Vector3.UP, yaw) * Vector3(entrada.x, 0.0, entrada.y)

	var pos := global_position + dir * velocidad * delta
	var plano := Vector2(pos.x - centro_zona.x, pos.z - centro_zona.z)
	if plano.length() > radio_zona:          # no dejar que se salga de la isla
		plano = plano.normalized() * radio_zona
		pos.x = centro_zona.x + plano.x
		pos.z = centro_zona.z + plano.y
	pos.y = centro_zona.y + altura_vuelo
	global_position = pos

	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(8.0 * delta, 1.0))
	modelo.rotation.z = lerpf(modelo.rotation.z, -entrada.x * 0.35, minf(6.0 * delta, 1.0))   # se inclina al girar
	jugador.global_position = global_position + Vector3(0, 0.3, 0)

	t_disparo -= delta
	var quiere_disparar := Input.is_action_pressed("disparar") \
			or (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if quiere_disparar and t_disparo <= 0.0:
		_disparar()


func _disparar() -> void:
	t_disparo = cadencia
	lado_disparo = -lado_disparo
	var objetivo := _buscar_objetivo()
	var l := Laser.new()
	l.objetivo = objetivo
	l.direccion = global_transform.basis.z.normalized()
	if objetivo:
		l.direccion = (objetivo.global_position + Vector3(0, 1.0, 0) - global_position).normalized()
	get_parent().add_child(l)
	l.global_position = modelo.global_transform * Vector3(0.9 * lado_disparo, -0.15, 0.9)


# Busca la Sombra viva más cercana (el Rey Sombra tiene prioridad).
func _buscar_objetivo() -> Node3D:
	var mejor: Node3D = null
	var mejor_d := INF
	for e in get_tree().get_nodes_in_group("enemy"):
		var sombra := e as Node3D
		if sombra == null or int(sombra.get("health")) <= 0:
			continue
		var d := sombra.global_position.distance_to(global_position)
		if d > alcance:
			continue
		if sombra.is_in_group("jefe"):
			d *= 0.5
		if d < mejor_d:
			mejor_d = d
			mejor = sombra
	return mejor


func _al_herir_jugador() -> void:
	if not pilotando:
		return
	# La nave brilla en rojo y se sacude
	mat_cuerpo.emission_energy_multiplier = 3.0
	var tw := create_tween()
	tw.tween_property(mat_cuerpo, "emission_energy_multiplier", 0.0, 0.5)
	var sacudida := create_tween()
	for i in 4:
		sacudida.tween_property(modelo, "position:x", 0.15 if i % 2 == 0 else -0.15, 0.04)
	sacudida.tween_property(modelo, "position:x", 0.0, 0.04)
