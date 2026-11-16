extends "res://scripts/ApartmentKit.gd"

# Обжитые мелочи в доме отца (карта «Шоссе»), по сюжету: старик жил тут один, Сэм за ним
# присматривал, полиция уже приходила. Механик здесь нет, предметы глав не трогаются.
#   Ванная: ванна на ножках, унитаз, треснувшее зеркало, полотенце.
#   Кухня: две кружки на столе (отец и Сэм), чайник, кастрюля, посуда, сковородки.
#   Гостиная: плед на диване, газета и очки на столике, рога над диваном, ружьё на стене.
#   Прихожая: вешалка с куртками отца, сапоги, ключи на комоде.
#   Комната отца: лампа, стакан воды и таблетки, тапки, фото жены, жёлтые метки полиции.
#   Комната Сэма: кровать, фото с фотоловушек на стене, камера и кассеты на столе, рюкзак.
# Узел стоит внутри дома, чтобы прятаться вместе с остальными внутренностями (HighwayChapter).

const ORIGIN := Vector3(-62.0, 0.0, -225.0)
const GY := 0.16
const FY := 3.48

const WHITE := Color(0.84, 0.83, 0.78)
const WOOD := Color(0.36, 0.26, 0.18)
const DARK_WOOD := Color(0.22, 0.16, 0.11)
const IRON := Color(0.14, 0.14, 0.15)
# Метки полиции у кровати отца (в главе 3 кровать отъезжает к -223.25 — туда не ставим)
const MARKS := [[-67.7, -222.6, "1"], [-66.9, -221.4, "2"], [-67.2, -223.7, "3"]]
const BRASS := Color(0.55, 0.42, 0.2)


func _ready() -> void:
	name = "HouseDressing"
	position = ORIGIN
	_rng.seed = 5150
	_bathroom()
	_flush(_vmat(0.3), true)
	_kitchen()
	_flush(_vmat(0.45, 0.25), true)
	_living()
	_hall()
	_flush(_vmat(0.85), true)
	_father_room()
	_sam_room()
	_flush(_vmat(0.8), true)
	_mirror()
	_texts()
	_solids()


func _at(p: Vector3, yaw: float = 0.0) -> void:
	_base = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), p - ORIGIN)


func _w(p: Vector3) -> Vector3:
	return p - ORIGIN


# ── Ванная (x -71..-65, z -231..-225) ──

func _bathroom() -> void:
	# Ванна на львиных ножках у северной стены
	_at(Vector3(-69.92, GY, -230.38))
	_softbox(Vector3(1.66, 0.5, 0.74), _xf(Vector3(0, 0.39, 0)), WHITE, 0.3, 0.0, 0.18)
	_softbox(Vector3(1.48, 0.1, 0.58), _xf(Vector3(0, 0.61, 0)), Color(0.42, 0.4, 0.34), 0.4)
	_bx(Vector3(1.4, 0.02, 0.5), Vector3(0, 0.6, 0), Color(0.3, 0.27, 0.2))
	for fx in [-0.62, 0.62]:
		for fz in [-0.24, 0.24]:
			_bl(Vector3(0.06, 0.08, 0.06), Vector3(fx, 0.08, fz), BRASS)
	_pipe(Vector3(-0.78, 0.6, 0), Vector3(-0.78, 0.86, 0), 0.02, BRASS)
	_pipe(Vector3(-0.78, 0.86, 0), Vector3(-0.64, 0.86, 0), 0.016, BRASS)
	# Ржавый потёк под краном
	_bx(Vector3(0.05, 0.003, 0.18), Vector3(-0.6, 0.615, 0.02), Color(0.45, 0.25, 0.1))
	# Унитаз с бачком на стене
	_at(Vector3(-67.6, GY, -230.42))
	_cy(0.15, 0.12, 0.38, Vector3(0, 0.19, 0.12), WHITE, Vector3.ZERO, 16)
	_softbox(Vector3(0.38, 0.06, 0.46), _xf(Vector3(0, 0.4, 0.14)), WHITE, 0.45)
	_bx(Vector3(0.36, 0.03, 0.42), Vector3(0, 0.44, 0.15), Color(0.5, 0.4, 0.3), Vector3(-4, 0, 0))
	_softbox(Vector3(0.44, 0.36, 0.18), _xf(Vector3(0, 0.62, -0.27)), WHITE, 0.4)
	_bx(Vector3(0.46, 0.03, 0.2), Vector3(0, 0.815, -0.27), WHITE.darkened(0.05))
	_bx(Vector3(0.06, 0.02, 0.02), Vector3(0.14, 0.76, -0.17), Color(0.6, 0.6, 0.6))
	# Полочка над раковиной и полотенце у двери
	_at(Vector3(-70.72, GY, -226.8))
	_bx(Vector3(0.14, 0.03, 0.55), Vector3(0, 1.32, 0), Color(0.8, 0.8, 0.76))
	for k in range(3):
		var z := -0.18 + k * 0.17
		_cy(0.025, 0.025, 0.12 + k * 0.02, Vector3(0.02, 1.4 + k * 0.01, z), [Color(0.25, 0.45, 0.6), Color(0.6, 0.55, 0.4), WHITE][k], Vector3.ZERO, 8)
	_at(Vector3(-67.8, GY, -225.19))
	_pipe(Vector3(-0.35, 1.4, -0.05), Vector3(0.35, 1.4, -0.05), 0.012, Color(0.6, 0.6, 0.6))
	_bx(Vector3(0.5, 0.62, 0.025), Vector3(0.0, 1.11, -0.065), Color(0.62, 0.6, 0.52))
	_bx(Vector3(0.5, 0.05, 0.03), Vector3(0.0, 0.84, -0.065), Color(0.5, 0.48, 0.42))
	# Коврик у ванны
	_at(Vector3(-69.9, GY, -229.55))
	_bx(Vector3(0.9, 0.012, 0.5), Vector3(0, 0.006, 0), Color(0.4, 0.45, 0.4))


