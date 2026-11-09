extends "res://scripts/ApartmentKit.gd"

# Лес главы 4: тропа от края двора к поляне с домом Крейна (это один мир с CraneHouseMap).
# Тропы почти не видно, дорогу показывают деревья с тремя засечками (marks).
# На пути ручей, поваленные деревья, ботинок и фонарик Сэма, страница его дневника.
# Механик здесь нет. Для thebekshdet: marks — метки, boot, flashlight и page — находки,
# START — откуда игрок входит в лес.

const POINTS := [
	Vector2(13, 1.2), Vector2(24, 2), Vector2(34, -3), Vector2(46, -6), Vector2(58, 2), Vector2(66, 14), Vector2(78, 22), Vector2(92, 18),
	Vector2(104, 8), Vector2(118, 6), Vector2(130, 16), Vector2(136, 30), Vector2(150, 38), Vector2(166, 34), Vector2(178, 22),
]
const STREAM := [Vector2(118, -44), Vector2(108, -18), Vector2(102, 2), Vector2(99, 13), Vector2(92, 30), Vector2(96, 52), Vector2(88, 80)]
const START := Vector3(177.0, 0.2, 23.0)
const CORRIDOR := 13.0
const MARK_STEP := 24.0

const DIARY := "Папа умер ночью. Я сидел рядом. Под утро из коридора я услышал его голос: «Сэм, сынок, иди ко мне». Я знал, что это не он. Я знал. Но я так хотел, чтобы это был он, что ответил: «Я здесь, пап».\n\nЯ написал Итану на стене. Я спрятал ключ. Теперь оно забирает мой голос. Я чувствую, как он уходит.\n\nЕсли ты нашёл это, Итан, не иди за мной. Сожги его. Не отвечай. Ни мне, ни папе. Никому."

const DIRT_SHADER := """
shader_type spatial;
render_mode depth_draw_never;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { w = VERTEX; }
void fragment() {
	vec2 p = w.xz;
	float big = n(p * 0.9) * 0.6 + n(p * 3.2) * 0.4;
	float fine = n(p * 18.0) * 0.5 + n(p * 46.0) * 0.5;
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * (0.65 + 0.7 * fine);
	ROUGHNESS = 0.97;
	SPECULAR = 0.15;
	ALPHA = COLOR.a * smoothstep(0.34, 0.62, big + COLOR.a * 0.32);
}
"""

const WATER_SHADER := """
shader_type spatial;
render_mode depth_draw_never;
varying vec3 w;
float h(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 v) {
	vec2 i = floor(v), f = fract(v);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { w = VERTEX; }
void fragment() {
	vec2 p = w.xz * 1.6;
	float t = TIME * 0.55;
	float a = n(p + vec2(0.2, t)) + 0.5 * n(p * 2.3 - vec2(t * 0.6, t * 1.4));
	float b = n(p + vec2(0.31, t) + vec2(0.06, 0.0)) + 0.5 * n((p + vec2(0.06, 0.0)) * 2.3 - vec2(t * 0.6, t * 1.4));
	float c = n(p + vec2(0.2, t) + vec2(0.0, 0.06)) + 0.5 * n((p + vec2(0.0, 0.06)) * 2.3 - vec2(t * 0.6, t * 1.4));
	vec3 wn = normalize(vec3((a - b) * 0.55, 1.0, (a - c) * 0.55));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = vec3(0.025, 0.04, 0.05);
	EMISSION = vec3(0.16, 0.21, 0.27) * smoothstep(0.86, 1.22, a);
	ROUGHNESS = 0.08;
	METALLIC = 0.25;
	SPECULAR = 0.8;
	ALPHA = smoothstep(0.0, 0.5, COLOR.a) * 0.93;
}
"""

static var _samples: Array = []
static var _stream_samples: Array = []

