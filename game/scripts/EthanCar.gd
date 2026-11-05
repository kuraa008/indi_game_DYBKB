extends Node3D
class_name EthanCar

# ══════════════════════════════════════════════════════════════════════════════
#  EthanCar.gd — машина Итана: трёхдверный хэтчбек конца 70-х в духе первого
#  «Гольфа». Красный, заниженный, на широких полированных дисках, с круглыми
#  фарами в чёрной решётке, широкой задней стойкой и клетчатыми сиденьями.
#  Собрана кодом, без готовых моделей. Перед смотрит вдоль -Z, начало
#  координат — на земле посередине машины.
#  Салон настоящий: в виде от лица камера стоит в EYE (руль, приборы, ёлочка).
#  set_wrecked(true) — та же машина после удара левой частью морды о валун:
#  морда смята и сдвинута, капот вздут и приоткрыт, левая фара разбита,
#  бампер висит, лобовое в трещинах, левое переднее колесо вывернуто.
# ══════════════════════════════════════════════════════════════════════════════

const SIZE := Vector3(1.62, 1.35, 3.71)
const FRONT_Z := -1.855
const REAR_Z := 1.85
const NOSE_Z := -1.785            # плоскость решётки
const TAIL_Z := 1.80              # плоскость задней панели
const HALF_W := 0.805
const AXLE_F := -1.195
const AXLE_R := 1.205
const WHEEL_R := 0.29
const WHEEL_X := 0.712
const ARCH_R := 0.335
const SILL_Y := 0.19
const BELT_Y := 0.86
const COWL_Z := -0.55
const COWL_Y := 0.885
const ROOF_Y := 1.31
const ROOF_FZ := 0.02
const ROOF_RZ := 1.38
const HATCH_Z := 1.73
const HATCH_Y := 0.93
const GH_BELT_X := 0.785          # боковое стекло у подоконника
const GH_ROOF_X := 0.643          # боковое стекло у крыши (завал внутрь)
const WS_BASE_X := 0.72
const WS_TOP_X := 0.62
const HATCH_TOP_X := 0.62
const HATCH_LOW_X := 0.69
const HOOD_FRONT_Z := -1.79
const HOOD_HINGE_Z := -0.585
const HOOD_HALF_W := 0.752
const HEAD_L := Vector3(-0.58, 0.655, -1.80)
const HEAD_R := Vector3(0.58, 0.655, -1.80)
const EYE := Vector3(-0.36, 1.12, 0.22)            # глаза водителя
const BUCKLE := Vector3(-0.1, 0.62, 0.46)           # замок ремня между сиденьями
const GLOVEBOX := Vector3(0.4, 0.8, -0.21)
const STEAM_POINT := Vector3(-0.2, 0.86, -1.42)    # пар из-под смятого капота

@export var paint_color := Color(0.5, 0.045, 0.035)

var hood: Node3D
var speed_needle: Node3D
var wheel_spin: Node3D
var freshener: Node3D
var wrecked := false

var _mats := {}
var _cur := {}
var _body: MeshInstance3D
var _body_clean: ArrayMesh
var _body_wreck: ArrayMesh
var _hood_mi: MeshInstance3D
var _hood_clean: ArrayMesh
var _hood_wreck: ArrayMesh
var _crack: MeshInstance3D
var _wheel_roots: Array[Node3D] = []
var _steers: Array[Node3D] = []
var _spins: Array[Node3D] = []
var _spin := 0.0


func _init() -> void:
	name = "EthanCar"
	add_to_group("ethan_car")
	_make_materials()
	_cur = {}
	_build_body()
	_build_greenhouse()
	_build_front()
	_build_rear()
	_build_sides()
	var body_geo := _cur
	_cur = {}
	_build_hood_panel()
	var hood_geo := _cur
	_cur = {}
	_build_interior()
	var int_geo := _cur
	_cur = {}
	_build_wheel_geo()
	var wheel_geo := _cur
	_cur = {}

	_body_clean = _commit(body_geo, Callable())
	_body_wreck = _commit(body_geo, wreck_point)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = _body_clean
	add_child(_body)

	var interior := MeshInstance3D.new()
	interior.name = "Interior"
	interior.mesh = _commit(int_geo, Callable())
	add_child(interior)

	hood = Node3D.new()
	hood.name = "Hood"
	hood.position = Vector3(0.0, _top(HOOD_HINGE_Z) + 0.014, HOOD_HINGE_Z)
	add_child(hood)
	_hood_clean = _commit(hood_geo, Callable())
	_hood_wreck = _commit(hood_geo, _hood_dent)
	_hood_mi = MeshInstance3D.new()
	_hood_mi.mesh = _hood_clean
	hood.add_child(_hood_mi)

	_build_crack()
	_build_interior_moving()
	_build_wheels(_commit(wheel_geo, Callable()))


# ══════════════════════════════════════════════
#  Управление
# ══════════════════════════════════════════════
func set_wrecked(v: bool) -> void:
	wrecked = v
	_body.mesh = _body_wreck if v else _body_clean
	_hood_mi.mesh = _hood_wreck if v else _hood_clean
	hood.rotation = Vector3(deg_to_rad(9.0), 0.0, deg_to_rad(-3.0)) if v else Vector3.ZERO
	_crack.visible = v
	var hl: StandardMaterial3D = _mats["head_l"]
	hl.albedo_color = Color(0.08, 0.08, 0.08) if v else Color(0.9, 0.88, 0.8)
	if v:
		hl.emission_energy_multiplier = 0.0
	# Удар пришёлся в левое переднее колесо: оно ушло назад и вывернуто
	_wheel_roots[0].position = Vector3(-WHEEL_X + (0.05 if v else 0.0), WHEEL_R - (0.025 if v else 0.0), AXLE_F + (0.06 if v else 0.0))
	_steers[0].rotation = Vector3(0.0, deg_to_rad(17.0), deg_to_rad(-8.0)) if v else Vector3.ZERO


# Фары и задние огни; brake 0…1 — стоп-сигнал
func set_lights(on: bool, brake: float = 0.0) -> void:
	if not wrecked:
		_mats["head_l"].emission_energy_multiplier = 2.6 if on else 0.0
	_mats["head_r"].emission_energy_multiplier = 2.6 if on else 0.0
	_mats["tail"].emission_energy_multiplier = (0.9 if on else 0.0) + 2.6 * brake


# После удара уцелевшая правая фара мигает
func set_right_lamp(energy: float) -> void:
	_mats["head_r"].emission_energy_multiplier = energy


# Колёса крутятся по скорости, передние поворачивают вслед за рулём
func set_motion(delta: float, speed: float, steer_deg: float) -> void:
	_spin = fmod(_spin + speed * delta / WHEEL_R, TAU)
	for s in _spins:
		s.rotation.x = -_spin
	if not wrecked:
		_steers[0].rotation.y = deg_to_rad(steer_deg)
	_steers[1].rotation.y = deg_to_rad(steer_deg) if not wrecked else 0.0


