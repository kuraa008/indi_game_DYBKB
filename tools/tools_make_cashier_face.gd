extends SceneTree

# Генерирует текстуру лица кассирши: цвет кожи и карту рельефа.
# Запуск: godot --headless --path game/game --script <этот файл>
# Координаты те же, что в CashierModel: x, y в размерах головы, u — угол вокруг головы.

const W := 1536
const H := 768
const Y_MIN := -0.062
const Y_MAX := 0.25
const OUT := "res://assets/textures/cashier/"

var rings: Array = []
var y0 := 0.012
var r := PackedFloat32Array()
var g := PackedFloat32Array()
var b := PackedFloat32Array()
var hgt := PackedFloat32Array()
var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 77102
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	rings = CashierModel._face_rings()
	y0 = CashierModel.face_mouth_y()
	for a in [r, g, b, hgt]:
		a.resize(W * H)
	_paint_base()
	_paint_wrinkles()
	_paint_spots()
	_paint_brows()
	_save()
	quit()


func _ring_at(y: float) -> Array:
	var k := 0
	while k < rings.size() - 2 and y > rings[k + 1][0]:
		k += 1
	var t := clampf((y - rings[k][0]) / (rings[k + 1][0] - rings[k][0]), 0.0, 1.0)
	return [lerpf(rings[k][1], rings[k + 1][1], t), lerpf(rings[k][2], rings[k + 1][2], t), lerpf(rings[k][4], rings[k + 1][4], t)]


func _gauss(p: Vector3, c: Vector3, rad: float) -> float:
	return exp(-(p - c).length_squared() / (rad * rad))


func _paint_base() -> void:
	for py in H:
		var y := Y_MAX - (float(py) + 0.5) / float(H) * (Y_MAX - Y_MIN)
		var ring := _ring_at(y)
		var dy := y - y0
		for px in W:
			var th := (float(px) + 0.5) / float(W) * TAU
			var p := Vector3(ring[0] * cos(th), y, ring[2] + ring[1] * sin(th))
			var i := py * W + px
			var ax := absf(p.x)
			var front := smoothstep(.02, .07, p.z)
			# Основа: бледная сероватая кожа пожилого человека
			var c := Color(0.615, 0.47, 0.405)
			var m1 := noise.get_noise_2d(p.x * 16.0 + p.z * 11.0, y * 16.0)
			var m2 := noise.get_noise_2d(p.x * 58.0 + 40.0, y * 58.0 + p.z * 30.0)
			var m3 := noise.get_noise_2d(p.x * 210.0 + 90.0, y * 210.0)
			var pore := noise.get_noise_2d(p.x * 820.0 + p.z * 500.0, y * 820.0 + 300.0)
			c = c.lerp(Color(0.52, 0.37, 0.32), clampf(m1 * .9 + .25, 0.0, 1.0) * .32)
			c = c.lerp(Color(0.66, 0.42, 0.37), clampf(m2 * .9 + .15, 0.0, 1.0) * .2)
			var v := 1.0 + m3 * .03 + pore * .018
			# Прилив крови: щёки, кончик носа, подбородок
			var red := 0.0
			for s in [-1.0, 1.0]:
				red = maxf(red, _gauss(p, Vector3(.05 * s, .045, .08), .027) * .5)
				red = maxf(red, _gauss(p, Vector3(.0125 * s, .04, .098), .009) * .55)
				# Мешки и глазницы: лиловатая тень
				c = c.lerp(Color(0.43, 0.3, 0.3), _gauss(p, Vector3(.036 * s, .066, .092), .015) * .42)
				c = c.lerp(Color(0.46, 0.33, 0.3), _gauss(p, Vector3(.035 * s, .097, .09), .016) * .36)
				c = c.lerp(Color(0.5, 0.4, 0.37), _gauss(p, Vector3(.07 * s, .12, .05), .02) * .3)
			red = maxf(red, _gauss(p, Vector3(0, .047, .11), .013) * .5)
			red = maxf(red, _gauss(p, Vector3(0, -.032, .1), .016) * .22)
			c = c.lerp(Color(0.67, 0.39, 0.35), red)
			# Тень сбоку носа и под нижней губой
			var nose_side := exp(-pow((ax - .0135) / .0055, 2.0)) * smoothstep(.045, .058, y) * smoothstep(.1, .085, y) * front
			v *= 1.0 - nose_side * .14
			v *= 1.0 - _gauss(p, Vector3(0, y0 - .0155, .1), .006) * .16
			# Тень под челюстью
			v *= 1.0 - smoothstep(-.04, -.06, y) * .2
			var h := pore * .05 + m3 * .045 + m2 * .05
			# Губы: приглушённые, край мягкий, без помады
			var u := minf(ax / .0225, 1.0)
			var hu := .0058 * (1.0 - u * u) * (1.0 - .28 * exp(-pow(ax / .0042, 2.0))) + .0006
			var hl := .0082 * (1.0 - u * u * u) + .0006
			var lip: float = smoothstep(hu + .0022, hu - .0006, dy) if dy >= 0.0 else smoothstep(hl + .0022, hl - .0006, -dy)
			lip *= smoothstep(.026, .021, ax) * front
			c = c.lerp(Color(0.53, 0.33, 0.31).lerp(Color(0.47, 0.28, 0.27), clampf(m2 + .4, 0.0, 1.0)), lip * .85)
			# Смыкание губ и уголки
			var seam := exp(-pow(dy / .00085, 2.0)) * smoothstep(.0255, .02, ax) * front
			v *= 1.0 - seam * .72
			h -= seam * 1.6
			for s in [-1.0, 1.0]:
				v *= 1.0 - _gauss(p, Vector3(.0235 * s, y0 - .0005, .098), .0034) * .42
			# Лоб и волосы: у линии волос кожа темнее
			var hairline := .153 + .9 * ax * ax - 1.2 * maxf(0.0, ax - .05)
			v *= 1.0 - smoothstep(hairline - .014, hairline - .001, y) * smoothstep(-.02, .02, p.z) * .25
			r[i] = c.r * v
			g[i] = c.g * v
			b[i] = c.b * v
			hgt[i] = h


