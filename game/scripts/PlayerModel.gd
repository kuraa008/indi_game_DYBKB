extends Node3D
class_name PlayerModel

# Процедурная 3D-модель главного героя: рисунки персонажа натянуты на сетку со скелетом.
# Геометрия строится один раз и кэшируется. Лицо смотрит вдоль локальной +Z.
# От первого лица голова и руки скрыты: в кадре остаются руки PlayerHands.

const PX: float = 0.00172
const HIP_Y: float = 0.97
const HEAD_Y: float = HIP_Y + 0.4 + 0.13 + 0.053
const SHOULDER_X: float = 0.192
const LEG_X: float = 0.1
const THIGH: float = 0.42
const SHIN: float = 0.42
const TEX_PATH := "res://assets/textures/player_character/baked/player_%s.png"
# Глаза модели на этой высоте при масштабе 1
const EYE_Y: float = 1.654

# Строки: высота на рисунке, полуширина лица без ушей, затылок и перед по профилю
const HEAD_ROWS := [[6, 20, 68, 112], [12, 33, 62, 124], [18, 41, 54, 136], [24, 46, 47, 146], [30, 49, 42, 154], [42, 50, 36, 160], [54, 47, 33, 160], [64, 44, 33, 158], [78, 43, 36, 158], [90, 43, 42, 158], [102, 42, 47, 158], [114, 40, 53, 156], [122, 38, 56, 155], [130, 34, 70, 154], [138, 30, 88, 153], [146, 24, 102, 150], [153, 16, 112, 147], [158, 7, 122, 139]]
# Строки кисти: высота на рисунке, края спереди и края сбоку (левая кисть на листе)
const HAND_ROWS := [[516, 15, 46, 72, 104], [525, 13, 48, 69, 106], [534, 13, 50, 68, 110], [548, 12, 54, 68, 116], [562, 11, 58, 68, 120], [576, 12, 62, 69, 123], [588, 15, 63, 72, 124], [597, 25, 62, 78, 122], [604, 40, 60, 92, 120], [608, 50, 58, 104, 118]]

# Частота шага совпадает со звуком шагов в Player.gd
const GAITS := {
	"idle":   {"rate": 0.0,  "nominal": 1.0, "amp": 0.0,  "pitch": 0.03, "lean": 0.0,  "knee": 0.07, "out": 0.06, "elbow": 0.16, "swing": 0.0},
	"walk":   {"rate": 9.5,  "nominal": 4.2, "amp": 0.42, "pitch": 0.05, "lean": 0.03, "knee": 0.09, "out": 0.06, "elbow": 0.2,  "swing": 0.42},
	"run":    {"rate": 13.0, "nominal": 6.2, "amp": 0.64, "pitch": 0.16, "lean": 0.24, "knee": 0.22, "out": 0.1,  "elbow": 1.25, "swing": 0.78},
	# Присед в игре очень низкий: камера на высоте 0.88, поэтому колени согнуты сильно
	"crouch": {"rate": 7.0,  "nominal": 2.3, "amp": 0.26, "pitch": 0.55, "lean": 0.2,  "knee": 2.1,  "out": 0.14, "elbow": 0.62, "swing": 0.2},
}

class ProjSurf:
	var sf = SkinwalkerModel.Surf.new()
	var uv2 := PackedVector2Array()

static var _body_mesh: ArrayMesh = null
static var _upper_mesh: ArrayMesh = null
static var _bone_defs: Array = []
static var _globals: Array[Transform3D] = []
static var _ids := {}

var rig: Node3D
var skeleton: Skeleton3D
var body: MeshInstance3D
var upper: MeshInstance3D

var _b := {}
var _p := {}
var _t := 0.0
var _phase := 0.0
var _look_pitch := 0.0
var _spring := {"ls": 0.0, "lsv": 0.0, "rs": 0.0, "rsv": 0.0, "le": 0.0, "lev": 0.0, "re": 0.0, "rev": 0.0}


func _init() -> void:
	if _body_mesh == null:
		_build_mesh()
	rig = Node3D.new()
	rig.name = "Rig"
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
	skeleton.reset_bone_poses()
	body = _mesh_instance("Body", _body_mesh)
	upper = _mesh_instance("Upper", _upper_mesh)
	_p = GAITS["idle"].duplicate()
	_apply(0.0, 0.0)


func _mesh_instance(node_name: String, mesh: ArrayMesh) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.extra_cull_margin = 1.2
	skeleton.add_child(mi)
	mi.skeleton = NodePath("..")
	return mi


