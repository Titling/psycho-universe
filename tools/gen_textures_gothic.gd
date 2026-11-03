# Генерирует текстуры в духе мрачного замка: цвет + карта нормалей (файл *_n.png).
# Python не нужен, хватает самого Godot:
# Godot_v4.3-stable_win64_console.exe --headless --path . --script tools/gen_textures_gothic.gd
extends SceneTree

const OUT := "res://textures/"


func _init() -> void:
	seed(1839)
	# "-- faded" пересоздаёт только обои квартиры
	if "faded" in OS.get_cmdline_user_args():
		_faded_wallpaper()
		quit()
		return
	_stone_wall()
	_cobble()
	_rough_stone()
	_dark_wood()
	_iron()
	_marble()
	_wallpaper()
	print("done")
	quit()


func _noise(size: int, freq: float, octaves := 4, noise_seed := 0) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = noise_seed if noise_seed != 0 else randi()
	n.frequency = freq
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(size, size)
	img.convert(Image.FORMAT_L8)
	return img


func _save(name: String, albedo: Image, height: Image, strength: float) -> void:
	albedo.save_png(OUT + name + ".png")
	var normal := height.duplicate()
	normal.convert(Image.FORMAT_RGBA8)
	normal.bump_map_to_normal_map(strength)
	normal.save_png(OUT + name + "_n.png")


# Кладка: ряды блоков со смещением. warp искривляет швы, из неё же выходит брусчатка.
func _masonry(size: int, rows: int, cols: int, mortar: float, warp: float, stone: Color, seam: Color, strength: float, name: String) -> void:
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create(size, size, false, Image.FORMAT_L8)
	var detail := _noise(size, 0.03, 5)
	var fine := _noise(size, 0.16, 3)
	var stains := _noise(size, 0.006, 3)
	var warp_x := _noise(size, 0.02, 2)
	var warp_y := _noise(size, 0.02, 2)
	var streaks := PackedFloat32Array()
	streaks.resize(size)
	var column := randf()
	for x in size:
		column = clampf(column + randf_range(-0.09, 0.09), 0.0, 1.0)
		streaks[x] = column
	var tones := {}
	var row_h := float(size) / rows
	var col_w := float(size) / cols
	for y in size:
		for x in size:
			var wx := x + (warp_x.get_pixel(x, y).r - 0.5) * warp
			var wy := y + (warp_y.get_pixel(x, y).r - 0.5) * warp
			var row := int(floor(wy / row_h))
			var shifted := wx + (col_w * 0.5 if posmod(row, 2) == 1 else 0.0)
			var col := int(floor(shifted / col_w))
			var key := Vector2i(posmod(col, cols), posmod(row, rows))
			if not tones.has(key):
				tones[key] = randf()
			var tone: float = tones[key]
			var fx := fposmod(shifted, col_w)
			var fy := fposmod(wy, row_h)
			var edge := minf(minf(fx, col_w - fx), minf(fy, row_h - fy))
			var block := smoothstep(mortar * 0.4, mortar * 1.8, edge)
			var d := detail.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var c := seam.lerp(stone * (0.72 + tone * 0.5), block)
			c = c * (0.6 + d * 0.65) * (0.82 + f * 0.36)
			# сырость и потёки от швов вниз
			var damp := smoothstep(0.42, 0.72, stains.get_pixel(x, y).r)
			c = c.lerp(c * Color(0.55, 0.6, 0.52), damp * 0.8)
			c = c * (1.0 - smoothstep(0.62, 0.95, streaks[x]) * 0.32)
			c.a = 1.0
			albedo.set_pixel(x, y, c)
			var h := block * (0.62 + tone * 0.18) + (d - 0.5) * 0.3 + (f - 0.5) * 0.12
			height.set_pixel(x, y, Color(h, h, h))
	_save(name, albedo, height, strength)


