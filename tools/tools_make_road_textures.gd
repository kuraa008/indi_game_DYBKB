extends SceneTree

# Генерирует текстуры дороги: кусок шоссе 12 x 24 м с обочинами, повторяется вдоль дороги,
# а также плитки асфальта и бетона для заправки.
# Запуск: godot --headless --path game/game --script <этот файл>

const W := 1024
const H := 2048
const OUT := "res://assets/textures/road/"
const PX := float(W) / 12.0

var r := PackedFloat32Array()
var g := PackedFloat32Array()
var b := PackedFloat32Array()
var a := PackedFloat32Array()
var hgt := PackedFloat32Array()
var rgh := PackedFloat32Array()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 81347
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for arr in [r, g, b, a, hgt, rgh]:
		arr.resize(W * H)
	_paint_base()
	_paint_patches()
	_paint_cracks()
	_save_road()
	_save_tile("asphalt_tile", Color(0.205, 0.205, 0.21), 0.075, 0.5, 0.92)
	_save_tile("concrete_tile", Color(0.4, 0.39, 0.365), 0.03, 0.18, 0.94)
	print("road baked")
	quit()


func _noise(freq: float, w: int, h: int, octaves: int = 4) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = rng.randi()
	n.frequency = freq
	n.fractal_octaves = octaves
	return n.get_seamless_image(w, h)


func _paint_base() -> void:
	var low := _noise(0.0045, W, H, 4)
	var mid := _noise(0.035, W, H, 4)
	var hi := _noise(0.3, W, H, 2)
	for py in H:
		var z := (float(py) + 0.5) / float(H) * 24.0
		for px in W:
			var x := (float(px) + 0.5) / float(W) * 12.0 - 6.0
			var ax := absf(x)
			var l: float = low.get_pixel(px, py).r
			var m: float = mid.get_pixel(px, py).r
			var s: float = hi.get_pixel(px, py).r
			var edge := 3.72 + (l - 0.5) * 0.55 + (m - 0.5) * 0.28
			var asph := smoothstep(edge + 0.025, edge - 0.025, ax)
			# Асфальт: щебень в битуме, выбеленный временем
			var stone := smoothstep(0.6, 0.67, s)
			var pit := smoothstep(0.42, 0.35, s)
			var track := exp(-pow((ax - 1.06) / 0.27, 2.0)) + exp(-pow((ax - 2.54) / 0.27, 2.0))
			var v := 0.2 + (l - 0.5) * 0.09 + (m - 0.5) * 0.06
			v += stone * (0.1 - track * 0.05) - pit * 0.055
			v -= track * 0.012
			# Масляная полоса посреди полосы движения
			var oil := exp(-pow((ax - 1.8) / 0.15, 2.0)) * smoothstep(0.42, 0.62, m)
			v -= oil * 0.06
			var c := Color(v, v * 0.985, v * 0.975)
			var h := (s - 0.5) * 0.38 + (m - 0.5) * 0.22 - track * 0.2
			var ro := lerpf(0.94, 0.66, clampf(track, 0.0, 1.0) * 0.85) - oil * 0.2
			# Разметка: стёрта пятнами, сквозь неё виден щебень
			var mark := 0.0
			if absf(ax - 3.42) < 0.07:
				mark = 1.0
			if ax < 0.065 and fmod(z, 8.0) < 3.0:
				mark = 1.0
			if mark > 0.0:
				var wear := smoothstep(0.34, 0.6, m * 0.65 + s * 0.35 + (l - 0.5) * 0.4)
				var k := wear * (1.0 - stone * 0.45) * (1.0 - pit * 0.5)
				c = c.lerp(Color(0.6, 0.6, 0.55), k)
				h += k * 0.22
				ro = lerpf(ro, 0.72, k)
			# Обочина: гравий и земля, край рваный
			var out_k := clampf((ax - 3.75) / 1.5, 0.0, 1.0)
			var dirt := Color(0.17, 0.145, 0.115).lerp(Color(0.075, 0.066, 0.052), out_k)
			var peb := smoothstep(0.58, 0.64, s)
			dirt = dirt.lerp(Color(0.33, 0.305, 0.27), peb * (1.0 - out_k * 0.7))
			dirt = dirt.lerp(Color(0.04, 0.035, 0.028), smoothstep(0.44, 0.34, s) * 0.8)
			var dh := (s - 0.5) * 1.5 + (m - 0.5) * 0.7
			c = dirt.lerp(c, asph)
			h = lerpf(dh, h, asph)
			ro = lerpf(0.98, ro, asph)
			# Тёмная кромка, где асфальт крошится
			var rim := exp(-pow((ax - edge) / 0.05, 2.0))
			c = c.lerp(Color(0.05, 0.045, 0.04), rim * 0.65)
			h -= rim * 0.5
			var cut := 5.15 + (l - 0.5) * 1.1 + (s - 0.5) * 0.4
			var i := py * W + px
			r[i] = c.r
			g[i] = c.g
			b[i] = c.b
			a[i] = smoothstep(cut + 0.02, cut - 0.02, ax)
			hgt[i] = h
			rgh[i] = ro


