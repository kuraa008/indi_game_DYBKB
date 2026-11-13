extends Node3D

# Финал в игре (Jan-ky; ставит Main на карте «Заправка»). Через несколько дней, пасмурный день.
#   1. «Заплатить за бензин»: Итан стоит у отцовской машины, идёт к магазину, [ЛКМ / E] на двери,
#      подходит к прилавку, [ЛКМ / E] → кат-сцена Finale "talk" («Вы были правы. Во всём»).
#   2. «Уехать»: от двери магазина обратно к машине. На полпути из леса за заправкой:
#      «Марта… Марта…», на опушке появляется чёрный олень.
#        — олень попал в кадр (игрок обернулся) → Finale "secret";
#        — дошёл и [ЛКМ / E] «Сесть в машину» → Finale "drive".
#      После «КОНЕЦ» — главное меню.
# Заправка Досыма (GasStation.gd) построена для кат-сцен, столкновений в ней нет: невидимые стены,
# прилавок, полки и колонки ставит этот скрипт. Сам GasStation.gd не тронут.
# Геймплею: сигнал ended(secret), поле phase, GameManager.get_meta("finale_secret").

signal ended(secret: bool)

enum Phase { ARRIVE, SHOP, LEAVE, CALLED, END }

const FINALE := "res://scenes/cutscenes/Finale.tscn"
const MENU := "res://scenes/Menu.tscn"
const Fin := preload("res://scripts/cutscenes/Finale.gd")
const Spot := preload("res://scripts/StorySpot.gd")
const INTRO_SND := "res://assets/audio/intro/"
const CUT_SND := "res://assets/audio/cutscenes/"

const START := Vector3(13.0, 0.3, -3.8)       # у водительской двери, на островке
const OUTSIDE := Vector3(20.9, 0.15, -3.3)    # перед дверью магазина
const INSIDE := Vector3(22.85, 0.2, -3.3)     # сразу за дверью
const CALL_DIST := 5.2      # «на полпути»: столько метров остаётся до машины
const SEEN_DOT := 0.6       # олень входит в кадр → игрок обернулся
const CALL_EVERY := 11.0    # голос зовёт снова, пока игрок стоит

var phase: int = Phase.ARRIVE
var station: GasStation
var car: Node3D
var deer: Node3D

var _missions: MissionTracker
var _door_out: Area3D
var _door_in: Area3D
var _counter: Area3D
var _car_spot: Area3D
var _layer: CanvasLayer
var _black: ColorRect
var _sub: Label
var _sub_tween: Tween
var _wind: AudioStreamPlayer
var _room: AudioStreamPlayer
var _radio: AudioStreamPlayer3D
var _voice: AudioStreamPlayer3D
var _busy := false
var _call_t := 0.0
var _grace := 0.0


func _ready() -> void:
	name = "FinaleStation"
	station = GasStation.new()
	station.build_environment = false
	station.build_forest = true
	add_child(station)
	car = Fin.father_car(self)
	deer = Fin.forest_deer(self)
	deer.visible = false
	_build_colliders()
	_build_spots()
	_build_ui()
	_build_audio()
	_missions = MissionTracker.new()
	_missions.setup([
		{"text": "Заплатить за бензин", "done": func(): return phase >= Phase.LEAVE},
		{"text": "Уехать"},
	])
	add_child(_missions)
	if GameManager and not GameManager.graphics_quality_changed.is_connected(_on_quality_changed):
		GameManager.graphics_quality_changed.connect(_on_quality_changed)
	_prepare.call_deferred()
	_title()


func _on_quality_changed(_q: String) -> void:
	_setup_day.call_deferred()


func _prepare() -> void:
	await get_tree().physics_frame
	_setup_day()
	for n in ["Ambient", "OutdoorAmbient"]:
		var amb := get_parent().get_node_or_null(n) as AudioStreamPlayer
		if amb:
			amb.stop()
	_place(START, Vector3(22.0, 0, -3.3))


# Пасмурный день, как в кат-сцене Finale: луна общей сцены становится солнцем за облаками
func _setup_day() -> void:
	var main := get_parent()
	var night := main.get_node_or_null("SkyElements") as Node3D
	if night:
		night.visible = false
		night.process_mode = Node.PROCESS_MODE_DISABLED
	for n in ["door_light", "base_light"]:
		var lamp := main.get_node_or_null(n) as Node3D
		if lamp:
			lamp.visible = false
	var sun = main.get("moon_light")
	if sun:
		sun.visible = true
		sun.light_color = Color(0.95, 0.9, 0.82)
		sun.light_energy = 0.9
		sun.rotation_degrees = Vector3(-30, -150, 0)
		sun.directional_shadow_max_distance = 90.0
	var node = main.get("world_env_node")
	if node == null or node.environment == null:
		return
	var env: Environment = node.environment
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.5, 0.54, 0.6)
	sky_mat.sky_horizon_color = Color(0.72, 0.71, 0.68)
	sky_mat.ground_horizon_color = Color(0.72, 0.71, 0.68).darkened(0.3)
	sky_mat.ground_bottom_color = Color(0.2, 0.2, 0.19)
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.85
	env.ambient_light_sky_contribution = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.volumetric_fog_enabled = false
	env.ssr_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.64, 0.66)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.75