func _stone_wall() -> void:
	_masonry(512, 8, 4, 3.5, 7.0, Color(0.5, 0.48, 0.44), Color(0.1, 0.09, 0.08), 7.0, "stone_wall")


func _rough_stone() -> void:
	_masonry(512, 6, 3, 5.0, 16.0, Color(0.42, 0.38, 0.33), Color(0.07, 0.06, 0.05), 9.0, "rough_stone")


func _cobble() -> void:
	_masonry(512, 9, 9, 4.0, 24.0, Color(0.34, 0.33, 0.31), Color(0.04, 0.04, 0.04), 8.0, "cobble")


func _dark_wood() -> void:
	var size := 256
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create(size, size, false, Image.FORMAT_L8)
	var fine := _noise(size, 0.09, 3)
	var planks := 4
	var plank_h := size / planks
	var tones := []
	for i in planks:
		tones.append(randf_range(0.75, 1.15))
	for y in size:
		var plank := y / plank_h
		var fy := y % plank_h
		var edge := minf(fy, plank_h - fy)
		for x in size:
			var f := fine.get_pixel(x, y).r
			var grain := sin(TAU * 3.0 * float(y) / size * planks + f * 9.0 + sin(TAU * float(x) / size) * 1.5) * 0.5 + 0.5
			var tone: float = tones[plank]
			var c := Color(0.27, 0.17, 0.1) * tone * (0.55 + grain * 0.6)
			var seam := smoothstep(0.0, 3.0, float(edge))
			c = c * (0.25 + seam * 0.75)
			c.a = 1.0
			albedo.set_pixel(x, y, c)
			var h := seam * 0.7 + grain * 0.22
			height.set_pixel(x, y, Color(h, h, h))
	_save("dark_wood", albedo, height, 5.0)


func _iron() -> void:
	var size := 256
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create(size, size, false, Image.FORMAT_L8)
	var big := _noise(size, 0.025, 4)
	var fine := _noise(size, 0.2, 2)
	for y in size:
		for x in size:
			var b := big.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var rust := smoothstep(0.52, 0.72, b + (f - 0.5) * 0.25)
			var c := Color(0.13, 0.13, 0.14).lerp(Color(0.3, 0.16, 0.08), rust) * (0.7 + f * 0.6)
			c.a = 1.0
			albedo.set_pixel(x, y, c)
			var h := 0.5 + (f - 0.5) * 0.5 - rust * 0.15
			height.set_pixel(x, y, Color(h, h, h))
	_save("iron", albedo, height, 4.0)


# Пол холла: чёрно-белый мрамор с прожилками.
func _marble() -> void:
	var size := 256
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create(size, size, false, Image.FORMAT_L8)
	var veins := _noise(size, 0.018, 5)
	var soft := _noise(size, 0.01, 3)
	var tile := size / 2
	for y in size:
		for x in size:
			var odd := (x / tile + y / tile) % 2 == 1
			var v := veins.get_pixel(x, y).r
			var line := 1.0 - smoothstep(0.0, 0.035, absf(v - 0.5))
			var s := soft.get_pixel(x, y).r
			var c := Color(0.55, 0.52, 0.46) if odd else Color(0.075, 0.07, 0.07)
			c = c * (0.8 + s * 0.4)
			c = c.lerp(Color(0.25, 0.22, 0.2) if odd else Color(0.3, 0.27, 0.23), line * 0.55)
			var edge := mini(mini(x % tile, tile - x % tile), mini(y % tile, tile - y % tile))
			var seam := smoothstep(0.0, 2.0, float(edge))
			c = c * (0.35 + seam * 0.65)
			c.a = 1.0
			albedo.set_pixel(x, y, c)
			var h := seam
			height.set_pixel(x, y, Color(h, h, h))
	_save("marble", albedo, height, 2.0)


