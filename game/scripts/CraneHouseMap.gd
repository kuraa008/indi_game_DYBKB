extends "res://scripts/ApartmentKit.gd"

# Дом Крейна (главы 4–5): почерневший сруб на лесной поляне, крыша провалилась, окна без стёкол.
# Внутри одна комната: стол с четырьмя тарелками, четыре стула, каменный очаг.
# Снаружи колодец под камнями и десятки оленьих рогов на ветках.
# Координаты совпадают с кат-сценами Jan-ky (CraneHouse.gd). Механик здесь нет:
# для thebekshdet — стул SAM_CHAIR запускает кат-сцену, очаг HEARTH разжигается.

const HEAD := Vector3(-1.3, 0, 0)
const FATHER := Vector3(0.0, 0, 0.78)
const ELDER := Vector3(0.0, 0, -0.78)
const YOUNGER := Vector3(1.3, 0, 0)
const SAM_CHAIR := ELDER
const HEARTH := Vector3(-2.75, 0, 0)
const TABLE_Y := 0.78
const WIN_L := Vector3(0.8, 1.35, -2.5)
const WIN_R := Vector3(-1.2, 1.35, 2.5)
const DOOR := Vector3(3.0, 0, 1.2)
const WELL := Vector3(4.5, 0, -3.2)

const W := 3.0
const D := 2.5
const WALL_H := 2.42
const RIDGE := 3.45
const LOG_R := 0.13
const SPAWN := Vector3(13.0, 0.2, 1.2)
const Trail := preload("res://scripts/ForestTrail.gd")

var _tips: Array = []


func _ready() -> void:
	name = "CraneHouseMap"
	_rng.seed = 1894
	if GameManager and not GameManager.graphics_quality_changed.is_connected(_on_quality_changed):
		GameManager.graphics_quality_changed.connect(_on_quality_changed)
	_build_ground()
	_build_walls()
	_build_roof()
	_build_floor()
	_build_door_and_windows()
	_build_table()
	_build_hearth()
	_build_well()
	_build_dead_trees()
	_build_antlers()
	_build_bounds()
	_details()
	add_child(Trail.new())
	_prepare_start.call_deferred()


func _on_quality_changed(_q: String) -> void:
	_setup_night.call_deferred()


# Лунная ночь: дом и рога должны читаться издалека, а углы комнаты остаются тёмными
func _setup_night() -> void:
	var main := get_parent()
	var moon = main.get("moon_light")
	if moon:
		moon.light_color = Color(0.62, 0.7, 0.92)
		moon.light_energy = 0.75
	var node = main.get("world_env_node")
	if node and node.environment:
		node.environment.ambient_light_color = Color(0.42, 0.5, 0.68)
		node.environment.ambient_light_energy = 1.25
		node.environment.fog_enabled = true
		node.environment.fog_light_color = Color(0.05, 0.075, 0.11)
		node.environment.fog_light_energy = 1.0
		node.environment.fog_density = 0.026


func _prepare_start() -> void:
	await get_tree().physics_frame
	_setup_night()
	var lamp := get_parent().get_node_or_null("door_light")
	if lamp:
		lamp.visible = false
	var player = GameManager.player_ref
	if is_instance_valid(player):
		if "лесная" in GameManager.active_map_path.to_lower():
			# Глава 4: Итан входит в лес с дальнего конца тропы
			player.global_position = Trail.START
			var line: Array = Trail.samples()
			var ahead: Vector2 = line[line.size() - 8] - line[line.size() - 1]
			player.rotation.y = atan2(-ahead.x, -ahead.y)
		else:
			player.global_position = SPAWN
			player.rotation.y = PI * 0.5


