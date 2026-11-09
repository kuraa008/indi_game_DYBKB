extends Node

# Замеры поведения монстра с ботом-игроком на настоящей карте.
# Запуск: --path game --headless res://scratch/ai_metrics.tscn -- res://scenes/1level.json 180
var map_path := "res://scenes/1level.json"
var game_seconds := 180.0
var bot_goal := Vector3.ZERO
var bot_hold := 0.0
var noise_timer := 0.0
var flee_goal := Vector3.ZERO
var flee_stamina := 5.0
var bot_exhausted := false
var was_chased := false
var caught_now := false
var reach_hold := 0.0
var flee_replan := 0.0
var chase_start_t := 0.0
var chase_start_d := 0.0
var bot_moved := 0.0
var catch_log: Array[String] = []
var trace_rows := []
var stall_causes := {}
var wall_time := {}
var wall_pts := []
var face_wall := {}
var face_pts := []
var doors_closed := 0
var chases := 0
var escapes := 0

# Достижимая точка подальше от монстра
func _far_point(map: RID, from: Vector3, enemy_pos: Vector3) -> Vector3:
	var best := from
	var best_score := -INF
	for i in range(40):
		var c := NavigationServer3D.map_get_random_point(map, 1, true)
		var route := NavigationServer3D.map_get_path(map, from, c, true)
		if route.size() < 2 or route[-1].distance_to(c) > 0.5:
			continue
		# Живой игрок не побежит сквозь монстра: путь не должен проходить рядом с ним
		var passes_enemy := false
		for k in range(1, route.size()):
			if route[k].distance_to(enemy_pos) < 4.0 and route[k].distance_to(from) > 1.0:
				passes_enemy = true
				break
		if passes_enemy:
			continue
		var score: float = c.distance_to(enemy_pos) - c.distance_to(from) * 0.4
		# Человек не побежит мимо монстра: первый шаг должен уводить от него
		var step_i := mini(1, route.size() - 1)
		var first: Vector3 = (route[step_i] - from).normalized()
		var away: Vector3 = (from - enemy_pos).normalized()
		score += first.dot(away) * 25.0
		if score > best_score:
			best_score = score
			best = c
	return best

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		map_path = args[0]
	if args.size() > 1:
		game_seconds = float(args[1])
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
	GameManager.mic_enabled = false
	var e = GameManager.enemy_ref
	var p = GameManager.player_ref
	if not is_instance_valid(e):
		print("NO ENEMY")
		get_tree().quit()
		return
	p.set_physics_process(false)
	var map: RID = p.get_world_3d().navigation_map
	var dt := 1.0 / 60.0
	var total := int(game_seconds * 60.0)
	var state_time := {}
	var still_wanting := 0.0        # хочет идти, но стоит
	var pending_time := 0.0
	var hunt_time := 0.0
	var hunt_dist := 0.0
	var hunt_max_speed := 0.0
	var move_time := 0.0
	var move_dist := 0.0
	var encounters := 0
	var catches := 0
	var saw_now := false
	var first_contact := -1.0
	var near_time := 0.0
	var dist_sum := 0.0
	var long_stalls := 0
	var stall_run := 0.0
	var transitions := 0
	var last_state := -1
	var last_pos: Vector3 = e.global_position
	var flips := 0
	var last_dir := Vector3.ZERO
	var trace: Array[String] = []
	for i in range(total):
		await get_tree().physics_frame
		# Обычный игрок: заметив погоню, бежит подальше, пока хватает дыхания
		var chased: bool = e.state in [e.State.HUNT, e.State.RAGE, e.State.DASH]
		if chased and not was_chased:
			chases += 1
			chase_start_t = i * dt
			chase_start_d = e.global_position.distance_to(p.global_position)
			bot_moved = 0.0
			flee_goal = _far_point(map, p.global_position, e.global_position)
			flee_stamina = maxf(flee_stamina, 0.0)
		if was_chased and not chased and not caught_now:
			escapes += 1
		was_chased = chased
		caught_now = false
		var bot_before: Vector3 = p.global_position
		if chased:
			if flee_stamina > 0.0 and not bot_exhausted:
				flee_stamina = maxf(0.0, flee_stamina - dt)
				if flee_stamina <= 0.0:
					bot_exhausted = true
			else:
				flee_stamina = minf(5.0, flee_stamina + dt * 0.8)
				if flee_stamina > 1.5:
					bot_exhausted = false
			var sprinting: bool = flee_stamina > 0.0 and not bot_exhausted
			var run_speed := 6.2 if sprinting else 4.2
			p.set("is_sprinting", sprinting)
			var to_flee: Vector3 = (flee_goal - p.global_position).normalized()
			var to_enemy: Vector3 = (e.global_position - p.global_position).normalized()
			var blocked: bool = to_flee.dot(to_enemy) > 0.6 and e.global_position.distance_to(p.global_position) < 7.0
			flee_replan -= dt
			if flee_goal.distance_to(p.global_position) < 1.0 or (blocked and flee_replan <= 0.0):
				flee_replan = 1.5
				flee_goal = _far_point(map, p.global_position, e.global_position)
			var fpath := NavigationServer3D.map_get_path(map, p.global_position, flee_goal, true)
			for fpt in fpath:
				if fpt.distance_to(p.global_position) > 0.4:
					p.global_position += (fpt - p.global_position).normalized() * run_speed * dt
					break
			noise_timer -= dt
			if noise_timer <= 0.0:
				noise_timer = 0.4
				GameManager.emit_noise(p.global_position, 26.0 if flee_stamina > 0.0 else 12.0, "footstep")
		elif bot_hold > 0.0:
			flee_stamina = minf(5.0, flee_stamina + dt)
			p.set("is_sprinting", false)
			bot_hold -= dt
		else:
			p.set("is_sprinting", false)
			var to_goal: Vector3 = bot_goal - p.global_position
			to_goal.y = 0.0
			if bot_goal == Vector3.ZERO or to_goal.length() < 0.5:
				for t_i in range(300):
					bot_goal = NavigationServer3D.map_get_random_point(map, 1, true)
					var check := NavigationServer3D.map_get_path(map, p.global_position, bot_goal, true)
					if check.size() >= 2 and check[-1].distance_to(bot_goal) < 0.5:
						break
				bot_hold = randf_range(1.0, 5.0)
			else:
				var path := NavigationServer3D.map_get_path(map, p.global_position, bot_goal, true)
				var step_to: Vector3 = bot_goal
				for pt in path:
					if pt.distance_to(p.global_position) > 0.4:
						step_to = pt
						break
				var d: Vector3 = (step_to - p.global_position)
				if d.length() > 0.01:
					p.global_position += d.normalized() * 3.2 * dt
				noise_timer -= dt
				if noise_timer <= 0.0:
					noise_timer = 0.5
					GameManager.emit_noise(p.global_position, 8.0, "footstep")
		bot_moved += Vector2(p.global_position.x - bot_before.x, p.global_position.z - bot_before.z).length()
		var key: String = e.State.keys()[e.state]
		state_time[key] = float(state_time.get(key, 0.0)) + dt
		if int(e.state) != last_state:
			last_state = int(e.state)
			transitions += 1
			if trace.size() < 60:
				trace.append("%.0f:%s" % [i * dt, key])
		var moved: float = Vector2(e.global_position.x - last_pos.x, e.global_position.z - last_pos.z).length()
		var dir: Vector3 = (e.global_position - last_pos)
		dir.y = 0.0
		if moved > 0.005 and last_dir != Vector3.ZERO and dir.normalized().dot(last_dir) < -0.5:
			flips += 1
		if moved > 0.005:
			last_dir = dir.normalized()
		last_pos = e.global_position
		var wants: bool = e._desired_speed > 0.0
		if e.navigator.pending:
			pending_time += dt
		if wants:
			move_time += dt
			move_dist += moved
			if moved < 0.004:
				still_wanting += dt
				var cause := "move"
				if e._retreat_time > 0.0: cause = "retreat"
				elif e.navigator.pending and e.navigator.path.is_empty(): cause = "pending"
				elif e.navigator.failed: cause = "failed"
				elif e.navigator.path.is_empty(): cause = "nopath"
				elif false: cause = "blocked"
				elif e.is_blinded_by_light: cause = "blind"
				var ck: String = key + "/" + cause
				stall_causes[ck] = float(stall_causes.get(ck, 0.0)) + dt
				stall_run += dt
				if stall_run > 1.0 and stall_run - dt <= 1.0:
					long_stalls += 1
			else:
				stall_run = 0.0
		if e.state == e.State.HUNT:
			hunt_time += dt
			hunt_dist += moved
			hunt_max_speed = maxf(hunt_max_speed, moved / dt)
		var sees: bool = e._visible
		if sees and not saw_now:
			encounters += 1
			if first_contact < 0.0:
				first_contact = i * dt
		saw_now = sees
		var dist: float = e.global_position.distance_to(p.global_position)
		# Поймал: игрок «возрождается» подальше, замер идёт дальше
		# Как в игре: поймать можно, только удержав игрока рядом CATCH_HOLD секунд
		if dist < e.catch_distance and e.state not in [e.State.DASH, e.State.LURK] and i * dt >= e.START_GRACE:
			reach_hold += dt
		else:
			reach_hold = maxf(0.0, reach_hold - dt)
		if reach_hold >= e.CATCH_HOLD:
			reach_hold = 0.0
			catches += 1
			caught_now = true
			catch_log.append("t=%.0f state=%s chased=%s after %.1fs start_d=%.1f bot_ran=%.1fm stamina=%.1f" % [i * dt, e.State.keys()[e.state], chased, i * dt - chase_start_t, chase_start_d, bot_moved, flee_stamina])
			for t_i in range(300):
				var respawn := NavigationServer3D.map_get_random_point(map, 1, true)
				var check := NavigationServer3D.map_get_path(map, p.global_position, respawn, true)
				if check.size() >= 2 and check[-1].distance_to(respawn) < 0.5 and respawn.distance_to(e.global_position) > 18.0:
					p.global_position = respawn
					break
			bot_goal = Vector3.ZERO
			e.reset_ai()
		dist_sum += dist
		# Как живой игрок: закрывает за собой двери
		if i % 240 == 0 and OS.get_environment("AI_CLOSE_DOORS") != "":
			for d in get_tree().get_nodes_in_group("doors"):
				if d is Node3D and d.get("is_open") == true and d.get("is_animating") != true and d.has_method("_toggle_simple_door") and d.global_position.distance_to(e.global_position) > 3.0 and d.global_position.distance_to(p.global_position) < 6.0:
					d.call("_toggle_simple_door", p)
					doors_closed += 1
		# Упирается в стену: есть касание стены, а скорость сильно меньше желаемой
		var wall_hit := false
		for k in range(e.get_slide_collision_count()):
			var col: KinematicCollision3D = e.get_slide_collision(k)
			if absf(col.get_normal().y) < 0.4 and not (col.get_collider() is CharacterBody3D):
				var into: float = -Vector2(e.velocity.x, e.velocity.z).normalized().dot(Vector2(col.get_normal().x, col.get_normal().z))
				if into > 0.5:
					wall_hit = true
		# Стена прямо перед носом, пока хочет идти: бежит на стену
		if wants:
			var fwd: Vector3 = -e.global_transform.basis.z
			var o: Vector3 = e.global_position + Vector3.UP * 1.0
			var rq := PhysicsRayQueryParameters3D.create(o, o + fwd * 0.75, 1, [e.get_rid(), p.get_rid()])
			var rh: Dictionary = e.get_world_3d().direct_space_state.intersect_ray(rq)
			if not rh.is_empty() and absf(rh.normal.y) < 0.4:
				var fk: String = key + ("/partial" if e.navigator.partial else ("/failed" if e.navigator.failed else "/ok")) + ("/stopped" if moved < 0.01 else "/moving")
				face_wall[fk] = float(face_wall.get(fk, 0.0)) + dt
				if i % 10 == 0 and face_pts.size() < 30:
					face_pts.append("%s (%.1f,%.1f) tgt(%.1f,%.1f) d=%.1f" % [fk, e.global_position.x, e.global_position.z, e.last_nav_target.x, e.last_nav_target.z, e._flat_dist(e.global_position, e.last_nav_target)])
		if wall_hit and wants:
			var why := "normal"
			if e.navigator.pending and e.navigator.path.is_empty(): why = "quick"
			elif false: why = "side"
			elif e._retreat_time > 0.0: why = "retreat"
			var wk: String = key + "/" + why
			wall_time[wk] = float(wall_time.get(wk, 0.0)) + dt
			if i % 20 == 0:
				wall_pts.append([snappedf(e.global_position.x, 0.1), snappedf(e.global_position.z, 0.1), key, why])
		if chased and i % 30 == 0 and OS.get_environment("AI_CHASELOG") != "":
			print("CL t=%.1f d=%.1f mon=%.1f bot=%.1f st=%.1f ex=%s vis=%s path=%d" % [i * dt, dist, moved / dt, Vector2(p.global_position.x - bot_before.x, p.global_position.z - bot_before.z).length() / dt, flee_stamina, bot_exhausted, e._visible, e.navigator.path.size()])
		# Траектория для рисунка: где был монстр, в каком состоянии, стоял ли
		if i % 15 == 0:
			trace_rows.append([snappedf(e.global_position.x, 0.01), snappedf(e.global_position.z, 0.01), int(e.state), 1 if (wants and moved < 0.004) else 0, snappedf(p.global_position.x, 0.01), snappedf(p.global_position.z, 0.01), 1 if e._visible else 0])
		if dist < 12.0:
			near_time += dt
	Engine.time_scale = 1.0
	print("== METRICS ", map_path, " ", game_seconds, "s")
	var pct := func(v: float) -> String: return "%.0f%%" % (100.0 * v / game_seconds)
	var parts: Array[String] = []
	for k in state_time:
		parts.append("%s %s" % [k, pct.call(state_time[k])])
	print("STATES ", ", ".join(parts))
	print("CASUAL chases %d, escaped %d, caught %d (chase every %.0fs, survive %.0f%%)" % [chases, escapes, catches, game_seconds / maxf(chases, 1), 100.0 * escapes / maxf(chases, 1)])
	print("ENCOUNTERS %d, first at %.0fs, near(<12m) %s, avg dist %.1f m" % [encounters, first_contact, pct.call(near_time), dist_sum / total])
	print("MOVE wants %.0fs, stuck-while-wanting %.0fs (%.0f%%), stalls>1s %d, pending %.1fs, avg speed %.2f" % [move_time, still_wanting, 100.0 * still_wanting / maxf(move_time, 0.1), long_stalls, pending_time, move_dist / maxf(move_time, 0.1)])
	print("HUNT time %.1fs avg speed %.2f max %.2f (nominal %.2f)" % [hunt_time, hunt_dist / maxf(hunt_time, 0.1), hunt_max_speed, e.speed_hunt])
	print("MISC transitions %d, direction flips %d, recoveries %d" % [transitions, flips, e.navigation_recoveries])
	print("TRACE ", " ".join(trace))
	print("STALLS ", stall_causes)
	print("WALL ", wall_time)
	print("FACEWALL ", face_wall, " doors closed ", doors_closed)
	for fp in face_pts:
		print("FP ", fp)
	print("WALLPTS ", wall_pts.slice(0, 40))
	print("SMART - %d, recoveries %d" % [0, e.navigation_recoveries])
	for c in catch_log:
		print("CATCH ", c)
	var region: NavigationRegion3D = get_tree().current_scene.get("nav_region")
	var nav_out := {"verts": [], "polys": []}
	if region:
		var nm: NavigationMesh = region.navigation_mesh
		for v in nm.get_vertices():
			nav_out.verts.append([v.x, v.y, v.z])
		for k in range(nm.get_polygon_count()):
			nav_out.polys.append(Array(nm.get_polygon(k)))
	var covers := []
	for c in e.world_actions.cover:
		if is_instance_valid(c):
			covers.append([c.global_position.x, c.global_position.z, str(c.get_meta("prefab_type", ""))])
	var doors := []
	for d in get_tree().get_nodes_in_group("doors"):
		if d is Node3D:
			doors.append([d.global_position.x, d.global_position.z])
	var f := FileAccess.open("res://scratch/trace.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"rows": trace_rows, "states": e.State.keys(), "nav": nav_out, "covers": covers, "doors": doors}))
	f.close()
	print("METRICS DONE")
	get_tree().quit()
