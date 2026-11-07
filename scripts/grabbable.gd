# Предмет, который можно взять в руки, бросить и толкнуть. Пока его не трогали, он заморожен:
# лежит ровно там, где стоит в сцене, и ничего не считает.
extends RigidBody3D

const SoundsScript := preload("res://scripts/apartment_sounds.gd")

const PROP_LAYER := 16      # слой предметов: их видит луч игрока, но сквозь мелочь можно пройти
const WORLD_LAYER := 1
const MIN_SIZE := 0.05      # совсем тонкие коробки дрожат на полу
const STILL_SPEED := 0.25
const STILL_SPIN := 1.5
const STILL_TIME := 0.35    # столько предмет почти не двигается, и его можно снова заморозить
const SETTLE_LIMIT := 3.0   # дрожащий предмет замораживается в любом случае
const GROUND_GAP := 0.15
const BOUNCE_LOSS := 0.3
const DENSITY := 220.0      # кг на м³ по габаритам: большая часть предметов полая
const MIN_MASS := 0.15
const MAX_MASS := 5.0
const HIT_SOUND_SPEED := 1.2
const SUPPORT_GAP := 0.06

var prompt := "Взять"
var enabled := true
var title := ""
var pocketable := true      # помещается ли в инвентарь
var hands: Node
var touched := false        # игрок брал или толкал предмет: подмены его больше не трогают
var radius := 0.1
var area := AABB()          # дальше этих границ предмет не улетит
var icon: Texture2D = null

var _sound: AudioStreamPlayer3D
var _held := false
var _still_time := 0.0
var _active_time := 0.0
var _last_position := Vector3.ZERO
var _safe_position := Vector3.ZERO


# Заменяет узел сцены телом с тем же именем: кто искал узел по пути, найдёт тело.
# blocks_player: об него игрок спотыкается и толкает его (стул), а мелочь не мешает ходить.
static func wrap(node: Node3D, item_title: String, can_pocket: bool, blocks_player: bool, extras: Array, item_hands: Node, item_area: AABB) -> RigidBody3D:
	var body = load("res://scripts/grabbable.gd").new()
	var parts: Array = [node] + extras
	var bounds := _bounds(parts)
	var parent := node.get_parent()
	var original_name := node.name
	node.name = String(original_name) + "_модель"
	body.name = original_name
	parent.add_child(body)
	body.global_position = bounds.get_center()
	for part in parts:
		part.reparent(body)
		_remove_static_bodies(part)
	body.title = item_title
	body.pocketable = can_pocket
	body.hands = item_hands
	body.area = item_area
	body.prompt = "Взять: " + item_title
	body.collision_layer = PROP_LAYER | (WORLD_LAYER if blocks_player else 0)
	body.collision_mask = PROP_LAYER | WORLD_LAYER
	var box := BoxShape3D.new()
	box.size = bounds.size.max(Vector3.ONE * MIN_SIZE)
	body.radius = box.size[box.size.max_axis_index()] / 2.0
	var shape := CollisionShape3D.new()
	shape.shape = box
	body.add_child(shape)
	body.mass = clampf(box.size.x * box.size.y * box.size.z * DENSITY, MIN_MASS, MAX_MASS)
	return body


static func _bounds(parts: Array) -> AABB:
	var bounds := AABB()
	var first := true
	for part in parts:
		var meshes: Array = part.find_children("*", "MeshInstance3D", true, false)
		if part is MeshInstance3D:
			meshes.append(part)
		for mesh in meshes:
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
	return bounds


static func _remove_static_bodies(node: Node) -> void:
	for child in node.get_children():
		if child is StaticBody3D:
			child.free()
		else:
			_remove_static_bodies(child)


func _ready() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	can_sleep = false   # засыпает он сам, заморозкой: движок усыплял предмет в воздухе у стены
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = 0.8
	physics_material_override.bounce = 0.05
	_sound = AudioStreamPlayer3D.new()
	_sound.unit_size = 1.5
	_sound.max_distance = 10.0
	add_child(_sound)


