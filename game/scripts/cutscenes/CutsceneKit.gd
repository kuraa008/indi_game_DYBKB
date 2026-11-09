class_name CutsceneKit
extends RefCounted

# Декорации для кат-сцен: материалы, простые меши, мебель из PrefabBuilder,
# кусок карты «Шоссе» (дом и гараж Досыма), огонь, ткань, паутина, череп и т. д.

const HOUSE := "res://assets/textures/house/"
const NATURE := "res://assets/textures/nature/"

static var _mats := {}
static var _web_tex: ImageTexture
static var _soft_tex: GradientTexture2D


# ════════════════════════════════════════════════════════════
#  Материалы
# ════════════════════════════════════════════════════════════
static func mat(col: Color, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var key := "m|%s|%.2f|%.2f" % [col.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


# Текстура с трипланарной проекцией: не тянется на коробках любого размера
static func tmat(file: String, tint: Color = Color.WHITE, uv: float = 1.0, rough: float = 0.85, normal_file: String = "") -> StandardMaterial3D:
	var path := file if file.begins_with("res://") else HOUSE + file
	var key := "t|%s|%s|%.3f|%.2f" % [path, tint.to_html(), uv, rough]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = TextureHelper.get_texture(path)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	TextureHelper.upgrade_material(m, path)
	if normal_file != "":
		var np := normal_file if normal_file.begins_with("res://") else NATURE + normal_file
		m.normal_enabled = true
		m.normal_texture = TextureHelper.get_texture(np)
	_mats[key] = m
	return m


static func glow(col: Color, energy: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col * energy
	return m


static func add_mat(col: Color, tex: Texture2D = null) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.albedo_color = col
	m.albedo_texture = tex if tex != null else soft_tex()
	m.disable_receive_shadows = true
	return m


static var _flame: ImageTexture


# Язык пламени: мягкая капля, острая сверху
static func flame_tex() -> ImageTexture:
	if _flame:
		return _flame
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var v := 1.0 - y / 63.0
			var half_w := 0.46 * pow(sin(clampf(v, 0.0, 1.0) * PI * 0.92 + 0.12), 1.4) * (1.0 - v * 0.55)
			var d := absf(x / 31.0 - 0.5)
			var a := clampf(1.0 - d / maxf(half_w, 0.001), 0.0, 1.0)
			a = a * a * smoothstep(0.0, 0.12, v) * (1.0 - smoothstep(0.85, 1.0, v))
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_flame = ImageTexture.create_from_image(img)
	return _flame


static func soft_tex() -> GradientTexture2D:
	if _soft_tex:
		return _soft_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.4, Color(1, 1, 1, 0.45))
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 64
	_soft_tex.height = 64
	return _soft_tex


# ════════════════════════════════════════════════════════════
#  Простые меши
# ════════════════════════════════════════════════════════════
static func node(parent: Node, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, nm: String = "") -> Node3D:
	var n := Node3D.new()
	if nm != "":
		n.name = nm
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees = rot_deg
	return n


static func mesh_node(parent: Node, m: Mesh, pos: Vector3, mt: Material, rot_deg: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mt
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	return mi


static func box(parent: Node, size: Vector3, pos: Vector3, mt: Material, rot_deg: Vector3 = Vector3.ZERO, shadows: bool = true) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	return mesh_node(parent, bm, pos, mt, rot_deg, shadows)


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mt: Material, rot_deg: Vector3 = Vector3.ZERO, sides: int = 12) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	return mesh_node(parent, cm, pos, mt, rot_deg)


static func ball(parent: Node, r: float, pos: Vector3, mt: Material, scl: Vector3 = Vector3.ONE, segs: int = 12) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(4, segs / 2)
	var mi := mesh_node(parent, sm, pos, mt)
	mi.scale = scl
	return mi


static func quad(parent: Node, size: Vector2, pos: Vector3, mt: Material, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var qm := QuadMesh.new()
	qm.size = size
	return mesh_node(parent, qm, pos, mt, rot_deg, false)


# Отрезок-брус между двумя точками
static func beam(parent: Node, a: Vector3, b: Vector3, thick: Vector2, mt: Material) -> MeshInstance3D:
	var len := a.distance_to(b)
	var bm := BoxMesh.new()
	bm.size = Vector3(thick.x, thick.y, len)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = mt
	parent.add_child(mi)
	mi.position = (a + b) * 0.5
	if len > 0.0001:
		var d := (b - a) / len
		var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		mi.basis = Basis.looking_at(d, up)
	return mi


static func text3d(parent: Node, s: String, pos: Vector3, rot_deg: Vector3, px: float, col: Color, font_size: int = 48, outline: int = 0) -> Label3D:
	var l := Label3D.new()
	l.text = s
	l.pixel_size = px
	l.font_size = font_size
	l.modulate = col
	l.outline_size = outline
	l.outline_modulate = Color(0, 0, 0, 0.6)
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISABLED
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(l)
	l.position = pos
	l.rotation_degrees = rot_deg
	return l


# Стена от a до b (по горизонтали) высотой h с прямоугольным проёмом.
# hole = Rect2(x от a, y от пола, ширина, высота); пустой Rect2 — без проёма.
static func wall(parent: Node, a: Vector3, b: Vector3, h: float, thick: float, mt: Material, hole: Rect2 = Rect2()) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var dir := Vector3(b.x - a.x, 0, b.z - a.z)
	var len := dir.length()
	root.position = a
	root.basis = Basis(Vector3.UP, atan2(-dir.z, dir.x))
	var parts: Array = []
	if hole.size.x <= 0.0:
		parts.append(Rect2(0, 0, len, h))
	else:
		var x0 := hole.position.x
		var x1 := hole.position.x + hole.size.x
		var y0 := hole.position.y
		var y1 := hole.position.y + hole.size.y
		if x0 > 0.001:
			parts.append(Rect2(0, 0, x0, h))
		if x1 < len - 0.001:
			parts.append(Rect2(x1, 0, len - x1, h))
		if y0 > 0.001:
			parts.append(Rect2(x0, 0, x1 - x0, y0))
		if y1 < h - 0.001:
			parts.append(Rect2(x0, y1, x1 - x0, h - y1))
	for r in parts:
		var rr: Rect2 = r
		box(root, Vector3(rr.size.x, rr.size.y, thick), Vector3(rr.position.x + rr.size.x * 0.5, rr.position.y + rr.size.y * 0.5, 0), mt)
	return root


static func ground(parent: Node, center: Vector3, size: Vector2, mt: Material) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	var mi := mesh_node(parent, pm, center, mt)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# ════════════════════════════════════════════════════════════
#  Мебель и предметы из PrefabBuilder (как их ставит Main.gd)
# ════════════════════════════════════════════════════════════
static func prefab(parent: Node, type: String, sz: Vector3, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, col: Color = Color.WHITE) -> Node3D:
	var is_door := ("door" in type and not ("hatch" in type))
	var is_prim := type == "cube" or type.begins_with("wall") or is_door or type == "prop_tree_pine" \
		or type in ["floor_drag", "floor_custom", "ceiling_drag", "ceiling_custom"]
	var base := PrefabBuilder.get_prefab_base_size(type)
	if base.x <= 0.01:
		base.x = 1.0
	if base.y <= 0.01:
		base.y = 1.0
	if base.z <= 0.01:
		base.z = 1.0
	var n := PrefabBuilder.build_prefab(type, sz if is_prim else base, col, false, "")
	if n == null:
		return null
	_strip_logic(n)
	parent.add_child(n)
	n.position = pos
	n.rotation_degrees = rot_deg
	if not is_prim and not is_door:
		n.scale = Vector3(sz.x / base.x, sz.y / base.y, sz.z / base.z)
	return n


# Скрипты дверей, часов и телевизоров в кат-сцене не нужны: только вид
static func _strip_logic(n: Node) -> void:
	for c in [n] + n.find_children("*", "", true, false):
		var s: Script = c.get_script()
		if s != null and not (c is MeshInstance3D):
			var keep := c is Light3D
			if not keep:
				c.set_script(null)
		if c is CollisionObject3D:
			(c as CollisionObject3D).collision_layer = 0
			(c as CollisionObject3D).collision_mask = 0


# Кусок карты в радиусе от точки: дом, гараж, поленница, деревья.
# Собирается так же, как в Main.gd, только без логики, предметов и маркеров.
# with_basement = false: подвал Досыма под домом (объекты «Подвал: …») не строится — он под землёй
# и в кадре наружных сцен не виден, а это ~350 объектов.
# y_max: объекты выше этой высоты пропускаются (для подвала: дом над ним в кадр не попадает).
static func map_area(parent: Node, json_path: String, center: Vector3, radius: float, skip_types: Array = [], skip_ids: Array = [], skip_box: AABB = AABB(), with_basement: bool = false, y_max: float = INF) -> Node3D:
	var root := Node3D.new()
	root.name = "MapArea"
	parent.add_child(root)
	var f := FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_warning("CutsceneKit: нет карты " + json_path)
		return root
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return root
	var skip := ["marker_player", "marker_enemy", "marker_lumberjack", "marker", "prop_note", "prop_note_safe",
		"light_warm", "light_red", "light_ceiling", "prop_grandfather_clock", "prop_crt_tv", "prop_tv",
		"prop_occult_altar", "prop_light_switch", "prop_fusebox", "prop_ethan_car", "prop_streetlight"] + skip_types
	# Стоячие ели — пачками MultiMesh, как их строит HighwayChapter (иначе FPS падает)
	var pines: Array = []
	for obj in (data as Dictionary).get("objects", []):
		var o: Dictionary = obj
		var type: String = o.get("type", "cube")
		if type in skip or type.begins_with("item_") or type.begins_with("custom_"):
			continue
		if not bool(o.get("visible", true)) or int(o.get("id", -1)) in skip_ids:
			continue
		if not with_basement and String(o.get("name", "")).begins_with("Подвал"):
			continue
		var pa: Array = o.get("position", [0, 0, 0])
		var pos := Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		if Vector2(pos.x - center.x, pos.z - center.z).length() > radius or pos.y > y_max:
			continue
		if skip_box.size != Vector3.ZERO and skip_box.has_point(pos) and type != "cube" and not type.begins_with("floor") and not type.begins_with("ceiling"):
			continue
		var ra: Array = o.get("rotation", [0, 0, 0])
		var sa: Array = o.get("scale", [1, 1, 1])
		var rot := Vector3(float(ra[0]), float(ra[1]), float(ra[2]))
		var sz := Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
		var col := Color.html(String(o.get("color", "#7d8590")))
		if type == "prop_tree_pine" and absf(rot.x) < 1.0:
			pines.append([pos, sz, deg_to_rad(rot.y)])
			continue
		if type == "cube":
			var mi := box(root, sz, pos, mat(col), rot)
			var wt := String(o.get("wall_texture", ""))
			if wt != "":
				mi.material_override = TextureHelper.create_wall_material(wt, col)
			continue
		var n := prefab(root, type, sz, pos, rot, col)
		if n != null:
			if o.has("door_texture") and String(o["door_texture"]) != "":
				TextureHelper.apply_door_texture_to_node(n, String(o["door_texture"]))
			if o.has("painting_art") and String(o["painting_art"]) != "":
				TextureHelper.apply_painting_art_to_node(n, String(o["painting_art"]))
	spruce_chunks(root, pines)
	return root


# Ели пачками: [позиция, размер (ширина, высота, ширина), поворот] → несколько MultiMesh
static func spruce_chunks(parent: Node3D, trees: Array, tint: Color = Color(0.12, 0.3, 0.14)) -> void:
	var groups := {}
	for tr in trees:
		var sz: Vector3 = tr[1]
		var big := sz.y > 10.5
		var k2 := ("big" if big else "small") + str(int(absf((tr[0] as Vector3).x * 13.0 + (tr[0] as Vector3).z * 7.0)) % 3)
		if not groups.has(k2):
			groups[k2] = []
		groups[k2].append(tr)
	for k in groups:
		var list: Array = groups[k]
		NatureKit.add_spruce_chunk(parent, list, String(k).begins_with("big"), int(String(k).right(1)), tint, NatureKit.NEAR_END, NatureKit.FAR_END)


# ════════════════════════════════════════════════════════════
#  Природа
# ════════════════════════════════════════════════════════════
static func spruce(parent: Node, pos: Vector3, height: float, tint: Color = Color(0.12, 0.3, 0.14)) -> Node3D:
	var n := node(parent, pos)
	NatureKit.add_spruce(n, Vector3(height * 0.36, height, height * 0.36), tint)
	return n


# Ели по кольцу вокруг точки; avoid(x, z) -> true, если место занято
static func forest(parent: Node, center: Vector3, r_in: float, r_out: float, count: int, rng_seed: int, h_min: float = 9.0, h_max: float = 17.0, avoid: Callable = Callable()) -> Node3D:
	var root := node(parent, Vector3.ZERO, Vector3.ZERO, "Forest")
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var placed := 0
	var tries := 0
	var trees: Array = []
	while placed < count and tries < count * 6:
		tries += 1
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf_range(r_in * r_in, r_out * r_out))
		var p := center + Vector3(cos(a) * r, 0, sin(a) * r)
		if avoid.is_valid() and bool(avoid.call(p.x, p.z)):
			continue
		var h := rng.randf_range(h_min, h_max)
		trees.append([Vector3(p.x, center.y, p.z), Vector3(h * 0.36, h, h * 0.36), rng.randf() * TAU])
		placed += 1
	spruce_chunks(root, trees)
	return root


static func rock(parent: Node, pos: Vector3, sz: Vector3, tint: Color = Color(0.36, 0.34, 0.31)) -> Node3D:
	var n := node(parent, pos)
	NatureKit.add_rock(n, sz, tint)
	return n


static func bush(parent: Node, pos: Vector3, sz: Vector3) -> Node3D:
	var n := node(parent, pos)
	NatureKit.add_bush(n, sz)
	return n


# Высокая трава пучками
static func grass(parent: Node, center: Vector3, size: Vector2, count: int, rng_seed: int, h: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var xf: Array[Transform3D] = []
	for i in count:
		var p := center + Vector3(rng.randf_range(-0.5, 0.5) * size.x, 0, rng.randf_range(-0.5, 0.5) * size.y)
		var s := rng.randf_range(0.7, 1.3) * h
		xf.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.5), s)), p))
	RoadKit.add_tufts(parent as Node3D, xf, 60.0)


