extends "res://scripts/ApartmentKit.gd"

# Двор и улица у дома Итана (пролог, два-три дня после звонка). Пасмурно, мокро после дождя.
# Итан выходит из подъезда и идёт к своей машине; на каждом столбе объявления о пропаже Сэма.
# Механик здесь нет. Для thebekshdet: посадка в машину и реплики у объявлений ещё не сделаны;
# точки объявлений лежат в _posters, машина стоит в CAR_POS.

const YARD_END := 24.0        # конец двора, дальше тротуар
const CURB := 28.0            # бордюр северной стороны
const ROAD_Z := 32.5          # середина дороги
const SOUTH_WALK := 37.0
const LIMIT_X := 54.0         # дальше улицу перекрывают ограждения
const CAR_POS := Vector3(6.0, 0.0, 29.5)

const ASPHALT_SHADER := """
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
	vec2 p = w.xz;
	float grain = n(p * 34.0) * 0.5 + n(p * 90.0) * 0.5;
	grain = mix(0.5, grain, 1.0 - smoothstep(0.3, 1.0, fwidth(p.x) * 60.0));
	float wet = smoothstep(0.56, 0.68, n(p * 0.42) * 0.65 + n(p * 1.3) * 0.35);
	vec3 c = vec3(0.075, 0.075, 0.08) * (0.75 + 0.55 * grain);
	ALBEDO = c * mix(1.0, 0.55, wet);
	ROUGHNESS = mix(0.86, 0.42, wet);
	SPECULAR = 0.5;
}
"""

const PAVER_SHADER := """
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
	vec2 p = w.xz / 0.5;
	p.x += 0.5 * floor(p.y);
	vec2 id = floor(p);
	vec2 d = min(fract(p), 1.0 - fract(p)) * 0.5;
	float px = fwidth(w.x) + fwidth(w.z);
	float joint = smoothstep(0.003, 0.009 + px, min(d.x, d.y));
	joint = mix(joint, 0.9, smoothstep(0.02, 0.07, px));
	float wet = smoothstep(0.55, 0.7, n(w.xz * 0.5) * 0.65 + n(w.xz * 1.7) * 0.35);
	vec3 c = vec3(0.2, 0.195, 0.18) * (0.78 + 0.34 * h(id)) * (0.85 + 0.3 * mix(0.5, n(w.xz * 22.0), 1.0 - smoothstep(0.3, 1.0, px * 22.0)));
	ALBEDO = mix(vec3(0.035), c * mix(1.0, 0.6, wet), joint);
	ROUGHNESS = mix(0.95, mix(0.8, 0.46, wet), joint);
}
"""

const GRASS_SHADER := """
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
	vec2 p = w.xz;
	float blades = n(p * 80.0) * 0.55 + n(p * 210.0) * 0.45;
	blades = mix(0.5, blades, 1.0 - smoothstep(0.3, 1.0, fwidth(p.x) * 120.0));
	float patches = n(p * 0.8) * 0.6 + n(p * 3.1) * 0.4;
	vec3 grass = mix(vec3(0.05, 0.075, 0.025), vec3(0.11, 0.13, 0.04), blades);
	vec3 dirt = vec3(0.075, 0.055, 0.035) * (0.7 + 0.6 * blades);
	ALBEDO = mix(grass, dirt, smoothstep(0.58, 0.74, patches));
	ROUGHNESS = 0.96;
	SPECULAR = 0.15;
}
"""

# Панельный дом: швы плит, потёки, окна с рамами, тёмное стекло
const FACADE_SHADER := """
shader_type spatial;
varying vec3 w;
varying vec3 nm;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
uniform vec3 tone = vec3(0.3, 0.285, 0.25);
void vertex() { w = VERTEX; nm = NORMAL; }
void fragment() {
	float u = abs(nm.x) > 0.5 ? w.z : w.x;
	vec2 size = vec2(3.4, 3.0);
	vec2 cell = vec2(u, w.y) / size;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	vec2 e = min(f, 1.0 - f) * size;
	vec3 c = tone * (0.86 + 0.24 * h(id)) * (0.72 + 0.5 * n(vec2(u * 2.4, w.y * 0.22)));
	c *= mix(0.55, 1.0, smoothstep(0.012, 0.04, min(e.x, e.y)));
	if (w.y < 0.75) { c = vec3(0.09, 0.085, 0.08) * (0.8 + 0.4 * n(vec2(u, w.y) * 9.0)); }
	vec2 win = abs(f - vec2(0.5, 0.53)) * size;
	float inside = step(win.x, 0.74) * step(win.y, 0.8);
	float pane = step(win.x, 0.68) * step(win.y, 0.74);
	float bar = step(abs(f.x - 0.5) * size.x, 0.028);
	float rough = 0.92;
	if (w.y > 0.75 && inside > 0.5) {
		c = vec3(0.42, 0.41, 0.38);
		if (pane > 0.5 && bar < 0.5) {
			float r = h(id + 3.0);
			c = mix(vec3(0.05, 0.06, 0.075), vec3(0.2, 0.235, 0.28), smoothstep(-0.8, 0.8, win.y + r - 0.5));
			if (r > 0.9) { c = vec3(0.3, 0.215, 0.11) * (0.7 + 0.6 * smoothstep(-0.7, 0.7, win.y)); }
			else if (r > 0.6) { c *= mix(0.45, 1.0, step(abs(f.x - 0.3), 0.14)); }
			rough = 0.08;
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.5;
}
"""

const CLOUD_SHADER := """
shader_type spatial;
render_mode unshaded, cull_front, fog_disabled;
varying vec3 d;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { d = normalize(VERTEX); }
void fragment() {
	vec2 p = d.xz / (abs(d.y) + 0.22) * 2.2 + vec2(TIME * 0.008, 0.0);
	float c = n(p) * 0.5 + n(p * 2.2) * 0.3 + n(p * 5.1) * 0.2;
	vec3 sky = mix(vec3(0.2, 0.215, 0.24), vec3(0.42, 0.44, 0.47), smoothstep(0.32, 0.72, c));
	ALBEDO = mix(vec3(0.32, 0.335, 0.36), sky, smoothstep(0.0, 0.26, d.y));
}
"""

var _posters: Array = []
var _pole_tops: Array = []


func _ready() -> void:
	name = "CityStreetScene"
	_rng.seed = 4410
	_setup_weather()
	if GameManager and not GameManager.graphics_quality_changed.is_connected(_on_quality_changed):
		GameManager.graphics_quality_changed.connect(_on_quality_changed)
	_build_ground()
	_build_blocks()
	_build_entrance()
	_build_yard()
	_build_street_furniture()
	_build_district()
	_build_poles()
	_build_posters()
	_build_car()
	_face_street.call_deferred()


func _on_quality_changed(_q: String) -> void:
	_setup_weather.call_deferred()


# Итан только что вышел из подъезда и смотрит во двор
func _face_street() -> void:
	await get_tree().physics_frame
	_setup_weather()
	var player = GameManager.player_ref
	if is_instance_valid(player):
		player.rotation.y = PI


