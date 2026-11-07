# Мир 3 «Зал ожидания». Всё неподвижное лежит в scenes/world3.tscn.
# Здесь только живые детали: мигающая лампа (группа flicker) и табло очереди.
extends "res://scripts/worlds/world_base.gd"

var _flicker: Array[Node] = []
var _board: Label3D


func _ready() -> void:
	_flicker = get_tree().get_nodes_in_group("flicker")
	_board = get_tree().get_first_node_in_group("queue_board")
	super._ready()


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var on := fmod(t * 7.3, 5.0) > 0.6 and sin(t * 13.0) > -0.8
	for n in _flicker:
		n.visible = on
	if _board != null:
		_board.text = "ВЫЗЫВАЕТСЯ\n№ %03d" % (1 + int(t / 20.0))