# Точка кузова после удара: морда смята назад, левая сторона сильнее, бампер слева висит
static func wreck_point(p: Vector3) -> Vector3:
	if p.z > -0.95:
		return p
	var u := clampf((-0.95 - p.z) / 0.9, 0.0, 1.0)
	var s := clampf(0.5 - p.x / 1.6, 0.0, 1.0)
	var k := pow(u, 1.4)
	var q := p
	q.z += (0.1 + 0.28 * s) * k
	q.x += 0.06 * s * k
	q.y += sin(u * 7.0 + p.x * 5.0) * 0.022 * k + 0.03 * s * k * (1.0 if p.y > 0.6 else -0.4)
	if p.y < 0.53 and p.y > 0.2 and p.z < -1.74:
		q.y -= 0.075 * clampf(-p.x / 0.8, 0.0, 1.0)
	return q


# ══════════════════════════════════════════════
#  Материалы
# ══════════════════════════════════════════════
func _make_materials() -> void:
	var paint := _m("paint", paint_color, 0.34, 0.3)
	paint.clearcoat_enabled = true
	paint.clearcoat = 0.6
	paint.clearcoat_roughness = 0.15
	_m("paint2", paint_color.darkened(0.3), 0.5, 0.2)
	_m("trim", Color(0.028, 0.028, 0.03), 0.72)
	_m("trim2", Color(0.055, 0.055, 0.06), 0.6)
	_m("chrome", Color(0.82, 0.82, 0.84), 0.12, 1.0)
	_m("pin", Color(0.75, 0.05, 0.04), 0.5)
	_m("lens", Color(0.72, 0.72, 0.68), 0.12)
	_m("amber", Color(0.62, 0.3, 0.03), 0.3)
	_m("plate", Color(0.8, 0.8, 0.76), 0.6)
	_m("under", Color(0.03, 0.03, 0.032), 0.95)
	_m("engine", Color(0.06, 0.06, 0.065), 0.8)
	_m("rubber", Color(0.022, 0.022, 0.022), 0.92)
	_m("rim", Color(0.7, 0.7, 0.72), 0.2, 0.9)
	_m("disc", Color(0.25, 0.24, 0.23), 0.5, 0.7)
	_m("caliper", Color(0.6, 0.05, 0.04), 0.4)
	_m("int", Color(0.045, 0.045, 0.05), 0.85)
	_m("int2", Color(0.09, 0.09, 0.095), 0.8)
	_m("dash", Color(0.035, 0.035, 0.038), 0.75)
	_m("liner", Color(0.3, 0.29, 0.27), 0.95)
	_m("carpet", Color(0.03, 0.03, 0.03), 1.0)
	_m("seat_side", Color(0.03, 0.03, 0.032), 0.9)
	_m("knob", Color(0.85, 0.84, 0.8), 0.5)
	_m("mirror", Color(0.15, 0.17, 0.2), 0.05, 0.9)
	var seat := _m("seat", Color.WHITE, 0.95)
	seat.albedo_texture = LumberjackModel._plaid_tex(64, false)
	seat.uv1_scale = Vector3(3.0, 3.0, 1.0)
	var glass := _m("glass", Color(0.04, 0.06, 0.07, 0.42), 0.04)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 1.0
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for key in ["head_l", "head_r"]:
		var h := _m(key, Color(0.9, 0.88, 0.8), 0.1)
		h.emission_enabled = true
		h.emission = Color(1.0, 0.93, 0.78)
		h.emission_energy_multiplier = 0.0
	var tail := _m("tail", Color(0.32, 0.02, 0.02), 0.25)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.06, 0.04)
	tail.emission_energy_multiplier = 0.0
	_m("glow", Color(0.04, 0.14, 0.11), 1.0).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m("needle", Color(1.0, 0.45, 0.12), 1.0).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m("radio", Color(0.55, 0.22, 0.04), 1.0).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _m(key: String, col: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


# ══════════════════════════════════════════════
#  Сборка треугольников
# ══════════════════════════════════════════════
func _arr(mat: String) -> Dictionary:
	if not _cur.has(mat):
		_cur[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array()}
	return _cur[mat]


# Лицевая сторона в Godot — обход по часовой стрелке, если смотреть на неё
func _emit(g: Dictionary, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	g.v.append(a)
	g.v.append(b)
	g.v.append(c)
	g.n.append(na)
	g.n.append(nb)
	g.n.append(nc)
	g.uv.append(ua)
	g.uv.append(ub)
	g.uv.append(uc)


# Плоский выпуклый многоугольник; out — куда он смотрит лицом
func _face(mat: String, pts: Array, out: Vector3, uvs: Array = []) -> void:
	var n := Vector3.ZERO
	for i in range(1, pts.size() - 1):
		n += (pts[i] - pts[0]).cross(pts[i + 1] - pts[0])
	if n.length() < 1e-10:
		return
	n = n.normalized()
	var flip := n.dot(out) < 0.0
	if flip:
		n = -n
	var g := _arr(mat)
	for i in range(1, pts.size() - 1):
		var ib := i if flip else i + 1
		var ic := i + 1 if flip else i
		var ua: Vector2 = uvs[0] if uvs.size() > 0 else Vector2.ZERO
		var ub: Vector2 = uvs[ib] if uvs.size() > 0 else Vector2.ZERO
		var uc: Vector2 = uvs[ic] if uvs.size() > 0 else Vector2.ZERO
		_emit(g, pts[0], pts[ib], pts[ic], n, n, n, ua, ub, uc)


func _box(mat: String, size: Vector3, center: Vector3, basis: Basis = Basis()) -> void:
	var h := size * 0.5
	var ax := [basis.x, basis.y, basis.z]
	for k in 3:
		var a: Vector3 = ax[k]
		var b: Vector3 = ax[(k + 1) % 3]
		var c: Vector3 = ax[(k + 2) % 3]
		var ha: float = h[k]
		var hb: float = h[(k + 1) % 3]
		var hc: float = h[(k + 2) % 3]
		for s in [-1.0, 1.0]:
			var o: Vector3 = center + a * ha * s
			var pts := [o - b * hb - c * hc, o + b * hb - c * hc, o + b * hb + c * hc, o - b * hb + c * hc]
			var uvs := []
			for p in pts:
				uvs.append(Vector2((p as Vector3).dot(b), (p as Vector3).dot(c)) * 2.0)
			_face(mat, pts, a * s, uvs)


# Цилиндр вдоль basis.y
func _cyl(mat: String, r_top: float, r_bot: float, h: float, center: Vector3, basis: Basis = Basis(), sides: int = 16, caps: bool = true) -> void:
	var ax := basis.y
	var top := center + ax * h * 0.5
	var bot := center - ax * h * 0.5
	var ring_t := []
	var ring_b := []
	for i in sides:
		var a := TAU * float(i) / float(sides)
		var d := basis.x * cos(a) + basis.z * sin(a)
		ring_t.append(top + d * r_top)
		ring_b.append(bot + d * r_bot)
	for i in sides:
		var j := (i + 1) % sides
		var mid: Vector3 = (ring_t[i] + ring_t[j] + ring_b[i] + ring_b[j]) * 0.25
		_face(mat, [ring_b[i], ring_b[j], ring_t[j], ring_t[i]], mid - center - ax * ax.dot(mid - center))
	if caps:
		if r_top > 0.0005:
			_face(mat, ring_t, ax)
		if r_bot > 0.0005:
			_face(mat, ring_b, -ax)


# Сетка rows[i][j] с гладкими нормалями; outs — куда смотрит лицо: массив по рядам
# или функция точки (для тел вращения и сфер)
func _grid(mat: String, rows: Array, outs: Variant) -> void:
	var ni := rows.size()
	if ni < 2:
		return
	var nj: int = rows[0].size()
	var qn := []
	for i in ni - 1:
		var row := []
		for j in nj - 1:
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i + 1][j]
			var c: Vector3 = rows[i + 1][j + 1]
			var d: Vector3 = rows[i][j + 1]
			var n := (b - a).cross(d - a) + (c - b).cross(a - b) + (d - c).cross(b - c)
			var out: Vector3
			if outs is Callable:
				out = (outs as Callable).call((a + b + c + d) * 0.25)
			else:
				out = (outs[i] + outs[i + 1]) * 0.5
			if n.dot(out) < 0.0:
				n = -n
			row.append(n.normalized() if n.length() > 1e-10 else Vector3.ZERO)
		qn.append(row)
	var vn := []
	for i in ni:
		var row := []
		for j in nj:
			var s := Vector3.ZERO
			for di in [-1, 0]:
				for dj in [-1, 0]:
					var qi: int = i + di
					var qj: int = j + dj
					if qi >= 0 and qi < ni - 1 and qj >= 0 and qj < nj - 1:
						s += qn[qi][qj]
			row.append(s.normalized() if s.length() > 1e-10 else Vector3.UP)
		vn.append(row)
	var g := _arr(mat)
	for i in ni - 1:
		for j in nj - 1:
			var n: Vector3 = qn[i][j]
			if n == Vector3.ZERO:
				continue
			var a: Vector3 = rows[i][j]
			var b: Vector3 = rows[i + 1][j]
			var c: Vector3 = rows[i + 1][j + 1]
			var d: Vector3 = rows[i][j + 1]
			var raw := (b - a).cross(d - a)
			var na: Vector3 = vn[i][j]
			var nb: Vector3 = vn[i + 1][j]
			var nc: Vector3 = vn[i + 1][j + 1]
			var nd: Vector3 = vn[i][j + 1]
			var z2 := Vector2.ZERO
			if raw.dot(n) > 0.0:
				_emit(g, a, d, c, na, nd, nc, z2, z2, z2)
				_emit(g, a, c, b, na, nc, nb, z2, z2, z2)
			else:
				_emit(g, a, b, c, na, nb, nc, z2, z2, z2)
				_emit(g, a, c, d, na, nc, nd, z2, z2, z2)


# Тело вращения вокруг оси X: профиль — пары (радиус, смещение по оси).
# Лицо смотрит от центра сечения mid (смещение, радиус); inward — внутрь, к оси
func _lathe(mat: String, profile: Array, sides: int, mid: Vector2, inward: bool = false) -> void:
	var rows := []
	for i in sides + 1:
		var a := TAU * float(i) / float(sides)
		var row := []
		for p in profile:
			row.append(Vector3((p as Vector2).y, cos(a) * (p as Vector2).x, sin(a) * (p as Vector2).x))
		rows.append(row)
	var out := func(p: Vector3) -> Vector3:
		var radial := Vector3(0.0, p.y, p.z).normalized()
		if inward:
			return -radial
		return Vector3(p.x - mid.x, 0.0, 0.0) + radial * (Vector2(p.y, p.z).length() - mid.y)
	_grid(mat, rows, out)


# ══════════════════════════════════════════════
#  Кузов ниже окон: сечения вдоль машины
# ══════════════════════════════════════════════
func _w(z: float) -> float:
	var f := clampf((z - FRONT_Z) / 0.28, 0.0, 1.0)
	var r := clampf((REAR_Z - z) / 0.24, 0.0, 1.0)
	var w := HALF_W - 0.055 * (1.0 - f) * (1.0 - f) - 0.05 * (1.0 - r) * (1.0 - r)
	for a in [AXLE_F, AXLE_R]:
		var d := absf(z - a)
		if d < 0.52:
			w += 0.022 * (0.5 + 0.5 * cos(PI * d / 0.52))
	return w


func _top(z: float) -> float:
	if z < COWL_Z:
		return lerpf(0.80, COWL_Y, clampf((z - HOOD_FRONT_Z) / (COWL_Z - HOOD_FRONT_Z), 0.0, 1.0))
	if z < 1.45:
		return BELT_Y
	return lerpf(BELT_Y, HATCH_Y, smoothstep(1.45, HATCH_Z, z))


func _arch(z: float) -> float:
	for a in [AXLE_F, AXLE_R]:
		var d := absf(z - a)
		if d < ARCH_R:
			return WHEEL_R + sqrt(ARCH_R * ARCH_R - d * d)
	return 0.0


# Правая половина сечения: от середины крыши капота вниз по борту к середине днища
func _ring(z: float) -> Array:
	var w := _w(z)
	var top := _top(z)
	var pts := [
		Vector3(0.0, top + (0.012 if z < COWL_Z else 0.0), z),
		Vector3(w - 0.05, top, z),
		Vector3(w - 0.014, top - 0.01, z),
		Vector3(w, top - 0.04, z),
		Vector3(w + 0.006, 0.6, z),
		Vector3(w, 0.42, z),
		Vector3(w - 0.022, 0.26, z),
		Vector3(w - 0.06, SILL_Y, z),
		Vector3(w - 0.15, SILL_Y - 0.01, z),
		Vector3(0.0, SILL_Y - 0.01, z),
	]
	var ay := _arch(z)
	if ay > 0.0:
		# Вырез под колесо: всё, что ниже края арки, поднимается к нему и уходит внутрь
		var xs := [w + 0.006, w, w - 0.03, w - 0.26]
		for i in range(4, 8):
			if pts[i].y < ay:
				pts[i] = Vector3(xs[i - 4], ay, z)
		if pts[7].y >= ay - 0.001:
			pts[8] = Vector3(w - 0.34, 0.2, z)
	return pts


func _build_body() -> void:
	var zs: Array[float] = []
	var z := NOSE_Z
	while z < TAIL_Z - 0.01:
		zs.append(z)
		z += 0.035
	zs.append(TAIL_Z)
	var rings := []
	for zz in zs:
		rings.append(_ring(zz))
	for side in [1.0, -1.0]:
		var flip := Vector3(side, 1.0, 1.0)
		for j in 9:
			var run := []
			var outs := []
			var run_mat := ""
			for i in rings.size():
				var a: Vector3 = rings[i][j] * flip
				var b: Vector3 = rings[i][j + 1] * flip
				var mat := _band_mat(j, zs[i])
				var out := _band_out(a, b)
				if mat != run_mat and run.size() > 0:
					run.append([a, b])
					outs.append(out)
					if run_mat != "":
						_grid(run_mat, run, outs)
					run = []
					outs = []
				run_mat = mat
				run.append([a, b])
				outs.append(out)
			if run_mat != "" and run.size() > 1:
				_grid(run_mat, run, outs)
	_cap(rings[0], Vector3(0, 0, -1), "trim")
	_cap(rings[rings.size() - 1], Vector3(0, 0, 1), "paint")


func _band_mat(j: int, z: float) -> String:
	if j == 0:
		if z < COWL_Z:
			return "engine"
		if z < 1.45:
			return ""
		return "int" if z < HATCH_Z else "paint"
	if j >= 7:
		return "under"
	return "paint"


# Горизонтальные полосы внизу (арки, днище) смотрят вниз, наверху — вверх, остальные — от оси машины
func _band_out(a: Vector3, b: Vector3) -> Vector3:
	var m := (a + b) * 0.5
	if absf(a.y - b.y) < 0.002 and absf(a.x - b.x) > 0.005:
		return Vector3.DOWN if m.y < 0.7 else Vector3.UP
	return Vector3(m.x, m.y - 0.55, 0.0)


func _cap(ring: Array, out: Vector3, mat: String) -> void:
	var poly := []
	for p in ring:
		poly.append(p)
	for i in range(ring.size() - 2, 0, -1):
		poly.append((ring[i] as Vector3) * Vector3(-1.0, 1.0, 1.0))
	var c := Vector3.ZERO
	for p in poly:
		c += p
	c /= float(poly.size())
	for i in poly.size():
		_face(mat, [c, poly[i], poly[(i + 1) % poly.size()]], out)


# ══════════════════════════════════════════════
#  Стёкла, стойки и крыша
# ══════════════════════════════════════════════
func _gx(y: float) -> float:
	return lerpf(GH_BELT_X, GH_ROOF_X, clampf((y - BELT_Y) / (ROOF_Y - BELT_Y), 0.0, 1.0))


# Точка на плоскости бокового стекла (z, y); side = ±1
func _sp(z: float, y: float, side: float, off: float = 0.0) -> Vector3:
	return Vector3(side * (_gx(y) + off), y, z)


func _side_poly(mat: String, zy: Array, side: float, off: float = 0.0) -> void:
	var pts := []
	for p in zy:
		pts.append(_sp((p as Vector2).x, (p as Vector2).y, side, off))
	_face(mat, pts, Vector3(side, 0.3, 0.0))


func _build_greenhouse() -> void:
	for side in [1.0, -1.0]:
		# Стойка лобового: от края стекла до переднего края двери
		_face("paint", [Vector3(side * WS_BASE_X, COWL_Y, COWL_Z), _sp(-0.47, 0.885, side), _sp(0.05, 1.3, side), Vector3(side * WS_TOP_X, ROOF_Y, ROOF_FZ)], Vector3(side, 0.4, -0.6))
		_side_poly("glass", [Vector2(-0.47, 0.885), Vector2(0.47, 0.885), Vector2(0.47, 1.27), Vector2(0.012, 1.27)], side, -0.004)
		_side_poly("trim", [Vector2(0.47, 0.885), Vector2(0.555, 0.885), Vector2(0.555, 1.27), Vector2(0.47, 1.27)], side)
		_side_poly("glass", [Vector2(0.555, 0.885), Vector2(1.1, 0.885), Vector2(1.02, 1.27), Vector2(0.555, 1.27)], side, -0.004)
		_side_poly("paint", [Vector2(0.012, 1.27), Vector2(1.02, 1.27), Vector2(1.02, 1.305), Vector2(0.055, 1.305)], side)
		# Широкая задняя стойка — главная черта силуэта
		_side_poly("paint", [Vector2(1.1, 0.885), Vector2(HATCH_Z, HATCH_Y), Vector2(ROOF_RZ, 1.305), Vector2(1.02, 1.305), Vector2(1.02, 1.27)], side)
		_side_poly("trim", [Vector2(-0.55, 0.858), Vector2(1.1, 0.858), Vector2(1.1, 0.885), Vector2(-0.55, 0.885)], side, 0.004)
		# Стойка заворачивает за угол к стеклу двери багажника
		_face("paint", [_sp(HATCH_Z, HATCH_Y, side), _sp(ROOF_RZ, 1.305, side), Vector3(side * HATCH_TOP_X, 1.3, 1.39), Vector3(side * HATCH_LOW_X, HATCH_Y, HATCH_Z)], Vector3(side, 0.3, 0.7))
		# Водосток вдоль крыши
		_box("trim", Vector3(0.012, 0.012, ROOF_RZ - ROOF_FZ), Vector3(side * (GH_ROOF_X + 0.004), ROOF_Y + 0.004, (ROOF_FZ + ROOF_RZ) * 0.5))
	# Лобовое стекло (отдельно: после удара его покрывают трещины) и стекло двери багажника
	_face("glass", [Vector3(-WS_BASE_X, COWL_Y, COWL_Z), Vector3(WS_BASE_X, COWL_Y, COWL_Z), Vector3(WS_TOP_X, ROOF_Y, ROOF_FZ), Vector3(-WS_TOP_X, ROOF_Y, ROOF_FZ)], Vector3(0, 0.6, -1))
	_face("glass", [Vector3(-HATCH_LOW_X, HATCH_Y, HATCH_Z), Vector3(HATCH_LOW_X, HATCH_Y, HATCH_Z), Vector3(HATCH_TOP_X, 1.3, 1.39), Vector3(-HATCH_TOP_X, 1.3, 1.39)], Vector3(0, 0.7, 1))
	# Крыша с небольшим горбом; к лобовому и к двери багажника горб сходит на нет
	var rows := []
	var outs := []
	var nz := 12
	var nx := 10
	for i in nz + 1:
		var z := lerpf(ROOF_FZ, ROOF_RZ, float(i) / float(nz))
		var edge := smoothstep(0.0, 0.2, z - ROOF_FZ) * smoothstep(0.0, 0.2, ROOF_RZ - z)
		var row := []
		for j in nx + 1:
			var x := lerpf(-GH_ROOF_X, GH_ROOF_X, float(j) / float(nx))
			row.append(Vector3(x, ROOF_Y + 0.04 * (1.0 - pow(x / GH_ROOF_X, 2.0)) * edge, z))
		rows.append(row)
		outs.append(Vector3.UP)
	_grid("paint", rows, outs)
	# Козырёк-спойлер над стеклом багажника
	_box("trim", Vector3(1.24, 0.026, 0.14), Vector3(0.0, 1.336, 1.44), Basis(Vector3.RIGHT, 0.2))
	# Чёрная решётка у основания лобового и дворники на нём
	_face("trim", [Vector3(-0.74, 0.876, -0.64), Vector3(0.74, 0.876, -0.64), Vector3(WS_BASE_X, COWL_Y + 0.006, COWL_Z + 0.004), Vector3(-WS_BASE_X, COWL_Y + 0.006, COWL_Z + 0.004)], Vector3.UP)
	for x0 in [-0.32, 0.26]:
		_box("trim", Vector3(0.5, 0.012, 0.014), Vector3(x0, COWL_Y + 0.02, COWL_Z + 0.03), Basis(Vector3.UP, 0.08))
	_box("trim", Vector3(0.014, 0.012, 0.4), Vector3(0.0, (HATCH_Y + 1.3) * 0.5 + 0.012, (HATCH_Z + 1.39) * 0.5 + 0.01), Basis(Vector3.RIGHT, 0.82))


# ══════════════════════════════════════════════
#  Морда, корма, борта
# ══════════════════════════════════════════════
func _build_front() -> void:
	var fz := NOSE_Z
	for i in 5:
		_box("trim2", Vector3(0.86, 0.016, 0.02), Vector3(0.0, 0.585 + i * 0.045, fz - 0.012))
	_box("pin", Vector3(1.4, 0.009, 0.008), Vector3(0.0, 0.786, fz - 0.006))
	_box("pin", Vector3(1.4, 0.009, 0.008), Vector3(0.0, 0.546, fz - 0.006))
	var to_z := Basis(Vector3.RIGHT, PI * 0.5)
	for s in [-1.0, 1.0]:
		var hl := Vector3(0.58 * s, 0.655, fz)
		_cyl("chrome", 0.098, 0.098, 0.024, hl + Vector3(0, 0, -0.012), to_z, 22)
		_cyl("head_l" if s < 0.0 else "head_r", 0.086, 0.086, 0.01, hl + Vector3(0, 0, -0.027), to_z, 22)
		var fl := Vector3(0.36 * s, 0.655, fz)
		_cyl("chrome", 0.064, 0.064, 0.02, fl + Vector3(0, 0, -0.01), to_z, 16)
		_cyl("lens", 0.054, 0.054, 0.01, fl + Vector3(0, 0, -0.022), to_z, 16)
		_box("amber", Vector3(0.11, 0.045, 0.02), Vector3(0.6 * s, 0.445, -1.864))
		_box("trim", Vector3(0.1, 0.12, 0.05), Vector3(0.772 * s, 0.44, -1.8), Basis(Vector3.UP, -0.55 * s))
	_box("trim", Vector3(1.5, 0.12, 0.07), Vector3(0.0, 0.44, -1.83))
	_box("trim", Vector3(1.46, 0.055, 0.12), Vector3(0.0, 0.255, -1.775), Basis(Vector3.RIGHT, 0.12))
	_plate(Vector3(0.0, 0.44, -1.8665), PI)


func _build_rear() -> void:
	var rz := TAIL_Z
	for s in [-1.0, 1.0]:
		_box("trim", Vector3(0.36, 0.19, 0.012), Vector3(0.615 * s, 0.665, rz + 0.004))
		_box("tail", Vector3(0.21, 0.15, 0.014), Vector3(0.6 * s, 0.665, rz + 0.011))
		_box("amber", Vector3(0.065, 0.15, 0.014), Vector3(0.745 * s, 0.665, rz + 0.011))
		_box("lens", Vector3(0.05, 0.15, 0.014), Vector3(0.468 * s, 0.665, rz + 0.011))
		_box("trim", Vector3(0.1, 0.12, 0.05), Vector3(0.772 * s, 0.42, 1.8), Basis(Vector3.UP, 0.55 * s))
	_box("trim", Vector3(0.54, 0.15, 0.01), Vector3(0.0, 0.565, rz + 0.004))
	_plate(Vector3(0.0, 0.565, rz + 0.012), 0.0)
	_box("trim", Vector3(1.5, 0.12, 0.07), Vector3(0.0, 0.42, 1.83))
	_cyl("chrome", 0.034, 0.034, 0.14, Vector3(-0.42, 0.24, 1.84), Basis(Vector3.RIGHT, PI * 0.5), 12)
	_box("trim", Vector3(0.12, 0.03, 0.03), Vector3(0.0, 0.9, 1.79))


# Номер: светлая табличка и тёмные «знаки» без настоящего формата
func _plate(center: Vector3, yaw: float) -> void:
	var b := Basis(Vector3.UP, yaw)
	_box("plate", Vector3(0.46, 0.1, 0.008), center, b)
	var xs := [-0.17, -0.11, -0.03, 0.03, 0.09, 0.16]
	for i in xs.size():
		var w := 0.022 if i % 3 == 1 else 0.034
		_box("trim", Vector3(w, 0.058, 0.004), center + b * Vector3(xs[i], 0.0, 0.006), b)


func _build_sides() -> void:
	for s in [-1.0, 1.0]:
		# Зеркало на ножке
		_box("trim", Vector3(0.08, 0.03, 0.05), Vector3(s * 0.8, 0.905, -0.43))
		_box("trim", Vector3(0.15, 0.085, 0.075), Vector3(s * 0.875, 0.93, -0.43), Basis(Vector3.UP, 0.12 * s))
		_box("mirror", Vector3(0.13, 0.068, 0.004), Vector3(s * 0.875, 0.93, -0.391), Basis(Vector3.UP, 0.12 * s))
		# Ручка двери, зазоры двери, поворотник на крыле, молдинг
		_box("trim", Vector3(0.018, 0.028, 0.13), Vector3(s * (_w(0.42) + 0.009), 0.79, 0.42))
		for gz in [-0.535, 0.585]:
			_box("under", Vector3(0.006, 0.6, 0.005), Vector3(s * (_w(gz) + 0.008), 0.555, gz))
		_box("under", Vector3(0.006, 0.005, 1.12), Vector3(s * (_w(0.0) + 0.004), 0.255, 0.025))
		_box("amber", Vector3(0.008, 0.026, 0.055), Vector3(s * (_w(-1.45) + 0.004), 0.63, -1.45))
		_box("trim", Vector3(0.012, 0.03, 1.0), Vector3(s * (_w(0.02) + 0.008), 0.5, 0.02))
		for axle in [AXLE_F, AXLE_R]:
			_flare(axle, s)
	# Лючок бензобака справа сзади (заправка справа, со стороны колонки)
	_cyl("paint2", 0.05, 0.05, 0.006, Vector3(_w(1.36) + 0.004, 0.7, 1.36), Basis(Vector3.BACK, PI * 0.5), 16)
	# Антенна слева над лобовым
	_cyl("trim", 0.003, 0.004, 0.7, Vector3(-0.55, 1.5, 0.2), Basis(Vector3.RIGHT, 0.45), 6, false)


# Чёрные расширители арок: дуга вокруг колеса
func _flare(axle: float, s: float) -> void:
	var n := 16
	var r0 := ARCH_R - 0.004
	var r1 := ARCH_R + 0.045
	for k in n:
		var a0 := lerpf(-1.85, 1.85, float(k) / float(n))
		var a1 := lerpf(-1.85, 1.85, float(k + 1) / float(n))
		var z0i := axle + sin(a0) * r0
		var z1i := axle + sin(a1) * r0
		var z0o := axle + sin(a0) * r1
		var z1o := axle + sin(a1) * r1
		var xo0 := s * (_w(z0o) + 0.026)
		var xo1 := s * (_w(z1o) + 0.026)
		var xi0 := s * (_w(z0i) - 0.012)
		var xi1 := s * (_w(z1i) - 0.012)
		var p0i := Vector3(xo0, WHEEL_R + cos(a0) * r0, z0i)
		var p1i := Vector3(xo1, WHEEL_R + cos(a1) * r0, z1i)
		var p0o := Vector3(xo0, WHEEL_R + cos(a0) * r1, z0o)
		var p1o := Vector3(xo1, WHEEL_R + cos(a1) * r1, z1o)
		_face("trim", [p0i, p1i, p1o, p0o], Vector3(s, 0, 0))
		var radial := Vector3(0.0, cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5))
		_face("trim", [p0o, p1o, Vector3(xi1, p1o.y, p1o.z), Vector3(xi0, p0o.y, p0o.z)], radial)
		_face("trim", [p0i, p1i, Vector3(xi1, p1i.y, p1i.z), Vector3(xi0, p0i.y, p0i.z)], -radial)


