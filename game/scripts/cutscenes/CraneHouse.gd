class_name CraneHouse
extends RefCounted

# Дом Крейна в лесу (главы 4–5 и плохая концовка): почерневший сруб, крыша
# провалилась, окна без стёкол. Одна комната: посредине стол с четырьмя тарелками
# под пылью и паутиной, четыре стула — «Отец», «Старший», «Младший» и пустой во главе.
# У дальней стены — каменный очаг. Снаружи — колодец под камнями, рога на ветках.
#
# Оси: вход в стене x = +3, очаг у стены x = -3, стол вдоль X в центре.

const HEAD := Vector3(-1.3, 0, 0)        # стул во главе стола (смотрит на +X)
const FATHER := Vector3(0.0, 0, 0.78)    # «Отец» (смотрит на -Z)
const ELDER := Vector3(0.0, 0, -0.78)    # «Старший» (смотрит на +Z)
const YOUNGER := Vector3(1.3, 0, 0)      # «Младший» (смотрит на -X)
const HEARTH := Vector3(-2.75, 0, 0)     # центр топки
const TABLE_Y := 0.78
const WIN_L := Vector3(0.8, 1.35, -2.5)  # окно в стене z = -2.5
const WIN_R := Vector3(-1.2, 1.35, 2.5)  # окно в стене z = +2.5
const DOOR := Vector3(3.0, 0, 1.2)


