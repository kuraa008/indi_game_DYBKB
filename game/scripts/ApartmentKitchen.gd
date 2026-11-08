extends "res://scripts/ApartmentKit.gd"

# Кухня Итана: холодильник, газовая плита, шкафы со столешницей и утопленной мойкой.
# Механик здесь нет. Для thebekshdet: турка стоит на левой передней конфорке,
# тряпка лежит на столешнице; кофе и уборку плиты можно вешать на них.

const BACK_Z := -6.34      # стена за гарнитуром
const FRONT_Z := -5.72     # передняя плоскость шкафов
const TOP_Y := FL + 0.90   # верх столешницы
const END_X := 8.14        # стена с окном
const STOVE_L := 5.05
const STOVE_R := 5.67
const SINK := Vector2(7.22, -6.0)
const STEEL := Color(0.72, 0.73, 0.75)
const PAINT := Color(0.38, 0.45, 0.43)

const WORKTOP_SHADER := """
shader_type spatial;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { w = VERTEX; }
void fragment() {
	vec2 p = w.xz + w.y * vec2(0.6, 1.3);
	float big = n(p * 14.0) * 0.6 + n(p * 37.0) * 0.4;
	vec3 c = mix(vec3(0.02, 0.022, 0.026), vec3(0.05, 0.05, 0.056), big);
	float fade = 1.0 - smoothstep(0.25, 0.9, fwidth(p.x * 240.0));
	c += vec3(0.05, 0.046, 0.04) * step(0.982, h(floor(p * 240.0))) * fade;
	ALBEDO = c;
	ROUGHNESS = 0.3;
	SPECULAR = 0.5;
}
"""

const TILE_SHADER := """
shader_type spatial;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { w = VERTEX; }
void fragment() {
	vec2 size = vec2(0.15, 0.075);
	vec2 p = w.xy / size;
	p.x += 0.5 * floor(p.y);
	vec2 id = floor(p);
	vec2 f = fract(p);
	vec2 d = min(f, 1.0 - f) * size;
	float joint = smoothstep(0.001, 0.0026, min(d.x, d.y));
	vec3 tile = vec3(0.5, 0.5, 0.45) * (0.88 + 0.2 * h(id));
	ALBEDO = mix(vec3(0.09, 0.085, 0.075), tile, joint);
	ROUGHNESS = mix(0.9, 0.15, joint);
	SPECULAR = 0.55;
}
"""

const DISH_SHADER := """
shader_type spatial;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { w = VERTEX; }
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	float g = n(w.xz * 34.0) * 0.62 + n(w.xz * 95.0) * 0.38;
	float stain = smoothstep(0.52, 0.74, g) * (1.0 - COLOR.a);
	c = mix(c, vec3(0.3, 0.11, 0.035), stain * 0.62);
	ALBEDO = c;
	ROUGHNESS = mix(0.2, 0.55, stain);
}
"""

# Шахматный пол: тёплый светлый камень и тёмные плитки
const FLOOR_SHADER := """
shader_type spatial;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { w = VERTEX; }
void fragment() {
	float size = 0.3;
	vec2 p = w.xz / size;
	vec2 id = floor(p);
	vec2 f = fract(p);
	vec2 d = min(f, 1.0 - f) * size;
	float joint = smoothstep(0.0012, 0.003, min(d.x, d.y));
	float dark = mod(id.x + id.y, 2.0);
	vec3 c = mix(vec3(0.46, 0.4, 0.3), vec3(0.08, 0.075, 0.07), dark) * (0.86 + 0.26 * h(id));
	c *= 0.86 + 0.28 * (n(w.xz * 9.0 + id * 3.0) * 0.6 + n(w.xz * 27.0) * 0.4);
	ALBEDO = mix(vec3(0.14, 0.13, 0.115), c, joint);
	ROUGHNESS = mix(0.9, 0.24, joint);
	SPECULAR = 0.5;
	vec2 tilt = (vec2(h(id + 3.1), h(id + 5.7)) - 0.5) * 0.035;
	vec2 bevel = sign(f - 0.5) * (1.0 - smoothstep(0.0, 0.008, d)) * 0.35;
	NORMAL = normalize((VIEW_MATRIX * vec4(tilt.x + bevel.x, 1.0, tilt.y + bevel.y, 0.0)).xyz);
}
"""

