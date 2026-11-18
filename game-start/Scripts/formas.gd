extends RefCounted
# Utilidades para construir modelos, materiales y partículas con estilo "galaxia".


# ---------- Materiales ----------

static func mat(color: Color, emision: float = 0.0, rim: float = 0.35, rugosidad: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rugosidad
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.4
	if emision > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emision
	return m


# Material que toma el color de cada instancia (para MultiMesh).
static func mat_instancias(sombreado: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	if sombreado:
		m.rim_enabled = true
		m.rim = 0.4
		m.rim_tint = 0.4
	else:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func mat_transparente(color: Color, aditivo: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if aditivo:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


# ---------- Mallas básicas ----------

static func malla(mesh: Mesh, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if material:
		mi.material_override = material
	mi.position = pos
	return mi


static func esfera(radio: float, material: Material, pos: Vector3 = Vector3.ZERO, segmentos: int = 24) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = radio
	m.height = radio * 2.0
	m.radial_segments = segmentos
	m.rings = maxi(int(segmentos * 0.5), 4)
	return malla(m, material, pos)


static func cilindro(r_arriba: float, r_abajo: float, alto: float, material: Material, pos: Vector3 = Vector3.ZERO, lados: int = 16) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r_arriba
	m.bottom_radius = r_abajo
	m.height = alto
	m.radial_segments = lados
	m.rings = 1
	return malla(m, material, pos)


static func cono(radio: float, alto: float, material: Material, pos: Vector3 = Vector3.ZERO, lados: int = 12) -> MeshInstance3D:
	return cilindro(0.0, radio, alto, material, pos, lados)


static func caja(tam: Vector3, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = tam
	return malla(m, material, pos)


static func prisma(tam: Vector3, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := PrismMesh.new()
	m.size = tam
	return malla(m, material, pos)


static func toroide(r_interior: float, r_exterior: float, material: Material, pos: Vector3 = Vector3.ZERO, segmentos: int = 48) -> MeshInstance3D:
	var m := TorusMesh.new()
	m.inner_radius = r_interior
	m.outer_radius = r_exterior
	m.rings = segmentos
	m.ring_segments = 12
	return malla(m, material, pos)


# Orienta el eje +Y del nodo hacia una dirección.
static func orientar(nodo: Node3D, direccion: Vector3) -> void:
	var d := direccion.normalized()
	if d.is_equal_approx(Vector3.UP):
		nodo.basis = Basis()
		return
	if d.is_equal_approx(Vector3.DOWN):
		nodo.basis = Basis(Vector3.RIGHT, PI)
		return
	nodo.basis = Basis(Quaternion(Vector3.UP, d))


# ---------- Mallas especiales ----------

# Estrella extruida (frente hacia +Z), con el centro abultado.
static func estrella_mesh(puntas: int = 5, r_ext: float = 1.0, r_int: float = 0.45, grosor: float = 0.3) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := puntas * 2
	var borde: Array[Vector3] = []
	for i in n:
		var a := TAU * i / n
		var r := r_ext if i % 2 == 0 else r_int
		borde.append(Vector3(sin(a) * r, cos(a) * r, 0.0))
	var frente := Vector3(0, 0, grosor)
	var atras := Vector3(0, 0, -grosor)
	for i in n:
		var a := borde[i]
		var b := borde[(i + 1) % n]
		st.add_vertex(frente)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(atras)
		st.add_vertex(b)
		st.add_vertex(a)
	st.generate_normals()
	return st.commit()


# Cristal octaédrico (rombo 3D).
static func cristal_mesh(ancho: float = 0.3, alto: float = 0.6) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arriba := Vector3(0, alto, 0)
	var abajo := Vector3(0, -alto, 0)
	var anillo: Array[Vector3] = [Vector3(ancho, 0, 0), Vector3(0, 0, ancho), Vector3(-ancho, 0, 0), Vector3(0, 0, -ancho)]
	for i in 4:
		var a := anillo[i]
		var b := anillo[(i + 1) % 4]
		st.add_vertex(arriba)
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(abajo)
		st.add_vertex(b)
		st.add_vertex(a)
	st.generate_normals()
	return st.commit()


# ---------- Partículas ----------

static func particulas(color: Color, cantidad: int, vida: float, radio_emision: float, tam: float,
		gravedad: Vector3, velocidad: float = 0.5, energia: float = 2.5) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = cantidad
	p.lifetime = vida
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = radio_emision
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = velocidad * 0.4
	pm.initial_velocity_max = velocidad
	pm.gravity = gravedad
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var curva := Curve.new()
	curva.add_point(Vector2(0.0, 0.0))
	curva.add_point(Vector2(0.15, 1.0))
	curva.add_point(Vector2(1.0, 0.0))
	var textura_curva := CurveTexture.new()
	textura_curva.curve = curva
	pm.scale_curve = textura_curva
	p.process_material = pm
	var bolita := SphereMesh.new()
	bolita.radius = tam
	bolita.height = tam * 2.0
	bolita.radial_segments = 6
	bolita.rings = 3
	bolita.material = mat(color, energia, 0.0)
	p.draw_pass_1 = bolita
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-8, -8, -8), Vector3(16, 16, 16))
	return p


# Explosión de chispas de un solo uso (se borra sola).
static func estallido(padre: Node, pos: Vector3, color: Color, cantidad: int = 30, tam: float = 0.08) -> void:
	if padre == null or not padre.is_inside_tree():
		return
	var p := particulas(color, cantidad, 0.9, 0.3, tam, Vector3(0, -4.0, 0), 6.0, 4.0)
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	padre.add_child(p)
	p.global_position = pos
	p.emitting = true
	p.get_tree().create_timer(2.0).timeout.connect(p.queue_free)
