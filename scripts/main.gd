# Прототип Мира 1 «Окраина города».
# Этот скрипт строит уровень из простых блоков (без моделей) и ведёт сюжет по шагам.
extends Node3D

const D := preload("res://data/dialogues.gd")
const PlayerScript := preload("res://scripts/player.gd")
const ShadowScript := preload("res://scripts/shadow.gd")
const PhoneScript := preload("res://scripts/phone.gd")
const UIScript := preload("res://scripts/ui.gd")
const SynthScript := preload("res://scripts/synth.gd")
const WallShadowScript := preload("res://scripts/wall_shadow.gd")
const InteractableScript := preload("res://scripts/interactable.gd")
const HandPhoneScript := preload("res://scripts/hand_phone.gd")
const PS1_SHADER := preload("res://shaders/ps1.gdshader")
const WINDOW_SHADER := preload("res://shaders/window.gdshader")
const FILM_SHADER := preload("res://shaders/film.gdshader")

# Пиксельные текстуры (лежат в textures/, сгенерированы скриптом tools/gen_textures.py).
const T_CONCRETE := preload("res://textures/concrete_panel.png")
const T_ASPHALT := preload("res://textures/asphalt.png")
const T_RUST := preload("res://textures/rust_metal.png")
const T_WOOD := preload("res://textures/wood.png")
const T_BRICK := preload("res://textures/brick.png")
const T_TILES := preload("res://textures/tiles_checker.png")
const T_PLASTER := preload("res://textures/plaster.png")

const FOG_COLOR := Color(0.12, 0.13, 0.15)
const WALL_COLOR := Color(0.78, 0.78, 0.8)
const LAMP_COLOR := Color(1.0, 0.66, 0.34)
const HALL := Vector3(88, 0, 120)

const START_POINT := Vector3(0, 0, 21)
const MANSION_DOOR := Vector3(76.6, 0, -48)
const GRAFFITI := Vector3(-23.95, 2.2, -12)
const GIRL_PATH := [
	Vector3(20, 0, -22), Vector3(26, 0, -40), Vector3(16, 0, -62),
	Vector3(30, 0, -80), Vector3(24, 0, -96),
]

var nav_region: NavigationRegion3D
var player: CharacterBody3D
var shadow: CharacterBody3D
var ui: CanvasLayer
var drone
var beeper
var girl: Node3D
var bench_phone: Node3D
var lot_phone: Node3D
var door: Area3D
var mansion_windows: MultiMeshInstance3D
var porch_light: OmniLight3D
var environment: Environment
var hall_phone: Node3D
var hand_phone: Node3D

var checkpoint := START_POINT
var shadow_spawn := Vector3(-20, 0, -16)
var stage := "intro"
var busy := false
var girl_index := 0
var has_phone := false
var lamp_points: Array[Vector3] = []
var idle_time := 0.0
var shadow_seen := false
var graffiti_seen := false

var _materials := {}
var _windows := {0: [], 1: [], 2: []}


func _ready() -> void:
	randomize()
	_setup_input()
	_setup_environment()

	nav_region = NavigationRegion3D.new()
	add_child(nav_region)
	_build_courtyard()
	_build_street()
	_build_lot()
	_build_hall()
	_build_windows()
	_bake_navigation()

	player = PlayerScript.new()
	add_child(player)
	player.global_position = START_POINT

	ui = UIScript.new()
	add_child(ui)
	player.prompt_changed.connect(ui.set_prompt)

	hand_phone = HandPhoneScript.new()
	hand_phone.visible = false
	player.camera.add_child(hand_phone)
	hand_phone.battery_low.connect(func(): _comment(D.SMS_LOW_BATTERY))
	ui.sms_shown.connect(func(): if has_phone: hand_phone.show_message())

	drone = SynthScript.new()
	beeper = SynthScript.new()
	player.camera.add_child(drone)
	player.camera.add_child(beeper)
	drone.set_mode("drone")
	drone.level = 0.0
	ui.sms_shown.connect(func(): beeper.set_mode("beep"))

	shadow = ShadowScript.new()
	add_child(shadow)
	shadow.target = player
	shadow.caught.connect(_on_caught)

	_spawn_wall_shadows()
	_start()


