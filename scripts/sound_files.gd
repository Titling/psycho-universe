# Звуки из файлов. Если в res://sounds/ лежит файл с нужным именем (.ogg или .wav),
# игра берёт его вместо звука, который synth.gd и apartment_sounds.gd генерируют в коде.
# Если файла нет, остаётся сгенерированная заглушка, так что игра звучит в любом случае.
# Откуда взят каждый файл и под какой он лицензией, записано в sounds/CREDITS.md.
extends RefCounted

const DIR := "res://sounds/"
const EXTENSIONS := ["ogg", "wav"]

static var _cache := {}


# Звук по имени без расширения, например "step_wood_0" или "synth/ring". null, если файла нет.
static func find(sound_name: String, loop := false) -> AudioStream:
	var key := "%s|%s" % [sound_name, loop]
	if key in _cache:
		return _cache[key]
	var stream: AudioStream = null
	for ext in EXTENSIONS:
		var path := "%s%s.%s" % [DIR, sound_name, ext]
		if ResourceLoader.exists(path):
			stream = load(path)
			break
	if stream != null and loop:
		stream = stream.duplicate()
		_set_loop(stream)
	_cache[key] = stream
	return stream


static func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis or stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		var frame_bytes := (2 if wav.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if wav.stereo else 1)
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / frame_bytes
