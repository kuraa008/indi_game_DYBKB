extends Node3D

# Инструменты для вещей в квартире Итана. Кусочки одного материала сливаются
# в один меш: целая группа вещей стоит один вызов отрисовки и почти не влияет на FPS.
# Порядок работы: собрать кусочки (_bx, _cy, _loft, _tube...), затем вызвать _flush(материал).

const FL := 0.01

var _base := Transform3D.IDENTITY
var _parts: Array = []
var _rng := RandomNumberGenerator.new()
var _unit_box := BoxMesh.new()
var _unit_ball := SphereMesh.new()


func _init() -> void:
	_unit_box.size = Vector3.ONE
	_unit_ball.radius = 1.0
	_unit_ball.height = 2.0
	_unit_ball.radial_segments = 10
	_unit_ball.rings = 6


func _xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var r := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	return Transform3D(Basis.from_euler(r) * Basis.from_scale(scl), pos)


func _bx(size: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	if _cache_mode == CACHE_READ:
		return
	_parts.append([_unit_box, _base * _xf(pos, rot, size), col])


func _bl(radii: Vector3, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO) -> void:
	if _cache_mode == CACHE_READ:
		return
	_parts.append([_unit_ball, _base * _xf(pos, rot, radii), col])


func _cy(r_top: float, r_bot: float, h: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, sides: int = 14, top: bool = true) -> void:
	if _cache_mode == CACHE_READ:
		return
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = sides
	m.rings = 1
	m.cap_top = top
	_parts.append([m, _base * _xf(pos, rot), col])


func _torus(inner: float, outer: float, pos: Vector3, col: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> void:
	if _cache_mode == CACHE_READ:
		return
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 18
	m.ring_segments = 8
	_parts.append([m, _base * _xf(pos, rot, scl), col])


# Трубка между двумя точками
func _pipe(a: Vector3, b: Vector3, r: float, col: Color) -> void:
	if _cache_mode == CACHE_READ:
		return
	var d := b - a
	var y := d.normalized()
	var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.BACK).normalized()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = d.length()
	m.radial_segments = 8
	m.rings = 1
	_parts.append([m, _base * Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5), col])


# ── Гладкие формы ──

func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if (b - a).cross(c - a).length_squared() < 1e-16:
		return
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


func _commit(st: SurfaceTool, xf: Transform3D = Transform3D.IDENTITY) -> void:
	if _cache_mode == CACHE_READ:
		return
	st.generate_normals()
	st.index()
	_parts.append([st.commit(), _base * xf, Color.WHITE])


# grid и cols: ряды точек и цветов одинаковой длины; closed замыкает ряд в кольцо
func _emit_grid(grid: Array, cols: Array, closed: bool, flip: bool, xf: Transform3D) -> void:
	if _cache_mode == CACHE_READ:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu: int = grid[0].size()
	var last: int = nu if closed else nu - 1
	for j in range(grid.size() - 1):
		for i in range(last):
			var i2: int = (i + 1) % nu
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i2]
			var c: Vector3 = grid[j + 1][i2]
			var d: Vector3 = grid[j + 1][i]
			var ca: Color = cols[j][i]
			var cb: Color = cols[j][i2]
			var cc: Color = cols[j + 1][i2]
			var cd: Color = cols[j + 1][i]
			if flip:
				_add_tri(st, a, c, b, ca, cc, cb)
				_add_tri(st, a, d, c, ca, cd, cc)
			else:
				_add_tri(st, a, b, c, ca, cb, cc)
				_add_tri(st, a, c, d, ca, cc, cd)
	_commit(st, xf)


func _row(c: Color, n: int) -> PackedColorArray:
	var row := PackedColorArray()
	row.resize(n)
	row.fill(c)
	return row


# Кольцо для _loft: скруглённый прямоугольник на высоте y со сдвигом центра
func _rg(hx: float, hz: float, r: float, y: float, cx: float = 0.0, cz: float = 0.0) -> Array:
	return [hx, hz, r, y, cx, cz]


func _rr_point(hx: float, hz: float, r: float, idx: int, corner: int) -> Vector2:
	var rad := minf(r, minf(hx, hz))
	@warning_ignore("integer_division")
	var q := idx / (corner + 1)
	var k := idx % (corner + 1)
	var a := (float(q) + float(k) / float(corner)) * PI * 0.5
	var sx := 1.0 if q == 0 or q == 3 else -1.0
	var sz := 1.0 if q == 0 or q == 1 else -1.0
	return Vector2(sx * (hx - rad) + cos(a) * rad, sz * (hz - rad) + sin(a) * rad)


