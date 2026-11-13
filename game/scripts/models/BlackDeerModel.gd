class_name BlackDeerModel
extends "res://scripts/models/SculptKit.gd"

# Чёрный олень для аварии и финала, по пропорциям благородного оленя-самца.
# Туловище с глубокой грудью, высокой холкой, подтянутым животом и круглым крупом;
# лопатки и окорока выпирают. Толстая шея с гривой, голова клином вниз, большие уши.
# Ноги с настоящими суставами: локоть, запястье, путовый сустав, бабка; сзади колено
# и скакательный сустав с пяточным бугром. Раздвоенные копыта и шпоры.
# Рога ветвистые: надглазный, второй и средний отростки и корона из трёх концов.
# Глаза человеческие: белки, карая радужка и зрачок. Смотрит вдоль +Z, стоит на нуле.
# height — полная высота вместе с рогами.

const FUR := Color(0.045, 0.04, 0.036)
const FULL := 2.6

var height := 2.3
var eyes: Node3D
var eye_points: Array[Vector3] = []


# ═══ Туловище: от крупа (t = 0) к груди (t = 1), голова в сторону -Z ═══

const TOP := [[0.0, 1.12], [0.06, 1.2], [0.18, 1.235], [0.4, 1.185], [0.62, 1.19], [0.8, 1.25], [0.9, 1.285], [1.0, 1.2]]
const BOTTOM := [[0.0, 1.06], [0.05, 0.96], [0.14, 0.9], [0.3, 0.925], [0.5, 0.865], [0.7, 0.8], [0.86, 0.79], [0.96, 0.88], [1.0, 1.04]]
const WIDTH := [[0.0, 0.05], [0.05, 0.18], [0.14, 0.225], [0.3, 0.21], [0.5, 0.24], [0.68, 0.265], [0.84, 0.245], [0.95, 0.17], [1.0, 0.05]]


func _torso_spine(t: float) -> Vector3:
	var top: float = _table(TOP, t)
	var bottom: float = _table(BOTTOM, t)
	return Vector3(0.0, (top + bottom) * 0.5, lerpf(0.78, -0.6, t))


func _torso_shape(t: float, a: float) -> float:
	var h: float = (_table(TOP, t) - _table(BOTTOM, t)) * 0.5
	var w: float = _table(WIDTH, t)
	var r := _se(a, w, h, 2.35)
	var side_up := _ga(a, 0.55, 0.42) + _ga(a, PI - 0.55, 0.42)
	var side_mid := _ga(a, 0.0, 0.5) + _ga(a, PI, 0.5)
	# Окорока сзади и лопатки спереди
	r += 0.045 * _g(t, 0.13, 0.08) * (side_up + 0.6 * side_mid)
	r += 0.03 * _g(t, 0.83, 0.07) * side_up
	# Позвоночник и холка чуть выступают, бока над животом впалые
	r += 0.012 * _ga(a, PI * 0.5, 0.18) * smoothstep(0.1, 0.3, t)
	r -= 0.018 * _g(t, 0.35, 0.1) * (_ga(a, -0.5, 0.35) + _ga(a, PI + 0.5, 0.35))
	# Грудина спереди внизу выпирает между ногами
	r += 0.04 * _g(t, 0.93, 0.05) * _ga(a, -PI * 0.5, 0.7)
	# Рёбра под шкурой
	r += 0.004 * sin(t * 62.0) * _g(t, 0.6, 0.1) * side_mid
	return r + 0.0025 * _noise(t, a, 2.0)


# ═══ Шея: от груди вверх и вперёд к затылку; «верх» сечения смотрит вперёд, к горлу ═══

func _neck_spine(t: float) -> Vector3:
	var p0 := Vector3(0.0, 1.08, -0.46)
	var p1 := Vector3(0.0, 1.42, -0.62)
	var p2 := Vector3(0.0, 1.8, -0.71)
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


