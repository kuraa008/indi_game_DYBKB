extends "res://scripts/ApartmentKit.gd"

# Ванная Итана: ванна с душем и шторкой, унитаз, раковина, стиральная машина, корзина.
# Механик здесь нет. Для thebekshdet: одежду собирать в корзину и загружать в машину.

const TUB := Vector3(6.29, FL, 1.94)   # центр ванны на полу
const HX := 0.85
const HZ := 0.40
const RIM := 0.58
const CHROME := Color(0.8, 0.81, 0.84)
const ENAMEL := Color(0.86, 0.86, 0.82)
const PORCELAIN := Color(0.84, 0.84, 0.81)
const WALL_N := -0.94                  # стена за унитазом и раковиной
const WASHER := Vector3(6.83, FL, 0.5)

# Глазурованная плитка: внизу морская волна, посередине бордюр с ромбами, выше кремовая.
# Каждая плитка чуть наклонена, поэтому блик фонаря ломается как на настоящей
const WALL_TILE_SHADER := """
shader_type spatial;
varying vec3 w;
varying vec3 n;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { w = VERTEX; n = NORMAL; }
void fragment() {
	bool along_z = abs(n.x) > 0.5;
	float u = along_z ? w.z : w.x;
	float belt0 = 1.17;
	float belt1 = 1.29;
	vec2 size = vec2(0.15, 0.15);
	vec2 p = vec2(u, w.y - belt0) / size;
	vec3 base = vec3(0.075, 0.2, 0.2);
	int zone = 0;
	if (w.y > belt1) {
		zone = 2;
		size = vec2(0.2, 0.1);
		p = vec2(u, w.y - belt1) / size;
		p.x += 0.5 * floor(p.y);
		base = vec3(0.58, 0.56, 0.47);
	} else if (w.y > belt0) {
		zone = 1;
		size = vec2(0.12, belt1 - belt0);
		p = vec2(u, w.y - belt0) / size;
		base = vec3(0.03, 0.09, 0.09);
	}
	vec2 id = floor(p);
	vec2 f = fract(p);
	vec2 d = min(f, 1.0 - f) * size;
	float joint = smoothstep(0.001, 0.0024, min(d.x, d.y));
	vec3 c = base * (0.86 + 0.26 * h(id + float(zone) * 7.0));
	if (zone == 1) {
		float diamond = 1.0 - smoothstep(0.3, 0.32, abs(f.x - 0.5) + abs(f.y - 0.5));
		c = mix(c, vec3(0.52, 0.42, 0.2), diamond);
	}
	ALBEDO = mix(vec3(0.3, 0.29, 0.26), c, joint);
	ROUGHNESS = mix(0.9, 0.2, joint);
	SPECULAR = 0.6;
	vec3 side = along_z ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
	vec2 tilt = (vec2(h(id + 3.1), h(id + 5.7)) - 0.5) * 0.05;
	vec2 bevel = sign(f - 0.5) * (1.0 - smoothstep(0.0, 0.007, d)) * 0.4;
	vec3 wn = n + side * (tilt.x + bevel.x) + vec3(0.0, 1.0, 0.0) * (tilt.y + bevel.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
"""

# Мелкая шестигранная мозаика на полу с тёмными вкраплениями
const HEX_FLOOR_SHADER := """
shader_type spatial;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { w = VERTEX; }
void fragment() {
	vec2 p = w.xz / 0.065;
	vec2 s = vec2(1.0, 1.732);
	vec2 a = mod(p, s) - s * 0.5;
	vec2 b = mod(p - s * 0.5, s) - s * 0.5;
	vec2 g = dot(a, a) < dot(b, b) ? a : b;
	vec2 id = floor((p - g) * 2.0);
	vec2 ag = abs(g);
	float d = 0.5 - max(dot(ag, normalize(s)), ag.x);
	float joint = smoothstep(0.012, 0.04, d);
	vec3 c = vec3(0.5, 0.49, 0.43) * (0.84 + 0.28 * h(id));
	if (h(id + 9.3) > 0.87) { c = vec3(0.05, 0.13, 0.13) * (0.85 + 0.3 * h(id)); }
	ALBEDO = mix(vec3(0.17, 0.165, 0.15), c, joint);
	ROUGHNESS = mix(0.9, 0.2, joint);
	SPECULAR = 0.5;
	vec2 tilt = (vec2(h(id + 3.1), h(id + 5.7)) - 0.5) * 0.06;
	NORMAL = normalize((VIEW_MATRIX * vec4(tilt.x, 1.0, tilt.y, 0.0)).xyz);
}
"""