func _setup_weather() -> void:
	var main := get_parent()
	var sky := main.get_node_or_null("SkyElements")
	if sky:
		sky.visible = false
		sky.process_mode = Node.PROCESS_MODE_DISABLED
	var moon = main.get("moon_light")
	if moon:
		moon.visible = false
	# Красная лампа выхода из общей сцены оказалась бы посреди двора
	var exit_lamp := main.get_node_or_null("door_light")
	if exit_lamp:
		exit_lamp.visible = false
	var node = main.get("world_env_node")
	if node == null or node.environment == null:
		return
	var env: Environment = node.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.52, 0.55)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.76, 0.82)
	env.ambient_light_energy = 0.82
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.volumetric_fog_enabled = false
	# Отражения на мокрой плитке рисовали красные пятна от машины
	env.ssr_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.52, 0.54, 0.57)
	env.fog_light_energy = 1.0
	env.fog_density = 0.014
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.04
	if get_node_or_null("OvercastLight") == null:
		var sun := DirectionalLight3D.new()
		sun.name = "OvercastLight"
		sun.light_color = Color(0.82, 0.85, 0.9)
		sun.light_energy = 0.42
		sun.shadow_enabled = false
		add_child(sun)
		sun.rotation_degrees = Vector3(-62, 28, 0)
		var dome := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 170.0
		ball.height = 340.0
		ball.radial_segments = 24
		ball.rings = 12
		dome.mesh = ball
		dome.material_override = _shader(CLOUD_SHADER)
		dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dome)
		dome.position = Vector3(0, -12, 20)


func _plate(x0: float, x1: float, z0: float, z1: float, y: float = 0.0) -> void:
	_bx(Vector3(x1 - x0, 0.02, z1 - z0), Vector3((x0 + x1) * 0.5, y - 0.01, (z0 + z1) * 0.5), Color.WHITE)


# ── Земля: асфальт, плитка, газоны, дорога ──
func _build_ground() -> void:
	var far := 112.0
	_plate(-far, far, YARD_END, CURB, 0.05)
	_plate(-far, far, SOUTH_WALK, 40.0, 0.05)
	_plate(-34.0, 34.0, 0.0, 2.6, 0.03)
	_plate(-1.6, 1.6, 2.6, YARD_END, 0.03)
	_flush(_shader(PAVER_SHADER))

	_plate(14.0, 34.0, 2.6, YARD_END, 0.024)
	_flush(_shader(ASPHALT_SHADER))

	_plate(-34.0, -1.6, 2.6, YARD_END, 0.02)
	_plate(1.6, 14.0, 2.6, YARD_END, 0.02)
	_flush(_shader(GRASS_SHADER))

	var road := Node3D.new()
	add_child(road)
	road.position = Vector3(0, 0.02, ROAD_Z)
	road.rotation_degrees = Vector3(0, 90, 0)
	RoadKit.add_road(road, -112.0, 112.0, 0.0, 0.0, 12.0, 0.03, -0.012, false)

	# Бордюры и бортики вокруг газонов
	var stone := Color(0.5, 0.49, 0.46)
	for z in [CURB, SOUTH_WALK]:
		_bx(Vector3(far * 2.0, 0.14, 0.16), Vector3(0, 0.07, z), stone)
	for pair in [[-34.0, -1.6], [1.6, 14.0]]:
		var mid: float = (float(pair[0]) + float(pair[1])) * 0.5
		var w: float = float(pair[1]) - float(pair[0])
		_bx(Vector3(w, 0.1, 0.09), Vector3(mid, 0.05, 2.6), stone)
		_bx(Vector3(w, 0.1, 0.09), Vector3(mid, 0.05, YARD_END), stone)
	for x in [-1.6, 1.6, 14.0]:
		_bx(Vector3(0.09, 0.1, YARD_END - 2.6), Vector3(x, 0.05, (2.6 + YARD_END) * 0.5), stone)
	_flush(_vmat(0.9, 0.0, false, "concrete"))

	# Трава кустиками у дорожек
	var xforms: Array[Transform3D] = []
	for k in range(90):
		var x := _rng.randf_range(-33.5, 13.5)
		if absf(x) < 2.0:
			continue
		var scale_v := _rng.randf_range(0.3, 0.55)
		xforms.append(_xf(Vector3(x, 0.0, _rng.randf_range(3.0, 23.5)), Vector3(0, _rng.randf() * 360.0, 0), Vector3.ONE * scale_v))
	RoadKit.add_tufts(self, xforms, 30.0)


func _facade(tone: Color) -> ShaderMaterial:
	var m := _shader(FACADE_SHADER)
	m.set_shader_parameter("tone", Vector3(tone.r, tone.g, tone.b))
	return m


func _block(x0: float, x1: float, z0: float, z1: float, h: float) -> void:
	_bx(Vector3(x1 - x0, h, z1 - z0), Vector3((x0 + x1) * 0.5, h * 0.5, (z0 + z1) * 0.5), Color.WHITE)


