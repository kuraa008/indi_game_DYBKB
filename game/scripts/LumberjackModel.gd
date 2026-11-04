extends Node3D
class_name LumberjackModel

# Процедурная 3D-модель лесоруба с двустволкой: цельная сетка на скелете и анимация из кода.
# Геометрия строится один раз и кэшируется. Лицо смотрит вдоль локальной +Z.
# Ружьё — отдельная кость груди, кисти держат его через двухзвенный IK.

const THIGH: float = 0.44
const SHIN: float = 0.44
const UPPER_ARM: float = 0.31
const FOREARM: float = 0.29
const BARREL: float = 0.72
const GRIP := Vector3(0, -0.03, -0.05)
const FORE := Vector3(0, -0.022, 0.2)
const POUCH := Vector3(0.2, -0.3, 0.14)
const SHOULDER_X: float = 0.185
const SHOULDER_Y: float = 0.085

const GUN_POSES := {
	"idle":   {"p": Vector3(0.13, -0.26, 0.2),   "r": Vector3(0.42, -0.62, 0.25)},
	"walk":   {"p": Vector3(0.13, -0.24, 0.2),   "r": Vector3(0.32, -0.58, 0.25)},
	"run":    {"p": Vector3(0.03, -0.1, 0.22),   "r": Vector3(-0.62, -0.98, 0.55)},
	"aim":    {"p": Vector3(0.135, 0.085, 0.17), "r": Vector3.ZERO},
	"reload": {"p": Vector3(0.1, -0.2, 0.24),    "r": Vector3(0.95, -0.4, 0.45)},
}
const GAITS := {
	"idle":   {"amp": 0.0,  "pitch": 0.04, "lean": 0.0,  "knee": 0.1,  "head": 0.0},
	"walk":   {"amp": 0.36, "pitch": 0.1,  "lean": 0.04, "knee": 0.16, "head": 0.0},
	"run":    {"amp": 0.56, "pitch": 0.24, "lean": 0.18, "knee": 0.36, "head": 0.0},
	"aim":    {"amp": 0.0,  "pitch": 0.14, "lean": 0.0,  "knee": 0.24, "head": 0.28},
	"reload": {"amp": 0.0,  "pitch": 0.22, "lean": 0.0,  "knee": 0.2,  "head": 0.32},
}

static var _mesh: ArrayMesh = null
static var _bone_defs: Array = []
static var _globals: Array[Transform3D] = []
static var _ids := {}
static var _rng := RandomNumberGenerator.new()

var rig: Node3D
var skeleton: Skeleton3D
var flash: MeshInstance3D
var phase := 0.0

var _b := {}
var _p := {}
var _mode := "idle"
var _t := 0.0
var _rate := 0.0
var _gp := Vector3(0.13, -0.26, 0.2)
var _gr := Vector3(0.42, -0.62, 0.25)
var _recoil := 0.0
var _rec_v := 0.0
var _flash_a := 0.0
var _reload_t := 0.0
var _look_yaw := 0.0


func _init() -> void:
	if _mesh == null:
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

	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh
	body.extra_cull_margin = 1.2
	# Слой 2: свет собственного фонарика не должен засвечивать самого лесоруба
	body.layers = 2
	skeleton.add_child(body)
	body.skeleton = NodePath("..")

	var gun_att := BoneAttachment3D.new()
	gun_att.bone_name = "gun"
	skeleton.add_child(gun_att)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.96, 0.82, 1.0))
	grad.set_color(1, Color(1.0, 0.35, 0.08, 0.0))
	grad.add_point(0.3, Color(1.0, 0.67, 0.27, 0.7))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_texture = gtex
	var quad := QuadMesh.new()
	quad.size = Vector2(0.6, 0.6)
	quad.material = mat
	flash = MeshInstance3D.new()
	flash.mesh = quad
	flash.position = Vector3(0, 0.012, 0.08 + BARREL + 0.1)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.visible = false
	gun_att.add_child(flash)

	_p = GAITS["idle"].duplicate()
	_apply(0.0)


# ══════════════════════════════════════════════
#  Публичное API
# ══════════════════════════════════════════════
func update_motion(delta: float, mode: String, move_speed: float) -> void:
	_mode = mode if GAITS.has(mode) else "idle"
	_t += delta
	var tg: Dictionary = GAITS[_mode]
	# Перезаряжая или целясь на ходу, он идёт ногами: руки заняты ружьём, ноги шагают
	if move_speed > 0.2 and _mode in ["aim", "reload", "idle"]:
		var legs: Dictionary = GAITS["run" if move_speed > 2.6 else "walk"]
		tg = tg.duplicate()
		tg["amp"] = legs["amp"]
		tg["knee"] = legs["knee"]
	var k := minf(1.0, delta * 4.0)
	for key in tg:
		_p[key] = lerpf(_p[key], tg[key], k)
	var target_rate := 0.0
	if move_speed > 0.2:
		# За половину цикла нога проходит 2 * длину ноги * sin(размаха): столько же проходит тело
		var stride := 2.0 * (THIGH + SHIN) * sin(maxf(float(_p["amp"]), 0.18))
		target_rate = minf(move_speed * PI / stride, 12.0)
	_rate = lerpf(_rate, target_rate, minf(1.0, delta * 8.0))
	phase += delta * _rate
	var gt: Dictionary = GUN_POSES[_mode]
	var gk := minf(1.0, delta * (7.0 if _mode == "aim" else 4.5))
	_gp = _gp.lerp(gt.p, gk)
	_gr = _gr.lerp(gt.r, gk)
	_rec_v += (-_recoil * 140.0 - _rec_v * 15.0) * minf(delta, 0.033)
	_recoil += _rec_v * minf(delta, 0.033)
	_flash_a = maxf(0.0, _flash_a - delta * (30.0 if _flash_a > 0.6 else 14.0))
	flash.visible = _flash_a > 0.05
	if flash.visible:
		flash.scale = Vector3.ONE * (0.6 + _flash_a * 0.6)
	_reload_t = _reload_t + delta if _mode == "reload" else 0.0
	_apply(delta)


