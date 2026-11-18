extends Node3D
# Ambiente espacial estilo galaxia: cielo de nebulosas con estrellas, sol,
# planetas lejanos, cinturón de asteroides y polvo de estrellas flotando.

const Formas = preload("res://Scripts/formas.gd")
const CENTRO_NIVEL := Vector3(20, 5, -55)

const SHADER_CIELO := """
shader_type sky;

uniform vec3 color_cenit : source_color = vec3(0.015, 0.01, 0.06);
uniform vec3 color_horizonte : source_color = vec3(0.17, 0.07, 0.32);
uniform vec3 color_abajo : source_color = vec3(0.03, 0.02, 0.11);
uniform vec3 nebulosa_rosa : source_color = vec3(0.78, 0.22, 0.68);
uniform vec3 nebulosa_azul : source_color = vec3(0.15, 0.42, 0.98);

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float ruido(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash13(i);
	float b = hash13(i + vec3(1.0, 0.0, 0.0));
	float c = hash13(i + vec3(0.0, 1.0, 0.0));
	float d = hash13(i + vec3(1.0, 1.0, 0.0));
	float e = hash13(i + vec3(0.0, 0.0, 1.0));
	float g = hash13(i + vec3(1.0, 0.0, 1.0));
	float h = hash13(i + vec3(0.0, 1.0, 1.0));
	float k = hash13(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(a, b, f.x), mix(c, d, f.x), f.y), mix(mix(e, g, f.x), mix(h, k, f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 5; i++) {
		v += amp * ruido(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		amp *= 0.5;
	}
	return v;
}

vec3 estrellas(vec3 dir, float escala, float umbral) {
	vec3 celda = dir * escala;
	vec3 id = floor(celda);
	float r = hash13(id);
	if (r < umbral) {
		return vec3(0.0);
	}
	vec3 desvio = vec3(hash13(id + 1.3), hash13(id + 7.1), hash13(id + 3.7)) - 0.5;
	vec3 centro = id + 0.5 + desvio * 0.6;
	float d = length(celda - centro);
	float brillo = 1.0 - smoothstep(0.0, 0.28, d);
	vec3 tono = mix(vec3(1.0, 0.85, 0.7), vec3(0.7, 0.85, 1.0), hash13(id + 5.0));
	return tono * brillo * (1.5 + 6.0 * (r - umbral) / (1.0 - umbral));
}

void sky() {
	vec3 dir = EYEDIR;
	float h = dir.y;
	vec3 col = mix(color_horizonte, color_cenit, smoothstep(0.0, 0.75, h));
	col = mix(col, color_abajo, smoothstep(0.0, 0.6, -h));
	float t = (dir.y - 0.1 + dir.x * 0.4) * 2.0;
	float banda = exp(-t * t);
	float n1 = fbm(dir * 2.2);
	float n2 = fbm(dir * 3.5 + vec3(4.0, 1.0, 7.0));
	col += nebulosa_rosa * smoothstep(0.42, 0.85, n1) * (0.3 + 0.9 * banda);
	col += nebulosa_azul * smoothstep(0.48, 0.9, n2) * (0.2 + 0.8 * banda);
	col += vec3(0.9, 0.8, 1.0) * banda * 0.08 * smoothstep(0.3, 0.7, n1);
	col += estrellas(dir, 170.0, 0.965);
	col += estrellas(dir, 60.0, 0.988) * 1.6;
	COLOR = col;
}
"""

var cinturon: Node3D
var planetas: Array[Node3D] = []


func _ready() -> void:
	_crear_entorno()
	_crear_luces()
	_crear_planetas()
	_crear_cinturon()
	_crear_polvo_estelar()


func _process(delta: float) -> void:
	if cinturon:
		cinturon.rotate_y(delta * 0.012)
	for p in planetas:
		p.rotate_y(delta * 0.04)


func _crear_entorno() -> void:
	var shader := Shader.new()
	shader.code = SHADER_CIELO
	var mat_cielo := ShaderMaterial.new()
	mat_cielo.shader = shader
	var cielo := Sky.new()
	cielo.sky_material = mat_cielo
	cielo.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = cielo
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.54, 0.92)
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.0
	env.glow_bloom = 0.06
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.ssao_enabled = true
	env.ssao_intensity = 1.4
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.05

	var mundo := WorldEnvironment.new()
	mundo.environment = env
	add_child(mundo)


func _crear_luces() -> void:
	var sol := DirectionalLight3D.new()
	sol.rotation_degrees = Vector3(-50.0, -32.0, 0.0)
	sol.light_color = Color(1.0, 0.93, 0.82)
	sol.light_energy = 1.3
	sol.shadow_enabled = true
	sol.directional_shadow_max_distance = 90.0
	add_child(sol)

	# Luz de relleno violeta desde el lado contrario (sin sombras)
	var relleno := DirectionalLight3D.new()
	relleno.rotation_degrees = Vector3(-25.0, 150.0, 0.0)
	relleno.light_color = Color(0.55, 0.45, 1.0)
	relleno.light_energy = 0.4
	add_child(relleno)

	# Disco del sol en el cielo, en la dirección de donde viene la luz
	var hacia_sol := sol.basis.z.normalized()
	var pos_sol := CENTRO_NIVEL + hacia_sol * 520.0
	_fondo(Formas.esfera(26.0, Formas.mat(Color(1.0, 0.86, 0.6), 5.0, 0.0), pos_sol, 24))
	_fondo(Formas.esfera(48.0, Formas.mat_transparente(Color(1.0, 0.7, 0.4, 0.12), true), pos_sol, 24))


