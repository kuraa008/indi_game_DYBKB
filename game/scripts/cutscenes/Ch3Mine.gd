extends Cutscene

# КОНЕЦ ГЛАВЫ 3 · «Это… моё». Комната отца: кровать сдвинута (под ножками тряпки),
# доска поднята, металлическая коробка открыта. Итан берёт череп в руки — и стук
# копыт в доме разом прекращается. Тишина, только часы в коридоре. Потом за дверью
# низкий хриплый чужой голос: «Это… моё». Дверная ручка медленно поворачивается.
#
# args.from_gameplay = true — игрок уже стоит на коленях у коробки (начало без затемнения).

const KNEEL := Vector3(-0.35, 0.95, -0.15)
const BOX_POS := Vector3(-0.35, 0.02, -0.85)
const DOOR_ROOT := Vector3(1.65, 0.0, 1.88)
const HANDLE_WORLD := Vector3(0.84, 1.0, 1.85)

var door: Dictionary
var skull_rig: Node3D
var skull: Node3D
var candle_light: OmniLight3D
var hands: Array = []


func build() -> void:
	set_env(Color(0.0, 0.0, 0.0), Color(0.3, 0.32, 0.4), 0.85, 0.0, Color.BLACK, 1.3)
	var planks := CutsceneKit.tmat("board_weathered.png", Color(0.55, 0.47, 0.4), 1.3)
	var floor_m := CutsceneKit.tmat("wood_furniture.png", Color(0.5, 0.4, 0.31), 1.1)
	var paper := CutsceneKit.mat(Color(0.3, 0.26, 0.21), 0.95)
	# Комната отца 4.2 × 2.6 × 3.8: окно слева, дверь в коридор напротив коробки
	CutsceneKit.box(self, Vector3(4.6, 0.1, 4.2), Vector3(0, -0.05, 0), floor_m)
	CutsceneKit.box(self, Vector3(4.6, 0.1, 4.2), Vector3(0, 2.65, 0), planks)
	CutsceneKit.wall(self, Vector3(-2.1, 0, 1.9), Vector3(-2.1, 0, -1.9), 2.6, 0.12, paper, Rect2(1.4, 0.9, 1.0, 1.2))
	CutsceneKit.wall(self, Vector3(2.1, 0, -1.9), Vector3(2.1, 0, 1.9), 2.6, 0.12, paper)
	CutsceneKit.wall(self, Vector3(-2.1, 0, -1.9), Vector3(2.1, 0, -1.9), 2.6, 0.12, paper)
	CutsceneKit.wall(self, Vector3(2.1, 0, 1.9), Vector3(-2.1, 0, 1.9), 2.6, 0.12, paper, Rect2(0.45, 0.0, 0.9, 2.08))
	door = CutsceneKit.door(self, DOOR_ROOT, Vector3(0, 180, 0), 0.9, 2.06)
	# Окно: ночь, лунный свет полосой на полу
	var frame := CutsceneKit.mat(Color(0.35, 0.3, 0.25), 0.8)
	var wc := Vector3(-2.1, 1.5, -0.4)
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, Vector3(0.14, 1.2, 0.06), wc + Vector3(0, 0, 0.5 * s), frame)
		CutsceneKit.box(self, Vector3(0.14, 0.06, 1.06), wc + Vector3(0, 0.6 * s, 0), frame)
	CutsceneKit.box(self, Vector3(0.14, 1.2, 0.04), wc, frame)
	var night := StandardMaterial3D.new()
	night.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	night.albedo_color = Color(0.1, 0.13, 0.2)
	CutsceneKit.quad(self, Vector2(3, 3), wc + Vector3(-1.5, 0, 0), night, Vector3(0, 90, 0))
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 4.0
	moon.spot_range = 7.0
	moon.spot_angle = 28.0
	moon.shadow_enabled = true
	add_child(moon)
	moon.position = wc + Vector3(-1.2, 0.9, 0)
	moon.look_at(Vector3(0.2, 0.0, -0.4), Vector3.UP)
	# Кровать сдвинута, под ножками тряпки; пустая, со смятой простынёй
	var bed := CutsceneKit.prefab(self, "prop_bed", Vector3(1.5, 0.9, 2.1), Vector3(1.2, 0, -0.95), Vector3(0, 90, 0), Color(0.45, 0.4, 0.35))
	bed.rotation_degrees.y = 98.0
	var rag := CutsceneKit.mat(Color(0.32, 0.3, 0.33), 1.0)
	for p in [Vector3(0.2, 0.015, -1.6), Vector3(0.15, 0.015, -0.35), Vector3(2.0, 0.015, -1.55), Vector3(1.95, 0.015, -0.3)]:
		CutsceneKit.box(self, Vector3(0.16, 0.03, 0.14), p, rag, Vector3(0, 20, 0))
	CutsceneKit.cloth(self, Vector2(1.6, 1.0), Vector3(1.2, 0.62, -0.85), Vector3(0, 8, 0), Color(0.78, 0.76, 0.72))
	# Поднятая доска и дыра в полу, рядом открытая коробка
	CutsceneKit.box(self, Vector3(0.95, 0.02, 0.17), BOX_POS + Vector3(0, -0.04, -0.42), CutsceneKit.mat(Color(0.02, 0.02, 0.02), 1.0))
	CutsceneKit.box(self, Vector3(0.95, 0.03, 0.17), BOX_POS + Vector3(0.6, 0.0, -0.1), floor_m, Vector3(0, 35, 0))
	var mbox := CutsceneKit.metal_box(self, BOX_POS, Vector3(0, 8, 0))
	(mbox.get_node("Lid") as Node3D).rotation_degrees = Vector3(-112, 0, 0)
	var note := CutsceneKit.box(self, Vector3(0.16, 0.002, 0.21), BOX_POS + Vector3(0.1, 0.02, 0.02), CutsceneKit.mat(Color(0.82, 0.78, 0.66), 0.95), Vector3(0, -14, 0))
	note.name = "LastNote"
	# Свеча на полу у коробки — тёплый дрожащий свет
	CutsceneKit.cyl(self, 0.018, 0.02, 0.1, BOX_POS + Vector3(0.38, 0.05, 0.25), CutsceneKit.mat(Color(0.85, 0.82, 0.7), 0.6))
	var flame := CutsceneKit.quad(self, Vector2(0.018, 0.035), BOX_POS + Vector3(0.38, 0.12, 0.25), CutsceneKit.add_mat(Color(1.0, 0.7, 0.3, 1.0), CutsceneKit.flame_tex()))
	(flame.material_override as StandardMaterial3D).billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	candle_light = OmniLight3D.new()
	candle_light.light_color = Color(1.0, 0.62, 0.3)
	candle_light.light_energy = 1.1
	candle_light.omni_range = 3.4
	candle_light.shadow_enabled = true
	candle_light.position = BOX_POS + Vector3(0.38, 0.2, 0.25)
	add_child(candle_light)
	# Отсвет луны на двери: ручку должно быть видно
	var door_fill := OmniLight3D.new()
	door_fill.light_color = Color(0.55, 0.62, 0.85)
	door_fill.light_energy = 0.9
	door_fill.omni_range = 1.8
	door_fill.position = HANDLE_WORLD + Vector3(-0.35, 0.3, -0.6)
	add_child(door_fill)
	# Стол с выдвинутым ящиком (письма Сэма), комод, шкаф
	CutsceneKit.prefab(self, "prop_table", Vector3(1.2, 0.76, 0.6), Vector3(1.75, 0, 0.6), Vector3(0, 90, 0), Color(0.4, 0.3, 0.22))
	CutsceneKit.box(self, Vector3(0.42, 0.12, 0.5), Vector3(1.32, 0.62, 0.6), CutsceneKit.tmat("wood_furniture.png", Color(0.42, 0.32, 0.24), 1.5))
	for i in 3:
		CutsceneKit.box(self, Vector3(0.15, 0.003, 0.22), Vector3(1.3 + i * 0.02, 0.69 + i * 0.004, 0.55 + i * 0.03), CutsceneKit.mat(Color(0.86, 0.83, 0.74), 0.95), Vector3(0, 10 * i, 0))
	CutsceneKit.prefab(self, "prop_dresser", Vector3(1.2, 0.9, 0.5), Vector3(-1.8, 0, 1.2), Vector3(0, 90, 0), Color(0.36, 0.28, 0.2))
	CutsceneKit.prefab(self, "prop_wardrobe", Vector3(1.2, 2.1, 0.6), Vector3(-1.4, 0, -1.55), Vector3.ZERO, Color(0.34, 0.26, 0.2))
	CutsceneKit.cobweb(self, Vector3(2.0, 2.5, -1.8), 0.5, Vector3(0, -45, 0))
	CutsceneKit.dust(self, Vector3(-0.6, 1.0, -0.4), Vector3(1.2, 0.8, 1.0), 50, Color(0.8, 0.85, 1.0, 0.3))
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
	var clock := loop("clock_tick", -22.0, 0.0, HANDLE_WORLD + Vector3(0.6, 0.6, 1.8), 4.0)
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
	look_to(HANDLE_WORLD + Vector3(-0.1, 0.25, 0.0), 2.4)
	tween_prop(skull_rig, "position", Vector3(0.02, -0.32, -0.5), 2.4)
	await wait(3.0)
	# За дверью: «Это… моё».
	await line("creature_mine", "ГОЛОС ЗА ДВЕРЬЮ", "Это… моё.", 0.5, HANDLE_WORLD + Vector3(0.0, 0.5, 0.7), 2.0, 5.0)
	# Ручка медленно поворачивается
	glide(KNEEL + Vector3(0.05, 0.02, 0.25), HANDLE_WORLD, 4.4, 30.0)
	sfx("door_handle_slow", -2.0, 1.0, HANDLE_WORLD, 3.0)
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
