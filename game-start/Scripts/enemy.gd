extends CharacterBody3D
# Sombra: criatura de oscuridad del Bosque Estelar.
# Patrulla, te descubre (¡!), te persigue, se carga y embiste.
# Gira cerca de ella (ESPACIO) para golpearla. Con es_jefe = true es el Rey Sombra.
# Escena: CharacterBody3D (este script) + CollisionShape3D. El modelo se arma por código.

const Formas = preload("res://Scripts/formas.gd")

enum Estado { PATRULLA, ALERTA, PERSIGUE, CARGA, EMBESTIDA, ATURDIDO, MUERTO }

@export var speed := 3.5
@export var detect_range := 10.0
@export var attack_range := 1.6
@export var damage := 1
@export var attack_cooldown := 1.0
@export var max_health := 3
@export var es_jefe := false
@export var radio_patrulla := 4.0
@export var correa := 15.0          # si Lumi se aleja tanto de su hogar, deja de perseguir

var health := 3
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var estado: Estado = Estado.PATRULLA
var t_estado := 0.0
var enfriamiento := 0.0
var hogar := Vector3.ZERO
var punto_patrulla := Vector3.ZERO
var empuje := Vector3.ZERO
var dir_embestida := Vector3.ZERO
var t_anim := 0.0
var escala := 1.0

var modelo: Node3D
var pivote: Node3D
var pies: Array[Node3D] = []
var mat_cuerpo: StandardMaterial3D
var mat_ojos: StandardMaterial3D
var puntos_vida: Node3D
var alerta: Label3D


func _ready() -> void:
	add_to_group("enemy")
	if es_jefe:
		add_to_group("jefe")
		escala = 1.9
	collision_mask |= 2   # choca con los bordes invisibles de las islas
	health = max_health
	hogar = global_position
	punto_patrulla = hogar
	player = get_tree().get_first_node_in_group("player")
	t_anim = randf() * 10.0
	_ajustar_colision()
	_construir_modelo()
	_construir_vida()


func _ajustar_colision() -> void:
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs == null or is_equal_approx(escala, 1.0):
		return
	var cap := cs.shape.duplicate() as CapsuleShape3D
	if cap == null:
		return
	cap.radius *= escala
	cap.height *= escala
	cs.shape = cap
	cs.position.y *= escala


# ---------- Modelo ----------

