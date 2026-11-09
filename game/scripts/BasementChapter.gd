extends Node3D

# Глава 2, подвал: загадки по сюжету Досыма. Запускается на карте «Шоссе», когда Итан
# очнулся в подвале (GameManager.wake_in_basement).
#
# Цепочка: ящик на верстаке → предохранитель → щиток и нужный рубильник → лампочка;
# столб роста → сундук с кодом 1815 → записка №7 → свеча → сквозняк за стеллажом →
# снять банки по одной → отодвинуть стеллаж → болторезы → цепь в несколько попыток → люк.
# Дверь наверху лестницы открыта, но выход через неё всегда заканчивается поимкой.

const StorySpot := preload("res://scripts/StorySpot.gd")

signal alerted(reason: String)  # громкий звук: сюда подключается существо

const MAP_FILE := "res://scenes/Шоссе.json"
const SFX := "res://assets/audio/"
const CUT := "res://assets/audio/cutscenes/"
const MONSTER := "res://assets/audio/monster/"

const CHEST_CODE := "1815"
const BASEMENT_AMBIENT := Color(0.2, 0.19, 0.2)
const RIGHT_SWITCH := 2         # третий рубильник: подвал
const JAR_MIN_INTERVAL := 0.7   # снял быстрее — банка падает
const CHAIN_ATTEMPTS := 3
const CHAIN_COOLDOWN := 2.5

const WAKE_POS := Vector3(-58.0, -4.15, -227.5)
const TOOLBOX := Vector3(-55.2, -3.05, -230.22)
const FUSEBOX := Vector3(-65.0, -2.8, -219.5)
const POST := Vector3(-58.5, -2.9, -225.2)
const CHEST := Vector3(-57.7, -3.9, -230.3)
const SOLDIER := Vector3(-64.15, -3.66, -229.85)
const CANDLE := Vector3(-55.85, -3.27, -229.95)
const CUTTERS := Vector3(-62.75, -3.54, -219.56)
const DRAFT := Vector3(-70.1, -3.4, -228.0)
const SHELF_CENTER := Vector3(-69.3, -3.2, -228.0)
const SHELF_SHIFT := Vector3(0, 0, 1.75)
const TRAPDOOR := Vector3(-70.1, -4.19, -228.0)
const LAMP_POS := Vector3(-58.0, -1.15, -225.8)
const DRAFT_SENSE := 3.2        # с этого расстояния пламя начинает клониться
const DRAFT_FOUND := 1.7
const DOOR_TRAP_Z := -218.85    # за этой чертой на площадке его уже ждут

const NOTES := [
	["№1", Vector3(-59.0, -4.15, -219.75), "Мальчикам я сказал, что это просто олень. Чёрный, крупный, бывает. Сэм поверил. Итан нет. Итан смотрел в окно до утра."],
	["№2", Vector3(-56.5, -3.28, -230.3), "Нашёл в городском архиве. Сто двадцать лет назад в этом лесу жил охотник Джозеф Крейн. Суровая зима, голод. Жена и двое сыновей. Весной Крейн вышел к людям один. Сказал, что семья умерла от болезни. Могил так и не нашли."],
	["№3", Vector3(-65.9, -3.06, -230.32), "Старики с заправки говорят: Крейн ушёл в лес и надел шкуру чёрного оленя. Хотел «вернуть своих». С тех пор в лесу кто-то зовёт по ночам голосами. Я думаю, он вернул. Только не их, а их голоса."],
	["№4", Vector3(-67.8, -4.17, -220.9), "Оно не может взять человека силой. Человек должен отозваться сам. Поэтому оно зовёт голосами тех, по кому скучают. Это ловушка не для тела, а для сердца."],
	["№5", Vector3(-64.4, -3.67, -229.95), "Оно собирает семью. Свою, ту, которую потерял. Отец, старший сын, младший сын. Ему нужны все трое. Я узнал это слишком поздно. Оно заметило нас, когда Итану было семь."],
	["№6", Vector3(-54.3, -4.17, -219.8), "Я отправил Итана учиться не ради учёбы. Попросил Сэма уговорить его. Чем дальше Итан от леса, тем он целее. Пусть думает, что мы о нём забыли. Пусть злится. Лишь бы не возвращался."],
]
const NOTE_7 := "Если ты это читаешь, значит, ты в подвале и выйти через дверь нельзя. Мальчики никогда не знали: когда мы строили дом, я сделал второй выход. Ищи там, где дует ветер. Цепь толстая, болторезы в котельной.\n\nВыйдешь — иди в мою комнату. Под кроватью, где скрипит доска. Там то, что может его остановить. Я так и не решился это сделать."
const POST_TEXT := "Отметки роста, ножом по дереву. Год за годом, в день рождения:\n\nС — 6     И — 4\nС — 7     И — 5\n…\nС — 16    И — 13\nС — 17    И — 14\nС — 18    И — 15\n\nДальше отметок нет."
const CHEST_LID := "На крышке выцарапано:\n«Последний год, когда мы были все вместе»"
const FUSE_SCHEME := "Схема отца на крышке щитка:\nI — верх дома     II — двор     III — подвал"

