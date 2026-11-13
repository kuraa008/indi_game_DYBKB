class_name DeerSkullModel
extends "res://scripts/models/SculptKit.gd"

# Олений череп Джозефа Крейна. Слеплен поверхностью: мозговая коробка, глазницы с костяным
# ободом, слёзные ямки, скуловые дуги, носовые кости и ноздри, ряды коренных зубов,
# затылочные мыщелки, швы и трещины. Один рог с отростками и жемчужинами, второй обломан.
# Морда смотрит вдоль -Z, длина около 27 см. Надпись — дочерний узел "Carving".

const BONE := Color(0.25, 0.215, 0.175)
const DARK := Color(0.015, 0.012, 0.01)
const TOOTH := Color(0.44, 0.39, 0.29)
const WIDTH := [[0.0, 0.012], [0.04, 0.036], [0.12, 0.049], [0.25, 0.052], [0.36, 0.049], [0.43, 0.056], [0.5, 0.045], [0.6, 0.032], [0.75, 0.026], [0.9, 0.02], [0.97, 0.013], [1.0, 0.002]]
const HEIGHT := [[0.0, 0.01], [0.04, 0.033], [0.15, 0.044], [0.3, 0.042], [0.42, 0.034], [0.55, 0.028], [0.75, 0.024], [0.9, 0.018], [1.0, 0.002]]


func _spine(t: float) -> Vector3:
	return Vector3(0.0, 0.014 - 0.03 * pow(t, 1.4), 0.08 - 0.27 * t)


func _feat(t: float, a: float) -> Dictionary:
	var orbit := _g(t, 0.43, 0.052) * (_ga(a, 0.42, 0.4) + _ga(a, PI - 0.42, 0.4))
	var rim := maxf(0.0, _g(t, 0.43, 0.085) * (_ga(a, 0.42, 0.68) + _ga(a, PI - 0.42, 0.68)) - orbit * 1.2)
	var nostril := _g(t, 0.935, 0.028) * (_ga(a, PI * 0.5 - 0.33, 0.2) + _ga(a, PI * 0.5 + 0.33, 0.2))
	var tooth_row := (_ga(a, -0.72, 0.17) + _ga(a, PI + 0.72, 0.17)) * smoothstep(0.52, 0.56, t) * smoothstep(0.82, 0.78, t)
	var tooth := tooth_row * maxf(0.0, sin(t * 150.0))
	var foramen := _g(t, 0.01, 0.025) * _ga(a, -PI * 0.5, 0.45)
	return {"orbit": orbit, "rim": rim, "nostril": nostril, "tooth_row": tooth_row, "tooth": tooth, "foramen": foramen}


func _shape(t: float, a: float) -> float:
	var w: float = _table(WIDTH, t)
	var h: float = _table(HEIGHT, t)
	if sin(a) < 0.0:
		w *= lerpf(1.0, 0.78, -sin(a))
	var r := _se(a, w, h, 2.6)
	var f := _feat(t, a)
	r += -0.02 * float(f["orbit"]) + 0.006 * float(f["rim"])
	r += -0.005 * _g(t, 0.55, 0.03) * (_ga(a, 0.25, 0.25) + _ga(a, PI - 0.25, 0.25))
	r += 0.007 * _g(t, 0.45, 0.07) * (_ga(a, -0.15, 0.3) + _ga(a, PI + 0.15, 0.3))
	r += 0.0025 * _g(t, 0.7, 0.2) * _ga(a, PI * 0.5, 0.18)
	r += 0.002 * _g(t, 0.2, 0.12) * _ga(a, PI * 0.5, 0.15)
	r += -0.007 * float(f["nostril"])
	r += float(f["tooth_row"]) * 0.003 + float(f["tooth"]) * 0.0028
	r += 0.006 * _g(t, 0.02, 0.03) * (_ga(a, -PI * 0.5 + 0.4, 0.3) + _ga(a, -PI * 0.5 - 0.4, 0.3))
	r += -0.004 * float(f["foramen"])
	r += 0.0006 * _noise(t, a, 1.0)
	return maxf(r, 0.0005)


func _color(t: float, a: float) -> Color:
	var f := _feat(t, a)
	var c := BONE * (0.86 + 0.16 * _noise(t, a, 0.7))
	# Затылок в копоти, морда стёрта до светлой кости
	c = c.lerp(Color(0.1, 0.085, 0.07), smoothstep(0.25, 0.0, t) * 0.6)
	c = c.lerp(Color(0.36, 0.31, 0.25), smoothstep(0.55, 0.95, t) * 0.4 * maxf(0.0, sin(a)))
	c = c.lerp(Color(0.38, 0.33, 0.27), float(f["rim"]) * 0.5)
	c = c.lerp(TOOTH, clampf(float(f["tooth"]) * 2.0, 0.0, 1.0))
	# Швы и трещина по темени
	if sin(a) > 0.3 and absf(t - 0.3) < 0.005:
		c = c.darkened(0.6)
	if t > 0.1 and t < 0.36 and absf(wrapf(a - PI * 0.5 - 0.035 * sin(t * 80.0), -PI, PI)) < 0.025:
		c = c.darkened(0.7)
	var hole := clampf(float(f["orbit"]) * 1.6 + float(f["nostril"]) * 1.4 + float(f["foramen"]) * 1.6, 0.0, 1.0)
	return c.lerp(DARK, hole)


