# Главное меню: живой тёмный зал за текстом. Свечи дышат, пыль висит в лунном луче,
# камера едва заметно покачивается. Берёт материалы и свет из main.gd.
extends "res://scripts/sketches/sketch_base.gd"

const Style := preload("res://scripts/style.gd")
const FpsLabel := preload("res://scripts/fps_label.gd")
const SHAFT_SHADER := preload("res://shaders/light_shaft.gdshader")
const GAME_SCENE := "res://scenes/apartment.tscn"
const CAMERA_POS := Vector3(0, 1.75, 7.2)

var _camera: Camera3D
var _music
var _tick
var _fade: ColorRect
var _logo: Label
var _echo: Label
var _pages := {}
var _leaving := false


func _ready() -> void:
	_setup_sketch()
	environment.background_color = Color(0.01, 0.012, 0.018)
	environment.fog_light_color = Color(0.02, 0.026, 0.038)
	environment.fog_density = 0.05
	environment.ambient_light_color = Color(0.24, 0.3, 0.42)
	environment.ambient_light_energy = 0.34
	film_material.set_shader_parameter("vignette", 1.0)

	_build_stage()
	_camera = Camera3D.new()
	_camera.position = CAMERA_POS
	_camera.fov = 58.0
	_camera.far = 60.0
	add_child(_camera)
	_camera.add_child(_dust(30, Vector3(7, 3, 9)))

	_music = SynthScript.new()
	_music.set_mode("ambient")
	_camera.add_child(_music)
	_tick = SynthScript.new()
	_camera.add_child(_tick)

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	add_child(preload("res://scripts/soft_cursor.gd").new())
	_build_interface()

	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 3.0).set_delay(0.3)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	_camera.position = CAMERA_POS + Vector3(sin(t * 0.13) * 0.28, sin(t * 0.21) * 0.07, sin(t * 0.09) * 0.2)
	_camera.rotation = Vector3(0.03 + sin(t * 0.17) * 0.008, sin(t * 0.11) * 0.022, sin(t * 0.07) * 0.006)
	# Призрак логотипа: едва видимое эхо, которое отстаёт и дрожит.
	_echo.position = _logo.position + Vector2(sin(t * 0.7) * 5.0, cos(t * 0.53) * 3.0)
	_echo.modulate.a = 0.1 + 0.05 * sin(t * 1.3) + 0.03 * sin(t * 7.1)


# ---------------------------------------------------------------- зал

