extends Node
## Упрощённые тени для дальних ламп (автозагрузка LightLOD).
##
## Каждая лампа с тенью в режиме Compatibility заново рисует сцену для своей
## карты теней (у OmniLight3D это куб из шести граней). Когда в квартире горят
## все лампы и открыты двери, таких проходов набирается много, и FPS падает.
##
## Скрипт сам находит все OmniLight3D и SpotLight3D, у которых в сцене включены
## тени, и оставляет тени только у MAX_SHADOWED ближайших к камере ламп в радиусе
## SHADOW_DISTANCE. У остальных тень выключается, сам свет продолжает гореть.
## Когда игрок подходит ближе, тень возвращается. Править сцены квартиры не нужно.
##
## Группы для ламп:
##   "always_shadow" — тень не выключается никогда (например, фонарик в руке);
##   "no_light_lod"  — скрипт эту лампу не трогает совсем.
##
## Если код игры сам включает или выключает тень у лампы во время игры,
## пусть вызывает LightLOD.set_wants_shadow(lamp, true/false), иначе скрипт
## перепишет shadow_enabled при следующем обновлении.
##
## F8 — включить или выключить упрощение (для замера), F9 — FPS и число ламп
## с тенями в заголовке окна.

## Дальше этого расстояния (в метрах) от камеры лампа теряет тень.
const SHADOW_DISTANCE := 12.0
## Запас, чтобы тень не мигала, когда игрок стоит ровно на границе.
const HYSTERESIS := 1.5
## Сколько ламп одновременно могут отбрасывать тень.
const MAX_SHADOWED := 3
## Как часто пересчитывать (секунды). Каждый кадр не нужно.
const UPDATE_INTERVAL := 0.2

const META_WANTS := &"light_lod_wants_shadow"

var enabled := true
var show_stats := false

var _lights: Array[Light3D] = []
var _timer := 0.0
var _shadowed_now := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_on_node_added)
	_scan(get_tree().root)


func _on_node_added(node: Node) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		# Лампы часто настраивают уже после add_child, поэтому смотрим на них
		# в конце кадра, когда код постройки уровня закончил.
		_register.call_deferred(node)


func _scan(node: Node) -> void:
	if node is OmniLight3D or node is SpotLight3D:
		_register(node)
	for child in node.get_children():
		_scan(child)


func _register(light: Light3D) -> void:
	if not is_instance_valid(light) or light in _lights:
		return
	if light.is_in_group(&"no_light_lod"):
		return
	if not light.has_meta(META_WANTS):
		light.set_meta(META_WANTS, light.shadow_enabled)
	_lights.append(light)
	_timer = 0.0


## Сообщить, нужна ли лампе тень вообще (вместо прямой записи shadow_enabled).
func set_wants_shadow(light: Light3D, wants: bool) -> void:
	light.set_meta(META_WANTS, wants)
	if not light in _lights:
		_register(light)
	_timer = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			enabled = not enabled
			_timer = 0.0
		elif event.keycode == KEY_F9:
			show_stats = not show_stats
			if not show_stats:
				DisplayServer.window_set_title(ProjectSettings.get_setting("application/config/name"))


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = UPDATE_INTERVAL
		_update()
	if show_stats:
		DisplayServer.window_set_title("FPS %d | тени %d из %d | упрощение %s (F8)" % [
			Engine.get_frames_per_second(), _shadowed_now, _count_wanting(),
			"вкл" if enabled else "выкл"])


func _update() -> void:
	var cam := get_viewport().get_camera_3d()
	var candidates: Array = []
	var i := _lights.size() - 1
	while i >= 0:
		var light := _lights[i]
		if not is_instance_valid(light):
			_lights.remove_at(i)
		i -= 1

	for light in _lights:
		if not light.get_meta(META_WANTS, false):
			light.shadow_enabled = false
			continue
		if not enabled or cam == null or light.is_in_group(&"always_shadow"):
			light.shadow_enabled = true
			continue
		# Погашенная лампа тени не даёт, и место в лимите ей не нужно.
		if not light.is_visible_in_tree() or light.light_energy <= 0.0:
			light.shadow_enabled = false
			continue
		var dist := light.global_position.distance_to(cam.global_position)
		# Лампа, у которой тень уже есть, держит её чуть дольше (гистерезис).
		var limit := SHADOW_DISTANCE + (HYSTERESIS if light.shadow_enabled else 0.0)
		if dist <= limit:
			candidates.append([dist - (HYSTERESIS if light.shadow_enabled else 0.0), light])
		else:
			light.shadow_enabled = false

	candidates.sort_custom(func(a, b): return a[0] < b[0])
	for k in candidates.size():
		candidates[k][1].shadow_enabled = k < MAX_SHADOWED
	_shadowed_now = 0
	for light in _lights:
		if light.shadow_enabled:
			_shadowed_now += 1


func _count_wanting() -> int:
	var n := 0
	for light in _lights:
		if is_instance_valid(light) and light.get_meta(META_WANTS, false):
			n += 1
	return n
