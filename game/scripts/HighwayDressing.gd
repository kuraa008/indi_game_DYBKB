extends "res://scripts/ApartmentKit.gd"

# Шоссе у дома отца (карта «Шоссе»): отбойники с проломом там, где слетела машина Итана,
# тормозной след, осколки, знаки, почтовый ящик у съезда к дому, провода между столбами,
# пни, поваленные стволы и камни у тропы к дому.
# Механик здесь нет. Координаты — мировые (узел стоит в нуле).

const ROAD_TOP := 0.12
const RAIL_X := 6.1
const DRIVE_Z := Vector2(-226.6, -218.4)     # съезд к дому: в отбойнике проём
const BREAK_Z := Vector2(-238.6, -251.0)     # пролом: здесь машина ушла с дороги
const POLES := [Vector3(8.5, 0.0, -222.5), Vector3(-14.0, 0.0, -220.5), Vector3(-28.0, 0.0, -218.5), Vector3(-42.0, 0.0, -220.5)]
const POLE_TOP := 6.79
const HOUSE_DROP := Vector3(-52.86, 6.1, -221.2)

const STEEL := Color(0.5, 0.52, 0.53)
const RUSTY := Color(0.36, 0.27, 0.2)
const AMBER := Color(0.85, 0.5, 0.08)


func _ready() -> void:
	name = "HighwayDressing"
	_rng.seed = 4401
	_build_rails()
	_flush(_vmat(0.55, 0.55), true)
	_build_skid()
	_build_patches()
	_flush(_vmat(1.0))
	_build_debris()
	_flush(_vmat(0.35, 0.2))
	_build_signs()
	_build_mailbox()
	_build_branches()
	_flush(_vmat(0.8, 0.1), true)
	_build_wires()
	_flush(_vmat(0.7), false)
	_labels()
	# Последним, чтобы номера мешей выше в кэше карты не сдвинулись
	_build_forest_floor()
	_flush(_vmat(0.95), true)


# ── Отбойники ──

func _build_rails() -> void:
	_rail_run(RAIL_X, -150.0, -300.0, 1.0)
	_rail_run(-RAIL_X, -150.0, DRIVE_Z.y, -1.0)
	_rail_run(-RAIL_X, DRIVE_Z.x, BREAK_Z.x, -1.0)
	_rail_run(-RAIL_X, BREAK_Z.y, -300.0, -1.0)
	# Край пролома: последняя секция выгнута наружу и смята, кусок балки лежит в траве
	_base = Transform3D(Basis(Vector3.UP, deg_to_rad(-24.0)) * Basis(Vector3.FORWARD, deg_to_rad(-9.0)), Vector3(-RAIL_X, 0.0, BREAK_Z.x))
	_beam(0.0, -2.6, -1.0, RUSTY.lerp(STEEL, 0.4))
	_bx(Vector3(0.1, 0.72, 0.15), Vector3(-0.05, 0.36, -2.5), STEEL.darkened(0.3), Vector3(0, 0, -14))
	_base = Transform3D.IDENTITY
	_base = _xf(Vector3(-7.9, 0.06, -244.6), Vector3(4.0, 71.0, 86.0))
	_beam(1.3, -1.3, 1.0, STEEL.darkened(0.15))
	_base = Transform3D.IDENTITY
	_base = Transform3D(Basis(Vector3.UP, deg_to_rad(18.0)) * Basis(Vector3.FORWARD, deg_to_rad(7.0)), Vector3(-RAIL_X, 0.0, BREAK_Z.y))
	_beam(1.9, 0.0, -1.0, STEEL.darkened(0.1))
	_base = Transform3D.IDENTITY
	# Через отбойник не перелезть, но только там, куда игрок может дойти
	for run in [[RAIL_X, -199.0, -262.0], [-RAIL_X, -199.0, DRIVE_Z.y], [-RAIL_X, DRIVE_Z.x, BREAK_Z.x], [-RAIL_X, BREAK_Z.y, -262.0]]:
		var z0: float = run[1]
		var z1: float = run[2]
		_solid(Vector3(run[0], 0.5, (z0 + z1) * 0.5), Vector3(0.3, 1.0, absf(z1 - z0)))