# Поверхность по кольцам, как на гончарном круге: снаружи снизу вверх,
# через край и внутрь. Круг — это кольцо с r = hx = hz. colors — цвет каждого кольца.
func _loft(rings: Array, col: Color, xf: Transform3D = Transform3D.IDENTITY, corner: int = 6, colors: Array = []) -> void:
	if _cache_mode == CACHE_READ:
		return
	var around := 4 * (corner + 1)
	var grid := []
	var cols := []
	for j in range(rings.size()):
		var ring: Array = rings[j]
		var pts := PackedVector3Array()
		for i in range(around):
			var p := _rr_point(ring[0], ring[1], ring[2], i, corner)
			pts.append(Vector3(p.x + ring[4], ring[3], p.y + ring[5]))
		grid.append(pts)
		cols.append(_row(colors[j] if j < colors.size() else col, around))
	_emit_grid(grid, cols, true, false, xf)


func _spow(v: float, e: float) -> float:
	return signf(v) * pow(absf(v), e)


# Мягкая подушка: коробка со скруглёнными краями. e — насколько кругло (0.2 почти кубик,
# 0.6 подушка), puff раздувает верх и низ, shade затемняет низ
func _softbox(size: Vector3, xf: Transform3D, col: Color, e: float = 0.28, puff: float = 0.0, shade: float = 0.22, res: int = 18) -> void:
	if _cache_mode == CACHE_READ:
		return
	var half := size * 0.5
	var grid := []
	var cols := []
	for j in range(res + 1):
		var lat := lerpf(-PI * 0.5, PI * 0.5, float(j) / float(res))
		var cl := _spow(cos(lat), e)
		var sy := _spow(sin(lat), e)
		var ring := PackedVector3Array()
		for i in range(res * 2):
			var lon := TAU * float(i) / float(res * 2)
			var x := cl * _spow(cos(lon), e)
			var z := cl * _spow(sin(lon), e)
			var y := sy * (1.0 + puff * (1.0 - x * x) * (1.0 - z * z))
			ring.append(Vector3(x * half.x, y * half.y, z * half.z))
		grid.append(ring)
		cols.append(_row(col.darkened(shade * (0.5 - 0.5 * sy)), res * 2))
	_emit_grid(grid, cols, true, false, xf)


# Плавная линия через точки
func _smooth(points: Array, steps: int = 6) -> Array:
	var out := []
	var n := points.size()
	for k in range(n - 1):
		var p0: Vector3 = points[maxi(k - 1, 0)]
		var p1: Vector3 = points[k]
		var p2: Vector3 = points[k + 1]
		var p3: Vector3 = points[mini(k + 2, n - 1)]
		for s in range(steps):
			out.append(p1.cubic_interpolate(p2, p0, p3, float(s) / float(steps)))
	out.append(points[n - 1])
	return out


# Трубка вдоль линии. radius — число или func(0..1); col — цвет или func(0..1).
# flat сжимает сечение вдоль (направление × hint): так получаются плоские полоски.
func _tube(path: Array, radius: Variant, col: Variant, sides: int = 10, flat: float = 1.0, hint: Vector3 = Vector3.ZERO) -> void:
	if _cache_mode == CACHE_READ:
		return
	var count := path.size()
	var first: Vector3 = (path[1] - path[0]).normalized()
	var nrm: Vector3 = hint
	if hint == Vector3.ZERO:
		nrm = first.cross(Vector3.UP if absf(first.y) < 0.9 else Vector3.RIGHT)
	var grid := []
	var cols := []
	for j in range(count):
		var before: Vector3 = path[maxi(j - 1, 0)]
		var after: Vector3 = path[mini(j + 1, count - 1)]
		var dir := (after - before).normalized()
		nrm = (nrm - dir * nrm.dot(dir)).normalized()
		var side := dir.cross(nrm)
		var k := float(j) / float(count - 1)
		var r: float = radius.call(k) if radius is Callable else float(radius)
		var c: Color = col.call(k) if col is Callable else col
		var ring := PackedVector3Array()
		for i in range(sides):
			var a := TAU * float(i) / float(sides)
			var centre: Vector3 = path[j]
			ring.append(centre + nrm * cos(a) * r + side * sin(a) * r * flat)
		grid.append(ring)
		cols.append(_row(c, sides))
	var head := PackedVector3Array()
	var tail := PackedVector3Array()
	head.resize(sides)
	tail.resize(sides)
	head.fill(path[0])
	tail.fill(path[count - 1])
	grid.push_front(head)
	grid.append(tail)
	cols.push_front(cols[0])
	cols.append(cols[cols.size() - 1])
	_emit_grid(grid, cols, true, true, Transform3D.IDENTITY)


