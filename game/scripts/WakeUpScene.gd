class_name WakeUpScene
extends CanvasLayer

# Пробуждение Итана у подвала: веки открываются рывками, звон в ушах и сердце.
# В первый раз вдали стоит силуэт, после следующего моргания его уже нет.

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float split = 0.0;
void fragment() {
	vec3 c = vec3(0.0);
	float w = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			c += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * amount * 2.0, 1.5).rgb;
			w += 1.0;
		}
	}
	c /= w;
	vec3 ghost = textureLod(screen_tex, SCREEN_UV + vec2(split, split * 0.3), 2.0).rgb;
	COLOR = vec4(mix(c, ghost, split > 0.0005 ? 0.42 : 0.0) * vec3(0.92, 0.82, 0.8), 1.0);
}
"""

var _blur: ColorRect
var _blur_mat: ShaderMaterial
var _top: TextureRect
var _bottom: TextureRect
var _black: ColorRect
var _title: Label
var _stamp: Label
var _ring: AudioStreamPlayer
var _breath: AudioStreamPlayer
var _figure: Node3D
var _figure_light: OmniLight3D
var _moon: OmniLight3D
var _player: Node3D
var _head: Node3D
var _open := 0.0
var _glitch := false


func _ready() -> void:
	layer = 100
	_build_screen()
	_set_open(0.0)
	_run()


func _process(delta: float) -> void:
	if is_instance_valid(_figure) and _figure.has_method("update_motion"):
		_figure.call("update_motion", delta, "idle", 0.0)
		var cam := get_viewport().get_camera_3d()
		if cam:
			_figure.call("set_look_target", cam.global_position)
	if _glitch and is_instance_valid(_title):
		_title.position.x = _title_base_x() + randf_range(-5.0, 5.0)
		_title.modulate.a = 0.0 if randf() < 0.22 else randf_range(0.65, 1.0)


func _title_base_x() -> float:
	return (get_viewport().get_visible_rect().size.x - _title.size.x) * 0.5


func _lid_texture(flip: bool) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.72, Color(0, 0, 0, 1))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 8
	t.height = 256
	t.fill_from = Vector2(0, 1 if flip else 0)
	t.fill_to = Vector2(0, 0 if flip else 1)
	return t


func _build_screen() -> void:
	_blur = ColorRect.new()
	_blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	_blur_mat = ShaderMaterial.new()
	_blur_mat.shader = sh
	_blur.material = _blur_mat
	add_child(_blur)
	for flip in [false, true]:
		var lid := TextureRect.new()
		lid.texture = _lid_texture(flip)
		lid.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lid.stretch_mode = TextureRect.STRETCH_SCALE
		lid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(lid)
		if flip:
			_bottom = lid
		else:
			_top = lid
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.add_theme_color_override("font_color", Color(0.82, 0.8, 0.74))
	_title.modulate.a = 0.0
	add_child(_title)
	_stamp = Label.new()
	_stamp.text = "ОКТ. 31 1994    23:47"
	_stamp.add_theme_font_size_override("font_size", 20)
	_stamp.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	_stamp.position = Vector2(30, 52)
	_stamp.modulate.a = 0.0
	add_child(_stamp)
	_ring = _audio("res://assets/audio/wake_ring.wav", -3.0)
	_breath = _audio("res://assets/audio/monster/monster_breath.wav", -5.0)


func _audio(path: String, db: float) -> AudioStreamPlayer:
	var a := AudioStreamPlayer.new()
	if ResourceLoader.exists(path):
		a.stream = load(path)
	a.volume_db = db
	add_child(a)
	return a


# 0 — глаза закрыты, 1 — открыты полностью
func _set_open(o: float) -> void:
	_open = o
	var vh: float = get_viewport().get_visible_rect().size.y
	var vw: float = get_viewport().get_visible_rect().size.x
	var h := vh * 0.8
	_top.size = Vector2(vw, h)
	_bottom.size = Vector2(vw, h)
	_top.position = Vector2(0, lerpf(vh * 0.62 - h, -h, o))
	_bottom.position = Vector2(0, lerpf(vh * 0.38, vh, o))
	_black.color.a = clampf(1.0 - o * 7.0, 0.0, 1.0)


func _lids(to: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_open, _open, to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec, false).timeout


func _blur_to(amount: float, split: float, time: float) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_blur_mat, "shader_parameter/amount", amount, time)
	tw.tween_property(_blur_mat, "shader_parameter/split", split, time)


func _show_title(text: String, col: Color, fade: float, hold: float, out: float) -> void:
	_title.text = text
	_title.add_theme_color_override("font_color", col)
	_title.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_title.position = Vector2((vp.x - _title.size.x) * 0.5, vp.y * 0.5 - _title.size.y * 0.5)
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, fade)
	tw.tween_interval(hold)
	tw.tween_property(_title, "modulate:a", 0.0, out)
	await tw.finished


func _set_figure(on: bool) -> void:
	if not on:
		if is_instance_valid(_figure):
			_figure.queue_free()
		if is_instance_valid(_figure_light):
			_figure_light.queue_free()
		return
	var scene := get_tree().current_scene
	var fwd := -_player.global_transform.basis.z
	var side := _player.global_transform.basis.x
	var ground := _player.global_position
	ground.y = 0.0
	var at: Vector3 = ground + fwd * 4.6 + side * 0.5
	_figure = SkinwalkerModel.new()
	scene.add_child(_figure)
	_figure.global_position = at
	_figure.look_at(ground, Vector3.UP, true)
	_figure_light = OmniLight3D.new()
	_figure_light.light_color = Color(0.55, 0.68, 1.0)
	_figure_light.light_energy = 26.0
	_figure_light.omni_range = 7.5
	scene.add_child(_figure_light)
	_figure_light.global_position = at - fwd * 2.0 + side * 0.8 + Vector3.UP * 2.2
	# Глаза светятся в темноте
	var eye_mat := StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.92, 0.75)
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.04
	eye_mesh.height = 0.08
	eye_mesh.radial_segments = 8
	eye_mesh.rings = 4
	eye_mesh.material = eye_mat
	var head_at: Vector3 = _figure.call("get_head_position")
	for sx in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = eye_mesh
		_figure.add_child(eye)
		eye.global_position = head_at - fwd * 0.15 + side * sx * 0.085


func _run() -> void:
	while not is_instance_valid(GameManager.player_ref) or not GameManager.player_ref.is_inside_tree():
		await get_tree().process_frame
	_player = GameManager.player_ref
	_head = _player.get("head")
	_player.set("is_in_cutscene", true)
	_player.velocity = Vector3.ZERO
	# Итан лежит спиной к подвалу и смотрит в лес
	_player.rotation.y = 0.0
	var hands: Node3D = _player.get("player_hands")
	if hands:
		hands.visible = false
	var ui = GameManager.ui_ref
	if ui and is_instance_valid(ui) and "visible" in ui:
		ui.visible = false
	_head.position.y = 0.32
	_head.rotation = Vector3(0.34, 0.0, 0.3)
	_blur_mat.set_shader_parameter("amount", 0.0016)
	_blur_mat.set_shader_parameter("split", 0.008)
	# Лунного света хватает только разглядеть силуэт
	_moon = OmniLight3D.new()
	_moon.light_color = Color(0.55, 0.65, 0.95)
	_moon.light_energy = 3.5
	_moon.omni_range = 22.0
	get_tree().current_scene.add_child(_moon)
	_moon.global_position = _player.global_position + Vector3.UP * 3.5 - _player.global_transform.basis.z * 2.5
	_ring.play()
	await _wait(0.9)

	# Первое открытие: кто-то стоит и смотрит
	_set_figure(true)
	_breath.play()
	await _lids(0.4, 0.55)
	await _wait(0.5)
	await _lids(0.55, 0.5)
	await _wait(0.75)
	await _lids(0.0, 0.16)
	_set_figure(false)
	_breath.stop()
	_blur_to(0.0016, 0.005, 0.2)
	await _wait(0.35)
	await _show_title("Итан очнулся…", Color(0.82, 0.8, 0.74), 0.4, 0.6, 0.35)

	# Второе открытие: на том месте пусто, только шёпот рядом
	var whisper := _audio("res://assets/audio/monster/monster_mimic.wav", -9.0)
	whisper.play()
	await _lids(0.62, 0.5)
	_blur_to(0.0009, 0.002, 0.7)
	await _wait(0.7)
	await _lids(0.0, 0.12)
	await _wait(0.28)

	# Итан поднимается, голова ещё кружится
	if is_instance_valid(_moon):
		_moon.queue_free()
	if hands:
		hands.visible = true
	if ui and is_instance_valid(ui) and "visible" in ui:
		ui.visible = true
	_lids(1.0, 0.75)
	_blur_to(0.0, 0.0, 1.6)
	var rise := create_tween().set_parallel()
	rise.tween_property(_head, "position:y", 1.62, 1.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(_head, "rotation:z", 0.0, 1.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rise.tween_property(_head, "rotation:x", 0.0, 1.3).set_trans(Tween.TRANS_SINE)
	var st := create_tween()
	st.tween_interval(0.5)
	st.tween_property(_stamp, "modulate:a", 0.9, 0.5)
	await rise.finished
	_blur.visible = false
	_head.rotation = Vector3.ZERO
	if is_instance_valid(_player):
		_player.set("is_in_cutscene", false)

	# Короткая надпись дёргается и пропадает
	_title.text = "Он всё ещё здесь."
	_title.add_theme_color_override("font_color", Color(0.78, 0.12, 0.09))
	_title.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_title.position = Vector2((vp.x - _title.size.x) * 0.5, vp.y * 0.34)
	_glitch = true
	await _wait(1.1)
	_glitch = false
	_title.modulate.a = 0.0
	await _wait(2.2)
	var out := create_tween()
	out.tween_property(_stamp, "modulate:a", 0.0, 1.0)
	await out.finished
	queue_free()
