# Рассудок героя: в темноте и рядом с Тенью его постепенно накрывает, на свету отпускает.
# 0 — всё в порядке, 1 — накрыло полностью.
extends RefCounted

const DARK_RATE := 0.012    # в единицу времени: полная темнота накрывает примерно за 80 с
const NEAR_RATE := 0.25     # вплотную к Тени накрывает за 4 с
const LIGHT_RATE := 0.08    # на свету отпускает примерно за 12 с
const NEAR_FLOOR := 0.6     # близость Тени чувствуется сразу, даже на свету

var value := 0.0


# near: 0 — Тень далеко, 1 — вплотную. Возвращает, насколько героя накрыло прямо сейчас.
func update(delta: float, dark: bool, near: float) -> float:
	var rate := near * NEAR_RATE
	if dark:
		rate += DARK_RATE
	elif near < 0.1:
		rate -= LIGHT_RATE
	value = clampf(value + rate * delta, 0.0, 1.0)
	return maxf(value, near * NEAR_FLOOR)