# Зеркало над раковиной: тёмное стекло с трещиной
func _mirror() -> void:
	_at(Vector3(-70.8, GY, -226.8))
	_bx(Vector3(0.04, 0.7, 0.54), Vector3(0, 1.78, 0), DARK_WOOD)
	_flush(_vmat(0.8), true)
	_at(Vector3(-70.8, GY, -226.8))
	_bx(Vector3(0.045, 0.6, 0.44), Vector3(0.002, 1.78, 0), Color(0.5, 0.52, 0.55))
	_flush(_vmat(0.05, 0.9))
	_at(Vector3(-70.77, GY, -226.8))
	for k in [[0.06, 1.86, 0.02, 0.32, 35.0], [-0.05, 1.7, 0.0, 0.26, -50.0], [0.1, 1.68, 0.0, 0.18, 80.0]]:
		_bx(Vector3(0.004, k[3], 0.006), Vector3(0.0, k[1], k[0]), Color(0.85, 0.87, 0.88), Vector3(k[4], 0, 0))
	_flush(_vmat(0.3))


# ── Кухня (x -65..-59, z -231..-225) ──

func _kitchen() -> void:
	var table_top := GY + 0.8
	_at(Vector3(-62.0, table_top, -227.5))
	# Две кружки: отца и Сэма. Одна недопита
	_mug(Vector3(-0.3, 0, 0.12), Color(0.72, 0.68, 0.6), true)
	_mug(Vector3(0.34, 0, -0.18), Color(0.3, 0.38, 0.5), false)
	_cy(0.13, 0.11, 0.02, Vector3(0.05, 0.01, -0.05), WHITE, Vector3.ZERO, 18)
	_bx(Vector3(0.16, 0.05, 0.08), Vector3(0.05, 0.045, -0.05), Color(0.55, 0.38, 0.2), Vector3(0, 20, 0))
	_cy(0.05, 0.06, 0.09, Vector3(-0.45, 0.045, -0.2), Color(0.65, 0.6, 0.5), Vector3.ZERO, 10)
	_bx(Vector3(0.02, 0.003, 0.18), Vector3(0.2, 0.002, 0.15), Color(0.7, 0.7, 0.7), Vector3(0, -30, 0))
	# Плита: чайник и кастрюля
	_at(Vector3(-61.6, GY + 0.9, -230.45))
	_cy(0.08, 0.11, 0.17, Vector3(-0.17, 0.085, 0.1), Color(0.28, 0.3, 0.3), Vector3.ZERO, 14)
	_pipe(Vector3(-0.07, 0.07, 0.1), Vector3(0.0, 0.15, 0.1), 0.016, Color(0.28, 0.3, 0.3))
	_torus(0.006, 0.02, Vector3(-0.17, 0.2, 0.1), IRON, Vector3(90, 0, 0), Vector3(3.5, 1, 1))
	_cy(0.14, 0.14, 0.16, Vector3(0.17, 0.08, -0.08), Color(0.62, 0.6, 0.55), Vector3.ZERO, 16)
	_cy(0.145, 0.145, 0.015, Vector3(0.17, 0.165, -0.08), Color(0.55, 0.53, 0.5), Vector3.ZERO, 16)
	# Стойка: сушилка с тарелками, банки, разделочная доска
	_at(Vector3(-63.3, GY + 0.9, -230.45))
	_bx(Vector3(0.4, 0.03, 0.26), Vector3(-0.75, 0.015, 0.0), Color(0.4, 0.38, 0.35))
	for k in range(5):
		_cy(0.12, 0.12, 0.012, Vector3(-0.9 + k * 0.07, 0.13, 0.0), WHITE, Vector3(0, 0, 78), 16)
	_bx(Vector3(0.42, 0.025, 0.28), Vector3(0.2, 0.013, 0.08), Color(0.55, 0.4, 0.24), Vector3(0, -8, 0))
	_bx(Vector3(0.2, 0.004, 0.025), Vector3(0.25, 0.03, 0.06), Color(0.7, 0.7, 0.72), Vector3(0, 25, 0))
	for k in range(3):
		_cy(0.06, 0.06, 0.16 + k * 0.03, Vector3(0.62 + k * 0.14, 0.08 + k * 0.015, -0.18), Color(0.6, 0.7, 0.65, 1.0).darkened(0.1 * k), Vector3.ZERO, 12)
		_cy(0.062, 0.062, 0.025, Vector3(0.62 + k * 0.14, 0.17 + k * 0.03, -0.18), Color(0.55, 0.42, 0.15), Vector3.ZERO, 12)
	# Сковородки на стене у ванной
	_at(Vector3(-64.82, GY, -228.6))
	_bx(Vector3(0.03, 0.04, 0.9), Vector3(0, 1.85, 0), DARK_WOOD)
	for k in range(3):
		var z := -0.3 + k * 0.3
		var r := 0.12 + k * 0.025
		_cy(r, r * 0.9, 0.04, Vector3(0.04, 1.7 - r, z), IRON, Vector3(0, 0, 90), 16)
		_bx(Vector3(0.02, 0.22, 0.025), Vector3(0.03, 1.75, z), DARK_WOOD)
	# Ведро у плиты
	_at(Vector3(-60.0, GY, -229.3))
	_cy(0.17, 0.14, 0.34, Vector3(0, 0.17, 0), Color(0.42, 0.44, 0.45), Vector3.ZERO, 14, false)


