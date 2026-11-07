# Квартира ГГ, начало игры. Стены и мебель лежат в самой сцене, их можно двигать в редакторе.
# Скрипт при запуске добавляет игрока, интерфейс, пролог, вид из окна и выход в Мир 1.
extends "res://scripts/sketches/sketch_base.gd"

const WORLD_1 := "res://scenes/main.tscn"
# Где двор Мира 1 относительно квартиры: окно смотрит на двор с четвёртого этажа дома ГГ,
# стена с окнами совпадает с фасадом дома (z = 24), подъезд почти под окном комнаты.
const YARD_OFFSET := Vector3(2.5, -9.0, -24.0)
const YARD_LAYER := 2
const SMALL_PROP := 0.35   # предметы меньше этого размера (м) теней не отбрасывают
const RoomLightsScript := preload("res://scripts/room_lights.gd")
const SoundsScript := preload("res://scripts/apartment_sounds.gd")
const ChangesScript := preload("res://scripts/apartment_changes.gd")
const GrabbableScript := preload("res://scripts/grabbable.gd")
const HandsScript := preload("res://scripts/hands.gd")
const FixturesScript := preload("res://scripts/apartment_fixtures.gd")

# Выключатели: комната света и узел в сцене. Кухня и ванная в начале игры тёмные.
const SWITCHES := {
	"Комната": "Комната/Выключатель",
	"Кухня": "Кухня/Выключатель",
	"Ванная": "Ванная/Выключатель",
	"Коридор": "Прихожая/Вещи/Выключатель",
}
const DARK_AT_START := ["Кухня", "Ванная"]
const SELF_SWITCHING_ROOMS := ["Комната", "Кухня", "Ванная"]   # где свет один раз щёлкнет сам
const PLAYER_ONLY_LAYER := 32   # сталкивается только с игроком
const BED_TOP := 0.58           # высота матраса, м
const APARTMENT_AREA :=AABB(Vector3(-0.05, -0.1, -0.09), Vector3(8.1, 2.9, 6.14))   # с нишами окон
# Что можно взять: путь, название, помещается ли в инвентарь, мешает ли ходить, что лежит сверху.
const GRABBABLES := [
	["Комната/Стул", "стул", false, true, ["Комната/Следы_жизни/Толстовка_на_стуле"]],
	["Кухня/Табурет", "табурет", false, true, []],
	["Комната/Декор/Кувшин", "кувшин", true, false, []],
	["Комната/Декор/Канцелярия", "канцелярия", true, false, []],
	["Комната/Следы_жизни/Кружка", "кружка", true, false, []],
	["Комната/Следы_жизни/Банка1", "банка", true, false, []],
	["Комната/Следы_жизни/Банка2", "банка", true, false, []],
	["Комната/Следы_жизни/Банка_упавшая", "банка", true, false, []],
	["Комната/Следы_жизни/Пепельница", "пепельница", true, false, ["Комната/Следы_жизни/Окурок"]],
	["Комната/Следы_жизни/Сигареты", "сигареты", true, false, []],
	["Комната/Следы_жизни/Тарелка", "тарелка", true, false, ["Комната/Следы_жизни/Вилка"]],
	["Комната/Вещи/Плеер", "плеер", true, false, []],
	["Кухня/Декор/Кастрюля", "кастрюля", true, false, []],
	["Кухня/Декор/Доска", "разделочная доска", true, false, []],
	["Кухня/Декор/Лимон1", "лимон", true, false, []],
	["Кухня/Декор/Лимон2", "лимон", true, false, []],
	["Кухня/Декор/Ложка", "ложка", true, false, []],
	["Кухня/Декор/Кувшин", "кувшин", true, false, []],
	["Кухня/Следы_жизни/Кружка_на_столе", "кружка", true, false, []],
	["Кухня/Следы_жизни/Кружка_в_мойке", "кружка", true, false, []],
	["Кухня/Следы_жизни/Консервы", "консервы", true, false, []],
	["Кухня/Следы_жизни/Банка_на_столе", "консервы", true, false, []],
	["Кухня/Следы_жизни/Сигареты", "сигареты", true, false, []],
	["Кухня/Следы_жизни/Нож", "нож", true, false, []],
	["Кухня/Следы_жизни/Кусок_хлеба", "кусок хлеба", true, false, []],
	["Кухня/Следы_жизни/Газета", "газета", true, false, []],
	["Кухня/Вещи/Чайник", "чайник", true, false, []],
	["Кухня/Вещи/Сковорода", "сковорода", true, false, []],
	["Кухня/Вещи/Миска", "миска", true, false, []],
	["Кухня/Вещи/Горшок", "горшок", true, false, []],
	["Кухня/Вещи/Бутылка_на_подоконнике1", "бутылка", true, false, []],
	["Кухня/Вещи/Бутылка_на_подоконнике2", "бутылка", true, false, []],
	["Кухня/Вещи/Бутылка_на_подоконнике3", "бутылка", true, false, []],
	["Кухня/Вещи/Масло", "масло", true, false, []],
	["Ванная/Следы_жизни/Хлорка", "хлорка", true, false, []],
	["Ванная/Следы_жизни/Стакан", "стакан", true, false, []],
	["Ванная/Следы_жизни/Мыло", "мыло", true, false, []],
	["Ванная/Следы_жизни/Рулон", "рулон бумаги", true, false, []],
	["Ванная/Вещи/Шампунь1", "шампунь", true, false, []],
	["Ванная/Вещи/Шампунь2", "шампунь", true, false, []],
	["Ванная/Вещи/Шампунь3", "шампунь", true, false, []],
	["Ванная/Вещи/Гель_на_ванне1", "гель", true, false, []],
	["Ванная/Вещи/Гель_на_ванне2", "гель", true, false, []],
	["Прихожая/Следы_жизни/Ключ", "ключи", true, false, ["Прихожая/Следы_жизни/Ключи_брелок", "Прихожая/Следы_жизни/Ключи_кольцо"]],
	["Прихожая/Вещи/Обувная_коробка", "обувная коробка", true, false, ["Прихожая/Вещи/Крышка_коробки"]],
]
const WAKE_SANITY := 0.7
const READ_ZONE := 0.16