func _tex(file: String, uv: float, rough: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = CutsceneKit.tmat(file, Color.WHITE, uv, rough).duplicate()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	return m


func _charred() -> Color:
	return Color(0.27, 0.22, 0.19).darkened(_rng.randf_range(0.0, 0.34)).lightened(_rng.randf_range(0.0, 0.05))


# ── Земля, тропа, трава, лес ──
func _build_ground() -> void:
	var mat := CutsceneKit.tmat("forest_floor.png", Color(0.46, 0.48, 0.4), 0.4)
	CutsceneKit.ground(self, Vector3(90, 0.006, 15), Vector2(380, 300), mat)
	_solid(Vector3(90, -0.5, 15), Vector3(460, 1.0, 360))
	# Вытоптанная тропа от леса к двери
	_bx(Vector3(11.5, 0.012, 1.5), Vector3(9.0, 0.016, 1.2), Color(0.5, 0.45, 0.38), Vector3(0, 2, 0))
	_flush(_tex("dirt_path.png", 0.8, 1.0))

	var avoid := func(x: float, z: float) -> bool:
		return Trail.dist(x, z) < 3.0
	var trees := []
	var tries := 0
	while trees.size() < 170 and tries < 2000:
		tries += 1
		var a := _rng.randf() * TAU
		var r := sqrt(_rng.randf_range(14.5 * 14.5, 46.0 * 46.0))
		var x := cos(a) * r
		var z := sin(a) * r
		if avoid.call(x, z):
			continue
		var h := _rng.randf_range(10.0, 19.0)
		trees.append([Vector3(x, 0, z), Vector3(h * 0.36, h, h * 0.36), _rng.randf() * TAU])
	Trail.spruce_cells(self, trees)

	var tufts: Array[Transform3D] = []
	var made := 0
	while made < 260:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(3.4, 15.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		if absf(p.x) < W + 0.4 and absf(p.z) < D + 0.4:
			continue
		if p.x > 3.0 and absf(p.z - 1.2) < 0.9:
			continue
		tufts.append(_xf(p, Vector3(0, _rng.randf() * 360.0, 0), Vector3.ONE * _rng.randf_range(0.45, 1.05)))
		made += 1
	RoadKit.add_tufts(self, tufts, 26.0)


# ── Стены из брёвен: углы перекрещиваются, проёмы вырезаны ──
func _log_rows(start: float) -> Array:
	var rows := []
	var y := start
	while y < WALL_H:
		rows.append(y)
		y += 0.25
	return rows


func _cut(lo: float, hi: float, holes: Array, y: float) -> Array:
	var parts := [[lo, hi]]
	for h in holes:
		if y <= float(h[2]) or y >= float(h[3]):
			continue
		var next := []
		for c in parts:
			if float(h[0]) > float(c[0]):
				next.append([c[0], minf(c[1], h[0])])
			if float(h[1]) < float(c[1]):
				next.append([maxf(c[0], h[1]), c[1]])
		parts = next
	return parts


func _build_walls() -> void:
	var over := 0.26
	var along_x := {-D: [[WIN_L.x - 0.55, WIN_L.x + 0.55, 0.85, 1.85]], D: [[WIN_R.x - 0.55, WIN_R.x + 0.55, 0.85, 1.85]]}
	for z in along_x.keys():
		for y in _log_rows(LOG_R):
			for c in _cut(-W - over, W + over, along_x[z], y):
				var l: float = float(c[1]) - float(c[0])
				if l > 0.08:
					var r := LOG_R * _rng.randf_range(0.94, 1.05)
					_cy(r, r, l, Vector3((float(c[0]) + float(c[1])) * 0.5, y, z), _charred(), Vector3(0, 0, 90), 9)
	var along_z := {W: [[DOOR.z - 0.5, DOOR.z + 0.5, 0.0, 2.0]], -W: []}
	for x in along_z.keys():
		for y in _log_rows(LOG_R * 2.0):
			for c in _cut(-D - over, D + over, along_z[x], y):
				var l: float = float(c[1]) - float(c[0])
				if l > 0.08:
					var r := LOG_R * _rng.randf_range(0.94, 1.05)
					_cy(r, r, l, Vector3(x, y, (float(c[0]) + float(c[1])) * 0.5), _charred(), Vector3(90, 0, 0), 9)
	# Треугольные фронтоны
	for z in [-D, D]:
		var y := WALL_H + 0.12
		while y < RIDGE:
			var half := W * (1.0 - (y - WALL_H) / (RIDGE - WALL_H))
			var r := LOG_R * 0.9
			# В фронтоне со стороны двери торчат обломанные брёвна
			var ragged := _rng.randf_range(0.0, 0.5) if z > 0.0 else 0.0
			if half - ragged > 0.2:
				_cy(r, r, half * 2.0 - ragged, Vector3(-ragged * 0.5, y, z), _charred(), Vector3(0, 0, 90), 8)
			y += 0.23
	_flush(_tex("board_weathered.png", 1.2, 0.97), true)

	_solid(Vector3(0, 1.3, -D), Vector3(W * 2.0 + 0.4, 2.6, 0.3))
	_solid(Vector3(0, 1.3, D), Vector3(W * 2.0 + 0.4, 2.6, 0.3))
	_solid(Vector3(-W, 1.3, 0), Vector3(0.3, 2.6, D * 2.0 + 0.4))
	var near_side := DOOR.z - 0.5 + D
	_solid(Vector3(W, 1.3, -D + near_side * 0.5), Vector3(0.3, 2.6, near_side))
	var far_side := D - DOOR.z - 0.5
	_solid(Vector3(W, 1.3, D - far_side * 0.5), Vector3(0.3, 2.6, far_side))


# ── Провалившаяся крыша: уцелели края скатов, балки обломаны, посередине дыра в небо ──
func _build_roof() -> void:
	var slope_len := sqrt(pow(W + 0.42, 2.0) + pow(RIDGE - WALL_H + 0.12, 2.0))
	var angle := atan2(RIDGE - WALL_H + 0.12, W + 0.42)
	var deg := rad_to_deg(angle)
	for s in [-1.0, 1.0]:
		var eave := Vector3(s * (W + 0.42), WALL_H + 0.02, 0)
		var dir := Vector3(-s * cos(angle), sin(angle), 0)
		var z := -D - 0.34
		while z < D + 0.34:
			var w := _rng.randf_range(0.16, 0.26)
			# Со стороны очага крыша держится лучше, над дверью почти вся рухнула
			var reach := _rng.randf_range(0.48, 0.72) if s < 0.0 else _rng.randf_range(0.2, 0.42)
			var l := slope_len * reach
			var c := eave + dir * l * 0.5 + Vector3(0, 0.06, z + w * 0.5)
			_bx(Vector3(l, 0.03, w - 0.012), c, _charred().darkened(0.1), Vector3(0, 0, -s * deg + _rng.randf_range(-1.2, 1.2)))
			z += w
	# Балка конька обломана с двух сторон
	for s in [-1.0, 1.0]:
		var l := _rng.randf_range(0.8, 1.15)
		_bx(Vector3(0.16, 0.18, l), Vector3(0, RIDGE + 0.02, s * (D + 0.1 - l * 0.5)), _charred())
	# Стропила: целые, короткие и сорвавшиеся внутрь дома
	var k := 0
	var z := -D
	while z <= D + 0.01:
		for s in [-1.0, 1.0]:
			var reach := 0.55 if s < 0.0 else 0.32
			var bottom := Vector3(s * (W + 0.3), WALL_H + 0.08, z)
			var top := bottom + Vector3(-s * cos(angle), sin(angle), 0) * slope_len * reach
			_pipe(bottom, top + Vector3(0, -0.02, _rng.randf_range(-0.04, 0.04)), 0.058, _charred())
		k += 1
		z += D * 0.5
	# Рухнувшие балки и доски лежат у двери
	# Верхние концы держатся за обломанные стропила, нижние лежат на полу
	_pipe(Vector3(2.25, 2.74, -1.25), Vector3(1.2, 0.07, -1.72), 0.075, _charred())
	_pipe(Vector3(2.25, 2.74, 0.0), Vector3(1.85, 0.08, -0.75), 0.065, _charred())
	_pipe(Vector3(2.25, 2.74, -2.5), Vector3(1.15, 0.07, -2.18), 0.06, _charred())
	for i in range(13):
		var l := _rng.randf_range(0.9, 1.9)
		var p := Vector3(_rng.randf_range(1.15, 2.6), 0.05 + float(i % 4) * 0.035, _rng.randf_range(-2.15, -0.75))
		_bx(Vector3(l, 0.03, _rng.randf_range(0.14, 0.22)), p, _charred(), Vector3(_rng.randf_range(-3.0, 3.0), _rng.randf() * 180.0, _rng.randf_range(-4.0, 4.0)))
	_flush(_tex("board_weathered.png", 1.2, 0.97), true)

	var moon := OmniLight3D.new()
	moon.light_color = Color(0.55, 0.64, 0.86)
	moon.light_energy = 1.5
	moon.omni_range = 7.5
	add_child(moon)
	moon.position = Vector3(0.7, 2.7, 0)


func _build_floor() -> void:
	# Тёмное основание: сквозь щели между досками не видно земли
	_bx(Vector3(W * 2.0 + 0.3, 0.03, D * 2.0 + 0.3), Vector3(0, 0.002, 0), Color(0.02, 0.018, 0.016))
	var z := -D + 0.1
	while z < D - 0.1:
		var w := _rng.randf_range(0.24, 0.32)
		var tone := Color(0.32, 0.28, 0.24).darkened(_rng.randf_range(0.0, 0.28))
		_bx(Vector3(W * 2.0 - 0.2, 0.05, w - 0.014), Vector3(0, 0.0, z + w * 0.5), tone)
		z += w
	# Порог
	_bx(Vector3(0.34, 0.09, 1.12), Vector3(DOOR.x + 0.02, 0.03, DOOR.z), _charred())
	_flush(_tex("board_weathered.png", 0.9, 0.98), true)


func _build_door_and_windows() -> void:
	# Косяки двери и сгнившая дверь на одной петле
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
	# Окна: рамы и гнилые ставни на окне, которое выбьет существо
	for w in [[WIN_L, 1.0], [WIN_R, -1.0]]:
		var c: Vector3 = w[0]
		for s in [-1.0, 1.0]:
			_bx(Vector3(0.09, 1.08, 0.32), c + Vector3(s * 0.57, 0, 0), frame)
			_bx(Vector3(1.22, 0.09, 0.34), c + Vector3(0, s * 0.53, 0), frame)
	for side in [-1.0, 1.0]:
		var hinge: Vector3 = WIN_L + Vector3(side * 0.53, 0, 0.2)
		var board := 0.0
		while board < 0.48:
			var w := _rng.randf_range(0.1, 0.15)
			var h := _rng.randf_range(0.62, 0.96)
			var along: float = board + w * 0.5
			var yaw: float = side * 58.0
			var offs := Vector3(-side * cos(deg_to_rad(yaw)) * along, _rng.randf_range(-0.04, 0.03), side * sin(deg_to_rad(yaw)) * along * side)
			_bx(Vector3(w - 0.01, h, 0.024), hinge + offs, _charred().lightened(0.1), Vector3(0, yaw, _rng.randf_range(-3.0, 3.0)))
			board += w
	_flush(_tex("board_weathered.png", 1.4, 0.97), true)


# ── Стол и четыре стула ──
func _chair(pos: Vector3, yaw: float, word: String) -> void:
	var at := _xf(pos, Vector3(0, yaw, 0))
	_base = at
	var c := Color(0.3, 0.23, 0.17)
	for k in range(4):
		_bx(Vector3(0.105, 0.034, 0.43), Vector3(-0.16 + float(k) * 0.107, 0.46, -0.01), c.darkened(_rng.randf_range(0.0, 0.2)), Vector3(0, _rng.randf_range(-1.5, 1.5), 0))
	for sx in [-0.17, 0.17]:
		_cy(0.026, 0.021, 0.45, Vector3(sx, 0.225, -0.18), c.darkened(0.12), Vector3(-3, 0, sx * 16.0), 7)
		_bx(Vector3(0.055, 1.04, 0.05), Vector3(sx * 1.1, 0.52, 0.2), c.darkened(0.08), Vector3(5, 0, 0))
	for sx in [-0.17, 0.17]:
		_pipe(Vector3(sx, 0.2, -0.17), Vector3(sx * 1.1, 0.2, 0.18), 0.012, c.darkened(0.2))
	_bx(Vector3(0.38, 0.05, 0.026), Vector3(0, 0.63, 0.214), c.darkened(0.12), Vector3(5, 0, 0))
	_bx(Vector3(0.45, 0.16, 0.036), Vector3(0, 0.98, 0.243), c, Vector3(5, 0, 0))
	_base = Transform3D.IDENTITY
	_solid(pos + Vector3(0, 0.5, 0), Vector3(0.42, 1.0, 0.42))
	if word == "":
		return
	var holder := CutsceneKit.node(self, pos, Vector3(0, yaw, 0))
	for q in [[0.2235, 180.0], [0.2655, 0.0]]:
		for layer in [[Color(0.5, 0.39, 0.25), -0.0013, 0.0], [Color(0.06, 0.04, 0.03), 0.0, 0.0008 * (1.0 if q[1] == 0.0 else -1.0)]]:
			var l := CutsceneKit.text3d(holder, word, Vector3(0, 0.98 + layer[1], float(q[0]) + layer[2]), Vector3(-5.0 if q[1] == 0.0 else 5.0, q[1], 0), 0.00085, layer[0], 48)
			l.visibility_range_end = 12.0


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
	_solid(Vector3(0, TABLE_Y * 0.5, 0), Vector3(2.0, TABLE_Y, 1.0))

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

	_chair(HEAD, -90.0, "")
	_chair(FATHER, 0.0, "Отец")
	_chair(ELDER, 180.0, "Старший")
	_chair(YOUNGER, 90.0, "Младший")
	_flush(_tex("wood_furniture.png", 1.5, 0.9), true)


# ── Каменный очаг у дальней стены: топка забита пеплом и костями ──
func _stone(c: Vector3, size: Vector3, soot: float) -> void:
	var col := Color(0.42, 0.4, 0.36).darkened(_rng.randf_range(0.0, 0.26)).lerp(Color(0.05, 0.045, 0.04), soot)
	_softbox(size, _xf(c, Vector3(_rng.randf_range(-1.5, 1.5), _rng.randf_range(-3.0, 3.0), _rng.randf_range(-1.5, 1.5))), col, 0.3, 0.02, 0.18, 4)


func _build_hearth() -> void:
	var face := -2.42
	var open_half := 0.54
	var open_top := 1.02
	var y := 0.13
	var row := 0
	while y < 3.95:
		var half: float = 1.05 if y < 1.42 else 0.64
		var z := -half + (0.0 if row % 2 == 0 else 0.13)
		while z < half - 0.08:
			var w := _rng.randf_range(0.3, 0.46)
			w = minf(w, half - z)
			var mid := z + w * 0.5
			if not (absf(mid) < open_half and y < open_top):
				var near_fire := 1.0 - smoothstep(0.0, 0.95, Vector2(absf(mid) - open_half * 0.6, maxf(y - open_top * 0.6, 0.0)).length())
				_stone(Vector3(face - 0.27, y, mid), Vector3(0.56, 0.2, w - 0.018), near_fire * 0.8)
			z += w
		y += 0.215
		row += 1
	# Каменная арка над топкой, полка-бревно и плита перед очагом
	for k in range(7):
		var a := PI * float(k) / 6.0
		var p := Vector3(face - 0.25, open_top - 0.1 + sin(a) * 0.26, cos(a) * (open_half + 0.05))
		_stone(p, Vector3(0.6, 0.2, 0.2), 0.75)
	for k in range(4):
		_stone(Vector3(face + 0.28, 0.05, -0.75 + float(k) * 0.5), Vector3(0.62, 0.09, 0.48), 0.3)
	_flush(_tex("concrete.png", 1.3, 0.95), true)

	# Тёмная топка
	_bx(Vector3(0.05, 1.04, 1.1), Vector3(face - 0.55, 0.52, 0), Color(0.02, 0.018, 0.016))
	_bx(Vector3(0.56, 0.02, 1.1), Vector3(face - 0.27, 0.03, 0), Color(0.03, 0.028, 0.025))
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.56, 1.04, 0.04), Vector3(face - 0.27, 0.52, s * 0.56), Color(0.025, 0.022, 0.02))
	_bx(Vector3(0.56, 0.04, 1.1), Vector3(face - 0.27, 1.0, 0), Color(0.018, 0.016, 0.014))
	_flush(_vmat(0.98))

	var beam := Color(0.13, 0.1, 0.08)
	_bx(Vector3(0.2, 0.17, 2.3), Vector3(face + 0.03, 1.46, 0), beam)
	_flush(_tex("board_weathered.png", 1.6, 0.96), true)

	# Старый пепел и кости
	var ash := Color(0.36, 0.35, 0.33)
	for k in range(18):
		var p := Vector3(face - 0.25 + _rng.randf_range(-0.18, 0.24), 0.05, _rng.randf_range(-0.44, 0.44))
		_bl(Vector3(_rng.randf_range(0.1, 0.22), _rng.randf_range(0.04, 0.13), _rng.randf_range(0.1, 0.22)), p, ash.darkened(_rng.randf_range(0.0, 0.45)))
	_flush(_vmat(1.0))
	var bone := Color(0.62, 0.58, 0.48)
	for k in range(9):
		var a := Vector3(face - 0.3 + _rng.randf_range(-0.14, 0.26), 0.13 + _rng.randf_range(0.0, 0.1), _rng.randf_range(-0.42, 0.42))
		var ang := _rng.randf() * TAU
		var b := a + Vector3(cos(ang) * 0.2, _rng.randf_range(-0.05, 0.08), sin(ang) * 0.2)
		var col := bone.darkened(_rng.randf_range(0.0, 0.4))
		_pipe(a, b, _rng.randf_range(0.012, 0.022), col)
		_bl(Vector3.ONE * 0.028, a, col)
		_bl(Vector3.ONE * 0.026, b, col)
	_flush(_vmat(0.7))
	_solid(Vector3(face - 0.27, 1.2, 0), Vector3(0.6, 2.4, 2.1))