var spots: Dictionary = {}
var has_fuse := false
var lit := false
var post_seen := false
var chest_open := false
var has_candle := false
var draft_found := false
var jars_left := 0
var shelf_moved := false
var has_cutters := false
var chain_hits := 0
var chain_cut := false
var escaped := false
var alerts := 0
var caught_count := 0
var modal_open := false

var _player: CharacterBody3D
var _camera: Camera3D
var _objects: Dictionary = {}    # id карты -> узел
var _jar_nodes: Array = []
var _shelf_nodes: Array = []
var _last_jar_at := -10.0
var _last_chain_at := -10.0
var _clock := 0.0
var _lamp_lights: Array = []
var _candle_rig: Node3D
var _candle_flame: MeshInstance3D
var _trapdoor: Node3D
var _chain: MeshInstance3D
var _wardrobe_note_read := false
var _wardrobe_wait := 0.0
var _busy := false
var _missions: MissionTracker

var _layer: CanvasLayer
var _black: ColorRect
var _sub: Label
var _sub_tween: Tween
var _modal: Control
var _code := ""
var _code_label: Label


func _ready() -> void:
	name = "BasementChapter"
	_build_ui()
	_begin.call_deferred()


func _begin() -> void:
	while not is_instance_valid(GameManager.player_ref) or not GameManager.player_ref.is_inside_tree():
		await get_tree().process_frame
	# Предметы карты появляются после игрока
	for i in range(3):
		await get_tree().process_frame
	_player = GameManager.player_ref
	_camera = _player.get("camera")
	_force_flashlight_off()
	_index_objects()
	_remove_map_notes()
	_silence_old_exit()
	_setup_lamp()
	_add_dim_light()
	_add_spots()
	_add_props()
	_start_missions()


func _index_objects() -> void:
	var main := get_parent()
	var roots: Array = main.get_children()
	var nav = main.get("nav_region")
	if nav != null:
		roots.append_array(nav.get_children())
	for n in roots:
		var parts := str(n.name).rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			_objects[int(parts[1])] = n
	var data = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
	if data == null:
		return
	for o in data["objects"]:
		var title := str(o["name"])
		if not title.contains("стеллаж с банками"):
			continue
		var node = _objects.get(int(o["id"]))
		if node == null:
			continue
		_shelf_nodes.append(node)
		if title.contains("(банка)"):
			# Крышка идёт в карте следующей после своей банки
			_jar_nodes.append([node, _objects.get(int(o["id"]) + 1), Vector3(o["position"][0], o["position"][1], o["position"][2])])
	jars_left = _jar_nodes.size()


# Записки карты — общий предмет без текста; вместо них здесь точки с текстом сюжета
func _remove_map_notes() -> void:
	var nodes: Array = get_parent().get_children()
	var nav = get_parent().get("nav_region")
	if nav != null:
		nodes.append_array(nav.get_children())
	for n in nodes:
		if n is Node3D and (n as Node3D).global_position.y < -2.8 and n.has_meta("item_type"):
			if str(n.get_meta("item_type")).begins_with("note"):
				n.queue_free()