var _handles: Array = []


func _ready() -> void:
	name = "ApartmentKitchen"
	_rng.seed = 3377
	_build_fridge()
	_build_stove()
	_build_cabinets()
	_build_worktop()
	_build_sink()
	_build_small_things()
	_bx(Vector3(4.0, 0.004, 5.4), Vector3(6.2, FL, -3.7), Color.WHITE)
	_flush(_shader(FLOOR_SHADER))
	_solid(Vector3(4.66, FL + 0.9, -6.0), Vector3(0.74, 1.8, 0.68))
	_solid(Vector3((STOVE_L + STOVE_R) * 0.5, FL + 0.46, -6.03), Vector3(STOVE_R - STOVE_L, 0.92, 0.62))
	_solid(Vector3((STOVE_R + END_X) * 0.5, TOP_Y * 0.5, -6.01), Vector3(END_X - STOVE_R, TOP_Y, 0.66))


# ── Холодильник: корпус, две дверцы с уплотнителем, ручки на стойках ──

func _build_fridge() -> void:
	var w := 0.74
	var enamel := Color(0.76, 0.76, 0.74)
	var door_t := 0.058
	var at := Vector3(4.66, FL, -5.76)
	_base = _xf(at)
	_loft([
		_rg(w * 0.5 - 0.002, 0.28, 0.012, 0.08, 0.0, -0.28),
		_rg(w * 0.5, 0.28, 0.014, 0.1, 0.0, -0.28),
		_rg(w * 0.5, 0.28, 0.014, 1.79, 0.0, -0.28),
		_rg(w * 0.5 - 0.006, 0.274, 0.014, 1.8, 0.0, -0.28),
		_rg(0.0, 0.0, 0.0, 1.8, 0.0, -0.28),
	], enamel.darkened(0.08), Transform3D.IDENTITY, 3)
	_fridge_door(w, 0.09, 1.29, door_t, enamel)
	_fridge_door(w, 1.298, 1.8, door_t, enamel)
	_flush(_vmat(0.22))

	# Тёмные детали: цоколь с решёткой, уплотнители, петли
	_base = _xf(at)
	_bx(Vector3(w - 0.02, 0.085, 0.5), Vector3(0, 0.0425, -0.27), Color(0.05, 0.05, 0.055))
	for k in range(5):
		_bx(Vector3(w - 0.09, 0.006, 0.004), Vector3(0, 0.02 + float(k) * 0.012, -0.018), Color(0.22, 0.22, 0.24))
	for y_pair in [[0.09, 1.29], [1.298, 1.8]]:
		var h: float = float(y_pair[1]) - float(y_pair[0])
		_bx(Vector3(w - 0.012, h - 0.012, 0.014), Vector3(0, float(y_pair[0]) + h * 0.5, 0.006), Color(0.1, 0.1, 0.1))
	for y in [0.09, 1.294, 1.8]:
		_bx(Vector3(0.05, 0.014, 0.075), Vector3(-w * 0.5 + 0.04, y, 0.036), Color(0.16, 0.16, 0.17))
	_flush(_vmat(0.6))

	# Ручки у щели между дверцами и шильдик
	_base = _xf(at)
	var face := 0.012 + door_t
	var hx := w * 0.5 - 0.06
	_bar_handle(Vector3(hx, 1.36, face), Vector3(hx, 1.64, face), 0.042, 0.0115)
	_bar_handle(Vector3(hx, 0.74, face), Vector3(hx, 1.23, face), 0.042, 0.0115)
	_bx(Vector3(0.075, 0.016, 0.002), Vector3(-w * 0.5 + 0.11, 1.72, face + 0.002), STEEL)
	_flush(_vmat(0.3, 0.6))

	# Записки на магнитах: только полоски почерка, без текста
	var z := face + 0.0065
	_base = _xf(at)
	_bx(Vector3(0.14, 0.2, 0.001), Vector3(-0.12, 1.08, z), Color(0.82, 0.8, 0.7), Vector3(0, 0, 3))
	for k in range(7):
		var ln := _rng.randf_range(0.06, 0.11)
		_bx(Vector3(ln, 0.0035, 0.001), Vector3(-0.17 + ln * 0.5, 1.15 - float(k) * 0.024, z + 0.0008), Color(0.2, 0.22, 0.32), Vector3(0, 0, 3))
	_bx(Vector3(0.1, 0.13, 0.001), Vector3(0.05, 1.0, z), Color(0.72, 0.66, 0.5), Vector3(0, 0, -4))
	_bx(Vector3(0.085, 0.09, 0.001), Vector3(0.05, 1.008, z + 0.0008), Color(0.26, 0.36, 0.3), Vector3(0, 0, -4))
	_bx(Vector3(0.085, 0.03, 0.001), Vector3(0.0525, 1.033, z + 0.0014), Color(0.48, 0.56, 0.62), Vector3(0, 0, -4))
	_bx(Vector3(0.075, 0.075, 0.001), Vector3(-0.2, 0.86, z), Color(0.78, 0.68, 0.24), Vector3(0, 0, -6))
	_flush(_vmat(0.85))
	_base = _xf(at)
	_cy(0.014, 0.015, 0.008, Vector3(-0.12, 1.17, z + 0.004), Color(0.62, 0.14, 0.1), Vector3(90, 0, 0), 14)
	_cy(0.014, 0.015, 0.008, Vector3(0.056, 1.058, z + 0.004), Color(0.16, 0.3, 0.55), Vector3(90, 0, 0), 14)
	_flush(_vmat(0.3))

	# На холодильнике: коробка хлопьев и корзинка
	_base = _xf(Vector3(4.66, FL + 1.8, -6.02))
	_bx(Vector3(0.19, 0.28, 0.07), Vector3(-0.16, 0.14, 0.02), Color(0.66, 0.24, 0.1), Vector3(0, 11, 0))
	_bx(Vector3(0.192, 0.06, 0.072), Vector3(-0.16, 0.2, 0.02), Color(0.84, 0.76, 0.5), Vector3(0, 11, 0))
	_flush(_vmat(0.75))
	_base = _xf(Vector3(4.82, FL + 1.8, -6.04))
	var wicker := Color(0.46, 0.33, 0.18)
	_loft([
		_rg(0.09, 0.09, 0.09, 0.0),
		_rg(0.115, 0.115, 0.115, 0.1),
		_rg(0.112, 0.112, 0.112, 0.108),
		_rg(0.102, 0.102, 0.102, 0.104),
		_rg(0.082, 0.082, 0.082, 0.01),
		_rg(0.0, 0.0, 0.0, 0.008),
	], wicker, Transform3D.IDENTITY, 5, [wicker, wicker, wicker, wicker.darkened(0.2), wicker.darkened(0.6), wicker.darkened(0.6)])
	_flush(_vmat(0.9))


