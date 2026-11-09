class_name HouseKit
extends RefCounted

# Детали дома: двери, окна, лампы, кровь и материалы мебели.
# Меши и материалы общие, поэтому одинаковые вещи рисуются инстансингом.

const TEX := "res://assets/textures/house/"

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


static func tex(file: String) -> Texture2D:
	return TextureHelper.get_texture(TEX + file)


static func wood_mat(file: String, tint: Color = Color.WHITE, scale_uv: float = 1.3, rough: float = 0.82) -> StandardMaterial3D:
	var key := "wood_%s_%s_%.2f" % [file, tint.to_html(false), scale_uv]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(file)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale_uv
	m.roughness = rough
	m.metallic_specular = 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	TextureHelper.upgrade_material(m, file)
	_mats[key] = m
	return m


static func metal_mat(tint: Color, rough: float = 0.5) -> StandardMaterial3D:
	var key := "metal_%s_%.2f" % [tint.to_html(false), rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.metallic = 0.85
	m.roughness = rough
	_mats[key] = m
	return m


static func _box(g: NatureKit.Geo, c: Vector3, size: Vector3, col: Color = Color.WHITE, rz: float = 0.0) -> void:
	g.box(Transform3D(Basis(Vector3.BACK, rz), c), size, col)


# ─── ДВЕРЬ ────────────────────────────────────────────────────────────────────

# Полотно с четырьмя филёнками: шарнир в x = 0, низ в y = 0
static func door_leaf_mesh(w: float, h: float) -> ArrayMesh:
	var key := "leaf_%.2f_%.2f" % [w, h]
	if _meshes.has(key):
		return _meshes[key]
	var wood := NatureKit.Geo.new()
	var t := 0.05
	var sw := 0.12
	var rail_top := 0.13
	var rail_mid := 0.17
	var rail_low := 0.24
	var cx := w * 0.5
	var mid_y := h * 0.44
	for x in [sw * 0.5, w - sw * 0.5]:
		_box(wood, Vector3(x, h * 0.5, 0.0), Vector3(sw, h, t))
	_box(wood, Vector3(cx, h - rail_top * 0.5, 0.0), Vector3(w - sw * 2.0, rail_top, t))
	_box(wood, Vector3(cx, mid_y, 0.0), Vector3(w - sw * 2.0, rail_mid, t))
	_box(wood, Vector3(cx, rail_low * 0.5, 0.0), Vector3(w - sw * 2.0, rail_low, t))
	_box(wood, Vector3(cx, (rail_low + h - rail_top) * 0.5, 0.0), Vector3(0.1, h - rail_top - rail_low, t))
	# Филёнки утоплены, вокруг них рамка-штапик, которая ловит свет
	var inner_w := (w - sw * 2.0 - 0.1) * 0.5
	var ys := [
		[rail_low, mid_y - rail_mid * 0.5],
		[mid_y + rail_mid * 0.5, h - rail_top],
	]
	var shade := Color(0.72, 0.72, 0.72)
	for span in ys:
		var y0: float = span[0]
		var y1: float = span[1]
		var ph := y1 - y0
		for x in [sw + inner_w * 0.5, w - sw - inner_w * 0.5]:
			_box(wood, Vector3(x, y0 + ph * 0.5, 0.0), Vector3(inner_w, ph, t * 0.42), shade)
			for s in [-1.0, 1.0]:
				_box(wood, Vector3(x, y0 + 0.012, s * t * 0.34), Vector3(inner_w, 0.024, t * 0.2))
				_box(wood, Vector3(x, y1 - 0.012, s * t * 0.34), Vector3(inner_w, 0.024, t * 0.2))
				_box(wood, Vector3(x - inner_w * 0.5 + 0.012, y0 + ph * 0.5, s * t * 0.34), Vector3(0.024, ph, t * 0.2))
				_box(wood, Vector3(x + inner_w * 0.5 - 0.012, y0 + ph * 0.5, s * t * 0.34), Vector3(0.024, ph, t * 0.2))

	var iron := NatureKit.Geo.new()
	# Петли со стороны шарнира
	for y in [0.24, h * 0.5, h - 0.24]:
		_box(iron, Vector3(0.012, y, t * 0.5), Vector3(0.05, 0.13, 0.012))
		_box(iron, Vector3(0.012, y, -t * 0.5), Vector3(0.05, 0.13, 0.012))
	# Ручка, накладка и скважина с обеих сторон
	var hx := w - 0.075
	for s in [-1.0, 1.0]:
		_box(iron, Vector3(hx, 1.0, s * (t * 0.5 + 0.004)), Vector3(0.052, 0.21, 0.008))
		iron.cyl(Transform3D(Basis(Vector3.RIGHT, s * PI * 0.5), Vector3(hx, 1.04, s * t * 0.5)), 0.012, 0.012, 0.045, 8, Color.WHITE)
		_box(iron, Vector3(hx - 0.04, 1.04, s * (t * 0.5 + 0.052)), Vector3(0.11, 0.024, 0.024))
		_box(iron, Vector3(hx, 0.95, s * (t * 0.5 + 0.009)), Vector3(0.012, 0.03, 0.002), Color(0.05, 0.05, 0.05))

	var mesh := ArrayMesh.new()
	wood.commit(mesh, wood_mat("wood_door.png", Color.WHITE, 1.2, 0.68))
	iron.commit(mesh, metal_mat(Color(0.34, 0.27, 0.17), 0.42))
	_meshes[key] = mesh
	return mesh


# Коробка и наличники: перекрывают стык двери со стеной с обеих сторон
static func door_frame_mesh(w: float, h: float, depth: float) -> ArrayMesh:
	var key := "frame_%.2f_%.2f_%.2f" % [w, h, depth]
	if _meshes.has(key):
		return _meshes[key]
	var g := NatureKit.Geo.new()
	var j := 0.05
	for s in [-1.0, 1.0]:
		_box(g, Vector3(s * (w * 0.5 - j * 0.5), h * 0.5, 0.0), Vector3(j, h, depth))
	_box(g, Vector3(0.0, h - j * 0.5, 0.0), Vector3(w, j, depth))
	var cas := 0.1
	for z in [-depth * 0.5 - 0.012, depth * 0.5 + 0.012]:
		for s in [-1.0, 1.0]:
			_box(g, Vector3(s * (w * 0.5 + cas * 0.5 - j), h * 0.5 + 0.03, z), Vector3(cas, h + 0.06, 0.024))
		_box(g, Vector3(0.0, h + 0.03 + 0.03, z), Vector3(w + cas * 2.0 - j * 2.0 + 0.06, 0.12, 0.03))
	var mesh := ArrayMesh.new()
	g.commit(mesh, wood_mat("wood_door.png", Color(0.62, 0.58, 0.54), 1.0))
	_meshes[key] = mesh
	return mesh


# ─── ЛОМ ──────────────────────────────────────────────────────────────────────

# Гвоздодёр вдоль оси X: красная рукоять, серое кольцо, чёрный стержень, изогнутая лапа
static func crowbar_mesh() -> ArrayMesh:
	if _meshes.has("crowbar"):
		return _meshes["crowbar"]
	var red := NatureKit.Geo.new()
	var black := NatureKit.Geo.new()
	var steel := NatureKit.Geo.new()
	_rod(red, Vector3(-0.355, -0.018, 0), Vector3(-0.3, 0.0, 0), 0.006, 0.019)
	_rod(red, Vector3(-0.3, 0.0, 0), Vector3(0.02, 0.0, 0), 0.019, 0.022)
	_rod(steel, Vector3(0.02, 0.0, 0), Vector3(0.036, 0.0, 0), 0.023, 0.023)
	var pts := [Vector3(0.036, 0, 0), Vector3(0.235, 0, 0), Vector3(0.285, 0.026, 0), Vector3(0.325, 0.07, 0), Vector3(0.334, 0.108, 0), Vector3(0.306, 0.132, 0), Vector3(0.262, 0.128, 0)]
	for i in range(pts.size() - 1):
		_rod(black, pts[i], pts[i + 1], 0.021 - i * 0.0012, 0.021 - (i + 1) * 0.0012)
	# Раздвоенная лапа: плоская, с вырезом посередине и светлой заточкой
	var claw_tilt := -0.3
	for s in [-1.0, 1.0]:
		_box(black, Vector3(0.232, 0.118, s * 0.015), Vector3(0.07, 0.012, 0.022), Color.WHITE, claw_tilt)
		_box(steel, Vector3(0.189, 0.104, s * 0.015), Vector3(0.024, 0.006, 0.02), Color.WHITE, claw_tilt)
	_box(black, Vector3(0.262, 0.127, 0.0), Vector3(0.03, 0.016, 0.052), Color.WHITE, claw_tilt)
	# Кончик рукояти чёрный, как у настоящего лома
	_rod(black, Vector3(-0.372, -0.034, 0), Vector3(-0.355, -0.018, 0), 0.002, 0.0065)
	var mesh := ArrayMesh.new()
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.72, 0.045, 0.035)
	rm.metallic = 0.25
	rm.roughness = 0.34
	red.commit(mesh, rm)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.028, 0.028, 0.032)
	bm.metallic = 0.65
	bm.roughness = 0.42
	black.commit(mesh, bm)
	steel.commit(mesh, metal_mat(Color(0.62, 0.63, 0.65), 0.3))
	_meshes["crowbar"] = mesh
	return mesh


