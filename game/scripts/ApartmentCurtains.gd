extends "res://scripts/ApartmentKit.gd"

# Шторы на окне в комнате: две половины на карнизе. По нажатию левая уезжает
# налево, правая направо; закрываются навстречу друг другу к центру.
# Складки считает видеокарта, поэтому движение ткани почти не нагружает игру.

const CENTRE := Vector3(0.3, FL, 2.275)   # середина карниза на полу, у стены с окном
const ROD_Y := 2.53
const TOP_Y := 2.5
const HEM_Y := 0.99                        # низ штор чуть выше подоконника
const END_X := 1.2                         # от середины до края карниза
const CLOSED_W := 1.22                     # половина закрыта и заходит за середину
const OPEN_W := 0.36                       # половина собрана у края окна
const FOLDS := 8
const CLOTH := Color(0.8, 0.77, 0.7)
const ROD := Color(0.07, 0.07, 0.08)

const FABRIC_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float open_amount = 1.0;
uniform float dir = 1.0;
uniform float closed_w = 1.2;
uniform float open_w = 0.36;
uniform float height = 1.5;
uniform float folds = 8.0;
uniform vec3 cloth = vec3(0.6);
uniform sampler2D tex : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 tuv;
varying float valley;
void vertex() {
	float s = UV.x;
	float t = UV.y;
	float w = mix(closed_w, open_w, open_amount);
	float phase = s * TAU * folds + 0.9 * t * sin(s * 11.0);
	float wave = sin(phase) * 0.72 + sin(phase * 0.47 + 1.9) * 0.28;
	float depth = mix(0.024, 0.04, open_amount) * (0.72 + 0.4 * t);
	float slope = depth * TAU * folds * (cos(phase) * 0.72 + 0.47 * cos(phase * 0.47 + 1.9) * 0.28);
	VERTEX = vec3(dir * s * w, -t * height - 0.008 * t * sin(s * 23.0), wave * depth);
	NORMAL = normalize(vec3(-dir * slope, 0.0, w));
	valley = 0.5 - 0.5 * wave;
	tuv = vec2(s * closed_w, t * height) * 5.0;
}
void fragment() {
	vec3 c = cloth * mix(vec3(0.72), texture(tex, tuv * 2.0).rgb, 0.22);
	c *= mix(1.0, 0.56, valley);
	ALBEDO = c;
	if (dot(NORMAL, VIEW) < 0.0) { NORMAL = -NORMAL; }
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
}
"""


class CurtainPair extends Area3D:
	var panels: Array = []
	var rings: MultiMesh
	var amount := 1.0
	var closed := false
	var tween: Tween
	var sound: AudioStreamPlayer3D

	func _ready() -> void:
		collision_layer = 1 | 4
		collision_mask = 0
		apply(1.0)

	func get_interaction_hint() -> String:
		return "[ЛКМ / RT]  Открыть шторы" if closed else "[ЛКМ / RT]  Закрыть шторы"

	func interact(_opener: Node3D = null) -> void:
		closed = not closed
		var goal := 0.0 if closed else 1.0
		if tween and tween.is_valid():
			tween.kill()
		tween = create_tween()
		tween.tween_method(apply, amount, goal, 0.3 + 1.0 * absf(goal - amount)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sound.pitch_scale = randf_range(0.94, 1.08)
		sound.play()

	# value: 1 — шторы разведены к краям, 0 — закрыты
	func apply(value: float) -> void:
		amount = value
		for m in panels:
			m.set_shader_parameter("open_amount", value)
		var width: float = lerpf(CLOSED_W, OPEN_W, value)
		var n := 0
		var turn := Basis(Vector3.BACK, PI * 0.5)
		for dir in [1.0, -1.0]:
			for k in range(FOLDS):
				var s := (float(k) + 0.25) / float(FOLDS)
				var x: float = -dir * END_X + dir * s * width
				rings.set_instance_transform(n, Transform3D(turn, Vector3(x, ROD_Y - 0.006, 0)))
				n += 1


func _ready() -> void:
	name = "ApartmentCurtains"
	_rng.seed = 2214
	_build_rod()
	var pair := CurtainPair.new()
	# Ткань лежит отдельно от зоны нажатия: игра подсвечивает только детей этой зоны
	var visual := CutsceneKit.node(self, CENTRE)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(END_X * 2.0, TOP_Y - HEM_Y + 0.1, 0.1)
	col.shape = shape
	col.position = Vector3(0, (TOP_Y + HEM_Y) * 0.5, 0)
	pair.add_child(col)
	var texture: Texture2D = CutsceneKit.tmat("fabric.png").albedo_texture
	var mesh := _panel_mesh()
	for dir in [1.0, -1.0]:
		var mt := _shader(FABRIC_SHADER)
		mt.set_shader_parameter("dir", dir)
		mt.set_shader_parameter("closed_w", CLOSED_W)
		mt.set_shader_parameter("open_w", OPEN_W)
		mt.set_shader_parameter("height", TOP_Y - HEM_Y)
		mt.set_shader_parameter("folds", float(FOLDS))
		mt.set_shader_parameter("cloth", Vector3(CLOTH.srgb_to_linear().r, CLOTH.srgb_to_linear().g, CLOTH.srgb_to_linear().b))
		mt.set_shader_parameter("tex", texture)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Форму задаёт шейдер, поэтому границы для отсечения указаны вручную
		mi.custom_aabb = AABB(Vector3(-END_X * 2.2, -(TOP_Y - HEM_Y) - 0.1, -0.1), Vector3(END_X * 4.4, TOP_Y - HEM_Y + 0.2, 0.2))
		visual.add_child(mi)
		mi.position = Vector3(-dir * END_X, TOP_Y, 0)
		pair.panels.append(mt)

	var ring_set := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var ring := TorusMesh.new()
	ring.inner_radius = 0.0175
	ring.outer_radius = 0.0215
	ring.rings = 16
	ring.ring_segments = 6
	mm.mesh = ring
	mm.instance_count = FOLDS * 2
	ring_set.multimesh = mm
	ring_set.material_override = CutsceneKit.mat(ROD, 0.4, 0.5)
	ring_set.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.add_child(ring_set)
	pair.rings = mm

	var sound := AudioStreamPlayer3D.new()
	sound.stream = _swish()
	sound.max_distance = 12.0
	sound.unit_size = 3.0
	pair.add_child(sound)
	pair.sound = sound

	add_child(pair)
	pair.position = CENTRE


# Карниз: чёрная труба, шары на концах, кронштейны к стене
func _build_rod() -> void:
	_base = _xf(CENTRE)
	var half := END_X + 0.05
	_tube([Vector3(-half, ROD_Y, 0), Vector3(0, ROD_Y, 0), Vector3(half, ROD_Y, 0)], 0.0135, ROD, 12)
	for s in [-1.0, 1.0]:
		_bl(Vector3.ONE * 0.034, Vector3(s * (half + 0.03), ROD_Y, 0), ROD)
		_cy(0.017, 0.017, 0.03, Vector3(s * (half + 0.004), ROD_Y, 0), ROD, Vector3(0, 0, 90), 10)
	for x in [-END_X + 0.03, 0.0, END_X - 0.03]:
		_pipe(Vector3(x, ROD_Y, 0), Vector3(x, ROD_Y, 0.065), 0.008, ROD)
		_cy(0.024, 0.026, 0.006, Vector3(x, ROD_Y, 0.062), ROD, Vector3(90, 0, 0), 12)
	_flush(_vmat(0.4, 0.5))


# Заготовка полотна: только сетка, координаты берёт шейдер из UV
func _panel_mesh() -> ArrayMesh:
	var nu := FOLDS * 12
	var nv := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corner := func(i: int, j: int) -> void:
		var uv := Vector2(float(i) / float(nu), float(j) / float(nv))
		st.set_normal(Vector3.BACK)
		st.set_uv(uv)
		st.add_vertex(Vector3(uv.x, -uv.y, 0))
	for j in range(nv):
		for i in range(nu):
			for q in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]:
				corner.call(q[0], q[1])
	st.index()
	return st.commit()


# Звук: шорох ткани и лёгкий стук колец, собирается при загрузке
func _swish() -> AudioStreamWAV:
	var rate := 22050
	var count := int(float(rate) * 1.25)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var low := 0.0
	var next_click := 0.08
	var since := 1.0
	for i in range(count):
		var time := float(i) / float(rate)
		low += (_rng.randf_range(-1.0, 1.0) - low) * 0.14
		if time >= next_click:
			next_click = time + _rng.randf_range(0.09, 0.2)
			since = 0.0
		since += 1.0 / float(rate)
		var body := smoothstep(0.0, 0.2, time) * (1.0 - smoothstep(0.95, 1.25, time))
		var click := sin(time * 3400.0 * TAU) * exp(-since * 320.0) * 0.14 * body
		pcm.encode_s16(i * 2, int(clampf(low * body * 0.8 + click, -1.0, 1.0) * 24000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = pcm
	return wav
