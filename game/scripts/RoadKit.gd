extends RefCounted
class_name RoadKit

# Дорога для всей игры: лента с готовой текстурой асфальта, разметки, трещин и обочин.
# Поперечное сечение горбом, край ленты неровный, по краям трава и сигнальные столбики.

const TEX := "res://assets/textures/road/"
const STATIONS := [-6.0, -5.4, -4.6, -3.72, -1.8, 0.0, 1.8, 3.72, 4.6, 5.4, 6.0]

static var _material: StandardMaterial3D = null
static var _edge_material: StandardMaterial3D = null
static var _meshes := {}
static var _next_variant := 0
static var _tuft_mesh: ArrayMesh = null
static var _post_white: BoxMesh = null
static var _post_band: BoxMesh = null
static var _post_ref: BoxMesh = null


static func material() -> StandardMaterial3D:
	if _material:
		return _material
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(TEX + "road_albedo.png") as Texture2D
	m.normal_enabled = true
	m.normal_texture = load(TEX + "road_normal.png") as Texture2D
	m.normal_scale = 0.85
	m.roughness_texture = load(TEX + "road_rough.png") as Texture2D
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.roughness = 1.0
	m.metallic_specular = 0.42
	# Без анизотропии разметка и трещины вдали смазываются
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_material = m
	# Вырезанный край дороги дороже, поэтому только он с прозрачностью
	_edge_material = m.duplicate() as StandardMaterial3D
	_edge_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_edge_material.alpha_scissor_threshold = 0.5
	return m


# Высота сечения: 1 на оси дороги, 0 у края ленты
static func _profile(ax: float) -> float:
	if ax < 3.72:
		return 1.0 - ax / 3.72 * 0.2
	if ax < 4.6:
		return lerpf(0.8, 0.35, (ax - 3.72) / 0.88)
	return lerpf(0.35, 0.0, clampf((ax - 4.6) / 1.4, 0.0, 1.0))


# Лента длиной length вдоль Z, центр в начале координат
static func ribbon(width: float, length: float, crown: float, edge: float, variant: int = -1) -> ArrayMesh:
	if variant < 0:
		variant = _next_variant
		_next_variant = (_next_variant + 1) % 6
	var key := [snappedf(width, 0.01), snappedf(length, 0.01), snappedf(crown, 0.001), snappedf(edge, 0.001), variant]
	if _meshes.has(key):
		return _meshes[key]
	var flip_u := variant % 2 == 1
	var v_shift := float(variant / 2) / 3.0
	var rows := maxi(int(length / 4.0), 1) + 1
	var cols: int = STATIONS.size()
	var xs := width / 12.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var edge_idx := PackedInt32Array()
	for j in rows:
		var z := -length * 0.5 + length * float(j) / float(rows - 1)
		for i in cols:
			var sx: float = STATIONS[i]
			var y := lerpf(edge, crown, _profile(absf(sx)))
			verts.append(Vector3(sx * xs, y, z))
			var prev: float = STATIONS[maxi(i - 1, 0)]
			var nxt: float = STATIONS[mini(i + 1, cols - 1)]
			var dy := (lerpf(edge, crown, _profile(absf(nxt))) - lerpf(edge, crown, _profile(absf(prev)))) / ((nxt - prev) * xs)
			norms.append(Vector3(-dy, 1.0, 0.0).normalized())
			var t := Vector3(-1.0 if flip_u else 1.0, 0.0, 0.0)
			tans.append_array([t.x, t.y, t.z, 1.0])
			var u := (sx + 6.0) / 12.0
			uvs.append(Vector2(1.0 - u if flip_u else u, (z + length * 0.5) / 24.0 + v_shift))
	for j in rows - 1:
		for i in cols - 1:
			var p := j * cols + i
			var q := p + 1
			var s := p + cols
			var d := s + 1
			# Полотно до второй станции обочины непрозрачное
			if i >= 2 and i < cols - 3:
				idx.append_array([p, q, s, q, d, s])
			else:
				edge_idx.append_array([p, q, s, q, d, s])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TANGENT] = tans
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, material())
	arr[Mesh.ARRAY_INDEX] = edge_idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(1, _edge_material)
	_meshes[key] = mesh
	return mesh