var marks: Array = []
var boot := Vector3.ZERO
var flashlight := Vector3.ZERO
var page := Vector3.ZERO
var _colliders: StaticBody3D
var _bark: StandardMaterial3D


static func _line(pts: Array, steps: int) -> Array:
	var out := []
	var n := pts.size()
	for i in range(n - 1):
		var a: Vector2 = pts[maxi(i - 1, 0)]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var d: Vector2 = pts[mini(i + 2, n - 1)]
		for s in range(steps):
			out.append(b.cubic_interpolate(c, a, d, float(s) / float(steps)))
	out.append(pts[n - 1])
	return out


static func samples() -> Array:
	if _samples.is_empty():
		_samples = _line(POINTS, 8)
	return _samples


static func stream_samples() -> Array:
	if _stream_samples.is_empty():
		_stream_samples = _line(STREAM, 8)
	return _stream_samples


static func _min_dist(pts: Array, x: float, z: float) -> float:
	var best := 1e12
	var q := Vector2(x, z)
	for p: Vector2 in pts:
		best = minf(best, p.distance_squared_to(q))
	return sqrt(best)


static func dist(x: float, z: float) -> float:
	return _min_dist(samples(), x, z)


# Ели делятся на участки: подробные ветки видны у каждого дерева рядом с игроком
static func spruce_cells(parent: Node3D, trees: Array) -> void:
	var root := CutsceneKit.node(parent, Vector3.ZERO, Vector3.ZERO, "SpruceCells")
	var cells := {}
	for tree in trees:
		var p: Vector3 = tree[0]
		var big: bool = (tree[1] as Vector3).y > 10.5
		var key := Vector3i(int(floor(p.x / 16.0)), int(floor(p.z / 16.0)), 1 if big else 0)
		if not cells.has(key):
			cells[key] = []
		cells[key].append(tree)
	for key: Vector3i in cells:
		NatureKit.add_spruce_chunk(root, cells[key], key.z == 1, absi(key.x * 7 + key.y * 13) % 3, Color(0.12, 0.3, 0.14), NatureKit.NEAR_END, NatureKit.FAR_END)


func _ready() -> void:
	name = "ForestTrail"
	_rng.seed = 41120
	_bark = CutsceneKit.tmat("board_weathered.png", Color.WHITE, 0.9, 0.98).duplicate()
	_bark.vertex_color_use_as_albedo = true
	_bark.vertex_color_is_srgb = true
	_colliders = StaticBody3D.new()
	_colliders.name = "TrailColliders"
	add_child(_colliders)
	_build_ground_strips()
	_build_stream()
	_build_trees()
	_build_marks()
	_build_fallen()
	_build_scatter()
	_build_finds()
	_build_bounds()


func _collider(pos: Vector3, r: float, h: float) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r
	shape.height = h
	col.shape = shape
	_colliders.add_child(col)
	col.position = pos + Vector3(0, h * 0.5, 0)


func _ribbon(pts: Array, half: float, y: float, col: Color, wobble: float) -> void:
	var count := pts.size()
	var grid := []
	var cols := []
	var alphas := [0.0, 0.85, 1.0, 0.85, 0.0]
	var across := [-1.0, -0.55, 0.0, 0.55, 1.0]
	for j in range(count):
		var before: Vector2 = pts[maxi(j - 1, 0)]
		var after: Vector2 = pts[mini(j + 1, count - 1)]
		var dir := (after - before).normalized()
		var side := Vector2(-dir.y, dir.x)
		var c: Vector2 = pts[j]
		var w := half * (1.0 + wobble * sin(float(j) * 0.7) * sin(float(j) * 0.23 + 1.0))
		var ring := PackedVector3Array()
		var row := PackedColorArray()
		for k in range(5):
			var p: Vector2 = c + side * float(across[k]) * w
			ring.append(Vector3(p.x, y, p.y))
			row.append(Color(col.r, col.g, col.b, alphas[k]))
		grid.append(ring)
		cols.append(row)
	_emit_grid(grid, cols, false, true, Transform3D.IDENTITY)


