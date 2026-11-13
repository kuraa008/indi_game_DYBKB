class_name CutsceneCast
extends RefCounted

# Актёры кат-сцен. Итан — модель героя (PlayerModel) как есть; Сэм, Крейн и
# «что-то в отцовской одежде» — та же модель, перекрашенная шейдером
# cutscene_person.gdshader (грязь, щетина, клетка, седина, чёрная кожа, пепел).
# Позы задаются словарём {кость: Vector3(углы в радианах)} + "hips_pos".
# Кость смотрит лицом вдоль +Z. Бедро вперёд: thL.x = -1.57; колено: knL.x = +1.57;
# наклон корпуса вперёд: spineA.x > 0; кивок: head.x > 0; рука вперёд: shL.x < 0.

const PERSON_SHADER := preload("res://shaders/cutscene_person.gdshader")
const SKIN_SHADER := preload("res://shaders/cutscene_skin.gdshader")
const TEX := "res://assets/textures/player_character/baked/player_%s.png"
const BONES := ["hips", "spineA", "chest", "neck", "head", "shL", "elL", "wrL", "handL", "shR", "elR", "wrR", "handR", "thL", "knL", "anL", "thR", "knR", "anR"]
# Голова относительно кости head: глаза
const EYE_OFS := Vector3(0.031, 0.101, 0.104)

const ETHAN := {}
const SAM := {"dirt": 0.8, "pale": 0.45, "stubble": 0.85, "plaid": 1.0, "plaid_a": Color(0.24, 0.27, 0.21), "plaid_b": Color(0.07, 0.08, 0.07), "trouser_dark": 0.55, "thin": 0.88}
const CRANE := {"dirt": 0.55, "pale": 0.8, "grey_hair": 1.0, "plaid": 1.0, "plaid_a": Color(0.2, 0.17, 0.13), "plaid_b": Color(0.09, 0.08, 0.07), "tatter": 0.7, "trouser_dark": 0.8, "thin": 0.78, "stubble": 0.3}
const FATHER_THING := {"plaid": 1.0, "plaid_a": Color(0.44, 0.07, 0.05), "plaid_b": Color(0.035, 0.03, 0.03), "skin_black": 1.0, "trouser_dark": 0.5, "tall": 1.08}


static func person(look: Dictionary = {}) -> PlayerModel:
	var m := PlayerModel.new()
	var sm := ShaderMaterial.new()
	sm.shader = PERSON_SHADER
	for side in ["front", "back", "left", "right"]:
		sm.set_shader_parameter("tex_" + side, load(TEX % side))
	for k in look:
		if not (k in ["thin", "tall"]):
			sm.set_shader_parameter(k, look[k])
	m.body.set_surface_override_material(0, sm)
	m.upper.set_surface_override_material(0, sm)
	m.set_meta("mat", sm)
	m.set_shadows(true)
	if look.has("tall"):
		m.scale = Vector3.ONE * float(look["tall"])
	if look.has("thin"):
		m.set_meta("thin", float(look["thin"]))
	pose(m, {})
	return m


static func ethan() -> PlayerModel:
	return person(ETHAN)


static func sam() -> PlayerModel:
	var m := person(SAM)
	return m


# Крейн без шкуры: худой старик с длинными седыми волосами и бородой
static func crane() -> PlayerModel:
	var look := CRANE.duplicate()
	look["thin"] = 0.8
	var m := person(look)
	beard(m, Color(0.66, 0.64, 0.6), 1.35)
	hair(m, Color(0.62, 0.6, 0.56))
	brows(m, Color(0.5, 0.49, 0.47))
	rags(m)
	eyes(m, "empty")
	return m


static func father_thing() -> PlayerModel:
	var m := person(FATHER_THING)
	eyes(m, "black")
	return m


static func set_param(m: Node, key: String, value: Variant) -> void:
	var sm: ShaderMaterial = m.get_meta("mat") if m.has_meta("mat") else null
	if sm:
		sm.set_shader_parameter(key, value)