# Сетка nu × nv; fn(i, j) возвращает [точка, цвет]
func _surface(nu: int, nv: int, fn: Callable, xf: Transform3D = Transform3D.IDENTITY) -> void:
	if _cache_mode == CACHE_READ:
		return
	var grid := []
	var cols := []
	for j in range(nv + 1):
		var pts := PackedVector3Array()
		var row := PackedColorArray()
		for i in range(nu + 1):
			var v: Array = fn.call(i, j)
			pts.append(v[0])
			row.append(v[1])
		grid.append(pts)
		cols.append(row)
	_emit_grid(grid, cols, false, false, xf)


# Значение по таблице [[x, y], ...] с плавными переходами
func _table(t: Array, x: float) -> float:
	var n := t.size()
	if x <= float(t[0][0]):
		return t[0][1]
	for k in range(n - 1):
		if x <= float(t[k + 1][0]):
			var p0: float = t[maxi(k - 1, 0)][1]
			var p1: float = t[k][1]
			var p2: float = t[k + 1][1]
			var p3: float = t[mini(k + 2, n - 1)][1]
			var w := (x - float(t[k][0])) / (float(t[k + 1][0]) - float(t[k][0]))
			return cubic_interpolate(p1, p2, p0, p3, w)
	return t[n - 1][1]


# Мятая ткань по силуэту вещи: mask(точка) — внутри ли вещи,
# складки считаются суммой косых волн
func _cloth(xf: Transform3D, mask: Callable, half: Vector2, thick: float, col: Color, cell: float = 0.02) -> void:
	var nx := int(half.x * 2.0 / cell)
	var nz := int(half.y * 2.0 / cell)
	var dirs := []
	for k in range(6):
		var a := _rng.randf() * TAU
		dirs.append([Vector2(cos(a), sin(a)), _rng.randf_range(9.0, 34.0), _rng.randf() * TAU])
	var at := func(i: int, j: int) -> Vector2:
		return Vector2(-half.x + float(i) * cell, -half.y + float(j) * cell)
	var vert := func(i: int, j: int) -> Array:
		var p: Vector2 = at.call(i, j)
		var near := 0.0
		for o in [Vector2(cell, cell), Vector2(-cell, cell), Vector2(cell, -cell), Vector2(-cell, -cell)]:
			near += 0.0833 if mask.call(p + o) else 0.0
			near += 0.0833 if mask.call(p + o * 2.4) else 0.0
			near += 0.0833 if mask.call(p + o * 4.0) else 0.0
		var folds := 0.0
		for d in dirs:
			folds += absf(sin(p.dot(d[0]) * float(d[1]) + float(d[2])))
		folds /= float(dirs.size())
		var f: float = clampf(folds * 1.45 - 0.2, 0.0, 1.0)
		var h: float = thick * (0.3 + 0.7 * f) * (0.08 + 0.92 * near)
		var bump := Vector2(sin(p.y * 13.0 + float(dirs[0][2])), cos(p.x * 11.0 + float(dirs[1][2]))) * 0.008
		return [Vector3(p.x + bump.x, h + 0.001, p.y + bump.y), col.darkened(0.42 * (1.0 - f))]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in range(nz):
		for i in range(nx):
			# Ячейка на краю вещи режется по диагонали, чтобы край не был лесенкой
			var corners := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]
			var kept := []
			for c in corners:
				if mask.call(at.call(c[0], c[1])):
					kept.append(vert.call(c[0], c[1]))
			if kept.size() < 3:
				continue
			var tris: Array = [kept[0], kept[1], kept[2]]
			if kept.size() == 4:
				tris += [kept[0], kept[2], kept[3]]
			for q in tris:
				st.set_color(q[1])
				st.add_vertex(q[0])
	_commit(st, xf)


# Бутылка с крышкой
func _bottle(pos: Vector3, r: float, h: float, col: Color, cap: Color) -> void:
	var at := _xf(pos)
	_loft([
		_rg(r * 0.9, r * 0.9, r * 0.9, 0.0),
		_rg(r, r, r, h * 0.04),
		_rg(r, r, r, h * 0.7),
		_rg(r * 0.84, r * 0.84, r * 0.84, h * 0.79),
		_rg(r * 0.42, r * 0.42, r * 0.42, h * 0.85),
		_rg(r * 0.42, r * 0.42, r * 0.42, h * 0.9),
	], col, at, 3)
	_loft([
		_rg(r * 0.47, r * 0.47, r * 0.47, h * 0.89),
		_rg(r * 0.47, r * 0.47, r * 0.47, h),
		_rg(r * 0.4, r * 0.4, r * 0.4, h * 1.012),
		_rg(0.0, 0.0, 0.0, h * 1.014),
	], cap, at, 3)


