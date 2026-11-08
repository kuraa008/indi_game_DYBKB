extends Cutscene

# ПРОЛОГ · «Звонок». Квартира Итана — та же, что в игре: карта «Квартира.json» и
# ApartmentScene (мебель, пицца на столике, шторы, дождь за окнами, телевизор).
# Вечер, за окном темно и льёт дождь, по телевизору сериал, Итан на диване.
#
# «Обычный день» — игра: задачи, вибрация, кнопки «Ответить» / «Сбросить» — геймплей.
# Кат-сцена начинается, когда игрок САМ нажал «Ответить»: на экране «Неизвестный номер»
# и бегущие секунды разговора. Полиция: отец найден мёртвым в своей кровати, Сэм пропал.
# Итан застывает с трубкой у уха; секунд через десять — «Как…». По телевизору кто-то
# смеётся. Итан этого уже не слышал.
#
# args.from_gameplay = true — без затемнения в начале (игрок только что смотрел на телефон).

const MAP := "res://scenes/Квартира.json"
const FL := 0.01                                  # пол квартиры (как в ApartmentScene)
const SOFA_EYE := Vector3(0.25, 1.13, 1.45)
const TV_POS := Vector3(0.2, 0.95 + FL, -2.05)
const WIDE_CAM := Vector3(1.75, 1.7, -1.5)
const LAUGH_AT := TV_POS + Vector3(0, 0, 0.3)
const WOOD_FLOORS := [Vector3(-0.05, -0.04, 0.05), Vector3(-0.05, -0.04, -4.45), Vector3(3.45, -0.04, -2.0)]

var tv_light: OmniLight3D
var phone: Dictionary
var hand: CutsceneCast.Hand
var phone_rig: Node3D
var ethan: PlayerModel
var _tv_amb: Node
var _rain: Node
var _room: Node
var _call_from := -1.0     # время, с которого на экране телефона идут секунды разговора


func build() -> void:
	# Ночь, как в ApartmentScene._setup_night
	set_env(Color(0.012, 0.016, 0.035), Color(0.3, 0.33, 0.42), 0.3, 0.0, Color.BLACK, 1.08)
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.06
	var area := CutsceneKit.map_area(self, MAP, Vector3(2.75, 0.0, -2.0), 20.0)
	_wood_floors(area)
	# Всё, чего нет в карте: окна с дождём, телевизор, мебель, свет, шторы — из игры
	var apt: Node3D = load("res://scripts/ApartmentScene.gd").new()
	add_child(apt)
	_set_lights(apt)
	tv_light = _find_tv_light(apt)
	# Итан на диване — виден только в общем плане
	ethan = CutsceneCast.ethan()
	add_child(ethan)
	ethan.position = Vector3(0.25, FL, 1.62)
	ethan.rotation_degrees = Vector3(0, 180, 0)
	CutsceneCast.pose(ethan, _phone_pose())
	var held := BoneAttachment3D.new()
	held.bone_name = "handR"
	ethan.skeleton.add_child(held)
	var ph2 := CutsceneKit.phone(held)
	ph2.root.position = Vector3(0.0, 0.04, 0.02)
	ph2.root.rotation_degrees = Vector3(0, 90, 90)
	ph2.light.visible = false
	ethan.visible = false
	# Телефон в руке от первого лица: идёт разговор с неизвестным номером
	phone_rig = Node3D.new()
	cam.add_child(phone_rig)
	hand = CutsceneCast.hand(false)
	phone_rig.add_child(hand)
	hand.position = Vector3(0.01, -0.075, 0.03)
	hand.rotation_degrees = Vector3(72, 0, 0)
	hand.curl = 0.75
	phone = CutsceneKit.phone(phone_rig)
	phone.root.position = Vector3(0.0, 0.035, -0.06)
	phone.root.rotation_degrees = Vector3(-20, 0, 0)
	phone_rig.position = Vector3(0.12, -0.2, -0.36)
	phone_rig.rotation_degrees = Vector3(28, -8, 0)
	(phone.ok as Node3D).visible = false
	(phone.no as Node3D).visible = false
	_set_phone("Неизвестный номер", "00:00")


func _phone_pose() -> Dictionary:
	return CutsceneCast.with(CutsceneCast.sit_table(), {
		"hips_pos": Vector3(0, -0.52, 0.02),
		"spineA": Vector3(-0.12, 0, 0), "chest": Vector3(-0.04, 0, 0), "neck": Vector3(0.12, 0, 0), "head": Vector3(0.18, 0.12, 0),
		"shL": Vector3(-0.35, 0, -0.1), "elL": Vector3(-0.9, 0, 0),
		"shR": Vector3(-0.55, -0.2, 0.55), "elR": Vector3(-2.35, 0, 0), "wrR": Vector3(0.2, 0, 0),
	})


# Деревянный пол в комнате, спальне и коридоре (в игре его кладёт ApartmentScene по nav_region)
func _wood_floors(area: Node) -> void:
	var wood := CutsceneKit.tmat("wood_furniture.png", Color(0.62, 0.5, 0.4), 0.9, 0.7)
	for c in area.get_children():
		if c is MeshInstance3D:
			for p in WOOD_FLOORS:
				if (c as Node3D).position.distance_to(p) < 0.05:
					(c as MeshInstance3D).material_override = wood


