# Курсор, который рисует сама игра: в эксклюзивном полном экране системный может не показываться.
# Виден, только когда мышь не захвачена камерой. Системный курсор при этом скрыт.
extends CanvasLayer

const ARROW := [Vector2(0, 0), Vector2(0, 21), Vector2(5, 16.5), Vector2(8.5, 24), Vector2(12, 22.5), Vector2(8.5, 15), Vector2(15, 15)]

var _pointer: Node2D


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pointer = Node2D.new()
	add_child(_pointer)
	var shadow := Polygon2D.new()
	shadow.polygon = PackedVector2Array(ARROW)
	shadow.color = Color(0, 0, 0, 0.9)
	shadow.scale = Vector2(1.18, 1.14)
	shadow.position = Vector2(-1.2, -1.6)
	_pointer.add_child(shadow)
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array(ARROW)
	arrow.color = Color(0.86, 0.83, 0.75)
	_pointer.add_child(arrow)


func _process(_delta: float) -> void:
	_pointer.visible = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	_pointer.position = get_viewport().get_mouse_position()