# ════════════════════════════════════════════════════════════
#  Позы
# ════════════════════════════════════════════════════════════
static func pose(m: PlayerModel, p: Dictionary) -> void:
	var sk := m.skeleton
	for b in BONES:
		var i := sk.find_bone(b)
		if i < 0:
			continue
		var e: Vector3 = p.get(b, Vector3.ZERO)
		sk.set_bone_pose_rotation(i, Quaternion(Basis.from_euler(e, EULER_ORDER_XYZ)))
	var hi := sk.find_bone("hips")
	sk.set_bone_pose_position(hi, Vector3(0, PlayerModel.HIP_Y, 0) + (p.get("hips_pos", Vector3.ZERO) as Vector3))
	var thin: float = m.get_meta("thin", 1.0)
	if thin < 0.999:
		sk.set_bone_pose_scale(hi, Vector3(thin, 1.0, thin))
		sk.set_bone_pose_scale(sk.find_bone("neck"), Vector3(1.0 / thin, 1.0, 1.0 / thin))


# Смесь двух поз (u = 0 → a, 1 → b)
static func mix_pose(a: Dictionary, b: Dictionary, u: float) -> Dictionary:
	var r := {}
	for k in BONES + ["hips_pos"]:
		var va: Vector3 = a.get(k, Vector3.ZERO)
		var vb: Vector3 = b.get(k, Vector3.ZERO)
		r[k] = va.lerp(vb, u)
	return r


static func with(p: Dictionary, extra: Dictionary) -> Dictionary:
	var r := p.duplicate()
	r.merge(extra, true)
	return r


# Сидит прямо, предплечья на столе (стол ~0.76 м, сиденье ~0.46 м)
static func sit_table() -> Dictionary:
	return {
		"hips_pos": Vector3(0, -0.47, -0.04),
		"thL": Vector3(-1.52, 0.06, 0), "thR": Vector3(-1.52, -0.06, 0),
		"knL": Vector3(1.5, 0, 0), "knR": Vector3(1.5, 0, 0),
		"spineA": Vector3(0.05, 0, 0), "chest": Vector3(0.04, 0, 0),
		"shL": Vector3(-0.62, 0, -0.12), "elL": Vector3(-1.05, 0, 0), "wrL": Vector3(0.05, 0, 0),
		"shR": Vector3(-0.62, 0, 0.12), "elR": Vector3(-1.05, 0, 0), "wrR": Vector3(0.05, 0, 0),
	}


# Сидит, привязан за запястья к подлокотникам, голова опущена
static func sit_tied() -> Dictionary:
	return with(sit_table(), {
		"spineA": Vector3(0.22, 0, 0), "chest": Vector3(0.2, 0, 0), "neck": Vector3(0.25, 0, 0), "head": Vector3(0.35, 0, 0.05),
		"shL": Vector3(-0.35, 0, -0.18), "elL": Vector3(-0.75, 0, 0),
		"shR": Vector3(-0.35, 0, 0.18), "elR": Vector3(-0.75, 0, 0),
	})


# Сидит на полу, спиной к стене, ноги вперёд, руки безвольно
static func sit_floor() -> Dictionary:
	return {
		"hips_pos": Vector3(0, -0.84, 0.02),
		"thL": Vector3(-1.38, 0.12, 0), "thR": Vector3(-1.45, -0.1, 0),
		"knL": Vector3(0.75, 0, 0), "knR": Vector3(0.35, 0, 0),
		"anL": Vector3(-0.3, 0, 0), "anR": Vector3(-0.3, 0, 0),
		"spineA": Vector3(-0.12, 0, 0), "chest": Vector3(-0.05, 0, 0), "neck": Vector3(0.18, 0, 0), "head": Vector3(0.2, 0.25, 0.12),
		"shL": Vector3(-0.35, 0, -0.32), "elL": Vector3(-0.55, 0, 0),
		"shR": Vector3(-0.3, 0, 0.3), "elR": Vector3(-0.4, 0, 0),
	}


# На коленях, корпус прямо
static func kneel() -> Dictionary:
	return {
		"hips_pos": Vector3(0, -0.4, 0.02),
		"thL": Vector3(-0.08, 0.05, 0), "thR": Vector3(-0.08, -0.05, 0),
		"knL": Vector3(1.62, 0, 0), "knR": Vector3(1.62, 0, 0),
		"anL": Vector3(0.9, 0, 0), "anR": Vector3(0.9, 0, 0),
		"spineA": Vector3(0.08, 0, 0), "chest": Vector3(0.05, 0, 0), "neck": Vector3(0.05, 0, 0),
		"shL": Vector3(0.05, 0, -0.08), "elL": Vector3(-0.25, 0, 0),
		"shR": Vector3(0.05, 0, 0.08), "elR": Vector3(-0.25, 0, 0),
	}


