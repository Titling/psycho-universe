# Инвентарь: что герой носит с собой. Пока это только список, позже к нему можно привязать
# ключи и сюжетные предметы. При переходе между уровнями вещи переезжают вместе с героем.
extends RefCounted

const CAPACITY := 12
const CARRY_META := &"carried_inventory"   # где вещи ждут следующего уровня во время смены сцены

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


# Перед сменой сцены: вещи вынимаются из уровня, чтобы не исчезнуть вместе с ним,
# и ждут у корня дерева, который при смене сцены остаётся.
func pack(tree: SceneTree) -> void:
	for item in items:
		item.get_parent().remove_child(item)
	tree.root.set_meta(CARRY_META, items)
	items = []


# На новом уровне: забрать вещи, которые принёс герой. Если ничего не несли, список пустой.
static func unpack(tree: SceneTree) -> Array:
	if not tree.root.has_meta(CARRY_META):
		return []
	var carried: Array = tree.root.get_meta(CARRY_META)
	tree.root.remove_meta(CARRY_META)
	return carried
