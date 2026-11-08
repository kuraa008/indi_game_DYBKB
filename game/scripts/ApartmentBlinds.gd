extends "res://scripts/ApartmentKit.gd"

# Деревянные жалюзи на окнах квартиры. Нажатие опускает их или поднимает.
# Планки — один MultiMesh на окно: 40 штук стоят один вызов отрисовки,
# а пересчитываются только пока жалюзи движутся.

# Окно: центр проёма, ширина, направление в комнату
const WINDOWS := [
	[Vector3(0.3, 1.685, 2.4), 1.6, Vector3(0, 0, -1)],
	[Vector3(0.0, 1.685, -6.4), 1.6, Vector3(0, 0, 1)],
	[Vector3(8.2, 1.685, -3.7), 1.4, Vector3(-1, 0, 0)],
]
const INSET := 0.125          # насколько жалюзи стоят перед рамой
const HEAD_LOW := 0.76        # низ карниза относительно центра окна
const RAIL_LOW := -0.7        # нижняя планка в опущенных жалюзи
const STACK := 0.0062         # толщина одной планки в собранной пачке
const SLATS := 40
const CHORD := 0.052
const HONEY := Color(0.8, 0.6, 0.38)


class WindowBlind extends Area3D:
	var slats: MultiMesh
	var tapes: MultiMesh
	var rail: Node3D
	var cord: Node3D
	var acorn: Node3D
	var tape_x: Array = []
	var pitch := 0.0
	var rail_up := 0.0
	var cord_x := 0.0
	var t := 0.0
	var lowered := false
	var tween: Tween
	var sound: AudioStreamPlayer3D

	func _ready() -> void:
		collision_layer = 1 | 4
		collision_mask = 0
		apply(0.0)

	func get_interaction_hint() -> String:
		return "[ЛКМ / RT]  Поднять жалюзи" if lowered else "[ЛКМ / RT]  Опустить жалюзи"

	func interact(_opener: Node3D = null) -> void:
		lowered = not lowered
		var goal := 1.0 if lowered else 0.0
		if tween and tween.is_valid():
			tween.kill()
		tween = create_tween()
		tween.tween_method(apply, t, goal, 0.25 + 1.0 * absf(goal - t)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sound.pitch_scale = randf_range(0.95, 1.08)
		sound.play()

	# value: 0 — поднято в пачку под карнизом, 1 — опущено и закрыто
	func apply(value: float) -> void:
		t = value
		var rail_y: float = lerpf(rail_up, RAIL_LOW, value)
		var tilt := deg_to_rad(76.0) * smoothstep(0.8, 1.0, value)
		var basis_tilt := Basis(Vector3.RIGHT, tilt)
		for i in range(SLATS):
			var hang := HEAD_LOW - float(i + 1) * pitch
			var stacked := rail_y + 0.012 + float(SLATS - i) * STACK
			slats.set_instance_transform(i, Transform3D(basis_tilt, Vector3(0, maxf(hang, stacked), 0)))
		var length := HEAD_LOW - rail_y
		var mid := (HEAD_LOW + rail_y) * 0.5
		var n := 0
		for x in tape_x:
			for z in [-CHORD * 0.5, CHORD * 0.5]:
				tapes.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(0.012, length, 0.0012)), Vector3(x, mid, z)))
				n += 1
			tapes.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3(0.0028, length, 0.0028)), Vector3(x, mid, 0)))
			n += 1
		rail.position.y = rail_y
		# Шнур короче, когда жалюзи опущены
		var end_y: float = lerpf(-0.2, 0.38, value)
		cord.scale.y = 0.77 - end_y
		cord.position.y = (0.77 + end_y) * 0.5
		acorn.position.y = end_y - 0.018


func _ready() -> void:
	name = "ApartmentBlinds"
	var wood: StandardMaterial3D = CutsceneKit.tmat("wood_furniture.png", Color.WHITE, 1.0, 0.55).duplicate()
	wood.uv1_triplanar = false
	wood.uv1_scale = Vector3.ONE
	wood.vertex_color_use_as_albedo = true
	wood.vertex_color_is_srgb = true
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	var clack := _rattle()
	for win in WINDOWS:
		_build_blind(win[0], win[1], win[2], wood, clack)