# Люк в потолке за дверью остаётся только как запуск кат-сцены выхода
func _silence_old_exit() -> void:
	var hatch := _exit_hatch()
	if hatch == null:
		return
	for child in hatch.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true
	var chapter := get_parent().get_node_or_null("HighwayChapter")
	if chapter:
		var old = chapter.get("_missions")
		if is_instance_valid(old):
			old.queue_free()


func _exit_hatch() -> Node:
	var chapter := get_parent().get_node_or_null("HighwayChapter")
	return chapter.get_node_or_null("BasementExitHatch") if chapter else null


# Лампочка на карте только модель: свет добавляется здесь и горит после щитка
func _setup_lamp() -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.82, 0.55)
	l.light_energy = 7.0
	l.omni_range = 18.0
	l.position = LAMP_POS
	l.visible = false
	add_child(l)
	_lamp_lights = [l]


# Полоски света из щелей пола: без них в подвале совсем ничего не видно
func _add_dim_light() -> void:
	for p in [Vector3(-58.0, -1.2, -225.0), Vector3(-66.5, -1.2, -228.0), Vector3(-66.5, -1.2, -222.0)]:
		var l := OmniLight3D.new()
		l.light_color = Color(0.55, 0.6, 0.75)
		l.light_energy = 2.4
		l.omni_range = 13.0
		l.position = p
		add_child(l)


func _add_spots() -> void:
	_spot("toolbox", TOOLBOX, Vector3(0.7, 0.4, 0.5), "Открыть ящик с инструментами", _on_toolbox)
	_spot("fusebox", FUSEBOX, Vector3(0.7, 0.85, 0.4), "Открыть щиток", _on_fusebox)
	_spot("post", POST, Vector3(0.6, 1.4, 0.6), "Осмотреть столб", _on_post)
	_spot("chest", CHEST, Vector3(1.05, 0.75, 0.75), "Осмотреть сундук", _on_chest)
	_spot("soldier", SOLDIER, Vector3(0.3, 0.26, 0.3), "Взять солдатика", _on_soldier)
	_spot("cutters", CUTTERS, Vector3(0.6, 0.22, 0.4), "Взять болторезы", _on_cutters)
	for i in range(NOTES.size()):
		if i == 0:
			continue  # записка №1 в шкафу находится, когда Итан в него залез
		_spot("note%d" % i, NOTES[i][1] + Vector3(0, 0.05, 0), Vector3(0.45, 0.24, 0.42), "Прочитать записку", _read_note.bind(i))
	for i in range(_jar_nodes.size()):
		_spot("jar%d" % i, _jar_nodes[i][2] + Vector3(0.08, 0.02, 0), Vector3(0.3, 0.32, 0.26), "Снять банку", _on_jar.bind(i))


func _spot(key: String, pos: Vector3, side: Vector3, action: String, use: Callable) -> void:
	var s := StorySpot.new()
	s.setup(action, use, side)
	add_child(s)
	s.global_position = pos
	spots[key] = s


func _drop_spot(key: String) -> void:
	if spots.has(key):
		(spots[key] as Node).queue_free()
		spots.erase(key)


func _add_props() -> void:
	for i in range(1, NOTES.size()):
		_paper(NOTES[i][1])
	_soldier_mesh()
	_cutters_mesh()
	_candle_mesh()


func _paper(pos: Vector3) -> void:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.21, 0.003, 0.29)
	m.mesh = box
	m.material_override = _mat(Color(0.86, 0.82, 0.68), 0.95)
	add_child(m)
	m.global_position = pos
	m.rotation_degrees = Vector3(0, randf_range(-14.0, 14.0), 0)


