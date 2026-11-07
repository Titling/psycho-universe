# Счётчик кадров в правом верхнем углу. Включается в настройках.
extends Label

const Settings := preload("res://scripts/settings.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -16
	offset_top = 10
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Color(0.75, 0.72, 0.65))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	add_theme_constant_override("outline_size", 4)


func _process(_delta: float) -> void:
	visible = Settings.show_fps
	if visible:
		text = "FPS %d" % Engine.get_frames_per_second()