func _px(x: float, y: float) -> Vector2:
	var ring := _ring_at(y)
	var th := acos(clampf(x / ring[0], -1.0, 1.0))
	return Vector2(th / TAU * float(W), (Y_MAX - y) / (Y_MAX - Y_MIN) * float(H))


# Мазок: затемняет кожу и продавливает рельеф
func _stamp(x: float, y: float, rad: float, dark: float, depth: float, tint := Color(0.3, 0.2, 0.18)) -> void:
	var c := _px(x, y)
	var rr := ceili(rad * 2.2)
	for dy in range(-rr, rr + 1):
		for dx in range(-rr, rr + 1):
			var px := int(c.x) + dx
			var py := int(c.y) + dy
			if px < 0 or px >= W or py < 0 or py >= H:
				continue
			var d2 := pow(float(px) - c.x, 2.0) + pow(float(py) - c.y, 2.0)
			var k := exp(-d2 / (rad * rad))
			var i := py * W + px
			var a := k * dark
			r[i] = lerpf(r[i], tint.r, a)
			g[i] = lerpf(g[i], tint.g, a)
			b[i] = lerpf(b[i], tint.b, a)
			hgt[i] -= k * depth


# Линия морщины: неровная, глубина спадает к концам
func _line(pts: Array, rad: float, dark: float, depth: float, wob: float = .0012) -> void:
	var seed_v := rng.randf() * 500.0
	var total := 0.0
	for i in pts.size() - 1:
		total += (pts[i] as Vector2).distance_to(pts[i + 1])
	var walked := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var e: Vector2 = pts[i + 1]
		var seg := a.distance_to(e)
		var n := maxi(int(seg / .00035), 1)
		for j in n:
			var t := float(j) / float(n)
			var q := a.lerp(e, t)
			var along := (walked + seg * t) / total
			var fade := sin(along * PI)
			var w := noise.get_noise_2d(seed_v, (walked + seg * t) * 160.0) * wob
			_stamp(q.x, q.y + w, rad, dark * (.08 * fade), depth * (.1 * fade))
		walked += seg


