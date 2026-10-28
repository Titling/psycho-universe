# Найденный телефон в руке ГГ: на него приходят SMS, и это фонарик с батареей.
# Батарея садится, пока горит свет. Зарядить можно только от розеток.
extends Node3D

signal battery_low

const DRAIN := 1.0 / 90.0      # полной батареи хватает на полторы минуты света
const REST := Vector3(0.24, -0.27, -0.46)
const RAISED := Vector3(0.17, -0.16, -0.4)

var battery := 1.0
var light_on := false
var light: SpotLight3D

var _screen: MeshInstance3D
var _screen_mat: StandardMaterial3D
var _warned := false
var _tween: Tween


func _ready() -> void:
	position = REST
	rotation = Vector3(0.35, -0.25, 0.05)

	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.065, 0.13, 0.012)
	body.mesh = box
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.06, 0.06, 0.07)
	body.material_override = dark
	add_child(body)

	_screen = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.055, 0.112)
	_screen.mesh = quad
	_screen.position.z = 0.0065
	_screen_mat = StandardMaterial3D.new()
	_screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_screen.material_override = _screen_mat
	add_child(_screen)

	# рука, которая держит телефон
	var hand := MeshInstance3D.new()
	var hand_box := BoxMesh.new()
	hand_box.size = Vector3(0.08, 0.07, 0.03)
	hand.mesh = hand_box
	hand.position = Vector3(0.01, -0.06, -0.012)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.55, 0.42, 0.35)
	hand.material_override = skin
	add_child(hand)

	light = SpotLight3D.new()
	light.spot_range = 18.0
	light.spot_angle = 26.0
	light.light_energy = 0.0
	light.light_color = Color(0.85, 0.92, 1.0)
	light.position = Vector3(0, 0.06, -0.01)
	add_child(light)
	_update_screen(false)


func _process(delta: float) -> void:
	# свет всегда смотрит туда же, куда камера, даже если телефон наклонён
	light.global_basis = get_parent().global_basis
	if light_on:
		battery = maxf(battery - DRAIN * delta, 0.0)
		if battery <= 0.0:
			set_light(false)
		elif battery < 0.2 and not _warned:
			_warned = true
			battery_low.emit()
	# при севшей батарее свет начинает мигать
	var flicker := 1.0
	if light_on and battery < 0.15 and fmod(Time.get_ticks_msec() / 1000.0 * 9.0, 4.0) < 0.5:
		flicker = 0.2
	light.light_energy = 3.0 * flicker if light_on else 0.0


func toggle() -> void:
	set_light(not light_on)


func set_light(value: bool) -> void:
	light_on = value and battery > 0.0
	_update_screen(light_on)


func charge() -> void:
	battery = 1.0
	_warned = false


# Попадает ли точка в луч фонарика.
func lights_up(point: Vector3) -> bool:
	if not light_on:
		return false
	var to := point - light.global_position
	if to.length() > light.spot_range:
		return false
	return (-light.global_basis.z).dot(to.normalized()) > cos(deg_to_rad(light.spot_angle))


# Поднять телефон к глазам, когда пришло сообщение.
func show_message(time := 4.0) -> void:
	if _tween:
		_tween.kill()
	_update_screen(true)
	_tween = create_tween()
	_tween.tween_property(self, "position", RAISED, 0.25)
	_tween.tween_interval(time)
	_tween.tween_property(self, "position", REST, 0.4)
	_tween.tween_callback(func(): _update_screen(light_on))


func _update_screen(lit: bool) -> void:
	_screen_mat.albedo_color = Color(0.42, 0.52, 0.62) if lit else Color(0.04, 0.05, 0.07)
