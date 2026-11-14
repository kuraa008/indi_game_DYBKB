class_name HouseProps
extends "res://scripts/models/SculptKit.gd"

# Вещи главы 3 в доме отца (карта «Шоссе»). Механик здесь нет, только модели и простые методы.
# Для thebekshdet: у каждой вещи есть узел с именем и метод, который её двигает.
#
#   Доски на окне кладовки   pantry_boards[0..2], tear_off(i)           (монтировка из сарая)
#   Светлые скрипучие доски  loose_plank, lift_plank(on), plank_stepped (сигнал, когда кто-то наступил)
#                            они под кроватью отца: сначала move_bed(true), потом lift_plank(true)
#   Металлическая коробка    box (скрыта, пока доска не поднята), unlock(), open_box(on)
#   Олений череп и записка   skull, note (лежат в коробке)
#   Ящик с письмами Сэма     letters_lid, open_letters(on)
#   Часы с кукушкой          cuckoo(on), open_secret(on), take_key() -> ключ от коробки
#   Глава 4, гараж:
#   Керосин                  kerosene, take_kerosene()   (на полу у стеллажа)
#   Карта леса               forest_map, take_map()      (приколота к стене рядом с доской инструментов)
#
# Чтобы взять предмет, ставь Area3D на нужный узел и вызывай метод. Позиции совпадают с картой.

signal plank_stepped
signal board_torn(index: int)
signal key_taken

const FY := 3.48                                    # пол второго этажа
const PANTRY_AT := Vector3(-62.0, 1.88, -231.34)    # окно кладовки, три доски снаружи
const PLANK_AT := Vector3(-69.3, FY, -220.7)        # скрипучая доска, в комнате отца
const BOX_AT := Vector3(-69.05, FY, -220.8)         # коробка отца
const LETTERS_AT := Vector3(-63.6, 4.23, -219.55)   # ящик с письмами на столе отца
const CLOCK_AT := Vector3(-58.77, 1.935, -223.6)    # часы с кукушкой на стене коридора, смотрят на +X
const BED_FROM := Vector3(-69.3, 3.41, -220.7)       # кровать отца на карте стоит над досками
const BED_TO := Vector3(-69.45, 3.41, -223.25)      # отодвинута к середине комнаты (как в кат-сцене Ch3Mine)
const KEROSENE_AT := Vector3(-41.62, 0.1, -204.72)  # гараж: на полу у северного конца стеллажа
const FOREST_MAP_AT := Vector3(-48.55, 1.58, -204.172) # гараж: на северной стене, смотрит в гараж (-Z)
const OLD_IDS := [4000, 4001, 4004, 4005, 4006, 4008, 4009, 4010, 4011, 4019, 4020, 4021]

const OLD_WOOD := Color(0.42, 0.33, 0.24)
const OAK := Color(0.4, 0.3, 0.21)
const PALE := Color(0.84, 0.7, 0.52)
const IRON := Color(0.16, 0.16, 0.17)
const RUST := Color(0.3, 0.14, 0.07)
const SECRET_CLOSED := 0.081
const BRASS := Color(0.55, 0.42, 0.18)
const PAPER := Color(0.62, 0.56, 0.42)

var pantry_boards: Array[Node3D] = []
var loose_plank: Node3D
var cavity: Node3D
var box: Node3D
var box_lid: Node3D
var box_lock: Node3D
var skull: Node3D
var note: Node3D
var letters_lid: Node3D
var clock: Node3D
var clock_doors: Array[Node3D] = []
var clock_bird: Node3D
var clock_secret: Node3D
var clock_key: Node3D
var pendulum: Node3D
var kerosene: Node3D
var forest_map: Node3D
var _tween_swing: Tween
var _key_taken := false


func _ready() -> void:
	name = "HouseProps"
	_rng.seed = 4090
	_build_pantry_boards()
	_build_floor_patch()
	_build_box()
	_build_letters()
	_build_clock()
	_build_kerosene()
	_build_forest_map()
	_remove_old.call_deferred()


# ═══ Материалы и детали ═══

func _wood(uv: float = 1.4, rough: float = 0.92) -> StandardMaterial3D:
	var m: StandardMaterial3D = CutsceneKit.tmat("board_weathered.png", Color.WHITE, uv, rough).duplicate()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	return m


func _furniture(uv: float = 1.6) -> StandardMaterial3D:
	var m: StandardMaterial3D = CutsceneKit.tmat("wood_furniture.png", Color.WHITE, uv, 0.8).duplicate()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	return m


func _metal() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.roughness = 0.5
	m.metallic = 0.65
	return m


