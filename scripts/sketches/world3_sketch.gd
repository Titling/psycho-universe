# Набросок Мира 3 «Зал ожидания»: бесконечная поликлиника-вокзал, очередь по талонам,
# Тень сидит среди посетителей с талоном 318, кабинеты «Кто я?», «Зачем?», «Что потом?».
extends "res://scripts/sketches/sketch_base.gd"

const T_CLINIC := preload("res://textures/clinic_wall.png")
const T_LINO := preload("res://textures/linoleum.png")
const T_CEIL := preload("res://textures/ceiling.png")
const T_PAPER := preload("res://textures/paper.png")

const LENGTH := 84.0          # зал идёт от z = 10 до z = -74
const HALF_W := 7.0
const HEIGHT := 3.4
const COLD := Color(0.86, 0.95, 1.0)
const ROOM := Vector3(-14, 0, -42)   # «Кабинет 3. Что потом?»

var _flicker: Array[OmniLight3D] = []
var _flicker_tubes: Array[MeshInstance3D] = []
var _board: Label3D


func _ready() -> void:
	_setup_sketch()
	environment.background_color = Color(0.0, 0.0, 0.0)
	environment.fog_light_color = Color(0.02, 0.03, 0.03)
	environment.fog_density = 0.03
	environment.ambient_light_color = Color(0.7, 0.8, 0.8)
	environment.ambient_light_energy = 0.25

	_build_hall()
	_build_chairs()
	_build_doors()
	_build_room()
	_build_boards()
	# Тень сидит в очереди с талоном 318 на коленях
	var shadow_seat := Vector3(0.5, 0.0, -14.85)
	_sitting_figure(shadow_seat, -PI / 2, Color(0, 0, 0))
	var talon := shadow_seat + Vector3(0.28, 0.585, 0.08)
	_mesh(talon, Vector3(0.13, 0.005, 0.09), Color(0.95, 0.9, 0.8), Vector3.ZERO, null, 1.0, Color(0.2, 0.2, 0.17))
	var number := _label(talon + Vector3(0, 0.004, 0), "318", 14, Color(0.05, 0.05, 0.05))
	number.rotation = Vector3(-PI / 2, -PI / 2, 0)
	_spawn_player(Vector3(0, 0, 6), 0.0, "МИР 3. ЗАЛ ОЖИДАНИЯ\n(набросок)")


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var on := fmod(t * 7.3, 5.0) > 0.6 and sin(t * 13.0) > -0.8
	for l in _flicker:
		l.visible = on
	for m in _flicker_tubes:
		m.visible = on
	var number := 1 + int(t / 20.0)
	_board.text = "ВЫЗЫВАЕТСЯ\n№ %03d" % number