# Участок дороги от z_from до z_to: для кат-сцен и декораций
static func add_road(parent: Node3D, z_from: float, z_to: float, x: float = 0.0, y: float = 0.0, width: float = 12.0, crown: float = 0.05, edge: float = -0.012, decorate: bool = true) -> void:
	var seg := 40.0
	var z := minf(z_from, z_to)
	var end := maxf(z_from, z_to)
	var n := 0
	while z < end:
		var mi := MeshInstance3D.new()
		mi.name = "RoadPart"
		mi.mesh = ribbon(width, seg, crown, edge)
		mi.position = Vector3(x, y, z + seg * 0.5)
		parent.add_child(mi)
		if decorate:
			add_roadside(mi, width, seg, n)
		z += seg
		n += 1


# Трава у края и сигнальные столбики
static func add_roadside(parent: Node3D, width: float, length: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7741 + seed_v * 13
	var half := width * 0.5
	var xforms: Array[Transform3D] = []
	for i in 32:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var x := side * half * rng.randf_range(0.8, 1.14)
		var z := rng.randf_range(-length * 0.5, length * 0.5)
		var sc := rng.randf_range(0.55, 1.15)
		xforms.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), Vector3(x, -0.03, z)))
	add_tufts(parent, xforms)
	if seed_v % 2 == 0:
		_post(parent, Vector3(half * 0.84, 0.0, -length * 0.25 + rng.randf_range(-1.0, 1.0)), rng.randf_range(-0.05, 0.05))
	if seed_v % 3 != 1:
		_post(parent, Vector3(-half * 0.84, 0.0, length * 0.2 + rng.randf_range(-1.0, 1.0)), rng.randf_range(-0.09, 0.09))


static func add_tufts(parent: Node3D, xforms: Array[Transform3D], range_end: float = 26.0) -> void:
	if xforms.is_empty():
		return
	var mm := NatureKit._multimesh_of(_tuft(), xforms)
	mm.visibility_range_end = range_end
	mm.visibility_range_end_margin = 3.0
	mm.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	parent.add_child(mm)


static func _tuft() -> ArrayMesh:
	if _tuft_mesh:
		return _tuft_mesh
	var m := StandardMaterial3D.new()
	m.albedo_texture = TextureHelper.get_texture("res://assets/textures/nature/grass_tuft.png")
	m.albedo_color = Color(0.44, 0.48, 0.31)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(m)
	for ang in [0.0, 1.05, 2.1]:
		var d := Vector3(cos(ang), 0.0, sin(ang)) * 0.42
		var up := Vector3.UP * 0.46
		for spec in [[-d, Vector2(0, 1)], [-d + up, Vector2(0, 0)], [d + up, Vector2(1, 0)], [-d, Vector2(0, 1)], [d + up, Vector2(1, 0)], [d, Vector2(1, 1)]]:
			st.set_normal(Vector3.UP)
			st.set_uv(spec[1])
			st.add_vertex(spec[0])
	_tuft_mesh = st.commit()
	return _tuft_mesh


# Сигнальный столбик: белый, с чёрной полосой и световозвращателем
static func _post(parent: Node3D, pos: Vector3, tilt: float) -> void:
	if _post_white == null:
		var white := StandardMaterial3D.new()
		white.albedo_color = Color(0.46, 0.46, 0.42)
		white.roughness = 0.7
		_post_white = BoxMesh.new()
		_post_white.size = Vector3(0.11, 1.0, 0.09)
		_post_white.material = white
		var black := StandardMaterial3D.new()
		black.albedo_color = Color(0.015, 0.015, 0.015)
		_post_band = BoxMesh.new()
		_post_band.size = Vector3(0.115, 0.22, 0.095)
		_post_band.material = black
		var ref := StandardMaterial3D.new()
		ref.albedo_color = Color(0.62, 0.3, 0.05)
		ref.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_post_ref = BoxMesh.new()
		_post_ref.size = Vector3(0.05, 0.12, 0.1)
		_post_ref.material = ref
	var root := Node3D.new()
	root.position = pos
	root.rotation = Vector3(tilt * 0.6, tilt * 4.0, tilt)
	parent.add_child(root)
	for spec in [[_post_white, 0.5], [_post_band, 0.82], [_post_ref, 0.82]]:
		var mi := MeshInstance3D.new()
		mi.mesh = spec[0]
		mi.position.y = spec[1]
		root.add_child(mi)
