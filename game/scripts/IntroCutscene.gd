extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  IntroCutscene.gd — Вступление: ночь 31 октября 1994 года, шоссе Блэк-Пайн
#  • Пикап Итана едет через сосновый лес искать пропавшего брата Сэма
#  • Посреди дороги олень встаёт на задние ноги → сигнал, визг шин, удар о валун
#  • Пар из радиатора, заевший сигнал, из леса зовёт голос брата
#  • Камера 04 на сосне, фонарик падает, шёпот за спиной → скример скинвокера
#  • После скримера — 1-й уровень (кошмар Итана, пока он без сознания)
#  • [Пробел / Enter / Esc / Start] — пропустить вступление
# ══════════════════════════════════════════════════════════════════════════════

# ── Раскадровка (секунды от начала вступления) ──
const T_TITLE_OUT: float = 2.8     # дата гаснет
const T_DRIVE: float = 3.6         # из темноты проступает шоссе
const T_POV: float = 12.5          # вид из кабины
const T_HORN: float = 15.4         # олень в свете фар: сигнал и торможение
const T_REAR: float = 15.9         # олень встаёт на задние ноги
const T_SWERVE: float = 16.7       # руль влево, визг шин
const T_CRASH: float = 18.0        # удар о валун
const T_AFTER: float = 23.0        # пар из радиатора, заевший сигнал
const T_HORN_STOP: float = 25.2    # сигнал резко смолкает
const T_VOICE: float = 25.6        # «Итан!..» из леса
const T_WALK: float = 29.0         # от первого лица вдоль обочины
const T_CAMERA04: float = 32.4     # камера 04 на сосне
const T_FALL: float = 33.6         # Итан спотыкается, фонарик падает
const T_EYES: float = 34.6         # красные глаза между стволами
const T_WHISPER: float = 35.6      # шёпот за спиной
const T_DONT_LOOK: float = 37.6    # «Не оглядывайся»
const T_TURN: float = 38.8         # Итан оборачивается
const T_SCARE: float = 39.35       # скример скинвокера

# ── Движение пикапа ──
const CAR_START_Z: float = 20.0
const CAR_SPEED: float = 20.0          # ~72 км/ч
const CAR_BRAKE_SPEED: float = 9.0
const BRAKE_TIME: float = 1.4
const SWERVE_X: float = -7.2           # уход влево с дороги
const SWERVE_YAW_DEG: float = 34.0

# ── Точки сцены (пикап врезается в валун у z ≈ -247) ──
const ROAD_START_Z: float = 40.0
const ROAD_END_Z: float = -540.0
const DEER_POS := Vector3(0.4, 0.0, -244.5)
const ROCK_POS := Vector3(-9.6, 0.0, -250.8)
const CAM04_PINE_POS := Vector3(-6.2, 0.0, -236.0)
const CAM04_POS := Vector3(-6.08, 1.45, -236.32)
const DROPPED_LIGHT_POS := Vector3(-5.2, 0.06, -238.9)
const FOREST_EYES_POS := Vector3(-14.5, 1.85, -239.4)
const DEER_HEIGHT: float = 2.3
const DEER_EYES_PX = [Vector2(82, 178), Vector2(116, 178)]   # глаза на Olen.png

var cam: Camera3D
var car: Node3D
var car_body: Node3D
var cockpit: Node3D
var headlight_l: SpotLight3D
var headlight_r: SpotLight3D
var steam: CPUParticles3D
var deer_root: Node3D
var deer_eyes: Node3D
var hand_light: SpotLight3D
var dropped_light: Node3D
var forest_eyes: Node3D
var cam04_led: Node3D
var flicker_light: SpotLight3D
var flicker_mat: StandardMaterial3D
var world_env: Environment
var moon_light: DirectionalLight3D
var eye_mesh: SphereMesh

# UI
var black_rect: ColorRect
var flash_rect: ColorRect
var title_box: VBoxContainer
var sub_box: VBoxContainer
var speaker_label: Label
var line_label: Label
var warn_label: Label

# Звук
var engine_player: AudioStreamPlayer
var radio_player: AudioStreamPlayer
var steam_player: AudioStreamPlayer
var horn_loop_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var heart_player: AudioStreamPlayer

var _t: float = 0.0
var _fired: Dictionary = {}
var _trauma: float = 0.0
var _next_step_t: float = 0.0
var _step_idx: int = 0
var _car_crashed: bool = false
var _finished: bool = false
var _sub_tween: Tween = null
var _fade_tween: Tween = null

func _ready() -> void:
	name = "IntroCutscene"
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_setup_environment()
	_build_ground_and_road()
	_build_streetlights()
	_build_forest()
	_build_crash_site()
	_build_car()
	_build_deer()
	_build_walk_props()
	_setup_camera()
	_build_overlay()

	if GameManager:
		GameManager.graphics_quality_changed.connect(_apply_graphics_quality)

	_update_car()
	_update_camera(0.0)

func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	_run_timeline()
	_update_car()
	_update_deer()
	_update_props()
	_update_camera(delta)

func _unhandled_input(event: InputEvent) -> void:
	if _finished or _t < 0.6:
		return
	var skip := event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		skip = true
	if skip:
		get_viewport().set_input_as_handled()
		_finish()

