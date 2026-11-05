class_name HighwayChapter
extends Node3D

# Пролог на карте «Шоссе»: от аварии до камеры 04.
# Итан приходит в себя у пикапа, идёт на голос через старый дом и лес,
# у камеры падает и оборачивается. После скримера начинается 1-й уровень.

const WRECK_POS := Vector3(-7.2, 0.0, -247.1)
const HOUSE_DIR_POS := Vector3(-60.0, 2.0, -225.0)
const CAMERA_POS := Vector3(-7.4, 0.0, -312.0)
const NEXT_MAP := "res://scenes/1level.json"
const FOG_COLOR := Color(0.062, 0.082, 0.125)
const LOOK_SENS := 0.0022

const NOTE_SAM := "«Ол дыбысты естиді. Ол дауысты қайталайды. Артыңа қарама.»\n\nОно слышит звук. Оно повторяет голос. Не оборачивайся.\n\nКамера 04 стоит на ели у шоссе, за калиткой. Ключ оставляю на столе.\nЕсли ты это читаешь, Итан, уезжай.\n\n— Сэм"
const NOTE_HALL := "Холлис предупреждал: по ночам дорогу лучше не переходить.\nТой ночью я слышал, как мама зовёт меня из леса.\nМама умерла двенадцать лет назад."

var _player: CharacterBody3D
var _head: Node3D
var _t := 0.0
var _done: Dictionary = {}
var _layer: CanvasLayer
var _black: ColorRect
var _speaker: Label
var _line: Label
var _warn: Label
var _sub_tween: Tween
var _horn: AudioStreamPlayer3D
var _steam_audio: AudioStreamPlayer3D
var _heart: AudioStreamPlayer
var _steam: CPUParticles3D
var _car_light: SpotLight3D
var _cam_led: MeshInstance3D
var _led_light: OmniLight3D
var _flicker_lights: Array[Light3D] = []
var _tv_light: OmniLight3D
var _tv_strip: MeshInstance3D
var _ending := false
var _turn_active := false
var _turned := 0.0
var _boundary_cd := 0.0
var _interior: Array = []
var _interior_on := true
var _missions: MissionTracker
var _doors: Dictionary = {}
var _map: Dictionary = {}
var _segments: Array = []
var _house_lights: Array[Node3D] = []
var _candle: OmniLight3D


func _ready() -> void:
	name = "HighwayChapter"
	_load_map_data()
	_hide_city_horizon()
	_build_screen()
	_setup_fog()
	_build_ground()
	_build_mountains()
	_build_boundaries()
	_build_trails()
	_build_crash_effects()
	_build_house_lights()
	_build_camera04()
	_dress_house()
	_build_forest()
	_build_grass()
	_set_items_still()
	_setup_interior()
	_setup_missions()
	_run_start()


func _say(speaker: String, line: String, hold: float) -> void:
	_speaker.text = speaker
	_line.text = line
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_speaker.get_parent(), "modulate:a", 1.0, 0.25)
	_sub_tween.tween_interval(hold)
	_sub_tween.tween_property(_speaker.get_parent(), "modulate:a", 0.0, 0.35)


func _sound(path: String, db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


func _sound_at(path: String, at: Vector3, db: float = 0.0, pitch: float = 1.0, loop: bool = false) -> AudioStreamPlayer3D:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	p.max_distance = 140.0
	p.unit_size = 14.0
	add_child(p)
	p.global_position = at
	p.finished.connect(p.play if loop else p.queue_free)
	p.play()
	return p


func _once(key: String) -> bool:
	if _done.has(key):
		return false
	_done[key] = true
	return true


# ─── Построение ───────────────────────────────────────────────────────────────

func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_black)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.custom_minimum_size = Vector2(1100.0, 0.0)
	box.offset_left = -550.0
	box.offset_right = 550.0
	box.offset_top = -150.0
	box.offset_bottom = -70.0
	box.alignment = BoxContainer.ALIGNMENT_END
	box.modulate.a = 0.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(box)
	_speaker = _label(19, Color(0.62, 0.66, 0.74))
	box.add_child(_speaker)
	_line = _label(29, Color(0.93, 0.92, 0.88))
	box.add_child(_line)

	_warn = _label(46, Color(0.86, 0.1, 0.08))
	_warn.text = "НЕ ОБОРАЧИВАЙСЯ"
	_warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_warn.offset_left = -400.0
	_warn.offset_right = 400.0
	_warn.offset_top = -40.0
	_warn.offset_bottom = 40.0
	_warn.modulate.a = 0.0
	_layer.add_child(_warn)