func _build_blind(centre: Vector3, opening: float, inward: Vector3, wood: Material, clack: AudioStream) -> void:
	var yaw := rad_to_deg(atan2(inward.x, inward.z))
	var at := _xf(centre + inward * INSET, Vector3(0, yaw, 0))
	var w := opening + 0.14
	var trim := CutsceneKit.tmat("wood_furniture.png", HONEY.darkened(0.12), 2.2, 0.5)

	# Карниз: деревянная планка спереди, боковины, верхняя полка и профиль
	_base = at
	_bx(Vector3(w + 0.02, 0.085, 0.014), Vector3(0, 0.795, 0.043), Color.WHITE)
	_bx(Vector3(w + 0.034, 0.009, 0.02), Vector3(0, 0.84, 0.046), Color.WHITE)
	_bx(Vector3(w + 0.034, 0.009, 0.02), Vector3(0, 0.757, 0.046), Color.WHITE)
	_bx(Vector3(w + 0.02, 0.012, 0.08), Vector3(0, 0.834, 0.005), Color.WHITE)
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.014, 0.085, 0.08), Vector3(s * (w * 0.5 + 0.003), 0.795, 0.005), Color.WHITE)
	_flush(trim)
	_base = at
	_bx(Vector3(w - 0.02, 0.04, 0.05), Vector3(0, 0.795, 0.0), Color(0.3, 0.3, 0.32))
	# Рукоятка для наклона планок
	var wand := Vector3(-w * 0.5 + 0.06, 0.76, 0.05)
	_tube([wand, wand + Vector3(0, -0.34, 0), wand + Vector3(0, -0.68, 0)], 0.0048, Color(0.58, 0.44, 0.27), 8)
	_bl(Vector3(0.008, 0.016, 0.008), wand + Vector3(0, -0.69, 0), Color(0.58, 0.44, 0.27))
	_flush(_vmat(0.45))

	# Подвижная часть
	var blind := WindowBlind.new()
	blind.pitch = (HEAD_LOW - RAIL_LOW) / float(SLATS + 1)
	blind.rail_up = HEAD_LOW - 0.016 - float(SLATS) * STACK
	blind.tape_x = [-w * 0.36, 0.0, w * 0.36]
	var area_col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(w, 1.62, 0.09)
	area_col.shape = shape
	blind.add_child(area_col)

	var slat_set := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _slat_mesh(w - 0.03)
	mm.instance_count = SLATS
	for i in range(SLATS):
		mm.set_instance_color(i, HONEY.darkened(_rng.randf_range(0.0, 0.14)))
	slat_set.multimesh = mm
	slat_set.material_override = wood
	slat_set.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blind.add_child(slat_set)
	blind.slats = mm

	var tape_set := MultiMeshInstance3D.new()
	var tm := MultiMesh.new()
	tm.transform_format = MultiMesh.TRANSFORM_3D
	tm.mesh = _unit_box
	tm.instance_count = blind.tape_x.size() * 3
	tape_set.multimesh = tm
	tape_set.material_override = CutsceneKit.mat(Color(0.74, 0.68, 0.56), 0.9)
	tape_set.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	blind.add_child(tape_set)
	blind.tapes = tm

	blind.rail = CutsceneKit.node(blind)
	CutsceneKit.box(blind.rail, Vector3(w - 0.02, 0.024, CHORD + 0.006), Vector3.ZERO, trim, Vector3.ZERO, false)
	var cap := CutsceneKit.mat(Color(0.24, 0.17, 0.1), 0.5)
	for x in blind.tape_x:
		CutsceneKit.box(blind.rail, Vector3(0.018, 0.005, 0.03), Vector3(x, -0.0145, 0), cap, Vector3.ZERO, false)

	# Шнур: единичной высоты, длину задаёт масштаб
	var cord_mat := CutsceneKit.mat(Color(0.74, 0.68, 0.56), 0.9)
	blind.cord = CutsceneKit.box(blind, Vector3(0.0034, 1.0, 0.0034), Vector3(w * 0.5 - 0.06, 0, 0.05), cord_mat, Vector3.ZERO, false)
	blind.acorn = CutsceneKit.node(blind, Vector3(w * 0.5 - 0.06, 0, 0.05))
	var acorn_mat := trim
	CutsceneKit.cyl(blind.acorn, 0.0065, 0.012, 0.036, Vector3.ZERO, acorn_mat, Vector3.ZERO, 10)

	var sound := AudioStreamPlayer3D.new()
	sound.stream = clack
	sound.max_distance = 14.0
	sound.unit_size = 3.0
	blind.add_child(sound)
	blind.sound = sound

	add_child(blind)
	blind.transform = at


# Одна планка: слегка выгнутая полоска, волокна дерева идут вдоль неё
func _slat_mesh(length: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 6
	var point := func(s: float, k: float) -> Array:
		var u := k * 2.0 - 1.0
		var z := u * CHORD * 0.5
		var x := (s - 0.5) * length
		return [Vector3(x, 0.0035 * (1.0 - u * u), z), Vector2(z * 1.5, x)]
	for j in range(steps):
		var k0 := float(j) / float(steps)
		var k1 := float(j + 1) / float(steps)
		var a: Array = point.call(0.0, k0)
		var b: Array = point.call(1.0, k0)
		var c: Array = point.call(1.0, k1)
		var d: Array = point.call(0.0, k1)
		for q in [a, c, b, a, d, c]:
			st.set_color(Color.WHITE)
			st.set_uv(q[1])
			st.add_vertex(q[0])
	st.generate_normals()
	st.index()
	return st.commit()


# Звук: быстрая дробь планок, собирается при загрузке и не требует файла
func _rattle() -> AudioStreamWAV:
	var rate := 22050
	var count := int(float(rate) * 1.1)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	var next_click := 0.0
	var since := 1.0
	for i in range(count):
		var time := float(i) / float(rate)
		if time >= next_click:
			next_click = time + _rng.randf_range(0.018, 0.042)
			since = 0.0
		since += 1.0 / float(rate)
		var env := exp(-since * 240.0) * smoothstep(0.0, 0.05, time) * (1.0 - smoothstep(0.9, 1.1, time))
		var v := (_rng.randf_range(-1.0, 1.0) * 0.45 + sin(time * 2700.0 * TAU) * 0.2) * env
		pcm.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = pcm
	return wav