# ──────────────────────────────────────────────────────────────────────────────
#  Раскадровка: каждое событие срабатывает один раз в свой момент
# ──────────────────────────────────────────────────────────────────────────────
func _once(key: String, at: float) -> bool:
	if _t < at or _fired.has(key):
		return false
	_fired[key] = true
	return true

func _run_timeline() -> void:
	if _once("title_in", 0.3):
		create_tween().tween_property(title_box, "modulate:a", 1.0, 0.9)
	if _once("engine", 0.8):
		engine_player = _sfx("res://assets/audio/car_engine.wav", -10.0, 0.92, true)
		radio_player = _sfx("res://assets/audio/tv_static.wav", -24.0, 0.8, true)
	if _once("title_out", T_TITLE_OUT):
		create_tween().tween_property(title_box, "modulate:a", 0.0, 0.7)
	if _once("drive", T_DRIVE):
		_fade_black(0.0, 1.4)
	if _once("tape_1", 5.0):
		_say("СЭМ (С КАССЕТЫ)", "«Итан, если эта кассета дойдёт до тебя — не приезжай…»", 3.4)
	if _once("tape_2", 8.8):
		_say("СЭМ (С КАССЕТЫ)", "«…Это не олень».", 2.4)
	if _once("pov", T_POV):
		car_body.visible = false
		cockpit.visible = true
		deer_root.visible = true
	if _once("horn", T_HORN):
		_sfx("res://assets/audio/car_horn.wav", 0.0)
		if engine_player:
			create_tween().tween_property(engine_player, "pitch_scale", 0.7, BRAKE_TIME)
	if _once("growl", T_REAR):
		_sfx("res://assets/audio/skinwalker_scream.wav", -12.0, 0.45)
	if _once("deer_eyes", T_REAR + 0.35):
		deer_eyes.visible = true
	if _once("swerve", T_SWERVE):
		_sfx("res://assets/audio/tires_screech.wav", -2.0)
		_trauma = 0.55
	if _once("crash", T_CRASH):
		_crash()
	if _once("steam", T_CRASH + 0.9):
		steam_player = _sfx("res://assets/audio/car_steam.wav", -6.0, 1.0, true)
		horn_loop_player = _sfx("res://assets/audio/car_horn.wav", -9.0, 0.96, true)
	if _once("ambient", T_AFTER - 1.0):
		ambient_player = _sfx("res://assets/ambient_night.mp3", -16.0, 1.0, true)
	if _once("after", T_AFTER):
		_fade_black(0.0, 1.6)
	if _once("horn_stop", T_HORN_STOP):
		_stop(horn_loop_player)
		horn_loop_player = null
	if _once("voice", T_VOICE):
		_sfx("res://assets/creepy_mutter.mp3", -18.0, 0.9)
		_say("ГОЛОС ИЗ ЛЕСА", "«Итан!.. Итан, я здесь!»", 2.8)
	if _once("walk_cut", T_WALK - 0.7):
		_fade_black(1.0, 0.6)
	if _once("walk", T_WALK):
		hand_light.visible = true
		if steam_player:
			steam_player.volume_db = -16.0
		_next_step_t = T_WALK + 0.3
		_fade_black(0.0, 0.9)
	if _once("cam04", T_CAMERA04):
		_say("ИТАН", "«04»… Это камера Сэма.", 2.2)
	if _once("fall", T_FALL):
		_fall()
	if _once("eyes_on", T_EYES):
		forest_eyes.visible = true
		_sfx("res://assets/audio/monster_step.wav", -4.0, 0.8)
	if _once("eyes_off", T_EYES + 0.9):
		forest_eyes.visible = false
	if _once("whisper", T_WHISPER):
		_sfx("res://assets/creepy_whisper.mp3", 0.0, 0.92)
		_say("ШЁПОТ ЗА СПИНОЙ", "«Итан… обернись. Посмотри на меня».", 1.4)
	if _once("dont_look", T_DONT_LOOK):
		_flash_warning()
	if _once("turn", T_TURN):
		if heart_player:
			create_tween().tween_property(heart_player, "volume_db", 2.0, 0.4)
	if _once("scare", T_SCARE):
		_start_scare()

	# Шаги по обочине, пока Итан идёт к камере 04
	if _t > T_WALK and _t < T_FALL and _t >= _next_step_t:
		_next_step_t = _t + 0.55
		_step_idx += 1
		var step_path := "res://assets/audio/step_1.mp3" if _step_idx % 2 == 0 else "res://assets/audio/step_2.mp3"
		_sfx(step_path, -10.0, randf_range(0.92, 1.05))

func _crash() -> void:
	_car_crashed = true
	_sfx("res://assets/audio/car_crash.wav", 2.0)
	_stop(engine_player)
	_stop(radio_player)
	engine_player = null
	radio_player = null

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	black_rect.color.a = 1.0
	flash_rect.color.a = 0.9
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.35)

	# Пикап застыл носом в валуне: перекос, правая фара разбита
	car.position = Vector3(SWERVE_X, 0.0, CAR_START_Z - _car_distance(T_CRASH))
	car.rotation = Vector3(deg_to_rad(-4.0), deg_to_rad(SWERVE_YAW_DEG), deg_to_rad(3.0))
	car_body.visible = true
	cockpit.visible = false
	headlight_r.visible = false
	deer_root.visible = false
	steam.emitting = true
	_trauma = 0.0