func _label(px: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# Городской горизонт из общей сцены здесь не нужен: его окна светились сквозь лес
func _hide_city_horizon() -> void:
	for n in get_parent().find_children("*", "Node3D", true, false):
		var sc = n.get_script()
		if sc and str(sc.resource_path).ends_with("ParallaxHorizon.gd"):
			n.visible = false
			n.set_process(false)


# Внутренности дома скрыты снаружи и появляются, когда заходишь: снаружи их всё равно не видно
func _setup_interior() -> void:
	var candidates: Array = []
	candidates.append_array(get_parent().get("nav_region").get_children())
	candidates.append_array(get_parent().get_children())
	candidates.append_array(get_children())
	for n in candidates:
		if n is Node3D and n != self:
			var p: Vector3 = n.global_position
			if p.x > -70.9 and p.x < -53.1 and p.z > -230.9 and p.z < -219.1 and p.y < 6.7:
				_interior.append(n)
	_set_interior(false)


func _set_interior(on: bool) -> void:
	_interior_on = on
	for n in _interior:
		if is_instance_valid(n):
			n.visible = on


func _update_interior(pos: Vector3) -> void:
	var inside := pos.x > -71.0 and pos.x < -53.0 and pos.z > -231.0 and pos.z < -219.0
	var at_door := Vector2(pos.x + 53.0, pos.z + 225.0).length() < 9.0 and _door_flag(-53.0, -225.0, "is_open")
	var want := inside or at_door
	if want != _interior_on:
		_set_interior(want)


func _setup_missions() -> void:
	_missions = MissionTracker.new()
	_missions.setup([
		{"text": "Найди хижину", "done": func(): return _pl_pos().x < -38.0},
		{"text": "Проверь дверь хижины", "done": func(): return _done.has("porch") or GameManager.has_crowbar},
		{"text": "Найди лом в гараже рядом с хижиной", "done": func(): return GameManager.has_crowbar},
		{"text": "Сорви доски с парадной двери", "done": func(): return _door_flag(-53.0, -225.0, "door_boards_broken")},
		{"text": "Войди в хижину", "done": func(): return _done.has("inside")},
		{"text": "Найди ключ в комнате Сэма на втором этаже", "done": func(): return GameManager.has_key_id(1)},
		{"text": "Открой калитку в заборе за хижиной", "done": func(): return _door_flag(-60.0, -262.0, "is_open") or _pl_pos().z < -263.0},
		{"text": "Иди по тропе через лес", "done": func(): return _ending},
	])
	add_child(_missions)


func _pl_pos() -> Vector3:
	return _player.global_position if is_instance_valid(_player) else Vector3(0.0, 0.0, -241.0)


func _door_flag(x: float, z: float, prop: String) -> bool:
	var key := "%d_%d" % [int(x), int(z)]
	if not _doors.has(key):
		for n in get_parent().find_children("*", "Node3D", true, false):
			if n.has_method("get_door_info") and n.name != "Panel" and absf(n.global_position.x - x) < 1.0 and absf(n.global_position.z - z) < 1.0:
				_doors[key] = n
				break
	var d = _doors.get(key)
	return is_instance_valid(d) and d.get(prop) == true


func _load_map_data() -> void:
	var file := FileAccess.open(GameManager.active_map_path, FileAccess.READ)
	if file:
		var data = JSON.parse_string(file.get_as_text())
		if data is Dictionary:
			_map = data


# Туман скрывает край мира, и дальше него ничего не рисуется: это главный выигрыш в FPS
func _setup_fog() -> void:
	_apply_fog()
	if GameManager and not GameManager.graphics_quality_changed.is_connected(_on_quality_changed):
		GameManager.graphics_quality_changed.connect(_on_quality_changed)


func _on_quality_changed(_q: String) -> void:
	call_deferred("_apply_fog")


func _apply_fog() -> void:
	var node = get_parent().get("world_env_node")
	if node == null or node.environment == null:
		return
	var env: Environment = node.environment
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = FOG_COLOR
	env.fog_light_energy = 1.0
	env.fog_density = 0.03
	env.fog_sky_affect = 0.2
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.28, 0.42)
	env.ambient_light_energy = 0.55
	var moon = get_parent().get("moon_light")
	if moon:
		moon.light_energy = 0.55
	env.fog_sun_scatter = 0.0
	env.volumetric_fog_enabled = false
	env.ssil_enabled = false
	env.ssr_enabled = false


func _build_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900.0, 900.0)
	var m := StandardMaterial3D.new()
	m.albedo_texture = HouseKit.tex("forest_floor.png")
	m.uv1_scale = Vector3(170.0, 170.0, 1.0)
	m.roughness = 1.0
	m.metallic_specular = 0.05
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	pm.material = m
	mi.mesh = pm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(-40.0, 0.006, -262.0)


# Горы по кругу не зависят от тумана и закрывают пустой горизонт одной дешёвой сеткой
func _build_mountains() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 1994
	noise.frequency = 0.9
	noise.fractal_octaves = 4
	var center := Vector3(-40.0, -4.0, -262.0)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for layer in range(2):
		var radius := 210.0 + layer * 70.0
		var base_h := 46.0 + layer * 30.0
		var low := Color(0.016, 0.021, 0.033) if layer == 0 else Color(0.02, 0.026, 0.041)
		var high := Color(0.01, 0.013, 0.022) if layer == 0 else Color(0.014, 0.018, 0.03)
		var v := PackedVector3Array()
		var col := PackedColorArray()
		var count := 128
		for i in range(count):
			var a0 := TAU * i / count
			var a1 := TAU * (i + 1) / count
			var h0 := base_h * (0.55 + 0.75 * absf(noise.get_noise_2d(cos(a0) * 5.0 + layer * 9.0, sin(a0) * 5.0)))
			var h1 := base_h * (0.55 + 0.75 * absf(noise.get_noise_2d(cos(a1) * 5.0 + layer * 9.0, sin(a1) * 5.0)))
			var b0 := Vector3(cos(a0) * radius, 0.0, sin(a0) * radius)
			var b1 := Vector3(cos(a1) * radius, 0.0, sin(a1) * radius)
			var t0 := b0 + Vector3.UP * h0
			var t1 := b1 + Vector3.UP * h1
			for p in [b0, t0, t1, b0, t1, b1]:
				v.append(p)
				col.append(high if p.y > 1.0 else low)
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_COLOR] = col
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, m)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2000.0
		mi.ignore_occlusion_culling = true
		add_child(mi)
		mi.global_position = center


