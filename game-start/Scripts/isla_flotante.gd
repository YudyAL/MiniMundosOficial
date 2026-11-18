extends Node3D
# Isla flotante estilo galaxia: césped redondeado, capa de tierra, roca colgante
# con cristales, borde de arbustos (con muro invisible para no caer) y decoración.
# La posición de la isla es el CENTRO DE SU SUPERFICIE (donde se camina).

const Formas = preload("res://Scripts/formas.gd")
const ARBOLES_GLB := [
	preload("res://Assets/Bosque/tree_thin.glb"),
	preload("res://Assets/Bosque/tree_thin_dark.glb"),
	preload("res://Assets/Bosque/tree_thin_fall.glb"),
]
const CAPA_BORDE := 2   # capa de física de los bordes invisibles (la cámara la ignora)

var nombre_isla := "Isla"
var radio := 12.0
var color_pasto := Color(0.45, 0.85, 0.32)
var color_tierra := Color(0.6, 0.39, 0.24)
var color_roca := Color(0.36, 0.27, 0.45)
var colores_copa: Array = [Color(0.35, 0.78, 0.3)]
var aberturas: Array = []             # ángulos (radianes) donde llega un puente
var medio_ancho_abertura := 1.65      # metros a cada lado del puente
var semilla := 1
var spawn_local := Vector3(0, 0.3, 0)

var rng := RandomNumberGenerator.new()
var orbita: Node3D
var ocupados: Array[Vector3] = []
var mat_tronco: StandardMaterial3D


func _ready() -> void:
	rng.seed = semilla
	mat_tronco = Formas.mat(Color(0.47, 0.29, 0.18), 0.0, 0.3)
	_crear_suelo()
	_crear_borde()
	_crear_cesped_y_flores()
	_crear_orbita()


func _process(delta: float) -> void:
	if orbita:
		orbita.rotate_y(delta * 0.12)


# ---------- Suelo ----------

func _crear_suelo() -> void:
	# Colisión de la superficie
	var cuerpo := StaticBody3D.new()
	add_child(cuerpo)
	var forma := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = radio
	cil.height = 1.2
	forma.shape = cil
	forma.position.y = -0.6
	cuerpo.add_child(forma)

	# Césped y su borde redondeado
	var mat_pasto := Formas.mat(color_pasto, 0.0, 0.25)
	add_child(Formas.cilindro(radio, radio, 0.6, mat_pasto, Vector3(0, -0.3, 0), 64))
	var labio := Formas.toroide(radio - 0.45, radio + 0.2, Formas.mat(color_pasto.lightened(0.08), 0.0, 0.35), Vector3(0, -0.14, 0), 64)
	labio.scale = Vector3(1.0, 0.55, 1.0)
	add_child(labio)

	# Tierra
	add_child(Formas.cilindro(radio + 0.05, radio * 0.94, 1.0, Formas.mat(color_tierra, 0.0, 0.2), Vector3(0, -1.1, 0), 48))

	# Roca colgante (cono invertido)
	var mat_roca := Formas.mat(color_roca, 0.0, 0.3, 0.95)
	var alto_roca := radio * 0.8
	add_child(Formas.cilindro(radio * 0.94, radio * 0.16, alto_roca, mat_roca, Vector3(0, -1.6 - alto_roca * 0.5, 0), 20))
	var capa := Formas.cilindro(radio * 0.8, radio * 0.32, alto_roca * 0.55, Formas.mat(color_roca.lightened(0.12), 0.0, 0.3, 0.95),
			Vector3(radio * 0.08, -1.7 - alto_roca * 0.3, -radio * 0.05), 9)
	capa.rotation.y = rng.randf() * TAU
	add_child(capa)

	# Estalactitas
	for i in 8:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.25, 0.75) * radio
		var largo := rng.randf_range(1.5, 4.5)
		var y_sup := _y_roca(d, alto_roca)
		add_child(Formas.cilindro(largo * 0.18, 0.0, largo, mat_roca, Vector3(sin(a) * d, y_sup - largo * 0.5 + 0.3, cos(a) * d), 7))

	# Cristales colgantes brillantes
	var colores_cristal := [Color(0.45, 0.8, 1.0), Color(0.9, 0.5, 1.0), Color(1.0, 0.75, 0.35)]
	for i in 6:
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.2, 0.7) * radio
		var c: Color = colores_cristal[i % colores_cristal.size()]
		var alto := rng.randf_range(0.6, 1.4)
		var cristal := Formas.malla(Formas.cristal_mesh(alto * 0.4, alto), Formas.mat(c, 3.0, 0.0),
				Vector3(sin(a) * d, _y_roca(d, alto_roca) - alto * 0.7, cos(a) * d))
		cristal.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))
		add_child(cristal)
	var luz := OmniLight3D.new()
	luz.light_color = Color(0.7, 0.6, 1.0)
	luz.light_energy = 2.0
	luz.omni_range = radio * 0.9
	luz.position.y = -alto_roca * 0.6
	add_child(luz)