func _process(delta: float) -> void:
	var player = GameManager.player_ref
	if not is_instance_valid(player) or phase == Phase.END:
		return
	var view := get_viewport().get_camera_3d()
	if phase == Phase.SHOP and view and station.cashier:
		station.cashier.set_look_target(view.global_position)
	if _busy:
		return
	var p: Vector3 = player.global_position
	if phase == Phase.LEAVE:
		if Vector2(p.x - Fin.CAR_DOOR.x, p.z - Fin.CAR_DOOR.z).length() < CALL_DIST:
			phase = Phase.CALLED
			deer.visible = true
			_grace = 0.5
			_call()
	elif phase == Phase.CALLED and view:
		_call_t -= delta
		if _call_t <= 0.0:
			_call()
		_grace -= delta
		var fwd := -view.global_transform.basis.z
		var to := Fin.DEER_AT - view.global_position
		fwd.y = 0.0
		to.y = 0.0
		if _grace <= 0.0 and fwd.normalized().dot(to.normalized()) > SEEN_DOT:
			_on_turned(view)


# ── Шаги истории ──
func _on_enter() -> void:
	if _busy or phase != Phase.ARRIVE:
		return
	_busy = true
	_lock(true)
	_play(INTRO_SND + "door_bell.wav", -8.0)
	await _fade(1.0, 0.35)
	phase = Phase.SHOP
	_set_inside(true)
	_place(INSIDE, Vector3(24.6, 0, 1.4))
	await _fade(0.0, 0.45)
	_lock(false)
	_busy = false


func _on_exit() -> void:
	if _busy or phase != Phase.SHOP:
		return
	_busy = true
	_lock(true)
	_play(INTRO_SND + "door_bell.wav", -8.0)
	await _fade(1.0, 0.35)
	phase = Phase.ARRIVE
	_set_inside(false)
	_place(OUTSIDE, Fin.CAR_DOOR)
	await _fade(0.0, 0.45)
	_lock(false)
	_busy = false


func _on_pay() -> void:
	if _busy or phase != Phase.SHOP:
		return
	_busy = true
	_lock(true)
	await _fade(1.0, 0.3)
	for a in [_wind, _room, _radio]:
		a.stop()
	await Cutscene.overlay(self, FINALE, {"part": "talk", "from_gameplay": true})
	# Кат-сцена кончилась тем, что Итан вышел за дверь
	_black.color.a = 1.0
	phase = Phase.LEAVE
	_set_inside(false)
	_place(OUTSIDE, Fin.CAR_DOOR)
	_wind.play()
	await _fade(0.0, 0.6)
	_lock(false)
	_busy = false


func _call() -> void:
	_call_t = CALL_EVERY
	if _voice.stream:
		_voice.play()
	_say("ГОЛОС ИЗ ЛЕСА", "Марта… Марта…", _voice.stream.get_length() if _voice.stream else 3.0)


func _on_turned(view: Camera3D) -> void:
	_busy = true
	_lock(true)
	_finish({
		"part": "secret", "from_gameplay": true,
		"cam_pos": view.global_position,
		"cam_dir": -view.global_transform.basis.z,
		"cam_fov": view.fov,
		"voice_pos": _voice.get_playback_position() if _voice.playing else -1.0,
	}, true)


func _on_car() -> void:
	if _busy or (phase != Phase.LEAVE and phase != Phase.CALLED):
		return
	_busy = true
	_lock(true)
	await _fade(1.0, 0.4)
	_finish({"part": "drive", "from_gameplay": true}, false)


func _finish(args: Dictionary, secret: bool) -> void:
	phase = Phase.END
	_missions.finish()
	_sub.modulate.a = 0.0
	for a in [_wind, _room, _radio, _voice]:
		a.stop()
	GameManager.set_meta("finale_secret", secret)
	await Cutscene.overlay(self, FINALE, args)
	_black.color.a = 1.0
	ended.emit(secret)
	GameManager.change_scene_fast(MENU)


# ── Мелочи ──
func _lock(on: bool) -> void:
	var player = GameManager.player_ref
	if is_instance_valid(player):
		player.set("is_in_cutscene", on)
		player.set("velocity", Vector3.ZERO)