func kick() -> void:
	_rec_v = 7.5
	_flash_a = 1.0


func set_look_target(world_point: Variant) -> void:
	var yaw := 0.0
	if world_point is Vector3:
		var local: Vector3 = global_transform.affine_inverse() * (world_point as Vector3)
		if local.z > 0.0:
			yaw = clampf(atan2(local.x, local.z), -0.9, 0.9)
	_look_yaw = lerp_angle(_look_yaw, yaw, 0.1)


func get_head_position() -> Vector3:
	var pose := skeleton.get_bone_global_pose(_b["head"])
	return skeleton.global_transform * (pose * Vector3(0, 0.11, 0.1))


func get_muzzle_position() -> Vector3:
	var pose := skeleton.get_bone_global_pose(_b["gun"])
	return skeleton.global_transform * (pose * Vector3(0, 0.012, 0.08 + BARREL + 0.05))


# ══════════════════════════════════════════════
#  Анимация
# ══════════════════════════════════════════════
func _rot(bone: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
	skeleton.set_bone_pose_rotation(_b[bone], Quaternion(Basis.from_euler(Vector3(x, y, z), EULER_ORDER_XYZ)))


# Двухзвенный IK. Возвращает суммарный поворот предплечья в осях груди.
func _ik(sfx: String, side: float, target: Vector3) -> Quaternion:
	var s_pos := Vector3(SHOULDER_X * side, SHOULDER_Y, 0.0)
	var v := target - s_pos
	var d := clampf(v.length(), 0.14, UPPER_ARM + FOREARM - 0.004)
	var dir := v.normalized()
	var a := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, UPPER_ARM * UPPER_ARM - a * a))
	var pole := Vector3(side * 0.55, -0.9, -0.3)
	pole = (pole - dir * pole.dot(dir)).normalized()
	var elbow := s_pos + dir * a + pole * h
	var wrist := s_pos + dir * d
	var u1 := (elbow - s_pos).normalized()
	var u2 := (wrist - elbow).normalized()
	var q1 := Quaternion(Vector3.DOWN, u1)
	var q2 := Quaternion(Vector3.DOWN, q1.inverse() * u2)
	skeleton.set_bone_pose_rotation(_b["sh" + sfx], q1)
	skeleton.set_bone_pose_rotation(_b["el" + sfx], q2)
	return q1 * q2


# Ставит запястье так, чтобы ладонь лежала на точке хвата, и поворачивает кисть
func _grip(sfx: String, side: float, point: Vector3, hand: Basis) -> void:
	var wrist := point + hand.y * 0.055 - hand.z * 0.026
	var fore_q := _ik(sfx, side, wrist)
	skeleton.set_bone_pose_rotation(_b["hand" + sfx], fore_q.inverse() * Quaternion(hand.orthonormalized()))

