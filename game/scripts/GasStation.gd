extends Node3D
class_name GasStation

# Одинокая заправка у лесного шоссе, ночь. Построена кодом, для кат-сцены: столкновений нет.
# Шоссе идёт вдоль оси Z при x = 0, машина едет в сторону -Z. Заправка стоит справа, при x > 4.
# Кассирша за прилавком: cashier. По умолчанию опирается на прилавок, say() проговаривает фразу.

const FLOOR_Y := 0.12
const CASHIER_POS := Vector3(25.72, FLOOR_Y, 1.8)
const TEX := "res://assets/textures/"
# Точки для камеры
const SHOT_ROAD := [Vector3(-1.6, 1.25, 78.0), Vector3(16.0, 2.2, -1.0)]
const SHOT_WIDE := [Vector3(-9.0, 2.4, 25.0), Vector3(18.0, 2.0, 0.0)]
const SHOT_PUMPS := [Vector3(7.5, 1.55, 9.5), Vector3(23.0, 1.8, 0.5)]
const SHOT_WINDOW := [Vector3(19.2, 1.58, 3.1), Vector3(25.7, 1.45, 1.8)]
const SHOT_INSIDE := [Vector3(23.75, 1.5, 2.55), Vector3(25.7, 1.48, 1.8)]

@export var build_environment := true
@export var build_forest := true

var cashier: CashierModel
var _geo := {}
var _mats := {}
var _preview_cam: Camera3D = null
var _flicker_mesh: StandardMaterial3D
var _flicker_light: Light3D
var _flicker_energy := 0.0
var _sign_mat: StandardMaterial3D
var _t := 0.0
var _next_blink := 1.5
var _blink := 0.0


func _ready() -> void:
	_setup_materials()
	if build_environment:
		_setup_environment()
	_build_ground_and_road()
	_build_canopy_and_pumps()
	_build_store()
	_build_interior()
	_build_yard()
	_build_roadside()
	_detail_forecourt()
	_detail_canopy()
	_detail_store()
	_detail_interior()
	_commit_geometry()
	_build_lights()
	_build_moths()
	if build_forest:
		_build_forest()
	cashier = CashierModel.new()
	cashier.position = CASHIER_POS
	cashier.rotation.y = -PI * 0.5
	cashier.use_counter = true
	add_child(cashier)
	_setup_preview.call_deferred()


# Если сцену запустили саму по себе: камера и клавиши для просмотра. В кат-сцене не включается
func _setup_preview() -> void:
	if get_tree().current_scene != self:
		return
	_preview_cam = Camera3D.new()
	_preview_cam.far = 500.0
	add_child(_preview_cam)
	_preview_cam.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	var label := Label.new()
	label.position = Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 22)
	label.text = "1 дорога   2 общий план   3 колонки   4 окно   5 кассирша   6 кассирша говорит   Esc выход"
	ui.add_child(label)
	_preview_shot(SHOT_ROAD)


func _preview_shot(shot: Array) -> void:
	_preview_cam.global_position = shot[0]
	_preview_cam.look_at(shot[1])


func _unhandled_key_input(event: InputEvent) -> void:
	if _preview_cam == null or not event.is_pressed():
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			_preview_shot(SHOT_ROAD)
		KEY_2:
			_preview_shot(SHOT_WIDE)
		KEY_3:
			_preview_shot(SHOT_PUMPS)
		KEY_4:
			_preview_shot(SHOT_WINDOW)
		KEY_5:
			_preview_shot(SHOT_INSIDE)
		KEY_6:
			cashier.say("Увидишь на дороге оленя — не останавливайся.", 2.6)
		KEY_ESCAPE:
			get_tree().quit()


func _process(delta: float) -> void:
	_t += delta
	_next_blink -= delta
	# Одна лампа навеса умирает: гаснет сериями
	if _next_blink <= 0.0:
		_blink = randf_range(0.08, 0.5)
		_next_blink = randf_range(1.2, 6.0)
	_blink -= delta
	var on := 1.0
	if _blink > 0.0:
		on = 0.12 if fmod(_t, 0.11) < 0.06 else 0.7
	if _flicker_light:
		_flicker_light.light_energy = _flicker_energy * on
	if _flicker_mesh:
		_flicker_mesh.emission_energy_multiplier = 3.2 * on
	# Вывеска гудит и слегка дрожит
	if _sign_mat:
		_sign_mat.emission_energy_multiplier = 2.1 + sin(_t * 37.0) * 0.08 + sin(_t * 91.0) * 0.05
	if cashier and not cashier.is_speaking():
		cashier.update_motion(delta, "counter")
	elif cashier:
		cashier.update_motion(delta)


