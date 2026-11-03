# Настройки игрока: громкость музыки и эффектов, чувствительность мыши.
# Подключён как автозагрузка «Settings» (project.godot), поэтому работает во всех сценах.
# Значения хранятся в user://settings.cfg и переживают перезапуск игры.
#
# Звук разложен по двум шинам: «Music» и «SFX». Любой AudioStreamPlayer
# (обычный, 2D или 3D), который появляется в игре на шине Master, сам уходит на SFX,
# а если узел добавлен в группу «music», то на Music. Так новые звуки и музыка
# подчиняются ползункам без правок в коде, достаточно для музыки сделать
# player.add_to_group("music") до add_child.
extends Node

signal changed

const PATH := "user://settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"
const MUSIC_GROUP := "music"

# 0..1, линейная громкость (как на ползунке).
var music_volume := 0.8
var sfx_volume := 0.8
# Множитель к базовой чувствительности мыши: 1.0 — как было в прототипе.
var mouse_sensitivity := 1.0

var _menu: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	load_settings()
	apply()
	get_tree().node_added.connect(_on_node_added)

	_menu = preload("res://scripts/settings_menu.gd").new()
	add_child(_menu)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")


func _on_node_added(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node.bus == &"Master":
			node.bus = MUSIC_BUS if node.is_in_group(MUSIC_GROUP) else SFX_BUS


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply()


func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.1, 3.0)
	changed.emit()


func apply() -> void:
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)
	changed.emit()


func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, value <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.001)))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_volume = clampf(float(cfg.get_value("audio", "music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	mouse_sensitivity = clampf(float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity)), 0.1, 3.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.save(PATH)