func _mat(color: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	m.rotation_degrees = rot
	parent.add_child(m)
	return m


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c


func _soldier_mesh() -> void:
	var root := Node3D.new()
	root.name = "Soldier"
	add_child(root)
	root.global_position = SOLDIER + Vector3(0, -0.06, 0)
	var coat := _mat(Color(0.46, 0.14, 0.1))
	var wood := _mat(Color(0.62, 0.46, 0.28))
	_part(root, _cyl(0.022, 0.07), Vector3(0, 0.035, 0), wood)
	_part(root, _cyl(0.026, 0.06), Vector3(0, 0.1, 0), coat)
	_part(root, _cyl(0.016, 0.03), Vector3(0, 0.145, 0), wood)
	_part(root, _cyl(0.018, 0.035), Vector3(0, 0.177, 0), _mat(Color(0.1, 0.1, 0.12)))


func _cutters_mesh() -> void:
	var root := Node3D.new()
	root.name = "Cutters"
	add_child(root)
	root.global_position = CUTTERS
	var red := _mat(Color(0.55, 0.1, 0.08), 0.6)
	var steel := _mat(Color(0.3, 0.3, 0.33), 0.4, 0.8)
	_part(root, _cyl(0.012, 0.42), Vector3(-0.03, 0, 0.0), red, Vector3(0, 0, 86))
	_part(root, _cyl(0.012, 0.42), Vector3(-0.03, 0, 0.06), red, Vector3(0, 8, 86))
	_part(root, _cyl(0.022, 0.14), Vector3(0.24, 0, 0.03), steel, Vector3(0, 0, 90))


func _candle_mesh() -> void:
	var root := Node3D.new()
	root.name = "CandleOnBench"
	add_child(root)
	root.global_position = CANDLE
	_part(root, _cyl(0.018, 0.13), Vector3(0, 0.065, 0), _mat(Color(0.86, 0.82, 0.68), 0.6))
	var lighter := BoxMesh.new()
	lighter.size = Vector3(0.024, 0.07, 0.012)
	_part(root, lighter, Vector3(0.08, 0.035, 0.02), _mat(Color(0.2, 0.3, 0.55), 0.35))


func _start_missions() -> void:
	_missions = MissionTracker.new()
	_missions.setup([
		{"text": "Найти свет", "done": func(): return lit},
		{"text": "Открыть сундук отца", "done": func(): return chest_open},
		{"text": "Найти, где дует ветер", "done": func(): return draft_found},
		{"text": "Снять банки со стеллажа", "done": func(): return jars_left <= 0},
		{"text": "Отодвинуть стеллаж", "done": func(): return shelf_moved},
		{"text": "Открыть люк", "done": func(): return chain_cut},
		{"text": "Выбраться из подвала", "done": func(): return escaped},
	])
	add_child(_missions)


# ─── Свет ───────────────────────────────────────────────────

func _on_toolbox() -> void:
	if has_fuse:
		return
	has_fuse = true
	_drop_spot("toolbox")
	_play(SFX + "bag_open.wav", -8.0)
	_toast("Запасной предохранитель")


func _on_fusebox() -> void:
	if lit:
		return
	if not has_fuse:
		_say("Предохранителя нет. Может, в отцовском ящике…", 2.6)
		return
	_show_fusebox()


func _pull_switch(index: int) -> void:
	_close_modal()
	_play(SFX + "switch_pull.wav", -5.0)
	if index != RIGHT_SWITCH:
		_say("Наверху что-то загорелось…", 2.4)
		_alert("wrong_switch")
		return
	lit = true
	_drop_spot("fusebox")
	for l in _lamp_lights:
		(l as Light3D).visible = true
	_play(SFX + "fuse_insert.wav", -8.0)


# ─── Столб, сундук, записки ─────────────────────────────────

func _on_post() -> void:
	post_seen = true
	_play(CUT + "finger_dust.wav", -12.0)
	_show_paper("Столб", POST_TEXT)


func _on_chest() -> void:
	if chest_open:
		_show_paper("Записка №7", NOTE_7)
		return
	_show_code()


func _try_code() -> void:
	if _code != CHEST_CODE:
		_play(SFX + "safe_click.wav", -6.0)
		_code = ""
		_code_label.text = _code_view()
		return
	chest_open = true
	_close_modal()
	_play(SFX + "safe_open.wav", -6.0)
	(spots["chest"] as StorySpot).hint = "[ЛКМ / E]  Перечитать записку"
	_spot("candle", CANDLE + Vector3(0, 0.1, 0), Vector3(0.46, 0.34, 0.46), "Взять свечу и зажигалку", _on_candle)
	Phone.add_note("Записка №7", NOTE_7)
	_show_paper("Записка №7", NOTE_7, func(): _say("В тот год он перестал отмечать рост… Я и не заметил.", 3.2))


func _read_note(index: int) -> void:
	var title: String = "Записка " + str(NOTES[index][0])
	_play(CUT + "phone_tap.wav", -14.0)
	Phone.add_note(title, NOTES[index][2])
	_show_paper(title, NOTES[index][2])


func _on_soldier() -> void:
	if _busy:
		return
	_busy = true
	_drop_spot("soldier")
	var toy := get_node_or_null("Soldier")
	if toy:
		toy.queue_free()
	_player.set("is_in_cutscene", true)
	var warm := ColorRect.new()
	warm.color = Color(0.5, 0.33, 0.12, 0.0)
	warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(warm)
	_layer.move_child(warm, 0)
	var tw := create_tween()
	tw.tween_property(warm, "color:a", 0.62, 1.0)
	await tw.finished
	_say_as("", "Прятки. Сэм прятался так, что я искал его целый час.", 3.4)
	await get_tree().create_timer(3.8, false).timeout
	_say_as("СЭМ", "Я был там, где дует ветер. Папа запретил туда лазить, так что никому не говори.", 4.2)
	await get_tree().create_timer(4.6, false).timeout
	var back := create_tween()
	back.tween_property(warm, "color:a", 0.0, 1.0)
	await back.finished
	warm.queue_free()
	_player.set("is_in_cutscene", false)
	_busy = false


# ─── Свеча и сквозняк ───────────────────────────────────────

func _on_candle() -> void:
	has_candle = true
	_drop_spot("candle")
	var bench := get_node_or_null("CandleOnBench")
	if bench:
		bench.queue_free()
	_play(CUT + "fire_ignite.wav", -18.0)
	_candle_rig = Node3D.new()
	_camera.add_child(_candle_rig)
	_candle_rig.position = Vector3(0.2, -0.2, -0.42)
	_candle_rig.scale = Vector3.ONE * 0.7
	_part(_candle_rig, _cyl(0.014, 0.11), Vector3.ZERO, _mat(Color(0.86, 0.82, 0.68), 0.6))
	var drop := SphereMesh.new()
	drop.radius = 0.013
	drop.height = 0.05
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.72, 0.28)
	_candle_flame = _part(_candle_rig, drop, Vector3(0, 0.085, 0), glow)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 4.0
	light.omni_range = 9.0
	light.position = Vector3(0, 0.12, 0)
	_candle_rig.add_child(light)


