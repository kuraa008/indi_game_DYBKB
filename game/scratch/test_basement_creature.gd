extends Node

# Проверка существа в подвале. Запуск: --path game --headless res://scratch/test_basement_creature.tscn
const MAIN := "res://scenes/Main.tscn"
const MAP := "res://scenes/Шоссе.json"
var failures := 0


func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func wait_until(cond: Callable, limit: float) -> float:
	var t := 0.0
	while not cond.call() and t < limit:
		await wait(0.1)
		t += 0.1
	return t


func _ready() -> void:
	_start.call_deferred()


func _wardrobe(scene: Node, near: Vector3) -> Node3D:
	var best: Node3D = null
	for n in scene.find_children("*", "", true, false):
		if n is Node3D and n.has_meta("hiding_type") and (n as Node3D).global_position.distance_to(near) < 1.5:
			best = n
	return best


func _start() -> void:
	reparent(get_tree().root)
	GameManager.reset_state()
	GameManager.active_map_path = MAP
	GameManager.wake_in_basement = true
	get_tree().change_scene_to_file(MAIN)
	await wait(2.0)
	var scene := get_tree().current_scene
	var ch: Node = scene.get_node_or_null("BasementChapter")
	var player: CharacterBody3D = GameManager.player_ref
	await wait_until(func(): return ch.creature != null, 5.0)
	var cr: Node = ch.creature
	check(cr != null and is_instance_valid(cr.enemy), "Существо создано")
	check(not cr.enemy.visible, "Пока наверху, его не видно")
	check(GameManager.is_godmode, "Обычная смерть в подвале выключена")
	var hands = player.get("player_hands")
	var pivot = hands.find_child("FlashlightPivot", true, false) if hands else null
	check(pivot != null and not pivot.visible, "Фонарика в руке нет")
	await wait_until(func(): return player.get("is_in_cutscene") != true, 30.0)

	# 1. Успел спрятаться: оно нюхает, зовёт, уходит
	var wardrobe := _wardrobe(scene, cr.WARDROBE)
	check(wardrobe != null, "Шкаф найден")
	player.call("enter_hiding", wardrobe)
	check(player.get("is_hiding") == true, "Итан в шкафу")
	await wait_until(func(): return cr.enemy.visible, 15.0)
	var start: Vector3 = cr.enemy.global_position
	check(cr.enemy.visible, "Оно спустилось")
	var took := await wait_until(func(): return cr.phase == cr.Phase.OPENING_CALL, 20.0)
	print("walk+sniff took ", took)
	check(cr.phase == cr.Phase.OPENING_CALL, "Зовёт голосом Сэма")
	check(start.distance_to(cr.enemy.global_position) > 3.0, "Спустилось и прошло по подвалу (%.1f м)" % start.distance_to(cr.enemy.global_position))
	check(Vector2(cr.enemy.global_position.x - cr.WAKE_SPOT.x, cr.enemy.global_position.z - cr.WAKE_SPOT.z).length() < 2.0, "Стоит там, где лежал Итан")
	check(cr._prompt.visible, "На экране «Ответить»")
	if "shots" in OS.get_cmdline_user_args():
		await wait(0.6)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://cr_call.png")
		player.call("exit_hiding")
		var head: Node3D = player.get("head")
		player.global_position = Vector3(-56.0, -4.15, -230.0)
		var to: Vector3 = cr.enemy.global_position + Vector3(0, 1.2, 0) - (player.global_position + Vector3(0, 1.62, 0))
		player.rotation.y = atan2(-to.x, -to.z)
		head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		player.set_physics_process(false)
		await wait(0.3)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://cr_look.png")
		print("ENEMY ", cr.enemy.global_position, " vis ", cr.enemy.visible, " tree ", cr.enemy.is_visible_in_tree(), " parent ", cr.enemy.get_parent().name)
		for m in cr.enemy.find_children("*", "MeshInstance3D", true, false).slice(0, 4):
			print("  mesh ", m.name, " vis ", m.is_visible_in_tree(), " ", m.global_position)
		print("PLAYER ", player.global_position)
		get_tree().quit()
		return
	await wait_until(func(): return cr.opening_done, 25.0)
	check(cr.opening_done and cr.catches == 0, "Не ответил: оно ушло")
	check(not cr.enemy.visible, "Оно снова наверху")
	player.call("exit_hiding")
	await wait(0.3)

	# 2. Громкий звук: спускается почти сразу
	ch._alert("test")
	check(cr.phase == cr.Phase.IDLE and cr._next_visit <= 0.0, "Шум зовёт его вниз")
	await wait(0.2)
	check(cr.phase == cr.Phase.WARNING, "Наверху стук: несколько секунд, чтобы спрятаться")

	# 3. Не спрятался: поймал, возврат к пробуждению
	player.global_position = Vector3(-55.0, -4.15, -224.0)
	await wait_until(func(): return cr.catches == 1, 20.0)
	check(cr.catches == 1, "Не спрятался: поймал")
	await wait(2.4)
	check(player.global_position.distance_to(ch.WAKE_POS) < 1.0, "Начинает с места пробуждения")
	check(not cr.enemy.visible, "После поимки оно ушло наверх")

	# 4. Ответил на зов
	cr._start_opening()
	player.call("enter_hiding", wardrobe)
	print("hidden for answer: ", player.get("is_hiding"), " busy ", ch._busy, " phase ", cr.phase)
	await wait_until(func(): return cr.phase == cr.Phase.OPENING_CALL, 40.0)
	print("answer phase ", cr.phase, " catches ", cr.catches)
	cr.answer()
	await wait(1.6)
	check(cr.catches == 2, "Ответил: оно нашло его")
	await wait(2.5)

	# 5. Обычный визит и уход
	cr.opening_done = true
	cr._plan_next_visit()
	cr._next_visit = 0.0
	player.call("enter_hiding", wardrobe)
	await wait_until(func(): return cr.phase == cr.Phase.VISIT, 15.0)
	check(cr.phase == cr.Phase.VISIT and cr.visits >= 1, "Спустилось проверить подвал")
	cr._t = cr.VISIT_SECONDS
	await wait_until(func(): return cr.phase == cr.Phase.IDLE, 20.0)
	check(cr.phase == cr.Phase.IDLE and not cr.enemy.visible, "Проверило и ушло")
	check(cr.catches == 2, "В шкафу не тронуло")

	print("CREATURE FAILURES: %d" % failures)
	get_tree().quit()
