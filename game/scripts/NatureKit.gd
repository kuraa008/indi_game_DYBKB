class_name NatureKit
extends RefCounted

# Часто используемые модели карты: ель, валун, куст, фонарь, разбитая машина и
# выступающие кирпичи. Меши и материалы общие, поэтому сотни объектов рисуются
# инстансингом и не добавляют отдельных вызовов отрисовки.

const TEX := "res://assets/textures/nature/"
const SPRUCE_TINT_REF := Color(0.12, 0.30, 0.14)
const NEAR_END := 36.0
const FAR_END := 120.0

static var _meshes: Dictionary = {}
static var _mats: Dictionary = {}
static var _counter: int = 0


class Geo:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()

	func vert(p: Vector3, nor: Vector3, col: Color, t: Vector2 = Vector2.ZERO) -> void:
		v.append(p)
		n.append(nor)
		c.append(col)
		uv.append(t)

	# Треугольник с плоской нормалью, повёрнутый наружу относительно точки inner
	func flat(a: Vector3, b: Vector3, d: Vector3, inner: Vector3, col: Color) -> void:
		var nor := (b - a).cross(d - a)
		if nor.length_squared() < 1e-12:
			return
		nor = nor.normalized()
		if nor.dot((a + b + d) / 3.0 - inner) < 0.0:
			nor = -nor
		# В Godot лицевая сторона идёт по часовой стрелке
		if (b - a).cross(d - a).dot(nor) > 0.0:
			var t := b
			b = d
			d = t
		vert(a, nor, col)
		vert(b, nor, col)
		vert(d, nor, col)

	func quad_flat(a: Vector3, b: Vector3, e: Vector3, d: Vector3, inner: Vector3, col: Color) -> void:
		flat(a, b, e, inner, col)
		flat(a, e, d, inner, col)

	func box(xf: Transform3D, size: Vector3, col: Color) -> void:
		var h := size * 0.5
		var p: Array[Vector3] = []
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					p.append(xf * Vector3(sx * h.x, sy * h.y, sz * h.z))
		var o: Vector3 = xf.origin
		quad_flat(p[0], p[1], p[3], p[2], o, col)
		quad_flat(p[4], p[5], p[7], p[6], o, col)
		quad_flat(p[0], p[1], p[5], p[4], o, col)
		quad_flat(p[2], p[3], p[7], p[6], o, col)
		quad_flat(p[0], p[2], p[6], p[4], o, col)
		quad_flat(p[1], p[3], p[7], p[5], o, col)

	# Цилиндр по локальной оси Y от y=0 до y=h, с плавными боковыми нормалями
	func cyl(xf: Transform3D, r0: float, r1: float, h: float, sides: int, col: Color, caps: bool = false) -> void:
		for i in range(sides):
			var a0 := TAU * float(i) / sides
			var a1 := TAU * float(i + 1) / sides
			var d0 := Vector3(cos(a0), 0.0, sin(a0))
			var d1 := Vector3(cos(a1), 0.0, sin(a1))
			var n0 := xf.basis * d0
			var n1 := xf.basis * d1
			n0 = n0.normalized()
			n1 = n1.normalized()
			var b0 := xf * (d0 * r0)
			var b1 := xf * (d1 * r0)
			var t0 := xf * (d0 * r1 + Vector3.UP * h)
			var t1 := xf * (d1 * r1 + Vector3.UP * h)
			var u0 := float(i) / sides * 3.0
			var u1 := float(i + 1) / sides * 3.0
			var vh := h * 2.0
			vert(b0, n0, col, Vector2(u0, vh))
			vert(t1, n1, col, Vector2(u1, 0.0))
			vert(t0, n0, col, Vector2(u0, 0.0))
			vert(b0, n0, col, Vector2(u0, vh))
			vert(b1, n1, col, Vector2(u1, vh))
			vert(t1, n1, col, Vector2(u1, 0.0))
			if caps:
				var cb := xf * Vector3.ZERO
				var ct := xf * (Vector3.UP * h)
				var inner := xf * (Vector3.UP * h * 0.5)
				flat(cb, b0, b1, inner, col)
				flat(ct, t0, t1, inner, col)

	func commit(mesh: ArrayMesh, mat: Material) -> void:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = v
		a[Mesh.ARRAY_NORMAL] = n
		a[Mesh.ARRAY_COLOR] = c
		a[Mesh.ARRAY_TEX_UV] = uv
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)


static func _tex(file: String) -> Texture2D:
	return TextureHelper.get_texture(TEX + file)


static func _next_angle() -> float:
	_counter += 1
	return fposmod(float(_counter) * 2.399963, TAU)


# ─── ЕЛЬ ──────────────────────────────────────────────────────────────────────

static func _spruce_mat(tint: Color) -> StandardMaterial3D:
	var m_col := Color.WHITE
	if tint != Color.WHITE:
		m_col = Color(
			clampf(tint.r / SPRUCE_TINT_REF.r, 0.4, 2.0),
			clampf(tint.g / SPRUCE_TINT_REF.g, 0.4, 2.0),
			clampf(tint.b / SPRUCE_TINT_REF.b, 0.4, 2.0))
	var key := "spruce_%s" % m_col.to_html(false)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("spruce_bough.png")
	m.albedo_color = m_col
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.38
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.metallic_specular = 0.12
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