func _wrap_y(py: int) -> int:
	return posmod(py, H)


func _stamp(x: float, z: float, rad_px: float, tint: Color, alpha: float, depth: float, rough: float = -1.0) -> void:
	var cx := (x + 6.0) * PX
	var cy := z * PX
	var rr := ceili(rad_px * 2.0)
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var px := int(cx) + dx
			if px < 0 or px >= W:
				continue
			var d2 := pow(float(px) - cx, 2.0) + pow(float(int(cy) + dy) - cy, 2.0)
			var k := exp(-d2 / (rad_px * rad_px))
			var i := _wrap_y(int(cy) + dy) * W + px
			var f := k * alpha
			r[i] = lerpf(r[i], tint.r, f)
			g[i] = lerpf(g[i], tint.g, f)
			b[i] = lerpf(b[i], tint.b, f)
			hgt[i] -= k * depth
			if rough >= 0.0:
				rgh[i] = lerpf(rgh[i], rough, f)


# Трещина идёт от точки в заданном направлении и виляет
func _crack(x: float, z: float, ang: float, length: float, rad: float, tint: Color, alpha: float, depth: float, rough: float = -1.0, wiggle: float = 0.75) -> void:
	var walked := 0.0
	var step := 0.018
	var a0 := ang
	while walked < length:
		ang += rng.randf_range(-wiggle, wiggle) * 0.16
		ang = lerp_angle(ang, a0, 0.02)
		x += cos(ang) * step
		z += sin(ang) * step
		if absf(x) > 3.72:
			return
		var fade := minf(1.0, minf(walked, length - walked) / 0.3 + 0.25)
		_stamp(x, z, rad * fade, tint, alpha, depth * fade, rough)
		walked += step


