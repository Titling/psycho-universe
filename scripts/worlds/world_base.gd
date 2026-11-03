# Общая основа для Миров 2 и 3. Сам уровень (пол, стены, свет, туман, фильтр) лежит в сцене .tscn
# и правится в редакторе Godot. Скрипт только ставит игрока на маркер PlayerStart и показывает название.
extends Node3D

const PlayerScript := preload("res://scripts/player.gd")
const UIScript := preload("res://scripts/ui.gd")

@export var title := ""
@export var camera_far := 250.0

var player: CharacterBody3D
var ui: CanvasLayer


func _ready() -> void:
	randomize()
	_setup_input()
	var start: Node3D = get_node_or_null("PlayerStart")
	player = PlayerScript.new()
	add_child(player)
	if start != null:
		player.global_position = start.global_position
		player.rotation.y = start.global_rotation.y
	player.camera.far = camera_far
	ui = UIScript.new()
	add_child(ui)
	player.prompt_changed.connect(ui.set_prompt)
	_intro()


func _intro() -> void:
	await get_tree().create_timer(0.3).timeout
	ui.show_title(title)
	await ui.fade_to(0.0, 2.0)
	ui.show_hint("Сюжета здесь пока нет.   WASD — идти   Shift — бежать   Esc — показать курсор")


# Те же клавиши, что и в Мире 1, чтобы сцену можно было запускать отдельно (F6).
func _setup_input() -> void:
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("interact", [KEY_E])
	_add_action("flashlight", [KEY_F])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