func _ready() -> void:
	name = "DeerSkull"
	_rng.seed = 1815
	_gencyl(90, 72, _spine, _shape, _color)
	_flush(_vmat(0.6, 0.0, false, "bone"), true)

	# Пеньки рогов с венчиками из бугорков
	var antler := Color(0.21, 0.175, 0.14)
	for s: float in [-1.0, 1.0]:
		_cy(0.009, 0.012, 0.024, Vector3(0.028 * s, 0.058, 0.004), BONE, Vector3(-18, 0, -22 * s), 14)
		_torus(0.009, 0.016, Vector3(0.034 * s, 0.07, 0.0), antler.darkened(0.25), Vector3(-18, 0, -22 * s), Vector3(1.0, 0.8, 1.0))
		for k in range(9):
			var ang := TAU * k / 9.0
			_bl(Vector3(0.0035, 0.003, 0.0035), Vector3(0.034 * s + cos(ang) * 0.0145, 0.07 + sin(ang) * 0.004, sin(ang) * 0.0145), antler.darkened(0.3))
	# Целый рог: изогнутый ствол с жемчужинами и четырьмя отростками, кончики светлее
	var tip := func(k: float) -> Color: return antler.lerp(Color(0.42, 0.37, 0.3), smoothstep(0.6, 1.0, k))
	var beaded := func(r0: float, r1: float) -> Callable:
		return func(k: float) -> float: return lerpf(r0, r1, k) * (1.0 + 0.13 * sin(k * 55.0) * (1.0 - k))
	var pivot := Vector3(-0.034, 0.07, 0.0)
	_base = Transform3D(Basis.IDENTITY, pivot) * Transform3D(Basis.from_scale(Vector3(0.8, 0.66, 0.8)), Vector3.ZERO) * Transform3D(Basis.IDENTITY, -pivot)
	_tube(_smooth([pivot, Vector3(-0.062, 0.12, 0.026), Vector3(-0.078, 0.19, 0.032), Vector3(-0.072, 0.26, 0.004), Vector3(-0.056, 0.31, -0.03)], 8), beaded.call(0.0108, 0.0026), tip, 14)
	for tine: Array in [
		[Vector3(-0.046, 0.094, 0.012), Vector3(-0.044, 0.118, -0.03), Vector3(-0.038, 0.128, -0.07)],
		[Vector3(-0.077, 0.18, 0.03), Vector3(-0.1, 0.215, 0.006), Vector3(-0.112, 0.24, -0.02)],
		[Vector3(-0.07, 0.258, 0.006), Vector3(-0.088, 0.29, 0.03), Vector3(-0.09, 0.31, 0.05)],
		[Vector3(-0.066, 0.145, 0.03), Vector3(-0.09, 0.16, 0.05), Vector3(-0.1, 0.17, 0.064)],
	]:
		_tube(_smooth(tine, 6), beaded.call(0.0062, 0.0016), tip, 10)
	_base = Transform3D.IDENTITY
	# Второй рог обломан: короткий пенёк и рваный скол
	_tube([Vector3(0.034, 0.07, 0.0), Vector3(0.046, 0.094, 0.01), Vector3(0.054, 0.112, 0.016)], func(k: float) -> float: return lerpf(0.0108, 0.0098, k), antler, 10)
	for k in range(6):
		var ang := TAU * k / 6.0
		_bl(Vector3(0.0035, 0.004 + 0.003 * float(k % 2), 0.0035), Vector3(0.054 + cos(ang) * 0.006, 0.116 + float(k % 3) * 0.002, 0.016 + sin(ang) * 0.006), Color(0.4, 0.35, 0.28))
	_flush(_vmat(0.45, 0.0, false, "antler"), true)

	# Надпись ножом на лбу, между глазницами и рогами
	var carve := Label3D.new()
	carve.name = "Carving"
	carve.text = "ДЖОЗЕФ\nКРЕЙН"
	carve.font_size = 40
	carve.line_spacing = -8.0
	carve.pixel_size = 0.00019
	carve.modulate = Color(0.66, 0.6, 0.5)
	carve.outline_size = 0
	carve.shaded = true
	carve.position = Vector3(0.0, 0.0585, 0.0)
	carve.rotation_degrees = Vector3(-84, 0, 0)
	add_child(carve)