func _apply(_delta: float) -> void:
	var amp: float = _p["amp"]
	var knee: float = _p["knee"]
	var lean: float = _p["lean"]
	var head_aim: float = _p["head"]
	var s := sin(phase)
	var c := cos(phase)
	var k := minf(1.0, _rate / 2.6)
	var br := sin(_t * 1.4)

	var pitch: float = float(_p["pitch"]) + lean + br * 0.006 + absf(s) * 0.012 * k
	var lth := -s * amp - lean * 0.5 - knee * 0.42
	var rth := s * amp - lean * 0.5 - knee * 0.42
	var lkn := knee + amp * 1.3 * pow(maxf(0.0, c), 1.3)
	var rkn := knee + amp * 1.3 * pow(maxf(0.0, -c), 1.3)
	var drop_l := THIGH * cos(lth) + SHIN * cos(lth + lkn)
	var drop_r := THIGH * cos(rth) + SHIN * cos(rth + rkn)
	skeleton.set_bone_pose_position(_b["hips"], Vector3(s * 0.03 * k, maxf(drop_l, drop_r) + 0.135, 0.0))
	_rot("hips", 0.0, s * 0.11 * k, -s * 0.05 * k)

	var twist := -s * 0.13 * k
	if _mode == "aim":
		twist -= 0.22
	elif _mode == "reload":
		twist += 0.1
	var roll := s * 0.026 * k
	_rot("spineA", pitch * 0.55, twist * 0.5, roll * 0.5)
	_rot("chest", pitch * 0.45 - _recoil * 0.5, twist * 0.5, roll * 0.5)

	_rot("thL", lth, 0.0, -0.04)
	_rot("thR", rth, 0.0, 0.04)
	_rot("knL", lkn)
	_rot("knR", rkn)
	_rot("anL", -(lth + lkn) + maxf(0.0, c) * amp * 0.25)
	_rot("anR", -(rth + rkn) + maxf(0.0, -c) * amp * 0.25)

	# Голова оглядывается на ходу, в прицеле ложится на приклад
	var aim_w := smoothstep(0.1, 0.28, head_aim)
	var scan := 0.0
	if _mode == "idle":
		scan = sin(_t * 0.35) * 0.42 + sin(_t * 1.1) * 0.05
	elif _mode == "walk":
		scan = sin(_t * 0.55) * 0.26
	_rot("neck", -pitch * 0.75 + 0.05 + head_aim * 0.45)
	_rot("head", -0.02 + br * 0.004 - aim_w * 0.1, (scan + _look_yaw) * (1.0 - aim_w) - twist * (1.0 - aim_w) + aim_w * 0.3, -aim_w * 0.2 + sin(_t * 0.7) * 0.018)

	# Ружьё и кисти
	var gun_pos := Vector3(_gp.x, _gp.y + _recoil * 0.05 + s * 0.012 * k, _gp.z - _recoil * 0.17)
	var gun_rot := Vector3(_gr.x - _recoil, _gr.y, _gr.z)
	var gun_basis := Basis.from_euler(gun_rot, EULER_ORDER_XYZ)
	skeleton.set_bone_pose_position(_b["gun"], gun_pos)
	skeleton.set_bone_pose_rotation(_b["gun"], Quaternion(gun_basis))
	var gun_t := Transform3D(gun_basis, gun_pos)
	var grip := gun_t * GRIP
	var fore := gun_t * FORE
	if _mode == "reload":
		var u := fmod(_reload_t, 3.0) / 3.0
		fore = fore.lerp(POUCH, smoothstep(0.1, 0.32, u) * (1.0 - smoothstep(0.62, 0.84, u)))
	var gx := gun_basis.x
	var gy := gun_basis.y
	# Правая ладонь справа на шейке приклада, пальцы вниз; левая снизу под цевьём
	var right_hand := Basis(gy.cross(-gx), gy, -gx)
	var left_hand := Basis((-gx).cross(gy), -gx, gy)
	_grip("R", 1.0, grip, right_hand)
	_grip("L", -1.0, fore, left_hand)

# ══════════════════════════════════════════════
#  Постройка геометрии (использует лофт из SkinwalkerModel)
# ══════════════════════════════════════════════
static func _bone(bname: String, parent: String, pos: Vector3) -> void:
	var pid: int = _ids[parent] if parent != "" else -1
	var rest := Transform3D(Basis(), pos)
	_ids[bname] = _bone_defs.size()
	_bone_defs.append({"name": bname, "parent": pid, "rest": rest})
	_globals.append(_globals[pid] * rest if pid >= 0 else rest)


static func _G(bname: String) -> Transform3D:
	return _globals[_ids[bname]]


# Рисует уже посчитанную сетку в поверхность, привязав к одной кости
static func _put(sf, geo: Dictionary, bone: String, local: Transform3D = Transform3D(), tint: Color = Color.WHITE) -> void:
	SkinwalkerModel._add(sf, SkinwalkerModel._xf(geo, _G(bone) * local), _ids[bone], tint)


static func _loft(rings: Array, nu: int, ps: int, disp: Callable = Callable(), uvk: float = 1.0) -> Dictionary:
	return SkinwalkerModel._loft(rings, nu, ps, disp, uvk)


# Сфера нужного масштаба
static func _ball(sc: Vector3) -> Dictionary:
	var g := SkinwalkerModel._sphere(12, 8)
	return SkinwalkerModel._xf(g, Transform3D(Basis().scaled(sc), Vector3.ZERO))


# Прямоугольник как короткий лофт с квадратным сечением
static func _box(w: float, h: float, d: float) -> Dictionary:
	var e := 0.0002
	var g := _loft([[-h * 0.5 - e, 0.0, 0.0], [-h * 0.5, 0.707, 0.707], [h * 0.5, 0.707, 0.707], [h * 0.5 + e, 0.0, 0.0]], 4, 1)
	var bas := Basis().scaled(Vector3(w, 1.0, d)) * Basis(Vector3.UP, PI * 0.25)
	return SkinwalkerModel._xf(g, Transform3D(bas, Vector3.ZERO))


# Цилиндр вдоль +Z от начала координат
static func _tube(r0: float, r1: float, l: float, nu: int = 10) -> Dictionary:
	var g := _loft([[0.0, r0, r0], [0.0005, r0, r0], [l - 0.0005, r1, r1], [l, r1, r1]], nu, 1)
	return SkinwalkerModel._xf(g, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO))


