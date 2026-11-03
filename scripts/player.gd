# Игрок: вид от первого лица, ходьба, бег, луч для взаимодействия.
extends CharacterBody3D

signal prompt_changed(text: String)

const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.6
const CROUCH_SPEED := 1.4
const JUMP_VELOCITY := 3.6   # высота прыжка около 65 см
const MOUSE_SENS := 0.0025
const EYE_HEIGHT := 1.65
const CROUCH_EYE_HEIGHT := 0.95
const LYING_EYE_HEIGHT := 0.2
const LYING_ROLL := 0.9
const EYE_SPEED := 3.0
const SANITY_SLOWDOWN := 0.15   # при полной потере рассудка игрок идёт настолько медленнее
const PUSH_FORCE := 0.3         # как сильно игрок толкает мебель на ходу
const PROP_LAYER := 16
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.1
const BASE_FOV := 70.0
const Settings := preload("res://scripts/settings.gd")

var camera: Camera3D
var ray: RayCast3D
var locked := false
var sanity := 0.0   # 1 — героя накрыло: взгляд плывёт и заваливается
var lying := false
var carrying := false   # в руках предмет: E кладёт его, а не нажимает то, на что смотрит герой
var eye_roll := 0.0

var crouching := false

var _bob := 0.0
var _eye := EYE_HEIGHT
var _eye_speed := EYE_SPEED
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D
var _target: Node = null


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	_shape = CollisionShape3D.new()
	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.28   # проходит в межкомнатные двери
	_capsule.height = STAND_HEIGHT
	_shape.shape = _capsule
	_shape.position.y = STAND_HEIGHT / 2.0
	add_child(_shape)

	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = BASE_FOV
	camera.near = 0.05
	camera.far = 70.0
	add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.2)
	ray.collide_with_areas = true
	ray.collision_mask = 1 | 2 | PROP_LAYER
	camera.add_child(ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not locked:
		var sens := MOUSE_SENS * Settings.sensitivity
		rotate_y(-event.relative.x * sens)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * sens, -1.4, 1.4)
	elif event.is_action_pressed("crouch") and not locked:
		toggle_crouch()
	elif event.is_action_pressed("interact") and not locked and _target != null:
		_target.use()
		# Открыть сменилось на Закрыть: подсказка обновляется сразу.
		if _target != null and _target.enabled:
			prompt_changed.emit("[E] " + _target.prompt)


# Присесть или встать. Встать нельзя, если над головой что-то мешает.
func toggle_crouch() -> void:
	if crouching and test_move(global_transform, Vector3.UP * (STAND_HEIGHT - CROUCH_HEIGHT)):
		return
	crouching = not crouching
	var height := CROUCH_HEIGHT if crouching else STAND_HEIGHT
	_capsule.height = height
	_shape.position.y = height / 2.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	elif Input.is_action_just_pressed("jump") and not locked and not crouching:
		velocity.y = JUMP_VELOCITY

	var input := Vector2.ZERO
	if not locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	speed *= 1.0 - SANITY_SLOWDOWN * sanity
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	move_and_slide()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var other := collision.get_collider()
		# Толкает сила шага: скорость при упоре в предмет почти гаснет.
		if other != null and other.has_method("push") and dir != Vector3.ZERO:
			other.push(-collision.get_normal() * PUSH_FORCE * speed)

	# Покачивание камеры при ходьбе.
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 0.1:
		_bob += delta * horizontal * 2.2
	var eye_target := CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
	_eye = move_toward(_eye, LYING_EYE_HEIGHT if lying else eye_target, _eye_speed * delta)
	camera.position.y = _eye + sin(_bob) * 0.04 * minf(horizontal / WALK_SPEED, 1.5)

	var t := Time.get_ticks_msec() / 1000.0
	camera.fov = BASE_FOV + sin(t * 1.7) * 4.0 * sanity
	camera.rotation.z = sin(t * 0.9) * 0.05 * sanity + eye_roll

	_update_target()


func _update_target() -> void:
	var found: Node = null
	if not locked and not carrying and ray.is_colliding():
		var hit := ray.get_collider()
		if hit != null and hit.has_method("use") and hit.enabled:
			found = hit
	if found != _target:
		_target = found
		prompt_changed.emit("[E] " + found.prompt if found else "")


# Герой лежит на боку и смотрит на точку на полу.
func lie_down(point: Vector3) -> void:
	lying = true
	_eye = LYING_EYE_HEIGHT
	eye_roll = LYING_ROLL
	camera.rotation.x = -0.3
	var to := point - global_position
	rotation.y = atan2(-to.x, -to.z)


func get_up(time := 2.0) -> void:
	lying = false
	_eye_speed = (EYE_HEIGHT - LYING_EYE_HEIGHT) / time
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "eye_roll", 0.0, time)
	tween.tween_property(camera, "rotation:x", 0.0, time)
	await tween.finished
	_eye_speed = EYE_SPEED


# Плавно развернуть игрока лицом к точке (для сценок).
func face_point(point: Vector3, time := 0.6) -> void:
	var to := point - global_position
	var target_yaw := atan2(-to.x, -to.z)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "rotation:y", rotation.y + wrapf(target_yaw - rotation.y, -PI, PI), time)
	tween.tween_property(camera, "rotation:x", 0.0, time)
	await tween.finished
