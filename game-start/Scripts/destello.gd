extends CharacterBody3D
# Destello: cristal estelar agitado. Gira cerca de él (ESPACIO) para calmarlo.
# Escena: CharacterBody3D (este script) + CollisionShape3D. El brillo se arma por código.

const Formas = preload("res://Scripts/formas.gd")
const COLORES := [
	Color(1.0, 0.85, 0.2), Color(0.35, 0.9, 1.0), Color(1.0, 0.45, 0.75),
	Color(0.55, 1.0, 0.45), Color(0.78, 0.55, 1.0),
]

@export var walk_detect := 4.0   # detecta a Lumi a 4 m si camina
@export var run_detect := 8.0    # y a 8 m si corre
@export var speed := 3.0
@export var flee_from_player := false   # true = huye en vez de perseguir

var calmed := false
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var color := Color(1.0, 0.85, 0.2)
var visual: Node3D
var cristal: MeshInstance3D
var t := 0.0


func _ready() -> void:
	add_to_group("destello")
	collision_mask |= 2   # no se cae de las islas
	player = get_tree().get_first_node_in_group("player")
	color = COLORES[randi() % COLORES.size()]
	t = randf() * 10.0
	_construir()


func _construir() -> void:
	visual = Node3D.new()
	visual.position.y = 0.45
	add_child(visual)

	var mat_cristal := Formas.mat(color, 2.6, 0.4, 0.25)
	mat_cristal.cull_mode = BaseMaterial3D.CULL_DISABLED
	cristal = Formas.malla(Formas.estrella_mesh(4, 0.34, 0.13, 0.13), mat_cristal)
	visual.add_child(cristal)
	var nucleo := Formas.esfera(0.11, Formas.mat(Color(1, 1, 1), 4.0, 0.0), Vector3.ZERO, 12)
	visual.add_child(nucleo)

	var luz := OmniLight3D.new()
	luz.light_color = color
	luz.light_energy = 0.9
	luz.omni_range = 3.0
	visual.add_child(luz)

	var chispas := Formas.particulas(color, 10, 1.2, 0.35, 0.035, Vector3(0, 0.6, 0), 0.3, 4.0)
	visual.add_child(chispas)


func _process(delta: float) -> void:
	if calmed:
		return
	t += delta
	var agitacion := clampf(Vector2(velocity.x, velocity.z).length() / maxf(speed, 0.1), 0.0, 1.0)
	visual.position.y = 0.45 + sin(t * (3.0 + agitacion * 5.0)) * 0.12
	cristal.rotate_y(delta * (2.5 + agitacion * 8.0))


func _physics_process(delta: float) -> void:
	if calmed or player == null:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	var to_player := player.global_position - global_position
	var dy := absf(to_player.y)
	to_player.y = 0.0
	var dist := to_player.length()
	var detect_range: float = run_detect if player.get("is_running") else walk_detect

	if dist <= detect_range and dist > 1.0 and dy < 3.0:
		var dir := to_player.normalized()
		if flee_from_player:
			dir = -dir
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		rotation.y = atan2(dir.x, dir.z)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
	move_and_slide()


func on_spin(_from_pos: Vector3, _push: float) -> void:
	if calmed:
		return
	calmed = true
	set_physics_process(false)
	var cs := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if cs:
		cs.set_deferred("disabled", true)
	Formas.estallido(get_parent(), visual.global_position, color, 30)
	var tw := create_tween()
	tw.tween_property(visual, "position:y", visual.position.y + 1.6, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "scale", Vector3.ONE * 1.6, 0.35)
	tw.tween_property(visual, "scale", Vector3.ONE * 0.01, 0.25)
	tw.finished.connect(queue_free)
	Game.register_calm()