static func _plaid_tex(size: int, henley: bool) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var red := Color(0.33, 0.07, 0.06)
	var black := Color(0.035, 0.028, 0.03)
	var mid := Color(0.15, 0.035, 0.03)
	var st := size / 12
	for y in size:
		var row := (y / st) % 2 == 0
		for x in size:
			var col_ := (x / st) % 2 == 0
			var c: Color = black if (row and col_) else (mid if (row or col_) else red)
			var thread := (x % st == st / 2) or (y % st == st / 2)
			if thread:
				c = c.lerp(Color(0.5, 0.4, 0.33), 0.16)
			var n := _rng.randf_range(-0.012, 0.012)
			img.set_pixel(x, y, Color(c.r + n, c.g + n, c.b + n))
	if henley:
		# Тёмная кофта в распахнутом вороте рубашки (спереди, u = 0.25)
		var w := int(size * 0.034)
		for y in size:
			for x in range(size / 4 - w, size / 4 + w):
				var edge := absi(x - size / 4) >= w - 2
				img.set_pixel(x, y, Color(0.008, 0.007, 0.006) if edge else Color(0.045, 0.036, 0.028))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _rib_tex() -> ImageTexture:
	var img := Image.create(128, 16, false, Image.FORMAT_RGB8)
	for y in 16:
		for x in 128:
			var dark := (x % 8) < 3
			img.set_pixel(x, y, Color(0.20, 0.07, 0.02) if dark else Color(0.44, 0.15, 0.04))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _noise_mat(c0: Color, c1: Color, freq: float, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var ramp := Gradient.new()
	ramp.set_color(0, c0)
	ramp.set_color(1, c1)
	var tex := SkinwalkerModel._noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, freq, false)
	tex.color_ramp = ramp
	m.albedo_texture = tex
	m.roughness = rough
	m.metallic = metal
	return m