func _process(delta: float) -> void:
	var near: float = shadow.closeness()
	ui.set_noise(near * near * 0.8)
	drone.level = near * near
	_update_light_rules()
	_update_comments(delta)

	match stage:
		"girl":
			_update_girl()
		"after_dead_end":
			if player.global_position.distance_to(GIRL_PATH[-1]) > 9.0 and not busy:
				_girl_talk()
		"to_door":
			if player.global_position.distance_to(MANSION_DOOR) < 12.0 and not busy:
				stage = "at_door"
				ui.say(D.DOOR_SMS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flashlight") and has_phone and not player.locked:
		hand_phone.toggle()


# Тень не любит свет: в луче фонарика почти замирает, а под горящим фонарём
# игрока не трогает и ждёт в темноте.
func _update_light_rules() -> void:
	if has_phone:
		ui.set_battery(hand_phone.battery, hand_phone.light_on)
	shadow.slowed = has_phone and hand_phone.lights_up(shadow.global_position + Vector3(0, 1.0, 0))
	var safe := false
	for p in lamp_points:
		if Vector2(p.x - player.global_position.x, p.z - player.global_position.z).length() < 4.5:
			safe = true
			break
	shadow.waiting = safe


# Неизвестный комментирует происходящее, как зритель в чате стрима.
func _update_comments(delta: float) -> void:
	if busy or ui.talking or not shadow.active:
		idle_time = 0.0
		return
	var cam: Camera3D = player.camera
	var forward := -cam.global_basis.z
	if not shadow_seen:
		var to: Vector3 = shadow.global_position + Vector3(0, 1.0, 0) - cam.global_position
		if to.length() < 20.0 and forward.dot(to.normalized()) > 0.85:
			shadow_seen = true
			_comment(D.SMS_FIRST_SHADOW)
			return
	if not graffiti_seen:
		var to_g := GRAFFITI - cam.global_position
		if to_g.length() < 8.0 and forward.dot(to_g.normalized()) > 0.8:
			graffiti_seen = true
			_comment(D.SMS_GRAFFITI)
			return
	if player.velocity.length() < 0.2:
		idle_time += delta
		if idle_time > 25.0:
			idle_time = -60.0   # не чаще раза в полторы минуты
			_comment(D.SMS_IDLE)
	elif idle_time > 0.0:
		idle_time = 0.0


func _comment(text: String) -> void:
	if not ui.talking:
		ui.say([{"sms": text}])


# ---------------------------------------------------------------- сюжет

func _start() -> void:
	player.locked = true
	await get_tree().create_timer(0.8).timeout
	await ui.say(D.PROLOGUE)
	ui.show_title("МИР 1. ОДИНОЧЕСТВО\nОкраина города")
	await ui.fade_to(0.0, 3.0)
	player.locked = false
	ui.show_hint("WASD — идти   Shift — бежать   E — действие   Esc — показать курсор")
	stage = "explore"
	bench_phone.ringing = true


func _on_bench_phone() -> void:
	bench_phone.ringing = false
	await _scene(D.BENCH_CALL, bench_phone.global_position)
	bench_phone.visible = false
	has_phone = true
	hand_phone.visible = true
	ui.show_hint("F — фонарик на телефоне. Батарея садится, заряжать от розеток. Под фонарями Тень не подходит.", 10.0)
	checkpoint = bench_phone.global_position + Vector3(0, -0.5, 1.5)
	shadow.activate(_nav_point(shadow_spawn))
	girl.position = GIRL_PATH[0]
	girl.visible = true
	girl_index = 0
	stage = "girl"


func _update_girl() -> void:
	girl.look_at(Vector3(player.global_position.x, girl.global_position.y, player.global_position.z))
	var d := player.global_position.distance_to(girl.global_position)
	if girl_index < GIRL_PATH.size() - 1:
		if d < 9.0 and girl.visible:
			# Она будто телепортируется дальше по улице.
			girl.visible = false
			girl_index += 1
			await get_tree().create_timer(0.5).timeout
			girl.position = GIRL_PATH[girl_index]
			girl.visible = true
	elif d < 3.5 and not busy:
		_dead_end()


func _dead_end() -> void:
	stage = "dead_end"
	girl.visible = false
	await _scene(D.DEAD_END_1, girl.global_position)
	busy = true
	player.locked = true
	shadow.paused = true
	await player.face_point(player.global_position + player.global_basis.z * 5.0, 0.35)
	await ui.say(D.DEAD_END_2)
	player.locked = false
	shadow.paused = false
	busy = false
	stage = "after_dead_end"
	await get_tree().create_timer(2.0).timeout
	_comment(D.SMS_AFTER_DEAD_END)


func _girl_talk() -> void:
	stage = "girl_talk"
	var front := player.global_position - player.global_basis.z * 3.0
	girl.position = Vector3(front.x, 0, front.z)
	girl.visible = true
	girl.look_at(Vector3(player.global_position.x, 0, player.global_position.z))
	busy = true
	player.locked = true
	shadow.paused = true
	await ui.say(D.GIRL_TALK.slice(0, 2))
	await player.face_point(MANSION_DOOR)
	await ui.say(D.GIRL_TALK.slice(2))
	girl.visible = false
	_light_mansion()
	player.locked = false
	shadow.paused = false
	busy = false
	lot_phone.ringing = true
	stage = "to_lot"


func _on_lot_phone() -> void:
	lot_phone.ringing = false
	await _scene(D.LOT_CALL, lot_phone.global_position)
	checkpoint = lot_phone.global_position + Vector3(-1.5, -0.55, 0)
	shadow_spawn = Vector3(24, 0, -92)
	door.enabled = true
	stage = "to_door"


func _on_door() -> void:
	if busy:
		return
	if door.prompt == "Прочитать записку":
		await _scene(D.NOTE, MANSION_DOOR + Vector3(0, 1.5, 0))
		door.prompt = "Войти"
		door.enabled = true
		return
	busy = true
	door.enabled = false
	player.locked = true
	shadow.paused = true
	stage = "hall"
	await ui.fade_to(1.0, 1.5)
	shadow.active = false
	shadow.visible = false
	_set_interior_lighting()
	player.global_position = HALL + Vector3(0, 0, 9)
	player.rotation.y = 0.0
	player.camera.rotation.x = 0.0
	await get_tree().create_timer(0.5).timeout
	await ui.fade_to(0.0, 2.0)
	await ui.say(D.MANSION.slice(0, 1))
	player.locked = false
	busy = false
	hall_phone.ringing = true


func _on_hall_phone() -> void:
	hall_phone.ringing = false
	await _scene(D.MANSION.slice(1), hall_phone.global_position)
	busy = true
	player.locked = true
	stage = "end"
	await ui.fade_to(1.0, 2.5)
	ui.show_title("Конец прототипа\nПродолжение следует", 1000.0)


# Сценка: игрок замирает, Тень тоже, идут реплики.
func _scene(lines: Array, look_at_point: Vector3) -> void:
	busy = true
	player.locked = true
	shadow.paused = true
	ui.set_prompt("")
	await player.face_point(look_at_point, 0.4)
	await ui.say(lines)
	player.locked = false
	shadow.paused = false
	busy = false


func _on_caught() -> void:
	if busy:
		return
	busy = true
	player.locked = true
	shadow.paused = true
	await ui.fade_to(1.0, 0.4)
	player.global_position = checkpoint
	player.velocity = Vector3.ZERO
	shadow.global_position = _nav_point(shadow_spawn)
	await get_tree().create_timer(1.0).timeout
	await ui.fade_to(0.0, 1.0)
	player.locked = false
	shadow.paused = false
	busy = false
	ui.say([{"sms": D.CAUGHT_SMS.pick_random()}])


# Ближайшая к точке позиция на навигационной сетке (там, где Тень может ходить).
func _nav_point(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, p)


func _light_mansion() -> void:
	var m := ShaderMaterial.new()
	m.shader = WINDOW_SHADER
	m.set_shader_parameter("mode", 1)
	m.set_shader_parameter("color", Color(1.0, 0.85, 0.6))
	mansion_windows.material_override = m
	porch_light.visible = true


# ---------------------------------------------------------------- уровень

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


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 1.1
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = 0.06
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	environment = env

	# Плёночный фильтр поверх 3D. Интерфейс (слой 1) рисуется уже поверх него.
	var film_layer := CanvasLayer.new()
	film_layer.layer = 0
	var film := ColorRect.new()
	film.set_anchors_preset(Control.PRESET_FULL_RECT)
	film.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var film_mat := ShaderMaterial.new()
	film_mat.shader = FILM_SHADER
	film.material = film_mat
	film_layer.add_child(film)
	add_child(film_layer)


# Свет и туман внутри особняка: светло, чисто, почти без тумана.
func _set_interior_lighting() -> void:
	environment.background_color = Color(0.85, 0.82, 0.74)
	environment.fog_density = 0.008
	environment.fog_light_color = Color(0.85, 0.82, 0.74)
	environment.ambient_light_color = Color(1.0, 0.95, 0.85)
	environment.ambient_light_energy = 0.6


func _material(color: Color, emission := Color.BLACK, tex: Texture2D = null, scale := 0.333) -> ShaderMaterial:
	var key := [color, emission, tex, scale]
	if not _materials.has(key):
		var m := ShaderMaterial.new()
		m.shader = PS1_SHADER
		m.set_shader_parameter("albedo", color)
		m.set_shader_parameter("emission", emission)
		if tex != null:
			m.set_shader_parameter("tex", tex)
		m.set_shader_parameter("tex_scale", scale)
		_materials[key] = m
	return _materials[key]


# Коробка с коллизией. Из таких собран весь уровень.
func _box(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, tex: Texture2D = null, scale := 0.333) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(color, Color.BLACK, tex, scale)
	mi.position = pos
	mi.rotation = rot
	nav_region.add_child(mi)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	mi.add_child(body)
	return mi


func _wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = pos
	nav_region.add_child(body)


# Панелька: коробка + окна на всех четырёх сторонах.
func _building(center: Vector3, size: Vector3) -> void:
	_box(center + Vector3(0, size.y / 2, 0), size, WALL_COLOR, Vector3.ZERO, T_CONCRETE)
	var floors := int(size.y / 3.0)
	var half := size / 2.0
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), size.x, half.z, 0.0],
		[Vector3(0, 0, -1), Vector3(1, 0, 0), size.x, half.z, PI],
		[Vector3(1, 0, 0), Vector3(0, 0, 1), size.z, half.x, PI / 2],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), size.z, half.x, -PI / 2],
	]
	for face in faces:
		var normal: Vector3 = face[0]
		var along: Vector3 = face[1]
		var length: float = face[2]
		var depth: float = face[3]
		var cols := int((length - 2.0) / 3.5)
		for f in floors:
			for c in cols:
				var offset := -length / 2.0 + 2.0 + c * 3.5 + 0.75
				var pos := center + normal * (depth + 0.03) + along * offset + Vector3(0, 1.8 + f * 3.0, 0)
				var r := randf()
				var mode := 1 if r < 0.12 else (2 if r < 0.15 else 0)
				_windows[mode].append(Transform3D(Basis(Vector3.UP, face[4]), pos))


