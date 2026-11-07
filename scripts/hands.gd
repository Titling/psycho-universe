# Руки героя: держат предмет перед собой, кладут, бросают, убирают в инвентарь.
extends Node

const InventoryScript := preload("res://scripts/inventory.gd")
const ItemCatalog := preload("res://scripts/item_catalog.gd")
# Границы для вещей, которые пришлось достать из сцены квартиры, если у уровня своих нет.
const FALLBACK_AREA := AABB(Vector3(-300, -20, -300), Vector3(600, 120, 600))

const HOLD_DISTANCE := 0.8
const HOLD_DROP := -0.15     # предмет чуть ниже центра взгляда
const FOLLOW_SPEED := 14.0
const MAX_SPEED := 9.0
const LOST_DISTANCE := 1.4   # предмет застрял за стеной: герой его выпускает
const REACH_TIME := 1.0      # столько предмет летит в руки издалека, пока это не считается застреванием
const THROW_SPEED := 7.0
const WORLD_LAYER := 1
const TURN_SPEED := 0.008    # радиан на пиксель мыши
const ICON_SIZE := 128
const ICON_FOV := 30.0

var player: CharacterBody3D
var ui: Node
var area := AABB()   # границы уровня для принесённых вещей; пустые — оставить их старые границы
var inventory = InventoryScript.new()
var held: Node = null
var save_key := "items"   # часть сохранения, см. scripts/save_game.gd

var _storage: Node3D
var _inventory_open := false
var _reach_time := 0.0
var _turning := false
var _turn_input := Vector2.ZERO


func _ready() -> void:
	add_to_group("saveable")
	_storage = Node3D.new()
	_storage.name = "Вещи_в_инвентаре"
	add_child(_storage)
	_adopt_carried()


# Вещи, которые герой принёс с прошлого уровня, сразу лежат в инвентаре.
func _adopt_carried() -> void:
	for item in InventoryScript.unpack(get_tree()):
		if not is_instance_valid(item):
			continue
		_storage.add_child(item)
		item.hands = self
		if area.has_volume():
			item.area = area
		inventory.add(item)


# Уход с уровня, шаг 1: вещь из рук убирается в инвентарь, если влезает, иначе остаётся здесь.
func stash_held() -> void:
	if held == null:
		return
	if held.pocketable and not inventory.is_full():
		_store_held()
	else:
		release()


# Уход с уровня, шаг 2, прямо перед сменой сцены: инвентарь уезжает вместе с героем.
func pack_for_travel() -> void:
	if held != null:
		release()
	inventory.pack(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _inventory_open:
			ui.close_inventory()
		elif not player.locked and not ui.talking:
			_open_inventory()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_turning = event.pressed and held != null and not player.locked
	if held == null or player.locked:
		return
	if _turning and event is InputEventMouseMotion:
		_turn_input += event.relative
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact"):
		release()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var item := held
		release()
		item.linear_velocity = -player.camera.global_basis.z * THROW_SPEED
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("store_item"):
		_store_held()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if held == null:
		return
	var camera: Camera3D = player.camera
	var target := camera.global_transform * Vector3(0, HOLD_DROP, -HOLD_DISTANCE)
	# Стена ближе вытянутой руки: держим предмет перед ней, а не за ней.
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, WORLD_LAYER, [held.get_rid()])
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit.position + hit.normal * held.radius
	var to_target: Vector3 = target - held.global_position
	_reach_time -= delta
	if _reach_time <= 0.0 and to_target.length() > LOST_DISTANCE:
		release()
		return
	held.linear_velocity = (to_target * FOLLOW_SPEED).limit_length(MAX_SPEED)
	_apply_turn(delta)
	ui.set_prompt(_held_prompt())


# Пока зажата ПКМ, мышь крутит предмет вокруг осей взгляда, а камера стоит на месте.
# Вращение идёт через угловую скорость: прямую установку поворота физика затирала.
func _apply_turn(delta: float) -> void:
	var view: Basis = player.camera.global_basis
	held.angular_velocity = (view.y * _turn_input.x + view.x * _turn_input.y) * TURN_SPEED / delta
	_turn_input = Vector2.ZERO


func _held_prompt() -> String:
	var text := "[E] Положить   [ЛКМ] Бросить   [ПКМ] Вертеть"
	if not held.pocketable:
		return text
	return text + ("   Инвентарь полон" if inventory.is_full() else "   [Q] В инвентарь")


