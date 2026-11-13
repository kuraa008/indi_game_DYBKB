extends Node

# Проверка подвала. Запуск: --path game --headless res://scratch/test_basement.tscn
const MAIN := "res://scenes/Main.tscn"
const MAP := "res://scenes/Шоссе.json"
var failures := 0


func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func aim(player: CharacterBody3D, target: Vector3, from: Vector3) -> void:
	player.global_position = from
	player.velocity = Vector3.ZERO
	var head: Node3D = player.get("head")
	var eye := from + Vector3(0, head.position.y, 0)
	var to := target - eye
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await wait(0.35)


func shot(file: String) -> void:
	await wait(0.5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://" + file)


func _make_shots(ch: Node, player: CharacterBody3D) -> void:
	while player.get("is_in_cutscene") == true:
		await wait(0.5)
	await wait(0.6)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	await aim(player, Vector3(-58.5, -3.0, -225.2), Vector3(-55.5, -4.15, -228.0))
	await shot("bs_dark.png")
	ch.spots.toolbox.interact(player)
	ch.spots.fusebox.interact(player)
	ch._pull_switch(ch.RIGHT_SWITCH)
	await shot("bs_lit.png")

	ch.spots.post.interact(player)
	await shot("bs_post.png")
	ch._finish_modal()
	ch.spots.chest.interact(player)
	await shot("bs_code.png")
	for d in ["1", "8", "1", "5"]:
		ch._press_digit(d)
	await shot("bs_note7.png")
	ch._finish_modal()
	ch.spots.candle.interact(player)
	await aim(player, Vector3(-69.3, -3.2, -228.0), Vector3(-67.6, -4.15, -228.0))
	await shot("bs_shelf.png")
	player.global_position = Vector3(-69.0, -4.15, -228.0)
	await wait(0.2)
	ch._last_jar_at = -10.0
	for i in range(ch._jar_nodes.size()):
		ch._last_jar_at = -10.0
		ch.spots["jar%d" % i].interact(player)
	ch.spots.shelf.interact(player)
	await wait(2.0)
	player.set("is_in_cutscene", false)
	await aim(player, Vector3(-70.1, -4.15, -228.0), Vector3(-68.9, -4.15, -228.0))
	await shot("bs_hatch.png")


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
	var ch: Node = scene.get_node_or_null("BasementChapter")
	check(ch != null, "Подвал запущен")
	if ch == null:
		get_tree().quit(1)
		return
	var player: CharacterBody3D = GameManager.player_ref
	if "shots" in OS.get_cmdline_user_args():
		await _make_shots(ch, player)
		get_tree().quit()
		return
	var waited := 0.0
	while player.get("is_in_cutscene") == true and waited < 30.0:
		await wait(0.5)
		waited += 0.5
	print("wake took ", waited)
	check(player.get("is_in_cutscene") != true, "После пробуждения управление у игрока")
	# Здесь проверяются загадки; существо проверяет test_basement_creature
	ch.creature.stop()
	ch.creature.opening_done = true
	await wait(0.5)
	check(ch._lamp_lights.size() > 0, "Лампочка найдена на карте")
	check(ch._lamp_lights.all(func(l): return not l.visible), "Лампа выключена")
	check(ch._jar_nodes.size() >= 12 and ch.jars_left == ch._jar_nodes.size(), "Банки найдены: %d" % ch.jars_left)
	check(ch._shelf_nodes.size() > ch._jar_nodes.size(), "Стеллаж найден")
	var pool: Array = scene.get_children()
	if scene.get("nav_region"):
		pool.append_array(scene.get("nav_region").get_children())
	var map_notes := 0
	for n in pool:
		if n is Node3D and n.global_position.y < -2.8 and n.has_meta("item_type") and str(n.get_meta("item_type")).begins_with("note"):
			map_notes += 1
	check(map_notes == 0, "Пустые записки карты убраны (%d)" % map_notes)

	# Настоящий прицел
	var aims := {
		"toolbox": [Vector3(-55.2, -3.05, -230.22), Vector3(-55.2, -4.15, -229.0)],
		"fusebox": [Vector3(-65.0, -2.8, -219.5), Vector3(-65.0, -4.15, -220.9)],
		"post": [Vector3(-58.5, -2.9, -225.2), Vector3(-58.5, -4.15, -226.4)],
		"chest": [Vector3(-57.7, -3.8, -230.2), Vector3(-57.7, -4.15, -229.0)],
		"soldier": [Vector3(-64.15, -3.66, -229.85), Vector3(-64.1, -4.15, -228.9)],
		"cutters": [Vector3(-62.75, -3.54, -219.56), Vector3(-62.8, -4.15, -220.7)],
		"note1": [Vector3(-56.5, -3.25, -230.3), Vector3(-56.5, -4.15, -229.1)],
		"note2": [Vector3(-65.9, -3.03, -230.32), Vector3(-65.9, -4.15, -229.1)],
		"note3": [Vector3(-67.8, -4.15, -220.9), Vector3(-66.9, -4.15, -221.2)],
		"note4": [Vector3(-64.4, -3.64, -229.95), Vector3(-64.6, -4.15, -228.9)],
		"note5": [Vector3(-54.3, -4.15, -219.8), Vector3(-55.5, -4.15, -220.3)],
		"jar0": [Vector3(-69.25, -3.46, -228.64), Vector3(-68.2, -4.15, -228.6)],
	}
	for key in aims:
		await aim(player, aims[key][0], aims[key][1])
		var got: Node = player.call("_get_interactable")
		var seen := "ничего"
		if got:
			seen = str(got.name) + " " + str(got.get_meta("item_type", ""))
		check(got == ch.spots.get(key), "Прицел берёт: %s (%s)" % [key, seen])

	# Свет
	ch.spots.fusebox.interact(player)
	check(not ch.modal_open, "Без предохранителя щиток не открыть")
	ch.spots.toolbox.interact(player)
	check(ch.has_fuse, "Предохранитель взят")
	ch.spots.fusebox.interact(player)
	check(ch.modal_open, "Щиток открыт")
	check(GameManager.is_backpack_open, "Игрок заморожен")
	var a0: int = ch.alerts
	ch._pull_switch(0)
	check(ch.alerts == a0 + 1 and not ch.lit, "Неверный рубильник поднимает шум")
	ch.spots.fusebox.interact(player)
	ch._pull_switch(ch.RIGHT_SWITCH)
	await wait(0.15)
	check(ch.lit and ch._lamp_lights.all(func(l): return l.visible), "Лампочка зажглась")
	check(not GameManager.is_backpack_open, "Управление вернулось")
	check(not GameManager.ui_ref.backpack_overlay.visible, "Панель рюкзака не открылась")

	# Столб, записка, журнал
	ch.spots.post.interact(player)
	check(ch.post_seen and ch.modal_open, "Столб осмотрен")
	ch._finish_modal()
	await wait(0.15)
	# Настоящие нажатия: E на русской раскладке закрывает записку и не открывает её снова
	await aim(player, Vector3(-56.5, -3.25, -230.3), Vector3(-56.5, -4.15, -229.1))
	player.call("_try_interact")
	check(ch.modal_open and Phone.notes_count() == 1, "Записка открыта прицелом и попала в журнал")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_E
	key.keycode = 1059 as Key
	Input.parse_input_event(key)
	await wait(0.05)
	var up: InputEventKey = key.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await wait(0.4)
	check(not ch.modal_open, "E закрывает записку и она не открывается снова")
	check(not GameManager.is_backpack_open, "После записки игрок снова управляет")

	# Сундук
	ch.spots.chest.interact(player)
	for d in ["1", "2", "3", "4"]:
		ch._press_digit(d)
	check(not ch.chest_open and ch.modal_open and ch._code == "", "Неверный код сбрасывается")
	for d in ["1", "8", "1", "5"]:
		ch._press_digit(d)
	check(ch.chest_open and ch.modal_open, "Код 1815 открывает сундук и показывает записку №7")
	ch._finish_modal()
	await wait(0.15)
	check(Phone.notes_count() == 2 and ch.spots.has("candle"), "Записка №7 в журнале, появилась свеча")

	# Солдатик
	ch.spots.soldier.interact(player)
	check(player.get("is_in_cutscene") == true, "Воспоминание")
	await wait(10.5)
	check(player.get("is_in_cutscene") != true and not ch.spots.has("soldier"), "Солдатик взят, управление вернулось")

	# Свеча и сквозняк
	ch.spots.jar0.interact(player)
	check(ch.spots.has("jar0"), "До сквозняка банки не трогаем")
	await aim(player, Vector3(-55.85, -3.2, -229.95), Vector3(-55.85, -4.15, -228.7))
	var aimed: Node = player.call("_get_interactable")
	check(aimed == ch.spots.candle, "Прицел берёт свечу (%s)" % (str(aimed.get("hint")) if aimed else "ничего"))
	player.call("_try_interact")
	check(ch.has_candle, "Свеча в руке настоящим нажатием")
	player.global_position = Vector3(-60, -4.15, -225)
	await wait(0.2)
	check(not ch.draft_found and absf(ch._candle_flame.rotation_degrees.z) < 8.0, "Вдали пламя ровное")
	player.global_position = Vector3(-68.75, -4.15, -228.0)
	await wait(0.2)
	check(ch.draft_found, "Сквозняк найден")
	check(absf(ch._candle_flame.rotation_degrees.z) > 25.0, "Пламя клонится")

	# Банки
	var total: int = ch.jars_left
	a0 = ch.alerts
	ch.spots.jar0.interact(player)
	ch.spots.jar1.interact(player)
	check(ch.alerts == a0 + 1, "Слишком быстро: банка падает и шумит")
	for i in range(2, total):
		await wait(0.75)
		ch.spots["jar%d" % i].interact(player)
	check(ch.jars_left == 0 and ch.alerts == a0 + 1, "Банки сняты тихо")
	await wait(0.1)
	ch.spots.shelf.interact(player)
	await wait(2.0)
	check(ch.shelf_moved and ch.spots.has("hatch"), "Стеллаж отодвинут, виден люк")

	# Цепь
	ch.spots.hatch.interact(player)
	check(ch.chain_hits == 0, "Без болторезов цепь не перекусить")
	ch.spots.cutters.interact(player)
	for i in range(3):
		ch.spots.hatch.interact(player)
		if i < 2:
			check(not ch.chain_cut, "Попытка %d: цепь держится" % (i + 1))
			var hits: int = ch.chain_hits
			ch.spots.hatch.interact(player)
			check(ch.chain_hits == hits, "Сразу повторить нельзя")
			await wait(2.6)
	check(ch.chain_cut, "Цепь перекушена")

	# Ловушка у двери
	var before: int = ch.caught_count
	player.global_position = Vector3(-54.4, -2.65, -218.5)
	await wait(0.2)
	check(ch.caught_count == before + 1, "Дверь наверху: поимка")
	await wait(2.3)
	check(player.global_position.distance_to(ch.WAKE_POS) < 1.0 and player.get("is_in_cutscene") != true, "Возврат на место пробуждения")

	# Выход
	ch.spots.hatch.interact(player)
	await wait(1.0)
	check(ch.escaped, "Итан ушёл в люк")
	waited = 0.0
	while player.get("is_in_cutscene") == true and waited < 45.0:
		await wait(0.5)
		waited += 0.5
	print("tunnel took ", waited)
	check(player.global_position.y > -1.0, "После лаза Итан во дворе")

	print("BASEMENT FAILURES: %d" % failures)
	get_tree().quit()
