# Весь интерфейс: затемнение, потеря рассудка, субтитры в формате пьесы, SMS, подсказки, пауза.
extends CanvasLayer

signal sms_shown
signal inventory_closed

const Style := preload("res://scripts/style.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
const SANITY_STAGES := [
	preload("res://textures/sanity/stage_1.png"),
	preload("res://textures/sanity/stage_2.png"),
	preload("res://textures/sanity/stage_3.png"),
	preload("res://textures/sanity/stage_4.png"),
	preload("res://textures/sanity/stage_5.png"),
]
const SANITY_ICON_SIZE := 110.0
const INVENTORY_COLUMNS := 4
const SLOT_SIZE := 92.0

var _fade: ColorRect
var _noise: ColorRect
var _prompt: Label
var _title: Label
var _hint: Label
var _dialog: PanelContainer
var _dialog_text: RichTextLabel
var _sms: PanelContainer
var _sms_text: Label
var _pause: Control
var _pause_status: Label
var _leaving := false
var _paper: PanelContainer
var _paper_text: Label
var _sanity: TextureRect
var _sanity_stage := 0
var _inventory: PanelContainer
var _inventory_grid: GridContainer
var _inventory_caption: Label

var _battery: Label
var talking := false

var _advance := false
var _line_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

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

	_title = _label(46, HORIZONTAL_ALIGNMENT_CENTER)
	_title.add_theme_font_override("font", Style.spaced(4))
	_title.set_anchors_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.modulate.a = 0.0
	add_child(_title)

	_hint = _label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_hint.add_theme_font_override("font", Style.serif(true))
	_hint.position = Vector2(24, 18)
	_hint.modulate = Color(1, 1, 1, 0)
	add_child(_hint)

	_prompt = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.add_theme_font_override("font", Style.serif(true))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y -= 190
	add_child(_prompt)

	# Субтитры без подложки, как в старых хоррорах: только тень под буквами.
	_dialog = PanelContainer.new()
	_dialog.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_dialog.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dialog.offset_left = 150
	_dialog.offset_right = -150
	_dialog.offset_top = -170
	_dialog.offset_bottom = -30
	_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_text = RichTextLabel.new()
	_dialog_text.bbcode_enabled = true
	_dialog_text.fit_content = true
	_dialog_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog_text.add_theme_font_override("normal_font", Style.serif())
	_dialog_text.add_theme_font_override("bold_font", Style.serif(false, true))
	_dialog_text.add_theme_font_override("italics_font", Style.serif(true))
	_dialog_text.add_theme_font_size_override("normal_font_size", 26)
	_dialog_text.add_theme_font_size_override("bold_font_size", 26)
	_dialog_text.add_theme_font_size_override("italics_font_size", 26)
	_dialog_text.add_theme_color_override("default_color", Style.BONE)
	_dialog_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_dialog_text.add_theme_constant_override("shadow_offset_x", 2)
	_dialog_text.add_theme_constant_override("shadow_offset_y", 2)
	_dialog_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_dialog_text.add_theme_constant_override("outline_size", 5)
	_dialog.add_child(_dialog_text)
	_dialog.visible = false
	add_child(_dialog)

	_sms = PanelContainer.new()
	var sms_box := _box(Color(0.03, 0.03, 0.04, 0.9))
	sms_box.border_color = Color(0.32, 0.25, 0.16, 0.9)
	sms_box.set_border_width_all(1)
	_sms.add_theme_stylebox_override("panel", sms_box)
	# SMS появляется над телефоном в руке, справа внизу
	_sms.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_sms.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sms.offset_left = -470
	_sms.offset_right = -24
	_sms.offset_bottom = -250
	var vb := VBoxContainer.new()
	var header := _label(20, HORIZONTAL_ALIGNMENT_LEFT)
	header.add_theme_font_override("font", Style.serif(true))
	header.text = "03:17   Неизвестный"
	header.modulate = Style.DIM
	vb.add_child(header)
	_sms_text = _label(25, HORIZONTAL_ALIGNMENT_LEFT)
	_sms_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sms_text.custom_minimum_size.x = 420
	vb.add_child(_sms_text)
	_sms.add_child(vb)
	_sms.visible = false
	add_child(_sms)

	_paper = PanelContainer.new()
	var paper_box := _box(Color(0.8, 0.76, 0.66, 0.97))
	paper_box.set_content_margin_all(34)
	_paper.add_theme_stylebox_override("panel", paper_box)
	_paper.set_anchors_preset(Control.PRESET_CENTER)
	_paper.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_paper.grow_vertical = Control.GROW_DIRECTION_BOTH
	_paper_text = _label(27, HORIZONTAL_ALIGNMENT_LEFT)
	_paper_text.add_theme_font_override("font", Style.serif())
	_paper_text.add_theme_color_override("font_color", Color(0.13, 0.1, 0.08))
	_paper_text.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_paper_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_paper_text.custom_minimum_size.x = 640
	_paper.add_child(_paper_text)
	_paper.visible = false
	add_child(_paper)

	_build_sanity()
	_build_inventory()

	_battery = _label(20, HORIZONTAL_ALIGNMENT_RIGHT)
	_battery.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_battery.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_battery.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_battery.offset_right = -20
	_battery.offset_bottom = -14
	_battery.visible = false
	add_child(_battery)

	add_child(preload("res://scripts/fps_label.gd").new())
	add_child(preload("res://scripts/soft_cursor.gd").new())
	_build_pause()


# Показатель рассудка в левом нижнем углу: глаз, который с каждой стадией выглядит хуже.
func _build_sanity() -> void:
	_sanity = TextureRect.new()
	_sanity.texture = SANITY_STAGES[0]
	_sanity.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sanity.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sanity.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_sanity.offset_left = 16
	_sanity.offset_right = 16 + SANITY_ICON_SIZE
	_sanity.offset_top = -SANITY_ICON_SIZE - 10
	_sanity.offset_bottom = -10
	_sanity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sanity.visible = false
	add_child(_sanity)


# sanity: 0 — всё в порядке, 1 — героя накрыло.
func set_sanity(sanity: float, shown: bool) -> void:
	_sanity.visible = shown
	var stage := mini(int(sanity * SANITY_STAGES.size()), SANITY_STAGES.size() - 1)
	if stage == _sanity_stage:
		return
	_sanity_stage = stage
	_sanity.texture = SANITY_STAGES[stage]
	_sanity.modulate.a = 0.35
	create_tween().tween_property(_sanity, "modulate:a", 1.0, 0.5)


func _build_inventory() -> void:
	_inventory = PanelContainer.new()
	var box := _box(Color(0.03, 0.03, 0.04, 0.92))
	box.border_color = Color(0.32, 0.25, 0.16, 0.9)
	box.set_border_width_all(1)
	box.set_content_margin_all(26)
	_inventory.add_theme_stylebox_override("panel", box)
	_inventory.set_anchors_preset(Control.PRESET_CENTER)
	_inventory.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_inventory.grow_vertical = Control.GROW_DIRECTION_BOTH
	_inventory.visible = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	var header := _label(28, HORIZONTAL_ALIGNMENT_LEFT)
	header.add_theme_font_override("font", Style.spaced(3))
	header.text = "ИНВЕНТАРЬ"
	column.add_child(header)
	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = INVENTORY_COLUMNS
	_inventory_grid.add_theme_constant_override("h_separation", 8)
	_inventory_grid.add_theme_constant_override("v_separation", 8)
	column.add_child(_inventory_grid)
	_inventory_caption = _label(20, HORIZONTAL_ALIGNMENT_LEFT)
	_inventory_caption.add_theme_font_override("font", Style.serif(true))
	_inventory_caption.modulate = Style.DIM
	column.add_child(_inventory_caption)
	_inventory.add_child(column)
	add_child(_inventory)


func _inventory_hint(hands_full: bool) -> String:
	return "Сначала положи то, что в руках" if hands_full else "Нажми на вещь, чтобы взять её.   Tab — закрыть"


# Ячейки с иконками. Нажатие достаёт вещь в руки, если они свободны.
func open_inventory(items: Array, capacity: int, hands_full: bool, on_pick: Callable) -> void:
	for child in _inventory_grid.get_children():
		child.queue_free()
	var hint := _inventory_hint(hands_full)
	_inventory_caption.text = hint
	for i in capacity:
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		slot.focus_mode = Control.FOCUS_NONE
		slot.expand_icon = true
		slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var normal := _box(Color(0.1, 0.09, 0.09, 0.9))
		normal.set_content_margin_all(6)
		var hover := _box(Color(0.2, 0.17, 0.13, 0.95))
		hover.set_content_margin_all(6)
		slot.add_theme_stylebox_override("normal", normal)
		slot.add_theme_stylebox_override("disabled", normal)
		slot.add_theme_stylebox_override("hover", hover)
		slot.add_theme_stylebox_override("pressed", hover)
		if i >= items.size():
			slot.disabled = true
			_inventory_grid.add_child(slot)
			continue
		var item: Node = items[i]
		slot.icon = item.icon
		slot.disabled = hands_full
		slot.mouse_entered.connect(func(): _inventory_caption.text = item.title.capitalize())
		slot.mouse_exited.connect(func(): _inventory_caption.text = hint)
		slot.pressed.connect(func():
			close_inventory()
			on_pick.call(i))
		_inventory_grid.add_child(slot)
	_inventory.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func close_inventory() -> void:
	_inventory.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	inventory_closed.emit()


func _build_pause() -> void:
	_pause = ColorRect.new()
	_pause.color = Color(0, 0, 0, 0.72)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause.visible = false
	add_child(_pause)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 14)
	_pause.add_child(column)
	var resume := Style.menu_button("Продолжить", 34)
	resume.pressed.connect(_set_paused.bind(false))
	column.add_child(resume)
	column.add_child(Style.quality_toggle(34))
	column.add_child(Style.vsync_toggle(34))
	column.add_child(Style.fps_toggle(34))
	var save_exit := Style.menu_button("Сохранить и выйти", 34)
	save_exit.pressed.connect(_save_and_exit)
	column.add_child(save_exit)
	var to_menu := Style.menu_button("Выйти без сохранения", 34)
	to_menu.pressed.connect(_exit_to_menu)
	column.add_child(to_menu)
	_pause_status = _label(22, HORIZONTAL_ALIGNMENT_CENTER)
	_pause_status.add_theme_color_override("font_color", Style.DIM)
	column.add_child(_pause_status)