# Поздний вечер у телевизора: люстра в комнате выключена, горит торшер у окна,
# в коридоре свет (он падает в комнату через дверь), кухня, спальня и ванная тёмные.
func _set_lights(apt: Node) -> void:
	for n in apt.find_children("*", "", true, false):
		if n.get("group") == null or not n.has_method("_update_toggle_visual"):
			continue
		var on := (n as Node3D).position.x > 2.7 and (n as Node3D).position.z > 1.0   # выключатель коридора
		n.set("is_light_on", on)
		n.get("group").call("set_on", on)
		n.call("_update_toggle_visual", false)


func _find_tv_light(apt: Node) -> OmniLight3D:
	for c in apt.get_children():
		if c is OmniLight3D and (c as Node3D).position.distance_to(TV_POS + Vector3(0, 0, 0.6)) < 0.05:
			return c
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.72, 0.85)
	l.omni_range = 4.5
	l.position = TV_POS + Vector3(0, 0, 0.6)
	add_child(l)
	return l


func _set_phone(title: String, sub: String) -> void:
	(phone.title as Label3D).text = title
	(phone.sub as Label3D).text = sub


func tick(_delta: float) -> void:
	# Свет телевизора следует за картинкой: смена планов (каждые 3.7 с, как шейдер) и мерцание
	var scene := floorf(t / 3.7)
	var warm := fposmod(sin(scene * 12.9898) * 43758.5453, 1.0)
	tv_light.light_color = Color(0.85, 0.66, 0.5).lerp(Color(0.5, 0.65, 0.9), warm)
	tv_light.light_energy = 0.8 + 0.2 * sin(t * 7.3) * sin(t * 2.1) + 0.1 * sin(t * 23.0)
	if _call_from >= 0.0 and phone_rig.visible:
		var s := int(t - _call_from)
		(phone.sub as Label3D).text = "%02d:%02d" % [s / 60, s % 60]


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	_room = loop("amb_apartment", -16.0)
	_rain = loop("amb_rain_window", -12.0)
	_tv_amb = loop("tv_show", -15.0, 0.0, LAUGH_AT, 3.0)
	breathe = 0.8
	handheld = 0.25
	# «Ответить» уже нажато: на экране неизвестный номер, пошли секунды разговора
	shot(SOFA_EYE, Vector3(0.18, 0.62, 0.9), 58.0)
	_call_from = t
	if from_game:
		fade_in(0.25)
	else:
		fade_in(1.0)
	sfx("phone_tap", -8.0)
	await wait(0.9 if from_game else 1.6)
	# Телефон к уху: рука уходит вправо, взгляд — на телевизор
	tween_prop(phone_rig, "position", Vector3(0.42, -0.05, -0.12), 0.7)
	tween_prop(phone_rig, "rotation_degrees", Vector3(10, -60, 0), 0.7)
	look_to(Vector3(0.0, 1.0, -2.0), 1.2)
	var line_noise := loop("phone_line", -20.0, 0.3)
	fade(_tv_amb, -21.0, 1.0)
	await wait(1.0)
	phone_rig.visible = false
	await line("police_1", "ПОЛИЦИЯ", "Итан? Это полиция округа…", 0.5)
	# Камера медленно наезжает на экран, мир уходит
	glide(SOFA_EYE + Vector3(-0.02, -0.02, -0.18), Vector3(0.1, 0.98, -2.0), 9.0, 52.0)
	var d2 := say_line("police_2", "ПОЛИЦИЯ", "Ваш отец найден мёртвым в своей кровати. Ваш брат, Сэм, пропал. Мы не можем его найти.")
	await wait(2.6)
	var ring := sfx("res://assets/audio/intro/tinnitus.wav", -30.0)
	if ring:
		fade(ring, -16.0, 6.0)
	muffle(1400.0, 6.0)
	handheld = 0.1
	await wait(maxf(0.0, d2 - 2.6) + 0.3)
	stop(line_noise, 0.6)
	# Секунд десять Итан не может сказать ни слова: трубка у уха, дождь по стеклу
	breathe = 0.0
	var heart := loop("heartbeat_slow", -24.0, 2.0)
	await wait(2.2)
	_wide_shot()
	await wait(5.2)
	shot(SOFA_EYE + Vector3(-0.02, -0.06, -0.16), Vector3(0.05, 0.62, 0.4), 50.0)
	handheld = 0.15
	await wait(1.4)
	await line("ethan_kak", "ИТАН", "Как…", 1.0, null, -2.0)
	# По телевизору кто-то засмеялся. Итан этого уже не слышал.
	_wide_shot()
	muffle(20000.0, 0.15)
	fade(_tv_amb, -12.0, 0.2)
	sfx("tv_laugh", -9.0, 1.0, LAUGH_AT, 3.0)
	await wait(1.8)
	muffle(500.0, 2.5)
	if ring:
		fade(ring, -12.0, 2.0)
	fade_out(3.0)
	silence(3.0)
	stop(heart, 3.0)
	await wait(3.6)
	if ring:
		stop(ring, 1.0)
	await wait(0.8)


# Общий план от телевизора: Итан на диване с телефоном у уха, за ним окно с дождём
func _wide_shot() -> void:
	ethan.visible = true
	handheld = 0.0
	breathe = 0.0
	shot(WIDE_CAM, Vector3(0.2, 1.05, 1.9), 46.0)
	glide(WIDE_CAM + Vector3(-0.15, -0.04, 0.25), Vector3(0.22, 1.02, 1.9), 7.0, 43.0)
