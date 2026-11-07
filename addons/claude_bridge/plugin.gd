# Мост между Claude и открытым редактором. Команды приходят файлом .godot/claude_bridge/in.json,
# ответ пишется в out_<id>.json рядом. Выполняется только то, что перечислено в _run():
# произвольный код плагин не запускает. Правки идут через отмену, поэтому Ctrl+Z работает,
# а на диск сцена попадает только по команде save.
@tool
extends EditorPlugin

const DIR := "res://.godot/claude_bridge/"
const MAX_NODES := 2000

var _timer: Timer
var _busy := false


func _enter_tree() -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "shots")
	_timer = Timer.new()
	_timer.wait_time = 0.25
	_timer.timeout.connect(_poll)
	add_child(_timer)
	_timer.start()


func _exit_tree() -> void:
	_timer.queue_free()


func _poll() -> void:
	if _busy or not FileAccess.file_exists(DIR + "in.json"):
		return
	_busy = true
	var text := FileAccess.get_file_as_string(DIR + "in.json")
	DirAccess.remove_absolute(DIR + "in.json")
	var request = JSON.parse_string(text)
	var reply := {}
	var id := "unknown"
	if request is Dictionary and request.get("cmd") is String:
		id = str(request.get("id", "unknown")).validate_filename()
		var args: Dictionary = request.get("args", {}) if request.get("args", {}) is Dictionary else {}
		reply = await _run(request.cmd, args)
	else:
		reply = _error("запрос не разобран")
	var out := FileAccess.open(DIR + "out_%s.tmp" % id, FileAccess.WRITE)
	out.store_string(JSON.stringify(reply))
	out.close()
	DirAccess.rename_absolute(DIR + "out_%s.tmp" % id, DIR + "out_%s.json" % id)
	_busy = false


func _error(text: String) -> Dictionary:
	return {"ok": false, "error": text}


func _run(cmd: String, args: Dictionary) -> Dictionary:
	match cmd:
		"ping":
			var root := EditorInterface.get_edited_scene_root()
			return {"ok": true, "scene": root.scene_file_path if root else ""}
		"open_scene":
			return _open_scene(str(args.get("path", "")))
		"tree":
			return _tree()
		"selected":
			var names := []
			for node in EditorInterface.get_selection().get_selected_nodes():
				names.append(_path_of(node))
			return {"ok": true, "selected": names}
		"select":
			return _select(str(args.get("node", "")))
		"set":
			return _set_property(str(args.get("node", "")), str(args.get("property", "")), args.get("value"))
		"add_node":
			return _add_node(args)
		"rescan":
			EditorInterface.get_resource_filesystem().scan()
			return {"ok": true}
		"reload_scene":
			var edited := EditorInterface.get_edited_scene_root()
			if edited == null:
				return _error("сцена не открыта")
			EditorInterface.reload_scene_from_path(edited.scene_file_path)
			return {"ok": true}
		"save":
			return _save()
		"screenshot":
			return await _screenshot(str(args.get("name", "view")), bool(args.get("whole_editor", false)))
		"render":
			return await _render(args)
	return _error("неизвестная команда: " + cmd)


func _open_scene(path: String) -> Dictionary:
	if not path.begins_with("res://") or not path.ends_with(".tscn") or not FileAccess.file_exists(path):
		return _error("нет такой сцены: " + path)
	EditorInterface.open_scene_from_path(path)
	return {"ok": true, "scene": path}


func _path_of(node: Node) -> String:
	return str(EditorInterface.get_edited_scene_root().get_path_to(node))


func _find(path: String) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	return root.get_node_or_null(NodePath(path)) if root else null


func _tree() -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error("сцена не открыта")
	var nodes := []
	_collect(root, nodes)
	return {"ok": true, "scene": root.scene_file_path, "nodes": nodes, "truncated": nodes.size() >= MAX_NODES}


func _collect(node: Node, out: Array) -> void:
	if out.size() >= MAX_NODES:
		return
	var entry := {"path": _path_of(node), "type": node.get_class()}
	if node is Node3D:
		var p: Vector3 = node.position
		entry["position"] = [snappedf(p.x, 0.001), snappedf(p.y, 0.001), snappedf(p.z, 0.001)]
	out.append(entry)
	for child in node.get_children():
		if child.owner != null:
			_collect(child, out)


func _select(path: String) -> Dictionary:
	var node := _find(path)
	if node == null:
		return _error("нет такого узла: " + path)
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(node)
	return {"ok": true}


func _set_property(path: String, property: String, value: Variant) -> Dictionary:
	var node := _find(path)
	if node == null:
		return _error("нет такого узла: " + path)
	if property.begins_with("script") or not property in node:
		return _error("нет такого свойства: " + property)
	var old = node.get(property)
	var converted = _convert(value, typeof(old))
	if converted == null:
		return _error("неподходящее значение для " + property)
	var undo := get_undo_redo()
	undo.create_action("Claude: %s.%s" % [node.name, property])
	undo.add_do_property(node, property, converted)
	undo.add_undo_property(node, property, old)
	undo.commit_action()
	return {"ok": true, "old": var_to_str(old), "new": var_to_str(node.get(property))}