# ── Дома ──
func _build_blocks() -> void:
	_block(-34.0, 40.0, -12.0, 0.0, 15.0)
	_block(-46.0, -34.0, -12.0, YARD_END, 15.0)
	_block(-112.0, -46.0, -12.0, 22.0, 15.0)
	_flush(_facade(Color(0.3, 0.285, 0.25)))
	_block(40.0, 112.0, -12.0, 22.0, 12.0)
	_block(-112.0, 112.0, 40.0, 52.0, 12.0)
	_flush(_facade(Color(0.25, 0.235, 0.22)))

	# Балконы: плита, ограждение, тёмная задняя часть
	var concrete := Color(0.46, 0.45, 0.42)
	var rail := Color(0.2, 0.22, 0.23)
	var bay := 3.4
	var x := -34.0 + bay * 2.5
	while x < 33.0:
		for floor_i in range(1, 5):
			var y := float(floor_i) * 3.0
			if int((x + 34.0) / bay) % 4 == 2 or absf(x) < 3.0:
				continue
			_bx(Vector3(2.5, 0.14, 1.0), Vector3(x, y + 0.02, 0.5), concrete)
			_bx(Vector3(2.5, 0.95, 0.05), Vector3(x, y + 0.56, 0.98), rail)
			for s in [-1.0, 1.0]:
				_bx(Vector3(0.05, 0.95, 1.0), Vector3(x + s * 1.22, y + 0.56, 0.5), rail)
		x += bay
	# Карнизы
	_bx(Vector3(74.4, 0.3, 12.4), Vector3(3.0, 15.15, -6.0), concrete.darkened(0.2))
	_bx(Vector3(12.4, 0.3, 36.4), Vector3(-40.0, 15.15, 6.0), concrete.darkened(0.2))
	_flush(_vmat(0.9, 0.0, false, "concrete"))

	# Гаражи с восточной стороны двора
	var metal := Color(0.24, 0.27, 0.27)
	for k in range(5):
		var z := 3.0 + float(k) * 4.2
		_bx(Vector3(6.0, 2.5, 3.9), Vector3(37.0, 1.25, z + 1.95), Color(0.36, 0.35, 0.32))
		_bx(Vector3(0.05, 2.1, 3.1), Vector3(33.98, 1.08, z + 1.95), metal.lightened(float(k % 3) * 0.05))
		_bx(Vector3(0.03, 2.0, 0.03), Vector3(33.95, 1.08, z + 1.95), metal.darkened(0.4))
		_bx(Vector3(6.3, 0.14, 4.0), Vector3(37.0, 2.57, z + 1.95), Color(0.14, 0.14, 0.15))
	# Трансформаторная будка закрывает проход между домом и гаражами
	var booth := Color(0.36, 0.35, 0.32)
	_bx(Vector3(6.0, 2.5, 3.2), Vector3(37.0, 1.25, 1.5), booth)
	_bx(Vector3(6.3, 0.14, 3.3), Vector3(37.0, 2.57, 1.5), Color(0.14, 0.14, 0.15))
	_bx(Vector3(0.05, 2.0, 1.1), Vector3(33.98, 1.05, 1.5), metal.darkened(0.15))
	_bx(Vector3(0.012, 0.3, 0.3), Vector3(33.95, 1.55, 1.5), Color(0.68, 0.56, 0.12), Vector3(45, 0, 0))
	_bx(Vector3(0.05, 0.08, 0.05), Vector3(33.94, 1.05, 1.96), Color(0.1, 0.1, 0.11))
	_flush(_vmat(0.65, 0.3))

	_solid(Vector3(3.0, 7.5, -6.0), Vector3(74.0, 15.0, 12.0))
	_solid(Vector3(-40.0, 7.5, 6.0), Vector3(12.0, 15.0, 36.0))
	_solid(Vector3(37.0, 1.5, 12.0), Vector3(6.0, 3.0, 24.4))
	_solid(Vector3(0, 7.5, 46.0), Vector3(224.0, 15.0, 12.0))
	# Улицу перекрыли ремонтом: дальше игрок не проходит
	for s in [-1.0, 1.0]:
		_solid(Vector3(s * LIMIT_X, 2.0, 32.0), Vector3(0.4, 4.0, 18.0))
	_solid(Vector3(44.0, 2.0, 16.0), Vector3(20.0, 4.0, 16.0))


# ── Подъезд: козырёк, металлическая дверь, домофон, фонарь ──
func _build_entrance() -> void:
	var concrete := Color(0.5, 0.49, 0.45)
	_bx(Vector3(3.4, 0.16, 2.0), Vector3(0, 2.86, 1.0), concrete)
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.16, 2.78, 0.16), Vector3(s * 1.55, 1.39, 1.85), concrete.darkened(0.1))
		_bx(Vector3(0.36, 2.2, 0.1), Vector3(s * 0.98, 1.1, 0.04), concrete.darkened(0.16))
	_bx(Vector3(2.32, 0.5, 0.1), Vector3(0, 2.42, 0.04), concrete.darkened(0.16))
	_bx(Vector3(3.4, 0.06, 2.0), Vector3(0, 0.03, 1.0), concrete.darkened(0.25))
	_flush(_vmat(0.9, 0.0, false, "concrete"))

	var door := Color(0.13, 0.21, 0.18)
	_bx(Vector3(1.56, 2.14, 0.06), Vector3(0, 1.08, 0.03), door.darkened(0.3))
	_bx(Vector3(1.42, 2.04, 0.05), Vector3(0, 1.05, 0.07), door)
	_bx(Vector3(0.06, 2.04, 0.012), Vector3(0, 1.05, 0.1), door.darkened(0.4))
	_bx(Vector3(0.42, 0.04, 0.012), Vector3(-0.37, 1.16, 0.1), door.lightened(0.1))
	_bx(Vector3(0.42, 0.04, 0.012), Vector3(0.37, 1.16, 0.1), door.lightened(0.1))
	_flush(_vmat(0.5, 0.45))

	var steel := Color(0.6, 0.61, 0.63)
	_pipe(Vector3(-0.14, 0.95, 0.15), Vector3(-0.14, 1.3, 0.15), 0.012, steel)
	_pipe(Vector3(-0.14, 1.28, 0.09), Vector3(-0.14, 1.28, 0.15), 0.009, steel)
	_pipe(Vector3(-0.14, 0.97, 0.09), Vector3(-0.14, 0.97, 0.15), 0.009, steel)
	_cy(0.04, 0.048, 0.01, Vector3(0, 2.76, 1.0), steel)
	_flush(_vmat(0.34, 0.6))

	_build_intercom(Vector3(1.0, 1.44, 0.09))
	_solid(Vector3(0, 1.1, 0.06), Vector3(2.4, 2.2, 0.12))
	_solid(Vector3(-1.55, 1.4, 1.85), Vector3(0.18, 2.8, 0.18))
	_solid(Vector3(1.55, 1.4, 1.85), Vector3(0.18, 2.8, 0.18))
	_posters.append([Vector3(0.37, 1.55, 0.102), 0.0, 3.0])


# Домофон: стальная панель на тёмной рамке, камера, решётка динамика, табло, кнопки с цифрами
func _build_intercom(at: Vector3) -> void:
	var steel := Color(0.5, 0.51, 0.53)
	var dark := Color(0.05, 0.05, 0.06)
	var key := Color(0.68, 0.69, 0.71)
	_base = _xf(at)
	_bx(Vector3(0.2, 0.4, 0.016), Vector3(0, 0, 0.008), dark)
	_bx(Vector3(0.176, 0.376, 0.012), Vector3(0, 0, 0.022), steel)
	for sx in [-0.076, 0.076]:
		for sy in [-0.176, 0.176]:
			_cy(0.005, 0.0055, 0.003, Vector3(sx, sy, 0.0295), steel.darkened(0.4), Vector3(90, 0, 0), 8)
	# Кольцо камеры и прорези динамика
	_cy(0.02, 0.022, 0.006, Vector3(0, 0.15, 0.031), Color(0.1, 0.1, 0.11), Vector3(90, 0, 0), 16)
	for k in range(5):
		_bx(Vector3(0.09 - absf(float(k) - 2.0) * 0.012, 0.0035, 0.002), Vector3(0, 0.116 - float(k) * 0.0085, 0.0285), dark)
	# Рамка табло
	_bx(Vector3(0.128, 0.042, 0.003), Vector3(0, 0.052, 0.029), dark)
	# Кнопки: тёмное углубление и выпуклая клавиша
	var labels := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
	var spots := []
	for row in range(4):
		for col in range(3):
			var pos := Vector2(-0.044 + float(col) * 0.044, 0.008 - float(row) * 0.04)
			_bx(Vector3(0.037, 0.033, 0.002), Vector3(pos.x, pos.y, 0.0285), dark)
			_bx(Vector3(0.031, 0.027, 0.006), Vector3(pos.x, pos.y, 0.031), key)
			spots.append(pos)
	# Кнопка вызова с красным ободком
	_torus(0.015, 0.02, Vector3(0, -0.158, 0.03), Color(0.5, 0.08, 0.06), Vector3(90, 0, 0), Vector3(1, 0.4, 1))
	_cy(0.0145, 0.0155, 0.007, Vector3(0, -0.158, 0.032), key, Vector3(90, 0, 0), 14)
	_flush(_vmat(0.42, 0.55))
	_base = _xf(at)
	_cy(0.011, 0.011, 0.002, Vector3(0, 0.15, 0.0345), Color(0.02, 0.025, 0.04), Vector3(90, 0, 0), 14)
	_flush(_vmat(0.06))
	var screen := StandardMaterial3D.new()
	screen.albedo_color = Color(0.015, 0.05, 0.05)
	screen.emission_enabled = true
	screen.emission = Color(0.05, 0.3, 0.27)
	screen.emission_energy_multiplier = 0.5
	CutsceneKit.box(self, Vector3(0.114, 0.03, 0.002), at + Vector3(0, 0.052, 0.0312), screen, Vector3.ZERO, false)
	var hint := CutsceneKit.text3d(self, "НАБЕРИТЕ КВ.", at + Vector3(0, 0.052, 0.0335), Vector3.ZERO, 0.0003, Color(0.5, 1.0, 0.9), 44)
	hint.shaded = false
	hint.visibility_range_end = 4.0
	for k in range(labels.size()):
		var l := CutsceneKit.text3d(self, labels[k], at + Vector3(spots[k].x, spots[k].y, 0.0345), Vector3.ZERO, 0.00042, Color(0.06, 0.06, 0.07), 44)
		l.visibility_range_end = 4.0


