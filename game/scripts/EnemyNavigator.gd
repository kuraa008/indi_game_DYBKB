extends RefCounted
## Routes are checked against physics with a capsule wider than the monster.
## Navmesh is the fast path. Incremental A* handles changed furniture/locked doors.

const CELL := 0.5
const STEP := 0.55
const MAX_NODES := 12000
const NEIGHBORS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
var body: CharacterBody3D
var shape := CapsuleShape3D.new()
# Тело монстра тоньше капсулы планирования: для шага вперёд хватает тонкой проверки
var move_shape := CapsuleShape3D.new()
var path := PackedVector3Array()
var cursor := 0
var pending := false
var failed := false
var goal := Vector3.ZERO
var cooldown := 0.0
var excluded: Array[RID] = []
var door_excluded: Array[RID] = []
var frontier: Array = []
var points: Dictionary = {}
var costs: Dictionary = {}
var parents: Dictionary = {}
var closed: Dictionary = {}
var samples: Dictionary = {}
var start_key := Vector3i.ZERO
var search_min := Vector2.ZERO
var search_max := Vector2.ZERO
var attempts := 0
var search_age := 0.0
var best_key := Vector3i.ZERO
var best_distance := INF
var partial := false
var blocked_spots: Array[Dictionary] = []
var door_refresh_timer := 0.0

func _init(actor: CharacterBody3D) -> void:
	body = actor
	shape.radius = 0.31
	shape.height = 1.58
	move_shape.radius = 0.22
	move_shape.height = 1.5

# Карта проходимости состоит из островов: пол дома, улица, верх стен. Через остров не дойти.
func reachable_point(target: Vector3, tolerance: float = 0.9) -> bool:
	var map := body.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return true
	var route := NavigationServer3D.map_get_path(map, body.global_position, target, true)
	# Сетки здесь нет вообще: судить не о чем
	if route.size() < 2:
		return true
	return route[-1].distance_to(target) < tolerance

func clear() -> void:
	path.clear()
	cursor = 0
	pending = false
	failed = false
	partial = false
	cooldown = 0.0

func refresh_exclusions() -> void:
	excluded = [body.get_rid()]
	var player: Variant = GameManager.player_ref
	if is_instance_valid(player) and player is CollisionObject3D:
		excluded.append(player.get_rid())
	door_excluded = excluded.duplicate()
	for door in body.get_tree().get_nodes_in_group("doors"):
		if not is_instance_valid(door) or not door.has_method("open_by_enemy"):
			continue
		if door.has_method("is_door_locked") and door.call("is_door_locked"):
			continue
		# Always exclude doors that can be opened so monster can navigate through doorways freely
		var panel = door.find_child("Panel", true, false)
		if panel is CollisionObject3D:
			door_excluded.append(panel.get_rid())
		if door is CollisionObject3D:
			door_excluded.append(door.get_rid())

func floor_at(pos: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.50, pos - Vector3.UP * 0.70, 1, door_excluded)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or hit.normal.y < 0.50:
		return null
	return Vector3(pos.x, hit.position.y + 0.025, pos.z)

func body_clear(pos: Vector3, planning: bool = true) -> bool:
	if planning:
		for blocked in blocked_spots:
			if pos.distance_to(blocked.position) < 0.32:
				return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 1.14)
	q.collision_mask = 1
	q.exclude = door_excluded
	return body.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func segment_clear(a: Vector3, b: Vector3, planning: bool = true, thin: bool = false) -> bool:
	if planning and not _memory_clear(a, b):
		return false
	if absf(b.y - a.y) > STEP + 0.15 and a.distance_to(b) < 0.8:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = move_shape if thin else shape
	q.transform = Transform3D(Basis.IDENTITY, a + Vector3.UP * 1.14)
	q.motion = b - a
	q.collision_mask = 1
	q.exclude = door_excluded
	var result := body.get_world_3d().direct_space_state.cast_motion(q)
	if result[0] < 0.995 or not (thin or body_clear(b, planning)):
		return false
	# A clear capsule sweep alone would allow shortcuts across pits/stair voids.
	var previous := a
	var count := maxi(1, ceili(a.distance_to(b) / 0.4))
	for i in range(1, count + 1):
		var point: Variant = floor_at(a.lerp(b, float(i) / count))
		if point == null or absf(point.y - previous.y) > STEP + 0.05:
			return false
		previous = point
	return true

