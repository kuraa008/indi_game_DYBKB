extends "res://scripts/ApartmentKit.gd"

# Двор дома отца: гараж изнутри, машина под брезентом, сарай, поленница, крыльцо.
# Механик здесь нет. Для thebekshdet, глава 4 и глава 3:
#   полная канистра FULL_CAN под машиной, пустая EMPTY_CAN на стеллаже, ключ KEY_POS на гвоздике,
#   монтировка CROWBAR_POS в сарае, машина откатывается от CAR_POS.

const CAR_POS := Vector3(-47.0, 0.1, -208.4)
const FULL_CAN := Vector3(-46.2, 0.1, -206.5)
const EMPTY_CAN := Vector3(-41.5, 1.33, -206.9)
const KEY_POS := Vector3(-49.4, 1.38, -212.82)
const SHED := Vector3(-70.0, 0.0, -238.0)
const CROWBAR_POS := Vector3(-71.45, 0.0, -238.9)

const OLD_WOOD := Color(0.42, 0.33, 0.24)
const PAINTED := Color(0.4, 0.31, 0.23)   # старое тёмное дерево, в цвет стен дома
const IRON := Color(0.16, 0.16, 0.17)


func _ready() -> void:
	name = "FatherYard"
	_rng.seed = 7203
	_build_covered_car()
	_build_garage_inside()
	_build_shed()
	_build_woodpile()
	_build_porch()
	_build_yard_hatch()
	_build_well()
	_remove_old_hatch.call_deferred()


func _wood(uv: float = 1.4, rough: float = 0.92) -> StandardMaterial3D:
	var m: StandardMaterial3D = CutsceneKit.tmat("board_weathered.png", Color.WHITE, uv, rough).duplicate()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


func _plank_tone(base: Color) -> Color:
	return base.darkened(_rng.randf_range(0.0, 0.22)).lightened(_rng.randf_range(0.0, 0.06))


# Канистра: корпус со скруглёнными рёбрами, штампованный крест, три ручки, горловина
func _jerrycan(at: Transform3D, col: Color) -> void:
	_base = at
	var edge := col.darkened(0.3)
	_loft([
		_rg(0.16, 0.078, 0.022, 0.0),
		_rg(0.165, 0.083, 0.024, 0.012),
		_rg(0.165, 0.083, 0.024, 0.42),
		_rg(0.158, 0.076, 0.022, 0.44),
		_rg(0.0, 0.0, 0.0, 0.44),
	], col, Transform3D.IDENTITY, 3)
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.3, 0.018, 0.003), Vector3(0, 0.21, s * 0.084), edge, Vector3(0, 0, 52))
		_bx(Vector3(0.3, 0.018, 0.003), Vector3(0, 0.21, s * 0.084), edge, Vector3(0, 0, -52))
	for x in [-0.09, 0.0, 0.09]:
		_pipe(Vector3(x - 0.02, 0.44, 0), Vector3(x - 0.02, 0.5, 0), 0.006, edge)
		_pipe(Vector3(x + 0.02, 0.44, 0), Vector3(x + 0.02, 0.5, 0), 0.006, edge)
		_pipe(Vector3(x - 0.02, 0.5, 0), Vector3(x + 0.02, 0.5, 0), 0.007, edge)
	_cy(0.028, 0.03, 0.03, Vector3(0.12, 0.455, 0), Color(0.3, 0.3, 0.32), Vector3(0, 0, -22), 10)


# Банка с краской: закатанный край, этикетка, потёк, у части — проволочная ручка
func _paint_can(pos: Vector3, r: float, h: float, col: Color) -> void:
	var xf := _xf(pos, Vector3(0, _rng.randf() * 360.0, 0))
	var rim := Color(0.3, 0.3, 0.29)
	_loft([
		_rg(r * 0.96, r * 0.96, r * 0.96, 0.0), _rg(r, r, r, 0.007), _rg(r, r, r, h - 0.01), _rg(r * 1.03, r * 1.03, r * 1.03, h - 0.006),
		_rg(r * 1.03, r * 1.03, r * 1.03, h), _rg(r * 0.93, r * 0.93, r * 0.93, h), _rg(r * 0.93, r * 0.93, r * 0.93, h - 0.006), _rg(0.0, 0.0, 0.0, h - 0.006),
	], col, xf, 3, [rim, col, col, rim, rim, rim, col.darkened(0.3), col.darkened(0.3)])
	var label := Color(0.42, 0.38, 0.28).darkened(_rng.randf_range(0.0, 0.3))
	_loft([_rg(r * 1.006, r * 1.006, r * 1.006, h * 0.2), _rg(r * 1.006, r * 1.006, r * 1.006, h * 0.7)], label, xf, 3)
	var saved := _base
	_base = _base * xf
	_bx(Vector3(r * 0.7, h * 0.16, 0.0015), Vector3(0, h * 0.48, r * 1.012), col.darkened(0.2))
	_bx(Vector3(0.012, h * _rng.randf_range(0.35, 0.6), 0.002), Vector3(r * 0.5, h * 0.72, r * 0.9), col.lightened(0.12))
	if _rng.randf() < 0.55:
		var bail := []
		for k in range(9):
			var a := PI * float(k) / 8.0
			bail.append(Vector3(cos(a) * r * 1.04, h + sin(a) * r * 0.42, 0.0))
		_tube(bail, 0.0022, Color(0.24, 0.24, 0.25), 5)
	_base = saved


# ── Старая машина отца под брезентом ──

# Высота машины под тканью: длинный капот, кабина, багажник
func _car_height(x: float, z: float) -> float:
	var body: float = _table([[-2.4, 0.62], [-2.15, 0.76], [-1.0, 0.85], [0.9, 0.86], [2.1, 0.8], [2.4, 0.6]], z)
	var body_w: float = _table([[-2.4, 0.84], [-2.0, 0.95], [2.0, 0.95], [2.4, 0.86]], z)
	var side := pow(maxf(0.0, 1.0 - pow(absf(x) / body_w, 5.0)), 0.3)
	var h := body * side
	if z > -0.95 and z < 1.15:
		var roof: float = _table([[-0.95, 0.86], [-0.5, 1.33], [0.65, 1.37], [1.15, 0.9]], z)
		var cab := pow(maxf(0.0, 1.0 - pow(absf(x) / 0.68, 4.0)), 0.4)
		h = maxf(h, roof * cab)
	return h