const TERRY_SHADER := """
shader_type spatial;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { w = VERTEX; }
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	vec2 p = w.xz * 520.0;
	float fade = 1.0 - smoothstep(0.3, 1.2, fwidth(p.x));
	c *= mix(1.0, 0.55 + 0.8 * h(floor(p)), fade);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
"""

const WICKER_SHADER := """
shader_type spatial;
varying vec3 w;
void vertex() { w = VERTEX; }
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	vec2 p = vec2(w.x + w.z, w.y) * 170.0;
	float fade = 1.0 - smoothstep(0.5, 1.6, fwidth(p.y));
	float weave = sin(p.x) * sin(p.y);
	c *= mix(0.9, 0.62 + 0.6 * smoothstep(-0.35, 0.65, weave), fade);
	ALBEDO = c;
	ROUGHNESS = 0.88;
}
"""


func _ready() -> void:
	name = "ApartmentBathroom"
	_rng.seed = 5120
	_build_tub()
	_build_taps()
	_build_curtain()
	_build_small_things()
	_build_toilet()
	_build_basin()
	_build_washer()
	_build_basket()
	_build_tiles()
	_solid(TUB + Vector3(0, RIM * 0.5, 0), Vector3(HX * 2.0, RIM, HZ * 2.0))


# Плитка лежит тонким слоем поверх стен и пола; на западной стене вырез под дверь
func _build_tiles() -> void:
	var y0 := FL
	var y1 := FL + 2.7
	var mid := (y0 + y1) * 0.5
	var h := y1 - y0
	var t := 0.004
	var x_w := 4.26 + t * 0.5
	var x_e := 7.14 - t * 0.5
	var z_n := WALL_N + t * 0.5
	var z_s := 2.34 - t * 0.5
	_bx(Vector3(x_e - x_w, h, t), Vector3((x_w + x_e) * 0.5, mid, z_n), Color.WHITE)
	_bx(Vector3(x_e - x_w, h, t), Vector3((x_w + x_e) * 0.5, mid, z_s), Color.WHITE)
	_bx(Vector3(t, h, z_s - z_n), Vector3(x_e, mid, (z_n + z_s) * 0.5), Color.WHITE)
	var door0 := 0.7 - 0.425
	var door1 := 0.7 + 0.425
	var door_top := FL + 2.1
	_bx(Vector3(t, h, door0 - z_n), Vector3(x_w, mid, (z_n + door0) * 0.5), Color.WHITE)
	_bx(Vector3(t, h, z_s - door1), Vector3(x_w, mid, (z_s + door1) * 0.5), Color.WHITE)
	_bx(Vector3(t, y1 - door_top, door1 - door0), Vector3(x_w, (y1 + door_top) * 0.5, (door0 + door1) * 0.5), Color.WHITE)
	_flush(_shader(WALL_TILE_SHADER))

	_bx(Vector3(3.0, 0.004, 3.4), Vector3(5.7, FL, 0.7), Color.WHITE)
	_flush(_shader(HEX_FLOOR_SHADER))


# Ванна: корпус, скруглённый борт и глубокая чаша. Чаша темнеет книзу, чтобы глубина читалась
func _build_tub() -> void:
	var rings := [
		_rg(HX - 0.005, HZ - 0.005, 0.05, 0.0),
		_rg(HX, HZ, 0.05, 0.02),
		_rg(HX, HZ, 0.05, RIM - 0.02),
		_rg(HX - 0.004, HZ - 0.004, 0.05, RIM - 0.006),
		_rg(HX - 0.016, HZ - 0.016, 0.05, RIM),
		_rg(HX - 0.075, HZ - 0.068, 0.15, RIM),
		_rg(HX - 0.088, HZ - 0.08, 0.16, RIM - 0.008),
		_rg(HX - 0.105, HZ - 0.095, 0.18, RIM - 0.08),
		_rg(HX - 0.19, HZ - 0.14, 0.18, RIM - 0.3, 0.05),
		_rg(HX - 0.29, HZ - 0.175, 0.17, RIM - 0.45, 0.1),
		_rg(HX - 0.37, HZ - 0.21, 0.15, RIM - 0.505, 0.13),
		_rg(HX - 0.42, HZ - 0.245, 0.12, RIM - 0.52, 0.14),
		_rg(0.0, 0.0, 0.0, RIM - 0.525, 0.14),
	]
	var depth := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.08, 0.2, 0.32, 0.4, 0.44, 0.44]
	var colors := []
	for d in depth:
		colors.append(ENAMEL.darkened(d))
	_base = _xf(TUB)
	_loft(rings, ENAMEL, Transform3D.IDENTITY, 7, colors)
	_flush(_vmat(0.2))

	# Слив в дне и перелив на стенке
	_base = _xf(TUB)
	_cy(0.034, 0.034, 0.003, Vector3(0.47, RIM - 0.52, 0), CHROME, Vector3.ZERO, 20)
	_flush(_vmat(0.28, 0.6))
	_base = _xf(TUB)
	_cy(0.018, 0.018, 0.002, Vector3(0.47, RIM - 0.517, 0), Color(0.06, 0.06, 0.07), Vector3.ZERO, 14)
	_flush(_vmat(0.6))
	_base = _xf(TUB)
	_cy(0.03, 0.03, 0.006, Vector3(0.722, RIM - 0.14, 0), CHROME, Vector3(0, 0, 82), 18)
	_flush(_vmat(0.28, 0.6))


