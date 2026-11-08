extends Cutscene

# КОНЕЦ ГЛАВЫ 2 · «Люк». Подвал Досыма: за дверью наверху лестницы — тесный тамбур, на стене
# скобы, в потолке люк (BasementExitHatch). В доме, совсем рядом, стучат копыта. Итан упирается
# в крышку — с первого раза она не поддаётся, сыплется земля, и копыта замирают. Второй раз —
# крышка откидывается, сверху ночь. Итан выбирается во двор за домом у такого же люка в земле
# (HighwayChapter.EXIT_HATCH): холодный ветер, лес. Отходит, оборачивается — тёмный дом,
# и из дома голос Сэма: «Итан?.. Итан, куда ты ушёл?..»
#
# В сюжете выход — земляной лаз из кладовой с крышкой за колодцем. На карте Досыма выход —
# этот тамбур с люком, и сцена повторяет карту. Люк в тамбуре и люк во дворе на карте в разных
# местах (игра переносит игрока), поэтому между ними склейка.
# Старый вариант с лазом и поленницей — в истории git (коммит 5f19389).
# args.from_gameplay = true — короткое появление и без затемнения в конце.

const MAP := "res://scenes/Шоссе.json"
const HATCH := Vector3(-54.4, -0.7, -217.7)        # люк в потолке тамбура (низ потолка)
const HALF := 0.45                                  # полкрышки (крышка 0.9 × 0.9)
const YARD_HATCH := Vector3(-58.0, 0.0, -232.1)    # HighwayChapter.EXIT_HATCH
const OUT := Vector3(-58.0, 1.62, -233.5)          # BasementExitHatch.OUT_POS, глаза на высоте роста
const AWAY := Vector3(-59.2, 1.62, -239.0)         # отошёл от дома к лесу
const HOUSE_VOICE := Vector3(-62.0, 1.6, -227.5)   # кухня за задней стеной
const DOORWAY := Vector3(-54.4, -1.1, -218.85)     # глаза Итана в двери тамбура
const UNDER := Vector3(-54.4, -1.4, -217.22)       # у скоб, под люком
const SKIP_IDS := [3035, 3042, 3043]                # дверь наверху, рама и крышка люка — здесь свои
const HAND_DOWN := Vector3(0.12, -0.42, -0.4)       # рука в кадре камеры: ниже кадра
const HAND_LID := Vector3(0.07, -0.05, -0.68)       # ладонь у крышки

var lid: Node3D
var hand: Node3D
var crack_light: OmniLight3D
var crack_glow: Array = []
var dirt: CPUParticles3D
var moon: DirectionalLight3D


func build() -> void:
	set_env(Color(0.012, 0.016, 0.026), Color(0.38, 0.42, 0.55), 2.6, 0.0, Color(0.05, 0.06, 0.09), 1.4)
	# Тамбур со скобами — из подвала с карты; двор, дом и лес — с поверхности карты
	CutsceneKit.map_area(self, MAP, Vector3(-54.4, 0.0, -218.0), 3.2, [], SKIP_IDS, AABB(), true, -0.3)
	CutsceneKit.map_area(self, MAP, Vector3(-60.0, 0.0, -236.0), 32.0, [], [], AABB(Vector3(-71.0, 0.0, -230.9), Vector3(18.0, 7.0, 11.8)))
	# Земля матовая, как в HighwayChapter: без блика луны она не похожа на снег
	var floor_m: StandardMaterial3D = CutsceneKit.tmat("forest_floor.png", Color(0.42, 0.46, 0.38), 0.35).duplicate()
	floor_m.roughness = 1.0
	floor_m.metallic_specular = 0.05
	CutsceneKit.ground(self, Vector3(-60.0, 0.0, -236.0), Vector2(90, 90), floor_m)
	_night_sky()
	CutsceneKit.grass(self, Vector3(-58.0, 0.0, -236.6), Vector2(11.0, 7.0), 130, 21, 1.0)
	CutsceneKit.grass(self, Vector3(-63.4, 0.0, -232.4), Vector2(4.5, 2.4), 30, 22, 0.8)
	CutsceneKit.grass(self, Vector3(-52.6, 0.0, -232.4), Vector2(4.5, 2.4), 30, 23, 0.8)
	CutsceneKit.forest(self, Vector3(-60.0, 0.0, -236.0), 9.0, 30.0, 46, 5, 9.0, 16.0, func(_x: float, z: float) -> bool: return z > -240.0)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-30, 230, 0)
	moon.shadow_enabled = true
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	_inside_hatch()
	_yard_hatch()