# ══════════════════════════════════════════════
#  Капот: отдельная деталь, чтобы после удара вздуться и приоткрыться
# ══════════════════════════════════════════════
func _build_hood_panel() -> void:
	var hy := _top(HOOD_HINGE_Z) + 0.014
	var rows := []
	var outs := []
	var nz := 14
	var nx := 10
	for i in nz + 1:
		var z := lerpf(HOOD_FRONT_Z, HOOD_HINGE_Z, float(i) / float(nz))
		var row := []
		for j in nx + 1:
			var x := lerpf(-HOOD_HALF_W, HOOD_HALF_W, float(j) / float(nx))
			row.append(Vector3(x, _top(z) + 0.014 + 0.012 * (1.0 - pow(x / HOOD_HALF_W, 2.0)) - hy, z - HOOD_HINGE_Z))
		rows.append(row)
		outs.append(Vector3.UP)
	_grid("paint", rows, outs)
	# Кромки: передняя загибается вниз к решётке, боковые — к крыльям
	var first: Array = rows[0]
	for j in nx:
		var a: Vector3 = first[j]
		var b: Vector3 = first[j + 1]
		_face("paint", [a, b, b + Vector3(0, -0.035, 0.004), a + Vector3(0, -0.035, 0.004)], Vector3(0, 0, -1))
	for i in nz:
		for k in [0, nx]:
			var a: Vector3 = rows[i][k]
			var b: Vector3 = rows[i + 1][k]
			var sx := signf(a.x)
			_face("paint", [a, b, b + Vector3(0, -0.02, 0), a + Vector3(0, -0.02, 0)], Vector3(sx, 0, 0))
	# Изнанка: тёмная, видна, когда капот приоткрыт
	var under_rows := []
	for row in rows:
		var r2 := []
		for p in row:
			r2.append((p as Vector3) + Vector3(0, -0.018, 0))
		under_rows.append(r2)
	var downs := []
	for i in under_rows.size():
		downs.append(Vector3.DOWN)
	_grid("engine", under_rows, downs)


