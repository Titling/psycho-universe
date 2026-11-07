# Межкомнатная дверь. Сама створка лежит в сцене, узел стоит на петле.
# Скрипт при запуске добавляет зону для E и поворачивает дверь на open_degrees.
extends Node3D

const InteractableScript := preload("res://scripts/interactable.gd")
const SoundsScript := preload("res://scripts/apartment_sounds.gd")

@export var open_degrees := 100.0
@export var leaf_width := 0.78

var _closed_yaw := 0.0
var is_open := false
var fully_closed := true   # створка дошла до косяка: пока она закрывается, в щель ещё видно комнату
var _area: Area3D
var _tween: Tween
var _sound: AudioStreamPlayer3D


func _ready() -> void:
	_closed_yaw = rotation.y
	_area = InteractableScript.new()
	_area.setup(Vector3(leaf_width, 2.03, 0.2), "Открыть дверь")
	_area.position = Vector3(leaf_width / 2.0, 1.02, 0.0)
	_area.used.connect(toggle)
	add_child(_area)
	_sound = AudioStreamPlayer3D.new()
	_sound.position = _area.position
	_sound.unit_size = 2.5
	_sound.max_distance = 12.0
	add_child(_sound)


func toggle() -> void:
	is_open = not is_open
	fully_closed = false
	_area.prompt = "Закрыть дверь" if is_open else "Открыть дверь"
	_play(SoundsScript.creak())
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var target := _closed_yaw + deg_to_rad(open_degrees) if is_open else _closed_yaw
	_tween.tween_property(self, "rotation:y", target, 0.7)
	_tween.tween_callback(_finish_move)


# Дверь сама приоткрылась: слышен тихий скрип. Для игрока она всё ещё закрыта,
# поэтому E открывает её дальше, а свет комнаты уже горит, как при открытой двери.
func set_ajar(degrees: float) -> void:
	fully_closed = false
	_play(SoundsScript.creak(), -10.0)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "rotation:y", _closed_yaw + deg_to_rad(degrees), 0.7)


# Дверь движется сама: закрытая приоткрывается, а открытая или приоткрытая закрывается.
func drift(ajar_degrees: float) -> void:
	if fully_closed:
		set_ajar(ajar_degrees)
		return
	is_open = false
	_area.prompt = "Открыть дверь"
	_play(SoundsScript.creak(), -10.0)
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "rotation:y", _closed_yaw, 1.2)
	_tween.tween_callback(_finish_move)


func _finish_move() -> void:
	fully_closed = not is_open
	if fully_closed:
		_play(SoundsScript.door_thud())


func _play(stream: AudioStream, volume := 0.0) -> void:
	_sound.stream = stream
	_sound.volume_db = volume
	_sound.play()
