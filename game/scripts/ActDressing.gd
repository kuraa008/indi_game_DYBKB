class_name ActDressing
extends Node3D

# Вещи первого акта на Карте 6: свет за заколоченными окнами, стук из подвала,
# камера 04 у места аварии, трава вокруг дома и текст пробуждения.

const CELLAR_POS := Vector3(-177.0, -0.3, -48.4)
const CAM_POS := Vector3(-44.2, 2.2, 85.6)

static var wake_shown := false

var _tv_mat: StandardMaterial3D
var _candle_mat: StandardMaterial3D
var _tv_light: OmniLight3D
var _candle_light: OmniLight3D
var _led_mat: StandardMaterial3D
var _knock: AudioStreamPlayer3D
var _knock_wait := 8.0
var _time := 0.0
var _tick := 0.0


func _ready() -> void:
	_build_windows()
	_build_camera()
	_build_grass()
	_knock = AudioStreamPlayer3D.new()
	_knock.stream = load("res://assets/audio/cellar_knock.wav")
	_knock.position = CELLAR_POS
	_knock.max_distance = 20.0
	_knock.unit_size = 5.0
	add_child(_knock)
	if not wake_shown:
		wake_shown = true
		_show_wake_text()


func _process(delta: float) -> void:
	_time += delta
	_tick -= delta
	_knock_wait -= delta
	if _knock_wait <= 0.0:
		_knock_wait = randf_range(26.0, 44.0)
		var p: Node3D = GameManager.player_ref as Node3D
		if is_instance_valid(p) and p.global_position.distance_to(CELLAR_POS) < 20.0:
			_knock.play()
	if _led_mat:
		_led_mat.emission_energy_multiplier = 6.0 if fmod(_time, 1.4) < 0.18 else 0.15
	if _tick > 0.0:
		return
	_tick = 0.07
	var tv := 0.55 + 0.45 * randf()
	if randf() < 0.06:
		tv = 0.2
	_tv_mat.emission_energy_multiplier = 1.5 + tv * 2.2
	_tv_light.light_energy = 0.5 + tv * 0.9
	var cn := 0.72 + 0.16 * sin(_time * 7.3) + 0.09 * sin(_time * 13.1 + 1.0) + randf() * 0.05
	_candle_mat.emission_energy_multiplier = 1.0 + cn * 1.4
	_candle_light.light_energy = cn * 0.9


func _pane_mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col * 0.45
	m.emission_enabled = true
	m.emission = col
	return m


# Окно на задней стене дома: рама, свет за стеклом и прибитые крест-накрест доски
func _window(center: Vector3, w: float, h: float, pane: StandardMaterial3D, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var wood := NatureKit.Geo.new()
	var dark := Color(0.34, 0.28, 0.22)
	wood.box(Transform3D(Basis.IDENTITY, center + Vector3(0, h * 0.5 + 0.06, -0.04)), Vector3(w + 0.3, 0.12, 0.1), dark)
	wood.box(Transform3D(Basis.IDENTITY, center + Vector3(0, -h * 0.5 - 0.06, -0.06)), Vector3(w + 0.42, 0.13, 0.15), dark)
	for sx in [-1.0, 1.0]:
		wood.box(Transform3D(Basis.IDENTITY, center + Vector3(sx * (w * 0.5 + 0.06), 0, -0.04)), Vector3(0.12, h, 0.1), dark)
	var ys := [-h * 0.34, h * 0.02, h * 0.36]
	for i in range(3):
		var tilt := rng.randf_range(-0.09, 0.09)
		var bas := Basis(Vector3.BACK, tilt)
		wood.box(Transform3D(bas, center + Vector3(rng.randf_range(-0.05, 0.05), ys[i], -0.11)), Vector3(w + 0.55, 0.22 if i != 1 else 0.17, 0.04), Color(0.72, 0.62, 0.5) * rng.randf_range(0.75, 1.05))
	var mesh := ArrayMesh.new()
	wood.commit(mesh, TextureHelper.create_wall_material("wood_planks", Color(1, 1, 1)))
	mesh.surface_get_material(0).vertex_color_use_as_albedo = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(w, h)
	qm.material = pane
	q.mesh = qm
	q.position = center + Vector3(0, 0, -0.012)
	q.rotation.y = PI
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(q)


func _soft_light(pos: Vector3, col: Color, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.omni_range = rng_m
	l.distance_fade_enabled = true
	l.distance_fade_begin = 30.0
	l.distance_fade_length = 8.0
	add_child(l)
	return l


func _build_windows() -> void:
	# Второй этаж: голубое мерцание телевизора в щели между досками
	_tv_mat = _pane_mat(Color(0.5, 0.68, 1.0))
	_window(Vector3(-169.0, 4.9, -47.21), 1.1, 1.3, _tv_mat, 11)
	_tv_light = _soft_light(Vector3(-169.0, 4.9, -47.9), Color(0.5, 0.65, 1.0), 6.0)
	# Первый этаж: свеча в соседней комнате
	_candle_mat = _pane_mat(Color(1.0, 0.58, 0.22))
	_window(Vector3(-174.3, 1.75, -47.21), 1.05, 1.25, _candle_mat, 23)
	_candle_light = _soft_light(Vector3(-174.3, 1.6, -47.9), Color(1.0, 0.6, 0.28), 5.0)


func _build_camera() -> void:
	# Столб на обочине, камера смотрит на разбитую машину
	var post := NatureKit.Geo.new()
	post.cyl(Transform3D(Basis(Vector3.BACK, 0.03), Vector3(CAM_POS.x, 0.0, CAM_POS.z)), 0.075, 0.055, CAM_POS.y - 0.03, 8, Color.WHITE)
	var post_mesh := ArrayMesh.new()
	post.commit(post_mesh, NatureKit._bark_mat())
	var post_mi := MeshInstance3D.new()
	post_mi.mesh = post_mesh
	post_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	post_mi.visibility_range_end = 70.0
	add_child(post_mi)
	var root := Node3D.new()
	root.position = CAM_POS
	root.look_at_from_position(CAM_POS, Vector3(-48.5, 0.6, 86.5), Vector3.UP)
	add_child(root)
	var g := NatureKit.Geo.new()
	var body_c := Color(0.012, 0.012, 0.014)
	g.box(Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.02)), Vector3(0.13, 0.11, 0.22), body_c)
	g.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.07, 0.0)), Vector3(0.16, 0.012, 0.28), body_c * 0.7)
	g.cyl(Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0, -0.08)), 0.038, 0.034, 0.05, 10, Color(0.03, 0.03, 0.035), true)
	var mesh := ArrayMesh.new()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.55
	g.commit(mesh, m)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 60.0
	root.add_child(mi)
	_led_mat = StandardMaterial3D.new()
	_led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_led_mat.albedo_color = Color(0.6, 0.02, 0.02)
	_led_mat.emission_enabled = true
	_led_mat.emission = Color(1.0, 0.05, 0.03)
	var led := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.014
	sm.height = 0.028
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _led_mat
	led.mesh = sm
	led.position = Vector3(0.045, 0.035, -0.092)
	root.add_child(led)
	# Второй огонёк сзади, чтобы его было видно с дороги
	var led_back := MeshInstance3D.new()
	led_back.mesh = sm
	led_back.position = Vector3(0.04, 0.03, 0.135)
	root.add_child(led_back)
	var tag := Label3D.new()
	tag.text = "04"
	tag.font_size = 40
	tag.pixel_size = 0.0016
	tag.modulate = Color(0.85, 0.85, 0.8)
	tag.position = Vector3(0.0665, -0.01, 0.02)
	tag.rotation.y = PI * 0.5
	tag.visibility_range_end = 25.0
	root.add_child(tag)