# Видимая граница: старая ограда из столбов и жердей, за ней сразу плотный лес
func _build_boundaries() -> void:
	var fence := NatureKit.Geo.new()
	var span := 2.6
	fence.box(Transform3D(Basis(), Vector3(0.0, 0.7, 0.0)), Vector3(0.13, 1.4, 0.13), Color(0.8, 0.8, 0.8))
	for y in [0.48, 0.98]:
		fence.box(Transform3D(Basis(Vector3.BACK, 0.03), Vector3(span * 0.5, y, 0.0)), Vector3(span + 0.1, 0.09, 0.045), Color.WHITE)
	var mesh := ArrayMesh.new()
	fence.commit(mesh, HouseKit.wood_mat("board_weathered.png", Color(0.62, 0.58, 0.52), 1.5))
	var xforms: Array[Transform3D] = []
	for seg in _map.get("boundary", []):
		var a := Vector3(float(seg[0]), 0.0, float(seg[1]))
		var b := Vector3(float(seg[2]), 0.0, float(seg[3]))
		_segments.append([a, b])
		var ln := a.distance_to(b)
		var dir := (b - a) / ln
		var yaw := atan2(-dir.z, dir.x)
		var body_pos := (a + b) * 0.5 + Vector3.UP * 8.0
		var wall := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(ln, 16.0, 0.6)
		col.shape = box
		wall.add_child(col)
		add_child(wall)
		wall.global_position = body_pos
		wall.rotation.y = yaw
		if bool(seg[4]):
			var count := int(ln / span)
			for i in range(count):
				var p := a + dir * (span * i)
				if absf(p.x) < 7.0 or absf(p.x + span * dir.x) < 7.0:
					continue
				var tilt := sin(float(i) * 12.9) * 0.05
				var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
				xforms.append(Transform3D(basis, p))
	if not xforms.is_empty():
		var mm := NatureKit._multimesh_of(mesh, xforms)
		mm.name = "BoundaryFence"
		mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(mm)


# Тропа: мягкая лента вытоптанной земли с неровным краем, который растворяется в траве
func _build_trails() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = HouseKit.tex("dirt_path.png")
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.metallic_specular = 0.05
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.18
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var across := [-1.45, -0.72, 0.0, 0.72, 1.45]
	var alpha := [0.0, 0.95, 1.0, 0.95, 0.0]
	for trail in _map.get("trails", []):
		var pts: Array = trail[0]
		var width: float = float(trail[1]) * 0.5
		var curve := Curve2D.new()
		for i in range(pts.size()):
			var p := Vector2(float(pts[i][0]), float(pts[i][1]))
			var tangent := Vector2.ZERO
			if i > 0 and i < pts.size() - 1:
				tangent = (Vector2(float(pts[i + 1][0]), float(pts[i + 1][1])) - Vector2(float(pts[i - 1][0]), float(pts[i - 1][1]))) * 0.22
			curve.add_point(p, -tangent, tangent)
		curve.bake_interval = 0.8
		var baked := curve.get_baked_points()
		var dist := 0.0
		var start := v.size()
		for i in range(baked.size()):
			var cur: Vector2 = baked[i]
			var nxt: Vector2 = baked[mini(i + 1, baked.size() - 1)]
			var prev: Vector2 = baked[maxi(i - 1, 0)]
			var fwd := (nxt - prev).normalized()
			if i > 0:
				dist += cur.distance_to(prev)
			var side := Vector2(-fwd.y, fwd.x)
			var w := width * (1.0 + noise.get_noise_2d(dist, 3.0) * 0.45)
			var end_fade := minf(1.0, minf(float(i), float(baked.size() - 1 - i)) / 3.0)
			for k in range(across.size()):
				var off: float = float(across[k]) * w + noise.get_noise_2d(dist * 1.4, float(k) * 9.0) * 0.28
				var pos: Vector2 = cur + side * off
				v.append(Vector3(pos.x, 0.022, pos.y))
				n.append(Vector3.UP)
				uv.append(pos * 0.24)
				col.append(Color(1, 1, 1, alpha[k] * end_fade))
			if i > 0:
				var row := start + (i - 1) * across.size()
				for k in range(across.size() - 1):
					idx.append_array([row + k, row + k + across.size(), row + k + 1, row + k + 1, row + k + across.size(), row + k + across.size() + 1])
	if v.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = n
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.name = "Trails"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


