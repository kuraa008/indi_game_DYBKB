extends Cutscene

# КОНЕЦ ГЛАВЫ 2 · «Лаз». Последние метры узкого земляного лаза под двором: сверху
# по полу дома стучат копыта. Лаз упирается в деревянную крышку — Итан выдавливает
# её плечом и выбирается в высокую траву за поленницей. Ночь, холодный ветер,
# дом в двадцати шагах. Из дома голос Сэма: «Итан?.. Итан, куда ты ушёл?..»
#
# Лаз идёт от дома на запад; выход — в траве за домом с карты «Шоссе».
# В сюжете выход «за старым колодцем»; Досым в заметках предлагает заменить колодец
# поленницей, чтобы не путать с колодцем Крейна, — здесь поленница (USE_WELL вернёт колодец).

const MAP := "res://scenes/Шоссе.json"
const USE_WELL := false
const Z := -226.0
const FLOOR_Y := -1.15
const RAMP_X := -82.4          # отсюда пол лаза поднимается к крышке
const LID_FAR := -84.3         # дальний край крышки (петли)
const LID_NEAR := -83.35
const CRAWL_FROM := Vector3(-78.6, -0.72, Z)
const CRAWL_TO := Vector3(-82.3, -0.7, Z)
const UNDER_LID := Vector3(-83.1, -0.42, Z)
const OUT := Vector3(-84.55, 0.8, Z - 0.1)
const HOUSE_VOICE := Vector3(-71.6, 1.6, -226.0)

var lid: Node3D
var crack_light: OmniLight3D
var dirt: CPUParticles3D
var dirt2: CPUParticles3D