func take(item: Node) -> void:
	if held != null:
		return
	held = item
	_reach_time = REACH_TIME
	player.carrying = true
	item.set_held(true, player)


func release() -> void:
	_turning = false
	held.set_held(false, player)
	held = null
	player.carrying = false
	ui.set_prompt("")


func _store_held() -> void:
	if not held.pocketable or inventory.is_full():
		return
	var item := held
	release()
	item.reparent(_storage)
	item.set_stored(true)
	inventory.add(item)
	if item.icon == null:
		_render_icon(item)


# Иконка — снимок самого предмета: отдельная маленькая сцена с копией его модели.
func _render_icon(item: Node) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for child in item.get_children():
		if child is Node3D and not child is CollisionShape3D and not child is AudioStreamPlayer3D:
			viewport.add_child(child.duplicate())
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.73, 0.7)
	environment.ambient_light_energy = 0.8
	var camera := Camera3D.new()
	camera.environment = environment
	camera.fov = ICON_FOV
	camera.near = 0.01
	camera.far = 20.0
	viewport.add_child(camera)
	var distance: float = item.radius * sqrt(3.0) / sin(deg_to_rad(ICON_FOV / 2.0))
	camera.look_at_from_position(Vector3(0.55, 0.65, 1.0).normalized() * distance, Vector3.ZERO)
	var sun := DirectionalLight3D.new()
	sun.light_energy = 1.2
	viewport.add_child(sun)
	sun.look_at_from_position(Vector3(0.4, 1.0, 0.8), Vector3.ZERO)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image != null:
		item.icon = ImageTexture.create_from_image(image)
	viewport.queue_free()


func _open_inventory() -> void:
	_inventory_open = true
	player.locked = true
	if not ui.inventory_closed.is_connected(_on_inventory_closed):
		ui.inventory_closed.connect(_on_inventory_closed)
	ui.open_inventory(inventory.items, inventory.CAPACITY, held != null, _take_out)


func _on_inventory_closed() -> void:
	_inventory_open = false
	player.locked = false


# Достать вещь: она сразу оказывается в руках.
func _take_out(index: int) -> void:
	var item: Node = inventory.remove_at(index)
	var camera: Camera3D = player.camera
	item.reparent(get_parent())
	item.global_position = camera.global_transform * Vector3(0, HOLD_DROP, -HOLD_DISTANCE)
	item.set_stored(false)
	take(item)


# ---------------------------------------------------------------- сохранение

# Что в инвентаре и где лежат вещи, которые игрок трогал. Вещь в руках считается лежащей там, где она сейчас.
func save_state() -> Dictionary:
	var stored := []
	for item in inventory.items:
		if item.origin != "":
			stored.append(item.origin)
	var loose := []
	for body in get_tree().get_nodes_in_group("grabbable"):
		if body.origin == "" or not body.touched or body in inventory.items:
			continue
		loose.append({"origin": body.origin, "position": body.global_position, "rotation": body.global_rotation})
	return {"inventory": stored, "loose": loose}


func load_state(data: Dictionary) -> void:
	if held != null:
		release()
	var stored: Array = data.get("inventory", [])
	var loose: Array = data.get("loose", [])
	var bodies := {}
	for body in get_tree().get_nodes_in_group("grabbable"):
		if body.origin != "":
			bodies[body.origin] = body
	# Вещей из квартиры на этом уровне может не быть: их модели берутся из сцены квартиры.
	var missing := []
	for origin in stored:
		if not bodies.has(origin):
			missing.append(origin)
	for entry in loose:
		if not bodies.has(entry.origin):
			missing.append(entry.origin)
	bodies.merge(ItemCatalog.spawn(missing, get_parent(), self, area if area.has_volume() else FALLBACK_AREA))

	for origin in stored:
		var item = bodies.get(origin)
		if item == null or item in inventory.items or inventory.is_full():
			continue
		item.touched = true
		item.reparent(_storage)
		item.set_stored(true)
		inventory.add(item)
		if item.icon == null:
			_render_icon(item)
	for entry in loose:
		var body = bodies.get(entry.origin)
		if body == null or body in inventory.items:
			continue
		body.touched = true
		body.freeze = true
		body.global_position = entry.position
		body.global_rotation = entry.rotation
