extends Node

# Проверка «Обычного дня». Запуск: --path game --headless res://scratch/test_prologue.tscn
# Снимки: то же без --headless и с аргументом -- shots
const MAIN := "res://scenes/Main.tscn"
const MAP := "res://scenes/Квартира.json"
const SHOT_DIR := "user://"

var failures := 0
var shots := false


func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func shot(file: String) -> void:
	if not shots:
		return
	await wait(0.5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + file)


func look_at_point(pos: Vector3, from: Vector3) -> void:
	var p: CharacterBody3D = GameManager.player_ref
	p.global_position = from
	p.velocity = Vector3.ZERO
	var head: Node3D = p.get("head")
	var eye := from + Vector3(0, head.position.y, 0)
	var to := pos - eye
	p.rotation.y = atan2(-to.x, -to.z)
	head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


func _ready() -> void:
	shots = "shots" in OS.get_cmdline_user_args()
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	GameManager.reset_state()
	GameManager.active_map_path = MAP
	get_tree().change_scene_to_file(MAIN)
	await wait(1.5)
	var scene := get_tree().current_scene
	var pro: Node = scene.get_node_or_null("PrologueApartment")
	check(pro != null, "Сценарий пролога стоит на карте квартиры")
	check(scene.get_node_or_null("ApartmentCall") == null, "Старого экрана звонка нет")
	if pro == null:
		get_tree().quit(1)
		return
	var player: CharacterBody3D = GameManager.player_ref
	if shots:
		# На снимках окно игры не должно ловить настоящую мышь и клавиатуру
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
	check(is_instance_valid(player), "Игрок на месте")
	var missions: MissionTracker = null
	for child in pro.get_children():
		if child is MissionTracker:
			missions = child
	check(missions != null and missions.current_text() != "", "Задача показана в углу")
	await wait(0.8)
	print("task: ", missions.current_text())
	var baked: MeshInstance3D = null
	var props := scene.get_node("ApartmentScene/ApartmentProps")
	for child in props.get_children():
		if child is MeshInstance3D:
			baked = child
	check(baked != null and not baked.visible, "Исходный меш одежды скрыт")
	check(baked.mesh.get_aabb().size.y < 1.2 and baked.mesh.get_aabb().position.y < 0.1, "Скрыт именно меш одежды, он лежит у пола")

	if not shots:
		# Настоящий прицел игрока: каждая вещь должна ловиться лучом, а не кроватью или мебелью
		var aims := {
			"pizza": [Vector3(0.05, 0.5, 0.25), Vector3(0.05, 0.03, -0.9)],
			"turka": [Vector3(5.215, 1.0, -5.88), Vector3(5.2, 0.03, -4.9)],
			"shirt": [Vector3(1.12, 0.02, -3.07), Vector3(1.1, 0.03, -4.2)],
			"jeans": [Vector3(-0.03, 0.02, -3.32), Vector3(0.0, 0.03, -4.4)],
			"hoodie": [Vector3(1.7, 0.02, -4.75), Vector3(0.6, 0.03, -4.4)],
			"socks": [Vector3(0.745, 0.02, -4.975), Vector3(0.7, 0.03, -3.9)],
			"washer": [Vector3(6.53, 0.5, 0.5), Vector3(5.2, 0.03, 0.5)],
			"sofa": [Vector3(0.25, 0.6, 1.4), Vector3(1.6, 0.03, 0.9)],
		}
		for key in aims:
			look_at_point(aims[key][0], aims[key][1])
			await wait(0.35)
			var got: Node = player.call("_get_interactable")
			check(got == pro.spots[key], "Прицел берёт: %s (%s)" % [key, str(got.name) if got else "ничего"])
	if shots:
		look_at_point(Vector3(0.05, 0.5, 0.25), Vector3(0.05, 0.03, -0.9))
		await shot("pro_pizza_before.png")
	pro.spots.sofa.interact(player)
	check(not pro.on_sofa, "Рано на диван: сначала дела")
	pro.spots.washer.interact(player)
	check(not pro.washer_running, "Стиралка без одежды не запускается")

	pro.spots.pizza.interact(player)
	check(pro.pizza_eaten and not pro.spots.has("pizza"), "Пицца съедена")
	await shot("pro_pizza_after.png")
	await wait(0.9)
	print("task: ", missions.current_text())
	check(missions.current_text().contains("кофе"), "Следующая задача: кофе")

	check(not pro.spots.has("stove"), "Плиту нельзя тереть до кофе")
	if shots:
		look_at_point(Vector3(5.25, 0.95, -5.9), Vector3(5.25, 0.03, -4.8))
	pro.spots.turka.interact(player)
	check(pro.coffee_started and not pro.coffee_spilled, "Кофе поставлен и греется")
	await wait(1.0)
	await shot("pro_flame.png")
	await wait(pro.BOIL_SECONDS - 0.5 - (2.0 if shots else 0.0))
	await shot("pro_foam.png")
	await wait(1.2 if not shots else 2.0)
	check(pro.coffee_spilled, "Кофе убежал")
	check(pro.spots.has("stove"), "Появилось действие «оттереть плиту»")
	await shot("pro_stain.png")
	if not shots:
		look_at_point(Vector3(5.3, 0.93, -5.95), Vector3(5.3, 0.03, -4.9))
		await wait(0.35)
		check(player.call("_get_interactable") == pro.spots.stove, "Прицел берёт плиту")
	for i in range(4):
		pro.spots.stove.interact(player)
		await get_tree().process_frame
	check(pro.wipes == 4 and not pro.spots.has("stove"), "Плита оттёрта за четыре движения")
	await wait(0.2)

	if shots:
		look_at_point(Vector3(1.1, 0.02, -4.0), Vector3(0.4, 0.03, -5.6))
		await shot("pro_clothes.png")
	for key in ["shirt", "jeans", "hoodie", "socks"]:
		pro.spots[key].interact(player)
	await wait(0.2)
	check(pro.clothes_left == 0, "Одежда собрана")
	if shots:
		await shot("pro_clothes_gone.png")
		look_at_point(Vector3(6.53, 0.6, 0.5), Vector3(5.2, 0.03, 0.5))
	pro.spots.washer.interact(player)
	check(pro.washer_running, "Стирка запущена")
	await shot("pro_washer.png")
	await wait(1.0)

	pro.spots.sofa.interact(player)
	check(pro.on_sofa, "Итан на диване")
	check(player.get("is_in_cutscene") == true, "Игрок обездвижен")
	await wait(2.3)
	check(Phone.is_open(), "Телефон открылся сам")
	await shot("pro_sofa_phone.png")
	Phone._open_page(Phone.Page.NEWS)
	await wait(0.1)
	Phone._open_page(Phone.Page.CONTACTS)
	await wait(pro.QUIET_BEFORE_CALL + 0.8)
	check(Phone.is_ringing(), "Звонок пришёл")
	check(Phone._caller == pro.CALLER, "Звонит неизвестный номер")
	await shot("pro_call.png")
	await wait(0.55)
	Phone._decline_btn.pressed.emit()
	await wait(0.2)
	check(not Phone.is_ringing(), "Сброс")
	await wait(pro.REDIAL_AFTER + 0.4)
	check(Phone.is_ringing(), "Перезванивают")
	await wait(0.55)
	Phone._answer_btn.pressed.emit()
	await wait(1.5)
	var after := get_tree().current_scene
	check(after != null and after.scene_file_path.contains("PoliceCall"), "Ответ ведёт в кат-сцену «Звонок»")
	check(GameManager.active_map_path.contains("Улица"), "После кат-сцены следующая карта улица")
	check(not Phone.is_open() and not Phone.allow_in_cutscene, "Телефон убран, разрешение снято")
	check(not GameManager.is_backpack_open, "Блокировка снята")

	print("PROLOGUE FAILURES: %d" % failures)
	get_tree().quit()
