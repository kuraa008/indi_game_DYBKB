extends Node

# Проверка существа в доме (глава 3). Запуск: --path game --headless res://scratch/test_house_creature.tscn
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


func _start() -> void:
	reparent(get_tree().root)
	GameManager.reset_state()
	GameManager.active_map_path = MAP
	GameManager.wake_in_basement = true
	get_tree().change_scene_to_file(MAIN)
	await wait(2.0)
	var scene := get_tree().current_scene
	var player: CharacterBody3D = GameManager.player_ref
	while player.get("is_in_cutscene") == true:
		await wait(0.5)
	scene.get_node("BasementChapter")._finish_basement()
	# Игрок пока в стороне, в саду: существо обходит дом без него
	player.global_position = Vector3(-40.0, 0.15, -245.0)
	await wait(0.5)
	var ch: Node = scene.get_node("HouseChapter3")
	var cr: Node = ch.creature
	check(cr != null and cr.enemy.visible, "Существо в доме")
	check(GameManager.is_godmode, "Обычная смерть выключена: поимку решает глава")

	# Обход: доходит до второго этажа и возвращается вниз
	var top := -10.0
	var seen_points := {}
	var t := 0.0
	while t < 75.0:
		await wait(0.25)
		t += 0.25
		top = maxf(top, cr.enemy.global_position.y)
		seen_points[cr.route_i] = true
		if top > 3.0 and seen_points.size() >= cr.ROUTE.size():
			break
	print("patrol ", t, " s, highest y ", top, " points ", seen_points.size(), " pos ", cr.enemy.global_position)
	check(top > 3.0, "Поднимается на второй этаж")
	check(seen_points.size() >= cr.ROUTE.size(), "Проходит весь обход (%d из %d)" % [seen_points.size(), cr.ROUTE.size()])
	check(cr.mode == "patrol" and cr.catches == 0, "Без игрока просто ходит")

	# Шум: идёт на звук
	cr.route_i = 1
	cr.enemy.global_position = cr.ROUTE[1]
	# Доски на окне кладовки: шумит у задней стены
	player.global_position = Vector3(-62.0, 0.15, -233.0)
	ch._alert("board")
	await wait(0.4)
	check(cr.mode == "ai", "Громкий звук: идёт проверять")
	player.global_position = Vector3(-40.0, 0.15, -245.0)
	await wait_until(func(): return cr.mode == "patrol", 40.0)
	check(cr.mode == "patrol", "Проверил и вернулся на обход")

	# Увидел: погоня и поимка, возврат к последней точке
	cr.checkpoint = ch.INSIDE_PANTRY
	player.global_position = Vector3(-56.5, 0.16, -223.5)
	cr.enemy.global_position = Vector3(-56.5, 0.16, -229.0)
	var head: Node3D = player.get("head")
	cr.enemy.rotation.y = 0.0
	cr.route_i = 2
	await wait_until(func(): return cr.catches == 1, 20.0)
	check(cr.catches == 1, "Увидел в коридоре: поймал")
	await wait(2.4)
	check(player.global_position.distance_to(ch.INSIDE_PANTRY) < 1.0, "Начинает с кладовки")
	check(cr.enemy.global_position.distance_to(player.global_position) > 5.0, "Существо ушло в дальний конец дома")

	# В шкафу: не трогает
	var wardrobe: Node3D = null
	for n in scene.find_children("*", "", true, false):
		if n is Node3D and n.has_meta("hiding_type") and (n as Node3D).global_position.distance_to(Vector3(-60.3, 3.48, -219.55)) < 1.5:
			wardrobe = n
	check(wardrobe != null, "Шкаф в комнате отца найден")
	player.global_position = Vector3(-60.3, 3.55, -220.6)
	player.call("enter_hiding", wardrobe)
	cr.mode = "patrol"
	cr.route_i = 6
	cr.enemy.global_position = cr.ROUTE[5]
	await wait(20.0)
	check(cr.catches == 1, "Спрятался в шкаф: не поймал")
	player.call("exit_hiding")

	print("HOUSE CREATURE FAILURES: %d" % failures)
	get_tree().quit()
