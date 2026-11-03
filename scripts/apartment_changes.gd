# Меняющаяся квартира: пока игрок не смотрит, что-то в ней становится не так.
# Двери двигаются сами снова и снова, остальные подмены срабатывают по одному разу.
# Часы сначала стоят на 03:17, как в прологе, а одна из подмен запускает их.
# Чем сильнее героя накрыло, тем чаще всё меняется.
extends Node

const SoundsScript := preload("res://scripts/apartment_sounds.gd")

const FIRST_CHANGE := 40.0   # с после того, как игрок получил управление
const MIN_GAP := 20.0
const MAX_GAP := 45.0
const RETRY := 1.0           # всё на виду: попробовать чуть позже
const MIN_DISTANCE := 1.5    # ближе игрок заметит или попадёт под дверь
const VIEW_MARGIN := 0.3     # проверяем и края предмета, а не только его центр
const DOOR_AJAR_DEGREES := 14.0
const FRIDGE_AJAR_DEGREES := 20.0
const DOOR_PATHS := ["Двери/Комната/Дверь", "Двери/Кухня/Дверь", "Двери/Ванная/Дверь"]

var player: CharacterBody3D
var sounds: Node
var root: Node
var fixtures: Node
var lights: Node
var switch_positions := {}   # комната света: где её выключатель
var sanity := 0.0

var _clock_running := false
var _changes := []   # {at: Vector3, apply: Callable}
var _wait := FIRST_CHANGE
var _tick_wait := 1.0
var _second_hand: Node3D
var _minute_hand: Node3D
var _hour_hand: Node3D
var _clock_sound: AudioStreamPlayer3D


func _ready() -> void:
	var clock: Node3D = root.get_node("Комната/Декор/Часы")
	_second_hand = clock.find_child("wall_clock_second_hand", true, false)
	_minute_hand = clock.find_child("wall_clock_minute_hand", true, false)
	_hour_hand = clock.find_child("wall_clock_hours_hand", true, false)
	_clock_sound = sounds.add_spatial(clock.global_position, SoundsScript.clock_tick(), "Комната", -8.0)

	_add_mug_change("Комната/Следы_жизни/Кружка", Vector3(0.08, 0, -0.11), 2.1)
	_add_mug_change("Кухня/Следы_жизни/Кружка_на_столе", Vector3(-0.1, 0, -0.14), -1.7)
	_add_chair_change()
	_add_door_changes()
	_add_monitor_change()
	_changes.append({"at": clock.global_position, "apply": func(): _clock_running = true})
	_changes.append({"at": fixtures.SPOUT, "apply": func(): fixtures.set_water(true)})
	_changes.append({"at": fixtures.FRIDGE_LIGHT_POS, "apply": func(): fixtures.set_fridge(true, FRIDGE_AJAR_DEGREES)})
	for room_name in switch_positions:
		_changes.append({"at": switch_positions[room_name], "apply": func():
			lights.toggle_switch(room_name)
			sounds.click()})


func _process(delta: float) -> void:
	_tick_wait -= delta
	if _tick_wait <= 0.0:
		_tick_wait += 1.0
		if _clock_running:
			_tick_clock()
	if player.locked or _changes.is_empty():
		return
	_wait -= delta * (1.0 + 2.0 * sanity)
	if _wait > 0.0:
		return
	_wait = RETRY
	_changes.shuffle()
	for change in _changes:
		if _is_unseen(change.at):
			if not change.get("repeat", false):
				_changes.erase(change)
			change.apply.call()
			_wait = randf_range(MIN_GAP, MAX_GAP)
			return


func _is_unseen(at: Vector3) -> bool:
	if player.global_position.distance_to(at) < MIN_DISTANCE:
		return false
	var camera: Camera3D = player.camera
	for offset in [Vector3.ZERO, Vector3(VIEW_MARGIN, 0, 0), Vector3(-VIEW_MARGIN, 0, 0), Vector3(0, 0, VIEW_MARGIN), Vector3(0, 0, -VIEW_MARGIN)]:
		if camera.is_position_in_frustum(at + offset):
			return false
	return true


# Кружка сдвигается, только если игрок её не трогал.
func _add_mug_change(path: String, shift: Vector3, turn: float) -> void:
	var mug: RigidBody3D = root.get_node(path)
	_changes.append({"at": mug.global_position, "apply": func():
		if not mug.touched:
			mug.global_position += shift
			mug.rotate_y(turn)})


# Стул отодвигается от стола, будто на нём кто-то сидел.
func _add_chair_change() -> void:
	var chair: RigidBody3D = root.get_node("Комната/Стул")
	_changes.append({"at": chair.global_position, "apply": func():
		if not chair.touched:
			chair.global_position += Vector3(-0.3, 0, 0.3)
			chair.rotate_y(0.6)})


func _add_door_changes() -> void:
	for path in DOOR_PATHS:
		var door: Node3D = root.get_node(path)
		_changes.append({"at": door.global_position, "repeat": true, "apply": func(): door.drift(DOOR_AJAR_DEGREES)})


func _add_monitor_change() -> void:
	var screen: MeshInstance3D = root.get_node("Комната/Стол/Экран")
	_changes.append({"at": screen.global_position, "apply": func(): _break_monitor(screen)})


# Рабочий стол пропадает: чёрный экран и один мигающий курсор в углу.
func _break_monitor(screen: MeshInstance3D) -> void:
	var image := Image.create(160, 90, false, Image.FORMAT_RGB8)
	image.fill_rect(Rect2i(6, 6, 4, 7), Color.WHITE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	screen.material_override = material
	var blink := screen.create_tween().set_loops()
	blink.tween_callback(func(): material.albedo_color = Color.BLACK).set_delay(0.55)
	blink.tween_callback(func(): material.albedo_color = Color.WHITE).set_delay(0.55)


func _tick_clock() -> void:
	# Циферблат смотрит вдоль +Z модели, по часовой стрелке значит вокруг Z в минус.
	_second_hand.rotate_z(-TAU / 60.0)
	_minute_hand.rotate_z(-TAU / 3600.0)
	_hour_hand.rotate_z(-TAU / 43200.0)
	_clock_sound.play()