# Ставит игрока в точку лицом к look
func _place(pos: Vector3, look: Vector3) -> void:
	var player = GameManager.player_ref
	if not is_instance_valid(player):
		return
	player.global_position = pos
	player.rotation.y = atan2(pos.x - look.x, pos.z - look.z)
	var head = player.get("head")
	if head is Node3D:
		head.rotation.x = 0.0
	player.set("velocity", Vector3.ZERO)


# Какие точки действия работают: снаружи дверь (пока не заплатил) или машина, внутри — дверь и прилавок
func _set_inside(inside: bool) -> void:
	var paid := phase >= Phase.LEAVE
	_enable(_door_out, not inside and not paid)
	_enable(_car_spot, not inside and paid)
	_enable(_door_in, inside)
	_enable(_counter, inside)
	_wind.volume_db = -30.0 if inside else -18.0
	if inside:
		_room.play()
		_radio.play()
	else:
		_room.stop()
		_radio.stop()


func _enable(spot: Area3D, on: bool) -> void:
	for c in spot.get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).disabled = not on


func _fade(alpha: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, dur)
	await tw.finished


func _say(who: String, text: String, hold: float) -> void:
	_sub.text = "%s: %s" % [who, text]
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_sub, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_interval(hold)
	_sub_tween.tween_property(_sub, "modulate:a", 0.0, 0.4)


func _play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


# «Через несколько дней»
func _title() -> void:
	_black.color.a = 1.0
	var card := Label.new()
	card.text = "ЧЕРЕЗ НЕСКОЛЬКО ДНЕЙ"
	card.add_theme_font_size_override("font_size", 40)
	card.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.modulate.a = 0.0
	_layer.add_child(card)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(1.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.7)
	tw.tween_property(_black, "color:a", 0.0, 1.2)
	tw.tween_callback(card.queue_free)