# Поленница: ряды поленьев
static func woodpile(parent: Node, pos: Vector3, rot_y: float, length: float, rows: int) -> Node3D:
	var root := node(parent, pos, Vector3(0, rot_y, 0), "Woodpile")
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var bark := tmat("board_weathered.png", Color(0.5, 0.4, 0.32), 2.0)
	var cut := mat(Color(0.36, 0.29, 0.21), 0.95)
	var r := 0.11
	for row in rows:
		var n := int(length / (r * 2.05))
		for i in n:
			var x := -length * 0.5 + r + i * r * 2.05 + (r if row % 2 == 1 else 0.0)
			if x > length * 0.5 - r:
				continue
			var y := r + row * r * 1.78
			var lg := cyl(root, r * rng.randf_range(0.85, 1.05), r, 0.62, Vector3(x, y, rng.randf_range(-0.05, 0.05)), bark, Vector3(90, 0, 0), 8)
			for s in [-1.0, 1.0]:
				var cap := cyl(root, r * 0.97, r * 0.97, 0.01, Vector3(x, y, s * 0.31 + lg.position.z), cut, Vector3(90, 0, 0), 8)
				cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


# ════════════════════════════════════════════════════════════
#  Эффекты
# ════════════════════════════════════════════════════════════
# Огонь в очаге: пламя, угли, дым и мерцающий свет. level 0…1 — сила огня.
class Fire extends Node3D:
	var level := 1.0
	var light: OmniLight3D
	var flames: CPUParticles3D
	var embers: CPUParticles3D
	var smoke: CPUParticles3D
	var base_energy := 2.6
	var _t := 0.0
	var _flame_mat: StandardMaterial3D
	var _flame_col := Color(1.0, 0.95, 0.9)

	func _init(size: float = 1.0) -> void:
		name = "Fire"
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.22)
		light.omni_range = 7.0 * size
		light.omni_attenuation = 1.4
		light.shadow_enabled = true
		light.position = Vector3(0, 0.35 * size, 0.15 * size)
		add_child(light)
		flames = _parts(64, 0.6, _flame_col, 0.2 * size, Vector3(0.2, 0.03, 0.1) * size, 0.9 * size, 0.3 * size)
		(flames.mesh as QuadMesh).material.set("albedo_texture", CutsceneKit.flame_tex())
		_flame_mat = (flames.mesh as QuadMesh).material as StandardMaterial3D
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.95, 0.7, 0.0))
		ramp.add_point(0.1, Color(1.0, 0.85, 0.45, 1.0))
		ramp.add_point(0.55, Color(1.0, 0.42, 0.1, 0.8))
		ramp.set_color(ramp.get_point_count() - 1, Color(0.6, 0.12, 0.03, 0.0))
		flames.color_ramp = ramp
		embers = _parts(22, 1.6, Color(1.0, 0.45, 0.12), 0.025 * size, Vector3(0.22, 0.05, 0.1) * size, 1.4 * size, 0.2 * size)
		smoke = _parts(14, 3.2, Color(0.32, 0.31, 0.3, 0.16), 0.45 * size, Vector3(0.12, 0.08, 0.08) * size, 0.55 * size, 1.4 * size, false)
		smoke.position.y = 0.55 * size

	func _parts(n: int, life: float, col: Color, sz: float, box_ext: Vector3, speed: float, grow: float, additive: bool = true) -> CPUParticles3D:
		var p := CPUParticles3D.new()
		p.amount = n
		p.lifetime = life
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = box_ext
		p.direction = Vector3.UP
		p.spread = 12.0
		p.gravity = Vector3(0, 0.4, 0)
		p.initial_velocity_min = speed * 0.6
		p.initial_velocity_max = speed
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.2
		var curve := Curve.new()
		curve.add_point(Vector2(0, 0.4))
		curve.add_point(Vector2(0.3, 1.0))
		curve.add_point(Vector2(1, 0.0 if additive else 1.0 + grow))
		p.scale_amount_curve = curve
		var q := QuadMesh.new()
		q.size = Vector2(sz, sz * (1.5 if additive else 1.0))
		var m := CutsceneKit.add_mat(col)
		if not additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		q.material = m
		p.mesh = q
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.0))
		g.add_point(0.15, Color(1, 1, 1, 1.0))
		g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
		p.color_ramp = g
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(p)
		return p

	func _process(delta: float) -> void:
		_t += delta
		var f := 0.82 + 0.1 * sin(_t * 9.1) + 0.07 * sin(_t * 23.7 + 1.3) + 0.05 * sin(_t * 41.0)
		light.light_energy = base_energy * level * f
		light.position.x = 0.04 * sin(_t * 5.3)
		flames.emitting = level > 0.03
		_flame_mat.albedo_color = Color(_flame_col.r, _flame_col.g, _flame_col.b, clampf(level, 0.0, 1.0))
		embers.emitting = level > 0.01
		smoke.emitting = level > 0.05