func _neck_shape(t: float, a: float) -> float:
	var w: float = _table([[0.0, 0.21], [0.4, 0.14], [0.8, 0.1], [1.0, 0.068]], t)
	var h: float = _table([[0.0, 0.24], [0.35, 0.165], [0.8, 0.11], [1.0, 0.075]], t)
	var r := _se(a, w, h, 2.1)
	# Горло спереди и косматая грива сзади
	r += 0.02 * _g(t, 0.55, 0.25) * _ga(a, PI * 0.5, 0.45)
	r += _ga(a, -PI * 0.5, 0.7) * (0.016 + 0.014 * absf(sin(t * 40.0 + a * 7.0))) * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.75, 0.95, t))
	return r


# ═══ Голова: от затылка (t = 0) к носу (t = 1), опущена мордой вниз ═══

func _head_spine(t: float) -> Vector3:
	return Vector3(0.0, lerpf(1.81, 1.55, t) + 0.015 * sin(t * PI), lerpf(-0.6, -1.03, t))


func _head_shape(t: float, a: float) -> float:
	# Крупный череп со скулами и короткая сужающаяся морда
	var w: float = _table([[0.0, 0.03], [0.04, 0.075], [0.1, 0.094], [0.22, 0.098], [0.38, 0.072], [0.55, 0.048], [0.78, 0.036], [0.93, 0.034], [1.0, 0.01]], t)
	var h: float = _table([[0.0, 0.035], [0.05, 0.09], [0.12, 0.108], [0.28, 0.098], [0.5, 0.068], [0.75, 0.052], [0.93, 0.047], [1.0, 0.012]], t)
	var low := maxf(0.0, -sin(a))
	# Снизу уже и глубже: нижняя челюсть
	w *= lerpf(1.0, 0.7, low)
	h += 0.016 * low * _g(t, 0.25, 0.18)
	var r := _se(a, w, h, 2.2)
	# Выпуклый лоб между рогами
	r += 0.012 * _g(t, 0.12, 0.08) * _ga(a, PI * 0.5, 0.5)
	# Глазницы по бокам и надбровья над ними
	var socket := _g(t, 0.29, 0.05) * (_ga(a, 0.3, 0.3) + _ga(a, PI - 0.3, 0.3))
	r += -0.024 * socket + 0.012 * _g(t, 0.25, 0.06) * (_ga(a, 0.68, 0.28) + _ga(a, PI - 0.68, 0.28))
	r += 0.006 * _g(t, 0.36, 0.05) * (_ga(a, -0.05, 0.3) + _ga(a, PI + 0.05, 0.3))
	r += 0.005 * _g(t, 0.93, 0.03) * (_ga(a, PI * 0.5 - 0.95, 0.2) + _ga(a, PI * 0.5 + 0.95, 0.2))
	r += 0.004 * _g(t, 0.9, 0.05) * _ga(a, -PI * 0.5, 0.5)
	# Слёзные ямки перед глазами — у оленей они заметные
	r -= 0.006 * _g(t, 0.42, 0.05) * (_ga(a, 0.15, 0.2) + _ga(a, PI - 0.15, 0.2))
	# Ноздри и уголки рта
	r -= 0.007 * _g(t, 0.95, 0.03) * (_ga(a, PI * 0.5 - 0.6, 0.22) + _ga(a, PI * 0.5 + 0.6, 0.22))
	r -= 0.005 * _g(t, 0.82, 0.1) * (_ga(a, -0.3, 0.12) + _ga(a, PI + 0.3, 0.12))
	return r + 0.002 * _noise(t, a, 3.0)


func _head_color(t: float, a: float) -> Color:
	var c := FUR * (0.9 + 0.2 * _noise(t, a, 1.0))
	# Глазницы чернее шерсти, по краю воспалённая голая кожа
	var socket := _g(t, 0.29, 0.045) * (_ga(a, 0.3, 0.26) + _ga(a, PI - 0.3, 0.26))
	var ring := maxf(0.0, _g(t, 0.29, 0.07) * (_ga(a, 0.3, 0.42) + _ga(a, PI - 0.3, 0.42)) - socket * 1.3)
	c = c.lerp(Color(0.16, 0.04, 0.035), clampf(ring * 1.4, 0.0, 0.7))
	c = c.lerp(Color(0.004, 0.003, 0.003), clampf(socket * 1.6, 0.0, 1.0))
	# Влажный голый нос
	c = c.lerp(Color(0.012, 0.011, 0.011), smoothstep(0.88, 0.95, t) * smoothstep(-0.4, 0.4, sin(a)))
	# Чуть светлее подбородок и губы
	return c.lerp(FUR * 1.7, 0.35 * smoothstep(0.65, 0.88, t) * smoothstep(0.2, 0.9, -sin(a)))