func _build_windows() -> void:
	var colors := {0: Color(0.08, 0.09, 0.11), 1: Color(1.0, 0.78, 0.5), 2: Color(0.45, 0.6, 1.0)}
	for mode in _windows:
		var mmi := _window_multimesh(_windows[mode])
		var m := ShaderMaterial.new()
		m.shader = WINDOW_SHADER
		m.set_shader_parameter("mode", mode)
		m.set_shader_parameter("color", colors[mode])
		mmi.material_override = m
		add_child(mmi)


# Все окна одного типа рисуются одним вызовом: так город почти ничего не стоит видеокарте.
func _window_multimesh(transforms: Array) -> MultiMeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.5)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _lamp(pos: Vector3) -> OmniLight3D:
	_box(Vector3(pos.x, pos.y / 2, pos.z), Vector3(0.15, pos.y, 0.15), Color(0.5, 0.5, 0.5), Vector3.ZERO, T_RUST, 1.0)
	_box(pos + Vector3(0, 0.15, 0), Vector3(0.6, 0.12, 0.6), Color(0.35, 0.35, 0.35), Vector3.ZERO, T_RUST, 1.0)
	var bulb := MeshInstance3D.new()
	var bulb_mesh := BoxMesh.new()
	bulb_mesh.size = Vector3(0.2, 0.12, 0.2)
	bulb.mesh = bulb_mesh
	bulb.position = pos + Vector3(0, 0.03, 0)
	bulb.material_override = _material(Color.BLACK, LAMP_COLOR * 2.0)
	add_child(bulb)
	lamp_points.append(pos)
	var light := OmniLight3D.new()
	light.position = pos - Vector3(0, 0.2, 0)
	light.omni_range = 15.0
	light.light_energy = 6.0
	light.light_color = LAMP_COLOR
	add_child(light)
	return light