# Смеситель на стене у дальнего края ванны, штанга и лейка душа
func _build_taps() -> void:
	var wall := HX
	var y := 0.8
	_base = _xf(TUB)
	for s in [-1.0, 1.0]:
		_cy(0.03, 0.032, 0.008, Vector3(wall - 0.004, y, s * 0.09), CHROME, Vector3(0, 0, 90), 16)
		_pipe(Vector3(wall, y, s * 0.09), Vector3(wall - 0.06, y, s * 0.09), 0.011, CHROME)
		# Вентиль с крестовиной
		_cy(0.022, 0.026, 0.034, Vector3(wall - 0.06, y, s * 0.142), CHROME, Vector3(90, 0, 0), 14)
		_bx(Vector3(0.078, 0.009, 0.012), Vector3(wall - 0.06, y, s * 0.164), CHROME)
		_bx(Vector3(0.009, 0.078, 0.012), Vector3(wall - 0.06, y, s * 0.164), CHROME)
	_tube([Vector3(wall - 0.06, y, -0.13), Vector3(wall - 0.06, y, 0.13)], 0.017, CHROME, 12)
	# Излив
	_tube(_smooth([Vector3(wall - 0.06, y, 0), Vector3(wall - 0.13, y, 0), Vector3(wall - 0.19, y - 0.008, 0),
		Vector3(wall - 0.225, y - 0.04, 0), Vector3(wall - 0.232, y - 0.075, 0)], 6), 0.012, CHROME, 10)
	_cy(0.0145, 0.0145, 0.02, Vector3(wall - 0.232, y - 0.083, 0), CHROME, Vector3.ZERO, 12)
	_cy(0.009, 0.012, 0.05, Vector3(wall - 0.06, y + 0.04, 0), CHROME, Vector3.ZERO, 10)
	_bl(Vector3.ONE * 0.013, Vector3(wall - 0.06, y + 0.07, 0), CHROME)
	# Штанга душа
	var zr := -0.2
	_pipe(Vector3(wall - 0.045, 1.08, zr), Vector3(wall - 0.045, 1.86, zr), 0.011, CHROME)
	for py in [1.08, 1.86]:
		_pipe(Vector3(wall, py, zr), Vector3(wall - 0.045, py, zr), 0.009, CHROME)
		_cy(0.02, 0.022, 0.006, Vector3(wall - 0.003, py, zr), CHROME, Vector3(0, 0, 90), 12)
		_bl(Vector3.ONE * 0.0125, Vector3(wall - 0.045, py, zr), CHROME)
	# Держатель и лейка
	_bx(Vector3(0.04, 0.05, 0.03), Vector3(wall - 0.06, 1.68, zr), CHROME.darkened(0.2))
	var low := Vector3(wall - 0.07, 1.66, zr)
	var top := Vector3(wall - 0.115, 1.81, zr)
	_tube([low, low.lerp(top, 0.5), top], func(k: float) -> float: return lerpf(0.013, 0.018, k), CHROME, 10)
	_base = _xf(TUB) * Transform3D(Basis(Vector3.BACK, deg_to_rad(-42.0)), top + Vector3(-0.012, 0.012, 0))
	_loft([
		_rg(0.0, 0.0, 0.0, 0.016),
		_rg(0.028, 0.028, 0.028, 0.014),
		_rg(0.055, 0.055, 0.055, 0.0),
		_rg(0.06, 0.06, 0.06, -0.012),
		_rg(0.058, 0.058, 0.058, -0.018),
		_rg(0.0, 0.0, 0.0, -0.019),
	], CHROME, Transform3D.IDENTITY, 5)
	_flush(_vmat(0.24, 0.6))

	# Рассеиватель лейки: чёрные отверстия по кругу
	_base = _xf(TUB) * Transform3D(Basis(Vector3.BACK, deg_to_rad(-42.0)), top + Vector3(-0.012, 0.012, 0))
	for ring_n in [[0.016, 6], [0.03, 10], [0.045, 14]]:
		for k in range(ring_n[1]):
			var a: float = TAU * float(k) / float(ring_n[1])
			_cy(0.0022, 0.0022, 0.002, Vector3(cos(a) * float(ring_n[0]), -0.0195, sin(a) * float(ring_n[0])), Color(0.05, 0.05, 0.06), Vector3.ZERO, 6)
	# Отметки горячей и холодной воды
	_base = _xf(TUB)
	_cy(0.006, 0.006, 0.002, Vector3(wall - 0.06, y + 0.012, 0.164), Color(0.7, 0.1, 0.08), Vector3(90, 0, 0), 8)
	_cy(0.006, 0.006, 0.002, Vector3(wall - 0.06, y + 0.012, -0.164), Color(0.1, 0.25, 0.7), Vector3(90, 0, 0), 8)
	_flush(_vmat(0.4))

	# Гибкий шланг провисает петлёй от смесителя к лейке
	_base = _xf(TUB)
	var hose := _smooth([Vector3(wall - 0.065, y - 0.02, -0.06), Vector3(wall - 0.085, y - 0.13, -0.09),
		Vector3(wall - 0.12, y - 0.19, -0.17), Vector3(wall - 0.14, y - 0.1, -0.24), Vector3(wall - 0.125, 1.1, -0.26),
		Vector3(wall - 0.095, 1.45, -0.235), Vector3(wall - 0.072, 1.645, -0.205)], 8)
	_tube(hose, 0.0065, Color(0.5, 0.51, 0.54), 7)
	_flush(_vmat(0.42, 0.5))


