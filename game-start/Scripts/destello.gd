extends CharacterBody3D
# Destello. Escena: CharacterBody3D (este script) + CollisionShape3D + MeshInstance3D

@export var walk_detect := 4.0   # detecta a Lumi a 4 m si camina
@export var run_detect := 8.0    # y a 8 m si corre
@export var speed := 3.0
@export var flee_from_player := false   # true = huye en vez de perseguir

var calmed := false
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
    add_to_group("destello")
    player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
    if calmed or player == null:
        return
    if not is_on_floor():
        velocity.y -= gravity * delta

    var to_player := player.global_position - global_position
    to_player.y = 0.0
    var dist := to_player.length()
    var detect_range := run_detect if player.is_running else walk_detect

    if dist <= detect_range and dist > 1.0:
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

func on_spin(from_pos: Vector3, push: float) -> void:
    if calmed:
        return
    calmed = true
    set_physics_process(false)
    var away := global_position - from_pos
    away.y = 0.0
    var tween := create_tween()
    tween.tween_property(self, "global_position", global_position + away.normalized() * push, 0.15)
    tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
    tween.finished.connect(queue_free)
    Game.register_calm()
