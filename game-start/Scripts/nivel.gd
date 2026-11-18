extends Node3D
# Nivel "Bosque Estelar": cuatro islas flotantes en el espacio, unidas por un
# puente y por lanzadores estelares. Todo se construye por código al iniciar.
#
#   1. Claro de las Luciérnagas (inicio)  --puente-->  2. Bosque de Hongos
#   2. Bosque de Hongos  --lanzador-->  3. Arboleda Oculta (muro de árboles)
#   3. Arboleda Oculta   --lanzador-->  4. Cima Estelar (Rey Sombra + Gran Estrella)
#   4. Cima Estelar      --lanzador-->  1. Claro (para volver por destellos perdidos)

const Formas = preload("res://Scripts/formas.gd")
const Ambiente = preload("res://Scripts/ambiente_galaxia.gd")
const IslaFlotante = preload("res://Scripts/isla_flotante.gd")
const Lanzador = preload("res://Scripts/lanzador_estelar.gd")
const GranEstrella = preload("res://Scripts/gran_estrella.gd")
const Muro = preload("res://Scripts/muro.gd")
const ESCENA_DESTELLO := preload("res://Escenas/Destello.tscn")
const ESCENA_ENEMIGO := preload("res://Escenas/Enemigo.tscn")

const VACIO_Y := -45.0        # si Lumi cae por debajo, reaparece (y pierde 1 vida)
const CAPA_BORDE := 2

var player: CharacterBody3D
var islas: Array = []
var isla_actual: Node3D
var checkpoint := Vector3(0, 0.3, 7)
var total_destellos := 0


func _ready() -> void:
	player = get_node_or_null("Player") as CharacterBody3D
	add_child(Ambiente.new())
	_construir_nivel()

	Game.total_destellos = total_destellos
	Game.hay_jefe = true
	Game.usa_estrella = true
	Game.jugando = true

	if player:
		player.collision_mask = 1 | CAPA_BORDE
		player.global_position = checkpoint
		var brazo := player.get_node_or_null("SpringArm3D") as SpringArm3D
		if brazo:
			brazo.spring_length = 5.0
	Game.mostrar_mensaje.call_deferred("Bosque Estelar — calma los destellos y derrota al Rey Sombra")