# Шторка отодвинута к стене со смесителем и висит крупными складками
func _build_curtain() -> void:
	var y_rail := 2.03
	var z_rail := -HZ + 0.055
	_base = _xf(TUB)
	# Карниз буквой Г: от стены со смесителем вдоль ванны и к дальней стене
	var rail := _smooth([Vector3(HX, y_rail, z_rail), Vector3(0.2, y_rail, z_rail), Vector3(-0.6, y_rail, z_rail),
		Vector3(-0.74, y_rail, z_rail + 0.015), Vector3(-0.795, y_rail, z_rail + 0.07), Vector3(-0.8, y_rail, z_rail + 0.2),
		Vector3(-0.8, y_rail, HZ)], 5)
	_tube(rail, 0.0125, CHROME, 10)
	_cy(0.028, 0.03, 0.01, Vector3(HX - 0.005, y_rail, z_rail), CHROME, Vector3(0, 0, 90), 16)
	_cy(0.028, 0.03, 0.01, Vector3(-0.8, y_rail, HZ - 0.005), CHROME, Vector3(90, 0, 0), 16)
	var folds := 9
	var x_near := HX - 0.03
	var x_far := 0.36
	for k in range(folds):
		var s := (float(k) + 0.25) / float(folds)
		_torus(0.015, 0.0185, Vector3(lerpf(x_near, x_far, s), y_rail - 0.008, z_rail), CHROME, Vector3(0, 0, 90))
	_flush(_vmat(0.28, 0.6))

	var fabric := Color(0.63, 0.66, 0.64)
	var band := fabric.darkened(0.3)
	var nu := 90
	var nv := 16
	var y_top := y_rail - 0.03
	var y_low := RIM + 0.05
	var point := func(i: int, j: int) -> Array:
		var s := float(i) / float(nu)
		var t := float(j) / float(nv)
		var phase := s * TAU * float(folds) + 1.1 * t * sin(s * 11.0)
		var wave := sin(phase) * 0.72 + sin(phase * 0.47 + 1.9) * 0.28
		var amp := (0.018 + 0.036 * t) * (0.75 + 0.25 * sin(s * 31.0 + 0.4))
		var x := lerpf(x_near, x_far, s) + 0.02 * t * sin(s * 17.0)
		var y := lerpf(y_top, y_low, t) + 0.012 * t * sin(s * 23.0)
		var c := fabric.darkened(0.36 * (0.5 - 0.5 * wave))
		if t < 0.08 or t > 0.93:
			c = c.lerp(band, 0.5)
		return [Vector3(x, y, z_rail + wave * amp), c]
	_base = _xf(TUB)
	_surface(nu, nv, point)
	_flush(_vmat(0.72, 0.0, true))