func _update_candle() -> void:
	# Стеллаж не подпускает ближе: считается только расстояние по полу
	var dist: float = Vector2(_player.global_position.x - DRAFT.x, _player.global_position.z - DRAFT.z).length()
	var lean: float = clampf(1.0 - (dist - DRAFT_FOUND) / (DRAFT_SENSE - DRAFT_FOUND), 0.0, 1.0)
	var wobble: float = sin(_clock * 11.0) * 2.0 + sin(_clock * 23.0) * 1.0
	_candle_flame.rotation_degrees.z = wobble + lean * 52.0 * (1.0 + 0.2 * sin(_clock * 17.0))
	if not draft_found and dist <= DRAFT_FOUND:
		draft_found = true
		_say("Я был там, где дует ветер…", 2.8)


# ─── Банки и стеллаж ────────────────────────────────────────

func _on_jar(index: int) -> void:
	if not draft_found:
		_say("Банки. Зачем мне они?", 1.8)
		return
	var key := "jar%d" % index
	if not spots.has(key):
		return
	_drop_spot(key)
	var pair: Array = _jar_nodes[index]
	for n in [pair[0], pair[1]]:
		if is_instance_valid(n):
			(n as Node3D).visible = false
			_disable_collision(n)
	jars_left -= 1
	if _clock - _last_jar_at < JAR_MIN_INTERVAL:
		_play(CUT + "window_smash.wav", -12.0)
		_say("Тише!..", 1.4)
		_alert("jar_fell")
	else:
		_play(SFX + "bag_item_select.wav", -12.0)
	_last_jar_at = _clock
	if jars_left == 0:
		_spot("shelf", SHELF_CENTER, Vector3(0.75, 2.3, 1.9), "Отодвинуть стеллаж", _on_shelf)