func build() -> void:
	set_env(Color(0.015, 0.02, 0.03), Color(0.17, 0.2, 0.28), 0.95, 0.012, Color(0.05, 0.06, 0.09), 1.2)
	CutsceneKit.map_area(self, MAP, Vector3(-66, 0, -225), 30.0)
	CutsceneKit.ground(self, Vector3(-70, 0.0, -225), Vector2(80, 80), CutsceneKit.tmat("forest_floor.png", Color(0.55, 0.6, 0.5), 0.35))
	CutsceneKit.grass(self, Vector3(-84.2, 0, Z), Vector2(5, 5), 110, 21, 1.0)
	CutsceneKit.grass(self, Vector3(-78, 0, Z), Vector2(8, 10), 90, 22, 0.8)
	CutsceneKit.forest(self, Vector3(-82, 0, Z), 9.0, 30.0, 46, 5, 9.0, 16.0, func(x: float, _z: float) -> bool: return x > -75.0)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 1.0
	moon.rotation_degrees = Vector3(-32, -110, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 45.0
	add_child(moon)
	if USE_WELL:
		_well(Vector3(-82.6, 0, Z + 0.6))
	else:
		CutsceneKit.woodpile(self, Vector3(-82.75, 0, Z + 0.95), 90.0, 2.2, 5)
	_tunnel()


func _well(p: Vector3) -> void:
	var stone := CutsceneKit.tmat("res://assets/textures/nature/rock_tile.png", Color(0.5, 0.48, 0.45), 1.2)
	for i in 12:
		var a := i / 12.0 * TAU
		CutsceneKit.box(self, Vector3(0.38, 0.75, 0.22), p + Vector3(cos(a) * 0.62, 0.37, sin(a) * 0.62), stone, Vector3(0, -rad_to_deg(a), 0))
	CutsceneKit.box(self, Vector3(1.5, 0.08, 1.5), p + Vector3(0, 0.78, 0), CutsceneKit.tmat("board_weathered.png", Color(0.5, 0.45, 0.4), 1.5))


func _tunnel() -> void:
	var earth := CutsceneKit.tmat("dirt_path.png", Color(0.4, 0.31, 0.23), 1.5)
	var wood := CutsceneKit.tmat("board_weathered.png", Color(0.5, 0.42, 0.34), 1.6)
	var root_m := CutsceneKit.mat(Color(0.16, 0.12, 0.09), 0.9)
	var x0 := -77.6
	var ceil_y := FLOOR_Y + 0.88
	var mid := (x0 + RAMP_X) * 0.5
	var len := absf(RAMP_X - x0)
	# Ровная часть: пол, потолок, стены
	CutsceneKit.box(self, Vector3(len, 0.1, 1.2), Vector3(mid, FLOOR_Y - 0.05, Z), earth)
	CutsceneKit.box(self, Vector3(absf(LID_NEAR - x0), 0.12, 1.2), Vector3((x0 + LID_NEAR) * 0.5, ceil_y + 0.06, Z), earth)
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, Vector3(absf(LID_FAR - x0) + 0.3, 1.5, 0.2), Vector3((x0 + LID_FAR) * 0.5, FLOOR_Y + 0.7, Z + 0.55 * s), earth)
	CutsceneKit.box(self, Vector3(0.2, 1.0, 1.2), Vector3(x0 + 0.1, FLOOR_Y + 0.44, Z), earth)
	# Подъём к крышке и земля за ней
	var ramp_len := Vector2(LID_FAR - RAMP_X, 0.0 - FLOOR_Y).length()
	var ramp_ang := rad_to_deg(atan2(0.0 - FLOOR_Y, absf(LID_FAR - RAMP_X)))
	CutsceneKit.box(self, Vector3(ramp_len, 0.1, 1.2), Vector3((RAMP_X + LID_FAR) * 0.5, FLOOR_Y * 0.5 - 0.05, Z), earth, Vector3(0, 0, -ramp_ang))
	CutsceneKit.box(self, Vector3(0.2, 1.4, 1.2), Vector3(LID_FAR - 0.1, -0.7, Z), earth)
	# Доски-крепь
	var x := x0 - 0.3
	while x > LID_NEAR + 0.4:
		for s in [-1.0, 1.0]:
			CutsceneKit.box(self, Vector3(0.08, 0.86, 0.06), Vector3(x, FLOOR_Y + 0.43, Z + 0.42 * s), wood)
		CutsceneKit.box(self, Vector3(0.14, 0.05, 0.92), Vector3(x, ceil_y - 0.03, Z), wood)
		x -= 1.05
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var clod := CutsceneKit.mat(Color(0.2, 0.16, 0.12), 1.0)
	var pebble := CutsceneKit.mat(Color(0.3, 0.29, 0.27), 0.8)
	for i in 40:
		var side := -1.0 if i % 2 == 0 else 1.0
		var cp := Vector3(rng.randf_range(RAMP_X, x0), FLOOR_Y + rng.randf_range(0.05, 0.8), Z + side * rng.randf_range(0.43, 0.47))
		CutsceneKit.ball(self, rng.randf_range(0.04, 0.11), cp, clod if i % 3 else pebble, Vector3(1.0, rng.randf_range(0.5, 1.0), 0.6), 6)
	for i in 16:
		var rp := Vector3(rng.randf_range(LID_NEAR, x0), ceil_y - 0.02, Z + rng.randf_range(-0.4, 0.4))
		CutsceneKit.cyl(self, 0.004, 0.012, rng.randf_range(0.12, 0.3), rp + Vector3(0, -0.08, 0), root_m, Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20)), 5)
	# Крышка: лежит в траве, петли на дальнем крае; открывается вперёд
	lid = CutsceneKit.node(self, Vector3(LID_FAR, 0.0, Z), Vector3.ZERO, "Lid")
	var w := LID_NEAR - LID_FAR
	for i in 5:
		CutsceneKit.box(lid, Vector3(w, 0.05, 0.17), Vector3(w * 0.5, 0.0, -0.36 + i * 0.18), wood)
	CutsceneKit.box(lid, Vector3(w, 0.03, 0.88), Vector3(w * 0.5, 0.04, 0), CutsceneKit.tmat("forest_floor.png", Color(0.45, 0.5, 0.38), 1.0))
	for i in 4:
		CutsceneKit.box(self, Vector3(w - 0.06, 0.003, 0.004), Vector3((LID_FAR + LID_NEAR) * 0.5, -0.03, Z - 0.27 + i * 0.18), CutsceneKit.glow(Color(0.5, 0.58, 0.8), 0.55), Vector3.ZERO, false)
	crack_light = OmniLight3D.new()
	crack_light.light_color = Color(0.6, 0.68, 0.9)
	crack_light.light_energy = 0.8
	crack_light.omni_range = 3.4
	crack_light.position = Vector3(-83.8, -0.2, Z)
	add_child(crack_light)
	dirt = CutsceneKit.debris(self, Vector3(-81.0, ceil_y - 0.05, Z), Vector3(0.6, 0.02, 0.3), 40, Color(0.25, 0.2, 0.15), 0.015, 0.8)
	dirt2 = CutsceneKit.debris(self, Vector3(-83.8, -0.06, Z), Vector3(0.4, 0.02, 0.35), 50, Color(0.22, 0.2, 0.15), 0.018, 1.0)


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	env.ambient_light_energy = 0.2
	var amb := loop("amb_basement", -22.0, 1.0)
	handheld = 0.45
	breathe = 1.2
	shot(CRAWL_FROM, CRAWL_FROM + Vector3(-3.0, -0.05, 0), 66.0)
	fade_in(0.6 if from_game else 1.4)
	# Ползёт: каждый рывок — рука, колено, земля
	for i in 5:
		var p := CRAWL_FROM.lerp(CRAWL_TO, (i + 1) / 5.0)
		move_to(p + Vector3(0, -0.04, 0), 0.75, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
		tween_prop(self, "cam_roll", 0.04 * (1.0 if i % 2 == 0 else -1.0), 0.4)
		sfx("crawl_%d" % (i % 3 + 1), -8.0)
		if i == 1 or i == 3:
			# Сверху по полу дома стучат копыта: с досок сыплется земля
			sfx("hoof_muffled_%d" % (i / 2 + 1), -4.0)
			dirt.position.x = p.x - 0.4
			dirt.restart()
			dirt.emitting = true
			sfx("dirt_trickle", -12.0)
			shake(0.15)
		await wait(0.82)
	sfx("hoof_muffled_3", -7.0)
	tween_prop(self, "cam_roll", 0.0, 0.5)
	# Подъём к крышке: щели светятся
	glide(UNDER_LID, Vector3(-83.9, 0.05, Z), 1.4)
	sfx("body_shift", -10.0)
	await wait(1.7)
	# Плечом — раз: крышка приподнимается и падает обратно
	sfx("lid_push", -4.0)
	move_to(UNDER_LID + Vector3(-0.08, 0.08, 0), 0.25, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween_prop(lid, "rotation_degrees", Vector3(0, 0, -11), 0.3)
	tween_prop(crack_light, "light_energy", 1.6, 0.3)
	dirt2.restart()
	dirt2.emitting = true
	await wait(0.55)
	tween_prop(lid, "rotation_degrees", Vector3.ZERO, 0.18, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(crack_light, "light_energy", 0.8, 0.2)
	move_to(UNDER_LID, 0.3)
	shake(0.3)
	await wait(1.0)
	# Второй раз — крышка откидывается вперёд, в траву
	sfx("lid_open", -2.0)
	move_to(UNDER_LID + Vector3(-0.15, 0.12, 0), 0.4)
	tween_prop(lid, "rotation_degrees", Vector3(0, 0, -165), 1.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(crack_light, "light_energy", 0.0, 1.0)
	dirt2.restart()
	dirt2.emitting = true
	var wind := loop("amb_night_wind", -12.0, 1.2)
	tween_prop(env, "ambient_light_energy", 0.95, 1.6)
	stop(amb, 1.5)
	await wait(1.1)
	# Выбирается в высокую траву
	sfx("grass_rustle", -7.0)
	glide(OUT, OUT + Vector3(-3.0, 0.2, -0.4), 1.8, 62.0, Tween.TRANS_SINE, Tween.EASE_OUT)
	handheld = 0.6
	await wait(2.0)
	# Оборачивается: дом в двадцати шагах, за поленницей
	sfx("step_grass_2", -14.0)
	look_to(Vector3(-71.0, 1.4, -226.9), 1.6, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await wait(1.6)
	look_to(Vector3(-71.0, 1.9, -225.6), 3.0)
	await wait(0.8)
	# Где-то в доме голос Сэма
	await line("mimic_sam_where", "ГОЛОС СЭМА", "Итан?.. Итан, куда ты ушёл?..", 0.6, HOUSE_VOICE, 6.0, 14.0)
	breathe = 1.6
	await wait(1.6)
	if not from_game:
		fade_out(1.5)
		stop(wind, 1.5)
		await wait(1.8)