func _construir_modelo() -> void:
	modelo = Node3D.new()
	modelo.scale = Vector3.ONE * escala
	add_child(modelo)
	pivote = Node3D.new()
	modelo.add_child(pivote)

	var c_cuerpo := Color(0.13, 0.04, 0.2) if not es_jefe else Color(0.2, 0.02, 0.06)
	var c_puas := Color(0.6, 0.12, 0.85) if not es_jefe else Color(1.0, 0.22, 0.15)
	var c_ojos := Color(1.0, 0.3, 0.05) if not es_jefe else Color(1.0, 0.85, 0.15)
	var centro := Vector3(0, 0.75, 0)

	# Cuerpo: bola oscura con brillo de borde
	mat_cuerpo = Formas.mat(c_cuerpo, 0.0, 0.9, 0.35)
	mat_cuerpo.rim_tint = 0.0
	mat_cuerpo.metallic = 0.25
	mat_cuerpo.emission_enabled = true
	mat_cuerpo.emission = Color(1, 1, 1)
	mat_cuerpo.emission_energy_multiplier = 0.0
	pivote.add_child(Formas.esfera(0.62, mat_cuerpo, centro, 28))

	# Púas brillantes en el lomo (tres filas)
	var mat_puas := Formas.mat(c_puas, 1.6, 0.3, 0.4)
	for fila: float in [-0.32, 0.0, 0.32]:
		var cantidad := 5 if is_zero_approx(fila) else 4
		var alto := 0.55 if is_zero_approx(fila) else 0.4
		for i in cantidad:
			var th := lerpf(-0.2, 2.1, float(i) / float(cantidad - 1))
			var dir := Vector3(fila, cos(th), -sin(th)).normalized()
			var pua := Formas.cono(0.11, alto, mat_puas)
			Formas.orientar(pua, dir)
			pua.position = centro + dir * (0.6 + alto * 0.35)
			pivote.add_child(pua)

	# Cuernos
	var mat_cuerno := Formas.mat(Color(0.93, 0.87, 0.75), 0.0, 0.4, 0.5)
	for lado: float in [-1.0, 1.0]:
		var dir := Vector3(0.6 * lado, 0.75, 0.3).normalized()
		var cuerno := Formas.cono(0.13, 0.6, mat_cuerno)
		Formas.orientar(cuerno, dir)
		cuerno.position = centro + dir * 0.78
		pivote.add_child(cuerno)

	# Ojos furiosos, pupilas de rendija y cejas
	mat_ojos = Formas.mat(c_ojos, 4.0, 0.0, 0.3)
	var mat_negro := Formas.mat(Color(0.02, 0.0, 0.03), 0.0, 0.0, 0.6)
	for lado: float in [-1.0, 1.0]:
		var ojo := Formas.esfera(0.15, mat_ojos, Vector3(0.23 * lado, 0.93, 0.55), 16)
		ojo.scale = Vector3(1.0, 0.65, 0.55)
		ojo.rotation.z = 0.35 * lado
		pivote.add_child(ojo)
		var pupila := Formas.caja(Vector3(0.045, 0.14, 0.03), mat_negro, Vector3(0.23 * lado, 0.925, 0.635))
		pupila.rotation.z = 0.2 * lado
		pivote.add_child(pupila)
		var ceja := Formas.caja(Vector3(0.32, 0.07, 0.12), mat_negro, Vector3(0.22 * lado, 1.1, 0.52))
		ceja.rotation.z = 0.45 * lado
		pivote.add_child(ceja)

	# Boca con dientes
	pivote.add_child(Formas.caja(Vector3(0.46, 0.13, 0.08), Formas.mat(Color(0.3, 0.0, 0.06), 0.4), Vector3(0, 0.6, 0.58)))
	var mat_diente := Formas.mat(Color(1, 0.97, 0.9), 0.0, 0.2, 0.4)
	for i in 4:
		var diente := Formas.prisma(Vector3(0.08, 0.1, 0.04), mat_diente, Vector3(-0.16 + i * 0.107, 0.63, 0.63))
		diente.rotation.z = PI   # punta hacia abajo
		pivote.add_child(diente)
	for i in 3:
		pivote.add_child(Formas.prisma(Vector3(0.07, 0.08, 0.04), mat_diente, Vector3(-0.11 + i * 0.11, 0.565, 0.63)))

	# Corona del Rey Sombra
	if es_jefe:
		var mat_oro := Formas.mat(Color(1.0, 0.78, 0.2), 1.2, 0.5, 0.3)
		mat_oro.metallic = 0.8
		pivote.add_child(Formas.toroide(0.2, 0.33, mat_oro, Vector3(0, 1.33, 0.05), 24))
		for i in 6:
			var a := TAU * i / 6.0
			var punta := Formas.cono(0.07, 0.3, mat_oro, Vector3(sin(a) * 0.27, 1.5, cos(a) * 0.27 + 0.05), 8)
			pivote.add_child(punta)
			if i % 2 == 0:
				pivote.add_child(Formas.esfera(0.05, Formas.mat(Color(1.0, 0.2, 0.4), 3.0, 0.0), Vector3(sin(a) * 0.33, 1.33, cos(a) * 0.33 + 0.05), 8))

	# Patitas
	var mat_pie := Formas.mat(c_cuerpo.darkened(0.3), 0.0, 0.5)
	for lado: float in [-1.0, 1.0]:
		var pie := Node3D.new()
		pie.position = Vector3(0.3 * lado, 0.12, 0.08)
		var bola := Formas.esfera(0.2, mat_pie, Vector3.ZERO, 14)
		bola.scale = Vector3(1.0, 0.6, 1.35)
		pie.add_child(bola)
		modelo.add_child(pie)
		pies.append(pie)

	# Aura de humo oscuro y luz de los ojos
	var aura := Formas.particulas(c_puas.darkened(0.45), 18, 1.4, 0.5 * escala, 0.09 * escala, Vector3(0, 1.3, 0), 0.3, 1.0)
	aura.position.y = 0.8 * escala
	aura.local_coords = false
	add_child(aura)
	var luz := OmniLight3D.new()
	luz.light_color = c_ojos
	luz.light_energy = 0.8
	luz.omni_range = 3.5 * escala
	luz.position = Vector3(0, 1.0, 0.9) * escala
	add_child(luz)

	# Signo de alerta
	alerta = Label3D.new()
	alerta.text = "!"
	alerta.font_size = 110
	alerta.pixel_size = 0.006
	alerta.outline_size = 22
	alerta.modulate = Color(1.0, 0.85, 0.2)
	alerta.outline_modulate = Color(0.35, 0.0, 0.05)
	alerta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alerta.no_depth_test = true
	alerta.position.y = 2.2 * escala
	alerta.visible = false
	add_child(alerta)


