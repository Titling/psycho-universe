# Зона, на которую можно навести взгляд и нажать E.
extends Area3D

signal used

var prompt := "Действие"
var enabled := true


func setup(size: Vector3, text: String) -> void:
	prompt = text
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)


func use() -> void:
	used.emit()