func _fridge_door(w: float, y0: float, y1: float, t: float, col: Color) -> void:
	var hx := w * 0.5 - 0.003
	var hz := (y1 - y0) * 0.5 - 0.002
	var xf := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, (y0 + y1) * 0.5, 0.012))
	_loft([
		_rg(hx - 0.004, hz - 0.004, 0.03, 0.0),
		_rg(hx, hz, 0.032, 0.008),
		_rg(hx, hz, 0.032, t - 0.016),
		_rg(hx - 0.003, hz - 0.003, 0.032, t - 0.006),
		_rg(hx - 0.012, hz - 0.012, 0.03, t - 0.001),
		_rg(hx - 0.03, hz - 0.03, 0.03, t),
		_rg(hx - 0.05, hz - 0.05, 0.03, t),
		_rg(0.0, 0.0, 0.0, t),
	], col, xf, 5)


# Ручка-скоба: перекладина на двух стойках, out — куда она отходит
func _bar_handle(a: Vector3, b: Vector3, stand: float, r: float, out: Vector3 = Vector3.BACK) -> void:
	var dir := (b - a).normalized()
	_tube([a + out * stand, a.lerp(b, 0.5) + out * stand, b + out * stand], r, STEEL, 10)
	for p in [a + dir * r * 2.5, b - dir * r * 2.5]:
		_pipe(p, p + out * stand, r * 0.72, STEEL)