# Ночное небо (в люке и над лесом): тёмно-синее, светлее у горизонта
func _night_sky() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.016, 0.024, 0.048)
	sky_mat.sky_horizon_color = Color(0.055, 0.07, 0.105)
	sky_mat.ground_horizon_color = Color(0.03, 0.036, 0.05)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.015)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky


# Потолок тамбура с проёмом, короткая шахта до земли, железная рама и крышка на петлях
func _inside_hatch() -> void:
	var wood := TextureHelper.create_wall_material("wood_planks", Color.html("4a3a2a"))
	var iron := TextureHelper.create_wall_material("rusted_metal", Color.html("2a2420"))
	var earth := CutsceneKit.tmat("dirt_path.png", Color(0.35, 0.28, 0.21), 1.5)
	var x0 := HATCH.x - HALF
	var x1 := HATCH.x + HALF
	var z0 := HATCH.z - HALF
	var z1 := HATCH.z + HALF
	CutsceneKit.box(self, Vector3(x0 + 56.0, 0.2, 3.0), Vector3((x0 - 56.0) * 0.5, -0.6, -218.1), wood)
	CutsceneKit.box(self, Vector3(-52.8 - x1, 0.2, 3.0), Vector3((x1 - 52.8) * 0.5, -0.6, -218.1), wood)
	CutsceneKit.box(self, Vector3(HALF * 2.0, 0.2, z0 + 219.6), Vector3(HATCH.x, -0.6, (z0 - 219.6) * 0.5), wood)
	CutsceneKit.box(self, Vector3(HALF * 2.0, 0.2, -216.6 - z1), Vector3(HATCH.x, -0.6, (z1 - 216.6) * 0.5), wood)
	for w in [[Vector3(0.1, 0.7, 1.1), Vector3(x0 - 0.05, -0.35, HATCH.z)], [Vector3(0.1, 0.7, 1.1), Vector3(x1 + 0.05, -0.35, HATCH.z)],
			[Vector3(1.1, 0.7, 0.1), Vector3(HATCH.x, -0.35, z0 - 0.05)], [Vector3(1.1, 0.7, 0.1), Vector3(HATCH.x, -0.35, z1 + 0.05)]]:
		CutsceneKit.box(self, w[0], w[1], earth)
	for f in [[Vector3(1.1, 0.06, 0.1), Vector3(HATCH.x, -0.73, z0 - 0.05)], [Vector3(1.1, 0.06, 0.1), Vector3(HATCH.x, -0.73, z1 + 0.05)],
			[Vector3(0.1, 0.06, 0.9), Vector3(x0 - 0.05, -0.73, HATCH.z)], [Vector3(0.1, 0.06, 0.9), Vector3(x1 + 0.05, -0.73, HATCH.z)]]:
		CutsceneKit.box(self, f[0], f[1], iron)
	# Крышка: петли на северном краю (над скобами), открывается вверх и встаёт к стенке шахты
	lid = CutsceneKit.node(self, Vector3(HATCH.x, -0.72, z1), Vector3.ZERO, "Lid")
	CutsceneKit.box(lid, Vector3(0.88, 0.05, 0.88), Vector3(0, 0.0, -HALF), TextureHelper.create_wall_material("wood_planks", Color.html("3e3022")))
	for x in [-0.24, 0.24]:
		CutsceneKit.box(lid, Vector3(0.06, 0.025, 0.84), Vector3(x, -0.037, -HALF), iron)
	CutsceneKit.cyl(lid, 0.035, 0.035, 0.012, Vector3(0.0, -0.05, -HALF - 0.12), iron)
	# Лунный свет в щелях вокруг крышки
	var leak := CutsceneKit.glow(Color(0.55, 0.62, 0.85), 1.1)
	for g in [[Vector3(0.88, 0.004, 0.008), Vector3(HATCH.x, -0.703, z0 + 0.004)], [Vector3(0.88, 0.004, 0.008), Vector3(HATCH.x, -0.703, z1 - 0.004)],
			[Vector3(0.008, 0.004, 0.88), Vector3(x0 + 0.004, -0.703, HATCH.z)], [Vector3(0.008, 0.004, 0.88), Vector3(x1 - 0.004, -0.703, HATCH.z)]]:
		crack_glow.append(CutsceneKit.box(self, g[0], g[1], leak, Vector3.ZERO, false))
	crack_light = OmniLight3D.new()
	crack_light.light_color = Color(0.6, 0.68, 0.92)
	crack_light.light_energy = 0.7
	crack_light.omni_range = 2.8
	crack_light.position = HATCH + Vector3(0.0, 0.3, 0.0)
	add_child(crack_light)
	dirt = CutsceneKit.debris(self, HATCH + Vector3(0.0, -0.03, -0.1), Vector3(0.38, 0.02, 0.3), 32, Color(0.13, 0.11, 0.08), 0.007, 1.0)
	# Рука Итана у камеры: пальцы вверх, ладонь к крышке, рукав уходит вниз из кадра
	hand = CutsceneCast.hand(false)
	cam.add_child(hand)
	hand.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
	hand.position = HAND_DOWN
	hand.curl = 0.12
	hand.visible = false