func _build_ground_strips() -> void:
	_ribbon(samples(), 0.82, 0.018, Color(0.24, 0.19, 0.14), 0.35)
	_flush(_shader(DIRT_SHADER))


func _build_stream() -> void:
	var line := stream_samples()
	_ribbon(line, 2.9, 0.024, Color(0.17, 0.14, 0.11), 0.2)
	_flush(_shader(DIRT_SHADER))
	_ribbon(line, 1.7, 0.03, Color.WHITE, 0.22)
	_flush(_shader(WATER_SHADER))
	# Камни по берегам и в воде, плоские камни-переход на тропе
	for k in range(70):
		var p: Vector2 = line[_rng.randi_range(0, line.size() - 1)]
		var side := Vector2(_rng.randf_range(-2.4, 2.4), _rng.randf_range(-2.4, 2.4))
		var s := pow(_rng.randf(), 2.0) * 0.8 + 0.2
		if dist(p.x + side.x, p.y + side.y) < 1.6:
			continue
		CutsceneKit.rock(self, Vector3(p.x + side.x, 0.02, p.y + side.y), Vector3(s * 1.2, s * 0.7, s), Color(0.3, 0.29, 0.27))
	var cross := Vector2(99.0, 13.0)
	var dir := Vector2(-0.78, 0.62)
	for k in range(5):
		var p := cross + dir * (float(k) - 2.0) * 0.82 + Vector2(_rng.randf_range(-0.1, 0.1), _rng.randf_range(-0.1, 0.1))
		_softbox(Vector3(0.62, 0.11, 0.54), _xf(Vector3(p.x, 0.05, p.y), Vector3(0, _rng.randf() * 180.0, 0)), Color(0.3, 0.29, 0.27).darkened(_rng.randf_range(0.0, 0.2)), 0.65, 0.05, 0.2, 6)
	_flush(_vmat(0.8, 0.0, false, "concrete"))


func _clear_spot(x: float, z: float) -> bool:
	return Vector2(x, z).length() > 14.5 and _min_dist(stream_samples(), x, z) > 3.2


# Ели по обе стороны тропы; те, что рядом с тропой, твёрдые
func _build_trees() -> void:
	var trees := []
	var line := samples()
	var tries := 0
	while trees.size() < 680 and tries < 9000:
		tries += 1
		var c: Vector2 = line[_rng.randi_range(0, line.size() - 1)]
		var off := Vector2(_rng.randf_range(-27.0, 27.0), _rng.randf_range(-27.0, 27.0))
		var x := c.x + off.x
		var z := c.y + off.y
		var d := dist(x, z)
		if d < 3.0 or d > 27.0 or not _clear_spot(x, z):
			continue
		var h := _rng.randf_range(10.0, 20.0)
		var p := Vector3(x, 0, z)
		trees.append([p, Vector3(h * 0.36, h, h * 0.36), _rng.randf() * TAU])
		if d < CORRIDOR + 1.0:
			_collider(p, 0.26, 4.0)
	spruce_cells(self, trees)


func _trunk(pos: Vector3, tall: float, r: float) -> void:
	var col := Color(0.2, 0.16, 0.13)
	_base = _xf(pos)
	var lean := Vector3(_rng.randf_range(-0.2, 0.2), tall, _rng.randf_range(-0.2, 0.2))
	var radius := func(k: float) -> float:
		return lerpf(r, r * 0.3, k) * (1.0 + 0.5 * pow(maxf(0.0, 1.0 - k * 14.0), 2.0))
	var colour := func(k: float) -> Color:
		return col.darkened(0.12 + 0.12 * sin(k * 40.0))
	_tube([Vector3.ZERO, lean * 0.08, lean * 0.3, lean * 0.65, lean], radius, colour, 10, 1.0, Vector3.RIGHT)
	for k in range(9):
		var y := _rng.randf_range(2.2, tall * 0.9)
		var a := _rng.randf() * TAU
		var from := lean * (y / tall)
		var l := _rng.randf_range(0.5, 1.5)
		_pipe(from, from + Vector3(cos(a) * l, _rng.randf_range(-0.25, 0.15), sin(a) * l), 0.018, col.darkened(0.25))
	_base = Transform3D.IDENTITY