# Капот после удара: смят вместе с мордой и вздут посередине
func _hood_dent(p: Vector3) -> Vector3:
	var base := Vector3(0.0, _top(HOOD_HINGE_Z) + 0.014, HOOD_HINGE_Z)
	var w := wreck_point(p + base) - base
	var u := clampf(-p.z / (HOOD_HINGE_Z - HOOD_FRONT_Z), 0.0, 1.0)
	w.y += 0.075 * sin(PI * u) * (1.0 - 0.5 * absf(p.x) / HOOD_HALF_W)
	return w


# Трещины на лобовом стекле: лучи от места удара головой и кольца
func _build_crack() -> void:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3104
	var c := Vector2(size * 0.68, size * 0.62)
	for i in 15:
		var a := TAU * float(i) / 15.0 + rng.randf_range(-0.2, 0.2)
		var p := c
		var len := rng.randf_range(60.0, 170.0)
		var t := 0.0
		while t < len:
			a += rng.randf_range(-0.25, 0.25)
			var q := p + Vector2(cos(a), sin(a)) * 6.0
			_line(img, p, q, Color(0.92, 0.95, 1.0, 0.75 * (1.0 - t / len) + 0.15))
			p = q
			t += 6.0
	for rr in [14.0, 30.0]:
		for k in 48:
			var a0 := TAU * float(k) / 48.0
			var a1 := TAU * float(k + 1) / 48.0
			if rng.randf() < 0.75:
				_line(img, c + Vector2(cos(a0), sin(a0)) * rr, c + Vector2(cos(a1), sin(a1)) * (rr + rng.randf_range(-2.0, 2.0)), Color(0.92, 0.95, 1.0, 0.7))
	img.generate_mipmaps()
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var a := Vector3(-WS_BASE_X, COWL_Y, COWL_Z)
	var b := Vector3(WS_BASE_X, COWL_Y, COWL_Z)
	var cc := Vector3(WS_TOP_X, ROOF_Y, ROOF_FZ)
	var d := Vector3(-WS_TOP_X, ROOF_Y, ROOF_FZ)
	var n := (b - a).cross(d - a).normalized()
	if n.dot(Vector3(0, 0.6, -1)) < 0.0:
		n = -n
	var off := n * 0.003
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for tri in [[a, b, cc, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)], [a, cc, d, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0)]]:
		for k in 3:
			st.set_normal(n)
			st.set_uv(tri[3 + k])
			st.add_vertex(tri[k] + off)
	_crack = MeshInstance3D.new()
	_crack.name = "WindshieldCracks"
	_crack.mesh = st.commit()
	_crack.visible = false
	add_child(_crack)