# Трава пучками только рядом с игроком: дальше её всё равно съедает темнота
func _build_grass() -> void:
	var tuft := TextureHelper.get_texture("res://assets/textures/nature/grass_tuft.png")
	if tuft == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_texture = tuft
	m.albedo_color = Color(0.55, 0.62, 0.42)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	var g := NatureKit.Geo.new()
	for a in [0.0, 1.05, 2.1]:
		var d := Vector3(cos(a), 0.0, sin(a)) * 0.45
		var nor := Vector3.UP
		g.vert(-d, nor, Color.WHITE, Vector2(0, 1))
		g.vert(-d + Vector3.UP * 0.5, nor, Color.WHITE, Vector2(0, 0))
		g.vert(d + Vector3.UP * 0.5, nor, Color.WHITE, Vector2(1, 0))
		g.vert(-d, nor, Color.WHITE, Vector2(0, 1))
		g.vert(d + Vector3.UP * 0.5, nor, Color.WHITE, Vector2(1, 0))
		g.vert(d, nor, Color.WHITE, Vector2(1, 1))
	var mesh := ArrayMesh.new()
	g.commit(mesh, m)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var cells: Dictionary = {}
	for i in range(2600):
		var x := rng.randf_range(-96.0, 16.0)
		var z := rng.randf_range(-324.0, -200.0)
		if absf(x) < 5.8 or (x > -71.5 and x < -49.5 and z > -231.5 and z < -218.5) or (x > -53.5 and x < -40.5 and z > -213.5 and z < -203.5):
			continue
		if x < -78.0 and z < -262.0:
			continue
		if x > 10.0 and z < -262.0:
			continue
		var sc := rng.randf_range(0.7, 1.35)
		var cell := Vector2i(int(floor(x / 24.0)), int(floor(z / 24.0)))
		if not cells.has(cell):
			cells[cell] = []
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(x, 0.0, z))
		cells[cell].append(xf)
	for cell in cells:
		var xforms: Array[Transform3D] = []
		xforms.assign(cells[cell])
		var mm := NatureKit._multimesh_of(mesh, xforms)
		mm.visibility_range_end = 30.0
		mm.visibility_range_end_margin = 3.0
		mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		add_child(mm)


# Ключ и лом лежат на месте, а не парят
func _set_items_still() -> void:
	for n in get_parent().get_children():
		if n is Area3D and n.has_meta("item_type"):
			var t := str(n.get_meta("item_type"))
			if t == "key":
				n.set_meta("rest_still", true)
				n.rotation_degrees = Vector3(0.0, 35.0, 0.0)


func _invisible_wall(pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	body.add_child(col)
	add_child(body)
	body.global_position = pos


func _build_crash_effects() -> void:
	_steam = CPUParticles3D.new()
	_steam.amount = 26
	_steam.lifetime = 2.4
	_steam.direction = Vector3.UP
	_steam.spread = 16.0
	_steam.gravity = Vector3(0.25, 0.5, 0.0)
	_steam.initial_velocity_min = 0.7
	_steam.initial_velocity_max = 1.5
	_steam.scale_amount_min = 0.5
	_steam.scale_amount_max = 1.3
	_steam.color = Color(0.7, 0.72, 0.76, 0.1)
	var puff := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = grad
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(1.0, 0.5)
	puff.width = 48
	puff.height = 48
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = puff
	var quad := QuadMesh.new()
	quad.size = Vector2(1.2, 1.2)
	quad.material = mat
	_steam.mesh = quad
	add_child(_steam)
	_steam.global_position = WRECK_POS + Vector3(-1.2, 1.0, -1.7)

	# Уцелевшая фара упирается в валун и мигает
	_car_light = SpotLight3D.new()
	_car_light.light_color = Color(1.0, 0.92, 0.72)
	_car_light.light_energy = 5.0
	_car_light.spot_range = 13.0
	_car_light.spot_angle = 32.0
	add_child(_car_light)
	_car_light.global_position = WRECK_POS + Vector3(-0.2, 0.75, -2.0)
	_car_light.look_at(WRECK_POS + Vector3(-3.5, 0.5, -8.0), Vector3.UP)

	# Фонарь через дорогу от аварии мигает, как в кат-сцене
	var flick := SpotLight3D.new()
	flick.light_color = Color(1.0, 0.66, 0.38)
	flick.light_energy = 2.2
	flick.spot_range = 12.0
	flick.spot_angle = 62.0
	flick.spot_attenuation = 1.25
	flick.rotation_degrees.x = -90.0
	add_child(flick)
	flick.global_position = Vector3(-3.9, 6.6, -260.0)
	_flicker_lights.append(flick)


# Свет всегда идёт от видимой лампы, свечи или телевизора
func _build_house_lights() -> void:
	_tv_light = OmniLight3D.new()
	_tv_light.light_color = Color(0.45, 0.62, 1.0)
	_tv_light.light_energy = 1.4
	_tv_light.omni_range = 6.0
	add_child(_tv_light)
	_tv_light.global_position = Vector3(-69.5, 4.75, -226.3)

	# Отсвет телевизора в щели окна второго этажа виден с дороги
	var strip_mat := StandardMaterial3D.new()
	strip_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	strip_mat.albedo_color = Color(0.3, 0.42, 0.72)
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.006, 1.2, 1.2)
	strip_mesh.material = strip_mat
	_tv_strip = MeshInstance3D.new()
	_tv_strip.mesh = strip_mesh
	add_child(_tv_strip)
	_tv_strip.global_position = Vector3(-52.838, 5.0, -228.0)
	var yard := OmniLight3D.new()
	yard.light_color = Color(0.5, 0.62, 1.0)
	yard.light_energy = 0.9
	yard.omni_range = 8.0
	add_child(yard)
	yard.global_position = Vector3(-51.4, 5.0, -228.0)
	_flicker_lights.append(yard)

	# Висячие лампы: часть включена, часть мертва
	_ceiling_lamp(Vector3(-54.0, 3.28, -222.0), true, 0.75)
	_ceiling_lamp(Vector3(-65.0, 3.28, -222.0), false, 0.0)
	_ceiling_lamp(Vector3(-62.0, 3.28, -228.0), true, 0.55)
	_ceiling_lamp(Vector3(-68.0, 3.28, -228.0), false, 0.0)
	_ceiling_lamp(Vector3(-54.0, 6.72, -224.0), true, 0.6)
	_ceiling_lamp(Vector3(-65.0, 6.72, -222.0), false, 0.0)
	_ceiling_lamp(Vector3(-66.0, 6.72, -228.0), false, 0.0)
	_ceiling_lamp(Vector3(-47.0, 3.04, -208.5), true, 1.5)
	# Фонарь у входа подсказывает, куда идти
	_ceiling_lamp(Vector3(-51.3, 2.98, -225.0), true, 1.1)
	# Свеча на столе в гостиной
	_candle = _add_candle(Vector3(-65.6, 0.72, -222.3))

	# Записки: одна в прихожей, вторая на столе Сэма
	_add_note(Vector3(-53.5, 1.03, -230.0), NOTE_HALL)
	_add_note(Vector3(-65.5, 4.30, -230.3), NOTE_SAM)


