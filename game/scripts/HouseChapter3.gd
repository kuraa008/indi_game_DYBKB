extends "res://scripts/BasementChapter.gd"

# Глава 3, комната отца (сюжет Досыма). Начинается во дворе, когда Итан выбрался из лаза.
#
# Монтировка у задней стены → три доски на окне кладовки → в дом → комната отца →
# тряпки из комода под ножки кровати → кровать отодвигается тихо → наступить на доски,
# одна скрипит → под ней коробка, заперта → письма Сэма на столе → ключ в часах с
# кукушкой в коридоре (кукушку придержать, иначе бьют) → коробка: записка отца и череп →
# кат-сцена «Это… моё» (Ch3Mine).
#
# Предметы — модели HouseProps (Куро, узел в главе «Шоссе»): здесь только действия,
# а движения делают их методы (tear_off, move_bed, lift_plank, open_box, take_key…).
# Сарая на карте нет, поэтому монтировка лежит у задней стены дома.

const CH3_MINE := "res://scenes/cutscenes/Ch3Mine.tscn"
const HouseCreature := preload("res://scripts/HouseCreature.gd")
const FATHER_ROOM_POINT := Vector3(-62.5, 3.55, -221.0)
const MAIN_SCENE := "res://scenes/Main.tscn"
const NEXT_MAP := "res://scenes/Лесная_тропа.json"   # глава 4 (пока без гаража)

const CROWBAR_AT := Vector3(-59.6, 0.62, -231.62)
const WINDOW := Vector3(-62.0, 1.85, -231.4)
const INSIDE_PANTRY := Vector3(-62.0, 0.2, -230.2)
const BOARD_PRY_COOLDOWN := 1.4
const DRESSER_ID := 1215
const BED_ID := 1212
const BED_SHIFT := Vector3(1.7, 0, 0)
const RAGS_NEEDED := 4
const CUCKOO_HOLD_WINDOW := 1.6

const LETTERS := "«Итан, папа сегодня спрашивал про тебя. Я сказал, что ты сдаёшь экзамены. Он улыбнулся. Я опять не отправлю это письмо: он запретил тебя звать».\n\n«Оно снова ходило вокруг дома. Папа говорит, что, пока ты далеко, ты в безопасности. Я ненавижу, что ты думаешь, будто мы тебя бросили. Но лучше так».\n\n«Папы больше нет. Оно пришло ночью. Я слышал, как оно говорило его голосом. Ключ от папиной коробки я спрятал там, где мы прятали секреты. Ты помнишь. Если ты когда-нибудь это прочитаешь, значит, ты всё-таки вернулся. Прости меня»."
const FATHER_LAST := "Это череп того самого оленя. Крейн надел его шкуру, и с тех пор это его настоящее тело. Шкуры, которые оно носит, — просто одежда. Пока череп цел, оно не умрёт.\n\nЯ нашёл череп в его логове, у старого колодца, и украл его. С тех пор оно не могло зайти в дом, пока я был жив и держал его рядом.\n\nЧтобы его остановить, нужно сжечь череп и назвать его настоящим именем. Не скинволкер, не оно. Джозеф Крейн. Оно забыло, кем было. Когда вспомнит, оно станет тем, кем было на самом деле: мёртвым человеком.\n\nЯ не решился. Я боялся, что, если ошибусь, оно заберёт мальчиков.\n\nСэм, если ты это читаешь, — сожги его. Итан, если это ты, — прости, что держал тебя так далеко. Я люблю вас обоих."

var has_crowbar := false
var boards_left := 0
var inside := false
var in_father_room := false
var rags_placed := 0
var has_rags := false
var bed_moved := false
var board_found := false
var board_lifted := false
var letters_read := false
var has_key := false
var clock_rang := false
var box_open := false
var skull_taken := false

var _last_pry := -10.0
var _cuckoo_open_at := -1.0
var _bed: Node3D
var _props: Node


func _ready() -> void:
	name = "HouseChapter3"
	_build_ui()
	_begin_house.call_deferred()