# Люк во дворе, как его ставит HighwayChapter (железная рама, доски, две полосы) — уже открыт,
# под ним тёмная шахта
func _yard_hatch() -> void:
	var iron := CutsceneKit.mat(Color(0.12, 0.11, 0.1), 0.7, 0.6)
	var wood := CutsceneKit.tmat("res://assets/textures/wood_planks.png", Color(0.62, 0.5, 0.38), 1.0, 0.95)
	var earth := CutsceneKit.tmat("dirt_path.png", Color(0.3, 0.24, 0.18), 1.5)
	var p := YARD_HATCH
	for f in [[Vector3(1.1, 0.05, 0.1), Vector3(0, 0.025, -0.5)], [Vector3(1.1, 0.05, 0.1), Vector3(0, 0.025, 0.5)],
			[Vector3(0.1, 0.05, 0.9), Vector3(-0.5, 0.025, 0)], [Vector3(0.1, 0.05, 0.9), Vector3(0.5, 0.025, 0)]]:
		CutsceneKit.box(self, f[0], p + f[1], iron)
	for w in [[Vector3(0.1, 1.4, 0.9), Vector3(-0.5, -0.7, 0)], [Vector3(0.1, 1.4, 0.9), Vector3(0.5, -0.7, 0)],
			[Vector3(1.1, 1.4, 0.1), Vector3(0, -0.7, -0.5)], [Vector3(1.1, 1.4, 0.1), Vector3(0, -0.7, 0.5)]]:
		CutsceneKit.box(self, w[0], p + w[1], earth)
	CutsceneKit.box(self, Vector3(0.9, 0.05, 0.9), p + Vector3(0, -1.4, 0), CutsceneKit.mat(Color(0.03, 0.03, 0.03), 1.0))
	# Откинутая крышка лежит на траве у стены дома (петли с северного края)
	var yl := CutsceneKit.node(self, p + Vector3(0, 0.06, 0.45), Vector3(-176, 0, 0), "YardLid")
	CutsceneKit.box(yl, Vector3(0.9, 0.04, 0.9), Vector3(0, 0, -0.45), wood)
	for x in [-0.2, 0.2]:
		CutsceneKit.box(yl, Vector3(0.06, 0.03, 0.5), Vector3(x, 0.035, -0.45), iron)


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	var amb := loop("amb_basement", -20.0, 1.0)
	handheld = 0.45
	breathe = 1.1
	# В двери тамбура: скобы на стене, люк в потолке, в щелях — луна
	shot(DOORWAY, Vector3(-54.4, -1.2, -217.15), 66.0)
	fade_in(0.5 if from_game else 1.2)
	sfx("hoof_muffled_1", -6.0, 1.0, Vector3(-56.0, 0.3, -222.0), 8.0)
	await wait(1.2)
	look_to(HATCH + Vector3(0.0, 0.0, 0.15), 0.9)
	sfx("hoof_muffled_2", -6.0, 1.0, Vector3(-57.0, 0.3, -223.5), 8.0)
	await wait(0.9)
	# Шаг к скобам, взгляд вверх, рука к крышке
	sfx("body_shift", -10.0)
	glide(UNDER, HATCH + Vector3(0.0, 0.0, -0.05), 1.1, 70.0)
	await wait(1.0)
	hand.visible = true
	tween_prop(hand, "position", HAND_LID, 0.55, Tween.TRANS_SINE, Tween.EASE_OUT)
	await wait(0.65)
	# Первый раз — крышка поднимается на ладонь и падает обратно, сыплется земля
	sfx("lid_push", -4.0)
	tween_prop(lid, "rotation_degrees", Vector3(7, 0, 0), 0.3)
	tween_prop(hand, "position", HAND_LID + Vector3(0.0, 0.0, -0.06), 0.3)
	tween_prop(crack_light, "light_energy", 2.6, 0.3)
	dirt.restart()
	dirt.emitting = true
	await wait(0.5)
	tween_prop(lid, "rotation_degrees", Vector3.ZERO, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(hand, "position", HAND_LID, 0.16)
	tween_prop(crack_light, "light_energy", 0.7, 0.2)
	sfx("dirt_trickle", -10.0)
	shake(0.35)
	blink(0.12)
	await wait(0.6)
	# Копыта в доме замирают. Тишина. Итан не дышит
	sfx("hoof_muffled_3", -3.0, 1.0, Vector3(-55.0, 0.3, -220.0), 8.0)
	await wait(0.4)
	sfx("ethan_breath_held", -10.0)
	breathe = 0.0
	handheld = 0.2
	fade(amb, -30.0, 0.5)
	await wait(1.4)
	sfx("hoof_muffled_4", -12.0, 1.0, Vector3(-62.0, 0.3, -228.0), 8.0)
	fade(amb, -20.0, 1.0)
	await wait(0.7)
	# Второй раз — плечом: крышка откидывается, сверху ночь и холодный воздух
	breathe = 1.4
	handheld = 0.5
	sfx("lid_open", -2.0)
	move_to(UNDER + Vector3(0.0, 0.28, -0.1), 0.45, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween_prop(lid, "rotation_degrees", Vector3(86, 0, 0), 0.7, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween_prop(hand, "position", HAND_LID + Vector3(0.0, 0.05, -0.35), 0.4)
	# В шахту падает лунный свет
	tween_prop(crack_light, "light_energy", 3.0, 0.5)
	for g in crack_glow:
		(g as Node3D).visible = false
	dirt.restart()
	dirt.emitting = true
	var wind := loop("amb_night_wind", -14.0, 0.6)
	stop(amb, 1.0)
	await wait(0.8)
	# Склейка: люк во дворе за домом. Голова над травой
	hand.visible = false
	env.ambient_light_color = Color(0.2, 0.24, 0.33)
	env.ambient_light_energy = 1.25
	env.fog_enabled = true
	env.fog_density = 0.012
	shot(YARD_HATCH + Vector3(0.0, -0.45, -0.1), YARD_HATCH + Vector3(0.0, 0.7, -1.2), 64.0)
	fade(wind, -9.0, 0.6)
	sfx("grass_rustle", -8.0)
	glide(YARD_HATCH + Vector3(0.0, 0.42, -0.25), YARD_HATCH + Vector3(0.2, 0.9, -7.0), 1.1, 64.0, Tween.TRANS_SINE, Tween.EASE_OUT)
	await wait(1.2)
	sfx("body_shift", -9.0)
	glide(YARD_HATCH + Vector3(-0.05, 0.95, -0.9), YARD_HATCH + Vector3(0.4, 1.0, -8.0), 1.0)
	await wait(1.1)
	glide(OUT, OUT + Vector3(0.6, -0.1, -8.0), 1.2, 62.0)
	handheld = 0.6
	await wait(1.3)
	# Ночь, лес, ветер. Ни огонька
	look_to(OUT + Vector3(5.0, -0.2, -7.0), 1.1)
	await wait(1.1)
	look_to(OUT + Vector3(-4.5, 0.0, -7.5), 1.2)
	await wait(1.0)
	# Отходит от дома к лесу — и оборачивается
	for i in 4:
		sfx("step_grass_%d" % (i + 1), -12.0)
		move_to(OUT.lerp(AWAY, (i + 1) / 4.0), 0.52, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		await wait(0.52)
	look_to(Vector3(-61.5, 3.0, -231.0), 1.7, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await wait(1.8)
	# Тёмный дом. И где-то в нём голос Сэма
	look_to(Vector3(-62.0, 2.7, -231.0), 3.0)
	await line("mimic_sam_where", "ГОЛОС СЭМА", "Итан?.. Итан, куда ты ушёл?..", 0.6, HOUSE_VOICE, 6.0, 14.0)
	breathe = 1.8
	sfx("step_grass_2", -15.0)
	move_to(AWAY + Vector3(0.0, 0.0, -0.35), 0.8)
	await wait(0.9)
	if not from_game:
		fade_out(1.5)
		stop(wind, 1.5)
		await wait(1.8)