func _paint_patches() -> void:
	# Заплатки свежего асфальта: темнее и глаже, через разметку
	for spec in [[-1.9, 3.5, 2.1, 3.0], [1.8, 13.0, 2.6, 4.4], [2.6, 21.5, 1.3, 1.5]]:
		var cx: float = spec[0]
		var cz: float = spec[1]
		var w: float = spec[2]
		var l: float = spec[3]
		var x0 := int((cx - w * 0.5 + 6.0) * PX)
		var x1 := int((cx + w * 0.5 + 6.0) * PX)
		var y0 := int((cz - l * 0.5) * PX)
		var y1 := int((cz + l * 0.5) * PX)
		for py in range(y0, y1):
			for px in range(x0, x1):
				var i := _wrap_y(py) * W + px
				r[i] = r[i] * 0.62 + 0.025
				g[i] = g[i] * 0.62 + 0.025
				b[i] = b[i] * 0.62 + 0.027
				hgt[i] = hgt[i] * 0.5 + 0.12
				rgh[i] = 0.82
		# Швы вокруг заплатки залиты битумом
		for k in range(0, x1 - x0, 2):
			_stamp(cx - w * 0.5 + float(k) / PX, cz - l * 0.5 + sin(float(k) * 0.09) * 0.01, 1.8, Color(0.018, 0.018, 0.018), 0.85, 0.35, 0.42)
			_stamp(cx - w * 0.5 + float(k) / PX, cz + l * 0.5 + sin(float(k) * 0.07) * 0.01, 1.8, Color(0.018, 0.018, 0.018), 0.85, 0.35, 0.42)
		for k in range(0, y1 - y0, 2):
			_stamp(cx - w * 0.5 + sin(float(k) * 0.08) * 0.01, cz - l * 0.5 + float(k) / PX, 1.8, Color(0.018, 0.018, 0.018), 0.85, 0.35, 0.42)
			_stamp(cx + w * 0.5 + sin(float(k) * 0.06) * 0.01, cz - l * 0.5 + float(k) / PX, 1.8, Color(0.018, 0.018, 0.018), 0.85, 0.35, 0.42)


func _paint_cracks() -> void:
	var dark := Color(0.02, 0.02, 0.02)
	# Продольный шов посередине, залитый битумом: замкнут по длине куска
	var z := 0.0
	while z < 24.0:
		var x := 0.14 + sin(z / 24.0 * TAU * 2.0) * 0.05 + sin(z / 24.0 * TAU * 5.0) * 0.022
		_stamp(x, z, 1.5, Color(0.03, 0.03, 0.03), 0.8, 0.3, 0.5)
		z += 0.012
	# Поперечные трещины через всю дорогу
	for zc in [1.9, 6.8, 11.1, 16.4, 22.2]:
		_crack(-3.6, zc, 0.0, 3.7, 1.25, dark, 0.86, 0.75)
		_crack(0.1, zc + rng.randf_range(-0.2, 0.2), 0.0, 3.5, 1.25, dark, 0.86, 0.75)
	# Заливка битумом: извилистые блестящие полосы
	for i in 5:
		var x0 := rng.randf_range(-3.2, 3.2)
		_crack(x0, rng.randf_range(0.0, 24.0), PI * 0.5 + rng.randf_range(-0.25, 0.25), rng.randf_range(2.5, 6.0), 1.7, Color(0.03, 0.03, 0.03), 0.78, 0.25, 0.48, 1.0)
	# Продольные трещины в колее
	for sx in [-2.55, -1.05, 1.05, 2.55]:
		for k in 2:
			_crack(sx + rng.randf_range(-0.12, 0.12), rng.randf_range(0.0, 24.0), PI * 0.5, rng.randf_range(2.5, 6.0), 1.05, dark, 0.8, 0.65)
	# «Крокодилова кожа» у края и в колее
	for spec in [[-3.15, 5.2, 3.4], [3.2, 16.8, 2.8], [1.05, 21.5, 1.8]]:
		var cx: float = spec[0]
		var cz: float = spec[1]
		var l: float = spec[2]
		for n in 70:
			_crack(cx + rng.randf_range(-0.38, 0.38), cz + rng.randf_range(0.0, l), rng.randf() * TAU, rng.randf_range(0.14, 0.34), 0.95, dark, 0.78, 0.6, -1.0, 1.4)
	# Мелкие волосные трещины
	for n in 120:
		_crack(rng.randf_range(-3.6, 3.6), rng.randf_range(0.0, 24.0), rng.randf() * TAU, rng.randf_range(0.2, 0.9), 0.75, Color(0.05, 0.05, 0.05), 0.55, 0.35)
	# Выбоины
	for n in 7:
		var px := rng.randf_range(-3.3, 3.3)
		var pz := rng.randf_range(0.0, 24.0)
		var rad := rng.randf_range(4.5, 11.0)
		for k in 9:
			_stamp(px + rng.randf_range(-0.05, 0.05), pz + rng.randf_range(-0.05, 0.05), rad * rng.randf_range(0.4, 0.9), Color(0.07, 0.065, 0.06), 0.42, 0.42)