func _disable_collision(node: Node) -> void:
	for shape in node.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = true
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true


func _on_shelf() -> void:
	if shelf_moved or _busy:
		return
	_busy = true
	_drop_spot("shelf")
	_player.set("is_in_cutscene", true)
	_play(CUT + "chair_scrape.wav", -8.0)
	_build_trapdoor()
	var tw := create_tween().set_parallel()
	for n in _shelf_nodes:
		if is_instance_valid(n):
			tw.tween_property(n, "global_position", (n as Node3D).global_position + SHELF_SHIFT, 1.6).set_trans(Tween.TRANS_SINE)
	await tw.finished
	shelf_moved = true
	_player.set("is_in_cutscene", false)
	_busy = false
	_spot("hatch", TRAPDOOR + Vector3(0, 0.12, 0), Vector3(1.05, 0.4, 1.05), "Перекусить цепь", _on_chain)


func _build_trapdoor() -> void:
	_trapdoor = Node3D.new()
	_trapdoor.name = "Trapdoor"
	add_child(_trapdoor)
	_trapdoor.global_position = TRAPDOOR
	var wood := _mat(Color(0.3, 0.22, 0.15), 0.95)
	var iron := _mat(Color(0.13, 0.12, 0.11), 0.6, 0.7)
	var plate := BoxMesh.new()
	plate.size = Vector3(0.9, 0.04, 0.9)
	_part(_trapdoor, plate, Vector3.ZERO, wood)
	var band := BoxMesh.new()
	band.size = Vector3(0.94, 0.012, 0.07)
	_part(_trapdoor, band, Vector3(0, 0.026, -0.27), iron)
	_part(_trapdoor, band, Vector3(0, 0.026, 0.27), iron)
	var chain_mesh := BoxMesh.new()
	chain_mesh.size = Vector3(0.05, 0.03, 0.96)
	_chain = _part(_trapdoor, chain_mesh, Vector3(0.1, 0.05, 0), _mat(Color(0.32, 0.2, 0.12), 0.75, 0.6))


# ─── Цепь и выход ───────────────────────────────────────────

func _on_cutters() -> void:
	has_cutters = true
	_drop_spot("cutters")
	var tool_node := get_node_or_null("Cutters")
	if tool_node:
		tool_node.queue_free()
	_play(SFX + "bag_item_select.wav", -6.0)
	_toast("Болторезы")


func _on_chain() -> void:
	if chain_cut:
		_escape()
		return
	if not has_cutters:
		_say("Цепь толстая. Нужны болторезы.", 2.2)
		return
	if _clock - _last_chain_at < CHAIN_COOLDOWN:
		return
	_last_chain_at = _clock
	chain_hits += 1
	_play(SFX + "safe_open.wav", -4.0)
	_alert("chain")
	if chain_hits < CHAIN_ATTEMPTS:
		_say("Ещё держится…", 1.4)
		return
	chain_cut = true
	_chain.visible = false
	(spots["hatch"] as StorySpot).hint = "[ЛКМ / E]  Спуститься в люк"
	_play(CUT + "lid_open.wav", -6.0)


func _escape() -> void:
	if escaped or _busy:
		return
	_busy = true
	escaped = true
	_drop_spot("hatch")
	if is_instance_valid(_candle_rig):
		_candle_rig.queue_free()
	var hatch := _exit_hatch()
	if hatch and hatch.has_method("interact"):
		await hatch.call("interact", _player)
	_restore_fog()
	visible = false
	set_process(false)


# ─── Ловушка у двери, поимка, шум ───────────────────────────