func _both(pts: Array, rad: float, dark: float, depth: float, wob: float = .0012) -> void:
	for s in [-1.0, 1.0]:
		var side: Array = []
		for q in pts:
			side.append(Vector2((q as Vector2).x * s, (q as Vector2).y + rng.randf_range(-.0006, .0006)))
		_line(side, rad, dark, depth, wob)


func _paint_wrinkles() -> void:
	# Морщины лба с разрывами
	for yw in [.127, .138, .149]:
		_line([Vector2(-.058, yw + .005), Vector2(-.024, yw - .001), Vector2(-.004, yw + .0006)], 1.9, .75, 1.0)
		_line([Vector2(.003, yw + .0008), Vector2(.026, yw - .0015), Vector2(.056, yw + .004)], 1.9, .75, 1.0)
	# Между бровей
	_both([Vector2(.0058, .1225), Vector2(.0066, .112), Vector2(.0052, .103)], 1.9, .85, 1.2, .0005)
	# Складка верхнего века и под глазом
	_both([Vector2(.015, .095), Vector2(.03, .1), Vector2(.046, .098), Vector2(.058, .088)], 1.8, .75, 1.1, .0004)
	_both([Vector2(.019, .0705), Vector2(.034, .0655), Vector2(.05, .0695)], 1.7, .55, .8, .0005)
	_both([Vector2(.022, .0605), Vector2(.036, .0555), Vector2(.056, .0615)], 2.0, .6, 1.0, .0006)
	# Гусиные лапки
	for k in 4:
		var yy := .0935 - float(k) * .0075
		_both([Vector2(.061, yy - .0015 + float(k) * .0008), Vector2(.076, yy + (float(k) - 1.5) * .0056)], 1.6, .6, .9, .0004)
	# Носогубные складки, морщины от уголков рта, подбородок
	_both([Vector2(.0165, .049), Vector2(.0225, .035), Vector2(.0285, .019), Vector2(.0325, .006)], 2.6, .95, 1.5, .0005)
	_both([Vector2(.0255, .006), Vector2(.0285, -.008), Vector2(.0325, -.026)], 2.2, .7, 1.1, .0005)
	_both([Vector2(.04, .036), Vector2(.05, .02), Vector2(.055, .002)], 2.2, .35, .6, .001)
	_line([Vector2(-.014, y0 - .0195), Vector2(0, y0 - .0225), Vector2(.014, y0 - .0195)], 2.0, .32, .8, .0005)
	# Вертикальные морщинки над и на губах
	for n in 24:
		var x := rng.randf_range(-.024, .024)
		var top := y0 + rng.randf_range(.012, .021)
		_line([Vector2(x, y0 + .0065 * (1.0 - pow(x / .025, 2.0))), Vector2(x * 1.05, top)], 1.25, .42, .7, .0002)
	for n in 30:
		var x := rng.randf_range(-.019, .019)
		var up := n % 2 == 0
		var a := y0 + (.0007 if up else -.0007)
		var e := y0 + (.0048 if up else -.0072) * (1.0 - pow(x / .022, 2.0))
		_line([Vector2(x, a), Vector2(x * 1.03, e)], 1.05, .28, .7, .0001)
	# Морщины на щеках, переносице и подбородке
	for n in 14:
		var x := rng.randf_range(.04, .068)
		var y := rng.randf_range(.002, .05)
		_both([Vector2(x, y), Vector2(x + rng.randf_range(.002, .007), y - rng.randf_range(.008, .018))], 1.4, .18, .32, .0007)