# ── Постройка ──
func _solid(centre: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	add_child(body)
	body.position = centre


func _build_colliders() -> void:
	# Земля и пол магазина
	_solid(Vector3(0, -0.45, 0), Vector3(500, 1.0, 500))
	_solid(Vector3(27.5, -0.12, 0), Vector3(11.8, 0.5, 12.0))
	# Стены магазина: фасад сплошной, дверь работает как переход
	_solid(Vector3(22.0, 1.75, 0), Vector3(0.3, 3.5, 11.4))
	_solid(Vector3(33.0, 1.75, 0), Vector3(0.3, 3.5, 11.4))
	for s in [-1.0, 1.0]:
		_solid(Vector3(27.5, 1.75, 5.6 * s), Vector3(11.2, 3.5, 0.3))
	# Прилавок, место кассирши за ним, стойка с сигаретами
	_solid(Vector3(24.95, 0.6, 1.8), Vector3(0.74, 1.0, 4.72))
	_solid(Vector3(25.95, 1.1, -0.6), Vector3(1.9, 2.0, 0.12))
	_solid(Vector3(25.95, 1.1, 4.2), Vector3(1.9, 2.0, 0.12))
	_solid(Vector3(26.95, 1.2, 1.8), Vector3(0.3, 2.2, 4.2))
	# Полки, холодильники, столик с кофе
	for z in [-3.9, -1.9]:
		_solid(Vector3(28.0, 0.93, z), Vector3(6.0, 1.7, 0.84))
	_solid(Vector3(32.45, 1.2, -1.95), Vector3(0.9, 2.3, 5.85))
	_solid(Vector3(22.75, 0.6, -1.2), Vector3(0.6, 1.0, 1.6))
	# Снаружи: автомат, ящик со льдом, столбики перед витриной
	_solid(Vector3(21.4, 1.0, -4.55), Vector3(0.82, 1.9, 1.0))
	_solid(Vector3(21.46, 0.55, 4.5), Vector3(0.76, 0.9, 1.3))
	for zb in [-4.9, -1.6, 1.2, 3.85]:
		_solid(Vector3(20.0, 0.5, zb), Vector3(0.16, 1.0, 0.16))
	# Островок (пологий бортик, чтобы на него можно было зайти), колонки, стойки навеса, урна
	_island()
	for s in [-1.0, 1.0]:
		_solid(Vector3(13.0, 1.15, 2.6 * s), Vector3(0.9, 2.2, 1.05))
		_solid(Vector3(13.0, 1.5, 5.2 * s), Vector3(0.5, 3.0, 0.5))
		for bx in [12.45, 13.55]:
			_solid(Vector3(bx, 0.6, 6.8 * s), Vector3(0.16, 1.0, 0.16))
	_solid(Vector3(13.0, 0.65, 4.2), Vector3(0.44, 0.9, 0.44))
	# Машина
	_solid(Fin.CAR_AT + Vector3(0, 0.75, 0), Vector3(1.84, 1.5, 4.7))   # пикап FatherCar 1.86 × 1.78 × 4.62
	# Двор: будка, стела, воздух, контейнер, забор
	_solid(Vector3(19.8, 1.14, -10.6), Vector3(0.94, 2.2, 0.94))
	_solid(Vector3(7.2, 1.5, -13.0), Vector3(0.4, 3.0, 0.4))
	_solid(Vector3(21.0, 0.68, 9.5), Vector3(0.3, 1.3, 0.3))
	_solid(Vector3(31.0, 0.68, 8.1), Vector3(1.9, 1.4, 2.8))
	_solid(Vector3(35.5, 1.1, 0.25), Vector3(0.14, 2.2, 32.6))
	# Края уровня: дальняя обочина шоссе и опушка
	_solid(Vector3(-9.0, 2.0, 0), Vector3(0.4, 4.0, 60.0))
	_solid(Vector3(37.0, 2.0, 0), Vector3(0.4, 4.0, 60.0))
	for s in [-1.0, 1.0]:
		_solid(Vector3(14.0, 2.0, 26.0 * s), Vector3(46.4, 4.0, 0.4))


func _island() -> void:
	var pts := PackedVector3Array()
	for z in [-1.0, 1.0]:
		for x in [-1.0, 1.0]:
			pts.append(Vector3(13.0 + 1.05 * x, 0.04, 6.85 * z))
			pts.append(Vector3(13.0 + 0.8 * x, 0.25, 6.5 * z))
	var shape := ConvexPolygonShape3D.new()
	shape.points = pts
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	add_child(body)


func _spot(action: String, use: Callable, pos: Vector3, size: Vector3) -> Area3D:
	var s: Area3D = Spot.new()
	s.setup(action, use, size)
	add_child(s)
	s.position = pos
	return s


func _build_spots() -> void:
	# Точки тонкие и прижаты к предмету: если камера окажется внутри точки, прицел её не увидит
	_door_out = _spot("Войти в магазин", _on_enter, Vector3(21.78, 1.25, -3.3), Vector3(0.2, 2.3, 1.4))
	_door_in = _spot("Выйти на улицу", _on_exit, Vector3(22.22, 1.25, -3.3), Vector3(0.2, 2.3, 1.4))
	_counter = _spot("Положить деньги на прилавок", _on_pay, Vector3(24.86, 1.45, 1.45), Vector3(0.9, 1.3, 2.6))
	_car_spot = _spot("Сесть в машину", _on_car, Fin.CAR_AT + Vector3(0, 1.15, 0), Vector3(2.2, 2.3, 4.9))
	for s in [_door_in, _counter, _car_spot]:
		_enable(s, false)


func _looped(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var st: AudioStream = load(path)
	if st is AudioStreamWAV and (st as AudioStreamWAV).loop_mode == AudioStreamWAV.LOOP_DISABLED:
		var c := st.duplicate() as AudioStreamWAV
		c.loop_mode = AudioStreamWAV.LOOP_FORWARD
		c.loop_end = int(c.get_length() * c.mix_rate)
		return c
	return st


func _build_audio() -> void:
	_wind = AudioStreamPlayer.new()
	_wind.stream = _looped(CUT_SND + "amb_night_wind.wav")
	_wind.volume_db = -18.0
	_wind.autoplay = true
	add_child(_wind)
	_room = AudioStreamPlayer.new()
	_room.stream = _looped(INTRO_SND + "shop_room.wav")
	_room.volume_db = -16.0
	add_child(_room)
	_radio = AudioStreamPlayer3D.new()
	_radio.stream = _looped(INTRO_SND + "shop_radio.wav")
	_radio.volume_db = -26.0
	_radio.unit_size = 3.0
	_radio.max_distance = 80.0
	add_child(_radio)
	_radio.position = Vector3(25.3, 1.6, 3.4)
	_voice = AudioStreamPlayer3D.new()
	var call_path := CUT_SND + "voice/forest_marta.wav"
	if ResourceLoader.exists(call_path):
		_voice.stream = load(call_path)
	_voice.volume_db = 10.0
	_voice.unit_size = 30.0
	_voice.max_distance = 80.0
	_voice.attenuation_filter_cutoff_hz = 9000.0
	add_child(_voice)
	_voice.position = Fin.FOREST_VOICE


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
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
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.anchor_top = 1.0
	_sub.anchor_bottom = 1.0
	_sub.offset_top = -120
	_sub.offset_bottom = -80
	_sub.modulate.a = 0.0
	_layer.add_child(_sub)