# Стоит; руки чуть согнуты
static func stand() -> Dictionary:
	return {"shL": Vector3(0.02, 0, -0.06), "shR": Vector3(0.02, 0, 0.06), "elL": Vector3(-0.12, 0, 0), "elR": Vector3(-0.12, 0, 0)}


# ════════════════════════════════════════════════════════════
#  Добавки: глаза, борода
# ════════════════════════════════════════════════════════════
static func _head_attach(m: PlayerModel, nm: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.name = nm
	ba.bone_name = "head"
	m.skeleton.add_child(ba)
	return ba


# "empty" — мутные белёсые; "black" — чёрные провалы с отблеском; "none" — убрать
static func eyes(m: PlayerModel, kind: String) -> void:
	var old := m.skeleton.get_node_or_null("Eyes")
	if old:
		old.queue_free()
	if kind == "none":
		return
	var ba := _head_attach(m, "Eyes")
	var em := StandardMaterial3D.new()
	if kind == "empty":
		em.albedo_color = Color(0.78, 0.8, 0.78)
		em.emission_enabled = true
		em.emission = Color(0.16, 0.17, 0.17)
		em.roughness = 0.15
	else:
		em.albedo_color = Color(0.0, 0.0, 0.0)
		em.roughness = 0.05
		em.metallic_specular = 1.0
	for s in [-1.0, 1.0]:
		var e := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.0125
		sm.height = 0.025
		sm.radial_segments = 10
		sm.rings = 6
		e.mesh = sm
		e.material_override = em
		e.scale = Vector3(1.1, 0.62, 0.45)
		e.position = Vector3(EYE_OFS.x * s, EYE_OFS.y, EYE_OFS.z)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ba.add_child(e)


# Борода из прядей: пучки от челюсти и подбородка вниз, у старика спутанные
static func beard(m: PlayerModel, col: Color, long: float = 1.0) -> void:
	var ba := _head_attach(m, "Beard")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1815
	var locks := 34 if long > 1.0 else 20
	for i in locks:
		var a := rng.randf_range(-1.3, 1.3)
		var root := Vector3(sin(a) * 0.064, 0.032 - absf(a) * 0.016 + rng.randf_range(-0.01, 0.006), cos(a) * 0.068 + 0.012)
		var len := rng.randf_range(0.1, 0.18) * (1.0 - absf(a) * 0.3) * long
		var flow := Vector3(sin(a) * 0.12, -1.0, 0.3 + rng.randf_range(-0.1, 0.1)).normalized()
		var base_c := col * rng.randf_range(0.82, 1.08)
		for j in (8 if long > 1.0 else 5):
			var p: Vector3 = root + Vector3(rng.randf_range(-0.006, 0.006), rng.randf_range(-0.005, 0.005), rng.randf_range(-0.004, 0.004))
			var dir := (flow + Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.05, 0.05))).normalized()
			var w := rng.randf_range(0.0022, 0.0042)
			var l := len * rng.randf_range(0.75, 1.1)
			var c := base_c * rng.randf_range(0.88, 1.1)
			c.a = 1.0
			_strand(st, p, dir, l, w, c, c.darkened(0.25), 5, rng, Vector3(sin(a), 0.0, cos(a)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _hair_mat()
	ba.add_child(mi)


# Прядь: лента из нескольких звеньев, от корня к кончику тоньше и светлее
static func _strand(st: SurfaceTool, root: Vector3, dir: Vector3, length: float, width: float, tip_col: Color, root_col: Color, steps: int, rng: RandomNumberGenerator, out: Vector3) -> void:
	var p := root
	var d := dir
	for s in steps:
		var q := p + d * (length / steps)
		d = (d + Vector3(rng.randf_range(-0.1, 0.1), -0.08, rng.randf_range(-0.08, 0.08))).normalized()
		var side := d.cross(out).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var w0 := width * (1.0 - float(s) / steps * 0.75)
		var w1 := width * (1.0 - float(s + 1) / steps * 0.75)
		var c0 := root_col.lerp(tip_col, float(s) / steps)
		var c1 := root_col.lerp(tip_col, float(s + 1) / steps)
		for v in [[p - side * w0, c0], [p + side * w0, c0], [q + side * w1, c1], [p - side * w0, c0], [q + side * w1, c1], [q - side * w1, c1]]:
			st.set_color(v[1])
			st.set_normal(out)
			st.add_vertex(v[0])
		p = q


static func _hair_mat() -> StandardMaterial3D:
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hm.roughness = 0.62
	hm.metallic_specular = 0.35
	return hm


# Брови и усы: короткие седые пряди над глазами и над ртом
static func brows(m: PlayerModel, col: Color) -> void:
	var ba := _head_attach(m, "Brows")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var tufts := []
	for s in [-1.0, 1.0]:
		for k in 14:
			var x: float = float(s) * (0.012 + k * 0.0034)
			tufts.append([Vector3(x, EYE_OFS.y + 0.024 + k * 0.0005, EYE_OFS.z + 0.006 - k * 0.0011), Vector3(s * 0.9, 0.12, 0.25), 0.016, 0.004])
		for k in 22:
			var x: float = float(s) * (0.003 + k * 0.0019)
			tufts.append([Vector3(x, EYE_OFS.y - 0.05, EYE_OFS.z + 0.013 - k * 0.0012), Vector3(s * 0.35, -1.0, 0.25), 0.034, 0.0038])
	for tf in tufts:
		var p: Vector3 = tf[0]
		var dir: Vector3 = (tf[1] as Vector3).normalized()
		var len: float = tf[2] * rng.randf_range(0.8, 1.25)
		var w: float = tf[3]
		var side := dir.cross(Vector3.FORWARD).normalized()
		var q := p + dir * len
		var c := (col * rng.randf_range(0.8, 1.1)).srgb_to_linear()
		c.a = 1.0
		var nrm := Vector3(0, 0.3, 1).normalized()
		for v in [p - side * w, p + side * w, q, ]:
			st.set_color(c)
			st.set_normal(nrm)
			st.add_vertex(v)
	var bm := StandardMaterial3D.new()
	bm.vertex_color_use_as_albedo = true
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	bm.roughness = 0.9
	bm.metallic_specular = 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = bm
	ba.add_child(mi)


# Охотничье снаряжение: кожаный ремень с железной пряжкой и нож в ножнах
static func rags(m: PlayerModel) -> void:
	var hip := BoneAttachment3D.new()
	hip.name = "Rags"
	hip.bone_name = "hips"
	m.skeleton.add_child(hip)
	# Ремень, пряжка и ножны на правом боку
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color(0.17, 0.1, 0.055)
	leather.roughness = 0.7
	var belt := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.155
	tm.outer_radius = 0.175
	tm.rings = 24
	tm.ring_segments = 6
	belt.mesh = tm
	belt.material_override = leather
	belt.scale = Vector3(1.0, 1.8, 0.74)
	belt.position = Vector3(0, 0.05, 0)
	hip.add_child(belt)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.28, 0.26, 0.22)
	iron.metallic = 0.7
	iron.roughness = 0.45
	var buckle := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 0.04, 0.012)
	buckle.mesh = bm
	buckle.material_override = iron
	buckle.position = Vector3(0, 0.05, 0.13)
	hip.add_child(buckle)
	var sheath := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.03, 0.2, 0.05)
	sheath.mesh = sm
	sheath.material_override = leather
	sheath.position = Vector3(-0.17, -0.06, 0.02)
	sheath.rotation_degrees = Vector3(0, 0, -8)
	hip.add_child(sheath)
	var handle := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.012
	hm.bottom_radius = 0.014
	hm.height = 0.1
	hm.radial_segments = 8
	handle.mesh = hm
	handle.material_override = leather
	handle.position = Vector3(-0.175, 0.08, 0.02)
	hip.add_child(handle)