func _matte(two_sided: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = false
	m.roughness = 0.96
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _part(nm: String, at: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.name = nm
	n.position = at
	n.rotation_degrees = rot
	(parent if parent else _home()).add_child(n)
	return n


# Части вешаются на главу, а не на этот узел: глава прячет и показывает внутренности дома по их позициям
func _home() -> Node:
	return get_parent() if get_parent() else self


func _emit(part: Node3D, mat: Material, shadows: bool = true) -> void:
	var mi := _flush(mat, shadows)
	remove_child(mi)
	part.add_child(mi)


func _tone(base: Color, spread: float = 0.2) -> Color:
	return base.darkened(_rng.randf_range(0.0, spread)).lightened(_rng.randf_range(0.0, spread * 0.3))


# Гвоздь со шляпкой, чуть кривой
func _nail(at: Vector3, bent: bool = false) -> void:
	_cy(0.011, 0.009, 0.006, at, RUST.darkened(0.1), Vector3(90, 0, 0), 8)
	_cy(0.0035, 0.0035, 0.03, at + Vector3(0, 0, 0.012), IRON, Vector3(90 + (28.0 if bent else 0.0), 0, 0), 6)


# Прожилки и сучок на доске: тёмные тонкие полоски вдоль волокон
func _grain(size: Vector3, col: Color, count: int) -> void:
	for i in range(count):
		var y := _rng.randf_range(-size.y * 0.42, size.y * 0.42)
		var len := size.x * _rng.randf_range(0.25, 0.8)
		var x := _rng.randf_range(-size.x * 0.5 + len * 0.5, size.x * 0.5 - len * 0.5)
		_bx(Vector3(len, 0.0035, 0.002), Vector3(x, y, size.z * 0.5 + 0.0006), col.darkened(0.35))


# ═══ 1. Доски на окне кладовки: рваные концы, гвозди, отрываются по одной ═══

func _build_pantry_boards() -> void:
	var rolls := [4.0, -3.0, 6.0]
	var ys := [-0.47, 0.0, 0.48]
	for i in range(3):
		var part := _part("PantryBoard%d" % i, PANTRY_AT + Vector3(0, ys[i], 0), Vector3(0, 0, rolls[i]))
		var w := 1.9 + _rng.randf_range(-0.04, 0.03)
		var h := 0.16 + _rng.randf_range(-0.01, 0.01)
		var col := _tone(OLD_WOOD.lightened(0.12), 0.22)
		_bx(Vector3(w, h, 0.04), Vector3.ZERO, col)
		# Корка и сколы по краям, расщеплённые торцы
		_bx(Vector3(w, 0.008, 0.044), Vector3(0, h * 0.5 - 0.004, 0), col.darkened(0.2))
		_bx(Vector3(w, 0.008, 0.044), Vector3(0, -h * 0.5 + 0.004, 0), col.darkened(0.25))
		for s: float in [-1.0, 1.0]:
			for k in range(3):
				var sp := _rng.randf_range(0.04, 0.09)
				_bx(Vector3(sp, 0.012, 0.012), Vector3(s * (w * 0.5 + sp * 0.35), _rng.randf_range(-h * 0.35, h * 0.35), _rng.randf_range(-0.012, 0.012)), col.lightened(0.1), Vector3(0, 0, _rng.randf_range(-18, 18)))
			_nail(Vector3(s * (w * 0.5 - 0.1), 0.035, 0.022), i == 1 and s < 0.0)
			_nail(Vector3(s * (w * 0.5 - 0.1), -0.035, 0.022))
			_nail(Vector3(s * (w * 0.5 - 0.22), 0.0, 0.022))
		_grain(Vector3(w, h, 0.04), col, 6)
		_cy(0.022, 0.022, 0.004, Vector3(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.03, 0.03), 0.021), col.darkened(0.5), Vector3(90, 0, 0), 10)
		_emit(part, _wood(1.6))
		pantry_boards.append(part)


func tear_off(index: int) -> void:
	if index < 0 or index >= pantry_boards.size():
		return
	var b := pantry_boards[index]
	if b == null or not is_instance_valid(b):
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(b, "rotation_degrees", Vector3(70.0, _rng.randf_range(-12, 12), b.rotation_degrees.z + _rng.randf_range(-20, 20)), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(b, "position", Vector3(b.position.x, 0.12, b.position.z - 0.55), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	board_torn.emit(index)


# ═══ 2. Светлые скрипучие доски: свежие, не как старый пол; одна лежит неплотно ═══

func _build_floor_patch() -> void:
	var patch := _part("FloorPatch", PLANK_AT)
	# Тёмные щели между досками
	_bx(Vector3(1.64, 0.002, 0.86), Vector3(0, 0.003, 0), Color(0.02, 0.015, 0.012))
	for k in range(-2, 3):
		if k == 0:
			continue
		var z := float(k) * 0.162
		var col := _tone(PALE, 0.18)
		var len := 1.6 + _rng.randf_range(-0.02, 0.02)
		_bx(Vector3(len, 0.018, 0.152), Vector3(0, 0.012, z), col)
		_bx(Vector3(len, 0.005, 0.15), Vector3(0, 0.0215, z), col.lightened(0.05))
		_patch_detail(len, z, col, 0.0215)
	_emit(patch, _wood(1.0, 0.85))

	# Сама скрипучая доска: ось вращения у восточного края, чтобы поднимать запад
	loose_plank = _part("LoosePlank", PLANK_AT + Vector3(0.8, 0, 0), Vector3(0, 1.4, 0))
	var col2 := PALE.lightened(0.04)
	_bx(Vector3(1.6, 0.02, 0.15), Vector3(-0.8, 0.016, 0), col2)
	_bx(Vector3(1.6, 0.005, 0.148), Vector3(-0.8, 0.0275, 0), col2.lightened(0.06))
	_patch_detail(1.6, 0.0, col2, 0.0275, -0.8)
	# Выгнутая и потёртая посередине, там где на неё наступают
	_bx(Vector3(0.5, 0.002, 0.15), Vector3(-0.8, 0.0305, 0), col2.darkened(0.12))
	_emit(loose_plank, _wood(1.0, 0.8))

	cavity = _part("Cavity", PLANK_AT)
	_bx(Vector3(1.52, 0.004, 0.13), Vector3(0, 0.004, 0), Color(0.02, 0.016, 0.013))
	_bx(Vector3(1.52, 0.004, 0.012), Vector3(0, 0.005, 0.07), Color(0.1, 0.075, 0.05))
	# Старая паутина в углу
	for i in range(5):
		_pipe(Vector3(-0.72, 0.01, 0.06), Vector3(-0.72 + 0.1 + 0.02 * i, 0.01, 0.06 - 0.025 * i - 0.01), 0.0008, Color(0.5, 0.5, 0.48))
	_emit(cavity, _matte(true), false)

	# Скрип: шаг по доске даёт сигнал. Звук и шум для врага делает геймплей
	var area := Area3D.new()
	area.name = "CreakArea"
	area.position = PLANK_AT + Vector3(0, 0.15, 0)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.5, 0.3, 0.3)
	shape.shape = bs
	area.add_child(shape)
	_home().add_child(area)
	area.body_entered.connect(func(b: Node3D) -> void:
		if b is CharacterBody3D:
			plank_stepped.emit())


func _patch_detail(len: float, z: float, col: Color, top: float, x0: float = 0.0) -> void:
	for i in range(5):
		var x := x0 + _rng.randf_range(-len * 0.4, len * 0.4)
		_bx(Vector3(_rng.randf_range(0.2, 0.7), 0.0012, 0.003), Vector3(x, top + 0.0012, z + _rng.randf_range(-0.05, 0.05)), col.darkened(0.3))
	for s: float in [-1.0, 1.0]:
		for dz: float in [-0.045, 0.045]:
			_cy(0.007, 0.006, 0.003, Vector3(x0 + s * (len * 0.5 - 0.06), top + 0.0012, z + dz), IRON.lightened(0.05), Vector3.ZERO, 8)
	_cy(0.03, 0.03, 0.002, Vector3(x0 + _rng.randf_range(-0.4, 0.4), top + 0.001, z), col.darkened(0.45), Vector3.ZERO, 10)


func move_bed(on: bool = true) -> void:
	var holder := get_parent().get_parent() if get_parent() else null
	if holder == null:
		return
	var bed: Node3D = holder.find_child("prop_bed_1212", true, false) as Node3D
	if bed == null:
		return
	create_tween().tween_property(bed, "position", BED_TO if on else BED_FROM, 1.4).set_trans(Tween.TRANS_SINE)


func lift_plank(on: bool = true) -> void:
	var tw := create_tween()
	tw.tween_property(loose_plank, "rotation_degrees:z", -42.0 if on else 0.0, 0.7 if on else 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on:
		show_box(true)


# ═══ 5. Металлическая коробка отца: заклёпки, ржавчина, замок; внутри череп и записка ═══

func _build_box() -> void:
	box = _part("FatherBox", BOX_AT)
	box.visible = false
	var iron := Color(0.2, 0.2, 0.21)
	# Корпус открытый сверху: стенки изнутри и снаружи
	var w := 0.4
	var d := 0.3
	var h := 0.14
	var t := 0.012
	_bx(Vector3(w, t, d), Vector3(0, t * 0.5, 0), iron.darkened(0.2))
	_bx(Vector3(w, h, t), Vector3(0, h * 0.5, d * 0.5 - t * 0.5), iron)
	_bx(Vector3(w, h, t), Vector3(0, h * 0.5, -d * 0.5 + t * 0.5), iron)
	_bx(Vector3(t, h, d), Vector3(w * 0.5 - t * 0.5, h * 0.5, 0), iron)
	_bx(Vector3(t, h, d), Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0), iron)
	# Рёбра жёсткости, окантовка по верху, угловые накладки, заклёпки
	for x in [-0.12, 0.0, 0.12]:
		_bx(Vector3(0.016, h - 0.03, 0.004), Vector3(x, h * 0.5, d * 0.5 + 0.001), iron.lightened(0.08))
		_bx(Vector3(0.016, h - 0.03, 0.004), Vector3(x, h * 0.5, -d * 0.5 - 0.001), iron.lightened(0.08))
	_bx(Vector3(w + 0.012, 0.012, 0.014), Vector3(0, h - 0.004, d * 0.5), iron.lightened(0.12))
	_bx(Vector3(w + 0.012, 0.012, 0.014), Vector3(0, h - 0.004, -d * 0.5), iron.lightened(0.12))
	_bx(Vector3(0.014, 0.012, d + 0.012), Vector3(w * 0.5, h - 0.004, 0), iron.lightened(0.12))
	_bx(Vector3(0.014, 0.012, d + 0.012), Vector3(-w * 0.5, h - 0.004, 0), iron.lightened(0.12))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bx(Vector3(0.04, h, 0.04), Vector3(sx * (w * 0.5 - 0.015), h * 0.5, sz * (d * 0.5 - 0.015)), iron.lightened(0.04))
			_cy(0.007, 0.006, 0.004, Vector3(sx * (w * 0.5 - 0.015), h * 0.5 + 0.03, sz * (d * 0.5 + 0.003)), IRON.lightened(0.14), Vector3(90, 0, 0), 8)
			_cy(0.007, 0.006, 0.004, Vector3(sx * (w * 0.5 - 0.015), h * 0.5 - 0.03, sz * (d * 0.5 + 0.003)), IRON.lightened(0.14), Vector3(90, 0, 0), 8)
	# Ржавые потёки и пятна
	for i in range(9):
		var rx := _rng.randf_range(-w * 0.45, w * 0.45)
		_bx(Vector3(_rng.randf_range(0.01, 0.035), _rng.randf_range(0.03, 0.1), 0.0012), Vector3(rx, _rng.randf_range(0.03, h - 0.01), d * 0.5 + 0.002), RUST.lerp(iron, _rng.randf_range(0.45, 0.8)))
	# Ручки-кольца по бокам
	for s: float in [-1.0, 1.0]:
		_bx(Vector3(0.012, 0.03, 0.05), Vector3(s * (w * 0.5 + 0.006), h * 0.55, 0), iron.lightened(0.1))
		_torus(0.0115, 0.0145, Vector3(s * (w * 0.5 + 0.024), h * 0.5, 0), IRON.lightened(0.12), Vector3(0, 0, 90))
	# Ушки под замок на корпусе
	_bx(Vector3(0.05, 0.03, 0.01), Vector3(0, h - 0.04, d * 0.5 + 0.008), iron.lightened(0.15))
	# Подкладка и всё что внутри
	_bx(Vector3(w - 0.028, 0.012, d - 0.028), Vector3(0, 0.018, 0), Color(0.14, 0.04, 0.04))
	_bx(Vector3(w - 0.028, 0.05, 0.01), Vector3(0, 0.044, -d * 0.5 + 0.02), Color(0.14, 0.04, 0.04))
	_emit(box, _metal())

	# Сукно под череп и мятая бумага
	var cloth := _part("Cloth", Vector3(0, 0.026, 0), Vector3.ZERO, box)
	for i in range(7):
		_bx(Vector3(_rng.randf_range(0.18, 0.34), 0.008, _rng.randf_range(0.08, 0.14)), Vector3(_rng.randf_range(-0.04, 0.04), 0.004 * float(i % 3), _rng.randf_range(-0.07, 0.07)), Color(0.19, 0.07, 0.06).lightened(_rng.randf_range(0.0, 0.1)), Vector3(0, _rng.randf_range(-30, 30), _rng.randf_range(-6, 6)))
	_emit(cloth, _matte(true), false)

	# Олений череп Крейна из слепка, он влезает целиком
	skull = _part("Skull", Vector3(-0.02, 0.07, 0.0), Vector3(-6, 80, 4), box)
	skull.scale = Vector3.ONE * 0.9
	skull.add_child(DeerSkullModel.new())

	# Последняя записка отца: сложенный лист и нить; слов не видно, только кривые строчки
	note = _part("FatherNote", Vector3(0.13, 0.038, 0.07), Vector3(0, 24, 0), box)
	_bx(Vector3(0.1, 0.004, 0.14), Vector3.ZERO, PAPER.lightened(0.06))
	_bx(Vector3(0.1, 0.0025, 0.002), Vector3(0, 0.003, 0.0), PAPER.darkened(0.3))
	for i in range(9):
		_bx(Vector3(_rng.randf_range(0.04, 0.085), 0.0012, 0.0016), Vector3(_rng.randf_range(-0.008, 0.008), 0.0034, -0.055 + 0.012 * float(i)), Color(0.12, 0.1, 0.09), Vector3(0, _rng.randf_range(-2, 2), 0))
	_bx(Vector3(0.1, 0.0012, 0.01), Vector3(0, 0.0032, 0.062), PAPER.darkened(0.15))
	_emit(note, _matte(true), false)

	# Крышка: петли сзади, внутри окантовка, спереди скоба для замка
	box_lid = _part("Lid", BOX_AT + Vector3(0, h, -d * 0.5), Vector3.ZERO)
	_bx(Vector3(w + 0.012, 0.014, d + 0.012), Vector3(0, 0.007, d * 0.5), iron.lightened(0.05))
	_bx(Vector3(w - 0.03, 0.01, d - 0.03), Vector3(0, -0.004, d * 0.5), iron.darkened(0.2))
	for x in [-0.12, 0.0, 0.12]:
		_bx(Vector3(0.018, 0.005, d - 0.02), Vector3(x, 0.0165, d * 0.5), iron.lightened(0.13))
	_bx(Vector3(w - 0.02, 0.005, 0.018), Vector3(0, 0.0165, 0.02), iron.lightened(0.13))
	_bx(Vector3(w - 0.02, 0.005, 0.018), Vector3(0, 0.0165, d - 0.02), iron.lightened(0.13))
	for sx: float in [-1.0, 1.0]:
		for z in [0.03, d - 0.03]:
			_cy(0.007, 0.006, 0.004, Vector3(sx * (w * 0.5 - 0.02), 0.019, z), IRON.lightened(0.15), Vector3.ZERO, 8)
	for x in [-0.12, 0.12]:
		_cy(0.011, 0.011, 0.04, Vector3(x, 0.0, 0.0), IRON.lightened(0.12), Vector3(0, 0, 90), 10)
	_bx(Vector3(0.04, 0.034, 0.008), Vector3(0, -0.004, d + 0.004), iron.lightened(0.15))
	for i in range(5):
		_bx(Vector3(_rng.randf_range(0.04, 0.09), 0.0015, _rng.randf_range(0.04, 0.09)), Vector3(_rng.randf_range(-0.14, 0.14), 0.018, _rng.randf_range(0.05, d - 0.05)), RUST.lerp(iron, _rng.randf_range(0.0, 0.5)))
	_emit(box_lid, _metal())

	# Навесной замок: латунный корпус и дужка, снимается ключом из часов
	box_lock = _part("Padlock", BOX_AT + Vector3(0, h - 0.045, d * 0.5 + 0.02))
	_bx(Vector3(0.05, 0.058, 0.022), Vector3(0, -0.01, 0), BRASS.darkened(0.2))
	_bx(Vector3(0.044, 0.012, 0.004), Vector3(0, 0.012, 0.012), BRASS.lightened(0.1))
	_cy(0.005, 0.005, 0.004, Vector3(0, -0.02, 0.012), Color(0.03, 0.02, 0.01), Vector3(90, 0, 0), 8)
	_torus(0.0115, 0.0145, Vector3(0, 0.03, 0), IRON.lightened(0.2), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.0))
	_emit(box_lock, _metal())
	box_lock.visible = false
	box.visible = false
	box_lid.visible = false


func unlock() -> void:
	if box_lock == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(box_lock, "position:y", box_lock.position.y - 0.4, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(box_lock, "rotation_degrees:x", 80.0, 0.5)
	tw.chain().tween_callback(func() -> void: box_lock.visible = false)


func open_box(on: bool = true) -> void:
	var tw := create_tween()
	tw.tween_property(box_lid, "rotation_degrees:x", -112.0 if on else 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if on:
		show_box(true)


func show_box(on: bool = true) -> void:
	box.visible = on
	box_lid.visible = on
	box_lock.visible = on and not _key_taken


# ═══ 3. Ящик с письмами Сэма на столе отца: латунные уголки, замок, пачки писем ═══

func _build_letters() -> void:
	var part := _part("LettersBox", LETTERS_AT, Vector3(0, 6, 0))
	var w := 0.3
	var d := 0.2
	var h := 0.09
	var wood := Color(0.27, 0.17, 0.1)
	_bx(Vector3(w, 0.012, d), Vector3(0, 0.006, 0), wood.darkened(0.15))
	_bx(Vector3(w, h, 0.012), Vector3(0, h * 0.5, d * 0.5 - 0.006), wood)
	_bx(Vector3(w, h, 0.012), Vector3(0, h * 0.5, -d * 0.5 + 0.006), wood)
	_bx(Vector3(0.012, h, d), Vector3(w * 0.5 - 0.006, h * 0.5, 0), wood)
	_bx(Vector3(0.012, h, d), Vector3(-w * 0.5 + 0.006, h * 0.5, 0), wood)
	# Нижняя ступенька-цоколь и накладки
	_bx(Vector3(w + 0.012, 0.01, d + 0.012), Vector3(0, 0.005, 0), wood.darkened(0.25))
	_bx(Vector3(w + 0.004, 0.012, d + 0.004), Vector3(0, h - 0.004, 0), wood.lightened(0.06))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_bx(Vector3(0.026, 0.026, 0.026), Vector3(sx * (w * 0.5 - 0.006), 0.014, sz * (d * 0.5 - 0.006)), BRASS.darkened(0.15))
	_bx(Vector3(0.05, 0.034, 0.006), Vector3(0, h - 0.025, d * 0.5 + 0.004), BRASS.darkened(0.1))
	_cy(0.005, 0.005, 0.004, Vector3(0, h - 0.027, d * 0.5 + 0.008), Color(0.04, 0.03, 0.02), Vector3(90, 0, 0), 8)
	# Бумага стопками: письма в конвертах стоят на ребре и лежат пачками
	for i in range(18):
		var x := -w * 0.5 + 0.03 + float(i) * 0.014 + _rng.randf_range(-0.002, 0.002)
		var hh := _rng.randf_range(0.062, 0.078)
		_bx(Vector3(0.011, hh, 0.14), Vector3(x, 0.012 + hh * 0.5, _rng.randf_range(-0.006, 0.006)), _tone(PAPER, 0.18), Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-3, 3)))
	_emit(part, _furniture(2.0))

	# Бумага и металл: марки, сургуч, шпагат. Всё это тоже в ящике
	var paper_part := _part("LetterPaper", Vector3.ZERO, Vector3.ZERO, part)
	for i in range(3):
		var bundle := Vector3(-0.07 + 0.075 * float(i), 0.016 + 0.003 * float(i % 2), -0.02 * float(i % 2))
		for k in range(5):
			_bx(Vector3(0.12, 0.0035, 0.07), bundle + Vector3(0, 0.0036 * float(k), 0), _tone(PAPER, 0.15), Vector3(0, _rng.randf_range(-3, 3), 0))
		_bx(Vector3(0.006, 0.026, 0.074), bundle + Vector3(0, 0.01, 0), Color(0.36, 0.3, 0.2))
		_bx(Vector3(0.125, 0.026, 0.004), bundle + Vector3(0, 0.01, 0), Color(0.36, 0.3, 0.2))
	_emit(paper_part, _matte(true), false)

	# Открытая крышка на петлях сзади, внутри выцветшая обивка
	letters_lid = _part("LettersLid", Vector3(0, h, -d * 0.5), Vector3(-104.0, 0, 0), part)
	_bx(Vector3(w + 0.004, 0.014, d + 0.004), Vector3(0, 0.007, d * 0.5), wood.lightened(0.04))
	_bx(Vector3(w - 0.03, 0.004, d - 0.03), Vector3(0, -0.002, d * 0.5), Color(0.18, 0.06, 0.06))
	_bx(Vector3(0.05, 0.012, 0.006), Vector3(0, 0.0, d - 0.004), BRASS.darkened(0.1))
	for x in [-0.1, 0.1]:
		_cy(0.007, 0.007, 0.04, Vector3(x, 0.0, 0.0), BRASS.darkened(0.2), Vector3(0, 0, 90), 8)
	_emit(letters_lid, _furniture(2.0))

	# Три письма и лист на самом столе, как будто их только что читали
	var table := _part("LettersOnTable", Vector3(0.3, 0.003, 0.14), Vector3.ZERO, part)
	var spots := [Vector3(0, 0, 0), Vector3(0.09, 0.004, -0.05), Vector3(-0.05, 0.008, 0.1)]
	var rots := [16.0, -24.0, 40.0]
	for i in range(3):
		var base_at: Vector3 = spots[i]
		var rr: float = rots[i]
		_bx(Vector3(0.16, 0.003, 0.1), base_at, _tone(PAPER, 0.15), Vector3(0, rr, 0))
		_bx(Vector3(0.16, 0.004, 0.003), base_at + Vector3(0, 0.002, -0.03).rotated(Vector3.UP, deg_to_rad(rr)), PAPER.darkened(0.25), Vector3(0, rr, 0))
		# марка и штамп
		_bx(Vector3(0.016, 0.0016, 0.02), base_at + Vector3(0.06, 0.0025, 0.03).rotated(Vector3.UP, deg_to_rad(rr)), Color(0.5, 0.2, 0.12), Vector3(0, rr, 0))
		_torus(0.007, 0.0095, base_at + Vector3(0.05, 0.003, 0.03).rotated(Vector3.UP, deg_to_rad(rr)), Color(0.12, 0.1, 0.09), Vector3(0, rr, 0))
		for k in range(4):
			_bx(Vector3(_rng.randf_range(0.04, 0.085), 0.0012, 0.0014), base_at + Vector3(-0.015, 0.0024, -0.005 + 0.011 * float(k)).rotated(Vector3.UP, deg_to_rad(rr)), Color(0.12, 0.1, 0.09), Vector3(0, rr + _rng.randf_range(-2, 2), 0))
	# Развёрнутый лист, исписанный мелко
	var sheet_at := Vector3(0.2, 0.012, -0.1)
	_bx(Vector3(0.16, 0.002, 0.22), sheet_at, PAPER.lightened(0.1), Vector3(0, -12, 0))
	for k in range(14):
		_bx(Vector3(_rng.randf_range(0.09, 0.14), 0.0011, 0.0013), sheet_at + Vector3(0, 0.0016, -0.1 + 0.015 * float(k)).rotated(Vector3.UP, deg_to_rad(-12)), Color(0.12, 0.1, 0.09), Vector3(0, -12 + _rng.randf_range(-1.5, 1.5), 0))
	_emit(table, _matte(true), false)
	# Шпагат вокруг пачек: два-три тонких оборота
	var twine := _part("Twine", Vector3.ZERO, Vector3.ZERO, part)
	for i in range(3):
		var bundle := Vector3(-0.07 + 0.075 * float(i), 0.016 + 0.003 * float(i % 2), -0.02 * float(i % 2))
		_torus(0.059, 0.0605, bundle + Vector3(0, 0.014, 0), Color(0.46, 0.38, 0.22), Vector3(0, 90, 0), Vector3(0.46, 0.5, 1.4))
	_emit(twine, _matte(), false)


func open_letters(on: bool = true) -> void:
	var tw := create_tween()
	tw.tween_property(letters_lid, "rotation_degrees:x", -104.0 if on else 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ═══ 4. Часы с кукушкой: тайник Сэма и Итана, в нём ключ от коробки ═══

func _prism(size: Vector3, at: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = mat
	mi.position = at
	mi.rotation_degrees = rot
	return mi


func _build_clock() -> void:
	clock = _part("CuckooClock", CLOCK_AT, Vector3(0, 90, 0))
	var oak := Color(0.29, 0.19, 0.11)
	var dark := Color(0.17, 0.1, 0.06)
	var w := 0.3
	var h := 0.24
	var d := 0.12
	# Корпус-домик: дно, стенки, полка с точёным краем, крыша с черепицей и фронтон
	_bx(Vector3(w, h, 0.01), Vector3(0, 0.0, -d * 0.5 + 0.005), dark)
	_bx(Vector3(0.012, h, d), Vector3(-w * 0.5 + 0.006, 0.0, 0), oak)
	_bx(Vector3(0.012, h, d), Vector3(w * 0.5 - 0.006, 0.0, 0), oak)
	_bx(Vector3(w, 0.014, d), Vector3(0, -h * 0.5 + 0.007, 0), oak.darkened(0.1))
	_bx(Vector3(w, 0.014, d), Vector3(0, h * 0.5 - 0.007, 0), oak)
	_bx(Vector3(w - 0.03, h - 0.03, 0.008), Vector3(0, 0.0, d * 0.5 - 0.004), dark.lightened(0.04))
	_bx(Vector3(w + 0.03, 0.02, d + 0.03), Vector3(0, -h * 0.5 - 0.008, 0.012), oak.darkened(0.15))
	# Угловые колонки и резные листья
	for s: float in [-1.0, 1.0]:
		_cy(0.012, 0.012, h, Vector3(s * (w * 0.5 - 0.002), 0.0, d * 0.5 - 0.004), oak.lightened(0.08), Vector3.ZERO, 8)
	for i in range(7):
		var x := -0.12 + 0.04 * float(i)
		_bl(Vector3(0.013, 0.02, 0.006), Vector3(x, -h * 0.5 - 0.034, d * 0.5 + 0.004), oak.lightened(0.05), Vector3(0, 0, 18.0 * (float(i) - 3.0)))
	# Крыша: два ската с досками черепицы, ось по глубине, подъём к коньку
	for s: float in [-1.0, 1.0]:
		var rof := Vector3(s * 0.093, h * 0.5 + 0.084, 0.0)
		_bx(Vector3(0.21, 0.014, d + 0.05), rof, oak.lightened(0.04), Vector3(0, 0, -s * 42.0))
		for i in range(5):
			var f := 0.1 + 0.18 * float(i)
			_bx(Vector3(0.036, 0.008, d + 0.054), Vector3(s * (0.03 + f * 0.17), h * 0.5 + 0.01 + f * 0.155, 0.0), _tone(dark.lightened(0.08), 0.2), Vector3(0, 0, -s * 42.0))
	_bx(Vector3(0.02, 0.02, d + 0.06), Vector3(0, h * 0.5 + 0.178, 0), oak.darkened(0.1))
	# Резной конёк с шишкой
	_bl(Vector3(0.016, 0.022, 0.016), Vector3(0, h * 0.5 + 0.2, d * 0.5 + 0.02), oak.lightened(0.1))
	_emit(clock, _furniture(3.0))

	# Передняя панель: циферблат с римскими метками, стрелки, крышечка
	var face := _part("Face", Vector3(0, -0.01, d * 0.5 + 0.001), Vector3.ZERO, clock)
	_cy(0.084, 0.084, 0.01, Vector3.ZERO, Color(0.08, 0.06, 0.04), Vector3(90, 0, 0), 28)
	_cy(0.075, 0.075, 0.006, Vector3(0, 0, 0.006), Color(0.64, 0.58, 0.44), Vector3(90, 0, 0), 28)
	for i in range(12):
		var a := deg_to_rad(float(i) * 30.0)
		_bx(Vector3(0.006 if i % 3 != 0 else 0.009, 0.016 if i % 3 != 0 else 0.022, 0.002), Vector3(sin(a) * 0.058, cos(a) * 0.058, 0.01), Color(0.09, 0.07, 0.05), Vector3(0, 0, -float(i) * 30.0))
	_bx(Vector3(0.004, 0.056, 0.002), Vector3(0.003, 0.025, 0.012), Color(0.06, 0.05, 0.04), Vector3(0, 0, -14))
	_bx(Vector3(0.006, 0.042, 0.002), Vector3(-0.017, 0.013, 0.014), Color(0.06, 0.05, 0.04), Vector3(0, 0, 58))
	_cy(0.007, 0.007, 0.006, Vector3(0, 0, 0.016), BRASS, Vector3(90, 0, 0), 12)
	_torus(0.08, 0.086, Vector3(0, 0, 0.003), BRASS.darkened(0.15), Vector3(90, 0, 0))
	_emit(face, _metal())

	# Домик кукушки: дверцы с петлями и птица. Открываются по очереди
	var nest := _part("Nest", Vector3(0, h * 0.5 + 0.044 - 0.0, d * 0.5 - 0.0), Vector3.ZERO, clock)
	_bx(Vector3(0.1, 0.1, 0.008), Vector3(0, 0, 0.004), Color(0.04, 0.025, 0.015))
	_bx(Vector3(0.1, 0.012, 0.02), Vector3(0, -0.05, 0.01), oak.lightened(0.05))
	for sx: float in [-1.0, 1.0]:
		var leaf := _part("Door%s" % ("L" if sx < 0 else "R"), Vector3(sx * 0.044, 0, 0.012), Vector3.ZERO, nest)
		_bx(Vector3(0.044, 0.09, 0.006), Vector3(-sx * 0.022, 0.0, 0), oak.lightened(0.05))
		_bx(Vector3(0.03, 0.07, 0.003), Vector3(-sx * 0.022, 0.0, 0.004), oak.darkened(0.05))
		_cy(0.0035, 0.0035, 0.01, Vector3(-sx * 0.036, 0.0, 0.006), BRASS, Vector3.ZERO, 8)
		_emit(leaf, _furniture(3.0))
		clock_doors.append(leaf)
	_emit(nest, _furniture(3.0))
	clock_bird = _part("Bird", Vector3(0, -0.005, 0.0), Vector3.ZERO, nest)
	_bl(Vector3(0.022, 0.032, 0.024), Vector3(0, 0, 0.0), Color(0.28, 0.17, 0.08))
	_bl(Vector3(0.015, 0.015, 0.015), Vector3(0, 0.038, 0.008), Color(0.32, 0.2, 0.1))
	_cy(0.0, 0.006, 0.026, Vector3(0, 0.036, 0.028), Color(0.6, 0.45, 0.1), Vector3(90, 0, 0), 8)
	_cy(0.007, 0.002, 0.04, Vector3(0, -0.03, -0.012), Color(0.2, 0.12, 0.06), Vector3(-20, 0, 0), 8)
	_bx(Vector3(0.003, 0.004, 0.003), Vector3(-0.007, 0.042, 0.02), Color(0.01, 0.01, 0.01))
	_bx(Vector3(0.003, 0.004, 0.003), Vector3(0.007, 0.042, 0.02), Color(0.01, 0.01, 0.01))
	_emit(clock_bird, _matte(), false)
	clock_bird.position = Vector3(0, -0.005, -0.04)

	# Тайник в основании: выдвижная планка, спрятанная в резном поясе. Внутри ключ на ленте
	clock_secret = _part("Secret", Vector3(0, -h * 0.5 - 0.008, SECRET_CLOSED), Vector3.ZERO, clock)
	_bx(Vector3(0.2, 0.018, 0.016), Vector3.ZERO, oak.lightened(0.02))
	_bx(Vector3(0.18, 0.006, 0.09), Vector3(0, -0.005, -0.045), dark)
	_bx(Vector3(0.18, 0.006, 0.09), Vector3(0, 0.005, -0.045), dark.lightened(0.03))
	_cy(0.006, 0.006, 0.01, Vector3(0, 0, 0.011), BRASS.darkened(0.1), Vector3(90, 0, 0), 8)
	_emit(clock_secret, _furniture(3.0))
	clock_key = _part("Key", Vector3(0.0, 0.012, -0.05), Vector3(90, 0, 4), clock_secret)
	_torus(0.0095, 0.0135, Vector3(0, 0.044, 0), IRON.lightened(0.18), Vector3(0, 0, 0))
	_cy(0.0035, 0.0035, 0.07, Vector3(0, -0.005, 0), IRON.lightened(0.12), Vector3.ZERO, 8)
	_bx(Vector3(0.016, 0.006, 0.004), Vector3(0.0075, -0.034, 0), IRON.lightened(0.12))
	_bx(Vector3(0.012, 0.006, 0.004), Vector3(0.0055, -0.024, 0), IRON.lightened(0.12))
	_bx(Vector3(0.016, 0.006, 0.004), Vector3(0.0075, -0.043, 0), IRON.lightened(0.12))
	_bx(Vector3(0.003, 0.05, 0.001), Vector3(-0.012, 0.03, 0.002), Color(0.45, 0.07, 0.07))
	_emit(clock_key, _metal())
	clock_key.scale = Vector3.ONE * 1.6

	# Гири-шишки на цепочках и маятник под корпусом
	var drop := _part("Weights", Vector3(0, -h * 0.5 - 0.02, 0), Vector3.ZERO, clock)
	for sx: float in [-1.0, 1.0]:
		var wx := sx * 0.08
		var len := 0.26 if sx < 0 else 0.4
		for i in range(int(len / 0.014)):
			_torus(0.0025, 0.0062, Vector3(wx, -0.0072 * float(i) * 2.0, 0.0), IRON.lightened(0.1), Vector3(0, 0 if i % 2 == 0 else 90, 0), Vector3(0.7, 1.0, 1.0))
		var bottom := -len - 0.02
		_bl(Vector3(0.028, 0.042, 0.028), Vector3(wx, bottom - 0.03, 0.0), Color(0.24, 0.17, 0.08))
		for row in range(4):
			for k in range(8):
				var a := float(k) * 45.0 + 22.0 * float(row)
				var ry := bottom - 0.07 + float(row) * 0.025
				_bl(Vector3(0.012, 0.014, 0.004), Vector3(wx + sin(deg_to_rad(a)) * 0.026, ry, cos(deg_to_rad(a)) * 0.026), Color(0.34, 0.24, 0.12).darkened(0.06 * float(row)), Vector3(0, a, 0))
	_emit(drop, _matte(), true)
	pendulum = _part("Pendulum", Vector3(0, -h * 0.5 - 0.02, 0.0), Vector3.ZERO, clock)
	_pipe(Vector3(0, 0, 0), Vector3(0, -0.2, 0), 0.0025, BRASS.darkened(0.2))
	_cy(0.03, 0.03, 0.008, Vector3(0, -0.22, 0.0), BRASS, Vector3(90, 0, 0), 20)
	_cy(0.012, 0.012, 0.01, Vector3(0, -0.22, 0.003), BRASS.lightened(0.15), Vector3(90, 0, 0), 12)
	_emit(pendulum, _metal())
	pendulum_swing(true)


func pendulum_swing(on: bool = true) -> void:
	if _tween_swing and _tween_swing.is_valid():
		_tween_swing.kill()
	if not on:
		pendulum.rotation_degrees.z = 0.0
		return
	pendulum.rotation_degrees.z = -7.0
	_tween_swing = create_tween().set_loops()
	_tween_swing.tween_property(pendulum, "rotation_degrees:z", 7.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_swing.tween_property(pendulum, "rotation_degrees:z", -7.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func cuckoo(on: bool = true) -> void:
	var tw := create_tween().set_parallel(true)
	for i in range(clock_doors.size()):
		var sx := -1.0 if i == 0 else 1.0
		tw.tween_property(clock_doors[i], "rotation_degrees:y", (-100.0 * sx) if on else 0.0, 0.25)
	tw.tween_property(clock_bird, "position:z", 0.02 if on else -0.04, 0.3).set_delay(0.15 if on else 0.0)


func open_secret(on: bool = true) -> void:
	var tw := create_tween()
	tw.tween_property(clock_secret, "position:z", SECRET_CLOSED + (0.085 if on else 0.0), 0.5).set_trans(Tween.TRANS_SINE)


func take_key() -> Node3D:
	if _key_taken or clock_key == null:
		return null
	_key_taken = true
	var k := clock_key
	clock_key = null
	key_taken.emit()
	k.visible = false
	return k


# ═══ Глава 4, гараж: керосин и карта леса ═══

# Жестяная канистра керосина: красная краска стёрта до металла, ручка, носик с крышкой, бумажная этикетка
func _build_kerosene() -> void:
	kerosene = _part("Kerosene", KEROSENE_AT, Vector3(0, 204, 0))
	var paint := Color(0.46, 0.12, 0.08)
	var worn := Color(0.36, 0.33, 0.3)
	var w := 0.22
	var h := 0.3
	var d := 0.12
	_bx(Vector3(w, h - 0.02, d), Vector3(0, h * 0.5, 0), paint)
	# Загнутые кромки сверху и снизу, стёртые до металла
	_bx(Vector3(w + 0.006, 0.012, d + 0.006), Vector3(0, 0.006, 0), worn)
	_bx(Vector3(w + 0.006, 0.012, d + 0.006), Vector3(0, h - 0.004, 0), worn)
	for sx: float in [-1.0, 1.0]:
		_bx(Vector3(0.006, h - 0.03, 0.01), Vector3(sx * (w * 0.5 + 0.001), h * 0.5, d * 0.5 - 0.003), worn.darkened(0.1))
		_bx(Vector3(0.006, h - 0.03, 0.01), Vector3(sx * (w * 0.5 + 0.001), h * 0.5, -d * 0.5 + 0.003), worn.darkened(0.1))
	# Выштампованная рамка на боках
	for sz: float in [-1.0, 1.0]:
		_bx(Vector3(w - 0.05, h - 0.08, 0.004), Vector3(0, h * 0.5 - 0.005, sz * (d * 0.5 + 0.001)), paint.lightened(0.06))
	# Царапины и ржавые потёки
	for i in range(10):
		var sz := 1.0 if i % 2 == 0 else -1.0
		_bx(Vector3(_rng.randf_range(0.01, 0.05), _rng.randf_range(0.004, 0.03), 0.0015), Vector3(_rng.randf_range(-0.09, 0.09), _rng.randf_range(0.03, h - 0.03), sz * (d * 0.5 + 0.003)), worn if i % 3 else RUST)
	# Ручка сверху и носик с латунной крышкой
	for sx: float in [-0.06, 0.06]:
		_bx(Vector3(0.012, 0.04, 0.02), Vector3(sx, h + 0.02, 0), worn)
	_bx(Vector3(0.13, 0.016, 0.026), Vector3(0, h + 0.044, 0), Color(0.1, 0.1, 0.1))
	_cy(0.017, 0.02, 0.03, Vector3(0.085, h + 0.012, 0), worn, Vector3.ZERO, 12)
	_cy(0.021, 0.021, 0.018, Vector3(0.085, h + 0.034, 0), BRASS, Vector3.ZERO, 12)
	_emit(kerosene, _metal())
	# Этикетка на боку
	var label := _part("Label", Vector3(0, h * 0.5, d * 0.5 + 0.0045), Vector3.ZERO, kerosene)
	_bx(Vector3(0.14, 0.12, 0.002), Vector3.ZERO, PAPER.darkened(0.05))
	_bx(Vector3(0.14, 0.018, 0.0024), Vector3(0, 0.035, 0.0003), Color(0.12, 0.1, 0.09))
	_emit(label, _matte(), false)
	var txt := Label3D.new()
	txt.text = "КЕРОСИН"
	txt.font_size = 40
	txt.pixel_size = 0.0007
	txt.modulate = Color(0.1, 0.08, 0.07)
	txt.outline_size = 0
	txt.shaded = true
	txt.double_sided = false
	txt.position = Vector3(0, -0.012, 0.0016)
	label.add_child(txt)
	var small := Label3D.new()
	small.text = "осветительный\n5 л"
	small.font_size = 24
	small.pixel_size = 0.0006
	small.modulate = Color(0.16, 0.13, 0.11)
	small.outline_size = 0
	small.shaded = true
	small.double_sided = false
	small.position = Vector3(0, -0.04, 0.0016)
	label.add_child(small)


func take_kerosene() -> Node3D:
	if kerosene == null or not kerosene.visible:
		return null
	kerosene.visible = false
	return kerosene


# Старая карта леса, нарисованная от руки: дом отца внизу, тропа через лес, дом Крейна наверху
func _build_forest_map() -> void:
	forest_map = _part("ForestMap", FOREST_MAP_AT, Vector3(0, 180, -2))
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.62, 0.46)
	sheet.mesh = quad
	var m := StandardMaterial3D.new()
	m.albedo_texture = _forest_map_texture()
	m.roughness = 0.92
	m.albedo_color = Color(0.82, 0.82, 0.82)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	sheet.material_override = m
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	forest_map.add_child(sheet)
	# Кнопки по углам
	for c: Vector2 in [Vector2(-0.29, 0.21), Vector2(0.29, 0.21), Vector2(-0.29, -0.21), Vector2(0.29, -0.21)]:
		_cy(0.007, 0.008, 0.008, Vector3(c.x, c.y, 0.004), Color(0.6, 0.1, 0.08), Vector3(90, 0, 0), 10)
	_emit(forest_map, _matte())


func take_map() -> Node3D:
	if forest_map == null or not forest_map.visible:
		return null
	forest_map.visible = false
	return forest_map


static var _map_tex: ImageTexture


static func _forest_map_texture() -> ImageTexture:
	if _map_tex:
		return _map_tex
	var w := 512
	var h := 380
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1815
	img.fill(Color(0.78, 0.72, 0.57))
	# Пятна и потемневшие края старой бумаги
	for i in range(40):
		_map_disc(img, Vector2(rng.randf() * w, rng.randf() * h), rng.randf_range(12, 60), Color(0.62, 0.53, 0.38), 0.12)
	for x in range(w):
		for y in [0, 1, 2, 3, h - 1, h - 2, h - 3, h - 4]:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.25))
	for y in range(h):
		for x in [0, 1, 2, 3, w - 1, w - 2, w - 3, w - 4]:
			img.set_pixel(x, y, img.get_pixel(x, y).darkened(0.25))
	# Лес: много тёмно-зелёных пятен, вдоль тропы просека
	var trail := [Vector2(70, 330), Vector2(130, 290), Vector2(170, 240), Vector2(250, 220), Vector2(300, 170), Vector2(360, 140), Vector2(420, 80)]
	for i in range(520):
		var p := Vector2(rng.randf() * w, rng.randf() * h)
		var near := INF
		for k in range(trail.size() - 1):
			near = minf(near, _seg_dist(p, trail[k], trail[k + 1]))
		if near < 16.0 or p.distance_to(Vector2(70, 330)) < 40.0:
			continue
		_map_disc(img, p, rng.randf_range(4, 9), Color(0.2, 0.3, 0.16), 0.75)
	# Ручей
	var river := [Vector2(0, 150), Vector2(80, 170), Vector2(160, 150), Vector2(230, 175), Vector2(300, 230), Vector2(380, 260), Vector2(512, 250)]
	for k in range(river.size() - 1):
		_map_line(img, river[k], river[k + 1], 3.0, Color(0.22, 0.34, 0.5), 1.0, 0)
	# Дорога внизу и дом отца у неё
	_map_line(img, Vector2(0, 352), Vector2(512, 340), 4.0, Color(0.3, 0.27, 0.22), 1.0, 0)
	_map_rect(img, Vector2(58, 318), Vector2(84, 340), Color(0.08, 0.07, 0.06))
	# Тропа пунктиром, дом Крейна обведён красным, крест рядом
	for k in range(trail.size() - 1):
		_map_line(img, trail[k], trail[k + 1], 2.2, Color(0.5, 0.08, 0.06), 1.0, 9)
	_map_rect(img, Vector2(408, 66), Vector2(432, 88), Color(0.08, 0.07, 0.06))
	for a in range(0, 360, 2):
		var t := deg_to_rad(float(a))
		var r := 26.0 + 2.0 * sin(t * 3.0)
		_map_disc(img, Vector2(420, 77) + Vector2(cos(t), sin(t)) * r, 2.2, Color(0.62, 0.08, 0.06), 1.0)
	# Сгибы листа
	for x in range(w):
		img.set_pixel(x, h / 2, img.get_pixel(x, h / 2).darkened(0.18))
		img.set_pixel(x, h / 2 + 1, img.get_pixel(x, h / 2 + 1).lightened(0.08))
	for y in range(h):
		img.set_pixel(w / 2, y, img.get_pixel(w / 2, y).darkened(0.18))
		img.set_pixel(w / 2 + 1, y, img.get_pixel(w / 2 + 1, y).lightened(0.08))
	img.generate_mipmaps()
	_map_tex = ImageTexture.create_from_image(img)
	return _map_tex


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _map_disc(img: Image, c: Vector2, r: float, col: Color, alpha: float) -> void:
	for y in range(maxi(0, int(c.y - r - 1)), mini(img.get_height(), int(c.y + r + 2))):
		for x in range(maxi(0, int(c.x - r - 1)), mini(img.get_width(), int(c.x + r + 2))):
			var a := clampf(r - Vector2(x + 0.5, y + 0.5).distance_to(c) + 0.5, 0.0, 1.0) * alpha
			if a > 0.0:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, a))


static func _map_line(img: Image, a: Vector2, b: Vector2, r: float, col: Color, alpha: float, dash: int) -> void:
	var len := a.distance_to(b)
	var steps := int(len / 1.5) + 1
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		if dash > 0 and int(t * len / float(dash)) % 2 == 1:
			continue
		_map_disc(img, a.lerp(b, t), r, col, alpha * 0.6)


static func _map_rect(img: Image, a: Vector2, b: Vector2, col: Color) -> void:
	img.fill_rect(Rect2i(Vector2i(a), Vector2i(b - a)), col)


# ═══ Убрать из карты старые кубики-заглушки, которые эти модели заменяют ═══

func _remove_old() -> void:
	var holder := get_parent().get_parent() if get_parent() and get_parent().get_parent() else get_parent()
	if holder == null:
		return
	for id in OLD_IDS:
		for n in holder.find_children("*_%d" % id, "", true, false):
			if n is Node3D and n != self and not self.is_ancestor_of(n):
				n.queue_free()
