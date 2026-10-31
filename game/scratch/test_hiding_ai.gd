extends Node3D

var failures: int = 0

func check(ok: bool, message: String) -> void:
	if ok: print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	shape.material = material
	mesh.mesh = shape
	mesh.position = pos
	add_child(mesh)

func _ready() -> void:
	GameManager.set_process(false)
	GameManager.game_ended = false
	GameManager.is_godmode = false
	var wardrobe = PrefabBuilder.build_prefab("prop_wardrobe", Vector3.ONE, Color.WHITE, false)
	add_child(wardrobe)
	var cabinet = wardrobe.get_child(0) as Node3D
	var player = load("res://scenes/Player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.position = Vector3(0,0,1.4)
	GameManager.player_ref = player
	var before: Vector3 = player.position
	var old_near: float = player.camera.near
	player.enter_hiding(cabinet)
	check(absf(cabinet.to_local(player.camera.global_position).z - 0.08) < 0.01, "Camera is physically inside cabinet behind doors")
	check(player.col_node.disabled, "Player collider is disabled in wardrobe")
	player._physics_process(0.016)
	check(player.col_node.disabled, "Hidden collider stays disabled on next frame")
	check(player.camera.near < 0.02, "Near plane preserves close interior walls")
	player.exit_hiding()
	check(player.position.is_equal_approx(before) and not player.col_node.disabled and player.camera.near == old_near, "Exit restores position, collision and camera")
	# Check a rotated cabinet as well as the default orientation.
	wardrobe.rotation.y = PI / 2.0
	player.enter_hiding(cabinet)
	check((-player.camera.global_basis.z).dot(cabinet.global_basis.z.normalized()) > 0.99, "View faces out of rotated cabinet")
	player.exit_hiding()
	wardrobe.rotation.y = 0
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	GameManager.enemy_ref = enemy
	GameManager.player_ref = null
	enemy.state = enemy.State.SEARCH
	enemy.search_points = [Vector3(0.5,0,0)]
	enemy.state_timer = 0
	enemy.search_inspecting = false
	enemy._do_search(0.1)
	check(enemy.search_inspecting, "SEARCH executes inspection movement logic")
	enemy.state = enemy.State.AMBUSH
	enemy.search_inspecting = false
	enemy.ambush_timer = 0
	enemy._do_ambush(0.1)
	check(not enemy.search_inspecting and enemy.state == enemy.State.AMBUSH, "AMBUSH does not run SEARCH movement")
	enemy._start_search(Vector3(3,0,3))
	enemy.state_timer = 5
	enemy._start_search(Vector3(3,0,3))
	check(enemy.state_timer == 5, "Repeated sound does not reset search timer")
	GameManager.player_ref = player
	player.enter_hiding(cabinet)
	enemy.last_known_player_pos = Vector3(4,0,3)
	enemy.time_since_last_seen = 20
	enemy.state = enemy.State.RAGE
	enemy._do_rage(0.1)
	check(enemy.state == enemy.State.SEARCH and enemy.alert_pos == Vector3(4,0,3), "Rage searches last known location instead of tracking through walls")
	enemy.last_visual_time = Time.get_ticks_msec()/1000.0
	enemy.last_known_player_pos = player.global_position
	check(enemy._witnessed_hiding(player), "Hunter remembers a witnessed hiding entry")
	enemy.last_visual_time = -100
	enemy.witnessed_hiding_spot = null
	check(not enemy._witnessed_hiding(player), "Unseen hiding does not reveal itself")
	var region = NavigationRegion3D.new()
	var nav = NavigationMesh.new()
	nav.vertices = PackedVector3Array([Vector3(-15,0,-15),Vector3(15,0,-15),Vector3(15,0,15),Vector3(-15,0,15)])
	nav.add_polygon(PackedInt32Array([0,3,2,1]))
	region.navigation_mesh = nav
	add_child(region)
	var bot = load("res://scripts/SurvivorBot.gd").new()
	add_child(bot)
	bot.set_physics_process(false)
	bot.position = Vector3(0,0,4)
	bot.threat_position = Vector3(0,0,1)
	await get_tree().create_timer(0.3).timeout
	var escape: Vector3 = bot._choose_escape_target()
	check(escape.distance_to(bot.threat_position) > bot.global_position.distance_to(bot.threat_position), "Survivor chooses reachable escape away from known threat")
	bot.oxygen = 0
	bot.breath_recovery = 1
	check(bot.get_breath_noise_level() > 0.7, "Survivor cannot hold breath indefinitely")
	# Showcase real cabinet occlusion and visible action outside.
	bot.hide()
	enemy.position = Vector3(0,0,3.5)
	enemy.rotation.y = 0
	player.camera.current = true
	var light = OmniLight3D.new()
	light.position = Vector3(0,2,2)
	light.omni_range = 12
	light.light_energy = 1.7
	add_child(light)
	box(Vector3(0,-0.15,3),Vector3(8,0.2,9),Color(0.23,0.24,0.20))
	box(Vector3(0,1.5,6),Vector3(8,3,0.2),Color(0.36,0.39,0.33))
	box(Vector3(-4,1.5,2),Vector3(0.2,3,8),Color(0.28,0.30,0.26))
	box(Vector3(4,1.5,2),Vector3(0.2,3,8),Color(0.28,0.30,0.26))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image = get_viewport().get_texture().get_image()
		image.save_png("res://scratch/wardrobe_inside.png")
	print("HIDING AND TACTICS FAILURES: ", failures)
	GameManager.player_ref = null
	GameManager.enemy_ref = null
	get_tree().quit(0 if failures == 0 else 1)
