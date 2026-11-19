extends Node3D
# Estilo visual de Lumi (va como hijo del Player).
# Borde de luz estelar, bufanda violeta con franja dorada, estrella flotando
# sobre la cabeza, chispas al correr y anillo de luz al girar.
# Solo es decoración: no cambia los movimientos ni los controles.

const Formas = preload("res://Scripts/formas.gd")
const ORO := Color(1.0, 0.82, 0.3)
const VIOLETA := Color(0.52, 0.28, 0.95)
const VIOLETA_OSCURO := Color(0.34, 0.16, 0.7)
const LUZ_BORDE := Color(0.75, 0.65, 1.0)

const SHADER_BORDE := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 color_borde : source_color = vec4(0.75, 0.65, 1.0, 1.0);
uniform float potencia = 2.4;
uniform float intensidad = 1.3;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), potencia);
	ALBEDO = color_borde.rgb * f * intensidad;
}
"""

var lumi: CharacterBody3D
var modelo: Node3D
var esqueleto: Skeleton3D
var hueso_cabeza := -1
var hueso_cuello := -1
var alto := 1.8

var bufanda: Node3D
var colas: Array[Node3D] = []
var estrella: Node3D
var malla_estrella: MeshInstance3D
var chispas: GPUParticles3D
var t := 0.0
var balanceo := 0.0
var giraba := false


func _ready() -> void:
	lumi = get_parent() as CharacterBody3D
	if lumi == null:
		return
	modelo = lumi.get_node_or_null("Model") as Node3D
	if modelo == null:
		return
	_aplicar_borde()
	_buscar_huesos()
	_crear_bufanda()
	_crear_estrella()
	_crear_chispas()


# ---------- Borde de luz y medidas del modelo ----------

func _aplicar_borde() -> void:
	var sh := Shader.new()
	sh.code = SHADER_BORDE
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("color_borde", LUZ_BORDE)
	var y_min := INF
	var y_max := -INF
	for n in modelo.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		m.material_overlay = mat
		var caja := m.get_aabb()
		for i in 8:
			var y := (m.global_transform * caja.get_endpoint(i)).y
			y_min = minf(y_min, y)
			y_max = maxf(y_max, y)
	if y_max > y_min:
		alto = clampf(y_max - y_min, 0.8, 3.0)


func _buscar_huesos() -> void:
	var lista := modelo.find_children("*", "Skeleton3D", true, false)
	if lista.is_empty():
		return
	esqueleto = lista[0] as Skeleton3D
	hueso_cabeza = _hueso("head")
	hueso_cuello = _hueso("neck")


func _hueso(nombre: String) -> int:
	for i in esqueleto.get_bone_count():
		var n := esqueleto.get_bone_name(i).to_lower()
		if n.ends_with(nombre):
			return i
	for i in esqueleto.get_bone_count():
		var n := esqueleto.get_bone_name(i).to_lower()
		if n.contains(nombre) and not n.contains("end"):
			return i
	return -1


func _pos_hueso(idx: int, altura_respaldo: float) -> Vector3:
	if esqueleto and idx >= 0:
		return (esqueleto.global_transform * esqueleto.get_bone_global_pose(idx)).origin
	return modelo.global_position + Vector3(0, alto * altura_respaldo, 0)


# ---------- Piezas ----------

func _crear_bufanda() -> void:
	var f := alto / 1.8
	bufanda = Node3D.new()
	bufanda.top_level = true
	add_child(bufanda)
	var mat := Formas.mat(VIOLETA, 0.25, 0.6, 0.7)
	var mat_oscuro := Formas.mat(VIOLETA_OSCURO, 0.15, 0.6, 0.7)
	var mat_oro := Formas.mat(ORO, 1.5, 0.3, 0.4)
	var anillo := Formas.toroide(0.13 * f, 0.26 * f, mat, Vector3.ZERO, 32)
	anillo.scale = Vector3(1.0, 0.75, 1.0)
	bufanda.add_child(anillo)
	bufanda.add_child(Formas.toroide(0.2 * f, 0.27 * f, mat_oro, Vector3(0, -0.035 * f, 0), 32))
	# Dos puntas que cuelgan atrás y ondean al correr
	for lado: float in [-1.0, 1.0]:
		var pivote := Node3D.new()
		pivote.position = Vector3(0.06 * f * lado, 0.0, -0.2 * f)
		bufanda.add_child(pivote)
		var largo := (0.5 if lado < 0.0 else 0.4) * f
		pivote.add_child(Formas.caja(Vector3(0.13 * f, largo, 0.035 * f), mat_oscuro if lado < 0.0 else mat, Vector3(0, -largo * 0.5, 0)))
		pivote.add_child(Formas.caja(Vector3(0.135 * f, 0.05 * f, 0.04 * f), mat_oro, Vector3(0, -largo + 0.05 * f, 0)))
		colas.append(pivote)


func _crear_estrella() -> void:
	estrella = Node3D.new()
	estrella.top_level = true
	add_child(estrella)
	var mat := Formas.mat(ORO, 3.0, 0.5, 0.3)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	malla_estrella = Formas.malla(Formas.estrella_mesh(5, 0.16, 0.07, 0.05), mat)
	malla_estrella.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	estrella.add_child(malla_estrella)
	var luz := OmniLight3D.new()
	luz.light_color = ORO
	luz.light_energy = 0.9
	luz.omni_range = 3.0
	estrella.add_child(luz)
	var brillo := Formas.particulas(ORO, 8, 1.0, 0.15, 0.025, Vector3(0, -0.4, 0), 0.15, 5.0)
	estrella.add_child(brillo)


func _crear_chispas() -> void:
	chispas = Formas.particulas(ORO, 40, 0.7, 0.25, 0.04, Vector3(0, 0.6, 0), 0.4, 5.0)
	chispas.local_coords = false
	chispas.position.y = 0.25
	chispas.emitting = false
	add_child(chispas)


# ---------- Animación ----------

func _process(delta: float) -> void:
	if lumi == null or modelo == null:
		return
	t += delta
	var yaw := modelo.global_rotation.y
	var vel := Vector2(lumi.velocity.x, lumi.velocity.z).length()
	var lanzado := bool(lumi.get("controls_locked"))

	# Bufanda en el cuello, mirando hacia donde mira Lumi
	bufanda.global_position = _pos_hueso(hueso_cuello, 0.62)
	bufanda.global_rotation = Vector3(0, yaw, 0)
	bufanda.visible = modelo.visible
	var objetivo := clampf(vel / 8.0, 0.0, 1.0) * 1.2
	if lanzado:
		objetivo = 1.4
	balanceo = lerpf(balanceo, objetivo, minf(delta * 6.0, 1.0))
	for i in colas.size():
		var onda := sin(t * (10.0 + i * 3.0) + i) * (0.08 + balanceo * 0.15)
		colas[i].rotation = Vector3(0.15 + balanceo + onda, 0.0, (i - 0.5) * 0.25)

	# Estrella flotando sobre la cabeza
	var cabeza := _pos_hueso(hueso_cabeza, 0.75)
	var arriba := lumi.global_position.y + alto + 0.3 + sin(t * 2.5) * 0.06
	estrella.global_position = Vector3(cabeza.x, arriba, cabeza.z)
	malla_estrella.rotate_y(delta * (12.0 if lanzado else 2.0))

	# Chispas al correr o volar
	var corriendo := bool(lumi.get("is_running")) and lumi.is_on_floor()
	chispas.emitting = corriendo or lanzado

	# Anillo de luz al girar
	var girando := bool(lumi.get("is_attacking"))
	if girando and not giraba:
		_anillo_giro()
	giraba = girando


func _anillo_giro() -> void:
	var mat := Formas.mat_transparente(Color(ORO.r, ORO.g, ORO.b, 0.85), true)
	var anillo := Formas.toroide(0.9, 1.1, mat, Vector3.ZERO, 48)
	anillo.top_level = true
	anillo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(anillo)
	anillo.global_position = lumi.global_position + Vector3(0, alto * 0.4, 0)
	anillo.scale = Vector3(0.4, 0.3, 0.4)
	var tw := anillo.create_tween()
	tw.set_parallel(true)
	tw.tween_property(anillo, "scale", Vector3(1.7, 0.3, 1.7), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tw.chain().tween_callback(anillo.queue_free)
	Formas.estallido(get_parent().get_parent(), lumi.global_position + Vector3(0, alto * 0.4, 0), ORO, 16, 0.05)