var _room_lights: Node
var _sounds: Node
var _changes: Node
var _hands: Node
var _fixtures: Node
var _intro_done := false


func _ready() -> void:
	_setup_sketch()
	_use_night_sky()
	_reset_shadow_atlas()
	environment.ambient_light_color = Color(0.42, 0.45, 0.55)
	environment.ambient_light_energy = 0.3
	_build_yard_view()

	var start: Marker3D = $"Старт"
	player = PlayerScript.new()
	add_child(player)
	player.global_position = start.global_position
	player.rotation.y = start.rotation.y
	player.camera.far = 90.0
	player.camera.add_child(_dust(25, Vector3(5, 2.5, 5)))
	var ambience = SynthScript.new()
	player.camera.add_child(ambience)
	ambience.set_mode("ambient")
	ambience.level = 0.3

	ui = UIScript.new()
	add_child(ui)
	player.prompt_changed.connect(ui.set_prompt)

	_add_exit()
	_setup_light_rooms()
	_add_grabbables()
	_setup_living_apartment()
	_add_switches()
	_add_readables()
	_disable_small_shadows($"Комната")
	_disable_small_shadows($"Кухня")
	_disable_small_shadows($"Ванная")
	_disable_small_shadows($"Прихожая")
	_disable_small_shadows($"Двери")
	var saved := SaveGame.take_continue("apartment")
	if saved.is_empty():
		_intro_scene()
	else:
		_restore(saved)


# Каждая лампа с тенью каждый кадр заново рисует всю геометрию вокруг себя, поэтому свет
# в пустых закрытых комнатах выключен. Размеры комнат совпадают с планом квартиры.
func _setup_light_rooms() -> void:
	var room_door: Node3D = $"Двери/Комната/Дверь"
	var kitchen_door: Node3D = $"Двери/Кухня/Дверь"
	var bath_door: Node3D = $"Двери/Ванная/Дверь"
	var lights = RoomLightsScript.new()
	lights.name = "Свет_по_комнатам"
	lights.player = player
	lights.add_room("Комната", Rect2(0, 0, 5, 4), [$"Комната/Лампа_комнаты", $"Комната/Светильник/Лампочка"], [room_door], [$"Комната/Луна_снаружи"])
	lights.add_room("Кухня", Rect2(5, 0, 3, 4), [$"Кухня/Лампа_кухни", $"Кухня/Светильник/Лампочка"], [kitchen_door], [$"Кухня/Луна_снаружи"])
	lights.add_room("Ванная", Rect2(0, 4, 2.4, 2), [$"Ванная/Лампа_ванной", $"Ванная/Светильник/Лампочка"], [bath_door])
	lights.add_room("Коридор", Rect2(2.4, 4, 5.6, 2), [$"Прихожая/Лампа_прихожей", $"Прихожая/Светильник/Лампочка"], [room_door, kitchen_door, bath_door])
	add_child(lights)
	_room_lights = lights