func _construir_vida() -> void:
	puntos_vida = Node3D.new()
	puntos_vida.position.y = 2.05 * escala
	add_child(puntos_vida)
	var mat_p := Formas.mat(Color(1.0, 0.25, 0.4), 2.5, 0.0)
	for i in max_health:
		var x := (i - (max_health - 1) * 0.5) * 0.2
		puntos_vida.add_child(Formas.esfera(0.075, mat_p, Vector3(x, 0, 0), 10))
	puntos_vida.visible = false


func _actualizar_vida() -> void:
	var hijos := puntos_vida.get_children()
	for i in hijos.size():
		var pip := hijos[i] as Node3D
		pip.visible = i < health
	puntos_vida.visible = not es_jefe and health > 0 and health < max_health


# ---------- Comportamiento ----------

func _physics_process(delta: float) -> void:
	if estado == Estado.MUERTO:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	if not is_on_floor():
		velocity.y -= gravity * delta
	t_estado += delta
	enfriamiento = maxf(enfriamiento - delta, 0.0)

	var to_player := player.global_position - global_position
	var dy := absf(to_player.y)
	to_player.y = 0.0
	var dist := to_player.length()
	var lejos_de_hogar := Vector2(player.global_position.x - hogar.x, player.global_position.z - hogar.z).length()
	var jugador_en_zona := lejos_de_hogar < correa and dy < 3.5
	var deseada := Vector3.ZERO

	match estado:
		Estado.PATRULLA:
			var hacia := punto_patrulla - global_position
			hacia.y = 0.0
			if hacia.length() < 0.6 or t_estado > 5.0:
				_nuevo_punto_patrulla()
			else:
				deseada = hacia.normalized() * speed * 0.45
			if jugador_en_zona and dist <= detect_range:
				_cambiar(Estado.ALERTA)
		Estado.ALERTA:
			_mirar(to_player, delta, 14.0)
			if t_estado > 0.55:
				_cambiar(Estado.PERSIGUE)
		Estado.PERSIGUE:
			if not jugador_en_zona or dist > detect_range * 1.7:
				_cambiar(Estado.PATRULLA)
			elif dist <= attack_range * 2.3 and enfriamiento <= 0.0:
				_cambiar(Estado.CARGA)
			elif dist > attack_range * 0.8:
				deseada = to_player.normalized() * speed
		Estado.CARGA:
			# Se echa hacia atrás y brilla: aviso de que va a embestir
			_mirar(to_player, delta, 12.0)
			if t_estado > (0.6 if es_jefe else 0.45):
				dir_embestida = to_player.normalized() if dist > 0.05 else global_transform.basis.z
				_cambiar(Estado.EMBESTIDA)
		Estado.EMBESTIDA:
			deseada = dir_embestida * speed * 3.4
			if dist <= attack_range and enfriamiento <= 0.0:
				_hit_player()
			if t_estado > 0.38:
				enfriamiento = maxf(enfriamiento, attack_cooldown)
				_cambiar(Estado.PERSIGUE)
		Estado.ATURDIDO:
			if t_estado > 0.7:
				_cambiar(Estado.PERSIGUE)

	velocity.x = deseada.x + empuje.x
	velocity.z = deseada.z + empuje.z
	empuje = empuje.lerp(Vector3.ZERO, minf(8.0 * delta, 1.0))
	if deseada.length() > 0.1 and estado != Estado.EMBESTIDA:
		_mirar(deseada, delta, 9.0)
	move_and_slide()

	# Tocarla de frente mientras persigue también duele
	if estado == Estado.PERSIGUE and dist <= attack_range * 0.75 and enfriamiento <= 0.0:
		_hit_player()


func _cambiar(nuevo: Estado) -> void:
	estado = nuevo
	t_estado = 0.0
	match nuevo:
		Estado.ALERTA:
			velocity.y = 4.5   # saltito de sorpresa
			_mostrar_alerta()
		Estado.PATRULLA:
			punto_patrulla = hogar


func _nuevo_punto_patrulla() -> void:
	var a := randf() * TAU
	var r := randf_range(1.0, radio_patrulla)
	punto_patrulla = hogar + Vector3(sin(a) * r, 0.0, cos(a) * r)
	t_estado = 0.0


