class_name FatherCar
extends "res://scripts/models/SculptKit.gd"

# Отцовский пикап из гаража: старый, выцветший зелёный, ржавчина на арках, порогах и заднем борту.
# Скруглённые панели, круглые фары в хромовых ободках, решётка с вертикальными прутьями,
# зеркала на кронштейнах, дворники, ручки, подножки, номера, сиденье и руль в кабине,
# рёбра в кузове, цепи заднего борта, протектор и колпаки с гайками.
# Перед смотрит вдоль -Z, колёса стоят на нуле. Те же вызовы, что у EthanCar:
# _mats["paint"] / _mats["paint2"], set_lights(фары, стоп), set_motion(delta, скорость, руль).

const SIZE := Vector3(1.86, 1.78, 4.62)
const WHEEL_R := 0.38

var _mats := {}
var _wheels: Array[Node3D] = []
var _front_wheels: Array[Node3D] = []
var _head_lights: Array[SpotLight3D] = []
var _spin := 0.0


func _init() -> void:
	super._init()
	_mats["paint"] = _paint(Color(0.16, 0.22, 0.17), 0.45)
	_mats["paint2"] = _paint(Color(0.12, 0.16, 0.13), 0.75)
	_mats["chrome"] = _plain(Color(0.6, 0.6, 0.58), 0.25, 0.9)
	_mats["glass"] = _plain(Color(0.025, 0.03, 0.035), 0.06, 0.4)
	_mats["rubber"] = _plain(Color(0.035, 0.034, 0.033), 0.95, 0.0)
	_mats["lamp"] = _plain(Color(0.85, 0.83, 0.74), 0.15, 0.0)
	_mats["tail"] = _plain(Color(0.38, 0.03, 0.02), 0.2, 0.0)
	_mats["amber"] = _plain(Color(0.6, 0.32, 0.05), 0.2, 0.0)


static var _noise_tex: NoiseTexture2D


# Краска шейдером: выцветание, царапины, ржавчина снизу и пятнами, грязь у порогов
func _paint(c: Color, rust: float) -> ShaderMaterial:
	if _noise_tex == null:
		var n := FastNoiseLite.new()
		n.seed = 1979
		n.frequency = 0.012
		n.fractal_octaves = 5
		_noise_tex = NoiseTexture2D.new()
		_noise_tex.noise = n
		_noise_tex.seamless = true
		_noise_tex.width = 512
		_noise_tex.height = 512
		_noise_tex.generate_mipmaps = true
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/car_paint.gdshader")
	m.set_shader_parameter("paint", c)
	m.set_shader_parameter("noise_tex", _noise_tex)
	m.set_shader_parameter("detail_tex", TextureHelper.get_texture(TextureHelper.SURFACE + "metal.png"))
	m.set_shader_parameter("rust_amount", rust)
	return m


