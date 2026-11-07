# Звуки квартиры. Настоящий звук берётся из res://sounds/<имя>.ogg (см. sound_files.gd),
# а если файла нет, генерируется при запуске, как в synth.gd.
# Шаги зависят от пола под игроком, холодильник и кран глохнут за закрытой дверью кухни.
extends Node

const RATE := 22050
const SoundFiles := preload("res://scripts/sound_files.gd")
const LOOPED := ["fridge", "water"]
const TILE_AREAS := [Rect2(5, 0, 3, 4), Rect2(0, 4, 2.4, 2)]   # кухня и ванная, остальное дерево
const STEP_VARIANTS := 4
const WALK_STRIDE := 0.72
const SPRINT_STRIDE := 1.05
const SPRINT_FROM := 3.4   # м/с: быстрее этого игрок уже бежит
const FRIDGE_POS := Vector3(5.33, 0.91, 3.35)
const DRIP_POS := Vector3(5.39, 0.92, 1.05)
const MUFFLE_DB := -14.0
const MUFFLE_CUTOFF := 900.0
const OPEN_CUTOFF := 6000.0

static var _cache := {}

var player: CharacterBody3D
var lights: Node   # room_lights.gd: знает, где игрок и какие двери открыты
var dripping := true   # из открытого крана течёт вода, и капель не слышно

var _feet: AudioStreamPlayer
var _click: AudioStreamPlayer
var _drip: AudioStreamPlayer3D
var _drip_wait := 3.0
var _stride := 0.0
var _air_time := 0.0
var _muffled := []   # {sound, room, volume}


func _ready() -> void:
	_feet = AudioStreamPlayer.new()
	add_child(_feet)
	_click = AudioStreamPlayer.new()
	_click.stream = _cached("switch_click", _switch_click)
	_click.volume_db = -6.0
	add_child(_click)
	add_spatial(FRIDGE_POS, fridge(), "Кухня", -12.0).play()
	_drip = add_spatial(DRIP_POS, drip(), "Кухня", -6.0)


# Источник звука в квартире. Если он в комнате, за её закрытой дверью его слышно глуше.
func add_spatial(pos: Vector3, stream: AudioStream, room_name: String, volume := 0.0) -> AudioStreamPlayer3D:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.position = pos
	sound.unit_size = 1.5
	sound.max_distance = 11.0
	sound.volume_db = volume
	add_child(sound)
	_muffled.append({"sound": sound, "room": room_name, "volume": volume})
	return sound


func _process(delta: float) -> void:
	for item in _muffled:
		var heard: bool = lights.is_player_in(item.room) or lights.is_door_open(item.room)
		item.sound.volume_db = item.volume + (0.0 if heard else MUFFLE_DB)
		item.sound.attenuation_filter_cutoff_hz = OPEN_CUTOFF if heard else MUFFLE_CUTOFF
	_drip_wait -= delta
	if _drip_wait <= 0.0 and dripping:
		_drip_wait = randf_range(2.0, 6.5)
		_drip.pitch_scale = randf_range(0.9, 1.15)
		_drip.play()


func _physics_process(delta: float) -> void:
	if not player.is_on_floor():
		_air_time += delta
		return
	if _air_time > 0.2 and not player.locked:
		_step(-2.0)
	_air_time = 0.0
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if speed < 0.3:
		_stride = 0.0
		return
	var stride := SPRINT_STRIDE if speed > SPRINT_FROM else WALK_STRIDE
	_stride += speed * delta
	if _stride >= stride:
		_stride -= stride
		var volume := -14.0 if player.crouching else (-3.0 if speed > SPRINT_FROM else -7.0)
		_step(volume)


func click() -> void:
	_click.play()


func _step(volume: float) -> void:
	var p := player.global_position
	var tile := false
	for area in TILE_AREAS:
		tile = tile or area.has_point(Vector2(p.x, p.z))
	_feet.stream = step(tile, randi() % STEP_VARIANTS)
	_feet.pitch_scale = randf_range(0.92, 1.08)
	_feet.volume_db = volume
	_feet.play()


static func step(tile: bool, variant: int) -> AudioStream:
	var key := "step_%s_%d" % ["tile" if tile else "wood", variant]
	if key not in _cache:
		var file := SoundFiles.find(key)
		_cache[key] = file if file != null else (_tile_step() if tile else _wood_step())
	return _cache[key]


static func fridge() -> AudioStream:
	return _cached("fridge", _fridge)


static func water() -> AudioStream:
	return _cached("water", _water)


