# Звуки без файлов: генерируются прямо в коде.
# mode: "ring" — звонок телефона, "beep" — пришло SMS, "drone" — гул Тени, "" — тишина.
extends AudioStreamPlayer3D

const RATE := 22050.0

var mode := ""
var level := 1.0

var _playback: AudioStreamGeneratorPlayback
var _t := 0.0
var _phase := 0.0
var _noise := 0.0


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	stream = gen
	play()
	_playback = get_stream_playback()


func set_mode(new_mode: String) -> void:
	mode = new_mode
	_t = 0.0


func _process(_delta: float) -> void:
	if _playback == null or mode == "":
		return
	for i in _playback.get_frames_available():
		var s := _sample()
		_playback.push_frame(Vector2(s, s))
		_t += 1.0 / RATE


func _sample() -> float:
	match mode:
		"ring":
			var t := fmod(_t, 3.0)
			if t > 1.2:
				return 0.0
			var freq := 1300.0 if fmod(t, 0.08) < 0.04 else 1600.0
			_phase = fmod(_phase + freq / RATE, 1.0)
			return (0.25 if _phase < 0.5 else -0.25) * level
		"beep":
			if _t > 0.5:
				mode = ""
				return 0.0
			if _t < 0.12 or (_t > 0.2 and _t < 0.32):
				_phase = fmod(_phase + 1800.0 / RATE, 1.0)
				return sin(_phase * TAU) * 0.3
			return 0.0
		"drone":
			_phase = fmod(_phase + 47.0 / RATE, 1.0)
			_noise = lerpf(_noise, randf() * 2.0 - 1.0, 0.05)
			return (sin(_phase * TAU) * 0.5 + _noise * 0.5) * 0.6 * level
	return 0.0