# ── Сборка ──

# Математику слияния считают все ядра, поэтому карта строится заметно быстрее.
# Готовые вершины попадают в меши в конце кадра, до первой отрисовки.
static var _pending: Array = []
static var _sync_queued := false

# Кэш готовых мешей на диске. Первая загрузка карты сохраняет их в user://map_cache,
# следующие берут оттуда и не считают геометрию. Новый exe сбрасывает кэш.
# Вместе с игрой идут заранее собранные модели: их создаёт сцена res://tools/BakeMaps.tscn.
# В редакторе кэш выключен, чтобы правки скриптов были видны сразу.
const CACHE_OFF := 0
const CACHE_WRITE := 1
const CACHE_READ := 2
const CACHE_SAVE := 3
const CACHE_DIR := "user://map_cache"
const SHIP_DIR := "res://assets/map_cache"
static var cache_force := false
static var cache_bake := false
static var _cache_shipped := false
static var _cache_bad := ""
static var _cache_mode := CACHE_OFF
static var _cache_data := {}
static var _cache_order := {}
static var _cache_path := ""
static var _cache_missed := false


static func cache_begin(map_key: String) -> void:
	_cache_mode = CACHE_OFF
	_cache_data = {}
	_cache_order = {}
	_cache_missed = false
	_cache_shipped = false
	var file_name := map_key.md5_text()
	if cache_bake:
		DirAccess.make_dir_recursive_absolute(SHIP_DIR)
		_cache_path = "%s/%s.bin" % [SHIP_DIR, file_name]
		_cache_mode = CACHE_WRITE
		return
	if OS.has_feature("editor") and not cache_force:
		return
	var stamp := str(FileAccess.get_modified_time(OS.get_executable_path()))
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var own := "%s/%s_%s.bin" % [CACHE_DIR, stamp, file_name]
	_cache_bad = "%s/%s_%s.bad" % [CACHE_DIR, stamp, file_name]
	var shipped := "%s/%s.bin" % [SHIP_DIR, file_name]
	if FileAccess.file_exists(shipped) and not FileAccess.file_exists(_cache_bad) and _cache_read(shipped):
		_cache_shipped = true
		return
	_cache_path = own
	if FileAccess.file_exists(own) and _cache_read(own):
		return
	for old in DirAccess.get_files_at(CACHE_DIR):
		if not old.begins_with(stamp + "_"):
			DirAccess.remove_absolute(CACHE_DIR + "/" + old)
	_cache_mode = CACHE_WRITE


static func _cache_read(path: String) -> bool:
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var saved: Variant = f.get_var()
	if saved is Dictionary and not (saved as Dictionary).is_empty():
		_cache_data = saved
		_cache_mode = CACHE_READ
		return true
	return false


static func cache_end() -> void:
	if _cache_mode == CACHE_READ:
		_cache_mode = CACHE_OFF
		_cache_data = {}
		# Ход постройки изменился: файл больше не подходит, в следующий раз карта соберётся заново
		if _cache_missed:
			if _cache_shipped:
				FileAccess.open(_cache_bad, FileAccess.WRITE)
			else:
				DirAccess.remove_absolute(_cache_path)
	elif _cache_mode == CACHE_WRITE:
		_cache_mode = CACHE_SAVE if not _pending.is_empty() else CACHE_OFF


func _cache_slot() -> String:
	var path: String = get_script().resource_path
	var n: int = _cache_order.get(path, 0)
	_cache_order[path] = n + 1
	return "%s#%d" % [path, n]


func _flush(mt: Material, shadows: bool = false) -> MeshInstance3D:
	var slot := ""
	if _cache_mode == CACHE_READ or _cache_mode == CACHE_WRITE:
		slot = _cache_slot()
	if _cache_mode == CACHE_READ:
		return _flush_cached(mt, shadows, slot)
	var sources := {}
	var job: Array = []
	for part in _parts:
		var m: Mesh = part[0]
		if not sources.has(m):
			sources[m] = m.surface_get_arrays(0) if m is ArrayMesh else (m as PrimitiveMesh).get_mesh_arrays()
		job.append([sources[m], part[1], part[2], m is ArrayMesh])
	var am := ArrayMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mt
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts.clear()
	_base = Transform3D.IDENTITY
	var data := {"parts": job, "arrays": []}
	_pending.append([WorkerThreadPool.add_task(_merge.bind(data)), data, am, slot])
	if not _sync_queued:
		_sync_queued = true
		_finish_pending.call_deferred()
	return mi


