extends Node3D

# Квартира Итана (пролог). Стены и мебель лежат в карте «Квартира.json».
# Здесь то, чего нет в карте: ночной свет, окна с дождём и темнотой за ними,
# и телевизор; вещи по комнатам собирают ApartmentProps, Kitchen, Bathroom и Hall. Комната повторяет кат-сцену звонка Jan-ky
# (PoliceCall.gd) по координатам и мебели, но там за окном день, здесь ночь.
# Механик здесь нет: пиццу, кофе, стирку и телефон делает thebekshdet.

const FL := 0.01
const WOOD_FLOORS := ["wall_5000", "wall_5001", "wall_5002"]
const TV_POS := Vector3(0.2, 0.95 + FL, -2.05)

var _window_light: OmniLight3D

const RAIN_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float a = 0.0;
	for (int k = 0; k < 3; k++) {
		vec2 g = UV * vec2(14.0 + float(k) * 7.0, 9.0 + float(k) * 5.0);
		vec2 id = floor(g);
		float rnd = h(id + float(k) * 3.1);
		float speed = 0.15 + rnd * 0.25;
		vec2 f = fract(g + vec2(0.0, TIME * speed * (rnd > 0.75 ? 1.0 : 0.05)));
		float d = length((f - vec2(0.5, 0.5)) * vec2(1.0, 0.7));
		a += smoothstep(0.18, 0.08, d) * step(0.45, rnd);
		a += smoothstep(0.03, 0.0, abs(f.x - 0.5)) * step(0.88, rnd) * 0.4;
	}
	ALBEDO = vec3(0.14, 0.16, 0.22);
	ALPHA = clamp(0.02 + a * 0.22, 0.0, 0.4);
}
"""

# Струи дождя за стеклом: падают сверху вниз, чтобы дождь было видно издалека
const RAIN_FALL_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	float a = 0.0;
	for (int k = 0; k < 4; k++) {
		float fk = float(k);
		vec2 g = vec2(UV.x + UV.y * 0.06, UV.y) * vec2(115.0 + fk * 63.0, 4.4 + fk * 2.1);
		float col = floor(g.x);
		float r = h(vec2(col, fk + 1.0));
		float y = fract(g.y - TIME * (3.0 + r * 2.3) + r * 10.0);
		float line = smoothstep(0.3, 0.05, abs(fract(g.x) - 0.5));
		a += line * smoothstep(0.62, 1.0, y) * step(0.3, r);
	}
	ALBEDO = vec3(0.2, 0.23, 0.3);
	ALPHA = clamp(a * 0.3, 0.0, 0.4);
}
"""

const TV_SHADER := """
shader_type spatial;
render_mode unshaded;
float h(float n) { return fract(sin(n) * 43758.5453); }
float box(vec2 p, vec2 c, vec2 s) { vec2 d = abs(p - c) - s; return 1.0 - smoothstep(0.0, 0.012, max(d.x, d.y)); }
float circ(vec2 p, vec2 c, float r) { return 1.0 - smoothstep(r - 0.012, r + 0.012, length((p - c) * vec2(1.6, 1.0))); }
void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float sc = floor(TIME / 3.7);
	vec3 wall = mix(vec3(0.75, 0.55, 0.38), vec3(0.42, 0.55, 0.68), h(sc * 1.7 + 0.3));
	vec3 c = wall * (0.55 + 0.45 * uv.y);
	c = mix(c, wall * 0.5, box(uv, vec2(0.15 + 0.7 * h(sc + 0.7), 0.56), vec2(0.08, 0.3)));
	c = mix(c, mix(vec3(0.5, 0.2, 0.18), vec3(0.25, 0.32, 0.22), h(sc + 2.0)), box(uv, vec2(0.5, 0.17), vec2(0.4, 0.1)));
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float x = 0.3 + 0.4 * fi + 0.05 * sin(TIME * (0.8 + fi) + sc);
		vec3 shirt = mix(vec3(0.7, 0.25, 0.2), vec3(0.2, 0.35, 0.6), h(sc * 3.0 + fi));
		c = mix(c, shirt, box(uv, vec2(x, 0.38), vec2(0.07, 0.17)));
		c = mix(c, vec3(0.85, 0.65, 0.5), circ(uv, vec2(x, 0.62 + 0.01 * sin(TIME * 3.0 + fi)), 0.06));
	}
	c *= 0.82 + 0.18 * sin(UV.y * 600.0);
	c *= 0.92 + 0.08 * h(floor(TIME * 24.0));
	float vig = smoothstep(0.9, 0.3, length(UV - 0.5));
	ALBEDO = c * vig * 1.2;
}
"""


func _ready() -> void:
	name = "ApartmentScene"
	_setup_night()
	if GameManager and not GameManager.graphics_quality_changed.is_connected(_on_quality_changed):
		GameManager.graphics_quality_changed.connect(_on_quality_changed)
	call_deferred("_lay_wood_floors")
	# Окна: центр проёма и направление наружу
	_window(Vector3(0.3, 1.675 + FL, 2.4), 1.6, Vector3(0, 0, 1))
	_window(Vector3(0.0, 1.675 + FL, -6.4), 1.6, Vector3(0, 0, -1))
	_window(Vector3(8.2, 1.675 + FL, -3.7), 1.4, Vector3(1, 0, 0))
	_build_darkness()
	_build_tv()
	for part in ["ApartmentProps", "ApartmentKitchen", "ApartmentBathroom", "ApartmentHall", "ApartmentLights", "ApartmentBlinds", "ApartmentCurtains"]:
		add_child(load("res://scripts/%s.gd" % part).new())
	_build_lights()