# «Пропал человек»: листок с фото, лицо на котором стёрто от того, что его часто трогали.
func _poster(pos: Vector3, yaw: float, tilt := 0.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(0, yaw, tilt)
	add_child(root)
	var paper := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.58)
	paper.mesh = quad
	paper.material_override = _material(Color(0.88, 0.86, 0.8), Color(0.08, 0.08, 0.07))
	root.add_child(paper)
	var photo := MeshInstance3D.new()
	var photo_quad := QuadMesh.new()
	photo_quad.size = Vector2(0.22, 0.24)
	photo.mesh = photo_quad
	photo.position = Vector3(0, 0.04, 0.003)
	photo.material_override = _material(Color(0.35, 0.33, 0.32))
	root.add_child(photo)
	var face := MeshInstance3D.new()
	var face_quad := QuadMesh.new()
	face_quad.size = Vector2(0.1, 0.12)
	face.mesh = face_quad
	face.position = Vector3(0, 0.07, 0.005)
	face.material_override = _material(Color(0.72, 0.7, 0.66))
	root.add_child(face)
	for line in [["ПРОПАЛ", Vector3(0, 0.22, 0.004), 40], ["ЧЕЛОВЕК", Vector3(0, -0.13, 0.004), 28], ["…рост 178, на вид 20 лет…", Vector3(0, -0.21, 0.004), 14]]:
		var l := Label3D.new()
		l.text = line[0]
		l.font_size = line[2]
		l.pixel_size = 0.003
		l.modulate = Color(0.12, 0.1, 0.1)
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.position = line[1]
		root.add_child(l)


