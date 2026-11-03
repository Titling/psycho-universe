# Мир 2 «Кладбище надежд». Всё неподвижное лежит в scenes/world2.tscn.
# Здесь только то, что движется: письма на ветру и часы, которые идут.
extends "res://scripts/worlds/world_base.gd"

var _letters: MultiMeshInstance3D
var _letter_seeds := []
var _ticking: Label3D


func _ready() -> void:
	_letters = get_tree().get_first_node_in_group("wind_letters")
	_ticking = get_tree().get_first_node_in_group("ticking_clock")
	if _letters != null:
		for i in _letters.multimesh.instance_count:
			_letter_seeds.append(Vector4(randf() * 80.0, randf_range(-70, 10), randf() * TAU, randf_range(1.5, 4.0)))
	super._ready()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _letter_seeds.size():
		var s: Vector4 = _letter_seeds[i]
		var x := fposmod(s.x + t * s.w, 80.0) - 40.0
		var pos := Vector3(x, 0.15 + abs(sin(t * 1.3 + s.z)) * 0.9, s.y + sin(t * 0.7 + s.z) * 1.5)
		var basis := Basis(Vector3(1, 0.3, 0.2).normalized(), t * 2.0 + s.z)
		_letters.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	if _ticking != null:
		_ticking.text = "03:17:%02d" % (int(t) % 60)