# Секция: балка-«волна» на столбиках каждые 4 м, на столбиках катафоты
func _rail_run(x: float, z0: float, z1: float, side: float) -> void:
	_base = _xf(Vector3(x, 0.0, 0.0))
	_beam(z0, z1, side, STEEL)
	var z := z0
	while z >= z1 - 0.01:
		var tone := STEEL.darkened(_rng.randf_range(0.15, 0.35))
		_bx(Vector3(0.1, 0.75, 0.15), Vector3(side * 0.09, 0.375, z), tone)
		_bx(Vector3(0.14, 0.18, 0.12), Vector3(side * 0.03, 0.62, z), tone)
		_bx(Vector3(0.02, 0.05, 0.07), Vector3(-side * 0.035, 0.8, z), AMBER)
		z -= 4.0
	_base = Transform3D.IDENTITY


func _beam(z0: float, z1: float, side: float, col: Color) -> void:
	var ln := absf(z1 - z0)
	var mid := (z0 + z1) * 0.5
	_bx(Vector3(0.025, 0.31, ln), Vector3(-side * 0.02, 0.62, mid), col)
	for y in [0.52, 0.72]:
		_bx(Vector3(0.05, 0.07, ln), Vector3(-side * 0.045, y, mid), col.lightened(0.06))
	# Ржавые потёки по низу балки
	var n := int(ln / 3.0)
	for i in range(n):
		var zz := z0 + (z1 - z0) * (float(i) + _rng.randf()) / float(maxi(n, 1))
		_bx(Vector3(0.028, 0.08, _rng.randf_range(0.2, 0.7)), Vector3(-side * 0.021, 0.5, zz), RUSTY)


# ── Тормозной след: две чёрные полосы с дороги в траву ──

func _build_skid() -> void:
	var p := [Vector3(2.2, 0, -224.0), Vector3(1.6, 0, -234.0), Vector3(-2.6, 0, -241.0), Vector3(-6.4, 0, -244.8)]
	var pts := []
	for i in range(41):
		var t := float(i) / 40.0
		var u := 1.0 - t
		pts.append(p[0] * u * u * u + p[1] * 3.0 * u * u * t + p[2] * 3.0 * u * t * t + p[3] * t * t * t)
	for side in [-0.78, 0.78]:
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var d := b - a
			var off: Vector3 = Vector3(-d.z, 0, d.x).normalized() * float(side)
			var c: Vector3 = (a + b) * 0.5 + off
			var on_road := absf(c.x) < 4.75
			var y := ROAD_TOP + 0.003 if on_road else 0.03
			var fade := clampf(float(i) / 8.0, 0.0, 1.0)
			var col := Color(0.04, 0.04, 0.045).lerp(Color(0.21, 0.21, 0.22), 1.0 - fade) if on_road else Color(0.12, 0.08, 0.05)
			_bx(Vector3(0.21, 0.004, d.length() + 0.04), Vector3(c.x, y, c.z), col, Vector3(0, rad_to_deg(atan2(d.x, d.z)), 0))