# Новый узел из короткого списка типов. Как и остальные правки, отменяется через Ctrl+Z.
func _add_node(args: Dictionary) -> Dictionary:
	var parent := _find(str(args.get("parent", ".")))
	if parent == null:
		return _error("нет такого родителя")
	var type := str(args.get("type", ""))
	var node: Node3D
	match type:
		"OmniLight3D":
			node = OmniLight3D.new()
		"SpotLight3D":
			node = SpotLight3D.new()
		"Marker3D":
			node = Marker3D.new()
		"Node3D":
			node = Node3D.new()
		_:
			return _error("этот тип добавлять нельзя: " + type)
	node.name = str(args.get("name", type))
	var props = args.get("props", {})
	if props is Dictionary:
		for property in props:
			if not property in node:
				node.free()
				return _error("нет такого свойства: " + property)
			var value = _convert(props[property], typeof(node.get(property)))
			if value == null:
				node.free()
				return _error("неподходящее значение для " + property)
			node.set(property, value)
	var undo := get_undo_redo()
	undo.create_action("Claude: добавить %s" % node.name)
	undo.add_do_method(parent, "add_child", node, true)
	undo.add_do_property(node, "owner", EditorInterface.get_edited_scene_root())
	undo.add_do_reference(node)
	undo.add_undo_method(parent, "remove_child", node)
	undo.commit_action()
	return {"ok": true, "path": _path_of(node)}


# Только простые типы: числа, флаги, строки, векторы и цвета.
func _convert(value: Variant, type: int) -> Variant:
	match type:
		TYPE_BOOL:
			return value if value is bool else null
		TYPE_INT:
			return int(value) if value is float or value is int else null
		TYPE_FLOAT:
			return float(value) if value is float or value is int else null
		TYPE_STRING:
			return value if value is String else null
		TYPE_VECTOR3:
			if value is Array and value.size() == 3:
				return Vector3(value[0], value[1], value[2])
		TYPE_COLOR:
			if value is Array and value.size() >= 3:
				return Color(value[0], value[1], value[2], value[3] if value.size() > 3 else 1.0)
	return null


func _save() -> Dictionary:
	if EditorInterface.get_edited_scene_root() == null:
		return _error("сцена не открыта")
	var err := EditorInterface.save_scene()
	return {"ok": err == OK, "code": err}


# Дождаться отрисовки. Редактор в покое может не рисовать кадры, поэтому ждём с ограничением.
func _wait_for_draw() -> void:
	var drawn := [false]
	var mark := func(): drawn[0] = true
	RenderingServer.frame_post_draw.connect(mark, CONNECT_ONE_SHOT)
	EditorInterface.get_base_control().queue_redraw()
	for i in 120:
		await get_tree().process_frame
		if drawn[0]:
			return
		EditorInterface.get_base_control().queue_redraw()
	if RenderingServer.frame_post_draw.is_connected(mark):
		RenderingServer.frame_post_draw.disconnect(mark)


func _save_image(image: Image, name: String) -> Dictionary:
	if image == null or image.is_empty():
		return _error("кадр пустой")
	var file := DIR + "shots/" + name.validate_filename() + ".png"
	var err := image.save_png(file)
	return {"ok": err == OK, "file": ProjectSettings.globalize_path(file)}


func _screenshot(name: String, whole_editor: bool) -> Dictionary:
	await _wait_for_draw()
	var viewport: Viewport = EditorInterface.get_base_control().get_viewport() if whole_editor else EditorInterface.get_editor_viewport_3d(0)
	return _save_image(viewport.get_texture().get_image(), name)


# Кадр сцены со своей камеры: вид редактора у человека при этом не сдвигается.
func _render(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _error("сцена не открыта")
	var from = _convert(args.get("from"), TYPE_VECTOR3)
	var to = _convert(args.get("to"), TYPE_VECTOR3)
	if from == null or to == null:
		return _error("нужны from и to: [x, y, z]")
	var view := SubViewport.new()
	view.size = Vector2i(int(args.get("width", 1280)), int(args.get("height", 720)))
	view.world_3d = EditorInterface.get_editor_viewport_3d(0).find_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var camera := Camera3D.new()
	camera.fov = float(args.get("fov", 70.0))
	camera.near = 0.05
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.48, 0.5)
	env.ambient_light_energy = float(args.get("ambient", 0.45))
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	camera.environment = env
	view.add_child(camera)
	add_child(view)
	camera.look_at_from_position(from, to)
	camera.make_current()
	for i in 3:
		await _wait_for_draw()
	var result := _save_image(view.get_texture().get_image(), str(args.get("name", "render")))
	view.queue_free()
	return result