# Не у всех полок и подоконников в сцене есть столкновения. Если под предметом пусто,
# кладём невидимую подставку, иначе от удара он провалится сквозь полку.
func add_support_if_missing() -> void:
	var size: Vector3 = find_children("*", "CollisionShape3D", false, false)[0].shape.size
	var bottom := global_position - Vector3(0, size.y / 2.0, 0)
	var query := PhysicsRayQueryParameters3D.create(global_position, bottom - Vector3(0, SUPPORT_GAP, 0), WORLD_LAYER)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		return
	var plate := BoxShape3D.new()
	plate.size = Vector3(size.x + 0.1, 0.02, size.z + 0.1)
	var plate_shape := CollisionShape3D.new()
	plate_shape.shape = plate
	var support := StaticBody3D.new()
	support.name = "Подставка_" + name
	support.collision_layer = PROP_LAYER
	support.collision_mask = 0
	support.add_child(plate_shape)
	get_parent().add_child(support)
	support.global_position = bottom - Vector3(0, 0.01, 0)


func use() -> void:
	hands.take(self)


func wake() -> void:
	freeze = false
	sleeping = false
	_still_time = 0.0
	_active_time = 0.0
	_last_position = global_position
	_safe_position = global_position


# Игрок упёрся в предмет на ходу.
func push(impulse: Vector3) -> void:
	touched = true
	wake()
	apply_central_impulse(impulse)


func _physics_process(delta: float) -> void:
	if freeze:
		return
	_keep_out_of_walls()
	if _held:
		return
	_active_time += delta
	if linear_velocity.length() < STILL_SPEED and angular_velocity.length() < STILL_SPIN:
		_still_time += delta
	else:
		_still_time = 0.0
	# Лежит на месте: замораживаем, чтобы не дрожал и не считался. В воздухе не замораживаем.
	if (_still_time > STILL_TIME or _active_time > SETTLE_LIMIT) and _has_ground():
		freeze = true


func _has_ground() -> bool:
	var below := global_position - Vector3(0, radius + GROUND_GAP, 0)
	var query := PhysicsRayQueryParameters3D.create(global_position, below, WORLD_LAYER | PROP_LAYER, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# За один шаг физики быстрый предмет может перескочить тонкую стену. Смотрим, не пересёк
# ли он её по пути, и возвращаем к стене. Границы квартиры — последняя страховка.
func _keep_out_of_walls() -> void:
	var query := PhysicsRayQueryParameters3D.create(_last_position, global_position, WORLD_LAYER, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.position + hit.normal * radius
		linear_velocity = linear_velocity.bounce(hit.normal) * BOUNCE_LOSS
	elif area.has_point(global_position):
		_safe_position = global_position
	else:
		global_position = _safe_position
		linear_velocity = Vector3.ZERO
	_last_position = global_position


func set_held(value: bool, player: Node) -> void:
	_held = value
	touched = true
	enabled = not value
	gravity_scale = 0.0 if value else 1.0
	linear_damp = 4.0 if value else 0.1
	angular_damp = 6.0 if value else 0.6
	wake()
	if value:
		add_collision_exception_with(player)
		return
	remove_collision_exception_with(player)
	if not contact_monitor:
		contact_monitor = true
		max_contacts_reported = 4
		body_entered.connect(_on_hit)


func _on_hit(other: Node) -> void:
	if other.has_method("wake"):
		other.wake()
	if linear_velocity.length() > HIT_SOUND_SPEED:
		_sound.stream = SoundsScript.step(false, 0)
		_sound.pitch_scale = randf_range(1.1, 1.7)
		_sound.play()


# В инвентаре предмет не виден и не участвует в физике.
func set_stored(value: bool) -> void:
	visible = not value
	freeze = value
	process_mode = Node.PROCESS_MODE_DISABLED if value else Node.PROCESS_MODE_INHERIT
