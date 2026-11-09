extends Node3D

# Проверка нового ИИ скинволкера. Запуск: --path game --headless res://scratch/test_ai_senses.tscn
const PLAYER_SRC := """extends CharacterBody3D
var is_dead := false
var is_hiding := false
var hiding_node = null
var is_crouching := false
var is_sprinting := false
var flashlight_on := false
var breath_held := false
var died := 0
func is_breath_held() -> bool:
	return breath_held
func die(_killer = null) -> void:
	died += 1
func exit_hiding() -> void:
	is_hiding = false
"""

var failures := 0
var enemy: CharacterBody3D
var player: CharacterBody3D
var wall: StaticBody3D

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = pos
	add_child(body)
	return body

func wait(seconds: float) -> void:
	for i in range(int(seconds * 60.0)):
		await get_tree().physics_frame

func place(enemy_pos: Vector3, player_pos: Vector3, face_player: bool = true) -> void:
	enemy.set_physics_process(false)
	enemy.reset_ai()
	enemy._clock = 99.0
	enemy._last_contact = 99.0
	enemy.global_position = enemy_pos
	enemy.velocity = Vector3.ZERO
	player.global_position = player_pos
	player.velocity = Vector3.ZERO
	player.is_hiding = false
	player.hiding_node = null
	player.is_crouching = false
	player.is_sprinting = false
	player.flashlight_on = false
	player.breath_held = false
	player.died = 0
	var to_player := player_pos - enemy_pos
	var yaw := atan2(-to_player.x, -to_player.z)
	enemy.rotation.y = yaw if face_player else yaw + PI
	enemy._goal = enemy_pos
	enemy.waypoints.clear()
	await get_tree().physics_frame
	await get_tree().physics_frame

func run(seconds: float) -> void:
	enemy.set_physics_process(true)
	await wait(seconds)
	enemy.set_physics_process(false)

