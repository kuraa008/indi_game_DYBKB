extends Cutscene

# ФИНАЛ · заправка, через несколько дней. Пасмурный день.
#  talk   — Итан кладёт деньги на прилавок: «Вы были правы. Во всём». Бабушка долго
#           смотрит, кивает: «А мой муж? Ты его там не видел?» Итан качает головой, уходит.
#  walk   — (в игре это геймплей) идёт к машине; из леса за заправкой: «Марта… Марта…»
#  drive  — Итан не оборачивается, заводит машину и уезжает. КОНЕЦ.
#  secret — если обернулся: на опушке чёрный олень смотрит человеческими глазами,
#           экран гаснет — секретный кадр, после него игра всё равно заканчивается.
#
# args.part: "all" (talk → walk → drive, по умолчанию), "talk", "walk", "drive", "secret",
# "walk_secret" (talk → walk → secret). Заправка и бабушка — GasStation.gd / CashierModel.gd (Досым).
# Машина — старая отцовская (из гаража): пока это тот же кузов, что у Итана, другого цвета.
# Она стоит у колонки носом на юг (Итан едет обратно в город), водительская дверь — к магазину:
# по дороге от магазина к двери лес с голосом всё время остаётся за спиной.
#
# В игре финал идёт на карте «Заправка» (FinaleStation.gd): оттуда приходят
#   {"part": "talk", "from_gameplay": true}                      — игрок положил деньги на прилавок
#   {"part": "drive", "from_gameplay": true}                     — сел в машину, не обернувшись
#   {"part": "secret", "cam_pos": …, "cam_dir": …, "cam_fov": …} — обернулся: кадр продолжает его взгляд

const COUNTER_CAM := Vector3(24.05, 1.6, 1.3)
const CASHIER_HEAD := Vector3(25.72, 1.5, 1.8)
const DOOR_IN := Vector3(21.96, 1.6, -3.3)
const DOOR_OUT := Vector3(20.6, 1.62, -4.4)
const CAR_AT := Vector3(11.3, 0.0, -3.4)
const CAR_DOOR := Vector3(12.1, 0.0, -3.6)        # водительская дверь, со стороны островка
const FOREST_VOICE := Vector3(40.0, 2.0, -12.0)
const DEER_AT := Vector3(37.5, 0.0, -21.0)

var station: GasStation
var car: Node3D
var deer_node: Node3D
var money: Node3D
var path: Curve3D
var _drive := false
var _drive_s := 0.0
var _speed := 0.0