func _build_covered_car() -> void:
	var half_x := 1.08
	var half_z := 2.72
	var nu := 66
	var nv := 104
	var canvas := Color(0.3, 0.32, 0.24)
	var dirs := [[Vector2(0.8, 0.6), 21.0, 0.4], [Vector2(-0.5, 0.86), 33.0, 2.1], [Vector2(0.97, -0.24), 13.0, 4.0], [Vector2(0.2, 0.98), 47.0, 1.2]]
	var point := func(i: int, j: int) -> Array:
		var x := lerpf(-half_x, half_x, float(i) / float(nu))
		var z := lerpf(-half_z, half_z, float(j) / float(nv))
		var p := Vector2(x, z)
		var folds := 0.0
		for d in dirs:
			folds += sin(p.dot(d[0]) * float(d[1]) + float(d[2]))
		folds /= 4.0
		var top := _car_height(x, z)
		var near_edge := maxf(absf(x) / half_x, absf(z) / half_z)
		var skirt := smoothstep(0.76, 1.0, near_edge)
		# Складки свисающей ткани крупнее, чем на крыше
		var along := sin((x + z) * 26.0 + sin(x * 9.0) * 2.0) * 0.5 + sin((x - z) * 17.0) * 0.5
		var lift := 0.15
		# Угол брезента задран: под ним видна канистра
		lift += 0.32 * smoothstep(0.75, 0.0, Vector2(x - 0.92, z - 2.0).length())
		var h: float = lerpf(maxf(top, lift), lift, smoothstep(0.84, 1.0, near_edge))
		h += folds * 0.018 * (1.0 - skirt) + along * 0.02 * skirt * float(h > lift + 0.02)
		var spread := 1.0 + 0.03 * along * skirt
		var c := canvas.darkened(0.3 * (0.5 - 0.5 * folds) + 0.25 * skirt * (0.5 - 0.5 * along))
		return [Vector3(x * spread, h, z * spread), c]
	_base = _xf(CAR_POS)
	_surface(nu, nv, point)
	var fabric: StandardMaterial3D = CutsceneKit.tmat("fabric.png", Color.WHITE, 3.0, 0.96).duplicate()
	fabric.vertex_color_use_as_albedo = true
	fabric.vertex_color_is_srgb = true
	fabric.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flush(fabric)

	# Колёса и темнота под машиной, верёвки поверх брезента
	_base = _xf(CAR_POS)
	_bx(Vector3(1.5, 0.02, 4.2), Vector3(0, 0.012, 0), Color(0.02, 0.02, 0.02))
	for sx in [-0.72, 0.72]:
		for sz in [-1.45, 1.45]:
			_cy(0.3, 0.3, 0.17, Vector3(sx, 0.3, sz), Color(0.03, 0.03, 0.035), Vector3(0, 0, 90), 16)
	var rope := Color(0.5, 0.44, 0.3)
	for z in [-1.55, 1.75]:
		var pts := []
		for k in range(25):
			var x := lerpf(-half_x * 0.95, half_x * 0.95, float(k) / 24.0)
			pts.append(Vector3(x, maxf(_car_height(x, z), 0.2) + 0.018, z))
		_tube(pts, 0.009, rope, 5)
	_flush(_vmat(0.85, 0.0, false, "fabric"))
	_solid(CAR_POS + Vector3(0, 0.72, 0), Vector3(1.72, 1.44, 4.78))

	# Полная канистра под задранным углом брезента
	_jerrycan(_xf(FULL_CAN, Vector3(0, 28, 0)), Color(0.46, 0.09, 0.07))
	_flush(_vmat(0.42, 0.3))


