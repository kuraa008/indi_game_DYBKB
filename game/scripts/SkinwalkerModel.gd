extends Node3D
class_name SkinwalkerModel

# Процедурная 3D-модель скинвокера: цельная сетка на скелете + анимация из кода.
# Геометрия строится один раз и кэшируется, все экземпляры используют один ArrayMesh.
# Лицо модели смотрит вдоль локальной +Z.

const MODEL_SCALE: float = 1.0   # Высота ~2.6 м: в двери и под низкие потолки пригибается
const FULL_HEIGHT: float = 2.63 * MODEL_SCALE
const THIGH: float = 0.56
const SHIN: float = 0.56

const GAITS := {
	"idle":   {"amp": 0.0,  "hunch": 0.14, "lean": 0.0,  "swing": 0.0,  "out": 0.08, "raise": 0.0,  "jaw": 0.05, "curl": 0.5,  "knee": 0.1,  "limp": 0.0},
	"walk":   {"amp": 0.46, "hunch": 0.2,  "lean": 0.03, "swing": 0.42, "out": 0.08, "raise": 0.0,  "jaw": 0.07, "curl": 0.55, "knee": 0.13, "limp": 0.1},
	"stalk":  {"amp": 0.34, "hunch": 0.72, "lean": 0.06, "swing": 0.14, "out": 0.3,  "raise": 0.42, "jaw": 0.26, "curl": 0.75, "knee": 0.62, "limp": 0.22},
	"run":    {"amp": 0.95, "hunch": 0.5,  "lean": 0.3,  "swing": 0.95, "out": 0.2,  "raise": 0.1,  "jaw": 0.6,  "curl": 0.25, "knee": 0.3,  "limp": 0.0},
	"twitch": {"amp": 0.0,  "hunch": 0.38, "lean": 0.04, "swing": 0.0,  "out": 0.2,  "raise": 0.15, "jaw": 0.25, "curl": 0.7,  "knee": 0.2,  "limp": 0.0},
}

static var _mesh: ArrayMesh = null
static var _bone_defs: Array = []   # {name, parent, rest}

var rig: Node3D
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var halos: Array[MeshInstance3D] = []

var _b := {}                  # имя кости -> индекс
var _rest_q: Array[Quaternion] = []
var _p := {}                  # сглаженные параметры походки
var _t := 0.0
var phase := 0.0
var _rate := 0.0
var _arm_s := [0.0, 0.0]      # пружины рук: плечо
var _arm_sv := [0.0, 0.0]
var _arm_e := [0.0, 0.0]      # пружины рук: локоть
var _arm_ev := [0.0, 0.0]
var _snap := 0.0
var _snap_hold := 0.0
var _next_snap := 4.0
var _glitch := 0.0
var _next_glitch := 5.0
var _gseed := [0.0, 0.0, 0.0, 0.0, 0.0]
var _look_yaw := 0.0
var _gait := "idle"
var _hands_on := true
var _stoop := 0.0
var _stoop_target := 0.0


func _init() -> void:
	if _mesh == null:
		_build_mesh()
	rig = Node3D.new()
	rig.name = "Rig"
	rig.scale = Vector3.ONE * MODEL_SCALE
	add_child(rig)

	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	rig.add_child(skeleton)
	for d in _bone_defs:
		var i := skeleton.add_bone(d.name)
		_b[d.name] = i
		if d.parent >= 0:
			skeleton.set_bone_parent(i, d.parent)
		skeleton.set_bone_rest(i, d.rest)
		_rest_q.append(d.rest.basis.get_rotation_quaternion())
	skeleton.reset_bone_poses()

	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Body"
	mesh_instance.mesh = _mesh
	mesh_instance.extra_cull_margin = 1.5
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")

	var head_att := BoneAttachment3D.new()
	head_att.bone_name = "head"
	skeleton.add_child(head_att)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	grad.add_point(0.25, Color(1, 1, 1, 0.35))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	halo_mat.albedo_texture = gtex
	halo_mat.albedo_color = Color(1.0, 0.16, 0.08, 0.7)
	var halo_quad := QuadMesh.new()
	halo_quad.size = Vector2(0.05, 0.05)
	halo_quad.material = halo_mat
	for s in [-1.0, 1.0]:
		var h := MeshInstance3D.new()
		h.mesh = halo_quad
		h.position = Vector3(0.046 * s, 0.165, 0.098)
		h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		head_att.add_child(h)
		halos.append(h)

	_p = GAITS["idle"].duplicate()
	_p["rage"] = 0.0
	_apply_pose(_idle_pose())


# ══════════════════════════════════════════════
#  Публичное API
# ══════════════════════════════════════════════
func update_motion(delta: float, gait: String, move_speed: float, rage: float = 0.0) -> void:
	_gait = gait if GAITS.has(gait) else "idle"
	_t += delta
	_stoop = lerpf(_stoop, _stoop_target, minf(1.0, delta * 7.0))
	var tg: Dictionary = GAITS[_gait]
	var k := minf(1.0, delta * 3.2)
	for key in tg:
		_p[key] = lerpf(_p[key], tg[key], k)
	_p["rage"] = lerpf(_p["rage"], rage, k)
	# Скорость шага считаем от реальной скорости, чтобы ступни не скользили по полу
	var target_rate := 0.0
	if move_speed > 0.2:
		target_rate = minf(move_speed / (maxf(float(_p["amp"]), 0.2) * 0.9 * MODEL_SCALE), 9.5)
	_rate = lerpf(_rate, target_rate, minf(1.0, delta * 8.0))
	phase += delta * _rate
	_tick_events(delta)
	_apply_pose(_loco_pose(delta))


func set_look_target(world_point: Variant) -> void:
	var yaw := 0.0
	if world_point is Vector3:
		var local: Vector3 = global_transform.affine_inverse() * (world_point as Vector3)
		if local.z > 0.0:
			yaw = clampf(atan2(local.x, local.z), -1.05, 1.05)
	_look_yaw = lerp_angle(_look_yaw, yaw, 0.12)