# Длинные спутанные волосы: растут по всей голове кроме лица, лежат по черепу и падают на плечи
static func hair(m: PlayerModel, col: Color) -> void:
	var ba := _head_attach(m, "Hair")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1894
	var centre := Vector3(0.0, 0.1, 0.008)
	var radii := Vector3(0.093, 0.155, 0.12)
	var made := 0
	var tries := 0
	while made < 70 and tries < 400:
		tries += 1
		var theta := rng.randf() * TAU
		var elev := asin(rng.randf_range(-0.1, 1.0))
		var front := cos(theta)
		# Лицо и лоб открыты: спереди волосы начинаются только высоко
		if front > 0.35 and elev < 0.95:
			continue
		var unit := Vector3(sin(theta) * cos(elev), sin(elev), cos(theta) * cos(elev))
		var root := centre + unit * radii
		var base_c := col * rng.randf_range(0.8, 1.12)
		var l := rng.randf_range(0.24, 0.38)
		for j in 6:
			var p := root + Vector3(rng.randf_range(-0.008, 0.008), rng.randf_range(-0.006, 0.006), rng.randf_range(-0.008, 0.008))
			var c := base_c * rng.randf_range(0.88, 1.1)
			c.a = 1.0
			_drape(st, p, centre, radii, l * rng.randf_range(0.8, 1.1), rng.randf_range(0.0028, 0.005), c, c.darkened(0.3), rng)
		made += 1
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _hair_mat()
	ba.add_child(mi)
	# Шапка волос на макушке: зачёсанные назад пряди поверх черепа, лоб открыт
	var cap := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.is_hemisphere = true
	sm.radius = 1.0
	sm.height = 1.0
	sm.radial_segments = 28
	sm.rings = 10
	cap.mesh = sm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = col * 1.12
	cm.albedo_texture = TextureHelper.get_texture(TextureHelper.SURFACE + "wood.png")
	cm.normal_enabled = true
	cm.normal_texture = TextureHelper.get_texture(TextureHelper.SURFACE + "wood_n.png")
	cm.normal_scale = 1.6
	cm.uv1_scale = Vector3(10.0, 0.6, 1.0)
	cm.roughness = 0.6
	cm.metallic_specular = 0.35
	cap.material_override = cm
	cap.scale = radii * 1.03
	cap.position = centre + Vector3(0.0, -0.01, -0.014)
	cap.rotation_degrees = Vector3(-24.0, 0.0, 0.0)
	ba.add_child(cap)