func _fall() -> void:
	_sfx("res://assets/audio/player_step.wav", 0.0, 0.55)
	_trauma = 0.75
	hand_light.visible = false
	dropped_light.visible = true
	heart_player = _sfx("res://assets/heart.mp3", -8.0, 1.0, true)

func _flash_warning() -> void:
	var tw := create_tween()
	tw.tween_property(warn_label, "modulate:a", 1.0, 0.08)
	tw.tween_interval(0.85)
	tw.tween_property(warn_label, "modulate:a", 0.0, 0.25)

func _start_scare() -> void:
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	sub_box.modulate.a = 0.0
	warn_label.modulate.a = 0.0
	_stop(heart_player)
	_stop(ambient_player)
	_stop(steam_player)
	heart_player = null
	ambient_player = null
	steam_player = null

	var scare := SkinwalkerScare.new()
	add_child(scare)
	scare.finished.connect(_finish)

func _finish() -> void:
	if _finished:
		return
	_finished = true
	if GameManager:
		GameManager.intro_cutscene_played = true
		GameManager.active_map_path = "res://scenes/1level.json"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ──────────────────────────────────────────────────────────────────────────────
#  Движение пикапа: 20 м/с, торможение после сигнала, занос влево в валун
# ──────────────────────────────────────────────────────────────────────────────
func _car_distance(t: float) -> float:
	if t <= T_DRIVE:
		return 0.0
	var d := (minf(t, T_HORN) - T_DRIVE) * CAR_SPEED
	if t > T_HORN:
		var b := minf(t - T_HORN, BRAKE_TIME)
		var decel := (CAR_SPEED - CAR_BRAKE_SPEED) / BRAKE_TIME
		d += CAR_SPEED * b - 0.5 * decel * b * b
	if t > T_HORN + BRAKE_TIME:
		d += (minf(t, T_CRASH) - T_HORN - BRAKE_TIME) * CAR_BRAKE_SPEED
	return d

func _car_swerve(t: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - T_SWERVE) / (T_CRASH - T_SWERVE), 0.0, 1.0))

func _update_car() -> void:
	if _car_crashed:
		return
	var s := _car_swerve(_t)
	car.position = Vector3(SWERVE_X * s, 0.0, CAR_START_Z - _car_distance(_t))
	car.rotation = Vector3(0.0, deg_to_rad(SWERVE_YAW_DEG) * s, deg_to_rad(-3.0) * sin(s * PI))

func _update_deer() -> void:
	if not deer_root.visible:
		return
	# Пивот у копыт: силуэт откидывается назад и вытягивается вверх
	var r := smoothstep(T_REAR, T_REAR + 0.6, _t)
	deer_root.rotation.z = deg_to_rad(-16.0) * r
	deer_root.scale = Vector3(1.0 - 0.15 * r, 1.0 + 0.3 * r, 1.0)

func _update_props() -> void:
	cam04_led.visible = fmod(_t, 1.0) < 0.5
	var off := sin(_t * 13.0) * cos(_t * 7.3) > 0.55
	flicker_light.light_energy = 0.15 if off else 2.1
	flicker_mat.albedo_color = Color(0.22, 0.16, 0.1) if off else Color(1.0, 0.78, 0.52)
	if _car_crashed:
		headlight_l.light_energy = 0.8 if sin(_t * 23.0) < -0.85 else 5.0

# ──────────────────────────────────────────────────────────────────────────────
#  Камера: погоня за пикапом → кабина → место аварии → от первого лица
# ──────────────────────────────────────────────────────────────────────────────
func _update_camera(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 1.2)
	if _t < T_POV:
		_camera_chase()
	elif _t < T_CRASH:
		_camera_pov()
	elif _t < T_WALK:
		_camera_aftermath()
	else:
		_camera_walk()

	if _trauma > 0.0:
		var m := _trauma * _trauma * 0.12
		cam.global_position += cam.global_transform.basis * Vector3(randf_range(-m, m), randf_range(-m, m), 0.0)

func _camera_chase() -> void:
	cam.fov = 62.0
	var sway := Vector3(sin(_t * 0.7) * 0.25, sin(_t * 1.1) * 0.08, 0.0)
	cam.global_position = car.global_position + Vector3(-0.9, 2.2, 6.6) + sway
	cam.look_at(car.global_position + Vector3(0.0, 1.0, -10.0), Vector3.UP)

func _camera_pov() -> void:
	cam.fov = 70.0
	var b := car.global_transform.basis
	cam.global_position = car.global_position + b * Vector3(-0.38, 1.28, -0.15)
	cam.look_at(cam.global_position - b.z * 20.0 + Vector3(0.0, -0.9, 0.0), Vector3.UP)
	var s := _car_swerve(_t)
	if s > 0.0:
		cam.rotate_object_local(Vector3.BACK, deg_to_rad(9.0) * sin(s * PI))

func _camera_aftermath() -> void:
	cam.fov = 55.0
	var u := clampf((_t - T_AFTER) / (T_WALK - T_AFTER), 0.0, 1.0)
	cam.global_position = Vector3(-2.8, 1.75, -238.8).lerp(Vector3(-3.4, 1.55, -241.6), u)
	cam.look_at(Vector3(-8.6, 0.9, -249.2), Vector3.UP)

