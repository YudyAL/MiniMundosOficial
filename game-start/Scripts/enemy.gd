extends CharacterBody3D
# Enemigo de oscuridad. Escena: CharacterBody3D + CollisionShape3D + MeshInstance3D

@export var speed := 3.5
@export var detect_range := 10.0
@export var attack_range := 1.6
@export var damage := 1
@export var attack_cooldown := 1.0
@export var max_health := 3

var health := 3
var can_attack := true
var player: Node3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
    add_to_group("enemy")
    health = max_health
    player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
    if player == null:
        return
    if not is_on_floor():
        velocity.y -= gravity * delta

    var to_player := player.global_position - global_position
    to_player.y = 0.0
    var dist := to_player.length()

    if dist <= detect_range and dist > attack_range:
        var dir := to_player.normalized()
        velocity.x = dir.x * speed
        velocity.z = dir.z * speed
        rotation.y = atan2(dir.x, dir.z)
    else:
        velocity.x = 0.0
        velocity.z = 0.0
    move_and_slide()

    if dist <= attack_range and can_attack:
        _hit_player()

func _hit_player() -> void:
    can_attack = false
    player.take_damage(damage, global_position)
    await get_tree().create_timer(attack_cooldown).timeout
    can_attack = true

func on_spin(from_pos: Vector3, push: float) -> void:
    health -= 1
    var away := global_position - from_pos
    away.y = 0.0
    var tween := create_tween()
    tween.tween_property(self, "global_position", global_position + away.normalized() * push, 0.15)
    if health <= 0:
        set_physics_process(false)
        tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
        tween.finished.connect(queue_free)