func _crear_planetas() -> void:
	# Gigante gaseoso violeta con atmósfera
	var gigante := _fondo(Formas.esfera(110.0, Formas.mat(Color(0.36, 0.3, 0.85), 0.25, 0.9, 0.9), Vector3(-310, 40, -400), 48))
	planetas.append(gigante)
	_fondo(Formas.esfera(118.0, Formas.mat_transparente(Color(0.5, 0.6, 1.0, 0.1), true), Vector3(-310, 40, -400), 48))
	var mat_banda := Formas.mat(Color(0.58, 0.42, 0.98), 0.35, 0.0)
	for desfase: float in [-38.0, 0.0, 30.0]:
		var rr := sqrt(110.0 * 110.0 - desfase * desfase)
		var banda := Formas.toroide(rr - 2.0, rr + 1.2, mat_banda, Vector3(-310, 40 + desfase, -400), 64)
		banda.scale = Vector3(1.0, 0.35, 1.0)
		_fondo(banda)

	# Planeta naranja con anillos
	var anillado := _fondo(Formas.esfera(45.0, Formas.mat(Color(0.98, 0.62, 0.35), 0.2, 0.7, 0.9), Vector3(340, 150, -270), 40))
	planetas.append(anillado)
	var anillo := Formas.toroide(62.0, 96.0, Formas.mat_transparente(Color(1.0, 0.84, 0.62, 0.55)), Vector3(340, 150, -270), 96)
	anillo.scale = Vector3(1.0, 0.03, 1.0)
	anillo.rotation = Vector3(0.45, 0.0, 0.3)
	_fondo(anillo)

	# Mini mundo verde con arbolitos (abajo, a lo lejos)
	var mini_pos := Vector3(170, -150, -380)
	var mini := _fondo(Formas.esfera(34.0, Formas.mat(Color(0.35, 0.8, 0.4), 0.15, 0.8), mini_pos, 32))
	planetas.append(mini)
	var mat_copa := Formas.mat(Color(0.2, 0.6, 0.3), 0.1, 0.6)
	for i in 14:
		var dir := Vector3(sin(i * 2.4), 0.4 + 0.6 * absf(cos(i * 1.7)), cos(i * 2.4)).normalized()
		var arbol := Formas.cono(4.0, 10.0, mat_copa, dir * 37.0)
		Formas.orientar(arbol, dir)
		mini.add_child(arbol)

	# Luna lila
	_fondo(Formas.esfera(18.0, Formas.mat(Color(0.75, 0.7, 0.9), 0.1, 0.6), Vector3(-140, 190, 220), 32))


func _crear_cinturon() -> void:
	cinturon = Node3D.new()
	cinturon.position = CENTRO_NIVEL + Vector3(0, -20, 0)
	add_child(cinturon)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var mat_roca := Formas.mat(Color(0.42, 0.34, 0.52), 0.0, 0.5, 0.95)
	var mat_roca_b := Formas.mat(Color(0.3, 0.25, 0.4), 0.0, 0.5, 0.95)
	for i in 70:
		var a := rng.randf() * TAU
		var r := rng.randf_range(110.0, 160.0)
		var pos := Vector3(sin(a) * r, rng.randf_range(-25.0, 25.0), cos(a) * r)
		var tam := rng.randf_range(0.8, 5.0)
		var roca := Formas.esfera(tam, mat_roca if i % 3 != 0 else mat_roca_b, pos, 7)
		roca.scale = Vector3(rng.randf_range(0.7, 1.3), rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.3))
		roca.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)
		roca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cinturon.add_child(roca)
		if i % 6 == 0:
			var color_cristal := Color(0.4, 0.85, 1.0) if i % 12 == 0 else Color(1.0, 0.5, 0.9)
			var cristal := Formas.malla(Formas.cristal_mesh(tam * 0.35, tam * 0.8), Formas.mat(color_cristal, 2.5, 0.0), pos + Vector3(0, tam, 0))
			cristal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cinturon.add_child(cristal)


func _crear_polvo_estelar() -> void:
	var colores := [Color(1.0, 0.92, 0.65), Color(0.6, 0.85, 1.0)]
	for c: Color in colores:
		var polvo := Formas.particulas(c, 220, 9.0, 1.0, 0.06, Vector3(0, 0.12, 0), 0.25, 5.0)
		var pm := polvo.process_material as ParticleProcessMaterial
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(75, 30, 85)
		polvo.preprocess = 9.0
		polvo.position = CENTRO_NIVEL
		polvo.visibility_aabb = AABB(Vector3(-90, -45, -100), Vector3(180, 90, 200))
		add_child(polvo)


func _fondo(nodo: MeshInstance3D) -> MeshInstance3D:
	nodo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nodo)
	return nodo