# ══════════════════════════════════════════════
#  Материалы и сборка геометрии
# ══════════════════════════════════════════════
func _mat(key: String, col: Color, tex: String = "", rough: float = 0.85, metal: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	m.roughness = rough
	m.metallic = metal
	if tex != "":
		m.albedo_texture = load(TEX + tex) as Texture2D
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	_mats[key] = m
	return m


# Пятнистая серая текстура: создаётся сразу, без ожидания
func _noise_image(freq: float, low: float, high: float) -> ImageTexture:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = 5
	var src := n.get_seamless_image(256, 256)
	var img := Image.create(256, 256, true, Image.FORMAT_RGB8)
	for y in 256:
		for x in 256:
			var v := lerpf(low, high, src.get_pixel(x, y).r)
			img.set_pixel(x, y, Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _setup_materials() -> void:
	var grunge := _noise_image(0.018, 0.74, 1.0)
	var concrete := _mat("concrete", Color.WHITE, "road/concrete_tile.png", 0.94)
	concrete.normal_enabled = true
	concrete.normal_texture = load(TEX + "road/concrete_tile_n.png") as Texture2D
	concrete.normal_scale = 0.7
	concrete.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var tarmac := _mat("tarmac", Color.WHITE, "road/asphalt_tile.png", 0.9)
	tarmac.normal_enabled = true
	tarmac.normal_texture = load(TEX + "road/asphalt_tile_n.png") as Texture2D
	tarmac.normal_scale = 0.8
	tarmac.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mat("brick", Color(0.62, 0.55, 0.5), "brick_dark.png", 0.95)
	_mat("plaster", Color(0.42, 0.4, 0.35), "", 0.92).albedo_texture = grunge
	_mat("tile", Color(0.25, 0.25, 0.23), "tile_morgue.png", 0.55)
	_mat("rust", Color(0.72, 0.62, 0.55), "rusted_metal.png", 0.85, 0.3)
	_mat("paint", Color.WHITE, "", 0.72)
	_mat("metal", Color.WHITE, "", 0.45, 0.55)
	_mat("ground", Color(0.095, 0.115, 0.075), "", 1.0).albedo_texture = grunge
	_mat("tube", Color(0.86, 0.96, 1.0), "", 0.4, 0.0, 3.2)
	_flicker_mesh = _mat("tube_bad", Color(0.86, 0.96, 1.0), "", 0.4, 0.0, 3.2)
	_mat("tube_in", Color(1.0, 0.97, 0.84), "", 0.4, 0.0, 3.0)
	_sign_mat = _mat("sign", Color(0.92, 0.25, 0.1), "", 0.5, 0.0, 2.1)
	_mat("signbox", Color(0.8, 0.68, 0.42), "", 0.5, 0.0, 0.55)
	_mat("fridge", Color(0.75, 0.9, 1.0), "", 0.5, 0.0, 0.7)
	_mat("amber", Color(1.0, 0.55, 0.12), "", 0.4, 0.0, 1.5)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.65, 0.65, 0.13)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.08
	glass.metallic_specular = 0.75
	_mats["glass"] = glass


# Параллелепипед с текстурой, положенной в метрах: на больших стенах она не растягивается
func _box(key: String, size: Vector3, pos: Vector3, col: Color = Color.WHITE, bas: Basis = Basis(), uv_k: float = 0.3) -> void:
	if not _geo.has(key):
		_geo[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	var g: Dictionary = _geo[key]
	var h := size * 0.5
	var x := Vector3.RIGHT
	var y := Vector3.UP
	var z := Vector3.BACK
	var faces := [[x, y, z, h.x, h.y, h.z], [-x, z, y, h.x, h.z, h.y], [y, z, x, h.y, h.z, h.x], [-y, x, z, h.y, h.x, h.z], [z, x, y, h.z, h.x, h.y], [-z, y, x, h.z, h.y, h.x]]
	for f in faces:
		var base: int = g.v.size()
		var n: Vector3 = f[0]
		var a: Vector3 = f[1]
		var b: Vector3 = f[2]
		var c: Vector3 = n * float(f[3])
		var ha: float = f[4]
		var hb: float = f[5]
		var corners := [c - a * ha - b * hb, c - a * ha + b * hb, c + a * ha + b * hb, c + a * ha - b * hb]
		for q in corners:
			var w: Vector3 = pos + bas * (q as Vector3)
			g.v.append(w)
			g.n.append((bas * n).normalized())
			var tg: Vector3 = bas * a
			g.t.append_array([tg.x, tg.y, tg.z, 1.0])
			g.c.append(col)
			g.uv.append(Vector2((q as Vector3).dot(a) + w.dot(a), (q as Vector3).dot(b) + w.dot(b)) * uv_k)
		g.i.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


# Цилиндр: ось вдоль bas.y, центр в pos
func _cyl(key: String, rad: float, height: float, pos: Vector3, col: Color = Color.WHITE, sides: int = 10, bas: Basis = Basis()) -> void:
	if not _geo.has(key):
		_geo[key] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(), "uv": PackedVector2Array(), "c": PackedColorArray(), "i": PackedInt32Array()}
	var g: Dictionary = _geo[key]
	var h := height * 0.5
	var base: int = g.v.size()
	for j in sides + 1:
		var th := float(j) / float(sides) * TAU
		var nrm := Vector3(cos(th), 0.0, sin(th))
		for yy in [-h, h]:
			g.v.append(pos + bas * (nrm * rad + Vector3.UP * yy))
			g.n.append((bas * nrm).normalized())
			var tg: Vector3 = bas * Vector3(-sin(th), 0.0, cos(th))
			g.t.append_array([tg.x, tg.y, tg.z, 1.0])
			g.uv.append(Vector2(th * rad, yy) * 0.3)
			g.c.append(col)
	for j in sides:
		var q := base + j * 2
		g.i.append_array([q, q + 3, q + 1, q, q + 2, q + 3])
	for cap in [1.0, -1.0]:
		var c0: int = g.v.size()
		var nrm: Vector3 = (bas * Vector3.UP * cap).normalized()
		g.v.append(pos + bas * (Vector3.UP * h * cap))
		g.n.append(nrm)
		g.t.append_array([1.0, 0.0, 0.0, 1.0])
		g.uv.append(Vector2.ZERO)
		g.c.append(col)
		for j in sides:
			var th := float(j) / float(sides) * TAU
			g.v.append(pos + bas * (Vector3(cos(th), 0.0, sin(th)) * rad + Vector3.UP * h * cap))
			g.n.append(nrm)
			g.t.append_array([1.0, 0.0, 0.0, 1.0])
			g.uv.append(Vector2(cos(th), sin(th)) * rad)
			g.c.append(col)
		for j in sides:
			var a0 := c0 + 1 + j
			var a1 := c0 + 1 + (j + 1) % sides
			if cap > 0.0:
				g.i.append_array([c0, a1, a0])
			else:
				g.i.append_array([c0, a0, a1])


func _commit_geometry() -> void:
	for key in _geo:
		var g: Dictionary = _geo[key]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = g.v
		arr[Mesh.ARRAY_NORMAL] = g.n
		arr[Mesh.ARRAY_TANGENT] = g.t
		arr[Mesh.ARRAY_TEX_UV] = g.uv
		arr[Mesh.ARRAY_COLOR] = g.c
		arr[Mesh.ARRAY_INDEX] = g.i
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(0, _mats[key])
		var mi := MeshInstance3D.new()
		mi.name = "Geo_" + key
		mi.mesh = mesh
		if key == "glass" or key.begins_with("tube") or key == "sign" or key == "signbox":
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_geo.clear()


# Надпись; yaw — куда смотрит лицевая сторона
func _text(s: String, pos: Vector3, yaw: float, size: float, col: Color, bold_px: int = 0) -> Label3D:
	var l := Label3D.new()
	l.text = s
	l.position = pos
	l.rotation.y = yaw
	l.pixel_size = size / 96.0
	l.font_size = 96
	l.outline_size = bold_px
	l.outline_modulate = Color(col.r, col.g, col.b, 0.25)
	l.modulate = col
	l.shaded = false
	l.double_sided = false
	add_child(l)
	return l


# ══════════════════════════════════════════════
#  Земля и дорога
# ══════════════════════════════════════════════
func _build_ground_and_road() -> void:
	_box("ground", Vector3(900.0, 0.2, 900.0), Vector3(0, -0.13, 0), Color.WHITE, Basis(), 0.12)
	RoadKit.add_road(self, -340.0, 340.0)
	# Бетон перед заправкой и съезды
	_box("concrete", Vector3(20.0, 0.1, 30.0), Vector3(14.0, 0.0, 0.0), Color.WHITE, Basis(), 0.125)
	# Съезды с шоссе ложатся поверх обочины
	for s in [-1.0, 1.0]:
		_box("tarmac", Vector3(3.2, 0.09, 9.0), Vector3(5.4, 0.008, 11.0 * s), Color(1.0, 1.0, 1.0), Basis(), 0.125)
	# Пятна масла и трещины
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for i in 34:
		var pos := Vector3(rng.randf_range(6.0, 22.0), 0.054, rng.randf_range(-13.0, 13.0))
		var yaw := Basis(Vector3.UP, rng.randf() * TAU)
		if i < 16:
			var r := rng.randf_range(0.3, 1.1)
			_box("paint", Vector3(r, 0.002, r * rng.randf_range(0.5, 1.0)), pos, Color(0.035, 0.032, 0.03), yaw)
		else:
			_box("paint", Vector3(rng.randf_range(0.8, 3.4), 0.002, 0.018), pos, Color(0.03, 0.03, 0.03), yaw)


# ══════════════════════════════════════════════
#  Навес и колонки
# ══════════════════════════════════════════════
func _build_canopy_and_pumps() -> void:
	var cx := 13.0
	# Островок
	_box("concrete", Vector3(1.6, 0.2, 13.0), Vector3(cx, 0.15, 0), Color(0.82, 0.8, 0.74), Basis(), 0.3)
	_box("paint", Vector3(1.66, 0.05, 0.12), Vector3(cx, 0.26, 6.45), Color(0.6, 0.5, 0.1))
	_box("paint", Vector3(1.66, 0.05, 0.12), Vector3(cx, 0.26, -6.45), Color(0.6, 0.5, 0.1))
	# Стойки
	for s in [-1.0, 1.0]:
		_box("metal", Vector3(0.42, 4.5, 0.42), Vector3(cx, 2.4, 5.2 * s), Color(0.52, 0.51, 0.47))
		_box("rust", Vector3(0.5, 0.65, 0.5), Vector3(cx, 0.55, 5.2 * s), Color.WHITE, Basis(), 0.6)
		_box("paint", Vector3(0.52, 0.12, 0.52), Vector3(cx, 0.95, 5.2 * s), Color(0.5, 0.42, 0.08))
	# Крыша навеса: белая кромка с выгоревшей красной полосой
	_box("metal", Vector3(9.0, 0.32, 15.0), Vector3(cx, 4.82, 0), Color(0.3, 0.3, 0.29))
	_box("paint", Vector3(9.2, 0.6, 15.2), Vector3(cx, 5.15, 0), Color(0.58, 0.57, 0.52))
	for s in [-1.0, 1.0]:
		_box("paint", Vector3(9.24, 0.16, 0.02), Vector3(cx, 5.1, 7.61 * s), Color(0.42, 0.07, 0.05))
		_box("paint", Vector3(0.02, 0.16, 15.24), Vector3(cx + 4.61 * s, 5.1, 0), Color(0.42, 0.07, 0.05))
	_text("ТОПЛИВО", Vector3(cx - 4.625, 5.14, 3.8), -PI * 0.5, 0.42, Color(0.72, 0.68, 0.58))
	# Лампы под навесом: одна умирает
	var spots := [Vector3(cx - 2.3, 4.65, -4.0), Vector3(cx - 2.3, 4.65, 0.0), Vector3(cx - 2.3, 4.65, 4.0), Vector3(cx + 2.3, 4.65, -4.0), Vector3(cx + 2.3, 4.65, 0.0), Vector3(cx + 2.3, 4.65, 4.0)]
	for i in spots.size():
		_box("metal", Vector3(0.5, 0.05, 1.42), spots[i] + Vector3(0, 0.03, 0), Color(0.2, 0.2, 0.2))
		_box("tube_bad" if i == 2 else "tube", Vector3(0.36, 0.04, 1.3), spots[i], Color.WHITE)
	# Колонки: рабочая и сломанная
	_pump(Vector3(cx, 0.25, -2.6), true)
	_pump(Vector3(cx, 0.25, 2.6), false)
	# Урна и ведро со щёткой у стойки
	_box("metal", Vector3(0.44, 0.8, 0.44), Vector3(cx, 0.65, 4.2), Color(0.1, 0.12, 0.11))
	_box("metal", Vector3(0.36, 0.05, 0.36), Vector3(cx, 1.06, 4.2), Color(0.06, 0.06, 0.06))
	_box("paint", Vector3(0.28, 0.32, 0.28), Vector3(cx, 0.41, -4.5), Color(0.22, 0.26, 0.3))
	_box("paint", Vector3(0.04, 0.72, 0.04), Vector3(cx + 0.07, 0.72, -4.5), Color(0.3, 0.2, 0.1), Basis(Vector3.BACK, -0.2))


func _pump(p: Vector3, works: bool) -> void:
	var body := Color(0.22, 0.21, 0.18) if works else Color(0.11, 0.11, 0.1)
	_box("paint", Vector3(0.9, 0.2, 1.05), p + Vector3(0, 0.1, 0), Color(0.12, 0.12, 0.12))
	_box("paint", Vector3(0.66, 1.72, 0.92), p + Vector3(0, 1.06, 0), body)
	_box("paint", Vector3(0.7, 0.24, 0.96), p + Vector3(0, 1.98, 0), Color(0.16, 0.03, 0.02) if works else Color(0.08, 0.03, 0.02))
	for s in [-1.0, 1.0]:
		var face := p + Vector3(0.34 * s, 0, 0)
		_box("paint", Vector3(0.015, 0.44, 0.68), face + Vector3(0, 1.48, 0), Color(0.05, 0.05, 0.05))
		if works:
			_box("amber", Vector3(0.012, 0.14, 0.5), face + Vector3(0.005 * s, 1.58, 0), Color(0.4, 0.2, 0.05))
			_text("37.40", face + Vector3(0.014 * s, 1.58, 0), PI * 0.5 * s, 0.12, Color(1.0, 0.62, 0.15))
			_text("000.00", face + Vector3(0.014 * s, 1.38, 0), PI * 0.5 * s, 0.09, Color(0.85, 0.6, 0.3))
		# Швы панелей, решётка внизу, считыватель и наклейки
		for z in [-0.43, 0.43]:
			_box("paint", Vector3(0.012, 1.7, 0.012), face + Vector3(0.003 * s, 1.06, z), Color(0.015, 0.015, 0.015))
		_box("paint", Vector3(0.012, 0.012, 0.9), face + Vector3(0.003 * s, 0.86, 0), Color(0.015, 0.015, 0.015))
		for i in 6:
			_box("paint", Vector3(0.013, 0.018, 0.56), face + Vector3(0.003 * s, 0.36 + float(i) * 0.06, 0), Color(0.02, 0.02, 0.02))
		_box("paint", Vector3(0.022, 0.13, 0.18), face + Vector3(0.006 * s, 0.98, 0.16), Color(0.03, 0.03, 0.03))
		_box("paint", Vector3(0.025, 0.012, 0.11), face + Vector3(0.009 * s, 1.0, 0.16), Color(0.25, 0.25, 0.22))
		_box("paint", Vector3(0.014, 0.08, 0.14), face + Vector3(0.002 * s, 0.97, -0.17), Color(0.28, 0.03, 0.02))
		_text("АИ-92" if works else "ДТ", face + Vector3(0.016 * s, 1.97, 0), PI * 0.5 * s, 0.1, Color(0.62, 0.58, 0.48))
		# Кнопки, пистолет и шланг
		for i in 3:
			_box("paint", Vector3(0.014, 0.05, 0.12), face + Vector3(0, 1.13, -0.17 + i * 0.17), Color(0.42, 0.42, 0.38))
		var nz := 0.52
		_box("metal", Vector3(0.06, 0.28, 0.06), face + Vector3(0.05 * s, 1.06, nz - 0.1), Color(0.08, 0.08, 0.08))
		var a := face + Vector3(0.05 * s, 0.9, nz - 0.1)
		var e := face + Vector3(-0.1 * s, 1.75, 0.46)
		_hose(a, e, 0.5)
	if not works:
		# Мешок на пистолетах и листок
		_box("paint", Vector3(0.82, 0.62, 1.02), p + Vector3(0, 1.46, 0), Color(0.05, 0.05, 0.055))
		_box("paint", Vector3(0.012, 0.3, 0.46), p + Vector3(-0.42, 1.44, 0), Color(0.6, 0.58, 0.5))
		_text("НЕ\nРАБОТАЕТ", p + Vector3(-0.43, 1.44, 0), -PI * 0.5, 0.075, Color(0.1, 0.05, 0.05))


# Шланг провисает дугой из коротких отрезков
func _hose(a: Vector3, e: Vector3, sag: float) -> void:
	var n := 9
	var prev := a
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var q := a.lerp(e, t) + Vector3.DOWN * sin(t * PI) * sag
		var mid := (prev + q) * 0.5
		var d := q - prev
		if d.length() > 0.001:
			var bas := Basis.looking_at(d.normalized(), Vector3.UP if absf(d.normalized().y) < 0.98 else Vector3.RIGHT)
			_box("metal", Vector3(0.028, 0.028, d.length() + 0.012), mid, Color(0.035, 0.035, 0.035), bas)
		prev = q


# ══════════════════════════════════════════════
#  Магазин снаружи
# ══════════════════════════════════════════════
func _build_store() -> void:
	var x0 := 22.0
	var x1 := 33.0
	var zw := 5.6
	var top := 3.5
	# Фундамент и пол
	_box("concrete", Vector3(x1 - x0 + 0.8, FLOOR_Y, zw * 2.0 + 0.8), Vector3((x0 + x1) * 0.5, FLOOR_Y * 0.5, 0), Color(0.75, 0.74, 0.7), Basis(), 0.3)
	_box("concrete", Vector3(x1 - x0 - 0.2, 0.012, zw * 2.0 - 0.2), Vector3((x0 + x1) * 0.5, FLOOR_Y + 0.004, 0), Color(0.52, 0.5, 0.45), Basis(), 0.28)
	# Боковые и задняя стены
	for s in [-1.0, 1.0]:
		_box("plaster", Vector3(x1 - x0, top, 0.22), Vector3((x0 + x1) * 0.5, top * 0.5, zw * s), Color(0.8, 0.79, 0.72))
		_box("brick", Vector3(x1 - x0 + 0.02, 0.9, 0.25), Vector3((x0 + x1) * 0.5, 0.45, zw * s), Color.WHITE, Basis(), 0.55)
	_box("plaster", Vector3(0.22, top, zw * 2.0), Vector3(x1, top * 0.5, 0), Color(0.8, 0.79, 0.72))
	# Внутренняя отделка потолка и стен
	_box("paint", Vector3(x1 - x0, 0.1, zw * 2.0), Vector3((x0 + x1) * 0.5, top - 0.25, 0), Color(0.5, 0.49, 0.43))
	# Крыша с козырьком
	_box("metal", Vector3(x1 - x0 + 1.8, 0.2, zw * 2.0 + 1.4), Vector3((x0 + x1) * 0.5 - 0.4, top + 0.1, 0), Color(0.16, 0.16, 0.16))
	_box("paint", Vector3(0.2, 0.86, zw * 2.0 + 1.5), Vector3(x0 - 1.32, top + 0.17, 0), Color(0.46, 0.45, 0.4))
	# Фасад: цоколь, стойки, верхняя полоса, стекло
	_box("brick", Vector3(0.28, 0.72, zw * 2.0), Vector3(x0, 0.48, 0), Color.WHITE, Basis(), 0.55)
	_box("plaster", Vector3(0.28, 0.62, zw * 2.0), Vector3(x0, top - 0.31, 0), Color(0.68, 0.67, 0.6))
	_box("glass", Vector3(0.03, 2.1, zw * 2.0 - 0.2), Vector3(x0, 1.84, 0))
	var bars := [-5.5, -4.0, -2.6, -0.9, 1.1, 3.3, 5.5]
	for b in bars:
		_box("metal", Vector3(0.14, 2.3, 0.1), Vector3(x0, 1.9, b), Color(0.09, 0.09, 0.09))
	_box("metal", Vector3(0.14, 0.08, zw * 2.0), Vector3(x0, 0.86, 0), Color(0.09, 0.09, 0.09))
	# Дверь с ручкой и табличкой
	_box("metal", Vector3(0.1, 2.3, 0.08), Vector3(x0 - 0.04, 1.3, -3.3), Color(0.08, 0.08, 0.08))
	_box("metal", Vector3(0.06, 0.04, 0.3), Vector3(x0 - 0.12, 1.15, -3.0), Color(0.6, 0.58, 0.5))
	_box("paint", Vector3(0.02, 0.22, 0.42), Vector3(x0 - 0.05, 1.55, -3.3), Color(0.7, 0.68, 0.6))
	_text("ОТКРЫТО\n24 ЧАСА", Vector3(x0 - 0.062, 1.55, -3.3), -PI * 0.5, 0.05, Color(0.1, 0.06, 0.05))
	# Вывеска на фасаде
	_box("paint", Vector3(0.1, 0.7, 6.2), Vector3(x0 - 1.46, top + 0.17, 0), Color(0.07, 0.07, 0.07))
	_text("ЗАПРАВКА", Vector3(x0 - 1.53, top + 0.17, 0), -PI * 0.5, 0.56, Color(1.0, 0.3, 0.13), 8)
	# Неон в окне
	_text("ОТКРЫТО", Vector3(x0 + 0.08, 2.35, 3.3), -PI * 0.5, 0.26, Color(1.0, 0.15, 0.1), 10)
	_text("КОФЕ · ТАБАК", Vector3(x0 + 0.08, 2.5, -1.2), -PI * 0.5, 0.17, Color(0.5, 0.85, 0.75), 6)
	# Объявления о пропавших на стекле: их много и они старые
	var rng := RandomNumberGenerator.new()
	rng.seed = 9021
	var missing := [-2.05, -1.55, -0.2, 0.32, 1.75, 2.25, 4.1, 4.65]
	for i in missing.size():
		var z: float = missing[i]
		var y := rng.randf_range(1.15, 1.75)
		var c := Color(0.62, 0.6, 0.5).lerp(Color(0.5, 0.44, 0.3), rng.randf())
		var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.05, 0.05))
		_box("paint", Vector3(0.008, 0.46, 0.34), Vector3(x0 - 0.03, y, z), c, tilt)
		_box("paint", Vector3(0.006, 0.17, 0.15), Vector3(x0 - 0.036, y + 0.03, z), Color(0.08, 0.08, 0.08), tilt)
		_text("ПРОПАЛ", Vector3(x0 - 0.04, y + 0.17, z), -PI * 0.5, 0.05, Color(0.08, 0.05, 0.04))
		_text("где-то у леса", Vector3(x0 - 0.04, y - 0.12, z), -PI * 0.5, 0.026, Color(0.12, 0.1, 0.08))
	# Торговый автомат и ящик со льдом у стены
	_box("paint", Vector3(0.82, 1.85, 1.0), Vector3(x0 - 0.6, 1.0, -4.55), Color(0.28, 0.05, 0.04))
	_box("fridge", Vector3(0.02, 1.3, 0.72), Vector3(x0 - 1.02, 1.15, -4.55), Color(0.2, 0.22, 0.24))
	_box("paint", Vector3(0.76, 0.86, 1.3), Vector3(x0 - 0.54, 0.55, 4.5), Color(0.14, 0.15, 0.15))
	_text("ЛЁД", Vector3(x0 - 0.93, 0.68, 4.5), -PI * 0.5, 0.26, Color(0.28, 0.42, 0.55))