# Заплатки и трещины на старом асфальте
func _build_patches() -> void:
	for q in [[-2.4, -206.0, 2.2, 1.4], [1.9, -217.5, 1.4, 2.6], [-1.2, -252.5, 2.8, 1.6], [2.6, -258.0, 1.5, 1.2], [-2.8, -230.0, 1.2, 1.9]]:
		_bx(Vector3(q[2], 0.003, q[3]), Vector3(q[0], ROAD_TOP + 0.0015, q[1]), Color(0.16, 0.165, 0.17), Vector3(0, _rng.randf_range(-6, 6), 0))
	for i in range(14):
		var x := _rng.randf_range(-4.2, 4.2)
		var z := _rng.randf_range(-262.0, -200.0)
		var a := _rng.randf_range(0.0, 180.0)
		for k in range(3):
			var ln := _rng.randf_range(0.4, 1.1)
			_bx(Vector3(0.025, 0.003, ln), Vector3(x, ROAD_TOP + 0.002, z), Color(0.07, 0.07, 0.075), Vector3(0, a, 0))
			x += sin(deg_to_rad(a)) * ln * 0.5
			z += cos(deg_to_rad(a)) * ln * 0.5
			a += _rng.randf_range(-40.0, 40.0)
	# Обочина: хвоя и шишки на краю асфальта
	for i in range(90):
		var sx := 1.0 if _rng.randf() < 0.5 else -1.0
		var x := sx * _rng.randf_range(4.3, 4.85)
		var z := _rng.randf_range(-262.0, -200.0)
		_bx(Vector3(_rng.randf_range(0.2, 0.6), 0.004, _rng.randf_range(0.1, 0.3)), Vector3(x, ROAD_TOP + 0.002, z), Color(0.2, 0.15, 0.08), Vector3(0, _rng.randf_range(0, 180), 0))


# ── Осколки фар и стекла, кусок бампера, колпак ──

func _build_debris() -> void:
	var centre := Vector3(-8.7, 0.0, -249.6)
	for i in range(70):
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf()) * 2.2
		var p := centre + Vector3(cos(a) * r, 0.0, sin(a) * r * 1.3)
		var s := _rng.randf_range(0.02, 0.07)
		var col := Color(0.62, 0.7, 0.72) if i % 3 != 0 else (Color(0.6, 0.06, 0.04) if i % 2 == 0 else Color(0.85, 0.82, 0.7))
		_bx(Vector3(s, 0.006, s * _rng.randf_range(0.5, 1.4)), p + Vector3(0, 0.035, 0), col, Vector3(_rng.randf_range(-15, 15), _rng.randf() * 180.0, 0))
	# На дороге тоже: машину крутило
	for i in range(26):
		var p := Vector3(_rng.randf_range(-4.4, -1.0), ROAD_TOP + 0.004, _rng.randf_range(-243.5, -238.0))
		var s := _rng.randf_range(0.02, 0.05)
		_bx(Vector3(s, 0.005, s), p, Color(0.62, 0.7, 0.72), Vector3(0, _rng.randf() * 180.0, 0))
	# Кусок бампера
	_base = _xf(Vector3(-4.0, ROAD_TOP + 0.05, -242.2), Vector3(0, 63, 4))
	_bx(Vector3(0.9, 0.12, 0.08), Vector3.ZERO, Color(0.08, 0.08, 0.085))
	_bx(Vector3(0.35, 0.11, 0.07), Vector3(0.56, 0.0, 0.07), Color(0.08, 0.08, 0.085), Vector3(0, 28, 0))
	_bx(Vector3(0.14, 0.05, 0.02), Vector3(-0.2, 0.0, -0.045), Color(0.75, 0.75, 0.72))
	_base = Transform3D.IDENTITY
	# Колпак колеса
	_base = _xf(Vector3(-3.1, ROAD_TOP + 0.03, -245.6), Vector3(7, 0, -4))
	_cy(0.19, 0.2, 0.035, Vector3.ZERO, Color(0.66, 0.67, 0.68), Vector3.ZERO, 18)
	_cy(0.07, 0.07, 0.04, Vector3(0, 0.005, 0), Color(0.4, 0.4, 0.42), Vector3.ZERO, 10)
	_base = Transform3D.IDENTITY


# ── Знаки ──