func _alert(reason: String) -> void:
	alerts += 1
	alerted.emit(reason)
	GameManager.emit_noise(_player.global_position, 30.0, reason)


func caught() -> void:
	if _busy:
		return
	_busy = true
	caught_count += 1
	_player.set("is_in_cutscene", true)
	_play(MONSTER + "monster_growl.wav", -4.0)
	await _fade(1.0, 0.25)
	_player.global_position = WAKE_POS
	_player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.9, false).timeout
	_player.set("is_in_cutscene", false)
	await _fade(0.0, 0.8)
	_busy = false


func _process(delta: float) -> void:
	_clock += delta
	if not is_instance_valid(_player):
		return
	_keep_fog_off()
	if modal_open:
		GameManager.is_backpack_open = true
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	_keep_flashlight_broken()
	if is_instance_valid(_candle_flame):
		_update_candle()
	_check_wardrobe_note()
	var p: Vector3 = _player.global_position
	if not _busy and absf(p.x + 54.4) < 1.4 and p.y > -3.3 and p.z > DOOR_TRAP_Z:
		caught()


# Уличный туман считается от камеры и съедает весь подвал; настройки качества могут вернуть его
func _keep_fog_off() -> void:
	var world = get_parent().get("world_env_node")
	if world == null or world.environment == null:
		return
	var env: Environment = world.environment
	if env.fog_enabled:
		env.fog_enabled = false
	if env.volumetric_fog_enabled:
		env.volumetric_fog_enabled = false
	# Общая подсветка, чтобы очертания комнаты были видны и без лампы
	env.ambient_light_color = BASEMENT_AMBIENT
	env.ambient_light_energy = 1.0


func _restore_fog() -> void:
	var world = get_parent().get("world_env_node")
	if world != null and world.environment != null:
		world.environment.fog_enabled = true
		world.environment.ambient_light_color = Color(0.03, 0.04, 0.08)
		world.environment.ambient_light_energy = 0.28


func _keep_flashlight_broken() -> void:
	if _player.get("flashlight_on") != true:
		return
	_force_flashlight_off()
	_say("Разбит…", 1.4)


func _force_flashlight_off() -> void:
	_player.set("flashlight_on", false)
	var torch = _player.get("flashlight")
	if torch != null:
		torch.visible = false
	var hands = _player.get("player_hands")
	if hands != null:
		hands.call("set_flashlight_state", false, 0.0)


func _check_wardrobe_note() -> void:
	if _wardrobe_note_read or _player.get("is_hiding") != true:
		return
	var spot = _player.get("hiding_node")
	if not is_instance_valid(spot) or (spot as Node3D).global_position.distance_to(NOTES[0][1]) > 1.6:
		return
	_wardrobe_wait += get_process_delta_time()
	if _wardrobe_wait >= 2.0:
		_wardrobe_note_read = true
		_read_note(0)


# ─── Окна: бумага, щиток, кодовый замок ─────────────────────

func _open_modal(panel: Control) -> void:
	_close_modal()
	modal_open = true
	_modal_is_paper = false
	GameManager.is_backpack_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.add_child(centre)
	centre.add_child(panel)
	_layer.add_child(dim)
	_modal = dim


func _close_modal() -> void:
	if not modal_open:
		return
	modal_open = false
	if is_instance_valid(_modal):
		_modal.queue_free()
	_release_player()


# Игрок опрашивает клавиши в физическом кадре. Если отпустить его сразу, то же нажатие
# E снова откроет записку, а Esc выпустит мышь из окна.
func _release_player() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if modal_open:
		return
	GameManager.is_backpack_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if not modal_open:
		return
	# Физическая клавиша: на русской раскладке keycode у E другой
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ESCAPE, KEY_E, KEY_TAB, KEY_X]:
		if event.physical_keycode == KEY_ESCAPE or (event.physical_keycode == KEY_E and _modal_is_paper):
			_finish_modal()
		get_viewport().set_input_as_handled()
	elif _modal_is_paper and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_finish_modal()
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B:
		_finish_modal()
		get_viewport().set_input_as_handled()