# ══════════════════════════════════════════════
#  Магазин внутри
# ══════════════════════════════════════════════
func _build_interior() -> void:
	var f := FLOOR_Y
	# Лампы на потолке
	for z in [-3.4, 0.0, 3.4]:
		for x in [24.2, 28.0, 31.2]:
			_box("metal", Vector3(1.32, 0.06, 0.28), Vector3(x, 3.17, z), Color(0.3, 0.3, 0.28))
			_box("tube_in", Vector3(1.22, 0.03, 0.16), Vector3(x, 3.13, z))
	# Прилавок: кассирша за ним, смотрит на дорогу
	_box("paint", Vector3(0.64, 0.82, 4.6), Vector3(24.95, f + 0.41, 1.8), Color(0.2, 0.13, 0.08))
	_box("paint", Vector3(0.74, 0.04, 4.72), Vector3(24.95, f + 0.84, 1.8), Color(0.085, 0.075, 0.06))
	# Касса, терминал, подставки с мелочью, журнал, стакан
	_box("paint", Vector3(0.38, 0.18, 0.44), Vector3(24.98, f + 0.95, 0.72), Color(0.1, 0.1, 0.1))
	_box("paint", Vector3(0.05, 0.25, 0.32), Vector3(24.85, f + 1.14, 0.72), Color(0.07, 0.07, 0.07), Basis(Vector3.BACK, 0.25))
	_box("amber", Vector3(0.004, 0.08, 0.2), Vector3(24.82, f + 1.16, 0.72), Color(0.3, 0.75, 0.25), Basis(Vector3.BACK, 0.25))
	_box("paint", Vector3(0.22, 0.012, 0.3), Vector3(24.86, f + 0.87, 2.9), Color(0.55, 0.53, 0.44), Basis(Vector3.UP, 0.25))
	_box("paint", Vector3(0.07, 0.11, 0.07), Vector3(25.08, f + 0.92, 2.72), Color(0.5, 0.48, 0.42))
	# Стойка с сигаретами за спиной
	_box("paint", Vector3(0.28, 2.1, 4.2), Vector3(26.95, f + 1.08, 1.8), Color(0.11, 0.08, 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = 212
	for row in 10:
		_box("metal", Vector3(0.1, 0.012, 4.05), Vector3(26.76, f + 0.88 + row * 0.135, 1.8), Color(0.05, 0.05, 0.05))
		var brand := _goods_color(rng)
		for i in 38:
			if i % 4 == 0:
				brand = _goods_color(rng)
			var pack := Vector3(26.79, f + 0.94 + row * 0.135, -0.13 + i * 0.104)
			_box("paint", Vector3(0.05, 0.105, 0.078), pack, brand)
			if i % 2 == 0:
				_box("paint", Vector3(0.052, 0.022, 0.078), pack + Vector3(0, 0.024, 0), brand.lightened(0.28))
	# Два ряда полок с товаром
	for z in [-3.9, -1.9]:
		_shelf(Vector3(28.0, f, z), 6.0, rng)
	# Холодильники у задней стены
	for i in 3:
		var z := -3.9 + i * 1.95
		_box("paint", Vector3(0.75, 2.2, 1.85), Vector3(32.45, f + 1.1, z), Color(0.13, 0.13, 0.14))
		_box("fridge", Vector3(0.02, 1.88, 1.6), Vector3(32.05, f + 1.14, z), Color(0.3, 0.42, 0.5))
		for sh in 4:
			for k in 10:
				_box("paint", Vector3(0.04, 0.3, 0.09), Vector3(32.03, f + 0.42 + sh * 0.44, z - 0.65 + k * 0.145), _goods_color(rng))
		_box("glass", Vector3(0.02, 1.95, 1.7), Vector3(32.0, f + 1.14, z))
	# Кофемашина на столике у окна и журнальная стойка
	_box("paint", Vector3(0.6, 0.9, 1.6), Vector3(22.75, f + 0.45, -1.2), Color(0.2, 0.17, 0.13))
	_box("paint", Vector3(0.42, 0.52, 0.5), Vector3(22.75, f + 1.16, -1.5), Color(0.07, 0.07, 0.07))
	_box("amber", Vector3(0.02, 0.05, 0.1), Vector3(22.53, f + 1.3, -1.5), Color(0.7, 0.1, 0.05))
	_box("metal", Vector3(0.14, 0.2, 0.14), Vector3(22.75, f + 1.0, -0.8), Color(0.4, 0.4, 0.38))
	# Дверь в подсобку, приоткрытая, за ней темно
	_box("paint", Vector3(0.03, 2.1, 1.0), Vector3(32.87, f + 1.05, 4.6), Color(0.015, 0.015, 0.015))
	_box("paint", Vector3(1.0, 2.1, 0.05), Vector3(32.42, f + 1.05, 4.07), Color(0.25, 0.26, 0.24), Basis(Vector3.UP, 0.45))
	# Настенные часы над стойкой: стоят
	_box("paint", Vector3(0.05, 0.4, 0.4), Vector3(27.1, f + 2.68, 1.8), Color(0.55, 0.53, 0.47))
	_text("21:40", Vector3(27.07, f + 2.68, 1.8), -PI * 0.5, 0.115, Color(0.05, 0.05, 0.05))


# Выгоревшие упаковки: тёмные, в основном тусклый красный, жёлтый, синий и коричневый
func _goods_color(rng: RandomNumberGenerator) -> Color:
	var base: Color = [Color(0.22, 0.04, 0.03), Color(0.24, 0.17, 0.03), Color(0.03, 0.07, 0.17), Color(0.1, 0.06, 0.03), Color(0.2, 0.2, 0.17), Color(0.03, 0.12, 0.06)][rng.randi_range(0, 5)]
	return base * rng.randf_range(0.55, 1.15)


func _shelf(p: Vector3, length: float, rng: RandomNumberGenerator) -> void:
	_box("metal", Vector3(length, 1.62, 0.1), p + Vector3(0, 0.81, 0), Color(0.09, 0.09, 0.085))
	for lv in 4:
		var y := 0.22 + lv * 0.46
		_box("metal", Vector3(length, 0.035, 0.84), p + Vector3(0, y, 0), Color(0.11, 0.11, 0.105))
		for s in [-1.0, 1.0]:
			var x := -length * 0.5 + 0.12
			while x < length * 0.5 - 0.1:
				var w := rng.randf_range(0.09, 0.2)
				# Кое-где полки пустые
				if rng.randf() > 0.2:
					var h := rng.randf_range(0.14, 0.34)
					var c := _goods_color(rng)
					var q := p + Vector3(x, y + 0.018 + h * 0.5, 0.25 * s)
					_box("paint", Vector3(w, h, 0.26), q, c)
					_box("paint", Vector3(w + 0.002, h * 0.3, 0.262), q + Vector3(0, h * 0.12, 0), c.lightened(0.14))
				x += w + 0.015


# ══════════════════════════════════════════════
#  Двор и обочина
# ══════════════════════════════════════════════
func _build_yard() -> void:
	# Контейнер, покрышки и бочки за углом
	_box("rust", Vector3(1.7, 1.25, 2.6), Vector3(31.0, 0.68, 8.1), Color(0.55, 0.65, 0.55), Basis(Vector3.UP, 0.12), 0.45)
	_box("metal", Vector3(1.8, 0.07, 2.7), Vector3(31.0, 1.34, 8.1), Color(0.1, 0.13, 0.1), Basis(Vector3.UP, 0.12))
	for i in 5:
		var q := Vector3(25.5 + (i % 2) * 0.1, 0.17 + i * 0.26, 7.3 - (i % 2) * 0.1)
		_box("paint", Vector3(0.74, 0.24, 0.74), q, Color(0.03, 0.03, 0.03), Basis(Vector3.UP, float(i) * 0.35))
	for spec in [[27.4, 7.8], [28.15, 8.05]]:
		_box("rust", Vector3(0.58, 0.9, 0.58), Vector3(spec[0], 0.5, spec[1]), Color(0.75, 0.6, 0.5), Basis(Vector3.UP, spec[0]), 0.7)
	# Воздух и вода
	_box("metal", Vector3(0.3, 1.25, 0.3), Vector3(21.0, 0.68, 9.5), Color(0.42, 0.11, 0.08))
	# Телефонная будка без трубки
	_box("metal", Vector3(0.9, 2.2, 0.9), Vector3(19.8, 1.14, -10.6), Color(0.15, 0.16, 0.17))
	_box("glass", Vector3(0.94, 1.8, 0.94), Vector3(19.8, 1.2, -10.6))
	_box("paint", Vector3(0.05, 0.42, 0.32), Vector3(19.34, 1.45, -10.6), Color(0.07, 0.07, 0.07))
	# Сетка-забор за магазином
	for i in 14:
		_box("metal", Vector3(0.07, 2.2, 0.07), Vector3(35.5, 1.1, -16.0 + i * 2.5), Color(0.25, 0.24, 0.22))
	_box("metal", Vector3(0.02, 1.9, 32.5), Vector3(35.5, 1.1, 0.25), Color(0.08, 0.08, 0.08))


func _build_roadside() -> void:
	# Стела с ценами у дороги
	var p := Vector3(7.2, 0, -13.0)
	_box("rust", Vector3(0.34, 8.6, 0.34), p + Vector3(0, 4.3, 0), Color(0.7, 0.68, 0.62))
	# Лицом к машине: она едет от +Z
	_box("paint", Vector3(3.3, 3.1, 0.34), p + Vector3(0, 8.4, 0), Color(0.05, 0.05, 0.05))
	_box("signbox", Vector3(3.05, 1.0, 0.02), p + Vector3(0, 9.3, 0.19), Color(0.88, 0.35, 0.12))
	_box("signbox", Vector3(3.05, 1.65, 0.02), p + Vector3(0, 7.92, 0.19), Color(0.75, 0.72, 0.6))
	_text("ТОПЛИВО", p + Vector3(0, 9.3, 0.21), 0.0, 0.58, Color(0.08, 0.03, 0.02))
	_text("АИ-92     37.40\nДТ        41.15", p + Vector3(0, 7.92, 0.21), 0.0, 0.36, Color(0.06, 0.05, 0.04))
	# Дорожный знак перед заправкой
	var q := Vector3(-5.6, 0, 92.0)
	_box("metal", Vector3(0.1, 3.0, 0.1), q + Vector3(-1.0, 1.5, 0), Color(0.35, 0.35, 0.33))
	_box("metal", Vector3(0.1, 3.0, 0.1), q + Vector3(1.0, 1.5, 0), Color(0.35, 0.35, 0.33))
	_box("paint", Vector3(3.3, 1.5, 0.05), q + Vector3(0, 3.0, 0), Color(0.03, 0.19, 0.12))
	_text("ЗАПРАВКА  200 м\nСЛЕДУЮЩАЯ  180 км", q + Vector3(0, 3.0, 0.035), 0.0, 0.25, Color(0.82, 0.84, 0.78))
	# Столбы с проводами вдоль шоссе
	var z := -300.0
	var prev := Vector3.ZERO
	var first := true
	while z <= 300.0:
		var b := Vector3(-7.0, 0, z)
		_box("rust", Vector3(0.24, 8.4, 0.24), b + Vector3(0, 4.2, 0), Color(0.3, 0.22, 0.14), Basis(Vector3.BACK, sin(z) * 0.015), 0.9)
		_box("rust", Vector3(1.9, 0.14, 0.14), b + Vector3(0, 7.9, 0), Color(0.3, 0.22, 0.14), Basis(), 0.9)
		if not first:
			for off in [-0.8, 0.8]:
				var a := prev + Vector3(off, 7.98, 0)
				var e := b + Vector3(off, 7.98, 0)
				_wire(a, e)
		prev = b
		first = false
		z += 42.0


func _wire(a: Vector3, e: Vector3) -> void:
	var n := 6
	var last := a
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var q := a.lerp(e, t) + Vector3.DOWN * sin(t * PI) * 0.75
		var d := q - last
		_box("paint", Vector3(0.018, 0.018, d.length() + 0.02), (q + last) * 0.5, Color(0.012, 0.012, 0.012), Basis.looking_at(d.normalized(), Vector3.UP))
		last = q


# ══════════════════════════════════════════════
#  Детали: бетон, навес, магазин, зал
# ══════════════════════════════════════════════
func _detail_forecourt() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 660
	var y := 0.052
	# Швы между бетонными плитами
	var x := 4.0
	while x <= 24.0:
		_box("paint", Vector3(0.028, 0.003, 30.0), Vector3(x, y, 0), Color(0.012, 0.012, 0.012))
		x += 4.0
	var z := -15.0
	while z <= 15.0:
		_box("paint", Vector3(20.0, 0.003, 0.028), Vector3(14.0, y, z), Color(0.012, 0.012, 0.012))
		z += 5.0
	# Сколы и смещённые плиты
	for i in 9:
		var q := Vector3(rng.randf_range(5.0, 22.0), y, rng.randf_range(-14.0, 14.0))
		_box("paint", Vector3(rng.randf_range(0.2, 0.6), 0.003, rng.randf_range(0.1, 0.4)), q, Color(0.05, 0.05, 0.05), Basis(Vector3.UP, rng.randf()))
	# Горловины подземных резервуаров в жёлтой рамке
	for i in 4:
		var q := Vector3(18.5, y + 0.006, -12.2 + float(i) * 1.15)
		_cyl("metal", 0.23, 0.012, q, Color(0.13, 0.13, 0.13), 16)
		_cyl("metal", 0.07, 0.016, q, Color(0.28, 0.1, 0.05), 10)
	for spec in [[Vector3(18.5, y + 0.002, -13.0), Vector3(1.0, 0.003, 0.05)], [Vector3(18.5, y + 0.002, -8.0), Vector3(1.0, 0.003, 0.05)], [Vector3(18.0, y + 0.002, -10.5), Vector3(0.05, 0.003, 5.0)], [Vector3(19.0, y + 0.002, -10.5), Vector3(0.05, 0.003, 5.0)]]:
		_box("paint", spec[1], spec[0], Color(0.32, 0.25, 0.04))
	# Люк и решётка ливнёвки
	_cyl("metal", 0.42, 0.012, Vector3(8.0, y + 0.006, -6.0), Color(0.08, 0.075, 0.07), 18)
	_box("metal", Vector3(0.5, 0.012, 1.3), Vector3(20.8, y + 0.006, 8.0), Color(0.045, 0.045, 0.045))
	for i in 9:
		_box("paint", Vector3(0.46, 0.014, 0.03), Vector3(20.8, y + 0.009, 7.45 + float(i) * 0.14), Color(0.005, 0.005, 0.005))
	# Разметка парковки у магазина и стрелка
	for i in 5:
		_box("paint", Vector3(3.2, 0.003, 0.08), Vector3(19.0, y + 0.002, -3.4 + float(i) * 2.2), Color(0.3, 0.3, 0.27))
	_box("paint", Vector3(0.12, 0.003, 1.8), Vector3(9.5, y + 0.002, 3.0), Color(0.3, 0.3, 0.27))
	_box("paint", Vector3(0.1, 0.003, 0.6), Vector3(9.3, y + 0.002, 2.25), Color(0.3, 0.3, 0.27), Basis(Vector3.UP, 0.7))
	_box("paint", Vector3(0.1, 0.003, 0.6), Vector3(9.7, y + 0.002, 2.25), Color(0.3, 0.3, 0.27), Basis(Vector3.UP, -0.7))
	# Столбики у островка и перед витриной
	for q in [Vector3(12.45, 0.7, 6.8), Vector3(13.55, 0.7, 6.8), Vector3(12.45, 0.7, -6.8), Vector3(13.55, 0.7, -6.8)]:
		_bollard(q)
	for zb in [-4.9, -1.6, 1.2, 3.85]:
		_bollard(Vector3(20.0, 0.51, zb))
	# Следы шин
	for spec in [[Vector3(9.7, y + 0.001, 6.0), 0.2], [Vector3(10.9, y + 0.001, 6.2), 0.16], [Vector3(10.0, y + 0.001, -6.2), -0.24], [Vector3(11.2, y + 0.001, -6.5), -0.2], [Vector3(16.2, y + 0.001, 0.0), 0.02]]:
		_box("paint", Vector3(0.11, 0.002, 6.0), spec[0], Color(0.12, 0.115, 0.11), Basis(Vector3.UP, spec[1]))
	# Тёмные потёки топлива у колонок
	for spec in [[Vector3(14.0, y + 0.002, -2.7), 0.2], [Vector3(12.0, y + 0.002, 2.5), 2.1], [Vector3(14.1, y + 0.002, 2.4), 0.8]]:
		for k in 5:
			var off := Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.7, 0.7))
			_cyl("paint", rng.randf_range(0.14, 0.4), 0.002, spec[0] + off, Color(0.11, 0.105, 0.098), 12, Basis().scaled(Vector3(1.0, 1.0, rng.randf_range(0.5, 1.0))))
	# Мусор: окурки, стаканы, банки, бумага
	for i in 44:
		var q := Vector3(rng.randf_range(10.5, 21.5), y + 0.012, rng.randf_range(-7.0, 8.0))
		_box("paint", Vector3(0.026, 0.012, 0.012), q, Color(0.42, 0.36, 0.26), Basis(Vector3.UP, rng.randf() * TAU))
	for spec in [[Vector3(14.1, 0.1, 4.6), Color(0.32, 0.31, 0.26)], [Vector3(20.2, 0.1, -2.1), Color(0.3, 0.04, 0.03)], [Vector3(11.4, 0.1, 0.8), Color(0.05, 0.1, 0.22)]]:
		_cyl("paint", 0.035, 0.12, spec[0], spec[1], 8, Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, spec[0].x))
	for i in 8:
		var q := Vector3(rng.randf_range(16.0, 21.0), y + 0.004, rng.randf_range(-9.0, 9.0))
		_box("paint", Vector3(0.21, 0.002, 0.15), q, Color(0.3, 0.29, 0.25), Basis(Vector3.UP, rng.randf() * TAU))
	# Сорняки у края бетона и у стены
	var tufts: Array[Transform3D] = []
	for i in 90:
		var q: Vector3
		if i < 40:
			q = Vector3(rng.randf_range(4.0, 24.0), 0.04, 15.0 * (-1.0 if i % 2 == 0 else 1.0) + rng.randf_range(-0.4, 0.4))
		elif i < 60:
			q = Vector3(21.5, 0.09, rng.randf_range(-5.6, 5.6))
		else:
			q = Vector3(rng.randf_range(23.0, 34.0), 0.0, 5.95 * (-1.0 if i % 2 == 0 else 1.0))
		var sc := rng.randf_range(0.45, 0.85)
		tufts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), q))
	RoadKit.add_tufts(self, tufts, 60.0)