func _build_small_things() -> void:
	# Флаконы на углу ванны и мыло на борту
	_base = _xf(TUB)
	_bottle(Vector3(0.755, RIM, 0.33), 0.03, 0.19, Color(0.16, 0.34, 0.45), Color(0.88, 0.88, 0.85))
	_bottle(Vector3(0.67, RIM, 0.352), 0.026, 0.16, Color(0.78, 0.55, 0.24), Color(0.2, 0.18, 0.16))
	_bl(Vector3(0.042, 0.014, 0.027), Vector3(0.2, RIM + 0.014, 0.355), Color(0.84, 0.76, 0.6))
	_flush(_vmat(0.32))

	# Коврик перед ванной
	var mat_col := Color(0.24, 0.33, 0.37)
	_base = _xf(Vector3(5.95, FL, 1.16))
	_loft([
		_rg(0.42, 0.27, 0.07, 0.0),
		_rg(0.42, 0.27, 0.07, 0.01),
		_rg(0.405, 0.255, 0.07, 0.017),
		_rg(0.385, 0.235, 0.07, 0.018),
		_rg(0.34, 0.19, 0.06, 0.018),
		_rg(0.0, 0.0, 0.0, 0.018),
	], mat_col, Transform3D.IDENTITY, 5, [mat_col.darkened(0.2), mat_col.darkened(0.2), mat_col.darkened(0.08), mat_col, mat_col, mat_col])
	_flush(_shader(TERRY_SHADER))