func _bench(pos: Vector3, yaw: float) -> void:
	_base = _xf(pos, Vector3(0, yaw, 0))
	var wood := Color(0.34, 0.24, 0.15)
	var iron := Color(0.1, 0.1, 0.11)
	for s in [-0.72, 0.72]:
		_bx(Vector3(0.06, 0.44, 0.46), Vector3(s, 0.22, 0.0), iron)
		_pipe(Vector3(s, 0.42, -0.16), Vector3(s, 0.86, -0.28), 0.022, iron)
	for k in range(4):
		_bx(Vector3(1.7, 0.03, 0.095), Vector3(0, 0.45, -0.17 + float(k) * 0.115), wood.darkened(float(k % 2) * 0.1))
	for k in range(3):
		_bx(Vector3(1.7, 0.095, 0.03), Vector3(0, 0.6 + float(k) * 0.12, -0.235 - float(k) * 0.027), wood.darkened(float(k % 2) * 0.1), Vector3(-14, 0, 0))
	_flush(_vmat(0.75, 0.0, false, "wood"))
	_solid(pos + Vector3(0, 0.4, 0), Vector3(1.7, 0.8, 0.5) if absf(sin(deg_to_rad(yaw))) < 0.5 else Vector3(0.5, 0.8, 1.7))


func _bin(pos: Vector3) -> void:
	_base = _xf(pos)
	var c := Color(0.2, 0.26, 0.24)
	_loft([_rg(0.2, 0.2, 0.2, 0.0), _rg(0.24, 0.24, 0.24, 0.72), _rg(0.25, 0.25, 0.25, 0.76), _rg(0.2, 0.2, 0.2, 0.77), _rg(0.18, 0.18, 0.18, 0.6), _rg(0.0, 0.0, 0.0, 0.6)],
		c, Transform3D.IDENTITY, 5, [c, c, c, c, Color(0.04, 0.04, 0.04), Color(0.04, 0.04, 0.04)])
	_flush(_vmat(0.6, 0.2))
	_solid(pos + Vector3(0, 0.38, 0), Vector3(0.48, 0.76, 0.48))


# Голое дерево: ствол и ветви, которые делятся и тоньшают к концам
func _tree(pos: Vector3) -> void:
	var tall := _rng.randf_range(2.6, 3.4)
	_base = _xf(pos, Vector3(0, _rng.randf() * 360.0, 0))
	_branch(Vector3.ZERO, Vector3(_rng.randf_range(-0.08, 0.08), 1.0, _rng.randf_range(-0.08, 0.08)).normalized(), tall, _rng.randf_range(0.17, 0.24), 4)
	_base = Transform3D.IDENTITY
	_solid(pos + Vector3(0, 1.0, 0), Vector3(0.45, 2.0, 0.45))


func _branch(from: Vector3, dir: Vector3, length: float, r: float, depth: int) -> void:
	var bend := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1.0, 1.0)) * length * 0.09
	var mid := from + dir * length * 0.5 + bend
	var tip := from + dir * length + bend * 1.6
	var col := Color(0.14, 0.115, 0.095).lightened(_rng.randf_range(0.0, 0.05))
	var path := _smooth([from, mid, tip], 2)
	var radius := func(k: float) -> float: return lerpf(r, r * 0.62, k)
	_tube(path, radius, col, 4 + mini(depth, 3), 1.0, Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.BACK)
	if depth == 0:
		return
	var kids := _rng.randi_range(2, 3)
	var out := (tip - mid).normalized()
	for k in range(kids):
		var a := _rng.randf() * TAU + float(k) * TAU / float(kids)
		var side := out.cross(Vector3(cos(a), 0.2, sin(a))).normalized()
		var next := (out + side * _rng.randf_range(0.45, 0.85) + Vector3.UP * 0.12).normalized()
		_branch(tip, next, length * _rng.randf_range(0.62, 0.78), r * 0.6, depth - 1)


