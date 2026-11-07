# Сохранение и загрузка игры. Подключён как автозагрузка SaveGame (см. project.godot).
#
# Файл сохранения: user://save.json (на Windows это
# %APPDATA%\Godot\app_userdata\Psycho Universe\save.json). Это обычный JSON, его можно открыть блокнотом.
#
# Как добавить в сохранение свою часть игры (квартира, инвентарь и т. д.):
#   1. Добавь узел в группу "saveable":      add_to_group("saveable")
#   2. Задай ему уникальный ключ:             var save_key := "inventory"
#   3. Напиши два метода:
#        func save_state() -> Dictionary      # что положить в файл
#        func load_state(data: Dictionary)    # как восстановить из файла
#   SaveGame сам соберёт эти данные при сохранении и раздаст при загрузке.
#   В словаре можно хранить числа, строки, bool, массивы, словари и Vector2/Vector3/Color
#   (векторы и цвета переводятся в JSON и обратно функциями pack()/unpack()).
extends Node

signal saved
signal loaded

const PATH := "user://save.json"
const TMP_PATH := "user://save.json.tmp"
const VERSION := 1

# true, пока игра открывает уровень, чтобы продолжить с сохранения.
var continue_requested := false

var _data := {}


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


# Записать сохранение. world — состояние текущего мира (main.gd), остальное соберётся из группы "saveable".
func save_game(world: Dictionary) -> bool:
	var sections := {}
	for node in get_tree().get_nodes_in_group("saveable"):
		if node.has_method("save_state") and "save_key" in node:
			sections[node.save_key] = pack(node.save_state())
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"scene": get_tree().current_scene.scene_file_path if get_tree().current_scene else "",
		"world": pack(world),
		"sections": sections,
	}
	# Сначала пишем во временный файл, потом переименовываем: если игра упадёт посреди записи,
	# старое сохранение останется целым.
	var file := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveGame: не удалось записать %s (%s)" % [TMP_PATH, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_PATH), ProjectSettings.globalize_path(PATH))
	if err != OK:
		push_error("SaveGame: не удалось заменить сохранение (%s)" % error_string(err))
		return false
	_data = data
	saved.emit()
	return true


# Прочитать файл сохранения. Пустой словарь, если файла нет или он повреждён.
func read() -> Dictionary:
	if not has_save():
		return {}
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) > VERSION:
		push_warning("SaveGame: файл сохранения повреждён или от более новой версии, он не будет загружен")
		return {}
	_data = parsed
	return parsed


# Состояние мира из последнего прочитанного сохранения.
func world_state() -> Dictionary:
	var w = unpack(_data.get("world", {}))
	return w if typeof(w) == TYPE_DICTIONARY else {}


# Раздать сохранённые данные всем узлам из группы "saveable". Вызывать, когда уровень уже построен.
func apply_sections() -> void:
	var sections: Dictionary = _data.get("sections", {})
	for node in get_tree().get_nodes_in_group("saveable"):
		if "save_key" in node and sections.has(node.save_key) and node.has_method("load_state"):
			node.load_state(unpack(sections[node.save_key]))
	loaded.emit()


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_data = {}


# Продолжить с сохранения: открыть уровень, на котором сохранились (квартиру или Мир 1).
# Уровень сам заберёт своё состояние через take_continue().
func continue_game() -> void:
	var path: String = read().get("scene", "")
	if path == "" or not ResourceLoader.exists(path):
		return
	continue_requested = true
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


# Уровень спрашивает при запуске: продолжаем ли мы с сохранения, сделанного на нём.
# Возвращает состояние мира или пустой словарь, если начинать с начала.
func take_continue(world_name: String) -> Dictionary:
	if not continue_requested:
		return {}
	continue_requested = false
	var w := world_state()
	return w if w.get("world", "") == world_name else {}


# ---------------------------------------------------------------- JSON не знает векторов

static func pack(value):
	match typeof(value):
		TYPE_VECTOR2:
			return {"__v2": [value.x, value.y]}
		TYPE_VECTOR3:
			return {"__v3": [value.x, value.y, value.z]}
		TYPE_COLOR:
			return {"__c": [value.r, value.g, value.b, value.a]}
		TYPE_DICTIONARY:
			var d := {}
			for k in value:
				d[str(k)] = pack(value[k])
			return d
		TYPE_ARRAY:
			var a := []
			for v in value:
				a.append(pack(v))
			return a
		_:
			if value is PackedStringArray or value is PackedFloat32Array or value is PackedInt32Array:
				return pack(Array(value))
			return value


static func unpack(value):
	match typeof(value):
		TYPE_DICTIONARY:
			if value.size() == 1:
				if value.has("__v2"):
					return Vector2(value.__v2[0], value.__v2[1])
				if value.has("__v3"):
					return Vector3(value.__v3[0], value.__v3[1], value.__v3[2])
				if value.has("__c"):
					return Color(value.__c[0], value.__c[1], value.__c[2], value.__c[3])
			var d := {}
			for k in value:
				d[k] = unpack(value[k])
			return d
		TYPE_ARRAY:
			var a := []
			for v in value:
				a.append(unpack(v))
			return a
		_:
			return value
