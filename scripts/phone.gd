# Брошенный телефон, который сам звонит.
extends Node3D

signal answered

var ringing := false:
	set(value):
		ringing = value
		if is_inside_tree():
			_sound.set_mode("ring" if value else "")
			area.enabled = value

var area
var _screen: MeshInstance3D
var _sound
var _blink := 0.0


func _ready() -> void:
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.08, 0.015, 0.16)
	body.mesh = box
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.05, 0.06)
	body.material_override = dark
	add_child(body)

	_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.065, 0.13)
	_screen.mesh = quad
	_screen.rotation.x = -PI / 2
	_screen.position.y = 0.009
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.6, 0.8, 1.0)
	_screen.material_override = glow
	add_child(_screen)

	area = preload("res://scripts/interactable.gd").new()
	area.setup(Vector3(0.6, 0.6, 0.6), "Взять трубку")
	area.used.connect(func(): answered.emit())
	add_child(area)

	_sound = preload("res://scripts/synth.gd").new()
	_sound.unit_size = 4.0
	_sound.max_distance = 40.0
	add_child(_sound)

	ringing = ringing


func _process(delta: float) -> void:
	_blink += delta
	_screen.visible = ringing and fmod(_blink, 0.6) < 0.4
