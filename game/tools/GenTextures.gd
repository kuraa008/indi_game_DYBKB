extends SceneTree

# Генерирует бесшовные текстуры поверхностей с картами рельефа в assets/textures/surface.
# Запуск: Godot --headless --path . -s res://tools/GenTextures.gd

const SIZE := 1024
const DIR := "res://assets/textures/surface/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_wood("wood", false, 11)
	_wood("wood_h", true, 12)
	_plaster()
	_fabric()
	_metal()
	_concrete()
	_bark_log()
	_soil()
	_wallpaper()
	print("GEN DONE")
	quit()


func _noise(freq: float, seed_value: int, octaves: int = 4, kind: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, w: int = SIZE, h: int = SIZE) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.frequency = freq
	n.seed = seed_value
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(w, h, false, false, 0.15)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


# Шум, растянутый вдоль одной оси: волокна дерева, царапины, ворс
func _streaks(freq: float, stretch: int, seed_value: int, along_x: bool) -> PackedByteArray:
	var short := SIZE / stretch
	var data := _noise(freq, seed_value, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, short if along_x else SIZE, SIZE if along_x else short)
	var out := PackedByteArray()
	out.resize(SIZE * SIZE)
	for y in range(SIZE):
		for x in range(SIZE):
			if along_x:
				var t := float(x) / stretch
				var a := int(t)
				var f := t - a
				f = f * f * (3.0 - 2.0 * f)
				out[y * SIZE + x] = int(lerpf(data[y * short + a % short], data[y * short + (a + 1) % short], f))
			else:
				var t := float(y) / stretch
				var a := int(t)
				var f := t - a
				f = f * f * (3.0 - 2.0 * f)
				out[y * SIZE + x] = int(lerpf(data[(a % short) * SIZE + x], data[((a + 1) % short) * SIZE + x], f))
	return out


func _save(file: String, albedo: PackedFloat32Array, height: PackedFloat32Array, strength: float, tint: Color = Color.WHITE) -> void:
	var rgb := PackedByteArray()
	rgb.resize(SIZE * SIZE * 3)
	var bump := PackedByteArray()
	bump.resize(SIZE * SIZE * 4)
	for i in range(SIZE * SIZE):
		var a: float = clampf(albedo[i], 0.0, 1.0)
		rgb[i * 3] = int(a * tint.r * 255.0)
		rgb[i * 3 + 1] = int(a * tint.g * 255.0)
		rgb[i * 3 + 2] = int(a * tint.b * 255.0)
		var h := int(clampf(height[i], 0.0, 1.0) * 255.0)
		bump[i * 4] = h
		bump[i * 4 + 1] = h
		bump[i * 4 + 2] = h
		bump[i * 4 + 3] = 255
	Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, rgb).save_png(DIR + file + ".png")
	var n := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, bump)
	n.bump_map_to_normal_map(strength)
	n.convert(Image.FORMAT_RGB8)
	n.save_png(DIR + file + "_n.png")
	print("  ", file)


func _floats() -> PackedFloat32Array:
	var f := PackedFloat32Array()
	f.resize(SIZE * SIZE)
	return f


func _wood(file: String, along_x: bool, seed_value: int) -> void:
	var fine := _streaks(0.09, 16, seed_value, along_x)
	var broad := _streaks(0.012, 8, seed_value + 1, along_x)
	var rings := _noise(0.0016, seed_value + 2, 2)
	var pores := _streaks(0.3, 24, seed_value + 3, along_x)
	var alb := _floats()
	var hgt := _floats()
	for i in range(SIZE * SIZE):
		var x := i % SIZE
		var y := i / SIZE
		var across := float(y if along_x else x) / SIZE
		var warp := rings[i] / 255.0
		# Годичные кольца: тёмные полосы изгибаются вокруг сучков
		var ring := 0.5 + 0.5 * sin((across + warp * 0.13) * TAU * 9.0)
		ring = pow(ring, 2.6)
		var f := fine[i] / 255.0
		var b := broad[i] / 255.0
		var p := pores[i] / 255.0
		var pore_dark := smoothstep(0.34, 0.2, p)
		var v := 0.66 + (f - 0.5) * 0.26 + (b - 0.5) * 0.2 - ring * 0.1 - pore_dark * 0.2
		alb[i] = v + 0.16
		hgt[i] = 0.5 + (f - 0.5) * 0.55 - pore_dark * 0.5 - ring * 0.08
	_save(file, alb, hgt, 3.2, Color(1.0, 0.95, 0.88))