# ── Гараж внутри: стеллаж, инструменты, ключ на гвоздике, шины, масляные пятна ──
func _build_garage_inside() -> void:
	# Металлический стеллаж вдоль восточной стены
	var post := Color(0.2, 0.22, 0.23)
	var board := Color(0.4, 0.31, 0.21)
	var rack := Vector3(-41.5, 0.1, -206.6)
	_base = _xf(rack)
	for sx in [-0.3, 0.3]:
		for sz in [-1.15, 1.15]:
			_bx(Vector3(0.04, 2.05, 0.04), Vector3(sx, 1.025, sz), post)
	var shelf_levels := [0.18, 0.7, 1.22, 1.74]
	for y in shelf_levels:
		_bx(Vector3(0.62, 0.03, 2.34), Vector3(0, y, 0), board.darkened(_rng.randf_range(0.0, 0.2)))
		for sz in [-1.15, 1.15]:
			_bx(Vector3(0.6, 0.03, 0.04), Vector3(0, y - 0.03, sz), post)
	_flush(_vmat(0.85, 0.0, false, "wood"))
	_solid(rack + Vector3(0, 1.0, 0), Vector3(0.66, 2.05, 2.4))

	# Пустая канистра на полке; банки, бутылки и ящик с инструментом
	_jerrycan(_xf(EMPTY_CAN, Vector3(0, 86, 0)), Color(0.2, 0.3, 0.2))
	_flush(_vmat(0.48, 0.25))
	_base = _xf(rack)
	var jar_cols := [Color(0.44, 0.33, 0.14), Color(0.28, 0.3, 0.34), Color(0.5, 0.15, 0.1), Color(0.18, 0.28, 0.42), Color(0.56, 0.54, 0.48)]
	for y in [0.195, 0.715, 1.755]:
		var z := -1.05
		while z < 1.05:
			var r := _rng.randf_range(0.05, 0.085)
			var h := _rng.randf_range(0.11, 0.2)
			var c: Color = jar_cols[_rng.randi_range(0, jar_cols.size() - 1)]
			var x := _rng.randf_range(-0.14, 0.14)
			_paint_can(Vector3(x, float(y), z), r, h, c.darkened(0.35))
			z += _rng.randf_range(0.24, 0.42)
	_bx(Vector3(0.28, 0.17, 0.5), Vector3(0, 1.32, 0.72), Color(0.42, 0.13, 0.1))
	_bx(Vector3(0.29, 0.03, 0.51), Vector3(0, 1.415, 0.72), Color(0.32, 0.1, 0.08))
	_pipe(Vector3(0, 1.45, 0.58), Vector3(0, 1.45, 0.86), 0.01, Color(0.15, 0.15, 0.16))
	_flush(_vmat(0.5, 0.2))

	# Доска с инструментами над верстаком
	var wall_z := -204.15
	var board_at := _xf(Vector3(-50.8, 0.0, wall_z), Vector3(0, 180, 0))
	_base = board_at
	_bx(Vector3(2.1, 0.9, 0.02), Vector3(0, 1.62, 0.012), Color(0.44, 0.36, 0.26))
	_flush(_wood())
	_base = board_at
	var steel := Color(0.5, 0.51, 0.53)
	var handle := Color(0.3, 0.17, 0.09)
	# Пила
	_bx(Vector3(0.6, 0.14, 0.003), Vector3(-0.62, 1.8, 0.03), steel)
	_bx(Vector3(0.14, 0.16, 0.022), Vector3(-0.27, 1.8, 0.03), handle)
	# Молоток
	_bx(Vector3(0.032, 0.32, 0.024), Vector3(-0.08, 1.62, 0.033), handle)
	_bx(Vector3(0.13, 0.042, 0.038), Vector3(-0.08, 1.78, 0.04), steel.darkened(0.3))
	# Ключи по размеру
	for k in range(5):
		var len_k := 0.16 + float(k) * 0.035
		var x := 0.14 + float(k) * 0.08
		_bx(Vector3(0.022, len_k, 0.006), Vector3(x, 1.86 - len_k * 0.5, 0.03), steel)
		_torus(0.012, 0.022, Vector3(x, 1.86, 0.03), steel, Vector3(90, 0, 0), Vector3(1, 0.4, 1))
	# Отвёртки и моток проволоки
	for k in range(3):
		var x := 0.2 + float(k) * 0.09
		_cy(0.014, 0.014, 0.09, Vector3(x, 1.48, 0.03), Color(0.5, 0.2 + float(k) * 0.1, 0.08), Vector3.ZERO, 8)
		_cy(0.0045, 0.0045, 0.12, Vector3(x, 1.38, 0.03), steel, Vector3.ZERO, 6)
	_torus(0.075, 0.1, Vector3(0.74, 1.62, 0.04), Color(0.3, 0.2, 0.12), Vector3(90, 0, 0), Vector3(1, 0.5, 1))
	_flush(_vmat(0.5, 0.45))

	# Ключ на гвоздике у двери
	_base = _xf(KEY_POS)
	_cy(0.0035, 0.0035, 0.03, Vector3(0, 0.03, 0.012), IRON, Vector3(90, 0, 0), 6)
	_torus(0.012, 0.018, Vector3(0, 0.012, 0.018), Color(0.62, 0.52, 0.26), Vector3(90, 0, 0), Vector3(1, 0.5, 1))
	_bx(Vector3(0.006, 0.05, 0.003), Vector3(0, -0.028, 0.018), Color(0.62, 0.52, 0.26))
	for k in range(2):
		_bx(Vector3(0.012, 0.005, 0.003), Vector3(0.008, -0.04 - float(k) * 0.012, 0.018), Color(0.62, 0.52, 0.26))
	_flush(_vmat(0.32, 0.7))

	# Старые шины в углу и пятна масла на полу
	_base = _xf(Vector3(-51.7, 0.1, -209.0))
	for k in range(3):
		_torus(0.17, 0.32, Vector3(float(k) * 0.015, 0.1 + float(k) * 0.19, float(k % 2) * 0.03), Color(0.04, 0.04, 0.045), Vector3(0, 0, 0), Vector3(1, 0.62, 1))
	_flush(_vmat(0.82))
	_solid(Vector3(-51.7, 0.45, -209.0), Vector3(0.7, 0.7, 0.7))
	_base = Transform3D.IDENTITY
	for q in [[-46.5, -207.0, 0.42], [-47.4, -209.6, 0.3], [-46.2, -210.8, 0.2], [-48.2, -206.2, 0.17]]:
		_cy(q[2], q[2], 0.001, Vector3(q[0], 0.1008, q[1]), Color(0.018, 0.016, 0.014), Vector3.ZERO, 20)
	_flush(_vmat(0.2))