static func _tex_mat(tex: Texture2D, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.roughness = rough
	return m


static func _build_mesh() -> void:
	_bone_defs.clear()
	_globals.clear()
	_ids.clear()
	_rng.seed = 271828

	_bone("hips", "", Vector3(0, 0.97, 0))
	_bone("spineA", "hips", Vector3(0, 0.2, 0))
	_bone("chest", "spineA", Vector3(0, 0.2, 0))
	_bone("neck", "chest", Vector3(0, 0.2, 0))
	_bone("head", "neck", Vector3(0, 0.1, 0))
	_bone("gun", "chest", Vector3(0.13, -0.26, 0.2))

	var shirt = SkinwalkerModel.Surf.new()
	var sleeve = SkinwalkerModel.Surf.new()
	var jeans = SkinwalkerModel.Surf.new()
	var boot = SkinwalkerModel.Surf.new()
	var skin = SkinwalkerModel.Surf.new()
	var beanie = SkinwalkerModel.Surf.new()
	var wood = SkinwalkerModel.Surf.new()
	var metal = SkinwalkerModel.Surf.new()
	var misc = SkinwalkerModel.Surf.new()
	var hair = SkinwalkerModel.Surf.new()

	# ── Таз и рубашка ──
	_put(jeans, _loft([[-.17, .01, .01], [-.15, .09, .08], [-.08, .165, .115], [.02, .18, .125], [.08, .178, .123], [.12, .16, .11]], 20, 3, Callable(), 1.4), "hips")
	var sh := _loft([[-.13, .2, .145], [-.08, .195, .14], [.0, .19, .135], [.1, .183, .128], [.2, .188, .13], [.3, .2, .134], [.4, .214, .133], [.47, .214, .122], [.52, .185, .106], [.56, .105, .08], [.6, .058, .058]], 32, 4, _shirt_disp)
	SkinwalkerModel._chain_weights(sh, [0.0, 0.2, 0.2], [_ids.hips, _ids.spineA, _ids.chest], 0.09, 1.0)
	SkinwalkerModel._xf(sh, _G("hips"))
	SkinwalkerModel._add(shirt, sh)

	# ── Детали торса ──
	var dark_belt := Color(0.05, 0.028, 0.018)
	_put(misc, _loft([[.01, .183, .128], [.03, .185, .13], [.075, .185, .13], [.095, .183, .128]], 24, 2), "hips", Transform3D(), dark_belt)
	_put(misc, _box(.062, .05, .012), "hips", Transform3D(Basis(), Vector3(0, .055, .132)), Color(0.32, 0.22, 0.08))
	_put(misc, _box(.042, .03, .016), "hips", Transform3D(Basis(), Vector3(0, .055, .133)), dark_belt)
	var yaw_p := Basis(Vector3.UP, -0.25)
	_put(misc, _box(.075, .1, .05), "hips", Transform3D(yaw_p, Vector3(.2, -.02, .02)), Color(0.012, 0.011, 0.006))
	_put(misc, _box(.08, .03, .056), "hips", Transform3D(yaw_p, Vector3(.2, .03, .02)), dark_belt)
	# Нож в ножнах и моток верёвки
	_put(wood, _box(.022, .055, .03), "hips", Transform3D(Basis(), Vector3(-.195, .04, .03)))
	var blade := _loft([[0.0, .016, .0025], [-.15, .017, .0025], [-.21, .01, .002], [-.235, .001, .001]], 8, 2)
	_put(metal, blade, "hips", Transform3D(Basis(Vector3.BACK, -0.1), Vector3(-.195, .012, .03)))
	for s in [-1.0, 1.0]:
		var yaw_c := Basis(Vector3.UP, 0.34 * s)
		_put(sleeve, _box(.092, .098, .012), "chest", Transform3D(yaw_c, Vector3(.1 * s, .06, .127)))
		_put(sleeve, _box(.098, .032, .016), "chest", Transform3D(yaw_c, Vector3(.1 * s, .1, .129)))
		_put(misc, _ball(Vector3.ONE * .006), "chest", Transform3D(Basis(), Vector3(.1 * s, .1, .14)), Color(0.02, 0.015, 0.012))
		_put(sleeve, _box(.06, .09, .008), "neck", Transform3D(Basis.from_euler(Vector3(.18, 0, .5 * s)), Vector3(.042 * s, -.055, .075)))
	for i in 5:
		var bone := "chest" if i < 3 else "spineA"
		var y := .13 - i * .085 if i < 3 else .14 - (i - 3) * .09
		_put(misc, _ball(Vector3.ONE * .0068), bone, Transform3D(Basis(), Vector3(0, y, .118)), Color(0.02, 0.015, 0.012))

	# ── Шея, воротник, голова ──
	_put(skin, _loft([[-.03, .058, .058], [.1, .05, .05]], 12, 2), "neck", Transform3D(Basis(), Vector3(0, 0, .002)))
	_put(sleeve, _loft([[.0, .08, .074], [.035, .07, .066], [.07, .066, .062]], 16, 2, Callable(), .5), "neck", Transform3D(Basis(), Vector3(0, -.04, 0)))
	_build_head(skin, beanie, misc, hair)

	for side in [-1.0, 1.0]:
		_build_arm(side, sleeve, skin)
		_build_leg(side, jeans, boot, misc)
	_build_gun(wood, metal, misc)

	var mesh := ArrayMesh.new()
	SkinwalkerModel._commit(mesh, shirt, _tex_mat(_plaid_tex(256, true), 0.95))
	SkinwalkerModel._commit(mesh, sleeve, _tex_mat(_plaid_tex(128, false), 0.95))
	var jm := _noise_mat(Color(0.012, 0.016, 0.02), Color(0.05, 0.055, 0.058), 0.018, 0.96)
	SkinwalkerModel._commit(mesh, jeans, jm)
	SkinwalkerModel._commit(mesh, boot, _noise_mat(Color(0.03, 0.016, 0.009), Color(0.11, 0.065, 0.035), 0.025, 0.72))
	var skin_m := _noise_mat(Color(0.42, 0.23, 0.16), Color(0.56, 0.33, 0.24), 0.04, 0.7)
	skin_m.vertex_color_use_as_albedo = true
	SkinwalkerModel._commit(mesh, skin, skin_m)
	SkinwalkerModel._commit(mesh, beanie, _tex_mat(_rib_tex(), 0.98))
	var wood_m := _noise_mat(Color(0.05, 0.022, 0.009), Color(0.17, 0.08, 0.03), 0.03, 0.55)
	(wood_m.albedo_texture.noise as FastNoiseLite).frequency = 0.05
	SkinwalkerModel._commit(mesh, wood, wood_m)
	SkinwalkerModel._commit(mesh, metal, _noise_mat(Color(0.03, 0.03, 0.033), Color(0.11, 0.07, 0.05), 0.04, 0.5, 0.72))
	var misc_m := StandardMaterial3D.new()
	misc_m.vertex_color_use_as_albedo = true
	misc_m.roughness = 0.9
	SkinwalkerModel._commit(mesh, misc, misc_m)
	var hair_m := StandardMaterial3D.new()
	hair_m.vertex_color_use_as_albedo = true
	hair_m.roughness = 1.0
	hair_m.metallic_specular = 0.1
	hair_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	SkinwalkerModel._commit(mesh, hair, hair_m)
	_mesh = mesh


static func _shirt_disp(th: float, y: float, _c: float, s: float) -> float:
	var d := 0.004 * sin(th * 6.0 + y * 16.0) * smoothstep(0.3, -0.1, y) + 0.0025 * sin(y * 38.0 + th * 3.0)
	if y < -0.05:
		d += 0.006 * sin(th * 17.0 + 1.3) * smoothstep(-0.05, -0.13, y)
	var fd := SkinwalkerModel._ang(th, PI / 2.0)
	if y > 0.05 and y < 0.5:
		d -= 0.006 * exp(-(fd * fd) / 0.05)
	d += 0.022 * pow(maxf(0.0, s), 1.5) * exp(-pow((y - 0.03) / 0.11, 2.0))
	return d


static func _build_head(skin, beanie, misc, hair) -> void:
	var face := _loft([[-.075, .006, .006, 0, .012], [-.07, .04, .05, 0, .012], [-.04, .062, .076, 0, .01], [.0, .072, .09, 0, .006], [.05, .08, .098, 0, .002], [.1, .087, .103, 0, -.002], [.15, .09, .105, 0, -.006], [.2, .082, .098, 0, -.012], [.235, .05, .066, 0, -.016], [.25, .006, .006, 0, -.018]], 48, 5, Callable(), .6)
	var pts: PackedVector3Array = face.pts
	var cols := PackedColorArray()
	var center := Vector3(0, .08, 0)
	var gs := SkinwalkerModel._gs
	for i in pts.size():
		var p := pts[i]
		var d := 0.0
		var dark := 0.0
		for s in [-1.0, 1.0]:
			var so: float = gs.call(p, Vector3(.035 * s, .085, .094), .021)
			d -= .018 * so
			dark = maxf(dark, so * .8)
			d += .004 * float(gs.call(p, Vector3(.05 * s, .105, .095), .016))
			d += .008 * float(gs.call(p, Vector3(.055 * s, .048, .075), .022))
			d -= .006 * float(gs.call(p, Vector3(.068 * s, .145, .07), .022))
			d += .004 * float(gs.call(p, Vector3(.012 * s, .022, .102), .008))
		var front := smoothstep(.05, .09, p.z)
		d += .016 * exp(-pow(p.x / .0105, 2.0)) * exp(-pow((p.y - .06) / .032, 2.0)) * front
		d += .012 * float(gs.call(p, Vector3(0, .035, .108), .012))
		var ax := absf(p.x)
		var yb := .092 + .32 * ax
		d += .0125 * exp(-pow((p.y - yb) / .0085, 2.0)) * smoothstep(.075, .05, ax) * front
		dark = maxf(dark, exp(-pow((p.y - (yb - .012)) / .005, 2.0)) * smoothstep(.075, .05, ax) * front * .55)
		var nl := exp(-pow((ax - (.024 + (.055 - p.y) * .32)) / .0035, 2.0)) * smoothstep(.0, .015, p.y) * smoothstep(.07, .05, p.y) * front
		dark = maxf(dark, nl * .5)
		var fr := exp(-pow(ax / .0035, 2.0)) * smoothstep(.09, .1, p.y) * smoothstep(.125, .11, p.y) * smoothstep(.07, .09, p.z)
		dark = maxf(dark, fr * .55)
		d -= .007 * float(gs.call(p, Vector3(0, .118, .105), .012))
		p += (p - center).normalized() * d
		pts[i] = p
		var v := 1.0 - minf(1.0, dark)
		v *= lerpf(0.2, 1.0, smoothstep(-.03, .03, p.z))
		cols.append(Color(v, v, v))
	face.pts = pts
	face.col = cols

	# Передняя поверхность лица в сетке 2 см: поиск прядей не перебирает все вершины
	var z_grid := {}
	for q in pts:
		if q.z < 0.0:
			continue
		var cell := Vector2i(roundi(q.x / 0.02), roundi(q.y / 0.02))
		if q.z > float(z_grid.get(cell, -1.0)):
			z_grid[cell] = q.z
	var surf_z := func(x: float, y: float) -> float:
		return float(z_grid.get(Vector2i(roundi(x / 0.02), roundi(y / 0.02)), 0.09))

	var eye_w := Color(0.2, 0.17, 0.14)
	var iris := Color(0.012, 0.008, 0.006)
	for s in [-1.0, 1.0]:
		var ez: float = surf_z.call(.035 * s, .085)
		_put(misc, _ball(Vector3(.0118, .0068, .0072)), "head", Transform3D(Basis(), Vector3(.035 * s, .083, ez - .0042)), eye_w)
		var lid_t := Transform3D(Basis(Vector3.BACK, .22 * s), Vector3(.035 * s, .0925, ez - .004))
		_put(skin, _ball(Vector3(.0145, .0062, .0092)), "head", lid_t)
		_put(misc, _ball(Vector3(.0052, .0052, .0022)), "head", Transform3D(Basis(), Vector3(.033 * s, .0825, ez + .0026)), iris)

	# Борода, усы, брови и волосы: пряди из маленьких трубок, одной поверхностью
	var positions := face.pts as PackedVector3Array
	var add := func(p0: Vector3, dv: Vector3, bv: Vector3, l: float, w: float) -> void:
		var r := _rng.randf()
		var g := (_rng.randf_range(.03, .07) if r < .25 else (_rng.randf_range(.12, .22) if r < .75 else _rng.randf_range(.26, .38)))
		_strand(hair, p0, dv, bv, l, w, Color(g, g * .92, g * .82))
	for n in 700:
		var q := positions[_rng.randi_range(0, positions.size() - 1)]
		if q.z < -.015:
			continue
		var beard_ok := q.y < .03 and not (absf(q.x) < .024 and q.y > .014 and q.z > .085)
		var side_ok := q.y < .07 and q.y >= .03 and absf(q.x) > .054 and q.z > -.01
		if not beard_ok and not side_ok:
			continue
		var l := _rng.randf_range(.05, .11) * (1.45 if q.y < -.01 else 1.0)
		add.call(q, Vector3(q.x * .4 + _rng.randf_range(-.14, .14), -.72, .3 + _rng.randf_range(-.1, .14)), Vector3(_rng.randf_range(-.08, .08), -.26, -.12), l, _rng.randf_range(.0028, .0046))
	for n in 110:
		var s := -1.0 if _rng.randf() < .5 else 1.0
		var x := s * _rng.randf_range(.003, .047)
		var z: float = surf_z.call(x, .02)
		add.call(Vector3(x, .0235 - absf(x) * .08, z + .003), Vector3(s * .5, -.55, .18), Vector3(s * .05, -.2, 0), _rng.randf_range(.024, .042), _rng.randf_range(.0014, .0024))
	for n in 90:
		var s := -1.0 if _rng.randf() < .5 else 1.0
		var x := s * _rng.randf_range(.008, .066)
		var yb := .092 + .32 * absf(x) + _rng.randf_range(-.004, .006)
		var z: float = surf_z.call(x, yb)
		add.call(Vector3(x, yb, z + .0015), Vector3(s * .75, .28, .4), Vector3(0, -.25, -.1), _rng.randf_range(.013, .024), _rng.randf_range(.0012, .002))
	for n in 300:
		var a := _rng.randf_range(.95, PI) * (1.0 if _rng.randf() < .5 else -1.0) + PI / 2.0
		var x := cos(a) * .09
		var z := sin(a) * .1 - .008
		add.call(Vector3(x, _rng.randf_range(.09, .15), z), Vector3(x * 2.2, -.8, z * .8), Vector3(0, -.3, -.05), _rng.randf_range(.05, .11), _rng.randf_range(.0028, .0046))

	_put(skin, face, "head")
	var fuzz := func(th: float, y: float, _c: float, _s: float) -> float:
		return .004 * sin(th * 9.0 + y * 40.0) + .003 * sin(th * 23.0 - y * 70.0)
	var beard_vol := _loft([[.025, .06, .044, 0, .044], [.0, .066, .052, 0, .048], [-.05, .066, .056, 0, .052], [-.11, .05, .046, 0, .056], [-.155, .03, .03, 0, .058], [-.185, .01, .012, 0, .06]], 20, 3, fuzz, .6)
	var vol_pts: PackedVector3Array = beard_vol.pts
	for n in 900:
		var q := vol_pts[_rng.randi_range(0, vol_pts.size() - 1)]
		if q.z < .005:
			continue
		add.call(q, Vector3((q.x * 1.2) + _rng.randf_range(-.08, .08), -.85, (q.z - .05) * .6), Vector3(_rng.randf_range(-.05, .05), -.2, -.05), _rng.randf_range(.035, .085), _rng.randf_range(.0028, .0048))
	_put(misc, beard_vol, "head", Transform3D(), Color(0.022, 0.02, 0.017))

	# Шапка
	var rib := func(th: float, _y: float, _c: float, _s: float) -> float:
		return .0016 * sin(th * 32.0)
	_put(beanie, _loft([[.135, .1, .116, 0, -.008], [.165, .1, .117, 0, -.01], [.205, .096, .112, 0, -.012], [.245, .08, .094, 0, -.016], [.272, .052, .062, 0, -.018], [.285, .01, .01, 0, -.018]], 32, 3, rib, 3.0), "head")
	var rib2 := func(th: float, _y: float, _c: float, _s: float) -> float:
		return .0018 * sin(th * 48.0)
	_put(beanie, _loft([[.112, .1, .117, 0, -.006], [.118, .109, .126, 0, -.006], [.15, .111, .128, 0, -.008], [.172, .106, .122, 0, -.009], [.178, .09, .108, 0, -.01]], 40, 2, rib2, 3.0), "head")


# Одна прядь: три сегмента по изогнутой линии, треугольное сечение
static func _strand(sf, p0: Vector3, dv: Vector3, bv: Vector3, l: float, w: float, col: Color) -> void:
	var head_t := _G("head")
	var base: int = sf.v.size()
	var segs := 2
	for i in segs + 1:
		var t := float(i) / float(segs)
		var cw := w * (1.0 - t * 0.92)
		var c := p0 + dv * t * l + bv * t * t * l
		for j in 3:
			var a := float(j) / 3.0 * TAU
			var nrm := Vector3(cos(a), 0.0, sin(a))
			sf.v.append(head_t * (c + nrm * cw))
			sf.n.append(head_t.basis * nrm)
			sf.tan.append_array([1.0, 0.0, 0.0, 1.0])
			sf.uv.append(Vector2(0.0, 0.0))
			sf.col.append(col)
			sf.bones.append_array([_ids.head, 0, 0, 0])
			sf.weights.append_array([1.0, 0.0, 0.0, 0.0])
	for i in segs:
		for j in 3:
			var a := base + i * 3 + j
			var c := base + i * 3 + (j + 1) % 3
			var d := a + 3
			var e := c + 3
			sf.idx.append_array([a, c, d, c, e, d])


static func _build_arm(side: float, sleeve, skin) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("sh" + sfx, "chest", Vector3(SHOULDER_X * side, SHOULDER_Y, 0))
	_bone("el" + sfx, "sh" + sfx, Vector3(0, -UPPER_ARM, 0))
	_bone("wr" + sfx, "el" + sfx, Vector3(0, -FOREARM, 0))
	_bone("hand" + sfx, "wr" + sfx, Vector3(0, -0.01, 0))
	var disp := func(th: float, y: float, _c: float, _s: float) -> float:
		return .002 * sin(th * 5.0 + y * 30.0)
	var g := _loft([[.05, .012, .012], [.035, .036, .042], [.0, .056, .06], [-.1, .06, .062], [-.2, .061, .058], [-.3, .054, .052], [-.33, .056, .052], [-.42, .052, .046], [-.52, .043, .036], [-.58, .047, .041], [-.6, .05, .044], [-.61, .012, .01]], 16, 3, disp, 1.3)
	SkinwalkerModel._chain_weights(g, [0.0, -UPPER_ARM, -FOREARM], [_ids["sh" + sfx], _ids["el" + sfx], _ids["wr" + sfx]], .05, -1.0)
	SkinwalkerModel._xf(g, _G("sh" + sfx))
	SkinwalkerModel._add(sleeve, g)
	var hb := "hand" + sfx
	_put(skin, _loft([[.01, .018, .018], [-.03, .038, .019], [-.075, .043, .018], [-.092, .036, .014]], 10, 2, Callable(), .4), hb)
	for i in 4:
		var x := (i - 1.5) * .021
		var t0 := Transform3D(Basis(Vector3.RIGHT, -1.2), Vector3(x, -.09, 0))
		_put(skin, _finger(.038, .0095), hb, t0)
		var t1 := t0 * Transform3D(Basis(Vector3.RIGHT, -1.05), Vector3(0, -.038, 0))
		_put(skin, _finger(.028, .0086), hb, t1)
		var t2 := t1 * Transform3D(Basis(Vector3.RIGHT, -.75), Vector3(0, -.028, 0))
		_put(skin, _finger(.022, .0078), hb, t2)
	var th_t := Transform3D(Basis.from_euler(Vector3(-.9, 0, .8 * side)), Vector3(.03 * side, -.035, .012))
	_put(skin, _loft([[.004, .011, .011], [-.025, .01, .01], [-.05, .0085, .0085]], 7, 2, Callable(), .3), hb, th_t)


static func _finger(l: float, r: float) -> Dictionary:
	return _loft([[.003, r, r], [-l / 2.0, r * .92, r * .92], [-l, r * .95, r * .95]], 7, 1, Callable(), .3)


static func _build_leg(side: float, jeans, boot, misc) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("th" + sfx, "hips", Vector3(.098 * side, -.05, 0))
	_bone("kn" + sfx, "th" + sfx, Vector3(0, -THIGH, 0))
	_bone("an" + sfx, "kn" + sfx, Vector3(0, -SHIN, 0))
	var disp := func(th: float, y: float, _c: float, _s: float) -> float:
		return .003 * sin(th * 6.0 + y * 24.0) + (.0025 * sin(th * 11.0) if y < -.74 else 0.0)
	var g := _loft([[.08, .012, .012], [.055, .088, .092], [-.04, .106, .118], [-.2, .083, .09, 0, .006], [-.36, .067, .07, 0, .008], [-.44, .068, .074, 0, .014], [-.52, .066, .07, 0, .002], [-.66, .066, .074, 0, -.006], [-.78, .063, .066], [-.84, .066, .068], [-.86, .012, .012]], 18, 3, disp)
	SkinwalkerModel._chain_weights(g, [0.0, -THIGH, -SHIN], [_ids["th" + sfx], _ids["kn" + sfx], _ids["an" + sfx]], .055, -1.0)
	SkinwalkerModel._xf(g, _G("th" + sfx))
	SkinwalkerModel._add(jeans, g)
	var ab := "an" + sfx
	_put(boot, _loft([[.16, .06, .064], [.1, .056, .062], [.03, .054, .066], [-.03, .056, .076, 0, .006], [-.06, .058, .08, 0, .012]], 14, 2, Callable(), .7), ab)
	var f := _loft([[-.085, .012, .012], [-.07, .052, .046], [.0, .058, .052], [.08, .062, .044], [.145, .064, .04], [.195, .054, .033], [.222, .01, .01]], 14, 3, Callable(), .8)
	_put(boot, f, ab, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -.04, 0)))
	var sole := _loft([[-.09, .02, .01], [-.075, .05, .012], [.0, .058, .012], [.09, .064, .012], [.165, .066, .012], [.205, .054, .012], [.225, .02, .01]], 14, 2)
	_put(misc, sole, ab, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -.076, 0)), Color(0.008, 0.006, 0.005))
	for i in 5:
		_put(misc, _box(.083, .004, .005), ab, Transform3D(Basis(), Vector3(0, .11 - i * .034, .066 + .004 * i)), Color(0.02, 0.015, 0.008))