func _plaster() -> void:
	var soft := _noise(0.004, 21, 4)
	var mid := _noise(0.03, 22, 4)
	var grain := _noise(0.42, 23, 2)
	var stains := _noise(0.0022, 24, 3)
	var alb := _floats()
	var hgt := _floats()
	for i in range(SIZE * SIZE):
		var s := soft[i] / 255.0
		var m := mid[i] / 255.0
		var g := grain[i] / 255.0
		var st := smoothstep(0.62, 0.8, stains[i] / 255.0)
		alb[i] = 0.9 + (s - 0.5) * 0.14 + (m - 0.5) * 0.06 + (g - 0.5) * 0.05 - st * 0.09
		hgt[i] = 0.5 + (m - 0.5) * 0.5 + (g - 0.5) * 0.28
	_save("plaster", alb, hgt, 1.4)


func _fabric() -> void:
	var slub := _noise(0.05, 31, 3)
	var fuzz := _noise(0.5, 32, 2)
	var wear := _noise(0.004, 33, 3)
	var alb := _floats()
	var hgt := _floats()
	var period := 8.0  # нитей на тайл: 128
	for i in range(SIZE * SIZE):
		var x := float(i % SIZE)
		var y := float(i / SIZE)
		var cx := int(x / period)
		var cy := int(y / period)
		var over := (cx + cy) % 2 == 0
		var fx := fmod(x, period) / period
		var fy := fmod(y, period) / period
		var bump: float = sin(fy * PI) if over else sin(fx * PI)
		bump *= 0.82 + 0.18 * (sin((fx if over else fy) * PI))
		var s := slub[i] / 255.0
		var fz := fuzz[i] / 255.0
		var w := smoothstep(0.58, 0.78, wear[i] / 255.0)
		alb[i] = 0.62 + bump * 0.3 + (s - 0.5) * 0.14 + (fz - 0.5) * 0.08 + w * 0.05
		hgt[i] = bump * 0.8 + (fz - 0.5) * 0.15
	_save("fabric", alb, hgt, 2.4)


func _metal() -> void:
	var brushed := _streaks(0.25, 32, 41, true)
	var blotch := _noise(0.006, 42, 4)
	var specks := _noise(0.25, 43, 3)
	var alb := _floats()
	var hgt := _floats()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	# Отдельные глубокие царапины
	var scratch := PackedFloat32Array()
	scratch.resize(SIZE * SIZE)
	for k in range(140):
		var px := rng.randf() * SIZE
		var py := rng.randf() * SIZE
		var ang := rng.randf() * TAU
		var len_px := rng.randf_range(40.0, 340.0)
		for t in range(int(len_px)):
			var sx := posmod(int(px + cos(ang) * t), SIZE)
			var sy := posmod(int(py + sin(ang) * t), SIZE)
			scratch[sy * SIZE + sx] = 1.0
	for i in range(SIZE * SIZE):
		var b := brushed[i] / 255.0
		var bl := blotch[i] / 255.0
		var sp := smoothstep(0.7, 0.82, specks[i] / 255.0)
		alb[i] = 0.84 + (b - 0.5) * 0.14 + (bl - 0.5) * 0.3 - sp * 0.2 + scratch[i] * 0.12
		hgt[i] = 0.55 + (b - 0.5) * 0.14 - sp * 0.2 - scratch[i] * 0.25
	_save("metal", alb, hgt, 1.2)


func _concrete() -> void:
	var soft := _noise(0.0045, 51, 5)
	var mid := _noise(0.05, 52, 4)
	var pits := _noise(0.11, 53, 3)
	var grain := _noise(0.55, 54, 2)
	var rain := _streaks(0.03, 16, 55, false)
	var alb := _floats()
	var hgt := _floats()
	for i in range(SIZE * SIZE):
		var s := soft[i] / 255.0
		var m := mid[i] / 255.0
		var p := smoothstep(0.26, 0.14, pits[i] / 255.0)
		var g := grain[i] / 255.0
		var r := smoothstep(0.54, 0.76, rain[i] / 255.0)
		alb[i] = 0.82 + (s - 0.5) * 0.36 + (m - 0.5) * 0.12 + (g - 0.5) * 0.1 - p * 0.3 - r * 0.2
		hgt[i] = 0.55 + (m - 0.5) * 0.4 + (g - 0.5) * 0.2 - p * 0.7
	_save("concrete", alb, hgt, 2.0)