# ── Двор: скамейки, урны, детская площадка, ограда ──
func _build_yard() -> void:
	for t in [[-29.0, 18.0], [-24.0, 20.5], [-11.0, 6.0], [-7.0, 19.0], [-13.0, 15.5], [5.5, 7.0], [9.5, 19.0], [11.5, 11.0], [-31.0, 6.0]]:
		_tree(Vector3(t[0], 0.0, t[1]))
	_flush(_vmat(0.96, 0.0, false, "soil"))
	_bench(Vector3(-3.2, 0.012, 1.0), 0.0)
	_bench(Vector3(3.2, 0.012, 1.0), 0.0)
	_bin(Vector3(-2.2, 0.012, 1.1))
	_bin(Vector3(2.3, 0.0, 22.7))

	# Качели
	var paint := Color(0.42, 0.14, 0.11)
	var at := Vector3(-18.0, 0.0, 12.0)
	_base = _xf(at)
	for s in [-1.4, 1.4]:
		_pipe(Vector3(s, 0, -0.9), Vector3(s, 2.5, 0), 0.04, paint)
		_pipe(Vector3(s, 0, 0.9), Vector3(s, 2.5, 0), 0.04, paint)
	_pipe(Vector3(-1.5, 2.5, 0), Vector3(1.5, 2.5, 0), 0.05, paint)
	_flush(_vmat(0.6, 0.3))
	_base = _xf(at)
	var chain := Color(0.3, 0.3, 0.32)
	for sx in [-0.7, 0.7]:
		var lean := -0.06 if sx < 0.0 else 0.13
		for side in [-0.2, 0.2]:
			_pipe(Vector3(sx + side, 2.5, 0), Vector3(sx + side, 0.48, lean), 0.006, chain)
		_bx(Vector3(0.48, 0.03, 0.18), Vector3(sx, 0.47, lean), Color(0.2, 0.15, 0.1))
	_flush(_vmat(0.5, 0.5))

	# Песочница с вытоптанным песком
	var board := Color(0.3, 0.22, 0.14)
	_base = _xf(Vector3(-25.0, 0.0, 8.0))
	for s in [-1.0, 1.0]:
		_bx(Vector3(3.1, 0.3, 0.1), Vector3(0, 0.15, s * 1.5), board)
		_bx(Vector3(0.1, 0.3, 3.1), Vector3(s * 1.5, 0.15, 0), board)
	_bx(Vector3(2.95, 0.1, 2.95), Vector3(0, 0.08, 0), Color(0.42, 0.36, 0.26))
	_flush(_vmat(0.95, 0.0, false, "concrete"))

	# Низкая ограда между двором и тротуаром, с проходом у дорожки
	var iron := Color(0.11, 0.13, 0.13)
	for span in [[-34.0, -1.7], [1.7, 14.0]]:
		var a: float = span[0]
		var b: float = span[1]
		var mid := (a + b) * 0.5
		_bx(Vector3(b - a, 0.04, 0.04), Vector3(mid, 0.9, YARD_END), iron)
		_bx(Vector3(b - a, 0.04, 0.04), Vector3(mid, 0.2, YARD_END), iron)
		var x := a
		while x <= b + 0.01:
			var post: float = 0.06 if int(round((x - a) / 0.2)) % 15 == 0 else 0.02
			_bx(Vector3(post, 1.05, post), Vector3(x, 0.525, YARD_END), iron)
			x += 0.2
		_solid(Vector3(mid, 0.6, YARD_END), Vector3(b - a, 1.2, 0.08))
	_flush(_vmat(0.55, 0.4))

	# Машины соседей на разметке парковки
	var row_z := 15.0
	var lot := [[0, Color(0.27, 0.32, 0.37), 180.0], [1, Color(0.44, 0.4, 0.3), 180.0], [3, Color(0.17, 0.2, 0.17), 180.0], [4, Color(0.56, 0.55, 0.52), 180.0], [5, Color(0.3, 0.13, 0.11), 180.0]]
	for q in lot:
		_parked_car(Vector3(17.4 + float(q[0]) * 2.8, 0.008, row_z + _rng.randf_range(-0.15, 0.15)), float(q[2]) + _rng.randf_range(-2.0, 2.0), q[1])


# Та же модель, что у Итана, в другом цвете. Перед машины смотрит вдоль -Z
func _parked_car(pos: Vector3, yaw: float, col: Color) -> void:
	var car := EthanCar.new()
	car._mats["paint"].albedo_color = col
	car._mats["paint2"].albedo_color = col.darkened(0.3)
	add_child(car)
	car.position = pos
	car.rotation_degrees = Vector3(0, yaw, 0)
	_lighten_car(car)
	var along_x := absf(sin(deg_to_rad(yaw))) > 0.7
	_solid(pos + Vector3(0, 0.65, 0), Vector3(3.75, 1.3, 1.66) if along_x else Vector3(1.66, 1.3, 3.75))


# Стоящим машинам не нужны лампочка приборов и тени, а салон и колёса вдали не видны
func _lighten_car(car: Node3D) -> void:
	for light in car.find_children("*", "Light3D", true, false):
		light.free()
	for mi: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var root: Node3D = mi
		while root.get_parent() != car:
			root = root.get_parent()
		if root.name == "Body" or root.name == "Hood":
			continue
		var is_wheel: bool = absf(root.position.x) > 0.5 and root.position.y < 0.6
		mi.visibility_range_end = 40.0 if is_wheel else 11.0


# ── На улице: остановка, урны, скамья, дорожные ограждения ──
func _build_street_furniture() -> void:
	# Автобусная остановка: стойки, крыша, стекло, скамья
	var at := Vector3(-20.0, 0.012, 26.0)
	var frame := Color(0.2, 0.22, 0.24)
	_base = _xf(at)
	for sx in [-2.0, 0.0, 2.0]:
		_bx(Vector3(0.08, 2.5, 0.08), Vector3(sx, 1.25, -1.2), frame)
	for sx in [-2.0, 2.0]:
		_bx(Vector3(0.08, 2.5, 0.08), Vector3(sx, 1.25, 0.4), frame)
	_bx(Vector3(4.5, 0.1, 2.2), Vector3(0, 2.55, -0.4), frame.darkened(0.2))
	_bx(Vector3(4.0, 0.06, 0.06), Vector3(0, 0.3, -1.2), frame)
	_flush(_vmat(0.5, 0.4))
	_base = _xf(at)
	_bx(Vector3(4.0, 2.05, 0.012), Vector3(0, 1.32, -1.2), Color(0.34, 0.4, 0.44))
	_flush(_vmat(0.06, 0.1))
	_bench(at + Vector3(0.0, 0.0, -0.75), 0.0)
	_solid(at + Vector3(0, 1.25, -1.2), Vector3(4.1, 2.5, 0.24))
	for sx in [-2.0, 2.0]:
		_solid(at + Vector3(sx, 1.25, 0.4), Vector3(0.16, 2.5, 0.16))
	_posters.append([at + Vector3(-1.0, 1.55, -1.19), 0.0, -2.0])
	_posters.append([at + Vector3(0.7, 1.5, -1.19), 0.0, 3.0])

	_bin(Vector3(-16.5, 0.012, 25.0))
	_bin(Vector3(21.0, 0.012, 25.0))

	# Красно-белые ограждения на концах улицы
	var red := Color(0.6, 0.14, 0.1)
	var white := Color(0.8, 0.78, 0.72)
	for s in [-1.0, 1.0]:
		var z := CURB - 3.4
		while z < 40.0:
			_base = _xf(Vector3(s * LIMIT_X, 0.0, z + 1.1))
			for sz in [-0.85, 0.85]:
				_bx(Vector3(0.08, 1.05, 0.08), Vector3(0, 0.52, sz), Color(0.2, 0.2, 0.22))
				_bx(Vector3(0.5, 0.06, 0.12), Vector3(0, 0.03, sz), Color(0.2, 0.2, 0.22))
			for k in range(6):
				_bx(Vector3(0.04, 0.22, 0.34), Vector3(0, 0.86, -0.85 + 0.17 + float(k) * 0.34 - 0.17), red if k % 2 == 0 else white)
			z += 2.4
	_flush(_vmat(0.6))


# ── Район: разметка, переход, знаки, тумба, контейнеры, кусты, листья, мелочи на домах ──
func _road_y(z: float) -> float:
	var k := (z - ROAD_Z) / 6.0
	return 0.02 + 0.03 * (1.0 - k * k)