# Розетка, от которой можно зарядить найденный телефон.
func _socket(pos: Vector3, yaw: float) -> void:
	var plate := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.03)
	plate.mesh = box
	plate.position = pos
	plate.rotation.y = yaw
	plate.material_override = _material(Color(0.85, 0.83, 0.78), Color(0.06, 0.05, 0.03))
	add_child(plate)
	var area = InteractableScript.new()
	area.setup(Vector3(0.6, 0.6, 0.6), "Зарядить телефон")
	area.position = pos
	area.used.connect(func():
		if has_phone:
			hand_phone.charge()
			ui.show_hint("Телефон заряжен.", 3.0)
		else:
			ui.show_hint("Заряжать нечего.", 3.0))
	add_child(area)


func _car(pos: Vector3, yaw: float, color: Color) -> void:
	_box(pos + Vector3(0, 0.55, 0), Vector3(1.8, 0.8, 4.2), color, Vector3(0, yaw, 0))
	_box(pos + Vector3(0, 1.2, 0).rotated(Vector3.UP, yaw), Vector3(1.6, 0.6, 2.2), color.darkened(0.2), Vector3(0, yaw, 0))


func _build_courtyard() -> void:
	# Земля кусками по 30 м: в лёгком рендере у каждого куска свои ближайшие фонари.
	for gx in range(-45, 115, 30):
		for gz in range(-120, 45, 30):
			_box(Vector3(gx + 15, -0.5, gz + 15), Vector3(30, 1, 30), Color(0.9, 0.9, 0.9), Vector3.ZERO, T_ASPHALT, 0.5)
	_building(Vector3(0, 0, 30), Vector3(60, 27, 12))
	_building(Vector3(-10, 0, -30), Vector3(52, 27, 12))
	_building(Vector3(-30, 0, 0), Vector3(12, 27, 48))
	_building(Vector3(30, 0, 6), Vector3(12, 27, 36))
	# дверь подъезда, из которого вышел ГГ
	_box(Vector3(0, 1.2, 23.95), Vector3(1.4, 2.4, 0.1), Color(0.6, 0.75, 0.7), Vector3.ZERO, T_RUST, 1.0)
	_box(Vector3(0, 2.6, 23.4), Vector3(2.4, 0.15, 1.3), Color(0.35, 0.35, 0.35))

	# беседка, где всегда сидели алкаши
	var g := Vector3(-12, 0, 4)
	for corner in [Vector3(-1.6, 0, -1.6), Vector3(1.6, 0, -1.6), Vector3(-1.6, 0, 1.6), Vector3(1.6, 0, 1.6)]:
		_box(g + corner + Vector3(0, 1.2, 0), Vector3(0.15, 2.4, 0.15), Color(0.8, 0.8, 0.8), Vector3.ZERO, T_WOOD, 1.0)
	_box(g + Vector3(0, 2.5, 0), Vector3(3.8, 0.15, 3.8), Color(0.7, 0.8, 0.75), Vector3.ZERO, T_RUST, 1.0)
	_box(g + Vector3(0, 0.45, -1.3), Vector3(3.0, 0.1, 0.5), Color(0.8, 0.8, 0.8), Vector3.ZERO, T_WOOD, 1.0)
	_box(g + Vector3(0, 0.75, 0), Vector3(1.2, 0.08, 0.8), Color(0.8, 0.8, 0.8), Vector3.ZERO, T_WOOD, 1.0)
	_box(g + Vector3(0.3, 0.88, 0.1), Vector3(0.08, 0.25, 0.08), Color(0.2, 0.35, 0.2))

	# детская площадка
	_box(Vector3(10, 0.15, -8), Vector3(3, 0.3, 3), Color(0.5, 0.45, 0.32))
	_box(Vector3(8.5, 1.1, -13), Vector3(0.1, 2.2, 0.1), Color(0.9, 0.6, 0.55), Vector3.ZERO, T_RUST, 1.0)
	_box(Vector3(11.5, 1.1, -13), Vector3(0.1, 2.2, 0.1), Color(0.9, 0.6, 0.55), Vector3.ZERO, T_RUST, 1.0)
	_box(Vector3(10, 2.2, -13), Vector3(3.2, 0.1, 0.1), Color(0.9, 0.6, 0.55), Vector3.ZERO, T_RUST, 1.0)
	_box(Vector3(10, 0.5, -13), Vector3(0.6, 0.05, 0.3), Color(0.2, 0.3, 0.5))
	_box(Vector3(14, 1.0, -6), Vector3(0.8, 0.1, 3.5), Color(0.2, 0.35, 0.5), Vector3(0.5, 0, 0))

	# скамейка со звонящим телефоном
	_box(Vector3(4, 0.45, 14), Vector3(1.8, 0.08, 0.5), Color(0.9, 0.9, 0.9), Vector3.ZERO, T_WOOD, 1.0)
	_box(Vector3(4, 0.75, 14.25), Vector3(1.8, 0.4, 0.06), Color(0.9, 0.9, 0.9), Vector3.ZERO, T_WOOD, 1.0)
	_box(Vector3(3.3, 0.2, 14), Vector3(0.1, 0.4, 0.4), Color(0.2, 0.2, 0.2))
	_box(Vector3(4.7, 0.2, 14), Vector3(0.1, 0.4, 0.4), Color(0.2, 0.2, 0.2))
	bench_phone = PhoneScript.new()
	bench_phone.position = Vector3(4.3, 0.5, 14)
	bench_phone.rotation.y = 0.4
	add_child(bench_phone)
	bench_phone.answered.connect(_on_bench_phone)

	_car(Vector3(-18, 0, 18), 0.1, Color(0.35, 0.12, 0.1))
	_car(Vector3(18, 0, 16), -0.05, Color(0.75, 0.75, 0.72))
	_box(Vector3(-20, 0.7, -18), Vector3(1.6, 1.4, 1.2), Color(0.8, 0.9, 0.8), Vector3.ZERO, T_RUST, 1.0)
	_box(Vector3(-18.2, 0.7, -18), Vector3(1.6, 1.4, 1.2), Color(0.8, 0.9, 0.8), Vector3.ZERO, T_RUST, 1.0)

	_lamp(Vector3(-14, 4.5, 10))
	_lamp(Vector3(12, 4.5, -16))
	_lamp(Vector3(8, 4.5, 18))

	# граффити на торце дома у гаражей; ответ на него будет в Мире 2
	var graffiti := Label3D.new()
	graffiti.text = "ТЫ ГДЕ?"
	graffiti.font_size = 96
	graffiti.pixel_size = 0.012
	graffiti.modulate = Color(0.75, 0.12, 0.1)
	graffiti.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	graffiti.position = GRAFFITI
	graffiti.rotation.y = PI / 2
	graffiti.rotation.z = 0.06
	add_child(graffiti)

	# объявления о пропаже: на фото ГГ, лицо затёрто
	_poster(Vector3(-1.3, 1.6, 23.93), PI)
	_poster(Vector3(1.25, 1.5, 23.93), PI, 0.08)
	_poster(Vector3(-23.93, 1.6, 6), PI / 2)
	_socket(Vector3(1.8, 0.45, 23.93), PI)