func _ceiling_lamp(top: Vector3, on: bool, energy: float) -> void:
	var cord := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.008
	cm.bottom_radius = 0.008
	cm.height = 0.34
	cm.radial_segments = 6
	cm.rings = 1
	cm.material = HouseKit.metal_mat(Color(0.05, 0.05, 0.05), 0.7)
	cord.mesh = cm
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cord)
	cord.global_position = top - Vector3.UP * 0.17
	var shade := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = 0.2
	sm.height = 0.13
	sm.radial_segments = 14
	sm.rings = 1
	sm.material = HouseKit.metal_mat(Color(0.2, 0.19, 0.14), 0.6)
	shade.mesh = sm
	shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shade)
	shade.global_position = top - Vector3.UP * 0.4
	var bulb := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.042
	bm.height = 0.084
	bm.radial_segments = 10
	bm.rings = 6
	var mat := StandardMaterial3D.new()
	if on:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.82, 0.55)
	else:
		mat.albedo_color = Color(0.2, 0.19, 0.17)
		mat.roughness = 0.3
	bm.material = mat
	bulb.mesh = bm
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bulb)
	bulb.global_position = top - Vector3.UP * 0.47
	if not on:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.72, 0.45)
	l.light_energy = energy
	l.omni_range = 6.5
	l.omni_attenuation = 1.3
	add_child(l)
	l.global_position = top - Vector3.UP * 0.55
	_house_lights.append(l)
	_house_lights.append(bulb)


func _add_candle(pos: Vector3) -> OmniLight3D:
	var wax := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.022
	wm.bottom_radius = 0.026
	wm.height = 0.13
	wm.radial_segments = 8
	wm.rings = 1
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.72, 0.68, 0.56)
	wm.material = wmat
	wax.mesh = wm
	wax.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wax)
	wax.global_position = pos + Vector3.UP * 0.065
	var fl := MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.016
	fm.height = 0.05
	fm.radial_segments = 8
	fm.rings = 4
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color(1.0, 0.7, 0.28)
	fm.material = fmat
	fl.mesh = fm
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fl)
	fl.global_position = pos + Vector3.UP * 0.155
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.28)
	l.light_energy = 1.0
	l.omni_range = 4.5
	add_child(l)
	l.global_position = pos + Vector3.UP * 0.2
	return l


func _add_forest_tree(chunks: Dictionary, pos: Vector3, sz: Vector3, yaw: float) -> void:
	var key := [int(floor(pos.x / 30.0)), int(floor(pos.z / 30.0)), sz.y > 10.0]
	if not chunks.has(key):
		chunks[key] = []
	chunks[key].append([pos, sz, yaw])


# Текстуры полов и тёмные торцы крыш
func _dress_house() -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_texture = HouseKit.tex("board_weathered.png")
	dark.albedo_color = Color(0.3, 0.27, 0.24)
	dark.uv1_triplanar = true
	dark.uv1_scale = Vector3.ONE * 0.5
	dark.roughness = 1.0
	var main := get_parent()
	for node in main.find_children("*", "MeshInstance3D", true, false):
		if node.mesh is PrismMesh:
			var p: Vector3 = node.global_position
			if p.x > -75.0 and p.x < -38.0 and p.z > -235.0 and p.z < -200.0:
				node.material_override = dark
	for node in main.find_children("floor_custom_*", "Node3D", true, false):
		var p: Vector3 = node.global_position
		if absf(p.x + 62.0) < 10.0 and absf(p.z + 225.0) < 7.0:
			TextureHelper.apply_wall_texture_to_node(node, "wood_planks", Color(0.5, 0.38, 0.28))
	for node in main.find_children("ceiling_custom_*", "Node3D", true, false):
		var p: Vector3 = node.global_position
		if absf(p.x + 56.0) < 18.0 and absf(p.z + 217.0) < 16.0:
			TextureHelper.apply_wall_texture_to_node(node, "plaster", Color(0.5, 0.48, 0.44))


