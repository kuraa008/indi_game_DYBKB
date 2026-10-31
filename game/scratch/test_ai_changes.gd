extends Node3D

var failures: int = 0
var pain_events: Array = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func wave_count() -> int:
	var count: int = 0
	for child in get_children():
		if child.get_script() == load("res://scripts/AcousticWave.gd"):
			count += 1
	return count

func _ready() -> void:
	GameManager.set_process(false)
	GameManager.game_ended = false
	GameManager.is_no_ai = false
	GameManager.pain_triggered.connect(func(who, _penalty, _reason): pain_events.append(who))
	position = Vector3(3, 0, 2)
	GameManager.emit_noise(Vector3(7, 0, 5), 15)
	check(wave_count() == 0, "Footsteps/environment create no marker")
	GameManager.emit_noise(Vector3(7, 0, 5), 32, "bottle")
	check(wave_count() == 1, "Bottle creates one marker")
	var wave = get_child(get_child_count() - 1)
	check(wave.global_position.is_equal_approx(Vector3(7, 0, 5)), "Marker uses impact world position under transformed scene")
	check(wave.ring_mat.no_depth_test and wave.label_3d.no_depth_test, "Ring and text visible through walls")
	check(wave.label_3d.outline_modulate == Color(0, 0, 0, 0.8), "Label3D outline property works")
	var human = CharacterBody3D.new()
	add_child(human)
	GameManager.enemy_ref = human
	GameManager.player_score = 100
	GameManager.monster_score = 100
	GameManager.trigger_pain("player", "test")
	GameManager.trigger_pain("monster", "human-controlled")
	check(pain_events.is_empty() and GameManager.player_score == 100 and GameManager.monster_score == 100, "Neither human role receives pain")
	var report = GameManager.get_node("AIReport")
	var human_path: String = report.save_report(ProjectSettings.globalize_path("res://scratch/ai_human_test.json"))
	var human_json = JSON.parse_string(FileAccess.get_file_as_string(human_path))
	check(human_json.current.controlled_by == "human_demonstrator", "Export supports human-controlled monster")
	var enemy = load("res://scenes/Enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	GameManager.enemy_ref = enemy
	GameManager.trigger_pain("monster", "test")
	check(pain_events == ["monster"] and GameManager.monster_score == 60, "AI monster receives pain and score penalty")
	var region = NavigationRegion3D.new()
	var nav = NavigationMesh.new()
	nav.vertices = PackedVector3Array([Vector3(-10,0,-10),Vector3(10,0,-10),Vector3(10,0,10),Vector3(-10,0,10)])
	nav.add_polygon(PackedInt32Array([0,3,2,1]))
	region.navigation_mesh = nav
	add_child(region)
	await get_tree().create_timer(0.3).timeout
	for i in range(4):
		await get_tree().physics_frame
	enemy.navigation_anchor = enemy.global_position
	for i in range(100):
		enemy._navigation_recovery_target(enemy.global_position + Vector3(6,0,0), 0.02)
	check(enemy.navigation_recoveries > 0, "Zero-motion watchdog activates without a steering direction")
	check(enemy.recovery_time > 0, "Watchdog chooses a navigable detour")
	var wall = StaticBody3D.new()
	wall.position = enemy.position + Vector3(1.2, 1.0, 0.0)
	var box = BoxShape3D.new()
	box.size = Vector3(0.3, 2.0, 1.5)
	var shape = CollisionShape3D.new()
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	await get_tree().physics_frame
	enemy.recovery_time = 0.0
	enemy.navigation_stall_time = 1.6
	var detour: Vector3 = enemy._navigation_recovery_target(enemy.global_position + Vector3(6,0,0), 0.02)
	check(enemy.recovery_time > 0 and not enemy.test_move(enemy.global_transform, Vector3(detour.x-enemy.global_position.x,0,detour.z-enemy.global_position.z)), "Recovery detour passes full body collision check beside a wall")
	enemy.reset_ai()
	check(enemy.recovery_time == 0 and enemy.navigation_stall_time == 0, "Restart clears recovery state")
	var path: String = report.save_report(ProjectSettings.globalize_path("res://scratch/ai_test.json"))
	var saved = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved != null and saved.current.controlled_by == "ai" and saved.has("expected_behavior") and saved.has("history"), "AI report is valid JSON with rules and diagnostics")
	var polygon = load("res://scripts/Polygon.gd").new()
	var profile: Dictionary = polygon._build_demonstration_profile()
	check(profile.has("samples") and profile.has("tactics"), "Training demonstration exports samples and desired tactics")
	polygon.free()
	GameManager.enemy_ref = null
	print("AI CHANGE TEST FAILURES: ", failures)
	get_tree().quit(0 if failures == 0 else 1)