func _camera_walk() -> void:
	if _t < T_FALL:
		# Камера наезжает на «04», когда Итан узнаёт камеру брата
		cam.fov = lerpf(72.0, 50.0, smoothstep(T_CAMERA04 - 0.4, T_CAMERA04 + 0.8, _t))
		var w := clampf((_t - T_WALK) / (T_FALL - T_WALK), 0.0, 1.0)
		var walk_pos := Vector3(-4.6, 1.65 + sin((_t - T_WALK) * 7.4) * 0.035, lerpf(-245.0, -238.8, w))
		var ahead := Vector3(-4.6, 1.45, walk_pos.z + 6.0)
		cam.global_position = walk_pos
		cam.look_at(ahead.lerp(CAM04_POS, smoothstep(T_CAMERA04 - 0.4, T_CAMERA04 + 0.6, _t)), Vector3.UP)
		return

	# Падение: камера проседает к земле и смотрит вдоль луча упавшего фонарика
	var f := smoothstep(T_FALL, T_FALL + 0.45, _t)
	cam.fov = lerpf(50.0, 72.0, f)
	var low_pos :=Vector3(-4.6, 1.65, -238.8).lerp(Vector3(-4.4, 0.55, -238.6), f)
	var target := CAM04_POS.lerp(Vector3(-16.5, 1.4, -239.2), smoothstep(T_FALL + 0.2, T_FALL + 1.0, _t))
	if _t >= T_TURN:
		# Итан оборачивается: взгляд уходит из чащи назад, к дороге
		var ang := PI * smoothstep(T_TURN, T_TURN + 0.55, _t)
		target = low_pos + Vector3(-cos(ang), 0.06, sin(ang)) * 8.0
	cam.global_position = low_pos
	cam.look_at(target, Vector3.UP)
	cam.rotate_object_local(Vector3.BACK, deg_to_rad(10.0) * f)

# ──────────────────────────────────────────────────────────────────────────────
#  Окружение: ночное небо, туман, луна
# ──────────────────────────────────────────────────────────────────────────────
func _setup_environment() -> void:
	var env_node := WorldEnvironment.new()
	world_env = Environment.new()
	world_env.background_mode = Environment.BG_SKY

	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.018, 0.038)
	sky_mat.sky_horizon_color = Color(0.035, 0.055, 0.095)
	sky_mat.ground_bottom_color = Color(0.006, 0.009, 0.015)
	sky_mat.ground_horizon_color = Color(0.035, 0.055, 0.095)
	sky_mat.sun_angle_max = 0.0
	sky.sky_material = sky_mat
	world_env.sky = sky

	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_sky_contribution = 0.0
	world_env.fog_enabled = true
	world_env.fog_light_color = Color(0.03, 0.045, 0.08)
	env_node.environment = world_env
	add_child(env_node)

	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.rotation_degrees = Vector3(-48.0, 35.0, 0.0)
	moon_light.light_color = Color(0.68, 0.80, 1.0)
	moon_light.light_energy = 0.32
	moon_light.shadow_bias = 0.05
	moon_light.shadow_blur = 1.8
	add_child(moon_light)

	_apply_graphics_quality(GameManager.graphics_quality if GameManager else "ultra")

func _apply_graphics_quality(quality: String) -> void:
	if not world_env:
		return
	world_env.ambient_light_color = Color(0.10, 0.12, 0.17)
	world_env.ambient_light_energy = 0.7
	world_env.fog_density = 0.012
	match quality:
		"ultra", "high":
			world_env.ambient_light_color = Color(0.22, 0.28, 0.40)
			world_env.ambient_light_energy = 0.6
			world_env.fog_density = 0.008
			world_env.ssao_enabled = true
			world_env.glow_enabled = true
			world_env.glow_bloom = 0.08
			world_env.glow_intensity = 0.6
			world_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			world_env.volumetric_fog_enabled = true
			world_env.volumetric_fog_density = 0.018
			world_env.volumetric_fog_albedo = Color(0.42, 0.50, 0.62)
			world_env.volumetric_fog_anisotropy = 0.45
			world_env.volumetric_fog_temporal_reprojection_enabled = true
			world_env.tonemap_mode = Environment.TONE_MAPPER_ACES
			world_env.tonemap_exposure = 1.3
			world_env.tonemap_white = 6.0
			moon_light.shadow_enabled = true
		"medium":
			world_env.ssao_enabled = true
			world_env.glow_enabled = true
			world_env.glow_bloom = 0.08
			world_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			world_env.volumetric_fog_enabled = false
			world_env.tonemap_mode = Environment.TONE_MAPPER_ACES
			world_env.tonemap_exposure = 1.15
			moon_light.shadow_enabled = true
		_:
			world_env.ssao_enabled = false
			world_env.glow_enabled = false
			world_env.volumetric_fog_enabled = false
			world_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			moon_light.shadow_enabled = false