# Столкновение кровати — коробка в полный рост со спинкой. Игроку это подходит, а вещи
# лежали бы на ней в воздухе, поэтому для них под ней своя низкая коробка по матрас.
func _lower_bed_for_props() -> void:
	var bed: StaticBody3D = $"Комната/Кровать/Коллизия"
	var form: CollisionShape3D = bed.get_node("Форма")
	bed.collision_layer = PLAYER_ONLY_LAYER
	player.collision_mask |= PLAYER_ONLY_LAYER
	var box := BoxShape3D.new()
	box.size = Vector3(form.shape.size.x, BED_TOP, form.shape.size.z)
	var shape := CollisionShape3D.new()
	shape.shape = box
	var mattress := StaticBody3D.new()
	mattress.name = "Матрас_для_вещей"
	mattress.collision_layer = GrabbableScript.PROP_LAYER
	mattress.collision_mask = 0
	mattress.add_child(shape)
	bed.get_parent().add_child(mattress)
	var center := form.global_position
	mattress.global_position = Vector3(center.x, BED_TOP / 2.0, center.z)


func _add_grabbables() -> void:
	_lower_bed_for_props()
	_hands = HandsScript.new()
	_hands.name = "Руки"
	_hands.player = player
	_hands.ui = ui
	add_child(_hands)
	var bodies := []
	for entry in GRABBABLES:
		var extras := []
		for path in entry[4]:
			extras.append(get_node(path))
		var body = GrabbableScript.wrap(get_node(entry[0]), entry[1], entry[2], entry[3], extras, _hands, APARTMENT_AREA)
		body.origin = entry[0]
		bodies.append(body)
	# Столкновения видны физике только с первого её шага.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in bodies:
		body.add_support_if_missing()


func _setup_living_apartment() -> void:
	_sounds = SoundsScript.new()
	_sounds.name = "Звуки_квартиры"
	_sounds.player = player
	_sounds.lights = _room_lights
	add_child(_sounds)
	var fixtures = FixturesScript.new()
	fixtures.name = "Кран_и_холодильник"
	fixtures.root = self
	fixtures.player = player
	fixtures.ui = ui
	fixtures.sounds = _sounds
	add_child(fixtures)
	_fixtures = fixtures
	_changes = ChangesScript.new()
	_changes.name = "Подмены"
	_changes.player = player
	_changes.sounds = _sounds
	_changes.root = self
	_changes.fixtures = fixtures
	_changes.lights = _room_lights
	for room_name in SELF_SWITCHING_ROOMS:
		_changes.switch_positions[room_name] = get_node(SWITCHES[room_name]).global_position
	add_child(_changes)
	_add_examinables()


func _add_examinables() -> void:
	for path in D.EXAMINABLES:
		var entry: Dictionary = D.EXAMINABLES[path]
		var zone = InteractableScript.new()
		zone.setup(entry.size, entry.prompt)
		zone.position = get_node(path).global_position + Vector3(0, entry.get("lift", 0.0), 0)
		zone.used.connect(_examine.bind(entry))
		add_child(zone)


func _examine(entry: Dictionary) -> void:
	player.locked = true
	sanity_meter.value = minf(sanity_meter.value + entry.get("rattles", 0.0), 1.0)
	await ui.say(entry.lines)
	player.locked = false


func _add_switches() -> void:
	for room_name in SWITCHES:
		_room_lights.set_switch(room_name, room_name not in DARK_AT_START)
		var zone = InteractableScript.new()
		zone.setup(Vector3(0.2, 0.2, 0.2), "Щёлкнуть выключателем")
		zone.position = get_node(SWITCHES[room_name]).global_position
		zone.used.connect(func():
			_room_lights.toggle_switch(room_name)
			_sounds.click())
		add_child(zone)


func _add_readables() -> void:
	for path in D.READABLES:
		var entry: Dictionary = D.READABLES[path]
		var item: Node3D = get_node(path)
		var size: float = entry.get("size", READ_ZONE)
		var zone = InteractableScript.new()
		zone.setup(Vector3(size, size, size), entry.prompt)
		zone.position = item.global_position
		zone.used.connect(_read.bind(item, entry.pages))
		add_child(zone)


# Герой берёт предмет в руки: на месте его нет, пока лист перед глазами.
func _read(item: Node3D, pages: Array) -> void:
	player.locked = true
	item.visible = false
	await ui.read_note(pages)
	item.visible = true
	player.locked = false


func _process(delta: float) -> void:
	_changes.sanity = _apply_sanity(delta, not _room_lights.is_player_lit() and not player.locked, 0.0)


func _disable_small_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		var size: Vector3 = node.get_aabb().size * node.global_basis.get_scale()
		if maxf(size.x, maxf(size.y, size.z)) < SMALL_PROP:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_small_shadows(child)