func _mug(p: Vector3, col: Color, full: bool) -> void:
	_cy(0.045, 0.04, 0.1, p + Vector3(0, 0.05, 0), col, Vector3.ZERO, 12)
	_torus(0.008, 0.03, p + Vector3(0.055, 0.05, 0), col, Vector3(90, 0, 0))
	if full:
		_cy(0.04, 0.04, 0.005, p + Vector3(0, 0.08, 0), Color(0.16, 0.09, 0.05), Vector3.ZERO, 12)


# ── Гостиная (x -71..-59, z -225..-219) ──

func _living() -> void:
	# Газета, очки и пепельница с трубкой на журнальном столе
	_at(Vector3(-65.8, GY + 0.55, -222.4), 8.0)
	_bx(Vector3(0.42, 0.012, 0.3), Vector3(-0.25, 0.006, 0.05), Color(0.78, 0.76, 0.7), Vector3(0, 12, 0))
	_bx(Vector3(0.36, 0.006, 0.26), Vector3(-0.2, 0.014, 0.0), Color(0.82, 0.8, 0.74), Vector3(0, -6, 0))
	_torus(0.004, 0.025, Vector3(0.12, 0.012, 0.1), IRON, Vector3.ZERO)
	_torus(0.004, 0.025, Vector3(0.18, 0.012, 0.1), IRON, Vector3.ZERO)
	_cy(0.07, 0.06, 0.03, Vector3(0.35, 0.015, -0.12), Color(0.35, 0.36, 0.38), Vector3.ZERO, 12)
	_tube([Vector3(0.3, 0.04, -0.12), Vector3(0.38, 0.045, -0.1), Vector3(0.44, 0.06, -0.06)], 0.009, DARK_WOOD, 6)
	_cy(0.022, 0.018, 0.04, Vector3(0.3, 0.05, -0.12), DARK_WOOD, Vector3.ZERO, 8)
	# Плед, сползший с дивана
	_at(Vector3(-66.0, GY, -219.95), 180.0)
	_softbox(Vector3(1.1, 0.06, 0.7), _xf(Vector3(0.45, 0.58, -0.05), Vector3(0, 8, -6)), Color(0.2, 0.3, 0.24), 0.5, 0.3)
	_softbox(Vector3(0.5, 0.05, 0.4), _xf(Vector3(0.75, 0.42, -0.5), Vector3(70, 0, 0)), Color(0.19, 0.28, 0.22), 0.5)
	for k in range(4):
		_bx(Vector3(1.0, 0.065, 0.025), Vector3(0.45, 0.585, -0.3 + k * 0.17), Color(0.55, 0.45, 0.2), Vector3(0, 8, -6))
	# Оленьи рога на дощечке над диваном
	_at(Vector3(-66.0, GY + 2.25, -219.18), 180.0)
	_softbox(Vector3(0.36, 0.42, 0.04), _xf(Vector3(0, 0, 0)), DARK_WOOD, 0.5)
	_bl(Vector3(0.06, 0.06, 0.05), Vector3(0, 0.05, 0.04), Color(0.82, 0.78, 0.68))
	for s in [-1.0, 1.0]:
		var antler := Color(0.78, 0.72, 0.6)
		var main := [Vector3(s * 0.04, 0.07, 0.07), Vector3(s * 0.2, 0.2, 0.11), Vector3(s * 0.32, 0.42, 0.1), Vector3(s * 0.3, 0.62, 0.06)]
		_tube(_smooth(main, 4), func(k): return lerpf(0.022, 0.008, k), antler, 6)
		for t in [[1, 0.2], [2, 0.18]]:
			var b: Vector3 = main[t[0]]
			_tube([b, b + Vector3(-s * 0.05, t[1], 0.04)], 0.009, antler, 5)
	# Ружьё на двух крючках на северной стене, над креслом
	_at(Vector3(-68.2, GY + 1.95, -224.83), -90.0)
	for dz in [-0.32, 0.32]:
		_bx(Vector3(0.08, 0.03, 0.03), Vector3(0.04, -0.03, dz), IRON)
	_bx(Vector3(0.05, 0.035, 0.75), Vector3(0.08, 0.02, -0.18), IRON)
	_bx(Vector3(0.05, 0.06, 0.5), Vector3(0.08, 0.0, 0.42), Color(0.32, 0.2, 0.12))
	_bx(Vector3(0.05, 0.12, 0.28), Vector3(0.08, -0.06, 0.62), Color(0.32, 0.2, 0.12), Vector3(-12, 0, 0))
	# Корзина с поленьями у кресла
	_at(Vector3(-70.3, GY, -224.4))
	_cy(0.24, 0.2, 0.32, Vector3(0, 0.16, 0), Color(0.45, 0.35, 0.2), Vector3.ZERO, 14, false)
	for k in range(5):
		_cy(0.045, 0.045, 0.5, Vector3(-0.12 + k * 0.06, 0.34, _rng.randf_range(-0.08, 0.08)), Color(0.35, 0.25, 0.16), Vector3(90, _rng.randf_range(-20, 20), 0), 7)
	# Фотографии в рамках на стене у двери в гостиную
	for k in range(3):
		_at(Vector3(-59.17, GY + 1.55 + (k % 2) * 0.3, -221.3 + k * 0.42))
		_bx(Vector3(0.025, 0.26, 0.2), Vector3.ZERO, DARK_WOOD)
		_bx(Vector3(0.028, 0.2, 0.15), Vector3(-0.003, 0, 0), Color(0.5, 0.46, 0.4).darkened(0.1 * k))


