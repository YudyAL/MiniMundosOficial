extends CharacterBody3D


@export var walk_speed := 4.0
@export var run_speed := 8.0
@export var accel := 12.0
@export var turn_speed := 10.0
@export var max_health := 5
@export var attack_cooldown := 0.6
@export var push_distance := 1.5
@export var mouse_sens := 0.003

var health := 5
var is_running := false
var is_attacking := false
var can_attack := true
var invulnerable := false
var knockback := Vector3.ZERO
var controls_locked := false   # true mientras un lanzador estelar mueve a Lumi
var en_nave := false           # true mientras Lumi pilota la Nave Estelar
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var spring_arm: SpringArm3D = $SpringArm3D
@onready var model: Node3D = $Model
@onready var spin_area: Area3D = $SpinArea
@onready var anim: AnimationPlayer = get_node_or_null("Model/AnimationPlayer")

func _ready() -> void:
	add_to_group("player")
	health = max_health
	Game.reset()
	_setup_inputs()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _setup_inputs() -> void:
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
		"run": KEY_SHIFT, "attack": KEY_SPACE,
		"interact": KEY_E, "disparar": KEY_F
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotation.y -= event.relative.x * mouse_sens
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * mouse_sens, -1.2, 0.3)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if controls_locked:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	var move_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw := Basis(Vector3.UP, spring_arm.rotation.y)
	var dir := (yaw * Vector3(move_input.x, 0.0, move_input.y)).normalized()
	
	is_running = (Input.is_action_pressed("run") or Input.is_physical_key_pressed(KEY_SHIFT)) and dir != Vector3.ZERO
	var speed := run_speed if is_running else walk_speed
	var target := dir * speed

	velocity.x = move_toward(velocity.x, target.x, accel * delta * speed) + knockback.x
	velocity.z = move_toward(velocity.z, target.z, accel * delta * speed) + knockback.z
	knockback = knockback.lerp(Vector3.ZERO, 10.0 * delta)

	if dir != Vector3.ZERO and not is_attacking:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), turn_speed * delta)

	move_and_slide()

	if Input.is_action_just_pressed("attack") and can_attack:
		_spin_attack()

	if not is_attacking:
		if dir == Vector3.ZERO:
			_play("idle")
		elif is_running:
			_play("run")
		else:
			_play("walk")

func _spin_attack() -> void:
	can_attack = false
	is_attacking = true
	_play("attack")
	# Giro visual de 360°
	var tween := create_tween()
	tween.tween_property(model, "rotation:y", model.rotation.y + TAU, 0.3)
	tween.finished.connect(func(): is_attacking = false)
	# Afecta a todo lo que esté alrededor
	for body in spin_area.get_overlapping_bodies():
		if body.has_method("on_spin"):
			body.on_spin(global_position, push_distance)
	# También activa áreas (por ejemplo, los lanzadores estelares)
	for area in spin_area.get_overlapping_areas():
		if area.has_method("on_spin"):
			area.on_spin(global_position, push_distance)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

func take_damage(amount: int, from_pos: Vector3) -> void:
	if invulnerable:
		return
	health -= amount
	var away := (global_position - from_pos)
	away.y = 0.0
	knockback = away.normalized() * 6.0
	invulnerable = true
	Game.jugador_herido.emit()
	_parpadeo()
	if health <= 0:
		Game.lose()
		return
	await get_tree().create_timer(1.0).timeout
	invulnerable = false

func _parpadeo() -> void:
	# Lumi parpadea mientras es invulnerable
	if en_nave:
		return   # va escondida dentro de la nave: la nave hace su propio efecto
	var tw := create_tween()
	for i in 5:
		tw.tween_callback(func(): model.visible = false)
		tw.tween_interval(0.09)
		tw.tween_callback(func(): model.visible = not en_nave)
		tw.tween_interval(0.09)

func _play(anim_name: String) -> void:
	if anim == null:
		return
	if anim_name == "walk" and not anim.has_animation("walk"):
		anim_name = "run"
	if anim.has_animation(anim_name) and anim.current_animation != anim_name:
		anim.play(anim_name)