func _build_signs() -> void:
	# «Осторожно, олени»: треугольник на столбе у правой обочины
	_base = _xf(Vector3(RAIL_X + 0.7, 0.0, -213.5))
	_cy(0.035, 0.04, 2.35, Vector3(0, 1.175, -0.02), STEEL.darkened(0.25), Vector3.ZERO, 8)
	_parts.append([_prism(Vector3(0.92, 0.8, 0.025)), _base * _xf(Vector3(0, 2.25, 0.0)), Color(0.62, 0.06, 0.05)])
	_parts.append([_prism(Vector3(0.72, 0.62, 0.03)), _base * _xf(Vector3(0, 2.2, 0.004)), Color(0.88, 0.87, 0.82)])
	_deer(Vector3(0.0, 2.13, 0.024), 0.36, Color(0.05, 0.05, 0.05))
	_bx(Vector3(0.62, 0.2, 0.02), Vector3(0, 1.66, 0.0), Color(0.88, 0.87, 0.82))
	_bx(Vector3(0.66, 0.24, 0.015), Vector3(0, 1.66, -0.004), Color(0.08, 0.08, 0.08))
	# Ржавая вмятина от дроби: кто-то стрелял по знаку
	for i in range(7):
		_bx(Vector3(0.015, 0.015, 0.006), Vector3(_rng.randf_range(-0.2, 0.2), _rng.randf_range(2.05, 2.35), 0.02), RUSTY.darkened(0.4))
	_base = Transform3D.IDENTITY
	# Указатель на Блэк-Пайн у левой обочины: зелёный щит на двух столбах
	_base = _xf(Vector3(-RAIL_X - 1.2, 0.0, -205.5))
	for sx in [-0.62, 0.62]:
		_cy(0.04, 0.045, 2.6, Vector3(sx, 1.3, -0.03), STEEL.darkened(0.3), Vector3.ZERO, 8)
	_bx(Vector3(1.75, 0.66, 0.03), Vector3(0, 2.22, 0), Color(0.08, 0.26, 0.16))
	_bx(Vector3(1.65, 0.56, 0.032), Vector3(0, 2.22, 0.0), Color(0.07, 0.24, 0.15))
	for y in [1.91, 2.53]:
		_bx(Vector3(1.66, 0.018, 0.034), Vector3(0, y, 0.0), Color(0.8, 0.82, 0.78))
	_base = Transform3D.IDENTITY


func _prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


# Силуэт оленя для знака: тело, шея, голова, ноги и рога, всё плоское
func _deer(at: Vector3, s: float, col: Color) -> void:
	var t := 0.006
	_bx(Vector3(0.5, 0.2, t) * s, at + Vector3(0, 0, 0), col, Vector3(0, 0, -6))
	_bx(Vector3(0.09, 0.26, t) * s, at + Vector3(0.24, 0.15, 0) * s, col, Vector3(0, 0, -28))
	_bx(Vector3(0.18, 0.08, t) * s, at + Vector3(0.36, 0.28, 0) * s, col, Vector3(0, 0, -18))
	for lx in [-0.2, -0.12, 0.13, 0.2]:
		_bx(Vector3(0.04, 0.26, t) * s, at + Vector3(lx, -0.2, 0) * s, col, Vector3(0, 0, lx * 40.0))
	for k in [[0.28, 0.42, 30.0], [0.36, 0.44, -15.0], [0.24, 0.5, 70.0], [0.4, 0.52, 60.0]]:
		_bx(Vector3(0.025, 0.16, t) * s, at + Vector3(k[0], k[1], 0) * s, col, Vector3(0, 0, k[2]))
	_bx(Vector3(0.08, 0.03, t) * s, at + Vector3(-0.27, 0.06, 0) * s, col, Vector3(0, 0, 30))


# ── Почтовый ящик отца у съезда ──

func _build_mailbox() -> void:
	_base = _xf(Vector3(-RAIL_X - 0.15, 0.0, -227.2), Vector3(0, 0, 3))
	var post := Color(0.3, 0.24, 0.17)
	_bx(Vector3(0.11, 1.12, 0.11), Vector3(0, 0.56, 0), post)
	_bx(Vector3(0.36, 0.06, 0.2), Vector3(0, 1.1, 0), post)
	var green := Color(0.17, 0.25, 0.19)
	_bx(Vector3(0.5, 0.17, 0.24), Vector3(0.02, 1.215, 0), green)
	_cy(0.12, 0.12, 0.5, Vector3(0.02, 1.3, 0), green, Vector3(0, 0, 90), 16)
	_bx(Vector3(0.012, 0.3, 0.25), Vector3(0.275, 1.25, 0), green.darkened(0.2))
	# Красный флажок опущен: писем никто не ждёт
	_bx(Vector3(0.02, 0.26, 0.03), Vector3(-0.08, 1.28, 0.13), Color(0.55, 0.08, 0.05), Vector3(0, 0, 80))
	for i in range(6):
		_bx(Vector3(_rng.randf_range(0.03, 0.09), _rng.randf_range(0.02, 0.06), 0.004), Vector3(_rng.randf_range(-0.2, 0.22), _rng.randf_range(1.16, 1.36), 0.123), RUSTY)
	_base = Transform3D.IDENTITY