# ── Старый колодец, заваленный камнями ──
func _build_well() -> void:
	var r := 0.72
	_base = _xf(WELL)
	for course in range(4):
		var n := 13
		for k in range(n):
			if course == 3 and k % 3 == 1:
				continue
			var a := (float(k) + 0.5 * float(course % 2)) * TAU / float(n)
			var rr := r + _rng.randf_range(-0.03, 0.04)
			var size := Vector3(TAU * r / float(n) * _rng.randf_range(0.9, 1.05), _rng.randf_range(0.17, 0.22), _rng.randf_range(0.24, 0.32))
			var col := Color(0.4, 0.38, 0.34).darkened(_rng.randf_range(0.0, 0.35))
			_softbox(size, _xf(Vector3(cos(a) * rr, 0.09 + float(course) * 0.185, sin(a) * rr), Vector3(_rng.randf_range(-5.0, 5.0), rad_to_deg(-a) + 90.0, _rng.randf_range(-5.0, 5.0))), col, 0.32, 0.03, 0.2, 4)
	# Завал: крупные камни сверху и рядом
	for k in range(20):
		var a := _rng.randf() * TAU
		var rr := pow(_rng.randf(), 0.7) * 0.62
		var s := _rng.randf_range(0.22, 0.46)
		var col := Color(0.36, 0.34, 0.31).darkened(_rng.randf_range(0.0, 0.32))
		_softbox(Vector3(s * _rng.randf_range(0.9, 1.5), s * 0.8, s), _xf(Vector3(cos(a) * rr, 0.62 + _rng.randf_range(0.0, 0.42) * (1.0 - rr), sin(a) * rr), Vector3(_rng.randf() * 40.0, _rng.randf() * 360.0, _rng.randf() * 40.0)), col, 0.65, 0.05, 0.22, 5)
	for k in range(6):
		var a := _rng.randf() * TAU
		var s := _rng.randf_range(0.18, 0.34)
		_softbox(Vector3(s * 1.3, s * 0.7, s), _xf(Vector3(cos(a) * 1.2, s * 0.26, sin(a) * 1.2), Vector3(0, _rng.randf() * 360.0, 0)), Color(0.32, 0.3, 0.27), 0.65, 0.05, 0.25, 5)
	_flush(_tex("concrete.png", 1.2, 0.96), true)
	_solid(WELL + Vector3(0, 0.55, 0), Vector3(1.9, 1.1, 1.9))


