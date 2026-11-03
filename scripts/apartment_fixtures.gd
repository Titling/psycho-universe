# То, чем можно пользоваться в квартире: кран и холодильник. Подмены включают их теми же
# функциями, поэтому игрок может найти открытый холодильник и сам его закрыть.
extends Node

const InteractableScript := preload("res://scripts/interactable.gd")
const SoundsScript := preload("res://scripts/apartment_sounds.gd")
const D := preload("res://data/dialogues.gd")
const POT_MODEL := preload("res://models/pot_enamel_01/pot_enamel_01_1k.gltf")

const SPOUT := Vector3(5.34, 1.13, 1.05)
const SINK_BOTTOM := 0.91
const FRIDGE_HINGE := Vector3(5.66, 0.0, 3.06)
const FRIDGE_OPEN_DEGREES := 105.0
const FRIDGE_LIGHT_POS := Vector3(5.72, 0.75, 3.35)
const SHELF_HEIGHTS := [-0.2, 0.2]   # от центра задней стенки холодильника
const SOUP_LEVEL := 0.105          # м от дна кастрюли (сама она высотой 0.13)

var root: Node3D
var player: CharacterBody3D
var ui: Node
var sounds: Node

var water_on := false
var fridge_open := false

var _water_mesh: MeshInstance3D
var _water_sound: AudioStreamPlayer3D
var _water_zone: Area3D
var _fridge_hinge: Node3D
var _fridge_zone: Area3D
var _fridge_glow: MeshInstance3D
var _fridge_light: OmniLight3D
var _fridge_sound: AudioStreamPlayer3D
var _fridge_seen := false
var _tween: Tween


func _ready() -> void:
	_build_tap()
	_build_fridge()


func _zone(pos: Vector3, size: Vector3, prompt: String, action: Callable) -> Area3D:
	var zone := InteractableScript.new()
	zone.setup(size, prompt)
	zone.position = pos
	zone.used.connect(action)
	root.add_child(zone)
	return zone


func _build_tap() -> void:
	var stream := CylinderMesh.new()
	stream.top_radius = 0.007
	stream.bottom_radius = 0.009
	stream.height = SPOUT.y - SINK_BOTTOM
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.8, 0.88, 0.75)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.15
	_water_mesh = MeshInstance3D.new()
	_water_mesh.mesh = stream
	_water_mesh.material_override = material
	_water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_mesh.visible = false
	root.add_child(_water_mesh)
	_water_mesh.global_position = Vector3(SPOUT.x, (SPOUT.y + SINK_BOTTOM) / 2.0, SPOUT.z)
	_water_sound = sounds.add_spatial(SPOUT, SoundsScript.water(), "Кухня", -8.0)
	_water_zone = _zone(Vector3(5.22, 1.1, 1.05), Vector3(0.28, 0.2, 0.14), "Открыть кран", func(): set_water(not water_on))


func set_water(on: bool) -> void:
	water_on = on
	_water_mesh.visible = on
	sounds.dripping = not on
	if on:
		_water_sound.play()
	else:
		_water_sound.stop()
	_water_zone.prompt = "Закрыть кран" if on else "Открыть кран"