func _bollard(q: Vector3) -> void:
	_cyl("metal", 0.065, 0.9, q, Color(0.32, 0.25, 0.03), 10)
	for k in 2:
		_cyl("metal", 0.067, 0.1, q + Vector3(0, 0.05 + float(k) * 0.28, 0), Color(0.02, 0.02, 0.02), 10)
	_cyl("metal", 0.05, 0.03, q + Vector3(0, 0.46, 0), Color(0.05, 0.05, 0.05), 10)


func _detail_canopy() -> void:
	var cx := 13.0
	# Панели потолка навеса и водостоки
	var z := -7.0
	while z <= 7.0:
		_box("metal", Vector3(8.9, 0.02, 0.025), Vector3(cx, 4.65, z), Color(0.1, 0.1, 0.1))
		z += 1.0
	for s in [-1.0, 1.0]:
		_box("metal", Vector3(0.1, 0.1, 15.2), Vector3(cx + 4.62 * s, 4.8, 0), Color(0.18, 0.18, 0.17))
		# Водосточная труба и кронштейны у стойки
		_cyl("metal", 0.045, 4.4, Vector3(cx + 0.27, 2.4, 5.2 * s), Color(0.14, 0.14, 0.13), 8)
		for yy in [1.3, 2.6, 3.9]:
			_box("metal", Vector3(0.1, 0.03, 0.09), Vector3(cx + 0.24, yy, 5.2 * s), Color(0.09, 0.09, 0.09))
		# Жёлто-чёрные полосы на стойках
		for k in 4:
			_box("paint", Vector3(0.455, 0.1, 0.455), Vector3(cx, 1.08 + float(k) * 0.2, 5.2 * s), Color(0.32, 0.25, 0.03) if k % 2 == 0 else Color(0.02, 0.02, 0.02))
	# Таблички на стойке и огнетушитель
	_box("paint", Vector3(0.012, 0.34, 0.26), Vector3(cx - 0.216, 2.1, -5.2), Color(0.34, 0.04, 0.03))
	_text("НЕ КУРИТЬ", Vector3(cx - 0.224, 2.1, -5.2), -PI * 0.5, 0.042, Color(0.8, 0.76, 0.66))
	_box("paint", Vector3(0.012, 0.28, 0.26), Vector3(cx - 0.216, 1.72, -5.2), Color(0.42, 0.4, 0.33))
	_text("ЗАГЛУШИ\nМОТОР", Vector3(cx - 0.224, 1.72, -5.2), -PI * 0.5, 0.036, Color(0.05, 0.05, 0.05))
	_cyl("paint", 0.075, 0.46, Vector3(cx - 0.32, 1.0, 5.2), Color(0.34, 0.03, 0.02), 10)
	_cyl("metal", 0.03, 0.06, Vector3(cx - 0.32, 1.26, 5.2), Color(0.04, 0.04, 0.04), 8)
	_box("metal", Vector3(0.05, 0.05, 0.16), Vector3(cx - 0.3, 1.31, 5.2), Color(0.04, 0.04, 0.04))
	# Коробка с полотенцами, камера наблюдения, динамик и кабели
	_box("paint", Vector3(0.12, 0.34, 0.27), Vector3(cx + 0.27, 1.38, -5.2), Color(0.14, 0.14, 0.13))
	_box("paint", Vector3(0.2, 0.12, 0.13), Vector3(cx + 3.6, 4.5, -6.9), Color(0.09, 0.09, 0.09))
	_box("paint", Vector3(0.1, 0.09, 0.1), Vector3(cx + 3.48, 4.44, -6.88), Color(0.02, 0.02, 0.02))
	_cyl("metal", 0.16, 0.13, Vector3(cx - 3.6, 4.58, 5.0), Color(0.15, 0.15, 0.14), 10)
	_box("metal", Vector3(0.05, 0.05, 11.0), Vector3(cx + 2.3, 4.63, 0.0), Color(0.06, 0.06, 0.06))
	_box("metal", Vector3(0.05, 0.05, 11.0), Vector3(cx - 2.3, 4.63, 0.0), Color(0.06, 0.06, 0.06))