# Лес рисуется участками 30 x 30 м: деревьев много, а объектов отрисовки единицы.
# Столкновения только у елей внутри зоны, за оградой туда не пройти.
func _build_forest() -> void:
	var chunks: Dictionary = {}
	var solid: Dictionary = {}
	for t in get_parent().get("highway_trees"):
		var pos: Vector3 = t[0]
		pos.y = 0.0
		_add_forest_tree(chunks, pos, t[1], float(t[2]))
		if t[3]:
			var cell := Vector2i(int(floor(pos.x / 30.0)), int(floor(pos.z / 30.0)))
			if not solid.has(cell):
				solid[cell] = []
			solid[cell].append(pos)
	for key in chunks:
		NatureKit.add_spruce_chunk(self, chunks[key], key[2], posmod(key[0] + key[1], 3), Color.WHITE, 30.0, 95.0)
	var shape := CylinderShape3D.new()
	shape.radius = 0.38
	shape.height = 6.0
	for cell in solid:
		var body := StaticBody3D.new()
		add_child(body)
		for p in solid[cell]:
			var col := CollisionShape3D.new()
			col.shape = shape
			body.add_child(col)
			col.global_position = p + Vector3.UP * 3.0


func _add_note(pos: Vector3, text: String) -> void:
	var area := Area3D.new()
	area.set_script(load("res://scripts/Item.gd"))
	area.set_meta("item_type", "note")
	area.set_meta("note_text", text)
	add_child(area)
	area.global_position = pos


# Камера Сэма на ели у обочины: голый ствол, чтобы лапы не закрывали корпус
func _build_camera04() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.27
	trunk_mesh.bottom_radius = 0.31
	trunk_mesh.height = 3.6
	trunk_mesh.radial_segments = 10
	trunk_mesh.rings = 1
	trunk_mesh.material = NatureKit._bark_mat()
	var trunk := StaticBody3D.new()
	var trunk_mi := MeshInstance3D.new()
	trunk_mi.mesh = trunk_mesh
	trunk.add_child(trunk_mi)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 3.6
	col.shape = shape
	trunk.add_child(col)
	add_child(trunk)
	trunk.global_position = CAMERA_POS + Vector3.UP * 1.8
	NatureKit.add_spruce_chunk(self, [[CAMERA_POS + Vector3.UP * 2.7, Vector3(6.5, 13.0, 6.5), 0.6]], true, 0, Color.WHITE, 60.0, 95.0)

	var cam := Node3D.new()
	add_child(cam)
	cam.global_position = CAMERA_POS + Vector3(0.36, 1.5, 0.0)
	cam.rotation_degrees.y = 0.0
	var case_mat := StandardMaterial3D.new()
	case_mat.albedo_color = Color(0.16, 0.17, 0.14)
	case_mat.roughness = 0.8
	var case_mesh := BoxMesh.new()
	case_mesh.size = Vector3(0.16, 0.34, 0.24)
	case_mesh.material = case_mat
	var case_mi := MeshInstance3D.new()
	case_mi.mesh = case_mesh
	cam.add_child(case_mi)
	var number := Label3D.new()
	number.text = "04"
	number.font_size = 40
	number.pixel_size = 0.004
	number.outline_size = 8
	number.modulate = Color(0.92, 0.93, 0.88)
	number.position = Vector3(0.085, -0.08, 0.0)
	number.rotation_degrees.y = 90.0
	cam.add_child(number)
	var led_mat := StandardMaterial3D.new()
	led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led_mat.albedo_color = Color(1.0, 0.08, 0.05)
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.016
	led_mesh.height = 0.032
	led_mesh.radial_segments = 8
	led_mesh.rings = 4
	led_mesh.material = led_mat
	_cam_led = MeshInstance3D.new()
	_cam_led.mesh = led_mesh
	_cam_led.position = Vector3(0.085, 0.12, 0.07)
	cam.add_child(_cam_led)
	_led_light = OmniLight3D.new()
	_led_light.light_color = Color(1.0, 0.1, 0.06)
	_led_light.light_energy = 0.7
	_led_light.omni_range = 2.4
	_led_light.position = Vector3(0.2, 0.12, 0.07)
	cam.add_child(_led_light)


# ─── События ──────────────────────────────────────────────────────────────────

func _run_start() -> void:
	while not is_instance_valid(GameManager.player_ref) or not GameManager.player_ref.is_inside_tree():
		await get_tree().process_frame
	_player = GameManager.player_ref
	_head = _player.get("head")
	_player.set("is_in_cutscene", true)
	# Итан смотрит на разбитый пикап, голова кружится
	_player.rotation.y = atan2(_player.global_position.x - WRECK_POS.x, _player.global_position.z - WRECK_POS.z)
	_head.position.y = 0.7
	_head.rotation.z = 0.25
	_horn = _sound_at("res://assets/audio/car_horn.wav", WRECK_POS + Vector3.UP, -3.0, 0.96, true)
	_steam_audio = _sound_at("res://assets/audio/car_steam.wav", WRECK_POS + Vector3.UP, -6.0, 1.0, true)
	var amb := _sound("res://assets/ambient_night.mp3", -18.0)
	if amb:
		amb.finished.disconnect(amb.queue_free)
		amb.finished.connect(amb.play)
	await get_tree().create_timer(0.3, false).timeout
	var tw := create_tween().set_parallel()
	tw.tween_property(_black, "color:a", 0.0, 1.8)
	tw.tween_property(_head, "position:y", 1.62, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_head, "rotation:z", 0.0, 2.4).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_head.rotation = Vector3.ZERO
	_player.set("is_in_cutscene", false)
	_say("ИТАН", "…Сэм?", 2.0)