func _construir_nivel() -> void:
	# ---------- 1. Claro de las Luciérnagas ----------
	var claro := _isla("Claro de las Luciérnagas", Vector3(0, 0, 0), 13.0, [PI], 11,
			Color(0.47, 0.86, 0.33), [Color(0.35, 0.78, 0.3), Color(0.5, 0.86, 0.32), Color(1.0, 0.62, 0.8)])
	claro.spawn_local = Vector3(0, 0.3, 7)
	var d_claro := [Vector3(-7, 0, 3), Vector3(8, 0, 2), Vector3(-5, 0, -6), Vector3(5, 0, -8)]
	var e_claro := [Vector3(1, 0, -4)]
	var libres_claro := d_claro + e_claro + [Vector3(0, 0, 7), Vector3(0, 0, 4), Vector3(0, 0, -11), Vector3(0, 0, -8), Vector3(3, 0, 5)]
	claro.poblar(10, ["redondo", "redondo", "pino", "glb"], libres_claro, 0.9, 1.3)
	claro.agregar_luciernagas(50)
	_destellos(claro, d_claro, [1, 3])
	_enemigos(claro, e_claro)
	isla_actual = claro

	# ---------- 2. Bosque de Hongos ----------
	var hongos := _isla("Bosque de Hongos", Vector3(0, 3, -42), 12.0, [0.0], 22,
			Color(0.4, 0.82, 0.55), [Color(0.3, 0.7, 0.45)])
	hongos.spawn_local = Vector3(0, 0.3, 9)
	var d_hongos := [Vector3(-6, 0, 3), Vector3(7, 0, 3), Vector3(-5, 0, -6), Vector3(0, 0, -8)]
	var e_hongos := [Vector3(-3, 0, -1), Vector3(4, 0, -2)]
	var lanz_hongos := Vector3(5, 0, -6)
	var libres_hongos := d_hongos + e_hongos + [lanz_hongos, Vector3(0, 0, 10), Vector3(0, 0, 7), Vector3(0, 0, 4)]
	hongos.poblar(5, ["hongo_gigante"], libres_hongos, 1.0, 1.4, 3.5)
	hongos.poblar(16, ["hongo"], libres_hongos, 0.8, 1.5, 1.4)
	hongos.poblar(2, ["redondo", "cristal"], libres_hongos, 0.9, 1.1)
	_destellos(hongos, d_hongos, [0, 2])
	_enemigos(hongos, e_hongos)

	# ---------- 3. Arboleda Oculta ----------
	var arboleda := _isla("Arboleda Oculta", Vector3(46, 9, -64), 16.0, [], 33,
			Color(0.34, 0.72, 0.3), [Color(0.25, 0.62, 0.28), Color(0.4, 0.75, 0.3), Color(0.95, 0.55, 0.3)])
	arboleda.spawn_local = Vector3(0, 0.3, 12)
	var d_arboleda := [Vector3(-8, 0, 6), Vector3(8, 0, 7), Vector3(0, 0, 4),     # delante del muro
			Vector3(-7, 0, -8), Vector3(2, 0, -7), Vector3(-2, 0, -13)]            # escondidos detrás
	var e_arboleda := [Vector3(-4, 0, 9), Vector3(4, 0, -11)]
	var lanz_arboleda := Vector3(9, 0, -10)
	var libres_arboleda := d_arboleda + e_arboleda + [lanz_arboleda, Vector3(0, 0, 12), Vector3(0, 0, 9)]
	for x in range(-13, 14, 2):   # franja del muro de árboles y sus pasos laterales
		libres_arboleda.append(Vector3(x, 0, -2))
	arboleda.poblar(16, ["redondo", "pino", "pino", "glb", "cristal"], libres_arboleda, 0.9, 1.4)
	arboleda.agregar_luciernagas(40)
	var muro := Muro.new()
	muro.length = 22.0
	muro.spacing = 1.6
	muro.jitter = 1.0
	muro.min_scale = 2.0
	muro.max_scale = 3.0
	var piezas: Array[PackedScene] = [
		preload("res://Assets/Bosque/rock_tallF.glb"), preload("res://Assets/Bosque/rock_tallG.glb"),
		preload("res://Assets/Bosque/tree_thin.glb"), preload("res://Assets/Bosque/tree_thin_dark.glb"),
		preload("res://Assets/Bosque/tree_thin_fall.glb"),
	]
	muro.pieces = piezas
	muro.position = arboleda.position + Vector3(0, 0, -2)
	add_child(muro)
	_destellos(arboleda, d_arboleda, [0, 4])
	_enemigos(arboleda, e_arboleda)

	# ---------- 4. Cima Estelar ----------
	var cima := _isla("Cima Estelar", Vector3(0, 18, -104), 14.0, [], 44,
			Color(0.42, 0.78, 0.62), [Color(0.4, 0.85, 1.0), Color(0.8, 0.55, 1.0)])
	cima.color_roca = Color(0.3, 0.24, 0.5)
	cima.spawn_local = Vector3(4, 0.3, 9)
	var d_cima := [Vector3(-8, 0, 3), Vector3(8, 0, -2), Vector3(-5, 0, -9)]
	var e_cima := [Vector3(7, 0, 4)]
	var pos_estrella := Vector3(0, 0, -1)
	var pos_jefe := Vector3(2, 0, -6)
	var lanz_cima := Vector3(-8, 0, 8)
	var libres_cima := d_cima + e_cima + [pos_estrella, pos_jefe, lanz_cima, Vector3(4, 0, 9),
			Vector3(0, 0, 3), Vector3(3, 0, -3), Vector3(-3, 0, -3), Vector3(0, 0, -5)]
	cima.agregar_cristales_grandes(5, libres_cima)
	cima.poblar(6, ["cristal", "cristal", "pino"], libres_cima, 0.9, 1.3)
	_destellos(cima, d_cima, [1])
	_enemigos(cima, e_cima)
	_enemigo(cima.position + pos_jefe, true)
	var estrella := GranEstrella.new()
	estrella.position = cima.position + pos_estrella
	add_child(estrella)

	# ---------- Conexiones ----------
	_puente(claro.position + Vector3(0, 0, -(claro.radio - 0.4)), hongos.position + Vector3(0, 0, hongos.radio - 0.4))
	_lanzador(hongos.position + lanz_hongos, arboleda.position + Vector3(0, 0.1, 12), 14.0, Color(1.0, 0.85, 0.25))
	_lanzador(arboleda.position + lanz_arboleda, cima.position + Vector3(4, 0.1, 9), 16.0, Color(1.0, 0.85, 0.25))
	_lanzador(cima.position + lanz_cima, claro.position + Vector3(3, 0.1, 5), 10.0, Color(0.45, 0.9, 1.0))


# ---------- Constructores ----------

func _isla(nombre: String, centro: Vector3, radio: float, aberturas: Array, semilla: int,
		pasto: Color, copas: Array) -> IslaFlotante:
	var isla := IslaFlotante.new()
	isla.nombre_isla = nombre
	isla.position = centro
	isla.radio = radio
	isla.aberturas = aberturas
	isla.semilla = semilla
	isla.color_pasto = pasto
	isla.colores_copa = copas
	add_child(isla)
	islas.append(isla)
	return isla


func _destellos(isla: IslaFlotante, posiciones: Array, huyen: Array) -> void:
	for i in posiciones.size():
		var d := ESCENA_DESTELLO.instantiate() as Node3D
		d.set("flee_from_player", i in huyen)
		var local: Vector3 = posiciones[i]
		d.position = isla.position + local + Vector3(0, 0.15, 0)
		add_child(d)
		total_destellos += 1


func _enemigos(isla: IslaFlotante, posiciones: Array) -> void:
	for p in posiciones:
		var local: Vector3 = p
		_enemigo(isla.position + local, false)


