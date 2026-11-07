# Звуки без файлов: генерируются прямо в коде.
# mode: "ring" — звонок телефона, "beep" — пришло SMS, "drone" — гул Тени,
# "ambient" — мрачный фон меню и уровней, "tick" — шорох кнопки меню, "" — тишина.
extends AudioStreamPlayer3D

const RATE := 22050.0
const Settings := preload("res://scripts/settings.gd")

var mode := ""
var level := 1.0

var _playback: AudioStreamGeneratorPlayback
var _t := 0.0
var _phase := 0.0
var _noise := 0.0

# Генераторы живут до конца игры. Аудиопоток Godot 4.3 держит на генератор голый указатель
# и может ещё раз смешать звук после того, как плеер удалён вместе со сценой. Если генератор
# к этому моменту освобождён, игра падает (так было при выходе из квартиры в Мир 1).
static var _keep_alive: Array[AudioStreamGenerator] = []


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.15
	_keep_alive.append(gen)
	stream = gen
	play()
	_playback = get_stream_playback()


# Плеер уходит из дерева: перестаём кормить звук до того, как сцену удалят.
func _exit_tree() -> void:
	_playback = null
	stop()


# Если плеер просто переставили к другому родителю, звук включается снова.
func _enter_tree() -> void:
	if is_node_ready() and _playback == null:
		play()
		_playback = get_stream_playback()


func set_mode(new_mode: String) -> void:
	mode = new_mode
	# Фоновый гул — это музыка игры, остальное (звонок, SMS, гул Тени, шорох) — эффекты.
	Settings.route_as_music(self, mode == "ambient")
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
		"ambient":
			# ветер в коридорах и низкий тревожный аккорд, который то нарастает, то уходит
			_noise = lerpf(_noise, randf() * 2.0 - 1.0, 0.02 + 0.015 * sin(_t * 0.23))
			var wind := _noise * (0.55 + 0.45 * sin(_t * 0.31 + sin(_t * 0.11) * 2.0))
			var swell := 0.5 + 0.5 * sin(_t * 0.17)
			var chord := sin(_t * TAU * 55.0) + sin(_t * TAU * 58.3) * 0.7 + sin(_t * TAU * 82.4) * 0.45 * swell + sin(_t * TAU * 116.5) * 0.18 * swell
			return (wind * 0.75 + chord * 0.1) * 0.8 * level
		"tick":
			if _t > 0.07:
				mode = ""
				return 0.0
			_phase = fmod(_phase + 180.0 / RATE, 1.0)
			return (sin(_phase * TAU) * 0.5 + randf_range(-0.2, 0.2)) * (1.0 - _t / 0.07) * 0.3
	return 0.0