# Сухие сучья на обочине и у съезда
func _build_branches() -> void:
	for b in [[-8.4, -219.0, 20.0], [-9.5, -233.5, 120.0], [8.4, -241.0, 60.0], [9.8, -208.5, 160.0], [-8.8, -258.0, 80.0], [11.0, -253.0, 10.0]]:
		var o := Vector3(b[0], 0.05, b[1])
		var d := Vector3(sin(deg_to_rad(b[2])), 0, cos(deg_to_rad(b[2])))
		var ln := _rng.randf_range(1.4, 2.6)
		var path := [o, o + d * ln * 0.5 + Vector3(0, 0.05, 0), o + d * ln]
		_tube(path, func(k): return lerpf(0.06, 0.02, k), Color(0.2, 0.15, 0.1), 6)
		var side := Vector3(-d.z, 0, d.x)
		_tube([o + d * ln * 0.4, o + d * ln * 0.55 + side * 0.4 + Vector3(0, 0.12, 0)], 0.018, Color(0.2, 0.15, 0.1), 5)


# ── Провода между столбами и к дому ──

func _build_wires() -> void:
	var dark := Color(0.04, 0.04, 0.045)
	for i in range(POLES.size() - 1):
		for dz in [-0.768, 0.0, 0.768]:
			var a: Vector3 = POLES[i] + Vector3(0, POLE_TOP, dz)
			var b: Vector3 = POLES[i + 1] + Vector3(0, POLE_TOP, dz)
			_tube(_sag(a, b, 0.012 * a.distance_to(b) + 0.35), 0.011, dark, 5)
	var last: Vector3 = POLES[POLES.size() - 1] + Vector3(0, POLE_TOP, 0.0)
	_tube(_sag(last, HOUSE_DROP, 0.5), 0.012, dark, 5)
	# Кронштейн с изолятором на стене дома
	_bx(Vector3(0.3, 0.05, 0.05), HOUSE_DROP + Vector3(0.12, -0.04, 0), Color(0.12, 0.12, 0.12))
	_cy(0.03, 0.04, 0.12, HOUSE_DROP + Vector3(0.24, 0.04, 0), Color(0.85, 0.86, 0.82), Vector3.ZERO, 8)


func _sag(a: Vector3, b: Vector3, sag: float) -> Array:
	var out := []
	for i in range(17):
		var t := float(i) / 16.0
		out.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	return out


func _labels() -> void:
	var white := Color(0.92, 0.93, 0.9)
	CutsceneKit.text3d(self, "ГОРОД   92 км", Vector3(-RAIL_X - 1.2, 2.25, -205.48), Vector3.ZERO, 0.0042, white, 64)
	CutsceneKit.text3d(self, "8 км", Vector3(RAIL_X + 0.7, 1.655, -213.488), Vector3.ZERO, 0.0026, Color(0.06, 0.06, 0.06), 64)


# ── Лесная подстилка у тропы к дому и у тропинки от машины ──
# Ели из HighwayChapter на эти места не встают: FLOOR_SPOTS для них заняты.
const FLOOR_SPOTS := [
	# вид, x, z, поворот (°), размер (у бревна — длина)
	["stump", -11.0, -226.6, 0.0, 1.0],
	["stump", -23.5, -220.4, 40.0, 0.85],
	["stump", -17.4, -236.2, 80.0, 1.15],
	["log", -33.6, -226.7, 72.0, 4.2],
	["log", -10.9, -234.8, 24.0, 3.4],
	["rock", -19.6, -227.6, 0.0, 0.7],
	["rock", -38.6, -220.4, 0.0, 0.9],
	["rock", -13.2, -241.4, 0.0, 0.55],
	["rock", -16.9, -229.8, 0.0, 0.5],
]
const BARK := Color(0.17, 0.125, 0.09)
const SAWN := Color(0.5, 0.4, 0.27)