func _plain(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


# Скруглённая панель кузова
func _panel(size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO, round_k: float = 0.16) -> void:
	_softbox(size, _xf(pos, rot), Color.WHITE, round_k, 0.0, 0.0, 14)


func _ready() -> void:
	name = "FatherCar"
	_rng.seed = 1979
	var w := Color.WHITE
	var arch_z := [-1.55, 1.38]

	# ── Основной цвет: капот, крылья, кабина, двери ──
	_panel(Vector3(1.66, 0.56, 1.3), Vector3(0, 0.84, -1.62))
	_panel(Vector3(1.6, 0.1, 1.26), Vector3(0, 1.13, -1.6), Vector3(-2.5, 0, 0), 0.4)
	for s: float in [-1.0, 1.0]:
		# Переднее крыло над колесом: выпуклое, с отогнутой кромкой
		_panel(Vector3(0.26, 0.5, 1.28), Vector3(0.79 * s, 0.98, -1.6), Vector3.ZERO, 0.35)
	_panel(Vector3(1.78, 0.66, 1.44), Vector3(0, 0.84, -0.3))
	_panel(Vector3(1.64, 0.09, 1.1), Vector3(0, 1.76, -0.22), Vector3.ZERO, 0.45)
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.07, 0.62, 0.08), Vector3(0.8 * s, 1.44, -0.84), w, Vector3(-18, 0, 0))
		_bx(Vector3(0.07, 0.62, 0.1), Vector3(0.8 * s, 1.44, 0.29), w)
		_bx(Vector3(0.07, 0.07, 1.14), Vector3(0.8 * s, 1.73, -0.24), w)
	_bx(Vector3(1.66, 0.07, 0.08), Vector3(0, 1.73, 0.3), w)
	_bx(Vector3(1.66, 0.08, 0.1), Vector3(0, 1.16, 0.3), w)
	_flush(_mats["paint"], true)

	# ── Второй цвет: кузов, задние крылья, пороги ──
	_panel(Vector3(1.7, 0.08, 1.74), Vector3(0, 0.84, 1.3), Vector3.ZERO, 0.1)
	for s: float in [-1.0, 1.0]:
		_panel(Vector3(0.08, 0.52, 1.74), Vector3(0.83 * s, 1.08, 1.3), Vector3.ZERO, 0.2)
		_panel(Vector3(0.12, 0.07, 1.78), Vector3(0.83 * s, 1.36, 1.3), Vector3.ZERO, 0.45)
		_panel(Vector3(0.24, 0.42, 1.14), Vector3(0.79 * s, 0.97, 1.38), Vector3.ZERO, 0.35)
		_bx(Vector3(0.12, 0.12, 1.6), Vector3(0.84 * s, 0.53, -0.3), w)
	_panel(Vector3(1.7, 0.52, 0.08), Vector3(0, 1.08, 0.45), Vector3.ZERO, 0.2)
	_panel(Vector3(1.66, 0.5, 0.07), Vector3(0, 1.07, 2.17), Vector3.ZERO, 0.2)
	# Рёбра пола кузова и колёсные кожухи внутри
	for k in range(5):
		_bx(Vector3(0.05, 0.025, 1.68), Vector3(-0.6 + k * 0.3, 0.895, 1.3), w)
	for s: float in [-1.0, 1.0]:
		_panel(Vector3(0.3, 0.26, 0.9), Vector3(0.65 * s, 0.98, 1.38), Vector3.ZERO, 0.4)
	_flush(_mats["paint2"], true)

	# ── Хром: бампера с клыками, решётка, ободки, ручки, зеркала, дворники, антенна ──
	_panel(Vector3(1.88, 0.15, 0.16), Vector3(0, 0.56, -2.31), Vector3.ZERO, 0.45)
	_panel(Vector3(1.86, 0.14, 0.15), Vector3(0, 0.58, 2.27), Vector3.ZERO, 0.45)
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.06, 0.24, 0.08), Vector3(0.42 * s, 0.6, -2.37), w)
	_bx(Vector3(1.42, 0.05, 0.05), Vector3(0, 1.06, -2.26), w)
	_bx(Vector3(1.42, 0.05, 0.05), Vector3(0, 0.68, -2.26), w)
	for k in range(9):
		_bx(Vector3(0.025, 0.36, 0.04), Vector3(-0.56 + k * 0.14, 0.87, -2.265), w)
	_bx(Vector3(0.24, 0.07, 0.02), Vector3(0, 1.0, -2.29), w)
	for s: float in [-1.0, 1.0]:
		_torus(0.088, 0.112, Vector3(0.66 * s, 0.9, -2.27), w, Vector3(90, 0, 0), Vector3.ONE)
		_bx(Vector3(0.035, 0.03, 0.15), Vector3(0.83 * s, 1.02, -0.66), w)
		_bx(Vector3(0.035, 0.03, 0.15), Vector3(0.86 * s, 1.08, 0.94), w)
		_pipe(Vector3(0.82 * s, 1.36, -0.86), Vector3(1.0 * s, 1.5, -0.9), 0.012, w)
		_panel(Vector3(0.05, 0.2, 0.14), Vector3(1.02 * s, 1.52, -0.9), Vector3.ZERO, 0.4)
		_pipe(Vector3(0.36 * s - 0.25, 1.17, -0.95), Vector3(0.36 * s + 0.25, 1.32, -0.9), 0.008, w)
	_pipe(Vector3(0.84, 1.12, -1.0), Vector3(0.84, 2.05, -1.02), 0.005, w)
	# Цепи заднего борта
	for s: float in [-1.0, 1.0]:
		for k in range(6):
			_torus(0.008, 0.016, Vector3(0.8 * s, 1.3 - k * 0.04, 2.15 + k * 0.012), w, Vector3(0, 0, 90 if k % 2 == 0 else 0), Vector3.ONE)
	_flush(_mats["chrome"], true)

	# ── Тёмные детали: щели решётки, швы дверей, подножки, сиденье, руль, номера ──
	var dark := Color(0.02, 0.02, 0.02)
	_bx(Vector3(1.38, 0.34, 0.02), Vector3(0, 0.87, -2.245), dark)
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.005, 0.6, 0.012), Vector3(0.895 * s, 0.84, 0.36), dark)
		_bx(Vector3(0.005, 0.6, 0.012), Vector3(0.895 * s, 0.84, -0.95), dark)
		_bx(Vector3(0.2, 0.04, 0.9), Vector3(0.98 * s, 0.42, -0.3), Color(0.05, 0.05, 0.05))
		_pipe(Vector3(0.36 * s - 0.25, 1.175, -0.948), Vector3(0.36 * s + 0.25, 1.325, -0.898), 0.006, dark)
	_panel(Vector3(1.5, 0.16, 0.5), Vector3(0, 1.0, -0.05), Vector3.ZERO, 0.4)
	_panel(Vector3(1.5, 0.5, 0.14), Vector3(0, 1.28, 0.18), Vector3(-8, 0, 0), 0.4)
	_bx(Vector3(1.56, 0.12, 0.3), Vector3(0, 1.22, -0.8), Color(0.06, 0.055, 0.05))
	_torus(0.17, 0.195, Vector3(-0.38, 1.36, -0.62), dark, Vector3(65, 0, 0), Vector3.ONE)
	_pipe(Vector3(-0.38, 1.36, -0.62), Vector3(-0.38, 1.2, -0.85), 0.025, dark)
	# Выхлопная труба и рама снизу
	_pipe(Vector3(0.5, 0.36, 0.0), Vector3(0.5, 0.33, 2.3), 0.035, Color(0.12, 0.1, 0.08))
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.1, 0.14, 4.3), Vector3(0.45 * s, 0.42, 0.0), dark)
	_flush(_vmat(0.7, 0.2, false, "none"), true)

	# Номера: белые таблички со стёртыми цифрами
	for z: float in [-2.4, 2.35]:
		_bx(Vector3(0.52, 0.12, 0.012), Vector3(0, 0.75 if z < 0.0 else 0.82, z), Color(0.72, 0.7, 0.62))
		var plate := Label3D.new()
		plate.text = "Х 815 ЕС"
		plate.font_size = 48
		plate.pixel_size = 0.0016
		plate.modulate = Color(0.08, 0.08, 0.08)
		plate.outline_size = 0
		plate.position = Vector3(0, 0.75 if z < 0.0 else 0.82, z + (-0.008 if z < 0.0 else 0.008))
		plate.rotation_degrees.y = 180.0 if z < 0.0 else 0.0
		add_child(plate)
	_flush(_vmat(0.6, 0.0, false, "none"), true)

	# Стёкла
	_bx(Vector3(1.5, 0.54, 0.02), Vector3(0, 1.44, -0.85), w, Vector3(-18, 0, 0))
	_bx(Vector3(1.48, 0.42, 0.02), Vector3(0, 1.46, 0.325), w)
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.015, 0.46, 1.04), Vector3(0.805 * s, 1.45, -0.28), w)
		_bx(Vector3(0.012, 0.13, 0.11), Vector3(1.05 * s, 1.52, -0.9), w)
	_flush(_mats["glass"], true)
	# Фары, поворотники, стопы
	for s: float in [-1.0, 1.0]:
		_bl(Vector3(0.088, 0.088, 0.03), Vector3(0.66 * s, 0.9, -2.27), w)
	_flush(_mats["lamp"], true)
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.14, 0.06, 0.03), Vector3(0.66 * s, 0.72, -2.27), w)
	_flush(_mats["amber"], true)
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.1, 0.2, 0.03), Vector3(0.74 * s, 1.08, 2.215), w)
	_flush(_mats["tail"], true)

	# ── Колёса: шина с протектором, диск, колпак с гайками; крутятся при движении ──
	for z: float in arch_z:
		for s: float in [-1.0, 1.0]:
			var pivot := Node3D.new()
			pivot.position = Vector3(0.76 * s, WHEEL_R, z)
			add_child(pivot)
			_wheel(pivot, s)
			_wheels.append(pivot)
			if z < 0.0:
				_front_wheels.append(pivot)
	for s: float in [-1.0, 1.0]:
		var spot := SpotLight3D.new()
		spot.light_color = Color(1.0, 0.92, 0.75)
		spot.light_energy = 0.0
		spot.spot_range = 26.0
		spot.spot_angle = 26.0
		spot.position = Vector3(0.66 * s, 0.9, -2.34)
		spot.rotation_degrees = Vector3(-4, 0, 0)
		add_child(spot)
		_head_lights.append(spot)