static func _build_gun(wood, metal, misc) -> void:
	for s in [-1.0, 1.0]:
		_put(metal, _tube(.0125, .0115, BARREL), "gun", Transform3D(Basis(), Vector3(.0118 * s, .012, .08)))
		_put(misc, _tube(.0075, .0075, .003), "gun", Transform3D(Basis(), Vector3(.0118 * s, .012, .08 + BARREL)), Color.BLACK)
		_put(metal, _box(.007, .022, .012), "gun", Transform3D(Basis(Vector3.RIGHT, -.5), Vector3(.016 * s, .034, -.03)))
	_put(metal, _box(.004, .004, BARREL - .02), "gun", Transform3D(Basis(), Vector3(0, .025, .08 + BARREL * .5)))
	_put(metal, _box(.046, .052, .13), "gun", Transform3D(Basis(), Vector3(0, .002, .02)))
	var to_z := Basis(Vector3.RIGHT, PI / 2.0)
	_put(wood, _loft([[-.01, .021, .019], [.05, .024, .022], [.14, .023, .02], [.215, .02, .016], [.225, .006, .006]], 10, 2, Callable(), .8), "gun", Transform3D(to_z, Vector3(0, -.009, .1)))
	var stock := _loft([[.0, .019, .024], [.08, .018, .025], [.15, .019, .032], [.25, .021, .043], [.335, .024, .053], [.36, .024, .051], [.362, .006, .006]], 12, 2)
	var back := Basis(Vector3.RIGHT, -.27) * Basis(Vector3.RIGHT, -PI / 2.0)
	_put(wood, stock, "gun", Transform3D(back, Vector3(0, -.012, -.04)))
	_put(misc, _box(.05, .108, .008), "gun", Transform3D(Basis(Vector3.RIGHT, -.27), Vector3(0, -.108, -.391)), Color(0.008, 0.006, 0.005))
	_put(metal, _box(.003, .024, .004), "gun", Transform3D(Basis(), Vector3(0, -.033, -.012)))
	_put(metal, _box(.004, .004, .04), "gun", Transform3D(Basis(), Vector3(0, -.046, -.012)))
