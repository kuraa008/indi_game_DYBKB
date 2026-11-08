extends Cutscene

# КОНЕЦ ГЛАВЫ 2 · «Лаз». В игре Итан сам лезет в люк тамбура и ползёт по лазу (присев);
# последние метры и крышка — эта кат-сцена. Узкий земляной лаз, укреплённый досками, идёт
# под домом к заднему двору. Сверху по полу дома стучат копыта, с досок сыплется земля.
# Лаз упирается в шахту, наверху деревянная крышка, в щелях — луна. Первый раз крышка
# не поддаётся и падает обратно — копыта наверху замирают, Итан не дышит. Второй раз он
# выдавливает её ПЛЕЧОМ и выбирается во двор за домом, в высокую траву. Ночь, холодный
# ветер, лес. Тихо опускает крышку, отходит к лесу, оборачивается на тёмный дом —
# и где-то в доме голос Сэма: «Итан?.. Итан, куда ты ушёл?..»
#
# Выход совпадает с картой: люк во дворе (HighwayChapter.EXIT_HATCH) — железная рама,
# доски и две полосы, как его строит игра; после сцены он снова закрыт, как в игре.
# Последний кадр — Итан стоит у опушки (≈ BasementExitHatch.OUT_POS + 5.5 м к лесу),
# смотрит на заднюю стену дома.
# В сюжете люк «за старым колодцем»: на карте у люка колодца нет, поэтому здесь просто трава.
# args.from_gameplay = true — короткое появление и без затемнения в конце.

const MAP := "res://scenes/Шоссе.json"
const HATCH := Vector3(-58.0, 0.0, -232.1)        # HighwayChapter.EXIT_HATCH
const HALF := 0.45                                 # полкрышки (крышка 0.9 × 0.9)
const HINGE_Z := HATCH.z + HALF                    # петли с северного края (со стороны дома)
const FLOOR_Y := -1.4                              # дно шахты и лаза
const CEIL_Y := -0.55                              # потолок лаза: только ползком
const TUN_FROM := -226.4                           # отсюда видно лаз (под кухней дома)
const CRAWL_FROM := Vector3(-58.0, -0.98, -227.3)
const CRAWL_TO := Vector3(-58.0, -0.97, -231.0)
const UNDER_LID := Vector3(-58.02, -0.36, -232.02)  # присел в шахте, голова под крышкой
const OUT := Vector3(-58.0, 1.62, -233.5)          # BasementExitHatch.OUT_POS, глаза на высоте роста
const AWAY := Vector3(-59.2, 1.62, -239.0)         # отошёл от дома к лесу
const HOUSE_VOICE := Vector3(-62.0, 1.6, -227.5)   # кухня за задней стеной
const HAND_DOWN := Vector3(0.12, -0.42, -0.4)      # рука в кадре камеры: ниже кадра
const HAND_LID := Vector3(0.07, -0.05, -0.62)      # ладонь у крышки

var lid: Node3D
var hand: Node3D
var crack_light: OmniLight3D
var crack_glow: Array = []
var dirt: CPUParticles3D
var dirt_lid: CPUParticles3D
var moon: DirectionalLight3D


func build() -> void:
	set_env(Color(0.012, 0.016, 0.026), Color(0.38, 0.42, 0.55), 0.85, 0.0, Color(0.05, 0.06, 0.09), 1.4)
	# Двор, дом и лес — с поверхности карты (без подвала и без вещей внутри дома)
	CutsceneKit.map_area(self, MAP, Vector3(-60.0, 0.0, -236.0), 32.0, [], [], AABB(Vector3(-71.0, 0.0, -230.9), Vector3(18.0, 7.0, 11.8)))
	_ground_with_hole()
	_night_sky()
	CutsceneKit.grass(self, Vector3(-58.0, 0.0, -236.6), Vector2(11.0, 7.0), 150, 21, 1.1)
	CutsceneKit.grass(self, Vector3(-63.4, 0.0, -232.3), Vector2(4.5, 2.2), 36, 22, 1.0)
	CutsceneKit.grass(self, Vector3(-52.6, 0.0, -232.3), Vector2(4.5, 2.2), 36, 23, 1.0)
	CutsceneKit.forest(self, Vector3(-60.0, 0.0, -236.0), 9.0, 30.0, 46, 5, 9.0, 16.0, func(_x: float, z: float) -> bool: return z > -240.0)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.85
	moon.rotation_degrees = Vector3(-30, 230, 0)
	moon.shadow_enabled = true
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moon)
	_tunnel()
	_hatch()


