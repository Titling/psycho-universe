# Игрок: вид от первого лица, ходьба, бег, луч для взаимодействия.
extends CharacterBody3D

signal prompt_changed(text: String)

const WALK_SPEED := 2.6
const SPRINT_SPEED := 4.6
const MOUSE_SENS := 0.0025
const EYE_HEIGHT := 1.65

var camera: Camera3D
var ray: RayCast3D
var locked := false

var _bob := 0.0
var _target: Node = null


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	camera = Camera3D.new()
	camera.position.y = EYE_HEIGHT
	camera.fov = 70.0
	camera.near = 0.05
	camera.far = 70.0
	add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.2)
	ray.collide_with_areas = true
	ray.collision_mask = 1 | 2
	camera.add_child(ray)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not locked:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * MOUSE_SENS, -1.4, 1.4)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("interact") and not locked and _target != null:
		_target.use()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	var input := Vector2.ZERO
	if not locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = move_toward(velocity.x, dir.x * speed, 20.0 * delta)
	velocity.z = move_toward(velocity.z, dir.z * speed, 20.0 * delta)
	move_and_slide()

	# Покачивание камеры при ходьбе.
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if horizontal > 0.1:
		_bob += delta * horizontal * 2.2
	camera.position.y = EYE_HEIGHT + sin(_bob) * 0.04 * minf(horizontal / WALK_SPEED, 1.5)

	_update_target()


func _update_target() -> void:
	var found: Node = null
	if not locked and ray.is_colliding():
		var hit := ray.get_collider()
		if hit != null and hit.has_method("use") and hit.enabled:
			found = hit
	if found != _target:
		_target = found
		prompt_changed.emit("[E] " + found.prompt if found else "")


# Плавно развернуть игрока лицом к точке (для сценок).
func face_point(point: Vector3, time := 0.6) -> void:
	var to := point - global_position
	var target_yaw := atan2(-to.x, -to.z)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "rotation:y", rotation.y + wrapf(target_yaw - rotation.y, -PI, PI), time)
	tween.tween_property(camera, "rotation:x", 0.0, time)
	await tween.finished