# «Сохранить и выйти»: уровень сам решает, можно ли сейчас сохраняться (can_save()) и что
# кладётся в файл (_world_state()). Во время сценки или в набросках миров сохранить нельзя:
# тогда игра остаётся на паузе, а выйти можно кнопкой «Выйти без сохранения».
func _save_and_exit() -> void:
	if _leaving:
		return
	var level := get_tree().current_scene
	if level == null or not level.has_method("can_save") or not level.has_method("_world_state"):
		_pause_status.text = "Здесь игра не сохраняется."
		return
	# can_save() не разрешает сохраняться на паузе, поэтому на один вызов паузу снимаем:
	# кадр за это время не проходит.
	get_tree().paused = false
	var allowed: bool = level.can_save()
	var ok := allowed and SaveGame.save_game(level._world_state())
	get_tree().paused = true
	if not allowed:
		_pause_status.text = "Сейчас сохранить нельзя."
		return
	if not ok:
		_pause_status.text = "Не удалось сохранить. Игра не закрыта."
		return
	_pause_status.text = "Сохранено"
	_leaving = true
	await get_tree().create_timer(0.6, true, false, true).timeout
	_exit_to_menu()


func _exit_to_menu() -> void:
	_leaving = true
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _set_paused(value: bool) -> void:
	if _leaving:
		return
	_pause_status.text = ""
	_pause.visible = value
	get_tree().paused = value
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if value else Input.MOUSE_MODE_CAPTURED