func _ready() -> void:
	GameManager.set_process(false)
	GameManager.reset_state()
	GameManager.game_ended = false
	GameManager.is_no_ai = false
	GameManager.is_godmode = true
	box(Vector3(0, -0.2, 0), Vector3(90, 0.4, 90))
	wall = box(Vector3(0, 1.5, 0), Vector3(0.4, 3.0, 12.0))
	enemy = load("res://scenes/Enemy.tscn").instantiate()
	add_child(enemy)
	enemy.set_physics_process(false)
	GameManager.enemy_ref = enemy
	player = CharacterBody3D.new()
	player.name = "Player"
	var scr := GDScript.new()
	scr.source_code = PLAYER_SRC
	scr.reload()
	player.set_script(scr)
	var pc := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	pc.shape = cap
	pc.position = Vector3(0, 0.85, 0)
	player.add_child(pc)
	add_child(player)
	GameManager.player_ref = player
	await get_tree().physics_frame

	# ── Зрение ──
	await place(Vector3(-5, 0.03, 0), Vector3(5, 0.03, 0))
	check(not enemy._can_see_player(), "Сквозь стену не видит")
	wall.collision_layer = 0
	await place(Vector3(-5, 0.03, 0), Vector3(-6.4, 0.03, 0.3), false)
	enemy._check_senses()
	check(enemy.state == enemy.State.HUNT, "Вплотную за спиной видит сразу")
	await place(Vector3(-5, 0.03, 0), Vector3(1, 0.03, 0))
	enemy._check_senses()
	check(enemy.state == enemy.State.HUNT, "В 6 м перед собой замечает мгновенно")
	await place(Vector3(-22, 0.03, 0), Vector3(2, 0.03, 0))
	player.flashlight_on = true
	enemy._check_senses()
	var ticks := 1
	while enemy.state != enemy.State.HUNT and ticks < 30:
		enemy._check_senses()
		ticks += 1
	check(ticks > 1 and ticks <= 10, "Издалека замечает за долю секунды (%d тиков)" % ticks)
	await place(Vector3(-5, 0.03, 0), Vector3(5, 0.03, 0), false)
	enemy._check_senses()
	check(enemy.state != enemy.State.HUNT, "В 10 м за спиной не видит")
	enemy._clock = 2.0
	await place(Vector3(-5, 0.03, 0), Vector3(3, 0.03, 0))
	enemy._clock = 2.0
	enemy._check_senses()
	check(enemy.state != enemy.State.HUNT, "Первые секунды уровня не замечает")

	# ── Погоня: быстро, без остановок ──
	await place(Vector3(-20, 0.03, -10), Vector3(10, 0.03, -10))
	enemy.last_known_player_pos = player.global_position
	enemy.time_since_last_seen = 0.0
	enemy._begin_hunt()
	var start: Vector3 = enemy.global_position
	await run(1.5)
	var speed: float = Vector2(enemy.global_position.x - start.x, enemy.global_position.z - start.z).length() / 1.5
	check(enemy.state == enemy.State.HUNT and speed > 5.8, "Сразу бежит в полную силу (%.1f м/с)" % speed)

	# ── Обходит стену кратчайшим путём ──
	wall.collision_layer = 1
	await place(Vector3(-3, 0.03, 0), Vector3(3, 0.03, 0))
	enemy._set_state(enemy.State.HUNT)
	enemy.last_known_player_pos = Vector3(3, 0.03, 0)
	enemy.time_since_last_seen = 0.0
	var reached := false
	enemy.set_physics_process(true)
	for i in range(int(6.0 * 60)):
		await get_tree().physics_frame
		enemy.time_since_last_seen = 0.0
		if enemy._flat_dist(enemy.global_position, player.global_position) < 1.8:
			reached = true
			break
	enemy.set_physics_process(false)
	check(reached, "Обходит стену и добегает до игрока")
	wall.collision_layer = 0

	# ── Потерял ──
	await place(Vector3(-5, 0.03, 0), Vector3(30, 0.03, 30))
	enemy._set_state(enemy.State.HUNT)
	enemy.last_known_player_pos = Vector3(-4.5, 0.03, 0)
	enemy.time_since_last_seen = 2.0
	await run(0.5)
	check(enemy.state == enemy.State.SEARCH, "Дойдя до последнего места, сразу ищет")
	await place(Vector3(-5, 0.03, 0), Vector3(30, 0.03, 30))
	enemy._set_state(enemy.State.HUNT)
	enemy.last_known_player_pos = Vector3(-30, 0.03, 0)
	enemy.time_since_last_seen = enemy.HUNT_MEMORY + 0.1
	await run(0.2)
	check(enemy.state != enemy.State.HUNT, "Память кончилась: погоня заканчивается")

	# ── Слух: сразу бежит, не стоит ──
	await place(Vector3(-10, 0.03, 0), Vector3(30, 0.03, 30))
	enemy.on_noise_heard(Vector3(0, 0.03, 0), 14.0)
	check(enemy.state == enemy.State.SEARCH, "Услышав шум, сразу идёт проверять")
	start = enemy.global_position
	await run(0.6)
	check(enemy.global_position.distance_to(start) > 1.5, "Без паузы: уже в пути")

	# ── Нигде долго не стоит ──
	await place(Vector3(-10, 0.03, 0), Vector3(30, 0.03, 30))
	enemy._start_search(Vector3(-4, 0.03, 0), false)
	var still := 0.0
	var last: Vector3 = enemy.global_position
	enemy.set_physics_process(true)
	for i in range(int(8.0 * 60)):
		await get_tree().physics_frame
		if enemy.global_position.distance_to(last) < 0.004:
			still += 1.0 / 60.0
		last = enemy.global_position
	enemy.set_physics_process(false)
	check(still < 2.5, "Ищет, а не стоит (стоял %.1f с из 8)" % still)

	# ── Укрытия ──
	var wardrobe := box(Vector3(-2, 1.0, 0), Vector3(1.0, 2.0, 0.6))
	await place(Vector3(-4, 0.03, 0), Vector3(-2, 0.03, 0))
	player.is_hiding = true
	player.hiding_node = wardrobe
	enemy._check_hiding_nearby()
	check(enemy.state == enemy.State.STAKEOUT_HIDING, "Подойдя к укрытию с игроком, прислушивается")
	player.breath_held = true
	await run(3.0)
	check(enemy.state != enemy.State.STAKEOUT_HIDING and player.died == 0, "Задержал дыхание: уходит")
	GameManager.is_godmode = false
	await place(Vector3(-4, 0.03, 0), Vector3(-2, 0.03, 0))
	player.is_hiding = true
	player.hiding_node = wardrobe
	enemy._check_hiding_nearby()
	await run(6.3)
	check(player.died == 1, "Дышит в укрытии: вытаскивает")
	await place(Vector3(-4, 0.03, 0), Vector3(-2, 0.03, 0))
	player.is_hiding = true
	player.hiding_node = wardrobe
	enemy.witnessed_hiding_spot = wardrobe
	enemy._check_hiding_nearby()
	await run(1.3)
	check(player.died == 1, "Видел, куда залез: достаёт сразу")
	wardrobe.queue_free()

	# ── Поимка ──
	await place(Vector3(-5, 0.03, 0), Vector3(-3.8, 0.03, 0))
	enemy._check_catch()
	check(player.died == 0, "Касание ещё не поимка")
	await run(0.4)
	check(player.died == 1, "Держит рядом: поймал")
	GameManager.is_godmode = true

	# ── Фонарик ──
	var cam_holder := Node3D.new()
	cam_holder.name = "Head"
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam_holder.add_child(cam)
	player.add_child(cam_holder)
	cam_holder.position = Vector3(0, 1.6, 0)
	await place(Vector3(-5, 0.03, 0), Vector3(5, 0.03, 0), false)
	player.look_at(Vector3(-5, 0.03, 0) + Vector3.UP * 0.0, Vector3.UP)
	player.flashlight_on = true
	enemy.set_physics_process(true)
	await wait(0.8)
	enemy.set_physics_process(false)
	check(enemy.state == enemy.State.HUNT, "Посветил фонариком: бросается")

	print("AI SENSES FAILURES: %d" % failures)
	get_tree().quit()
