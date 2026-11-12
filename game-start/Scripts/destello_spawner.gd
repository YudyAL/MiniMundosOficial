extends Node3D
# Pon este script en un Node3D vacío del nivel ("DestelloSpawner").
# Arrastra destello.tscn a "destello_scene" y ajusta las posiciones en el Inspector.

@export var destello_scene: PackedScene
@export var in_front_of_wall: Array[Vector3] = [   # 5 delante del muro
    Vector3(-6, 1, 8), Vector3(-2, 1, 10), Vector3(3, 1, 7), Vector3(7, 1, 11), Vector3(0, 1, 5)
]
@export var behind_wall: Array[Vector3] = [        # 7 detrás del muro (zona oculta)
    Vector3(-9, 1, -8), Vector3(-5, 1, -12), Vector3(-1, 1, -9), Vector3(3, 1, -14),
    Vector3(7, 1, -10), Vector3(10, 1, -6), Vector3(0, 1, -17)
]

func _ready() -> void:
    for pos in in_front_of_wall + behind_wall:
        var d := destello_scene.instantiate()
        add_child(d)
        d.global_position = pos
