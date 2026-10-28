# Набросок Мира 2 «Кладбище надежд»: песок, часы вместо крестов, надгробия-книги,
# руки из земли, письма на ветру и единственные часы, которые идут.
extends "res://scripts/sketches/sketch_base.gd"

const T_SAND := preload("res://textures/sand.png")
const T_PAPER := preload("res://textures/paper.png")
const SKY_SHADER := preload("res://shaders/sky_object.gdshader")
const CLOCK_FACES := [
	preload("res://textures/clock_a.png"),
	preload("res://textures/clock_b.png"),
	preload("res://textures/clock_c.png"),
]
const CLOCK_317 := preload("res://textures/clock_317.png")

const DUST := Color(0.27, 0.21, 0.15)
const STONE := Color(0.62, 0.6, 0.56)
const SKIN := Color(0.72, 0.64, 0.56)

var _letters: MultiMeshInstance3D
var _letter_seeds := []
var _ticking: Label3D


func _ready() -> void:
	_setup_sketch()
	environment.background_color = DUST
	environment.fog_light_color = DUST
	environment.fog_density = 0.045
	environment.ambient_light_color = Color(0.85, 0.7, 0.5)
	environment.ambient_light_energy = 0.9

	_build_ground()
	_build_clocks()
	_build_books()
	_build_hands()
	_build_gazebo(Vector3(17, 0, -30))
	_build_center()
	_build_sky()
	_build_letters()
	for z in [6.0, -14.0, -34.0, -54.0]:
		_lamp(Vector3(-2.2 if int(z) % 20 == 0 else 2.2, 3.2, z))
	_spawn_player(Vector3(0, 0, 14), 0.0, "МИР 2. КЛАДБИЩЕ НАДЕЖД\n(набросок)")


func _process(delta: float) -> void:
	# письма гоняет ветер
	var t := Time.get_ticks_msec() / 1000.0
	for i in _letter_seeds.size():
		var s: Vector4 = _letter_seeds[i]
		var x := fposmod(s.x + t * s.w, 80.0) - 40.0
		var pos := Vector3(x, 0.15 + abs(sin(t * 1.3 + s.z)) * 0.9, s.y + sin(t * 0.7 + s.z) * 1.5)
		var basis := Basis(Vector3(1, 0.3, 0.2).normalized(), t * 2.0 + s.z)
		_letters.multimesh.set_instance_transform(i, Transform3D(basis, pos))
	# часы, которые идут: 03:17 и секунды
	_ticking.text = "03:17:%02d" % (int(t) % 60)


func _build_ground() -> void:
	for x in range(-60, 61, 30):
		for z in range(-120, 31, 30):
			_box(Vector3(x, -0.5, z), Vector3(30, 1, 30), Color(0.95, 0.9, 0.85), Vector3.ZERO, T_SAND, 0.5)
	# барханы
	var dune_mat := _material(Color(0.95, 0.9, 0.85), Color.BLACK, T_SAND, 0.5)
	for i in 26:
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radial_segments = 10
		sphere.rings = 5
		mi.mesh = sphere
		mi.material_override = dune_mat
		var side := -1.0 if i % 2 == 0 else 1.0
		mi.position = Vector3(side * randf_range(9, 45), -0.4, randf_range(-110, 20))
		mi.scale = Vector3(randf_range(5, 12), randf_range(0.8, 2.2), randf_range(5, 12))
		add_child(mi)


# Аллея: часы на столбиках вместо крестов.
func _build_clocks() -> void:
	var posts := []
	var faces := [[], [], []]
	for z in range(10, -66, -3):
		for side in [-1, 1]:
			for col in range(4):
				var x: float = side * (4.0 + col * 3.2) + randf_range(-0.6, 0.6)
				var zz: float = z + randf_range(-0.8, 0.8)
				var h := randf_range(1.0, 1.6)
				var tilt := Basis(Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized(), randf_range(0.0, 0.18))
				var yaw := Basis(Vector3.UP, randf_range(-0.4, 0.4))
				var b := tilt * yaw
				posts.append(Transform3D(b, Vector3(x, h / 2.0 - 0.1, zz)).scaled_local(Vector3(1, h, 1)))
				faces[randi() % 3].append(Transform3D(b, Vector3(x, h - 0.1, zz) + b * Vector3(0, 0.12, 0.08)))
	_multimesh(_box_mesh(Vector3(0.12, 1.0, 0.12)), _material(Color(0.55, 0.5, 0.45), Color.BLACK, T_RUST, 1.0), posts)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.5, 0.5)
	for i in 3:
		_multimesh(quad, _picture_material(CLOCK_FACES[i]), faces[i])