func _detail_store() -> void:
	var x0 := 22.0
	var x1 := 33.0
	var zw := 5.6
	var top := 3.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 3190
	# Водостоки и трубы
	for s in [-1.0, 1.0]:
		_box("metal", Vector3(x1 - x0 + 1.8, 0.1, 0.12), Vector3((x0 + x1) * 0.5 - 0.4, top - 0.02, (zw + 0.7) * s), Color(0.18, 0.18, 0.17))
		_cyl("metal", 0.05, top, Vector3(x1 - 0.3, top * 0.5, (zw + 0.17) * s), Color(0.16, 0.16, 0.15), 8)
		# Подтёки на стенах
		for i in 16:
			var x := rng.randf_range(x0 + 0.4, x1 - 0.4)
			var h := rng.randf_range(0.5, 1.8)
			_box("paint", Vector3(rng.randf_range(0.05, 0.28), h, 0.004), Vector3(x, top - h * 0.5 - 0.05, (zw + 0.113) * s), Color(0.06, 0.055, 0.05))
	# Кабель-канал и щиток на боковой стене, дверь туалета
	_box("metal", Vector3(7.0, 0.05, 0.05), Vector3(27.2, 2.7, -5.76), Color(0.17, 0.17, 0.16))
	_box("metal", Vector3(0.05, 1.4, 0.05), Vector3(31.2, 2.0, -5.76), Color(0.17, 0.17, 0.16))
	_box("paint", Vector3(0.5, 0.7, 0.14), Vector3(31.2, 1.25, -5.8), Color(0.24, 0.25, 0.23))
	_box("paint", Vector3(0.1, 0.1, 0.02), Vector3(31.2, 1.35, -5.88), Color(0.3, 0.27, 0.03))
	_box("paint", Vector3(1.1, 2.2, 0.08), Vector3(27.6, 1.22, -5.74), Color(0.14, 0.18, 0.16))
	_box("metal", Vector3(1.2, 0.08, 0.1), Vector3(27.6, 2.36, -5.74), Color(0.07, 0.07, 0.07))
	_box("metal", Vector3(0.13, 0.03, 0.05), Vector3(27.2, 1.2, -5.8), Color(0.4, 0.38, 0.32))
	_box("paint", Vector3(0.42, 0.18, 0.01), Vector3(27.6, 1.85, -5.785), Color(0.42, 0.41, 0.36))
	_text("ТУАЛЕТ", Vector3(27.6, 1.85, -5.792), PI, 0.08, Color(0.06, 0.06, 0.06))
	# Крыша: кондиционеры, вытяжки и антенна
	for spec in [[27.8, 2.2], [30.6, -2.4]]:
		var q := Vector3(spec[0], top + 0.56, spec[1])
		_box("metal", Vector3(1.55, 0.72, 1.2), q, Color(0.27, 0.27, 0.25))
		_cyl("metal", 0.42, 0.04, q + Vector3(0, 0.37, 0), Color(0.05, 0.05, 0.05), 16)
		for k in 4:
			_box("metal", Vector3(0.8, 0.025, 0.05), q + Vector3(0, 0.39, 0), Color(0.11, 0.11, 0.11), Basis(Vector3.UP, float(k) * 0.78))
		_box("rust", Vector3(1.57, 0.14, 1.22), q + Vector3(0, -0.3, 0), Color(0.75, 0.6, 0.5), Basis(), 0.7)
	for q in [Vector3(25.3, top + 0.5, -2.5), Vector3(25.7, top + 0.4, 3.6)]:
		_cyl("metal", 0.1, 0.8, q, Color(0.2, 0.2, 0.19), 10)
		_cyl("metal", 0.16, 0.05, q + Vector3(0, 0.42, 0), Color(0.11, 0.11, 0.11), 10)
	_cyl("metal", 0.025, 3.8, Vector3(31.8, top + 2.1, 4.8), Color(0.2, 0.2, 0.2), 6)
	for k in 4:
		_box("metal", Vector3(0.9 - float(k) * 0.16, 0.018, 0.018), Vector3(31.8, top + 2.6 + float(k) * 0.32, 4.8), Color(0.2, 0.2, 0.2))
	# Лампы под козырьком
	for z in [-3.9, 0.0, 3.9]:
		_box("metal", Vector3(0.18, 0.05, 1.3), Vector3(x0 - 0.9, top - 0.03, z), Color(0.2, 0.2, 0.2))
		_box("tube_in", Vector3(0.12, 0.025, 1.18), Vector3(x0 - 0.9, top - 0.065, z))
	# Отлив окна, порог, резиновый коврик, поручень и наклейки на двери
	_box("metal", Vector3(0.34, 0.05, zw * 2.0), Vector3(x0 - 0.03, 0.86, 0), Color(0.21, 0.21, 0.2))
	_box("paint", Vector3(0.95, 0.018, 1.25), Vector3(x0 - 0.6, 0.128, -3.3), Color(0.02, 0.02, 0.02))
	_box("metal", Vector3(0.05, 0.05, 1.05), Vector3(x0 - 0.12, 1.08, -3.3), Color(0.42, 0.4, 0.36))
	for i in 4:
		var q := Vector3(x0 - 0.06, 1.25 + float(i % 2) * 0.13, -3.75 + float(i) * 0.26)
		_box("paint", Vector3(0.006, 0.09, 0.16), q, [Color(0.05, 0.1, 0.3), Color(0.35, 0.05, 0.04), Color(0.3, 0.24, 0.05), Color(0.05, 0.2, 0.1)][i])
	# Скамейка с пепельницей
	var bench := Vector3(x0 - 1.2, 0.0, 1.9)
	for i in 3:
		_box("paint", Vector3(0.14, 0.03, 1.8), bench + Vector3(-0.15 + float(i) * 0.16, 0.52, 0), Color(0.11, 0.07, 0.04))
	for i in 2:
		_box("paint", Vector3(0.1, 0.03, 1.8), bench + Vector3(0.24, 0.82 + float(i) * 0.15, 0), Color(0.11, 0.07, 0.04))
	for z in [-0.75, 0.75]:
		_box("metal", Vector3(0.48, 0.5, 0.05), bench + Vector3(0, 0.26, z), Color(0.05, 0.05, 0.05))
	_cyl("metal", 0.14, 0.8, Vector3(x0 - 1.1, 0.48, 3.1), Color(0.11, 0.11, 0.1), 10)
	_cyl("paint", 0.12, 0.012, Vector3(x0 - 1.1, 0.885, 3.1), Color(0.34, 0.31, 0.24), 10)
	# Газетный ящик, стойка масел и канистры
	_box("paint", Vector3(0.48, 0.92, 0.46), Vector3(x0 - 1.2, 0.56, -1.0), Color(0.04, 0.09, 0.2))
	_box("glass", Vector3(0.012, 0.4, 0.38), Vector3(x0 - 1.45, 0.72, -1.0))
	_box("paint", Vector3(0.006, 0.34, 0.3), Vector3(x0 - 1.44, 0.72, -1.0), Color(0.4, 0.39, 0.34))
	for k in 3:
		_box("metal", Vector3(0.42, 0.025, 1.2), Vector3(x0 - 0.45, 0.45 + float(k) * 0.38, 0.0), Color(0.08, 0.08, 0.08))
		for n in 9:
			var q := Vector3(x0 - 0.5, 0.56 + float(k) * 0.38, -0.5 + float(n) * 0.125)
			_box("paint", Vector3(0.11, 0.2, 0.1), q, [Color(0.3, 0.13, 0.02), Color(0.04, 0.09, 0.22), Color(0.2, 0.17, 0.04)][k])
	for i in 6:
		var q := Vector3(x0 - 0.6 - float(i % 2) * 0.38, 0.3, -2.0 - float(i / 2) * 0.32)
		_box("paint", Vector3(0.28, 0.38, 0.18), q, Color(0.26, 0.05, 0.03))
		_cyl("metal", 0.03, 0.08, q + Vector3(0.05, 0.22, 0), Color(0.08, 0.08, 0.08), 6)
	# Клетка с газовыми баллонами
	var cage := Vector3(24.0, 0.0, 7.4)
	for ix in 4:
		_box("metal", Vector3(0.04, 1.6, 0.04), cage + Vector3(-1.05 + float(ix) * 0.7, 0.8, -0.45), Color(0.16, 0.16, 0.15))
		_box("metal", Vector3(0.04, 1.6, 0.04), cage + Vector3(-1.05 + float(ix) * 0.7, 0.8, 0.45), Color(0.16, 0.16, 0.15))
	for yy in [0.2, 0.8, 1.55]:
		_box("metal", Vector3(2.15, 0.04, 0.04), cage + Vector3(0, yy, 0.45), Color(0.16, 0.16, 0.15))
		_box("metal", Vector3(2.15, 0.04, 0.04), cage + Vector3(0, yy, -0.45), Color(0.16, 0.16, 0.15))
	for i in 6:
		var q := cage + Vector3(-0.78 + float(i % 3) * 0.78, 0.45, -0.2 + float(i / 3) * 0.42)
		_cyl("paint", 0.17, 0.72, q, Color(0.42, 0.41, 0.37), 12)
		_cyl("metal", 0.05, 0.1, q + Vector3(0, 0.4, 0), Color(0.11, 0.11, 0.1), 8)
	_box("paint", Vector3(0.7, 0.26, 0.01), cage + Vector3(0, 1.2, 0.47), Color(0.32, 0.04, 0.03))
	_text("ГАЗ", cage + Vector3(0, 1.2, 0.477), 0.0, 0.16, Color(0.76, 0.72, 0.62))
	# Поддоны и коробки у контейнера
	for i in 3:
		var q := Vector3(28.6, 0.08 + float(i) * 0.15, 9.7)
		_box("paint", Vector3(1.2, 0.05, 1.0), q, Color(0.14, 0.1, 0.06), Basis(Vector3.UP, float(i) * 0.08))
		_box("paint", Vector3(1.2, 0.06, 0.09), q + Vector3(0, -0.055, 0.42), Color(0.1, 0.07, 0.04))
		_box("paint", Vector3(1.2, 0.06, 0.09), q + Vector3(0, -0.055, -0.42), Color(0.1, 0.07, 0.04))
	# Колючая проволока по забору и табличка на будке
	for i in 15:
		_box("metal", Vector3(0.012, 0.012, 2.5), Vector3(35.5, 2.15 + (float(i % 2) * 0.05), -15.0 + float(i) * 2.2), Color(0.08, 0.08, 0.08), Basis(Vector3.RIGHT, 0.08 if i % 2 == 0 else -0.08))
	_text("ТЕЛЕФОН", Vector3(19.34, 2.1, -10.6), -PI * 0.5, 0.11, Color(0.68, 0.66, 0.58))