# Высота свободного места над полом: если монстр не помещается, он пригибается
func set_clearance(height: float) -> void:
	_stoop_target = clampf((FULL_HEIGHT + 0.08 - height) / 0.55, 0.0, 1.0)


func get_top_height() -> float:
	var pose := skeleton.get_bone_global_pose(_b["head"])
	return (skeleton.global_transform * (pose * Vector3(0, 0.346, -0.024))).y - global_position.y


func set_hands_animated(on: bool) -> void:
	_hands_on = on


func get_head_position() -> Vector3:
	var pose := skeleton.get_bone_global_pose(_b["head"])
	return skeleton.global_transform * (pose * Vector3(0, 0.165, 0.12))


func get_face_center() -> Vector3:
	var pose := skeleton.get_bone_global_pose(_b["neckC"])
	return skeleton.global_transform * (pose * Vector3(0, 0.075, 0.03))


# Поза скримера: u — секунды от начала, close — вывихнутая челюсть и глаза нараспашку
func apply_scare_pose(u: float) -> float:
	_t += get_process_delta_time()
	var q := int(u * 20.0)
	var n := func(k: int) -> float:
		var v := sin(q * 12.9898 + k * 78.233) * 43758.5453
		return (v - floor(v)) * 2.0 - 1.0
	var j: float = n.call(1)
	var pz := _idle_pose()
	pz.pitch = 0.2
	pz.neck = -0.16
	pz.hx = -0.1 + float(n.call(2)) * 0.09
	pz.hy = float(n.call(3)) * 0.24
	pz.hz = float(n.call(4)) * 0.3
	pz.jaw = 1.7 + float(n.call(5)) * 0.14
	pz.lsx = -0.2
	pz.rsx = -0.25
	pz.lsz = 1.05
	pz.rsz = 1.05
	pz.lex = -2.7
	pz.rex = -2.75
	pz.lw = -0.1
	pz.rw = -0.15
	pz.curl_l = 0.08 + float(n.call(6)) * 0.1
	pz.curl_r = 0.08 + float(n.call(7)) * 0.1
	_apply_pose(pz)
	# Вывих челюсти, расширение глаз и глотки
	skeleton.set_bone_pose_position(_b["jaw"], Vector3(0, 0.022 - 0.062, -0.03 + 0.032))
	skeleton.set_bone_pose_rotation(_b["jaw"], Quaternion(Basis.from_euler(Vector3(float(pz.jaw) * 0.62, 0.0, j * 0.13), EULER_ORDER_XYZ)))
	skeleton.set_bone_pose_scale(_b["throat"], Vector3(1.42, 1.75, 1.28))
	skeleton.set_bone_pose_position(_b["throat"], Vector3(0, -0.06, -0.004))
	var hs := 1.0 + 0.07 * absf(j)
	skeleton.set_bone_pose_scale(_b["head"], Vector3(hs * 0.97, hs * 1.05, hs))
	for e in ["eyeL", "eyeR"]:
		skeleton.set_bone_pose_scale(_b[e], Vector3(1.47 + 0.24 * j, 2.26, 1.25))
	for h in halos:
		h.scale = Vector3.ONE * 0.7
	return j


# ══════════════════════════════════════════════
#  Анимация
# ══════════════════════════════════════════════
func _tick_events(delta: float) -> void:
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_glitch = randf_range(0.1, 0.22)
		_next_glitch = randf_range(0.5, 1.3) if _gait == "twitch" else randf_range(5.0, 11.0)
		for i in 5:
			_gseed[i] = randf_range(-1.0, 1.0)
	if _glitch > 0.0:
		_glitch -= delta
	# Резкий рывок головы набок
	_next_snap -= delta
	if _next_snap <= 0.0:
		_snap = (-1.0 if randf() < 0.5 else 1.0) * randf_range(0.55, 1.05)
		_snap_hold = randf_range(0.3, 1.1)
		_next_snap = randf_range(4.0, 9.0)
	if _snap_hold > 0.0:
		_snap_hold -= delta
	else:
		_snap = lerpf(_snap, 0.0, minf(1.0, delta * 1.1))


func _idle_pose() -> Dictionary:
	return {
		"sway_x": 0.0, "hip_yaw": 0.0, "hip_roll": 0.0,
		"pitch": 0.14, "twist": 0.0, "roll": 0.0, "neck": 0.0,
		"hx": 0.0, "hy": 0.0, "hz": 0.0, "jaw": 0.05,
		"lsx": 0.04, "lsz": 0.08, "lex": -0.2, "rsx": 0.04, "rsz": 0.08, "rex": -0.2,
		"lw": -0.1, "rw": -0.1, "curl_l": 0.5, "curl_r": 0.5,
		"lth": -0.04, "rth": -0.04, "lkn": 0.1, "rkn": 0.1, "l_lift": 0.0, "r_lift": 0.0,
		"finger_tw": 0.0, "glitch": false,
	}