# ──────────────────────────────────────────────────────────────────────────────
#  Шоссе: земля, асфальт, обочины и разметка
# ──────────────────────────────────────────────────────────────────────────────
func _build_ground_and_road() -> void:
	var road_len := ROAD_START_Z - ROAD_END_Z
	var mid_z := (ROAD_START_Z + ROAD_END_Z) * 0.5

	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(240.0, road_len + 80.0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.045, 0.052, 0.038)
	gmat.roughness = 0.96
	gm.material = gmat
	ground.mesh = gm
	ground.position = Vector3(0.0, 0.0, mid_z)
	add_child(ground)

	var road := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(8.0, road_len)
	var road_mat := StandardMaterial3D.new()
	road_mat.albedo_texture = TextureHelper.get_texture("res://assets/textures/highway_asphalt.png")
	road_mat.albedo_color = Color(0.55, 0.58, 0.64)
	road_mat.roughness = 0.92
	road_mat.uv1_scale = Vector3(1.0, road_len / 8.0, 1.0)
	rm.material = road_mat
	road.mesh = rm
	road.position = Vector3(0.0, 0.018, mid_z)
	add_child(road)

	var shoulder_mat := StandardMaterial3D.new()
	shoulder_mat.albedo_color = Color(0.11, 0.095, 0.075)
	shoulder_mat.roughness = 0.98
	var marking_mat := StandardMaterial3D.new()
	marking_mat.albedo_color = Color(0.72, 0.76, 0.82)
	marking_mat.roughness = 0.82
	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var sm := PlaneMesh.new()
		sm.size = Vector2(1.8, road_len)
		sm.material = shoulder_mat
		shoulder.mesh = sm
		shoulder.position = Vector3(side * 4.9, 0.012, mid_z)
		add_child(shoulder)

		var edge := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.13, 0.025, road_len)
		em.material = marking_mat
		edge.mesh = em
		edge.position = Vector3(side * 3.7, 0.045, mid_z)
		add_child(edge)

	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.12, 0.025, 3.1)
	dash_mesh.material = marking_mat
	var z := ROAD_START_Z - 4.0
	while z > ROAD_END_Z:
		var dash := MeshInstance3D.new()
		dash.mesh = dash_mesh
		dash.position = Vector3(0.0, 0.045, z)
		add_child(dash)
		z -= 9.0

# ──────────────────────────────────────────────────────────────────────────────
#  Фонари вдоль шоссе (через 30 м, попеременно слева и справа)
# ──────────────────────────────────────────────────────────────────────────────
func _build_streetlights() -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.13, 0.16, 0.21)
	pole_mat.metallic = 0.72
	pole_mat.roughness = 0.38
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.18, 7.2, 0.18)
	pole_mesh.material = pole_mat
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(1.7, 0.16, 0.19)
	arm_mesh.material = pole_mat
	var bulb_mesh := BoxMesh.new()
	bulb_mesh.size = Vector3(0.48, 0.1, 0.35)
	var lamp_mat := _make_lamp_material()

	for k in range(19):
		var side := 1.0 if k % 2 == 0 else -1.0
		var lamp_root := Node3D.new()
		lamp_root.position = Vector3(side * 5.0, 0.0, 10.0 - 30.0 * k)
		add_child(lamp_root)

		var pole := MeshInstance3D.new()
		pole.mesh = pole_mesh
		pole.position.y = 3.6
		lamp_root.add_child(pole)

		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.position = Vector3(-side * 0.68, 7.0, 0.0)
		lamp_root.add_child(arm)

		# Фонарь у места аварии мигает — у него свой материал
		var is_flicker := k == 9
		var mat := _make_lamp_material() if is_flicker else lamp_mat
		var bulb := MeshInstance3D.new()
		bulb.mesh = bulb_mesh
		bulb.material_override = mat
		bulb.position = Vector3(-side * 1.42, 6.88, 0.0)
		lamp_root.add_child(bulb)

		var pool := SpotLight3D.new()
		pool.light_color = Color(1.0, 0.66, 0.38)
		pool.light_energy = 2.1
		pool.spot_range = 12.0
		pool.spot_angle = 62.0
		pool.spot_attenuation = 1.25
		pool.position = Vector3(-side * 1.42, 6.7, 0.0)
		pool.rotation_degrees.x = -90.0
		lamp_root.add_child(pool)

		if is_flicker:
			flicker_light = pool
			flicker_mat = mat

func _make_lamp_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.78, 0.52)
	return m

# ──────────────────────────────────────────────────────────────────────────────
#  Сосновый лес по обеим сторонам шоссе (MultiMesh: стволы и ярусы крон)
# ──────────────────────────────────────────────────────────────────────────────
func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 311994
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var z := ROAD_START_Z
	while z > ROAD_END_Z:
		for side in [-1.0, 1.0]:
			for row in range(4):
				var x: float = side * (7.2 + row * 6.0 + rng.randf_range(-1.5, 1.5))
				var tz := z + rng.randf_range(-1.8, 1.8)
				var sc := rng.randf_range(0.85, 1.35)
				if _in_crash_clearing(x, tz):
					continue
				_add_pine(trunks, crowns, Vector3(x, 0.0, tz), sc)
		z -= 4.5
	# Сосна у обочины, на которой Сэм закрепил камеру 04
	_add_pine(trunks, crowns, CAM04_PINE_POS, 1.1)

	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.7
	trunk_mesh.bottom_radius = 1.0
	trunk_mesh.height = 1.0
	trunk_mesh.radial_segments = 8
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.18, 0.12, 0.08)
	trunk_mesh.material = trunk_mat
	add_child(_make_multimesh(trunk_mesh, trunks))

	var crown_mesh := CylinderMesh.new()
	crown_mesh.top_radius = 0.0
	crown_mesh.bottom_radius = 1.0
	crown_mesh.height = 1.0
	crown_mesh.radial_segments = 8
	var crown_mat := StandardMaterial3D.new()
	crown_mat.albedo_color = Color(0.05, 0.11, 0.06)
	crown_mesh.material = crown_mat
	var crowns_node := _make_multimesh(crown_mesh, crowns)
	crowns_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowns_node)