func _detail_interior() -> void:
	var f := FLOOR_Y
	var rng := RandomNumberGenerator.new()
	rng.seed = 7023
	# Подвесной потолок: решётка и несколько грязных или выпавших плит
	var x := 22.2
	while x < 33.0:
		_box("metal", Vector3(0.02, 0.012, 11.0), Vector3(x, 3.195, 0), Color(0.16, 0.16, 0.14))
		x += 0.6
	var z := -5.4
	while z < 5.5:
		_box("metal", Vector3(10.8, 0.012, 0.02), Vector3(27.6, 3.195, z), Color(0.16, 0.16, 0.14))
		z += 0.6
	for i in 9:
		var q := Vector3(22.5 + float(rng.randi_range(0, 17)) * 0.6, 3.19, -5.1 + float(rng.randi_range(0, 17)) * 0.6)
		_box("paint", Vector3(0.58, 0.01, 0.58), q, Color(0.02, 0.018, 0.015) if i < 2 else Color(0.2, 0.17, 0.11))
	# Швы плитки на полу
	x = 22.1
	while x < 33.0:
		_box("paint", Vector3(0.012, 0.002, 11.0), Vector3(x, f + 0.012, 0), Color(0.018, 0.018, 0.016))
		x += 0.45
	z = -5.5
	while z < 5.6:
		_box("paint", Vector3(10.9, 0.002, 0.012), Vector3(27.5, f + 0.012, z), Color(0.018, 0.018, 0.016))
		z += 0.45
	# Плинтус, потёртая дорожка от двери к кассе, чёрные следы на полу
	for s in [-1.0, 1.0]:
		_box("paint", Vector3(10.9, 0.14, 0.02), Vector3(27.5, f + 0.07, 5.47 * s), Color(0.05, 0.05, 0.045))
	_box("paint", Vector3(10.9, 0.14, 0.02), Vector3(27.5, f + 0.07, 5.47), Color(0.05, 0.05, 0.045))
	for i in 34:
		var q := Vector3(rng.randf_range(22.8, 26.0), f + 0.012, rng.randf_range(-3.4, 1.0))
		_box("paint", Vector3(rng.randf_range(0.06, 0.28), 0.002, 0.02), q, Color(0.012, 0.012, 0.012), Basis(Vector3.UP, rng.randf() * TAU))
	# Лицевая панель прилавка и витрина со сладостями
	for i in 5:
		_box("paint", Vector3(0.02, 0.76, 0.9), Vector3(24.62, f + 0.41, -0.05 + float(i) * 0.93), Color(0.11, 0.07, 0.045))
	for k in 2:
		_box("metal", Vector3(0.18, 0.02, 1.8), Vector3(24.5, f + 0.32 + float(k) * 0.26, 1.15), Color(0.13, 0.13, 0.12))
		for n in 14:
			_box("paint", Vector3(0.11, 0.17, 0.09), Vector3(24.5, f + 0.42 + float(k) * 0.26, 0.38 + float(n) * 0.118), _goods_color(rng).lightened(0.15))
	# Монитор камер на прилавке, стойка лотереи, стакан с ручками, рация и пепельница
	_box("paint", Vector3(0.36, 0.3, 0.42), Vector3(25.18, f + 1.02, 3.72), Color(0.05, 0.05, 0.05), Basis(Vector3.UP, 0.25))
	_box("fridge", Vector3(0.012, 0.21, 0.31), Vector3(24.995, f + 1.03, 3.68), Color(0.22, 0.26, 0.28), Basis(Vector3.UP, 0.25))
	_text("КАМ 04", Vector3(24.985, f + 1.11, 3.68), -PI * 0.5 + 0.25, 0.024, Color(0.75, 0.82, 0.8))
	_box("paint", Vector3(0.05, 0.42, 0.34), Vector3(24.78, f + 1.07, 2.15), Color(0.17, 0.03, 0.02), Basis(Vector3.BACK, 0.08))
	for k in 3:
		_box("paint", Vector3(0.006, 0.1, 0.28), Vector3(24.75, f + 0.96 + float(k) * 0.12, 2.15), Color(0.3, 0.27, 0.06))
	_cyl("metal", 0.035, 0.1, Vector3(24.86, f + 0.91, 3.05), Color(0.08, 0.08, 0.08), 8)
	for k in 3:
		_box("paint", Vector3(0.008, 0.14, 0.008), Vector3(24.86 + float(k) * 0.012, f + 0.97, 3.04 + float(k) * 0.012), Color(0.03, 0.05, 0.2))
	_box("paint", Vector3(0.1, 0.17, 0.2), Vector3(25.08, f + 0.95, 3.25), Color(0.06, 0.06, 0.06))
	_cyl("metal", 0.004, 0.2, Vector3(25.1, f + 1.14, 3.32), Color(0.3, 0.3, 0.3), 5)
	_cyl("paint", 0.065, 0.025, Vector3(25.05, f + 0.875, 0.2), Color(0.24, 0.23, 0.2), 10)
	for k in 4:
		_box("paint", Vector3(0.05, 0.01, 0.01), Vector3(25.05, f + 0.892, 0.17 + float(k) * 0.02), Color(0.42, 0.36, 0.26), Basis(Vector3.UP, float(k)))
	# Рулон чека торчит из кассы
	_box("paint", Vector3(0.008, 0.2, 0.06), Vector3(24.83, f + 1.02, 0.5), Color(0.5, 0.48, 0.42))
	# Табуретка за прилавком
	_cyl("paint", 0.17, 0.05, Vector3(26.25, f + 0.68, 3.2), Color(0.1, 0.03, 0.02), 12)
	_cyl("metal", 0.025, 0.65, Vector3(26.25, f + 0.33, 3.2), Color(0.16, 0.16, 0.15), 8)
	# Над стойкой: вывеска, календарь, зеркало
	_box("paint", Vector3(0.05, 0.28, 4.2), Vector3(26.79, f + 2.32, 1.8), Color(0.2, 0.03, 0.02))
	_text("ТАБАК", Vector3(26.76, f + 2.32, 1.0), -PI * 0.5, 0.17, Color(0.72, 0.68, 0.56))
	_box("paint", Vector3(0.012, 0.56, 0.42), Vector3(27.09, f + 2.1, 3.5), Color(0.5, 0.48, 0.42))
	_box("paint", Vector3(0.008, 0.14, 0.42), Vector3(27.08, f + 2.3, 3.5), Color(0.28, 0.04, 0.03))
	_text("ОКТЯБРЬ\n1994", Vector3(27.075, f + 2.08, 3.5), -PI * 0.5, 0.055, Color(0.06, 0.06, 0.06))
	var mirror_b := Basis(Vector3.BACK, -PI * 0.5) * Basis(Vector3.RIGHT, 0.5)
	_cyl("metal", 0.34, 0.03, Vector3(22.42, f + 2.75, -5.2), Color(0.52, 0.56, 0.58), 18, mirror_b)
	# Камера в углу
	_box("paint", Vector3(0.2, 0.1, 0.1), Vector3(26.7, f + 2.95, -0.3), Color(0.08, 0.08, 0.08))
	_box("amber", Vector3(0.012, 0.012, 0.012), Vector3(26.58, f + 2.97, -0.3), Color(0.7, 0.05, 0.04))
	# Таблички рядов и ценники на полках
	for spec in [[Vector3(28.0, f + 2.45, -3.9), "НАПИТКИ · ЕДА"], [Vector3(28.0, f + 2.45, -1.9), "ДОРОГА · АВТО"]]:
		_box("metal", Vector3(0.02, 0.6, 0.02), spec[0] + Vector3(-1.1, 0.42, 0), Color(0.15, 0.15, 0.14))
		_box("metal", Vector3(0.02, 0.6, 0.02), spec[0] + Vector3(1.1, 0.42, 0), Color(0.15, 0.15, 0.14))
		_box("paint", Vector3(2.5, 0.28, 0.03), spec[0], Color(0.04, 0.08, 0.15))
		_text(spec[1], spec[0] + Vector3(0, 0, 0.018), 0.0, 0.13, Color(0.72, 0.72, 0.64))
	for pz in [-3.9, -1.9]:
		for lv in 4:
			for s in [-1.0, 1.0]:
				_box("paint", Vector3(6.0, 0.035, 0.008), Vector3(28.0, f + 0.2 + float(lv) * 0.46, pz + 0.425 * s), Color(0.2, 0.19, 0.16))
	# Банки и бутылки на полках и торцах рядов
	for pz in [-3.9, -1.9]:
		for lv in 2:
			for n in 24:
				var q := Vector3(25.3 + float(n) * 0.225, f + 0.3 + float(lv) * 0.46 + 0.92, pz + 0.3 * (1.0 if n % 2 == 0 else -1.0))
				if rng.randf() < 0.72:
					_cyl("paint", 0.035, 0.14, q, _goods_color(rng), 8)
	for spec in [[Vector3(24.75, f + 0.75, -3.9), Color(0.2, 0.03, 0.02)], [Vector3(24.75, f + 0.75, -1.9), Color(0.03, 0.08, 0.16)]]:
		_box("paint", Vector3(0.48, 1.5, 0.9), spec[0], spec[1])
		_box("paint", Vector3(0.012, 0.5, 0.74), spec[0] + Vector3(-0.245, 0.35, 0), Color(0.45, 0.42, 0.34))
		_text("СКИДКА", spec[0] + Vector3(-0.253, 0.42, 0), -PI * 0.5, 0.11, Color(0.3, 0.04, 0.03))
	# Холодильники: рамы дверей, ручки, полки, бутылки
	for i in 3:
		var fz := -3.9 + float(i) * 1.95
		_box("metal", Vector3(0.04, 0.05, 1.7), Vector3(31.99, f + 2.12, fz), Color(0.16, 0.16, 0.15))
		_box("metal", Vector3(0.04, 0.05, 1.7), Vector3(31.99, f + 0.16, fz), Color(0.16, 0.16, 0.15))
		_box("metal", Vector3(0.04, 2.0, 0.05), Vector3(31.99, f + 1.14, fz), Color(0.16, 0.16, 0.15))
		_cyl("metal", 0.014, 0.42, Vector3(31.95, f + 1.14, fz - 0.14), Color(0.4, 0.4, 0.36), 6)
		_box("tube_in", Vector3(0.02, 1.8, 0.03), Vector3(32.02, f + 1.14, fz + 0.8))
		for sh in 4:
			_box("metal", Vector3(0.3, 0.012, 1.62), Vector3(32.18, f + 0.28 + float(sh) * 0.44, fz), Color(0.3, 0.32, 0.33))
			for k in 11:
				_cyl("paint", 0.032, 0.2, Vector3(32.12, f + 0.39 + float(sh) * 0.44, fz - 0.68 + float(k) * 0.135), _goods_color(rng).lightened(0.1), 8)
	# Кофейный угол: стаканы, крышки, гриль для сосисок
	for k in 3:
		for n in 5:
			_cyl("paint", 0.038, 0.06, Vector3(22.72, f + 0.93 + float(n) * 0.018, -0.5 + float(k) * 0.1), Color(0.42, 0.4, 0.34), 8)
	_box("metal", Vector3(0.44, 0.13, 0.62), Vector3(22.76, f + 0.97, -2.3), Color(0.25, 0.25, 0.23))
	for k in 6:
		_cyl("metal", 0.016, 0.54, Vector3(22.62 + float(k) * 0.055, f + 1.05, -2.3), Color(0.18, 0.07, 0.03), 6, Basis(Vector3.RIGHT, PI * 0.5))
	# Журнальная стойка, корзины у двери, ведро со шваброй и знак «Мокрый пол»
	_box("metal", Vector3(0.1, 1.5, 1.3), Vector3(22.42, f + 0.75, 3.8), Color(0.11, 0.11, 0.1))
	for k in 4:
		for n in 5:
			_box("paint", Vector3(0.03, 0.27, 0.22), Vector3(22.52, f + 0.3 + float(k) * 0.33, 3.32 + float(n) * 0.24), _goods_color(rng).lightened(0.25), Basis(Vector3.BACK, -0.14))
	for k in 5:
		_box("metal", Vector3(0.36, 0.03, 0.46), Vector3(22.6, f + 0.1 + float(k) * 0.04, -4.75), Color(0.2, 0.03, 0.02))
	_cyl("paint", 0.16, 0.3, Vector3(30.8, f + 0.15, 4.9), Color(0.3, 0.24, 0.03), 12)
	_cyl("paint", 0.016, 1.3, Vector3(30.86, f + 0.72, 4.9), Color(0.3, 0.25, 0.15), 6, Basis(Vector3.BACK, 0.12))
	_box("paint", Vector3(0.02, 0.62, 0.3), Vector3(29.9, f + 0.32, 3.9), Color(0.34, 0.27, 0.03), Basis(Vector3.BACK, 0.16))
	_text("МОКРЫЙ\nПОЛ", Vector3(29.885, f + 0.36, 3.9), -PI * 0.5, 0.042, Color(0.04, 0.04, 0.03))
	# Коробки с товаром у подсобки
	for spec in [[Vector3(31.0, f + 0.21, 2.9), 0.4], [Vector3(31.0, f + 0.63, 2.86), 0.1], [Vector3(30.5, f + 0.21, 3.1), 0.9]]:
		_box("paint", Vector3(0.48, 0.42, 0.6), spec[0], Color(0.26, 0.17, 0.09), Basis(Vector3.UP, spec[1]))
		_box("paint", Vector3(0.486, 0.05, 0.1), spec[0] + Vector3(0, 0.19, 0), Color(0.42, 0.36, 0.24), Basis(Vector3.UP, spec[1]))
	# Объявления и плакат на стене у туалета
	_box("paint", Vector3(0.7, 0.9, 0.01), Vector3(26.0, f + 1.8, -5.46), Color(0.06, 0.15, 0.1))
	_text("ДОРОГИ\nНОЧЬЮ\nОПАСНЫ", Vector3(26.0, f + 1.8, -5.45), 0.0, 0.1, Color(0.7, 0.68, 0.56))


