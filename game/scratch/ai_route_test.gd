extends Node

# Умеет ли монстр обходить стены: ходит между случайными точками настоящей карты.
# Запуск: --path game --headless res://scratch/ai_route_test.tscn -- res://scenes/1level.json 30
var map_path := "res://scenes/1level.json"
var trials := 30
# islands: цель в другом куске навмеша на том же уровне (например, снаружи у окна)
var islands := false

func _nav_len(map: RID, a: Vector3, b: Vector3) -> float:
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total

func _random_inside(map: RID, home: Vector3) -> Vector3:
	for i in range(400):
		var p := NavigationServer3D.map_get_random_point(map, 1, true)
		if _connected(map, home, p):
			return p
	return home

func _connected(map: RID, a: Vector3, b: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	return path.size() >= 2 and path[-1].distance_to(b) < 0.5 and path[0].distance_to(a) < 0.5

# Что мешает монстру идти по маршруту карты: первый отрезок, не прошедший проверку
func _diagnose(e, map: RID, a: Vector3, b: Vector3) -> String:
	e.navigator.refresh_exclusions()
	var path := NavigationServer3D.map_get_path(map, a, b, true)
	var space: PhysicsDirectSpaceState3D = e.get_world_3d().direct_space_state
	for i in range(1, path.size()):
		var p0: Variant = e.navigator.floor_at(path[i - 1])
		var p1: Variant = e.navigator.floor_at(path[i])
		if p1 == null:
			return "seg %d/%d: no floor at (%.1f,%.1f,%.1f)" % [i, path.size(), path[i].x, path[i].y, path[i].z]
		if p0 != null and not e.navigator.segment_clear(p0, p1):
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = e.navigator.shape
			q.transform = Transform3D(Basis.IDENTITY, p0 + Vector3.UP * 1.14)
			q.motion = p1 - p0
			q.collision_mask = 1
			q.exclude = e.navigator.door_excluded
			var frac: PackedFloat32Array = space.cast_motion(q)
			q.transform = Transform3D(Basis.IDENTITY, p0.lerp(p1, clampf(frac[1], 0.0, 1.0)) + Vector3.UP * 1.14)
			q.motion = Vector3.ZERO
			var hits := space.intersect_shape(q, 4)
			var names: Array[String] = []
			for h in hits:
				var c: Object = h.collider
				var label: String = c.name
				if c is Node and c.get_parent():
					label = c.get_parent().name + "/" + c.name
				if c is Node and c.has_meta("prefab_type"):
					label += "[" + str(c.get_meta("prefab_type")) + "]"
				names.append(label)
			var locked := ""
			for h in hits:
				var n: Node = h.collider
				while n and n != e.get_tree().root:
					if n.has_method("is_door_locked"):
						locked = " door locked=%s open=%s" % [n.call("is_door_locked"), n.get("is_open")]
						break
					n = n.get_parent()
			return "seg %d/%d at (%.1f,%.1f) len %.1f frac %.2f hits %s%s" % [i, path.size(), p0.x, p0.z, p0.distance_to(p1), frac[0], str(names), locked]
	return "nav path valid"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		map_path = args[0]
	if args.size() > 1:
		trials = int(args[1])
	if args.size() > 2:
		islands = args[2] == "islands"
	GameManager.intro_cutscene_played = true
	GameManager.active_map_path = map_path
	GameManager.mic_enabled = false
	var main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	for i in range(180):
		await get_tree().physics_frame
	GameManager.is_godmode = true
	GameManager.is_no_ai = false
	var e = GameManager.enemy_ref
	var p = GameManager.player_ref
	if not is_instance_valid(e):
		print("NO ENEMY")
		get_tree().quit()
		return
	p.set_physics_process(false)
	p.global_position += Vector3(0, -300, 0)
	e.set_physics_process(false)
	var map: RID = e.get_world_3d().navigation_map
	var dt := 1.0 / 60.0
	var home: Vector3 = e.global_position
	var ok := 0
	var fail := 0
	var walled := 0
	var walled_ok := 0
	var total_ratio := 0.0
	var total_stuck := 0.0
	var total_pending := 0.0
	var fails: Array[String] = []
	seed(12345)
	for t in range(trials):
		# Только настоящий пол: точки, связанные с местом появления монстра
		var a: Vector3 = _random_inside(map, home)
		var b: Vector3 = _random_inside(map, home)
		var tries := 0
		while a.distance_to(b) < 8.0 and tries < 60:
			b = _random_inside(map, home)
			tries += 1
		if islands:
			for k in range(2000):
				var c := NavigationServer3D.map_get_random_point(map, 1, true)
				if absf(c.y - a.y) < 0.4 and c.distance_to(a) > 6.0 and c.distance_to(a) < 28.0 and not _connected(map, a, c) and e.navigator.floor_at(c) != null and e.navigator.body_clear(c, false):
					b = c
					break
		e.reset_ai()
		e.global_position = a + Vector3.UP * 0.05
		e.velocity = Vector3.ZERO
		await get_tree().physics_frame
		await get_tree().physics_frame
		var ideal := _nav_len(map, a, b)
		var has_wall := ideal > a.distance_to(b) * 1.15
		var limit := ideal / 4.5 * 2.5 + 6.0
		if islands:
			limit = 25.0
		var facing_wall := 0.0
		var time := 0.0
		var stuck := 0.0
		var pend := 0.0
		var walked := 0.0
		var last: Vector3 = e.global_position
		var arrived := false
		e.navigator.clear()
		while time < limit:
			await get_tree().physics_frame
			time += dt
			e.navigator.tick(dt)
			e.world_actions.tick(dt)
			e._desired_speed = 0.0
			e._go(b, 4.5, dt)
			e.velocity.y = -0.5 if e.is_on_floor() else e.velocity.y - 18.0 * dt
			e._try_step(Vector3(e.velocity.x, 0, e.velocity.z) * dt)
			e.move_and_slide()
			if e.navigator.pending:
				pend += dt
			var moved: float = Vector2(e.global_position.x - last.x, e.global_position.z - last.z).length()
			walked += moved
			if moved < 0.004:
				stuck += dt
			last = e.global_position
			var fwd: Vector3 = -e.global_transform.basis.z
			var o: Vector3 = e.global_position + Vector3.UP
			var rh: Dictionary = e.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + fwd * 0.6, 1, [e.get_rid()]))
			if not rh.is_empty() and absf(rh.normal.y) < 0.4 and e._desired_speed > 0.0:
				facing_wall += dt
			if e._flat_dist(e.global_position, b) < 0.8:
				arrived = true
				break
		if has_wall:
			walled += 1
		if arrived:
			ok += 1
			if has_wall:
				walled_ok += 1
			total_ratio += time / maxf(ideal / 4.5, 0.1)
		else:
			fail += 1
			if fails.size() < 12:
				var why: String = _diagnose(e, map, a, b)
				fails.append(why + " || " + "(%.0f,%.0f)->(%.0f,%.0f) ideal %.0fm left %.1fm stuck %.1fs pending %.1fs failed=%s recov=%d" % [a.x, a.z, b.x, b.z, ideal, e._flat_dist(e.global_position, b), stuck, pend, e.navigator.failed, e.navigation_recoveries])
		total_stuck += stuck
		if islands:
			print("ISLAND (%.0f,%.0f)->(%.0f,%.0f) arrived=%s left=%.1f wall=%.1fs stuck=%.1fs pend=%.1fs" % [a.x, a.z, b.x, b.z, arrived, e._flat_dist(e.global_position, b), facing_wall, stuck, pend])
		total_pending += pend
	Engine.time_scale = 1.0
	print("ROUTES %d/%d arrived; through walls %d/%d; slowdown x%.2f of ideal; stuck %.1fs, pending %.1fs per trial" % [ok, trials, walled_ok, walled, total_ratio / maxf(ok, 1), total_stuck / trials, total_pending / trials])
	for f in fails:
		print("FAILED ", f)
	print("ROUTE DONE")
	get_tree().quit()