func _build_stage() -> void:
	var stone := Color(0.72, 0.72, 0.74)
	_box(Vector3(0, -0.5, -3), Vector3(12, 1, 28), Color(0.7, 0.7, 0.7), Vector3.ZERO, T_ASPHALT, 0.6)
	_box(Vector3(0, 6.5, -3), Vector3(12, 1, 28), Color(0.45, 0.45, 0.45), Vector3.ZERO, T_BRICK, 0.333)
	_box(Vector3(-6.5, 3, -3), Vector3(1, 7, 28), stone, Vector3.ZERO, T_CONCRETE)
	_box(Vector3(6.5, 3, -3), Vector3(1, 7, 28), stone, Vector3.ZERO, T_CONCRETE)
	_box(Vector3(0, 3, -13.5), Vector3(12, 7, 1), stone, Vector3.ZERO, T_CONCRETE)

	# массивные колонны и балки вдоль зала
	for z in [-9.5, -4.5, 0.5, 5.5]:
		for side in [-1, 1]:
			_box(Vector3(side * 4.6, 3, z), Vector3(0.9, 6, 0.9), stone, Vector3.ZERO, T_BRICK, 0.5)
		_box(Vector3(0, 5.75, z), Vector3(12, 0.5, 0.4), Color(0.75, 0.75, 0.75), Vector3.ZERO, T_WOOD, 1.0)

	# высокое стрельчатое окно в конце зала
	var window := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.4, 4.6)
	window.mesh = quad
	window.position = Vector3(0, 3.1, -12.97)
	var glass := ShaderMaterial.new()
	glass.shader = WINDOW_SHADER
	glass.set_shader_parameter("mode", 3)
	glass.set_shader_parameter("color", Color(0.36, 0.5, 0.74))
	window.material_override = glass
	add_child(window)

	var shaft := MeshInstance3D.new()
	var shaft_quad := QuadMesh.new()
	shaft_quad.size = Vector2(2.6, 12.0)
	shaft.mesh = shaft_quad
	shaft.position = Vector3(0, 1.9, -7.4)
	shaft.rotation = Vector3(deg_to_rad(-76), 0, 0)
	var shaft_mat := ShaderMaterial.new()
	shaft_mat.shader = SHAFT_SHADER
	shaft.material_override = shaft_mat
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shaft)

	var moon := OmniLight3D.new()
	moon.position = Vector3(0, 3.0, -11.0)
	moon.omni_range = 13.0
	moon.light_energy = 1.6
	moon.light_color = Color(0.5, 0.65, 1.0)
	add_child(moon)

	# стол со свечами слева и канделябр справа
	_box(Vector3(-3.1, 0.82, 1.2), Vector3(1.1, 0.09, 2.4), Color(0.85, 0.85, 0.85), Vector3.ZERO, T_WOOD, 1.0)
	for corner in [Vector3(-3.55, 0.4, 0.2), Vector3(-2.65, 0.4, 0.2), Vector3(-3.55, 0.4, 2.2), Vector3(-2.65, 0.4, 2.2)]:
		_box(corner, Vector3(0.1, 0.8, 0.1), Color(0.7, 0.7, 0.7), Vector3.ZERO, T_WOOD, 1.0)
	_candle(Vector3(-3.2, 0.87, 0.7), 0.22)
	_candle(Vector3(-2.95, 0.87, 1.05), 0.14)
	_candle(Vector3(-3.3, 0.87, 1.6), 0.18, 2.4, 7.5)

	_box(Vector3(3.3, 0.8, -1.4), Vector3(0.12, 1.6, 0.12), Color(0.6, 0.6, 0.6), Vector3.ZERO, T_RUST, 1.0)
	_box(Vector3(3.3, 0.04, -1.4), Vector3(0.6, 0.08, 0.6), Color(0.6, 0.6, 0.6), Vector3.ZERO, T_RUST, 1.0)
	_box(Vector3(3.3, 1.6, -1.4), Vector3(0.8, 0.05, 0.05), Color(0.6, 0.6, 0.6), Vector3.ZERO, T_RUST, 1.0)
	_candle(Vector3(2.95, 1.63, -1.4), 0.2)
	_candle(Vector3(3.3, 1.63, -1.4), 0.26, 2.6, 8.5)
	_candle(Vector3(3.65, 1.63, -1.4), 0.17)

	# тлеющие факелы у дальних колонн
	_flame_at(Vector3(-4.05, 2.7, -7.0), 0.5, 2.4, 7.0)
	_flame_at(Vector3(4.05, 2.7, -7.0), 0.5, 2.4, 7.0)


func _candle(pos: Vector3, height: float, energy := 0.0, light_range := 5.0) -> void:
	var wax := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.022
	mesh.bottom_radius = 0.026
	mesh.height = height
	wax.mesh = mesh
	wax.position = pos + Vector3(0, height / 2.0, 0)
	wax.material_override = _material(Color(0.75, 0.68, 0.52), Color(0.1, 0.06, 0.02))
	add_child(wax)
	_flame_at(pos + Vector3(0, height + 0.05, 0), 0.13, energy, light_range)