# Прядь, которая сначала ложится по голове назад и вниз, а потом свисает
static func _drape(st: SurfaceTool, root: Vector3, centre: Vector3, radii: Vector3, length: float, width: float, tip_col: Color, root_col: Color, rng: RandomNumberGenerator) -> void:
	var steps := 9
	var p := root
	var away := ((root - centre) / radii).normalized()
	var d := (Vector3(away.x * 0.4, -0.6, -0.7) + Vector3(rng.randf_range(-0.15, 0.15), 0, 0)).normalized()
	for s in steps:
		var q := p + d * (length / steps)
		# Не проваливаться внутрь головы: выталкиваем точку на поверхность
		var local := (q - centre) / (radii * 1.04)
		if local.length() < 1.0:
			q = centre + local.normalized() * radii * 1.04
		d = (d + Vector3(rng.randf_range(-0.06, 0.06), -0.35, -0.05)).normalized()
		var out := ((p - centre) / radii).normalized()
		var side := d.cross(out).normalized()
		if side.length_squared() < 0.01:
			side = Vector3.RIGHT
		var w0 := width * (1.0 - float(s) / steps * 0.7)
		var w1 := width * (1.0 - float(s + 1) / steps * 0.7)
		var c0 := root_col.lerp(tip_col, minf(1.0, float(s) / 3.0))
		var c1 := root_col.lerp(tip_col, minf(1.0, float(s + 1) / 3.0))
		for v in [[p - side * w0, c0], [p + side * w0, c0], [q + side * w1, c1], [p - side * w0, c0], [q + side * w1, c1], [q - side * w1, c1]]:
			st.set_color(v[1])
			st.set_normal(out)
			st.add_vertex(v[0])
		p = q


# ════════════════════════════════════════════════════════════
#  Скинвокер
# ════════════════════════════════════════════════════════════
static func skinwalker() -> SkinwalkerModel:
	var sw := SkinwalkerModel.new()
	return sw


# Поза скинвокера через его же словарь поз (_idle_pose + правки)
static func sw_pose(sw: SkinwalkerModel, extra: Dictionary) -> void:
	var q: Dictionary = sw._idle_pose()
	q.merge(extra, true)
	sw._apply_pose(q)