# Гранёный стержень между двумя точками
static func _rod(g: NatureKit.Geo, a: Vector3, b: Vector3, r0: float, r1: float) -> void:
	var d := b - a
	var y := d.normalized()
	var x := Vector3.BACK.cross(y).normalized()
	var z := x.cross(y).normalized()
	g.cyl(Transform3D(Basis(x, y, z), a), r0, r1, d.length(), 8, Color.WHITE)


# ─── ОКНА ─────────────────────────────────────────────────────────────────────

# Окно единичного размера: низ в y = 0, лицо смотрит в +Z.
# Варианты отличаются тем, как именно его заколотили.
static func window_mesh(variant: int) -> ArrayMesh:
	var key := "win_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var frame := NatureKit.Geo.new()
	var boards := NatureKit.Geo.new()
	var nails := NatureKit.Geo.new()
	var glass := NatureKit.Geo.new()
	# Рама, импост и горбыльки
	var d := 0.06
	for s in [-1.0, 1.0]:
		_box(frame, Vector3(s * 0.46, 0.5, d * 0.5), Vector3(0.08, 1.0, d))
	_box(frame, Vector3(0.0, 0.96, d * 0.5), Vector3(1.0, 0.08, d))
	_box(frame, Vector3(0.0, 0.04, d * 0.6), Vector3(1.08, 0.08, d * 1.3))
	_box(frame, Vector3(0.0, 0.5, d * 0.45), Vector3(0.035, 0.86, d * 0.6))
	_box(frame, Vector3(0.0, 0.5, d * 0.45), Vector3(0.84, 0.03, d * 0.6))
	_box(glass, Vector3(0.0, 0.5, 0.012), Vector3(0.86, 0.86, 0.004))

	var layout: Array = []
	match variant:
		0:
			layout = [[0.26, 1.08, 0.13, 0.03], [0.5, 1.1, 0.14, -0.05], [0.75, 1.06, 0.12, 0.04]]
		1:
			layout = [[0.5, 1.2, 0.12, 0.78], [0.5, 1.2, 0.12, -0.78]]
		2:
			# Сплошь закрыто, между досками щели, одна отломана
			var xs := [-0.36, -0.18, 0.0, 0.18, 0.36]
			for i in range(5):
				var ln := 1.06 if i != 3 else 0.5
				var cy := 0.5 if i != 3 else 0.25
				_box(boards, Vector3(xs[i], cy, 0.08), Vector3(0.15, ln, 0.024), Color(0.9 + i * 0.03, 0.9 + i * 0.03, 0.9 + i * 0.03), 0.015 * (i - 2))
				for ny in [cy - ln * 0.42, cy + ln * 0.42]:
					_box(nails, Vector3(xs[i], ny, 0.094), Vector3(0.016, 0.016, 0.006))
			_box(boards, Vector3(0.0, 0.76, 0.1), Vector3(1.1, 0.1, 0.022), Color(0.82, 0.82, 0.82), 0.02)
		3:
			# Наспех: две доски и обломок, сверху видно разбитое стекло
			layout = [[0.34, 1.12, 0.15, -0.16], [0.56, 1.04, 0.12, 0.09], [0.14, 0.55, 0.1, 0.05]]
			_box(frame, Vector3(-0.2, 0.74, 0.02), Vector3(0.24, 0.018, 0.006), Color(0.02, 0.02, 0.02), 0.7)
			_box(frame, Vector3(0.22, 0.8, 0.02), Vector3(0.2, 0.018, 0.006), Color(0.02, 0.02, 0.02), -0.5)
	var idx := 0
	for b in layout:
		var cy: float = b[0]
		var ln: float = b[1]
		var ht: float = b[2]
		var rz: float = b[3]
		var tone := 0.86 + 0.14 * sin(float(idx) * 2.1 + float(variant))
		_box(boards, Vector3(0.0, cy, 0.075 + idx * 0.024), Vector3(ln, ht, 0.022), Color(tone, tone, tone), rz)
		var dir := Vector2(cos(rz), sin(rz))
		for sx in [-0.44, 0.44]:
			if abs(sx) < ln * 0.5:
				var cn := Vector3(dir.x * sx, cy + dir.y * sx, 0.075 + idx * 0.024 + 0.014)
				_box(nails, cn, Vector3(0.018, 0.018, 0.006))
		idx += 1

	var mesh := ArrayMesh.new()
	frame.commit(mesh, wood_mat("board_weathered.png", Color(0.42, 0.40, 0.38), 1.6))
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.015, 0.02, 0.028)
	gm.metallic = 0.7
	gm.roughness = 0.12
	glass.commit(mesh, gm)
	boards.commit(mesh, wood_mat("board_weathered.png", Color.WHITE, 1.1))
	nails.commit(mesh, metal_mat(Color(0.14, 0.13, 0.12), 0.6))
	_meshes[key] = mesh
	return mesh