# ── Голые деревья вокруг поляны: на их ветках висят рога ──
func _build_dead_trees() -> void:
	var spots := [[-8.2, -3.6], [-7.0, 3.8], [-3.6, 7.4], [1.6, 7.0], [7.0, 5.6], [9.8, -2.4], [7.2, -7.6], [1.4, -7.6], [-4.4, -8.0], [-10.6, 1.0], [11.4, 5.4], [-10.0, -8.2]]
	for s in spots:
		var pos := Vector3(s[0], 0, s[1])
		_base = _xf(pos, Vector3(0, _rng.randf() * 360.0, 0))
		_branch(Vector3.ZERO, Vector3(_rng.randf_range(-0.12, 0.12), 1.0, _rng.randf_range(-0.12, 0.12)).normalized(), _rng.randf_range(2.5, 3.3), _rng.randf_range(0.17, 0.25), 4, _base)
		_base = Transform3D.IDENTITY
		_solid(pos + Vector3(0, 1.0, 0), Vector3(0.42, 2.0, 0.42))
	_flush(_vmat(0.96), true)


func _branch(from: Vector3, dir: Vector3, length: float, r: float, depth: int, world: Transform3D) -> void:
	var bend := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.3, 0.3), _rng.randf_range(-1.0, 1.0)) * length * 0.1
	var mid := from + dir * length * 0.5 + bend
	var tip := from + dir * length + bend * 1.6
	var col := Color(0.1, 0.085, 0.075).lightened(_rng.randf_range(0.0, 0.05))
	var radius := func(k: float) -> float: return lerpf(r, r * 0.6, k)
	_tube(_smooth([from, mid, tip], 2), radius, col, 4 + mini(depth, 3), 1.0, Vector3.RIGHT if absf(dir.x) < 0.9 else Vector3.BACK)
	if depth <= 1:
		var world_tip: Vector3 = world * tip
		if world_tip.y > 1.9 and world_tip.y < 5.4:
			_tips.append(world_tip)
	if depth == 0:
		return
	var out := (tip - mid).normalized()
	for k in range(_rng.randi_range(2, 3)):
		var a := _rng.randf() * TAU
		var side := out.cross(Vector3(cos(a), 0.2, sin(a))).normalized()
		var next := (out + side * _rng.randf_range(0.5, 0.95) + Vector3.UP * 0.05).normalized()
		_branch(tip, next, length * _rng.randf_range(0.62, 0.78), r * 0.6, depth - 1, world)