static func _spruce_far_mat(tint: Color) -> StandardMaterial3D:
	var key := "spruce_far_%s" % tint.to_html(false)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.albedo_color = _spruce_mat(tint).albedo_color
	m.roughness = 1.0
	m.metallic_specular = 0.1
	_mats[key] = m
	return m


static func _bark_mat() -> StandardMaterial3D:
	if _mats.has("bark"):
		return _mats["bark"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("rock_tile.png")
	m.normal_enabled = true
	m.normal_texture = _tex("rock_tile_n.png")
	m.albedo_color = Color(0.25, 0.165, 0.105)
	m.roughness = 1.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats["bark"] = m
	return m


static func _spruce_near(big: bool, variant: int, tint: Color) -> ArrayMesh:
	var key := "spruce_n_%d_%d_%s" % [int(big), variant, tint.to_html(false)]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100 + variant * 13 + int(big) * 7
	var g := Geo.new()
	var tiers := 22 if big else 17
	var dk := Color(1.0, 1.0, 1.0)
	# Тёмная сердцевина, чтобы сквозь лапы не просвечивало небо
	for s in range(7):
		var a0 := TAU * s / 7.0
		var a1 := TAU * (s + 1) / 7.0
		var r := 0.11
		var p0 := Vector3(cos(a0) * r, 0.2, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0.2, sin(a1) * r)
		var top := Vector3(0, 0.92, 0)
		var nn := Vector3(cos((a0 + a1) * 0.5), 0.3, sin((a0 + a1) * 0.5)).normalized()
		g.vert(p0, nn, dk, Vector2(0.008, 0.008))
		g.vert(top, nn, dk, Vector2(0.008, 0.008))
		g.vert(p1, nn, dk, Vector2(0.008, 0.008))
	for t in range(tiers):
		var k := float(t) / float(tiers - 1)
		var y := lerpf(0.16, 0.985, pow(k, 0.92))
		var reach := lerpf(0.47, 0.03, pow(k, 0.95)) * rng.randf_range(0.9, 1.05) * (0.88 if t % 2 == 1 else 1.0)
		var count := int(round(lerpf(11.0 if big else 10.0, 4.0, k)))
		var shift := rng.randf() * TAU
		var tone := rng.randf_range(0.82, 1.08)
		for i in range(count):
			var ang := shift + TAU * (float(i) + rng.randf_range(-0.22, 0.22)) / count
			var dir := Vector3(cos(ang), 0.0, sin(ang))
			var side := Vector3(-dir.z, 0.0, dir.x)
			var ln := reach * rng.randf_range(0.82, 1.1)
			var drop := lerpf(0.075, 0.01, k) * rng.randf_range(0.7, 1.25)
			var y0 := y + rng.randf_range(-0.012, 0.012)
			var nor := (dir * 0.55 + Vector3.UP * 0.85).normalized()
			var cards := [[0.0, 0.62], [0.36, 1.0]] if big and ln > 0.14 else [[0.0, 1.0]]
			for card in cards:
				var s0: float = card[0]
				var s1: float = card[1]
				var wd := ln * (s1 - s0) * rng.randf_range(0.78, 0.98) * (1.0 if big else 1.4) + 0.012
				var prev := []
				for j in range(3):
					var s := float(j) * 0.5
					var whole := lerpf(s0, s1, s)
					var c := dir * (0.015 + ln * whole) + Vector3.UP * (y0 - drop * sin(whole * 2.4))
					var droop := wd * 0.22 * s
					var sh := lerpf(0.42, 1.12, whole) * tone * lerpf(0.86, 1.14, k)
					var col := Color(sh * 0.94, sh, sh * 0.9)
					var vv := 1.0 - s
					var ring := [
						[c - side * wd * 0.5 - Vector3.UP * droop, Vector2(0.04, vv * 0.96 + 0.03)],
						[c, Vector2(0.5, vv * 0.96 + 0.03)],
						[c + side * wd * 0.5 - Vector3.UP * droop, Vector2(0.96, vv * 0.96 + 0.03)],
					]
					if j > 0:
						for q in range(2):
							var a: Array = prev[q]
							var b: Array = prev[q + 1]
							var d: Array = ring[q]
							var e: Array = ring[q + 1]
							var ca: Color = prev[3]
							g.vert(a[0], nor, ca, a[1])
							g.vert(b[0], nor, ca, b[1])
							g.vert(e[0], nor, col, e[1])
							g.vert(a[0], nor, ca, a[1])
							g.vert(e[0], nor, col, e[1])
							g.vert(d[0], nor, col, d[1])
					prev = [ring[0], ring[1], ring[2], col]
	var bark := Geo.new()
	var trunk_h := [0.0, 0.03, 0.09, 0.97]
	var trunk_r := [0.052, 0.038, 0.03, 0.004]
	for seg in range(3):
		bark.cyl(Transform3D(Basis.IDENTITY, Vector3(0, trunk_h[seg], 0)), trunk_r[seg], trunk_r[seg + 1], trunk_h[seg + 1] - trunk_h[seg], 8, Color.WHITE)
	var mesh := ArrayMesh.new()
	g.commit(mesh, _spruce_mat(tint))
	bark.commit(mesh, _bark_mat())
	_meshes[key] = mesh
	return mesh


static func _spruce_far(big: bool, tint: Color) -> ArrayMesh:
	var key := "spruce_f_%d_%s" % [int(big), tint.to_html(false)]
	if _meshes.has(key):
		return _meshes[key]
	var g := Geo.new()
	var levels := 6
	for l in range(levels):
		var k := float(l) / float(levels)
		var y0 := lerpf(0.15, 0.82, k)
		var y1 := y0 + 0.3 * (1.0 - k * 0.45)
		var r := lerpf(0.47, 0.11, k)
		var pts := 12
		for i in range(pts):
			var a0 := TAU * i / pts + float(l) * 0.4
			var a1 := TAU * (i + 1) / pts + float(l) * 0.4
			var r0 := r * (1.0 if i % 2 == 0 else 0.68)
			var r1 := r * (1.0 if (i + 1) % 2 == 0 else 0.68)
			var p0 := Vector3(cos(a0) * r0, y0 - (0.02 if i % 2 == 0 else 0.0), sin(a0) * r0)
			var p1 := Vector3(cos(a1) * r1, y0 - (0.02 if (i + 1) % 2 == 0 else 0.0), sin(a1) * r1)
			var top := Vector3(0, y1, 0)
			var mid := (a0 + a1) * 0.5
			var nor := Vector3(cos(mid), 0.65, sin(mid)).normalized()
			var low := Color(0.1, 0.2, 0.115)
			var hi := Color(0.055, 0.115, 0.07)
			g.vert(p0, nor, low)
			g.vert(top, nor, hi)
			g.vert(p1, nor, low)
	g.cyl(Transform3D(), 0.035, 0.02, 0.3, 5, Color(0.065, 0.045, 0.03))
	var mesh := ArrayMesh.new()
	g.commit(mesh, _spruce_far_mat(tint))
	_meshes[key] = mesh
	return mesh


# Деревья ставятся одним вызовом вместо старых цилиндра и трёх призм
static func add_spruce(parent: Node3D, sz: Vector3, tint: Color) -> void:
	var big := sz.y > 10.0
	var ang := _next_angle()
	var wide := 0.78 if big else 0.98
	var xf := Basis(Vector3.UP, ang) * Basis.from_scale(Vector3(sz.x * wide, sz.y * 1.05, sz.z * wide))
	var near := MeshInstance3D.new()
	near.name = "SpruceNear"
	near.mesh = _spruce_near(big, _counter % 3, tint)
	near.basis = xf
	near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	near.visibility_range_end = NEAR_END
	near.visibility_range_end_margin = 4.0
	parent.add_child(near)
	var far := MeshInstance3D.new()
	far.name = "SpruceFar"
	far.mesh = _spruce_far(big, tint)
	far.basis = xf
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	far.visibility_range_begin = NEAR_END
	far.visibility_range_begin_margin = 4.0
	far.visibility_range_end = FAR_END
	far.visibility_range_end_margin = 12.0
	parent.add_child(far)


# Участок леса одним вызовом: каждому дереву нужен вид [позиция, размер, угол].
# Расстояние считается от центра участка, поэтому пороги больше, чем у одной ели.
static func add_spruce_chunk(parent: Node3D, trees: Array, big: bool, variant: int, tint: Color, near_end: float, far_end: float) -> void:
	var wide := 0.78 if big else 0.98
	var xforms: Array[Transform3D] = []
	for tree in trees:
		var sz: Vector3 = tree[1]
		var b := Basis(Vector3.UP, tree[2]) * Basis.from_scale(Vector3(sz.x * wide, sz.y * 1.05, sz.z * wide))
		xforms.append(Transform3D(b, tree[0]))
	var near := _multimesh_of(_spruce_near(big, variant, tint), xforms)
	near.name = "SpruceChunkNear"
	near.visibility_range_end = near_end
	near.visibility_range_end_margin = 4.0
	parent.add_child(near)
	var far := _multimesh_of(_spruce_far(big, tint), xforms)
	far.name = "SpruceChunkFar"
	far.visibility_range_begin = near_end
	far.visibility_range_begin_margin = 4.0
	far.visibility_range_end = far_end
	far.visibility_range_end_margin = 12.0
	parent.add_child(far)


static func _multimesh_of(mesh: Mesh, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


# ─── ВАЛУН ────────────────────────────────────────────────────────────────────

static func _rock_mat(tint: Color) -> StandardMaterial3D:
	var key := "rock_%s" % tint.to_html(false)
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("rock_tile.png")
	m.normal_enabled = true
	m.normal_texture = _tex("rock_tile_n.png")
	m.normal_scale = 1.1
	m.albedo_color = Color(0.4, 0.41, 0.43) if tint == Color.WHITE else tint.lightened(0.12)
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.96
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 6.0
	m.uv1_scale = Vector3(0.42, 0.42, 0.42)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats[key] = m
	return m


static func _icosphere(level: int) -> Dictionary:
	var t := (1.0 + sqrt(5.0)) * 0.5
	var pts: Array[Vector3] = []
	for p in [[-1, t, 0], [1, t, 0], [-1, -t, 0], [1, -t, 0], [0, -1, t], [0, 1, t], [0, -1, -t], [0, 1, -t], [t, 0, -1], [t, 0, 1], [-t, 0, -1], [-t, 0, 1]]:
		pts.append(Vector3(p[0], p[1], p[2]).normalized())
	var faces := [[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],[11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],[3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
	for _l in range(level):
		var cache := {}
		var nf := []
		var mid := func(a: int, b: int) -> int:
			var k := Vector2i(mini(a, b), maxi(a, b))
			if cache.has(k):
				return cache[k]
			pts.append(((pts[a] + pts[b]) * 0.5).normalized())
			cache[k] = pts.size() - 1
			return cache[k]
		for f in faces:
			var ab: int = mid.call(f[0], f[1])
			var bc: int = mid.call(f[1], f[2])
			var ca: int = mid.call(f[2], f[0])
			nf.append([f[0], ab, ca])
			nf.append([f[1], bc, ab])
			nf.append([f[2], ca, bc])
			nf.append([ab, bc, ca])
		faces = nf
	return {"p": pts, "f": faces}


static func _rock_mesh(variant: int, tint: Color) -> ArrayMesh:
	var key := "rock_%d_%s" % [variant, tint.to_html(false)]
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800 + variant * 31
	var ico := _icosphere(2)
	var pts: Array[Vector3] = ico["p"]
	var planes: Array = []
	for i in range(10):
		var nor := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.1, 1), rng.randf_range(-1, 1)).normalized()
		planes.append([nor, rng.randf_range(0.66, 0.93)])
	var out: Array[Vector3] = []
	for p0 in pts:
		var box_p: Vector3 = p0 / maxf(maxf(abs(p0.x), abs(p0.y)), abs(p0.z))
		var p: Vector3 = p0.lerp(box_p * 0.92, 0.55)
		for pl in planes:
			var pn: Vector3 = pl[0]
			var over: float = p.dot(pn) - float(pl[1])
			if over > 0.0:
				p -= pn * over
		out.append(p)
	var lo := out[0]
	var hi := out[0]
	for p in out:
		lo = Vector3(minf(lo.x, p.x), minf(lo.y, p.y), minf(lo.z, p.z))
		hi = Vector3(maxf(hi.x, p.x), maxf(hi.y, p.y), maxf(hi.z, p.z))
	var ext := hi - lo
	for i in range(out.size()):
		var q := (out[i] - lo) / ext
		var flare := lerpf(1.2, 1.0, clampf(q.y / 0.3, 0.0, 1.0))
		out[i] = Vector3((q.x - 0.5) * 1.08 * flare, q.y * 1.08 - 0.06, (q.z - 0.5) * 1.08 * flare)
	var g := Geo.new()
	var ctr := Vector3(0, 0.5, 0)
	for f in ico["f"]:
		var a := out[f[0]]
		var b := out[f[1]]
		var d := out[f[2]]
		var nor := (b - a).cross(d - a).normalized()
		if nor.dot((a + b + d) / 3.0 - ctr) < 0.0:
			nor = -nor
		var hgt := clampf(((a.y + b.y + d.y) / 3.0), 0.0, 1.0)
		var sh := lerpf(0.55, 1.05, hgt) * rng.randf_range(0.86, 1.1)
		var col := Color(sh, sh, sh)
		# Мох на верхних гранях
		if nor.y > 0.55:
			var moss := clampf((nor.y - 0.55) * 1.8, 0.0, 0.7) * rng.randf_range(0.5, 1.0)
			col = col.lerp(Color(0.34, 0.5, 0.22), moss)
		g.flat(a, b, d, ctr, col)
	var mesh := ArrayMesh.new()
	g.commit(mesh, _rock_mat(tint))
	_meshes[key] = mesh
	return mesh


static func add_rock(parent: Node3D, sz: Vector3, tint: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Boulder"
	mi.mesh = _rock_mesh(_next_variant(4), tint)
	# Крупные скалы часто стоят стеной, поэтому поворот только кратно 180 градусам
	var turn := PI if _counter % 2 == 0 else 0.0
	mi.basis = Basis(Vector3.UP, turn) * Basis.from_scale(sz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 110.0
	mi.visibility_range_end_margin = 12.0
	parent.add_child(mi)


static func _next_variant(n: int) -> int:
	_counter += 1
	return _counter % n


# ─── КУСТ ─────────────────────────────────────────────────────────────────────

static func _bush_mesh(variant: int) -> ArrayMesh:
	var key := "bush_%d" % variant
	if _meshes.has(key):
		return _meshes[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2200 + variant * 19
	var g := Geo.new()
	for i in range(42):
		var inner := i < 8
		var ang := rng.randf() * TAU
		var el := rng.randf_range(-0.35, 1.35)
		var rad := rng.randf_range(0.05, 0.14) if inner else rng.randf_range(0.24, 0.36)
		var dir := Vector3(cos(ang) * cos(el), sin(el), sin(ang) * cos(el))
		var c := Vector3(dir.x * rad, maxf(0.34 + dir.y * rad * 1.45, 0.2), dir.z * rad)
		var nor := dir.normalized()
		var tang := nor.cross(Vector3(rng.randf(), 0.5, rng.randf()).normalized()).normalized()
		var bi := nor.cross(tang).normalized()
		var s := rng.randf_range(0.24, 0.34)
		var sh := rng.randf_range(0.34, 0.55) if inner else rng.randf_range(0.85, 1.25)
		var col := Color(sh, sh, sh * 0.9)
		var a := c - tang * s - bi * s
		var b := c + tang * s - bi * s
		var d := c + tang * s + bi * s
		var e := c - tang * s + bi * s
		g.vert(a, nor, col, Vector2(0, 0))
		g.vert(b, nor, col, Vector2(1, 0))
		g.vert(d, nor, col, Vector2(1, 1))
		g.vert(a, nor, col, Vector2(0, 0))
		g.vert(d, nor, col, Vector2(1, 1))
		g.vert(e, nor, col, Vector2(0, 1))
	var mesh := ArrayMesh.new()
	var m: StandardMaterial3D
	if _mats.has("bush"):
		m = _mats["bush"]
	else:
		m = StandardMaterial3D.new()
		m.albedo_texture = _tex("leaf_cluster.png")
		m.albedo_color = Color(1.6, 1.6, 1.6)
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.4
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.95
		m.metallic_specular = 0.15
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mats["bush"] = m
	g.commit(mesh, m)
	_meshes[key] = mesh
	return mesh


static func add_bush(parent: Node3D, sz: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "BushLeaves"
	mi.mesh = _bush_mesh(_next_variant(3))
	mi.basis = Basis(Vector3.UP, _next_angle()) * Basis.from_scale(sz)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 75.0
	mi.visibility_range_end_margin = 8.0
	parent.add_child(mi)


# ─── ФОНАРЬ ───────────────────────────────────────────────────────────────────

static func add_streetlight(parent: Node3D, height: float) -> void:
	var key := "streetlight_%.2f" % height
	var mesh: ArrayMesh
	if _meshes.has(key):
		mesh = _meshes[key]
	else:
		var metal := Geo.new()
		var col := Color(0.42, 0.42, 0.42)
		metal.cyl(Transform3D(), 0.17, 0.14, 0.5, 8, col * 0.8)
		metal.cyl(Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), 0.11, 0.065, height - 0.5, 8, col)
		metal.cyl(Transform3D(Basis.IDENTITY, Vector3(0, height * 0.48, 0)), 0.1, 0.1, 0.06, 8, col * 0.7)
		# Кронштейн изгибается вперёд
		var arm0 := Vector3(0, height - 0.02, 0)
		var arm1 := Vector3(0, height + 0.26, 0.22)
		var arm2 := Vector3(0, height + 0.36, 0.72)
		for seg in [[arm0, arm1], [arm1, arm2]]:
			var d: Vector3 = seg[1] - seg[0]
			var y: Vector3 = d.normalized()
			var x := Vector3.RIGHT
			var z := x.cross(y).normalized()
			metal.cyl(Transform3D(Basis(x, y, z), seg[0]), 0.05, 0.045, d.length(), 6, col)
		# Корпус плафона
		metal.box(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(4.0)), Vector3(0, height + 0.36, 0.95)), Vector3(0.36, 0.1, 0.66), col * 0.85)
		metal.box(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(4.0)), Vector3(0, height + 0.42, 0.9)), Vector3(0.26, 0.06, 0.4), col * 0.7)
		var lens := Geo.new()
		lens.box(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(4.0)), Vector3(0, height + 0.3, 0.98)), Vector3(0.28, 0.03, 0.5), Color.WHITE)
		mesh = ArrayMesh.new()
		var mm := _rust_mat()
		metal.commit(mesh, mm)
		var lm: StandardMaterial3D
		if _mats.has("lamp_lens"):
			lm = _mats["lamp_lens"]
		else:
			lm = StandardMaterial3D.new()
			lm.albedo_color = Color(1.0, 0.92, 0.72)
			lm.emission_enabled = true
			lm.emission = Color(1.0, 0.84, 0.55)
			lm.emission_energy_multiplier = 3.0
			_mats["lamp_lens"] = lm
		lens.commit(mesh, lm)
		_meshes[key] = mesh
	var mi := MeshInstance3D.new()
	mi.name = "Streetlight"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 110.0
	parent.add_child(mi)