func _memory_clear(a: Vector3, b: Vector3) -> bool:
	if a.distance_squared_to(b) < 0.001:
		return true
	for blocked in blocked_spots:
		var along: float = clampf((blocked.position - a).dot(b - a) / a.distance_squared_to(b), 0.0, 1.0)
		if a.lerp(b, along).distance_to(blocked.position) < 0.32:
			return false
	return true

func request(target: Vector3, force_grid: bool = false) -> void:
	refresh_exclusions()
	goal = target
	failed = false
	partial = false
	cooldown = 0.4
	# Цель за стеной на другом острове: идти туда бессмысленно, подходит как можно ближе
	var island_route := _route_to_closest_point(target)
	if not island_route.is_empty():
		var floor_target: Variant = floor_at(target)
		# Цель на том же уровне и недалеко: возможно, туда ведёт дверь, которой нет в навмеше
		if floor_target != null and absf(floor_target.y - body.global_position.y) < 0.6 and body.global_position.distance_to(target) < 32.0 and body_clear(floor_target):
			goal = floor_target
			path.clear()
			cursor = 0
			_begin_search(body.global_position)
			return
		pending = false
		path = island_route
		cursor = 1
		partial = true
		failed = true
		cooldown = 2.0
		return
	var grounded: Variant = _approachable_goal(target)
	# A sound/interaction marker can be inside a wall or over a void.
	# Reject it immediately instead of searching thousands of impossible cells.
	if grounded == null or not body_clear(grounded):
		pending = false
		failed = true
		path.clear()
		cooldown = 3.0
		return
	goal = grounded
	var start := body.global_position
	if not force_grid:
		var candidate := PackedVector3Array()
		if segment_clear(start, goal):
			candidate = PackedVector3Array([start, goal])
		else:
			var map := body.get_world_3d().navigation_map
			if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
				candidate = NavigationServer3D.map_get_path(map, start, goal, true)
				if candidate.size() < 2 or candidate[-1].distance_to(goal) > 0.85:
					candidate.clear()
				elif candidate[-1].distance_to(goal) > 0.05:
					candidate.append(goal)
		if candidate.size() >= 2:
			candidate[0] = start
			var valid := true
			for i in range(1, candidate.size()):
				var p: Variant = floor_at(candidate[i])
				if p == null:
					valid = false
					break
				candidate[i] = p
				if not segment_clear(candidate[i - 1], candidate[i], false, true):
					valid = false
					break
			if valid:
				path = candidate
				cursor = 1
				pending = false
				return
	_begin_search(start)

func _route_to_closest_point(target: Vector3) -> PackedVector3Array:
	var map := body.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return PackedVector3Array()
	var route := NavigationServer3D.map_get_path(map, body.global_position, target, true)
	if route.size() < 2 or route[-1].distance_to(target) < 2.5:
		return PackedVector3Array()
	route[0] = body.global_position
	return route

func _is_furniture_or_door(col: Object) -> bool:
	if not is_instance_valid(col):
		return true
	if col is CollisionObject3D and col.is_in_group("doors"):
		return true
	var curr: Node = col as Node
	var depth := 0
	while is_instance_valid(curr) and depth < 5:
		if curr.is_in_group("doors") or curr.has_method("open_by_enemy") or curr.has_method("is_door_locked"):
			return true
		for meta_key in ["prefab_type", "item_type", "prop_type", "door_type"]:
			if curr.has_meta(meta_key):
				var val := str(curr.get_meta(meta_key)).to_lower()
				if "door" in val or "table" in val or "chair" in val or "desk" in val or "dresser" in val or "nightstand" in val or "bed" in val or "cupboard" in val or "shelf" in val or "sofa" in val or "couch" in val or "counter" in val or "prop_" in val:
					return true
		var n_name := curr.name.to_lower()
		if "door" in n_name or "table" in n_name or "chair" in n_name or "desk" in n_name or "dresser" in n_name or "nightstand" in n_name or "bed" in n_name or "cupboard" in n_name or "shelf" in n_name or "sofa" in n_name or "counter" in n_name:
			return true
		curr = curr.get_parent()
		depth += 1
	return false