# Надгробие в виде раскрытой каменной книги.
func _book(pos: Vector3, yaw: float, title: String, empty := false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	_add_part(root, Vector3(0, 0.45, 0), Vector3(1.5, 0.9, 0.6), _material(STONE, Color.BLACK, T_CONCRETE, 1.0))
	# раскрытая книга, наклонена к тому, кто подошёл
	var book := Node3D.new()
	book.position = Vector3(0, 0.98, 0.0)
	book.rotation.x = 0.5
	root.add_child(book)
	var cover := _material(STONE.darkened(0.25), Color.BLACK, T_CONCRETE, 1.0)
	var page := _material(Color(1, 1, 1) if empty else Color(0.85, 0.82, 0.72), Color(0.12, 0.12, 0.1) if empty else Color.BLACK, T_PAPER, 1.5)
	for side in [-1, 1]:
		_add_part(book, Vector3(side * 0.42, 0.0, 0), Vector3(0.86, 0.1, 1.1), cover, Vector3(0, 0, -side * 0.28))
		_add_part(book, Vector3(side * 0.4, 0.07, 0), Vector3(0.78, 0.06, 1.0), page, Vector3(0, 0, -side * 0.28))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.5, 1.1, 0.8)
	shape.shape = box
	shape.position.y = 0.55
	body.add_child(shape)
	root.add_child(body)
	if title != "":
		var l := Label3D.new()
		l.text = title
		l.font_size = 48
		l.pixel_size = 0.0045
		l.outline_size = 0
		l.modulate = Color(0.15, 0.13, 0.12)
		l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		l.position = Vector3(0, 0.55, 0.36)
		root.add_child(l)
	return book


func _build_books() -> void:
	var art := _book(Vector3(-5.5, 0, -6), 0.5, "СТАТЬ\nХУДОЖНИКОМ")
	# засохшая палитра на одной странице, детский рисунок на другой
	_add_part(art, Vector3(-0.4, 0.11, 0.1), Vector3(0.34, 0.02, 0.26), _material(Color(0.6, 0.45, 0.3)), Vector3(0, 0.4, 0.28))
	for c in [Color(0.7, 0.15, 0.1), Color(0.15, 0.3, 0.6), Color(0.8, 0.7, 0.1)]:
		_add_part(art, Vector3(-0.4 + randf_range(-0.1, 0.1), 0.13, 0.1 + randf_range(-0.07, 0.07)), Vector3(0.06, 0.02, 0.06), _material(c), Vector3(0, 0, 0.28))
	_add_part(art, Vector3(0.4, 0.105, 0), Vector3(0.5, 0.01, 0.62), _material(Color(0.95, 0.95, 0.9), Color(0.1, 0.1, 0.1)), Vector3(0, 0.1, -0.28))
	_add_part(art, Vector3(0.35, 0.115, 0.08), Vector3(0.22, 0.01, 0.2), _material(Color(0.25, 0.4, 0.8)), Vector3(0, 0.1, -0.28))
	_add_part(art, Vector3(0.42, 0.115, -0.15), Vector3(0.1, 0.01, 0.1), _material(Color(0.9, 0.75, 0.1)), Vector3(0, 0.1, -0.28))
	var trip := _book(Vector3(6, 0, -14), -0.4, "ПУТЕШЕСТВОВАТЬ")
	# неиспользованные билеты
	_add_part(trip, Vector3(0.38, 0.11, 0.1), Vector3(0.36, 0.01, 0.14), _material(Color(0.8, 0.6, 0.65)), Vector3(0, -0.2, -0.28))
	_add_part(trip, Vector3(0.42, 0.12, -0.15), Vector3(0.36, 0.01, 0.14), _material(Color(0.6, 0.68, 0.85)), Vector3(0, 0.3, -0.28))
	_book(Vector3(-6, 0, -22), 0.3, "НАПИСАТЬ\nКНИГУ")
	_book(Vector3(6.5, 0, -30), -0.2, "ДОУЧИТЬСЯ")
	# «Бросить пить»: свежая яма по росту и лопата
	_book(Vector3(-5, 0, -40), 0.35, "БРОСИТЬ\nПИТЬ")
	_mesh(Vector3(-4.2, 0.005, -37.8), Vector3(0.95, 0.02, 2.0), Color(0.03, 0.025, 0.02), Vector3(0, 0.35, 0))
	var mound := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 4
	mound.mesh = sphere
	mound.material_override = _material(Color(1.2, 1.1, 1.0), Color.BLACK, T_SAND, 0.5)
	mound.position = Vector3(-2.7, 0.0, -38.3)
	mound.scale = Vector3(0.9, 0.55, 1.4)
	add_child(mound)
	_mesh(Vector3(-2.4, 0.75, -37.4), Vector3(0.05, 1.3, 0.05), Color(0.6, 0.45, 0.3), Vector3(0.25, 0, 0.15), T_WOOD, 1.0)
	_mesh(Vector3(-2.5, 0.05, -37.15), Vector3(0.24, 0.32, 0.03), Color(0.5, 0.48, 0.46), Vector3(0.25 + PI / 2.6, 0, 0.15), T_RUST, 1.0)
	# «Подойти к ней»: имя замазано, ответ на граффити из двора
	_book(Vector3(6, 0, -48), -0.35, "")
	var front := Vector3(6, 0, -48)
	_mesh(front + Vector3(0, 0.62, 0.31).rotated(Vector3.UP, -0.35), Vector3(1.1, 0.25, 0.02), Color(0.25, 0.25, 0.27), Vector3(0, -0.35, 0))
	_label(front + Vector3(0, 0.3, 0.32).rotated(Vector3.UP, -0.35), "Я ЗДЕСЬ", 34, Color(0.75, 0.1, 0.08), -0.35)