# Стена холла: тёмные обои с узором, снизу деревянная панель (нижняя часть текстуры).
func _wallpaper() -> void:
	var size := 512
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create(size, size, false, Image.FORMAT_L8)
	var cloth := _noise(size, 0.05, 4)
	var fine := _noise(size, 0.25, 2)
	var panel_top := int(size * 0.76)
	for y in size:
		for x in size:
			var f := fine.get_pixel(x, y).r
			var d := cloth.get_pixel(x, y).r
			var c: Color
			var h: float
			if y < panel_top:
				# ромбы дамаска, по 4 на сторону, чтобы стык был незаметен
				var px := fposmod(float(x), 64.0) - 32.0
				var py := fposmod(float(y) + (32.0 if int(x / 64.0) % 2 == 1 else 0.0), 64.0) - 32.0
				var petal := absf(px) + absf(py) * 0.75
				var motif := 1.0 - smoothstep(12.0, 16.0, petal + sin(atan2(py, px) * 4.0) * 3.0)
				c = Color(0.3, 0.09, 0.08).lerp(Color(0.42, 0.21, 0.13), motif * 0.8) * (0.7 + d * 0.6)
				h = 0.45 + motif * 0.12 + (f - 0.5) * 0.08
			else:
				var board := fposmod(float(x), 128.0)
				var seam := smoothstep(0.0, 4.0, minf(board, 128.0 - board))
				var rail := smoothstep(0.0, 6.0, float(y - panel_top))
				var grain := sin(float(x) * 0.35 + d * 14.0) * 0.5 + 0.5
				c = Color(0.2, 0.12, 0.07) * (0.55 + grain * 0.5) * (0.35 + 0.65 * seam * rail)
				h = 0.55 * seam * rail + grain * 0.12
			c.a = 1.0
			albedo.set_pixel(x, y, c)
			height.set_pixel(x, y, Color(h, h, h))
	_save("wallpaper", albedo, height, 4.0)


# Обои квартиры: выцветшие полосы с мелким узором, разводы и отставшие куски.
func _faded_wallpaper() -> void:
	var size := 512
	var albedo := Image.create(size, size, false, Image.FORMAT_RGB8)
	var height := Image.create(size, size, false, Image.FORMAT_L8)
	var cloth := _noise(size, 0.012, 4)
	var fine := _noise(size, 0.3, 2)
	var stains := _noise(size, 0.008, 3)
	var peel := _noise(size, 0.035, 3)
	var tones := []
	for i in 4:
		tones.append(randf_range(0.9, 1.08))
	for y in size:
		for x in size:
			var strip := x / 128
			var tone: float = tones[strip]
			var seam := smoothstep(0.0, 2.0, minf(fposmod(float(x), 128.0), 128.0 - fposmod(float(x), 128.0)))
			# мелкие ромбики: 32 пикселя при тайле 2.7 м дают узор примерно 17 см
			var px := fposmod(float(x), 32.0) - 16.0
			var py := fposmod(float(y), 32.0) - 16.0
			var motif := 1.0 - smoothstep(4.0, 6.0, absf(px) + absf(py))
			var d := cloth.get_pixel(x, y).r
			var f := fine.get_pixel(x, y).r
			var c := Color(0.29, 0.28, 0.23).lerp(Color(0.21, 0.2, 0.17), motif * 0.55)
			c = c * tone * (0.72 + d * 0.5) * (0.92 + f * 0.16)
			c = c.lerp(c * Color(0.62, 0.56, 0.45), smoothstep(0.5, 0.75, stains.get_pixel(x, y).r) * 0.85)
			var h := 0.55 + motif * 0.02 + (f - 0.5) * 0.05
			var gone := smoothstep(0.7, 0.74, peel.get_pixel(x, y).r)
			c = c.lerp(Color(0.2, 0.19, 0.17) * (0.7 + f * 0.5), gone)
			h -= gone * 0.25
			c = c * (0.55 + seam * 0.45)
			c.a = 1.0
			albedo.set_pixel(x, y, c)
			height.set_pixel(x, y, Color(h, h, h))
	_save("wallpaper_faded", albedo, height, 3.0)