static func drip() -> AudioStream:
	return _cached("drip", _drip_sound)


static func creak() -> AudioStream:
	return _cached("creak", _creak)


static func door_thud() -> AudioStream:
	return _cached("door_thud", _door_thud)


static func clock_tick() -> AudioStream:
	return _cached("clock_tick", _clock_tick)


static func _cached(key: String, build: Callable) -> AudioStream:
	if key not in _cache:
		var file := SoundFiles.find(key, key in LOOPED)
		_cache[key] = file if file != null else build.call()
	return _cache[key]


static func _wood_step() -> AudioStream:
	var samples := _empty(0.16)
	var freq := randf_range(85.0, 115.0)
	var noise := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.15)
		samples[i] = sin(t * TAU * freq) * exp(-t * 38.0) * 0.9 + noise * exp(-t * 60.0) * 0.5
	return _wav(samples)


static func _tile_step() -> AudioStream:
	var samples := _empty(0.09)
	var freq := randf_range(560.0, 700.0)
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.45 \
				+ sin(t * TAU * freq) * exp(-t * 70.0) * 0.25 \
				+ sin(t * TAU * 140.0) * exp(-t * 50.0) * 0.4
	return _wav(samples)


# Гудение с целым числом периодов за 2 с, поэтому склейка петли не щёлкает.
static func _fridge() -> AudioStream:
	var samples := _empty(2.0)
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = sin(t * TAU * 50.0) * 0.3 + sin(t * TAU * 100.0) * 0.3 \
				+ sin(t * TAU * 150.0) * 0.1 + sin(t * TAU * 200.0) * 0.06
	return _wav(samples, true)


static func _drip_sound() -> AudioStream:
	var samples := _empty(0.22)
	var phase := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		phase = fmod(phase + lerpf(700.0, 1500.0, minf(t * 12.0, 1.0)) / RATE, 1.0)
		samples[i] = sin(phase * TAU) * exp(-t * 26.0) * 0.6
	return _wav(samples)


# Скрип: петля то цепляется, то проскальзывает, и каждый рывок звенит на резонансе дерева.
static func _creak() -> AudioStream:
	var samples := _empty(0.7)
	var phase := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var r := 0.97
	var w := TAU * 850.0 / RATE
	for i in samples.size():
		var t := float(i) / RATE
		phase += (70.0 + 35.0 * sin(t * 9.0) + 25.0 * sin(t * 23.0)) / RATE
		var pulse := 0.0
		if phase >= 1.0:
			phase -= 1.0
			pulse = randf_range(0.6, 1.0)
		var y := 2.0 * r * cos(w) * y1 - r * r * y2 + pulse
		y2 = y1
		y1 = y
		samples[i] = y * sqrt(sin(PI * t / 0.7))
	return _wav(_normalized(samples, 0.5))


static func _door_thud() -> AudioStream:
	var samples := _empty(0.25)
	var noise := 0.0
	for i in samples.size():
		var t := float(i) / RATE
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.2)
		samples[i] = sin(t * TAU * 70.0) * exp(-t * 22.0) * 0.8 + noise * exp(-t * 60.0) * 0.5
	return _wav(samples)


static func _clock_tick() -> AudioStream:
	var samples := _empty(0.025)
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = randf_range(-1.0, 1.0) * exp(-t * 300.0) * 0.4 + sin(t * TAU * 2400.0) * exp(-t * 400.0) * 0.3
	return _wav(samples)


# Шум воды: сглаженный шум, по краям петли плавно сведён, чтобы склейка не щёлкала.
static func _water() -> AudioStream:
	var samples := _empty(2.0)
	var noise := 0.0
	var count := samples.size()
	for i in count:
		noise = lerpf(noise, randf_range(-1.0, 1.0), 0.35)
		var edge := minf(minf(i, count - i) / 400.0, 1.0)
		samples[i] = noise * 0.9 * edge
	return _wav(samples, true)


static func _switch_click() -> AudioStream:
	var samples := _empty(0.04)
	for i in samples.size():
		var t := float(i) / RATE
		samples[i] = randf_range(-1.0, 1.0) * exp(-t * 220.0) * 0.5 + sin(t * TAU * 1100.0) * exp(-t * 180.0) * 0.4
	return _wav(samples)


static func _empty(seconds: float) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(int(seconds * RATE))
	return samples


static func _normalized(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top := 0.001
	for s in samples:
		top = maxf(top, absf(s))
	for i in samples.size():
		samples[i] *= peak / top
	return samples


static func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
