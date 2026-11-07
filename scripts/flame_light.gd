# Свет живого огня: неровно дышит и чуть смещается, поэтому тени на стенах шевелятся.
extends OmniLight3D

var _base := -1.0
var _applied := -1.0
var _origin: Vector3
var _phase := 0.0


func _ready() -> void:
	_origin = position
	_phase = randf() * 100.0


func _process(_delta: float) -> void:
	# если кто-то задал новую яркость снаружи, она становится основной
	if not is_equal_approx(light_energy, _applied):
		_base = light_energy
	var t := Time.get_ticks_msec() / 1000.0 + _phase
	var flicker := 0.86 + 0.09 * sin(t * 7.3) + 0.05 * sin(t * 17.1) + 0.04 * sin(t * 2.1)
	_applied = _base * flicker
	light_energy = _applied
	position = _origin + Vector3(sin(t * 5.1), sin(t * 6.7), sin(t * 4.3)) * 0.025
