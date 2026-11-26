extends Node3D
# Láser Estelar: lo dispara la Nave Estelar. Vuela recto, corrige un poco
# su rumbo hacia el objetivo y le quita vida a la Sombra que toque.
# También puede destruir las bolas de fuego del Rey Sombra.

const Formas = preload("res://Scripts/formas.gd")
const COLOR := Color(0.4, 1.0, 0.85)

var objetivo: Node3D                  # Sombra a la que apunta (puede ser null)
var direccion := Vector3.FORWARD
var velocidad := 30.0
var vida := 1.6                       # segundos antes de desaparecer
var danio := 1


func _ready() -> void:
	var rayo := Formas.cilindro(0.07, 0.07, 1.1, Formas.mat(COLOR, 6.0, 0.0), Vector3.ZERO, 8)
	rayo.rotation.x = PI * 0.5        # el cilindro queda acostado a lo largo de Z
	rayo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rayo)
	var luz := OmniLight3D.new()
	luz.light_color = COLOR
	luz.light_energy = 1.2
	luz.omni_range = 2.5
	add_child(luz)


func _physics_process(delta: float) -> void:
	vida -= delta
	if vida <= 0.0:
		queue_free()
		return

	# Corrige el rumbo hacia el objetivo (apuntado automático)
	if objetivo and is_instance_valid(objetivo) and int(objetivo.get("health")) > 0:
		var hacia := _centro(objetivo) - global_position
		if hacia.length() > 0.01:
			direccion = direccion.lerp(hacia.normalized(), minf(10.0 * delta, 1.0)).normalized()

	global_position += direccion * velocidad * delta
	var arriba := Vector3.UP if absf(direccion.y) < 0.98 else Vector3.RIGHT
	look_at(global_position + direccion, arriba)

	# ¿Tocó alguna bola de fuego?
	for b in get_tree().get_nodes_in_group("bola_fuego"):
		var bola := b as Node3D
		if bola and bola.global_position.distance_to(global_position) < 0.8:
			bola.call("explotar")
			_impacto()
			return

	# ¿Tocó alguna Sombra?
	for e in get_tree().get_nodes_in_group("enemy"):
		var sombra := e as Node3D
		if sombra == null or int(sombra.get("health")) <= 0:
			continue
		var escala := float(sombra.get("escala"))
		if _centro(sombra).distance_to(global_position) < 0.8 * escala:
			if sombra.has_method("recibir_disparo"):
				sombra.recibir_disparo(danio, global_position)
			_impacto()
			return


func _centro(sombra: Node3D) -> Vector3:
	return sombra.global_position + Vector3(0, 0.8 * float(sombra.get("escala")), 0)


func _impacto() -> void:
	Formas.estallido(get_parent(), global_position, COLOR, 14)
	queue_free()