func _build_hall() -> void:
	var z0 := 10.0
	# пол и потолок кусками по 10 м, чтобы на кусок падало немного ламп
	for i in int(LENGTH / 10.0) + 1:
		var z := z0 - 5.0 - i * 10.0
		_box(Vector3(0, -0.5, z), Vector3(HALF_W * 2, 1, 10), Color(1, 1, 1), Vector3.ZERO, T_LINO, 0.5)
		_box(Vector3(0, HEIGHT + 0.5, z), Vector3(HALF_W * 2, 1, 10), Color(1, 1, 1), Vector3.ZERO, T_CEIL, 0.5)
		_box(Vector3(HALF_W + 0.5, HEIGHT / 2, z), Vector3(1, HEIGHT, 10), Color(1, 1, 1), Vector3.ZERO, T_CLINIC, 1.0 / 3.2)
	# левая стена с проёмом в «Кабинет 3»
	var gap_top := ROOM.z + 1.0
	var gap_bottom := ROOM.z - 1.0
	var left := [[z0, gap_top], [gap_bottom, z0 - LENGTH]]
	for seg in left:
		var a: float = seg[0]
		var b: float = seg[1]
		var z := a
		while z > b + 0.01:
			var len := minf(10.0, z - b)
			_box(Vector3(-HALF_W - 0.5, HEIGHT / 2, z - len / 2), Vector3(1, HEIGHT, len), Color(1, 1, 1), Vector3.ZERO, T_CLINIC, 1.0 / 3.2)
			z -= len
	_box(Vector3(-HALF_W - 0.5, HEIGHT - 0.6, ROOM.z), Vector3(1, 1.2, 2), Color(1, 1, 1), Vector3.ZERO, T_CLINIC, 1.0 / 3.2)
	_box(Vector3(0, HEIGHT / 2, z0 + 0.5), Vector3(HALF_W * 2, HEIGHT, 1), Color(1, 1, 1), Vector3.ZERO, T_CLINIC, 1.0 / 3.2)
	_box(Vector3(0, HEIGHT / 2, z0 - LENGTH - 0.5), Vector3(HALF_W * 2, HEIGHT, 1), Color(1, 1, 1), Vector3.ZERO, T_CLINIC, 1.0 / 3.2)

	# лампы дневного света: последние ряды уже погасли
	for i in int(LENGTH / 4.0):
		var z := z0 - 2.0 - i * 4.0
		var lit := z > -50.0
		for x in [-3.0, 3.0]:
			var tube := _mesh(Vector3(x, HEIGHT - 0.04, z), Vector3(0.3, 0.06, 1.3), Color(0.6, 0.6, 0.6), Vector3.ZERO, null, 1.0, COLD * 1.6 if lit else Color.BLACK)
			if lit and i == 6 and x > 0:
				_flicker_tubes.append(tube)
		if lit and i % 2 == 0:
			var light := OmniLight3D.new()
			light.position = Vector3(0, HEIGHT - 0.4, z)
			light.light_color = COLD
			light.light_energy = 1.6
			light.omni_range = 9.0
			add_child(light)
			if i == 6:
				_flicker.append(light)

	# «Кабинет 0» в самом конце, в темноте: из-под двери бьёт тёплый свет
	var end := z0 - LENGTH
	_box(Vector3(0, 1.1, end + 0.06), Vector3(1.2, 2.2, 0.12), Color(0.55, 0.42, 0.32), Vector3.ZERO, T_WOOD, 1.0)
	_mesh(Vector3(0, 0.02, end + 0.15), Vector3(1.2, 0.04, 0.05), Color.BLACK, Vector3.ZERO, null, 1.0, Color(2.2, 1.7, 1.1))
	_mesh(Vector3(0, 0.005, end + 0.9), Vector3(1.4, 0.01, 1.5), Color(0.9, 0.7, 0.5), Vector3.ZERO, null, 1.0, Color(0.25, 0.17, 0.08))
	var leak := OmniLight3D.new()
	leak.position = Vector3(0, 0.15, end + 0.4)
	leak.light_color = Color(1.0, 0.75, 0.45)
	leak.light_energy = 2.0
	leak.omni_range = 4.0
	add_child(leak)
	var plate := _label(Vector3(0, 2.45, end + 0.13), "КАБИНЕТ 0", 30, Color(0.9, 0.85, 0.75), 0.0, true)
	plate.modulate = Color(0.5, 0.45, 0.4)


func _build_chairs() -> void:
	var seats := [[], []]
	var backs := [[], []]
	var rails := []
	# ряды вдоль правой стены лицом к дверям и спиной к спине по центру
	var rows := [[HALF_W - 0.5, PI / 2], [0.55, -PI / 2], [-0.55, PI / 2]]
	for row in rows:
		var x: float = row[0]
		var yaw: float = row[1]
		var b := Basis(Vector3.UP, yaw)
		var z := 4.0
		while z > -62.0:
			if absf(z - ROOM.z) < 3.0 and x < 0:
				z -= 0.55
				continue
			var color := randi() % 5 == 0
			seats[int(color)].append(Transform3D(b, Vector3(x, 0.45, z)))
			backs[int(color)].append(Transform3D(b, Vector3(x, 0.72, z) + b * Vector3(0, 0, 0.22)))
			z -= 0.55
			if fmod(absf(z), 11.0) < 0.55:
				z -= 1.5   # проходы между рядами
		rails.append([Vector3(x, 0.38, -29.0), Vector3(0.08, 0.06, 66.0)])
	var blue := _material(Color(0.25, 0.42, 0.6))
	var orange := _material(Color(0.75, 0.42, 0.18))
	_multimesh(_box_mesh(Vector3(0.48, 0.05, 0.44)), blue, seats[0])
	_multimesh(_box_mesh(Vector3(0.48, 0.05, 0.44)), orange, seats[1])
	_multimesh(_box_mesh(Vector3(0.48, 0.5, 0.05)), blue, backs[0])
	_multimesh(_box_mesh(Vector3(0.48, 0.5, 0.05)), orange, backs[1])
	for r in rails:
		_box(r[0], r[1], Color(0.45, 0.45, 0.45), Vector3.ZERO, T_RUST, 1.0)
		_mesh(r[0] - Vector3(0, 0.19, 0), Vector3(0.05, 0.38, r[1].z), Color(0.35, 0.35, 0.35))