func _build_fridge() -> void:
	var fridge: Node3D = root.get_node("Кухня/Холодильник")
	_fridge_hinge = Node3D.new()
	_fridge_hinge.name = "Петля_дверцы"
	fridge.add_child(_fridge_hinge)
	_fridge_hinge.global_position = FRIDGE_HINGE
	for part in ["Дверца_низ", "Ручка_низ"]:
		fridge.get_node(part).reparent(_fridge_hinge)

	# Внутри: корпус — сплошная коробка, поэтому полка и свет лежат на его передней стенке.
	var panel := BoxMesh.new()
	panel.size = Vector3(0.01, 1.08, 0.52)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.86, 0.88, 0.84)
	glow.emission_enabled = true
	glow.emission = Color(0.8, 0.84, 0.8)
	glow.emission_energy_multiplier = 0.12
	_fridge_glow = MeshInstance3D.new()
	_fridge_glow.mesh = panel
	_fridge_glow.material_override = glow
	_fridge_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fridge_glow.visible = false
	fridge.add_child(_fridge_glow)
	_fridge_glow.global_position = Vector3(5.605, 0.62, 3.35)
	# Две полки и кастрюля с тем самым супом из записки.
	for y in SHELF_HEIGHTS:
		_add_inside(Vector3(0.05, 0.015, 0.5), Vector3(0.03, y, 0), Color(0.7, 0.72, 0.7))
	_add_soup_pot()

	_fridge_light = OmniLight3D.new()
	_fridge_light.light_color = Color(0.85, 0.92, 0.9)
	_fridge_light.light_energy = 0.5
	_fridge_light.omni_range = 1.6
	_fridge_light.visible = false
	fridge.add_child(_fridge_light)
	_fridge_light.global_position = FRIDGE_LIGHT_POS

	_fridge_sound = AudioStreamPlayer3D.new()
	_fridge_sound.unit_size = 2.5
	_fridge_sound.max_distance = 11.0
	fridge.add_child(_fridge_sound)
	_fridge_sound.global_position = FRIDGE_LIGHT_POS
	_fridge_zone = _zone(Vector3(5.68, 0.64, 3.35), Vector3(0.12, 1.16, 0.58), "Открыть холодильник", _use_fridge)


func _add_inside(size: Vector3, offset: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = offset
	_fridge_glow.add_child(part)


# Эмалированная кастрюля без крышки на нижней полке, суп сверху затянут плесенью.
# Корпус холодильника сплошной, поэтому задняя половина кастрюли уходит в стенку:
# спереди, откуда на неё смотрит игрок, этого не видно.
func _add_soup_pot() -> void:
	var pot: Node3D = POT_MODEL.instantiate()
	pot.name = "Кастрюля_с_супом"
	var lid := pot.get_node_or_null("pot_enamel_01_lid")
	if lid:
		lid.free()
	for mesh in pot.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pot.rotation.y = PI / 2.0   # ручки вдоль стенки, а не на игрока
	pot.position = Vector3(0.02, SHELF_HEIGHTS[0] + 0.008, 0.06)
	_fridge_glow.add_child(pot)

	var surface := CylinderMesh.new()
	surface.top_radius = 0.084
	surface.bottom_radius = 0.084
	surface.height = 0.004
	surface.radial_segments = 24
	var mould := StandardMaterial3D.new()
	mould.albedo_color = Color(0.8, 0.82, 0.74)
	mould.roughness = 1.0
	var noise := NoiseTexture2D.new()
	noise.width = 64
	noise.height = 64
	noise.noise = FastNoiseLite.new()
	noise.noise.frequency = 0.09
	noise.color_ramp = Gradient.new()
	noise.color_ramp.set_color(0, Color(0.55, 0.38, 0.22))   # сам суп, бурый
	noise.color_ramp.set_color(1, Color(0.9, 0.95, 0.85))    # белёсые пятна плесени
	mould.albedo_texture = noise
	var soup := MeshInstance3D.new()
	soup.name = "Плесень"
	soup.mesh = surface
	soup.material_override = mould
	soup.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	soup.position = Vector3(0, SOUP_LEVEL, 0)
	pot.add_child(soup)


func _use_fridge() -> void:
	set_fridge(not fridge_open)
	if fridge_open and not _fridge_seen:
		_fridge_seen = true
		player.locked = true
		await ui.say(D.FRIDGE_FIRST_LOOK)
		player.locked = false


func set_fridge(open: bool, angle := FRIDGE_OPEN_DEGREES) -> void:
	fridge_open = open
	_fridge_glow.visible = open
	_fridge_light.visible = open
	_fridge_zone.prompt = "Закрыть холодильник" if open else "Открыть холодильник"
	_fridge_sound.stream = SoundsScript.creak()
	_fridge_sound.volume_db = -14.0
	_fridge_sound.play()
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_fridge_hinge, "rotation:y", deg_to_rad(angle) if open else 0.0, 0.5)
