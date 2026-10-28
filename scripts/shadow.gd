# Тень: медленно идёт за игроком по навигационной сетке и никогда не останавливается.
# Убить её нельзя, от неё можно только оторваться.
extends CharacterBody3D

signal caught

const SPEED := 1.8
const CATCH_DISTANCE := 1.3

var target: Node3D
var active := false
var paused := false
var slowed := false    # в луче фонарика Тень почти замирает
var waiting := false   # игрок стоит под горящим фонарём: Тень ждёт в темноте
var agent: NavigationAgent3D

var _repath := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	visible = false

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.9
	shape.shape = capsule
	shape.position.y = 0.95
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var cap_mesh := CapsuleMesh.new()
	cap_mesh.radius = 0.32
	cap_mesh.height = 1.95
	mesh.mesh = cap_mesh
	mesh.position.y = 0.97
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.0, 0.0, 0.0)
	mesh.material_override = black
	add_child(mesh)

	agent = NavigationAgent3D.new()
	agent.radius = 0.4
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 0.8
	add_child(agent)


func activate(at: Vector3) -> void:
	global_position = at
	active = true
	visible = true


# Насколько Тень близко: 0 — далеко, 1 — вплотную.
func closeness() -> float:
	if not active or target == null:
		return 0.0
	var d := global_position.distance_to(target.global_position)
	return 1.0 - clampf((d - 2.0) / 18.0, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if not active or paused or waiting or target == null:
		velocity = Vector3.ZERO
		return

	_repath -= delta
	if _repath <= 0.0:
		agent.target_position = target.global_position
		_repath = 0.4

	var to := agent.get_next_path_position() - global_position
	to.y = 0.0
	if to.length() < 0.05:
		to = target.global_position - global_position
		to.y = 0.0
	velocity = to.normalized() * SPEED * (0.3 if slowed else 1.0)
	move_and_slide()
	global_position.y = 0.0
	if to.length() > 0.01:
		rotation.y = atan2(-to.x, -to.z)

	if global_position.distance_to(target.global_position) < CATCH_DISTANCE:
		caught.emit()