# ── Газовая плита ──

func _build_stove() -> void:
	var cx := (STOVE_L + STOVE_R) * 0.5
	var w := 0.6
	var enamel := Color(0.72, 0.72, 0.71)
	var iron := Color(0.05, 0.05, 0.055)
	_base = _xf(Vector3(cx, FL, FRONT_Z))
	_bx(Vector3(w, 0.88, 0.6), Vector3(0, 0.44, -0.3), enamel.darkened(0.12))
	_bx(Vector3(w - 0.012, 0.145, 0.018), Vector3(0, 0.1075, 0.009), enamel)
	_bx(Vector3(w - 0.012, 0.55, 0.032), Vector3(0, 0.46, 0.016), enamel)
	_bx(Vector3(w, 0.06, 0.02), Vector3(0, 0.92, -0.59), enamel)
	_flush(_vmat(0.26))

	_base = _xf(Vector3(cx, FL, FRONT_Z))
	_bx(Vector3(w, 0.013, 0.6), Vector3(0, 0.8865, -0.3), STEEL)
	_bx(Vector3(w - 0.012, 0.12, 0.02), Vector3(0, 0.805, 0.01), STEEL.darkened(0.14))
	_bar_handle(Vector3(-0.235, 0.69, 0.032), Vector3(0.235, 0.69, 0.032), 0.04, 0.0105)
	_bar_handle(Vector3(-0.11, 0.1075, 0.018), Vector3(0.11, 0.1075, 0.018), 0.03, 0.0085)
	for k in range(5):
		var x := -0.22 + float(k) * 0.11
		_cy(0.021, 0.024, 0.028, Vector3(x, 0.805, 0.034), STEEL, Vector3(90, 0, 0), 16)
		_bx(Vector3(0.005, 0.03, 0.004), Vector3(x, 0.805, 0.048), Color(0.14, 0.14, 0.15), Vector3(0, 0, -30.0 + float(k) * 22.0))
	# Конфорки
	var burners := [[-0.145, -0.16, 0.85], [0.145, -0.16, 1.1], [-0.145, -0.44, 1.1], [0.145, -0.44, 0.85]]
	for b in burners:
		var size: float = b[2]
		_cy(0.056 * size, 0.062 * size, 0.012, Vector3(b[0], 0.899, b[1]), STEEL.darkened(0.08), Vector3.ZERO, 22)
	_flush(_vmat(0.36, 0.55))

	# Стекло духовки с внутренней рамкой
	_base = _xf(Vector3(cx, FL, FRONT_Z))
	_bx(Vector3(0.44, 0.33, 0.004), Vector3(0, 0.44, 0.033), Color(0.025, 0.025, 0.03))
	_flush(_vmat(0.1))
	_base = _xf(Vector3(cx, FL, FRONT_Z))
	_bx(Vector3(0.07, 0.022, 0.002), Vector3(0, 0.845, 0.0208), Color(0.03, 0.04, 0.03))

	# Чугунные решётки и крышки конфорок
	var y := 0.927
	var bar := func(x0: float, z0: float, x1: float, z1: float) -> void:
		_bx(Vector3(absf(x1 - x0) + 0.011, 0.012, absf(z1 - z0) + 0.011), Vector3((x0 + x1) * 0.5, y, (z0 + z1) * 0.5), iron)
	for s in [-1.0, 1.0]:
		bar.call(s * 0.283, -0.03, s * 0.283, -0.57)
		bar.call(s * 0.012, -0.03, s * 0.012, -0.57)
		bar.call(s * 0.012, -0.03, s * 0.283, -0.03)
		bar.call(s * 0.012, -0.57, s * 0.283, -0.57)
		bar.call(s * 0.012, -0.3, s * 0.283, -0.3)
		for bz in [-0.16, -0.44]:
			bar.call(s * 0.012, bz, s * 0.105, bz)
			bar.call(s * 0.185, bz, s * 0.283, bz)
			var near := -0.03 if bz > -0.3 else -0.3
			var far := -0.3 if bz > -0.3 else -0.57
			bar.call(s * 0.145, near, s * 0.145, bz + 0.04)
			bar.call(s * 0.145, bz - 0.04, s * 0.145, far)
		for fx in [0.02, 0.275]:
			for fz in [-0.04, -0.3, -0.56]:
				_bx(Vector3(0.014, 0.03, 0.014), Vector3(s * fx, 0.907, fz), iron)
	for b in burners:
		var size: float = b[2]
		_cy(0.04 * size, 0.046 * size, 0.008, Vector3(b[0], 0.909, b[1]), Color(0.1, 0.09, 0.08), Vector3.ZERO, 18)
		_cy(0.032 * size, 0.038 * size, 0.008, Vector3(b[0], 0.917, b[1]), iron, Vector3.ZERO, 18)
	_flush(_vmat(0.62))

	# Турка на левой передней конфорке
	_base = _xf(Vector3(cx - 0.145, FL + 0.933, FRONT_Z - 0.16))
	_cy(0.038, 0.052, 0.07, Vector3(0, 0.035, 0), Color(0.62, 0.34, 0.17), Vector3.ZERO, 18)
	_cy(0.046, 0.038, 0.024, Vector3(0, 0.082, 0), Color(0.62, 0.34, 0.17), Vector3.ZERO, 18, false)
	_flush(_vmat(0.4, 0.7, true))
	_base = _xf(Vector3(cx - 0.145, FL + 0.933, FRONT_Z - 0.16))
	_cy(0.037, 0.037, 0.002, Vector3(0, 0.086, 0), Color(0.08, 0.05, 0.03), Vector3.ZERO, 18)
	_pipe(Vector3(0.04, 0.075, 0), Vector3(0.2, 0.115, 0), 0.008, Color(0.1, 0.08, 0.07))
	_flush(_vmat(0.55))

	# Вытяжка над плитой с коробом до потолка
	_base = _xf(Vector3(cx, FL, BACK_Z + 0.25))
	_loft([
		_rg(0.0, 0.0, 0.0, 1.58),
		_rg(0.3, 0.25, 0.012, 1.58),
		_rg(0.3, 0.25, 0.012, 1.64),
		_rg(0.125, 0.12, 0.012, 1.88, 0.0, -0.13),
		_rg(0.125, 0.12, 0.012, 2.7, 0.0, -0.13),
	], STEEL, Transform3D.IDENTITY, 2)
	_flush(_vmat(0.38, 0.5))
	_base = _xf(Vector3(cx, FL, BACK_Z + 0.25))
	_bx(Vector3(0.46, 0.003, 0.32), Vector3(0, 1.578, 0), Color(0.06, 0.06, 0.07))
	_flush(_vmat(0.6))


