extends Area3D
# Gran Estrella: la meta del nivel. Se ve como silueta hasta que calmas
# todos los destellos y derrotas al Rey Sombra; entonces aparece y, al tocarla, ganas.

const Formas = preload("res://Scripts/formas.gd")
const ORO := Color(1.0, 0.82, 0.25)

var activa := false
var tomada := false
var estrella: MeshInstance3D
var mat_fantasma: StandardMaterial3D
var mat_oro: StandardMaterial3D
var haz: MeshInstance3D
var luz: OmniLight3D
var chispas: GPUParticles3D
var t := 0.0


func _ready() -> void:
	monitoring = false
	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 1.7
	cs.shape = esfera
	cs.position.y = 1.8
	add_child(cs)

	# Pedestal
	var mat_base := Formas.mat(Color(0.3, 0.22, 0.55), 0.0, 0.7, 0.35)
	add_child(Formas.cilindro(2.0, 2.4, 0.4, mat_base, Vector3(0, 0.2, 0), 32))
	add_child(Formas.cilindro(1.5, 1.8, 0.3, mat_base, Vector3(0, 0.55, 0), 32))
	add_child(Formas.toroide(1.55, 1.75, Formas.mat(ORO, 2.5, 0.0), Vector3(0, 0.72, 0), 48))
	for i in 6:
		var a := TAU * i / 6.0
		var cr := Formas.malla(Formas.cristal_mesh(0.18, 0.5), Formas.mat(Color(0.6, 0.8, 1.0), 2.5, 0.0), Vector3(sin(a) * 2.15, 0.85, cos(a) * 2.15))
		add_child(cr)

	# Estrella: primero solo una silueta transparente
	mat_fantasma = Formas.mat_transparente(Color(1.0, 0.9, 0.5, 0.22))
	mat_oro = Formas.mat(ORO, 3.0, 0.6, 0.25)
	mat_oro.cull_mode = BaseMaterial3D.CULL_DISABLED
	estrella = Formas.malla(Formas.estrella_mesh(5, 1.0, 0.45, 0.32), mat_fantasma, Vector3(0, 2.3, 0))
	estrella.scale = Vector3.ONE * 1.3
	add_child(estrella)

	# Haz de luz (oculto)
	haz = Formas.cilindro(1.1, 1.1, 90.0, Formas.mat_transparente(Color(1.0, 0.85, 0.4, 0.16), true), Vector3(0, 45.0, 0), 24)
	haz.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	haz.visible = false
	add_child(haz)

	luz = OmniLight3D.new()
	luz.light_color = ORO
	luz.light_energy = 3.0
	luz.omni_range = 12.0
	luz.position.y = 2.3
	luz.visible = false
	add_child(luz)

	chispas = Formas.particulas(ORO, 40, 1.8, 1.4, 0.06, Vector3(0, 1.5, 0), 0.8, 5.0)
	chispas.position.y = 2.0
	chispas.emitting = false
	add_child(chispas)

	Game.objetivo_cumplido.connect(_activar)
	body_entered.connect(_al_entrar)


func _process(delta: float) -> void:
	t += delta
	estrella.rotate_y(delta * (2.2 if activa else 0.6))
	estrella.position.y = 2.3 + sin(t * 2.0) * 0.18


func _activar() -> void:
	if activa:
		return
	activa = true
	estrella.material_override = mat_oro
	estrella.scale = Vector3.ONE * 0.1
	var tw := create_tween()
	tw.tween_property(estrella, "scale", Vector3.ONE * 1.3, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	haz.visible = true
	luz.visible = true
	chispas.emitting = true
	Formas.estallido(get_parent(), global_position + Vector3(0, 2.3, 0), ORO, 80)
	set_deferred("monitoring", true)


func _al_entrar(body: Node3D) -> void:
	if not activa or tomada or not body.is_in_group("player"):
		return
	tomada = true
	Formas.estallido(get_parent(), estrella.global_position, ORO, 120, 0.12)
	var tw := create_tween()
	tw.tween_property(estrella, "position:y", estrella.position.y + 3.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	Game.win()