# Унитаз: бачок у стены, чаша с водой, сиденье, откинутая крышка
func _build_toilet() -> void:
	var at := Vector3(6.8, FL, WALL_N)
	var white := PORCELAIN
	var cz := 0.475
	_base = _xf(at)
	_loft([
		_rg(0.175, 0.075, 0.03, 0.4, 0.0, 0.095),
		_rg(0.185, 0.085, 0.035, 0.42, 0.0, 0.095),
		_rg(0.19, 0.088, 0.035, 0.755, 0.0, 0.095),
		_rg(0.186, 0.084, 0.035, 0.76, 0.0, 0.095),
		_rg(0.0, 0.0, 0.0, 0.76, 0.0, 0.095),
	], white, Transform3D.IDENTITY, 5)
	_loft([
		_rg(0.196, 0.094, 0.036, 0.76, 0.0, 0.095),
		_rg(0.198, 0.096, 0.038, 0.78, 0.0, 0.095),
		_rg(0.19, 0.088, 0.034, 0.79, 0.0, 0.095),
		_rg(0.17, 0.068, 0.03, 0.79, 0.0, 0.095),
		_rg(0.0, 0.0, 0.0, 0.79, 0.0, 0.095),
	], white, Transform3D.IDENTITY, 5)
	# Трубка от бачка к чаше и чаша
	_loft([
		_rg(0.09, 0.05, 0.045, 0.3, 0.0, 0.17),
		_rg(0.09, 0.05, 0.045, 0.43, 0.0, 0.17),
	], white.darkened(0.08), Transform3D.IDENTITY, 4)
	var rings := [
		_rg(0.12, 0.2, 0.11, 0.0, 0.0, cz - 0.04),
		_rg(0.115, 0.195, 0.105, 0.02, 0.0, cz - 0.04),
		_rg(0.105, 0.18, 0.095, 0.14, 0.0, cz - 0.03),
		_rg(0.165, 0.235, 0.15, 0.28, 0.0, cz),
		_rg(0.185, 0.26, 0.17, 0.385, 0.0, cz),
		_rg(0.18, 0.255, 0.165, 0.4, 0.0, cz),
		_rg(0.135, 0.205, 0.125, 0.4, 0.0, cz),
		_rg(0.125, 0.195, 0.115, 0.385, 0.0, cz),
		_rg(0.105, 0.165, 0.1, 0.3, 0.0, cz - 0.01),
		_rg(0.07, 0.1, 0.065, 0.225, 0.0, cz - 0.03),
	]
	var depth := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.28, 0.42]
	var colors := []
	for d in depth:
		colors.append(white.darkened(d))
	_loft(rings, white, Transform3D.IDENTITY, 7, colors)
	_flush(_vmat(0.18))

	# Вода в чаше
	_base = _xf(at)
	_loft([
		_rg(0.072, 0.102, 0.066, 0.222, 0.0, cz - 0.03),
		_rg(0.0, 0.0, 0.0, 0.222, 0.0, cz - 0.03),
	], Color(0.2, 0.28, 0.31), Transform3D.IDENTITY, 6)
	_flush(_vmat(0.06))

	# Сиденье и поднятая крышка
	var seat := Color(0.78, 0.78, 0.75)
	_base = _xf(at)
	_loft([
		_rg(0.172, 0.248, 0.16, 0.4, 0.0, cz),
		_rg(0.187, 0.265, 0.175, 0.412, 0.0, cz),
		_rg(0.18, 0.258, 0.168, 0.427, 0.0, cz),
		_rg(0.132, 0.202, 0.12, 0.427, 0.0, cz),
		_rg(0.122, 0.19, 0.113, 0.412, 0.0, cz),
		_rg(0.13, 0.2, 0.12, 0.4, 0.0, cz),
	], seat, Transform3D.IDENTITY, 7)
	var hinge := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-92.0)), Vector3(0, 0.43, 0.225))
	_loft([
		_rg(0.0, 0.0, 0.0, 0.0, 0.0, 0.255),
		_rg(0.178, 0.252, 0.168, 0.0, 0.0, 0.255),
		_rg(0.186, 0.26, 0.176, 0.012, 0.0, 0.255),
		_rg(0.176, 0.25, 0.166, 0.025, 0.0, 0.255),
		_rg(0.0, 0.0, 0.0, 0.029, 0.0, 0.255),
	], seat, hinge, 7)
	_flush(_vmat(0.28))

	# Кнопка смыва, петли сиденья, держатель с рулоном
	_base = _xf(at)
	_cy(0.03, 0.03, 0.005, Vector3(0, 0.793, 0.095), CHROME, Vector3.ZERO, 18)
	_bx(Vector3(0.002, 0.002, 0.055), Vector3(0, 0.7965, 0.095), Color(0.3, 0.3, 0.32))
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.022, 0.014, 0.036), Vector3(s * 0.075, 0.432, 0.232), CHROME)
	_base = _xf(Vector3(7.14, FL + 0.72, -0.38))
	_cy(0.024, 0.026, 0.006, Vector3(-0.003, 0, 0), CHROME, Vector3(0, 0, 90), 14)
	_pipe(Vector3(0, 0, 0), Vector3(-0.075, 0, 0), 0.0065, CHROME)
	_pipe(Vector3(-0.075, 0, 0), Vector3(-0.075, 0, 0.08), 0.0065, CHROME)
	_flush(_vmat(0.26, 0.6))
	_base = _xf(Vector3(7.14, FL + 0.72, -0.38))
	_cy(0.052, 0.052, 0.095, Vector3(-0.075, 0, 0.044), Color(0.86, 0.85, 0.8), Vector3(90, 0, 0), 22)
	_flush(_vmat(0.92))
	_base = _xf(Vector3(7.14, FL + 0.72, -0.38))
	_cy(0.021, 0.021, 0.097, Vector3(-0.075, 0, 0.044), Color(0.4, 0.3, 0.2), Vector3(90, 0, 0), 14)
	_flush(_vmat(0.9))

	_solid(at + Vector3(0, 0.21, cz), Vector3(0.38, 0.42, 0.54))
	_solid(at + Vector3(0, 0.4, 0.095), Vector3(0.39, 0.8, 0.19))


