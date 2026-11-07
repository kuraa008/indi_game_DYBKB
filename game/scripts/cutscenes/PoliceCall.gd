extends Cutscene

# ПРОЛОГ · «Звонок». Суббота, квартира Итана, дождь, по телевизору сериал.
# Игрок сам нажал «Ответить» → полиция: отец найден мёртвым, Сэм пропал.
# Итан застывает; секунд через десять — «Как…». По телевизору кто-то смеётся.
#
# args.from_gameplay = true — начать сразу с ответа на звонок (без вступления
# с вибрирующим телефоном, его играет геймплей thebekshdet).

const SOFA_EYE := Vector3(0.25, 1.12, 1.45)
const TV_POS := Vector3(0.2, 0.95, -2.05)
const WIDE_CAM := Vector3(1.75, 1.7, -1.5)

var tv_light: OmniLight3D
var tv_mat: ShaderMaterial
var phone: Dictionary
var hand: CutsceneCast.Hand
var phone_rig: Node3D
var ethan: PlayerModel
var window_light: OmniLight3D
var _tv_amb: Node
var _rain: Node
var _room: Node


func build() -> void:
	set_env(Color(0.05, 0.055, 0.06), Color(0.42, 0.45, 0.5), 0.55, 0.0, Color.BLACK, 1.05)
	env.adjustment_saturation = 0.78
	var paint := CutsceneKit.mat(Color(0.56, 0.55, 0.5), 0.92)
	var floor_m := CutsceneKit.tmat("wood_furniture.png", Color(0.62, 0.5, 0.4), 0.9, 0.7)
	var ceil_m := CutsceneKit.mat(Color(0.8, 0.8, 0.78), 0.95)
	# Комната 5.4 × 2.7 × 4.8; окно за диваном, дверь в коридор справа
	CutsceneKit.box(self, Vector3(5.6, 0.1, 5.0), Vector3(0, -0.05, 0), floor_m)
	CutsceneKit.box(self, Vector3(5.6, 0.1, 5.0), Vector3(0, 2.75, 0), ceil_m)
	CutsceneKit.wall(self, Vector3(-2.7, 0, 2.4), Vector3(-2.7, 0, -2.4), 2.7, 0.12, paint)
	CutsceneKit.wall(self, Vector3(2.7, 0, -2.4), Vector3(2.7, 0, 2.4), 2.7, 0.12, paint, Rect2(2.9, 0.0, 0.95, 2.1))
	CutsceneKit.wall(self, Vector3(-2.7, 0, -2.4), Vector3(2.7, 0, -2.4), 2.7, 0.12, paint)
	CutsceneKit.wall(self, Vector3(2.7, 0, 2.4), Vector3(-2.7, 0, 2.4), 2.7, 0.12, paint, Rect2(1.6, 0.95, 1.6, 1.45))
	var trim := CutsceneKit.mat(Color(0.86, 0.85, 0.82), 0.6)
	for z in [-2.33, 2.33]:
		CutsceneKit.box(self, Vector3(5.4, 0.08, 0.02), Vector3(0, 0.04, z), trim)
	# Коридор за открытой дверью: тусклый свет
	var hall := CutsceneKit.door(self, Vector3(2.7, 0, 0.5), Vector3(0, -90, 0), 0.92, 2.08)
	(hall.leaf as Node3D).rotation_degrees = Vector3(0, -105, 0)
	CutsceneKit.box(self, Vector3(1.6, 2.7, 2.6), Vector3(3.6, 1.35, 1.0), CutsceneKit.mat(Color(0.32, 0.3, 0.27), 0.95))
	var hall_light := OmniLight3D.new()
	hall_light.light_color = Color(1.0, 0.82, 0.6)
	hall_light.light_energy = 0.5
	hall_light.omni_range = 2.4
	hall_light.position = Vector3(3.3, 2.2, 1.0)
	add_child(hall_light)
	_build_window()
	# Мебель
	CutsceneKit.prefab(self, "prop_sofa", Vector3(2.3, 0.95, 1.0), Vector3(0.25, 0, 1.75), Vector3(0, 180, 0), Color(0.3, 0.33, 0.38))
	CutsceneKit.prefab(self, "prop_table", Vector3(1.2, 0.45, 0.65), Vector3(0.25, 0, 0.25), Vector3.ZERO, Color(0.45, 0.33, 0.24))
	CutsceneKit.prefab(self, "prop_dresser", Vector3(1.6, 0.55, 0.45), Vector3(0.2, 0, -2.1), Vector3.ZERO, Color(0.25, 0.22, 0.2))
	CutsceneKit.prefab(self, "prop_bookshelf", Vector3(1.0, 2.0, 0.35), Vector3(1.9, 0, -2.15), Vector3.ZERO, Color(0.4, 0.3, 0.22))
	CutsceneKit.prefab(self, "prop_lamp_floor", Vector3(0.4, 1.6, 0.4), Vector3(-1.4, 0, 1.9))
	CutsceneKit.prefab(self, "prop_carpet", Vector3(2.6, 0.02, 1.8), Vector3(0.25, 0.005, 0.4), Vector3.ZERO, Color(0.36, 0.3, 0.32))
	CutsceneKit.prefab(self, "prop_plant_pot", Vector3(0.4, 0.8, 0.4), Vector3(-2.3, 0, -0.1))
	_build_tv()
	_build_table_props()
	# Свет: серый день из окна, телевизор, лёгкая подсветка комнаты
	window_light = OmniLight3D.new()
	window_light.light_color = Color(0.68, 0.76, 0.9)
	window_light.light_energy = 1.6
	window_light.omni_range = 7.0
	window_light.shadow_enabled = true
	window_light.position = Vector3(0.3, 1.9, 2.05)
	add_child(window_light)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.9, 0.85, 0.78)
	fill.light_energy = 0.25
	fill.omni_range = 6.0
	fill.position = Vector3(1.5, 2.3, 1.2)
	add_child(fill)
	# Итан на диване — виден только в общем плане
	ethan = CutsceneCast.ethan()
	add_child(ethan)
	ethan.position = Vector3(0.25, 0, 1.62)
	ethan.rotation_degrees = Vector3(0, 180, 0)
	CutsceneCast.pose(ethan, _phone_pose())
	var held := BoneAttachment3D.new()
	held.bone_name = "handR"
	ethan.skeleton.add_child(held)
	var ph2 := CutsceneKit.phone(held)
	ph2.root.position = Vector3(0.0, 0.04, 0.02)
	ph2.root.rotation_degrees = Vector3(0, 90, 90)
	ph2.light.visible = false
	ethan.visible = false
	# Телефон в руке от первого лица
	phone_rig = Node3D.new()
	cam.add_child(phone_rig)
	hand = CutsceneCast.hand(false)
	phone_rig.add_child(hand)
	hand.position = Vector3(0.01, -0.075, 0.03)
	hand.rotation_degrees = Vector3(72, 0, 0)
	hand.curl = 0.75
	phone = CutsceneKit.phone(phone_rig)
	phone.root.position = Vector3(0.0, 0.035, -0.06)
	phone.root.rotation_degrees = Vector3(-20, 0, 0)
	phone_rig.position = Vector3(0.12, -0.2, -0.36)
	phone_rig.rotation_degrees = Vector3(28, -8, 0)
	_set_phone("Новости", "…снова жалуются на крупного\nчёрного оленя у дороги")
	(phone.ok as Node3D).visible = false
	(phone.no as Node3D).visible = false