# ─── РАЗБИТАЯ МАШИНА ──────────────────────────────────────────────────────────

static func _rust_mat() -> StandardMaterial3D:
	if _mats.has("rust"):
		return _mats["rust"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("car_rust.png")
	m.normal_enabled = true
	m.normal_texture = _tex("car_rust_n.png")
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.82
	m.metallic = 0.3
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.42, 0.42, 0.42)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats["rust"] = m
	return m


static func _car_mesh() -> ArrayMesh:
	if _meshes.has("car"):
		return _meshes["car"]
	var rust := Geo.new()
	var dark := Geo.new()
	var rc := Color(0.72, 0.7, 0.68)
	var pc := Color(0.86, 0.86, 0.86)
	var bl := Color(0.035, 0.035, 0.04)
	var tilt := func(rx: float, ry: float, rz: float) -> Basis:
		return Basis.from_euler(Vector3(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz)))
	# Кузов
	rust.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.58, 0)), Vector3(1.86, 0.46, 4.1), pc)
	rust.box(Transform3D(tilt.call(5.0, 0.0, 1.5), Vector3(0, 0.87, 1.42)), Vector3(1.72, 0.1, 1.2), rc)
	rust.box(Transform3D(tilt.call(-3.0, 0.0, 0.0), Vector3(0, 0.86, -1.62)), Vector3(1.72, 0.1, 0.82), pc)
	# Бамперы и решётка
	rust.box(Transform3D(tilt.call(0.0, 0.0, 5.0), Vector3(0, 0.42, 2.12)), Vector3(1.9, 0.16, 0.14), rc * 0.6)
	rust.box(Transform3D(tilt.call(0.0, 4.0, -7.0), Vector3(0.1, 0.36, -2.12)), Vector3(1.86, 0.16, 0.14), rc * 0.6)
	dark.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 2.05)), Vector3(1.5, 0.22, 0.04), bl)
	# Пустые глазницы фар
	for hx in [-0.68, 0.68]:
		dark.box(Transform3D(Basis.IDENTITY, Vector3(hx, 0.68, 2.06)), Vector3(0.3, 0.17, 0.05), bl)
	# Двери: тёмные швы и отогнутый край
	for sx in [-1.0, 1.0]:
		for zz in [0.92, -0.08, -1.05]:
			dark.box(Transform3D(Basis.IDENTITY, Vector3(sx * 0.935, 0.6, zz)), Vector3(0.015, 0.42, 0.025), bl)
		dark.box(Transform3D(Basis.IDENTITY, Vector3(sx * 0.935, 0.68, 0.45)), Vector3(0.015, 0.03, 0.15), bl)
	rust.box(Transform3D(tilt.call(0.0, -9.0, 0.0), Vector3(-1.0, 0.6, 0.38)), Vector3(0.05, 0.42, 1.0), rc)
	# Стойки кабины
	var pillar := func(a: Vector3, b: Vector3, th: float) -> void:
		var d: Vector3 = b - a
		var y: Vector3 = d.normalized()
		var x: Vector3 = Vector3.RIGHT if abs(y.x) < 0.8 else Vector3.FORWARD
		var z: Vector3 = x.cross(y).normalized()
		x = y.cross(z).normalized()
		rust.box(Transform3D(Basis(x, y, z), (a + b) * 0.5), Vector3(th, d.length(), th), pc)
	var rh := 1.34
	for sx in [-1.0, 1.0]:
		pillar.call(Vector3(sx * 0.8, 0.86, 0.82), Vector3(sx * 0.7, rh - 0.1 if sx < 0.0 else rh - 0.02, 0.12), 0.08)
		pillar.call(Vector3(sx * 0.82, 0.86, -0.14), Vector3(sx * 0.72, rh, -0.14), 0.08)
		pillar.call(Vector3(sx * 0.8, 0.86, -1.16), Vector3(sx * 0.7, rh, -0.8), 0.1)
	# Кабина закрыта тёмными окнами, под кузовом тёмное днище
	var cab_in := Vector3(0, 1.05, -0.2)
	var bl_f := Vector3(-0.82, 0.86, 0.82)
	var br_f := Vector3(0.82, 0.86, 0.82)
	var bl_b := Vector3(-0.82, 0.86, -1.16)
	var br_b := Vector3(0.82, 0.86, -1.16)
	var tl_f := Vector3(-0.71, rh - 0.02, 0.14)
	var tr_f := Vector3(0.71, rh - 0.02, 0.14)
	var tl_b := Vector3(-0.71, rh - 0.02, -0.84)
	var tr_b := Vector3(0.71, rh - 0.02, -0.84)
	dark.quad_flat(bl_f, br_f, tr_f, tl_f, cab_in, bl)
	dark.quad_flat(bl_b, br_b, tr_b, tl_b, cab_in, bl)
	dark.quad_flat(bl_f, bl_b, tl_b, tl_f, cab_in, bl)
	dark.quad_flat(br_f, br_b, tr_b, tr_f, cab_in, bl)
	dark.box(Transform3D(Basis.IDENTITY, Vector3(0, 0.28, 0)), Vector3(1.7, 0.16, 3.9), bl)
	# Смятая крыша: вогнутая сетка с провалом посередине
	var res := 6
	var grid: Array = []
	for iz in range(res + 1):
		var row: Array = []
		var fz := float(iz) / res
		for ix in range(res + 1):
			var fx := float(ix) / res
			var px := lerpf(-0.74, 0.74, fx)
			var pz := lerpf(-0.86, 0.16, fz)
			var dx := (px + 0.1) / 0.62
			var dz := (pz + 0.34) / 0.46
			var dent := exp(-(dx * dx + dz * dz)) * 0.27
			row.append(Vector3(px, rh + 0.03 - dent - abs(fx - 0.5) * 0.09 + sin(fx * 11.0 + fz * 7.0) * 0.012, pz))
		grid.append(row)
	for iz in range(res):
		for ix in range(res):
			var inner := Vector3(0, 0.3, -0.34)
			var shade := pc.lerp(rc, 0.3 + 0.7 * float((ix + iz * 3) % 4) / 3.0)
			rust.quad_flat(grid[iz][ix], grid[iz][ix + 1], grid[iz + 1][ix + 1], grid[iz + 1][ix], inner, shade)
	# Колёса; одно провалилось
	var wheels := [[-0.88, 1.32, 0.0], [0.88, 1.32, 0.0], [-0.9, -1.3, -0.1], [0.88, -1.3, 0.0]]
	for w in wheels:
		var r := 0.33
		var bas := Basis(Vector3.BACK, PI * 0.5)
		var wp := Vector3(0.94 if float(w[0]) > 0.0 else -0.7, r + float(w[2]), float(w[1]))
		dark.cyl(Transform3D(bas, wp), r, r, 0.24, 12, Color(0.05, 0.05, 0.05), true)
		rust.cyl(Transform3D(bas, wp + Vector3(-0.01, 0, 0)), 0.15, 0.15, 0.26, 8, rc * 0.7, true)
	var mesh := ArrayMesh.new()
	rust.commit(mesh, _rust_mat())
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.02, 0.022, 0.026)
	dm.roughness = 0.42
	dm.metallic_specular = 0.4
	dark.commit(mesh, dm)
	_meshes["car"] = mesh
	return mesh