func _in_crash_clearing(x: float, z: float) -> bool:
	# Поляна у места аварии: путь заноса, валун и обочина, по которой идёт Итан
	return x < 0.0 and x > -14.0 and z < -224.0 and z > -262.0

func _add_pine(trunks: Array[Transform3D], crowns: Array[Transform3D], pos: Vector3, sc: float) -> void:
	var turn := Basis(Vector3.UP, fmod(pos.x * 1.7 + pos.z * 0.9, TAU))
	trunks.append(Transform3D(turn.scaled(Vector3(0.26 * sc, 4.4 * sc, 0.26 * sc)), pos + Vector3(0.0, 2.2 * sc, 0.0)))
	for tier in range(3):
		var r := (1.85 - tier * 0.42) * sc
		crowns.append(Transform3D(turn.scaled(Vector3(r, 2.5 * sc, r)), pos + Vector3(0.0, (3.3 + tier * 1.5) * sc, 0.0)))

func _make_multimesh(mesh: Mesh, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	return mmi

# ──────────────────────────────────────────────────────────────────────────────
#  Место аварии и пикап Итана (тёмно-синий, как машина на 2-м уровне)
# ──────────────────────────────────────────────────────────────────────────────
func _build_crash_site() -> void:
	# Валун у обочины — как CrashSiteRock на 2-м уровне
	var rock := PrefabBuilder.build_prefab("prop_rock_large", Vector3(4.2, 3.2, 4.0), Color(0.32, 0.30, 0.28), false)
	rock.position = ROCK_POS
	rock.rotation_degrees = Vector3(5.0, 24.0, -6.0)
	add_child(rock)

func _build_car() -> void:
	car = Node3D.new()
	car.name = "EthanPickup"
	add_child(car)

	car_body = PrefabBuilder.build_prefab("prop_car", Vector3(2.0, 1.5, 4.4), Color(0.15, 0.22, 0.35), false)
	car.add_child(car_body)

	headlight_l = _make_headlight(-0.62, true)
	headlight_r = _make_headlight(0.62, false)

	cockpit = _build_cockpit()
	cockpit.visible = false
	car.add_child(cockpit)

	steam = _build_steam()
	steam.position = Vector3(0.0, 0.95, -1.85)
	car.add_child(steam)

func _make_headlight(x: float, shadows: bool) -> SpotLight3D:
	var hl := SpotLight3D.new()
	hl.light_color = Color(1.0, 0.95, 0.82)
	hl.light_energy = 10.0
	hl.spot_range = 55.0
	hl.spot_angle = 30.0
	hl.spot_attenuation = 0.6
	hl.shadow_enabled = shadows
	hl.light_volumetric_fog_energy = 2.5
	hl.position = Vector3(x, 0.66, -2.25)
	hl.rotation_degrees.x = -4.0
	car.add_child(hl)
	return hl

func _build_cockpit() -> Node3D:
	# Вид от лица водителя: снизу кадра только торпедо и капот
	var root := Node3D.new()
	root.name = "Cockpit"
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.035, 0.045)
	dark.roughness = 0.6
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.15, 0.22, 0.35)
	paint.metallic = 0.65
	paint.roughness = 0.35
	root.add_child(_box(Vector3(1.8, 0.06, 1.75), Vector3(0.0, 0.93, -1.4), paint))
	root.add_child(_box(Vector3(1.9, 0.2, 0.4), Vector3(0.0, 0.9, -0.6), dark))
	return root

func _build_steam() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.amount = 36
	p.lifetime = 2.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.35
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 25.0
	p.gravity = Vector3(0.0, 0.4, 0.0)
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.8
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.66, 0.72, 0.22))
	ramp.set_color(1, Color(0.62, 0.66, 0.72, 0.0))
	p.color_ramp = ramp

	# Мягкое круглое облачко вместо квадратной частицы
	var puff := Gradient.new()
	puff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	puff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var puff_tex := GradientTexture2D.new()
	puff_tex.gradient = puff
	puff_tex.fill = GradientTexture2D.FILL_RADIAL
	puff_tex.fill_from = Vector2(0.5, 0.5)
	puff_tex.fill_to = Vector2(1.0, 0.5)
	puff_tex.width = 64
	puff_tex.height = 64

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = puff_tex
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	quad.material = mat
	p.mesh = quad
	return p