func _phone_pose() -> Dictionary:
	return CutsceneCast.with(CutsceneCast.sit_table(), {
		"hips_pos": Vector3(0, -0.52, 0.02),
		"spineA": Vector3(-0.12, 0, 0), "chest": Vector3(-0.04, 0, 0), "neck": Vector3(0.12, 0, 0), "head": Vector3(0.18, 0.12, 0),
		"shL": Vector3(-0.35, 0, -0.1), "elL": Vector3(-0.9, 0, 0),
		"shR": Vector3(-0.55, -0.2, 0.55), "elR": Vector3(-2.35, 0, 0), "wrR": Vector3(0.2, 0, 0),
	})


func _build_window() -> void:
	var frame := CutsceneKit.mat(Color(0.85, 0.85, 0.83), 0.5)
	var c := Vector3(0.3, 1.675, 2.4)
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, Vector3(0.06, 1.45, 0.14), c + Vector3(0.8 * s, 0, 0), frame)
		CutsceneKit.box(self, Vector3(1.66, 0.06, 0.14), c + Vector3(0, 0.725 * s, 0), frame)
	CutsceneKit.box(self, Vector3(0.05, 1.45, 0.14), c, frame)
	CutsceneKit.box(self, Vector3(1.8, 0.05, 0.3), c + Vector3(0, -0.75, -0.1), frame)
	var curtain := CutsceneKit.mat(Color(0.42, 0.4, 0.44), 0.95)
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, Vector3(0.45, 2.2, 0.04), c + Vector3(1.05 * s, -0.25, -0.12), curtain)
	# Улица: серое небо и силуэты домов
	var sky := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