# Старое бревно: продольные трещины и потемневшая поверхность
func _bark_log() -> void:
	var fine := _streaks(0.11, 14, 61, true)
	var broad := _streaks(0.018, 8, 62, true)
	var crack := _streaks(0.05, 22, 63, true)
	var blotch := _noise(0.009, 64, 4)
	var alb := _floats()
	var hgt := _floats()
	for i in range(SIZE * SIZE):
		var f := fine[i] / 255.0
		var b := broad[i] / 255.0
		var c := 1.0 - absf(crack[i] / 255.0 - 0.5) * 2.0
		var cut := smoothstep(0.93, 0.985, c)
		var bl := blotch[i] / 255.0
		alb[i] = 0.74 + (f - 0.5) * 0.34 + (b - 0.5) * 0.4 + (bl - 0.5) * 0.3 - cut * 0.55
		hgt[i] = 0.62 + (f - 0.5) * 0.4 + (b - 0.5) * 0.25 - cut * 0.8
	_save("wood_log", alb, hgt, 4.2, Color(1.0, 0.94, 0.86))


func _soil() -> void:
	var soft := _noise(0.006, 71, 5)
	var mid := _noise(0.045, 72, 5)
	var stones := _noise(0.09, 73, 2, FastNoiseLite.TYPE_CELLULAR)
	var grain := _noise(0.6, 74, 2)
	var twig := _streaks(0.2, 10, 75, true)
	var alb := _floats()
	var hgt := _floats()
	for i in range(SIZE * SIZE):
		var s := soft[i] / 255.0
		var m := mid[i] / 255.0
		var st := smoothstep(0.72, 0.9, 1.0 - stones[i] / 255.0)
		var g := grain[i] / 255.0
		var t := smoothstep(0.82, 0.9, twig[i] / 255.0)
		alb[i] = 0.72 + (s - 0.5) * 0.46 + (m - 0.5) * 0.3 + (g - 0.5) * 0.2 + st * 0.18 - t * 0.22
		hgt[i] = 0.45 + (m - 0.5) * 0.6 + st * 0.5 + (g - 0.5) * 0.25 + t * 0.2
	_save("soil", alb, hgt, 3.6)


# Старые обои: неяркий цветочный дамаск, выцветание и подтёки сверху
func _wallpaper() -> void:
	var fade := _noise(0.0038, 81, 4)
	var grain := _noise(0.5, 82, 2)
	var drip := _streaks(0.02, 16, 83, false)
	var alb := _floats()
	var hgt := _floats()
	var cell := float(SIZE) / 4.0
	for i in range(SIZE * SIZE):
		var x := float(i % SIZE)
		var y := float(i / SIZE)
		var row := int(y / cell)
		var ox := fmod(x + (cell * 0.5 if row % 2 == 1 else 0.0), cell) / cell
		var oy := fmod(y, cell) / cell
		var dx := absf(ox - 0.5) * 2.0
		var dy := oy - 0.5
		# Лист: тонкая форма с прожилкой, отражённая по вертикальной оси
		var body := smoothstep(0.42, 0.36, sqrt(dx * dx * 1.9 + dy * dy * 1.2 * 4.0) + 0.1 * sin(oy * TAU * 3.0))
		var vein := smoothstep(0.06, 0.02, dx) * smoothstep(0.42, 0.34, absf(dy))
		var petal := smoothstep(0.26, 0.2, Vector2(dx - 0.55, dy + 0.0).length()) * 0.7
		var motif := maxf(body, petal)
		var f := fade[i] / 255.0
		var g := grain[i] / 255.0
		var d := smoothstep(0.62, 0.82, drip[i] / 255.0)
		alb[i] = 0.74 - motif * 0.17 + vein * 0.1 + (f - 0.5) * 0.32 + (g - 0.5) * 0.06 - d * 0.22
		hgt[i] = 0.5 + motif * 0.14 + (g - 0.5) * 0.18
	_save("wallpaper", alb, hgt, 1.1, Color(0.86, 0.8, 0.66))