static func add_car_wreck(parent: Node3D, sz: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "CarWreck"
	mi.mesh = _car_mesh()
	mi.basis = Basis.from_euler(Vector3(deg_to_rad(1.5), 0.0, deg_to_rad(-1.2))) * Basis.from_scale(sz / Vector3(2.1, 1.4, 4.4))
	mi.visibility_range_end = 110.0
	parent.add_child(mi)


# ─── ВЫСТУПАЮЩИЕ КИРПИЧИ ──────────────────────────────────────────────────────

static func _brick_mesh() -> ArrayMesh:
	if _meshes.has("brick"):
		return _meshes["brick"]
	# Кирпич единичной глубины со скошенными гранями; основание утоплено в стену
	var hw := 0.188
	var hh := 0.073
	var bv := 0.012
	var a := []
	var g := Geo.new()
	var f := [Vector3(-hw + bv, -hh + bv, 1), Vector3(hw - bv, -hh + bv, 1), Vector3(hw - bv, hh - bv, 1), Vector3(-hw + bv, hh - bv, 1)]
	var b := [Vector3(-hw, -hh, 0), Vector3(hw, -hh, 0), Vector3(hw, hh, 0), Vector3(-hw, hh, 0)]
	var uvf := func(p: Vector3) -> Vector2:
		return Vector2(p.x / 0.4 + 0.5, p.y / 0.167 + 0.5)
	var w := Color.WHITE
	var nf := Vector3(0, 0, 1)
	for idx in [[0, 2, 1], [0, 3, 2]]:
		for i in idx:
			g.vert(f[i], nf, w, uvf.call(f[i]))
	for i in range(4):
		var j := (i + 1) % 4
		var mid: Vector3 = (b[i] + b[j]) * 0.5
		var nor := Vector3(mid.x / hw, mid.y / hh, 0.0).normalized()
		nor = (nor + Vector3(0, 0, 0.35)).normalized()
		for p in [b[i], f[j], b[j], b[i], f[i], f[j]]:
			g.vert(p, nor, w * 0.82, uvf.call(p) * 0.92)
	var mesh := ArrayMesh.new()
	var m := StandardMaterial3D.new()
	m.albedo_texture = _tex("brick_face.png")
	m.normal_enabled = true
	m.normal_texture = _tex("brick_face_n.png")
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.metallic_specular = 0.25
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	g.commit(mesh, m)
	_meshes["brick"] = mesh
	return mesh


static func add_protruding_bricks(wall: Node3D, sz: Vector3, tint: Color, tri_scale: float) -> void:
	if sz.y < 1.2 or maxf(sz.x, sz.z) < 0.9:
		return
	var rows := 12.0
	var cols := 5.0
	var brick_h := 1.0 / (rows * tri_scale)
	var brick_w := 1.0 / (cols * tri_scale)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(wall.position)
	var phase := Vector2(rng.randf() * 10.0, rng.randf() * 10.0)
	var faces := []
	if sz.x >= sz.z * 2.0:
		faces = [Vector3(0, 0, 1), Vector3(0, 0, -1)]
	elif sz.z >= sz.x * 2.0:
		faces = [Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	else:
		faces = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)]
	var palette := [Color(0.72, 0.31, 0.17), Color(0.62, 0.25, 0.14), Color(0.8, 0.38, 0.2), Color(0.54, 0.22, 0.14), Color(0.74, 0.42, 0.28)]
	var items: Array[Transform3D] = []
	var tones: Array[Color] = []
	for face in faces:
		var on_z: bool = abs(face.z) > 0.5
		var half_len: float = (sz.x if on_z else sz.z) * 0.5
		var half_h: float = sz.y * 0.5
		var surf: float = (sz.z if on_z else sz.x) * 0.5
		var i_lo := int(floor(-half_h / brick_h))
		var i_hi := int(ceil(half_h / brick_h))
		for i in range(i_lo, i_hi):
			var y := -(float(i) + 0.5) * brick_h
			if abs(y) > half_h - brick_h * 0.7:
				continue
			var odd := posmod(i, 2) == 1
			var c_lo := int(floor(-half_len / brick_w)) - 1
			var c_hi := int(ceil(half_len / brick_w)) + 1
			for c in range(c_lo, c_hi):
				var u := (float(c) + (0.0 if odd else 0.5)) * brick_w
				if abs(u) > half_len - brick_w * 0.56:
					continue
				var nx := sin(u * 1.1 + phase.x) + sin(u * 0.47 + y * 0.9 + phase.y) + sin(y * 1.7 - u * 0.6)
				var prob := 0.03 + 0.34 * smoothstep(0.25, 1.7, nx)
				if rng.randf() > prob:
					continue
				var depth := rng.randf_range(0.014, 0.042)
				var p: Vector3
				var bas: Basis
				if on_z:
					p = Vector3(u, y, face.z * surf)
					bas = Basis(Vector3.RIGHT * face.z, Vector3.UP, Vector3(0, 0, face.z))
				else:
					# На боковой грани текстура идёт по -z
					p = Vector3(face.x * surf, y, -u)
					bas = Basis(Vector3(0, 0, -face.x), Vector3.UP, Vector3(face.x, 0, 0))
				p += Vector3(rng.randf_range(-0.004, 0.004), rng.randf_range(-0.003, 0.003), 0.0) if on_z else Vector3(0.0, rng.randf_range(-0.003, 0.003), rng.randf_range(-0.004, 0.004))
				bas = bas * Basis(Vector3.UP, rng.randf_range(-0.012, 0.012)) * Basis.from_scale(Vector3(1.0, 1.0, depth))
				items.append(Transform3D(bas, p))
				var tn: Color = palette[rng.randi() % palette.size()] * rng.randf_range(0.82, 1.1)
				tones.append(Color(tn.r * tint.r, tn.g * tint.g, tn.b * tint.b).srgb_to_linear())
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _brick_mesh()
	mm.instance_count = items.size()
	for i in range(items.size()):
		mm.set_instance_transform(i, items[i])
		mm.set_instance_color(i, tones[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "RaisedBricks"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = 32.0
	mmi.visibility_range_end_margin = 4.0
	wall.add_child(mmi)


# ─── УПРОЩЕНИЕ ПРИМИТИВОВ ─────────────────────────────────────────────────────

# По умолчанию SphereMesh содержит 4224 треугольника, CylinderMesh и TorusMesh тоже
# очень плотные. На заклёпках, ручках и петлях эта плотность не видна, а карта
# из-за неё рисует миллионы треугольников. Мелкие детали также не отбрасывают тень.
static func simplify_primitives(node: Node) -> void:
	if node is MeshInstance3D:
		_simplify_mesh(node as MeshInstance3D)
	for c in node.get_children():
		simplify_primitives(c)


static func _simplify_mesh(mi: MeshInstance3D) -> void:
	var m := mi.mesh
	if m == null:
		return
	var sc := mi.scale.abs()
	var factor := maxf(maxf(sc.x, sc.y), sc.z)
	var extent := 0.0
	if m is SphereMesh:
		var sm := m as SphereMesh
		extent = sm.radius * factor
		var seg := 8 if extent < 0.06 else (12 if extent < 0.25 else 20)
		sm.radial_segments = seg
		sm.rings = maxi(seg / 2, 4)
	elif m is CylinderMesh:
		var cm := m as CylinderMesh
		extent = maxf(cm.top_radius, cm.bottom_radius) * factor
		cm.radial_segments = 8 if extent < 0.06 else (12 if extent < 0.25 else 20)
		cm.rings = 1
		extent = maxf(extent, cm.height * 0.5 * factor)
	elif m is TorusMesh:
		var tm := m as TorusMesh
		extent = tm.outer_radius * factor
		tm.rings = 10 if extent < 0.08 else 16
		tm.ring_segments = 6 if extent < 0.08 else 10
	elif m is CapsuleMesh:
		var cp := m as CapsuleMesh
		extent = cp.height * 0.5 * factor
		cp.radial_segments = 10
		cp.rings = 3
	else:
		return
	if extent < 0.12:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