# ── Сарай: дощатые стены, двускатная крыша, приоткрытая дверь, монтировка внутри ──
func _build_shed() -> void:
	var w := 3.4
	var d := 2.6
	var eave := 2.05
	var rise := 0.62
	var plank := 0.145
	_base = _xf(SHED)
	var door_half := 0.48
	var door_top := 1.92
	# Торцы с высоким фронтоном идут по бокам: высота доски зависит от положения по Z
	for s in [-1.0, 1.0]:
		var z := -d * 0.5
		while z < d * 0.5 - 0.01:
			var mid := z + plank * 0.5
			var h := eave + rise * (1.0 - absf(mid) / (d * 0.5))
			_bx(Vector3(0.03, h, plank - 0.006), Vector3(s * w * 0.5, h * 0.5, mid), _plank_tone(OLD_WOOD))
			z += plank
	# Передняя и задняя стены
	for s in [-1.0, 1.0]:
		var x := -w * 0.5
		while x < w * 0.5 - 0.01:
			var mid := x + plank * 0.5
			var is_door: bool = s > 0.0 and absf(mid) < door_half
			if is_door:
				_bx(Vector3(plank - 0.006, eave - door_top, 0.03), Vector3(mid, (door_top + eave) * 0.5, s * d * 0.5), _plank_tone(OLD_WOOD))
			else:
				_bx(Vector3(plank - 0.006, eave, 0.03), Vector3(mid, eave * 0.5, s * d * 0.5), _plank_tone(OLD_WOOD))
			x += plank
	# Обвязка, косяки и пол
	var frame := OLD_WOOD.darkened(0.3)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bx(Vector3(0.09, eave, 0.09), Vector3(sx * (w * 0.5 - 0.05), eave * 0.5, sz * (d * 0.5 - 0.05)), frame)
		_bx(Vector3(0.05, door_top, 0.05), Vector3(sx * door_half, door_top * 0.5, d * 0.5 + 0.02), frame)
	_bx(Vector3(door_half * 2.0 + 0.1, 0.06, 0.05), Vector3(0, door_top + 0.03, d * 0.5 + 0.02), frame)
	_bx(Vector3(w - 0.1, 0.04, d - 0.1), Vector3(0, 0.02, 0), Color(0.27, 0.21, 0.15))
	# Полки и верстачок внутри
	for y in [1.2, 1.62]:
		_bx(Vector3(1.6, 0.03, 0.26), Vector3(-0.55, y, -d * 0.5 + 0.17), _plank_tone(OLD_WOOD))
	_bx(Vector3(0.7, 0.05, 1.5), Vector3(w * 0.5 - 0.4, 0.8, -0.25), _plank_tone(OLD_WOOD))
	for sz in [-0.9, 0.4]:
		_bx(Vector3(0.05, 0.8, 0.05), Vector3(w * 0.5 - 0.68, 0.4, sz), frame)
	# Дверь висит на петлях и приоткрыта наружу
	var door_at := _xf(Vector3(-door_half + 0.02, 0.0, d * 0.5 + 0.03), Vector3(0, -68, 0))
	var kept := _base
	_base = kept * door_at
	var x := 0.0
	while x < door_half * 2.0 - 0.06:
		_bx(Vector3(plank - 0.006, door_top - 0.1, 0.025), Vector3(x + plank * 0.5, door_top * 0.5, 0), _plank_tone(OLD_WOOD))
		x += plank
	for y in [0.3, 1.6]:
		_bx(Vector3(door_half * 2.0 - 0.1, 0.09, 0.025), Vector3(door_half - 0.03, y, 0.024), frame)
	_bx(Vector3(1.3, 0.09, 0.025), Vector3(door_half - 0.03, 0.95, 0.024), frame, Vector3(0, 0, 58))
	_base = kept
	_flush(_wood(1.6), true)

	# Крыша из ржавых листов с волной
	var slope := atan2(rise, d * 0.5)
	var slope_len := sqrt(rise * rise + d * d * 0.25) + 0.26
	var rust := Color(0.34, 0.2, 0.13)
	_base = _xf(SHED)
	for s in [-1.0, 1.0]:
		var centre := Vector3(0, eave + rise * 0.5 + 0.035, s * (d * 0.25 + 0.06))
		var tilt := Vector3(rad_to_deg(slope) * s, 0, 0)
		_bx(Vector3(w + 0.34, 0.012, slope_len), centre, rust.darkened(0.15), tilt)
		var rx := -(w + 0.3) * 0.5
		while rx < (w + 0.3) * 0.5:
			var tone := rust.lightened(_rng.randf_range(0.0, 0.12)).darkened(_rng.randf_range(0.0, 0.18))
			_bx(Vector3(0.05, 0.026, slope_len), centre + Vector3(rx, 0.012, 0), tone, tilt)
			rx += 0.11
	_bx(Vector3(w + 0.36, 0.05, 0.12), Vector3(0, eave + rise + 0.05, 0), rust.darkened(0.3))
	_flush(_vmat(0.62, 0.35))

	# Вещи в сарае: монтировка, лопата, грабли, банки
	_base = _xf(SHED)
	var bar := Color(0.46, 0.08, 0.06)
	var wall_side := -w * 0.5 + 0.1
	var low := Vector3(wall_side + 0.06, 0.02, -0.95)
	var high := Vector3(wall_side, 0.82, -0.86)
	_tube(_smooth([low + Vector3(0.05, 0.0, -0.05), low, low.lerp(high, 0.5), high, high + Vector3(-0.01, 0.06, 0.05), high + Vector3(-0.012, 0.075, 0.1)], 4), 0.011, bar, 7)
	for q in [[0.42, Color(0.34, 0.25, 0.16)], [0.82, Color(0.3, 0.23, 0.15)]]:
		var tx: float = q[0]
		_pipe(Vector3(tx, 0.1, -d * 0.5 + 0.2), Vector3(tx + 0.1, 1.62, -d * 0.5 + 0.08), 0.015, q[1])
	_bx(Vector3(0.22, 0.28, 0.02), Vector3(0.41, 0.17, -d * 0.5 + 0.21), Color(0.3, 0.3, 0.32), Vector3(14, 0, 0))
	_bx(Vector3(0.42, 0.05, 0.05), Vector3(0.82, 0.12, -d * 0.5 + 0.21), Color(0.25, 0.25, 0.27))
	for k in range(7):
		_bx(Vector3(0.008, 0.11, 0.012), Vector3(0.65 + float(k) * 0.056, 0.05, -d * 0.5 + 0.21), Color(0.25, 0.25, 0.27))
	var can_cols := [Color(0.22, 0.17, 0.1), Color(0.24, 0.11, 0.08), Color(0.13, 0.17, 0.2), Color(0.27, 0.23, 0.13), Color(0.16, 0.18, 0.13)]
	for k in range(6):
		var r := _rng.randf_range(0.05, 0.08)
		var h := _rng.randf_range(0.1, 0.18)
		_paint_can(Vector3(-1.18 + float(k) * 0.24, 1.215, -d * 0.5 + 0.17), r, h, can_cols[k % can_cols.size()])
	for k in range(3):
		_paint_can(Vector3(-1.1 + float(k) * 0.4, 1.635, -d * 0.5 + 0.17), 0.065, _rng.randf_range(0.09, 0.15), can_cols[(k + 2) % can_cols.size()])
	_flush(_vmat(0.6, 0.3))

	# Стены твёрдые, в дверном проёме свободно
	_solid(SHED + Vector3(-w * 0.5, 1.2, 0), Vector3(0.08, 2.4, d))
	_solid(SHED + Vector3(w * 0.5, 1.2, 0), Vector3(0.08, 2.4, d))
	_solid(SHED + Vector3(0, 1.2, -d * 0.5), Vector3(w, 2.4, 0.08))
	var side_w := w * 0.5 - door_half
	for s in [-1.0, 1.0]:
		_solid(SHED + Vector3(s * (door_half + side_w * 0.5), 1.2, d * 0.5), Vector3(side_w, 2.4, 0.08))
	_solid(SHED + Vector3(w * 0.5 - 0.4, 0.42, -0.25), Vector3(0.7, 0.84, 1.5))