static func fire(parent: Node, pos: Vector3, size: float = 1.0) -> Fire:
	var f := Fire.new(size)
	parent.add_child(f)
	f.position = pos
	return f


# Ткань на ветру (простыня, занавеска): волна в вершинном шейдере
static func cloth(parent: Node, size: Vector2, pos: Vector3, rot_deg: Vector3, col: Color, tex: Texture2D = null) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = size
	pm.subdivide_width = 18
	pm.subdivide_depth = 18
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec4 col : source_color = vec4(0.8, 0.8, 0.78, 1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap, hint_default_white;
uniform float wind = 0.0;
uniform float pinned_edge = 0.0;
uniform vec2 size = vec2(1.0);
varying float lift;
void vertex() {
	float u = (VERTEX.x / size.x) + 0.5;
	float v = (VERTEX.z / size.y) + 0.5;
	float k = mix(1.0, smoothstep(0.0, 0.7, v), pinned_edge);
	float w = sin(TIME * 2.3 + u * 5.0 + v * 3.0) * 0.6 + sin(TIME * 3.7 + u * 9.0) * 0.3 + sin(TIME * 1.1 + v * 4.0) * 0.4;
	lift = w * wind * k;
	VERTEX.y += lift * 0.06 + wind * k * 0.025 * sin(TIME * 0.9 + u * 2.0);
}
void fragment() {
	vec3 c = col.rgb * texture(tex, UV * 2.0).rgb;
	ALBEDO = c * (0.85 + lift * 0.4);
	ROUGHNESS = 0.95;
	BACKLIGHT = c * 0.35;
}
"""
	sm.shader = sh
	sm.set_shader_parameter("col", col)
	sm.set_shader_parameter("size", size)
	if tex:
		sm.set_shader_parameter("tex", tex)
	var mi := mesh_node(parent, pm, pos, sm, rot_deg)
	return mi


# Пылинки в луче света
static func dust(parent: Node, center: Vector3, ext: Vector3, amount: int = 60, col: Color = Color(1, 0.95, 0.85, 0.35)) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.gravity = Vector3(0, -0.01, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.04
	p.spread = 180.0
	var q := QuadMesh.new()
	q.size = Vector2(0.012, 0.012)
	var m := add_mat(col)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = center
	return p


# Сыплющаяся земля, пыль с потолка: emit() — один выброс
static func debris(parent: Node, pos: Vector3, ext: Vector3, amount: int, col: Color, size: float = 0.02, life: float = 1.2) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.75
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.gravity = Vector3(0, -6.0, 0)
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.3
	p.spread = 40.0
	p.direction = Vector3.DOWN
	var q := BoxMesh.new()
	q.size = Vector3.ONE * size
	q.material = mat(col, 1.0)
	p.mesh = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.position = pos
	return p


# Луч света сквозь щель: вытянутый полупрозрачный конус
static func light_shaft(parent: Node, from: Vector3, to: Vector3, width: float, col: Color) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	var len := from.distance_to(to)
	cm.top_radius = width * 0.35
	cm.bottom_radius = width
	cm.height = len
	cm.radial_segments = 10
	cm.cap_top = false
	cm.cap_bottom = false
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	m.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var mid := (from + to) * 0.5
	var dir := (from - to).normalized()
	var side := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(side, dir, side.cross(dir)).orthonormalized(), mid)
	return mi


# Паутина в углу: квадрат с нарисованной сеткой
static func cobweb(parent: Node, pos: Vector3, size: float, rot_deg: Vector3) -> MeshInstance3D:
	if _web_tex == null:
		var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		var c := Color(0.85, 0.85, 0.82, 0.55)
		for k in 9:
			var a := k / 9.0 * PI * 0.5
			for i in 128:
				var x := int(cos(a) * i)
				var y := int(sin(a) * i)
				if x < 128 and y < 128:
					img.set_pixel(x, y, c)
		for ring in range(10, 128, 13):
			for k in 120:
				var a := k / 120.0 * PI * 0.5
				var rr := ring * (1.0 - 0.08 * sin(k * 0.6))
				var x := int(cos(a) * rr)
				var y := int(sin(a) * rr)
				if x < 128 and y < 128:
					img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.35))
		img.generate_mipmaps()
		_web_tex = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_texture = _web_tex
	m.roughness = 1.0
	return quad(parent, Vector2(size, size), pos, m, rot_deg)


# ════════════════════════════════════════════════════════════
#  Предметы
# ════════════════════════════════════════════════════════════
# Олений череп: маленький, чёрный, с обломанным рогом и надписью «ДЖОЗЕФ КРЕЙН».
# Морда смотрит вдоль -Z, надпись на лбу.
static func deer_skull(parent: Node) -> Node3D:
	var root := node(parent, Vector3.ZERO, Vector3.ZERO, "DeerSkull")
	var bone := StandardMaterial3D.new()
	bone.albedo_color = Color(0.17, 0.15, 0.13)
	bone.roughness = 0.5
	bone.metallic_specular = 0.55
	var hole := mat(Color(0.0, 0.0, 0.0), 1.0)
	# Мозговая коробка, лоб и длинная узкая морда
	ball(root, 0.04, Vector3(0, 0.03, 0.055), bone, Vector3(1.1, 0.95, 1.25), 14)
	ball(root, 0.042, Vector3(0, 0.04, -0.005), bone, Vector3(1.05, 0.55, 1.15), 12)
	var snout := cyl(root, 0.013, 0.033, 0.2, Vector3(0, 0.005, -0.115), bone, Vector3(-90, 0, 0), 10)
	snout.scale = Vector3(1.0, 1.0, 0.62)
	ball(root, 0.016, Vector3(0, 0.0, -0.212), bone, Vector3(1.0, 0.75, 1.15), 8)
	for s in [-1.0, 1.0]:
		# Глазницы с надбровьем и носовые щели
		ball(root, 0.016, Vector3(0.036 * s, 0.032, -0.005), bone, Vector3(0.6, 0.9, 1.1), 10)
		ball(root, 0.014, Vector3(0.042 * s, 0.03, -0.01), hole, Vector3(0.5, 0.9, 0.9), 10)
		ball(root, 0.01, Vector3(0.012 * s, 0.012, -0.17), hole, Vector3(0.6, 0.8, 2.6), 8)
		cyl(root, 0.012, 0.016, 0.04, Vector3(0.03 * s, 0.085, 0.06), bone, Vector3(-15, 0, -22 * s), 8)
	var ant := node(root, Vector3(-0.042, 0.105, 0.065), Vector3(-25, 0, 26))
	cyl(ant, 0.005, 0.01, 0.2, Vector3(0, 0.1, 0), bone, Vector3.ZERO, 7)
	cyl(ant, 0.004, 0.007, 0.08, Vector3(0.0, 0.085, -0.03), bone, Vector3(-48, 0, 0), 6)
	cyl(ant, 0.004, 0.006, 0.07, Vector3(-0.008, 0.17, -0.02), bone, Vector3(-38, 0, 12), 6)
	# Обломок второго рога: короткий, с неровным сколом
	cyl(root, 0.008, 0.012, 0.045, Vector3(0.044, 0.115, 0.07), bone, Vector3(-25, 0, -26), 7)
	ball(root, 0.009, Vector3(0.052, 0.135, 0.075), bone, Vector3(1.0, 0.5, 1.0), 6)
	var carve := text3d(root, "ДЖОЗЕФ КРЕЙН", Vector3(0, 0.066, 0.008), Vector3(-100, 0, 0), 0.00028, Color(0.66, 0.62, 0.55), 40)
	carve.name = "Carving"
	return root


# Металлическая коробка с крышкой на петлях (крышка — дочерний узел "Lid")
static func metal_box(parent: Node, pos: Vector3, rot_deg: Vector3) -> Node3D:
	var root := node(parent, pos, rot_deg, "MetalBox")
	var m := mat(Color(0.2, 0.21, 0.2), 0.45, 0.8)
	var inner := mat(Color(0.05, 0.05, 0.05), 0.9)
	box(root, Vector3(0.42, 0.012, 0.3), Vector3(0, 0.006, 0), m)
	for s in [-1.0, 1.0]:
		box(root, Vector3(0.42, 0.14, 0.012), Vector3(0, 0.07, 0.144 * s), m)
		box(root, Vector3(0.012, 0.14, 0.3), Vector3(0.204 * s, 0.07, 0), m)
	box(root, Vector3(0.395, 0.004, 0.275), Vector3(0, 0.014, 0), inner)
	var lid := node(root, Vector3(0, 0.14, 0.15), Vector3.ZERO, "Lid")
	box(lid, Vector3(0.43, 0.014, 0.31), Vector3(0, 0.007, -0.155), m)
	box(lid, Vector3(0.05, 0.02, 0.02), Vector3(0, -0.004, -0.31), mat(Color(0.5, 0.45, 0.3), 0.3, 0.9))
	return root


# Дверь в коробке: возвращает {root, leaf (поворот на петлях по Y), handle (поворот по Z)}.
# Петли слева (x = 0), ручка справа; дверь смотрит вдоль +Z.
static func door(parent: Node, pos: Vector3, rot_deg: Vector3, w: float = 0.9, h: float = 2.05, tex: String = "wood_door.png") -> Dictionary:
	var root := node(parent, pos, rot_deg, "Door")
	var frame_m := tmat("wood_furniture.png", Color(0.55, 0.45, 0.36), 2.0)
	for s in [0.0, 1.0]:
		box(root, Vector3(0.07, h + 0.07, 0.14), Vector3(-0.035 + s * (w + 0.07), (h + 0.07) * 0.5, 0), frame_m)
	box(root, Vector3(w + 0.14, 0.07, 0.14), Vector3(w * 0.5, h + 0.035, 0), frame_m)
	var leaf := node(root, Vector3(0, 0, 0), Vector3.ZERO, "Leaf")
	var lm := tmat(tex, Color(0.8, 0.72, 0.62), 1.2)
	box(leaf, Vector3(w - 0.01, h - 0.01, 0.045), Vector3(w * 0.5, h * 0.5, 0), lm)
	for row in 2:
		for s in [-1.0, 1.0]:
			box(leaf, Vector3(w * 0.32, h * 0.33, 0.012), Vector3(w * 0.5 + s * w * 0.2, h * (0.3 + row * 0.42), s * 0.0 + 0.026), lm)
			box(leaf, Vector3(w * 0.32, h * 0.33, 0.012), Vector3(w * 0.5 + s * w * 0.2, h * (0.3 + row * 0.42), -0.026), lm)
	var brass := mat(Color(0.48, 0.4, 0.26), 0.35, 0.9)
	var handle := node(leaf, Vector3(w - 0.09, 1.0, 0), Vector3.ZERO, "Handle")
	for s in [-1.0, 1.0]:
		cyl(handle, 0.022, 0.022, 0.03, Vector3(0, 0, 0.04 * s), brass, Vector3(90, 0, 0), 10)
		box(handle, Vector3(0.12, 0.018, 0.022), Vector3(-0.05, 0, 0.058 * s), brass)
	box(leaf, Vector3(0.05, 0.16, 0.06), Vector3(w - 0.09, 0.96, 0), brass)
	return {"root": root, "leaf": leaf, "handle": handle}


# Стул с вырезанным словом на спинке (обращён сиденьем к -Z: спинка сзади, +Z)
static func carved_chair(parent: Node, pos: Vector3, rot_y: float, word: String, wood: Material) -> Node3D:
	var root := node(parent, pos, Vector3(0, rot_y, 0), "Chair")
	box(root, Vector3(0.46, 0.05, 0.44), Vector3(0, 0.46, 0), wood)
	for x in [-0.2, 0.2]:
		for z in [-0.19, 0.19]:
			box(root, Vector3(0.045, 0.46, 0.045), Vector3(x, 0.23, z), wood)
	for x in [-0.2, 0.2]:
		box(root, Vector3(0.05, 0.62, 0.05), Vector3(x, 0.77, 0.2), wood)
	box(root, Vector3(0.44, 0.16, 0.035), Vector3(0, 0.98, 0.2), wood)
	box(root, Vector3(0.44, 0.05, 0.03), Vector3(0, 0.7, 0.2), wood)
	if word != "":
		text3d(root, word, Vector3(0, 0.98, 0.18), Vector3(0, 180, 0), 0.0011, Color(0.2, 0.14, 0.09), 48)
		text3d(root, word, Vector3(0, 0.98, 0.222), Vector3(0, 0, 0), 0.0011, Color(0.2, 0.14, 0.09), 48)
	return root


# Телефон: корпус и светящийся экран с подписью
static func phone(parent: Node) -> Dictionary:
	var root := node(parent, Vector3.ZERO, Vector3.ZERO, "Phone")
	box(root, Vector3(0.072, 0.152, 0.009), Vector3.ZERO, mat(Color(0.03, 0.03, 0.035), 0.3, 0.4))
	var scr := box(root, Vector3(0.066, 0.142, 0.001), Vector3(0, 0, 0.0047), glow(Color(0.16, 0.2, 0.26), 1.0))
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.7, 0.9)
	light.light_energy = 0.25
	light.omni_range = 0.6
	light.position = Vector3(0, 0, 0.08)
	root.add_child(light)
	var l1 := text3d(root, "", Vector3(0, 0.035, 0.006), Vector3.ZERO, 0.00017, Color(0.92, 0.94, 0.98), 36)
	var l2 := text3d(root, "", Vector3(0, 0.008, 0.006), Vector3.ZERO, 0.00011, Color(0.7, 0.75, 0.82), 32)
	l1.shaded = false
	l2.shaded = false
	var ok := box(root, Vector3(0.016, 0.016, 0.001), Vector3(0.018, -0.05, 0.0055), glow(Color(0.2, 0.8, 0.35), 1.2))
	var no := box(root, Vector3(0.016, 0.016, 0.001), Vector3(-0.018, -0.05, 0.0055), glow(Color(0.9, 0.2, 0.2), 1.2))
	return {"root": root, "screen": scr, "title": l1, "sub": l2, "ok": ok, "no": no, "light": light}


# Чёрный олень (силуэт с рисунка Olen.png, как во вступлении) с ЧЕЛОВЕЧЕСКИМИ глазами:
# «глаза у него светятся не как у зверя, а как у человека» — белки и тёмные зрачки.
static func deer(parent: Node, height: float = 2.3) -> Node3D:
	var root := node(parent, Vector3.ZERO, Vector3.ZERO, "BlackDeer")
	var tex := TextureHelper.get_texture("res://assets/textures/Olen.png")
	var size := tex.get_size() if tex else Vector2(345.0, 579.0)
	var px := height / size.y
	var body := node(root, Vector3(0, height * 0.5, 0))
	if tex:
		var spr := Sprite3D.new()
		spr.texture = tex
		spr.pixel_size = px
		spr.shaded = false
		spr.double_sided = true
		spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		spr.modulate = Color(0.02, 0.02, 0.025)
		body.add_child(spr)
	var half := size * 0.5
	var white := StandardMaterial3D.new()
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	white.albedo_color = Color(0.86, 0.84, 0.8)
	var iris := StandardMaterial3D.new()
	iris.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	iris.albedo_color = Color(0.05, 0.04, 0.035)
	for e in [Vector2(82, 178), Vector2(116, 178)]:
		var p := Vector3((e.x - half.x) * px, (half.y - e.y) * px, 0.03)
		var sclera := ball(body, 0.042, p, white, Vector3(1.35, 0.72, 0.4), 12)
		sclera.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pupil := ball(body, 0.019, p + Vector3(0, 0, 0.012), iris, Vector3(1.0, 1.0, 0.4), 10)
		pupil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.85, 0.88, 0.95)
	glow.light_energy = 0.5
	glow.omni_range = 1.4
	glow.position = Vector3((99.0 - half.x) * px, (half.y - 178.0) * px, 0.3)
	body.add_child(glow)
	return root
