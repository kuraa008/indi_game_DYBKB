extends "res://scripts/ApartmentKit.gd"

# Коридор у входной двери: вешалка с крючками, стёганая куртка, ботинки, дорожная сумка.
# Механик здесь нет. Для thebekshdet: с этой сумкой Итан выходит из дома.

const WALL_X := 4.14            # стена, на которой висит куртка
const HOOK_Z := 1.7
const HOOK_Y := FL + 1.74
const NECK_Y := HOOK_Y - 0.075
const LENGTH := 0.74            # длина куртки от основания воротника
const TOP := -0.0525            # верх воротника
const QUILT := 0.0825           # высота одной стёганой полосы
const COAT := Color(0.17, 0.21, 0.18)
const BRASS := Color(0.55, 0.45, 0.25)

# Половина ширины и глубина куртки сверху вниз
const WIDTH := [[-0.0525, 0.062], [-0.02, 0.066], [0.0, 0.074], [0.03, 0.084], [0.07, 0.118], [0.11, 0.165], [0.16, 0.205],
	[0.22, 0.222], [0.36, 0.226], [0.55, 0.232], [0.74, 0.24]]
const DEPTH := [[-0.0525, 0.036], [0.0, 0.05], [0.06, 0.062], [0.16, 0.082], [0.4, 0.095], [0.74, 0.088]]


func _ready() -> void:
	name = "ApartmentHall"
	_rng.seed = 9012
	_build_hooks()
	_build_coat()
	_build_boots()
	_build_bag()
	_remove_lock_glow.call_deferred()


# Цветной замок снаружи входной двери светится, и свет проходит сквозь дверь в коридор
func _remove_lock_glow() -> void:
	var level := get_parent().get_parent()
	# Замок появляется не сразу после загрузки карты, поэтому ищем его несколько раз
	for attempt in range(20):
		var padlocks := level.find_children("DoorPadlock", "Node3D", true, false)
		if not padlocks.is_empty():
			for padlock in padlocks:
				for light in padlock.find_children("*", "OmniLight3D", true, false):
					light.queue_free()
			return
		await get_tree().create_timer(0.25).timeout


func _build_hooks() -> void:
	_bx(Vector3(0.022, 0.1, 0.96), Vector3(WALL_X - 0.011, HOOK_Y, HOOK_Z + 0.0), Color.WHITE)
	_flush(CutsceneKit.tmat("wood_furniture.png", Color(0.5, 0.36, 0.25), 2.5, 0.6))
	for z in [HOOK_Z - 0.3, HOOK_Z, HOOK_Z + 0.3]:
		_cy(0.02, 0.022, 0.006, Vector3(WALL_X - 0.025, HOOK_Y, z), BRASS, Vector3(0, 0, 90), 14)
		var tip := Vector3(WALL_X - 0.084, HOOK_Y + 0.03, z)
		_tube(_smooth([Vector3(WALL_X - 0.022, HOOK_Y, z), Vector3(WALL_X - 0.055, HOOK_Y - 0.004, z),
			Vector3(WALL_X - 0.078, HOOK_Y + 0.002, z), tip], 5), 0.0055, BRASS, 8)
		_bl(Vector3.ONE * 0.009, tip, BRASS)
	_flush(_vmat(0.36, 0.7))