# ── Прихожая (x -59..-53) ──

func _hall() -> void:
	# Вешалка у двери: куртки и шапка отца
	_at(Vector3(-58.83, GY, -220.15), 180.0)
	_bx(Vector3(0.04, 0.1, 0.9), Vector3(-0.02, 1.75, 0), DARK_WOOD)
	for dz in [-0.32, 0.0, 0.32]:
		_bx(Vector3(0.12, 0.025, 0.025), Vector3(-0.08, 1.74, dz), IRON, Vector3(0, 0, -25))
	_softbox(Vector3(0.18, 0.9, 0.42), _xf(Vector3(-0.13, 1.28, -0.28)), Color(0.24, 0.27, 0.18), 0.45, 0.1)
	_softbox(Vector3(0.16, 0.8, 0.38), _xf(Vector3(-0.12, 1.32, 0.1), Vector3(0, 0, 3)), Color(0.32, 0.22, 0.15), 0.45, 0.1)
	_softbox(Vector3(0.2, 0.14, 0.2), _xf(Vector3(-0.12, 1.86, 0.32)), Color(0.3, 0.12, 0.1), 0.55, 0.4)
	# Резиновые сапоги под вешалкой (дверь открывается внутрь, место у неё свободно)
	for k in [[-0.1, 0.0], [0.1, 18.0]]:
		_at(Vector3(-58.55, GY, -220.15 + k[0] * 2.0), 90.0 + k[1])
		_bx(Vector3(0.11, 0.36, 0.13), Vector3(0, 0.19, 0), Color(0.12, 0.15, 0.1))
		_bx(Vector3(0.12, 0.08, 0.28), Vector3(0, 0.04, 0.07), Color(0.12, 0.15, 0.1))
	# Ключи и фонарь на комоде
	_at(Vector3(-53.5, GY + 0.9, -230.0), 270.0)
	_cy(0.1, 0.07, 0.04, Vector3(0.2, 0.02, 0), Color(0.42, 0.3, 0.2), Vector3.ZERO, 14)
	_bx(Vector3(0.05, 0.004, 0.02), Vector3(0.2, 0.045, 0.02), BRASS, Vector3(0, 30, 0))
	_torus(0.004, 0.016, Vector3(0.18, 0.045, 0.0), Color(0.6, 0.6, 0.6), Vector3.ZERO)
	_cy(0.025, 0.025, 0.22, Vector3(-0.2, 0.03, 0.05), Color(0.18, 0.18, 0.2), Vector3(0, 0, 90), 10)