# ── Поленница у западной стены гаража, навес и колода с топором ──
func _build_woodpile() -> void:
	var x_end := -54.38         # торцы поленьев смотрят сюда
	var length := 0.56
	var z0 := -211.6
	var z1 := -205.4
	var bark := Color(0.2, 0.15, 0.1)
	var cut := Color(0.47, 0.37, 0.24)
	_base = Transform3D.IDENTITY
	var rows := 8
	for row in range(rows):
		var y := 0.12 + float(row) * 0.14
		var step := 0.165
		var z := z0 + (0.082 if row % 2 == 1 else 0.0)
		var top_trim: float = float(row - 6) * 0.9 if row >= 6 else 0.0
		while z < z1 - top_trim:
			if z >= z0 + top_trim:
				var r := _rng.randf_range(0.062, 0.088)
				var dx := _rng.randf_range(-0.05, 0.05)
				var centre := Vector3(x_end + length * 0.5 + dx, y + _rng.randf_range(-0.012, 0.012), z)
				_cy(r, r, length, centre, bark.lightened(_rng.randf_range(0.0, 0.12)), Vector3(0, 0, 90), 9)
				var pale := cut.darkened(_rng.randf_range(0.0, 0.3))
				_cy(r * 0.92, r * 0.92, 0.004, centre + Vector3(-length * 0.5 - 0.001, 0, 0), pale, Vector3(0, 0, 90), 9)
				_cy(r * 0.5, r * 0.5, 0.002, centre + Vector3(-length * 0.5 - 0.004, 0, 0), pale.darkened(0.2), Vector3(0, 0, 90), 6)
			z += step
	_flush(_vmat(0.92, 0.0, false, "log"))

	# Навес из досок на столбиках
	var wood_col := OLD_WOOD.darkened(0.15)
	var roof_y := 1.72
	var post_x := x_end - 0.16
	for z in [z0 - 0.15, (z0 + z1) * 0.5, z1 + 0.15]:
		_bx(Vector3(0.1, roof_y, 0.1), Vector3(post_x, roof_y * 0.5, z), wood_col)
	_bx(Vector3(0.1, 0.1, z1 - z0 + 0.5), Vector3(post_x, roof_y, (z0 + z1) * 0.5), wood_col)
	var tilt := Vector3(0, 0, -11)
	var z := z0 - 0.3
	while z < z1 + 0.3:
		_bx(Vector3(1.0, 0.03, 0.235), Vector3(post_x + 0.42, roof_y + 0.12, z + 0.12), _plank_tone(OLD_WOOD), tilt)
		z += 0.245
	# Колода с топором
	var block := Vector3(-56.2, 0.0, -209.4)
	_cy(0.28, 0.31, 0.5, block + Vector3(0, 0.25, 0), bark, Vector3.ZERO, 12)
	_cy(0.27, 0.27, 0.004, block + Vector3(0, 0.502, 0), cut.darkened(0.15), Vector3.ZERO, 12)
	_flush(_wood(1.8), true)

	_base = _xf(block + Vector3(0, 0.5, 0), Vector3(0, 35, 0))
	_pipe(Vector3(0.0, 0.02, 0.0), Vector3(-0.1, 0.5, 0.44), 0.016, Color(0.36, 0.26, 0.16))
	_flush(_vmat(0.8))
	_base = _xf(block + Vector3(0, 0.5, 0), Vector3(0, 35, 0))
	_bx(Vector3(0.05, 0.14, 0.16), Vector3(0.0, 0.05, -0.02), Color(0.26, 0.26, 0.28), Vector3(-22, 0, 0))
	_flush(_vmat(0.4, 0.7))
	# Щепки у колоды
	_base = _xf(block)
	for k in range(26):
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(0.34, 1.0)
		var size := Vector3(_rng.randf_range(0.03, 0.12), 0.012, _rng.randf_range(0.02, 0.05))
		_bx(size, Vector3(cos(a) * r, 0.008, sin(a) * r), cut.darkened(_rng.randf_range(0.05, 0.4)), Vector3(0, _rng.randf() * 180.0, 0))
	_flush(_vmat(0.95, 0.0, false, "concrete"))

	_solid(Vector3(x_end + length * 0.5, 0.65, (z0 + z1) * 0.5), Vector3(length, 1.3, z1 - z0))
	_solid(block + Vector3(0, 0.25, 0), Vector3(0.56, 0.5, 0.56))


# ── Люк во дворе: бетонное кольцо, две дощатые створки на кованых петлях, цепь ──
func _remove_old_hatch() -> void:
	var old := get_parent().get_node_or_null("YardHatch")
	if old:
		old.queue_free()