func build() -> void:
	sky_env(Color(0.5, 0.54, 0.6), Color(0.72, 0.71, 0.68), Color(0.2, 0.2, 0.19), 0.85)
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.64, 0.66)
	env.fog_density = 0.0035
	env.adjustment_saturation = 0.75
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.95, 0.9, 0.82)
	sun.light_energy = 0.9
	sun.rotation_degrees = Vector3(-30, -150, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	station = GasStation.new()
	station.build_environment = false
	station.build_forest = true
	add_child(station)
	car = father_car(self)
	# Чёрный олень на опушке за заправкой (виден, только если обернуться)
	deer_node = forest_deer(self)
	deer_node.visible = false
	# Деньги в руке
	money = Node3D.new()
	cam.add_child(money)
	money.position = Vector3(0.12, -0.42, -0.42)
	var h := CutsceneCast.hand(false)
	money.add_child(h)
	h.curl = 0.5
	var bill := CutsceneKit.mat(Color(0.52, 0.58, 0.5), 0.9)
	for i in 3:
		CutsceneKit.box(money, Vector3(0.07, 0.002, 0.14), Vector3(0.0, 0.016 + i * 0.002, -0.07), bill, Vector3(0, i * 9, 0))
	money.visible = false
	# Путь отъезда — обратно в город: вдоль островка на юг, через южный съезд, на дальнюю полосу
	path = Curve3D.new()
	for p in [CAR_AT, Vector3(11.3, 0, 3.5), Vector3(10.0, 0, 8.0), Vector3(6.0, 0, 10.6), Vector3(1.5, 0, 11.4), Vector3(-1.2, 0, 14.5), Vector3(-1.75, 0, 22.0), Vector3(-1.75, 0, 160.0)]:
		path.add_point(p)
	path.bake_interval = 0.25


# Отцовская машина у колонки и олень на опушке: те же, что ставит в игре FinaleStation.gd
# Отцовский пикап из гаража (FatherCar, Досым): те же set_lights / set_motion, что у EthanCar
static func father_car(parent: Node) -> Node3D:
	var c: Node3D = load("res://scripts/models/FatherCar.gd").new()
	parent.add_child(c)
	c.position = CAR_AT
	c.rotation.y = PI
	c.call("set_lights", false, 0.0)
	return c


static func forest_deer(parent: Node) -> Node3D:
	var d := CutsceneKit.deer(parent, 2.25)
	d.position = DEER_AT
	d.rotation_degrees = Vector3(0, -60, 0)
	return d


func tick(delta: float) -> void:
	if not _drive:
		return
	_speed = minf(_speed + delta * 3.2, 15.0)
	_drive_s += _speed * delta
	var len := path.get_baked_length()
	var s := minf(_drive_s, len - 0.01)
	var p := path.sample_baked(s)
	var q := path.sample_baked(minf(s + 1.5, len))
	car.position = p
	if q.distance_to(p) > 0.01:
		car.look_at_from_position(p, q, Vector3.UP)
	car.call("set_motion", delta, _speed, 0.0)


func run() -> void:
	var part: String = args.get("part", "all")
	var from_game: bool = args.get("from_gameplay", false)
	if part in ["all", "talk", "walk_secret"]:
		await _talk(from_game and part == "talk")
	if part in ["all", "walk", "walk_secret"]:
		await _walk(part == "walk_secret")
	if part in ["all", "drive"]:
		await _drive_off()
	if part in ["secret", "walk_secret"]:
		await _secret(part == "secret")


func _talk(quick: bool) -> void:
	var room := loop("res://assets/audio/intro/shop_room.wav", -16.0, 0.5)
	var radio := loop("res://assets/audio/intro/shop_radio.wav", -26.0, 0.5, Vector3(25.3, 1.6, 3.4), 3.0)
	station.cashier.set_look_target(Vector3(25.0, 0.95, 3.0))
	shot(COUNTER_CAM, CASHIER_HEAD + Vector3(0, -0.05, 0), 48.0)
	handheld = 0.25
	breathe = 0.6
	fade_in(0.4 if quick else 1.4)
	await wait(1.0)
	# Деньги на прилавок
	money.visible = true
	tween_prop(money, "position", Vector3(0.03, -0.3, -0.5), 0.6)
	look_to(Vector3(24.75, 0.98, 1.45), 0.7)
	await wait(0.6)
	sfx("money_counter", -6.0, 1.0, Vector3(24.75, 1.0, 1.45), 3.0)
	await wait(0.5)
	tween_prop(money, "position", Vector3(0.12, -0.6, -0.4), 0.5)
	var bills := CutsceneKit.node(self, Vector3(24.75, 0.985, 1.45), Vector3(0, 20, 0))
	for i in 2:
		CutsceneKit.box(bills, Vector3(0.07, 0.002, 0.14), Vector3(i * 0.02, i * 0.002, i * 0.01), CutsceneKit.mat(Color(0.52, 0.58, 0.5), 0.9), Vector3(0, i * 12, 0))
	look_to(CASHIER_HEAD + Vector3(0, -0.05, 0), 0.8)
	await wait(0.9)
	money.visible = false
	await line("ethan_right", "ИТАН", "Вы были правы. Во всём.", 0.4)
	# Бабушка долго смотрит на него. Потом кивает
	station.cashier.set_look_target(cam_pos)
	await wait(2.6)
	station.cashier.set_look_target(cam_pos + Vector3(0, -0.45, 0))
	await wait(0.4)
	station.cashier.set_look_target(cam_pos)
	await wait(0.8)
	var husband := voice_stream("grandma_husband")
	var hl := husband.get_length() if husband else 3.5
	station.cashier.say("А мой муж? Ты его там не видел?", hl * 0.9)
	await line("grandma_husband", "БАБУШКА", "А мой муж?.. Ты его там не видел?", 0.6, CASHIER_HEAD, 2.0, 4.0)
	# Итан не знает, что ответить. Качает головой и выходит
	for i in 2:
		look_to(CASHIER_HEAD + Vector3(0, -0.12, 0.16), 0.22)
		await wait(0.22)
		look_to(CASHIER_HEAD + Vector3(0, -0.12, -0.16), 0.22)
		await wait(0.22)
	look_to(CASHIER_HEAD + Vector3(0, -0.15, 0), 0.3)
	await wait(0.9)
	look_to(DOOR_IN + Vector3(0, -0.1, 0), 1.0)
	await wait(0.5)
	move_to(DOOR_IN + Vector3(0.4, 0, 0.6), 1.8)
	sfx("res://assets/audio/intro/steps_concrete.wav", -14.0)
	await wait(1.6)
	sfx("res://assets/audio/intro/door_bell.wav", -8.0, 1.0, DOOR_IN, 4.0)
	fade_out(0.6)
	stop(room, 0.6)
	stop(radio, 0.6)
	await wait(0.8)


func _walk(stop_halfway: bool) -> void:
	var wind := loop("amb_night_wind", -18.0, 0.6)
	shot(DOOR_OUT, CAR_AT + Vector3(0, 1.0, 0), 58.0)
	handheld = 0.6
	breathe = 0.8
	fade_in(0.6)
	var target := CAR_DOOR + Vector3(1.0, 1.85, 0.0)
	move_to(target, 7.0, Tween.TRANS_LINEAR)
	for i in 4:
		sfx("res://assets/audio/intro/step_gravel_%d.wav" % (i + 1), -14.0)
		await wait(0.85)
	# На полпути из леса за заправкой — далёкий мужской голос
	var voice_len := say_line("forest_marta", "ГОЛОС ИЗ ЛЕСА", "Марта… Марта…", FOREST_VOICE, 10.0, 30.0)
	if stop_halfway:
		await wait(1.6)
		return
	breathe = 1.4
	for i in 4:
		sfx("res://assets/audio/intro/step_gravel_%d.wav" % ((i + 2) % 4 + 1), -14.0)
		await wait(0.85)
	await wait(maxf(0.0, voice_len - 3.4))
	stop(wind, 1.0)


func _drive_off() -> void:
	# Итан не оборачивается. Садится, заводит машину и уезжает
	sfx("res://assets/audio/intro/car_door.wav", -6.0, 1.0, CAR_AT, 5.0)
	black(1.0)
	await wait(0.8)
	var wide := Vector3(-8.5, 1.65, 14.5)
	shot(wide, CAR_AT + Vector3(4.0, 1.4, -2.0), 42.0)
	handheld = 0.0
	breathe = 0.0
	fade_in(1.0)
	var eng := sfx("res://assets/audio/intro/engine_start.wav", -6.0, 1.0, CAR_AT, 8.0)
	car.call("set_lights", true, 0.0)
	await wait(2.4)
	var idle := loop("res://assets/audio/intro/engine_ext.wav", -12.0, 0.4, CAR_AT, 8.0)
	_drive = true
	glide(wide + Vector3(0, 0, 0.5), Vector3(-1.75, 1.0, 70.0), 9.0, 38.0)
	var follow_t := 0.0
	while follow_t < 7.5 and not skipping:
		follow_t += get_process_delta_time()
		if idle:
			(idle as Node3D).global_position = car.global_position
		await get_tree().process_frame
	if idle:
		fade(idle, -60.0, 3.0)
	await wait(1.6)
	fade_out(2.5)
	await wait(2.8)
	await card("КОНЕЦ", "", 3.0, 1.2)
	if eng:
		stop(eng, 0.1)


func _secret(standalone: bool) -> void:
	var seen = args.get("cam_pos")
	if standalone and seen is Vector3:
		# Из игры: игрок уже обернулся сам, голос уже прозвучал. Кадр продолжает его взгляд
		var dir: Vector3 = args.get("cam_dir", Vector3(1, 0, 0))
		loop("amb_night_wind", -18.0, 0.0)
		shot(seen, seen + dir * 12.0, args.get("cam_fov", 70.0))
		handheld = 0.6
		black(0.0)
		var st := voice_stream("forest_marta")
		var at: float = args.get("voice_pos", -1.0)
		if st and at >= 0.0 and at < st.get_length():
			_play3d(st, FOREST_VOICE, 10.0, 30.0, BUS_VOICE).seek(at)
	elif standalone:
		shot(CAR_DOOR + Vector3(3.6, 1.62, -1.0), CAR_AT + Vector3(0, 1.0, 0), 58.0)
		handheld = 0.6
		fade_in(0.6)
		say_line("forest_marta", "ГОЛОС ИЗ ЛЕСА", "Марта… Марта…", FOREST_VOICE, 10.0, 30.0)
		await wait(2.2)
	# Обернулся: на опушке — чёрный олень, глаза человеческие
	deer_node.visible = true
	look_to(DEER_AT + Vector3(0, 1.35, 0), 0.9, Tween.TRANS_QUAD, Tween.EASE_IN_OUT)
	await wait(1.0)
	silence(0.2)
	clear_subtitle()
	# Наезд: олень стоит далеко, поэтому кадр сужается, пока он не займёт треть экрана
	handheld = 0.15
	tween_prop(self, "cam_fov", 13.0, 2.4, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	await wait(3.1)
	sfx("stinger_hit", -2.0)
	black(1.0)
	await wait(2.0)
	await card("КОНЕЦ", "", 3.0, 1.2)