func _flush_cached(mt: Material, shadows: bool, slot: String) -> MeshInstance3D:
	var am := ArrayMesh.new()
	if _cache_data.has(slot):
		var arr: Variant = _cache_data[slot]
		if arr is Array:
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	else:
		_cache_missed = true
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mt
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_parts.clear()
	_base = Transform3D.IDENTITY
	return mi


static func _merge(data: Dictionary) -> void:
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var cs := PackedColorArray()
	var idx := PackedInt32Array()
	for part: Array in data["parts"]:
		var a: Array = part[0]
		var xf: Transform3D = part[1]
		var col: Color = part[2]
		var smooth: bool = part[3]
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var ind: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var nb := xf.basis.inverse().transposed()
		var off := vs.size()
		vs.append_array(xf * v)
		var turned: PackedVector3Array = Transform3D(nb, Vector3.ZERO) * n
		if absf(nb.x.length_squared() - 1.0) > 0.001 or absf(nb.y.length_squared() - 1.0) > 0.001 or absf(nb.z.length_squared() - 1.0) > 0.001:
			for i in range(turned.size()):
				turned[i] = turned[i].normalized()
		ns.append_array(turned)
		if smooth:
			cs.append_array(a[Mesh.ARRAY_COLOR])
		else:
			var tint := PackedColorArray()
			tint.resize(v.size())
			tint.fill(col)
			cs.append_array(tint)
		var shifted := idx.size()
		idx.resize(shifted + ind.size())
		for i in range(ind.size()):
			idx[shifted + i] = ind[i] + off
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = vs
	arr[Mesh.ARRAY_NORMAL] = ns
	arr[Mesh.ARRAY_COLOR] = cs
	arr[Mesh.ARRAY_INDEX] = idx
	data["arrays"] = arr


static func _finish_pending() -> void:
	_sync_queued = false
	for item: Array in _pending:
		WorkerThreadPool.wait_for_task_completion(item[0])
		var arr: Array = item[1]["arrays"]
		var filled: bool = not arr.is_empty() and not (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty()
		if filled:
			(item[2] as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if item[3] != "":
			_cache_data[item[3]] = arr if filled else null
	_pending.clear()
	if _cache_mode == CACHE_SAVE:
		_cache_mode = CACHE_OFF
		var f := FileAccess.open_compressed(_cache_path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		if f:
			f.store_var(_cache_data)
			f.close()
		_cache_data = {}


# kind: "wood", "wood_h", "log", "fabric", "concrete", "plaster", "metal" или "none".
# Без указания: матовое получает лёгкую фактуру, металл — царапины, глянец остаётся гладким.
const SURFACES := {
	"wood": ["wood", 1.0, 1.0, Color(1.2, 1.2, 1.2)],
	"wood_h": ["wood_h", 1.0, 1.0, Color(1.2, 1.2, 1.2)],
	"log": ["wood_log", 0.8, 1.3, Color(1.34, 1.34, 1.34)],
	"fabric": ["fabric", 2.4, 0.9, Color(1.32, 1.32, 1.32)],
	"concrete": ["concrete", 0.4, 1.0, Color(1.22, 1.22, 1.22)],
	"plaster": ["plaster", 0.75, 0.5, Color(1.1, 1.1, 1.1)],
	"soil": ["soil", 0.5, 1.3, Color(1.34, 1.34, 1.34)],
	"metal": ["metal", 1.2, 0.5, Color(1.14, 1.14, 1.14)],
}
static var _vmats := {}


func _vmat(rough: float, metal: float = 0.0, two_sided: bool = false, kind: String = "") -> StandardMaterial3D:
	if not TextureHelper.upgrades_on:
		kind = "none"
	if kind == "":
		if metal >= 0.25:
			kind = "metal"
		elif rough >= 0.45:
			kind = "plaster"
		else:
			kind = "none"
	var key := "%.2f_%.2f_%s_%s" % [rough, metal, two_sided, kind]
	if _vmats.has(key):
		return _vmats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = rough
	m.metallic = metal
	if two_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if SURFACES.has(kind):
		var surface: Array = SURFACES[kind]
		m.albedo_texture = TextureHelper.get_texture(TextureHelper.SURFACE + surface[0] + ".png")
		m.albedo_color = surface[3]
		m.normal_enabled = true
		m.normal_texture = TextureHelper.get_texture(TextureHelper.SURFACE + surface[0] + "_n.png")
		m.normal_scale = surface[2]
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * float(surface[1])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_vmats[key] = m
	return m


func _shader(code: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = code
	return m


# Невидимая преграда в форме коробки
func _solid(centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.position = centre