func _build_district() -> void:
	# Разметка парковки и бетонные упоры
	var paint := Color(0.62, 0.6, 0.54)
	for k in range(7):
		_bx(Vector3(0.1, 0.006, 5.2), Vector3(16.0 + float(k) * 2.8, 0.027, 15.0), paint)
	# Пешеходный переход напротив дорожки во двор
	var z := CURB + 0.75
	while z < SOUTH_WALK - 0.4:
		_bx(Vector3(3.2, 0.03, 0.5), Vector3(0, _road_y(z), z), paint)
		z += 1.0
	_flush(_vmat(0.82, 0.0, false, "concrete"))
	_base = Transform3D.IDENTITY
	for k in range(6):
		_bx(Vector3(1.9, 0.12, 0.22), Vector3(17.4 + float(k) * 2.8, 0.08, 12.0), Color(0.42, 0.41, 0.38))
	_flush(_vmat(0.9, 0.0, false, "concrete"))

	# Машины вдоль бордюров
	_parked_car(Vector3(-11.5, 0.0, 29.5), 90.0, Color(0.33, 0.36, 0.33))
	_parked_car(Vector3(20.5, 0.0, 29.5), 90.0, Color(0.14, 0.19, 0.3))
	_parked_car(Vector3(13.0, 0.0, 35.5), -90.0, Color(0.5, 0.48, 0.42))
	_parked_car(Vector3(-27.0, 0.0, 35.5), -90.0, Color(0.34, 0.17, 0.1))

	# Люки на дороге и тротуаре
	for q in [[-8.0, 33.2], [15.0, 31.0], [28.0, 34.0]]:
		_cy(0.36, 0.36, 0.02, Vector3(q[0], _road_y(q[1]), q[1]), Color(0.05, 0.05, 0.055), Vector3.ZERO, 20)
		_cy(0.3, 0.3, 0.024, Vector3(q[0], _road_y(q[1]), q[1]), Color(0.11, 0.1, 0.1), Vector3.ZERO, 20)
	_cy(0.3, 0.3, 0.024, Vector3(-30.0, 0.05, 26.0), Color(0.12, 0.11, 0.1), Vector3.ZERO, 20)
	_flush(_vmat(0.55, 0.4))

	# Знаки: пешеходный переход и остановка
	_sign(Vector3(-2.3, 0.0, 27.5), Color(0.1, 0.24, 0.5), 90.0)
	_sign(Vector3(2.3, 0.0, 37.5), Color(0.1, 0.24, 0.5), -90.0)
	_sign(Vector3(-17.3, 0.0, 27.6), Color(0.62, 0.55, 0.14), 90.0)

	# Рекламная тумба с объявлениями о пропаже
	var at := Vector3(-10.0, 0.012, 25.5)
	var drum := Color(0.42, 0.4, 0.34)
	_base = _xf(at)
	_loft([
		_rg(0.6, 0.6, 0.6, 0.0), _rg(0.6, 0.6, 0.6, 0.22), _rg(0.54, 0.54, 0.54, 0.26), _rg(0.54, 0.54, 0.54, 2.45), _rg(0.66, 0.66, 0.66, 2.52),
		_rg(0.66, 0.66, 0.66, 2.62), _rg(0.42, 0.42, 0.42, 2.95), _rg(0.0, 0.0, 0.0, 3.08),
	], drum, Transform3D.IDENTITY, 6, [drum.darkened(0.3), drum.darkened(0.3), drum, drum, drum.darkened(0.25), drum.darkened(0.25), drum.darkened(0.45), drum.darkened(0.5)])
	# Рваные старые афиши
	var shreds := [Color(0.52, 0.2, 0.15), Color(0.2, 0.3, 0.42), Color(0.58, 0.52, 0.3), Color(0.32, 0.36, 0.3)]
	for k in range(9):
		var a := float(k) * TAU / 9.0 + 0.3
		var h := _rng.randf_range(0.5, 0.95)
		var y := _rng.randf_range(0.65, 1.85)
		_bx(Vector3(0.24, h, 0.012), Vector3(sin(a) * 0.54, y, cos(a) * 0.54), shreds[k % shreds.size()].darkened(_rng.randf_range(0.0, 0.3)), Vector3(0, rad_to_deg(a), 0))
	_flush(_vmat(0.85, 0.0, false, "concrete"))
	_solid(at + Vector3(0, 1.4, 0), Vector3(1.1, 2.8, 1.1))
	for yaw in [180.0, 90.0, -90.0, 0.0]:
		var a := deg_to_rad(yaw)
		_posters.append([at + Vector3(sin(a) * 0.565, 1.5 + _rng.randf_range(-0.1, 0.12), cos(a) * 0.565), yaw, _rng.randf_range(-4.0, 4.0)])

	# Контейнеры для мусора на площадке за парковкой
	var bin_at := Vector3(31.0, 0.008, 21.2)
	var wall := Color(0.44, 0.43, 0.4)
	_base = _xf(bin_at)
	_bx(Vector3(4.2, 1.5, 0.14), Vector3(0, 0.75, 1.2), wall)
	for s_x in [-2.1, 2.1]:
		_bx(Vector3(0.14, 1.5, 2.4), Vector3(s_x, 0.75, 0), wall)
	var metal := Color(0.16, 0.25, 0.2)
	for s_x in [-1.05, 1.05]:
		_bx(Vector3(1.55, 1.05, 1.1), Vector3(s_x, 0.62, 0.3), metal.darkened(_rng.randf_range(0.0, 0.25)), Vector3(0, _rng.randf_range(-4.0, 4.0), 0))
		_bx(Vector3(1.62, 0.07, 1.16), Vector3(s_x, 1.2, 0.3), Color(0.08, 0.1, 0.09), Vector3(_rng.randf_range(-7.0, 3.0), 0, 0))
		for side in [-0.55, 0.55]:
			_cy(0.08, 0.08, 0.05, Vector3(s_x + side, 0.08, -0.12), Color(0.04, 0.04, 0.04), Vector3(90, 0, 0), 10)
	_flush(_vmat(0.65, 0.2))
	_base = _xf(bin_at)
	for k in range(5):
		_softbox(Vector3(_rng.randf_range(0.42, 0.62), _rng.randf_range(0.32, 0.46), _rng.randf_range(0.42, 0.62)), _xf(Vector3(_rng.randf_range(-1.5, 1.5), 0.2, _rng.randf_range(-1.05, -0.5))), Color(0.05, 0.05, 0.055), 0.72, 0.1, 0.15, 8)
	_flush(_vmat(0.5))
	_solid(bin_at + Vector3(0, 0.75, 0.1), Vector3(4.3, 1.5, 2.3))

	_build_hedge()

	# Опавшие листья на газонах и у бордюров
	var leaf_cols := [Color(0.3, 0.17, 0.06), Color(0.4, 0.27, 0.08), Color(0.2, 0.11, 0.05)]
	for k in range(620):
		var lx := _rng.randf_range(-34.0, 34.0)
		var lz := _rng.randf_range(2.8, 27.8)
		if lx > 14.0 and lz < 24.0 and _rng.randf() < 0.75:
			continue
		var size := _rng.randf_range(0.04, 0.085)
		_bx(Vector3(size, 0.002, size * 0.7), Vector3(lx, 0.058 if lz > YARD_END else 0.034, lz), leaf_cols[k % 3].darkened(_rng.randf_range(0.0, 0.3)), Vector3(_rng.randf_range(-8.0, 8.0), _rng.randf() * 180.0, 0))
	_flush(_vmat(0.95, 0.0, false, "concrete"))

	_dress_facade()