var _after_modal: Callable
var _modal_is_paper := false

func _finish_modal() -> void:
	_close_modal()
	if _after_modal.is_valid():
		var after := _after_modal
		_after_modal = Callable()
		after.call()


func _panel(width: float, paper: bool) -> VBoxContainer:
	return _panel_with(width, Color(0.82, 0.77, 0.62) if paper else Color(0.09, 0.09, 0.1))


func _panel_with(width: float, color: Color) -> VBoxContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size.x = width
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	style.set_content_margin_all(26)
	card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	_open_modal(card)
	return column


func _text(value: String, size_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	return l


func _show_paper(title: String, body: String, after: Callable = Callable()) -> void:
	var ink := Color(0.13, 0.1, 0.07)
	var column := _panel(560.0, true)
	_modal_is_paper = true
	column.add_child(_text(title, 15, Color(0.36, 0.28, 0.18)))
	column.add_child(_text(body, 21, ink))
	column.add_child(_text("[Esc / E / ЛКМ]  Закрыть", 14, Color(0.36, 0.28, 0.18)))
	_after_modal = after


func _show_fusebox() -> void:
	var column := _panel(520.0, false)
	column.add_child(_text("ЩИТОК", 15, Color(0.6, 0.6, 0.6)))
	column.add_child(_text(FUSE_SCHEME, 20, Color(0.88, 0.86, 0.78)))
	column.add_child(_text("Подписи на рубильниках стёрлись.", 15, Color(0.6, 0.6, 0.6)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	for i in range(3):
		var b := Button.new()
		b.text = ["I", "II", "III"][i]
		b.custom_minimum_size = Vector2(92, 76)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_pull_switch.bind(i))
		row.add_child(b)
		if i == 0:
			b.grab_focus.call_deferred()
	column.add_child(row)
	column.add_child(_text("[Esc]  Отойти", 14, Color(0.6, 0.6, 0.6)))


func _code_view() -> String:
	var shown := ""
	for i in range(4):
		shown += (_code[i] if i < _code.length() else "_") + " "
	return shown.strip_edges()


func _show_code() -> void:
	_code = ""
	var column := _panel(400.0, false)
	column.add_child(_text(CHEST_LID, 18, Color(0.88, 0.86, 0.78)))
	_code_label = _text(_code_view(), 38, Color(0.95, 0.9, 0.7))
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_code_label)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	for digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]:
		var b := Button.new()
		b.text = digit
		b.custom_minimum_size = Vector2(62, 52)
		b.add_theme_font_size_override("font_size", 22)
		b.pressed.connect(_press_digit.bind(digit))
		grid.add_child(b)
		if digit == "1":
			b.grab_focus.call_deferred()
	var centre := CenterContainer.new()
	centre.add_child(grid)
	column.add_child(centre)
	column.add_child(_text("[Esc]  Отойти", 14, Color(0.6, 0.6, 0.6)))


func _press_digit(digit: String) -> void:
	if _code.length() >= 4:
		return
	_play(SFX + "safe_click.wav", -14.0)
	_code += digit
	_code_label.text = _code_view()
	if _code.length() == 4:
		_try_code()


# ─── Звук, реплики, затемнение ──────────────────────────────

func _play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 70
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_black)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.anchor_right = 1.0
	_sub.anchor_top = 1.0
	_sub.anchor_bottom = 1.0
	_sub.offset_left = 160
	_sub.offset_right = -160
	_sub.offset_top = -130
	_sub.offset_bottom = -70
	_sub.modulate.a = 0.0
	_layer.add_child(_sub)


func _fade(alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, seconds)
	await tw.finished


func _say(text: String, hold: float) -> void:
	_say_as("ИТАН", text, hold)


func _say_as(who: String, text: String, hold: float) -> void:
	_sub.text = text if who == "" else "%s: %s" % [who, text]
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_sub, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_interval(hold)
	_sub_tween.tween_property(_sub, "modulate:a", 0.0, 0.4)


func _toast(item: String) -> void:
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		GameManager.ui_ref.call("show_hint", "Взято: " + item, 2.0)
