extends CanvasLayer
class_name SkinwalkerScare

# Скример скинвокера: своя 3D-сцена поверх игры, поэтому стены и мебель
# не могут перекрыть лицо. Лицо в упор с криком, затем обрыв в чёрный экран.

signal finished

const CLOSE_T: float = 1.1
const BLACK_T: float = 0.9

const POST_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 1.0;
uniform float time_s = 0.0;
uniform float invert = 0.0;
uniform float red = 0.6;
float h(float n){ return fract(sin(n) * 43758.5453); }
void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	c *= 1.0 + amount * 0.42 * dot(c, c);
	vec2 uv = c + 0.5;
	float row = floor(SCREEN_UV.y * 34.0);
	uv.x += amount * step(0.93, h(row * 91.7 + floor(time_s * 24.0) * 17.0)) * 0.075 * (h(row + time_s) - 0.5) * 2.0;
	vec2 off = vec2(amount * 0.0055, amount * 0.001);
	vec3 col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	col = (col - 0.5) * (1.0 + amount * 0.75) + 0.5;
	col *= vec3(1.0 + 0.22 * amount, 1.0 - 0.28 * amount, 1.0 - 0.32 * amount);
	col += (h(SCREEN_UV.x * 311.0 + SCREEN_UV.y * 173.0 + time_s * 91.0) - 0.5) * 0.16 * amount;
	col = mix(col, 1.0 - col, invert);
	float v = smoothstep(0.32, 0.78, length(SCREEN_UV - 0.5));
	col = mix(col, vec3(0.32, 0.0, 0.0), v * red);
	COLOR = vec4(col, 1.0);
}
"""

var viewport: SubViewport
var model: SkinwalkerModel
var cam: Camera3D
var strobe: OmniLight3D
var post: ColorRect
var post_mat: ShaderMaterial
var black: ColorRect
var screams: Array[AudioStreamPlayer] = []
var _t := 0.0
var _black_started := false
var _heart_done := false
var _done := false
var _flashes := true


func _ready() -> void:
	name = "SkinwalkerScare"
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS

	var container := SubViewportContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.handle_input_locally = false
	viewport.audio_listener_enable_3d = false
	container.add_child(viewport)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.5)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)

	model = SkinwalkerModel.new()
	viewport.add_child(model)

	cam = Camera3D.new()
	cam.fov = 36.0
	cam.current = true
	viewport.add_child(cam)

	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.62, 0.7, 1.0)
	rim.light_energy = 1.5
	rim.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(145.0), 0.0)
	viewport.add_child(rim)

	strobe = OmniLight3D.new()
	strobe.light_color = Color(1.0, 0.94, 0.9)
	strobe.omni_range = 5.0
	viewport.add_child(strobe)

	post_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = POST_SHADER
	post_mat.shader = shader
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.material = post_mat
	add_child(post)

	black = ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.visible = false
	add_child(black)

	_start_sound()
	_update(0.0)


func _start_sound() -> void:
	var path := "res://assets/scream.mp3" if ResourceLoader.exists("res://assets/scream.mp3") else "res://assets/audio/skinwalker_scream.mp3"
	var stream: Variant = load(path) if ResourceLoader.exists(path) else null
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		stream.loop = true
	if stream:
		# Три слоя с разной высотой дают нечеловеческий многоголосый крик
		for layer_def in [[1.0, 7.0], [0.74, 5.0], [1.32, 2.0]]:
			var p := AudioStreamPlayer.new()
			p.stream = stream
			p.pitch_scale = layer_def[0]
			p.volume_db = layer_def[1]
			add_child(p)
			p.play()
			screams.append(p)
	_one_shot("res://assets/audio/car_crash.wav", 6.0, 0.74)
	var st := _one_shot("res://assets/audio/tv_static.wav", -2.0, 1.35)
	if st:
		screams.append(st)


func _one_shot(path: String, db: float, pitch: float) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	return p


func _process(delta: float) -> void:
	_t += delta
	_update(delta)


func _update(_delta: float) -> void:
	if _done:
		return
	if _t < CLOSE_T:
		var q := int(_t * 20.0)
		model.apply_scare_pose(_t)
		var d := lerpf(1.0, 0.43, minf(1.0, _t / 0.08)) * SkinwalkerModel.MODEL_SCALE
		cam.fov = lerpf(36.0, 56.0, minf(1.0, _t / 0.1))
		var face := model.get_face_center()
		cam.position = face + Vector3(randf_range(-0.014, 0.014), randf_range(-0.014, 0.014) - 0.012, d)
		cam.look_at(face, Vector3.UP)
		strobe.position = cam.position + Vector3(0.08, 0.16, 0.04)
		strobe.light_energy = (16.0 if q % 2 == 1 else 7.0)
		post_mat.set_shader_parameter("amount", 1.0)
		post_mat.set_shader_parameter("time_s", _t)
		post_mat.set_shader_parameter("invert", 1.0 if q % 7 == 3 else 0.0)
		post_mat.set_shader_parameter("red", 0.55 + 0.25 * absf(sin(q * 7.3)))
	elif _t < CLOSE_T + BLACK_T:
		if not _black_started:
			_black_started = true
			# Крик обрывается мгновенно — после него только тишина и сердце
			for p in screams:
				if is_instance_valid(p):
					p.stop()
			black.visible = true
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		if not _heart_done and _t > CLOSE_T + 0.35:
			_heart_done = true
			_one_shot("res://assets/heart.mp3", 2.0, 0.9)
	else:
		_done = true
		finished.emit()
