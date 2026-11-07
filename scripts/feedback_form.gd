# Форма отзыва: оценка, тема, текст. Открывается из главного меню и с паузы.
# Каждый отзыв сохраняется файлом в user://feedback/ (на Windows это
# %APPDATA%\Godot\app_userdata\Psycho Universe\feedback). Если в настройках проекта
# задан адрес (раздел psycho/feedback), отзыв ещё и отправляется туда.
extends CanvasLayer

signal closed

const Style := preload("res://scripts/style.gd")
const Settings := preload("res://scripts/settings.gd")
const FOLDER := "user://feedback"
const TOPICS := ["Впечатление", "Ошибка", "Идея", "Страшно / не страшно"]
const MAX_LENGTH := 3000

var _panel: Control
var _stars: Array[Button] = []
var _rating := 0
var _topic := 0
var _topic_button: Button
var _text: TextEdit
var _system: CheckBox
var _status: Label
var _send: Button
var _http: HTTPRequest
var _sending := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_rating = 0
	_topic = 0
	_text.text = ""
	_status.text = ""
	_send.disabled = false
	_refresh()
	_panel.visible = true
	_text.grab_focus()


func close() -> void:
	if _sending:
		return
	_text.release_focus()
	_panel.visible = false
	closed.emit()


# Esc закрывает только форму: пауза под ней остаётся.
func _input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


# ---------------------------------------------------------------- вид

func _build() -> void:
	_panel = ColorRect.new()
	(_panel as ColorRect).color = Color(0, 0, 0, 0.92)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(640, 0)
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	var title := _label("Отзыв о прототипе", 40, Style.BONE)
	title.add_theme_font_override("font", Style.spaced(4))
	column.add_child(title)
	column.add_child(_label("Что понравилось, что сломалось, где было страшно. Читаем всё.", 20, Style.DIM, true))

	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	for i in 5:
		var b := Style.menu_button("★", 40)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.tooltip_text = "%d из 5" % (i + 1)
		b.pressed.connect(func():
			_rating = i + 1
			_refresh())
		stars.add_child(b)
		_stars.append(b)
	column.add_child(stars)

	_topic_button = Style.menu_button("", 26)
	_topic_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_topic_button.pressed.connect(func():
		_topic = (_topic + 1) % TOPICS.size()
		_refresh())
	column.add_child(_topic_button)

	_text = TextEdit.new()
	_text.custom_minimum_size = Vector2(640, 220)
	_text.placeholder_text = "Напиши здесь…"
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.add_theme_font_override("font", Style.serif())
	_text.add_theme_font_size_override("font_size", 22)
	_text.add_theme_color_override("font_color", Style.BONE)
	_text.add_theme_color_override("font_placeholder_color", Color(Style.DIM, 0.6))
	_text.add_theme_color_override("caret_color", Style.EMBER)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.06, 0.95)
	box.border_color = Color(Style.DIM, 0.5)
	box.set_border_width_all(1)
	box.set_content_margin_all(12)
	_text.add_theme_stylebox_override("normal", box)
	_text.add_theme_stylebox_override("focus", box)
	_text.text_changed.connect(func():
		if _text.text.length() > MAX_LENGTH:
			_text.text = _text.text.left(MAX_LENGTH)
			_text.set_caret_column(_text.get_line(_text.get_line_count() - 1).length())
			_text.set_caret_line(_text.get_line_count() - 1))
	column.add_child(_text)

	_system = CheckBox.new()
	_system.text = "Приложить сведения о компьютере и настройках (помогает искать ошибки)"
	_system.button_pressed = true
	_system.focus_mode = Control.FOCUS_NONE
	_system.add_theme_font_override("font", Style.serif(true))
	_system.add_theme_font_size_override("font_size", 18)
	_system.add_theme_color_override("font_color", Style.DIM)
	_system.add_theme_color_override("font_hover_color", Style.BONE)
	_system.add_theme_color_override("font_pressed_color", Style.DIM)
	_system.add_theme_color_override("font_hover_pressed_color", Style.BONE)
	column.add_child(_system)

	_status = _label("", 20, Style.EMBER, true)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 48)
	_send = Style.menu_button("Отправить", 32)
	_send.pressed.connect(_submit)
	buttons.add_child(_send)
	var folder := Style.menu_button("Папка с отзывами", 32)
	folder.pressed.connect(func():
		DirAccess.make_dir_recursive_absolute(FOLDER)
		OS.shell_open(ProjectSettings.globalize_path(FOLDER)))
	buttons.add_child(folder)
	var back := Style.menu_button("Назад", 32)
	back.pressed.connect(close)
	buttons.add_child(back)
	column.add_child(buttons)

	_http = HTTPRequest.new()
	_http.timeout = 15.0
	_http.request_completed.connect(_on_sent)
	add_child(_http)