# Метка: три косые засечки ножом с той стороны, откуда идёт тропа
func _notches(tree: Vector3, face: Vector3, r: float) -> void:
	_base = _xf(tree, Vector3(0, rad_to_deg(atan2(face.x, face.z)), 0))
	var sap := Color(0.42, 0.32, 0.19)
	var old := Color(0.09, 0.06, 0.04)
	for k in range(3):
		var y := 1.34 + float(k) * 0.17
		var roll := _rng.randf_range(14.0, 22.0)
		var depth := r * 0.985
		_bl(Vector3(0.12, 0.03, 0.016), Vector3(0, y, depth), old, Vector3(0, 0, roll))
		_bl(Vector3(0.1, 0.017, 0.012), Vector3(0, y + 0.006, depth + 0.009), sap.darkened(_rng.randf_range(0.0, 0.25)), Vector3(0, 0, roll))
	_base = Transform3D.IDENTITY


func _build_marks() -> void:
	var line := samples()
	var walked := 0.0
	var next_mark := 18.0
	var side := 1.0
	for i in range(1, line.size()):
		var a: Vector2 = line[i - 1]
		var b: Vector2 = line[i]
		walked += a.distance_to(b)
		if walked < next_mark:
			continue
		next_mark += MARK_STEP
		var dir := (b - a).normalized()
		var normal := Vector2(-dir.y, dir.x) * side
		side = -side
		var spot := b + normal * _rng.randf_range(1.9, 2.4)
		if _min_dist(stream_samples(), spot.x, spot.y) < 3.0:
			continue
		var tree := Vector3(spot.x, 0, spot.y)
		var r := _rng.randf_range(0.2, 0.26)
		var tall := _rng.randf_range(9.0, 12.0)
		_trunk(tree, tall, r)
		_flush(_bark, true)
		var trail_side := Vector3(-normal.x - dir.x * 0.75, 0, -normal.y - dir.y * 0.75).normalized()
		_notches(tree, trail_side, r)
		_flush(_vmat(0.85, 0.0, false, "log"))
		_collider(tree, r + 0.05, 4.0)
		marks.append({"pos": tree, "face": trail_side, "r": r})
	# Страница дневника прибита к последней метке перед поляной
	if marks.size() >= 1:
		_build_page(marks[0])


func _build_page(mark: Dictionary) -> void:
	var tree: Vector3 = mark["pos"]
	var face: Vector3 = mark["face"]
	var depth: float = float(mark["r"]) * 1.2 + 0.012
	page = tree + face * depth + Vector3(0, 0.98, 0)
	var yaw := rad_to_deg(atan2(face.x, face.z))
	var at := _xf(tree, Vector3(0, yaw, 0))
	_base = at
	_bx(Vector3(0.235, 0.32, 0.0016), Vector3(0.0, 0.98, depth), Color(0.74, 0.7, 0.58), Vector3(0, 0, -2.0))
	_flush(_vmat(0.9))
	_base = at
	_cy(0.005, 0.007, 0.012, Vector3(-0.005, 1.125, depth + 0.006), Color(0.3, 0.27, 0.22), Vector3(90, 0, 0), 8)
	_flush(_vmat(0.5, 0.6))
	var holder := CutsceneKit.node(self, tree, Vector3(0, yaw, 0))
	var text := CutsceneKit.text3d(holder, DIARY, Vector3(-0.1, 0.975, depth + 0.0016), Vector3(0, 0, -2.0), 0.0005, Color(0.06, 0.07, 0.14), 26)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.width = 400.0
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.visibility_range_end = 5.0


