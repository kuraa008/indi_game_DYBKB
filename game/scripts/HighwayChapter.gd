class_name HighwayChapter
extends Node3D

# Глава 1 «Возвращение домой» на карте «Шоссе», по сюжету Досыма.
# Итан приходит в себя у разбитой машины и идёт к дому отца. На двери полицейская лента,
# он зовёт в темноту. Комната отца: пустая кровать и улики. Комната Сэма, «наше место»
# с надписью кровью. Копыта: выключить фонарик и затаиться в углу. Тихий побег, гараж,
# выглянуть из-за угла, дойти до другого угла — кат-сцена Jan-ky Ch1Corner и подвал.

const WRECK_POS := Vector3(-7.2, 0.0, -247.1)
const WRECK_ROT := Vector3(-4.0, 34.0, 3.0)    # поворот «Машины Итана» на карте — та же поза, что во вступлении
const HOUSE_DIR_POS := Vector3(-60.0, 2.0, -225.0)
const BASEMENT_WAKE := Vector3(-58.0, -4.15, -227.5)   # пол подвала под домом, глава 2
const BASEMENT_LOOK := Vector3(-54.4, -4.15, -221.0)   # взгляд на лестницу к двери
const FOG_COLOR := Color(0.062, 0.082, 0.125)


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
var _steam: CPUParticles3D
var _car_light: SpotLight3D
var _ethan_car: Node
var _flicker_lights: Array[Light3D] = []
var _tv_light: OmniLight3D
var _tv_strip: MeshInstance3D
var _ending := false
var _boundary_cd := 0.0
var _interior: Array = []
var _interior_on := true
var _basement: Array = []
var _basement_on := true
var _basement_mode := false
var _missions: MissionTracker
var _doors: Dictionary = {}
var _map: Dictionary = {}
var _segments: Array = []
var _house_lights: Array[Node3D] = []
var _candle: OmniLight3D

# Глава 1
const StorySpot := preload("res://scripts/StorySpot.gd")
const FRONT_DOOR := Vector3(-53.0, 0.16, -225.0)
const SAM_DOOR := Vector3(-59.0, 3.48, -228.0)
const SAM_WARDROBE := Vector3(-70.48, 3.48, -229.85)   # шкаф в углу комнаты Сэма: в нём Итан прячется от существа
const GARAGE_PEEK := Vector3(-53.6, 0.2, -204.6)
const CREATURE_WAIT := Vector3(-46.5, 0.0, -199.6)
const FATHER_LINE := "Прости меня, пап… Я обещал, что буду приезжать. Каждый раз говорил себе: в следующие выходные. А потом перестал даже звонить. Ты ждал меня, а я так и не приехал. Теперь мне некому сказать «прости»."
const SAM_LINE := "Эх, брат… Ты остался здесь один, а я сбежал. Ты взял всё на себя, а я даже не спросил, как ты. Где же ты, Сэм?.."
const RULES := "Увидишь чёрного оленя — не останавливайся.\nПозовут по имени — не отзывайся.\nИдёт следом — не оборачивайся."
var _clues := 0
var _hide_watch := false
var _caught := false
var _creature: Node3D
var _creature_gait := "idle"
var _creature_speed := 0.0
var _spots: Array = []


func _ready() -> void:
	name = "HighwayChapter"
	_basement_mode = GameManager.wake_in_basement
	GameManager.wake_in_basement = false
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
	_dress_house()
	preload("res://scripts/HouseStory.gd").build(self)
	_build_chapter_props()
	_build_forest()
	_build_grass()
	_set_items_still()
	_open_front_door.call_deferred()
	_setup_interior()
	_setup_missions()
	if _basement_mode:
		_run_basement_wake()
	else:
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


func _wreck_xform() -> Transform3D:
	return Transform3D(Basis.from_euler(WRECK_ROT * (PI / 180.0)), WRECK_POS + Vector3(0.0, 0.05, 0.0))


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
			# Подвал под домом (глава 2) живёт отдельно: его видно только из самого подвала
			if p.y < -0.3 and p.x > -71.6 and p.x < -42.6 and p.z > -243.8 and p.z < -216.0:
				_basement.append(n)
			elif p.x > -70.9 and p.x < -53.1 and p.z > -230.9 and p.z < -219.1 and p.y < 6.7:
				_interior.append(n)
	_build_exit_hatch()
	_set_interior(false)
	_set_basement(false)