void fragment() {
	vec2 uv = UV;
	vec3 top = vec3(0.62, 0.66, 0.72);
	vec3 low = vec3(0.4, 0.43, 0.48);
	vec3 c = mix(top, low, smoothstep(0.1, 0.9, uv.y));
	float b = step(0.55 + 0.12 * step(0.5, fract(uv.x * 3.1)) - 0.08 * step(0.7, fract(uv.x * 5.3 + 0.2)), uv.y);
	c = mix(c, vec3(0.2, 0.22, 0.25), b * 0.85);
	float win = b * step(0.6, fract(uv.x * 40.0)) * step(0.55, fract(uv.y * 26.0)) * step(0.62, fract(sin(floor(uv.x * 40.0) * 12.9 + floor(uv.y * 26.0) * 7.1) * 43758.5));
	c += vec3(0.25, 0.22, 0.15) * win;
	ALBEDO = c * 1.25;
}
"""
	sky.shader = sh
	CutsceneKit.quad(self, Vector2(9, 5), Vector3(0.3, 1.8, 6.5), sky, Vector3(0, 180, 0))
	# Стекло с дождём
	var rain := ShaderMaterial.new()
	var rs := Shader.new()
	rs.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 uv = UV * vec2(1.0, 1.0);
	float a = 0.0;
	for (int k = 0; k < 3; k++) {
		vec2 g = uv * vec2(14.0 + float(k) * 7.0, 9.0 + float(k) * 5.0);
		vec2 id = floor(g);
		float rnd = h(id + float(k) * 3.1);
		float speed = 0.15 + rnd * 0.25;
		vec2 f = fract(g + vec2(0.0, TIME * speed * (rnd > 0.75 ? 1.0 : 0.05)));
		float d = length((f - vec2(0.5, 0.5)) * vec2(1.0, 0.7));
		a += smoothstep(0.18, 0.08, d) * step(0.45, rnd);
		a += smoothstep(0.03, 0.0, abs(f.x - 0.5)) * step(0.88, rnd) * 0.4;
	}
	ALBEDO = vec3(0.78, 0.82, 0.88);
	ALPHA = clamp(0.06 + a * 0.35, 0.0, 0.7);
}
"""
	rain.shader = rs
	CutsceneKit.quad(self, Vector2(1.6, 1.45), c + Vector3(0, 0, -0.01), rain, Vector3(0, 180, 0))


func _build_tv() -> void:
	var body := CutsceneKit.mat(Color(0.03, 0.03, 0.035), 0.3, 0.2)
	CutsceneKit.box(self, Vector3(1.25, 0.74, 0.06), TV_POS, body)
	CutsceneKit.box(self, Vector3(0.3, 0.04, 0.2), TV_POS + Vector3(0, -0.4, 0.02), body)
	tv_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded;