# ── Шкафы ──

# Фасад с рамкой: филёнка и четыре планки вокруг
func _front(x0: float, x1: float, y0: float, y1: float, z: float) -> void:
	var gap := 0.0025
	var w := x1 - x0 - gap * 2.0
	var h := y1 - y0 - gap * 2.0
	var cx := (x0 + x1) * 0.5
	var cy := (y0 + y1) * 0.5
	var rail := minf(0.065, h * 0.22)
	_bx(Vector3(w, h, 0.012), Vector3(cx, cy, z + 0.006), PAINT.darkened(0.12))
	for s in [-1.0, 1.0]:
		_bx(Vector3(rail, h, 0.02), Vector3(cx + s * (w - rail) * 0.5, cy, z + 0.01), PAINT)
		_bx(Vector3(w - rail * 2.0, rail, 0.02), Vector3(cx, cy + s * (h - rail) * 0.5, z + 0.01), PAINT)


func _handle(centre: Vector3, vertical: bool, length: float) -> void:
	_handles.append([centre, vertical, length])


func _door(x0: float, x1: float, y0: float, y1: float, z: float, hinge_left: bool, handle_y: float) -> void:
	_front(x0, x1, y0, y1, z)
	var x := x1 - 0.034 if hinge_left else x0 + 0.034
	_handle(Vector3(x, handle_y, z + 0.02), true, 0.14)