# Двери кабинетов вдоль левой стены, таблички с вопросами.
func _build_doors() -> void:
	var doors := [
		[-6.0, "КАБИНЕТ 1\nКТО Я?"],
		[-24.0, "КАБИНЕТ 2\nЗАЧЕМ?"],
		[ROOM.z, "КАБИНЕТ 3\nЧТО ПОТОМ?"],
		[-56.0, "КАБИНЕТ 4"],
	]
	for d in doors:
		var z: float = d[0]
		if z != ROOM.z:
			_mesh(Vector3(-HALF_W + 0.04, 1.1, z), Vector3(0.1, 2.2, 1.1), Color(0.6, 0.48, 0.36), Vector3.ZERO, T_WOOD, 1.0)
			_mesh(Vector3(-HALF_W + 0.11, 1.05, z - 0.4), Vector3(0.05, 0.05, 0.14), Color(0.7, 0.7, 0.68))
		_mesh(Vector3(-HALF_W + 0.04, 2.55, z), Vector3(0.03, 0.42, 0.9), Color(0.9, 0.9, 0.86))
		_label(Vector3(-HALF_W + 0.07, 2.55, z), d[1], 22, Color(0.1, 0.12, 0.2), PI / 2)
	# плакаты
	var posters := [[-14.0, "БЕРЕГИТЕ\nЗДОРОВЬЕ"], [-34.0, "КУРИТЬ\nЗАПРЕЩЕНО"], [-2.0, "ЖДИТЕ\nВЫЗОВА"]]
	for p in posters:
		_mesh(Vector3(HALF_W - 0.03, 2.2, p[0]), Vector3(0.02, 0.7, 0.55), Color(0.92, 0.9, 0.82), Vector3.ZERO, T_PAPER, 1.0)
		_label(Vector3(HALF_W - 0.05, 2.2, p[0]), p[1], 18, Color(0.55, 0.1, 0.1), -PI / 2)


# Табло очереди под потолком.
func _build_boards() -> void:
	for z in [-8.0, -36.0]:
		_mesh(Vector3(0, HEIGHT - 0.5, z), Vector3(2.4, 0.7, 0.15), Color(0.05, 0.05, 0.05))
		_mesh(Vector3(0, HEIGHT - 0.1, z), Vector3(0.04, 0.3, 0.04), Color(0.3, 0.3, 0.3))
		var l := _label(Vector3(0, HEIGHT - 0.5, z + 0.08), "ВЫЗЫВАЕТСЯ\n№ 001", 30, Color(1.0, 0.18, 0.1), 0.0, true)
		if _board == null:
			_board = l
		else:
			l.text = "ВАШ ТАЛОН\n№ 317"