func _build_forest_floor() -> void:
	for spot in FLOOR_SPOTS:
		var at := Vector3(float(spot[1]), 0.0, float(spot[2]))
		match str(spot[0]):
			"stump":
				_stump(at, float(spot[3]), float(spot[4]))
			"log":
				_log(at, float(spot[3]), float(spot[4]))
			"rock":
				_rock(at, float(spot[4]))


# Пень: срез светлый, корни уходят в землю
func _stump(at: Vector3, yaw: float, s: float) -> void:
	var h := 0.42 * s
	_cy(0.24 * s, 0.31 * s, h, at + Vector3(0, h * 0.5 - 0.02, 0), BARK, Vector3(0, yaw, 0), 11)
	_cy(0.225 * s, 0.225 * s, 0.03, at + Vector3(0, h - 0.01, 0), SAWN, Vector3(0, yaw, 0), 11)
	_cy(0.07 * s, 0.07 * s, 0.035, at + Vector3(0, h, 0), SAWN.darkened(0.25), Vector3(0, yaw, 0), 8)
	for k in range(4):
		var a := deg_to_rad(yaw + k * 90.0 + _rng.randf_range(5.0, 35.0))
		var d := Vector3(sin(a), 0, cos(a))
		var path := [at + d * 0.18 * s + Vector3(0, 0.14 * s, 0), at + d * 0.42 * s + Vector3(0, 0.05, 0), at + d * 0.66 * s + Vector3(0, -0.03, 0)]
		_tube(path, func(t): return lerpf(0.085, 0.025, t) * s, BARK, 6)


# Поваленный ствол: один торец спилен, другой обломан, на боку пара сучьев
func _log(at: Vector3, yaw: float, length: float) -> void:
	var d := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var a := at - d * length * 0.5 + Vector3(0, 0.19, 0)
	var b := at + d * length * 0.5 + Vector3(0, 0.15, 0)
	_tube([a, a.lerp(b, 0.5) + Vector3(0, 0.025, 0), b], func(t): return lerpf(0.22, 0.17, t), BARK, 10)
	var along := Vector3(0, yaw + 90.0, 90.0)
	_cy(0.205, 0.205, 0.03, a - d * 0.01, SAWN, along, 12)
	_cy(0.03, 0.17, 0.34, b + d * 0.16, BARK.darkened(0.15), along, 7)
	var side := Vector3(-d.z, 0, d.x)
	for k in [[0.3, 1.0], [0.62, -1.0], [0.82, 1.0]]:
		var o := a.lerp(b, k[0])
		_tube([o + side * k[1] * 0.15, o + side * k[1] * 0.45 + Vector3(0, 0.22, 0) + d * 0.12], func(t): return lerpf(0.045, 0.015, t), BARK, 5)


# Камень: две глыбы, сверху мох
func _rock(at: Vector3, s: float) -> void:
	var tone := Color(0.32, 0.33, 0.32).darkened(_rng.randf_range(0.0, 0.15))
	var turn := Vector3(_rng.randf_range(-8.0, 8.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(-8.0, 8.0))
	_bl(Vector3(0.62, 0.38, 0.5) * s, at + Vector3(0, 0.08 * s, 0), tone, turn)
	_bl(Vector3(0.5, 0.11, 0.4) * s, at + Vector3(0, 0.36 * s, 0), Color(0.19, 0.25, 0.13), turn)
	_bl(Vector3(0.32, 0.22, 0.28) * s, at + Vector3(0.5 * s, 0.03, 0.22 * s), tone.lightened(0.06), turn + Vector3(0, 40, 0))
