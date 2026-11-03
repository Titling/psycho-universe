# Меню паузы с настройками. Открывается и закрывается по Esc, на это время игра стоит.
extends CanvasLayer

var _panel: Control
var _music: HSlider
var _sfx: HSlider
var _mouse: HSlider
var _resume: Button
var _prev_mouse_mode := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS

	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	_panel.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.95)
	style.border_color = Color(0.35, 0.38, 0.45)
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	box.add_child(vb)

	var title := Label.new()
	title.text = "ПАУЗА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vb.add_child(title)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)

	_music = _row(grid, "Музыка", 0.0, 1.0, 0.05, Settings.music_volume,
		func(v): Settings.set_music_volume(v),
		func(v): return "%d%%" % roundi(v * 100.0))
	_sfx = _row(grid, "Эффекты", 0.0, 1.0, 0.05, Settings.sfx_volume,
		func(v): Settings.set_sfx_volume(v),
		func(v): return "%d%%" % roundi(v * 100.0))
	_mouse = _row(grid, "Мышь", 0.1, 3.0, 0.05, Settings.mouse_sensitivity,
		func(v): Settings.set_mouse_sensitivity(v),
		func(v): return "x%.2f" % v)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	vb.add_child(buttons)

	_resume = Button.new()
	_resume.text = "Продолжить"
	_resume.pressed.connect(close)
	buttons.add_child(_resume)

	var quit := Button.new()
	quit.text = "Выйти из игры"
	quit.pressed.connect(func():
		Settings.save_settings()
		get_tree().quit())
	buttons.add_child(quit)

	var hint := Label.new()
	hint.text = "Esc — вернуться в игру"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(0.6, 0.6, 0.65)
	vb.add_child(hint)


func _row(grid: GridContainer, caption: String, min_v: float, max_v: float, step: float,
		value: float, on_change: Callable, fmt: Callable) -> HSlider:
	var label := Label.new()
	label.text = caption
	grid.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.custom_minimum_size = Vector2(200, 20)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)

	var shown := Label.new()
	shown.custom_minimum_size.x = 48
	grid.add_child(shown)

	slider.value = value
	shown.text = fmt.call(value)
	slider.value_changed.connect(func(v: float):
		shown.text = fmt.call(v)
		on_change.call(v))
	return slider


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if is_open():
			close()
		else:
			open()


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	_music.set_value_no_signal(Settings.music_volume)
	_sfx.set_value_no_signal(Settings.sfx_volume)
	_mouse.set_value_no_signal(Settings.mouse_sensitivity)
	_prev_mouse_mode = Input.mouse_mode
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_resume.grab_focus()


func close() -> void:
	_panel.visible = false
	get_tree().paused = false
	Settings.save_settings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Settings.save_settings()
