extends Cutscene

# КОНЕЦ ГЛАВЫ 3 · «Это… моё». Комната отца на втором этаже дома с карты «Шоссе» (Досым):
# стол с письмами Сэма, комод, шкаф, заколоченные окна. Кровать отодвинута от стены
# (по полу следы), скрипучая доска поднята, металлическая коробка вытащена и открыта.
# Итан стоит на коленях и берёт череп в руки — и стук копыт в доме разом прекращается.
# Тишина, только старые часы в коридоре тикают. Потом за дверью низкий, хриплый,
# чужой голос: «Это… моё». Дверная ручка медленно поворачивается. КОНЕЦ ГЛАВЫ 3.
#
# Коробка и доска стоят там же, где на карте (Дом: скрипучая доска / металлическая коробка),
# дверь — «Дверь в спальню» в стене коридора. С карты не берутся только они и кровать:
# здесь свои, потому что двигаются.
# args.from_gameplay = true — игрок уже стоит на коленях у коробки (начало без затемнения).

const MAP := "res://scenes/Шоссе.json"
const FY := 3.48                                   # пол второго этажа (HouseStory.FY)
const HOLE := Vector3(-69.3, FY, -220.7)           # где лежала скрипучая доска
const BOX_POS := Vector3(-69.05, FY + 0.005, -221.15)
const KNEEL := Vector3(-69.05, FY + 0.93, -220.4)
const BED_FROM := Vector3(-69.3, 3.41, -220.7)     # кровать на карте
const BED_TO := Vector3(-69.45, 3.41, -223.25)      # отодвинута к середине комнаты
const DOOR_HINGE := Vector3(-59.0, FY, -223.04)    # «Дверь в спальню», петли с южной стороны
const CLOCK_AT := Vector3(-57.6, 5.0, -223.6)      # часы в коридоре
const SKIP_IDS := [1212, 4000, 4001, 1056]

var door: Dictionary
var handle_at := Vector3.ZERO
var skull_rig: Node3D
var skull: Node3D
var candle_light: OmniLight3D
var hands: Array = []


