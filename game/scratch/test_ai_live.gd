extends Node

# Оба ИИ живут на настоящей карте. Запуск: --path game --headless res://scratch/test_ai_live.tscn
var log_sw: Array[String] = []
var log_lj: Array[String] = []
var counts := {}

func _note(key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var map_path := "res://scenes/Карта_6_fix.json"
	for a in OS.get_cmdline_user_args():
		map_path = a
	GameManager.intro_cutscene_played = true
	GameManager.active_map_path = map_path
	var main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	for i in range(120):
		await get_tree().physics_frame
	GameManager.is_godmode = true
	GameManager.mic_enabled = false
	var e = GameManager.enemy_ref
	var lj = GameManager.lumberjack_ref
	var p = GameManager.player_ref
	print("MAP ", map_path, " enemy=", is_instance_valid(e), " lumberjack=", is_instance_valid(lj))
	if is_instance_valid(lj):
		lj.set_physics_process(true)
		lj.is_in_cutscene = false
		lj.start_grace = 0.0
	# Игрок вне карты и не шумит: оба живут своей жизнью
	p.set_physics_process(false)
	var home: Vector3 = p.global_position
	p.global_position = home + Vector3(0, -200, 0)
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	var last_sw := -1
	var last_lj := ""
	# time_scale не меняет длину тика: каждый тик это 1/60 игровой секунды
	for i in range(int(110.0 * 60.0)):
		await get_tree().physics_frame
		if is_instance_valid(e):
			if int(e.state) != last_sw:
				last_sw = int(e.state)
				_note("sw:" + e.State.keys()[last_sw])
				if log_sw.size() < 40:
					log_sw.append(e.State.keys()[last_sw])
		if is_instance_valid(lj):
			var cur: String = lj.State.keys()[lj.current_state]
			if lj.current_state == lj.State.ACTIVITY and lj.activity_phase == "do":
				cur = "DO_" + str(lj.activity.get("kind", "?"))
			if cur != last_lj:
				last_lj = cur
				_note("lj:" + cur)
				if log_lj.size() < 40:
					log_lj.append(cur)
	Engine.time_scale = 1.0
	print("SW: ", " > ".join(log_sw))
	print("LJ: ", " > ".join(log_lj))
	print("COUNTS ", counts)
	if is_instance_valid(e):
		print("SW recoveries=", e.navigation_recoveries, " stall=", e.navigation_stall_time)
	if not is_instance_valid(e):
		print("LIVE DONE")
		get_tree().quit()
		return
	# Встреча: игрок прямо перед монстром, дальше он бежит
	p.global_position = home
	e.global_position = home + Vector3(0, 0, 14)
	e.reset_ai()
	e._set_state(e.State.HUNT)
	e.last_known_player_pos = home
	e.time_since_last_seen = 0.0
	var saw_dash := false
	var dash_min := 99.0
	for i in range(360):
		await get_tree().physics_frame
		if e.state == e.State.DASH:
			saw_dash = true
		dash_min = minf(dash_min, e.global_position.distance_to(p.global_position))
	print("CHASE closest=%.2f state=%s" % [dash_min, e.State.keys()[e.state]])
	print("LIVE DONE")
	get_tree().quit()