func _line(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n))
		var x := int(p.x)
		var y := int(p.y)
		if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
			img.set_pixel(x, y, col)


# ══════════════════════════════════════════════
#  Салон
# ══════════════════════════════════════════════
func _build_interior() -> void:
	_box("carpet", Vector3(1.44, 0.03, 2.05), Vector3(0.0, 0.235, 0.42))
	_box("int", Vector3(1.44, 0.6, 0.03), Vector3(0.0, 0.52, -0.62))
	for s in [-1.0, 1.0]:
		_box("int", Vector3(0.025, 0.6, 1.12), Vector3(s * 0.73, 0.56, 0.02))
		_box("int2", Vector3(0.06, 0.04, 0.36), Vector3(s * 0.705, 0.66, 0.16))
		_box("int", Vector3(0.025, 0.22, 0.85), Vector3(s * 0.72, 0.76, 1.0))
		# Сиденья: подушка, спинка с боковой поддержкой, подголовник
		var x: float = 0.36 * s
		var lean := Basis(Vector3.RIGHT, 0.22)
		_box("seat", Vector3(0.44, 0.13, 0.5), Vector3(x, 0.43, 0.42))
		_box("seat_side", Vector3(0.06, 0.16, 0.5), Vector3(x - 0.23, 0.45, 0.42))
		_box("seat_side", Vector3(0.06, 0.16, 0.5), Vector3(x + 0.23, 0.45, 0.42))
		_box("seat", Vector3(0.4, 0.6, 0.12), Vector3(x, 0.79, 0.7), lean)
		_box("seat_side", Vector3(0.07, 0.55, 0.16), Vector3(x - 0.225, 0.78, 0.71), lean)
		_box("seat_side", Vector3(0.07, 0.55, 0.16), Vector3(x + 0.225, 0.78, 0.71), lean)
		_box("seat_side", Vector3(0.26, 0.17, 0.09), Vector3(x, 1.16, 0.8), lean)
		# Обшивка стоек лобового, козырьки
		_beam("int2", Vector3(s * 0.705, 0.885, -0.53), Vector3(s * 0.615, 1.29, 0.0), 0.05)
		_box("liner", Vector3(0.32, 0.015, 0.16), Vector3(s * 0.33, 1.272, 0.08), Basis(Vector3.RIGHT, 0.2))
		_beam("int2", Vector3(s * 0.73, 0.88, 0.51), Vector3(s * 0.635, 1.29, 0.51), 0.07)
		_beam("int2", Vector3(s * 0.74, 0.9, 1.25), Vector3(s * 0.635, 1.29, 1.2), 0.3)
	# Задний диван
	_box("seat", Vector3(1.18, 0.12, 0.46), Vector3(0.0, 0.4, 1.18))
	_box("seat", Vector3(1.18, 0.48, 0.11), Vector3(0.0, 0.68, 1.45), Basis(Vector3.RIGHT, 0.3))
	# Торпедо, щиток приборов, бардачок, тоннель с рычагом, магнитола
	# (передний край торпедо стоит за наклонным лобовым стеклом)
	_box("dash", Vector3(1.46, 0.17, 0.3), Vector3(0.0, 0.815, -0.36))
	_box("dash", Vector3(1.46, 0.03, 0.29), Vector3(0.0, 0.905, -0.345))
	_box("dash", Vector3(0.5, 0.11, 0.15), Vector3(-0.36, 0.945, -0.27))
	_box("int2", Vector3(0.36, 0.11, 0.01), GLOVEBOX + Vector3(0.0, 0.0, 0.006))
	_box("trim2", Vector3(0.06, 0.012, 0.01), GLOVEBOX + Vector3(0.0, 0.035, 0.012))
	_box("dash", Vector3(0.22, 0.3, 0.42), Vector3(0.0, 0.45, -0.22))
	_box("trim", Vector3(0.18, 0.05, 0.012), Vector3(0.0, 0.7, -0.204))
	_box("radio", Vector3(0.06, 0.012, 0.004), Vector3(0.03, 0.705, -0.196))
	_cyl("int2", 0.008, 0.01, 0.2, Vector3(0.0, 0.55, 0.06), Basis(Vector3.RIGHT, -0.25), 8, false)
	_sphere("knob", 0.024, Vector3(0.0, 0.65, 0.035))
	_beam("dash", Vector3(-0.36, 0.86, -0.32), Vector3(-0.36, 0.9, -0.08), 0.05)
	# Потолок и зеркало
	_face("liner", [Vector3(-0.63, 1.296, 0.0), Vector3(0.63, 1.296, 0.0), Vector3(0.63, 1.296, 1.37), Vector3(-0.63, 1.296, 1.37)], Vector3.DOWN)
	_beam("dash", Vector3(0.0, 1.29, 0.0), Vector3(0.0, 1.245, -0.01), 0.015)
	_box("dash", Vector3(0.22, 0.055, 0.02), Vector3(0.0, 1.232, -0.012))
	_box("mirror", Vector3(0.2, 0.045, 0.004), Vector3(0.0, 1.232, -0.001))