func _build_street() -> void:
	_building(Vector3(6, 0, -68), Vector3(12, 27, 64))
	_building(Vector3(42, 0, -27), Vector3(12, 27, 30))
	_building(Vector3(42, 0, -77), Vector3(12, 27, 46))
	_building(Vector3(24, 0, -106), Vector3(36, 27, 12))  # тупик

	_car(Vector3(14.5, 0, -50), 0.0, Color(0.2, 0.25, 0.35))
	_car(Vector3(33.5, 0, -70), PI, Color(0.3, 0.3, 0.28))
	_car(Vector3(15, 0, -86), 0.08, Color(0.45, 0.4, 0.2))

	_lamp(Vector3(24, 4.5, -40))
	_lamp(Vector3(24, 4.5, -72))
	_lamp(Vector3(24, 4.5, -97))
	_poster(Vector3(12.03, 1.6, -44), PI / 2)
	_poster(Vector3(12.03, 1.5, -62), PI / 2, -0.1)
	_poster(Vector3(35.97, 1.6, -58), -PI / 2, 0.05)
	_poster(Vector3(35.97, 1.55, -85), -PI / 2)
	_poster(Vector3(18, 1.6, -99.97), 0.0, 0.1)
	_socket(Vector3(12.03, 0.45, -70), -PI / 2)

	# Девушка: бледная фигура в тумане.
	girl = Node3D.new()
	girl.visible = false
	add_child(girl)
	var figure := MeshInstance3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.24
	body.height = 1.65
	figure.mesh = body
	figure.position.y = 0.83
	figure.material_override = _material(Color(0.85, 0.85, 0.88), Color(0.25, 0.25, 0.28))
	girl.add_child(figure)