func _process(delta: float) -> void:
	_t += delta
	_boundary_cd = maxf(0.0, _boundary_cd - delta)
	_update_flicker()
	if is_instance_valid(_player):
		_update_interior(_player.global_position)
	if _ending or not is_instance_valid(_player) or _player.get("is_in_cutscene") == true:
		return
	var pos := _player.global_position
	_update_story(pos)
	_update_boundary_hints(pos)


func _update_flicker() -> void:
	var off := sin(_t * 13.0) * cos(_t * 7.3) > 0.55
	if is_instance_valid(_car_light):
		_car_light.light_energy = 0.8 if sin(_t * 23.0) < -0.85 else 5.0
	if _flicker_lights.size() > 0 and is_instance_valid(_flicker_lights[0]):
		_flicker_lights[0].light_energy = 0.15 if off else 2.2
	if is_instance_valid(_tv_light) and _tv_light.visible:
		var n := 0.75 + 0.5 * sin(_t * 31.0) * cos(_t * 17.0)
		_tv_light.light_energy = 1.8 * n
		if _flicker_lights.size() > 1:
			_flicker_lights[1].light_energy = 1.1 * n
	if is_instance_valid(_candle):
		_candle.light_energy = 1.0 + 0.18 * sin(_t * 11.0) + 0.1 * sin(_t * 27.0)
	var led_on := fmod(_t, 1.0) < 0.5
	if is_instance_valid(_cam_led):
		_cam_led.visible = led_on
		_led_light.visible = led_on


func _update_story(pos: Vector3) -> void:
	# Сигнал смолкает сам собой, и в тишине лес зовёт по имени
	if _t > 8.0 and _once("horn_stop"):
		if is_instance_valid(_horn):
			_horn.finished.disconnect(_horn.play)
			_horn.stop()
			_horn.queue_free()
	if _t > 10.0 and _once("voice_1"):
		_say("ГОЛОС ИЗ ЛЕСА", "«Итан!.. Итан, я здесь!»", 3.0)
	if _t > 16.0 and _once("thought_1"):
		_say("ИТАН", "Это голос Сэма. Вон там тропа и свет в окне.", 3.2)

	if pos.x < -20.0 and _once("voice_2"):
		_say("ГОЛОС ИЗ ДОМА", "«Сюда… Иди ко мне, Итан».", 2.8)
	if pos.x > -52.6 and pos.x < -49.0 and absf(pos.z + 225.0) < 3.8 and _once("porch"):
		if not GameManager.has_crowbar:
			_say("ИТАН", "Дверь заколочена. Нужен лом… В гараже горит свет.", 3.4)

	# В доме
	var inside := pos.x > -71.0 and pos.x < -53.0 and pos.z > -231.0 and pos.z < -219.0
	if inside and _once("inside"):
		_say("ИТАН", "Сэм?! Это я!", 2.0)
	if inside and pos.y > 2.8 and _once("upstairs"):
		_sound_at("res://assets/audio/tv_static.wav", Vector3(-70.3, 4.6, -226.3), -8.0, 0.8, true)

	# Ключ наверху: дом вырубается, а голос теперь звучит прямо за стеной
	if GameManager.has_key_id(1) and _once("key_taken"):
		_on_key_taken()

	if pos.z < -264.0 and _once("past_gate"):
		_say("ГОЛОС ИЗ ЛЕСА", "«Итан!.. Не бойся, иди по тропе».", 3.0)
	if pos.z < -283.0 and _once("figure"):
		_flash_figure()

	if pos.z < -300.0 and Vector2(pos.x - CAMERA_POS.x, pos.z - CAMERA_POS.z).length() < 4.2 and _once("ending"):
		_run_ending()


func _update_boundary_hints(pos: Vector3) -> void:
	if _boundary_cd > 0.0:
		return
	if absf(pos.x) < 12.0 and pos.z < -261.0 and pos.z > -266.0:
		_say("ИТАН", "Дорогу завалило, здесь не пройти.", 2.4)
		_boundary_cd = 8.0
		return
	var p2 := Vector2(pos.x, pos.z)
	for seg in _segments:
		var a := Vector2(seg[0].x, seg[0].z)
		var b := Vector2(seg[1].x, seg[1].z)
		if Geometry2D.get_closest_point_to_segment(p2, a, b).distance_to(p2) < 2.0:
			_say("ИТАН", "Туда нельзя. Сэм где-то рядом с домом.", 2.4)
			_boundary_cd = 8.0
			return


func _on_key_taken() -> void:
	_tv_light.visible = false
	_tv_strip.visible = false
	_interior.erase(_tv_light)
	for n in _house_lights:
		if is_instance_valid(n):
			n.visible = false
			_interior.erase(n)
	if _flicker_lights.size() > 1:
		_flicker_lights[1].visible = false
	_sound("res://assets/audio/monster/basement_door_open.wav", -8.0, 0.8)
	await get_tree().create_timer(1.4, false).timeout
	_say("ШЁПОТ", "«Ты нашёл ключ, Итан. Калитка за домом».", 3.2)
	await get_tree().create_timer(4.2, false).timeout
	_say("ИТАН", "Сэм так никогда не говорил.", 2.6)