func _build_yard_hatch() -> void:
	var at := Vector3(-58.0, 0.0, -232.1)
	var curb := Color(0.52, 0.5, 0.45)
	var stone: StandardMaterial3D = CutsceneKit.tmat("concrete.png", Color.WHITE, 1.6, 0.95).duplicate()
	stone.vertex_color_use_as_albedo = true
	stone.vertex_color_is_srgb = true
	_base = _xf(at)
	_loft([
		_rg(0.76, 0.76, 0.05, -0.05), _rg(0.75, 0.75, 0.05, 0.1), _rg(0.72, 0.72, 0.05, 0.135), _rg(0.64, 0.64, 0.035, 0.135),
		_rg(0.625, 0.625, 0.03, 0.09), _rg(0.0, 0.0, 0.0, 0.09),
	], curb, Transform3D.IDENTITY, 3, [curb.darkened(0.4), curb.darkened(0.15), curb, curb.darkened(0.08), curb.darkened(0.5), curb.darkened(0.6)])
	_flush(stone, true)

	# Доски двух створок, каждая чуть своя
	var half_w := 0.598
	_base = _xf(at)
	for side in [-1.0, 1.0]:
		var n := 5
		var pw := half_w / float(n)
		for k in range(n):
			var cx: float = side * (0.008 + pw * (float(k) + 0.5))
			var lift := _rng.randf_range(-0.004, 0.006)
			_bx(Vector3(pw - 0.008, 0.042, 1.2 + _rng.randf_range(-0.012, 0.0)), Vector3(cx, 0.125 + lift, 0.0), _plank_tone(OLD_WOOD), Vector3(0, _rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.7, 0.7)))
	_flush(_wood(2.4), true)

	# Железо: стяжки с заклёпками, петли, кольца-ручки
	var iron := Color(0.15, 0.1, 0.075)
	var y := 0.152
	_base = _xf(at)
	for side in [-1.0, 1.0]:
		for z in [-0.36, 0.36]:
			_bx(Vector3(0.52, 0.007, 0.062), Vector3(side * 0.3, y, z), iron.lightened(_rng.randf_range(0.0, 0.08)))
			_cy(0.04, 0.04, 0.007, Vector3(side * 0.05, y, z), iron, Vector3.ZERO, 12)
			var nx := 0.1
			while nx < 0.56:
				_cy(0.0085, 0.011, 0.007, Vector3(side * nx, y + 0.006, z), iron.darkened(0.3), Vector3.ZERO, 8)
				nx += 0.09
			# Петля уходит на бетон
			_cy(0.021, 0.021, 0.12, Vector3(side * 0.625, 0.158, z), iron.darkened(0.15), Vector3(90, 0, 0), 10)
			_bx(Vector3(0.11, 0.007, 0.08), Vector3(side * 0.69, 0.14, z), iron)
		_cy(0.045, 0.05, 0.008, Vector3(side * 0.1, y, 0.0), iron, Vector3.ZERO, 12)
		_torus(0.034, 0.043, Vector3(side * 0.135, y + 0.014, 0.0), Color(0.2, 0.15, 0.11), Vector3(0, 0, -side * 9.0), Vector3(1, 0.6, 1))
	# Перекушенная цепь свисает с кольца и лежит на досках
	var link := Color(0.18, 0.13, 0.1)
	var cx := 0.14
	var cz := 0.03
	for k in range(9):
		var a := float(k) * 0.42 + 0.7
		cx += cos(a) * 0.05
		cz += sin(a) * 0.055
		_torus(0.011, 0.018, Vector3(cx, y + 0.012, cz), link, Vector3(90 if k % 2 == 0 else 8, rad_to_deg(-a), 0), Vector3(0.75, 1, 1.25))
	_flush(_vmat(0.82, 0.3))

	# Мох у основания, хвоя на створках, бурьян вокруг
	_base = _xf(at)
	var moss := Color(0.09, 0.13, 0.05)
	for k in range(14):
		var a := float(k) * TAU / 14.0 + _rng.randf_range(-0.2, 0.2)
		var r := Vector3(_rng.randf_range(0.1, 0.24), _rng.randf_range(0.012, 0.03), _rng.randf_range(0.05, 0.12))
		var rr := _rng.randf_range(0.74, 0.8)
		_bl(r, Vector3(cos(a) * rr, _rng.randf_range(0.02, 0.06), sin(a) * rr), moss.darkened(_rng.randf_range(0.0, 0.35)), Vector3(0, rad_to_deg(-a) + 90.0, 0))
	for k in range(70):
		var size := _rng.randf_range(0.03, 0.07)
		var px := _rng.randf_range(-0.62, 0.62)
		var pz := _rng.randf_range(-0.6, 0.6)
		_bx(Vector3(size, 0.002, 0.005), Vector3(px, y + 0.008, pz), Color(0.2, 0.13, 0.06).darkened(_rng.randf_range(0.0, 0.4)), Vector3(0, _rng.randf() * 180.0, 0))
	_flush(_vmat(0.96, 0.0, false, "concrete"))
	var tufts: Array[Transform3D] = []
	for k in range(13):
		var a := _rng.randf() * TAU
		var rr := _rng.randf_range(0.9, 1.25)
		tufts.append(_xf(at + Vector3(cos(a) * rr, 0.0, maxf(sin(a) * rr, -0.55)), Vector3(0, _rng.randf() * 360.0, 0), Vector3.ONE * _rng.randf_range(0.3, 0.55)))
	RoadKit.add_tufts(self, tufts, 26.0)