# Altura de la superficie de la roca colgante a una distancia del centro.
func _y_roca(d: float, alto_roca: float) -> float:
	var arriba := radio * 0.94
	var abajo := radio * 0.16
	var k := clampf((arriba - d) / (arriba - abajo), 0.0, 1.0)
	return -1.6 - alto_roca * k


# ---------- Borde con arbustos y muro invisible ----------

func _arcos() -> Array:
	if aberturas.is_empty():
		return [[0.0, TAU]]
	var lista: Array = aberturas.duplicate()
	lista.sort()
	var gh := medio_ancho_abertura / (radio - 0.35)
	var arcos: Array = []
	for i in lista.size():
		var a0: float = float(lista[i]) + gh
		var a1: float = float(lista[(i + 1) % lista.size()]) - gh
		if i == lista.size() - 1:
			a1 += TAU
		arcos.append([a0, a1])
	return arcos


func _crear_borde() -> void:
	var muro := StaticBody3D.new()
	muro.collision_layer = CAPA_BORDE
	muro.collision_mask = 0
	add_child(muro)
	var rw := radio - 0.35
	var t_arbustos: Array[Transform3D] = []
	var c_arbustos: Array[Color] = []
	var t_rocas: Array[Transform3D] = []
	var c_rocas: Array[Color] = []

	for arco in _arcos():
		var a0: float = arco[0]
		var a1: float = arco[1]
		var span := a1 - a0
		# Muro invisible en segmentos
		var n := maxi(1, ceili(span * rw / 1.4))
		var paso := span / n
		var ancho := 2.0 * rw * sin(paso * 0.5) * 1.12 + 0.1
		for j in n:
			var a := a0 + paso * (j + 0.5)
			var cs := CollisionShape3D.new()
			var caja := BoxShape3D.new()
			caja.size = Vector3(ancho, 3.0, 0.6)
			cs.shape = caja
			cs.position = Vector3(sin(a) * rw, 1.3, cos(a) * rw)
			cs.rotation.y = a
			muro.add_child(cs)
		# Arbustos y rocas decorativas encima del muro
		var nb := maxi(1, int(span * rw / 1.0))
		for j in nb:
			var a := a0 + span * (j + rng.randf_range(0.2, 0.8)) / nb
			var r := rw - rng.randf_range(-0.15, 0.35)
			var pos := Vector3(sin(a) * r, 0.0, cos(a) * r)
			if rng.randf() < 0.18:
				var s := rng.randf_range(0.35, 0.65)
				var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s * 1.3, s, s))
				t_rocas.append(Transform3D(b, pos + Vector3(0, s * 0.4, 0)))
				c_rocas.append(color_roca.lightened(rng.randf_range(0.15, 0.35)))
			else:
				var s := rng.randf_range(0.55, 1.0)
				var b := Basis().scaled(Vector3(s, s * rng.randf_range(0.75, 1.0), s))
				t_arbustos.append(Transform3D(b, pos + Vector3(0, 0.15 + s * 0.2, 0)))
				c_arbustos.append(color_pasto.darkened(rng.randf_range(0.08, 0.32)))

	var malla_arbusto := SphereMesh.new()
	malla_arbusto.radius = 0.7
	malla_arbusto.height = 1.4
	malla_arbusto.radial_segments = 12
	malla_arbusto.rings = 6
	add_child(_multimalla(malla_arbusto, t_arbustos, c_arbustos, Formas.mat_instancias()))
	var malla_roca := SphereMesh.new()
	malla_roca.radius = 0.8
	malla_roca.height = 1.4
	malla_roca.radial_segments = 6
	malla_roca.rings = 3
	add_child(_multimalla(malla_roca, t_rocas, c_rocas, Formas.mat_instancias()))


# ---------- Césped, flores y órbita de cristales ----------