# ── Десятки оленьих рогов, подвешенных на верёвках ──
func _build_antlers() -> void:
	_tips.shuffle()
	var count := mini(_tips.size(), 64)
	var cord := Color(0.3, 0.25, 0.17)
	for i in range(count):
		var tip: Vector3 = _tips[i]
		var hang := _rng.randf_range(0.28, 0.72)
		var p := tip + Vector3(0, -hang, 0)
		_base = Transform3D.IDENTITY
		_pipe(tip, p + Vector3(0, 0.06, 0), 0.0055, cord)
		var flip := 180.0 if _rng.randf() < 0.3 else 0.0
		_base = _xf(p, Vector3(flip + _rng.randf_range(-16.0, 16.0), _rng.randf() * 360.0, _rng.randf_range(-16.0, 16.0)))
		_antler_pair(_rng.randf_range(0.75, 1.2))
	_flush(_vmat(0.62))


func _antler_pair(size: float) -> void:
	var bone := Color(0.6, 0.56, 0.47).darkened(_rng.randf_range(0.0, 0.28))
	var tip_col := bone.lightened(0.18)
	_bl(Vector3(0.065, 0.045, 0.075) * size, Vector3(0, 0.03, 0), bone.darkened(0.2))
	for s in [-1.0, 1.0]:
		var pts := [Vector3(s * 0.04, 0.04, 0), Vector3(s * 0.15, 0.16, 0.05), Vector3(s * 0.24, 0.36, 0.04), Vector3(s * 0.21, 0.58, -0.05), Vector3(s * 0.13, 0.74, -0.03)]
		for k in range(pts.size()):
			pts[k] *= size
		var main_r := func(k: float) -> float: return lerpf(0.021, 0.006, k) * size
		var main_c := func(k: float) -> Color: return bone.lerp(tip_col, k)
		_tube(_smooth(pts, 2), main_r, main_c, 4)
		for q in [[1, Vector3(s * 0.08, 0.09, 0.2)], [2, Vector3(s * 0.15, 0.12, 0.17)], [3, Vector3(s * 0.2, 0.13, 0.08)]]:
			var from: Vector3 = pts[q[0]]
			var to: Vector3 = from + q[1] * size
			var mid: Vector3 = from.lerp(to, 0.55) + Vector3(0, 0.028, 0) * size
			var tine_r := func(k: float) -> float: return lerpf(0.012, 0.0035, k) * size
			_tube([from, mid, to], tine_r, tip_col.darkened(0.08), 4)