# Раковина на пьедестале, кран, полочка под зеркалом
func _build_basin() -> void:
	var white := PORCELAIN
	var at := Vector3(5.2, FL, -0.7)
	_base = _xf(at)
	_loft([
		_rg(0.105, 0.085, 0.08, 0.0, 0.0, -0.08),
		_rg(0.095, 0.075, 0.07, 0.03, 0.0, -0.08),
		_rg(0.075, 0.06, 0.055, 0.2, 0.0, -0.08),
		_rg(0.07, 0.058, 0.05, 0.5, 0.0, -0.08),
		_rg(0.095, 0.08, 0.07, 0.72, 0.0, -0.07),
	], white.darkened(0.05), Transform3D.IDENTITY, 6)
	var rings := [
		_rg(0.0, 0.0, 0.0, 0.66, 0.0, -0.02),
		_rg(0.13, 0.1, 0.09, 0.67, 0.0, -0.02),
		_rg(0.24, 0.18, 0.15, 0.75),
		_rg(0.29, 0.225, 0.18, 0.825),
		_rg(0.295, 0.23, 0.18, 0.85),
		_rg(0.288, 0.223, 0.175, 0.862),
		_rg(0.255, 0.175, 0.15, 0.862, 0.0, 0.02),
		_rg(0.24, 0.16, 0.14, 0.855, 0.0, 0.02),
		_rg(0.205, 0.125, 0.12, 0.79, 0.0, 0.02),
		_rg(0.12, 0.08, 0.075, 0.725, 0.0, 0.02),
		_rg(0.03, 0.03, 0.03, 0.705, 0.0, 0.02),
		_rg(0.0, 0.0, 0.0, 0.703, 0.0, 0.02),
	]
	var depth := [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.04, 0.16, 0.3, 0.36, 0.36]
	var colors := []
	for d in depth:
		colors.append(white.darkened(d))
	_loft(rings, white, Transform3D.IDENTITY, 7, colors)
	_flush(_vmat(0.18))

	_base = _xf(at)
	_cy(0.026, 0.026, 0.003, Vector3(0, 0.706, 0.02), CHROME, Vector3.ZERO, 18)
	var y := 0.862
	_cy(0.021, 0.026, 0.02, Vector3(0, y + 0.01, -0.19), CHROME, Vector3.ZERO, 16)
	_tube(_smooth([Vector3(0, y + 0.015, -0.19), Vector3(0, y + 0.09, -0.19), Vector3(0, y + 0.122, -0.16),
		Vector3(0, y + 0.122, -0.1), Vector3(0, y + 0.1, -0.075)], 6), 0.0105, CHROME, 10)
	_cy(0.0135, 0.0135, 0.018, Vector3(0, y + 0.092, -0.074), CHROME.darkened(0.15), Vector3.ZERO, 12)
	_tube([Vector3(0, y + 0.07, -0.2), Vector3(0, y + 0.085, -0.235)], 0.006, CHROME, 8)
	# Кронштейны полочки
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.012, 0.03, 0.09), Vector3(s * 0.2, 1.05, WALL_N + 0.05 - at.z), CHROME)
	_flush(_vmat(0.26, 0.6))
	_base = _xf(at)
	_cy(0.012, 0.012, 0.002, Vector3(0, 0.7075, 0.02), Color(0.05, 0.05, 0.06), Vector3.ZERO, 12)
	_flush(_vmat(0.6))

	# Полочка, стакан с зубной щёткой, тюбик
	_base = _xf(Vector3(5.2, FL, WALL_N))
	_bx(Vector3(0.5, 0.008, 0.11), Vector3(0, 1.068, 0.058), Color(0.62, 0.7, 0.7))
	_flush(_vmat(0.08))
	_base = _xf(Vector3(5.2, FL + 1.072, WALL_N))
	_loft([
		_rg(0.03, 0.03, 0.03, 0.0),
		_rg(0.036, 0.036, 0.036, 0.1),
		_rg(0.033, 0.033, 0.033, 0.1),
		_rg(0.028, 0.028, 0.028, 0.006),
		_rg(0.0, 0.0, 0.0, 0.006),
	], Color(0.38, 0.5, 0.55), _xf(Vector3(0.14, 0, 0.056)), 4)
	_bx(Vector3(0.009, 0.15, 0.005), Vector3(0.15, 0.1, 0.056), Color(0.75, 0.3, 0.22), Vector3(0, 0, -12))
	_bx(Vector3(0.012, 0.03, 0.008), Vector3(0.1335, 0.175, 0.056), Color(0.85, 0.85, 0.82), Vector3(0, 0, -12))
	_bottle(Vector3(-0.14, 0.0, 0.056), 0.026, 0.13, Color(0.75, 0.73, 0.68), Color(0.2, 0.32, 0.5))
	_flush(_vmat(0.34))

	_solid(at + Vector3(0, 0.43, 0), Vector3(0.58, 0.86, 0.46))