# Красные глаза между стволами: появились и пропали
func _flash_eyes(at: Vector3) -> void:
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = at
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.1, 0.05)
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = mat
	for s in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = mesh
		eye.position = Vector3(0.0, 0.0, s * 0.09)
		holder.add_child(eye)
	await get_tree().create_timer(1.1, false).timeout
	holder.queue_free()


# Силуэт переходит тропу вдали и исчезает в темноте
func _flash_figure() -> void:
	var figure := SkinwalkerModel.new()
	get_tree().current_scene.add_child(figure)
	var from := Vector3(-36.0, 0.0, -300.0)
	var to := Vector3(-22.0, 0.0, -292.0)
	figure.global_position = from
	figure.look_at(to, Vector3.UP, true)
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.68, 1.0)
	light.light_energy = 3.0
	light.omni_range = 8.0
	figure.add_child(light)
	light.position = Vector3(0.0, 3.0, 2.0)
	var tw := create_tween()
	tw.tween_property(figure, "global_position", to, 2.2)
	await tw.finished
	figure.queue_free()


func _run_ending() -> void:
	_ending = true
	_player.set("is_in_cutscene", true)
	_player.velocity = Vector3.ZERO
	# Итан подходит взглядом к камере
	var to_cam := CAMERA_POS + Vector3(0.36, 1.5, 0.0) - _head.global_position
	var yaw := atan2(-to_cam.x, -to_cam.z)
	var tw := create_tween().set_parallel()
	tw.tween_property(_player, "rotation:y", _player.rotation.y + wrapf(yaw - _player.rotation.y, -PI, PI), 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_head, "rotation:x", 0.0, 0.6)
	await tw.finished
	_say("ИТАН", "«04»… Это камера Сэма.", 2.2)
	await get_tree().create_timer(2.4, false).timeout

	# Спотыкается о край асфальта: фонарик улетает, камера у земли
	_sound("res://assets/audio/player_step.wav", 0.0, 0.55)
	_drop_flashlight()
	var fall := create_tween().set_parallel()
	fall.tween_property(_head, "position:y", 0.55, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_head, "rotation:z", deg_to_rad(10.0), 0.42)
	await fall.finished
	_heart = AudioStreamPlayer.new()
	_heart.stream = load("res://assets/heart.mp3")
	_heart.volume_db = -8.0
	add_child(_heart)
	_heart.finished.connect(_heart.play)
	_heart.play()
	await get_tree().create_timer(0.7, false).timeout
	var ahead := -_player.global_transform.basis.z
	_flash_eyes(_player.global_position + ahead * 11.0 + Vector3.UP * 1.8)
	await get_tree().create_timer(1.4, false).timeout

	_sound("res://assets/creepy_whisper.mp3", 0.0, 0.92)
	_say("ШЁПОТ ЗА СПИНОЙ", "«Итан… обернись. Посмотри на меня».", 2.4)
	await get_tree().create_timer(1.6, false).timeout
	var warn := create_tween()
	warn.tween_property(_warn, "modulate:a", 1.0, 0.08)
	warn.tween_interval(1.2)
	warn.tween_property(_warn, "modulate:a", 0.0, 0.3)
	# Дальше решает игрок: можно терпеть, но недолго
	_turn_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var waited := 0.0
	while _turn_active and waited < 8.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if _turn_active:
		_turn_active = false
		_say("ИТАН", "…", 0.6)
		var auto := create_tween()
		auto.tween_property(_player, "rotation:y", _player.rotation.y + PI, 0.55).set_trans(Tween.TRANS_SINE)
		await auto.finished
	_start_scare()


func _input(event: InputEvent) -> void:
	if _turn_active and event is InputEventMouseMotion:
		var dx: float = event.relative.x * LOOK_SENS
		_player.rotation.y -= dx
		_turned += dx
		if absf(_turned) > 1.5:
			_turn_active = false


func _drop_flashlight() -> void:
	var hands = _player.get("player_hands")
	if hands and hands.has_method("set_flashlight_state"):
		hands.call("set_flashlight_state", false, 0.0)
	var fl = _player.get("flashlight")
	if fl:
		fl.visible = false
	_player.set("flashlight_on", false)
	var fwd := -_player.global_transform.basis.z
	var side := _player.global_transform.basis.x
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.93, 0.78)
	beam.light_energy = 3.0
	beam.spot_range = 16.0
	beam.spot_angle = 30.0
	add_child(beam)
	var at := _player.global_position + fwd * 1.6 + side * 0.5
	at.y = 0.1
	beam.global_position = at
	beam.look_at(at + fwd * 8.0 + Vector3.UP * 1.2, Vector3.UP)


func _start_scare() -> void:
	_warn.modulate.a = 0.0
	if is_instance_valid(_heart):
		_heart.finished.disconnect(_heart.play)
		_heart.stop()
	if is_instance_valid(_steam_audio):
		_steam_audio.finished.disconnect(_steam_audio.play)
		_steam_audio.stop()
	var scare := SkinwalkerScare.new()
	add_child(scare)
	scare.finished.connect(_finish)


func _finish() -> void:
	GameManager.start_level_transition(NEXT_MAP, false)