# Кусты из листвы: сквозь них можно пройти, столкновений нет
func _build_hedge() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for span in [[-31.0, -10.0], [3.5, 12.5]]:
		var x: float = span[0]
		while x < float(span[1]):
			var w := _rng.randf_range(0.72, 1.1)
			var h := _rng.randf_range(0.66, 1.02)
			_leaf_ball(st, Vector3(x, h * 0.54, 23.15 + _rng.randf_range(-0.1, 0.1)), Vector3(w, h * 0.56, 0.62), int(78.0 * w))
			x += w * 1.3
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/nature/leaf_cluster.png")
	m.albedo_color = Color(2.6, 2.6, 2.3)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.95
	m.metallic_specular = 0.15
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _leaf_ball(st: SurfaceTool, c: Vector3, radii: Vector3, count: int) -> void:
	var green := Color(0.36, 0.42, 0.2)
	var dry := Color(0.46, 0.38, 0.16)
	for k in range(count):
		var dir := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.45, 1.0), _rng.randf_range(-1.0, 1.0)).normalized()
		var depth := pow(_rng.randf(), 0.42)
		var pos := c + Vector3(dir.x * radii.x, dir.y * radii.y, dir.z * radii.z) * depth
		pos.y = maxf(pos.y, 0.12)
		var size := _rng.randf_range(0.26, 0.46)
		var n := (dir + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.3, 0.6), _rng.randf_range(-0.6, 0.6))).normalized()
		var a := n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
		var b := n.cross(a)
		var spin := _rng.randf() * TAU
		var ax := a * cos(spin) + b * sin(spin)
		var ay := b * cos(spin) - a * sin(spin)
		var shade := lerpf(0.34, 1.0, depth) * lerpf(0.55, 1.06, clampf((pos.y - 0.1) / (radii.y * 1.7), 0.0, 1.0))
		var col := green.lerp(dry, pow(_rng.randf(), 3.0) * 0.8)
		col = Color(col.r * shade, col.g * shade, col.b * shade)
		var normal := (dir + Vector3.UP * 0.55).normalized()
		var corners := [pos - ax * size - ay * size, pos + ax * size - ay * size, pos + ax * size + ay * size, pos - ax * size + ay * size]
		var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_normal(normal)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])


func _sign(pos: Vector3, col: Color, yaw: float) -> void:
	_base = _xf(pos, Vector3(0, yaw, 0))
	var steel := Color(0.42, 0.43, 0.45)
	_cy(0.032, 0.036, 2.55, Vector3(0, 1.28, 0), steel, Vector3.ZERO, 8)
	_flush(_vmat(0.45, 0.5))
	_base = _xf(pos, Vector3(0, yaw, 0))
	_bx(Vector3(0.62, 0.62, 0.02), Vector3(0, 2.36, 0.04), Color(0.72, 0.72, 0.68))
	_bx(Vector3(0.55, 0.55, 0.004), Vector3(0, 2.36, 0.052), col)
	_bx(Vector3(0.3, 0.3, 0.004), Vector3(0, 2.34, 0.056), Color(0.76, 0.76, 0.72), Vector3(0, 0, 45))
	_bx(Vector3(0.05, 0.2, 0.004), Vector3(0, 2.35, 0.059), Color(0.05, 0.05, 0.06), Vector3(0, 0, 8))
	_bl(Vector3(0.036, 0.036, 0.003), Vector3(0.02, 2.47, 0.059), Color(0.05, 0.05, 0.06))
	_flush(_vmat(0.5))
	_base = Transform3D.IDENTITY
	_solid(pos + Vector3(0, 1.25, 0), Vector3(0.1, 2.5, 0.1))


# Жильцы: водосточные трубы, бельё на балконах, коробки, антенны, ворота гаражей
func _dress_facade() -> void:
	var pipe := Color(0.36, 0.36, 0.35)
	var px := -27.2
	while px < 28.0:
		if absf(px) > 4.0:
			_cy(0.05, 0.05, 15.0, Vector3(px, 7.5, 0.1), pipe, Vector3.ZERO, 8)
			for y in [1.5, 5.0, 8.0, 11.0, 14.0]:
				_bx(Vector3(0.14, 0.03, 0.12), Vector3(px, y, 0.06), pipe.darkened(0.25))
		px += 13.6
	_flush(_vmat(0.55, 0.3))

	var laundry := [Color(0.72, 0.7, 0.64), Color(0.42, 0.18, 0.15), Color(0.2, 0.27, 0.4), Color(0.56, 0.5, 0.26), Color(0.62, 0.62, 0.62)]
	for q in [[-22.1, 1], [-15.3, 3], [-8.5, 2], [5.1, 1], [11.9, 3], [18.7, 2], [25.5, 4]]:
		var x: float = q[0]
		var y := float(q[1]) * 3.0
		_bx(Vector3(2.3, 0.008, 0.008), Vector3(x, y + 2.05, 0.82), Color(0.5, 0.5, 0.5))
		var cx := x - 0.95
		while cx < x + 0.8:
			var w := _rng.randf_range(0.26, 0.5)
			var h := _rng.randf_range(0.42, 0.85)
			_bx(Vector3(w, h, 0.012), Vector3(cx + w * 0.5, y + 2.05 - h * 0.5, 0.82 + _rng.randf_range(-0.01, 0.01)), laundry[_rng.randi_range(0, laundry.size() - 1)], Vector3(0, _rng.randf_range(-6.0, 6.0), _rng.randf_range(-2.5, 2.5)))
			cx += w + _rng.randf_range(0.06, 0.22)
	for q in [[-18.7, 2], [-5.1, 4], [8.5, 2], [22.1, 1], [-22.1, 4]]:
		var y := float(q[1]) * 3.0
		_bx(Vector3(0.6, 0.45, 0.42), Vector3(float(q[0]) + _rng.randf_range(-0.6, 0.6), y + 0.32, 0.45), Color(0.4, 0.3, 0.2).darkened(_rng.randf_range(0.0, 0.3)), Vector3(0, _rng.randf_range(-15.0, 15.0), 0))
	# Ворота гаражей: засовы, петли, ржавые потёки
	var iron := Color(0.1, 0.1, 0.11)
	for k in range(5):
		var z := 3.0 + float(k) * 4.2 + 1.95
		_bx(Vector3(0.05, 0.06, 0.42), Vector3(33.94, 1.1, z), iron)
		_bx(Vector3(0.06, 0.13, 0.09), Vector3(33.91, 1.08, z + 0.1), Color(0.5, 0.42, 0.2))
		for side in [-1.0, 1.0]:
			for y in [0.45, 1.7]:
				_bx(Vector3(0.05, 0.1, 0.2), Vector3(33.95, y, z + side * 1.5), iron)
		for r in range(3):
			var w := _rng.randf_range(0.08, 0.26)
			var h := _rng.randf_range(0.4, 1.3)
			_bx(Vector3(0.008, h, w), Vector3(33.95, 2.1 - h * 0.5, z + _rng.randf_range(-1.3, 1.3)), Color(0.28, 0.16, 0.08))
	_flush(_vmat(0.72, 0.2))

	# Спутниковые тарелки на нескольких балконах
	var dish := Color(0.66, 0.66, 0.63)
	for q in [[-15.3, 2], [8.5, 3], [18.7, 1]]:
		var y := float(q[1]) * 3.0
		_base = _xf(Vector3(float(q[0]) + 0.95, y + 1.28, 1.05), Vector3(62, 0, 0))
		_loft([_rg(0.28, 0.28, 0.28, 0.1), _rg(0.18, 0.18, 0.18, 0.04), _rg(0.0, 0.0, 0.0, 0.0)], dish, Transform3D.IDENTITY, 7)
		_pipe(Vector3(0, 0.05, 0), Vector3(0, 0.32, -0.2), 0.008, Color(0.3, 0.3, 0.32))
	_flush(_vmat(0.45, 0.2, true))