# ── Старый колодец за люком: каменное кольцо, деревянный ворот с навесом, верёвка, ведро ──
func _build_well() -> void:
	var at := Vector3(-60.6, 0.0, -235.6)
	var r := 0.72
	var stone: StandardMaterial3D = CutsceneKit.tmat("concrete.png", Color.WHITE, 1.3, 0.96).duplicate()
	stone.vertex_color_use_as_albedo = true
	stone.vertex_color_is_srgb = true
	_base = _xf(at)
	var courses := 6
	for course in range(courses):
		var n := 15
		var y := 0.09 + float(course) * 0.155
		for k in range(n):
			var a := (float(k) + 0.5 * float(course % 2)) * TAU / float(n)
			var rr := r + _rng.randf_range(-0.015, 0.025)
			var size := Vector3(TAU * r / float(n) * _rng.randf_range(0.9, 1.03), _rng.randf_range(0.135, 0.165), _rng.randf_range(0.2, 0.27))
			var col := Color(0.44, 0.42, 0.38).darkened(_rng.randf_range(0.0, 0.32)).lightened(_rng.randf_range(0.0, 0.08))
			_softbox(size, _xf(Vector3(cos(a) * rr, y, sin(a) * rr), Vector3(_rng.randf_range(-2.5, 2.5), rad_to_deg(-a) + 90.0, _rng.randf_range(-2.5, 2.5))), col, 0.3, 0.03, 0.2, 4)
	_flush(stone, true)

	# Шахта уходит в темноту
	_base = _xf(at)
	var top := 0.9
	var wall_col := Color(0.2, 0.19, 0.17)
	var black := Color(0.006, 0.006, 0.007)
	var inner := r - 0.09
	_loft([_rg(inner, inner, inner, top), _rg(inner, inner, inner, top - 0.22), _rg(inner, inner, inner, 0.34), _rg(inner, inner, inner, 0.14), _rg(0.0, 0.0, 0.0, 0.14)],
		wall_col, Transform3D.IDENTITY, 8, [wall_col, wall_col.lerp(black, 0.65), black, black, black])
	_flush(_vmat(0.95, 0.0, true))

	# Ворот: два столба, распорки, бревно-барабан, навес
	var wood := OLD_WOOD.darkened(0.2)
	var span := r + 0.13
	_base = _xf(at)
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.13, 2.05, 0.13), Vector3(s * span, 1.02, 0.0), _plank_tone(wood))
		_bx(Vector3(0.1, 0.1, 0.72), Vector3(s * span, 0.42, 0.0), wood.darkened(0.2))
		_bx(Vector3(0.06, 0.06, 0.62), Vector3(s * span, 1.72, 0.0), wood.darkened(0.15))
	_bx(Vector3(span * 2.0 + 0.3, 0.12, 0.12), Vector3(0, 2.1, 0), _plank_tone(wood))
	var slope := 32.0
	var run := 0.84
	for s in [-1.0, 1.0]:
		var x := -span - 0.32
		while x < span + 0.32:
			var w := _rng.randf_range(0.13, 0.19)
			var c := Vector3(x + w * 0.5, 2.15 + sin(deg_to_rad(slope)) * run * 0.5, s * cos(deg_to_rad(slope)) * run * 0.5)
			_bx(Vector3(w - 0.008, 0.024, run + _rng.randf_range(-0.04, 0.05)), c, _plank_tone(OLD_WOOD.darkened(0.08)), Vector3(s * slope + _rng.randf_range(-1.0, 1.0), 0, 0))
			x += w
	_bx(Vector3(span * 2.0 + 0.7, 0.05, 0.08), Vector3(0, 2.15 + sin(deg_to_rad(slope)) * run + 0.015, 0), wood.darkened(0.25))
	_cy(0.085, 0.085, span * 2.0 - 0.1, Vector3(0, 1.38, 0), wood.lightened(0.05), Vector3(0, 0, 90), 12)
	# Ручка ворота
	_flush(_wood(2.0), true)

	var iron := Color(0.15, 0.11, 0.09)
	var rope := Color(0.42, 0.36, 0.25)
	_base = _xf(at)
	_pipe(Vector3(span - 0.05, 1.38, 0), Vector3(span + 0.2, 1.38, 0), 0.014, iron)
	_pipe(Vector3(span + 0.2, 1.38, 0), Vector3(span + 0.2, 1.08, 0.08), 0.014, iron)
	_pipe(Vector3(span + 0.2, 1.08, 0.08), Vector3(span + 0.4, 1.08, 0.08), 0.016, Color(0.26, 0.19, 0.12))
	_flush(_vmat(0.65, 0.35))
	_base = _xf(at)
	for k in range(9):
		_torus(0.079, 0.1, Vector3(-0.14 + float(k) * 0.034, 1.38, 0), rope.darkened(float(k % 2) * 0.16), Vector3(0, 0, 90))
	_tube([Vector3(0.0, 1.29, 0.0), Vector3(0.012, 0.92, 0.008), Vector3(0.0, 0.2, 0.0)], 0.0085, rope, 6)
	_flush(_vmat(0.95))

	# Ведро стоит у колодца, рядом мох у камней
	_base = _xf(at + Vector3(0.82, 0.0, 0.62), Vector3(0, 24, 0))
	var pail := Color(0.32, 0.25, 0.17)
	_loft([_rg(0.135, 0.135, 0.135, 0.0), _rg(0.175, 0.175, 0.175, 0.3), _rg(0.158, 0.158, 0.158, 0.3), _rg(0.128, 0.128, 0.128, 0.08), _rg(0.0, 0.0, 0.0, 0.08)],
		pail, Transform3D.IDENTITY, 6, [pail, pail, pail.darkened(0.5), pail.darkened(0.7), pail.darkened(0.7)])
	for y in [0.07, 0.25]:
		var ring_r: float = lerpf(0.135, 0.175, float(y) / 0.3) + 0.003
		_loft([_rg(ring_r, ring_r, ring_r, float(y) - 0.016), _rg(ring_r, ring_r, ring_r, float(y) + 0.016)], iron, Transform3D.IDENTITY, 6)
	var handle := []
	for k in range(11):
		var a := PI * float(k) / 10.0
		handle.append(Vector3(cos(a) * 0.17, 0.3 + sin(a) * 0.19, 0.0))
	_tube(handle, 0.006, iron, 6)
	_flush(_vmat(0.85, 0.05, true))
	_base = _xf(at)
	for k in range(22):
		var a := _rng.randf() * TAU
		var rr := r + _rng.randf_range(0.1, 0.17)
		_bl(Vector3(_rng.randf_range(0.08, 0.2), _rng.randf_range(0.02, 0.06), _rng.randf_range(0.06, 0.12)), Vector3(cos(a) * rr, _rng.randf_range(0.03, 0.34) * pow(_rng.randf(), 2.0), sin(a) * rr), Color(0.09, 0.13, 0.05).darkened(_rng.randf_range(0.0, 0.35)), Vector3(0, rad_to_deg(-a) + 90.0, 0))
	_flush(_vmat(0.96, 0.0, false, "concrete"))

	_solid(at + Vector3(0, 0.6, 0), Vector3(1.95, 1.2, 1.95))
	_solid(at + Vector3(0.82, 0.18, 0.62), Vector3(0.36, 0.36, 0.36))