func _add_part(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.position = pos
	mi.rotation = rot
	mi.material_override = mat
	parent.add_child(mi)


# Руки из песка: детские и подростковые, с краской на пальцах.
func _hand(pos: Vector3, yaw: float, reach: float, scale := 1.0) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(reach, yaw, 0)
	root.scale = Vector3.ONE * scale
	add_child(root)
	var mat := _material(SKIN)
	var paint := _material(Color(0.2, 0.35, 0.7))
	var parts := [
		[Vector3(0, 0.3, 0), Vector3(0.11, 0.62, 0.11), mat],
		[Vector3(0, 0.68, 0), Vector3(0.16, 0.18, 0.06), mat],
		[Vector3(-0.1, 0.66, 0.02), Vector3(0.04, 0.1, 0.04), mat],
	]
	for i in 4:
		parts.append([Vector3(-0.055 + i * 0.037, 0.83, 0), Vector3(0.03, 0.14, 0.035), paint if i == 1 else mat])
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(p[1])
		mi.position = p[0]
		mi.material_override = p[2]
		root.add_child(mi)


func _build_hands() -> void:
	var clusters := [Vector3(1.8, 0, -24), Vector3(-1.5, 0, -44), Vector3(2.5, 0, -58), Vector3(-9, 0, -10)]
	for c in clusters:
		for i in 5:
			var p: Vector3 = c + Vector3(randf_range(-1.5, 1.5), -0.25, randf_range(-1.5, 1.5))
			_hand(p, randf_range(-PI, PI), randf_range(-0.5, 0.5), randf_range(1.3, 1.8))


# Беседка из его двора, наполовину засыпанная песком.
func _build_gazebo(c: Vector3) -> void:
	var root := Node3D.new()
	root.position = c
	root.rotation = Vector3(0.08, 0.6, -0.12)
	add_child(root)
	var wood := _material(Color(0.55, 0.5, 0.45), Color.BLACK, T_WOOD, 1.0)
	var roof := _material(Color(0.45, 0.42, 0.4), Color.BLACK, T_RUST, 1.0)
	var parts := []
	for x in [-1.8, 1.8]:
		for z in [-1.8, 1.8]:
			parts.append([Vector3(x, 0.6, z), Vector3(0.15, 2.4, 0.15), wood])
	parts.append([Vector3(0, 1.9, 0), Vector3(4.4, 0.12, 4.4), roof])
	parts.append([Vector3(0, -0.1, 0), Vector3(1.6, 0.1, 0.8), wood])   # стол
	parts.append([Vector3(0, -0.15, 1.2), Vector3(3.2, 0.08, 0.4), wood]) # лавка
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(p[1])
		mi.position = p[0]
		mi.material_override = p[2]
		root.add_child(mi)
	# пустые бутылки на песке
	for i in 4:
		_mesh(c + Vector3(randf_range(-2, 2), 0.1, randf_range(1.5, 3)), Vector3(0.08, 0.28, 0.08), Color(0.2, 0.35, 0.2), Vector3(PI / 2, randf() * PI, 0))
	var light := OmniLight3D.new()
	light.position = c + Vector3(0, 1.5, 0)
	light.light_color = Color(0.7, 0.75, 1.0)
	light.light_energy = 1.5
	light.omni_range = 6.0
	add_child(light)


# Центр кладбища: высокие часы, которые идут, и книга с пустыми страницами.
func _build_center() -> void:
	var c := Vector3(0, 0, -72)
	_box(c + Vector3(0, 1.6, 0), Vector3(1.0, 3.2, 0.6), Color(0.6, 0.45, 0.35), Vector3.ZERO, T_WOOD, 1.0)
	_mesh(c + Vector3(0, 3.35, 0), Vector3(1.2, 0.3, 0.7), Color(0.5, 0.38, 0.3), Vector3.ZERO, T_WOOD, 1.0)
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	face.mesh = quad
	face.material_override = _picture_material(CLOCK_317, 0.6)
	face.position = c + Vector3(0, 2.65, 0.34)
	add_child(face)
	# маятник
	_mesh(c + Vector3(0, 1.4, 0.31), Vector3(0.04, 1.0, 0.02), Color(0.8, 0.65, 0.3))
	_mesh(c + Vector3(0, 0.9, 0.32), Vector3(0.2, 0.2, 0.03), Color(0.85, 0.7, 0.3), Vector3.ZERO, null, 1.0, Color(0.3, 0.22, 0.05))
	_ticking = _label(c + Vector3(0, 2.05, 0.37), "03:17:00", 48, Color(1.0, 0.3, 0.2), 0.0, true)

	var blank := _book(c + Vector3(2.6, 0, 2.8), -0.5, "", true)
	_add_part(blank, Vector3(0.4, 0.12, 0.1), Vector3(0.3, 0.025, 0.025), _material(Color(0.1, 0.1, 0.25)), Vector3(0, 0.5, -0.28))
	var lamp := _lamp(c + Vector3(4.2, 3.0, 3.5))
	lamp.light_energy = 3.0


# На небе огромные перевёрнутые песочные часы, из них сыплется песок.
func _build_sky() -> void:
	var c := Vector3(0, 55, -150)
	var mat := ShaderMaterial.new()
	mat.shader = SKY_SHADER
	mat.set_shader_parameter("color", Color(0.42, 0.34, 0.24))
	var stream_mat := ShaderMaterial.new()
	stream_mat.shader = SKY_SHADER
	stream_mat.set_shader_parameter("color", Color(0.6, 0.5, 0.35))
	for dir in [1, -1]:
		var cone := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 24.0 if dir == 1 else 0.6
		cyl.bottom_radius = 0.6 if dir == 1 else 24.0
		cyl.height = 30.0
		cyl.radial_segments = 10
		cone.mesh = cyl
		cone.material_override = mat
		cone.position = c + Vector3(0, dir * 15.0, 0)
		add_child(cone)
	var stream := MeshInstance3D.new()
	stream.mesh = _box_mesh(Vector3(0.6, 60, 0.6))
	stream.material_override = stream_mat
	stream.position = c + Vector3(0, -45, 0)
	add_child(stream)


func _build_letters() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(0.22, 0.28)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = T_PAPER
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var transforms := []
	for i in 50:
		_letter_seeds.append(Vector4(randf() * 80.0, randf_range(-70, 10), randf() * TAU, randf_range(1.5, 4.0)))
		transforms.append(Transform3D())
	_letters = _multimesh(quad, mat, transforms)