# ══════════════════════════════════════════════
#  Свет, небо, лес
# ══════════════════════════════════════════════
func _build_lights() -> void:
	# Навес: тень только от центральной лампы, чтобы не тратить FPS
	var cx := 13.0
	for spec in [[Vector3(cx - 2.3, 4.55, 0.0), true, false], [Vector3(cx + 2.3, 4.55, -4.0), false, false], [Vector3(cx - 2.3, 4.55, 4.0), false, true], [Vector3(cx + 2.3, 4.55, 4.0), false, false]]:
		var l := SpotLight3D.new()
		l.position = spec[0]
		l.rotation_degrees.x = -90.0
		l.spot_range = 13.0
		l.spot_angle = 68.0
		l.spot_attenuation = 0.9
		l.light_energy = 9.0
		l.light_color = Color(0.84, 0.95, 1.0)
		l.shadow_enabled = spec[1]
		add_child(l)
		if spec[2]:
			_flicker_light = l
			_flicker_energy = l.light_energy
	# Магазин: зеленоватые лампы и свет на бетоне перед окнами
	for x in [25.0, 30.0]:
		var o := OmniLight3D.new()
		o.position = Vector3(x, 2.9, 0.0)
		o.omni_range = 9.0
		o.omni_attenuation = 0.8
		o.light_energy = 1.7
		o.light_color = Color(1.0, 0.96, 0.82)
		add_child(o)
	var face := OmniLight3D.new()
	face.position = Vector3(24.1, 2.45, 1.8)
	face.omni_range = 3.6
	face.light_energy = 1.05
	face.light_color = Color(1.0, 0.95, 0.82)
	add_child(face)
	var awning := OmniLight3D.new()
	awning.position = Vector3(21.1, 3.2, 0.0)
	awning.omni_range = 6.5
	awning.light_energy = 1.1
	awning.light_color = Color(1.0, 0.95, 0.8)
	add_child(awning)
	var spill := SpotLight3D.new()
	spill.position = Vector3(23.2, 2.8, 0.0)
	spill.rotation_degrees = Vector3(-38.0, 90.0, 0.0)
	spill.spot_range = 11.0
	spill.spot_angle = 62.0
	spill.light_energy = 2.2
	spill.light_color = Color(1.0, 0.95, 0.8)
	add_child(spill)
	# Вывеска подкрашивает бетон красным, стела светит на обочину
	var red := OmniLight3D.new()
	red.position = Vector3(20.0, 3.4, 0.0)
	red.omni_range = 5.5
	red.light_energy = 0.9
	red.light_color = Color(1.0, 0.25, 0.12)
	add_child(red)
	var pylon := OmniLight3D.new()
	pylon.position = Vector3(7.2, 8.5, -11.8)
	pylon.omni_range = 11.0
	pylon.light_energy = 1.3
	pylon.light_color = Color(1.0, 0.72, 0.42)
	add_child(pylon)