# ──────────────────────────────────────────────────────────────────────────────
#  «Олень» на дороге (силуэт Olen.png), глаза загораются, когда он встаёт
# ──────────────────────────────────────────────────────────────────────────────
func _build_deer() -> void:
	deer_root = Node3D.new()
	deer_root.name = "Deer"
	deer_root.position = DEER_POS
	deer_root.visible = false
	add_child(deer_root)

	var body := Node3D.new()
	body.position = Vector3(0.0, DEER_HEIGHT * 0.5, 0.0)
	deer_root.add_child(body)

	var tex := TextureHelper.get_texture("res://assets/textures/Olen.png")
	var tex_size := tex.get_size() if tex else Vector2(345.0, 579.0)
	var px := DEER_HEIGHT / tex_size.y
	if tex:
		var sprite := Sprite3D.new()
		sprite.texture = tex
		sprite.pixel_size = px
		sprite.shaded = false
		sprite.double_sided = true
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.modulate = Color(0.02, 0.02, 0.025)
		body.add_child(sprite)

	deer_eyes = Node3D.new()
	deer_eyes.visible = false
	body.add_child(deer_eyes)
	var half := tex_size * 0.5
	for eye_px in DEER_EYES_PX:
		var p: Vector2 = eye_px
		deer_eyes.add_child(_make_eye(Vector3((p.x - half.x) * px, (half.y - p.y) * px, 0.03)))
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.15, 0.08)
	glow.light_energy = 1.4
	glow.omni_range = 2.2
	glow.position = Vector3((99.0 - half.x) * px, (half.y - 178.0) * px, 0.3)
	deer_eyes.add_child(glow)

func _make_eye(pos: Vector3) -> MeshInstance3D:
	if not eye_mesh:
		eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.05
		eye_mesh.height = 0.1
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.18, 0.1)
		eye_mesh.material = mat
	var eye := MeshInstance3D.new()
	eye.mesh = eye_mesh
	eye.position = pos
	return eye

# ──────────────────────────────────────────────────────────────────────────────
#  Обочина: камера 04 на сосне, упавший фонарик, глаза в чаще
# ──────────────────────────────────────────────────────────────────────────────
func _build_walk_props() -> void:
	var cam04 := Node3D.new()
	cam04.name = "ForestCamera04"
	cam04.position = CAM04_POS
	# Объектив смотрит вдоль шоссе — туда, где на кассете стоял «олень»
	cam04.rotation_degrees.y = 70.0
	add_child(cam04)
	var case_mat := StandardMaterial3D.new()
	case_mat.albedo_color = Color(0.16, 0.17, 0.14)
	case_mat.roughness = 0.8
	cam04.add_child(_box(Vector3(0.16, 0.34, 0.24), Vector3.ZERO, case_mat))
	var lens_mat := StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.04, 0.05, 0.07)
	lens_mat.metallic = 0.6
	lens_mat.roughness = 0.15
	cam04.add_child(_box(Vector3(0.03, 0.08, 0.08), Vector3(0.09, 0.07, 0.0), lens_mat))

	var number := Label3D.new()
	number.text = "04"
	number.font_size = 40
	number.pixel_size = 0.004
	number.outline_size = 8
	number.modulate = Color(0.92, 0.93, 0.88)
	number.position = Vector3(0.085, -0.08, 0.0)
	number.rotation_degrees.y = 90.0
	cam04.add_child(number)

	cam04_led = Node3D.new()
	cam04_led.position = Vector3(0.085, 0.13, 0.08)
	cam04.add_child(cam04_led)
	var led_dot := MeshInstance3D.new()
	var led_mesh := SphereMesh.new()
	led_mesh.radius = 0.012
	led_mesh.height = 0.024
	var led_mat := StandardMaterial3D.new()
	led_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	led_mat.albedo_color = Color(1.0, 0.1, 0.06)
	led_mesh.material = led_mat
	led_dot.mesh = led_mesh
	cam04_led.add_child(led_dot)
	var led_light := OmniLight3D.new()
	led_light.light_color = Color(1.0, 0.12, 0.06)
	led_light.light_energy = 0.7
	led_light.omni_range = 0.7
	cam04_led.add_child(led_light)

	# Фонарик Итана после падения: лежит на обочине, луч уходит в чащу
	dropped_light = Node3D.new()
	dropped_light.position = DROPPED_LIGHT_POS
	dropped_light.visible = false
	add_child(dropped_light)
	var torch := MeshInstance3D.new()
	var torch_mesh := CylinderMesh.new()
	torch_mesh.top_radius = 0.045
	torch_mesh.bottom_radius = 0.055
	torch_mesh.height = 0.32
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.12, 0.13, 0.15)
	metal.metallic = 0.8
	metal.roughness = 0.3
	torch_mesh.material = metal
	torch.mesh = torch_mesh
	torch.rotation_degrees.x = 90.0
	dropped_light.add_child(torch)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.96, 0.88)
	beam.light_energy = 8.0
	beam.spot_range = 30.0
	beam.spot_angle = 26.0
	beam.spot_attenuation = 0.6
	beam.shadow_enabled = true
	beam.light_volumetric_fog_energy = 3.0
	dropped_light.add_child(beam)
	dropped_light.look_at(Vector3(-15.0, 1.2, -239.4), Vector3.UP)

	# Глаза между стволами — на миг в луче фонарика
	forest_eyes = Node3D.new()
	forest_eyes.position = FOREST_EYES_POS
	forest_eyes.visible = false
	add_child(forest_eyes)
	forest_eyes.add_child(_make_eye(Vector3(0.0, 0.0, -0.065)))
	forest_eyes.add_child(_make_eye(Vector3(0.0, 0.0, 0.065)))
	var eyes_glow := OmniLight3D.new()
	eyes_glow.light_color = Color(1.0, 0.18, 0.08)
	eyes_glow.light_energy = 1.2
	eyes_glow.omni_range = 2.0
	eyes_glow.position = Vector3(0.3, 0.0, 0.0)
	forest_eyes.add_child(eyes_glow)