func _loco_pose(delta: float) -> Dictionary:
	var pz := _idle_pose()
	var amp: float = _p["amp"]
	var limp: float = _p["limp"]
	var knee: float = float(_p["knee"]) + _stoop * 1.3
	var lean: float = _p["lean"]
	var hunch: float = float(_p["hunch"]) + _stoop * 1.25
	var k := minf(1.0, _rate / 2.6)
	var s := sin(phase)
	var c := cos(phase)
	var br := sin(_t * 1.45)

	pz.lth = -s * amp * (1.0 - limp * 0.5) - lean * 0.5 - knee * 0.45
	pz.rth = s * amp * (1.0 + limp * 0.3) - lean * 0.5 - knee * 0.45
	pz.lkn = knee + amp * 1.35 * pow(maxf(0.0, c), 1.3)
	pz.rkn = knee + amp * 1.35 * pow(maxf(0.0, -c), 1.3)
	pz.l_lift = maxf(0.0, c) * amp * 0.25
	pz.r_lift = maxf(0.0, -c) * amp * 0.25
	pz.pitch = hunch + lean + br * 0.012 + limp * absf(s) * 0.04
	pz.twist = -s * 0.2 * k
	pz.roll = s * 0.045 * k + sin(_t * 0.37) * 0.012
	pz.neck = -(hunch + lean) * 0.85 + 0.08
	pz.hx = (0.12 if _gait == "stalk" else 0.02) - lean * 0.1
	pz.hy = sin(_t * 0.45) * 0.2 + _snap + _look_yaw - float(pz.twist) * 0.75
	pz.hz = sin(_t * 0.7) * 0.07 + 0.06 + _snap * 0.28
	pz.jaw = _p["jaw"]
	pz.curl_l = _p["curl"]
	pz.curl_r = float(_p["curl"]) + 0.08
	pz.lsz = float(_p["out"]) + 0.02
	pz.rsz = float(_p["out"]) + 0.03
	pz.sway_x = s * 0.03 * k
	pz.hip_yaw = s * 0.15 * k
	pz.hip_roll = -s * 0.05 * k

	# Руки болтаются по инерции: у каждой пружина с запаздыванием
	var swing: float = _p["swing"]
	var raise: float = _p["raise"]
	var stf := 80.0 if _gait == "run" else 42.0
	var dmp := 11.0 if _gait == "run" else 6.5
	var dt := minf(delta, 0.05)
	for i in 2:
		var ps := s if i == 0 else -s
		var t_sh := ps * swing * 0.68 - raise * 0.95 + 0.04 + sin(_t * 1.3 + i) * 0.018
		var t_el := -(0.18 + swing * 0.6 * (0.5 + 0.5 * ps) + raise * 0.75)
		_arm_sv[i] += (t_sh - _arm_s[i]) * stf * dt - _arm_sv[i] * dmp * dt
		_arm_s[i] += _arm_sv[i] * dt
		_arm_ev[i] += (t_el - _arm_e[i]) * stf * 0.8 * dt - _arm_ev[i] * dmp * dt
		_arm_e[i] += _arm_ev[i] * dt
	pz.lsx = _arm_s[0]
	pz.rsx = _arm_s[1]
	pz.lex = _arm_e[0]
	pz.rex = _arm_e[1]
	if _gait == "twitch":
		pz.finger_tw = 0.22 * maxf(0.0, sin(_t * 8.5))
	var gl := _glitch > 0.0 or _gait == "twitch"
	pz.glitch = gl
	if gl:
		pz.roll = float(pz.roll) + float(_gseed[1]) * 0.22
		pz.pitch = float(pz.pitch) + float(_gseed[2]) * 0.16
		pz.hy = float(pz.hy) + float(_gseed[3]) * 0.5
		pz.hx = float(pz.hx) + float(_gseed[4]) * 0.25
		pz.sway_x = float(pz.sway_x) + float(_gseed[0]) * 0.05
	return pz