func _crear_cesped_y_flores() -> void:
	var t_pasto: Array[Transform3D] = []
	var c_pasto: Array[Color] = []
	var matas := int(radio * radio * 0.8)
	for i in matas:
		var p := _punto_en_disco(radio - 1.2)
		for k in 3:
			var s := rng.randf_range(0.7, 1.4)
			var b := Basis(Vector3.UP, rng.randf() * TAU)
			b = b * Basis(Vector3.RIGHT, rng.randf_range(-0.35, 0.35))
			b = b.scaled(Vector3(s, s, s))
			var off := Vector3(rng.randf_range(-0.15, 0.15), 0.0, rng.randf_range(-0.15, 0.15))
			t_pasto.append(Transform3D(b, p + off + Vector3(0, 0.16 * s, 0)))
			c_pasto.append(color_pasto.lightened(rng.randf_range(-0.15, 0.2)))
	var malla_pasto := CylinderMesh.new()
	malla_pasto.top_radius = 0.0
	malla_pasto.bottom_radius = 0.07
	malla_pasto.height = 0.4
	malla_pasto.radial_segments = 4
	malla_pasto.rings = 1
	var mm_pasto := _multimalla(malla_pasto, t_pasto, c_pasto, Formas.mat_instancias())
	mm_pasto.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_pasto)

	var colores_flor := [Color(1.0, 0.5, 0.75), Color(1.0, 0.9, 0.35), Color(1.0, 1.0, 1.0), Color(0.5, 0.9, 1.0), Color(1.0, 0.62, 0.3)]
	var t_flor: Array[Transform3D] = []
	var c_flor: Array[Color] = []
	for i in int(radio * 4.0):
		var p := _punto_en_disco(radio - 1.5)
		var s := rng.randf_range(0.8, 1.3)
		t_flor.append(Transform3D(Basis().scaled(Vector3(s, s * 0.7, s)), p + Vector3(0, 0.3, 0)))
		c_flor.append(colores_flor[rng.randi() % colores_flor.size()])
	var malla_flor := SphereMesh.new()
	malla_flor.radius = 0.09
	malla_flor.height = 0.18
	malla_flor.radial_segments = 8
	malla_flor.rings = 4
	var mm_flor := _multimalla(malla_flor, t_flor, c_flor, Formas.mat_instancias(false))
	mm_flor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm_flor)


func _crear_orbita() -> void:
	orbita = Node3D.new()
	add_child(orbita)
	var colores := [Color(0.5, 0.85, 1.0), Color(1.0, 0.55, 0.9), Color(1.0, 0.85, 0.35)]
	for i in 7:
		var a := TAU * i / 7.0 + rng.randf_range(-0.2, 0.2)
		var r := radio + rng.randf_range(2.5, 4.5)
		var c: Color = colores[i % colores.size()]
		var cristal := Formas.malla(Formas.cristal_mesh(0.22, 0.5), Formas.mat(c, 3.0, 0.0),
				Vector3(sin(a) * r, rng.randf_range(0.5, 4.5), cos(a) * r))
		cristal.rotation = Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
		cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orbita.add_child(cristal)


# ---------- Árboles, hongos y cristales (los llama el nivel) ----------

func poblar(cantidad: int, tipos: Array, libres: Array, escala_min: float, escala_max: float, separacion: float = 2.6) -> void:
	var puestos := 0
	var intentos := 0
	while puestos < cantidad and intentos < cantidad * 40:
		intentos += 1
		var p := _punto_en_disco(radio - 2.8)
		if not _lugar_libre(p, libres, 3.0, separacion):
			continue
		var tipo: String = tipos[rng.randi() % tipos.size()]
		agregar_arbol(p, tipo, rng.randf_range(escala_min, escala_max))
		puestos += 1


func agregar_arbol(pos: Vector3, tipo: String, escala: float) -> void:
	var arbol := Node3D.new()
	arbol.position = pos
	arbol.rotation.y = rng.randf() * TAU
	add_child(arbol)
	ocupados.append(pos)
	var copa: Color = colores_copa[rng.randi() % colores_copa.size()]
	match tipo:
		"redondo":
			_arbol_redondo(arbol, copa)
		"pino":
			_arbol_pino(arbol, copa)
		"cristal":
			_arbol_cristal(arbol, copa)
		"glb":
			_arbol_glb(arbol)
		"hongo":
			_hongo(arbol, false)
		"hongo_gigante":
			_hongo(arbol, true)
	arbol.scale = Vector3.ONE * escala