func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Style.BONE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_content_margin_all(14)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _inventory.visible:
			close_inventory()
			return
		_set_paused(not get_tree().paused)
		return
	if get_tree().paused:
		return
	var pressed: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if pressed and _line_time > 0.35:
		_advance = true


func _process(delta: float) -> void:
	if not get_tree().paused:
		_line_time += delta


func set_prompt(text: String) -> void:
	_prompt.text = text


# Заряд телефона: показывается, только пока горит фонарик или батарея почти села.
func set_battery(value: float, light_on: bool) -> void:
	_battery.visible = light_on or value < 0.2
	_battery.text = "ЗАРЯД %d%%" % roundi(value * 100.0)
	_battery.modulate = Color(0.95, 0.42, 0.3) if value < 0.2 else Style.DIM


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
			# игрок вышел в главное меню посреди реплики
			if not is_inside_tree():
				return
	_dialog.visible = false
	_sms.visible = false
	talking = false


# Лист бумаги перед глазами: страницы сменяются только по нажатию, у текста нет таймера.
func read_note(pages: Array) -> void:
	talking = true
	_paper.visible = true
	for page in pages:
		_paper_text.text = page
		_advance = false
		_line_time = 0.0
		while not _advance:
			await get_tree().process_frame
			if not is_inside_tree():
				return
	_paper.visible = false
	talking = false


func _format(line: Dictionary) -> String:
	if line.has("remark"):
		return "[center][i][color=#a8a294]%s[/color][/i][/center]" % line.remark
	var s := "[b]%s[/b]" % line.who
	if line.has("note"):
		s += " [i][color=#a8a294](%s)[/color][/i]" % line.note
	return "[center]" + s + ". " + line.text + "[/center]"
