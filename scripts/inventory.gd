# Инвентарь: что герой носит с собой. Пока это только список, позже к нему можно привязать
# ключи, сюжетные предметы и переход между уровнями.
extends RefCounted

const CAPACITY := 12

var items: Array = []


func is_full() -> bool:
	return items.size() >= CAPACITY


func titles() -> Array:
	var result := []
	for item in items:
		result.append(item.title)
	return result


func add(item: Node) -> void:
	items.append(item)


func remove_at(index: int) -> Node:
	var item: Node = items[index]
	items.remove_at(index)
	return item