# Лес вокруг поляны непроходим, пока нет тропы
func _build_bounds() -> void:
	var n := 28
	var r := 15.6
	for k in range(n):
		var a := TAU * float(k) / float(n)
		# На востоке в кольце проход: сюда приходит тропа
		if absf(wrapf(a, -PI, PI)) < 0.3:
			continue
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(TAU * r / float(n) + 0.8, 8.0, 0.6)
		col.shape = shape
		body.add_child(col)
		add_child(body)
		body.position = Vector3(cos(a) * r, 4.0, sin(a) * r)
		body.rotation.y = -a + PI * 0.5


func _details() -> void:
	for q in [[Vector3(-2.85, 2.25, -2.32), 0.8, Vector3(0, 45, 0)], [Vector3(2.85, 2.2, 2.32), 0.7, Vector3(0, 225, 0)], [Vector3(-2.85, 2.1, 2.32), 0.65, Vector3(0, 135, 0)], [Vector3(WIN_R.x + 0.35, 1.7, 2.33), 0.42, Vector3(0, 180, 0)]]:
		CutsceneKit.cobweb(self, q[0], q[1], q[2])
	CutsceneKit.dust(self, Vector3(0, 1.3, 0), Vector3(2.6, 1.0, 2.0), 70, Color(0.75, 0.8, 0.95, 0.3))