func _build_grass() -> void:
	var g := NatureKit.Geo.new()
	var up := Vector3(0.0, 1.0, 0.0)
	var base_c := Color(0.72, 0.76, 0.72)
	var top_c := Color(1.0, 1.0, 1.0)
	for rot_i in range(2):
		var a := float(rot_i) * PI * 0.5 + 0.35
		var d := Vector3(cos(a), 0, sin(a)) * 0.34
		var p0 := -d
		var p1 := d
		var t0 := -d + Vector3(0.02, 0.5, 0.0)
		var t1 := d + Vector3(0.02, 0.5, 0.0)
		g.vert(p0, up, base_c, Vector2(0, 1))
		g.vert(p1, up, base_c, Vector2(1, 1))
		g.vert(t1, up, top_c, Vector2(1, 0))
		g.vert(p0, up, base_c, Vector2(0, 1))
		g.vert(t1, up, top_c, Vector2(1, 0))
		g.vert(t0, up, top_c, Vector2(0, 0))
		# Вторая сторона отдельно: с одной нормалью вверх обе стороны освещены как земля
		g.vert(p0, up, base_c, Vector2(0, 1))
		g.vert(t1, up, top_c, Vector2(1, 0))
		g.vert(p1, up, base_c, Vector2(1, 1))
		g.vert(p0, up, base_c, Vector2(0, 1))
		g.vert(t0, up, top_c, Vector2(0, 0))
		g.vert(t1, up, top_c, Vector2(1, 0))
	var mesh := ArrayMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/textures/nature/grass_tuft.png")
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.42
	m.roughness = 0.42
	m.metallic_specular = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	g.commit(mesh, m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 511
	var chunk := 15.0
	for cx in range(-14, -8):
		for cz in range(-7, 0):
			var org := Vector3(cx * chunk, 0.0, cz * chunk)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = mesh
			var xfs: Array[Transform3D] = []
			for _i in range(280):
				var p := Vector3(rng.randf_range(0.0, chunk), 0.0, rng.randf_range(0.0, chunk))
				var w := org + p
				# Внутри дома и на крыльце травы нет
				if w.x > -179.5 and w.x < -158.5 and w.z > -47.6 and w.z < -28.0:
					continue
				if w.x > -179.6 and w.x < -174.4 and w.z > -50.2 and w.z < -46.8:
					continue
				var s := rng.randf_range(0.5, 0.95)
				var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
				xfs.append(Transform3D(b, p))
			mm.instance_count = xfs.size()
			for i in range(xfs.size()):
				mm.set_instance_transform(i, xfs[i])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.position = org
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mmi.visibility_range_end = 42.0
			mmi.visibility_range_end_margin = 5.0
			add_child(mmi)


func _show_wake_text() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var title := Label.new()
	title.text = "Итан очнулся…"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78))
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	title.modulate.a = 0.0
	layer.add_child(title)
	var stamp := Label.new()
	stamp.text = "ОКТ. 31 1994    23:47"
	stamp.add_theme_font_size_override("font_size", 20)
	stamp.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	stamp.position = Vector2(30, 52)
	stamp.modulate.a = 0.0
	layer.add_child(stamp)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(stamp, "modulate:a", 0.9, 0.5)
	tw.parallel().tween_property(title, "modulate:a", 1.0, 1.2)
	tw.tween_interval(2.6)
	tw.tween_property(title, "modulate:a", 0.0, 1.2)
	tw.tween_interval(1.5)
	tw.tween_property(stamp, "modulate:a", 0.0, 1.0)
	tw.tween_callback(layer.queue_free)