# ── Крыльцо: доски настила, ступень, точёные столбы, балясины, карниз, коврик, фонарь ──
func _build_porch() -> void:
	var deck_top := 0.4
	var x_front := -49.8
	var x_wall := -52.85
	var z_a := -228.5
	var z_b := -221.5
	var board := Color(0.44, 0.35, 0.26)
	_base = Transform3D.IDENTITY
	var z := z_a
	while z < z_b - 0.02:
		_bx(Vector3(x_front - x_wall + 0.06, 0.016, 0.132), Vector3((x_front + x_wall) * 0.5 + 0.03, deck_top + 0.006, z + 0.068), _plank_tone(board))
		z += 0.14
	# Обшивка под настилом и ступень
	_bx(Vector3(0.03, deck_top, z_b - z_a), Vector3(x_front + 0.02, deck_top * 0.5, (z_a + z_b) * 0.5), board.darkened(0.3))
	for dz in [-1.26, -0.42, 0.42, 1.26]:
		_bx(Vector3(0.61, 0.03, 0.78), Vector3(-49.5, 0.215, -225.0 + float(dz)), _plank_tone(board))
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.62, 0.2, 0.05), Vector3(-49.5, 0.1, -225.0 + s * 1.68), board.darkened(0.35))
	# Подшивка потолка навеса и лобовая доска
	var beam_y := 2.965
	z = z_a - 0.25
	while z < z_b + 0.25:
		_bx(Vector3(3.45, 0.012, 0.135), Vector3(-51.22, beam_y, z + 0.07), _plank_tone(PAINTED))
		z += 0.14
	_flush(_wood(1.8), true)

	_base = Transform3D.IDENTITY
	_bx(Vector3(0.04, 0.3, 7.54), Vector3(-49.44, 3.03, -225.0), PAINTED.darkened(0.1))
	_bx(Vector3(3.56, 0.3, 0.04), Vector3(-51.22, 3.03, -228.76), PAINTED.darkened(0.1))
	_bx(Vector3(3.56, 0.3, 0.04), Vector3(-51.22, 3.03, -221.24), PAINTED.darkened(0.1))
	_bx(Vector3(0.14, 0.14, 7.2), Vector3(-50.0, 2.9, -225.0), PAINTED.darkened(0.05))
	# Точёные столбы с облупленной краской
	for pz in [-228.3, -226.3, -223.7, -221.7]:
		var at := _xf(Vector3(-50.0, deck_top + 0.01, pz))
		_bx(Vector3(0.2, 0.7, 0.2), Vector3(-50.0, deck_top + 0.36, pz), PAINTED)
		_bx(Vector3(0.2, 0.34, 0.2), Vector3(-50.0, 2.65, pz), PAINTED)
		_loft([
			_rg(0.07, 0.07, 0.07, 0.7), _rg(0.1, 0.1, 0.1, 0.74), _rg(0.06, 0.06, 0.06, 0.82), _rg(0.075, 0.075, 0.075, 1.2),
			_rg(0.088, 0.088, 0.088, 1.5), _rg(0.07, 0.07, 0.07, 1.82), _rg(0.05, 0.05, 0.05, 2.02), _rg(0.1, 0.1, 0.1, 2.12), _rg(0.08, 0.08, 0.08, 2.2),
		], PAINTED.darkened(0.06), at, 5)
		# Косынки под балкой
		for s in [-1.0, 1.0]:
			_bx(Vector3(0.05, 0.05, 0.44), Vector3(-50.0, 2.72, pz + s * 0.2), PAINTED, Vector3(-s * 42.0, 0, 0))
	# Перила: верхний и нижний брус, балясины
	var rail := func(a: Vector3, b: Vector3) -> void:
		var dir := (b - a)
		var length := dir.length()
		var along_x := absf(dir.x) > absf(dir.z)
		var mid := (a + b) * 0.5
		var size_top := Vector3(length, 0.05, 0.1) if along_x else Vector3(0.1, 0.05, length)
		var size_low := Vector3(length, 0.05, 0.07) if along_x else Vector3(0.07, 0.05, length)
		_bx(size_top, mid + Vector3(0, deck_top + 0.9, 0), PAINTED)
		_bx(size_low, mid + Vector3(0, deck_top + 0.14, 0), PAINTED.darkened(0.08))
		var count := int(length / 0.125)
		for k in range(1, count):
			var p := a.lerp(b, float(k) / float(count))
			_bx(Vector3(0.042, 0.72, 0.042), p + Vector3(0, deck_top + 0.52, 0), PAINTED.darkened(_rng.randf_range(0.0, 0.14)))
		_solid(mid + Vector3(0, deck_top + 0.5, 0), Vector3(length, 1.0, 0.12) if along_x else Vector3(0.12, 1.0, length))
	rail.call(Vector3(-50.0, 0, -228.3), Vector3(-50.0, 0, -226.3))
	rail.call(Vector3(-50.0, 0, -223.7), Vector3(-50.0, 0, -221.7))
	rail.call(Vector3(-50.0, 0, -228.42), Vector3(x_wall, 0, -228.42))
	rail.call(Vector3(-50.0, 0, -221.58), Vector3(x_wall, 0, -221.58))
	_flush(_wood(2.2), true)

	for pz in [-228.3, -226.3, -223.7, -221.7]:
		_solid(Vector3(-50.0, 1.7, pz), Vector3(0.22, 2.6, 0.22))

	# Коврик у двери и фонарь под навесом
	_base = _xf(Vector3(-52.15, deck_top + 0.016, -225.0))
	var mat_col := Color(0.25, 0.2, 0.13)
	_loft([_rg(0.32, 0.5, 0.03, 0.0), _rg(0.32, 0.5, 0.03, 0.014), _rg(0.3, 0.48, 0.03, 0.018), _rg(0.0, 0.0, 0.0, 0.018)], mat_col, Transform3D.IDENTITY, 2)
	_flush(_vmat(0.98, 0.0, false, "wood_h"))
	var lamp := Vector3(-51.3, 0.0, -225.0)
	_base = _xf(lamp)
	_pipe(Vector3(0, 2.96, 0), Vector3(0, 2.6, 0), 0.006, IRON)
	_cy(0.1, 0.13, 0.05, Vector3(0, 2.57, 0), IRON, Vector3.ZERO, 8)
	for k in range(4):
		var a := TAU * float(k) / 4.0 + PI * 0.25
		_pipe(Vector3(cos(a) * 0.1, 2.55, sin(a) * 0.1), Vector3(cos(a) * 0.08, 2.32, sin(a) * 0.08), 0.005, IRON)
	_cy(0.09, 0.08, 0.02, Vector3(0, 2.31, 0), IRON, Vector3.ZERO, 8)
	_flush(_vmat(0.45, 0.4))
	_base = _xf(lamp)
	_cy(0.085, 0.075, 0.22, Vector3(0, 2.435, 0), Color(0.5, 0.5, 0.44), Vector3.ZERO, 8)
	_flush(_vmat(0.1))
