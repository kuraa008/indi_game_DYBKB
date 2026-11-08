extends "res://scripts/ApartmentKit.gd"

# Мелкие вещи в комнате и спальне Итана: пицца, ноутбук, книжная полка, одежда.
# Кухня, ванная и коридор лежат в своих файлах рядом. Механик здесь нет.

const COFFEE_TOP := Vector3(0.25, 0.46 + FL, 0.25)
const DESK_Y := FL + 0.75

# Сколько кусков пиццы уже съедено: они отсекаются от сетки и от рисунка
const PIZZA_SEGS := 64
const PIZZA_SLICE_SEGS := 8
const PIZZA_EATEN := 2

const PIZZA_SHADER := """
shader_type spatial;
render_mode cull_disabled;
varying vec2 p;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 v) { return n(v) * 0.55 + n(v * 2.3 + 7.0) * 0.3 + n(v * 5.1 + 3.0) * 0.15; }
void vertex() { p = VERTEX.xz; }
void fragment() {
	float r = length(p);
	float big = fbm(p * 42.0);
	float fine = fbm(p * 150.0);
	vec3 cheese = mix(vec3(0.62, 0.34, 0.07), vec3(0.8, 0.53, 0.16), big);
	cheese = mix(cheese, vec3(0.26, 0.11, 0.025), smoothstep(0.66, 0.74, fbm(p * 65.0 + 11.0)));
	vec3 sauce = vec3(0.3, 0.05, 0.015) * (0.7 + 0.5 * fine);
	float edge = 0.138 + 0.012 * big;
	vec3 c = mix(cheese, sauce, smoothstep(edge - 0.006, edge, r));
	vec3 crust = mix(vec3(0.56, 0.3, 0.09), vec3(0.22, 0.09, 0.025), smoothstep(0.42, 0.68, fbm(p * 90.0)));
	c = mix(c, crust, smoothstep(0.146, 0.152, r));
	float a = mod(atan(p.y, p.x) + TAU, PI / 4.0);
	float cut = min(a, PI / 4.0 - a) * r;
	c *= mix(0.42, 1.0, smoothstep(0.0006, 0.0022, cut));
	if (COLOR.r > 0.5) { c = vec3(0.6, 0.38, 0.14) * (0.7 + 0.4 * fine); }
	ALBEDO = c;
	ROUGHNESS = mix(0.42, 0.85, smoothstep(0.14, 0.15, r));
	SPECULAR = 0.45;
}
"""

const CARDBOARD_SHADER := """
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
	vec2 uv = vec2(w.x + w.z * 0.37, w.y * 0.83 + w.z);
	float fib = n(uv * vec2(900.0, 240.0)) * 0.6 + n(uv * 320.0) * 0.4;
	vec3 c = pow(COLOR.rgb, vec3(2.2)) * (0.86 + 0.26 * fib);
	float g = n(uv * 24.0) * 0.6 + n(uv * 61.0) * 0.4;
	c *= mix(1.0, mix(1.0, 0.64, smoothstep(0.52, 0.72, g)), 1.0 - COLOR.a);
	ALBEDO = c;
	ROUGHNESS = 0.93;
	SPECULAR = 0.2;
}
"""

