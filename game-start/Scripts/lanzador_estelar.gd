extends Area3D
# Lanzador estelar: párate encima y gira (ESPACIO) para salir disparado
# en arco hasta otra isla. Muestra la trayectoria con puntitos brillantes.

const Formas = preload("res://Scripts/formas.gd")

var destino := Vector3.ZERO          # punto de aterrizaje (posición global de los pies)
var altura_arco := 14.0
var color := Color(1.0, 0.85, 0.25)

var duracion := 1.8
var lanzando := false
var estrella: MeshInstance3D
var anillo: MeshInstance3D
var t := 0.0


func _ready() -> void:
	monitoring = true
	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 1.8
	cs.shape = esfera
	cs.position.y = 1.0
	add_child(cs)
	duracion = clampf(global_position.distance_to(destino) / 24.0, 1.4, 3.2)
	_construir()
	_crear_trayectoria()
	body_entered.connect(_al_entrar)
	body_exited.connect(_al_salir)


func _construir() -> void:
	add_child(Formas.cilindro(1.25, 1.5, 0.28, Formas.mat(Color(0.26, 0.2, 0.48), 0.0, 0.6, 0.35), Vector3(0, 0.14, 0), 32))
	anillo = Formas.toroide(1.12, 1.36, Formas.mat(color, 3.0, 0.0), Vector3(0, 0.3, 0), 48)
	add_child(anillo)
	var mat_estrella := Formas.mat(color, 2.2, 0.5, 0.3)
	mat_estrella.cull_mode = BaseMaterial3D.CULL_DISABLED
	estrella = Formas.malla(Formas.estrella_mesh(5, 0.95, 0.42, 0.28), mat_estrella, Vector3(0, 1.6, 0))
	add_child(estrella)
	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 1.6
	luz.omni_range = 6.0
	luz.position.y = 1.5
	add_child(luz)
	var chispas := Formas.particulas(color, 24, 1.6, 1.2, 0.05, Vector3(0, 1.2, 0), 0.6, 4.0)
	chispas.position.y = 1.0
	add_child(chispas)


func _crear_trayectoria() -> void:
	var p0 := global_position + Vector3(0, 1.2, 0)
	var p2 := destino + Vector3(0, 1.0, 0)
	var p1 := (p0 + p2) * 0.5 + Vector3(0, altura_arco, 0)
	var largo := p0.distance_to(p2) + altura_arco
	var n := maxi(int(largo / 2.2), 4)
	var m := Formas.mat(color, 3.0, 0.0)
	for i in range(1, n):
		var k := float(i) / n
		var punto := Formas.esfera(0.2 if i % 3 == 0 else 0.11, m, _bezier(p0, p1, p2, k) - global_position, 8)
		punto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(punto)


func _process(delta: float) -> void:
	t += delta
	estrella.rotate_y(delta * (10.0 if lanzando else 1.6))
	estrella.position.y = 1.6 + sin(t * 2.5) * 0.12
	var pulso := 1.0 + sin(t * 4.0) * 0.05
	anillo.scale = Vector3(pulso, 1.0, pulso)


func _al_entrar(body: Node3D) -> void:
	if body.is_in_group("player") and not lanzando:
		Game.mostrar_pista("Gira con ESPACIO para lanzarte")


func _al_salir(body: Node3D) -> void:
	if body.is_in_group("player"):
		Game.mostrar_pista("")


func on_spin(_from_pos: Vector3, _push: float) -> void:
	if lanzando:
		return
	var jugador := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if jugador == null or not overlaps_body(jugador):
		return
	_lanzar(jugador)


func _lanzar(jugador: CharacterBody3D) -> void:
	lanzando = true
	Game.mostrar_pista("")
	jugador.set("controls_locked", true)
	jugador.velocity = Vector3.ZERO

	var inicio := jugador.global_position
	var arriba := inicio + Vector3(0, 1.2, 0)
	var p1 := (arriba + destino) * 0.5 + Vector3(0, altura_arco, 0)

	# Pequeña carga hacia arriba y luego el vuelo en arco
	var tw := create_tween()
	tw.tween_property(jugador, "global_position", arriba, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_mover_jugador.bind(jugador, arriba, p1, destino), 0.0, 1.0, duracion).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_aterrizar.bind(jugador))

	# Lumi gira como estrella durante el vuelo
	var modelo := jugador.get_node_or_null("Model") as Node3D
	if modelo:
		var giro := create_tween()
		giro.tween_property(modelo, "rotation:y", modelo.rotation.y + TAU * 4.0, duracion + 0.25)

	# Estela de chispas
	var estela := Formas.particulas(color, 70, 0.8, 0.35, 0.07, Vector3.ZERO, 0.3, 5.0)
	estela.local_coords = false
	estela.position.y = 0.9
	jugador.add_child(estela)
	get_tree().create_timer(duracion + 1.2).timeout.connect(estela.queue_free)
	Formas.estallido(get_parent(), global_position + Vector3(0, 1.0, 0), color, 40)


func _mover_jugador(k: float, jugador: CharacterBody3D, a: Vector3, b: Vector3, c: Vector3) -> void:
	if is_instance_valid(jugador):
		jugador.global_position = _bezier(a, b, c, k)


func _aterrizar(jugador: CharacterBody3D) -> void:
	lanzando = false
	if not is_instance_valid(jugador):
		return
	jugador.velocity = Vector3.ZERO
	jugador.set("controls_locked", false)
	Formas.estallido(get_parent(), jugador.global_position + Vector3(0, 0.3, 0), color, 30)


func _bezier(a: Vector3, b: Vector3, c: Vector3, k: float) -> Vector3:
	return a.lerp(b, k).lerp(b.lerp(c, k), k)