func _approachable_goal(target: Vector3) -> Variant:
	var grounded: Variant = floor_at(target)
	if grounded != null and body_clear(grounded):
		return grounded
	var best: Variant = null
	var distance := INF
	for radius in [0.35, 0.6, 0.9, 1.3, 1.8]:
		for i in range(12):
			var angle := TAU * float(i) / 12.0
			var p: Variant = floor_at(target + Vector3(cos(angle), 0, sin(angle)) * radius)
			if p == null or not body_clear(p):
				continue
			var ray := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.2, target + Vector3.UP * 1.2, 1, door_excluded)
			var hit := body.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty():
				var col: Object = hit.collider
				if not _is_furniture_or_door(col):
					continue
			var cost: float = body.global_position.distance_to(p) + radius
			if cost < distance:
				distance = cost
				best = p
		if best != null:
			break
	if best == null and grounded != null:
		best = grounded
	return best

func _key(pos: Vector3) -> Vector3i:
	return Vector3i(roundi(pos.x / CELL), roundi(pos.y / STEP), roundi(pos.z / CELL))

func _begin_search(start: Vector3) -> void:
	frontier.clear()
	points.clear()
	costs.clear()
	parents.clear()
	closed.clear()
	samples.clear()
	attempts = 0
	search_age = 0.0
	start_key = _key(start)
	best_key = start_key
	best_distance = start.distance_to(goal)
	points[start_key] = start
	costs[start_key] = 0.0
	search_min = Vector2(minf(start.x, goal.x), minf(start.z, goal.z)) - Vector2.ONE * 24.0
	search_max = Vector2(maxf(start.x, goal.x), maxf(start.z, goal.z)) + Vector2.ONE * 24.0
	_heap_push(start_key, start.distance_to(goal))
	pending = true

func tick(delta: float) -> void:
	door_refresh_timer -= delta
	if door_refresh_timer <= 0.0:
		door_refresh_timer = 0.25
		refresh_exclusions()
	for i in range(blocked_spots.size() - 1, -1, -1):
		blocked_spots[i].ttl -= delta
		if blocked_spots[i].ttl <= 0.0:
			blocked_spots.remove_at(i)
	cooldown = maxf(0.0, cooldown - delta)
	if not pending:
		return
	search_age += delta
	var deadline := Time.get_ticks_usec() + 2500
	var iterations := 0
	while not frontier.is_empty() and iterations < 96 and Time.get_ticks_usec() < deadline:
		iterations += 1
		var key: Vector3i = _heap_pop()
		if closed.has(key):
			continue
		closed[key] = true
		attempts += 1
		var pos: Vector3 = points[key]
		if pos.distance_to(goal) < best_distance:
			best_key = key
			best_distance = pos.distance_to(goal)
		if pos.distance_to(goal) < 0.80 and segment_clear(pos, goal):
			_finish(key)
			return
		if attempts >= MAX_NODES:
			break
		for offset in NEIGHBORS:
			var sample := Vector3((key.x + offset.x) * CELL, pos.y, (key.z + offset.y) * CELL)
			if sample.x < search_min.x or sample.z < search_min.y or sample.x > search_max.x or sample.z > search_max.y:
				continue
			var sample_key := _key(sample)
			if not samples.has(sample_key):
				var grounded: Variant = floor_at(sample)
				if grounded != null and absf(grounded.y - pos.y) <= STEP + 0.05 and body_clear(grounded):
					samples[sample_key] = grounded
				else:
					samples[sample_key] = null
			var next: Variant = samples[sample_key]
			if next == null:
				continue
			var next_key := _key(next)
			if closed.has(next_key) or not segment_clear(pos, next):
				continue
			var cost: float = costs[key] + pos.distance_to(next)
			if cost >= float(costs.get(next_key, INF)):
				continue
			costs[next_key] = cost
			parents[next_key] = key
			points[next_key] = next
			_heap_push(next_key, cost + next.distance_to(goal))
	if frontier.is_empty() or attempts >= MAX_NODES or search_age >= 3.0:
		pending = false
		path.clear()
		# Chase may approach the closest reachable point; never cross the barrier.
		if points[start_key].distance_to(goal) - best_distance > 1.0:
			_finish(best_key, false)
			partial = true
		failed = true
		cooldown = 3.0