# Выход из подвала: люк в потолке комнатки за дверью наверху лестницы, к нему ведут скобы,
# а выбирается Итан во двор за домом, у такого же люка в земле
const EXIT_HATCH := Vector3(-58.0, 0.0, -232.1)        # люк во дворе за задней стеной
const EXIT_HATCH_INSIDE := Vector3(-54.4, -0.78, -217.7)  # люк в потолке комнатки за дверью


func _build_exit_hatch() -> void:
	var hatch: StaticBody3D = preload("res://scripts/BasementExitHatch.gd").new()
	hatch.name = "BasementExitHatch"
	add_child(hatch)
	hatch.global_position = EXIT_HATCH_INSIDE
	_basement.append(hatch)
	var wood := StandardMaterial3D.new()
	if ResourceLoader.exists("res://assets/textures/wood_planks.png"):
		wood.albedo_texture = load("res://assets/textures/wood_planks.png")
	wood.albedo_color = Color(0.32, 0.24, 0.17)
	wood.roughness = 0.95
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.12, 0.11, 0.1)
	iron.roughness = 0.7
	iron.metallic = 0.6
	var top := Node3D.new()
	top.name = "YardHatch"
	add_child(top)
	top.global_position = EXIT_HATCH
	for part in [[Vector3(1.1, 0.05, 1.1), Vector3(0, 0.025, 0), iron], [Vector3(0.9, 0.04, 0.9), Vector3(0, 0.06, 0), wood],
			[Vector3(0.06, 0.03, 0.5), Vector3(0.2, 0.09, 0), iron], [Vector3(0.06, 0.03, 0.5), Vector3(-0.2, 0.09, 0), iron]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		bm.material = part[2]
		mi.mesh = bm
		mi.position = part[1]
		top.add_child(mi)


func _set_interior(on: bool) -> void:
	_interior_on = on
	for n in _interior:
		if is_instance_valid(n):
			n.visible = on


func _set_basement(on: bool) -> void:
	_basement_on = on
	for n in _basement:
		if is_instance_valid(n):
			n.visible = on


func _update_interior(pos: Vector3) -> void:
	var below := pos.y < -0.8
	var inside := pos.x > -71.0 and pos.x < -53.0 and pos.z > -231.0 and pos.z < -219.0
	var at_door := Vector2(pos.x + 53.0, pos.z + 225.0).length() < 9.0 and _door_flag(-53.0, -225.0, "is_open")
	var want := (inside or at_door) and not below
	if want != _interior_on:
		_set_interior(want)
	if below != _basement_on:
		_set_basement(below)


func _setup_missions() -> void:
	_missions = MissionTracker.new()
	if _basement_mode:
		_missions.setup([
			{"text": "Выберись из подвала", "done": func(): return _pl_pos().y > -0.5},
		])
		add_child(_missions)
		return
	_missions.setup([
		{"text": "Дойди до дома отца", "done": func(): return _done.has("porch")},
		{"text": "Позови у двери", "done": func(): return _done.has("called")},
		{"text": "Поднимись в комнату отца", "done": func(): return _done.has("father")},
		{"text": "Зайди в комнату Сэма", "done": func(): return _done.has("sam")},
		{"text": "Найди ваше с Сэмом место", "done": func(): return _done.has("names")},
		{"text": "Спрячься в шкаф в комнате Сэма", "done": func(): return _done.has("hidden")},
		{"text": "Не шевелись", "done": func(): return _done.has("creature_gone")},
		{"text": "Тихо выйди из дома", "done": func(): return _done.has("tripped")},
		{"text": "Спрячься за гаражом", "done": func(): return _done.has("at_garage")},
		{"text": "Выгляни из-за угла", "done": func(): return _done.has("peeked")},
		{"text": "Иди вдоль стены к другому углу", "done": func(): return _ending},
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
		# Трава не растёт на люке выхода из подвала за домом
		if Vector2(x - EXIT_HATCH.x, z - EXIT_HATCH.z).length() < 1.6:
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
	# Точки берутся у самой машины (EthanCar): пар — из-под смятого капота
	var wreck := _wreck_xform()
	_steam.global_position = wreck * EthanCar.STEAM_POINT

	# Уцелевшая правая фара упирается в валун и мигает (левая разбита ударом)
	_car_light = SpotLight3D.new()
	_car_light.light_color = Color(1.0, 0.92, 0.72)
	_car_light.light_energy = 5.0
	_car_light.spot_range = 13.0
	_car_light.spot_angle = 32.0
	add_child(_car_light)
	var lamp := wreck * (EthanCar.wreck_point(EthanCar.HEAD_R) + Vector3(0.0, 0.0, -0.06))
	_car_light.global_position = lamp
	_car_light.look_at(lamp + wreck.basis * Vector3(0.0, -0.08, -1.0), Vector3.UP)

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




# ─── События ──────────────────────────────────────────────────────────────────

func _run_start() -> void:
	while not is_instance_valid(GameManager.player_ref) or not GameManager.player_ref.is_inside_tree():
		await get_tree().process_frame
	_player = GameManager.player_ref
	_head = _player.get("head")
	_player.set("is_in_cutscene", true)
	# Итан смотрит на разбитую машину, голова кружится
	_player.rotation.y = atan2(_player.global_position.x - WRECK_POS.x, _player.global_position.z - WRECK_POS.z)
	_head.position.y = 0.7
	_head.rotation.z = 0.25
	# Тот же заклинивший сигнал и тот же пар, что в конце вступления: кадр сменился, звук — нет
	_horn = _sound_at("res://assets/audio/intro/horn_stuck.wav", WRECK_POS + Vector3.UP, -3.0, 1.0, true)
	_steam_audio = _sound_at("res://assets/audio/intro/steam_loop.wav", WRECK_POS + Vector3.UP, -6.0, 1.0, true)
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
	_say("ИТАН", "Я знаю эти места… Отцовский дом совсем рядом.", 3.2)


# Глава 2: Итан приходит в себя на холодном полу подвала и ничего не помнит
func _run_basement_wake() -> void:
	while not is_instance_valid(GameManager.player_ref) or not GameManager.player_ref.is_inside_tree():
		await get_tree().process_frame
	_player = GameManager.player_ref
	_head = _player.get("head")
	_player.set("is_in_cutscene", true)
	_player.global_position = BASEMENT_WAKE
	_player.velocity = Vector3.ZERO
	_player.rotation.y = atan2(BASEMENT_WAKE.x - BASEMENT_LOOK.x, BASEMENT_WAKE.z - BASEMENT_LOOK.z)
	_update_interior(BASEMENT_WAKE)
	# Пробуждение — кат-сцена Jan-ky (Ch2Wake, ~12 с) поверх игры: Итан приходит в себя на полу,
	# садится, сверху копыта, дверь наверху лестницы открывается. Последний кадр — лестница,
	# и управление сразу у игрока (он уже смотрит на BASEMENT_LOOK).
	await get_tree().process_frame
	await Cutscene.overlay(self, "res://scenes/cutscenes/Ch2Wake.tscn", {"from_gameplay": true})
	_black.color.a = 0.0
	_head.position.y = 1.62
	_head.rotation = Vector3.ZERO
	var drone := _sound("res://assets/audio/intro/dread_drone.wav", -16.0)
	if drone:
		drone.finished.disconnect(drone.queue_free)
		drone.finished.connect(drone.play)
	_player.set("is_in_cutscene", false)


func _process(delta: float) -> void:
	_t += delta
	_boundary_cd = maxf(0.0, _boundary_cd - delta)
	_update_flicker()
	if is_instance_valid(_player):
		_update_interior(_player.global_position)
	if is_instance_valid(_creature):
		_creature.call("update_motion", delta, _creature_gait, _creature_speed)
	if _hide_watch and not _caught and is_instance_valid(_player) and not _is_hidden():
		_on_caught()
	if _ending or not is_instance_valid(_player) or _player.get("is_in_cutscene") == true:
		return
	var pos := _player.global_position
	if _basement_mode:
		return
	_update_story(pos)
	_update_boundary_hints(pos)


func _update_flicker() -> void:
	var off := sin(_t * 13.0) * cos(_t * 7.3) > 0.55
	if is_instance_valid(_car_light):
		var dim := sin(_t * 23.0) < -0.85
		_car_light.light_energy = 0.8 if dim else 5.0
		# Стекло той же фары на машине мигает вместе со светом
		if not is_instance_valid(_ethan_car):
			_ethan_car = get_tree().get_first_node_in_group("ethan_car")
		if is_instance_valid(_ethan_car):
			_ethan_car.call("set_right_lamp", 0.5 if dim else 2.6)
	if _flicker_lights.size() > 0 and is_instance_valid(_flicker_lights[0]):
		_flicker_lights[0].light_energy = 0.15 if off else 2.2
	if is_instance_valid(_tv_light) and _tv_light.visible:
		var n := 0.75 + 0.5 * sin(_t * 31.0) * cos(_t * 17.0)
		_tv_light.light_energy = 1.8 * n
		if _flicker_lights.size() > 1:
			_flicker_lights[1].light_energy = 1.1 * n
	if is_instance_valid(_candle):
		_candle.light_energy = 1.0 + 0.18 * sin(_t * 11.0) + 0.1 * sin(_t * 27.0)


func _update_story(pos: Vector3) -> void:
	# Сигнал смолкает сам собой, дальше только лес
	if _t > 8.0 and _once("horn_stop"):
		if is_instance_valid(_horn):
			_horn.finished.disconnect(_horn.play)
			_horn.stop()
			_horn.queue_free()
			_sound_at("res://assets/audio/intro/horn_die.wav", WRECK_POS + Vector3.UP, -3.0)
	if pos.x < -46.0 and absf(pos.z + 225.0) < 4.0 and pos.y < 2.0 and _once("porch"):
		_say("ИТАН", "Полицейская лента… Дверь не заперта: здесь уже побывала полиция.", 3.6)

	var inside := pos.x > -71.0 and pos.x < -53.2 and pos.z > -231.0 and pos.z < -219.0
	if inside and not _done.has("called") and pos.x < -54.5:
		_done["called"] = true
	if inside and pos.y > 2.8 and pos.x < -59.3 and pos.z > -225.0 and _once("father_room"):
		_say("ИТАН", "Комната отца…", 1.8)
	if _done.has("father") and inside and pos.y > 2.8 and pos.x < -59.4 and pos.z < -225.3 and _once("sam"):
		_say("ИТАН", SAM_LINE, 7.2)
	if _done.has("sam") and inside and pos.y > 2.8 and pos.x > -61.4 and pos.z < -226.6 and pos.z > -229.4 and _t > 0.0 and _once("memory"):
		_say("ИТАН", "Постой… Наше место. Мы с Сэмом написали там имена — в углу, где никто не заметит.", 4.6)

	# Побег: снаружи Итан бежит и спотыкается
	if _done.has("creature_gone") and pos.x > -50.0 and pos.y < 1.5 and absf(pos.z + 223.0) < 8.0 and _once("tripped"):
		_run_trip()
	if _done.has("tripped") and pos.x > -55.4 and pos.x < -53.2 and pos.z > -212.6 and pos.z < -204.0 and _once("at_garage"):
		_say("ИТАН", "Сердце колотится… Надо увидеть, что это.", 3.0)
	if _done.has("peeked") and pos.z < -212.4 and pos.x > -55.4 and pos.x < -52.6 and _once("corner"):
		_run_corner()

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
			_say("ИТАН", "Не туда. Сначала дом отца.", 2.4)
			_boundary_cd = 8.0
			return
















# После скримера финал из кат-сцены: Итана волокут за ворота, затем он очнётся в подвале дома отца
func _finish() -> void:
	GameManager.intro_epilogue = true
	GameManager.wake_in_basement = true
	get_tree().change_scene_to_file("res://scenes/IntroCutscene.tscn")


# ─── Глава 1: дом ─────────────────────────────────────────────────────────────

# Полицейская лента на входе, правила бабушки рукой отца, улики в комнате отца
func _build_chapter_props() -> void:
	var tape := StandardMaterial3D.new()
	tape.albedo_color = Color(0.86, 0.72, 0.08)
	tape.roughness = 0.6
	tape.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Две ленты крест-накрест и одна поперёк проёма, снаружи двери
	for k in [[1.32, 27.0], [1.32, -27.0], [0.98, 0.0]]:
		var band := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.006, 0.075, 1.6)
		mesh.material = tape
		band.mesh = mesh
		add_child(band)
		band.global_position = FRONT_DOOR + Vector3(0.6, float(k[0]), 0.0)
		band.rotation_degrees = Vector3(float(k[1]), 0.0, 0.0)
		var text := Label3D.new()
		text.text = "ПОЛИЦИЯ · НЕ ВХОДИТЬ"
		text.font_size = 28
		text.pixel_size = 0.0016
		text.modulate = Color(0.05, 0.04, 0.02)
		text.outline_size = 0
		text.position = Vector3(0.006, 0.0, 0.0)
		text.rotation_degrees.y = 90.0
		band.add_child(text)
	# Правила на стене у входа: тот же текст, что у бабушки на заправке
	var rules := Label3D.new()
	rules.text = RULES
	rules.font_size = 34
	rules.pixel_size = 0.0019
	rules.modulate = Color(0.16, 0.13, 0.11, 0.9)
	rules.outline_size = 0
	rules.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(rules)
	rules.global_position = Vector3(-53.32, 1.55, -227.2)
	rules.rotation_degrees.y = -90.0
	# Улики в комнате отца
	var paper := _flat_mat(Color(0.82, 0.78, 0.68))
	var dark := _flat_mat(Color(0.12, 0.1, 0.09))
	_prop(Vector3(0.22, 0.17, 0.02), Vector3(-67.45, 4.32, -219.5), Vector3(-12.0, 160.0, 0.0), _flat_mat(Color(0.32, 0.24, 0.16)))
	_prop(Vector3(0.18, 0.13, 0.004), Vector3(-67.45, 4.32, -219.49), Vector3(-12.0, 160.0, 0.0), _flat_mat(Color(0.55, 0.5, 0.42)), Vector3(0.0, 0.0, 0.013))
	_prop(Vector3(0.17, 0.035, 0.24), Vector3(-64.0, 4.25, -219.5), Vector3(0.0, 12.0, 0.0), _flat_mat(Color(0.22, 0.12, 0.07)))
	_prop(Vector3(0.28, 0.4, 0.008), Vector3(-63.1, 5.05, -219.32), Vector3(0.0, 0.0, 1.5), paper)
	_prop(Vector3(0.05, 0.022, 0.11), Vector3(-63.25, 4.24, -219.62), Vector3(0.0, -30.0, 0.0), dark)
	var circle := Label3D.new()
	circle.text = "○"
	circle.font_size = 64
	circle.pixel_size = 0.0016
	circle.modulate = Color(0.6, 0.05, 0.03)
	circle.outline_size = 0
	add_child(circle)
	circle.global_position = Vector3(-63.05, 4.98, -219.31)


func _flat_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m


func _prop(size: Vector3, pos: Vector3, rot: Vector3, mat: Material, offset: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	mi.mesh = box
	add_child(mi)
	mi.global_position = pos
	mi.rotation_degrees = rot
	mi.position += mi.global_transform.basis * offset


func _spot(pos: Vector3, side: Vector3, action: String, use: Callable) -> StorySpot:
	var s := StorySpot.new()
	s.setup(action, use, side)
	add_child(s)
	s.global_position = pos
	_spots.append(s)
	return s


func _drop(s: Variant) -> void:
	if is_instance_valid(s):
		s.queue_free()


# Дверь не заперта: полиция сняла доски, Итан входит без лома
func _open_front_door() -> void:
	for n in get_parent().find_children("*", "Node3D", true, false):
		if n.has_method("get_door_info") and n.name != "Panel" and n.global_position.distance_to(FRONT_DOOR) < 1.2:
			n.set("door_boards_broken", true)
			n.set("requires_boards", false)
			var boards = n.get_node_or_null("Boards")
			if boards:
				boards.queue_free()
			if not _basement_mode and n.get("is_open") != true:
				n.call("open_by_enemy", null)
			break
	# Лом и ключ от калитки из старого сюжета больше не нужны
	for n in get_parent().find_children("*", "Area3D", true, false):
		if n.has_meta("item_type"):
			var p: Vector3 = (n as Node3D).global_position
			if p.distance_to(Vector3(-50.8, 1.2, -204.8)) < 1.5 or p.distance_to(Vector3(-66.5, 4.3, -230.3)) < 1.5:
				n.queue_free()
	if _basement_mode:
		return
	_spot(FRONT_DOOR + Vector3(0.85, 1.0, 0.0), Vector3(0.6, 2.0, 1.8), "Позвать", _on_call)
	_spot(Vector3(-69.3, 3.95, -220.7), Vector3(2.3, 1.0, 1.7), "Посмотреть на кровать", _on_father_bed)
	_spot(Vector3(-67.45, 4.32, -219.5), Vector3(0.4, 0.35, 0.3), "Взять фотографию", _on_clue.bind("Семейное фото… Отец, Сэм, я. И ещё кто-то: его лицо зачёркнуто ручкой. Кто это?"))
	_spot(Vector3(-64.0, 4.26, -219.5), Vector3(0.4, 0.25, 0.4), "Открыть дневник", _on_clue.bind("Дневник отца. Последние страницы вырваны."))
	_spot(Vector3(-63.1, 5.05, -219.35), Vector3(0.45, 0.55, 0.2), "Посмотреть календарь", _on_clue.bind("Календарь. Обведено число… Это день, когда я разбился на дороге."))
	_spot(Vector3(-63.25, 4.25, -219.62), Vector3(0.3, 0.2, 0.3), "Включить диктофон", _on_tape)
	_spot(Vector3(-53.45, 1.55, -227.2), Vector3(0.25, 0.8, 1.2), "Прочитать", _on_clue.bind("Это почерк отца… Те же правила, что у бабушки на заправке. Он знал."))
	_spot(Vector3(-70.45, 3.7, -230.55), Vector3(0.9, 0.8, 0.5), "Присмотреться к углу", _on_names)


func _on_call() -> void:
	if _done.has("called"):
		return
	_done["called"] = true
	_say("ИТАН", "Здесь кто-нибудь есть?", 2.2)
	await get_tree().create_timer(2.8, false).timeout
	_say("", "Тишина.", 1.8)


func _on_father_bed() -> void:
	if _done.has("father"):
		_say("ИТАН", "Кровать стоит криво… Её двигали. Тяжёлая.", 3.0)
		return
	_done["father"] = true
	_say("ИТАН", "Пустая… Простыня смята, будто он встал минуту назад.", 3.2)
	await get_tree().create_timer(3.8, false).timeout
	_say("ИТАН", FATHER_LINE, 8.5)


func _on_clue(text: String) -> void:
	_clues += 1
	_say("ИТАН", text, 3.6)


func _on_tape() -> void:
	_clues += 1
	_sound("res://assets/audio/tv_static.wav", -14.0, 1.4)
	await get_tree().create_timer(0.6, false).timeout
	_say("ОТЕЦ (ЗАПИСЬ)", "«Сэм, если я не вернусь до рассвета, не открывай подвал».", 4.0)


func _on_names() -> void:
	if not _done.has("sam") or _done.has("names"):
		return
	_done["names"] = true
	_say("ИТАН", "«СЭМ» и «ИТАН»… Детский почерк. А над ними…", 3.2)
	await get_tree().create_timer(3.6, false).timeout
	_say("", "«ИТАН, ЕСЛИ ТЫ ЭТО ЧИТАЕШЬ — БЕГИ. ОНО ИДЁТ…»", 4.2)
	await get_tree().create_timer(4.8, false).timeout
	_run_hooves(false)


# ─── Глава 1: копыта и прятки ─────────────────────────────────────────────────

# Спрятался = сидит в шкафу на втором этаже
func _is_hidden() -> bool:
	if _player.get("is_hiding") != true:
		return false
	var spot = _player.get("hiding_node")
	return is_instance_valid(spot) and (spot as Node3D).global_position.y > 3.0


func _hoof(kind: String, at: Vector3, db: float) -> void:
	_sound_at("res://assets/audio/cutscenes/hoof_%s_%d.wav" % [kind, randi() % 4 + 1], at, db, randf_range(0.94, 1.04))


func _run_hooves(retry: bool) -> void:
	_caught = false
	if not retry:
		for k in range(4):
			_hoof("ground", Vector3(-45.0 + k * 0.4, 0.2, -225.0 - k * 0.3), -2.0)
			await get_tree().create_timer(0.85, false).timeout
		_say("ИТАН", "…Это не шаги. Копыта.", 2.2)
		_warn.text = "СПРЯЧЬСЯ"
		var tw := create_tween()
		tw.tween_property(_warn, "modulate:a", 1.0, 0.1)
		tw.tween_interval(1.4)
		tw.tween_property(_warn, "modulate:a", 0.0, 0.4)
		await get_tree().create_timer(1.6, false).timeout
		_sound_at("res://assets/audio/intro/door_creak.wav", FRONT_DOOR + Vector3.UP, -4.0, 0.8)
		for k in range(3):
			_hoof("wood", FRONT_DOOR + Vector3(-1.0 - k * 0.9, 0.3, -0.5 - k * 0.6), 0.0)
			await get_tree().create_timer(0.9, false).timeout
	# Вверх по лестнице и по коридору, всё ближе и громче
	var path := [Vector3(-56.0, 0.4, -228.6), Vector3(-56.0, 3.6, -224.6), Vector3(-54.0, 3.6, -225.2), Vector3(-54.0, 3.6, -228.0), Vector3(-58.2, 3.6, -228.0)]
	var steps := 13
	for k in range(steps):
		var u := float(k) / float(steps - 1) * float(path.size() - 1)
		var a := int(floor(u))
		var b := mini(a + 1, path.size() - 1)
		_hoof("wood", (path[a] as Vector3).lerp(path[b], u - a), lerpf(0.0, 5.0, float(k) / steps))
		await get_tree().create_timer(0.78 - float(k) * 0.015, false).timeout
	if not _is_hidden():
		_on_caught()
		return
	_done["hidden"] = true
	# Дверь медленно открывается: в проёме когти, существо осматривает комнату
	_creature = SkinwalkerModel.new()
	get_tree().current_scene.add_child(_creature)
	_creature.global_position = SAM_DOOR + Vector3(0.9, 0.0, 0.0)
	_dim_outline(_creature)
	_creature.rotation.y = -PI * 0.5
	var door := _door_at(SAM_DOOR)
	if door:
		door.call("open_by_enemy", _creature)
	_hide_watch = true
	_creature_gait = "walk"
	_creature_speed = 0.5
	var tw2 := create_tween()
	tw2.tween_property(_creature, "global_position", SAM_DOOR + Vector3(-0.15, 0.0, 0.0), 1.6)
	await tw2.finished
	_creature_gait = "idle"
	_creature_speed = 0.0
	_sound_at("res://assets/audio/monster/monster_breath.wav", SAM_DOOR + Vector3(0.0, 2.0, 0.0), -2.0)
	for look: float in [-PI * 0.25, -PI * 0.75, -PI * 0.5]:
		var turn := create_tween()
		turn.tween_property(_creature, "rotation:y", look, 1.0).set_trans(Tween.TRANS_SINE)
		await turn.finished
		await get_tree().create_timer(0.6, false).timeout
		if _caught:
			return
	# Ничего не заметило и ушло в соседнюю комнату
	_creature_gait = "walk"
	_creature_speed = 0.55
	var turn_out := create_tween()
	turn_out.tween_property(_creature, "rotation:y", 0.0, 0.6)
	await turn_out.finished
	var away := create_tween()
	away.tween_property(_creature, "global_position", Vector3(-58.0, 3.48, -222.6), 3.4)
	await away.finished
	if _caught:
		return
	_hide_watch = false
	_creature.queue_free()
	_creature = null
	for k in range(2):
		_hoof("muffled", Vector3(-62.0, 3.6, -222.0), -6.0)
		await get_tree().create_timer(0.9, false).timeout
	_done["creature_gone"] = true
	_say("ИТАН", "Ушло в соседнюю комнату… Надо выбираться. Тихо.", 3.4)


# В темноте видно только контур и глаза: слабый холодный свет из-за спины
func _dim_outline(model: Node3D) -> void:
	model.call("set_eye_glow", 1.0)
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.55, 0.66, 0.95)
	rim.light_energy = 1.1
	rim.omni_range = 3.2
	rim.shadow_enabled = false
	model.add_child(rim)
	rim.position = Vector3(0.0, 2.2, 0.9)


func _door_at(pos: Vector3) -> Node:
	for n in get_parent().find_children("*", "Node3D", true, false):
		if n.has_method("get_door_info") and n.name != "Panel" and n.global_position.distance_to(pos) < 1.0:
			return n
	return null


# Заметило: скример, затем снова в углу, копыта ещё раз поднимаются по лестнице
func _on_caught() -> void:
	if _caught:
		return
	_caught = true
	_hide_watch = false
	_player.set("is_in_cutscene", true)
	var scare := SkinwalkerScare.new()
	add_child(scare)
	await scare.finished
	scare.queue_free()
	if is_instance_valid(_creature):
		_creature.queue_free()
	_creature = null
	var door := _door_at(SAM_DOOR)
	if door and door.get("is_open") == true and door.has_method("interact"):
		door.call("interact", null)
	_black.color.a = 1.0
	_player.global_position = SAM_WARDROBE + Vector3(1.4, 0.1, 0.4)
	_player.velocity = Vector3.ZERO
	_player.set("is_in_cutscene", false)
	var fade := create_tween()
	fade.tween_property(_black, "color:a", 0.0, 1.2)
	_say("ИТАН", "Нельзя, чтобы оно меня увидело. В шкаф, быстро…", 3.4)
	await get_tree().create_timer(4.5, false).timeout
	_run_hooves(true)


# ─── Глава 1: побег ───────────────────────────────────────────────────────────

func _run_trip() -> void:
	_player.set("is_in_cutscene", true)
	_player.velocity = Vector3.ZERO
	_sound("res://assets/audio/player_step.wav", 0.0, 0.55)
	var fall := create_tween().set_parallel()
	fall.tween_property(_head, "position:y", 0.7, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(_head, "rotation:z", deg_to_rad(12.0), 0.3)
	await fall.finished
	_say("ИТАН", "Ах!..", 1.2)
	await get_tree().create_timer(0.9, false).timeout
	_say("ИТАН", "(зажимает рот) …Поздно. Оно услышало.", 2.6)
	var up := create_tween().set_parallel()
	up.tween_property(_head, "position:y", 1.62, 0.6).set_trans(Tween.TRANS_SINE)
	up.tween_property(_head, "rotation:z", 0.0, 0.6)
	await up.finished
	_player.set("is_in_cutscene", false)
	# Быстрый стук копыт сверху и вниз по лестнице
	for k in range(9):
		_hoof("wood", Vector3(-56.0, lerpf(3.6, 0.4, k / 8.0), lerpf(-224.6, -228.6, k / 8.0)), 2.0)
		await get_tree().create_timer(0.24, false).timeout
	_say("ИТАН", "К гаражу!", 1.6)
	# Существо выходит во двор и обходит гараж с другой стороны
	_creature = SkinwalkerModel.new()
	get_tree().current_scene.add_child(_creature)
	_creature.global_position = FRONT_DOOR + Vector3(0.6, -0.16, 0.0)
	_dim_outline(_creature)
	_creature_gait = "walk"
	_creature_speed = 1.1
	for target: Vector3 in [Vector3(-45.0, 0.0, -219.0), Vector3(-38.6, 0.0, -212.0), Vector3(-38.6, 0.0, -202.0), CREATURE_WAIT]:
		if _done.has("peeked"):
			break
		var from := _creature.global_position
		_creature.rotation.y = atan2(target.x - from.x, target.z - from.z) + PI
		var walk := create_tween()
		walk.tween_property(_creature, "global_position", target, from.distance_to(target) / 2.4)
		await walk.finished
	_creature_gait = "idle"
	_creature_speed = 0.0
	_spot(GARAGE_PEEK + Vector3(0.1, 1.2, 0.3), Vector3(1.2, 2.0, 1.4), "Выглянуть из-за угла", _on_peek)


func _on_peek() -> void:
	if _done.has("peeked") or not _done.has("at_garage"):
		return
	for s in _spots:
		if is_instance_valid(s) and (s as StorySpot).hint.ends_with("Выглянуть из-за угла"):
			_drop(s)
	_player.set("is_in_cutscene", true)
	if is_instance_valid(_creature):
		_creature.global_position = CREATURE_WAIT
		_creature.rotation.y = atan2(-1.0, 0.0)
	var start := _player.global_position
	var peek := Vector3(-53.25, start.y, -203.55)
	var look := CREATURE_WAIT - peek
	var tw := create_tween().set_parallel()
	tw.tween_property(_player, "global_position", peek, 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_player, "rotation:y", atan2(-look.x, -look.z), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_head, "rotation:x", 0.12, 0.7)
	await tw.finished
	_say("ИТАН", "Высокое… чёрное… неестественно худое. Когти…", 3.0)
	await get_tree().create_timer(2.6, false).timeout
	var back := create_tween().set_parallel()
	back.tween_property(_player, "global_position", Vector3(-53.6, start.y, -205.6), 0.4).set_trans(Tween.TRANS_QUAD)
	back.tween_property(_player, "rotation:y", 0.0, 0.5)
	back.tween_property(_head, "rotation:x", 0.0, 0.4)
	await back.finished
	_done["peeked"] = true
	_player.set("is_in_cutscene", false)
	# Постояло и ушло
	if is_instance_valid(_creature):
		_creature_gait = "walk"
		_creature_speed = 1.0
		_creature.rotation.y = -PI * 0.5
		var go := create_tween()
		go.tween_property(_creature, "global_position", CREATURE_WAIT + Vector3(14.0, 0.0, -1.0), 5.0)
		go.tween_callback(_creature.queue_free)
	await get_tree().create_timer(1.4, false).timeout
	_say("ИТАН", "Ушло… Вдоль стены. Тихо.", 2.6)


# За углом его уже ждут: кат-сцена Jan-ky, потом подвал
func _run_corner() -> void:
	_ending = true
	_player.set("is_in_cutscene", true)
	_player.velocity = Vector3.ZERO
	for s in _spots:
		_drop(s)
	await Cutscene.overlay(self, "res://scenes/cutscenes/Ch1Corner.tscn", {"from_gameplay": true})
	_black.color.a = 1.0
	_finish()