func _beam(mat: String, a: Vector3, b: Vector3, t: float) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.RIGHT)
	_box(mat, Vector3(t, t, d.length()), (a + b) * 0.5, basis)


func _sphere(mat: String, r: float, c: Vector3) -> void:
	var rows := []
	for i in 9:
		var th := PI * float(i) / 8.0
		var row := []
		for j in 13:
			var ph := TAU * float(j) / 12.0
			row.append(c + Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * r)
		rows.append(row)
	_grid(mat, rows, func(p: Vector3) -> Vector3: return p - c)


# Подвижное внутри: руль, стрелки приборов, ёлочка под зеркалом
func _build_interior_moving() -> void:
	var glow: StandardMaterial3D = _mats["glow"]
	var needle_mat: StandardMaterial3D = _mats["needle"]
	for i in 2:
		var dial := Node3D.new()
		dial.position = Vector3(-0.47 + 0.22 * i, 0.945, -0.193)
		dial.rotation_degrees.x = 78.0
		add_child(dial)
		var face := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.052
		cm.bottom_radius = 0.052
		cm.height = 0.004
		cm.material = glow
		face.mesh = cm
		dial.add_child(face)
		var needle := Node3D.new()
		dial.add_child(needle)
		var nm := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.004, 0.003, 0.042)
		bm.material = needle_mat
		nm.mesh = bm
		nm.position = Vector3(0.0, 0.004, -0.019)
		needle.add_child(nm)
		if i == 0:
			speed_needle = needle
		else:
			needle.rotation.y = deg_to_rad(10.0)
	var cluster := OmniLight3D.new()
	cluster.light_color = Color(0.3, 0.85, 0.7)
	cluster.light_energy = 0.05
	cluster.omni_range = 0.4
	cluster.light_specular = 0.0     # иначе в лобовом стекле висит яркая зелёная точка-блик
	cluster.position = Vector3(-0.36, 0.95, -0.14)
	add_child(cluster)

	# Спортивный трёхспицевый руль
	var pivot := Node3D.new()
	pivot.position = Vector3(-0.36, 0.905, -0.06)
	pivot.rotation_degrees.x = 62.0
	add_child(pivot)
	wheel_spin = Node3D.new()
	pivot.add_child(wheel_spin)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.155
	tm.outer_radius = 0.185
	tm.rings = 28
	tm.ring_segments = 8
	tm.material = _mats["dash"]
	rim.mesh = tm
	wheel_spin.add_child(rim)
	for a in [PI * 0.5, PI * 7.0 / 6.0, PI * 11.0 / 6.0]:
		var sp := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.17, 0.014, 0.03)
		sb.material = _mats["trim2"]
		sp.mesh = sb
		sp.position = Vector3(cos(a) * 0.085, 0.0, sin(a) * 0.085)
		sp.rotation.y = -a
		wheel_spin.add_child(sp)
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.045
	hm.bottom_radius = 0.05
	hm.height = 0.03
	hm.material = _mats["trim"]
	hub.mesh = hm
	wheel_spin.add_child(hub)

	freshener = Node3D.new()
	freshener.position = Vector3(0.03, 1.21, -0.005)
	add_child(freshener)
	var string := MeshInstance3D.new()
	var stm := BoxMesh.new()
	stm.size = Vector3(0.003, 0.1, 0.003)
	stm.material = _mats["liner"]
	string.mesh = stm
	string.position = Vector3(0.0, -0.05, 0.0)
	freshener.add_child(string)
	var tree := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.032
	cone.height = 0.085
	cone.radial_segments = 3
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.12, 0.45, 0.16)
	green.roughness = 0.8
	cone.material = green
	tree.mesh = cone
	tree.position = Vector3(0.0, -0.14, 0.0)
	tree.scale = Vector3(1.0, 1.0, 0.15)
	freshener.add_child(tree)