# ── Комната отца (второй этаж, x -71..-59, z -225..-219) ──

func _father_room() -> void:
	# Тумбочка: лампа, стакан воды, таблетки, очки
	_at(Vector3(-67.6, FY + 0.74, -219.6))
	_cy(0.06, 0.07, 0.03, Vector3(-0.2, 0.015, -0.12), Color(0.3, 0.26, 0.2), Vector3.ZERO, 12)
	_cy(0.012, 0.012, 0.3, Vector3(-0.2, 0.17, -0.12), BRASS, Vector3.ZERO, 6)
	_cy(0.07, 0.12, 0.16, Vector3(-0.2, 0.36, -0.12), Color(0.75, 0.68, 0.5), Vector3.ZERO, 14, false)
	_cy(0.03, 0.027, 0.1, Vector3(0.2, 0.05, -0.18), Color(0.75, 0.8, 0.82), Vector3.ZERO, 10)
	for k in range(3):
		_cy(0.018, 0.018, 0.06, Vector3(-0.06 + k * 0.045, 0.03, -0.17), Color(0.75, 0.45, 0.15), Vector3.ZERO, 8)
		_cy(0.019, 0.019, 0.015, Vector3(-0.06 + k * 0.045, 0.065, -0.17), WHITE, Vector3.ZERO, 8)
	# Тапки у кровати
	for k in [[-0.08, 6.0], [0.1, -10.0]]:
		_at(Vector3(-67.95 + k[0], FY, -222.0), k[1])
		_softbox(Vector3(0.1, 0.06, 0.27), _xf(Vector3(0, 0.03, 0)), Color(0.3, 0.22, 0.17), 0.5)
	# Фото жены (Марта) на комоде и огарок свечи
	_at(Vector3(-64.2, FY + 0.9, -224.55))
	_bx(Vector3(0.2, 0.26, 0.02), Vector3(-0.3, 0.13, 0.05), DARK_WOOD, Vector3(-10, 0, 0))
	_bx(Vector3(0.15, 0.2, 0.022), Vector3(-0.3, 0.13, 0.053), Color(0.5, 0.45, 0.38), Vector3(-10, 0, 0))
	_bx(Vector3(0.04, 0.1, 0.06), Vector3(-0.3, 0.05, 0.02), DARK_WOOD)
	_cy(0.05, 0.05, 0.015, Vector3(0.1, 0.008, 0.05), BRASS, Vector3.ZERO, 12)
	_cy(0.02, 0.02, 0.06, Vector3(0.1, 0.045, 0.05), Color(0.85, 0.82, 0.7), Vector3.ZERO, 8)
	_bx(Vector3(0.12, 0.012, 0.2), Vector3(0.35, 0.006, 0.0), Color(0.5, 0.4, 0.3), Vector3(0, 15, 0))
	# Жёлтые метки полиции на полу у кровати
	for k in MARKS:
		_at(Vector3(k[0], FY, k[1]), 90.0)
		_parts.append([_tent(), _base * _xf(Vector3(0, 0.05, 0)), Color(0.9, 0.62, 0.04)])


