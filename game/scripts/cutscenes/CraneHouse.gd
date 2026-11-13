class_name CraneHouse
extends RefCounted

# Дом Крейна для кат-сцен (главы 4–5 и плохая концовка) — тот же дом, что в игре:
# CraneHouseMap.gd Досыма (сруб, провалившаяся крыша, стол с четырьмя тарелками, каменный
# очаг, колодец под камнями, рога на ветках, лесная тропа). Координаты у них общие.
#
# Отличие одно: в кат-сценах стулья и гнилые ставни двигаются (Сэм встаёт со стула «Старший»,
# существо выбивает ставни и швыряет стул «Младший» в стену, чёрная фигура выдвигает стул
# во главе стола). Поэтому дом строится без них, а стулья и ставни — тем же кодом Досыма,
# но каждый отдельным узлом, который можно двигать.
#
# Оси: вход в стене x = +3, очаг у стены x = -3, стол вдоль X в центре.

const HEAD := Vector3(-1.3, 0, 0)        # стул во главе стола (смотрит на +X)
const FATHER := Vector3(0.0, 0, 0.78)    # «Отец» (смотрит на -Z)
const ELDER := Vector3(0.0, 0, -0.78)    # «Старший» (смотрит на +Z)
const YOUNGER := Vector3(1.3, 0, 0)      # «Младший» (смотрит на -X)
const HEARTH := Vector3(-2.75, 0, 0)     # центр топки
const TABLE_Y := 0.78
const WIN_L := Vector3(0.8, 1.35, -2.5)  # окно в стене z = -2.5 (с гнилыми ставнями)
const WIN_R := Vector3(-1.2, 1.35, 2.5)  # окно в стене z = +2.5
const DOOR := Vector3(3.0, 0, 1.2)
const SAM_WALL := Vector3(-2.62, 0.0, 1.62)   # Сэм у стены рядом с очагом (очаг шириной ±1.05 по z)
const SAM_WORDS := "ПОЗДНО.\nОНО ИДЁТ.\nОГОНЬ — ОЧАГ."


# Дом Досыма без стульев и ставней и без того, что нужно только в игре
class House extends "res://scripts/CraneHouseMap.gd":
	func _prepare_start() -> void:
		pass   # игрока здесь нет

	func _setup_night() -> void:
		pass   # свет и туман ставит сама кат-сцена

	func _build_table() -> void:
		var c := Color(0.29, 0.23, 0.17)
		var dust := Color(0.42, 0.39, 0.34)
		var z := -0.5
		while z < 0.49:
			var w := _rng.randf_range(0.2, 0.27)
			_bx(Vector3(2.0 + _rng.randf_range(-0.03, 0.03), 0.06, minf(w, 0.5 - z) - 0.008), Vector3(0, TABLE_Y - 0.03, z + w * 0.5), dust.darkened(_rng.randf_range(0.0, 0.2)))
			z += w
		for x in [-0.86, 0.86]:
			for s in [-0.38, 0.38]:
				_cy(0.05, 0.038, TABLE_Y - 0.06, Vector3(x, (TABLE_Y - 0.06) * 0.5, s), c.darkened(0.15), Vector3.ZERO, 8)
			_bx(Vector3(0.06, 0.08, 0.72), Vector3(x, TABLE_Y - 0.11, 0), c.darkened(0.2))
		_bx(Vector3(1.66, 0.07, 0.06), Vector3(0, 0.3, 0), c.darkened(0.2))
		_flush(_tex("wood_furniture.png", 1.4, 0.9), true)
		var plate := Color(0.38, 0.37, 0.34)
		var inner := plate.darkened(0.22)
		for p in [HEAD + Vector3(0.45, 0, 0), FATHER + Vector3(0, 0, -0.35), ELDER + Vector3(0, 0, 0.35), YOUNGER + Vector3(-0.45, 0, 0)]:
			_base = _xf(Vector3(p.x + _rng.randf_range(-0.02, 0.02), TABLE_Y, p.z), Vector3(0, _rng.randf() * 360.0, 0))
			_loft([
				_rg(0.075, 0.075, 0.075, 0.0), _rg(0.11, 0.11, 0.11, 0.016), _rg(0.128, 0.128, 0.128, 0.024), _rg(0.127, 0.127, 0.127, 0.0275),
				_rg(0.108, 0.108, 0.108, 0.02), _rg(0.07, 0.07, 0.07, 0.006), _rg(0.0, 0.0, 0.0, 0.005),
			], plate, Transform3D.IDENTITY, 5, [plate, plate, plate, plate, inner, inner, inner.darkened(0.15)])
			_flush(_vmat(0.62, 0.35))
			var web := CutsceneKit.cobweb(self, Vector3(p.x + 0.04, TABLE_Y + 0.05, p.z), 0.15, Vector3(-75, 30, 0))
			web.transparency = 0.5
		_base = Transform3D.IDENTITY

	func _build_door_and_windows() -> void:
		var frame := Color(0.17, 0.14, 0.12)
		for s in [-1.0, 1.0]:
			_bx(Vector3(0.3, 2.06, 0.1), Vector3(DOOR.x, 1.03, DOOR.z + s * 0.55), frame)
		_bx(Vector3(0.32, 0.12, 1.22), Vector3(DOOR.x, 2.04, DOOR.z), frame)
		var door_at := _xf(Vector3(DOOR.x + 0.16, 0.0, DOOR.z - 0.5), Vector3(0, -112, 7))
		var saved := _base
		_base = door_at
		var x := 0.0
		while x < 0.92:
			var w := _rng.randf_range(0.14, 0.2)
			var h := _rng.randf_range(1.5, 1.96)
			_bx(Vector3(w - 0.012, h, 0.03), Vector3(x + w * 0.5, h * 0.5 + 0.03, 0), _charred().lightened(0.08))
			x += w
		for y in [0.32, 1.42]:
			_bx(Vector3(0.9, 0.1, 0.03), Vector3(0.46, y, 0.028), _charred())
		_base = saved
		for w in [[WIN_L, 1.0], [WIN_R, -1.0]]:
			var c: Vector3 = w[0]
			for s in [-1.0, 1.0]:
				_bx(Vector3(0.09, 1.08, 0.32), c + Vector3(s * 0.57, 0, 0), frame)
				_bx(Vector3(1.22, 0.09, 0.34), c + Vector3(0, s * 0.53, 0), frame)
		_flush(_tex("board_weathered.png", 1.4, 0.97), true)