# ══════════════════════════════════════════════
#  Колёса: широкая шина, глубокий полированный диск, тормоз с красной скобой
# ══════════════════════════════════════════════
func _build_wheel_geo() -> void:
	_lathe("rubber", [Vector2(0.198, 0.098), Vector2(0.226, 0.104), Vector2(0.258, 0.103), Vector2(0.279, 0.094), Vector2(0.288, 0.075), Vector2(0.29, 0.04),
		Vector2(0.29, -0.04), Vector2(0.288, -0.075), Vector2(0.279, -0.094), Vector2(0.258, -0.103), Vector2(0.226, -0.104), Vector2(0.198, -0.098)], 30, Vector2(0.0, 0.244))
	# Обод: внешняя полка и глубокая «тарелка»
	_lathe("rim", [Vector2(0.2, 0.097), Vector2(0.2, 0.104), Vector2(0.188, 0.107), Vector2(0.184, 0.098)], 30, Vector2(0.095, 0.19))
	_lathe("rim", [Vector2(0.184, 0.098), Vector2(0.184, 0.036)], 30, Vector2.ZERO, true)
	var ring := []
	for k in 31:
		var a := TAU * float(k) / 30.0
		ring.append(a)
	for k in 30:
		var a0: float = ring[k]
		var a1: float = ring[k + 1]
		var p := func(r: float, a: float) -> Vector3: return Vector3(0.036, cos(a) * r, sin(a) * r)
		_face("rim", [p.call(0.166, a0), p.call(0.184, a0), p.call(0.184, a1), p.call(0.166, a1)], Vector3.RIGHT)
	# Десять спиц, ступица, гайки
	for k in 10:
		var a := TAU * float(k) / 10.0
		var b := Basis(Vector3.RIGHT, a)
		_box("rim", Vector3(0.016, 0.125, 0.024), b * Vector3(0.03, 0.105, 0.0), b)
	_cyl("rim", 0.05, 0.05, 0.03, Vector3(0.04, 0.0, 0.0), Basis(Vector3.BACK, PI * 0.5), 16)
	_cyl("trim", 0.018, 0.018, 0.004, Vector3(0.056, 0.0, 0.0), Basis(Vector3.BACK, PI * 0.5), 12)
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.3
		_cyl("chrome", 0.009, 0.009, 0.012, Vector3(0.058, cos(a) * 0.032, sin(a) * 0.032), Basis(Vector3.BACK, PI * 0.5), 6)
	_cyl("disc", 0.135, 0.135, 0.022, Vector3(-0.04, 0.0, 0.0), Basis(Vector3.BACK, PI * 0.5), 24)
	_cyl("under", 0.184, 0.184, 0.01, Vector3(-0.07, 0.0, 0.0), Basis(Vector3.BACK, PI * 0.5), 24)