func _log(a: Vector3, b: Vector3, r: float) -> void:
	var col := Color(0.19, 0.15, 0.12)
	var mid := a.lerp(b, 0.5) + Vector3(0, 0.03, 0)
	var radius := func(k: float) -> float: return lerpf(r, r * 0.55, k) * (0.95 + 0.08 * sin(k * 19.0))
	var colour := func(k: float) -> Color: return col.darkened(0.1 + 0.14 * sin(k * 31.0))
	_tube([a, a.lerp(mid, 0.5), mid, mid.lerp(b, 0.5), b], radius, colour, 11, 1.0, Vector3.UP)
	# Обломанные ветки
	for k in range(9):
		var t := _rng.randf_range(0.15, 0.95)
		var p := a.lerp(b, t) + Vector3(0, r * 0.45, 0)
		var dir := Vector3(_rng.randf_range(-0.9, 0.9), _rng.randf_range(0.25, 1.0), _rng.randf_range(-0.9, 0.9)).normalized()
		_pipe(p, p + dir * _rng.randf_range(0.3, 1.2), 0.03, col.darkened(0.2))


# Вывернутые корни с комьями земли
func _root_plate(at: Vector3, away: Vector3, r: float) -> void:
	var col := Color(0.15, 0.11, 0.08)
	var dirt := Color(0.1, 0.075, 0.05)
	for k in range(18):
		var a := float(k) * TAU / 18.0 + _rng.randf_range(-0.2, 0.2)
		var side := away.cross(Vector3.UP).normalized()
		var spread := side * cos(a) + Vector3.UP * sin(a)
		var far := at + away * _rng.randf_range(0.15, 0.6) + spread * _rng.randf_range(0.9, 1.7) * (r / 0.42)
		far.y = maxf(far.y, 0.05)
		_tube(_smooth([at + spread * r * 0.7, at + away * 0.12 + spread * r * 1.5, far], 3), func(k2: float) -> float: return lerpf(0.09, 0.012, k2), col.darkened(_rng.randf_range(0.0, 0.25)), 5)
	for k in range(14):
		var p := at + away * _rng.randf_range(0.0, 0.3) + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.1, 1.15), _rng.randf_range(-0.6, 0.6))
		_bl(Vector3.ONE * _rng.randf_range(0.14, 0.32), p, dirt.darkened(_rng.randf_range(0.0, 0.3)))