func _build_cabinets() -> void:
	var y0 := FL + 0.09
	var y1 := FL + 0.86
	var z := FRONT_Z
	var modules := [5.67, 6.29, 6.91, 7.53, END_X]
	# Задник за фасадами; верхней крышки нет, чтобы чаша мойки не упиралась
	_bx(Vector3(END_X - modules[0], y1 - y0, 0.01), Vector3((END_X + modules[0]) * 0.5, (y0 + y1) * 0.5, z - 0.005), PAINT.darkened(0.4))
	# Первый модуль с ящиками
	var drawer_tops := [y0, FL + 0.34, FL + 0.6, y1]
	for k in range(3):
		_front(modules[0], modules[1], drawer_tops[k], drawer_tops[k + 1], z)
		_handle(Vector3((modules[0] + modules[1]) * 0.5, (drawer_tops[k] + drawer_tops[k + 1]) * 0.5, z + 0.02), false, 0.16)
	_door(modules[1], modules[2], y0, y1, z, true, y1 - 0.14)
	# Двойные дверцы под мойкой
	var mid: float = (float(modules[2]) + float(modules[3])) * 0.5
	_door(modules[2], mid, y0, y1, z, true, y1 - 0.14)
	_door(mid, modules[3], y0, y1, z, false, y1 - 0.14)
	_door(modules[3], modules[4], y0, y1, z, false, y1 - 0.14)

	# Навесные шкафы над столешницей
	var wy0 := FL + 1.5
	var wy1 := FL + 2.22
	var depth := 0.32
	var wx := 5.74
	var ww := 0.62
	_bx(Vector3(ww * 3.0, wy1 - wy0, depth), Vector3(wx + ww * 1.5, (wy0 + wy1) * 0.5, BACK_Z + depth * 0.5), PAINT.darkened(0.2))
	for k in range(3):
		_door(wx + float(k) * ww, wx + float(k + 1) * ww, wy0, wy1, BACK_Z + depth, k % 2 == 0, wy0 + 0.12)
	_flush(_vmat(0.58), true)

	# Цоколь
	_bx(Vector3(END_X - modules[0], 0.09, 0.02), Vector3((END_X + modules[0]) * 0.5, FL + 0.045, z - 0.05), Color(0.07, 0.07, 0.075))
	_flush(_vmat(0.7))

	for h in _handles:
		var c: Vector3 = h[0]
		var half: float = float(h[2]) * 0.5
		var along := Vector3.UP if h[1] else Vector3.RIGHT
		_bar_handle(c - along * half, c + along * half, 0.026, 0.0058)
	_flush(_vmat(0.32, 0.6))


# Столешница вырезана под мойку; плитка на стене — фартук
func _build_worktop() -> void:
	var x0 := STOVE_R
	var z_f := FRONT_Z + 0.04
	var y := TOP_Y - 0.02
	var hole := Vector2(0.26, 0.19)
	var left := SINK.x - hole.x
	var right := SINK.x + hole.x
	_bx(Vector3(left - x0, 0.04, z_f - BACK_Z), Vector3((left + x0) * 0.5, y, (z_f + BACK_Z) * 0.5), Color.WHITE)
	_bx(Vector3(END_X - right, 0.04, z_f - BACK_Z), Vector3((END_X + right) * 0.5, y, (z_f + BACK_Z) * 0.5), Color.WHITE)
	var hole_back := SINK.y - hole.y
	var hole_front := SINK.y + hole.y
	_bx(Vector3(hole.x * 2.0, 0.04, hole_back - BACK_Z), Vector3(SINK.x, y, (hole_back + BACK_Z) * 0.5), Color.WHITE)
	_bx(Vector3(hole.x * 2.0, 0.04, z_f - hole_front), Vector3(SINK.x, y, (z_f + hole_front) * 0.5), Color.WHITE)
	_flush(_shader(WORKTOP_SHADER))

	_bx(Vector3(END_X - STOVE_L, 0.56, 0.008), Vector3((END_X + STOVE_L) * 0.5, TOP_Y + 0.28, BACK_Z + 0.004), Color.WHITE)
	_flush(_shader(TILE_SHADER))