func _build_wheels(mesh: ArrayMesh) -> void:
	var spots := [Vector3(-WHEEL_X, WHEEL_R, AXLE_F), Vector3(WHEEL_X, WHEEL_R, AXLE_F), Vector3(-WHEEL_X, WHEEL_R, AXLE_R), Vector3(WHEEL_X, WHEEL_R, AXLE_R)]
	var caliper := BoxMesh.new()
	caliper.size = Vector3(0.045, 0.09, 0.06)
	caliper.material = _mats["caliper"]
	for i in 4:
		var s := signf(spots[i].x)
		var root := Node3D.new()
		root.name = ["WheelFL", "WheelFR", "WheelRL", "WheelRR"][i]
		root.position = spots[i]
		add_child(root)
		var steer := Node3D.new()
		root.add_child(steer)
		var spin := Node3D.new()
		steer.add_child(spin)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		if s < 0.0:
			mi.rotation.y = PI
		spin.add_child(mi)
		var cal := MeshInstance3D.new()
		cal.mesh = caliper
		cal.position = Vector3(-0.035 * s, 0.1, 0.07)
		steer.add_child(cal)
		_wheel_roots.append(root)
		_steers.append(steer)
		_spins.append(spin)


# ══════════════════════════════════════════════
#  Сетка: массивы → ArrayMesh; для разбитой машины точки сдвигаются деформацией
# ══════════════════════════════════════════════
func _commit(geo: Dictionary, deform: Callable) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in geo:
		var g: Dictionary = geo[key]
		if g.v.size() == 0:
			continue
		var v: PackedVector3Array = g.v
		var n: PackedVector3Array = g.n
		if deform.is_valid():
			v = PackedVector3Array()
			n = PackedVector3Array(g.n)
			v.resize(g.v.size())
			for i in g.v.size():
				v[i] = deform.call(g.v[i])
			# Там, где металл смят, нормали считаются заново — видны вмятины
			for t in range(0, v.size(), 3):
				var moved := false
				for k in 3:
					if (v[t + k] - g.v[t + k]).length_squared() > 1e-6:
						moved = true
				if moved:
					var fn := (v[t + 2] - v[t]).cross(v[t + 1] - v[t])
					if fn.length_squared() > 1e-14:
						fn = fn.normalized()
						for k in 3:
							n[t + k] = fn
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TEX_UV] = g.uv
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[key])
	return mesh
