# Автотест: открывает все сцены игры и проверяет, что сохранения и инвентарь переживают
# переходы между уровнями. Запуск без окна:
#   godot --headless --path . res://tests/smoke_test.tscn
# Код выхода 0 — всё в порядке, 1 — что-то сломалось (подробности в выводе, строки FAIL).
# Тот же тест гоняет GitHub на каждый PR (.github/workflows/smoke.yml).
extends Node

const SCENES := [
	"res://scenes/menu.tscn",
	"res://scenes/apartment.tscn",
	"res://scenes/main.tscn",
	"res://scenes/world2.tscn",
	"res://scenes/world3.tscn",
]


func _ready() -> void:
	# Сцена теста исчезнет при первой смене сцены, поэтому сам тест живёт у корня дерева.
	var runner := Runner.new()
	get_tree().root.add_child.call_deferred(runner)


class Runner extends Node:
	var failures := 0

	func _ready() -> void:
		_run()

	func check(ok: bool, what: String) -> void:
		print(("ok   " if ok else "FAIL ") + what)
		if not ok:
			failures += 1

	func wait(seconds: float) -> void:
		await get_tree().create_timer(seconds).timeout

	func _run() -> void:
		await wait(0.5)
		SaveGame.delete_save()

		for path in SCENES:
			get_tree().change_scene_to_file(path)
			await wait(3.0)
			var scene := get_tree().current_scene
			check(scene != null and scene.scene_file_path == path, "сцена открывается: " + path)

		# Квартира: вещь в инвентаре, сохранение, загрузка.
		get_tree().change_scene_to_file("res://scenes/apartment.tscn")
		await wait(1.5)
		var apartment := get_tree().current_scene
		apartment._intro_done = true
		apartment.player.locked = false
		apartment._hands.take(apartment.get_node("Кухня/Декор/Кастрюля"))
		apartment._hands._store_held()
		check(apartment.can_save(), "в квартире можно сохраниться")
		apartment._save()
		check(SaveGame.read().get("scene", "") == "res://scenes/apartment.tscn", "сохранение квартиры записано")
		SaveGame.continue_game()
		await wait(3.0)
		apartment = get_tree().current_scene
		check(apartment._hands.inventory.titles() == ["кастрюля"], "после загрузки кастрюля в инвентаре")

		# Двор: вещь приехала с героем, автосохранение, загрузка во дворе.
		apartment._hands.pack_for_travel()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		await wait(5.0)
		var world := get_tree().current_scene
		check(world.hands.inventory.titles() == ["кастрюля"], "кастрюля приехала во двор")
		check(SaveGame.read().get("scene", "") == "res://scenes/main.tscn", "автосохранение в Мире 1")
		SaveGame.continue_game()
		await wait(3.0)
		world = get_tree().current_scene
		check(world.stage == "explore", "Мир 1 продолжается с сохранения")
		check(world.hands.inventory.titles() == ["кастрюля"], "после загрузки во дворе кастрюля в инвентаре")

		SaveGame.delete_save()
		print("ИТОГ: " + ("всё в порядке" if failures == 0 else "%d ошибок" % failures))
		get_tree().quit(1 if failures > 0 else 0)