func remember_blocked_motion(direction: Vector3) -> void:
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		return
	blocked_spots.append({"position": body.global_position + direction.normalized() * 0.55, "ttl": 8.0})
	if blocked_spots.size() > 8:
		blocked_spots.pop_front()

func _finish(key: Vector3i, reached_goal: bool = true) -> void:
	var reverse: Array[Vector3] = []
	if reached_goal:
		reverse.append(goal)
	var current := key
	while true:
		reverse.append(points[current])
		if current == start_key:
			break
		current = parents[current]
	reverse.reverse()
	path = PackedVector3Array(reverse)
	cursor = 1
	pending = false
	failed = false

func is_last_point() -> bool:
	return cursor >= path.size() - 1

# Насколько резко поворачивает маршрут после текущей точки: 1 прямо, -1 разворот
func next_turn(direction: Vector3) -> float:
	if cursor + 1 >= path.size():
		return 1.0
	var after := path[cursor + 1] - path[cursor]
	after.y = 0.0
	return direction.dot(after.normalized()) if after.length_squared() > 0.001 else 1.0

func next_point() -> Vector3:
	while cursor < path.size() and body.global_position.distance_to(path[cursor]) < 0.22:
		cursor += 1
	if cursor >= path.size():
		return body.global_position
	# Skip only physically clear segments; never skip a corner through a wall.
	for i in range(mini(cursor + 5, path.size() - 1), cursor, -1):
		if _memory_clear(body.global_position, path[i]) and segment_clear(body.global_position, path[i], false):
			cursor = i
			break
	return path[cursor]

func retreat_clear(target: Vector3) -> bool:
	# Use the actual body here. The planning margin can overlap a wall on contact.
	var floor_point: Variant = floor_at(target)
	if floor_point == null or absf(floor_point.y - body.global_position.y) > 0.12:
		return false
	var motion := Vector3(target.x - body.global_position.x, 0, target.z - body.global_position.z)
	if body.test_move(body.global_transform, motion):
		return false
	var count := maxi(1, ceili(motion.length() / 0.15))
	for i in range(1, count + 1):
		var support: Variant = floor_at(body.global_position + motion * float(i) / count)
		if support == null or absf(support.y - body.global_position.y) > 0.12:
			return false
	return true

func _heap_push(key: Vector3i, priority: float) -> void:
	frontier.append([key, priority])
	var i := frontier.size() - 1
	while i > 0:
		var parent := (i - 1) / 2
		if frontier[parent][1] <= priority:
			break
		frontier[i] = frontier[parent]
		i = parent
	frontier[i] = [key, priority]

func _heap_pop() -> Vector3i:
	var answer: Vector3i = frontier[0][0]
	var tail: Array = frontier.pop_back()
	if frontier.is_empty():
		return answer
	var i := 0
	while i * 2 + 1 < frontier.size():
		var child := i * 2 + 1
		if child + 1 < frontier.size() and frontier[child + 1][1] < frontier[child][1]:
			child += 1
		if tail[1] <= frontier[child][1]:
			break
		frontier[i] = frontier[child]
		i = child
	frontier[i] = tail
	return answer

# Пока ищется путь, не стоять столбом: первая точка пути по навмешу
func quick_step(target: Vector3) -> Variant:
	var map := body.get_world_3d().navigation_map
	if not map.is_valid() or NavigationServer3D.map_get_iteration_id(map) <= 0:
		return null
	var route := NavigationServer3D.map_get_path(map, body.global_position, target, true)
	# Навмеш туда не ведёт: такой шаг упрётся в стену, лучше подождать сетку
	if route.size() < 2 or route[-1].distance_to(target) > 1.5:
		return null
	for p in route:
		if Vector2(p.x - body.global_position.x, p.z - body.global_position.z).length() > 0.35:
			return p
	return null