# ── Столбы с проводами и фонарями ──
func _pole(pos: Vector3, tall: float, arm_dir: float) -> void:
	_base = _xf(pos)
	var c := Color(0.5, 0.49, 0.45)
	_cy(0.1, 0.15, tall, Vector3(0, tall * 0.5, 0), c, Vector3.ZERO, 10)
	_cy(0.18, 0.2, 0.4, Vector3(0, 0.2, 0), c.darkened(0.15), Vector3.ZERO, 10)
	_flush(_vmat(0.9, 0.0, false, "concrete"))
	if arm_dir == 0.0:
		_base = _xf(pos)
		_bl(Vector3.ONE * 0.2, Vector3(0, tall + 0.2, 0), Color(0.72, 0.72, 0.68))
		_cy(0.1, 0.12, 0.08, Vector3(0, tall + 0.02, 0), Color(0.2, 0.2, 0.22), Vector3.ZERO, 10)
		_flush(_vmat(0.3))
		_solid(pos + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))
		return
	_base = _xf(pos)
	var steel := Color(0.26, 0.27, 0.29)
	_tube(_smooth([Vector3(0, tall - 0.8, 0), Vector3(0, tall - 0.42, arm_dir * 0.5), Vector3(0, tall - 0.3, arm_dir * 1.3), Vector3(0, tall - 0.32, arm_dir * 1.8)], 5), 0.035, steel, 8)
	_softbox(Vector3(0.28, 0.1, 0.62), _xf(Vector3(0, tall - 0.37, arm_dir * 2.05)), steel, 0.4)
	_bx(Vector3(1.3, 0.08, 0.08), Vector3(0, tall - 0.08, 0), steel)
	for sx in [-0.55, 0.0, 0.55]:
		_cy(0.025, 0.04, 0.12, Vector3(sx, tall + 0.0, 0), Color(0.5, 0.56, 0.54), Vector3.ZERO, 8)
	_flush(_vmat(0.5, 0.4))
	_solid(pos + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))


func _build_poles() -> void:
	var tall := 8.0
	var row := []
	var x := -49.0
	while x <= 49.0:
		var p := Vector3(x, 0.012, 27.3)
		_pole(p, tall, 1.0)
		row.append(p)
		x += 14.0
	# Провода провисают между столбами
	var wire := Color(0.05, 0.05, 0.06)
	for i in range(row.size() - 1):
		for sx in [-0.55, 0.0, 0.55]:
			var a: Vector3 = row[i] + Vector3(0, tall + 0.06, sx * 0.25)
			var b: Vector3 = row[i + 1] + Vector3(0, tall + 0.06, sx * 0.25)
			var pts := []
			for k in range(13):
				var t := float(k) / 12.0
				pts.append(a.lerp(b, t) + Vector3(0, -0.55 * 4.0 * t * (1.0 - t), 0))
			_tube(pts, 0.009, wire, 4)
	_flush(_vmat(0.8))

	# Столбы во дворе, вдоль дорожки
	for z in [8.5, 17.5]:
		_pole(Vector3(2.15, 0.012, z), 4.6, 0.0)

	# Объявления на всех столбах: со стороны двора и местами со стороны дороги
	for k in range(row.size()):
		var p: Vector3 = row[k]
		_posters.append([p + Vector3(0, 1.55, -0.16), 180.0, _rng.randf_range(-4.0, 4.0)])
		if k % 2 == 0:
			_posters.append([p + Vector3(0, 1.6, 0.16), 0.0, _rng.randf_range(-4.0, 4.0)])
	_posters.append([Vector3(2.15, 1.55, 8.34), 180.0, -3.0])
	_posters.append([Vector3(2.15, 1.5, 17.34), 180.0, 4.0])
	_posters.append([Vector3(-6.0, 0.62, YARD_END - 0.03), 180.0, 2.0])


# Все объявления — один MultiMesh и один вызов отрисовки
func _build_posters() -> void:
	var sheet := QuadMesh.new()
	sheet.size = Vector2(0.3, 0.424)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sheet
	mm.instance_count = _posters.size()
	var tape := Color(0.78, 0.74, 0.6)
	for i in range(_posters.size()):
		var p: Array = _posters[i]
		var xf := _xf(p[0], Vector3(0, p[1], p[2]))
		mm.set_instance_transform(i, xf)
		_base = xf
		for sy in [-1.0, 1.0]:
			_bx(Vector3(0.09, 0.03, 0.0015), Vector3(-0.1, sy * 0.205, 0.002), tape, Vector3(0, 0, 30.0 * sy))
			_bx(Vector3(0.09, 0.03, 0.0015), Vector3(0.1, sy * 0.205, 0.002), tape, Vector3(0, 0, -30.0 * sy))
	_flush(_vmat(0.4))
	var set_mi := MultiMeshInstance3D.new()
	set_mi.multimesh = mm
	var paper := StandardMaterial3D.new()
	paper.albedo_texture = load("res://assets/textures/street/poster_missing.png")
	paper.albedo_color = Color(0.92, 0.9, 0.86)
	paper.roughness = 0.82
	paper.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	set_mi.material_override = paper
	set_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(set_mi)


func _build_car() -> void:
	var car := EthanCar.new()
	add_child(car)
	car.position = CAR_POS
	# Перед машины смотрит вдоль -Z модели; здесь он повёрнут вдоль улицы
	car.rotation_degrees = Vector3(0, 90, 0)
	_solid(CAR_POS + Vector3(0, 0.65, 0), Vector3(3.75, 1.3, 1.66))