# Мотыльки у ламп навеса
func _build_moths() -> void:
	var p := GPUParticles3D.new()
	p.position = Vector3(13.0, 4.0, 0.0)
	p.amount = 26
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.visibility_aabb = AABB(Vector3(-6, -3, -9), Vector3(12, 5, 18))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(3.5, 0.5, 6.0)
	pm.gravity = Vector3.ZERO
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 3.0
	pm.turbulence_noise_scale = 1.6
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.032, 0.032)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.76, 0.66)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)


func _setup_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.016, 0.035)
	sky_mat.sky_horizon_color = Color(0.03, 0.04, 0.07)
	sky_mat.ground_bottom_color = Color(0.01, 0.012, 0.02)
	sky_mat.ground_horizon_color = Color(0.03, 0.04, 0.07)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.12, 0.15, 0.22)
	e.ambient_light_energy = 0.5
	e.fog_enabled = true
	e.fog_light_color = Color(0.035, 0.05, 0.08)
	e.fog_density = 0.0085
	e.glow_enabled = true
	e.glow_bloom = 0.06
	e.glow_intensity = 0.75
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.1
	env.environment = e
	add_child(env)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-42.0, -35.0, 0.0)
	moon.light_color = Color(0.5, 0.62, 0.85)
	moon.light_energy = 0.3
	moon.shadow_enabled = false
	add_child(moon)


func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 40711
	var chunks := {}
	var z := -320.0
	while z < 320.0:
		for side in [-1.0, 1.0]:
			for row in 4:
				var base := 9.4
				# Справа лес отступает от заправки, но стоит сразу за забором
				if side > 0.0 and absf(z) < 26.0:
					base = 38.5
				elif side > 0.0 and z > 0.0 and z < 76.0:
					base = 17.0
				elif side < 0.0 and absf(z) < 30.0:
					base = 15.0
				var x: float = side * (base + row * 6.0 + rng.randf_range(-1.2, 1.6))
				var tz := z + rng.randf_range(-1.9, 1.9)
				var h := rng.randf_range(8.5, 14.5)
				var big := h > 10.5
				var key := [int(floor(tz / 30.0)), side, big]
				if not chunks.has(key):
					chunks[key] = []
				chunks[key].append([Vector3(x, 0.0, tz), Vector3(h * 0.5, h, h * 0.5), rng.randf() * TAU])
		z += 4.5
	for key in chunks:
		NatureKit.add_spruce_chunk(self, chunks[key], key[2], posmod(key[0], 3), Color.WHITE, 40.0, 200.0)