func _normal_bytes(data: PackedFloat32Array, w: int, h: int, k: float, flip_y: bool) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(w * h * 3)
	for py in h:
		var up: int = posmod(py - 1, h) * w
		var dn: int = posmod(py + 1, h) * w
		var row: int = py * w
		for px in w:
			var lf: int = posmod(px - 1, w)
			var rt: int = posmod(px + 1, w)
			var nx: float = -(data[row + rt] - data[row + lf]) * k
			var ny: float = (data[dn + px] - data[up + px]) * k * (-1.0 if flip_y else 1.0)
			var n := Vector3(nx, ny, 1.0).normalized()
			var o: int = (row + px) * 3
			out[o] = int((n.x * 0.5 + 0.5) * 255.0)
			out[o + 1] = int((n.y * 0.5 + 0.5) * 255.0)
			out[o + 2] = int((n.z * 0.5 + 0.5) * 255.0)
	return out


func _save_road() -> void:
	var col := PackedByteArray()
	col.resize(W * H * 4)
	var rou := PackedByteArray()
	rou.resize(W * H)
	for i in W * H:
		col[i * 4] = int(clampf(r[i], 0.0, 1.0) * 255.0)
		col[i * 4 + 1] = int(clampf(g[i], 0.0, 1.0) * 255.0)
		col[i * 4 + 2] = int(clampf(b[i], 0.0, 1.0) * 255.0)
		col[i * 4 + 3] = int(clampf(a[i], 0.0, 1.0) * 255.0)
		rou[i] = int(clampf(rgh[i], 0.0, 1.0) * 255.0)
	Image.create_from_data(W, H, false, Image.FORMAT_RGBA8, col).save_png(OUT + "road_albedo.png")
	Image.create_from_data(W, H, false, Image.FORMAT_RGB8, _normal_bytes(hgt, W, H, 2.2, false)).save_png(OUT + "road_normal.png")
	var ri := Image.create_from_data(W, H, false, Image.FORMAT_L8, rou)
	ri.resize(512, 1024, Image.INTERPOLATE_BILINEAR)
	ri.save_png(OUT + "road_rough.png")


# Бесшовная плитка на 4 метра
func _save_tile(file_name: String, base: Color, stone_k: float, low_k: float, _rough: float) -> void:
	var s := 512
	var low := _noise(0.009, s, s, 5)
	var mid := _noise(0.05, s, s, 4)
	var hi := _noise(0.42, s, s, 2)
	var col := PackedByteArray()
	col.resize(s * s * 3)
	var h := PackedFloat32Array()
	h.resize(s * s)
	for py in s:
		for px in s:
			var l: float = low.get_pixel(px, py).r
			var m: float = mid.get_pixel(px, py).r
			var t: float = hi.get_pixel(px, py).r
			var v := 1.0 + (l - 0.5) * low_k * 2.0 + (m - 0.5) * 0.14 + smoothstep(0.6, 0.68, t) * stone_k * 5.0 - smoothstep(0.42, 0.35, t) * 0.14
			var o := (py * s + px) * 3
			col[o] = int(clampf(base.r * v, 0.0, 1.0) * 255.0)
			col[o + 1] = int(clampf(base.g * v, 0.0, 1.0) * 255.0)
			col[o + 2] = int(clampf(base.b * v, 0.0, 1.0) * 255.0)
			h[py * s + px] = (t - 0.5) * 0.35 + (m - 0.5) * 0.25
	Image.create_from_data(s, s, false, Image.FORMAT_RGB8, col).save_png(OUT + file_name + ".png")
	Image.create_from_data(s, s, false, Image.FORMAT_RGB8, _normal_bytes(h, s, s, 1.6, true)).save_png(OUT + file_name + "_n.png")