const LAPTOP_SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded;
float box(vec2 p, vec2 a, vec2 b) { return step(a.x, p.x) * step(p.x, b.x) * step(a.y, p.y) * step(p.y, b.y); }
void fragment() {
	vec2 uv = UV;
	vec3 c = mix(vec3(0.03, 0.06, 0.13), vec3(0.09, 0.1, 0.2), uv.x * 0.6 + uv.y * 0.4);
	c = mix(c, vec3(0.5, 0.52, 0.55), box(uv, vec2(0.12, 0.09), vec2(0.88, 0.86)));
	c = mix(c, vec3(0.13, 0.15, 0.2), box(uv, vec2(0.12, 0.09), vec2(0.88, 0.15)));
	float lines = step(0.45, fract(uv.y * 26.0)) * step(0.5, fract(sin(floor(uv.y * 26.0) * 91.7) * 43.7) * 0.5 + 0.55 - uv.x * 0.5);
	c = mix(c, vec3(0.2, 0.21, 0.24), lines * box(uv, vec2(0.17, 0.22), vec2(0.83, 0.8)));
	c = mix(c, vec3(0.04, 0.045, 0.07), box(uv, vec2(0.0, 0.94), vec2(1.0, 1.0)));
	ALBEDO = c * 0.72;
}
"""

const BOOK_COLORS := [
	Color(0.32, 0.1, 0.09), Color(0.14, 0.2, 0.33), Color(0.13, 0.25, 0.2), Color(0.46, 0.38, 0.24),
	Color(0.2, 0.17, 0.15), Color(0.5, 0.45, 0.38), Color(0.42, 0.24, 0.11), Color(0.27, 0.29, 0.34),
	Color(0.55, 0.15, 0.12), Color(0.1, 0.1, 0.12), Color(0.66, 0.6, 0.48), Color(0.2, 0.34, 0.42),
]

func _ready() -> void:
	name = "ApartmentProps"
	_rng.seed = 7741
	_build_pizza()
	_build_table_small()
	_build_laptop()
	_build_notebook()
	_flush(_vmat(0.55))
	_build_bookshelf()
	_build_sofa()
	_build_clothes()


# ── Коробка с пиццей: дно с бортиками, крышка с клапанами, внутри пятна жира ──

func _build_pizza() -> void:
	var W := 0.39
	var H := 0.045
	var T := 0.004
	var kraft := Color(0.6, 0.46, 0.31)
	var kraft_edge := Color(0.48, 0.36, 0.24)
	var outer := Color(0.8, 0.76, 0.68)
	var greasy := Color(0.6, 0.46, 0.31, 0.0)
	var red := Color(0.62, 0.11, 0.08)
	var at := _xf(COFFEE_TOP + Vector3(-0.2, 0.0, 0.0), Vector3(0, 12, 0))

	_base = at
	_bx(Vector3(W, T, W), Vector3(0, T * 0.5, 0), greasy)
	_bx(Vector3(W, H, T), Vector3(0, H * 0.5, -W * 0.5), kraft)
	_bx(Vector3(T, H, W), Vector3(-W * 0.5, H * 0.5, 0), kraft)
	_bx(Vector3(T, H, W), Vector3(W * 0.5, H * 0.5, 0), kraft)
	# Передний борт двойной: внешняя стенка и загнутый внутрь край
	_bx(Vector3(W, H, T), Vector3(0, H * 0.5, W * 0.5), kraft)
	_bx(Vector3(W - T * 2.0, H * 0.8, T), Vector3(0, H * 0.4, W * 0.5 - 0.012), kraft_edge)
	_bx(Vector3(W - T * 2.0, T, 0.012), Vector3(0, H * 0.8, W * 0.5 - 0.006), kraft)
	# Боковые борта тоже загнуты, сверху видна кромка
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.012, T, W - 0.04), Vector3(s * (W * 0.5 - 0.006), H * 0.85, 0), kraft)
		_bx(Vector3(T, H * 0.85, W - 0.04), Vector3(s * (W * 0.5 - 0.012), H * 0.42, 0), kraft_edge)

	# Крышка: в закрытом виде лежит вдоль +Z, открыта вокруг задней кромки
	_base = at * _xf(Vector3(0, H, -W * 0.5), Vector3(-104, 0, 0))
	var lid_up := Vector3(0, T * 0.5, W * 0.5)
	_bx(Vector3(W, T, W), lid_up, outer)
	_bx(Vector3(W - 0.004, 0.001, W - 0.004), Vector3(0, -0.0003, W * 0.5), Color(0.6, 0.46, 0.31, 0.8))
	_bx(Vector3(W, H * 0.9, T), Vector3(0, -H * 0.45, W), kraft)
	_bx(Vector3(W * 0.55, H * 1.3, T), Vector3(0, -H * 1.25, W - 0.001), kraft_edge)
	for s in [-1.0, 1.0]:
		_bx(Vector3(T, H * 0.8, W - 0.03), Vector3(s * W * 0.5, -H * 0.4, W * 0.5), kraft)
	# Рисунок на внешней стороне крышки
	_bx(Vector3(W, 0.0006, 0.05), Vector3(0, T + 0.0003, 0.05), red)
	_bx(Vector3(W, 0.0006, 0.05), Vector3(0, T + 0.0003, W - 0.05), red)
	_cy(0.1, 0.1, 0.0006, Vector3(0, T + 0.0003, W * 0.5), red, Vector3.ZERO, 28)
	var lid_base := _base
	var label := CutsceneKit.text3d(self, "PIZZA", Vector3.ZERO, Vector3.ZERO, 0.0014, Color(0.93, 0.9, 0.82), 64)
	label.transform = lid_base * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.BACK, PI), Vector3(0, T + 0.002, W * 0.5))
	_flush(_shader(CARDBOARD_SHADER))

	_base = at
	_add_pizza_disc(at * Transform3D(Basis.IDENTITY, Vector3(0.004, T, -0.004)))
	# Пепперони лежит только на оставшихся кусках
	var pep := [[1.95, 0.075], [2.45, 0.12], [2.9, 0.06], [3.25, 0.122], [3.75, 0.083], [4.2, 0.128],
		[4.6, 0.05], [5.0, 0.112], [5.5, 0.072], [5.95, 0.125], [0.0 + 4.0, 0.02]]
	var y := T + 0.0135
	_base = at * Transform3D(Basis.IDENTITY, Vector3(0.004, 0, -0.004))
	for q in pep:
		var ang: float = q[0]
		var r: float = q[1]
		var tilt := Vector3(_rng.randf_range(-4.0, 4.0), 0, _rng.randf_range(-4.0, 4.0))
		var pos := Vector3(cos(ang) * r, y, sin(ang) * r)
		var tone := _rng.randf_range(0.85, 1.1)
		var rad := _rng.randf_range(0.0185, 0.0225)
		_cy(rad + 0.0015, rad + 0.0015, 0.0022, pos, Color(0.22, 0.05, 0.03), tilt, 16)
		_cy(rad - 0.0005, rad, 0.0036, pos, Color(0.5 * tone, 0.13 * tone, 0.08 * tone), tilt, 16)
	# Крошки в месте съеденных кусков
	for k in range(9):
		var ang := _rng.randf_range(0.15, 1.45)
		var r := _rng.randf_range(0.05, 0.15)
		var s := _rng.randf_range(0.0015, 0.004)
		_bl(Vector3(s, s * 0.6, s), Vector3(cos(ang) * r, T + s * 0.5, sin(ang) * r), Color(0.6, 0.4, 0.18))
	_flush(_vmat(0.7))


# Круг с настоящим бортиком из теста; съеденные куски в сетке отсутствуют
func _add_pizza_disc(xf: Transform3D) -> void:
	var radii := [0.0, 0.05, 0.1, 0.135, 0.147, 0.154, 0.161, 0.166, 0.168]
	var heights := [0.012, 0.012, 0.012, 0.0125, 0.017, 0.0245, 0.0255, 0.016, 0.002]
	var first_seg := PIZZA_EATEN * PIZZA_SLICE_SEGS
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color.BLACK)
	var point := func(ring: int, seg: int, y: float) -> Vector3:
		var a := TAU * float(seg) / float(PIZZA_SEGS)
		var wobble := 1.0 + 0.012 * sin(a * 5.0 + 1.2) * float(ring) / float(radii.size())
		var r: float = radii[ring] * wobble
		return Vector3(cos(a) * r, y, sin(a) * r)
	for seg in range(first_seg, PIZZA_SEGS):
		for ring in range(radii.size() - 1):
			var ya: float = heights[ring]
			var yb: float = heights[ring + 1]
			var a0: Vector3 = point.call(ring, seg, ya)
			var b0: Vector3 = point.call(ring + 1, seg, yb)
			var b1: Vector3 = point.call(ring + 1, seg + 1, yb)
			var a1: Vector3 = point.call(ring, seg + 1, ya)
			for v in [a0, b0, b1, a0, b1, a1]:
				st.add_vertex(v)
	# Срезы теста там, где куски отрезаны
	st.set_color(Color.WHITE)
	st.set_smooth_group(-1)
	for seg in [first_seg, PIZZA_SEGS]:
		for ring in range(radii.size() - 1):
			var ya: float = heights[ring]
			var yb: float = heights[ring + 1]
			var top_a: Vector3 = point.call(ring, seg, ya)
			var top_b: Vector3 = point.call(ring + 1, seg, yb)
			var low_a := Vector3(top_a.x, 0.0, top_a.z)
			var low_b := Vector3(top_b.x, 0.0, top_b.z)
			for v in [low_a, top_a, top_b, low_a, top_b, low_b]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _shader(PIZZA_SHADER)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.transform = xf


# ── Диван: мягкие сиденья и спинка, круглые подлокотники, ножки, декоративные подушки ──

func _build_sofa() -> void:
	var at := Vector3(0.25, FL, 1.75)
	var cloth := Color(0.33, 0.37, 0.43)
	_base = _xf(at, Vector3(0, 180, 0))
	_softbox(Vector3(2.2, 0.2, 0.94), _xf(Vector3(0, 0.2, 0)), cloth.darkened(0.2), 0.2)
	_softbox(Vector3(1.86, 0.68, 0.22), _xf(Vector3(0, 0.56, -0.36)), cloth.darkened(0.08), 0.3)
	for s in [-1.0, 1.0]:
		_softbox(Vector3(0.2, 0.46, 0.92), _xf(Vector3(s * 1.0, 0.41, 0)), cloth.darkened(0.05), 0.3)
		_softbox(Vector3(0.26, 0.2, 0.96), _xf(Vector3(s * 1.0, 0.64, 0)), cloth, 0.62, 0.0, 0.3)
		# Сиденья чуть выступают вперёд, спинки откинуты назад
		_softbox(Vector3(0.885, 0.19, 0.74), _xf(Vector3(s * 0.445, 0.39, 0.07)), cloth, 0.26, 0.28)
		_softbox(Vector3(0.87, 0.2, 0.46), _xf(Vector3(s * 0.445, 0.72, -0.19), Vector3(77, 0, 0)), cloth, 0.3, 0.24)
	# Декоративные подушки
	_softbox(Vector3(0.42, 0.13, 0.42), _xf(Vector3(-0.68, 0.66, 0.02), Vector3(66, 14, 10)), Color(0.62, 0.44, 0.16), 0.62, 0.3)
	_softbox(Vector3(0.4, 0.13, 0.4), _xf(Vector3(0.7, 0.65, 0.03), Vector3(64, -12, -12)), Color(0.5, 0.2, 0.13), 0.62, 0.3)
	var fabric: StandardMaterial3D = CutsceneKit.tmat("fabric.png", Color.WHITE, 7.0, 0.95).duplicate()
	fabric.vertex_color_use_as_albedo = true
	fabric.vertex_color_is_srgb = true
	_flush(fabric, true)

	_base = _xf(at, Vector3(0, 180, 0))
	for sx in [-1.02, 1.02]:
		for sz in [-0.4, 0.4]:
			_cy(0.03, 0.02, 0.1, Vector3(sx, 0.05, sz), Color(0.22, 0.14, 0.08), Vector3.ZERO, 10)
	_flush(_vmat(0.5))
	_solid(at + Vector3(0, 0.45, 0), Vector3(2.24, 0.9, 0.98))


# ── Кружка и пульт на журнальном столике ──

func _build_table_small() -> void:
	_mug(COFFEE_TOP + Vector3(0.3, 0, 0.08), Color(0.84, 0.82, 0.77), 35.0, true)
	_mug(Vector3(6.44, DESK_Y, -3.46), Color(0.55, 0.62, 0.68), -70.0, false)
	_flush(_vmat(0.28, 0.0, true))

	_base = _xf(COFFEE_TOP + Vector3(0.1, 0, -0.12), Vector3(0, -20, 0))
	var body := Color(0.07, 0.07, 0.08)
	_bx(Vector3(0.05, 0.016, 0.17), Vector3(0, 0.009, 0), body)
	_bx(Vector3(0.05, 0.008, 0.05), Vector3(0, 0.012, 0.06), body, Vector3(-5, 0, 0))
	_cy(0.004, 0.004, 0.003, Vector3(-0.014, 0.0185, -0.068), Color(0.6, 0.1, 0.08))
	_torus(0.009, 0.015, Vector3(0, 0.0175, -0.03), Color(0.26, 0.27, 0.3), Vector3.ZERO, Vector3(1, 0.3, 1))
	_cy(0.0065, 0.0065, 0.003, Vector3(0, 0.0185, -0.03), Color(0.3, 0.31, 0.34))
	for row in range(4):
		for col in range(3):
			_bx(Vector3(0.009, 0.003, 0.006), Vector3(-0.013 + col * 0.013, 0.0185, 0.0 + row * 0.014), Color(0.24, 0.25, 0.28))
	_bx(Vector3(0.02, 0.0015, 0.004), Vector3(0, 0.0175, -0.076), Color(0.2, 0.2, 0.24))
	_flush(_vmat(0.5))


func _mug(pos: Vector3, col: Color, yaw: float, coffee: bool) -> void:
	_base = _xf(pos, Vector3(0, yaw, 0))
	_cy(0.043, 0.04, 0.098, Vector3(0, 0.049, 0), col, Vector3.ZERO, 20, false)
	_torus(0.0405, 0.0445, Vector3(0, 0.098, 0), col)
	_torus(0.017, 0.025, Vector3(0.056, 0.05, 0), col, Vector3(90, 0, 0), Vector3(0.75, 1, 1.3))
	if coffee:
		_cy(0.0405, 0.0405, 0.002, Vector3(0, 0.08, 0), Color(0.09, 0.05, 0.03), Vector3.ZERO, 20)
	else:
		_cy(0.0405, 0.0405, 0.002, Vector3(0, 0.03, 0), Color(0.2, 0.13, 0.09), Vector3.ZERO, 20)


# ── Ноутбук на письменном столе: экран смотрит на стул ──
# Кладётся в общий слитый меш; экран рисуется шейдером

func _build_laptop() -> void:
	var W := 0.325
	var D := 0.225
	var T := 0.015
	var alu := Color(0.36, 0.37, 0.4)
	var at := _xf(Vector3(-2.3, DESK_Y, -3.28), Vector3(0, 84, 0))
	_base = at
	_bx(Vector3(W, T - 0.004, D), Vector3(0, 0.0055 + 0.001, 0), alu)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cy(0.005, 0.005, 0.002, Vector3(sx * W * 0.42, 0.001, sz * D * 0.42), Color(0.05, 0.05, 0.05), Vector3.ZERO, 8)
	# Клавиатура: тёмная площадка и отдельные клавиши
	_bx(Vector3(W * 0.92, 0.0006, D * 0.5), Vector3(0, T, -0.038), Color(0.05, 0.05, 0.06))
	var key := Color(0.11, 0.115, 0.13)
	var pitch := 0.0212
	var rows_z := -0.038 - 0.0345
	for row in range(4):
		var shift := float(row) * 0.004
		var count := 14 - (1 if row > 0 else 0)
		for c in range(count):
			var x := -W * 0.44 + shift + float(c) * pitch + 0.009
			_bx(Vector3(0.0178, 0.0016, 0.0148), Vector3(x, T + 0.0009, rows_z + float(row) * 0.0174), key)
	var low := rows_z + 4.0 * 0.0174
	_bx(Vector3(0.105, 0.0016, 0.0148), Vector3(0, T + 0.0009, low), key)
	for side in [-1.0, 1.0]:
		for c in range(3):
			_bx(Vector3(0.0178, 0.0016, 0.0148), Vector3(side * (0.065 + float(c) * pitch), T + 0.0009, low), key)
	# Тачпад
	_bx(Vector3(0.1, 0.0005, 0.066), Vector3(0, T, 0.072), Color(0.27, 0.28, 0.31))
	_cy(0.004, 0.004, T * 0.8, Vector3(-W * 0.3, T * 0.5, -D * 0.5), Color(0.06, 0.06, 0.07), Vector3(0, 0, 90), 8)
	_cy(0.004, 0.004, T * 0.8, Vector3(W * 0.3, T * 0.5, -D * 0.5), Color(0.06, 0.06, 0.07), Vector3(0, 0, 90), 8)

	# Экран раскрыт вокруг задней кромки
	var hinge := at * _xf(Vector3(0, T, -D * 0.5), Vector3(-109, 0, 0))
	_base = hinge
	_bx(Vector3(W, 0.005, D), Vector3(0, 0.0, D * 0.5), alu)
	_bx(Vector3(W - 0.003, 0.0012, D - 0.003), Vector3(0, -0.003, D * 0.5), Color(0.02, 0.02, 0.025))
	_cy(0.017, 0.017, 0.0008, Vector3(0, 0.0028, D * 0.5), Color(0.62, 0.63, 0.66), Vector3.ZERO, 20)
	_base = Transform3D.IDENTITY
	var screen := CutsceneKit.quad(self, Vector2(W * 0.93, D * 0.87), Vector3.ZERO, _shader(LAPTOP_SCREEN_SHADER))
	screen.transform = hinge * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, -0.0042, D * 0.49))


# ── Тетрадь на пружине и ручка ──

func _build_notebook() -> void:
	_base = _xf(Vector3(-2.3, DESK_Y, -3.72), Vector3(0, 98, 0))
	var W := 0.17
	var L := 0.235
	_bx(Vector3(W, 0.0012, L), Vector3(0, 0.0006, 0), Color(0.12, 0.17, 0.26))
	_bx(Vector3(W - 0.004, 0.009, L - 0.004), Vector3(0, 0.0055, 0), Color(0.84, 0.81, 0.73))
	_bx(Vector3(W, 0.0012, L), Vector3(0, 0.0105, 0), Color(0.14, 0.2, 0.31))
	_bx(Vector3(0.1, 0.0003, 0.05), Vector3(0.01, 0.0113, -0.06), Color(0.86, 0.83, 0.75))
	for k in range(17):
		_torus(0.0035, 0.0048, Vector3(-W * 0.5 + 0.003, 0.0058, -L * 0.46 + float(k) * L * 0.0575), Color(0.3, 0.31, 0.33), Vector3(90, 90, 0))
	_base = _xf(Vector3(-2.3, DESK_Y + 0.016, -3.68), Vector3(0, 40, 0))
	_cy(0.0045, 0.0045, 0.12, Vector3(0, 0, 0), Color(0.08, 0.1, 0.2), Vector3(90, 0, 0), 8)
	_cy(0.0015, 0.0045, 0.018, Vector3(0, 0, 0.069), Color(0.65, 0.66, 0.68), Vector3(90, 0, 0), 8)
	_bx(Vector3(0.002, 0.004, 0.035), Vector3(0, 0.005, -0.04), Color(0.65, 0.66, 0.68))


# ── Книжная полка: рама, задняя стенка, ряды книг и вещи ──

func _build_bookshelf() -> void:
	var o := Vector3(1.9, FL, -2.15)
	var W := 1.0
	var H := 2.0
	var D := 0.35
	var levels := [0.09, 0.47, 0.85, 1.22, 1.59, 1.975]
	_base = _xf(o)
	var c := Color.WHITE
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.026, H, D), Vector3(s * (W * 0.5 - 0.013), H * 0.5, 0), c)
	for y in levels:
		_bx(Vector3(W - 0.05, 0.025, D - 0.01), Vector3(0, y, -0.005), c)
	_bx(Vector3(W - 0.05, 0.08, 0.018), Vector3(0, 0.04, D * 0.5 - 0.03), c)
	_flush(CutsceneKit.tmat("wood_furniture.png", Color(0.52, 0.38, 0.27), 1.4, 0.65), true)

	_base = _xf(o)
	_bx(Vector3(W - 0.05, H - 0.02, 0.008), Vector3(0, H * 0.5, -D * 0.5 + 0.006), Color(0.17, 0.12, 0.09))
	var half := W * 0.5 - 0.03
	for i in range(levels.size() - 1):
		var floor_y: float = float(levels[i]) + 0.0125
		var gap: float = float(levels[i + 1]) - float(levels[i]) - 0.03
		match i:
			0:
				_books(-half, 0.06, floor_y, gap)
				_cardboard_box(Vector3(0.27, floor_y, 0.0))
			1:
				_books(-half, half, floor_y, gap)
			2:
				_book_stack(Vector3(-0.3, floor_y, 0.03))
				_books(-0.1, half, floor_y, gap)
			3:
				_books(-half, 0.12, floor_y, gap)
				_photo_frame(Vector3(0.32, floor_y, 0.03))
			4:
				_books(-0.22, half, floor_y, gap)
				_jar(Vector3(-0.36, floor_y, 0.02))
	_flush(_vmat(0.72))

	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, H, D)
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.position = o + Vector3(0, H * 0.5, 0)


func _books(x_from: float, x_to: float, y: float, gap: float) -> void:
	var front := 0.135
	var x := x_from
	while x < x_to - 0.03:
		var w := _rng.randf_range(0.02, 0.052)
		if x + w > x_to:
			break
		var h: float = minf(_rng.randf_range(0.2, 0.32), gap - 0.02)
		var d := _rng.randf_range(0.15, 0.22)
		var col: Color = BOOK_COLORS[_rng.randi_range(0, BOOK_COLORS.size() - 1)]
		col = col.lightened(_rng.randf_range(0.0, 0.12))
		var inset := _rng.randf_range(0.0, 0.03)
		var z := front - inset - d * 0.5
		var lean := 0.0
		if _rng.randf() < 0.05:
			lean = _rng.randf_range(4.0, 9.0)
		var cx := x + w * 0.5
		var cy := y + h * 0.5
		_bx(Vector3(w, h, d), Vector3(cx, cy, z), col, Vector3(0, 0, -lean))
		# Обрез страниц виден сверху
		_bx(Vector3(w * 0.8, 0.002, d * 0.96), Vector3(cx, y + h + 0.0005, z - 0.001), Color(0.78, 0.73, 0.62), Vector3(0, 0, -lean))
		if lean == 0.0:
			var spine_z := z + d * 0.5 + 0.0006
			var deco := _rng.randi_range(0, 2)
			var trim := col.lightened(0.5)
			if deco >= 1:
				_bx(Vector3(w * 0.98, 0.005, 0.001), Vector3(cx, y + h * 0.88, spine_z), trim)
				_bx(Vector3(w * 0.98, 0.005, 0.001), Vector3(cx, y + h * 0.12, spine_z), trim)
			if deco == 2:
				_bx(Vector3(w * 0.6, h * 0.34, 0.001), Vector3(cx, y + h * 0.6, spine_z), Color(0.72, 0.68, 0.56))
		x += w + 0.0015
		if _rng.randf() < 0.05:
			x += _rng.randf_range(0.015, 0.05)


func _book_stack(pos: Vector3) -> void:
	var y := pos.y
	for k in range(4):
		var col: Color = BOOK_COLORS[_rng.randi_range(0, BOOK_COLORS.size() - 1)]
		var t := _rng.randf_range(0.028, 0.045)
		_bx(Vector3(0.25 - float(k) * 0.015, t, 0.18), Vector3(pos.x, y + t * 0.5, pos.z), col, Vector3(0, _rng.randf_range(-5.0, 5.0), 0))
		y += t
	_bl(Vector3(0.03, 0.03, 0.03), Vector3(pos.x, y + 0.03, pos.z), Color(0.5, 0.5, 0.48))


func _cardboard_box(pos: Vector3) -> void:
	var c := Color(0.5, 0.38, 0.25)
	_bx(Vector3(0.3, 0.24, 0.24), Vector3(pos.x, pos.y + 0.12, pos.z), c, Vector3(0, 3, 0))
	_bx(Vector3(0.3, 0.002, 0.03), Vector3(pos.x, pos.y + 0.241, pos.z), Color(0.68, 0.62, 0.45), Vector3(0, 3, 0))


func _photo_frame(pos: Vector3) -> void:
	_bx(Vector3(0.17, 0.22, 0.014), Vector3(pos.x, pos.y + 0.11, pos.z), Color(0.1, 0.08, 0.07), Vector3(-9, 0, 0))
	_bx(Vector3(0.14, 0.19, 0.002), Vector3(pos.x, pos.y + 0.112, pos.z + 0.008), Color(0.72, 0.68, 0.58), Vector3(-9, 0, 0))
	_bx(Vector3(0.1, 0.1, 0.002), Vector3(pos.x, pos.y + 0.098, pos.z + 0.0095), Color(0.3, 0.38, 0.32), Vector3(-9, 0, 0))
	_bx(Vector3(0.1, 0.05, 0.002), Vector3(pos.x, pos.y + 0.17, pos.z + 0.0085), Color(0.5, 0.58, 0.66), Vector3(-9, 0, 0))


func _jar(pos: Vector3) -> void:
	_cy(0.05, 0.06, 0.15, pos + Vector3(0, 0.075, 0), Color(0.33, 0.42, 0.42))
	_cy(0.045, 0.05, 0.03, pos + Vector3(0, 0.165, 0), Color(0.16, 0.14, 0.13))


# ── Одежда: мятая ткань по настоящему силуэту вещи ──

func _build_clothes() -> void:
	var shirt := func(p: Vector2) -> bool:
		var ax := absf(p.x)
		var torso := ax < 0.2 and absf(p.y) < 0.32
		var sleeve := ax < 0.38 and p.y > -0.32 + (ax - 0.2) * 0.55 and p.y < -0.13 + (ax - 0.2) * 0.8
		return (torso or sleeve) and (p - Vector2(0, -0.37)).length() > 0.1
	var jeans := func(p: Vector2) -> bool:
		var ax := absf(p.x)
		if p.y < -0.12:
			return ax < 0.2 and p.y > -0.5
		var w := 0.19 - (p.y + 0.12) * 0.07
		return ax > 0.012 + (p.y + 0.12) * 0.05 and ax < w + (p.y + 0.12) * 0.05 and p.y < 0.54
	var hoodie := func(p: Vector2) -> bool:
		var ax := absf(p.x)
		var torso := ax < 0.27 and absf(p.y) < 0.34
		var sleeve := ax < 0.6 and p.y > -0.34 + (ax - 0.27) * 0.45 and p.y < -0.14 + (ax - 0.27) * 0.65
		return torso or sleeve or (p - Vector2(0, -0.44)).length() < 0.17
	var folded := func(p: Vector2) -> bool:
		return absf(p.x) < 0.17 and absf(p.y) < 0.15

	_base = Transform3D.IDENTITY
	_cloth(_xf(Vector3(1.12, FL, -3.07), Vector3(0, -18, 0)), shirt, Vector2(0.4, 0.34), 0.03, Color(0.66, 0.64, 0.58))
	_cloth(_xf(Vector3(-0.03, FL, -3.32), Vector3(0, 25, 0)), jeans, Vector2(0.22, 0.56), 0.032, Color(0.22, 0.3, 0.46))
	_cloth(_xf(Vector3(-1.62, FL + 0.5, -4.72), Vector3(0, 12, 0)), hoodie, Vector2(0.62, 0.62), 0.05, Color(0.36, 0.39, 0.33))
	_cloth(_xf(Vector3(-1.62, FL + 0.49, -3.3), Vector3(0, 80, 0)), folded, Vector2(0.18, 0.16), 0.055, Color(0.52, 0.2, 0.17), 0.016)

	# Носки
	for q in [[Vector3(0.61, FL, -5.1), 40.0], [Vector3(0.88, FL, -4.85), -30.0]]:
		_base = _xf(q[0], Vector3(0, q[1], 0))
		var sock := Color(0.72, 0.7, 0.64)
		_bl(Vector3(0.042, 0.016, 0.08), Vector3(0, 0.015, -0.03), sock)
		_bl(Vector3(0.04, 0.018, 0.055), Vector3(0.022, 0.015, 0.07), sock.darkened(0.08), Vector3(0, -32, 0))

	_flush(_vmat(0.92))