# Тень от окна нужна только в самой комнате: в остальных она лишь тратила бы FPS
func _process(_delta: float) -> void:
	var pl = GameManager.player_ref
	if is_instance_valid(_window_light) and is_instance_valid(pl):
		var p: Vector3 = pl.global_position
		_window_light.shadow_enabled = p.x < 3.2 and p.z > -2.6


func _on_quality_changed(_q: String) -> void:
	call_deferred("_setup_night")


# За окнами только темнота и дождь: луна и небо общей сцены здесь не нужны
func _setup_night() -> void:
	var main := get_parent()
	var sky := main.get_node_or_null("SkyElements")
	if sky:
		sky.visible = false
		sky.process_mode = Node.PROCESS_MODE_DISABLED
	var moon = main.get("moon_light")
	if moon:
		moon.visible = false
	var node = main.get("world_env_node")
	if node == null or node.environment == null:
		return
	var env: Environment = node.environment
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.016, 0.035)   # ночь, если смотреть в окно сбоку
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.33, 0.42)
	env.ambient_light_energy = 0.28
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.06


func _lay_wood_floors() -> void:
	var region = get_parent().get("nav_region")
	if region == null:
		return
	var wood := CutsceneKit.tmat("wood_furniture.png", Color(0.62, 0.5, 0.4), 0.9, 0.7)
	for n in WOOD_FLOORS:
		var body = region.get_node_or_null(n)
		if body:
			for m in body.find_children("*", "MeshInstance3D", true, false):
				m.material_override = wood


func _window(c: Vector3, w: float, out: Vector3) -> void:
	var along := Vector3(0, 1, 0).cross(out).normalized()
	var yaw := rad_to_deg(atan2(out.x, out.z))
	var inward := -out
	var frame := CutsceneKit.mat(Color(0.85, 0.85, 0.83), 0.5)
	var sz_along := func(a: float, h: float, d: float) -> Vector3:
		return Vector3(a * absf(along.x) + d * absf(out.x), h, a * absf(along.z) + d * absf(out.z))
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, sz_along.call(0.06, 1.45, 0.14), c + along * (w * 0.5) * s, frame)
		CutsceneKit.box(self, sz_along.call(w + 0.06, 0.06, 0.14), c + Vector3.UP * 0.725 * s, frame)
	CutsceneKit.box(self, sz_along.call(0.05, 1.45, 0.14), c, frame)
	CutsceneKit.box(self, sz_along.call(w + 0.2, 0.05, 0.3), c + Vector3.UP * -0.75 + inward * 0.1, frame)
	# Стекло с дождём и струи за ним
	var rain := ShaderMaterial.new()
	rain.shader = Shader.new()
	rain.shader.code = RAIN_SHADER
	CutsceneKit.quad(self, Vector2(w, 1.45), c + inward * 0.01, rain, Vector3(0, yaw + 180.0, 0))
	var fall := ShaderMaterial.new()
	fall.shader = Shader.new()
	fall.shader.code = RAIN_FALL_SHADER
	CutsceneKit.quad(self, Vector2(w + 6.0, 6.0), c + out * 0.7, fall, Vector3(0, yaw + 180.0, 0))
	# Невидимая преграда, чтобы нельзя было вылезти в окно
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = sz_along.call(w, 1.5, 0.12)
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.global_position = c


# Чёрная коробка вокруг квартиры: за окнами только темнота, и через них
# не видно остальных объектов общей сцены.
func _build_darkness() -> void:
	var west := -5.7
	var east := 11.2
	var north := -9.4
	var south := 5.4
	var cx := (west + east) * 0.5
	var cz := (north + south) * 0.5
	var w := east - west
	var d := south - north
	var y := 3.7
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color.BLACK
	CutsceneKit.quad(self, Vector2(w, 14), Vector3(cx, y, north), black, Vector3.ZERO)
	CutsceneKit.quad(self, Vector2(w, 14), Vector3(cx, y, south), black, Vector3(0, 180, 0))
	CutsceneKit.quad(self, Vector2(d, 14), Vector3(east, y, cz), black, Vector3(0, -90, 0))
	CutsceneKit.quad(self, Vector2(d, 14), Vector3(west, y, cz), black, Vector3(0, 90, 0))
	CutsceneKit.box(self, Vector3(w, 0.01, d), Vector3(cx, 0.003, cz), black, Vector3.ZERO, false)


func _build_tv() -> void:
	var body := CutsceneKit.mat(Color(0.03, 0.03, 0.035), 0.3, 0.2)
	CutsceneKit.box(self, Vector3(1.25, 0.74, 0.06), TV_POS, body)
	CutsceneKit.box(self, Vector3(0.3, 0.04, 0.2), TV_POS + Vector3(0, -0.4, 0.02), body)
	var screen := ShaderMaterial.new()
	screen.shader = Shader.new()
	screen.shader.code = TV_SHADER
	CutsceneKit.quad(self, Vector2(1.17, 0.66), TV_POS + Vector3(0, 0, 0.032), screen)
	var light := OmniLight3D.new()
	light.light_color = Color(0.75, 0.72, 0.85)
	light.light_energy = 0.9
	light.omni_range = 4.5
	add_child(light)
	light.position = TV_POS + Vector3(0, 0, 0.6)


func _omni(pos: Vector3, col: Color, energy: float, rng: float, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadow
	add_child(l)
	l.position = pos
	return l


# Здесь только ночной свет из окон; люстры и лампы в ApartmentLights.gd
func _build_lights() -> void:
	var night := Color(0.42, 0.5, 0.72)
	_window_light = _omni(Vector3(0.3, 1.9, 2.05), night, 0.55, 5.5, true)
	_omni(Vector3(0.0, 1.9, -6.0), night, 0.5, 5.0)
