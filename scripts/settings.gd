# Настройки игрока: звук, яркость, мышь, полный экран. Хранятся в user://settings.cfg.
#
# Звук разложен по двум шинам: «Music» и «SFX», обе идут в общую Master («Громкость»).
# Любой проигрыватель звука (обычный, 2D или 3D), который появляется в игре на шине Master,
# сам уходит на SFX, а если его узел в группе «music», то на Music. Так новые звуки и музыка
# подчиняются ползункам без правок в коде: для музыки достаточно player.add_to_group("music")
# до add_child. Фоновый гул из synth.gd (режим "ambient") считается музыкой.
extends RefCounted

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["среднее", "высокое"]
const BASE_SIZE := Vector2i(1280, 720)
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const MUSIC_GROUP := &"music"

static var volume := 0.8
static var music_volume := 0.8
static var sfx_volume := 0.8
static var brightness := 1.0
static var sensitivity := 1.0
static var fullscreen := false
static var show_fps := false
static var quality := 0
static var vsync := true
static var _loaded := false


static func load_once() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		volume = cfg.get_value("game", "volume", volume)
		music_volume = cfg.get_value("game", "music_volume", music_volume)
		sfx_volume = cfg.get_value("game", "sfx_volume", sfx_volume)
		brightness = cfg.get_value("game", "brightness", brightness)
		sensitivity = cfg.get_value("game", "sensitivity", sensitivity)
		fullscreen = cfg.get_value("game", "fullscreen", fullscreen)
		show_fps = cfg.get_value("game", "show_fps", show_fps)
		quality = cfg.get_value("game", "quality", quality)
		vsync = cfg.get_value("game", "vsync", vsync)
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	(Engine.get_main_loop() as SceneTree).node_added.connect(_route_audio)
	apply()


static func apply() -> void:
	_set_bus_volume(&"Master", volume)
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)
	var mode := DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_apply_quality()


# На весь экран пикселей в разы больше, чем в окне 1280×720, и FPS падает примерно настолько же.
# Поэтому картинка считается в меньшем размере и растягивается на экран.
# Высокое качество считает каждый пиксель экрана.
static func _apply_quality() -> void:
	var window: Window = (Engine.get_main_loop() as SceneTree).root
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = BASE_SIZE
	if quality >= 1:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	else:
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT


static func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "volume", volume)
	cfg.set_value("game", "music_volume", music_volume)
	cfg.set_value("game", "sfx_volume", sfx_volume)
	cfg.set_value("game", "brightness", brightness)
	cfg.set_value("game", "sensitivity", sensitivity)
	cfg.set_value("game", "fullscreen", fullscreen)
	cfg.set_value("game", "show_fps", show_fps)
	cfg.set_value("game", "quality", quality)
	cfg.set_value("game", "vsync", vsync)
	cfg.save(PATH)


static func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, &"Master")


static func _set_bus_volume(bus_name: StringName, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_mute(idx, value <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.001)))


# Новый звук в игре: музыку на шину Music, всё остальное на SFX.
static func _route_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D:
		if node.bus == &"Master":
			node.bus = MUSIC_BUS if node.is_in_group(MUSIC_GROUP) else SFX_BUS


# Перевести уже играющий звук в музыку или обратно (например, synth.gd при смене режима).
static func route_as_music(player: Node, is_music: bool) -> void:
	player.bus = MUSIC_BUS if is_music else SFX_BUS
