extends Node

# Проверка главы 3. Запуск: --path game --headless res://scratch/test_chapter3.tscn
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
	var to := target - (from + Vector3(0, head.position.y, 0))
	player.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	await wait(0.35)


func shot(file: String) -> void:
	if not ("shots" in OS.get_cmdline_user_args()):
		return
	await wait(0.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://" + file)


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
	var basement: Node = scene.get_node("BasementChapter")
	var player: CharacterBody3D = GameManager.player_ref
	while player.get("is_in_cutscene") == true:
		await wait(0.5)
	await wait(0.5)
	# Подвал пройден: глава 3 начинается во дворе
	basement._finish_basement()
	player.global_position = Vector3(-59.2, 0.15, -239.35)
	await wait(0.5)
	var ch: Node = scene.get_node("HouseChapter3")
	# Здесь проверяются загадки; существо в доме проверяет test_house_creature
	await wait(0.2)
	ch.creature.stop()
	var trackers := 0
	for t in scene.find_children("*", "MissionTracker", true, false):
		if t.is_visible_in_tree() if t is CanvasItem else (t as CanvasLayer).visible and not t.is_queued_for_deletion():
			trackers += 1
	check(trackers == 1, "В углу одна задача, а не две (%d)" % trackers)
	check(player.get("flashlight_on") == true, "Светит фонарик телефона")
	check(ch.spots.size() >= 6, "Точки главы 3 расставлены (%d)" % ch.spots.size())
	check(ch.boards_left == 3, "Три доски на окне кладовки")
	check(ch._bed != null and ch._props != null, "Кровать и предметы главы 3 найдены")
	check(not ch._props.box.visible, "Коробку пока не видно")
	var leftovers := 0
	for c in scene.get_node("HighwayChapter").get_children():
		if c is Area3D and c.has_method("get_interaction_hint") and not c.is_queued_for_deletion():
			leftovers += 1
	check(leftovers == 0, "Точки главы 1 убраны")

	var aims := {
		"crowbar": [Vector3(-59.6, 0.62, -231.62), Vector3(-59.6, 0.15, -233.2)],
		"board1": [Vector3(-62.0, 1.88, -231.4), Vector3(-62.0, 0.15, -233.4)],
	}
	for key in aims:
		await aim(player, aims[key][0], aims[key][1])
		var got: Node = player.call("_get_interactable")
		check(got == ch.spots.get(key), "Прицел берёт: %s" % key)
	await shot("ch3_window.png")

	ch.spots.board0.interact(player)
	check(ch.boards_left == 3, "Без монтировки доску не оторвать")
	ch.spots.crowbar.interact(player)
	check(ch.has_crowbar, "Монтировка взята")
	for i in range(3):
		ch.spots["board%d" % i].interact(player)
		if i < 2:
			var left: int = ch.boards_left
			ch.spots["board%d" % (i + 1)].interact(player)
			check(ch.boards_left == left, "Доски по одной, с паузой")
			await wait(1.5)
	check(ch.boards_left == 0 and ch.spots.has("window"), "Окно свободно")
	ch.spots.window.interact(player)
	await wait(1.8)
	check(ch.inside and player.global_position.distance_to(ch.INSIDE_PANTRY) < 1.0, "Итан в кладовке")
	await shot("ch3_pantry.png")

	# Комната отца
	player.global_position = Vector3(-66.0, 3.55, -222.5)
	await wait(0.3)
	check(ch.in_father_room, "Комната отца")
	await aim(player, ch._obj_pos(ch.BED_ID) + Vector3(0, 0.5, 0), Vector3(-67.0, 3.55, -222.6))
	check(player.call("_get_interactable") == ch.spots.bed, "Прицел берёт кровать")
	await shot("ch3_room.png")
	ch.spots.bed.interact(player)
	check(not ch.bed_moved and ch.rags_placed == 0, "Без тряпок кровать скребёт и не двигается")
	ch.spots.dresser.interact(player)
	for i in range(4):
		ch.spots.bed.interact(player)
	check(ch.rags_placed == 4 and not ch.bed_moved, "Тряпки под четырьмя ножками")
	ch.spots.bed.interact(player)
	await wait(1.7)
	check(ch.bed_moved, "Кровать отодвинута тихо")
	player.global_position = ch._props.loose_plank.global_position + Vector3(0.0, 0.06, 0)
	await wait(0.3)
	check(ch.board_found and ch.spots.has("creaky"), "Наступил: доска скрипит")
	ch.spots.creaky.interact(player)
	check(ch.board_lifted and ch._props.box.visible and ch.spots.has("box"), "Под доской коробка")
	ch.spots.box.interact(player)
	check(not ch.box_open, "Коробка заперта")

	# Письма и часы
	ch.spots.letters.interact(player)
	check(ch.modal_open and Phone.notes_count() >= 1, "Письма прочитаны, в журнале телефона")
	ch._finish_modal()
	await wait(0.2)
	check(ch.spots.has("clock"), "Подсказка про часы с кукушкой")
	ch.spots.clock.interact(player)
	ch.spots.clock.interact(player)
	check(ch.has_key and not ch.clock_rang, "Кукушку придержал: ключ без шума")

	# Коробка и череп
	ch.spots.box.interact(player)
	check(ch.box_open and ch.modal_open, "Коробка открыта, записка отца")
	ch._finish_modal()
	await wait(0.2)
	ch.spots.box.interact(player)
	check(ch.skull_taken, "Череп взят")
	var next_map: String = ch.NEXT_MAP
	await wait(1.5)
	if DisplayServer.get_name() == "headless":
		check(GameManager.active_map_path == next_map, "Запрошена кат-сцена «Это… моё»")
	else:
		check(get_tree().current_scene.scene_file_path.contains("Ch3Mine"), "Кат-сцена «Это… моё»")

	print("CHAPTER3 FAILURES: %d" % failures)
	get_tree().quit()
