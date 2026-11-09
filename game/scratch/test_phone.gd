extends Node

# Проверка телефона. Запуск: --path game --headless res://scratch/test_phone.tscn
# Снимки экрана: то же без --headless и с аргументом -- shots
const PLAYER_SRC := """extends CharacterBody3D
var is_dead := false
var is_hiding := false
var is_in_cutscene := false
"""

const SHOT_DIR := "user://"

var failures := 0
var player: CharacterBody3D
var noises := 0


func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func press_key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.physical_keycode = code
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func shot(file: String) -> void:
	await wait(0.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_DIR + file)


func _ready() -> void:
	GameManager.set_process(false)
	GameManager.reset_state()
	GameManager.game_ended = false
	GameManager.noise_made.connect(func(_p, _r): noises += 1)

	if "shots" in OS.get_cmdline_user_args():
		await _make_shots()
		get_tree().quit()
		return

	check(not Phone.open(), "Без игрока телефон не открывается")
	check(not Phone.is_processing(), "Закрытый телефон не тратит кадры")
	check(Phone._built == false, "Интерфейс не строится заранее")
	_spawn_player()
	await get_tree().process_frame

	await press_key(KEY_P)
	check(Phone.is_open(), "P открывает телефон")
	check(GameManager.is_backpack_open, "Игрок заморожен, пока телефон в руках")
	await press_key(KEY_TAB)
	check(GameManager.is_backpack_open and Phone.is_open(), "Tab не ломает блокировку")

	for page in [Phone.Page.NEWS, Phone.Page.CHATS, Phone.Page.CONTACTS]:
		Phone._open_page(page)
		await get_tree().process_frame
		check(Phone._list.get_child_count() >= 1, "Страница %d заполнена" % page)

	Phone._open_thread("Одногруппники")
	await get_tree().process_frame
	check(Phone._page == Phone.Page.THREAD and Phone._list.get_child_count() == 7, "Переписка открывается")
	await press_key(KEY_ESCAPE)
	check(Phone._page == Phone.Page.CHATS and Phone.is_open(), "Esc из переписки возвращает к чатам")
	await press_key(KEY_ESCAPE)
	check(Phone.is_open() and Phone._page == Phone.Page.HOME, "Esc из приложения выходит на главный экран")
	await press_key(KEY_ESCAPE)
	check(not Phone.is_open(), "Esc закрывает телефон")
	await wait(0.1)
	check(not GameManager.is_backpack_open, "После закрытия игрок снова управляет")
	await get_tree().process_frame
	check(not Phone.is_processing(), "Закрытый телефон снова не тратит кадры")

	GameManager.is_backpack_open = true
	check(not Phone.open(), "При открытом рюкзаке не открывается")
	GameManager.is_backpack_open = false
	player.is_in_cutscene = true
	check(not Phone.open(), "В кат-сцене не открывается")
	player.is_in_cutscene = false
	Phone.enabled = false
	check(not Phone.open(), "Можно отключить по сюжету")
	Phone.enabled = true

	Phone.add_message("Неизвестный", "Ты дома?")
	check(Phone.unread_count() == 1 and Phone._toast.visible, "Новое сообщение: всплывашка и счётчик")
	check(not Phone._body.visible, "Всплывашка не показывает сам телефон")
	Phone.open(Phone.Page.CHATS)
	Phone._open_thread("Неизвестный")
	check(Phone.unread_count() == 0, "Прочитал: счётчик сброшен")
	check(not Phone._toast.visible, "Открытый телефон убирает всплывашку")
	Phone.close()

	# Ответ
	var box := {}
	var run := func(opts: Dictionary) -> void:
		box.result = await Phone.incoming_call("Неизвестный номер", opts)
	box.erase("result")
	run.call({})
	await get_tree().process_frame
	check(Phone.is_ringing() and Phone.is_open(), "Входящий звонок открывает экран вызова")
	check(GameManager.is_backpack_open, "Во время звонка игрок заморожен")
	check(Phone._decline_btn != null and Phone._answer_btn != null, "Есть обе кнопки")
	Phone._answer_btn.pressed.emit()
	await get_tree().process_frame
	check(Phone.is_ringing() and not box.has("result"), "Случайное нажатие в первые доли секунды не принимает звонок")
	check(not Phone.can_open(), "Пока идёт звонок, второй экран не открыть")
	await wait(0.55)
	Phone._answer_btn.pressed.emit()
	await get_tree().process_frame
	check(box.get("result") == Phone.ANSWERED, "Ответить")
	await wait(0.1)
	check(not Phone.is_open() and not GameManager.is_backpack_open, "После ответа телефон убран")

	# Сброс
	box.erase("result")
	run.call({})
	await wait(0.55)
	Phone._decline_btn.pressed.emit()
	await get_tree().process_frame
	check(box.get("result") == Phone.DECLINED, "Сбросить")

	# Сброс с перезвоном, как в прологе
	box.erase("result")
	run.call({"repeat_after": 0.4, "decline_line": "Да что ж такое…"})
	await wait(0.55)
	Phone._decline_btn.pressed.emit()
	await get_tree().process_frame
	check(not Phone.is_ringing() and not box.has("result"), "После сброса пауза перед перезвоном")
	await wait(0.6)
	check(Phone.is_ringing(), "Перезванивают снова")
	await wait(0.55)
	Phone._answer_btn.pressed.emit()
	await get_tree().process_frame
	check(box.get("result") == Phone.ANSWERED, "После перезвона можно ответить")

	# Нельзя сбросить
	box.erase("result")
	run.call({"can_decline": false, "ring_seconds": 0.5})
	await get_tree().process_frame
	check(Phone._decline_btn == null, "Кнопку «Сбросить» можно убрать")
	await wait(0.8)
	check(box.get("result") == Phone.MISSED, "Без ответа звонок заканчивается")

	# Шум для пряток
	noises = 0
	box.erase("result")
	run.call({"noise_radius": 20.0, "ring_seconds": 2.8})
	await wait(3.0)
	check(noises == 2, "Каждый гудок слышит враг (%d)" % noises)

	# Шкаф: звонок приходит и туда
	player.is_hiding = true
	box.erase("result")
	run.call({})
	await get_tree().process_frame
	check(Phone.is_ringing(), "Звонок застаёт и в шкафу")
	await wait(0.55)
	Phone._decline_btn.pressed.emit()
	await get_tree().process_frame
	player.is_hiding = false

	# Сохранение
	var state: Dictionary = Phone.get_state()
	Phone.clear_content()
	check(Phone._contacts.is_empty(), "Очистка")
	Phone.set_state(state)
	check(Phone._contacts.size() == 2 and Phone._news.size() == 2, "Состояние восстанавливается")

	# Смерть и смена сцены во время звонка
	box.erase("result")
	run.call({})
	await wait(0.1)
	player.is_dead = true
	await wait(0.1)
	check(box.get("result") == Phone.MISSED and not Phone.is_open(), "Смерть обрывает звонок")
	player.is_dead = false
	box.erase("result")
	run.call({})
	await wait(0.1)
	player.free()
	await wait(0.1)
	check(box.get("result") == Phone.MISSED and not Phone.is_open(), "Игрок исчез: звонок и блокировка сняты")
	await wait(0.1)
	check(not GameManager.is_backpack_open, "Флаг рюкзака не залип")

	print("PHONE FAILURES: %d" % failures)
	get_tree().quit()


func _spawn_player() -> void:
	player = CharacterBody3D.new()
	var scr := GDScript.new()
	scr.source_code = PLAYER_SRC
	scr.reload()
	player.set_script(scr)
	add_child(player)
	GameManager.player_ref = player


func _make_shots() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.12, 0.1)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.add_child(bg)
	add_child(layer)
	_spawn_player()
	await get_tree().process_frame
	Phone.add_message("Одногруппники", "Длинное сообщение, чтобы проверить, как текст переносится внутри пузыря.")
	Phone.open()
	check(Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE, "Курсор виден")
	await shot("phone_home.png")
	Phone._open_page(Phone.Page.NEWS)
	await shot("phone_news.png")
	Phone._open_page(Phone.Page.CHATS)
	await shot("phone_chats.png")
	Phone._open_thread("Одногруппники")
	await shot("phone_thread.png")
	Phone._open_page(Phone.Page.CONTACTS)
	await shot("phone_contacts.png")
	Phone.close()
	await wait(0.1)
	check(Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED, "Курсор снова захвачен")
	Phone.incoming_call("Неизвестный номер")
	await shot("phone_call.png")
	Phone._resolve_call(Phone.MISSED)
	GameManager.player_ref = null