func _fur(t: float, a: float) -> Color:
	return FUR * (0.86 + 0.24 * _noise(t, a, 1.3))


# ═══ Ноги: ось через суставы, сечение сплюснуто с боков ═══

func _leg(points: Array, widths: Array, depths: Array) -> void:
	var path: Array = _smooth(points, 6)
	var spine := func(t: float) -> Vector3:
		var f := t * float(path.size() - 1)
		var i := mini(int(f), path.size() - 2)
		return (path[i] as Vector3).lerp(path[i + 1], f - i)
	var shape := func(t: float, a: float) -> float:
		var w: float = _table(widths, t)
		var d: float = _table(depths, t)
		return _se(a, w, d, 2.0) + 0.0015 * _noise(t, a, 2.0)
	_gencyl(48, 18, spine, shape, _fur, Vector3.FORWARD, true)


func _ready() -> void:
	name = "BlackDeer"
	_rng.seed = 77
	var k := height / FULL
	scale = Vector3.ONE * k
	var flip := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)

	_base = flip
	_gencyl(96, 60, _torso_spine, _torso_shape, _fur, Vector3.UP, true)
	_gencyl(48, 44, _neck_spine, _neck_shape, _fur, Vector3.FORWARD, true)
	_gencyl(64, 48, _head_spine, _head_shape, _head_color, Vector3.UP, true)
	# Уши: большие вытянутые листья, повёрнутые вбок и чуть вперёд
	for s: float in [-1.0, 1.0]:
		var base := Vector3(0.07 * s, 1.86, -0.66)
		var tip := base + Vector3(0.15 * s, 0.07, -0.02)
		var ear_spine := func(t: float) -> Vector3: return base.lerp(tip, t) + Vector3(0, 0.025 * sin(t * PI), 0)
		var ear_shape := func(t: float, a: float) -> float:
			var w := 0.05 * sin(minf(t * 1.1, 1.0) * PI) + 0.006
			return _se(a, w * 0.34, w, 2.0)
		_gencyl(14, 16, ear_spine, ear_shape, func(t: float, a: float) -> Color: return FUR.lightened(0.05 * maxf(0.0, cos(a))), Vector3.FORWARD)
	# Ноги
	for s: float in [-1.0, 1.0]:
		var x := 0.14 * s
		# Передняя: лопатка → локоть → запястье → путовый сустав → копыто
		_leg([Vector3(x * 0.8, 1.04, -0.44), Vector3(x, 0.85, -0.43), Vector3(x * 1.04, 0.5, -0.46), Vector3(x * 1.04, 0.16, -0.46), Vector3(x * 1.04, 0.07, -0.5)],
			[[0.0, 0.06], [0.12, 0.075], [0.22, 0.072], [0.32, 0.055], [0.45, 0.032], [0.53, 0.036], [0.6, 0.022], [0.84, 0.021], [0.88, 0.028], [0.94, 0.021], [1.0, 0.02]],
			[[0.0, 0.1], [0.12, 0.12], [0.22, 0.105], [0.32, 0.075], [0.45, 0.04], [0.53, 0.045], [0.6, 0.027], [0.84, 0.026], [0.88, 0.034], [0.94, 0.024], [1.0, 0.024]])
		# Задняя: окорок → колено → скакательный сустав → путовый сустав → копыто
		_leg([Vector3(x * 0.8, 1.08, 0.5), Vector3(x * 1.05, 0.8, 0.38), Vector3(x * 1.0, 0.5, 0.64), Vector3(x * 1.0, 0.16, 0.6), Vector3(x * 1.0, 0.07, 0.56)],
			[[0.0, 0.12], [0.2, 0.1], [0.3, 0.072], [0.4, 0.045], [0.5, 0.034], [0.58, 0.023], [0.84, 0.021], [0.88, 0.028], [0.94, 0.021], [1.0, 0.02]],
			[[0.0, 0.2], [0.2, 0.16], [0.3, 0.11], [0.4, 0.065], [0.5, 0.055], [0.58, 0.03], [0.84, 0.027], [0.88, 0.034], [0.94, 0.024], [1.0, 0.024]])
		# Пяточный бугор скакательного сустава
		_bl(Vector3(0.015, 0.03, 0.02), Vector3(x, 0.53, 0.68), FUR, Vector3(15, 0, 0))
	# Темя между рогами
	_bl(Vector3(0.075, 0.05, 0.07), Vector3(0.0, 1.835, -0.67), FUR)
	# Короткий хвост
	_bl(Vector3(0.04, 0.075, 0.028), Vector3(0.0, 1.06, 0.8), FUR, Vector3(-18, 0, 0))
	_flush(_fur_mat(), true)

	# Раздвоенные копыта и шпоры: блестящие, чёрные
	_base = flip
	for s: float in [-1.0, 1.0]:
		for z: float in [-0.5, 0.56]:
			for half: float in [-1.0, 1.0]:
				_bx(Vector3(0.024, 0.07, 0.068), Vector3(0.1456 * s + 0.014 * half, 0.035, z - 0.01), Color(0.012, 0.011, 0.01), Vector3(-14, 0, 6 * half))
				_bl(Vector3(0.008, 0.012, 0.01), Vector3(0.1456 * s + 0.018 * half, 0.12, z + 0.04), Color(0.015, 0.014, 0.012))
	_flush(_vmat(0.25, 0.0, false, "none"), true)

	# Рога благородного оленя: ствол назад-вверх, три отростка вперёд и корона
	_base = flip
	var horn_col := func(t: float) -> Color: return Color(0.12, 0.1, 0.085).lerp(Color(0.4, 0.36, 0.3), smoothstep(0.7, 1.0, t))
	var beaded := func(r0: float, r1: float) -> Callable:
		return func(t: float) -> float: return lerpf(r0, r1, t) * (1.0 + 0.14 * sin(t * 52.0) * (1.0 - t) * (1.0 - t))
	for s: float in [-1.0, 1.0]:
		_torus(0.026, 0.044, Vector3(0.058 * s, 1.85, -0.68), Color(0.08, 0.07, 0.06), Vector3(-15, 0, -32 * s), Vector3(1.0, 0.7, 1.0))
		_bl(Vector3(0.034, 0.022, 0.034), Vector3(0.058 * s, 1.85, -0.68), Color(0.08, 0.07, 0.06), Vector3(-15, 0, -32 * s))
		var beam := [Vector3(0.06 * s, 1.85, -0.68), Vector3(0.12 * s, 1.95, -0.65), Vector3(0.2 * s, 2.07, -0.59), Vector3(0.27 * s, 2.21, -0.55), Vector3(0.31 * s, 2.35, -0.57), Vector3(0.32 * s, 2.45, -0.62)]
		_tube(_smooth(beam, 8), beaded.call(0.032, 0.014), horn_col, 14)
		for tine: Array in [
			[Vector3(0.072 * s, 1.88, -0.68), Vector3(0.1 * s, 1.9, -0.8), Vector3(0.11 * s, 1.97, -0.9)],
			[Vector3(0.12 * s, 1.95, -0.65), Vector3(0.15 * s, 1.99, -0.75), Vector3(0.16 * s, 2.05, -0.83)],
			[Vector3(0.25 * s, 2.17, -0.56), Vector3(0.29 * s, 2.2, -0.67), Vector3(0.31 * s, 2.27, -0.75)],
			[Vector3(0.315 * s, 2.42, -0.6), Vector3(0.31 * s, 2.51, -0.68), Vector3(0.3 * s, 2.58, -0.73)],
			[Vector3(0.32 * s, 2.42, -0.61), Vector3(0.38 * s, 2.5, -0.61), Vector3(0.42 * s, 2.56, -0.6)],
			[Vector3(0.32 * s, 2.43, -0.59), Vector3(0.33 * s, 2.51, -0.52), Vector3(0.33 * s, 2.57, -0.47)],
		]:
			_tube(_smooth(tine, 6), beaded.call(0.016, 0.0035), horn_col, 10)
	_flush(_vmat(0.48, 0.0, false, "antler"), true)

	# Человеческие глаза в глазницах: отдельный узел, чтобы их можно было зажечь и погасить
	eyes = Node3D.new()
	eyes.name = "Eyes"
	add_child(eyes)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.8, 0.7, 0.6)
	white.albedo_texture = _veins()
	white.emission_enabled = true
	white.emission = Color(0.16, 0.12, 0.1)
	white.roughness = 0.04
	white.clearcoat_enabled = true
	white.clearcoat = 1.0
	var iris := StandardMaterial3D.new()
	iris.albedo_color = Color(0.5, 0.53, 0.46)
	iris.roughness = 0.05
	var pupil := StandardMaterial3D.new()
	pupil.albedo_color = Color(0.005, 0.005, 0.005)
	pupil.roughness = 0.02
	var lid := StandardMaterial3D.new()
	lid.albedo_color = Color(0.04, 0.02, 0.018)
	lid.roughness = 0.85
	for a: float in [0.3, PI - 0.3]:
		var p := flip * _gencyl_point(_head_spine, _head_shape, 0.29, a, 0.02)
		eye_points.append(p * k)
		# Смотрят прямо вперёд, как у человека, — у оленя так не бывает
		var look := Vector3(0.18 * signf(p.x), -0.06, 1.0)
		var holder := Node3D.new()
		eyes.add_child(holder)
		holder.position = p
		holder.look_at(p + look, Vector3.UP, true)
		holder.add_child(_eye_part(Vector3.ZERO, 0.017, white, Vector3(1.0, 1.0, 1.0)))
		holder.add_child(_eye_part(Vector3(0, 0, 0.0128), 0.0078, iris, Vector3(1.0, 1.0, 0.45)))
		holder.add_child(_eye_part(Vector3(0, 0, 0.0158), 0.0026, pupil, Vector3(1.0, 1.0, 0.45)))
		# Тяжёлые веки сверху и снизу оставляют узкую щель
		holder.add_child(_eye_part(Vector3(0, 0.0095, 0.002), 0.0178, lid, Vector3(1.15, 0.6, 0.98)))
		holder.add_child(_eye_part(Vector3(0, -0.0115, 0.001), 0.0172, lid, Vector3(1.1, 0.45, 0.95)))
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.9, 0.82, 0.75)
	glow.light_energy = 0.3
	glow.omni_range = 1.2
	glow.position = (eye_points[0] / k + eye_points[1] / k) * 0.5 + Vector3(0, 0, 0.25)
	eyes.add_child(glow)


# Шерсть: волоски из текстуры и холодный контурный свет, чтобы силуэт читался в темноте
func _fur_mat() -> StandardMaterial3D:
	var m := (_vmat(0.72, 0.0, false, "fur").duplicate()) as StandardMaterial3D
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.35
	m.metallic_specular = 0.35
	return m


func _eye_part(pos: Vector3, r: float, mat: Material, scl: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# Красные прожилки на белках
static var _veins_tex: ImageTexture


static func _veins() -> ImageTexture:
	if _veins_tex:
		return _veins_tex
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(1.0, 1.0, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	for v in range(26):
		var p := Vector2(rng.randf() * size, rng.randf() * size)
		var ang := rng.randf() * TAU
		for step in range(rng.randi_range(14, 40)):
			ang += rng.randf_range(-0.6, 0.6)
			p += Vector2(cos(ang), sin(ang))
			img.set_pixel(posmod(int(p.x), size), posmod(int(p.y), size), Color(0.72, 0.18, 0.15))
	_veins_tex = ImageTexture.create_from_image(img)
	return _veins_tex


func show_eyes(on: bool) -> void:
	if eyes:
		eyes.visible = on