static func add_window(root: Node3D, variant: int) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "WindowBoarded"
	mi.mesh = window_mesh(variant)
	root.add_child(mi)


# ─── КРОВЬ ────────────────────────────────────────────────────────────────────

static func blood_mat(file: String) -> StandardMaterial3D:
	var key := "blood_" + file
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(file)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.roughness = 0.22
	m.metallic_specular = 0.6
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


static func add_blood_pool(parent: Node3D, sz: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(sz.x, sz.z)
	pm.material = blood_mat("blood_pool.png")
	mi.mesh = pm
	mi.position.y = 0.008
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func add_blood_wall(parent: Node3D, sz: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(sz.x * 1.6, sz.y * 1.3)
	q.material = blood_mat("blood_wall.png")
	mi.mesh = q
	mi.position.z = 0.006
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


# ─── МАТЕРИАЛЫ МЕБЕЛИ ─────────────────────────────────────────────────────────

const DRESSED := ["prop_table", "prop_chair", "prop_bed", "prop_wardrobe", "prop_cupboard", "prop_sofa", "prop_armchair", "prop_bookshelf", "prop_fridge", "prop_stove", "prop_kitchen_counter", "prop_toilet", "prop_sink", "prop_bathtub", "prop_bench", "prop_grandfather_clock", "prop_lamp_floor", "prop_mirror", "prop_mirror_broken", "prop_plant_pot", "prop_trash_bin", "railing_wood", "stairs_straight", "prop_crt_tv", "prop_painting", "prop_painting_moon", "prop_occult_altar", "prop_nightstand", "prop_dresser", "prop_crate", "prop_barrel"]


# Плоские цвета заменяются материалами с текстурой, одинаковые материалы становятся одним.
# Тип материала выбирается по его цвету: коричневое дерево, серый металл, белая керамика, цветная ткань.
static func dress_prefab(root: Node, type: String) -> void:
	if type.trim_prefix("custom_") == "prop_tree_dead":
		_apply_bark(root)
		return
	if not type.trim_prefix("custom_") in DRESSED:
		return
	_dress_node(root)


# Сухое дерево: настоящая кора с рельефом вместо серого цвета
static func _apply_bark(n: Node) -> void:
	if n is MeshInstance3D and n.mesh != null and not (n.mesh is ArrayMesh):
		if not _mats.has("dead_bark"):
			var m := StandardMaterial3D.new()
			m.albedo_texture = NatureKit._tex("rock_tile.png")
			m.normal_enabled = true
			m.normal_texture = NatureKit._tex("rock_tile_n.png")
			m.normal_scale = 1.4
			m.albedo_color = Color(0.3, 0.21, 0.14)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3(1.6, 0.6, 1.6)
			m.roughness = 1.0
			m.metallic_specular = 0.1
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			_mats["dead_bark"] = m
		n.mesh.surface_set_material(0, _mats["dead_bark"])
	for c in n.get_children():
		_apply_bark(c)


static func _dress_node(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.mesh.get_surface_count() > 0 and not (mi.mesh is ArrayMesh):
			var src := mi.mesh.surface_get_material(0) as StandardMaterial3D
			if src != null and src.albedo_texture == null:
				var nm := _dressed_material(src)
				if nm != null:
					mi.mesh.surface_set_material(0, nm)
	for c in n.get_children():
		_dress_node(c)


static func _dressed_material(src: StandardMaterial3D) -> StandardMaterial3D:
	if src.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or src.emission_enabled:
		return src
	var c := src.albedo_color
	var file := ""
	var tint := c
	var rough := src.roughness
	var metal := src.metallic
	var uv := 2.0
	if c.h > 0.09 and c.h < 0.18 and c.s > 0.5 and c.v > 0.55 and metal > 0.4:
		# Золотая рама и латунь выглядели как игрушка: старая потемневшая бронза
		tint = Color(0.2, 0.15, 0.09)
		metal = 0.35
		rough = 0.68
		file = "metal_worn.png"
	elif metal > 0.45:
		file = "metal_worn.png"
		uv = 3.0
	elif c.v > 0.68 and c.s < 0.16:
		# Керамика и эмаль: чуть пожелтевшая, с грязью
		tint = c.darkened(0.1)
		tint.b *= 0.95
		file = ""
		rough = minf(rough, 0.28)
		uv = 1.0
	elif c.s < 0.2:
		file = "metal_worn.png" if c.v < 0.4 else "concrete.png"
		tint = Color(c.r * 1.4, c.g * 1.4, c.b * 1.4)
	elif c.h < 0.14 or c.h > 0.97:
		if c.v < 0.75 and c.s > 0.28 and c.s < 0.92:
			file = "wood_furniture.png"
			tint = Color(c.r * 1.3, c.g * 1.22, c.b * 1.15)
		else:
			file = "fabric.png"
			uv = 7.0
	else:
		file = "fabric.png"
		uv = 7.0
	var key := "dress_%s_%s_%.1f_%.1f_%.0f" % [file, tint.to_html(false), rough, metal, uv]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	if file != "":
		m.albedo_texture = tex(file)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * uv
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = src.cull_mode
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if file != "":
		TextureHelper.upgrade_material(m, file)
	_mats[key] = m
	return m


# ─── ШКАФ ─────────────────────────────────────────────────────────────────────

# Старый двустворчатый шкаф: филёнки, ступенчатый карниз, ножки, бронзовая фурнитура.
# Внутри он полый, а на уровне глаз между створками оставлена щель, из неё смотрит спрятавшийся игрок.
static func add_wardrobe_body(body: Node3D, ghost: bool) -> void:
	var carcass: Array = []
	var frame: Array = []
	var panel: Array = []
	var crown: Array = []
	var bronze: Array = []
	# Корпус
	carcass.append(_wbox(Vector3(0.07, 2.0, 0.62), Vector3(-0.615, 1.14, 0)))
	carcass.append(_wbox(Vector3(0.07, 2.0, 0.62), Vector3(0.615, 1.14, 0)))
	carcass.append(_wbox(Vector3(1.16, 2.0, 0.05), Vector3(0, 1.14, -0.285)))
	carcass.append(_wbox(Vector3(1.16, 0.07, 0.62), Vector3(0, 2.1, 0)))
	carcass.append(_wbox(Vector3(1.16, 0.07, 0.62), Vector3(0, 0.205, 0)))
	var inside: Array = [_wbox(Vector3(1.16, 1.86, 0.006), Vector3(0, 1.14, -0.257))]
	# Цоколь и ножки
	crown.append(_wbox(Vector3(1.36, 0.1, 0.67), Vector3(0, 0.19, 0)))
	crown.append(_wbox(Vector3(1.42, 0.035, 0.7), Vector3(0, 0.15, 0.005)))
	for x: float in [-0.61, 0.61]:
		for z: float in [-0.25, 0.26]:
			crown.append(_wbox(Vector3(0.15, 0.135, 0.15), Vector3(x, 0.0675, z)))
	# Ступенчатый карниз
	crown.append(_wbox(Vector3(1.34, 0.05, 0.665), Vector3(0, 2.115, 0.0)))
	crown.append(_wbox(Vector3(1.4, 0.04, 0.7), Vector3(0, 2.16, 0.012)))
	crown.append(_wbox(Vector3(1.47, 0.055, 0.735), Vector3(0, 2.207, 0.02)))
	crown.append(_wbox(Vector3(0.62, 0.05, 0.05), Vector3(0, 2.26, 0.355)))
	# Боковые филёнки
	for s: float in [-1.0, 1.0]:
		panel.append(_wbox(Vector3(0.012, 1.62, 0.44), Vector3(s * 0.654, 1.15, 0.0)))
	# Рама фасада
	for s: float in [-1.0, 1.0]:
		frame.append(_wbox(Vector3(0.1, 1.86, 0.04), Vector3(s * 0.625, 1.17, 0.315)))
	frame.append(_wbox(Vector3(1.15, 0.05, 0.04), Vector3(0, 2.085, 0.315)))
	frame.append(_wbox(Vector3(1.15, 0.05, 0.04), Vector3(0, 0.255, 0.315)))
	# Створки
	for s: float in [-1.0, 1.0]:
		carcass.append(_wbox(Vector3(0.56, 1.14, 0.022), Vector3(s * 0.285, 0.85, 0.316)))
		carcass.append(_wbox(Vector3(0.505, 0.62, 0.022), Vector3(s * 0.3125, 1.75, 0.316)))
		frame.append(_wbox(Vector3(0.095, 1.78, 0.03), Vector3(s * 0.5175, 1.17, 0.337)))
		frame.append(_wbox(Vector3(0.095, 1.2, 0.03), Vector3(s * 0.0525, 0.86, 0.337)))
		frame.append(_wbox(Vector3(0.09, 0.68, 0.03), Vector3(s * 0.105, 1.72, 0.337)))
		frame.append(_wbox(Vector3(0.37, 0.1, 0.03), Vector3(s * 0.285, 0.33, 0.337)))
		frame.append(_wbox(Vector3(0.37, 0.16, 0.03), Vector3(s * 0.285, 1.38, 0.337)))
		frame.append(_wbox(Vector3(0.32, 0.1, 0.03), Vector3(s * 0.31, 2.01, 0.337)))
		# Выпуклые филёнки с тонкой фаской
		panel.append(_wbox(Vector3(0.31, 0.88, 0.016), Vector3(s * 0.285, 0.84, 0.333)))
		panel.append(_wbox(Vector3(0.25, 0.75, 0.018), Vector3(s * 0.285, 0.84, 0.345)))
		panel.append(_wbox(Vector3(0.26, 0.46, 0.016), Vector3(s * 0.31, 1.72, 0.333)))
		panel.append(_wbox(Vector3(0.2, 0.33, 0.018), Vector3(s * 0.31, 1.72, 0.345)))
		# Петли, накладка и ручка
		for y: float in [0.56, 1.88]:
			bronze.append(_wbox(Vector3(0.018, 0.085, 0.03), Vector3(s * 0.572, y, 0.34)))
		bronze.append(_wbox(Vector3(0.05, 0.15, 0.006), Vector3(s * 0.05, 1.12, 0.355)))
		var knob := SphereMesh.new()
		knob.radius = 0.021
		knob.height = 0.042
		knob.radial_segments = 8
		knob.rings = 4
		bronze.append([knob, Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 1.15, 0.378))])
		var neck := CylinderMesh.new()
		neck.top_radius = 0.008
		neck.bottom_radius = 0.008
		neck.height = 0.03
		neck.radial_segments = 6
		bronze.append([neck, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(s * 0.05, 1.15, 0.36))])
	_wardrobe_part(body, inside, "wardrobe_inside", Color(0.012, 0.009, 0.007), "wood_furniture.png", 1.0, 0.0, ghost)
	_wardrobe_part(body, carcass, "wardrobe_carcass", Color(0.17, 0.105, 0.062), "wood_furniture.png", 0.82, 0.0, ghost)
	_wardrobe_part(body, frame, "wardrobe_frame", Color(0.24, 0.15, 0.085), "wood_furniture.png", 0.72, 0.0, ghost)
	_wardrobe_part(body, panel, "wardrobe_panel", Color(0.31, 0.2, 0.115), "wood_furniture.png", 0.66, 0.0, ghost)
	_wardrobe_part(body, crown, "wardrobe_crown", Color(0.13, 0.08, 0.048), "wood_furniture.png", 0.76, 0.0, ghost)
	_wardrobe_part(body, bronze, "wardrobe_bronze", Color(0.2, 0.15, 0.09), "metal_worn.png", 0.6, 0.45, ghost)


static func _wbox(size: Vector3, pos: Vector3) -> Array:
	var box := BoxMesh.new()
	box.size = size
	return [box, Transform3D(Basis.IDENTITY, pos)]


static func _wardrobe_part(parent: Node3D, parts: Array, key: String, color: Color, file: String, rough: float, metal: float, ghost: bool) -> void:
	var st := SurfaceTool.new()
	for part in parts:
		st.append_from(part[0], 0, part[1])
	var mat_key := key + ("_ghost" if ghost else "")
	if not _mats.has(mat_key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = tex(file)
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 2.0
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		if ghost:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color.a = 0.6
		_mats[mat_key] = m
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mats[mat_key]
	parent.add_child(mi)