# Стиральная машина: круглая дверца со стеклом, панель с ручкой программ, лоток
func _build_washer() -> void:
	# Локальная ось +z смотрит из машины в комнату
	var at := _xf(WASHER, Vector3(0, -90, 0))
	var white := Color(0.78, 0.78, 0.76)
	var grey := Color(0.56, 0.57, 0.58)
	var hw := 0.29
	var hd := 0.29
	var h := 0.85
	var face := hd
	_base = at
	_loft([
		_rg(hw - 0.003, hd - 0.003, 0.012, 0.02),
		_rg(hw, hd, 0.014, 0.03),
		_rg(hw, hd, 0.014, h - 0.03),
		_rg(hw + 0.003, hd + 0.003, 0.016, h - 0.028),
		_rg(hw + 0.003, hd + 0.003, 0.016, h - 0.006),
		_rg(hw - 0.002, hd - 0.002, 0.016, h),
		_rg(hw - 0.03, hd - 0.03, 0.016, h),
		_rg(0.0, 0.0, 0.0, h),
	], white, Transform3D.IDENTITY, 4)
	# Панель управления и лоток для порошка
	_bx(Vector3(hw * 2.0 - 0.02, 0.12, 0.006), Vector3(0, h - 0.1, face + 0.003), grey.lightened(0.25))
	_bx(Vector3(0.17, 0.085, 0.012), Vector3(-0.185, h - 0.1, face + 0.008), white.lightened(0.1))
	_bx(Vector3(0.09, 0.012, 0.016), Vector3(-0.185, h - 0.13, face + 0.012), grey)
	# Нижняя планка
	_bx(Vector3(hw * 2.0 - 0.02, 0.085, 0.004), Vector3(0, 0.07, face + 0.002), white.darkened(0.08))
	_flush(_vmat(0.32))

	_base = at
	var door_y := 0.4
	# Рамка дверцы, ручка выбора программ, кнопки
	_torus(0.165, 0.215, Vector3(0, door_y, face + 0.022), Color(0.74, 0.75, 0.77), Vector3(90, 0, 0), Vector3(1, 1.3, 1))
	_bx(Vector3(0.035, 0.1, 0.03), Vector3(0.195, door_y, face + 0.038), Color(0.66, 0.67, 0.69))
	_cy(0.04, 0.044, 0.03, Vector3(0.17, h - 0.1, face + 0.02), Color(0.74, 0.75, 0.77), Vector3(90, 0, 0), 22)
	_bx(Vector3(0.006, 0.034, 0.004), Vector3(0.17, h - 0.085, face + 0.036), Color(0.14, 0.14, 0.16))
	for k in range(3):
		_cy(0.01, 0.011, 0.008, Vector3(0.015 + float(k) * 0.03, h - 0.125, face + 0.01), Color(0.74, 0.75, 0.77), Vector3(90, 0, 0), 10)
	_flush(_vmat(0.3, 0.55))

	# Стекло дверцы выпуклое и тёмное; барабан и бельё угадываются внутри
	var door := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, door_y, face))
	var dark := Color(0.05, 0.06, 0.08)
	var glass := Color(0.16, 0.2, 0.26)
	_base = at
	_loft([
		_rg(0.172, 0.172, 0.172, 0.0),
		_rg(0.168, 0.168, 0.168, 0.018),
		_rg(0.14, 0.14, 0.14, 0.036),
		_rg(0.08, 0.08, 0.08, 0.048),
		_rg(0.0, 0.0, 0.0, 0.052),
	], dark, door, 8, [dark, dark, dark.lerp(glass, 0.5), glass, glass])
	# Табло
	_bx(Vector3(0.1, 0.035, 0.002), Vector3(0.04, h - 0.082, face + 0.0065), Color(0.02, 0.03, 0.03))
	_flush(_vmat(0.08))

	_solid(WASHER + Vector3(0, h * 0.5, 0), Vector3(hd * 2.0, h, hw * 2.0))


# Плетёная корзина для белья с одеждой сверху
func _build_basket() -> void:
	var wicker := Color(0.56, 0.42, 0.25)
	var at := Vector3(4.72, FL, 2.0)
	var inner := wicker.darkened(0.55)
	_base = _xf(at)
	_loft([
		_rg(0.2, 0.165, 0.06, 0.0),
		_rg(0.235, 0.2, 0.07, 0.5),
		_rg(0.24, 0.205, 0.07, 0.515),
		_rg(0.24, 0.205, 0.07, 0.53),
		_rg(0.222, 0.187, 0.065, 0.535),
		_rg(0.214, 0.18, 0.06, 0.51),
		_rg(0.18, 0.15, 0.05, 0.06),
		_rg(0.0, 0.0, 0.0, 0.05),
	], wicker, Transform3D.IDENTITY, 5, [wicker.darkened(0.2), wicker, wicker, wicker, wicker, inner, inner, inner])
	_flush(_shader(WICKER_SHADER))

	var pile := func(p: Vector2) -> bool:
		return Vector2(p.x / 0.205, p.y / 0.17).length() < 1.0
	_base = Transform3D.IDENTITY
	_cloth(_xf(at + Vector3(0, 0.44, 0), Vector3(0, 30, 0)), pile, Vector2(0.22, 0.18), 0.11, Color(0.42, 0.44, 0.5), 0.016)
	_flush(_vmat(0.92))

	_solid(at + Vector3(0, 0.27, 0), Vector3(0.48, 0.54, 0.41))