# ---------------------------------------------------------------- интерфейс

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	_logo = _logo_label()
	root.add_child(_logo)
	_echo = _logo_label()
	_echo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_echo)

	var subtitle := Label.new()
	subtitle.text = "Окраина города"
	subtitle.add_theme_font_override("font", Style.serif(true))
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.add_theme_color_override("font_color", Style.DIM)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 212
	root.add_child(subtitle)

	var main_items := []
	if not SaveGame.read().is_empty():
		main_items.append(["Продолжить", _continue_game])
	main_items.append_array([
		["Новая игра", _start_game],
		["Наброски миров", _show.bind("worlds")],
		["Настройки", _show.bind("settings")],
		["Выход", func(): get_tree().quit()],
	])
	_pages["main"] = _page(root, main_items)
	_pages["worlds"] = _page(root, [
		["Кладбище надежд", _start_scene.bind("res://scenes/world2_sketch.tscn")],
		["Зал ожидания", _start_scene.bind("res://scenes/world3_sketch.tscn")],
		["Назад", _show.bind("main")],
	])
	_pages["settings"] = _settings_page(root)
	_show("main")
	root.add_child(FpsLabel.new())

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)


func _logo_label() -> Label:
	var l := Label.new()
	l.text = "PSYCHO UNIVERSE"
	l.add_theme_font_override("font", Style.spaced(14))
	l.add_theme_font_size_override("font_size", 84)
	l.add_theme_color_override("font_color", Color(0.86, 0.85, 0.8))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 96
	return l


func _column(root: Control) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	column.offset_left = 110
	column.offset_top = 330
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)
	return column


func _page(root: Control, items: Array) -> VBoxContainer:
	var column := _column(root)
	for item in items:
		var b: Button = Style.menu_button(item[0], 34)
		b.pressed.connect(item[1])
		b.mouse_entered.connect(func(): _tick.set_mode("tick"))
		column.add_child(b)
	return column


func _settings_page(root: Control) -> VBoxContainer:
	var column := _column(root)
	column.custom_minimum_size.x = 400
	column.add_child(_slider("Громкость", 0.0, 1.0, Settings.volume, func(v):
		Settings.volume = v
		Settings.apply()))
	column.add_child(_slider("Яркость", 0.6, 1.8, Settings.brightness, func(v):
		Settings.brightness = v
		film_material.set_shader_parameter("brightness", v)))
	column.add_child(_slider("Чувствительность мыши", 0.3, 2.5, Settings.sensitivity, func(v):
		Settings.sensitivity = v))
	var full: Button = Style.menu_button("", 28)
	var caption := func(): full.text = "Полный экран: да" if Settings.fullscreen else "Полный экран: нет"
	caption.call()
	full.pressed.connect(func():
		Settings.fullscreen = not Settings.fullscreen
		Settings.apply()
		caption.call())
	column.add_child(full)
	column.add_theme_constant_override("separation", 6)
	column.offset_top = 270
	column.add_child(Style.quality_toggle(26))
	column.add_child(Style.vsync_toggle(26))
	column.add_child(Style.fps_toggle(26))
	var back: Button = Style.menu_button("Назад", 34)
	back.pressed.connect(func():
		Settings.save()
		_show("main"))
	column.add_child(back)
	return column


func _slider(title: String, low: float, high: float, value: float, changed: Callable) -> VBoxContainer:
	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Style.serif(true))
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Style.DIM)
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	slider.modulate = Color(0.75, 0.68, 0.55)
	slider.value_changed.connect(changed)
	box.add_child(slider)
	return box


func _show(page: String) -> void:
	for key in _pages:
		_pages[key].visible = key == page


func _start_game() -> void:
	_start_scene(GAME_SCENE)


# Продолжить с сохранения: уровень, на котором сохранились, сам заберёт своё состояние.
func _continue_game() -> void:
	var path: String = SaveGame.read().get("scene", "")
	if path == "" or not ResourceLoader.exists(path):
		return
	SaveGame.continue_requested = true
	_start_scene(path)


func _start_scene(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	Settings.save()
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 1.6)
	tween.parallel().tween_property(_music, "level", 0.0, 1.6)
	await tween.finished
	get_tree().change_scene_to_file(path)