# Точка на куртке: v от левого края до правого, t вниз от основания воротника
func _coat_point(v: float, t: float) -> Array:
	var s := lerpf(v, sin(v * PI * 0.5), 0.65)
	var seam := absf(sin(PI * (t - 0.03) / QUILT))
	var puff := pow(seam, 0.55)
	var rib := smoothstep(LENGTH - 0.04, LENGTH - 0.03, t)
	puff = lerpf(puff, 0.72, rib)
	var hw: float = _table(WIDTH, t) * (0.985 + 0.03 * puff)
	var u := s * hw
	var edge := pow(maxf(0.0, 1.0 - s * s), 0.38)
	var h: float = _table(DEPTH, t) * edge * (0.84 + 0.22 * puff)
	# Складки расходятся от крючка, ниже ткань ложится мягкими волнами
	var fan := sin(atan2(u, t + 0.07) * 11.0 + 0.7) * smoothstep(0.0, 0.25, t) * (1.0 - 0.5 * t / LENGTH)
	var drape := sin(s * 14.0 + 1.3 + 2.0 * sin(t * 6.0)) * smoothstep(0.25, LENGTH, t)
	h += (0.008 * fan + 0.007 * drape) * edge
	# Ткань поджата к молнии
	h -= 0.014 * exp(-pow(u / 0.016, 2.0)) * edge
	var shade := 0.46 * (1.0 - smoothstep(0.0, 0.3, seam)) * (1.0 - rib) + 0.12 * (0.5 - 0.5 * (fan + drape) * 0.5)
	var c := COAT.darkened(shade)
	if rib > 0.5:
		c = COAT.darkened(0.42 + 0.1 * sin(u * 320.0))
	var hem := sin(s * 7.0 + 0.6) * 0.01 * smoothstep(0.5, LENGTH, t)
	return [Vector3(WALL_X - h, NECK_Y - t - hem, HOOK_Z + u), c]


func _build_coat() -> void:
	var nu := 56
	var nv := 66
	var lining := Color(0.04, 0.04, 0.045)
	var body := func(i: int, j: int) -> Array:
		var v := float(i) / float(nu) * 2.0 - 1.0
		if j == 0 or j > nv:
			# Первый и последний ряды заворачивают край к стене, чтобы не было щели
			var edge: Array = _coat_point(v, TOP if j == 0 else LENGTH)
			var p: Vector3 = edge[0]
			return [Vector3(WALL_X, p.y, p.z), lining]
		return _coat_point(v, lerpf(TOP, LENGTH, float(j - 1) / float(nv - 1)))
	_surface(nu, nv + 1, body)

	var on_wall := func(u: float, t: float, h: float) -> Vector3:
		return Vector3(WALL_X - h, NECK_Y - t, HOOK_Z + u)

	# Рукава начинаются внутри плеча и продолжают его скат
	for side in [-1.0, 1.0]:
		var pts := []
		for q in [[0.115, 0.115, 0.04], [0.185, 0.165, 0.056], [0.242, 0.25, 0.064], [0.272, 0.37, 0.066], [0.28, 0.52, 0.066], [0.272, 0.66, 0.072], [0.266, 0.72, 0.076]]:
			pts.append(on_wall.call(side * float(q[0]), q[1], q[2]))
		var radius := func(k: float) -> float:
			var grow := minf(1.0, 0.55 + k * 1.8)
			return lerpf(0.054, 0.044, k) * grow * (0.94 + 0.1 * pow(absf(sin(k * PI * 9.0)), 0.55))
		var colour := func(k: float) -> Color:
			return COAT.darkened(0.08 + 0.42 * (1.0 - smoothstep(0.0, 0.3, absf(sin(k * PI * 9.0)))))
		_tube(_smooth(pts, 6), radius, colour, 12, 0.82, Vector3.BACK)
		var wrist: Vector3 = pts[pts.size() - 1]
		_tube([wrist, wrist + Vector3(0.0, -0.028, 0.0), wrist + Vector3(0.002, -0.052, side * -0.002)], 0.034, COAT.darkened(0.5), 12, 0.82, Vector3.BACK)

	# Молния по центру и прорези карманов
	var zip := []
	for j in range(nv):
		var t := lerpf(TOP + 0.008, LENGTH - 0.015, float(j) / float(nv - 1))
		var p: Vector3 = _coat_point(0.0, t)[0]
		zip.append(p + Vector3(-0.0015, 0, 0))
	_tube(zip, 0.0095, COAT.darkened(0.62), 6, 0.3, Vector3.BACK)
	for side in [-1.0, 1.0]:
		var slit := []
		for k in range(12):
			var w := float(k) / 11.0
			var p: Vector3 = _coat_point(side * lerpf(0.42, 0.72, w), lerpf(0.47, 0.58, w))[0]
			slit.append(p + Vector3(-0.0025, 0, 0))
		_tube(slit, 0.0055, COAT.darkened(0.7), 6, 0.25, Vector3.UP)
	_flush(_vmat(0.74, 0.0, false, "fabric"))

	# Петля на крючке и бегунок молнии
	_torus(0.01, 0.0135, Vector3(WALL_X - 0.035, HOOK_Y - 0.011, HOOK_Z), Color(0.06, 0.06, 0.06), Vector3(0, 0, 90))
	_flush(_vmat(0.8, 0.0, false, "fabric"))
	var pull: Vector3 = _coat_point(0.0, TOP + 0.03)[0]
	_bx(Vector3(0.004, 0.028, 0.009), pull + Vector3(-0.005, -0.012, 0), Color(0.62, 0.62, 0.64))
	_flush(_vmat(0.3, 0.6))