# Земля вокруг люка — четыре куска с дыркой под шахту: сверху в открытый люк видно темноту
func _ground_with_hole() -> void:
	var floor_m: StandardMaterial3D = CutsceneKit.tmat("forest_floor.png", Color(0.42, 0.46, 0.38), 0.35).duplicate()
	floor_m.roughness = 1.0
	floor_m.metallic_specular = 0.05
	var x0 := -105.0
	var x1 := -15.0
	var z0 := -281.0
	var z1 := -191.0
	var hx0 := HATCH.x - HALF
	var hx1 := HATCH.x + HALF
	var hz0 := HATCH.z - HALF
	var hz1 := HATCH.z + HALF
	for r in [[x0, x1, hz1, z1], [x0, x1, z0, hz0], [x0, hx0, hz0, hz1], [hx1, x1, hz0, hz1]]:
		CutsceneKit.ground(self, Vector3((r[0] + r[1]) * 0.5, 0.0, (r[2] + r[3]) * 0.5), Vector2(r[1] - r[0], r[3] - r[2]), floor_m)


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


# Лаз: идёт с севера (из-под дома) на юг и выходит в шахту под люком.
# Земляные стены, доски-крепь через каждые 0.9 м, корни в потолке, комья и камни.
func _tunnel() -> void:
	var earth := CutsceneKit.tmat("dirt_path.png", Color(0.4, 0.31, 0.23), 1.5)
	var wood := CutsceneKit.tmat("board_weathered.png", Color(0.5, 0.42, 0.34), 1.6)
	var root_m := CutsceneKit.mat(Color(0.16, 0.12, 0.09), 0.9)
	var x := HATCH.x
	var z_end := HATCH.z - HALF          # южная стенка шахты
	var len_all := absf(z_end - TUN_FROM)
	var len_roof := absf(HINGE_Z - TUN_FROM)
	CutsceneKit.box(self, Vector3(1.1, 0.1, len_all), Vector3(x, FLOOR_Y - 0.05, (TUN_FROM + z_end) * 0.5), earth)
	CutsceneKit.box(self, Vector3(1.1, 0.14, len_roof), Vector3(x, CEIL_Y + 0.07, (TUN_FROM + HINGE_Z) * 0.5), earth)
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, Vector3(0.2, 1.5, len_all + 0.2), Vector3(x + 0.55 * s, -0.7, (TUN_FROM + z_end) * 0.5), earth)
	CutsceneKit.box(self, Vector3(1.1, 1.0, 0.2), Vector3(x, FLOOR_Y + 0.45, TUN_FROM + 0.1), earth)
	# Стенки шахты: над устьем лаза и южная
	CutsceneKit.box(self, Vector3(1.1, absf(CEIL_Y) + 0.05, 0.2), Vector3(x, CEIL_Y * 0.5, HINGE_Z + 0.1), earth)
	CutsceneKit.box(self, Vector3(1.1, 1.5, 0.2), Vector3(x, -0.7, z_end - 0.1), earth)
	# Доски-крепь: две стойки и перекладина
	var z := TUN_FROM - 0.5
	while z > HINGE_Z + 0.3:
		for s in [-1.0, 1.0]:
			CutsceneKit.box(self, Vector3(0.06, 0.84, 0.08), Vector3(x + 0.42 * s, FLOOR_Y + 0.42, z), wood)
		CutsceneKit.box(self, Vector3(0.92, 0.05, 0.14), Vector3(x, CEIL_Y - 0.03, z), wood)
		z -= 0.9
	# Доски потолка над шахтой — рама, на которую садится крышка
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var clod := CutsceneKit.mat(Color(0.2, 0.16, 0.12), 1.0)
	var pebble := CutsceneKit.mat(Color(0.3, 0.29, 0.27), 0.8)
	for i in 44:
		var side := -1.0 if i % 2 == 0 else 1.0
		var cp := Vector3(x + side * rng.randf_range(0.43, 0.46), FLOOR_Y + rng.randf_range(0.05, 0.8), rng.randf_range(HINGE_Z, TUN_FROM))
		CutsceneKit.ball(self, rng.randf_range(0.04, 0.11), cp, clod if i % 3 else pebble, Vector3(0.6, rng.randf_range(0.5, 1.0), 1.0), 6)
	for i in 12:
		var fp := Vector3(x + rng.randf_range(-0.35, 0.35), FLOOR_Y + 0.02, rng.randf_range(z_end, TUN_FROM))
		CutsceneKit.ball(self, rng.randf_range(0.03, 0.07), fp, clod, Vector3(1.0, 0.45, 1.0), 6)
	for i in 18:
		var rp := Vector3(x + rng.randf_range(-0.4, 0.4), CEIL_Y - 0.02, rng.randf_range(HINGE_Z, TUN_FROM))
		CutsceneKit.cyl(self, 0.004, 0.012, rng.randf_range(0.12, 0.3), rp + Vector3(0, -0.08, 0), root_m, Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 5)
	# Земля, что сыплется с досок, когда наверху ступает копыто
	dirt = CutsceneKit.debris(self, Vector3(x, CEIL_Y - 0.05, -228.5), Vector3(0.3, 0.02, 0.6), 40, Color(0.25, 0.2, 0.15), 0.015, 0.8)


