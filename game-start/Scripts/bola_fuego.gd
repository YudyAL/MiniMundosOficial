extends Node3D
# Bola de fuego del Rey Sombra: vuela hacia Lumi (o hacia la nave),
# corrige un poco su rumbo y le quita 1 vida si la toca.
# Se puede esquivar moviéndose de lado, o destruir con el Láser Estelar.

const Formas = preload("res://Scripts/formas.gd")
const FUEGO := Color(1.0, 0.45, 0.08)

var objetivo: Node3D                  # normalmente el jugador
var velocidad := 10.0
var giro := 1.5                       # qué tanto la persigue (más bajo = más fácil esquivar)
var vida := 5.0                       # segundos antes de apagarse sola
var danio := 1
var direccion := Vector3.ZERO
var nucleo: MeshInstance3D
var t := 0.0


func _ready() -> void:
	add_to_group("bola_fuego")
	nucleo = Formas.esfera(0.32, Formas.mat(Color(1.0, 0.75, 0.2), 6.0, 0.0), Vector3.ZERO, 14)
	nucleo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(nucleo)
	var halo := Formas.esfera(0.55, Formas.mat_transparente(Color(1.0, 0.25, 0.05, 0.35), true), Vector3.ZERO, 14)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(halo)
	var estela := Formas.particulas(FUEGO, 40, 0.5, 0.25, 0.1, Vector3(0, 1.5, 0), 0.4, 4.0)
	estela.local_coords = false
	add_child(estela)
	var luz := OmniLight3D.new()
	luz.light_color = FUEGO
	luz.light_energy = 2.0
	luz.omni_range = 4.0
	add_child(luz)


func _physics_process(delta: float) -> void:
	t += delta
	vida -= delta
	if vida <= 0.0 or Game.finished or objetivo == null or not is_instance_valid(objetivo):
		explotar()
		return

	var centro := objetivo.global_position + Vector3(0, 0.9, 0)
	var hacia := centro - global_position
	var radio := 1.4 if bool(objetivo.get("en_nave")) else 0.8   # la nave es más grande
	if hacia.length() < radio:
		if objetivo.has_method("take_damage"):
			objetivo.take_damage(danio, global_position)
		explotar()
		return

	if direccion == Vector3.ZERO:
		direccion = hacia.normalized()
	direccion = direccion.lerp(hacia.normalized(), minf(giro * delta, 1.0)).normalized()
	global_position += direccion * velocidad * delta
	nucleo.scale = Vector3.ONE * (1.0 + sin(t * 25.0) * 0.12)   # chisporrotea


func explotar() -> void:
	if is_queued_for_deletion():
		return
	Formas.estallido(get_parent(), global_position, FUEGO, 30)
	queue_free()