# ══════════════════════════════════════════════
#  Публичное API
# ══════════════════════════════════════════════
func set_first_person(enabled: bool) -> void:
	upper.visible = not enabled
	set_shadows(not enabled)


func set_shadows(enabled: bool) -> void:
	var mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.cast_shadow = mode
	upper.cast_shadow = mode


# pitch_rad: наклон взгляда игрока, плюс — вверх
func set_look_pitch(pitch_rad: float) -> void:
	_look_pitch = clampf(pitch_rad, -0.9, 0.7)


func update_motion(delta: float, mode: String, move_speed: float) -> void:
	var tg: Dictionary = GAITS[mode if GAITS.has(mode) else "idle"]
	_t += delta
	var k := minf(1.0, delta * 5.0)
	for key in tg:
		_p[key] = lerpf(_p[key], tg[key], k)
	var rate: float = float(tg.rate) * clampf(move_speed / float(tg.nominal), 0.0, 1.25)
	_phase += delta * rate
	_apply(delta, minf(1.0, rate / 4.0))


# ══════════════════════════════════════════════
#  Анимация
# ══════════════════════════════════════════════
func _rot(bone: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
	skeleton.set_bone_pose_rotation(_b[bone], Quaternion(Basis.from_euler(Vector3(x, y, z), EULER_ORDER_XYZ)))


func _spring_to(key: String, target: float, dt: float, stiff: float, damp: float) -> float:
	var v_key := key + "v"
	_spring[v_key] += (target - float(_spring[key])) * stiff * dt - float(_spring[v_key]) * damp * dt
	_spring[key] += float(_spring[v_key]) * dt
	return _spring[key]


func _apply(delta: float, k: float) -> void:
	var dt := minf(delta, 0.033)
	var amp: float = _p.amp
	var knee: float = _p.knee
	var lean: float = _p.lean
	var swing: float = _p.swing
	var elbow: float = _p.elbow
	var s := sin(_phase)
	var c := cos(_phase)
	var br := sin(_t * 1.5)

	var pitch: float = float(_p.pitch) + lean + br * 0.008 + absf(s) * 0.012 * k
	var lth := -s * amp - lean * 0.45 - knee * 0.46
	var rth := s * amp - lean * 0.45 - knee * 0.46
	var lkn := knee + amp * 1.34 * pow(maxf(0.0, c), 1.3)
	var rkn := knee + amp * 1.34 * pow(maxf(0.0, -c), 1.3)
	var drop_l := THIGH * cos(lth) + SHIN * cos(lth + lkn)
	var drop_r := THIGH * cos(rth) + SHIN * cos(rth + rkn)
	skeleton.set_bone_pose_position(_b["hips"], Vector3(s * 0.024 * k, maxf(drop_l, drop_r) + 0.13, 0.0))
	_rot("hips", 0.0, s * 0.11 * k, -s * 0.04 * k)

	var twist := -s * 0.14 * k
	var roll := s * 0.024 * k
	_rot("spineA", pitch * 0.55, twist * 0.5, roll * 0.5)
	_rot("chest", pitch * 0.45, twist * 0.5, roll * 0.5)

	_rot("thL", lth, 0.0, -0.025)
	_rot("thR", rth, 0.0, 0.025)
	_rot("knL", lkn)
	_rot("knR", rkn)
	_rot("anL", -(lth + lkn) + maxf(0.0, c) * amp * 0.25)
	_rot("anR", -(rth + rkn) + maxf(0.0, -c) * amp * 0.25)

	# Голова смотрит туда же, куда смотрит игрок
	_rot("neck", -pitch * 0.72 + br * 0.006 - _look_pitch * 0.35, 0.0, sin(_t * 0.53) * 0.012)
	_rot("head", -0.02 - _look_pitch * 0.55, -twist * 0.8, sin(_t * 0.7) * 0.014)

	var fast := float(_p.rate) > 11.0
	var stiff := 90.0 if fast else 45.0
	var damp := 12.0 if fast else 7.0
	var l_t := s * swing * 0.68 + 0.03 + sin(_t * 1.25) * 0.012
	var r_t := -s * swing * 0.68 + 0.03 + sin(_t * 1.25 + 1.0) * 0.012
	var l_e := -(elbow + swing * 0.4 * (0.5 + 0.5 * s))
	var r_e := -(elbow + swing * 0.4 * (0.5 - 0.5 * s))
	_rot("shL", _spring_to("ls", l_t, dt, stiff, damp), 0.0, -float(_p.out))
	_rot("shR", _spring_to("rs", r_t, dt, stiff, damp), 0.0, float(_p.out))
	_rot("elL", _spring_to("le", l_e, dt, stiff * 0.8, damp))
	_rot("elR", _spring_to("re", r_e, dt, stiff * 0.8, damp))
	_rot("wrL", -0.08, -0.2)
	_rot("wrR", -0.08, 0.2)


# ══════════════════════════════════════════════
#  Постройка геометрии
# ══════════════════════════════════════════════
static func _bone(bname: String, parent: String, pos: Vector3) -> void:
	var pid: int = _ids[parent] if parent != "" else -1
	var rest := Transform3D(Basis(), pos)
	_ids[bname] = _bone_defs.size()
	_bone_defs.append({"name": bname, "parent": pid, "rest": rest})
	_globals.append(_globals[pid] * rest if pid >= 0 else rest)


static func _top_y(py: float) -> float:
	return (1050.0 - py) * PX


# Нормали той же сетки, что считает SkinwalkerModel._add
static func _grid_normals(geo: Dictionary) -> PackedVector3Array:
	var pts: PackedVector3Array = geo.pts
	var nu: int = geo.nu
	var rows: int = geo.rows
	var st := nu + 1
	var nrm := PackedVector3Array()
	nrm.resize(pts.size())
	nrm.fill(Vector3.ZERO)
	var flip: bool = not geo.up
	for i in rows - 1:
		for j in nu:
			var a := i * st + j
			var b := (i + 1) * st + j
			var c := i * st + j + 1
			var d := (i + 1) * st + j + 1
			var fn := (pts[b] - pts[a]).cross(pts[c] - pts[a]) + (pts[b] - pts[c]).cross(pts[d] - pts[c])
			if flip:
				fn = -fn
			nrm[a] += fn
			nrm[b] += fn
			nrm[c] += fn
			nrm[d] += fn
	for i in rows:
		var ns := nrm[i * st] + nrm[i * st + nu]
		nrm[i * st] = ns
		nrm[i * st + nu] = ns
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 0.0 else Vector3.UP
	return nrm


# fn(точка, нормаль) возвращает [точка на рисунке, направление выбора рисунка, затенение]
static func _project(geo: Dictionary, fn: Callable) -> Dictionary:
	var pts: PackedVector3Array = geo.pts
	var nrm := _grid_normals(geo)
	var uvs := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	uvs.resize(pts.size())
	uv2.resize(pts.size())
	col.resize(pts.size())
	for i in pts.size():
		var r: Array = fn.call(pts[i], nrm[i])
		var bp: Vector3 = r[0]
		var bn: Vector3 = (r[1] as Vector3).normalized()
		uvs[i] = Vector2(bp.x, bp.y)
		uv2[i] = Vector2(bp.z, r[2])
		col[i] = Color(bn.x * 0.5 + 0.5, bn.y * 0.5 + 0.5, bn.z * 0.5 + 0.5)
	geo.uvs = uvs
	geo.uv2 = uv2
	geo.col = col
	return geo


# Кладёт сетку в поверхность, переводя её из осей кости в позу покоя всего скелета
static func _put(ps: ProjSurf, geo: Dictionary, bone: String) -> void:
	SkinwalkerModel._xf(geo, _globals[_ids[bone]])
	if geo.has("bones"):
		SkinwalkerModel._add(ps.sf, geo)
	else:
		SkinwalkerModel._add(ps.sf, geo, _ids[bone])
	ps.uv2.append_array(geo.uv2)


static func _put_plain(sf, geo: Dictionary, bone: String, local: Transform3D = Transform3D()) -> void:
	SkinwalkerModel._add(sf, SkinwalkerModel._xf(geo, _globals[_ids[bone]] * local), _ids[bone])


static func _row_half(py: float) -> float:
	if py <= float(HEAD_ROWS[0][0]):
		return HEAD_ROWS[0][1]
	for i in range(1, HEAD_ROWS.size()):
		var b: Array = HEAD_ROWS[i]
		if py <= float(b[0]):
			var a: Array = HEAD_ROWS[i - 1]
			return lerpf(a[1], b[1], (py - float(a[0])) / (float(b[0]) - float(a[0])))
	return HEAD_ROWS[HEAD_ROWS.size() - 1][1]


static func _build_head(ps: ProjSurf) -> void:
	var yr := func(py: float) -> float: return _top_y(py) - HEAD_Y
	var rings: Array = [[_top_y(3) - HEAD_Y, 0.004, 0.004, 0.0, (86.0 - 88.0) * PX]]
	for r in HEAD_ROWS:
		rings.append([_top_y(r[0]) - HEAD_Y, r[1] * PX, (r[3] - r[2]) / 2.0 * PX, 0.0, ((r[2] + r[3]) / 2.0 - 88.0) * PX])
	rings.append([_top_y(161) - HEAD_Y, 0.003, 0.003, 0.0, (130.0 - 88.0) * PX])
	var nu := 64
	var face := SkinwalkerModel._loft(rings, nu, 5, Callable(), 1.0)
	var pts: PackedVector3Array = face.pts
	var st := nu + 1
	var y_nose: float = yr.call(112.0)
	var y_eye: float = yr.call(88.0)
	var y_a: float = yr.call(108.0)
	var y_b: float = yr.call(150.0)
	for r in face.rows:
		var y := pts[r * st].y
		var rx := pts[r * st].x
		var zf := pts[r * st + nu / 4].z
		var zb := pts[r * st + nu * 3 / 4].z
		var oz := (zf + zb) / 2.0
		var rz := (zf - zb) / 2.0
		# Лоб и щёки плоские, ниже скул сечение сходится к подбородку. Высота растёт вниз к меньшему y
		var low := smoothstep(y_a, y_b, y)
		var pw := lerpf(2.35, 2.0, low)
		for j in nu + 1:
			var th := float(j) / float(nu) * TAU
			var cs := cos(th)
			var sn := sin(th)
			if sn <= 0.0:
				continue
			var x := rx * signf(cs) * pow(absf(cs), 2.0 / pw)
			var z := oz + rz * pow(sn, 2.0 / pw)
			var fr := smoothstep(0.04, 0.09, z)
			z += 0.012 * exp(-pow(x / 0.012, 2.0)) * exp(-pow((y - y_nose) / 0.022, 2.0)) * fr
			for s in [-1.0, 1.0]:
				z -= 0.005 * exp(-pow((x - 0.035 * s) / 0.016, 2.0)) * exp(-pow((y - y_eye) / 0.012, 2.0)) * fr
			pts[r * st + j] = Vector3(x, y, z)
	face.pts = pts
	_project(face, func(v: Vector3, n: Vector3) -> Array:
		# Край лица берётся из кожи, а не из контура рисунка, поэтому шва на щеке нет
		var py := 1050.0 - (v.y + HEAD_Y) / PX
		var w := smoothstep(58.0, 72.0, py)
		var half := _row_half(py) * PX
		var a := half * 0.7
		var m := half * 0.88
		var ax := absf(v.x)
		var sx := ax if ax < a else a + (m - a) * tanh((ax - a) / (m - a))
		return [Vector3(signf(v.x) * (ax + (sx - ax) * w) - 1.5 * PX, v.y + HEAD_Y, v.z), n, 1.0])
	_put(ps, face, "head")
	# Уши отдельно: их рисунок берётся с бокового вида
	for s in [-1.0, 1.0]:
		var ear := SkinwalkerModel._sphere(16, 12)
		var tr := Transform3D(Basis(Vector3.UP, -0.28 * s) * Basis().scaled(Vector3(0.007, 0.027, 0.0145)), Vector3(0.076 * s, _top_y(96) - HEAD_Y, -0.0095))
		SkinwalkerModel._xf(ear, tr)
		_project(ear, func(v: Vector3, _n: Vector3) -> Array:
			return [Vector3(v.x, v.y + HEAD_Y, v.z), Vector3(s, 0.0, 0.0), 1.0])
		_put(ps, ear, "head")


static func _build_arm(ps: ProjSurf, side: float) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("sh" + sfx, "chest", Vector3(SHOULDER_X * side, 0.0, 0.0))
	_bone("el" + sfx, "sh" + sfx, Vector3(0.0, -0.28, 0.0))
	_bone("wr" + sfx, "el" + sfx, Vector3(0.0, -0.27, 0.0))
	_bone("hand" + sfx, "wr" + sfx, Vector3(0.0, 0.083, 0.0))
	var arm := SkinwalkerModel._loft([[.042, .01, .01], [.03, .024, .03], [.0, .04, .05], [-.1, .047, .052], [-.2, .048, .046], [-.28, .046, .044], [-.36, .044, .042], [-.42, .042, .039], [-.462, .039, .035], [-.472, .036, .032], [-.476, .01, .01]], 18, 4, Callable(), 1.0)
	_project(arm, func(v: Vector3, n: Vector3) -> Array:
		# В рисунке руки чуть отведены: при наложении учитываем этот наклон
		var k := maxf(0.0, -v.y) / 0.55
		return [Vector3(v.x + side * (SHOULDER_X + k * 0.043), v.y * 0.89 + HIP_Y + 0.4, v.z), n, 1.0])
	SkinwalkerModel._chain_weights(arm, [0.0, -0.28, -0.27], [_ids["sh" + sfx], _ids["el" + sfx], _ids["wr" + sfx]], 0.05, -1.0)
	_put(ps, arm, "sh" + sfx)
	# Кисть: рисунок с костяшками и пальцами
	var rings: Array = []
	for r in HAND_ROWS:
		rings.append([(525.0 - r[0]) * PX, (r[2] - r[1]) / 2.0 * PX, (r[4] - r[3]) / 2.0 * PX, -side * ((r[1] + r[2]) / 2.0 - 40.0) * PX, ((r[3] + r[4]) / 2.0 - 93.0) * PX])
	var fingers := func(th: float, y: float, _c: float, _s: float) -> float:
		return 0.0026 * sin(th * 7.0) * (1.0 - smoothstep(-0.115, -0.07, y))
	var hand := SkinwalkerModel._loft(rings, 28, 3, fingers, 1.0)
	_project(hand, func(v: Vector3, n: Vector3) -> Array:
		return [Vector3(v.x * 0.8 + side * 130.0 * PX, v.y + _top_y(525), v.z * 0.84 + 5.0 * PX), Vector3(n.x * 1.6, n.y, n.z), 1.0])
	_put(ps, hand, "hand" + sfx)


static func _build_leg(ps: ProjSurf, shoe, sole, side: float) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("th" + sfx, "hips", Vector3(LEG_X * side, -0.05, 0.0))
	_bone("kn" + sfx, "th" + sfx, Vector3(0.0, -THIGH, 0.0))
	_bone("an" + sfx, "kn" + sfx, Vector3(0.0, -SHIN, 0.0))
	var leg := SkinwalkerModel._loft([[.03, .01, .01], [.015, .056, .07], [-.06, .064, .09], [-.2, .062, .08, 0.0, .004], [-.34, .056, .066, 0.0, .004], [-.42, .056, .066, 0.0, .008], [-.5, .054, .06], [-.64, .05, .058], [-.76, .048, .052], [-.82, .05, .056], [-.84, .01, .01]], 20, 4, Callable(), 1.0)
	_project(leg, func(v: Vector3, n: Vector3) -> Array:
		var nz := n.z + (0.6 if n.z >= 0.0 else -0.6)
		# Рядом с бедром на боковом рисунке нарисована кисть, там берём только вид спереди
		var y := v.y + HIP_Y - 0.05
		var near_hand := smoothstep(_top_y(495), _top_y(520), y) * (1.0 - smoothstep(_top_y(610), _top_y(630), y))
		return [Vector3(clampf(v.x + side * LEG_X, -0.145, 0.145), y, v.z), Vector3(n.x * 0.18 * (1.0 - near_hand), n.y, nz), 1.0])
	SkinwalkerModel._chain_weights(leg, [0.0, -THIGH, -SHIN], [_ids["th" + sfx], _ids["kn" + sfx], _ids["an" + sfx]], 0.055, -1.0)
	_put(ps, leg, "th" + sfx)
	var along := Basis(Vector3.RIGHT, PI / 2.0)
	_put_plain(shoe, SkinwalkerModel._loft([[.045, .044, .05], [.01, .046, .056], [-.04, .05, .068, 0.0, .008]], 16, 3, Callable(), 0.6), "an" + sfx)
	_put_plain(shoe, SkinwalkerModel._loft([[-.075, .012, .012], [-.062, .044, .04], [.0, .047, .044], [.085, .05, .032], [.15, .05, .027], [.2, .038, .022], [.218, .01, .01]], 18, 4, Callable(), 0.7), "an" + sfx, Transform3D(along, Vector3(0.0, -0.038, 0.0)))
	_put_plain(sole, SkinwalkerModel._loft([[-.082, .012, .008], [-.07, .042, .009], [.0, .047, .009], [.09, .052, .009], [.16, .052, .009], [.205, .04, .009], [.222, .012, .007]], 14, 3, Callable(), 0.5), "an" + sfx, Transform3D(along, Vector3(0.0, -0.069, 0.0)))


static func _commit_proj(mesh: ArrayMesh, ps: ProjSurf, mat: Material) -> void:
	var sf = ps.sf
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = sf.v
	arr[Mesh.ARRAY_NORMAL] = sf.n
	arr[Mesh.ARRAY_TANGENT] = sf.tan
	arr[Mesh.ARRAY_TEX_UV] = sf.uv
	arr[Mesh.ARRAY_TEX_UV2] = ps.uv2
	arr[Mesh.ARRAY_COLOR] = sf.col
	arr[Mesh.ARRAY_BONES] = sf.bones
	arr[Mesh.ARRAY_WEIGHTS] = sf.weights
	arr[Mesh.ARRAY_INDEX] = sf.idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func _build_mesh() -> void:
	_bone_defs.clear()
	_globals.clear()
	_ids.clear()
	_bone("hips", "", Vector3(0.0, HIP_Y, 0.0))
	_bone("spineA", "hips", Vector3(0.0, 0.2, 0.0))
	_bone("chest", "spineA", Vector3(0.0, 0.2, 0.0))
	_bone("neck", "chest", Vector3(0.0, 0.13, 0.0))
	_bone("head", "neck", Vector3(0.0, 0.053, 0.0))

	var trunk := ProjSurf.new()
	var top := ProjSurf.new()
	var shoe = SkinwalkerModel.Surf.new()
	var sole = SkinwalkerModel.Surf.new()

	var torso := SkinwalkerModel._loft([[-.15, .01, .01], [-.14, .14, .09], [-.12, .158, .102], [-.024, .16, .112], [.11, .16, .112], [.253, .172, .118], [.33, .19, .116], [.385, .226, .11], [.44, .218, .097], [.5, .14, .085], [.54, .07, .06], [.555, .053, .049], [.565, .01, .01]], 44, 6, Callable(), 1.0)
	_project(torso, func(v: Vector3, n: Vector3) -> Array:
		var nz := n.z + (0.5 if n.z >= 0.0 else -0.5)
		return [Vector3(v.x, v.y + HIP_Y, v.z), Vector3(n.x * 0.3, n.y, nz), 1.0 - 0.28 * smoothstep(0.5, 0.545, v.y)])
	SkinwalkerModel._chain_weights(torso, [0.0, 0.2, 0.2], [_ids.hips, _ids.spineA, _ids.chest], 0.09, 1.0)
	_put(trunk, torso, "hips")

	var neck := SkinwalkerModel._loft([[-.04, .052, .047, 0.0, -.006], [.02, .047, .043, 0.0, -.005], [.1, .044, .04, 0.0, -.004]], 16, 2, Callable(), 1.0)
	_project(neck, func(v: Vector3, n: Vector3) -> Array:
		var y := v.y + HIP_Y + 0.53
		return [Vector3(v.x, y, v.z), n, 0.56 + 0.34 * smoothstep(_top_y(150), _top_y(185), y)])
	_put(top, neck, "neck")
	_build_head(top)
	_build_arm(top, -1.0)
	_build_arm(top, 1.0)
	_build_leg(trunk, shoe, sole, -1.0)
	_build_leg(trunk, shoe, sole, 1.0)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/player_sprite.gdshader")
	mat.set_shader_parameter("tex_front", load(TEX_PATH % "front"))
	mat.set_shader_parameter("tex_back", load(TEX_PATH % "back"))
	mat.set_shader_parameter("tex_left", load(TEX_PATH % "left"))
	mat.set_shader_parameter("tex_right", load(TEX_PATH % "right"))
	var shoe_mat := StandardMaterial3D.new()
	shoe_mat.albedo_color = Color(0.06, 0.06, 0.07)
	shoe_mat.roughness = 0.55
	var sole_mat := StandardMaterial3D.new()
	sole_mat.albedo_color = Color(0.02, 0.02, 0.02)
	sole_mat.roughness = 0.8

	_body_mesh = ArrayMesh.new()
	_commit_proj(_body_mesh, trunk, mat)
	SkinwalkerModel._commit(_body_mesh, shoe, shoe_mat)
	SkinwalkerModel._commit(_body_mesh, sole, sole_mat)
	_upper_mesh = ArrayMesh.new()
	_commit_proj(_upper_mesh, top, mat)