func _begin_house() -> void:
	while not is_instance_valid(GameManager.player_ref) or not GameManager.player_ref.is_inside_tree():
		await get_tree().process_frame
	_player = GameManager.player_ref
	_camera = _player.get("camera")
	_index_objects()
	_remove_chapter_one_spots()
	_bed = _objects.get(BED_ID)
	var chapter := get_parent().get_node_or_null("HighwayChapter")
	_props = chapter.get_node_or_null("HouseProps") if chapter else null
	# HouseProps убирает старые заглушки карты отложенно: ждём кадр
	await get_tree().process_frame
	if _props:
		_props.show_box(false)
		_props.plank_stepped.connect(_on_plank_stepped)
	_add_house_spots()
	_start_house_missions()
	_light_phone()
	creature = HouseCreature.new()
	creature.chapter = self
	add_child(creature)
	creature.begin(_player)


# Свой фонарик разбит, светит телефон: ночью в доме иначе ничего не видно
func _light_phone() -> void:
	_player.set("flashlight_on", true)
	var torch = _player.get("flashlight")
	if torch != null:
		torch.visible = true
	var hands = _player.get("player_hands")
	if hands != null:
		hands.call("set_flashlight_state", true, 1.0)


# Точки главы 1 (кровать, дневник) снова запускали бы монологи первой главы
func _remove_chapter_one_spots() -> void:
	var chapter := get_parent().get_node_or_null("HighwayChapter")
	if chapter == null:
		return
	for child in chapter.get_children():
		if child is Area3D and child.has_method("get_interaction_hint"):
			child.queue_free()


func _add_house_spots() -> void:
	_crowbar_mesh()
	_spot("crowbar", CROWBAR_AT, Vector3(0.4, 1.1, 0.4), "Взять монтировку", _on_crowbar)
	_outline("crowbar", get_node_or_null("Crowbar"))
	if _props:
		var boards: Array = _props.get("pantry_boards")
		for i in range(boards.size()):
			var board: Node3D = boards[i]
			boards_left += 1
			_spot("board%d" % i, board.global_position + Vector3(0, 0, -0.12), Vector3(1.9, 0.36, 0.3), "Оторвать доску", _on_board.bind(i))
			_outline("board%d" % i, board)
	_spot("dresser", _obj_pos(DRESSER_ID) + Vector3(0, 0.6, 0), Vector3(1.3, 1.0, 0.7), "Взять старые носки и тряпки", _on_dresser)
	_outline("dresser", _objects.get(DRESSER_ID))
	_spot("bed", _obj_pos(BED_ID) + Vector3(0, 0.55, 0), Vector3(1.7, 0.9, 2.3), "Отодвинуть кровать", _on_bed)
	_outline("bed", _bed)
	if _props:
		var lid: Node3D = _props.get("letters_lid")
		_spot("letters", lid.global_position + Vector3(0, 0.05, 0), Vector3(0.6, 0.3, 0.45), "Открыть ящик с письмами", _on_letters)
		_outline("letters", lid.get_parent() if lid.get_parent() is Node3D else lid)


func _obj_pos(id: int) -> Vector3:
	var n = _objects.get(id)
	return (n as Node3D).global_position if n is Node3D else Vector3.ZERO


func _crowbar_mesh() -> void:
	var root := Node3D.new()
	root.name = "Crowbar"
	add_child(root)
	root.global_position = CROWBAR_AT
	root.rotation_degrees = Vector3(14, 0, 8)
	var iron := _mat(Color(0.2, 0.08, 0.06), 0.55, 0.6)
	_part(root, _cyl(0.014, 0.95), Vector3.ZERO, iron)
	_part(root, _cyl(0.014, 0.12), Vector3(0.05, 0.47, 0), iron, Vector3(0, 0, 60))


func _start_house_missions() -> void:
	_missions = MissionTracker.new()
	_missions.setup([
		{"text": "Попасть в дом", "done": func(): return inside},
		{"text": "Попасть в комнату отца", "done": func(): return in_father_room},
		{"text": "Найти скрипучую доску", "done": func(): return board_lifted},
		{"text": "Найти ключ", "done": func(): return has_key},
		{"text": "Открыть коробку", "done": func(): return box_open},
	])
	add_child(_missions)