# Возвращает словарь узлов: chairs (по именам), plates, dust (надпись на столе), fire_pos и т. д.
static func build(root: Node3D, broken_window: bool = false) -> Dictionary:
	var out := {}
	var logs := CutsceneKit.tmat("board_weathered.png", Color(0.22, 0.19, 0.17), 1.2)
	var dark_wood := CutsceneKit.tmat("wood_furniture.png", Color(0.3, 0.24, 0.19), 1.4)
	var floor_m := CutsceneKit.tmat("board_weathered.png", Color(0.34, 0.3, 0.26), 0.9)
	var stone := CutsceneKit.tmat("res://assets/textures/nature/rock_tile.png", Color(0.45, 0.43, 0.4), 1.6, 0.9, "rock_tile_n.png")
	# Пол и стены из брёвен
	CutsceneKit.box(root, Vector3(6.4, 0.12, 5.4), Vector3(0, -0.06, 0), floor_m)
	_log_wall(root, Vector3(-3.0, 0, -2.5), Vector3(3.0, 0, -2.5), logs, [Rect2(3.8 - 0.55, 0.85, 1.1, 1.0)])
	_log_wall(root, Vector3(3.0, 0, 2.5), Vector3(-3.0, 0, 2.5), logs, [Rect2(4.2 - 0.55, 0.85, 1.1, 1.0)])
	_log_wall(root, Vector3(3.0, 0, -2.5), Vector3(3.0, 0, 2.5), logs, [Rect2(3.7 - 0.5, 0.0, 1.0, 2.0)])
	_log_wall(root, Vector3(-3.0, 0, 2.5), Vector3(-3.0, 0, -2.5), logs, [])
	# Крыша провалилась: уцелевший край, обломки стропил, дыра в небо
	CutsceneKit.box(root, Vector3(2.4, 0.08, 5.4), Vector3(-1.9, 2.5, 0), logs, Vector3(0, 0, -8))
	CutsceneKit.box(root, Vector3(1.6, 0.08, 5.4), Vector3(2.3, 2.45, 0), logs, Vector3(0, 0, 6))
	for i in 4:
		var z := -2.0 + i * 1.3
		CutsceneKit.beam(root, Vector3(-0.7, 2.55, z), Vector3(0.4 + 0.3 * float(i % 2), 1.2 + 0.4 * float(i % 2), z + 0.2), Vector2(0.1, 0.12), logs)
	for i in 5:
		CutsceneKit.box(root, Vector3(1.6, 0.04, 0.18), Vector3(2.0 - i * 0.12, 0.05 + i * 0.03, -1.8 + i * 0.22), logs, Vector3(0, 20 + i * 9, 3))
	# Стол и тарелки
	var table := Vector3(0, 0, 0)
	CutsceneKit.box(root, Vector3(2.0, 0.07, 1.0), table + Vector3(0, TABLE_Y - 0.035, 0), dark_wood)
	for x in [-0.88, 0.88]:
		for z in [-0.4, 0.4]:
			CutsceneKit.box(root, Vector3(0.08, TABLE_Y - 0.07, 0.08), table + Vector3(x, (TABLE_Y - 0.07) * 0.5, z), dark_wood)
	var dust := StandardMaterial3D.new()
	dust.albedo_color = Color(0.27, 0.25, 0.22)
	dust.roughness = 1.0
	CutsceneKit.box(root, Vector3(1.96, 0.004, 0.96), table + Vector3(0, TABLE_Y + 0.002, 0), dust)
	var plate_m := CutsceneKit.mat(Color(0.36, 0.35, 0.32), 0.75)
	var plates := []
	for p in [HEAD + Vector3(0.45, 0, 0), FATHER + Vector3(0, 0, -0.35), ELDER + Vector3(0, 0, 0.35), YOUNGER + Vector3(-0.45, 0, 0)]:
		var pl := CutsceneKit.cyl(root, 0.12, 0.09, 0.02, Vector3(p.x, TABLE_Y + 0.014, p.z), plate_m, Vector3.ZERO, 16)
		plates.append(pl)
		var web := CutsceneKit.cobweb(root, Vector3(p.x + 0.04, TABLE_Y + 0.04, p.z), 0.14, Vector3(-75, 30, 0))
		web.transparency = 0.55
	out["plates"] = plates
	# Надпись Сэма на пыльном столе (появляется по буквам)
	var writing := CutsceneKit.text3d(root, "", Vector3(-0.32, TABLE_Y + 0.006, -0.2), Vector3(-90, 0, 0), 0.0011, Color(0.17, 0.14, 0.11), 64)
	writing.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	writing.autowrap_mode = TextServer.AUTOWRAP_OFF
	out["writing"] = writing
	# Стулья
	var chairs := {}
	chairs["head"] = CutsceneKit.carved_chair(root, HEAD, -90.0, "", dark_wood)
	chairs["father"] = CutsceneKit.carved_chair(root, FATHER, 0.0, "Отец", dark_wood)
	chairs["elder"] = CutsceneKit.carved_chair(root, ELDER, 180.0, "Старший", dark_wood)
	chairs["younger"] = CutsceneKit.carved_chair(root, YOUNGER, 90.0, "Младший", dark_wood)
	out["chairs"] = chairs
	# Каменный очаг у дальней стены
	var h := HEARTH
	for z in [-0.75, 0.75]:
		CutsceneKit.box(root, Vector3(0.5, 1.1, 0.45), h + Vector3(0.05, 0.55, z), stone)
	CutsceneKit.box(root, Vector3(0.6, 0.35, 2.0), h + Vector3(0.05, 1.27, 0), stone)
	CutsceneKit.box(root, Vector3(0.55, 1.4, 1.2), h + Vector3(-0.05, 2.1, 0), stone)
	CutsceneKit.box(root, Vector3(0.7, 0.12, 2.1), h + Vector3(0.1, 0.06, 0), stone)
	CutsceneKit.box(root, Vector3(0.45, 1.0, 1.05), h + Vector3(-0.2, 0.55, 0), CutsceneKit.mat(Color(0.03, 0.025, 0.02), 1.0))
	var ash := CutsceneKit.ball(root, 0.35, h + Vector3(0.0, 0.1, 0), CutsceneKit.mat(Color(0.22, 0.21, 0.2), 1.0), Vector3(1.0, 0.18, 1.2), 10)
	ash.name = "HearthAsh"
	out["hearth_ash"] = ash
	var bone := CutsceneKit.mat(Color(0.62, 0.58, 0.5), 0.6)
	for i in 4:
		CutsceneKit.cyl(root, 0.012, 0.016, 0.22, h + Vector3(0.1 - i * 0.04, 0.16, -0.25 + i * 0.16), bone, Vector3(80, i * 40, 0), 6)
	out["fire_pos"] = h + Vector3(0.0, 0.14, 0)
	# Окна: пустые проёмы, в одном — гнилые ставни (их выбьет существо)
	var shutters := []
	for side in [-1.0, 1.0]:
		var sh := CutsceneKit.box(root, Vector3(0.52, 0.95, 0.04), WIN_L + Vector3(0.27 * side, 0, 0.05), logs, Vector3(0, -side * 25, 0))
		shutters.append(sh)
	out["shutters"] = shutters
	# Снаружи: колодец под камнями, ели, рога на ветках
	var well := Vector3(4.5, 0, -3.2)
	for i in 10:
		var a := i / 10.0 * TAU
		CutsceneKit.box(root, Vector3(0.36, 0.7, 0.2), well + Vector3(cos(a) * 0.6, 0.35, sin(a) * 0.6), stone, Vector3(0, -rad_to_deg(a), 0))
	for i in 7:
		CutsceneKit.rock(root, well + Vector3(0.3 * sin(i * 2.1), 0.55 + i * 0.05, 0.3 * cos(i * 1.7)), Vector3.ONE * (0.25 + 0.02 * i), Color(0.4, 0.38, 0.35))
	CutsceneKit.ground(root, Vector3(0, -0.01, 0), Vector2(80, 80), CutsceneKit.tmat("forest_floor.png", Color(0.42, 0.45, 0.38), 0.4))
	CutsceneKit.forest(root, Vector3.ZERO, 7.0, 32.0, 70, 1815, 9.0, 18.0)
	var antler := CutsceneKit.mat(Color(0.7, 0.66, 0.58), 0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 120
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(4.2, 7.5)
		var ap := Vector3(cos(a) * r, rng.randf_range(1.8, 3.2), sin(a) * r)
		var an := CutsceneKit.node(root, ap, Vector3(rng.randf_range(-30, 30), rng.randf() * 360.0, rng.randf_range(-20, 20)))
		CutsceneKit.cyl(an, 0.006, 0.014, 0.42, Vector3(0, -0.12, 0), antler, Vector3(0, 0, 10), 6)
		CutsceneKit.cyl(an, 0.005, 0.01, 0.2, Vector3(0.05, -0.05, 0), antler, Vector3(0, 0, -40), 5)
		CutsceneKit.cyl(an, 0.005, 0.01, 0.18, Vector3(-0.04, 0.02, 0), antler, Vector3(0, 0, 35), 5)
		CutsceneKit.cyl(an, 0.004, 0.006, 0.6, Vector3(0, 0.25, 0), CutsceneKit.mat(Color(0.12, 0.1, 0.08), 0.9), Vector3(0, 0, 0), 4)
	CutsceneKit.cobweb(root, Vector3(-2.9, 2.3, -2.4), 0.8, Vector3(0, 45, 0))
	CutsceneKit.cobweb(root, Vector3(2.9, 2.2, 2.4), 0.7, Vector3(0, 225, 0))
	CutsceneKit.dust(root, Vector3(0, 1.3, 0), Vector3(2.6, 1.0, 2.0), 90, Color(0.75, 0.8, 0.95, 0.3))
	return out


# Стена из горизонтальных брёвен с проёмами (Rect2: x вдоль стены от a, y от пола)
static func _log_wall(root: Node3D, a: Vector3, b: Vector3, m: Material, holes: Array) -> void:
	var dir := Vector3(b.x - a.x, 0, b.z - a.z)
	var len := dir.length()
	var n := Node3D.new()
	root.add_child(n)
	n.position = a
	n.basis = Basis(Vector3.UP, atan2(-dir.z, dir.x))
	var r := 0.13
	var y := r
	while y < 2.45:
		# Бревно режется проёмами на куски
		var cuts: Array = [[0.0, len]]
		for hh in holes:
			var hr: Rect2 = hh
			if y > hr.position.y and y < hr.position.y + hr.size.y:
				var nxt: Array = []
				for c in cuts:
					var c0: float = c[0]
					var c1: float = c[1]
					if hr.position.x > c0:
						nxt.append([c0, minf(c1, hr.position.x)])
					if hr.position.x + hr.size.x < c1:
						nxt.append([maxf(c0, hr.position.x + hr.size.x), c1])
				cuts = nxt
		for c in cuts:
			var c0: float = c[0]
			var c1: float = c[1]
			if c1 - c0 < 0.05:
				continue
			CutsceneKit.cyl(n, r, r, c1 - c0 + 0.12, Vector3((c0 + c1) * 0.5, y, 0), m, Vector3(0, 0, 90), 8)
		y += r * 1.85