func _rot(bone: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
	var i: int = _b[bone]
	skeleton.set_bone_pose_rotation(i, _rest_q[i] * Quaternion(Basis.from_euler(Vector3(x, y, z), EULER_ORDER_XYZ)))


func _apply_pose(q: Dictionary) -> void:
	# Высоту бёдер считаем по длине ног, чтобы ступня всегда стояла на полу
	var drop_l: float = THIGH * cos(float(q.lth)) + SHIN * cos(float(q.lth) + float(q.lkn))
	var drop_r: float = THIGH * cos(float(q.rth)) + SHIN * cos(float(q.rth) + float(q.rkn))
	skeleton.set_bone_pose_position(_b["hips"], Vector3(q.sway_x, maxf(drop_l, drop_r) + 0.114, 0.0))
	_rot("hips", 0.0, q.hip_yaw, q.hip_roll)

	_rot("spineA", float(q.pitch) * 0.38, float(q.twist) * 0.3, float(q.roll) * 0.3)
	_rot("spineB", float(q.pitch) * 0.42, float(q.twist) * 0.4, float(q.roll) * 0.4)
	_rot("chest", float(q.pitch) * 0.2, float(q.twist) * 0.3, float(q.roll) * 0.3)

	var n: float = float(q.neck) + sin(_t * 1.45) * 0.008
	_rot("neckA", n * 0.55)
	_rot("neckC", n * 0.45)
	_rot("head", q.hx, q.hy, q.hz)
	var quiver := maxf(0.0, sin(_t * 1.9)) * sin(_t * 37.0) * 0.018
	if float(q.jaw) > 0.9:
		quiver += sin(_t * 58.0) * 0.05
	_rot("jaw", float(q.jaw) * 0.62 + quiver)

	_rot("thL", q.lth, 0.0, -0.018)
	_rot("thR", q.rth, 0.0, 0.018)
	_rot("knL", q.lkn)
	_rot("knR", q.rkn)
	_rot("anL", -(float(q.lth) + float(q.lkn)) + float(q.l_lift))
	_rot("anR", -(float(q.rth) + float(q.rkn)) + float(q.r_lift))

	_rot("shL", q.lsx, 0.0, -float(q.lsz))
	_rot("shR", q.rsx, 0.0, float(q.rsz))
	_rot("elL", q.lex)
	_rot("elR", q.rex)
	_rot("wrL", q.lw, -0.2)
	_rot("wrR", q.rw, 0.2)

	if _hands_on:
		_curl_hand("L", float(q.curl_l) + float(q.finger_tw), q.glitch)
		_curl_hand("R", float(q.curl_r) + float(q.finger_tw), q.glitch)


func _curl_hand(side: String, curl: float, gl: bool) -> void:
	for i in 4:
		var c := curl + sin(_t * 2.3 + i * 1.5 + (0.0 if side == "L" else 2.0)) * 0.04
		if gl:
			c += float(_gseed[(i + 1) % 5]) * 0.5
		_rot("f%s%da" % [side, i], -0.08 - c * 0.75)
		_rot("f%s%db" % [side, i], -0.12 - c * 0.95)
		_rot("f%s%dc" % [side, i], -0.08 - c * 0.7)
	var t := curl * 0.7
	_rot("t%sa" % side, -0.12 - t * 0.5)
	_rot("t%sb" % side, -0.2 - t * 0.7)
	_rot("t%sc" % side, -0.2 - t * 0.5)


# ══════════════════════════════════════════════
#  Постройка геометрии
# ══════════════════════════════════════════════
class Surf:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var tan := PackedFloat32Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var idx := PackedInt32Array()


static var _build_globals: Array[Transform3D] = []
static var _build_ids := {}


static func _bone(bname: String, parent: String, pos: Vector3, rz: float = 0.0) -> int:
	var i := _bone_defs.size()
	var rest := Transform3D(Basis(Vector3.BACK, rz), pos)
	var pid: int = _build_ids[parent] if parent != "" else -1
	_bone_defs.append({"name": bname, "parent": pid, "rest": rest})
	_build_ids[bname] = i
	_build_globals.append(_build_globals[pid] * rest if pid >= 0 else rest)
	return i


static func _crom(a: float, b: float, c: float, d: float, t: float) -> float:
	return 0.5 * (2.0 * b + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)


static func _sstep(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


static func _ang(a: float, b: float) -> float:
	return wrapf(a - b, -PI, PI)


# Лофт: кольца [y, rx, rz, ox, oz], сглаживание Катмулла-Рома. Возвращает сетку точек.
static func _loft(rings: Array, nu: int, ps: int, disp: Callable = Callable(), uvk: float = 2.0) -> Dictionary:
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var m := rings.size()
	var rows := (m - 1) * ps + 1
	var get_v := func(r: Array, f: int) -> float:
		return float(r[f]) if r.size() > f else 0.0
	for i in rows:
		var s := float(i) / float(ps)
		var k := mini(int(s), m - 2)
		var t := s - k
		var a: Array = rings[maxi(k - 1, 0)]
		var b: Array = rings[k]
		var c: Array = rings[k + 1]
		var d: Array = rings[mini(k + 2, m - 1)]
		var y := _crom(get_v.call(a, 0), get_v.call(b, 0), get_v.call(c, 0), get_v.call(d, 0), t)
		var rx := maxf(_crom(get_v.call(a, 1), get_v.call(b, 1), get_v.call(c, 1), get_v.call(d, 1), t), 0.0004)
		var rz := maxf(_crom(get_v.call(a, 2), get_v.call(b, 2), get_v.call(c, 2), get_v.call(d, 2), t), 0.0004)
		if i == 0 or i == rows - 1:
			# Края схлопываем в точку, иначе в конце лофта остаётся дыра
			rx = 0.0001
			rz = 0.0001
		var ox := _crom(get_v.call(a, 3), get_v.call(b, 3), get_v.call(c, 3), get_v.call(d, 3), t)
		var oz := _crom(get_v.call(a, 4), get_v.call(b, 4), get_v.call(c, 4), get_v.call(d, 4), t)
		for j in nu + 1:
			var th := float(j) / float(nu) * TAU
			var cs := cos(th)
			var sn := sin(th)
			var dr: float = disp.call(th, y, cs, sn) if disp.is_valid() else 0.0
			pts.append(Vector3(ox + (rx + dr) * cs, y, oz + (rz + dr) * sn))
			uvs.append(Vector2(float(j) / float(nu) * uvk, y * uvk * 1.6))
	return {"pts": pts, "uvs": uvs, "nu": nu, "rows": rows, "up": float(rings[m - 1][0]) > float(rings[0][0])}


# Сфера-заготовка (сверху вниз), точки потом деформируются
static func _sphere(nu: int, rows: int) -> Dictionary:
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in rows:
		var ph := float(i) / float(rows - 1) * PI
		for j in nu + 1:
			var th := float(j) / float(nu) * TAU
			pts.append(Vector3(sin(ph) * cos(th), cos(ph), sin(ph) * sin(th)))
			uvs.append(Vector2(float(j) / float(nu), float(i) / float(rows - 1)))
	return {"pts": pts, "uvs": uvs, "nu": nu, "rows": rows, "up": false}


static func _xf(geo: Dictionary, tr: Transform3D) -> Dictionary:
	var pts: PackedVector3Array = geo.pts
	for i in pts.size():
		pts[i] = tr * pts[i]
	geo.pts = pts
	return geo


static func _chain_weights(geo: Dictionary, ofs: Array, ids: Array, w: float, dir: float) -> void:
	var js: Array[float] = []
	var acc := 0.0
	for o in ofs:
		acc += absf(float(o))
		js.append(acc)
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	var pts: PackedVector3Array = geo.pts
	for v in pts.size():
		var d := pts[v].y * dir
		var a := 0
		for i in range(1, js.size()):
			if d > js[i] - w:
				a = i
		if a > 0 and d < js[a] + w:
			var t := smoothstep(js[a] - w, js[a] + w, d)
			bones.append_array([ids[a - 1], ids[a], 0, 0])
			wts.append_array([1.0 - t, t, 0.0, 0.0])
		else:
			bones.append_array([ids[a], 0, 0, 0])
			wts.append_array([1.0, 0.0, 0.0, 0.0])
	geo.bones = bones
	geo.weights = wts


# Добавляет сетку в поверхность: нормали считаем по сетке, швы сглаживаем.
# В Godot лицевая сторона — по часовой, поэтому индексы идут в обратном порядке.
static func _add(sf: Surf, geo: Dictionary, bone: int = -1, tint: Color = Color.WHITE) -> void:
	var pts: PackedVector3Array = geo.pts
	var nu: int = geo.nu
	var rows: int = geo.rows
	var st := nu + 1
	var base := sf.v.size()
	var nrm := PackedVector3Array()
	nrm.resize(pts.size())
	var flip: bool = not geo.up
	for i in rows - 1:
		for j in nu:
			var a := i * st + j
			var b := (i + 1) * st + j
			var c := i * st + j + 1
			var d := (i + 1) * st + j + 1
			var fn := (pts[b] - pts[a]).cross(pts[c] - pts[a]) + (pts[d] - pts[c]).cross(pts[b] - pts[c])
			if flip:
				fn = -fn
			nrm[a] += fn
			nrm[b] += fn
			nrm[c] += fn
			nrm[d] += fn
			if flip:
				sf.idx.append_array([base + a, base + b, base + c, base + c, base + b, base + d])
			else:
				sf.idx.append_array([base + a, base + c, base + b, base + c, base + d, base + b])
	for i in rows:
		var p := i * st
		var q := p + nu
		var ns := nrm[p] + nrm[q]
		nrm[p] = ns
		nrm[q] = ns
	var has_col: bool = geo.has("col")
	for i in pts.size():
		sf.v.append(pts[i])
		var nn := nrm[i].normalized() if nrm[i].length_squared() > 0.0 else Vector3.UP
		sf.n.append(nn)
		# Касательная вдоль кольца — без неё карта нормалей даёт пятна
		var nxt := i + 1 if (i % st) < nu else i - 1
		var tg := pts[nxt] - pts[i]
		if (i % st) >= nu:
			tg = -tg
		tg = (tg - nn * nn.dot(tg))
		if tg.length_squared() < 1e-12:
			tg = nn.cross(Vector3.UP if absf(nn.y) < 0.9 else Vector3.RIGHT)
		tg = tg.normalized()
		sf.tan.append_array([tg.x, tg.y, tg.z, 1.0])
		sf.uv.append(geo.uvs[i])
		sf.col.append(geo.col[i] if has_col else tint)
	if geo.has("bones"):
		sf.bones.append_array(geo.bones)
		sf.weights.append_array(geo.weights)
	else:
		for i in pts.size():
			sf.bones.append_array([bone, 0, 0, 0])
			sf.weights.append_array([1.0, 0.0, 0.0, 0.0])


static func _G(bname: String) -> Transform3D:
	return _build_globals[_build_ids[bname]]


static func _commit(mesh: ArrayMesh, sf: Surf, mat: Material) -> void:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = sf.v
	arr[Mesh.ARRAY_NORMAL] = sf.n
	arr[Mesh.ARRAY_TANGENT] = sf.tan
	arr[Mesh.ARRAY_TEX_UV] = sf.uv
	arr[Mesh.ARRAY_COLOR] = sf.col
	arr[Mesh.ARRAY_BONES] = sf.bones
	arr[Mesh.ARRAY_WEIGHTS] = sf.weights
	arr[Mesh.ARRAY_INDEX] = sf.idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func _noise_tex(ntype: int, freq: float, as_normal: bool) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = ntype
	fn.frequency = freq
	fn.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = fn
	if as_normal:
		tex.as_normal_map = true
		tex.bump_strength = 4.0
	return tex


static func _make_skin_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(0.035, 0.03, 0.033)
	m.normal_enabled = true
	m.normal_texture = _noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.05, true)
	m.normal_scale = 0.9
	m.roughness = 0.85
	m.metallic_specular = 0.2
	m.rim_enabled = true
	m.rim = 0.12
	m.rim_tint = 0.5
	m.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return m


static func _build_mesh() -> void:
	_bone_defs.clear()
	_build_globals.clear()
	_build_ids.clear()

	_bone("hips", "", Vector3(0, 1.17, 0))
	_bone("spineA", "hips", Vector3(0, 0.25, 0))
	_bone("spineB", "spineA", Vector3(0, 0.3, 0))
	_bone("chest", "spineB", Vector3(0, 0.25, 0))
	_bone("neck0", "chest", Vector3(0, 0.07, 0))
	_bone("neckA", "neck0", Vector3(0, 0.1, 0))
	_bone("neckC", "neckA", Vector3(0, 0.1, 0))
	_bone("head", "neckC", Vector3.ZERO)
	_bone("jaw", "head", Vector3(0, 0.022, -0.03))
	_bone("throat", "head", Vector3(0, -0.03, -0.004))
	_bone("eyeL", "head", Vector3(-0.046, 0.165, 0.09))
	_bone("eyeR", "head", Vector3(0.046, 0.165, 0.09))

	var skin := Surf.new()
	var horn := Surf.new()   # когти и зубы
	var inner := Surf.new()  # пасть изнутри
	var eyes := Surf.new()

	# ── Торс ──
	var torso := _loft([[-.185, .006, .006], [-.17, .05, .045], [-.11, .092, .066], [-.05, .126, .08], [.03, .136, .086], [.12, .116, .074], [.22, .1, .064], [.32, .112, .068], [.42, .148, .086], [.52, .172, .1], [.62, .18, .106], [.72, .196, .108], [.78, .188, .094], [.83, .14, .08], [.875, .082, .066], [.93, .054, .056], [.96, .04, .04]], 36, 6, _torso_disp)
	_chain_weights(torso, [0.0, 0.25, 0.3, 0.25], [_build_ids.hips, _build_ids.spineA, _build_ids.spineB, _build_ids.chest], 0.1, 1.0)
	_xf(torso, _G("hips"))
	_add(skin, torso)

	# ── Шея ──
	var neck := _loft([[-.04, .058, .056], [.03, .046, .048], [.1, .038, .04], [.17, .036, .04], [.22, .04, .042], [.25, .03, .03]], 16, 5, _neck_disp)
	_chain_weights(neck, [0.0, 0.1, 0.1], [_build_ids.neck0, _build_ids.neckA, _build_ids.neckC], 0.05, 1.0)
	_xf(neck, _G("neck0"))
	_add(skin, neck)

	_build_head(skin, horn, inner, eyes)

	for sd in [-1.0, 1.0]:
		_build_arm(sd, skin, horn)
		_build_leg(sd, skin, horn)

	var mesh := ArrayMesh.new()
	_commit(mesh, skin, _make_skin_material())

	var horn_m := StandardMaterial3D.new()
	horn_m.vertex_color_use_as_albedo = true
	horn_m.roughness = 0.32
	horn_m.metallic = 0.25
	_commit(mesh, horn, horn_m)

	var inner_m := StandardMaterial3D.new()
	inner_m.vertex_color_use_as_albedo = true
	inner_m.roughness = 0.55
	_commit(mesh, inner, inner_m)

	var eye_m := StandardMaterial3D.new()
	eye_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_m.albedo_color = Color(1.0, 0.72, 0.62)
	eye_m.emission_enabled = true
	eye_m.emission = Color(1.0, 0.25, 0.14)
	eye_m.emission_energy_multiplier = 2.2
	_commit(mesh, eyes, eye_m)

	_mesh = mesh


static func _torso_disp(th: float, y: float, c: float, s: float) -> float:
	var d := 0.0
	var front := maxf(0.0, s)
	if y > 0.34 and y < 0.74:
		var fade := smoothstep(0.34, 0.4, y) * (1.0 - smoothstep(0.68, 0.74, y))
		var r := maxf(0.0, sin((y + 0.03 * s - 0.34 + 0.004 * sin(th * 3.0)) * TAU / 0.064))
		var ms := smoothstep(0.14, 0.55, absf(c)) * (1.0 if s > -0.45 else smoothstep(-0.8, -0.45, s))
		d += r * r * 0.0042 * fade * ms
		d -= (1.0 - r) * 0.0014 * fade * ms
	var bd := _ang(th, PI * 1.5)
	if y > 0.0 and y < 0.86:
		d += 0.013 * exp(-(bd * bd) / 0.04) * (0.55 + 0.45 * sin(y * 118.0))
	if y > 0.1 and y < 0.8:
		d -= 0.006 * exp(-(bd * bd) / 0.3)
	var fd := _ang(th, PI / 2.0)
	if y > 0.38 and y < 0.72:
		d -= 0.006 * exp(-(fd * fd) / 0.03)
	d -= 0.022 * front * front * exp(-pow((y - 0.22) / 0.09, 2.0))
	if s > 0.0:
		d += 0.012 * exp(-pow((y - 0.04) / 0.03, 2.0)) * smoothstep(0.2, 0.8, absf(c))
	d += 0.009 * exp(-pow((y - 0.79) / 0.012, 2.0)) * front
	for q in [-1, 1]:
		var sd := _ang(th, -0.75 if q > 0 else PI + 0.75)
		d += 0.014 * exp(-(sd * sd) / 0.09) * exp(-pow((y - 0.67) / 0.06, 2.0))
	return d


static func _neck_disp(th: float, y: float, _c: float, _s: float) -> float:
	var a := _ang(th, PI / 2.0 - 0.6)
	var b := _ang(th, PI / 2.0 + 0.6)
	var e := _ang(th, PI * 1.5)
	return 0.006 * exp(-a * a / 0.05) + 0.006 * exp(-b * b / 0.05) + 0.004 * exp(-e * e / 0.08) * (0.5 + 0.5 * sin(y * 90.0))


static func _gs(p: Vector3, c: Vector3, sg: float) -> float:
	return exp(-p.distance_squared_to(c) / (sg * sg))


static func _build_head(skin: Surf, horn: Surf, inner: Surf, eyes: Surf) -> void:
	var head_t := _G("head")
	var skull := _loft([[-.035, .006, .006, 0, .02], [-.03, .044, .062, 0, .02], [-.005, .056, .08, 0, .02], [.04, .06, .088, 0, .014], [.09, .078, .098, 0, .006], [.14, .082, .104, 0, 0], [.2, .09, .114, 0, -.008], [.26, .09, .116, 0, -.016], [.31, .07, .092, 0, -.022], [.338, .038, .046, 0, -.024], [.346, .002, .002, 0, -.024]], 56, 6, Callable(), 1.4)
	var pts: PackedVector3Array = skull.pts
	var cols := PackedColorArray()
	var center := Vector3(0, 0.13, 0)
	for i in pts.size():
		var p := pts[i]
		var d := 0.0
		var dark := 0.0
		for s in [-1.0, 1.0]:
			var so := _gs(p, Vector3(0.046 * s, 0.165, 0.098), 0.033)
			d -= 0.034 * so
			dark = maxf(dark, so * 1.25)
			d -= 0.012 * _gs(p, Vector3(0.098 * s, 0.215, 0.01), 0.036)
			d += 0.016 * _gs(p, Vector3(0.077 * s, 0.098, 0.05), 0.024)
			d -= 0.03 * _gs(p, Vector3(0.062 * s, 0.04, 0.05), 0.032)
			d += 0.006 * _gs(p, Vector3(0.03 * s, 0.212, 0.1), 0.016)
			d -= 0.016 * _gs(p, Vector3(0.013 * s, 0.103, 0.102), 0.0105)
			dark = maxf(dark, _gs(p, Vector3(0.013 * s, 0.103, 0.102), 0.012) * 1.1)
			d += 0.006 * _gs(p, Vector3(0.055 * s, 0.0, 0.075), 0.018)
		d += 0.009 * exp(-pow((p.y - 0.205) / 0.012, 2.0)) * smoothstep(0.03, 0.085, p.z)
		d -= 0.01 * _gs(p, Vector3(0, 0.215, 0.115), 0.016)
		d += 0.006 * exp(-pow(p.x / 0.012, 2.0)) * smoothstep(0.13, 0.17, p.y) * (1.0 - smoothstep(0.17, 0.2, p.y)) * smoothstep(0.05, 0.1, p.z)
		if p.z < 0.06:
			d += 0.005 * exp(-pow(p.x / 0.006, 2.0)) * smoothstep(0.2, 0.3, p.y)
		var mo := exp(-pow((p.y + 0.012) / 0.014, 2.0)) * smoothstep(0.02, 0.07, p.z)
		dark = maxf(dark, mo)
		p += (p - center).normalized() * d
		pts[i] = p
		var v := maxf(0.02, 1.0 - minf(1.0, dark))
		cols.append(Color(v, v, v))
	skull.pts = pts
	skull.col = cols

	# Глаза сидят на поверхности глазниц: ищем точку черепа перед ними
	var eye_z := {}
	for s in [-1.0, 1.0]:
		var best := 1e9
		var z := 0.09
		for p in pts:
			if p.z < 0.0:
				continue
			var e := pow(p.x - 0.046 * s, 2.0) + pow(p.y - 0.165, 2.0)
			if e < best:
				best = e
				z = p.z
		eye_z[s] = z

	_xf(skull, head_t)
	_add(skin, skull, _build_ids.head)

	var flesh := Color(0.07, 0.012, 0.02)
	var tooth := Color(0.30, 0.27, 0.21)
	var ball := func(sc: Vector3, pos: Vector3, parent: Transform3D, nu: int, rows: int) -> Dictionary:
		var g := _sphere(nu, rows)
		return _xf(g, parent * Transform3D(Basis().scaled(sc), pos))

	# Глотка — чёрная сфера, чтобы пасть выглядела провалом
	var throat_b: int = _build_ids.throat
	_add(inner, ball.call(Vector3(0.038, 0.04, 0.042), Vector3.ZERO, _G("throat"), 12, 9), throat_b, Color.BLACK)
	_add(inner, ball.call(Vector3(0.044, 0.022, 0.058), Vector3(0, -0.018, 0.018), head_t, 14, 10), _build_ids.head, flesh)

	# Верхние зубы
	for i in 19:
		var a := float(i - 9) / 9.0 * 1.42
		var big := 1.5 if (i % 4 == 1 or i == 4 or i == 14) else 1.0
		var l := (0.022 + 0.016 * randf()) * big
		var r := 0.0032 * (1.25 if big > 1.0 else 1.0)
		var g := _needle(l, r)
		var tr := Transform3D(Basis.from_euler(Vector3(randf_range(-0.12, 0.12) + 0.08, 0.0, randf_range(-0.16, 0.16))), Vector3(0.05 * sin(a), -0.004, 0.015 + 0.074 * cos(a)))
		_add(horn, _xf(g, head_t * tr), _build_ids.head, tooth)

	# Нижняя челюсть
	var jaw_t := _G("jaw")
	var jaw_b: int = _build_ids.jaw
	var jg := _sphere(36, 24)
	var jp: PackedVector3Array = jg.pts
	for i in jp.size():
		var q := jp[i]
		var nar := 1.0 - 0.42 * smoothstep(-0.2, 1.0, q.z)
		var rad := Vector2(q.x / 0.82, (q.z + 0.05) / 0.85).length()
		var hol := (1.0 - smoothstep(0.45, 0.9, rad)) * 1.1 if q.y > 0.0 else 0.0
		var chin := -0.25 * (q.z - 0.55) if q.z > 0.55 else 0.0
		jp[i] = Vector3(0.058 * q.x * nar, (q.y - hol + chin) * 0.036, 0.082 * q.z) + Vector3(0, -0.06, 0.058)
	jg.pts = jp
	_add(skin, _xf(jg, jaw_t), jaw_b)
	_add(inner, ball.call(Vector3(0.036, 0.012, 0.052), Vector3(0, -0.056, 0.05), jaw_t, 12, 8), jaw_b, flesh)
	for i in 15:
		var a := float(i - 7) / 7.0 * 1.32
		var big := 1.5 if i % 4 == 2 else 1.0
		var l := (0.018 + 0.014 * randf()) * big
		var r := 0.003 * (1.25 if big > 1.0 else 1.0)
		var g := _needle(l, r)
		var tr := Transform3D(Basis.from_euler(Vector3(PI + randf_range(-0.12, 0.12), 0.0, randf_range(-0.14, 0.14))), Vector3(0.039 * sin(a), -0.034, 0.048 + 0.066 * cos(a)))
		_add(horn, _xf(g, jaw_t * tr), jaw_b, tooth)

	# Глаза: кости стоят на уровне глаз, сетка смещена к поверхности глазницы
	for s in [-1.0, 1.0]:
		var bname := "eyeL" if s < 0.0 else "eyeR"
		var eg := _sphere(10, 8)
		var offs := Vector3(0, 0, float(eye_z[s]) + 0.0015 - 0.09)
		var bas := Basis(Vector3.BACK, -0.42 * s) * Basis().scaled(Vector3(0.0085, 0.0042, 0.004))
		_add(eyes, _xf(eg, _G(bname) * Transform3D(bas, offs)), _build_ids[bname])


static func _needle(l: float, r: float) -> Dictionary:
	return _loft([[0.0, r, r], [-l * 0.5, r * 0.62, r * 0.62], [-l, 0.0002, 0.0002]], 6, 2)


static func _finger_seg(l: float, r0: float, r1: float) -> Dictionary:
	return _loft([[.006, r0 * .8, r0 * .8], [0.0, r0 * 1.12, r0 * 1.15], [-l * .5, r1 * .78, r1 * .82], [-l, r1 * 1.1, r1 * 1.15], [-l - .004, r1 * .7, r1 * .7]], 8, 3, Callable(), 0.6)


static func _make_finger(tag: String, parent: String, lens: Array, pos: Vector3, rz: float, claw_l: float, skin: Surf, horn: Surf) -> void:
	_bone(tag + "a", parent, pos, rz)
	_add(skin, _xf(_finger_seg(lens[0], 0.0095, 0.0078), _G(tag + "a")), _build_ids[tag + "a"])
	_bone(tag + "b", tag + "a", Vector3(0, -float(lens[0]), 0))
	_add(skin, _xf(_finger_seg(lens[1], 0.0078, 0.0066), _G(tag + "b")), _build_ids[tag + "b"])
	_bone(tag + "c", tag + "b", Vector3(0, -float(lens[1]), 0))
	_add(skin, _xf(_finger_seg(lens[2], 0.0066, 0.0056), _G(tag + "c")), _build_ids[tag + "c"])
	var cv := 0.038
	var r := 0.0062
	var claw := _loft([[0.0, r, r * 1.1, 0, 0], [-claw_l * .3, r * .8, r * .95, 0, cv * .09], [-claw_l * .65, r * .45, r * .55, 0, cv * .42], [-claw_l, .0002, .0002, 0, cv]], 7, 4)
	_add(horn, _xf(claw, _G(tag + "c") * Transform3D(Basis(), Vector3(0, -float(lens[2]), 0))), _build_ids[tag + "c"], Color(0.11, 0.095, 0.075))


static func _build_arm(side: float, skin: Surf, horn: Surf) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("sh" + sfx, "chest", Vector3(0.2 * side, -0.07, 0))
	_bone("el" + sfx, "sh" + sfx, Vector3(0, -0.62, 0))
	_bone("wr" + sfx, "el" + sfx, Vector3(0, -0.72, 0))
	var disp := func(th: float, y: float, _c: float, _s: float) -> float:
		var d := 0.0
		if y < -0.66 and y > -1.3:
			d += 0.0035 * absf(sin(th * 2.5))
		if y < -0.05 and y > -0.58:
			var f := _ang(th, -0.2 * side)
			d += 0.003 * exp(-f * f / 0.2)
		return d
	var arm := _loft([[.07, .008, .008], [.05, .042, .044], [.0, .058, .06], [-.08, .057, .058], [-.2, .045, .046], [-.35, .039, .04], [-.5, .033, .033], [-.59, .032, .032], [-.62, .036, .035], [-.655, .034, .034], [-.74, .037, .034], [-.84, .041, .036], [-1.0, .03, .026], [-1.15, .021, .017], [-1.3, .017, .012], [-1.345, .02, .013], [-1.39, .008, .005]], 14, 4, disp)
	_chain_weights(arm, [0.0, -0.62, -0.72], [_build_ids["sh" + sfx], _build_ids["el" + sfx], _build_ids["wr" + sfx]], 0.055, -1.0)
	_xf(arm, _G("sh" + sfx))
	_add(skin, arm)
	var palm := _loft([[.012, .022, .012], [-.03, .038, .015], [-.07, .046, .016], [-.105, .046, .014], [-.12, .024, .009]], 10, 3, Callable(), 0.6)
	_add(skin, _xf(palm, _G("wr" + sfx)), _build_ids["wr" + sfx])
	var fs := [[[.083, .062, .048], -.1, .1, -1.5 * .08, .11], [[.098, .072, .055], -.03, .108, -.5 * .08, .15], [[.093, .068, .052], .03, .106, .5 * .08, .13], [[.072, .054, .044], .09, .1, 1.5 * .08, .09]]
	for i in 4:
		var q: Array = fs[i]
		_make_finger("f%s%d" % [sfx, i], "wr" + sfx, q[0], Vector3(float(q[1]) * 0.42, -float(q[2]), 0), q[3], q[4], skin, horn)
	_make_finger("t" + sfx, "wr" + sfx, [.05, .04, .034], Vector3(-0.044 * side, -0.03, 0), 0.8 * side, 0.075, skin, horn)


static func _build_leg(side: float, skin: Surf, horn: Surf) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("th" + sfx, "hips", Vector3(0.08 * side, -0.04, 0))
	_bone("kn" + sfx, "th" + sfx, Vector3(0, -THIGH, 0))
	_bone("an" + sfx, "kn" + sfx, Vector3(0, -SHIN, 0))
	var disp := func(th: float, y: float, _c: float, _s: float) -> float:
		return 0.003 * absf(sin(th * 2.0)) if (y < -0.7 and y > -1.1) else 0.0
	var leg := _loft([[.05, .008, .008], [.03, .044, .05], [-.05, .07, .082], [-.22, .066, .076, 0, .008], [-.4, .054, .056, 0, .004], [-.52, .042, .045], [-.56, .046, .052, 0, .005], [-.6, .041, .044], [-.68, .041, .05, 0, -.008], [-.8, .046, .058, 0, -.014], [-.95, .03, .036, 0, -.006], [-1.06, .021, .024], [-1.12, .025, .028], [-1.15, .012, .012]], 14, 4, disp)
	_chain_weights(leg, [0.0, -THIGH, -SHIN], [_build_ids["th" + sfx], _build_ids["kn" + sfx], _build_ids["an" + sfx]], 0.06, -1.0)
	_xf(leg, _G("th" + sfx))
	_add(skin, leg)
	var an_b: int = _build_ids["an" + sfx]
	var an_t := _G("an" + sfx)
	var to_z := Basis(Vector3.RIGHT, PI / 2.0)
	var foot := _loft([[-.075, .008, .008], [-.06, .03, .03], [.01, .034, .026], [.09, .044, .018], [.15, .046, .012], [.175, .035, .008]], 12, 3, Callable(), 0.6)
	_add(skin, _xf(foot, an_t * Transform3D(to_z, Vector3(0, -0.042, 0))), an_b)
	for i in 3:
		var tl := 0.09 + 0.012 * (1.0 - absf(i - 1.0))
		var toe := _loft([[0.0, .012, .01], [.05, .0105, .009], [tl, .0075, .007]], 7, 2, Callable(), 0.4)
		var toe_t := an_t * Transform3D(Basis(Vector3.UP, (i - 1) * 0.17), Vector3((i - 1) * 0.03, -0.048, 0.165))
		_add(skin, _xf(toe, toe_t * Transform3D(to_z, Vector3.ZERO)), an_b)
		var claw := _loft([[0.0, .0072, .0065, 0, 0], [.04, .004, .004, 0, .006], [.075, .0002, .0002, 0, .022]], 6, 2)
		_add(horn, _xf(claw, toe_t * Transform3D(to_z, Vector3(0, 0, tl))), an_b, Color(0.11, 0.095, 0.075))
