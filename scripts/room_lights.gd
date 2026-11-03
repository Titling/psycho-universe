# Свет по комнатам. Если игрока в комнате нет и дверь в неё закрыта, свет выключается,
# иначе остаётся включённым. У коридора своей двери нет: для него «дверь» открыта,
# если открыта любая дверь, которая в него ведёт.
# Лампы ещё слушаются выключателя, а свет луны от выключателя не зависит.
extends Node

var player: Node3D
var rooms := {}   # имя: {area: Rect2 по осям X и Z, lamps: Array, moon: Array, doors: Array, switched_on: bool}

var _state := ""


func add_room(room_name: String, area: Rect2, lamps: Array, doors: Array, moon := []) -> void:
	rooms[room_name] = {"area": area, "lamps": lamps, "moon": moon, "doors": doors, "switched_on": true}


func is_player_in(room_name: String) -> bool:
	var p := player.global_position
	return rooms[room_name].area.has_point(Vector2(p.x, p.z))


func is_door_open(room_name: String) -> bool:
	for door in rooms[room_name].doors:
		if not door.fully_closed:
			return true
	return false


func toggle_switch(room_name: String) -> void:
	rooms[room_name].switched_on = not rooms[room_name].switched_on


func set_switch(room_name: String, on: bool) -> void:
	rooms[room_name].switched_on = on


# Горит ли лампа там, где стоит игрок.
func is_player_lit() -> bool:
	for room_name in rooms:
		if is_player_in(room_name) and rooms[room_name].switched_on:
			return true
	return false


func _process(_delta: float) -> void:
	var state := ""
	for room_name in rooms:
		state += "1" if is_player_in(room_name) or is_door_open(room_name) else "0"
		state += "1" if rooms[room_name].switched_on else "0"
	if state == _state:
		return
	_state = state
	var i := 0
	for room_name in rooms:
		var seen := state[i] == "1"
		for lamp in rooms[room_name].lamps:
			lamp.visible = seen and state[i + 1] == "1"
		for light in rooms[room_name].moon:
			light.visible = seen
		i += 2