# ── Мойка: глубокая чаша из стали, кран, посуда ──

func _build_sink() -> void:
	var steel := Color(0.8, 0.81, 0.83)
	var low := steel.darkened(0.42)
	_base = _xf(Vector3(SINK.x, TOP_Y, SINK.y))
	_loft([
		_rg(0.295, 0.225, 0.04, 0.0),
		_rg(0.295, 0.225, 0.04, 0.004),
		_rg(0.289, 0.219, 0.04, 0.007),
		_rg(0.265, 0.195, 0.05, 0.006),
		_rg(0.255, 0.185, 0.05, 0.002),
		_rg(0.25, 0.18, 0.055, -0.004),
		_rg(0.246, 0.176, 0.06, -0.12),
		_rg(0.232, 0.162, 0.065, -0.168),
		_rg(0.205, 0.138, 0.06, -0.183),
		_rg(0.06, 0.06, 0.06, -0.19, 0.11, 0.05),
		_rg(0.0, 0.0, 0.0, -0.193, 0.11, 0.05),
	], steel, Transform3D.IDENTITY, 6, [steel, steel, steel, steel, steel, steel, steel.darkened(0.2), low, low, low, low])
	_cy(0.036, 0.036, 0.003, Vector3(0.11, -0.19, 0.05), steel, Vector3.ZERO, 20)
	# Кран с изогнутым носиком
	_base = _xf(Vector3(SINK.x, TOP_Y, SINK.y - 0.255))
	_cy(0.024, 0.029, 0.032, Vector3(0, 0.016, 0), STEEL, Vector3.ZERO, 18)
	_tube(_smooth([Vector3(0, 0.03, 0), Vector3(0, 0.14, 0), Vector3(0, 0.25, 0.002), Vector3(0, 0.318, 0.042),
		Vector3(0, 0.328, 0.102), Vector3(0, 0.292, 0.162), Vector3(0, 0.235, 0.178)], 7), 0.0105, STEEL, 12)
	_cy(0.0135, 0.0135, 0.026, Vector3(0, 0.226, 0.1785), STEEL.darkened(0.15), Vector3.ZERO, 12)
	_cy(0.017, 0.017, 0.034, Vector3(0, 0.08, 0), STEEL, Vector3.ZERO, 14)
	_tube([Vector3(0.012, 0.09, 0), Vector3(0.06, 0.108, 0), Vector3(0.1, 0.115, 0)], 0.0065, STEEL, 8)
	_flush(_vmat(0.32, 0.5))
	_base = _xf(Vector3(SINK.x, TOP_Y, SINK.y))
	_cy(0.02, 0.02, 0.003, Vector3(0.11, -0.1875, 0.05), Color(0.05, 0.05, 0.06), Vector3.ZERO, 14)
	_flush(_vmat(0.6))

	# Грязные тарелки стопкой и одна прислонена к стенке
	var white := Color(0.86, 0.85, 0.8)
	var dirty := Color(0.86, 0.85, 0.8, 0.0)
	_base = _xf(Vector3(SINK.x, TOP_Y, SINK.y))
	for k in range(3):
		var off := Vector3(-0.07 + _rng.randf_range(-0.01, 0.01), -0.178 + float(k) * 0.016, -0.02 + _rng.randf_range(-0.01, 0.01))
		_plate(off, Vector3(_rng.randf_range(-2.0, 2.0), 0, _rng.randf_range(-2.0, 2.0)), white, dirty if k == 2 else white)
	_plate(Vector3(0.09, -0.07, -0.1), Vector3(-68, 0, 4), white, white)
	_flush(_shader(DISH_SHADER))

	# Вилка в тарелке
	_base = _xf(Vector3(SINK.x - 0.07, TOP_Y - 0.135, SINK.y - 0.02), Vector3(0, 35, 0))
	_bx(Vector3(0.012, 0.002, 0.13), Vector3(0, 0.0, 0.045), STEEL)
	_bx(Vector3(0.026, 0.002, 0.03), Vector3(0, 0.002, -0.03), STEEL)
	for k in range(3):
		_bx(Vector3(0.004, 0.002, 0.042), Vector3(-0.01 + float(k) * 0.01, 0.004, -0.066), STEEL)
	_flush(_vmat(0.3, 0.6))