# ─── Окно кладовки ──────────────────────────────────────────

func _on_crowbar() -> void:
	has_crowbar = true
	_drop_spot("crowbar")
	var bar := get_node_or_null("Crowbar")
	if bar:
		bar.queue_free()
	_play(SFX + "bag_item_select.wav", -6.0)
	_toast("Монтировка")


func _on_board(index: int) -> void:
	if not has_crowbar:
		_say("Голыми руками не оторвать. Нужна монтировка.", 2.4)
		return
	if _clock - _last_pry < BOARD_PRY_COOLDOWN:
		return
	_last_pry = _clock
	_drop_spot("board%d" % index)
	_play(CUT + "chair_scrape.wav", -6.0)
	_alert("board")
	if _props:
		var board: Node3D = (_props.get("pantry_boards") as Array)[index]
		_disable_collision(board)
		_props.tear_off(index)
	boards_left -= 1
	if boards_left <= 0:
		_spot("window", WINDOW, Vector3(1.6, 1.2, 0.5), "Залезть в окно", _on_window)


func _on_window() -> void:
	if _busy:
		return
	_busy = true
	_drop_spot("window")
	_player.set("is_in_cutscene", true)
	_play(CUT + "body_shift.wav", -6.0)
	await _fade(1.0, 0.4)
	_player.global_position = INSIDE_PANTRY
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	inside = true
	if creature:
		creature.checkpoint = INSIDE_PANTRY
	await get_tree().create_timer(0.4, false).timeout
	await _fade(0.0, 0.6)
	_player.set("is_in_cutscene", false)
	_busy = false


# ─── Кровать и скрипучая доска ──────────────────────────────

func _on_dresser() -> void:
	has_rags = true
	_drop_spot("dresser")
	_play(CUT + "hand_slide_wood.wav", -8.0)
	_toast("Старые носки и тряпки")


func _on_bed() -> void:
	if bed_moved or _busy:
		return
	if not has_rags:
		_play(CUT + "chair_scrape.wav", -10.0)
		_say("Ножки скребут по полу… Под них бы что-то подложить.", 2.6)
		return
	if rags_placed < RAGS_NEEDED:
		rags_placed += 1
		_play(CUT + "hand_slide_wood.wav", -12.0)
		if rags_placed < RAGS_NEEDED:
			(spots["bed"] as StorySpot).hint = "[ЛКМ / E]  Подложить тряпку под ножку (%d/%d)" % [rags_placed, RAGS_NEEDED]
		else:
			(spots["bed"] as StorySpot).hint = "[ЛКМ / E]  Отодвинуть кровать"
		return
	_busy = true
	_drop_spot("bed")
	_play(CUT + "body_shift.wav", -10.0)
	if _props:
		_props.move_bed(true)
	await get_tree().create_timer(1.45, false).timeout
	bed_moved = true
	_busy = false
	_say("Тихо… Теперь доски.", 2.0)


# Игрок сам наступает на светлые доски: скрипит только одна (сигнал HouseProps).
# Запасной путь по позиции нужен, если сигнал не придёт.
func _on_plank_stepped() -> void:
	if bed_moved and not board_found:
		_find_board()


func _check_creaky_board() -> void:
	if not bed_moved or board_found or _props == null:
		return
	var p: Vector3 = _player.global_position
	var c: Vector3 = _props.PLANK_AT
	if absf(p.y - c.y) < 0.6 and absf(p.x - c.x) < 0.9 and absf(p.z - c.z) < 0.35:
		_find_board()


func _find_board() -> void:
	board_found = true
	_play(CUT + "door_handle_slow.wav", -2.0)
	_alert("creaky_board")
	_say("Вот она.", 1.6)
	var plank: Node3D = _props.get("loose_plank")
	_spot("creaky", plank.global_position + Vector3(0, 0.08, 0), Vector3(1.7, 0.2, 0.4), "Поднять доску", _on_lift_board)
	_outline("creaky", plank)