func _build_lot() -> void:
	_building(Vector3(79, 0, -12), Vector3(62, 27, 12))
	_building(Vector3(79, 0, -86), Vector3(62, 27, 12))
	_wall(Vector3(36, 20, -116), Vector3(160, 40, 4))
	_wall(Vector3(36, 20, 40), Vector3(160, 40, 4))
	_wall(Vector3(-40, 20, -38), Vector3(4, 40, 160))
	_wall(Vector3(112, 20, -38), Vector3(4, 40, 160))

	# бетонный блок с телефоном у прохода на пустырь
	_box(Vector3(42, 0.25, -48), Vector3(0.8, 0.5, 0.8), Color(0.75, 0.75, 0.75), Vector3.ZERO, T_CONCRETE, 1.0)
	lot_phone = PhoneScript.new()
	lot_phone.position = Vector3(42, 0.51, -48)
	add_child(lot_phone)
	lot_phone.answered.connect(_on_lot_phone)

	# особняк: снаружи обычный, внутри слишком идеальный
	_box(Vector3(88, 4, -48), Vector3(22, 8, 16), Color(0.85, 0.8, 0.78), Vector3.ZERO, T_BRICK, 0.5)
	_box(Vector3(88, 8.6, -48), Vector3(23, 1.2, 17), Color(0.3, 0.2, 0.18))
	_box(Vector3(76.9, 1.2, -48), Vector3(0.2, 2.4, 1.6), Color(0.6, 0.5, 0.45), Vector3.ZERO, T_WOOD, 1.0)
	_box(Vector3(75.5, 0.15, -48), Vector3(2.5, 0.3, 3), Color(0.7, 0.7, 0.7), Vector3.ZERO, T_CONCRETE, 1.0)

	var note := MeshInstance3D.new()
	var paper := QuadMesh.new()
	paper.size = Vector2(0.25, 0.32)
	note.mesh = paper
	note.position = Vector3(76.78, 1.45, -48)
	note.rotation.y = -PI / 2
	note.material_override = _material(Color(0.9, 0.9, 0.85), Color(0.2, 0.2, 0.2))
	add_child(note)

	door = InteractableScript.new()
	door.setup(Vector3(0.6, 2.4, 1.8), "Прочитать записку")
	door.position = Vector3(76.6, 1.2, -48)
	door.enabled = false
	door.used.connect(_on_door)
	add_child(door)

	var transforms := []
	for floor_y in [2.2, 5.6]:
		for z in [-54.0, -51.0, -45.0, -42.0]:
			transforms.append(Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(76.97, floor_y, z)))
	mansion_windows = _window_multimesh(transforms)
	var dark := ShaderMaterial.new()
	dark.shader = WINDOW_SHADER
	dark.set_shader_parameter("color", Color(0.08, 0.09, 0.11))
	mansion_windows.material_override = dark
	add_child(mansion_windows)

	_lamp(Vector3(60, 4.5, -48))
	porch_light = OmniLight3D.new()
	porch_light.position = Vector3(75.5, 3.0, -48)
	porch_light.omni_range = 10.0
	porch_light.light_energy = 2.0
	porch_light.light_color = LAMP_COLOR
	porch_light.visible = false
	add_child(porch_light)