# Вид из окна строит тот же код, что и Мир 1, поэтому двор за окном совпадает со стартом уровня.
func _build_yard_view() -> void:
	var existing := get_children()
	_build_courtyard(false)
	_build_street()
	_build_windows(YARD_OFFSET)
	var yard := Node3D.new()
	yard.name = "Двор_за_окном"
	yard.position = YARD_OFFSET
	add_child(yard)
	nav_region.reparent(yard, false)
	for child in get_children():
		if child != yard and child != nav_region and child not in existing:
			child.reparent(yard, false)
	_isolate_yard(yard)


# Свет двора не должен попадать в квартиру: у него и у домов свой слой.
func _isolate_yard(node: Node) -> void:
	if node is Light3D:
		node.light_cull_mask = 1 << (YARD_LAYER - 1)
	elif node is VisualInstance3D:
		node.layers = 1 << (YARD_LAYER - 1)
	for child in node.get_children():
		_isolate_yard(child)


# Зона у входной двери. Сама дверь лежит в сцене, поэтому зона берёт её положение.
func _add_exit() -> void:
	var door_node: Node3D = $"Коробка/Входная_дверь"
	door = InteractableScript.new()
	door.setup(Vector3(0.4, 2.1, 0.9), "Выйти из квартиры")
	door.position = door_node.global_position
	door.used.connect(_leave)
	add_child(door)


func _intro_scene() -> void:
	player.locked = true
	player.lie_down($"Комната/Осколки_вазы/Осколок2".global_position)
	sanity_meter.value = WAKE_SANITY
	await get_tree().create_timer(0.8).timeout
	# Глаза открываются не сразу: два раза приоткрылись и закрылись, потом открылись.
	await ui.fade_to(0.6, 1.0)
	await ui.fade_to(0.95, 0.5)
	await ui.fade_to(0.4, 0.9)
	await ui.fade_to(0.8, 0.4)
	await ui.fade_to(0.0, 1.8)
	await ui.say(D.PROLOGUE_FLOOR)
	await player.get_up()
	await player.face_point($"Комната/Стол/Экран".global_position, 1.0)
	await ui.say(D.PROLOGUE_MONITOR)
	await player.face_point($"Комната/Декор/Часы".global_position, 1.0)
	await ui.say(D.PROLOGUE_CLOCK)
	player.locked = false
	_intro_done = true
	ui.show_hint("WASD — идти   Shift — бежать   Пробел — прыжок   Ctrl — присесть   E — действие   Tab — инвентарь   F5 — сохранить   Esc — пауза")
	_save()


func _leave() -> void:
	_intro_done = false   # дальше сохраняется уже Мир 1
	door.enabled = false
	player.locked = true
	ui.set_prompt("")
	_hands.stash_held()
	await ui.say(D.PROLOGUE_LEAVE)
	await ui.fade_to(1.0, 1.5)
	_hands.pack_for_travel()
	get_tree().change_scene_to_file(WORLD_1)


# ---------------------------------------------------------------- сохранение

func can_save() -> bool:
	return _intro_done and not player.locked and not ui.talking and not get_tree().paused


func _world_state() -> Dictionary:
	var switches := {}
	for room_name in _room_lights.rooms:
		switches[room_name] = _room_lights.rooms[room_name].switched_on
	return {
		"world": "apartment",
		"sanity": sanity_meter.value,
		"switches": switches,
		"water_on": _fixtures.water_on,
		"fridge_open": _fixtures.fridge_open,
		"clock_running": _changes._clock_running,
		"player_position": player.global_position,
		"player_yaw": player.rotation.y,
		"camera_pitch": player.camera.rotation.x,
	}


# Продолжить в квартире: пролог уже был, герой стоит там, где сохранился.
func _restore(w: Dictionary) -> void:
	player.locked = true
	# Вещи становятся телами и получают подставки только через пару кадров физики.
	for i in 3:
		await get_tree().physics_frame
	sanity_meter.value = clampf(float(w.get("sanity", WAKE_SANITY)), 0.0, 1.0)
	var switches: Dictionary = w.get("switches", {})
	for room_name in switches:
		if _room_lights.rooms.has(room_name):
			_room_lights.set_switch(room_name, bool(switches[room_name]))
	if w.get("water_on", false):
		_fixtures.set_water(true)
	if w.get("fridge_open", false):
		_fixtures.set_fridge(true)
	_changes._clock_running = w.get("clock_running", false)
	_place_player(w)
	SaveGame.apply_sections()
	await ui.fade_to(0.0, 1.5)
	player.locked = false
	_intro_done = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.show_hint("Продолжаем с сохранения.", 3.0)