func _wheel(pivot: Node3D, side: float) -> void:
	var tire := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.2
	tm.outer_radius = WHEEL_R
	tm.rings = 28
	tm.ring_segments = 10
	tire.mesh = tm
	tire.material_override = _mats["rubber"]
	tire.rotation_degrees = Vector3(0, 0, 90)
	tire.scale = Vector3(1.0, 1.35, 1.0)
	pivot.add_child(tire)
	# Протектор: поперечные шашки по кругу
	var lug := BoxMesh.new()
	lug.size = Vector3(0.2, 0.03, 0.06)
	for k in range(26):
		var ang := TAU * k / 26.0
		var mi := MeshInstance3D.new()
		mi.mesh = lug
		mi.material_override = _mats["rubber"]
		mi.position = Vector3(0, cos(ang), sin(ang)) * (WHEEL_R - 0.005)
		mi.rotation.x = ang
		pivot.add_child(mi)
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.21
	dm.bottom_radius = 0.21
	dm.height = 0.2
	dm.radial_segments = 18
	disc.mesh = dm
	disc.material_override = _mats["rubber"]
	disc.rotation_degrees = Vector3(0, 0, 90)
	pivot.add_child(disc)
	var cap := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.12
	cm.height = 0.24
	cm.radial_segments = 16
	cm.rings = 8
	cap.mesh = cm
	cap.material_override = _mats["chrome"]
	cap.position = Vector3(0.1 * side, 0, 0)
	cap.scale = Vector3(0.35, 1.0, 1.0)
	pivot.add_child(cap)
	var nut := CylinderMesh.new()
	nut.top_radius = 0.014
	nut.bottom_radius = 0.014
	nut.height = 0.03
	nut.radial_segments = 6
	for k in range(5):
		var ang := TAU * k / 5.0
		var n := MeshInstance3D.new()
		n.mesh = nut
		n.material_override = _mats["chrome"]
		n.position = Vector3(0.1 * side, cos(ang) * 0.155, sin(ang) * 0.155)
		n.rotation_degrees = Vector3(0, 0, 90)
		pivot.add_child(n)


func set_lights(on: bool, brake: float = 0.0) -> void:
	for spot in _head_lights:
		spot.light_energy = 4.0 if on else 0.0
	var lamp: StandardMaterial3D = _mats["lamp"]
	lamp.emission_enabled = on
	lamp.emission = Color(1.0, 0.92, 0.72) * 2.4
	var tail: StandardMaterial3D = _mats["tail"]
	tail.emission_enabled = on or brake > 0.0
	tail.emission = Color(0.9, 0.05, 0.02) * (0.6 + float(brake) * 1.6)


func set_motion(delta: float, speed: float, steer_deg: float) -> void:
	_spin += speed * delta / WHEEL_R
	for wheel in _wheels:
		wheel.rotation.x = -_spin
	for wheel in _front_wheels:
		wheel.rotation.y = deg_to_rad(steer_deg)