func _box(box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi

# ──────────────────────────────────────────────────────────────────────────────
#  Камера и фонарик в руке
# ──────────────────────────────────────────────────────────────────────────────
func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.name = "IntroCamera"
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 400.0
	cam.current = true
	add_child(cam)

	hand_light = SpotLight3D.new()
	hand_light.light_color = Color(1.0, 0.96, 0.88)
	hand_light.light_energy = 7.0
	hand_light.spot_range = 24.0
	hand_light.spot_angle = 28.0
	hand_light.spot_attenuation = 0.7
	hand_light.shadow_enabled = true
	hand_light.light_volumetric_fog_energy = 1.4
	hand_light.position = Vector3(0.22, -0.22, 0.0)
	hand_light.rotation_degrees.x = -4.0
	hand_light.visible = false
	cam.add_child(hand_light)

# ──────────────────────────────────────────────────────────────────────────────
#  Экран: затемнение, вспышка, полосы кадра, дата, субтитры, подсказка пропуска
# ──────────────────────────────────────────────────────────────────────────────
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "IntroOverlay"
	layer.layer = 40
	add_child(layer)

	var grain := TextureRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grain.texture = TextureHelper.get_texture("res://assets/textures/ui/horror_film_grunge_overlay.png")
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_SCALE
	grain.modulate = Color(0.72, 0.78, 0.88, 0.14)
	layer.add_child(grain)

	# Кинематографичные чёрные полосы сверху и снизу
	for is_top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if is_top else 0.9
		bar.anchor_bottom = 0.1 if is_top else 1.0
		layer.add_child(bar)

	black_rect = ColorRect.new()
	black_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black_rect.color = Color(0.0, 0.0, 0.0, 1.0)
	layer.add_child(black_rect)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1.0, 0.97, 0.92, 0.0)
	layer.add_child(flash_rect)

	title_box = VBoxContainer.new()
	title_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_box.add_theme_constant_override("separation", 10)
	title_box.modulate.a = 0.0
	title_box.add_child(_make_label("31 ОКТЯБРЯ 1994", 42, Color(0.92, 0.93, 0.95)))
	title_box.add_child(_make_label("Шоссе через лес Блэк-Пайн · 23:06", 18, Color(0.62, 0.66, 0.74)))
	layer.add_child(title_box)

	sub_box = VBoxContainer.new()
	sub_box.anchor_left = 0.1
	sub_box.anchor_right = 0.9
	sub_box.anchor_top = 0.7
	sub_box.anchor_bottom = 0.88
	sub_box.alignment = BoxContainer.ALIGNMENT_END
	sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_box.add_theme_constant_override("separation", 4)
	sub_box.modulate.a = 0.0
	speaker_label = _make_label("", 15, Color(0.62, 0.70, 0.82))
	line_label = _make_label("", 23, Color(0.95, 0.95, 0.96))
	line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_box.add_child(speaker_label)
	sub_box.add_child(line_label)
	layer.add_child(sub_box)

	# Строка из записки Сэма вспыхивает посреди экрана
	warn_label = _make_label("НЕ ОГЛЯДЫВАЙСЯ", 48, Color(0.86, 0.12, 0.10))
	warn_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	warn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	warn_label.add_theme_constant_override("outline_size", 10)
	warn_label.modulate.a = 0.0
	layer.add_child(warn_label)

	var skip_label := _make_label("[Пробел] пропустить", 13, Color(0.62, 0.65, 0.72, 0.7))
	skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_label.anchor_left = 0.5
	skip_label.anchor_right = 0.97
	skip_label.anchor_top = 0.92
	skip_label.anchor_bottom = 0.98
	layer.add_child(skip_label)

func _make_label(text: String, font_px: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _say(speaker: String, line: String, hold: float) -> void:
	speaker_label.text = speaker
	line_label.text = line
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	sub_box.modulate.a = 0.0
	_sub_tween = create_tween()
	_sub_tween.tween_property(sub_box, "modulate:a", 1.0, 0.25)
	_sub_tween.tween_interval(hold)
	_sub_tween.tween_property(sub_box, "modulate:a", 0.0, 0.35)

func _fade_black(alpha: float, duration: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(black_rect, "color:a", alpha, duration)

# ──────────────────────────────────────────────────────────────────────────────
#  Звук: разовые эффекты и петли (перезапуск по окончании)
# ──────────────────────────────────────────────────────────────────────────────
func _sfx(path: String, db: float = 0.0, pitch: float = 1.0, loop: bool = false) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	if loop:
		p.finished.connect(p.play)
	else:
		p.finished.connect(p.queue_free)
	p.play()
	return p

func _stop(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p):
		p.stop()
		p.queue_free()
