# Геймпад (раскладка Xbox; у PlayStation те же места). Подключён как автозагрузка Gamepad.
#
#   Левый стик — идти          Правый стик — смотреть
#   LT (держать) — бежать      RT — бросить предмет
#   A — прыжок                 X — действие, взять, положить; пролистать реплику
#   B или Start — пауза, назад  Y — инвентарь
#   LB — фонарик               RB — убрать предмет в инвентарь
#   R3 — присесть              Back — быстрое сохранение
#   В меню: крестовина или стик выбирают пункт, A нажимает.
extends Node

const DEADZONE := 0.2
const LOOK_SPEED := 2.6   # радиан в секунду при стике до упора и чувствительности 1

const BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_X],
	"inventory": [JOY_BUTTON_Y],
	"flashlight": [JOY_BUTTON_LEFT_SHOULDER],
	"store_item": [JOY_BUTTON_RIGHT_SHOULDER],
	"crouch": [JOY_BUTTON_RIGHT_STICK],
	"quick_save": [JOY_BUTTON_BACK],
	"ui_cancel": [JOY_BUTTON_START],
}
# действие: [ось, направление]
const AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"sprint": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"throw": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # меню паузы тоже должно слушаться геймпада


# Добавить кнопки геймпада к действиям. Вызывается из main.gd после того, как заведены клавиши.
func bind() -> void:
	for action in BUTTONS:
		for button in BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			_add_event(action, ev)
	for action in AXES:
		var ev := InputEventJoypadMotion.new()
		ev.axis = AXES[action][0]
		ev.axis_value = AXES[action][1]
		_add_event(action, ev)


func _add_event(action: String, ev: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, DEADZONE)
	for existing in InputMap.action_get_events(action):
		if existing.is_match(ev):
			return
	InputMap.action_add_event(action, ev)


# Поворот взгляда правым стиком за кадр: (влево-вправо, вверх-вниз), в радианах.
func look(delta: float, sensitivity: float) -> Vector2:
	if not InputMap.has_action("look_left"):
		return Vector2.ZERO
	var v := Input.get_vector("look_left", "look_right", "look_up", "look_down", DEADZONE)
	return v * v.length() * LOOK_SPEED * sensitivity * delta   # мягко у центра, быстро у края


# Меню сделаны под мышь. С геймпадом первая же кнопка в открытом меню получает фокус,
# дальше крестовина ходит по пунктам. Мышь фокус снимает, чтобы пункт не оставался подсвеченным.
func _input(event: InputEvent) -> void:
	var viewport := get_viewport()
	var owner := viewport.gui_get_focus_owner()
	if event is InputEventMouseMotion:
		if owner is BaseButton or owner is Range:
			owner.release_focus()
		return
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	if not pad or owner != null:
		return
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return   # идёт игра, а не меню
	var target := _first_focusable(get_tree().root)
	if target != null:
		target.grab_focus()
		viewport.set_input_as_handled()


func _first_focusable(node: Node) -> Control:
	if node is CanvasItem and not node.is_visible_in_tree():
		return null
	if node is Control and (node is BaseButton or node is Range) and node.focus_mode == Control.FOCUS_ALL:
		return node
	for child in node.get_children():
		var found := _first_focusable(child)
		if found != null:
			return found
	return null
