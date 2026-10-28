# Весь интерфейс: затемнение, помехи, реплики в формате пьесы, SMS, подсказки.
extends CanvasLayer

signal sms_shown

var _fade: ColorRect
var _noise: ColorRect
var _prompt: Label
var _title: Label
var _hint: Label
var _dialog: PanelContainer
var _dialog_text: RichTextLabel
var _sms: PanelContainer
var _sms_text: Label

var _battery: Label
var talking := false

var _advance := false
var _line_time := 0.0


func _ready() -> void:
	_noise = ColorRect.new()
	_noise.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var noise_mat := ShaderMaterial.new()
	noise_mat.shader = preload("res://shaders/noise.gdshader")
	_noise.material = noise_mat
	add_child(_noise)

	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_title = _label(32, HORIZONTAL_ALIGNMENT_CENTER)
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.modulate.a = 0.0
	add_child(_title)

	_hint = _label(13, HORIZONTAL_ALIGNMENT_LEFT)
	_hint.position = Vector2(10, 8)
	_hint.modulate = Color(1, 1, 1, 0)
	add_child(_hint)

	_prompt = _label(16, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y -= 120
	add_child(_prompt)

	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", _box(Color(0, 0, 0, 0.75)))
	_dialog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 40
	_dialog.offset_right = -40
	_dialog.offset_top = -120
	_dialog.offset_bottom = -16
	_dialog_text = RichTextLabel.new()
	_dialog_text.bbcode_enabled = true
	_dialog_text.fit_content = true
	_dialog_text.add_theme_font_size_override("normal_font_size", 16)
	_dialog_text.add_theme_font_size_override("bold_font_size", 16)
	_dialog_text.add_theme_font_size_override("italics_font_size", 16)
	_dialog.add_child(_dialog_text)
	_dialog.visible = false
	add_child(_dialog)

	_sms = PanelContainer.new()
	_sms.add_theme_stylebox_override("panel", _box(Color(0.05, 0.07, 0.1, 0.92)))
	# SMS появляется над телефоном в руке, справа внизу
	_sms.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_sms.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sms.offset_left = -290
	_sms.offset_right = -14
	_sms.offset_bottom = -150
	var vb := VBoxContainer.new()
	var header := _label(13, HORIZONTAL_ALIGNMENT_LEFT)
	header.text = "03:17   Неизвестный"
	header.modulate = Color(0.6, 0.7, 0.8)
	vb.add_child(header)
	_sms_text = _label(16, HORIZONTAL_ALIGNMENT_LEFT)
	_sms_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sms_text.custom_minimum_size.x = 260
	vb.add_child(_sms_text)
	_sms.add_child(vb)
	_sms.visible = false
	add_child(_sms)

	_battery = _label(13, HORIZONTAL_ALIGNMENT_RIGHT)
	_battery.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_battery.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_battery.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_battery.offset_right = -12
	_battery.offset_bottom = -8
	_battery.visible = false
	add_child(_battery)


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(10)
	return s


func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed and _line_time > 0.35:
		_advance = true


func _process(delta: float) -> void:
	_line_time += delta


func set_prompt(text: String) -> void:
	_prompt.text = text


# Заряд телефона: показывается, только пока горит фонарик или батарея почти села.
func set_battery(value: float, light_on: bool) -> void:
	_battery.visible = light_on or value < 0.2
	_battery.text = "ЗАРЯД %d%%" % roundi(value * 100.0)
	_battery.modulate = Color(1, 0.4, 0.35) if value < 0.2 else Color(0.75, 0.85, 0.95)


func set_noise(amount: float) -> void:
	(_noise.material as ShaderMaterial).set_shader_parameter("amount", amount)


func fade_to(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", alpha, time)
	await tween.finished


func show_title(text: String, time := 4.0) -> void:
	_title.text = text
	var tween := create_tween()
	tween.tween_property(_title, "modulate:a", 1.0, 1.0)
	tween.tween_interval(time)
	tween.tween_property(_title, "modulate:a", 0.0, 1.5)


func show_hint(text: String, time := 8.0) -> void:
	_hint.text = text
	var tween := create_tween()
	tween.tween_property(_hint, "modulate:a", 0.8, 0.5)
	tween.tween_interval(time)
	tween.tween_property(_hint, "modulate:a", 0.0, 1.5)


# Показать строки по очереди. Каждая ждёт нажатия E / клика или пропадает сама.
func say(lines: Array) -> void:
	talking = true
	for line in lines:
		var duration := 0.0
		if line.has("sms"):
			_dialog.visible = false
			_sms_text.text = line.sms
			_sms.visible = true
			sms_shown.emit()
			duration = 4.0
		else:
			_sms.visible = false
			_dialog_text.text = _format(line)
			_dialog.visible = true
			var length: int = line.get("text", line.get("remark", "")).length()
			duration = clampf(length * 0.07, 2.5, 14.0)
		_advance = false
		_line_time = 0.0
		while not _advance and _line_time < duration:
			await get_tree().process_frame
	_dialog.visible = false
	_sms.visible = false
	talking = false


func _format(line: Dictionary) -> String:
	if line.has("remark"):
		return "[center][i][color=#b0b0b0]%s[/color][/i][/center]" % line.remark
	var s := "[b]%s[/b]" % line.who
	if line.has("note"):
		s += " [i][color=#b0b0b0](%s)[/color][/i]" % line.note
	return s + ". " + line.text