func _on_lift_board() -> void:
	board_lifted = true
	_drop_spot("creaky")
	_play(CUT + "lid_open.wav", -8.0)
	_props.lift_plank(true)
	var box: Node3D = _props.get("box")
	_spot("box", box.global_position + Vector3(0, 0.1, 0), Vector3(0.6, 0.32, 0.5), "Открыть коробку", _on_box)
	_outline("box", box)


# ─── Письма, часы, коробка ──────────────────────────────────

func _on_letters() -> void:
	if not letters_read and _props:
		_props.open_letters(true)
	letters_read = true
	Phone.add_note("Письма Сэма", LETTERS)
	_play(CUT + "sheet_flutter.wav", -12.0)
	_show_paper("Письма Сэма", LETTERS, func(): _after_letters())


func _after_letters() -> void:
	if spots.has("clock") or has_key:
		return
	_say("Там, где мы прятали секреты… Часы с кукушкой в коридоре.", 3.2)
	var clock: Node3D = _props.get("clock")
	_spot("clock", _props.CLOCK_AT, Vector3(0.5, 0.7, 0.6), "Открыть тайник в часах", _on_clock)
	_outline("clock", clock)


func _on_clock() -> void:
	if has_key:
		return
	if _cuckoo_open_at < 0.0:
		_cuckoo_open_at = _clock
		_props.open_secret(true)
		_play(SFX + "safe_click.wav", -10.0)
		(spots["clock"] as StorySpot).hint = "[ЛКМ / E]  Придержать кукушку и достать ключ"
		return
	_take_key(false)


func _take_key(rang: bool) -> void:
	has_key = true
	clock_rang = rang
	_drop_spot("clock")
	_props.take_key()
	if rang:
		_props.cuckoo(true)
		_play(SFX + "clock_bell.wav", -2.0)
		_alert("clock")
		_say("Часы!.. Оно услышит.", 2.0)
	else:
		_play(SFX + "bag_item_select.wav", -8.0)
		_toast("Ключ от коробки")


func _on_box() -> void:
	if box_open:
		_show_paper("Последняя записка отца", FATHER_LAST)
		return
	if not has_key:
		_play(SFX + "safe_click.wav", -8.0)
		_say("Заперта на ключ.", 1.6)
		return
	box_open = true
	_props.unlock()
	_props.open_box(true)
	_outline("box", _props.get("skull"))
	_play(SFX + "safe_open.wav", -6.0)
	Phone.add_note("Последняя записка отца", FATHER_LAST)
	(spots["box"] as StorySpot).hint = "[ЛКМ / E]  Взять череп"
	(spots["box"] as StorySpot).on_use = _on_skull
	_show_paper("Последняя записка отца", FATHER_LAST)


func _on_skull() -> void:
	if skull_taken:
		return
	skull_taken = true
	_drop_spot("box")
	(_props.get("skull") as Node3D).visible = false
	if creature:
		creature.stop()
	_player.set("is_in_cutscene", true)
	GameManager.active_map_path = NEXT_MAP
	Cutscene.play(get_tree(), CH3_MINE, MAIN_SCENE, {"from_gameplay": true})


# ─── Кадр ───────────────────────────────────────────────────

func _process(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(_player):
		return
	if modal_open:
		GameManager.is_backpack_open = true
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	var p: Vector3 = _player.global_position
	if not in_father_room and p.y > 2.8 and p.x < -59.3 and p.z > -225.0 and p.x > -71.0:
		in_father_room = true
		if creature:
			creature.checkpoint = FATHER_ROOM_POINT
		_say("Комната отца… Под кроватью, где скрипит доска.", 2.8)
	if not inside and p.x > -71.0 and p.x < -53.2 and p.z > -231.0 and p.z < -219.0:
		inside = true
		if creature and not in_father_room:
			creature.checkpoint = INSIDE_PANTRY
	_check_creaky_board()
	# Не придержал кукушку: часы бьют
	if _cuckoo_open_at >= 0.0 and not has_key and _clock - _cuckoo_open_at > CUCKOO_HOLD_WINDOW:
		_take_key(true)
