# Вещи из квартиры для загрузки сохранения на другом уровне. Если игрок сохранился во дворе
# с кастрюлей в инвентаре, кастрюли в Мире 1 нет: её модель берётся из сцены квартиры.
# Вещь узнаётся по пути в сцене квартиры (origin), как в таблице GRABBABLES в apartment.gd.
extends RefCounted

const APARTMENT_SCENE := "res://scenes/apartment.tscn"
const GrabbableScript := preload("res://scripts/grabbable.gd")


static func entry(origin: String) -> Array:
	# load, а не preload: apartment.gd наследует main.gd, а main.gd пользуется этим файлом.
	for e in load("res://scripts/apartment.gd").GRABBABLES:
		if e[0] == origin:
			return e
	return []


# Достать из сцены квартиры вещи с такими путями и положить на уровень parent.
# Возвращает словарь путь: вещь. Неизвестные пути пропускаются.
static func spawn(origins: Array, parent: Node, hands: Node, area: AABB) -> Dictionary:
	var result := {}
	var known := []
	for origin in origins:
		if not entry(origin).is_empty():
			known.append(origin)
	if known.is_empty():
		return result
	var apartment: Node3D = load(APARTMENT_SCENE).instantiate()
	# Скрипт квартиры строит весь уровень с игроком и прологом, здесь нужны только модели.
	apartment.set_script(null)
	apartment.visible = false
	apartment.process_mode = Node.PROCESS_MODE_DISABLED
	parent.add_child(apartment)
	for origin in known:
		var e := entry(origin)
		var extras := []
		for path in e[4]:
			if apartment.has_node(path):
				extras.append(apartment.get_node(path))
		var body: RigidBody3D = GrabbableScript.wrap(apartment.get_node(e[0]), e[1], e[2], e[3], extras, hands, area)
		body.origin = origin
		body.reparent(parent)
		result[origin] = body
	apartment.queue_free()
	return result