# Отдельная деталь дома, построенная кодом Досыма (стул, ставня)
class Piece extends "res://scripts/CraneHouseMap.gd":
	func _ready() -> void:
		pass

	func chair(word: String, seed_value: int) -> void:
		_rng.seed = seed_value
		_chair(Vector3.ZERO, 0.0, word)
		_flush(_tex("wood_furniture.png", 1.5, 0.9), true)

	# Половина гнилых ставней на петле: доски уходят от петли под углом
	func shutter(side: float, seed_value: int) -> void:
		_rng.seed = seed_value
		var board := 0.0
		while board < 0.48:
			var w := _rng.randf_range(0.1, 0.15)
			var h := _rng.randf_range(0.62, 0.96)
			var along: float = board + w * 0.5
			var yaw: float = side * 58.0
			var offs := Vector3(-side * cos(deg_to_rad(yaw)) * along, _rng.randf_range(-0.04, 0.03), side * sin(deg_to_rad(yaw)) * along * side)
			_bx(Vector3(w - 0.01, h, 0.024), offs, _charred().lightened(0.1), Vector3(0, yaw, _rng.randf_range(-3.0, 3.0)))
			board += w
		_flush(_tex("board_weathered.png", 1.4, 0.97), true)


# Возвращает словарь узлов: chairs (head/father/elder/younger), shutters, writing (надпись
# Сэма на пыльном столе), hearth_ash, fire_pos.
static func build(root: Node3D, _broken_window: bool = false) -> Dictionary:
	var out := {}
	var house := House.new()
	root.add_child(house)
	house.name = "CraneHouseMap"
	# Стулья: стоят там же, где в игре, но каждый — свой узел
	var chairs := {}
	var i := 0
	for c in [["head", HEAD, -90.0, ""], ["father", FATHER, 0.0, "Отец"], ["elder", ELDER, 180.0, "Старший"], ["younger", YOUNGER, 90.0, "Младший"]]:
		var p := Piece.new()
		root.add_child(p)
		p.name = "Chair_" + String(c[0])
		p.chair(c[3], 1894 + i)
		p.position = c[1]
		p.rotation_degrees = Vector3(0, c[2], 0)
		chairs[c[0]] = p
		i += 1
	out["chairs"] = chairs
	# Гнилые ставни на окне, которое выбьет существо
	var shutters := []
	for side in [-1.0, 1.0]:
		var s := Piece.new()
		root.add_child(s)
		s.name = "Shutter"
		s.shutter(side, 77 + int(side))
		s.position = WIN_L + Vector3(side * 0.53, 0, 0.2)
		shutters.append(s)
	out["shutters"] = shutters
	# Надпись Сэма на пыльном столе (появляется по буквам)
	out["writing"] = dust_writing(root)
	# Пепел в топке — часть очага Досыма; узел оставлен, чтобы старые кат-сцены могли его «прятать»
	var ash := Node3D.new()
	ash.name = "HearthAsh"
	root.add_child(ash)
	out["hearth_ash"] = ash
	out["fire_pos"] = Vector3(-2.68, 0.1, 0.0)
	out["plates"] = []
	return out


# Надпись Сэма на пыльном столе. Пальцем по пыли: следы темнее пыльной столешницы Досыма
static func dust_writing(root: Node3D) -> Label3D:
	var writing := CutsceneKit.text3d(root, "", Vector3(-0.32, TABLE_Y + 0.006, -0.2), Vector3(-90, 0, 0), 0.0011, Color(0.17, 0.14, 0.11), 64)
	writing.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	writing.autowrap_mode = TextServer.AUTOWRAP_OFF
	writing.shaded = false
	writing.modulate = Color(0.07, 0.06, 0.045, 0.95)
	return writing


# Сэм на стуле «Старший», руки привязаны ремнями из оленьей кожи. Один и тот же Сэм
# в игре (CraneHouseSam.gd) и в кат-сцене Ch4Sam. Возвращает {sam, straps}.
static func sam_tied(root: Node3D) -> Dictionary:
	var sam := CutsceneCast.sam()
	root.add_child(sam)
	sam.position = ELDER + Vector3(0, 0, -0.04)
	CutsceneCast.pose(sam, CutsceneCast.sit_tied())
	var leather := CutsceneKit.mat(Color(0.3, 0.2, 0.13), 0.8)
	var straps := []
	for s in [-1.0, 1.0]:
		var st := CutsceneKit.box(root, Vector3(0.09, 0.05, 0.07), ELDER + Vector3(0.21 * s, 0.5, 0.05), leather)
		CutsceneKit.box(st, Vector3(0.02, 0.18, 0.02), Vector3(0, -0.11, 0), leather)
		straps.append(st)
	return {"sam": sam, "straps": straps}


# Сэм сидит на полу у стены рядом с очагом (конец главы 4)
static func sam_by_hearth(sam: PlayerModel) -> void:
	sam.position = SAM_WALL
	sam.rotation_degrees = Vector3(0, 90, 0)
	CutsceneCast.pose(sam, CutsceneCast.sit_floor())