func _mirar(dir: Vector3, delta: float, vel: float) -> void:
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(vel * delta, 1.0))


func _hit_player() -> void:
	enfriamiento = attack_cooldown
	if player.has_method("take_damage"):
		player.take_damage(damage, global_position)


func _mostrar_alerta() -> void:
	alerta.visible = true
	alerta.scale = Vector3.ONE * 0.2
	var tw := create_tween()
	tw.tween_property(alerta, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_callback(alerta.hide)


func on_spin(from_pos: Vector3, push: float) -> void:
	if estado == Estado.MUERTO:
		return
	health -= 1
	var away := global_position - from_pos
	away.y = 0.0
	if away.length() < 0.01:
		away = -global_transform.basis.z
	empuje = away.normalized() * push * (2.5 if es_jefe else 6.0)
	velocity.y = 2.5 if es_jefe else 4.0
	_golpe_visual()
	_actualizar_vida()
	if health <= 0:
		_morir()
	else:
		_cambiar(Estado.ATURDIDO)


func _golpe_visual() -> void:
	mat_cuerpo.emission_energy_multiplier = 2.5
	var tw := create_tween()
	tw.tween_property(mat_cuerpo, "emission_energy_multiplier", 0.0, 0.3)
	pivote.scale = Vector3(1.35, 0.7, 1.35)
	Formas.estallido(get_parent(), global_position + Vector3(0, 0.9 * escala, 0), Color(1.0, 0.9, 0.6), 14)


func _morir() -> void:
	estado = Estado.MUERTO
	set_physics_process(false)
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.set_deferred("disabled", true)
	puntos_vida.visible = false
	Game.register_enemy(es_jefe)
	Formas.estallido(get_parent(), global_position + Vector3(0, 0.8 * escala, 0), Color(0.65, 0.25, 1.0), 120 if es_jefe else 50, 0.1 * escala)
	var tw := create_tween()
	tw.tween_property(modelo, "scale", modelo.scale * 1.35, 0.12)
	tw.tween_property(modelo, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(modelo, "rotation:y", modelo.rotation.y + TAU, 0.35)
	tw.finished.connect(queue_free)


# ---------- Animación ----------

func _process(delta: float) -> void:
	if modelo == null or estado == Estado.MUERTO:
		return
	var vel_h := Vector2(velocity.x, velocity.z).length()
	var ritmo := clampf(vel_h / maxf(speed, 0.1), 0.0, 1.5)
	t_anim += delta * (3.0 + ritmo * 9.0)

	var escala_obj := Vector3.ONE
	var inclinacion := 0.0
	var brillo_ojos := 4.0
	match estado:
		Estado.CARGA:
			var temblor := sin(t_estado * 40.0) * 0.04
			escala_obj = Vector3(1.18 + temblor, 0.78, 1.18 + temblor)
			inclinacion = -0.35
			brillo_ojos = 10.0
		Estado.EMBESTIDA:
			escala_obj = Vector3(0.88, 1.08, 1.25)
			inclinacion = 0.45
			brillo_ojos = 8.0
		Estado.ATURDIDO:
			inclinacion = -0.2
			brillo_ojos = 1.0
		_:
			var b := sin(t_anim * 2.0) * 0.06 * (0.4 + ritmo)
			escala_obj = Vector3(1.0 - b, 1.0 + b, 1.0 - b)

	pivote.scale = pivote.scale.lerp(escala_obj, minf(delta * 12.0, 1.0))
	pivote.rotation.x = lerpf(pivote.rotation.x, inclinacion, minf(delta * 10.0, 1.0))
	pivote.position.y = absf(sin(t_anim)) * 0.08 * ritmo
	mat_ojos.emission_energy_multiplier = lerpf(mat_ojos.emission_energy_multiplier, brillo_ojos, minf(delta * 8.0, 1.0))

	var paso := minf(ritmo, 1.0)
	for i in pies.size():
		var fase := t_anim + i * PI
		pies[i].position.z = 0.08 + sin(fase) * 0.14 * paso
		pies[i].position.y = 0.12 + maxf(cos(fase), 0.0) * 0.08 * paso

	if puntos_vida.visible:
		var cam := get_viewport().get_camera_3d()
		if cam and not cam.global_position.is_equal_approx(puntos_vida.global_position):
			puntos_vida.look_at(cam.global_position, Vector3.UP)
