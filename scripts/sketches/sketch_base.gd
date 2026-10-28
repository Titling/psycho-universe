# Общая основа для набросков Миров 2 и 3: свободная прогулка без сюжета.
# Берёт из main.gd материалы, коробки, фонари и фильтр, но строит свой уровень.
extends "res://scripts/main.gd"


func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	pass


# Общий старт: управление, окружение, фильтр.
func _setup_sketch() -> void:
	randomize()
	_setup_input()
	_setup_environment()
	nav_region = NavigationRegion3D.new()
	add_child(nav_region)


func _spawn_player(start: Vector3, yaw: float, title: String) -> void:
	player = PlayerScript.new()
	add_child(player)
	player.global_position = start
	player.rotation.y = yaw
	player.camera.far = 250.0
	ui = UIScript.new()
	add_child(ui)
	player.prompt_changed.connect(ui.set_prompt)
	_intro(title)


func _intro(title: String) -> void:
	await get_tree().create_timer(0.3).timeout
	ui.show_title(title)
	await ui.fade_to(0.0, 2.0)
	ui.show_hint("Набросок, сюжета пока нет.   WASD — идти   Shift — бежать   Esc — показать курсор")


# Деталь без коллизии: для мелочей, через которые не нужно ходить.
func _mesh(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, tex: Texture2D = null, scale := 0.333, emission := Color.BLACK) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = _material(color, emission, tex, scale)
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


# Надпись в мире пиксельным шрифтом.
func _label(pos: Vector3, text: String, size := 32, color := Color(0.1, 0.08, 0.07), yaw := 0.0, unshaded := false) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 0
	l.shaded = not unshaded
	l.double_sided = false
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	l.position = pos
	l.rotation.y = yaw
	add_child(l)
	return l


# Плоская картинка (циферблат, плакат) с обычной развёрткой.
func _picture_material(tex: Texture2D, emission := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if emission > 0.0:
		m.emission_enabled = true
		m.emission_texture = tex
		m.emission_energy_multiplier = emission
	return m


# Много одинаковых предметов одним вызовом отрисовки.
func _multimesh(mesh: Mesh, material: Material, transforms: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi


func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


# Сидящая фигура: Тень или люди на прощании.
func _sitting_figure(pos: Vector3, yaw: float, color: Color) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if color.v < 0.05 else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.albedo_color = color
	var parts := [
		[Vector3(0, 0.78, 0.05), Vector3(0.42, 0.62, 0.26)],   # туловище
		[Vector3(0, 1.22, 0.05), Vector3(0.22, 0.26, 0.24)],   # голова
		[Vector3(-0.11, 0.5, -0.18), Vector3(0.16, 0.14, 0.44)], # бёдра
		[Vector3(0.11, 0.5, -0.18), Vector3(0.16, 0.14, 0.44)],
		[Vector3(-0.11, 0.24, -0.38), Vector3(0.13, 0.48, 0.13)], # голени
		[Vector3(0.11, 0.24, -0.38), Vector3(0.13, 0.48, 0.13)],
		[Vector3(-0.26, 0.78, -0.05), Vector3(0.1, 0.5, 0.12)],  # руки
		[Vector3(0.26, 0.78, -0.05), Vector3(0.1, 0.5, 0.12)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(p[1])
		mi.position = p[0]
		mi.material_override = m
		root.add_child(mi)
	return root
