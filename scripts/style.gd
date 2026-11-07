# Общий вид интерфейса: шрифты с засечками и кнопки меню.
extends RefCounted

const BONE := Color(0.82, 0.79, 0.72)
const DIM := Color(0.56, 0.54, 0.5)
const EMBER := Color(1.0, 0.86, 0.62)
const FONT_NAMES := ["Palatino Linotype", "Book Antiqua", "Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif"]
const Settings := preload("res://scripts/settings.gd")


static func serif(italic := false, bold := false) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(FONT_NAMES)
	f.font_italic = italic
	f.font_weight = 700 if bold else 400
	return f


# Заголовок с широкими промежутками между буквами.
static func spaced(spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = serif()
	f.spacing_glyph = spacing
	return f


# Кнопка меню: только текст, при наведении он разгорается.
static func menu_button(text: String, size := 30) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL   # чтобы по меню можно было ходить геймпадом, см. gamepad.gd
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_focus_color", EMBER)
	b.add_theme_font_override("font", serif())
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", EMBER)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	b.add_theme_constant_override("outline_size", 5)
	return b


# Переключатель качества: чем ниже, тем меньше пикселей считает видеокарта.
static func quality_toggle(size := 28) -> Button:
	var b := menu_button("", size)
	var caption := func(): b.text = "Качество: " + Settings.QUALITY_NAMES[Settings.quality]
	caption.call()
	b.pressed.connect(func():
		Settings.quality = (Settings.quality + 1) % Settings.QUALITY_NAMES.size()
		Settings.apply()
		Settings.save()
		caption.call())
	return b


# Вертикальная синхронизация: без неё больше кадров, но возможны разрывы картинки.
static func vsync_toggle(size := 28) -> Button:
	var b := menu_button("", size)
	var caption := func(): b.text = "Вертикальная синхронизация: вкл" if Settings.vsync else "Вертикальная синхронизация: выкл"
	caption.call()
	b.pressed.connect(func():
		Settings.vsync = not Settings.vsync
		Settings.apply()
		Settings.save()
		caption.call())
	return b


# Переключатель счётчика кадров: нужен и в настройках меню, и на паузе.
static func fps_toggle(size := 28) -> Button:
	var b := menu_button("", size)
	var caption := func(): b.text = "Показывать FPS: да" if Settings.show_fps else "Показывать FPS: нет"
	caption.call()
	b.pressed.connect(func():
		Settings.show_fps = not Settings.show_fps
		Settings.save()
		caption.call())
	return b
