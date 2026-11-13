extends "res://scripts/ApartmentKit.gd"

# Лепка живых форм: тело задаётся осью (spine) и сечением вокруг неё.
# shape(t, a) — расстояние от оси до поверхности по направлению a (0 — вправо, PI/2 — вверх),
# color(t, a) — цвет точки. t идёт от 0 до 1 вдоль оси, концы сходятся в точку.
#
# Цвета вершин переводятся в линейные здесь, а у материала vertex_color_is_srgb выключен:
# на встроенной графике AMD перевод в шейдере рвёт очень тёмные поверхности дырами.

static var _lin_mats := {}


func _vmat(rough: float, metal: float = 0.0, two_sided: bool = false, kind: String = "") -> StandardMaterial3D:
	var key := "%.2f_%.2f_%s_%s_%s" % [rough, metal, two_sided, kind, TextureHelper.upgrades_on]
	if _lin_mats.has(key):
		return _lin_mats[key]
	var m := super._vmat(rough, metal, two_sided, kind).duplicate() as StandardMaterial3D
	m.vertex_color_is_srgb = false
	_lin_mats[key] = m
	return m


func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	super._add_tri(st, a, b, c, ca.srgb_to_linear(), cb.srgb_to_linear(), cc.srgb_to_linear())


func _flush(mt: Material, shadows: bool = false) -> MeshInstance3D:
	for part in _parts:
		if not (part[0] is ArrayMesh):
			part[2] = (part[2] as Color).srgb_to_linear()
	return super._flush(mt, shadows)


func _gencyl(nt: int, na: int, spine: Callable, shape: Callable, color: Callable, up_hint: Vector3 = Vector3.UP, flip: bool = false) -> void:
	if _cache_mode == CACHE_READ:
		return
	var grid := []
	var cols := []
	for j in range(nt + 1):
		var t := float(j) / float(nt)
		var c: Vector3 = spine.call(t)
		var d: Vector3 = (spine.call(minf(t + 0.01, 1.0)) as Vector3) - (spine.call(maxf(t - 0.01, 0.0)) as Vector3)
		d = d.normalized()
		var side := d.cross(up_hint).normalized()
		var up := side.cross(d).normalized()
		var pts := PackedVector3Array()
		var row := PackedColorArray()
		for i in range(na + 1):
			var a := TAU * float(i % na) / float(na)
			var r: float = shape.call(t, a)
			pts.append(c + (side * cos(a) + up * sin(a)) * r)
			row.append(color.call(t, a))
		grid.append(pts)
		cols.append(row)
	_emit_grid(grid, cols, false, flip, Transform3D.IDENTITY)


# Точка на той же поверхности: для глаз, ноздрей и всего, что надо посадить точно на кожу
func _gencyl_point(spine: Callable, shape: Callable, t: float, a: float, inset: float = 0.0, up_hint: Vector3 = Vector3.UP) -> Vector3:
	var c: Vector3 = spine.call(t)
	var d: Vector3 = ((spine.call(minf(t + 0.01, 1.0)) as Vector3) - (spine.call(maxf(t - 0.01, 0.0)) as Vector3)).normalized()
	var side := d.cross(up_hint).normalized()
	var up := side.cross(d).normalized()
	var r: float = shape.call(t, a)
	return c + (side * cos(a) + up * sin(a)) * (r - inset)


static func _g(x: float, mu: float, s: float) -> float:
	var k := (x - mu) / s
	return exp(-k * k)


static func _ga(a: float, mu: float, s: float) -> float:
	var k := wrapf(a - mu, -PI, PI) / s
	return exp(-k * k)


# Суперэллипс: n = 2 — эллипс, больше — ближе к скруглённому прямоугольнику
static func _se(a: float, rx: float, ry: float, n: float) -> float:
	var c := absf(cos(a)) / maxf(rx, 0.0001)
	var s := absf(sin(a)) / maxf(ry, 0.0001)
	return 1.0 / pow(pow(c, n) + pow(s, n), 1.0 / n)


static func _noise(t: float, a: float, k: float) -> float:
	return sin(t * 37.0 * k + a * 5.0) * sin(a * 11.0 + t * 13.0 * k) * 0.5 + sin(t * 91.0 * k + a * 17.0) * 0.25