func _tent() -> PrismMesh:
	var m := PrismMesh.new()
	m.size = Vector3(0.1, 0.1, 0.075)
	return m


# ── Комната Сэма (второй этаж, x -71..-59, z -231..-225) ──

func _sam_room() -> void:
	# Кровать под картой леса: не заправлена
	_at(Vector3(-62.55, FY, -225.82))
	for fx in [-0.98, 0.98]:
		for fz in [-0.44, 0.44]:
			_bx(Vector3(0.07, 0.36, 0.07), Vector3(fx, 0.18, fz), WOOD)
	_bx(Vector3(2.0, 0.08, 0.96), Vector3(0, 0.3, 0), WOOD)
	_bx(Vector3(0.06, 0.75, 0.96), Vector3(-1.0, 0.375, 0), WOOD)
	_softbox(Vector3(1.92, 0.18, 0.88), _xf(Vector3(0, 0.43, 0)), Color(0.75, 0.73, 0.68), 0.3)
	_softbox(Vector3(0.4, 0.12, 0.62), _xf(Vector3(-0.72, 0.56, 0)), Color(0.82, 0.8, 0.75), 0.5, 0.2)
	_softbox(Vector3(1.25, 0.12, 0.98), _xf(Vector3(0.28, 0.55, 0.04), Vector3(0, 6, 3)), Color(0.22, 0.3, 0.38), 0.5, 0.35)
	_softbox(Vector3(0.6, 0.18, 0.5), _xf(Vector3(0.55, 0.6, -0.15), Vector3(0, -20, 0)), Color(0.2, 0.28, 0.36), 0.6, 0.4)
	# Стол: камера-ловушка, кассеты, тетрадь
	_at(Vector3(-66.0, FY + 0.8, -230.3))
	_bx(Vector3(0.14, 0.2, 0.1), Vector3(-0.55, 0.1, 0.0), Color(0.23, 0.26, 0.17), Vector3(0, 20, 0))
	_cy(0.035, 0.035, 0.03, Vector3(-0.53, 0.12, 0.06), Color(0.05, 0.05, 0.05), Vector3(90, 20, 0), 10)
	_bx(Vector3(0.05, 0.03, 0.006), Vector3(-0.51, 0.18, 0.052), Color(0.8, 0.8, 0.8), Vector3(0, 20, 0))
	for k in range(5):
		_bx(Vector3(0.19, 0.025, 0.105), Vector3(0.15, 0.0125 + k * 0.026, -0.1), Color(0.08, 0.08, 0.09), Vector3(0, _rng.randf_range(-8, 8), 0))
		_bx(Vector3(0.12, 0.016, 0.003), Vector3(0.15, 0.013 + k * 0.026, -0.047), Color(0.85, 0.83, 0.75))
	_bx(Vector3(0.28, 0.015, 0.2), Vector3(0.55, 0.008, 0.1), Color(0.3, 0.4, 0.55), Vector3(0, -12, 0))
	_bx(Vector3(0.15, 0.006, 0.008), Vector3(0.5, 0.02, 0.13), Color(0.85, 0.7, 0.1), Vector3(0, 30, 0))
	# Над столом: снимки с фотоловушек на кнопках, между ними красная нить
	var pins := []
	for k in range(7):
		var p := Vector3(-66.85 + k * 0.28 + _rng.randf_range(-0.05, 0.05), FY + 1.55 + _rng.randf_range(-0.22, 0.25), -230.83)
		pins.append(p)
		_at(p, 0.0)
		_bx(Vector3(0.17, 0.12, 0.004), Vector3.ZERO, Color(0.45, 0.48, 0.42).darkened(_rng.randf_range(0.0, 0.4)), Vector3(0, 0, _rng.randf_range(-8, 8)))
		_bx(Vector3(0.16, 0.025, 0.005), Vector3(0, -0.045, 0.001), Color(0.9, 0.88, 0.8))
		_bl(Vector3(0.012, 0.012, 0.012), Vector3(0, 0.05, 0.006), Color(0.8, 0.1, 0.08))
	_base = Transform3D(Basis(), -ORIGIN)
	for k in range(pins.size() - 1):
		var a: Vector3 = pins[k] + Vector3(0, 0.05, 0.009)
		var b: Vector3 = pins[k + 1] + Vector3(0, 0.05, 0.009)
		_tube([a, (a + b) * 0.5 - Vector3(0, 0.03, 0), b], 0.0025, Color(0.7, 0.06, 0.05), 4)
	# Рюкзак и кроссовки у кровати
	_at(Vector3(-64.1, FY, -226.6), 25.0)
	_softbox(Vector3(0.34, 0.46, 0.22), _xf(Vector3(0, 0.22, 0), Vector3(-12, 0, 0)), Color(0.28, 0.3, 0.24), 0.45, 0.15)
	_softbox(Vector3(0.24, 0.14, 0.08), _xf(Vector3(0, 0.16, 0.13), Vector3(-12, 0, 0)), Color(0.24, 0.26, 0.2), 0.45)
	for k in [[-0.35, 0.0], [-0.52, 40.0]]:
		_at(Vector3(-63.0 + k[0], FY, -226.75), k[1])
		_softbox(Vector3(0.11, 0.09, 0.28), _xf(Vector3(0, 0.045, 0)), Color(0.7, 0.7, 0.68), 0.4)
		_bx(Vector3(0.115, 0.025, 0.285), Vector3(0, 0.012, 0), Color(0.2, 0.2, 0.2))
	# Постер на стене между телевизором и шкафом: горы и надпись
	_at(Vector3(-70.83, FY + 1.6, -227.95))
	_bx(Vector3(0.006, 0.84, 0.6), Vector3.ZERO, Color(0.1, 0.13, 0.18))
	_bx(Vector3(0.008, 0.3, 0.6), Vector3(0, -0.2, 0), Color(0.08, 0.16, 0.12))
	for k in range(4):
		_bx(Vector3(0.008, 0.22, 0.22), Vector3(0.001, -0.02 + (k % 2) * 0.04, -0.2 + k * 0.13), Color(0.25, 0.3, 0.36), Vector3(45, 0, 0))


func _texts() -> void:
	# Цифры на метках полиции и надпись на постере Сэма
	for k in MARKS:
		CutsceneKit.text3d(self, k[2], _w(Vector3(k[0], FY + 0.05, k[1] + 0.027)), Vector3(-27, 0, 0), 0.0012, Color(0.05, 0.05, 0.05), 48)
	CutsceneKit.text3d(self, "BLACK PINE\nтропа 04", _w(Vector3(-70.82, FY + 1.85, -227.95)), Vector3(0, 90, 0), 0.0014, Color(0.85, 0.82, 0.7), 48)


# Ванна, унитаз и кровать Сэма твёрдые
func _solids() -> void:
	_solid(_w(Vector3(-69.92, GY + 0.35, -230.38)), Vector3(1.66, 0.7, 0.74))
	_solid(_w(Vector3(-67.6, GY + 0.25, -230.3)), Vector3(0.4, 0.5, 0.6))
	_solid(_w(Vector3(-62.55, FY + 0.3, -225.82)), Vector3(2.04, 0.6, 0.96))
