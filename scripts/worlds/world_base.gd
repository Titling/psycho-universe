# Общая основа для Миров 2 и 3. Сам уровень (пол, стены, свет, туман, фильтр) лежит в сцене .tscn
# и правится в редакторе Godot. Скрипт ставит игрока на маркер PlayerStart, показывает название,
# отдаёт герою вещи, которые он принёс с прошлого уровня, и ведёт к выходу на маркере Exit.
extends Node3D

const D := preload("res://data/dialogues.gd")
const PlayerScript := preload("res://scripts/player.gd")
const UIScript := preload("res://scripts/ui.gd")
const HandsScript := preload("res://scripts/hands.gd")
const InteractableScript := preload("res://scripts/interactable.gd")
const Settings := preload("res://scripts/settings.gd")
const MENU_SCENE := "res://scenes/menu.tscn"
# Куда могут улететь вещи из инвентаря, если их достать здесь: весь мир с запасом.
const LEVEL_AREA := AABB(Vector3(-200, -20, -200), Vector3(400, 120, 400))

@export var title := ""
@export var camera_far := 250.0
# Куда ведёт выход. Пусто — это последний мир: после выхода титры и главное меню.
@export_file("*.tscn") var next_scene := ""
# Подсказка, когда герой смотрит на выход (маркер Exit в сцене).
@export var exit_prompt := "Идти дальше"
# Размер зоны выхода вокруг маркера Exit, м.
@export var exit_size := Vector3(2.5, 2.5, 2.5)

var player: CharacterBody3D
var ui: CanvasLayer
var hands: Node
var exit: Area3D
var _leaving := false


func _ready() -> void:
	randomize()
	Settings.load_once()
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

	# Руки с инвентарём: вещи, которые герой нёс с собой из квартиры и Мира 1, переезжают дальше.
	hands = HandsScript.new()
	hands.name = "Руки"
	hands.player = player
	hands.ui = ui
	hands.area = LEVEL_AREA
	add_child(hands)

	var film: ColorRect = get_node_or_null("FilmFilter/Film")
	if film != null and film.material is ShaderMaterial:
		film.material.set_shader_parameter("brightness", Settings.brightness)

	_setup_exit()
	_intro()


func _intro() -> void:
	player.locked = true
	await get_tree().create_timer(0.3, false).timeout
	ui.show_title(title)
	await ui.fade_to(0.0, 2.0)
	var lines: Array = D.WORLD_ENTER.get(scene_file_path, [])
	if not lines.is_empty():
		await ui.say(lines)
	player.locked = false
	ui.show_hint("WASD — идти   Shift — бежать   Пробел — прыжок   Ctrl — присесть   E — действие   Tab — инвентарь   Esc — пауза")


# Выход из мира: зона на маркере Exit, на неё можно навести взгляд и нажать E.
func _setup_exit() -> void:
	var marker: Node3D = get_node_or_null("Exit")
	if marker == null:
		return
	exit = InteractableScript.new()
	exit.name = "Выход"
	exit.setup(exit_size, exit_prompt)
	add_child(exit)
	exit.global_transform = marker.global_transform
	exit.used.connect(_leave)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	exit.enabled = false
	player.locked = true
	ui.set_prompt("")
	hands.stash_held()
	var lines: Array = D.WORLD_LEAVE.get(scene_file_path, [])
	if not lines.is_empty():
		await ui.say(lines)
	await ui.fade_to(1.0, 2.0)
	if next_scene.is_empty():
		ui.show_title(D.ENDING_TITLE, 1000.0)
		await get_tree().create_timer(5.0, false).timeout
		get_tree().change_scene_to_file(MENU_SCENE)
		return
	hands.pack_for_travel()
	get_tree().change_scene_to_file(next_scene)


# Те же клавиши, что и в Мире 1, чтобы сцену можно было запускать отдельно (F6).
func _setup_input() -> void:
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("crouch", [KEY_CTRL, KEY_C])
	_add_action("jump", [KEY_SPACE])
	_add_action("interact", [KEY_E])
	_add_action("flashlight", [KEY_F])
	_add_action("inventory", [KEY_TAB, KEY_I])
	_add_action("store_item", [KEY_Q])


func _add_action(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)