# Холл особняка: чисто, светло и слишком идеально по сравнению с городом.
func _build_hall() -> void:
	var c := HALL
	var white := Color(1, 1, 1)
	_box(c + Vector3(0, -0.5, 0), Vector3(18, 1, 22), white, Vector3.ZERO, T_TILES, 1.0)
	_box(c + Vector3(0, 7.5, 0), Vector3(18, 1, 22), Color(0.95, 0.93, 0.88))
	_box(c + Vector3(-9.5, 3.5, 0), Vector3(1, 7, 22), white, Vector3.ZERO, T_PLASTER)
	_box(c + Vector3(9.5, 3.5, 0), Vector3(1, 7, 22), white, Vector3.ZERO, T_PLASTER)
	_box(c + Vector3(0, 3.5, -11.5), Vector3(18, 7, 1), white, Vector3.ZERO, T_PLASTER)
	_box(c + Vector3(0, 3.5, 11.5), Vector3(18, 7, 1), white, Vector3.ZERO, T_PLASTER)

	# парадная лестница по центру и балкон второго этажа
	for i in 12:
		_box(c + Vector3(0, 0.15 + i * 0.3, -2.0 - i * 0.55), Vector3(4, 0.3, 0.55), Color(0.85, 0.75, 0.65), Vector3.ZERO, T_WOOD, 1.0)
	_box(c + Vector3(0, 3.55, -9.5), Vector3(18, 0.3, 3), Color(0.85, 0.75, 0.65), Vector3.ZERO, T_WOOD, 1.0)
	_box(c + Vector3(-2.1, 2.4, -5.0), Vector3(0.1, 0.12, 6.9), Color(0.7, 0.6, 0.5), Vector3(0.5, 0, 0), T_WOOD, 1.0)
	_box(c + Vector3(2.1, 2.4, -5.0), Vector3(0.1, 0.12, 6.9), Color(0.7, 0.6, 0.5), Vector3(0.5, 0, 0), T_WOOD, 1.0)

	# двери в крылья особняка
	for side in [-1, 1]:
		for z in [-3.0, 4.0]:
			_box(c + Vector3(side * 8.95, 1.3, z), Vector3(0.15, 2.6, 1.4), Color(0.75, 0.6, 0.5), Vector3.ZERO, T_WOOD, 1.0)

	# ковёр и тумбочка с телефоном
	_box(c + Vector3(0, 0.01, 4), Vector3(3, 0.02, 9), Color(0.55, 0.12, 0.14))
	_box(c + Vector3(5, 0.45, 6), Vector3(1.2, 0.9, 0.6), Color(0.8, 0.7, 0.6), Vector3.ZERO, T_WOOD, 1.0)
	hall_phone = PhoneScript.new()
	hall_phone.position = c + Vector3(5, 0.91, 6)
	hall_phone.rotation.y = -0.3
	add_child(hall_phone)
	hall_phone.area.prompt = "Прослушать голосовое"
	hall_phone.answered.connect(_on_hall_phone)

	# люстра
	var chandelier := MeshInstance3D.new()
	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(1.2, 0.4, 1.2)
	chandelier.mesh = lamp_mesh
	chandelier.position = c + Vector3(0, 6.2, 2)
	chandelier.material_override = _material(Color.BLACK, Color(1.0, 0.9, 0.7) * 1.5)
	add_child(chandelier)
	for pos in [Vector3(0, 5.5, 2), Vector3(0, 5.5, -6)]:
		var light := OmniLight3D.new()
		light.position = c + pos
		light.omni_range = 16.0
		light.light_energy = 1.4
		light.light_color = Color(1.0, 0.92, 0.78)
		add_child(light)


func _spawn_wall_shadows() -> void:
	# [точка на стене, поворот, направление вдоль стены]
	var spots := [
		[Vector3(-18, 1, -23.97), 0.0, Vector3.RIGHT],
		[Vector3(-6, 1, -23.97), 0.0, Vector3.RIGHT],
		[Vector3(6, 1, -23.97), 0.0, Vector3.RIGHT],
		[Vector3(-23.97, 1, -10), PI / 2, Vector3.BACK],
		[Vector3(-23.97, 1, 8), PI / 2, Vector3.BACK],
		[Vector3(23.97, 1, 0), -PI / 2, Vector3.BACK],
		[Vector3(23.97, 1, 15), -PI / 2, Vector3.BACK],
		[Vector3(12.03, 1, -45), PI / 2, Vector3.BACK],
		[Vector3(12.03, 1, -65), PI / 2, Vector3.BACK],
		[Vector3(12.03, 1, -88), PI / 2, Vector3.BACK],
		[Vector3(35.97, 1, -62), -PI / 2, Vector3.BACK],
		[Vector3(35.97, 1, -80), -PI / 2, Vector3.BACK],
		[Vector3(18, 1, -99.97), 0.0, Vector3.RIGHT],
		[Vector3(30, 1, -99.97), 0.0, Vector3.RIGHT],
	]
	for spot in spots:
		var s = WallShadowScript.new()
		s.position = spot[0]
		s.rotation.y = spot[1]
		s.tangent = spot[2]
		s.watcher = player.camera
		add_child(s)


func _bake_navigation() -> void:
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.5)
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	nav.agent_radius = 0.5
	nav.agent_height = 2.0
	nav.agent_max_climb = 0.25
	nav_region.navigation_mesh = nav
	nav_region.bake_navigation_mesh(false)