func _log_body(a: Vector3, b: Vector3, r: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(r * 1.8, r * 1.8, a.distance_to(b))
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.position = a.lerp(b, 0.5)
	body.rotation.y = atan2(b.x - a.x, b.z - a.z)


func _build_fallen() -> void:
	# Большое поваленное дерево через ручей — ориентир
	var pairs := [
		[Vector3(107.0, 0.42, -2.0), Vector3(95.0, 0.28, 3.6), 0.44, true],
		[Vector3(146.0, 0.3, 32.5), Vector3(155.0, 0.2, 31.0), 0.3, true],
		[Vector3(60.0, 0.26, 16.0), Vector3(54.0, 0.18, 8.5), 0.26, false],
		[Vector3(34.0, 0.26, 4.5), Vector3(42.0, 0.2, 2.5), 0.25, false],
	]
	for q in pairs:
		_log(q[0], q[1], q[2])
		if q[3]:
			var away: Vector3 = (Vector3(q[0]) - Vector3(q[1])).normalized()
			_root_plate(q[0], away, q[2])
	_flush(_bark, true)
	_base = Transform3D.IDENTITY
	for q in pairs:
		_log_body(q[0], q[1], q[2])
	# Большой мшистый камень рядом с тропой, второй ориентир
	CutsceneKit.rock(self, Vector3(124.0, 0.0, 1.5), Vector3(3.2, 2.0, 2.6), Color(0.27, 0.27, 0.24))
	CutsceneKit.rock(self, Vector3(72.0, 0.0, 25.5), Vector3(2.4, 1.5, 2.0), Color(0.26, 0.26, 0.23))
	_collider(Vector3(124.0, 0.0, 1.5), 1.3, 2.0)
	_collider(Vector3(72.0, 0.0, 25.5), 1.0, 1.5)


func _build_scatter() -> void:
	var line := samples()
	var tufts: Array[Transform3D] = []
	var made := 0
	var tries := 0
	while made < 1100 and tries < 5000:
		tries += 1
		var c: Vector2 = line[_rng.randi_range(0, line.size() - 1)]
		var x := c.x + _rng.randf_range(-11.0, 11.0)
		var z := c.y + _rng.randf_range(-11.0, 11.0)
		var d := dist(x, z)
		if d < 1.05 or _min_dist(stream_samples(), x, z) < 2.0 or Vector2(x, z).length() < 15.0:
			continue
		tufts.append(_xf(Vector3(x, 0, z), Vector3(0, _rng.randf() * 360.0, 0), Vector3.ONE * _rng.randf_range(0.45, 1.15)))
		made += 1
	RoadKit.add_tufts(self, tufts, 30.0)

	var placed := 0
	tries = 0
	while placed < 46 and tries < 800:
		tries += 1
		var c: Vector2 = line[_rng.randi_range(0, line.size() - 1)]
		var x := c.x + _rng.randf_range(-13.0, 13.0)
		var z := c.y + _rng.randf_range(-13.0, 13.0)
		if dist(x, z) < 2.0 or not _clear_spot(x, z):
			continue
		placed += 1
		var kind := placed % 3
		var at := Vector3(x, 0, z)
		if kind == 0:
			var s := pow(_rng.randf(), 2.0) * 1.0 + 0.3
			CutsceneKit.rock(self, at, Vector3(s * 1.3, s * 0.8, s), Color(0.29, 0.28, 0.25))
		elif kind == 1:
			CutsceneKit.bush(self, at, Vector3.ONE * _rng.randf_range(0.8, 1.5))
		else:
			_stump(at)
	_flush(_bark, true)
	# Сухие ветки на земле
	for k in range(120):
		var c: Vector2 = line[_rng.randi_range(0, line.size() - 1)]
		var p := Vector3(c.x + _rng.randf_range(-9.0, 9.0), 0.03, c.y + _rng.randf_range(-9.0, 9.0))
		var a := _rng.randf() * TAU
		var l := _rng.randf_range(0.4, 1.5)
		_pipe(p, p + Vector3(cos(a) * l, 0.02, sin(a) * l), _rng.randf_range(0.012, 0.03), Color(0.14, 0.11, 0.08))
	_flush(_vmat(0.96, 0.0, false, "log"))


func _stump(at: Vector3) -> void:
	var r := _rng.randf_range(0.2, 0.36)
	var h := _rng.randf_range(0.35, 0.8)
	_cy(r * 0.9, r * 1.2, h, at + Vector3(0, h * 0.5, 0), Color(0.18, 0.14, 0.11), Vector3(_rng.randf_range(-3.0, 3.0), 0, _rng.randf_range(-3.0, 3.0)), 10)
	_cy(r * 0.82, r * 0.82, 0.01, at + Vector3(0, h + 0.003, 0), Color(0.42, 0.34, 0.24), Vector3.ZERO, 10)
	_collider(at, r, h)


# ── Находки: ботинок Сэма у ручья и его разбитый фонарик в траве ──
func _build_finds() -> void:
	boot = Vector3(96.2, 0.05, 15.9)
	_base = _xf(boot + Vector3(0, 0.03, 0), Vector3(4, 62, 78))
	var leather := Color(0.34, 0.22, 0.13)
	var mud := Color(0.09, 0.07, 0.05)
	_bx(Vector3(0.1, 0.024, 0.29), Vector3(0, 0.012, 0), Color(0.05, 0.04, 0.035))
	_bl(Vector3(0.052, 0.052, 0.1), Vector3(0, 0.055, -0.07), leather)
	_cy(0.046, 0.053, 0.15, Vector3(0, 0.1, 0.07), leather, Vector3(-6, 0, 0), 12)
	_torus(0.04, 0.052, Vector3(0, 0.175, 0.08), leather.darkened(0.2), Vector3(-6, 0, 0), Vector3(1, 0.5, 1))
	for k in range(4):
		_bx(Vector3(0.056, 0.003, 0.006), Vector3(0, 0.1 + float(k) * 0.019, 0.005 - float(k) * 0.02), Color(0.42, 0.36, 0.26), Vector3(-35, 0, 0))
	for k in range(9):
		_bl(Vector3.ONE * _rng.randf_range(0.012, 0.03), Vector3(_rng.randf_range(-0.05, 0.05), 0.02, _rng.randf_range(-0.14, 0.14)), mud)
	_flush(_vmat(0.82))

	var i := samples().size() - 1
	var near: Vector2 = samples()[int(i * 0.34)]
	flashlight = Vector3(near.x + 1.2, 0.045, near.y - 1.0)
	_base = _xf(flashlight, Vector3(90, 37, 4))
	var body := Color(0.12, 0.13, 0.15)
	var metal := Color(0.5, 0.5, 0.52)
	_cy(0.021, 0.021, 0.16, Vector3(0, -0.02, 0), body, Vector3.ZERO, 12)
	_cy(0.036, 0.024, 0.055, Vector3(0, 0.082, 0), body, Vector3.ZERO, 14)
	_torus(0.03, 0.037, Vector3(0, 0.11, 0), metal, Vector3.ZERO, Vector3(1, 0.6, 1))
	_bx(Vector3(0.012, 0.03, 0.006), Vector3(0.022, 0.0, 0), Color(0.44, 0.1, 0.08))
	_flush(_vmat(0.4, 0.5))
	# Разбитое стекло и выпавшая батарейка
	_base = _xf(flashlight)
	for k in range(7):
		_bx(Vector3(_rng.randf_range(0.01, 0.028), 0.0015, _rng.randf_range(0.008, 0.024)), Vector3(_rng.randf_range(-0.06, 0.12), -0.03, _rng.randf_range(-0.08, 0.08)), Color(0.6, 0.66, 0.7), Vector3(0, _rng.randf() * 180.0, 0))
	_flush(_vmat(0.1))
	_base = _xf(flashlight + Vector3(-0.2, -0.025, 0.13), Vector3(0, 24, 90))
	_cy(0.016, 0.016, 0.06, Vector3.ZERO, Color(0.55, 0.45, 0.14), Vector3.ZERO, 10)
	_flush(_vmat(0.35, 0.4))


# Лес по бокам тропы непроходим; у поляны стены заходят внутрь её кольца
func _build_bounds() -> void:
	var line := samples()
	for s in [-1.0, 1.0]:
		var i := 0
		while i < line.size() - 1:
			var a: Vector2 = line[i]
			var b: Vector2 = line[mini(i + 2, line.size() - 1)]
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x) * float(s) * CORRIDOR
			var mid := (a + b) * 0.5 + side
			i += 2
			if mid.length() < 15.2:
				continue
			_wall(Vector3(mid.x, 4.0, mid.y), a.distance_to(b) + 5.0, atan2(dir.x, dir.y))
	var end: Vector2 = line[line.size() - 1]
	var last: Vector2 = line[line.size() - 3]
	var dir := (end - last).normalized()
	_wall(Vector3(end.x + dir.x * 3.0, 4.0, end.y + dir.y * 3.0), CORRIDOR * 2.0 + 6.0, atan2(dir.y, -dir.x))


func _wall(pos: Vector3, length: float, yaw: float) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 8.0, length)
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.position = pos
	body.rotation.y = yaw