func _label(text: String, size: int, color: Color, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Style.serif(italic))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _refresh() -> void:
	for i in _stars.size():
		var lit := i < _rating
		_stars[i].add_theme_color_override("font_color", Style.EMBER if lit else Color(Style.DIM, 0.45))
	_topic_button.text = "Тема: " + TOPICS[_topic] + "  ›"


# ---------------------------------------------------------------- отправка

func _submit() -> void:
	if _sending:
		return
	var message := _text.text.strip_edges()
	if message.is_empty() and _rating == 0:
		_status.text = "Поставь оценку или напиши пару слов."
		return
	var report := _report(message)
	var saved := _save(report)
	if not _has_endpoint():
		_status.text = "Спасибо! Отзыв сохранён: " + saved if saved != "" else "Не удалось сохранить отзыв."
		_send.disabled = saved != ""
		return
	_sending = true
	_send.disabled = true
	_status.text = "Отправляю…"
	var err := _post(report)
	if err != OK:
		_sending = false
		_send.disabled = false
		_status.text = "Нет связи. Отзыв сохранён в файл, его можно прислать вручную."


func _report(message: String) -> Dictionary:
	var report := {
		"time": Time.get_datetime_string_from_system(false, true),
		"version": ProjectSettings.get_setting("application/config/version", "dev"),
		"rating": _rating,
		"topic": TOPICS[_topic],
		"text": message,
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
	}
	if _system.button_pressed:
		report["system"] = {
			"os": OS.get_name() + " " + OS.get_version(),
			"cpu": OS.get_processor_name(),
			"gpu": RenderingServer.get_video_adapter_name(),
			"driver": RenderingServer.get_video_adapter_api_version(),
			"screen": str(DisplayServer.screen_get_size()),
			"fps": Engine.get_frames_per_second(),
			"quality": Settings.QUALITY_NAMES[Settings.quality],
			"fullscreen": Settings.fullscreen,
			"vsync": Settings.vsync,
		}
	return report


# Возвращает путь к сохранённому файлу или пустую строку.
func _save(report: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var stamp := Time.get_datetime_string_from_system(false, false).replace(":", "-").replace("T", "_")
	var path := "%s/feedback_%s.json" % [FOLDER, stamp]
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	return ProjectSettings.globalize_path(path)


func _has_endpoint() -> bool:
	return _setting("url") != "" or (_setting("telegram_token") != "" and _setting("telegram_chat_id") != "")


func _setting(key: String) -> String:
	return str(ProjectSettings.get_setting("psycho/feedback/" + key, "")).strip_edges()


func _post(report: Dictionary) -> Error:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if _setting("telegram_token") != "" and _setting("telegram_chat_id") != "":
		var url := "https://api.telegram.org/bot%s/sendMessage" % _setting("telegram_token")
		var body := {"chat_id": _setting("telegram_chat_id"), "text": _telegram_text(report)}
		return _http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	return _http.request(_setting("url"), headers, HTTPClient.METHOD_POST, JSON.stringify(report))


func _telegram_text(report: Dictionary) -> String:
	var lines := [
		"Отзыв · Psycho Universe %s" % report.version,
		"Оценка: %s" % ("★".repeat(report.rating) if report.rating > 0 else "—"),
		"Тема: %s" % report.topic,
		"",
		report.text if report.text != "" else "(без текста)",
	]
	if report.has("system"):
		var s: Dictionary = report.system
		lines.append("")
		lines.append("%s · %s · %s · %d FPS · %s" % [s.os, s.gpu, s.screen, s.fps, s.quality])
	lines.append("Сцена: " + report.scene)
	# у Telegram предел 4096 символов на сообщение
	return "\n".join(lines).left(4000)


func _on_sent(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_sending = false
	if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
		_status.text = "Спасибо! Отзыв отправлен."
	else:
		_send.disabled = false
		_status.text = "Не получилось отправить (код %d). Отзыв сохранён в файл, его можно прислать вручную." % code
