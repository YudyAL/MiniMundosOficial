extends Area3D
# Cristal Congelante: al tocarlo, congela a todas las Sombras cercanas
# durante unos segundos. Después de un rato vuelve a aparecer.

const Formas = preload("res://Scripts/formas.gd")
const HIELO := Color(0.5, 0.88, 1.0)

var radio_efecto := 20.0
var duracion := 6.0
var recarga := 20.0

var disponible := true
var visual: Node3D
var t := 0.0


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var esfera := SphereShape3D.new()
	esfera.radius = 1.1
	cs.shape = esfera
	cs.position.y = 1.0
	add_child(cs)

	# Base pequeña
	add_child(Formas.cilindro(0.6, 0.75, 0.18, Formas.mat(Color(0.3, 0.4, 0.65), 0.0, 0.6, 0.35), Vector3(0, 0.09, 0), 24))
	add_child(Formas.toroide(0.55, 0.68, Formas.mat(HIELO, 2.5, 0.0), Vector3(0, 0.2, 0), 32))

	# Cristal tipo copo: tres cristales cruzados
	visual = Node3D.new()
	visual.position.y = 1.1
	add_child(visual)
	var mat := Formas.mat(HIELO, 2.2, 0.6, 0.15)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.add_child(Formas.malla(Formas.cristal_mesh(0.18, 0.5), mat))
	for k in 2:
		var cr := Formas.malla(Formas.cristal_mesh(0.12, 0.38), mat)
		cr.rotation.z = PI * 0.5
		cr.rotation.y = k * PI * 0.5
		visual.add_child(cr)
	var luz := OmniLight3D.new()
	luz.light_color = HIELO
	luz.light_energy = 1.4
	luz.omni_range = 4.0
	visual.add_child(luz)
	visual.add_child(Formas.particulas(Color(0.85, 0.95, 1.0), 12, 1.4, 0.5, 0.03, Vector3(0, -0.3, 0), 0.25, 4.0))

	body_entered.connect(_al_entrar)


func _process(delta: float) -> void:
	t += delta
	visual.rotate_y(delta * 1.8)
	visual.position.y = 1.1 + sin(t * 2.2) * 0.12


func _al_entrar(body: Node3D) -> void:
	if not disponible or not body.is_in_group("player"):
		return
	disponible = false
	var congeladas := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		var sombra := e as Node3D
		if sombra and sombra.has_method("congelar") and sombra.global_position.distance_to(global_position) <= radio_efecto:
			sombra.congelar(duracion)
			congeladas += 1
	if congeladas > 0:
		Game.mostrar_mensaje("¡%d Sombra%s congelada%s por %d segundos!" % [congeladas, "s" if congeladas > 1 else "", "s" if congeladas > 1 else "", int(duracion)])
	else:
		Game.mostrar_mensaje("Cristal Congelante: no hay Sombras cerca")
	_onda_de_hielo()
	Formas.estallido(get_parent(), visual.global_position, HIELO, 40)
	visual.visible = false
	get_tree().create_timer(recarga).timeout.connect(_reaparecer)


func _reaparecer() -> void:
	visual.visible = true
	visual.scale = Vector3.ONE * 0.1
	create_tween().tween_property(visual, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	disponible = true


func _onda_de_hielo() -> void:
	var mat := Formas.mat_transparente(Color(HIELO.r, HIELO.g, HIELO.b, 0.7), true)
	var onda := Formas.toroide(0.9, 1.0, mat, Vector3(0, 0.4, 0), 64)
	onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	onda.scale = Vector3(0.5, 0.4, 0.5)
	add_child(onda)
	var tw := onda.create_tween()
	tw.set_parallel(true)
	tw.tween_property(onda, "scale", Vector3(radio_efecto, 0.4, radio_efecto), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(onda.queue_free)
