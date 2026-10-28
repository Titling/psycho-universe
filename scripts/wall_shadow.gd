# Застывшая тень на стене. Когда игрок не смотрит, она меняет позу и место,
# а иногда перебегает прямо у него на глазах.
extends MeshInstance3D

var watcher: Camera3D
var tangent := Vector3.RIGHT

var _anchor: Vector3
var _timer := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	_anchor = position
	_timer = randf_range(2.0, 6.0)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 2.0)
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/silhouette.gdshader")
	_material.set_shader_parameter("pose", randf())
	_material.set_shader_parameter("lean", randf_range(-1.0, 1.0))
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or watcher == null:
		return
	_timer = randf_range(2.0, 6.0)

	var to := global_position - watcher.global_position
	var distance := to.length()
	var looking := (-watcher.global_basis.z).dot(to.normalized()) > 0.5
	var target := _anchor + tangent * randf_range(-5.0, 5.0)

	if not looking:
		position = target
		_material.set_shader_parameter("pose", randf())
		_material.set_shader_parameter("lean", randf_range(-1.0, 1.0))
	elif distance > 10.0 and randf() < 0.3:
		create_tween().tween_property(self, "position", target, 0.35)