# «Кабинет 3. Что потом?»: двор в тумане, беседка, гроб и почти пустые стулья.
func _build_room() -> void:
	var c := ROOM
	var size := Vector3(12, 4, 12)
	var dark := Color(0.4, 0.4, 0.42)
	_box(c + Vector3(0, -0.5, 0), Vector3(size.x, 1, size.z), Color(0.8, 0.8, 0.8), Vector3.ZERO, T_ASPHALT, 0.333)
	_box(c + Vector3(0, size.y + 0.5, 0), Vector3(size.x, 1, size.z), Color(0.1, 0.1, 0.1))
	_box(c + Vector3(-size.x / 2 - 0.5, size.y / 2, 0), Vector3(1, size.y, size.z), dark, Vector3.ZERO, T_CONCRETE)
	_box(c + Vector3(0, size.y / 2, -size.z / 2 - 0.5), Vector3(size.x, size.y, 1), dark, Vector3.ZERO, T_CONCRETE)
	_box(c + Vector3(0, size.y / 2, size.z / 2 + 0.5), Vector3(size.x, size.y, 1), dark, Vector3.ZERO, T_CONCRETE)
	# беседка
	var g := c + Vector3(-2.0, 0, 0)
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			_mesh(g + Vector3(x, 1.2, z), Vector3(0.15, 2.4, 0.15), Color(0.6, 0.55, 0.5), Vector3.ZERO, T_WOOD, 1.0)
	_mesh(g + Vector3(0, 2.45, 0), Vector3(4.4, 0.12, 4.4), Color(0.45, 0.42, 0.4), Vector3.ZERO, T_RUST, 1.0)
	# гроб на табуретках, крышка прислонена к столбу
	_mesh(g + Vector3(0, 0.75, 0), Vector3(0.75, 0.4, 2.0), Color(0.35, 0.2, 0.14), Vector3.ZERO, T_WOOD, 1.0)
	_mesh(g + Vector3(0, 0.93, 0), Vector3(0.62, 0.05, 1.85), Color(0.5, 0.08, 0.08))
	_mesh(g + Vector3(1.75, 1.0, -1.4), Vector3(0.7, 2.0, 0.08), Color(0.35, 0.2, 0.14), Vector3(0, 0.3, -0.12), T_WOOD, 1.0)
	for z in [-0.7, 0.7]:
		_mesh(g + Vector3(0, 0.27, z), Vector3(0.4, 0.55, 0.4), Color(0.5, 0.45, 0.4), Vector3.ZERO, T_WOOD, 1.0)
	# телефон на подушке: 47 пропущенных
	_mesh(g + Vector3(0, 0.97, -0.75), Vector3(0.09, 0.015, 0.17), Color(0.05, 0.05, 0.05), Vector3.ZERO, null, 1.0, Color(0.35, 0.55, 0.9))
	# стулья для прощания, заняты только два
	var chair := _material(Color(0.5, 0.45, 0.4), Color.BLACK, T_WOOD, 1.0)
	for i in 8:
		var p := c + Vector3(2.6 + (i % 2) * 1.3, 0, -3.0 + (i / 2) * 1.6)
		var seat := MeshInstance3D.new()
		seat.mesh = _box_mesh(Vector3(0.5, 0.06, 0.5))
		seat.material_override = chair
		seat.position = p + Vector3(0, 0.45, 0)
		add_child(seat)
		var back := MeshInstance3D.new()
		back.mesh = _box_mesh(Vector3(0.06, 0.5, 0.5))
		back.material_override = chair
		back.position = p + Vector3(0.25, 0.72, 0)
		add_child(back)
		for lx in [-0.2, 0.2]:
			for lz in [-0.2, 0.2]:
				_mesh(p + Vector3(lx, 0.22, lz), Vector3(0.04, 0.44, 0.04), Color(0.4, 0.35, 0.3))
	_sitting_figure(c + Vector3(2.6, 0, -1.4), PI / 2, Color(0.22, 0.2, 0.2))    # мать
	_sitting_figure(c + Vector3(3.9, 0, 0.2), PI / 2, Color(0.16, 0.16, 0.17))   # отец
	_lamp(c + Vector3(0.5, 3.6, 2.0)).light_energy = 6.0
	var mist := OmniLight3D.new()
	mist.position = c + Vector3(-2, 2.0, 0)
	mist.light_color = Color(0.6, 0.65, 0.75)
	mist.light_energy = 2.0
	mist.omni_range = 7.0
	add_child(mist)