func build() -> void:
	set_env(Color(0.0, 0.0, 0.0), Color(0.3, 0.32, 0.4), 0.85, 0.0, Color.BLACK, 1.3)
	CutsceneKit.map_area(self, MAP, Vector3(-65.0, 0.0, -222.0), 9.0, [], SKIP_IDS, AABB(), false)
	var floor_m := CutsceneKit.tmat("wood_furniture.png", Color(0.5, 0.4, 0.31), 1.1)
	# Дверь в коридор: на месте двери с карты, открывается внутрь комнаты
	door = CutsceneKit.door(self, DOOR_HINGE, Vector3(0, -90, 0), 1.06, 2.26)
	handle_at = (door.handle as Node3D).position.rotated(Vector3.UP, deg_to_rad(-90.0)) + DOOR_HINGE
	# Луна сквозь доски западного окна: полосы света на полу
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 6.0
	moon.spot_range = 9.0
	moon.spot_angle = 24.0
	moon.shadow_enabled = true
	add_child(moon)
	moon.position = Vector3(-73.4, 5.4, -222.0)
	moon.look_at(Vector3(-68.2, FY, -221.4), Vector3.UP)
	var room := OmniLight3D.new()
	room.light_color = Color(0.45, 0.52, 0.75)
	room.light_energy = 0.35
	room.omni_range = 7.0
	room.position = Vector3(-65.0, FY + 2.4, -222.0)
	add_child(room)
	# Кровать отодвинута от стены, на пыльном полу следы ножек
	var bed := CutsceneKit.prefab(self, "prop_bed", Vector3(1.48, 0.88, 2.12), BED_TO, Vector3(0, 96, 0), Color(0.45, 0.4, 0.35))
	bed.rotation_degrees.y = 96.0
	var scuff := CutsceneKit.mat(Color(0.2, 0.16, 0.12), 1.0)
	for dx in [-0.95, 0.95]:
		var p0 := BED_FROM + Vector3(dx, 0.0, 0.0)
		var p1 := BED_TO + Vector3(dx, 0.0, 0.0)
		CutsceneKit.box(self, Vector3(0.05, 0.003, p0.distance_to(p1)), Vector3((p0.x + p1.x) * 0.5, FY + 0.002, (p0.z + p1.z) * 0.5), scuff, Vector3.ZERO, false)
	# Поднятая доска и дыра в полу, рядом вытащенная открытая коробка
	CutsceneKit.box(self, Vector3(1.55, 0.02, 0.15), HOLE + Vector3(0, -0.005, 0), CutsceneKit.mat(Color(0.02, 0.02, 0.02), 1.0))
	CutsceneKit.box(self, Vector3(1.6, 0.03, 0.16), HOLE + Vector3(1.1, 0.02, 0.35), floor_m, Vector3(0, 28, 0))
	var mbox := CutsceneKit.metal_box(self, BOX_POS, Vector3(0, 8, 0))
	(mbox.get_node("Lid") as Node3D).rotation_degrees = Vector3(-112, 0, 0)
	var note := CutsceneKit.box(self, Vector3(0.16, 0.002, 0.21), BOX_POS + Vector3(0.1, 0.02, 0.02), CutsceneKit.mat(Color(0.82, 0.78, 0.66), 0.95), Vector3(0, -14, 0))
	note.name = "LastNote"
	# Свеча на полу у коробки — тёплый дрожащий свет
	CutsceneKit.cyl(self, 0.018, 0.02, 0.1, BOX_POS + Vector3(0.42, 0.05, 0.2), CutsceneKit.mat(Color(0.85, 0.82, 0.7), 0.6))
	var flame := CutsceneKit.quad(self, Vector2(0.018, 0.035), BOX_POS + Vector3(0.42, 0.12, 0.2), CutsceneKit.add_mat(Color(1.0, 0.7, 0.3, 1.0), CutsceneKit.flame_tex()))
	(flame.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	candle_light = OmniLight3D.new()
	candle_light.light_color = Color(1.0, 0.62, 0.3)
	candle_light.light_energy = 1.1
	candle_light.omni_range = 3.6
	candle_light.shadow_enabled = true
	candle_light.position = BOX_POS + Vector3(0.42, 0.2, 0.2)
	add_child(candle_light)
	# Отсвет на двери: ручку должно быть видно через всю комнату
	var door_fill := OmniLight3D.new()
	door_fill.light_color = Color(0.55, 0.62, 0.85)
	door_fill.light_energy = 2.2
	door_fill.omni_range = 1.6
	door_fill.position = handle_at + Vector3(-0.55, 0.25, -0.15)
	add_child(door_fill)
	CutsceneKit.cobweb(self, Vector3(-70.8, FY + 3.1, -219.2), 0.5, Vector3(0, 45, 0))
	CutsceneKit.dust(self, KNEEL + Vector3(-0.2, 0.0, -0.7), Vector3(1.4, 0.9, 1.2), 50, Color(0.8, 0.85, 1.0, 0.3))
	# Череп и руки — у камеры, поднимаются в кадр снизу
	skull_rig = Node3D.new()
	cam.add_child(skull_rig)
	skull_rig.position = Vector3(0, -0.75, -0.42)
	skull = CutsceneKit.deer_skull(skull_rig)
	skull.rotation_degrees = Vector3(-18, 78, 0)
	skull.scale = Vector3.ONE * 1.1
	var key := OmniLight3D.new()
	key.light_color = Color(0.62, 0.7, 0.95)
	key.light_energy = 0.35
	key.omni_range = 0.7
	key.position = Vector3(-0.25, 0.25, 0.05)
	skull_rig.add_child(key)
	for s in [-1.0, 1.0]:
		var h := CutsceneCast.hand(s < 0.0)
		skull_rig.add_child(h)
		h.position = Vector3(0.1 * s, -0.065, 0.01 if s < 0.0 else 0.04)
		h.rotation_degrees = Vector3(-15, -30 * s, 65 * s)
		h.curl = 0.6
		hands.append(h)


func tick(_delta: float) -> void:
	candle_light.light_energy = 1.0 + 0.12 * sin(t * 11.0) + 0.08 * sin(t * 23.0 + 1.0)


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	var clock := loop("clock_tick", -22.0, 0.0, CLOCK_AT, 4.0)
	handheld = 0.35
	breathe = 1.0
	shot(KNEEL, BOX_POS + Vector3(0.02, 0.05, 0.0), 58.0)
	fade_in(0.5 if from_game else 1.5)
	# Копыта ходят по дому — где-то наверху
	_walking_hooves()
	await wait(1.6)
	# Итан берёт череп в руки
	sfx("skull_lift", -8.0)
	tween_prop(skull_rig, "position", Vector3(0.02, -0.19, -0.52), 1.6, Tween.TRANS_SINE, Tween.EASE_OUT)
	look_to(KNEEL + Vector3(0.0, -0.35, -0.55), 1.6)
	await wait(2.4)
	# Стук копыт разом прекращается
	_hooves_on = false
	sfx("silence_drop", -10.0)
	fade(clock, -13.0, 0.4)
	handheld = 0.15
	breathe = 0.2
	sfx("ethan_breath_held", -12.0)
	await wait(2.6)
	# Взгляд — на дверь
	look_to(handle_at + Vector3(0.0, 0.3, -0.1), 2.4)
	tween_prop(skull_rig, "position", Vector3(0.02, -0.32, -0.5), 2.4)
	await wait(3.0)
	# За дверью: «Это… моё».
	await line("creature_mine", "ГОЛОС ЗА ДВЕРЬЮ", "Это… моё.", 0.5, handle_at + Vector3(0.8, 0.5, 0.0), 4.0, 8.0)
	# Ручка медленно поворачивается
	glide(KNEEL + Vector3(0.12, 0.02, -0.05), handle_at, 4.4, 12.0)
	sfx("door_handle_slow", 2.0, 1.0, handle_at, 6.0)
	tween_prop(door.handle, "rotation_degrees", Vector3(0, 0, 42), 3.9, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await wait(4.1)
	black(1.0)
	stop(clock, 0.05)
	silence(0.05)
	await wait(1.0)
	await card("КОНЕЦ ГЛАВЫ 3", "", 2.6, 0.8)


var _hooves_on := true


func _walking_hooves() -> void:
	var i := 0
	while _hooves_on and not skipping:
		sfx("hoof_muffled_%d" % (i % 4 + 1), -11.0 + 2.0 * sin(i * 0.7))
		i += 1
		await wait(0.78)
