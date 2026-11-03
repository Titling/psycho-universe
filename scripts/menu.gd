# Меню: стартовое («Продолжить» / «Новая игра») и пауза по Esc.
# Работает, даже когда игра на паузе.
extends CanvasLayer

signal chosen(action: String)

var is_open := false

var _root: Control
var _title: Label
var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = ColorRect.new()
	_root.color = Color(0, 0, 0, 0.72)
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	center.add_child(vb)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_title)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	vb.add_child(_list)

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 13)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.modulate = Color(0.7, 0.75, 0.8)
	vb.add_child(_status)

	_root.visible = false


# items: массив пар [действие, надпись]. Возвращает выбранное действие.
func open(title: String, items: Array, status := "") -> String:
	_title.text = title
	_status.text = status
	for child in _list.get_children():
		child.queue_free()
	var first: Button = null
	for item in items:
		var b := Button.new()
		b.text = item[1]
		b.flat = true
		b.add_theme_font_size_override("font_size", 18)
		b.add_theme_color_override("font_focus_color", Color(1.0, 0.75, 0.5))
		b.add_theme_color_override("font_hover_color", Color(1.0, 0.75, 0.5))
		b.custom_minimum_size.x = 260
		var action: String = item[0]
		b.pressed.connect(func(): chosen.emit(action))
		_list.add_child(b)
		if first == null:
			first = b
	_root.visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if first:
		first.grab_focus()
	var action: String = await chosen
	_root.visible = false
	is_open = false
	return action


func _unhandled_input(event: InputEvent) -> void:
	# Esc в открытом меню паузы = «Вернуться в игру».
	if is_open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		chosen.emit("resume")