func _plate(pos: Vector3, tilt: Vector3, rim_col: Color, inner_col: Color) -> void:
	_loft([
		_rg(0.06, 0.06, 0.06, 0.0),
		_rg(0.07, 0.07, 0.07, 0.001),
		_rg(0.115, 0.115, 0.115, 0.017),
		_rg(0.128, 0.128, 0.128, 0.024),
		_rg(0.127, 0.127, 0.127, 0.0265),
		_rg(0.11, 0.11, 0.11, 0.021),
		_rg(0.072, 0.072, 0.072, 0.0055),
		_rg(0.0, 0.0, 0.0, 0.005),
	], rim_col, _xf(pos, tilt), 5, [rim_col, rim_col, rim_col, rim_col, rim_col, inner_col, inner_col, inner_col])


func _build_small_things() -> void:
	# Средство для посуды, банка кофе
	_bottle(Vector3(SINK.x + 0.385, TOP_Y, -6.2), 0.032, 0.2, Color(0.16, 0.45, 0.26), Color(0.85, 0.85, 0.8))
	_base = _xf(Vector3(STOVE_R + 0.17, TOP_Y, -6.2))
	var tin := Color(0.5, 0.18, 0.12)
	_loft([
		_rg(0.05, 0.05, 0.05, 0.0),
		_rg(0.05, 0.05, 0.05, 0.13),
		_rg(0.0, 0.0, 0.0, 0.13),
	], tin, Transform3D.IDENTITY, 5)
	_loft([
		_rg(0.053, 0.053, 0.053, 0.125),
		_rg(0.053, 0.053, 0.053, 0.15),
		_rg(0.048, 0.048, 0.048, 0.155),
		_rg(0.0, 0.0, 0.0, 0.155),
	], Color(0.72, 0.68, 0.6), Transform3D.IDENTITY, 5)
	_flush(_vmat(0.3))

	# Губка на бортике мойки: жёлтая с зелёным жёстким слоем
	_base = _xf(Vector3(SINK.x + 0.385, TOP_Y, -5.92), Vector3(0, 20, 0))
	_bx(Vector3(0.1, 0.022, 0.065), Vector3(0, 0.011, 0), Color(0.82, 0.68, 0.22))
	_bx(Vector3(0.1, 0.007, 0.065), Vector3(0, 0.0255, 0), Color(0.16, 0.34, 0.2))
	# Сложенное кухонное полотенце на столешнице
	var towel := Color(0.72, 0.7, 0.64)
	_base = _xf(Vector3(6.4, TOP_Y, -5.92), Vector3(0, 14, 0))
	for k in range(2):
		var y := float(k) * 0.011
		_loft([
			_rg(0.125, 0.085, 0.012, y),
			_rg(0.128, 0.088, 0.012, y + 0.005),
			_rg(0.124, 0.084, 0.012, y + 0.0105),
			_rg(0.0, 0.0, 0.0, y + 0.0112),
		], towel, _xf(Vector3(float(k) * 0.004, 0, float(k) * -0.003)), 2)
	for sx in [-0.095, -0.08, 0.087, 0.102]:
		_bx(Vector3(0.007, 0.0006, 0.165), Vector3(sx, 0.0224, -0.003), Color(0.55, 0.16, 0.12))
	_flush(_vmat(0.9))
