extends CanvasLayer
class_name LumberjackScare

# Смерть от лесоруба: своя 3D-сцена поверх игры. Он стоит в упор и целится прямо в камеру,
# щёлкает курок, выстрел вспышкой на весь экран, затем обрыв в чёрный экран и тишина.

signal finished

const AIM_T: float = 0.62
const SHOT_T: float = 0.34
const BLACK_T: float = 0.9

var viewport: SubViewport
var model: LumberjackModel
var cam: Camera3D
var flash_light: OmniLight3D
var lamp: SpotLight3D
var post: ColorRect
var post_mat: ShaderMaterial
var white: ColorRect
var black: ColorRect
var _t := 0.0
var _shot_done := false
var _black_started := false
var _heart_done := false
var _done := false
var _face := Vector3.ZERO
var _shake := 0.0


func _ready() -> void:
	name = "LumberjackScare"
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
	env.ambient_light_color = Color(0.3, 0.33, 0.42)
	env.ambient_light_energy = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)

	model = LumberjackModel.new()
	viewport.add_child(model)
	for i in 70:
		model.update_motion(1.0 / 60.0, "aim", 0.0)
	_face = model.get_head_position()

	cam = Camera3D.new()
	cam.fov = 52.0
	cam.near = 0.005
	cam.current = true
	viewport.add_child(cam)

	# Снизу и сбоку, как от фонарика в руке жертвы
	lamp = SpotLight3D.new()
	lamp.light_color = Color(0.72, 0.8, 1.0)
	lamp.light_energy = 3.2
	lamp.spot_range = 6.0
	lamp.spot_angle = 16.0
	viewport.add_child(lamp)

	flash_light = OmniLight3D.new()
	flash_light.light_color = Color(1.0, 0.78, 0.5)
	flash_light.omni_range = 6.0
	flash_light.light_energy = 0.0
	viewport.add_child(flash_light)

	post_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SkinwalkerScare.POST_SHADER
	post_mat.shader = shader
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.material = post_mat
	add_child(post)

	white = ColorRect.new()
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.color = Color(1.0, 0.97, 0.88, 0.0)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(white)

	black = ColorRect.new()
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.visible = false
	add_child(black)

	# Лёгкие помехи: лицо за стволами должно быть видно
	VHSOverlay.set_fear(0.3)
	_one_shot("res://assets/audio/tv_static.wav", -14.0, 0.8)
	_one_shot("res://assets/audio/door_unlock_1.mp3", 6.0, 0.72)
	_update(0.0)


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


func _update(delta: float) -> void:
	if _done:
		return
	if _t < AIM_T + SHOT_T:
		model.update_motion(delta, "aim", 0.0)
		var shooting := _t >= AIM_T
		if shooting and not _shot_done:
			_shot_done = true
			model.kick()
			_shake = 1.0
			_one_shot("res://assets/audio/shotgun_shot.mp3", 9.0, 0.92)
			_one_shot("res://assets/audio/car_crash.wav", 6.0, 0.7)
			VHSOverlay.glitch(1.0)
		_shake = maxf(0.0, _shake - delta * 2.6)
		# Камера стоит напротив дула и медленно наезжает: стволы заполняют кадр, за ними его лицо
		var muzzle := model.get_muzzle_position()
		var u := minf(1.0, _t / AIM_T)
		var dist := lerpf(0.42, 0.05, pow(u, 1.5))
		if shooting:
			dist += (_t - AIM_T) * 1.8
		var s := 0.006 + _shake * 0.07
		var eye := muzzle + Vector3(randf_range(-s, s), 0.012 + randf_range(-s, s), dist)
		cam.position = eye
		cam.look_at(muzzle.lerp(_face, 0.1 * (1.0 - u) + 0.015), Vector3.UP)
		if shooting:
			cam.rotate_object_local(Vector3.FORWARD, (_t - AIM_T) * 2.2)
		# Свет снизу, как от упавшего фонарика: лицо страшнее, шапка уходит в темноту
		lamp.position = muzzle + Vector3(-0.1, -0.5, 0.15)
		lamp.look_at(_face + Vector3(0.0, -0.1, 0.05), Vector3.UP)
		lamp.visible = fmod(_t, 0.19) > 0.025 or shooting
		var since := _t - AIM_T
		white.color.a = clampf(1.0 - since * 8.0, 0.0, 1.0) if shooting else 0.0
		flash_light.position = muzzle + Vector3(0.0, 0.0, 0.12)
		flash_light.light_energy = 22.0 * clampf(1.0 - since * 4.5, 0.0, 1.0) if shooting else 0.0
		post_mat.set_shader_parameter("amount", 1.0 if shooting else 0.1 + 0.16 * u)
		post_mat.set_shader_parameter("time_s", _t)
		post_mat.set_shader_parameter("invert", 0.0)
		post_mat.set_shader_parameter("red", 0.7 if shooting else 0.0)
	elif _t < AIM_T + SHOT_T + BLACK_T:
		if not _black_started:
			_black_started = true
			black.visible = true
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			for ch in get_children():
				if ch is AudioStreamPlayer and ch.stream and "tv_static" in ch.stream.resource_path:
					ch.stop()
		if not _heart_done and _t > AIM_T + SHOT_T + 0.35:
			_heart_done = true
			_one_shot("res://assets/heart.mp3", 2.0, 0.9)
	else:
		_done = true
		finished.emit()
