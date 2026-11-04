extends RefCounted
class_name CellarLook

# Внешний вид входа в подвал. Столкновения и петли не меняются, поэтому створки открываются как раньше.
# Детали можно включать по отдельности: доски, ржавое железо, каменный цоколь, грязь и трава.

const LEAF_W: float = 0.81
const LEAF_LEN: float = 2.44


static func apply(root: Node3D, boards: bool, rust: bool, stone: bool, ground: bool) -> void:
	var left := root.find_child("LeftHinge", true, false) as Node3D
	var right := root.find_child("RightHinge", true, false) as Node3D
	var base := root.find_child("ConcreteBase", true, false) as Node3D
	if not left or not right or not base:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 4410
	if boards:
		_boards(left, 1.0, rng)
		_boards(right, -1.0, rng)
	if rust:
		_rust(left, right, rng)
	if stone:
		_stone(base)
	if ground:
		_ground(root, rng)


static func _mat(col: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


# Старые доски: разной длины и тона, с щелями, концы подгнили и обломаны
static func _boards(hinge: Node3D, dir: float, rng: RandomNumberGenerator) -> void:
	for c in hinge.get_children():
		if c is MeshInstance3D and c.mesh is BoxMesh:
			var s: Vector3 = (c.mesh as BoxMesh).size
			if s.z > 2.0:
				c.visible = false
	# Чернота под щелями
	_box(hinge, Vector3(LEAF_W - 0.01, 0.012, LEAF_LEN - 0.04), Vector3(dir * LEAF_W * 0.5, -0.016, 0.0), _mat(Color(0.012, 0.01, 0.009), 1.0))
	var count := 5
	var pitch := LEAF_W / float(count)
	for i in count:
		var w := pitch - rng.randf_range(0.012, 0.034)
		var shade := rng.randf_range(0.72, 1.18)
		var col := Color(0.15 * shade, 0.105 * shade, 0.072 * shade)
		var trim_a := rng.randf_range(0.0, 0.09)
		var trim_b := rng.randf_range(0.0, 0.16)
		var length := LEAF_LEN - trim_a - trim_b
		var mid := (trim_b - trim_a) * 0.5
		var x := dir * (pitch * (float(i) + 0.5))
		var y := rng.randf_range(-0.003, 0.006)
		var plank := _box(hinge, Vector3(w, 0.032, length), Vector3(x, y, mid), _mat(col, 0.97), Vector3(rng.randf_range(-0.006, 0.006), rng.randf_range(-0.006, 0.006), rng.randf_range(-0.012, 0.012)))
		plank.name = "Plank"
		# Тёмные полосы волокон и пятна гнили
		for g in 3:
			var gz := rng.randf_range(-length * 0.42, length * 0.42) + mid
			_box(hinge, Vector3(0.006, 0.002, rng.randf_range(0.25, 0.7)), Vector3(x + rng.randf_range(-w, w) * 0.34, y + 0.017, gz), _mat(col.darkened(0.45), 1.0))
		# Гнилой обломанный конец у нижнего края
		if rng.randf() < 0.75:
			_box(hinge, Vector3(w * rng.randf_range(0.35, 0.7), 0.034, 0.1), Vector3(x + rng.randf_range(-0.02, 0.02), y, mid + length * 0.5 - 0.02), _mat(Color(0.045, 0.036, 0.028), 1.0))
	# Поперечные планки
	for z in [-0.7, 0.7]:
		_box(hinge, Vector3(LEAF_W - 0.04, 0.03, 0.14), Vector3(dir * LEAF_W * 0.5, 0.022, z), _mat(Color(0.105, 0.075, 0.052), 0.97), Vector3(0.0, rng.randf_range(-0.012, 0.012), 0.0))


static func _rust_mat(rng: RandomNumberGenerator) -> StandardMaterial3D:
	var t := rng.randf()
	return _mat(Color(0.2, 0.09, 0.045).lerp(Color(0.1, 0.07, 0.055), t), 0.88, 0.45)


# Ржавые петли, засов, цепь и навесной замок
static func _rust(left: Node3D, right: Node3D, rng: RandomNumberGenerator) -> void:
	var old_iron := _rust_mat(rng)
	for hinge in [left, right]:
		for c in hinge.get_children():
			if c is MeshInstance3D and c.mesh is BoxMesh:
				var s: Vector3 = (c.mesh as BoxMesh).size
				# Старые железки: петли и ручки
				if s.x >= 0.03 and s.x <= 0.6 and s.y <= 0.06 and s.z <= 0.15:
					if (c.mesh as BoxMesh).material is StandardMaterial3D and ((c.mesh as BoxMesh).material as StandardMaterial3D).metallic > 0.5:
						c.visible = false
	for spec in [[left, 1.0], [right, -1.0]]:
		var hinge: Node3D = spec[0]
		var dir: float = spec[1]
		for z in [-0.7, 0.7]:
			# Длинная петля с расширением на конце и заклёпками
			_box(hinge, Vector3(0.6, 0.014, 0.06), Vector3(dir * 0.32, 0.05, z), _rust_mat(rng))
			_box(hinge, Vector3(0.09, 0.016, 0.11), Vector3(dir * 0.62, 0.05, z), _rust_mat(rng))
			_box(hinge, Vector3(0.07, 0.05, 0.1), Vector3(dir * 0.03, 0.05, z), _rust_mat(rng))
			for b in 4:
				var bolt := SphereMesh.new()
				bolt.radius = 0.011
				bolt.height = 0.016
				bolt.material = old_iron
				var mi := MeshInstance3D.new()
				mi.mesh = bolt
				mi.position = Vector3(dir * (0.1 + 0.15 * b), 0.06, z)
				hinge.add_child(mi)
		# Проушина под засов у центрального шва
		var eye := TorusMesh.new()
		eye.inner_radius = 0.018
		eye.outer_radius = 0.032
		eye.material = _rust_mat(rng)
		var eye_mi := MeshInstance3D.new()
		eye_mi.mesh = eye
		eye_mi.position = Vector3(dir * (LEAF_W - 0.1), 0.075, 0.18)
		eye_mi.rotation = Vector3(0.0, 0.0, PI * 0.5)
		hinge.add_child(eye_mi)
	# Засов лежит на правой створке и заходит в проушину левой
	_box(right, Vector3(0.42, 0.024, 0.04), Vector3(-LEAF_W + 0.02, 0.078, 0.18), _rust_mat(rng))
	# Цепь через обе проушины висит на правой створке
	var link_mat := _mat(Color(0.13, 0.085, 0.06), 0.82, 0.6)
	for i in 9:
		var t := float(i) / 8.0
		var link := TorusMesh.new()
		link.inner_radius = 0.0105
		link.outer_radius = 0.021
		link.material = link_mat
		var mi := MeshInstance3D.new()
		mi.mesh = link
		mi.position = Vector3(-LEAF_W - 0.2 + t * 0.4, 0.07 + 0.012 * sin(t * PI), 0.32 + sin(t * PI) * 0.1)
		mi.scale = Vector3(1.3, 1.0, 0.85)
		mi.rotation = Vector3(PI * 0.5 if i % 2 == 0 else 0.0, 0.4, 0.0)
		right.add_child(mi)
	# Навесной замок
	var lock_pos := Vector3(-LEAF_W + 0.0, 0.07, 0.47)
	_box(right, Vector3(0.09, 0.03, 0.1), lock_pos, _mat(Color(0.16, 0.11, 0.06), 0.65, 0.75))
	_box(right, Vector3(0.02, 0.032, 0.02), lock_pos + Vector3(0.0, 0.001, 0.015), _mat(Color(0.02, 0.018, 0.016), 1.0))
	var shackle := TorusMesh.new()
	shackle.inner_radius = 0.022
	shackle.outer_radius = 0.034
	shackle.material = _mat(Color(0.22, 0.2, 0.18), 0.5, 0.8)
	var sh := MeshInstance3D.new()
	sh.mesh = shackle
	sh.position = lock_pos + Vector3(0.0, 0.005, -0.06)
	sh.rotation = Vector3(0.0, 0.0, PI * 0.5)
	right.add_child(sh)


static func _stone_texture() -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = 991
	var sz := 256
	var img := Image.create(sz, sz, true, Image.FORMAT_RGB8)
	img.fill(Color(0.035, 0.033, 0.03))
	var rows := 6
	var row_h := sz / rows
	for r in rows:
		var x := -rng.randi_range(0, 34)
		while x < sz:
			var w := rng.randi_range(30, 62)
			var tone := rng.randf_range(0.13, 0.26)
			var col := Color(tone, tone * 0.97, tone * 0.9)
			for yy in range(r * row_h + 3, (r + 1) * row_h - 2):
				for xx in range(x + 2, x + w - 2):
					if xx >= 0 and xx < sz:
						var n := rng.randf_range(-0.018, 0.018)
						img.set_pixel(xx, yy, Color(col.r + n, col.g + n, col.b + n))
			x += w
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# Сплошной скос: профиль сбоку вместо ступенек
static func _wedge(parent: Node3D, x: float, w: float, mat: Material) -> void:
	var top_back := Vector3(0.0, 1.14, -1.2)
	var top_front := Vector3(0.0, 0.14, 1.2)
	var hw := w * 0.5
	var quads: Array = [
		# Верхний скос, две боковые стороны, торец
		[[-hw, top_back.y, top_back.z], [hw, top_back.y, top_back.z], [hw, top_front.y, top_front.z], [-hw, top_front.y, top_front.z]],
		[[hw, top_back.y, top_back.z], [hw, 0.0, top_back.z], [hw, 0.0, top_front.z], [hw, top_front.y, top_front.z]],
		[[-hw, top_front.y, top_front.z], [-hw, 0.0, top_front.z], [-hw, 0.0, top_back.z], [-hw, top_back.y, top_back.z]],
		[[-hw, top_front.y, top_front.z], [hw, top_front.y, top_front.z], [hw, 0.0, top_front.z], [-hw, 0.0, top_front.z]],
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var p: Array[Vector3] = []
		for v in q:
			p.append(Vector3(v[0], v[1], v[2]))
		var uv := func(v: Vector3) -> Vector2:
			var along: bool = absf(v.x) >= hw - 0.0001 and q != quads[0] and q != quads[3]
			return Vector2(v.z, v.y) if along else Vector2(v.x, v.z)
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_uv(uv.call(p[idx]))
			st.add_vertex(p[idx])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.position.x = x
	parent.add_child(mi)


# Низкий каменный цоколь вместо светлых бетонных ступенек
static func _stone(base: Node3D) -> void:
	for c in base.get_children():
		if not (c is MeshInstance3D and c.mesh is BoxMesh):
			continue
		var s: Vector3 = (c.mesh as BoxMesh).size
		# Подземные ступени и темнота остаются, наземные бетонные части заменяются
		if c.position.y > 0.08:
			c.visible = false
		else:
			var old := (c.mesh as BoxMesh).material as StandardMaterial3D
			if old and old.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				old.albedo_color = Color(0.085, 0.08, 0.075)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _stone_texture()
	mat.uv1_scale = Vector3(1.7, 1.7, 1.7)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for x in [-0.93, 0.93]:
		_wedge(base, x, 0.2, mat)
	var wall := _box(base, Vector3(2.08, 1.32, 0.2), Vector3(0.0, 0.66, -1.12), mat)
	wall.scale = Vector3.ONE
	_box(base, Vector3(2.08, 0.16, 0.2), Vector3(0.0, 0.08, 1.14), mat)
	# Верхняя плита над створками у стены
	_box(base, Vector3(2.16, 0.07, 0.3), Vector3(0.0, 1.32, -1.08), _mat(Color(0.11, 0.105, 0.095), 1.0))


# Грязь и трава у основания: вход врастает в землю
static func _ground(root: Node3D, rng: RandomNumberGenerator) -> void:
	var dirt := _mat(Color(0.05, 0.04, 0.03), 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	var ring: Array[Vector3] = []
	for i in seg:
		var a := float(i) / float(seg) * TAU
		var r := 1.0 + 0.14 * sin(a * 3.0 + 1.0) + 0.09 * sin(a * 7.0) + rng.randf_range(-0.05, 0.05)
		ring.append(Vector3(cos(a) * 1.75 * r, 0.018, sin(a) * 2.1 * r + 0.25))
	for i in seg:
		st.set_normal(Vector3.UP)
		st.add_vertex(Vector3(0.0, 0.018, 0.25))
		st.set_normal(Vector3.UP)
		st.add_vertex(ring[i])
		st.set_normal(Vector3.UP)
		st.add_vertex(ring[(i + 1) % seg])
	var patch := MeshInstance3D.new()
	patch.mesh = st.commit()
	patch.material_override = dirt
	root.add_child(patch)
	# Подсыпка земли у бортов
	for side in [-1.0, 1.0]:
		for i in 7:
			var z := -1.0 + float(i) * 0.38 + rng.randf_range(-0.08, 0.08)
			var clod := SphereMesh.new()
			clod.radius = rng.randf_range(0.17, 0.3)
			clod.height = clod.radius * rng.randf_range(0.55, 0.85)
			clod.material = _mat(Color(0.052, 0.042, 0.03).lerp(Color(0.04, 0.05, 0.028), rng.randf()), 1.0)
			var mi := MeshInstance3D.new()
			mi.mesh = clod
			mi.position = Vector3(side * rng.randf_range(1.07, 1.28), 0.03, z)
			root.add_child(mi)
	# Трава и сухие стебли у краёв
	var blades := SurfaceTool.new()
	blades.begin(Mesh.PRIMITIVE_TRIANGLES)
	blades.set_material(_grass_mat())
	for t in 420:
		var a := rng.randf() * TAU
		var dist := rng.randf_range(1.1, 2.1)
		var c := Vector3(cos(a) * dist * 1.0, 0.0, sin(a) * dist * 1.2 + 0.2)
		if c.x > -1.03 and c.x < 1.03 and c.z > -1.2 and c.z < 1.28:
			continue
		var clump := rng.randi_range(3, 6)
		for b in clump:
			var yaw := rng.randf() * TAU
			var h := rng.randf_range(0.07, 0.27)
			var w := rng.randf_range(0.008, 0.018)
			var lean := Vector3(cos(yaw), 0.0, sin(yaw)) * rng.randf_range(0.03, 0.2)
			var side_v := Vector3(sin(yaw), 0.0, -cos(yaw)) * w
			var p0 := c + Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
			var tone := rng.randf_range(0.6, 1.25)
			var dry := rng.randf() < 0.14
			var tip_col := Color(0.13 * tone, 0.12 * tone, 0.06 * tone) if dry else Color(0.075 * tone, 0.17 * tone, 0.07 * tone)
			var base_col := Color(0.03, 0.05, 0.025)
			for v in [[p0 - side_v, base_col], [p0 + side_v, base_col], [p0 + Vector3.UP * h + lean, tip_col]]:
				blades.set_color(v[1])
				blades.set_normal(Vector3.UP)
				blades.add_vertex(v[0])
	var grass := MeshInstance3D.new()
	grass.mesh = blades.commit()
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(grass)


static func _grass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