func _enemigo(pos: Vector3, jefe: bool) -> void:
	var e := ESCENA_ENEMIGO.instantiate() as Node3D
	if jefe:
		e.set("es_jefe", true)
		e.set("max_health", 8)
		e.set("speed", 4.2)
		e.set("detect_range", 13.0)
		e.set("attack_range", 2.6)
		e.set("radio_patrulla", 3.0)
		e.set("correa", 12.0)
	e.position = pos + Vector3(0, 0.2, 0)
	add_child(e)


func _lanzador(pos: Vector3, destino: Vector3, altura: float, color: Color) -> void:
	var l := Lanzador.new()
	l.position = pos
	l.destino = destino
	l.altura_arco = altura
	l.color = color
	add_child(l)


# Puente de madera con barandas y faroles entre dos puntos de superficie.
func _puente(desde: Vector3, hasta: Vector3) -> void:
	var dir := hasta - desde
	var largo := dir.length()
	var puente := Node3D.new()
	puente.position = (desde + hasta) * 0.5
	puente.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
	add_child(puente)

	# Colisión: tablero (capa normal) y barandas (capa de borde, la cámara las ignora)
	var tablero := StaticBody3D.new()
	puente.add_child(tablero)
	_caja_colision(tablero, Vector3(3.2, 0.4, largo), Vector3(0, -0.2, 0))
	var barandas := StaticBody3D.new()
	barandas.collision_layer = CAPA_BORDE
	barandas.collision_mask = 0
	puente.add_child(barandas)
	_caja_colision(barandas, Vector3(0.3, 2.4, largo + 2.0), Vector3(1.75, 1.0, 0))
	_caja_colision(barandas, Vector3(0.3, 2.4, largo + 2.0), Vector3(-1.75, 1.0, 0))

	# Tablas
	var mat_a := Formas.mat(Color(0.66, 0.43, 0.25), 0.0, 0.3)
	var mat_b := Formas.mat(Color(0.56, 0.35, 0.2), 0.0, 0.3)
	var n := int(largo / 0.45)
	for i in n:
		var z := -largo * 0.5 + (i + 0.5) * largo / n
		var tabla := Formas.caja(Vector3(3.0 + (i % 2) * 0.2, 0.22, 0.38), mat_a if i % 2 == 0 else mat_b, Vector3(0, -0.11, z))
		tabla.rotation.y = (i % 3 - 1) * 0.03
		puente.add_child(tabla)
	# Vigas de abajo
	for x: float in [-1.2, 1.2]:
		puente.add_child(Formas.caja(Vector3(0.25, 0.3, largo), mat_b, Vector3(x, -0.35, 0)))

	# Barandas, postes y faroles
	var mat_poste := Formas.mat(Color(0.45, 0.28, 0.16), 0.0, 0.3)
	var mat_farol := Formas.mat(Color(1.0, 0.8, 0.4), 4.0, 0.0)
	for lado: float in [-1.0, 1.0]:
		puente.add_child(Formas.caja(Vector3(0.14, 0.14, largo), mat_poste, Vector3(1.6 * lado, 0.95, 0)))
		puente.add_child(Formas.caja(Vector3(0.1, 0.1, largo), mat_poste, Vector3(1.6 * lado, 0.5, 0)))
		var postes := int(largo / 3.0) + 1
		for j in postes:
			var z := -largo * 0.5 + j * largo / (postes - 1)
			puente.add_child(Formas.caja(Vector3(0.22, 1.2, 0.22), mat_poste, Vector3(1.6 * lado, 0.5, z)))
			if j % 2 == 0:
				puente.add_child(Formas.esfera(0.16, mat_farol, Vector3(1.6 * lado, 1.25, z), 10))
	var luz := OmniLight3D.new()
	luz.light_color = Color(1.0, 0.8, 0.45)
	luz.light_energy = 1.5
	luz.omni_range = largo * 0.6
	luz.position.y = 2.0
	puente.add_child(luz)


func _caja_colision(cuerpo: StaticBody3D, tam: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = tam
	cs.shape = caja
	cs.position = pos
	cuerpo.add_child(cs)


# ---------- Puntos de control y caída al vacío ----------

func _physics_process(_delta: float) -> void:
	if player == null or Game.finished:
		return
	if player.global_position.y < VACIO_Y:
		_reaparecer()
		return
	if not player.is_on_floor():
		return
	for isla in islas:
		var c: Vector3 = isla.position
		var r: float = isla.radio
		var plano := Vector2(player.global_position.x - c.x, player.global_position.z - c.z)
		if plano.length() < r - 0.5 and absf(player.global_position.y - c.y) < 1.5:
			var spawn: Vector3 = isla.spawn_local
			checkpoint = c + spawn
			if isla != isla_actual:
				isla_actual = isla
				Game.mostrar_mensaje(isla.nombre_isla)
			break


func _reaparecer() -> void:
	player.velocity = Vector3.ZERO
	player.global_position = checkpoint
	Game.mostrar_mensaje("¡Cuidado con el vacío!")
	if player.has_method("take_damage"):
		player.take_damage(1, checkpoint)