func _build_boots() -> void:
	for bx_x in [3.87, 4.01]:
		_base = _xf(Vector3(bx_x, FL, 2.18), Vector3(0, 180 + (bx_x - 3.94) * 60.0, 0))
		var leather := Color(0.15, 0.11, 0.09)
		_bx(Vector3(0.1, 0.022, 0.28), Vector3(0, 0.011, 0), Color(0.06, 0.05, 0.05))
		_bl(Vector3(0.05, 0.05, 0.09), Vector3(0, 0.05, -0.07), leather)
		_cy(0.044, 0.05, 0.13, Vector3(0, 0.085, 0.07), leather, Vector3(-6, 0, 0), 12)
		_torus(0.039, 0.05, Vector3(0, 0.15, 0.078), leather.lightened(0.05), Vector3(-6, 0, 0), Vector3(1, 0.5, 1))
		for k in range(3):
			_bx(Vector3(0.05, 0.003, 0.006), Vector3(0, 0.094 + float(k) * 0.016, 0.003 - float(k) * 0.018), Color(0.5, 0.45, 0.35), Vector3(-35, 0, 0))
	_flush(_vmat(0.92))


# Дорожная сумка: мягкий цилиндр, ремни, ручки, молния сверху
func _build_bag() -> void:
	var x0 := 2.81
	var x1 := 3.29
	var z := 1.95
	var r := 0.135
	var y := FL + r
	var canvas := Color(0.13, 0.17, 0.24)
	var strap := Color(0.06, 0.06, 0.07)
	var path := []
	for k in range(25):
		path.append(Vector3(lerpf(x0, x1, float(k) / 24.0), y, z))
	var radius := func(k: float) -> float:
		var e := clampf(minf(k, 1.0 - k) / 0.13, 0.0, 1.0)
		return r * sqrt(1.0 - (1.0 - e) * (1.0 - e)) * (0.97 + 0.03 * sin(k * 17.0))
	_tube(path, radius, canvas, 16, 0.86, Vector3.UP)
	_flush(_vmat(0.86, 0.0, false, "fabric"))

	for sx in [x0 + 0.13, x1 - 0.13]:
		var band := []
		for k in range(21):
			var a := TAU * float(k) / 20.0
			band.append(Vector3(sx, y + cos(a) * (r + 0.002), z + sin(a) * (r * 0.86 + 0.002)))
		_tube(band, 0.016, strap, 6, 0.18, Vector3.RIGHT)
	var top_y := y + r
	_tube([Vector3(x0 + 0.05, top_y, z), Vector3((x0 + x1) * 0.5, top_y + 0.0005, z), Vector3(x1 - 0.05, top_y, z)], 0.011, strap, 6, 0.2, Vector3.BACK)
	for side in [-1.0, 1.0]:
		var dz: float = 0.035 * side
		_tube(_smooth([Vector3(x0 + 0.13, top_y, z + dz), Vector3(x0 + 0.17, top_y + 0.05, z + dz * 2.0), Vector3((x0 + x1) * 0.5, top_y + 0.075, z + dz * 3.4),
			Vector3(x1 - 0.17, top_y + 0.05, z + dz * 2.0), Vector3(x1 - 0.13, top_y, z + dz)], 6), 0.012, strap, 8, 0.45, Vector3.BACK)
	_flush(_vmat(0.8, 0.0, false, "fabric"))

	_solid(Vector3((x0 + x1) * 0.5, FL + r, z), Vector3(x1 - x0, r * 2.0, r * 2.0 * 0.86))