func _paint_spots() -> void:
	# Пигментные пятна на лбу, висках и щеках
	for n in 46:
		var x := rng.randf_range(-.07, .07)
		var y := rng.randf_range(.0, .148)
		if absf(x) < .022 and y < .09:
			continue
		_stamp(x, y, rng.randf_range(2.0, 6.0), rng.randf_range(.1, .3), 0.0, Color(0.38, 0.25, 0.17))
	# Сосудики на крыльях носа и щеках
	for n in 26:
		var s := -1.0 if rng.randf() < .5 else 1.0
		var x0 := s * rng.randf_range(.013, .036)
		var y0_v := rng.randf_range(.033, .056)
		_line([Vector2(x0, y0_v), Vector2(x0 + rng.randf_range(-.006, .006), y0_v + rng.randf_range(-.005, .005))], 1.0, .22, 0.0, .0006)


func _paint_brows() -> void:
	# Брови из отдельных волосков: редкие, седые с тёмными
	for s in [-1.0, 1.0]:
		for n in 105:
			var t := rng.randf()
			var x := .015 + t * .047
			var y := .1085 + .16 * x + rng.randf_range(-.0036, .0036) * (1.0 - t * .55) + .001
			var ang := lerpf(1.25, .12, t) + rng.randf_range(-.28, .28)
			var length := rng.randf_range(.004, .0085)
			var tint := Color(0.2, 0.185, 0.17) if rng.randf() < .68 else Color(0.5, 0.48, 0.45)
			var steps := 7
			for k in steps:
				var f := float(k) / float(steps)
				var qx := x + cos(ang) * length * f
				var qy := y + sin(ang) * length * f
				_stamp(qx * s, qy, 1.05, .24 * (1.0 - f * .6), .035, tint)
	# Короткие волоски у линии роста волос
	for n in 180:
		var x := rng.randf_range(-.062, .062)
		var hairline := .153 + .9 * x * x - 1.2 * maxf(0.0, absf(x) - .05) + rng.randf_range(-.0075, .001)
		for k in 6:
			_stamp(x + float(k) * .0002 * sign(x), hairline + float(k) * .0009, 1.0, .16, .02, Color(0.42, 0.4, 0.37))


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var color_b := PackedByteArray()
	var normal_b := PackedByteArray()
	color_b.resize(W * H * 3)
	normal_b.resize(W * H * 3)
	var k := 2.4
	for py in H:
		var up: int = maxi(py - 1, 0)
		var dn: int = mini(py + 1, H - 1)
		for px in W:
			var i := py * W + px
			var o := i * 3
			color_b[o] = int(clampf(r[i], 0.0, 1.0) * 255.0)
			color_b[o + 1] = int(clampf(g[i], 0.0, 1.0) * 255.0)
			color_b[o + 2] = int(clampf(b[i], 0.0, 1.0) * 255.0)
			var lf: int = py * W + (px + W - 1) % W
			var rt: int = py * W + (px + 1) % W
			# Касательная идёт по росту u, бинормаль — вниз по картинке
			var nx: float = -(hgt[rt] - hgt[lf]) * k
			var ny: float = -(hgt[dn * W + px] - hgt[up * W + px]) * k
			var n := Vector3(nx, ny, 1.0).normalized()
			normal_b[o] = int((n.x * 0.5 + 0.5) * 255.0)
			normal_b[o + 1] = int((n.y * 0.5 + 0.5) * 255.0)
			normal_b[o + 2] = int((n.z * 0.5 + 0.5) * 255.0)
	var ci := Image.create_from_data(W, H, false, Image.FORMAT_RGB8, color_b)
	var ni := Image.create_from_data(W, H, false, Image.FORMAT_RGB8, normal_b)
	ci.save_png(OUT + "face_albedo.png")
	ni.save_png(OUT + "face_normal.png")
	print("baked ", OUT)
