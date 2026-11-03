extends Node
## Упрощённые тени для дальних ламп (автозагрузка LightLOD).
##
## В режиме Compatibility каждая лампа с тенью заново рисует сцену в свою карту
## теней: OmniLight3D шесть раз (куб), SpotLight3D один раз. Когда в квартире
## горят все лампы и открыты двери, таких проходов набирается больше двадцати
## за кадр, и FPS падает.
##
## Скрипт сам находит все OmniLight3D и SpotLight3D, у которых в сцене включены
## тени, и каждый кадр раздаёт тени по «бюджету» SHADOW_BUDGET: сначала лампам,
## которые сильнее всего светят туда, где стоит камера, потом остальным, пока
## бюджет не кончится. Круглая лампа стоит OMNI_COST, направленная SPOT_COST.
## У ламп без тени сам свет продолжает гореть. Когда игрок подходит ближе,
## тень возвращается. Править сцены не нужно.
##
## Лампы, которые висят на камере (фонарик телефона), держат тень всегда и
## бюджет не тратят. Погашенные и скрытые лампы бюджет тоже не тратят.
##
## Группы для ламп:
##   "always_shadow" — тень не выключается никогда;
##   "no_light_lod"  — скрипт эту лампу не трогает совсем.
##
## Если код игры сам включает или выключает тень у лампы во время игры,
## пусть вызывает LightLOD.set_wants_shadow(lamp, true/false), иначе скрипт
## перепишет shadow_enabled в следующем кадре.
##
## F8 — включить или выключить упрощение (для замера), F9 — FPS и число ламп
## с тенями в заголовке окна.

## Сколько «проходов теней» можно потратить за кадр. 14 = две круглые лампы
## и две направленные (луна в окнах). Больше — красивее, меньше — быстрее.
const SHADOW_BUDGET := 14
const OMNI_COST := 6
const SPOT_COST := 1
## Лампа, у которой тень уже есть, считается ярче на эту долю, чтобы тени
## не перескакивали туда-сюда, когда две лампы светят почти одинаково.
const HYSTERESIS := 0.25

const META_WANTS := &"light_lod_wants_shadow"

var enabled := true
var show_stats := false

var _lights: Array[Light3D] = []
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


## Сообщить, нужна ли лампе тень вообще (вместо прямой записи shadow_enabled).
func set_wants_shadow(light: Light3D, wants: bool) -> void:
	light.set_meta(META_WANTS, wants)
	if not light in _lights:
		_register(light)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8:
			enabled = not enabled
		elif event.keycode == KEY_F9:
			show_stats = not show_stats
			if not show_stats:
				DisplayServer.window_set_title(ProjectSettings.get_setting("application/config/name"))


func _process(_delta: float) -> void:
	_update()
	if show_stats:
		DisplayServer.window_set_title("FPS %d | тени %d из %d | упрощение %s (F8)" % [
			Engine.get_frames_per_second(), _shadowed_now, _count_wanting(),
			"вкл" if enabled else "выкл"])


func _update() -> void:
	var cam := get_viewport().get_camera_3d()
	var candidates: Array = []
	for i in range(_lights.size() - 1, -1, -1):
		if not is_instance_valid(_lights[i]):
			_lights.remove_at(i)

	for light in _lights:
		if not light.get_meta(META_WANTS, false):
			light.shadow_enabled = false
			continue
		if not enabled or cam == null or light.is_in_group(&"always_shadow") or cam.is_ancestor_of(light):
			light.shadow_enabled = true
			continue
		# Скрытая лампа ничего не стоит. Её тень не трогаем, чтобы при включении
		# она не мелькнула без тени.
		if not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue
		var score := _strength_at(light, cam.global_position)
		if light.shadow_enabled:
			score *= 1.0 + HYSTERESIS
		candidates.append([score, light])

	candidates.sort_custom(func(a, b): return a[0] > b[0])
	var budget := SHADOW_BUDGET
	for c in candidates:
		var light: Light3D = c[1]
		var cost := OMNI_COST if light is OmniLight3D else SPOT_COST
		var on := cost <= budget
		if on:
			budget -= cost
		light.shadow_enabled = on

	_shadowed_now = 0
	for light in _lights:
		if light.shadow_enabled and light.is_visible_in_tree():
			_shadowed_now += 1


## Примерно как сильно лампа светит в точку (та же формула затухания, что в Godot).
## Лампа, которая до камеры не достаёт, всё равно получает небольшой вес по
## расстоянию: свет от неё может быть виден в дверном проёме.
func _strength_at(light: Light3D, point: Vector3) -> float:
	var d := maxf(light.global_position.distance_to(point), 0.5)
	var light_range: float
	var attenuation: float
	if light is OmniLight3D:
		light_range = light.omni_range
		attenuation = light.omni_attenuation
	else:
		light_range = light.spot_range
		attenuation = light.spot_attenuation
	var reach := pow(maxf(1.0 - pow(d / maxf(light_range, 0.01), 4.0), 0.0), 2.0)
	var falloff := pow(d, -attenuation) if attenuation > 0.0 else 1.0
	return light.light_energy * (reach * falloff + 0.001 / d)


func _count_wanting() -> int:
	var n := 0
	for light in _lights:
		if is_instance_valid(light) and light.get_meta(META_WANTS, false):
			n += 1
	return n