# Люк во дворе, как его ставит HighwayChapter: железная рама, доски, две железные полосы.
# Петли — с северного края, крышка откидывается к стене дома.
func _hatch() -> void:
	var iron := CutsceneKit.mat(Color(0.12, 0.11, 0.1), 0.7, 0.6)
	var wood := CutsceneKit.tmat("res://assets/textures/wood_planks.png", Color(0.32, 0.24, 0.17), 1.0, 0.95)
	var p := HATCH
	for f in [[Vector3(1.1, 0.05, 0.1), Vector3(0, 0.025, -0.5)], [Vector3(1.1, 0.05, 0.1), Vector3(0, 0.025, 0.5)],
			[Vector3(0.1, 0.05, 0.9), Vector3(-0.5, 0.025, 0)], [Vector3(0.1, 0.05, 0.9), Vector3(0.5, 0.025, 0)]]:
		CutsceneKit.box(self, f[0], p + f[1], iron)
	lid = CutsceneKit.node(self, Vector3(p.x, 0.06, HINGE_Z), Vector3.ZERO, "Lid")
	CutsceneKit.box(lid, Vector3(0.9, 0.04, 0.9), Vector3(0, 0, -HALF), wood)
	for lx in [-0.2, 0.2]:
		CutsceneKit.box(lid, Vector3(0.06, 0.03, 0.5), Vector3(lx, 0.03, -HALF), iron)
	# Снизу: поперечина и ручка-скоба
	CutsceneKit.box(lid, Vector3(0.84, 0.03, 0.06), Vector3(0, -0.035, -HALF), wood)
	# Лунный свет в щелях вокруг крышки
	var leak := CutsceneKit.glow(Color(0.55, 0.62, 0.85), 1.1)
	for g in [[Vector3(0.88, 0.004, 0.008), Vector3(p.x, 0.035, p.z - HALF + 0.004)], [Vector3(0.88, 0.004, 0.008), Vector3(p.x, 0.035, p.z + HALF - 0.004)],
			[Vector3(0.008, 0.004, 0.88), Vector3(p.x - HALF + 0.004, 0.035, p.z)], [Vector3(0.008, 0.004, 0.88), Vector3(p.x + HALF - 0.004, 0.035, p.z)]]:
		crack_glow.append(CutsceneKit.box(self, g[0], g[1], leak, Vector3.ZERO, false))
	crack_light = OmniLight3D.new()
	crack_light.light_color = Color(0.6, 0.68, 0.92)
	crack_light.light_energy = 0.9
	crack_light.omni_range = 5.5
	crack_light.position = p + Vector3(0.0, -0.1, 0.0)
	add_child(crack_light)
	dirt_lid = CutsceneKit.debris(self, p + Vector3(0.0, 0.0, 0.0), Vector3(0.38, 0.02, 0.38), 40, Color(0.13, 0.11, 0.08), 0.008, 1.0)
	# Рука Итана у камеры: пальцы вверх, ладонь к крышке
	hand = CutsceneCast.hand(false)
	cam.add_child(hand)
	hand.basis = Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))
	hand.position = HAND_DOWN
	hand.curl = 0.12
	hand.visible = false


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	var amb := loop("amb_basement", -20.0, 1.0)
	handheld = 0.45
	breathe = 1.2
	# Ползком по лазу; впереди, в конце, бледный свет из щелей крышки
	shot(CRAWL_FROM, CRAWL_FROM + Vector3(0.0, -0.08, -3.0), 68.0)
	fade_in(0.5 if from_game else 1.3)
	for i in 5:
		var p := CRAWL_FROM.lerp(CRAWL_TO, (i + 1) / 5.0)
		move_to(p + Vector3(0, -0.04, 0), 0.72, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		tween_prop(self, "cam_roll", 0.045 * (1.0 if i % 2 == 0 else -1.0), 0.38)
		sfx("crawl_%d" % (i % 3 + 1), -8.0)
		if i == 1 or i == 3:
			# Сверху по полу дома стучат копыта: с досок сыплется земля
			sfx("hoof_muffled_%d" % (i / 2 + 1), -4.0, 1.0, Vector3(-58.5, 0.4, p.z + 0.6), 8.0)
			dirt.position.z = p.z - 0.5
			dirt.restart()
			dirt.emitting = true
			sfx("dirt_trickle", -12.0)
			shake(0.15)
			look_to(Vector3(-58.0, CEIL_Y, p.z - 0.4), 0.35)
			await wait(0.4)
			look_to(CRAWL_TO + Vector3(0.0, -0.05, -3.0), 0.45)
			await wait(0.38)
		else:
			await wait(0.78)
	tween_prop(self, "cam_roll", 0.0, 0.4)
	# Шахта. Наверху — крышка, вокруг неё светится полоска луны
	sfx("body_shift", -10.0)
	glide(UNDER_LID, HATCH + Vector3(0.0, 0.0, -0.05), 1.3, 72.0)
	await wait(1.3)
	hand.visible = true
	tween_prop(hand, "position", HAND_LID, 0.5, Tween.TRANS_SINE, Tween.EASE_OUT)
	await wait(0.6)
	# Первый раз — крышка поднимается на ладонь и падает обратно, сыплется земля
	sfx("lid_push", -4.0)
	tween_prop(lid, "rotation_degrees", Vector3(7, 0, 0), 0.3)
	tween_prop(hand, "position", HAND_LID + Vector3(0.0, 0.0, -0.05), 0.3)
	tween_prop(crack_light, "light_energy", 2.2, 0.3)
	dirt_lid.restart()
	dirt_lid.emitting = true
	await wait(0.5)
	tween_prop(lid, "rotation_degrees", Vector3.ZERO, 0.16, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(hand, "position", HAND_LID, 0.16)
	tween_prop(crack_light, "light_energy", 0.9, 0.2)
	sfx("dirt_trickle", -10.0)
	shake(0.35)
	blink(0.12)
	await wait(0.5)
	# Копыта в доме замирают. Тишина. Итан не дышит
	sfx("hoof_muffled_3", -3.0, 1.0, Vector3(-58.5, 0.4, -229.0), 8.0)
	await wait(0.4)
	sfx("ethan_breath_held", -10.0)
	breathe = 0.0
	handheld = 0.15
	fade(amb, -32.0, 0.5)
	await wait(1.5)
	sfx("hoof_muffled_4", -12.0, 1.0, Vector3(-63.0, 0.4, -225.0), 8.0)
	fade(amb, -20.0, 1.0)
	await wait(0.7)
	# Второй раз — плечом: голова набок, плечо в крышку, рывок вверх
	hand.visible = false
	breathe = 1.4
	handheld = 0.5
	tween_prop(self, "cam_roll", -0.32, 0.35)
	look_to(HATCH + Vector3(0.35, 0.2, -0.05), 0.35)
	await wait(0.4)
	sfx("lid_open", -2.0)
	sfx("ethan_groan", -11.0)
	move_to(UNDER_LID + Vector3(0.0, 0.3, 0.0), 0.4, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween_prop(lid, "rotation_degrees", Vector3(176, 0, 0), 0.9, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(crack_light, "light_energy", 0.0, 0.6)
	for g in crack_glow:
		(g as Node3D).visible = false
	dirt_lid.restart()
	dirt_lid.emitting = true
	shake(0.3)
	var wind := loop("amb_night_wind", -13.0, 0.5)
	stop(amb, 1.0)
	tween_prop(env, "ambient_light_energy", 1.25, 0.8)
	await wait(0.45)
	tween_prop(self, "cam_roll", 0.0, 0.6)
	look_to(HATCH + Vector3(0.0, 2.0, -3.0), 0.6)
	await wait(0.6)
	# Выбирается: голова над травой, впереди лес
	env.fog_enabled = true
	env.fog_density = 0.012
	fade(wind, -9.0, 0.6)
	sfx("grass_rustle", -8.0)
	glide(HATCH + Vector3(0.0, 0.42, -0.2), HATCH + Vector3(0.2, 0.9, -7.0), 1.1, 64.0, Tween.TRANS_SINE, Tween.EASE_OUT)
	await wait(1.2)
	sfx("body_shift", -9.0)
	glide(HATCH + Vector3(-0.05, 0.95, -0.95), HATCH + Vector3(0.4, 1.0, -8.0), 1.0)
	await wait(1.1)
	glide(OUT, OUT + Vector3(0.6, -0.1, -8.0), 1.1, 62.0)
	handheld = 0.6
	await wait(1.2)
	# Ночь, лес, ветер. Ни огонька
	look_to(OUT + Vector3(5.0, -0.2, -7.0), 1.0)
	await wait(1.0)
	look_to(OUT + Vector3(-4.5, 0.0, -7.5), 1.1)
	await wait(1.0)
	# Оборачивается к люку и тихо опускает крышку, чтобы не стукнула
	look_to(HATCH + Vector3(0.0, 0.1, 0.0), 1.0)
	await wait(0.9)
	tween_prop(lid, "rotation_degrees", Vector3.ZERO, 1.3, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await wait(1.3)
	sfx("lid_push", -18.0)
	await wait(0.4)
	# Отходит от дома к лесу — и оборачивается
	look_to(OUT + Vector3(0.6, -0.1, -8.0), 0.9)
	await wait(0.5)
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
