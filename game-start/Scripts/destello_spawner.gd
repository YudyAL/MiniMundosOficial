extends Node3D


@export var destello_scene: PackedScene
@export var in_front_of_wall: Array[Vector3] = [   # 5 delante del muro (lado de Lumi)
	Vector3(-18, 0, -8), Vector3(-8, 0, -11), Vector3(6, 0, -9),
	Vector3(16, 0, -10), Vector3(22, 0, -5)
]
@export var behind_wall: Array[Vector3] = [        # 7 detrás del muro (zona oculta)
	Vector3(-22, 0, -20), Vector3(-12, 0, -24), Vector3(-4, 0, -19),
	Vector3(5, 0, -26), Vector3(14, 0, -21), Vector3(24, 0, -23),
	Vector3(0, 0, -32)
]

func _ground_y(pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		Vector3(pos.x, 200.0, pos.z), Vector3(pos.x, -200.0, pos.z))
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return pos.y
	return hit.position.y

func _ready() -> void:
	await get_tree().physics_frame   # espera a que el terreno exista en la física
	for pos in in_front_of_wall + behind_wall:
		var d := destello_scene.instantiate()
		add_child(d)
		d.global_position = Vector3(pos.x, _ground_y(pos) + 0.1, pos.z)
