extends Node3D
# Muro de bosque: pone árboles y rocas en fila apoyados en el terreno.

@export var length := 60.0        # largo del muro en metros
@export var spacing := 1.5        # separación entre piezas
@export var jitter := 1.5         # desorden hacia los lados
@export var min_scale := 2.0      # tamaño mínimo de cada pieza
@export var max_scale := 3.0      # tamaño máximo de cada pieza
@export var pieces: Array[PackedScene]

func _ground_y(world_pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(world_pos.x, 200.0, world_pos.z),
		Vector3(world_pos.x, -200.0, world_pos.z))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return global_position.y
	return hit.position.y

func _ready() -> void:
	await get_tree().physics_frame   # espera a que el terreno exista en la física
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var x := -length / 2.0
	while x <= length / 2.0:
		var scene: PackedScene = pieces.pick_random()
		var n: Node3D = scene.instantiate()
		add_child(n)
		var world := to_global(Vector3(x, 0.0, rng.randf_range(-jitter, jitter)))
		world.y = _ground_y(world)
		n.global_position = world
		n.rotation.y = rng.randf_range(0.0, TAU)
		n.scale = Vector3.ONE * rng.randf_range(min_scale, max_scale)
		x += spacing

	# Colisión del muro, apoyada en el suelo del centro
	var ground_local := to_local(Vector3(global_position.x, _ground_y(global_position), global_position.z)).y
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(length, 4.0, 2.0 + jitter * 2.0)
	shape.shape = box
	shape.position.y = ground_local + 2.0
	body.add_child(shape)
	add_child(body)