func agregar_cristales_grandes(cantidad: int, libres: Array) -> void:
	var colores := [Color(0.45, 0.85, 1.0), Color(0.85, 0.5, 1.0)]
	var puestos := 0
	var intentos := 0
	while puestos < cantidad and intentos < cantidad * 40:
		intentos += 1
		var a := rng.randf() * TAU
		var d := rng.randf_range(radio - 4.0, radio - 2.4)
		var p := Vector3(sin(a) * d, 0.0, cos(a) * d)
		if not _lugar_libre(p, libres, 3.0, 2.5):
			continue
		ocupados.append(p)
		puestos += 1
		var grupo := Node3D.new()
		grupo.position = p
		add_child(grupo)
		var c: Color = colores[puestos % colores.size()]
		var m := Formas.mat(c, 2.2, 0.5, 0.2)
		for k in 3:
			var alto := rng.randf_range(0.8, 1.8)
			var cr := Formas.malla(Formas.cristal_mesh(alto * 0.35, alto), m,
					Vector3(rng.randf_range(-0.5, 0.5), alto * 0.7, rng.randf_range(-0.5, 0.5)))
			cr.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
			grupo.add_child(cr)
		var luz := OmniLight3D.new()
		luz.light_color = c
		luz.light_energy = 1.2
		luz.omni_range = 5.0
		luz.position.y = 1.2
		grupo.add_child(luz)
		_colision_tronco(grupo, 0.7, 2.0)


func agregar_luciernagas(cantidad: int = 40) -> void:
	var luciernagas := Formas.particulas(Color(0.85, 1.0, 0.45), cantidad, 6.0, 1.0, 0.05, Vector3(0, 0.05, 0), 0.35, 5.0)
	var pm := luciernagas.process_material as ParticleProcessMaterial
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(radio * 0.8, 1.5, radio * 0.8)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	luciernagas.preprocess = 6.0
	luciernagas.position.y = 2.0
	luciernagas.visibility_aabb = AABB(Vector3(-radio, -3, -radio), Vector3(radio * 2.0, 8, radio * 2.0))
	add_child(luciernagas)


# ---------- Tipos de árbol ----------

func _arbol_redondo(arbol: Node3D, copa: Color) -> void:
	arbol.add_child(Formas.cilindro(0.16, 0.27, 2.0, mat_tronco, Vector3(0, 1.0, 0), 10))
	var m1 := Formas.mat(copa, 0.0, 0.5, 0.9)
	var m2 := Formas.mat(copa.lightened(0.15), 0.0, 0.5, 0.9)
	arbol.add_child(Formas.esfera(1.1, m1, Vector3(0, 2.5, 0), 18))
	arbol.add_child(Formas.esfera(0.8, m2, Vector3(0.6, 2.2, 0.35), 16))
	arbol.add_child(Formas.esfera(0.85, m1, Vector3(-0.55, 2.3, -0.3), 16))
	arbol.add_child(Formas.esfera(0.7, m2, Vector3(0.1, 3.25, 0.05), 16))
	# Frutas brillantes
	var fruta := Formas.mat(Color(1.0, 0.45, 0.4) if rng.randf() < 0.5 else Color(1.0, 0.85, 0.3), 2.0, 0.0)
	for i in 3:
		var a := rng.randf() * TAU
		arbol.add_child(Formas.esfera(0.12, fruta, Vector3(sin(a) * 1.0, 2.2 + rng.randf() * 0.6, cos(a) * 1.0), 10))
	_colision_tronco(arbol, 0.3, 2.4)


func _arbol_pino(arbol: Node3D, copa: Color) -> void:
	arbol.add_child(Formas.cilindro(0.13, 0.22, 1.2, mat_tronco, Vector3(0, 0.6, 0), 8))
	var m1 := Formas.mat(copa.darkened(0.25), 0.0, 0.5, 0.9)
	var m2 := Formas.mat(copa.darkened(0.12), 0.0, 0.5, 0.9)
	arbol.add_child(Formas.cono(1.3, 1.7, m1, Vector3(0, 1.6, 0), 10))
	arbol.add_child(Formas.cono(1.0, 1.5, m2, Vector3(0, 2.4, 0), 10))
	arbol.add_child(Formas.cono(0.7, 1.3, m1, Vector3(0, 3.15, 0), 10))
	arbol.add_child(Formas.malla(Formas.estrella_mesh(5, 0.22, 0.1, 0.06), Formas.mat(Color(1.0, 0.9, 0.4), 3.0, 0.0), Vector3(0, 3.95, 0)))
	_colision_tronco(arbol, 0.3, 2.4)


