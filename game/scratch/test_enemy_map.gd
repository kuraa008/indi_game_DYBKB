extends Node3D

var enemy: CharacterBody3D

func _ready() -> void:
	GameManager.set_process(false)
	var main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await get_tree().create_timer(1.0).timeout
	for i in range(4):
		await get_tree().physics_frame
	GameManager.is_godmode = true
	enemy = GameManager.enemy_ref
	var player: CharacterBody3D = GameManager.player_ref
	enemy.set_physics_process(false)
	player.set_physics_process(false)
	enemy.world_actions.scan()
	var goals: Array[Vector3] = [player.global_position]
	var failures := 0
	var nav_map := enemy.get_world_3d().navigation_map
	# Allow the asynchronous region iteration to publish the baked geometry.
	for i in range(120):
		if NavigationServer3D.region_get_bounds(main.nav_region.get_rid()).size.length() > 1.0:
			break
		await get_tree().physics_frame
	var near := NavigationServer3D.map_get_closest_point(nav_map, enemy.global_position)
	print("NAVMESH SPAWN DISTANCE: ", near.distance_to(enemy.global_position))
	print("NAVMESH POLYGONS: ", main.nav_region.navigation_mesh.get_polygon_count(), " iteration=", NavigationServer3D.map_get_iteration_id(nav_map), " bounds=", main.nav_region.navigation_mesh.filter_baking_aabb)
	var vertex_bounds := AABB()
	for vertex in main.nav_region.navigation_mesh.vertices:
		vertex_bounds = vertex_bounds.expand(vertex)
	print("NAV DEBUG: vertices=", vertex_bounds, " world_map=", nav_map, " region_map=", main.nav_region.get_navigation_map(), " server_region_map=", NavigationServer3D.region_get_map(main.nav_region.get_rid()), " active=", NavigationServer3D.map_is_active(nav_map), " region_count=", NavigationServer3D.map_get_regions(nav_map).size(), " enabled=", main.nav_region.enabled)
	print("REGION DEBUG: ", NavigationServer3D.region_get_bounds(main.nav_region.get_rid()), " iteration=", NavigationServer3D.region_get_iteration_id(main.nav_region.get_rid()), " region_closest=", NavigationServer3D.region_get_closest_point(main.nav_region.get_rid(), enemy.global_position))
	if near.distance_to(enemy.global_position) > 1.0:
		failures += 1
	for target in goals:
		print("REAL MAP ROUTE: ", enemy.global_position, " -> ", target, " props=", enemy.world_actions.movable.size())
		if not await drive(target):
			failures += 1
			break
	# Test a real house doorway with targets on its two physically free sides.
	var doorway: Node3D = main.nav_region.get_node("door_simple_2111")
	enemy.navigator.refresh_exclusions()
	var first: Variant = enemy.navigator.floor_at(doorway.global_position + doorway.global_basis.z * 1.2)
	var second: Variant = enemy.navigator.floor_at(doorway.global_position - doorway.global_basis.z * 1.2)
	print("MAP DOOR APPROACHES: ", first, " / ", second)
	if first != null and second != null and enemy.navigator.body_clear(first) and enemy.navigator.body_clear(second):
		enemy.global_position = first
		enemy.velocity = Vector3.ZERO
		enemy.navigator.blocked_spots.clear()
		await get_tree().physics_frame
		if not await drive(second):
			failures += 1
	else:
		print("FAIL: House doorway approach is obstructed by map geometry")
		failures += 1
	GameManager.player_ref = null
	GameManager.enemy_ref = null
	GameManager.ui_ref = null
	main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	print("REAL MAP FAILURES: ", failures)
	get_tree().quit(0 if failures == 0 else 1)

func drive(target: Vector3) -> bool:
	enemy.navigator.clear()
	for i in range(3600):
		await get_tree().physics_frame
		var dt := 1.0 / 60.0
		enemy.navigator.tick(dt)
		enemy.world_actions.tick(dt)
		enemy._retreat_cooldown = maxf(0.0, enemy._retreat_cooldown - dt)
		if enemy._retreat_time > 0.0:
			enemy._do_retreat(dt)
		else:
			enemy._nav_move_to(target, 4.8, dt)
		enemy.velocity.y = -0.5 if enemy.is_on_floor() else enemy.velocity.y - 18.0 * dt
		enemy._try_step(Vector3(enemy.velocity.x, 0, enemy.velocity.z) * dt)
		enemy.move_and_slide()
		enemy._update_progress(dt)
		if i % 600 == 0:
			print("MAP PROGRESS: ", enemy.global_position, " path=", enemy.navigator.path.size(), " pending=", enemy.navigator.pending, " expanded=", enemy.navigator.attempts)
		if enemy.global_position.distance_to(target) < 1.0:
			print("PASS: Real map route completed; recoveries=", enemy.navigation_recoveries)
			return true
		if enemy.navigator.failed and not enemy.navigator.partial:
			print("FAIL: Real map route unreachable at ", enemy.global_position, " nodes=", enemy.navigator.attempts)
			return false
	print("FAIL: Real map route timed out at ", enemy.global_position, " path=", enemy.navigator.path)
	return false