uniform float on = 1.0;
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
	ALBEDO = c * vig * on * 1.2;
}
"""
	tv_mat.shader = sh
	CutsceneKit.quad(self, Vector2(1.17, 0.66), TV_POS + Vector3(0, 0, 0.032), tv_mat)
	tv_light = OmniLight3D.new()
	tv_light.light_color = Color(0.75, 0.72, 0.85)
	tv_light.light_energy = 0.9
	tv_light.omni_range = 4.5
	tv_light.position = TV_POS + Vector3(0, 0, 0.6)
	add_child(tv_light)


func _build_table_props() -> void:
	var top := Vector3(0.25, 0.46, 0.25)
	var box_m := CutsceneKit.mat(Color(0.75, 0.68, 0.55), 0.95)
	CutsceneKit.box(self, Vector3(0.36, 0.02, 0.36), top + Vector3(-0.2, 0.01, 0.0), box_m, Vector3(0, 12, 0))
	var lid := CutsceneKit.box(self, Vector3(0.36, 0.01, 0.36), top + Vector3(-0.2, 0.12, -0.2), box_m, Vector3(70, 12, 0))
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mug := CutsceneKit.mat(Color(0.82, 0.8, 0.76), 0.3)
	CutsceneKit.cyl(self, 0.042, 0.04, 0.1, top + Vector3(0.3, 0.05, 0.08), mug)
	CutsceneKit.cyl(self, 0.036, 0.036, 0.004, top + Vector3(0.3, 0.098, 0.08), CutsceneKit.mat(Color(0.12, 0.07, 0.04), 0.2))
	CutsceneKit.box(self, Vector3(0.05, 0.02, 0.17), top + Vector3(0.1, 0.01, -0.12), CutsceneKit.mat(Color(0.05, 0.05, 0.05), 0.4), Vector3(0, -20, 0))


func _set_phone(title: String, sub: String) -> void:
	(phone.title as Label3D).text = title
	(phone.sub as Label3D).text = sub


func tick(_delta: float) -> void:
	# Свет телевизора следует за картинкой: смена планов и мерцание
	var scene := floorf(t / 3.7)
	var warm := fposmod(sin(scene * 12.9898) * 43758.5453, 1.0)
	tv_light.light_color = Color(0.85, 0.66, 0.5).lerp(Color(0.5, 0.65, 0.9), warm)
	tv_light.light_energy = 0.75 + 0.18 * sin(t * 7.3) * sin(t * 2.1) + 0.1 * sin(t * 23.0)


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	_room = loop("amb_apartment", -16.0)
	_rain = loop("amb_rain_window", -13.0)
	_tv_amb = loop("tv_show", -15.0, 0.0, TV_POS + Vector3(0, 0, 0.3), 3.0)
	breathe = 0.8
	handheld = 0.25
	if not from_game:
		# Обычный вечер: сериал, телефон в руке, лента новостей
		shot(SOFA_EYE, Vector3(0.15, 0.95, -2.0), 58.0)
		fade_in(1.6)
		await wait(2.4)
		sfx("dog_bark_wall", -14.0, 1.0, Vector3(2.8, 1.2, 1.0), 2.0)
		look_to(Vector3(0.18, 0.62, 0.9), 1.4)
		await wait(2.2)
		sfx("phone_vibrate", -6.0)
		_set_phone("Неизвестный номер", "Вызов…")
		(phone.ok as Node3D).visible = true
		(phone.no as Node3D).visible = true
		shake(0.15)
		await wait(1.4)
		await thought("«Опять какой-нибудь банк…»", 1.6)
		sfx("phone_vibrate", -7.0)
		await wait(0.8)
		sfx("phone_tap", -6.0)
	else:
		shot(SOFA_EYE, Vector3(0.18, 0.62, 0.9), 58.0)
		fade_in(0.5)
	_set_phone("Неизвестный номер", "00:01")
	(phone.ok as Node3D).visible = false
	(phone.no as Node3D).visible = false
	await wait(0.4)
	# Телефон к уху: рука уходит вправо, взгляд — на телевизор
	tween_prop(phone_rig, "position", Vector3(0.42, -0.05, -0.12), 0.7)
	tween_prop(phone_rig, "rotation_degrees", Vector3(10, -60, 0), 0.7)
	look_to(Vector3(0.0, 1.0, -2.0), 1.2)
	var line_noise := loop("phone_line", -20.0, 0.3)
	fade(_tv_amb, -21.0, 1.0)
	await wait(1.0)
	phone_rig.visible = false
	await line("police_1", "ПОЛИЦИЯ", "Итан? Это полиция округа…", 0.5)
	# Камера медленно наезжает на экран, мир уходит
	glide(SOFA_EYE + Vector3(-0.02, -0.02, -0.18), Vector3(0.1, 0.98, -2.0), 9.0, 52.0)
	var d2 := say_line("police_2", "ПОЛИЦИЯ", "Ваш отец найден мёртвым в своей кровати. Ваш брат, Сэм, пропал. Мы не можем его найти.")
	await wait(2.6)
	var ring := sfx("res://assets/audio/intro/tinnitus.wav", -30.0)
	if ring:
		fade(ring, -16.0, 6.0)
	muffle(1400.0, 6.0)
	handheld = 0.1
	await wait(maxf(0.0, d2 - 2.6) + 0.3)
	stop(line_noise, 0.6)
	# Секунд десять Итан не может сказать ни слова
	breathe = 0.0
	var heart := loop("heartbeat_slow", -24.0, 2.0)
	await wait(2.2)
	_wide_shot()
	await wait(5.2)
	shot(SOFA_EYE + Vector3(-0.02, -0.06, -0.16), Vector3(0.05, 0.62, 0.4), 50.0)
	handheld = 0.15
	await wait(1.4)
	await line("ethan_kak", "ИТАН", "Как…", 1.0, null, -2.0)
	# По телевизору кто-то засмеялся. Итан этого уже не слышал.
	_wide_shot()
	muffle(20000.0, 0.15)
	fade(_tv_amb, -12.0, 0.2)
	sfx("tv_laugh", -9.0, 1.0, TV_POS + Vector3(0, 0, 0.3), 3.0)
	await wait(1.8)
	muffle(500.0, 2.5)
	if ring:
		fade(ring, -12.0, 2.0)
	fade_out(3.0)
	silence(3.0)
	stop(heart, 3.0)
	await wait(3.6)
	if ring:
		stop(ring, 1.0)
	await wait(0.8)


func _wide_shot() -> void:
	ethan.visible = true
	handheld = 0.0
	breathe = 0.0
	shot(WIDE_CAM, Vector3(0.2, 1.05, 1.9), 46.0)
	glide(WIDE_CAM + Vector3(-0.15, -0.04, 0.25), Vector3(0.22, 1.02, 1.9), 7.0, 43.0)
