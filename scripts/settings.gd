# Настройки игрока: звук, яркость, мышь, полный экран. Хранятся в user://settings.cfg.
extends RefCounted

const PATH := "user://settings.cfg"
const QUALITY_NAMES := ["среднее", "высокое"]
const BASE_SIZE := Vector2i(1280, 720)

static var volume := 0.8
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
		brightness = cfg.get_value("game", "brightness", brightness)
		sensitivity = cfg.get_value("game", "sensitivity", sensitivity)
		fullscreen = cfg.get_value("game", "fullscreen", fullscreen)
		show_fps = cfg.get_value("game", "show_fps", show_fps)
		quality = cfg.get_value("game", "quality", quality)
		vsync = cfg.get_value("game", "vsync", vsync)
	apply()


static func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
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
	cfg.set_value("game", "brightness", brightness)
	cfg.set_value("game", "sensitivity", sensitivity)
	cfg.set_value("game", "fullscreen", fullscreen)
	cfg.set_value("game", "show_fps", show_fps)
	cfg.set_value("game", "quality", quality)
	cfg.set_value("game", "vsync", vsync)
	cfg.save(PATH)