func _arbol_cristal(arbol: Node3D, copa: Color) -> void:
	arbol.add_child(Formas.cilindro(0.12, 0.25, 2.2, Formas.mat(Color(0.38, 0.28, 0.55), 0.0, 0.5), Vector3(0, 1.1, 0), 8))
	var m := Formas.mat(copa, 0.7, 0.6, 0.4)
	arbol.add_child(Formas.esfera(0.95, m, Vector3(0, 2.6, 0), 16))
	arbol.add_child(Formas.esfera(0.65, m, Vector3(0.55, 2.2, 0.2), 14))
	arbol.add_child(Formas.esfera(0.6, m, Vector3(-0.5, 2.35, -0.2), 14))
	var m_cristal := Formas.mat(copa.lightened(0.3), 2.5, 0.0)
	for i in 4:
		var a := TAU * i / 4.0
		var cr := Formas.malla(Formas.cristal_mesh(0.12, 0.3), m_cristal, Vector3(sin(a) * 0.9, 2.9, cos(a) * 0.9))
		cr.rotation.z = 0.4
		arbol.add_child(cr)
	var luz := OmniLight3D.new()
	luz.light_color = copa
	luz.light_energy = 1.0
	luz.omni_range = 4.5
	luz.position.y = 2.5
	arbol.add_child(luz)
	_colision_tronco(arbol, 0.3, 2.4)


func _arbol_glb(arbol: Node3D) -> void:
	var escena: PackedScene = ARBOLES_GLB[rng.randi() % ARBOLES_GLB.size()]
	var modelo := escena.instantiate() as Node3D
	if modelo:
		modelo.scale = Vector3.ONE * 2.6
		arbol.add_child(modelo)
	_colision_tronco(arbol, 0.3, 2.6)


func _hongo(arbol: Node3D, gigante: bool) -> void:
	var colores := [Color(0.95, 0.3, 0.38), Color(0.62, 0.38, 0.98), Color(0.28, 0.78, 0.98), Color(1.0, 0.6, 0.22)]
	var c: Color = colores[rng.randi() % colores.size()]
	var alto := 1.7 if gigante else 0.45
	var r := 1.35 if gigante else 0.36
	var mat_tallo := Formas.mat(Color(0.98, 0.93, 0.82), 0.0, 0.3)
	arbol.add_child(Formas.cilindro(r * 0.17, r * 0.25, alto, mat_tallo, Vector3(0, alto * 0.5, 0), 12))
	var centro := Vector3(0, alto + r * 0.12, 0)
	var sombrero := Formas.esfera(r, Formas.mat(c, 0.3, 0.6, 0.6), centro, 24)
	sombrero.scale = Vector3(1.0, 0.58, 1.0)
	arbol.add_child(sombrero)
	arbol.add_child(Formas.cilindro(r * 0.52, r * 0.52, 0.04, Formas.mat(Color(1.0, 0.9, 0.75), 0.4, 0.0), centro - Vector3(0, r * 0.5, 0), 24))
	var mat_punto := Formas.mat(Color(1, 1, 0.95), 0.6, 0.0)
	var puntos := 6 if gigante else 3
	for i in puntos:
		var a := rng.randf() * TAU
		var elev := rng.randf_range(0.35, 0.85)
		var dir := Vector3(sin(a) * sqrt(1.0 - elev * elev), elev, cos(a) * sqrt(1.0 - elev * elev))
		var p := centro + Vector3(dir.x * r, dir.y * r * 0.58, dir.z * r) * 0.98
		var punto := Formas.esfera(r * 0.13, mat_punto, p, 10)
		punto.scale = Vector3(1.0, 0.5, 1.0)
		arbol.add_child(punto)
	if gigante:
		var luz := OmniLight3D.new()
		luz.light_color = c
		luz.light_energy = 1.2
		luz.omni_range = 5.0
		luz.position.y = alto * 0.7
		arbol.add_child(luz)
		_colision_tronco(arbol, r * 0.3, alto)


# ---------- Utilidades ----------

func _colision_tronco(padre: Node3D, radio_c: float, alto: float) -> void:
	var cuerpo := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cil := CylinderShape3D.new()
	cil.radius = radio_c
	cil.height = alto
	cs.shape = cil
	cs.position.y = alto * 0.5
	cuerpo.add_child(cs)
	padre.add_child(cuerpo)


func _punto_en_disco(r_max: float) -> Vector3:
	var a := rng.randf() * TAU
	var d := sqrt(rng.randf()) * r_max
	return Vector3(sin(a) * d, 0.0, cos(a) * d)


func _lugar_libre(p: Vector3, libres: Array, margen: float, separacion: float) -> bool:
	for q in libres:
		if p.distance_to(q) < margen:
			return false
	for q in ocupados:
		if p.distance_to(q) < separacion:
			return false
	return true


func _multimalla(mesh: Mesh, transformaciones: Array[Transform3D], colores: Array[Color], material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transformaciones.size()
	for i in transformaciones.size():
		mm.set_instance_transform(i, transformaciones[i])
		mm.set_instance_color(i, colores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	return mmi