# Шкура, которая может сползти (кат-сцена «Крейн»)
static func sw_slide_material(sw: SkinwalkerModel) -> ShaderMaterial:
	var src := sw.mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
	var sm := ShaderMaterial.new()
	sm.shader = SKIN_SHADER
	if src and src.normal_texture:
		sm.set_shader_parameter("normal_tex", src.normal_texture)
	for i in sw.mesh_instance.mesh.get_surface_count():
		var s_src := sw.mesh_instance.mesh.surface_get_material(i)
		if s_src == src:
			sw.mesh_instance.set_surface_override_material(i, sm)
	return sm


# ════════════════════════════════════════════════════════════
#  Руки от первого лица
# ════════════════════════════════════════════════════════════
# Кисть с рукавом. Пальцы смотрят вдоль -Z, ладонь вниз. curl 0…1 — сжатие.
class Hand extends Node3D:
	var fingers: Array[Node3D] = []
	var curl := 0.2:
		set(v):
			curl = v
			_apply()

	func _init(left: bool, sleeve_col: Color = Color(0.09, 0.09, 0.1)) -> void:
		var s := -1.0 if left else 1.0
		var skin := StandardMaterial3D.new()
		skin.albedo_color = Color(0.5, 0.34, 0.27)
		skin.roughness = 0.7
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = sleeve_col
		cloth.roughness = 0.95
		var sleeve := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.047
		cm.bottom_radius = 0.055
		cm.height = 0.42
		sleeve.mesh = cm
		sleeve.material_override = cloth
		sleeve.rotation_degrees = Vector3(90, 0, 0)
		sleeve.position = Vector3(0, 0.005, 0.27)
		add_child(sleeve)
		var wrist := MeshInstance3D.new()
		var wm := CylinderMesh.new()
		wm.top_radius = 0.028
		wm.bottom_radius = 0.032
		wm.height = 0.06
		wrist.mesh = wm
		wrist.material_override = skin
		wrist.rotation_degrees = Vector3(90, 0, 0)
		wrist.position = Vector3(0, 0, 0.05)
		add_child(wrist)
		var palm := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.082, 0.026, 0.09)
		palm.mesh = pm
		palm.material_override = skin
		palm.position = Vector3(0, 0, -0.02)
		add_child(palm)
		for i in 4:
			var root := Node3D.new()
			root.position = Vector3((-0.03 + i * 0.02) * s, 0, -0.064)
			add_child(root)
			var lens: float = [0.042, 0.048, 0.045, 0.036][i]
			_seg(root, lens, 0.0085, skin)
			fingers.append(root)
		var th := Node3D.new()
		th.position = Vector3(0.042 * s * -1.0, -0.005, -0.01)
		th.rotation_degrees = Vector3(0, 55 * s, 0)
		add_child(th)
		_seg(th, 0.04, 0.01, skin)
		fingers.append(th)
		_apply()

	func _seg(parent: Node3D, len: float, r: float, m: Material) -> void:
		var a := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = r
		cm.height = len + r * 2.0
		a.mesh = cm
		a.material_override = m
		a.rotation_degrees = Vector3(90, 0, 0)
		a.position = Vector3(0, 0, -len * 0.5)
		parent.add_child(a)
		var tip := Node3D.new()
		tip.name = "Tip"
		tip.position = Vector3(0, 0, -len)
		parent.add_child(tip)
		var b := MeshInstance3D.new()
		var cm2 := CapsuleMesh.new()
		cm2.radius = r * 0.92
		cm2.height = len * 0.8 + r * 2.0
		b.mesh = cm2
		b.material_override = m
		b.rotation_degrees = Vector3(90, 0, 0)
		b.position = Vector3(0, 0, -len * 0.4)
		tip.add_child(b)

	func _apply() -> void:
		for i in fingers.size():
			var f := fingers[i]
			var k := curl if i < 4 else curl * 0.6
			f.rotation.x = -k * 1.1
			var tip := f.get_node_or_null("Tip") as Node3D
			if tip:
				tip.rotation.x = -k * 1.3


static func hand(left: bool) -> Hand:
	return Hand.new(left)
