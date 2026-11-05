extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  IntroCutscene.gd — Вступление: от кассеты Сэма до кошмара Итана
#  1. Запись «ЛЕСНАЯ КАМЕРА 04», 14.10.1994: олень на шоссе встаёт на дыбы,
#     глаза горят красным, белый шум и шёпот Сэма «…не приезжай. Это не олень»
#  2. 31.10.1994, 21:40, последняя заправка перед лесом (scripts/GasStation.gd):
#     «Гольф» Итана встаёт у колонки, на витрине среди старых объявлений —
#     свежее «ПРОПАЛ: СЭМ КОУЛ»; три бутылки и карта на прилавке, кассирша
#     видит круг посреди леса и вполголоса называет три правила; уезжает —
#     она смотрит вслед. 23:06: шоссе через Блэк-Пайн, радио тонет в помехах
#  3. Фонари впереди гаснут один за другим, олень в свете фар: сигнал, тормоза
#     (нарушено первое правило), хруст суставов, крик, занос, удар о валун
#  4. Звон в ушах, мир глохнет; Итан приходит в себя в разбитой кабине,
#     отстёгивается, берёт фонарик из бардачка и вываливается из машины
#  5. Сигнал смолкает сам, сверчки замолкают разом, «Сэм» зовёт из леса —
#     Итан отзывается (второе правило)
#  6. Камера 04 на сосне, вспышка памяти, падение, глаза в чаще, далёкий смех,
#     шёпот у самого уха → «НЕ ОГЛЯДЫВАЙСЯ» → оборачивается (третье) → скример
#  7. Запись камеры 04: тело Итана, фонарик, высокая тень между соснами
#  8. Итана волокут за ноги: налобный фонарь, хрип старика, искры электрической
#     калитки, лязг ворот и тот самый смех с обочины → 1-й уровень (сон)
#  Звуки: assets/audio/intro/*.wav — их собирает scripts/generate_intro_sfx.js
#  [Пробел / Enter / Esc / Start] — пропустить
# ══════════════════════════════════════════════════════════════════════════════

const SND := "res://assets/audio/intro/"
const BUS_MASTER := "Master"
const BUS_WORLD := "IntroWorld"    # мир вокруг: глохнет после удара
const BUS_VERB := "IntroVerb"      # далёкое в лесу: с отражениями
const BUS_TAPE := "IntroTape"      # звук записи камеры 04: узкая полоса
const BUS_NEAR := "IntroNear"      # у самого уха, слева

# ── Раскадровка (секунды от начала вступления) ──
# 1. Запись камеры 04
const T_VCR: float = 0.15
const T_FOOTAGE: float = 1.3
const T_RISE_TAPE: float = 4.4
const T_TILT_TAPE: float = 6.7
const T_EYES_TAPE: float = 7.3
const T_JUMP_TAPE: float = 8.0      # сбой кадра: олень вдруг ближе
const T_STATIC: float = 8.6
const T_TAPE_VOICE: float = 8.7     # tape_whisper.wav: фраза А с 0.05 с, фраза Б с 3.35 с
const T_EJECT: float = 13.3
# 2. Заправка, 21:40 (фразы кассирши: cashier_*.wav, речь 1.7 / 1.4 / 2.7 / 2.4 / 3.35 с)
const T_TITLE: float = 13.8
const T_GS_ARRIVE: float = 16.4     # «Гольф» сворачивает с шоссе к колонке
const T_GS_PARKED: float = 20.3     # встал у колонки, мотор глохнет
const T_GS_WINDOW: float = 21.0     # снаружи у витрины: объявление о Сэме, за стеклом кассирша
const T_GS_COUNTER: float = 23.6    # у прилавка: бутылки, карта, касса
const T_GS_ASK: float = 26.1        # «Сегодня ночью — в Блэк-Пайн?»
const T_GS_THREE: float = 28.1      # «Тогда запомни три вещи»
const T_GS_RULE_1: float = 29.85
const T_GS_RULE_2: float = 32.9
const T_GS_RULE_3: float = 35.65
const T_GS_TAKE: float = 39.3       # бутылки в рюкзак, она смотрит в окно, на лес
const T_GS_LEAVE: float = 40.3      # через дорогу: «Гольф» выезжает на шоссе, в окне — кассирша
const T_GS_END: float = 44.3
# Всё, что дальше, сдвинуто на длину заправки (раньше шоссе начиналось сразу после кассеты)
const GS_SHIFT: float = 23.3
const T_DRIVE: float = 44.9         # 23:06, шоссе через Блэк-Пайн
const T_RADIO_CUT: float = 26.6 + GS_SHIFT
# 3. Олень
const T_POV: float = 27.2 + GS_SHIFT
const T_DEER_SEEN: float = 28.8 + GS_SHIFT
const T_HORN: float = 30.6 + GS_SHIFT
const T_BRAKE: float = 30.75 + GS_SHIFT
const T_REAR: float = 31.1 + GS_SHIFT
const T_DEER_EYES: float = 31.7 + GS_SHIFT
const T_SWERVE: float = 32.3 + GS_SHIFT
const T_GRAVEL: float = 32.95 + GS_SHIFT
const T_CRASH: float = 33.6 + GS_SHIFT
# 4. После удара
const T_EARS: float = 37.0 + GS_SHIFT
const T_WAKE: float = 38.2 + GS_SHIFT
const T_BELT: float = 40.7 + GS_SHIFT
const T_GLOVEBOX: float = 41.3 + GS_SHIFT
const T_DOOR: float = 42.2 + GS_SHIFT
const T_OUT: float = 43.9 + GS_SHIFT
const T_ROAD_LOOK: float = 45.8 + GS_SHIFT
const T_TORCH_ON: float = 47.0 + GS_SHIFT
# 5. Голос из леса
const T_HORN_STOP: float = 48.4 + GS_SHIFT
const T_VOICE: float = 49.8 + GS_SHIFT
const T_ANSWER: float = 52.7 + GS_SHIFT
# 6. Камера 04 и шёпот
const T_WALK: float = 54.0 + GS_SHIFT
const T_CAM04: float = 57.0 + GS_SHIFT
const T_FLASHBACK: float = 58.4 + GS_SHIFT
const FLASHBACK_LEN: float = 0.4
const T_FALL: float = 59.4 + GS_SHIFT
const T_EYES: float = 60.5 + GS_SHIFT
const T_LAUGH: float = 61.5 + GS_SHIFT
const T_WHISPER: float = 63.2 + GS_SHIFT
const T_DONT_LOOK: float = 67.4 + GS_SHIFT
const T_TURN: float = 68.6 + GS_SHIFT
const T_SCARE: float = 69.45 + GS_SHIFT   # полсекунды мёртвой тишины после поворота
# Итан выбрался из машины: дальше игрок идёт сам по карте «Шоссе»
const T_TO_MAP: float = 46.8 + GS_SHIFT
# 7–8. Эпилог: секунды от конца скримера. Его показывает карта «Шоссе» после своего скримера
const E_FOOTAGE: float = 0.5
const E_STOP: float = 3.4
const E_LOOK: float = 3.7
const E_STATIC: float = 4.7
const E_DRAG: float = 5.3
const E_SPARK: float = 8.4
const E_GATE: float = 9.4
const E_SLAM: float = 11.2
const E_LAUGH: float = 12.0
const E_FADE: float = 13.6
const E_END: float = 14.9
const DRAG_PERIOD: float = 1.3

# Фонари, которые гаснут перед оленем: номер → время; последний — прямо над машиной
const LAMP_DIE := {12: 27.7 + GS_SHIFT, 11: 28.15 + GS_SHIFT, 10: 28.6 + GS_SHIFT, 9: 29.05 + GS_SHIFT, 8: 29.5 + GS_SHIFT, 7: 30.0 + GS_SHIFT}
const LAMP_FLICKER: int = 8         # после аварии мигает один фонарь через дорогу
const LAMP_ON := Color(1.0, 0.78, 0.52)
const LAMP_OFF := Color(0.16, 0.13, 0.1)

# ── Движение машины ──
# На шоссе машина в кадре 5.6 с (а не 10.6, как без заправки) — стартует ближе,
# чтобы к T_POV оказаться там же, у z = -144
const CAR_START_Z: float = -32.0
const CAR_SPEED: float = 20.0          # ~72 км/ч
const CAR_BRAKE_SPEED: float = 9.0
const BRAKE_TIME: float = 1.4
const SWERVE_X: float = -7.2           # уход влево с дороги
const SWERVE_YAW_DEG: float = 34.0

# ── Точки сцены (машина врезается в валун у z ≈ -247) ──
const ROAD_START_Z: float = 100.0
const ROAD_END_Z: float = -540.0
const DEER_POS := Vector3(0.4, 0.0, -244.5)
const DEER_JUMP_POS := Vector3(-1.6, 0.0, -239.8)
const DEER_SIGN_POS := Vector3(4.4, 0.0, -84.0)
const ROCK_POS := Vector3(-9.6, 0.0, -250.8)
const CAM04_PINE_POS := Vector3(-6.3, 0.0, -231.55)
const CAM04_POS := Vector3(-6.3, 1.45, -231.95)
const FOOTAGE_TARGET := Vector3(-4.0, 0.2, -246.0)
const FOOTAGE_FOV: float = 56.0
const OUT_LOW := Vector3(-8.9, 0.4, -245.2)
const OUT_STAND := Vector3(-8.7, 1.62, -244.6)
const WALK_END := Vector3(-7.0, 1.62, -238.6)
const FALLEN_POS := Vector3(-7.15, 0.48, -238.35)
const DROPPED_LIGHT_POS := Vector3(-8.3, 0.06, -237.2)
const DROPPED_LIGHT_AIM := Vector3(-16.0, 1.1, -235.0)
const FOREST_EYES_POS := Vector3(-15.2, 1.85, -235.4)
const BODY_POS := Vector3(-7.0, 0.2, -238.7)
const WALKER_FROM := Vector3(-12.9, 0.0, -252.2)
const WALKER_TO := Vector3(-11.9, 0.0, -248.2)
const DRAG_FROM := Vector3(-19.5, 0.32, -239.0)
const DEER_HEIGHT: float = 2.3
const DEER_EYES_PX = [Vector2(82, 178), Vector2(116, 178)]   # глаза на Olen.png

const CASHIER := "КАССИРША"
const SAM_TAPE := "СЭМ · ЗАПИСЬ КАМЕРЫ 04"

# ── Заправка (scripts/GasStation.gd): стоит далеко от шоссе с оленем, в своём лесу.
#    Координаты ниже — в осях заправки: её шоссе идёт вдоль Z при x = 0, магазин справа ──
const GS_ORIGIN := Vector3(0.0, 0.0, 1000.0)
const GS_CAM_ARRIVE := Vector3(-7.5, 1.6, 9.0)      # через дорогу: видно навес, магазин и вывеску
const GS_CAM_WINDOW := Vector3(21.1, 1.5, 2.66)     # снаружи у витрины: её лицо — в просвете между листами
const GS_POSTER := Vector3(21.955, 1.5, 2.84)       # свежее объявление о Сэме на стекле
const GS_CAM_COUNTER := Vector3(24.05, 1.6, 1.3)    # Итан у прилавка
const GS_CAM_LEAVE := Vector3(-6.0, 1.5, -8.0)      # через дорогу: машина уходит влево, магазин светится
const GS_DOOR := Vector3(21.96, 1.6, -3.3)
const GS_MAGAZINE := Vector3(24.86, 0.95, 2.9)      # журнал на прилавке: в него она смотрит, пока никого нет
const GS_WINDOW_DARK := Vector3(21.0, 1.7, -1.8)    # за окном — тёмный лес
const GS_BOTTLES := [Vector3(24.79, 0.98, 1.06), Vector3(24.74, 0.98, 1.19), Vector3(24.81, 0.98, 1.32)]
const GS_BOTTLE_CLINK := [0.15, 0.41, 0.65]         # когда каждая встаёт на прилавок (bottles_clink.wav)
const GS_MAP_POS := Vector3(24.84, 0.982, 1.8)
const GS_CAR_ACCEL: float = 4.0
const GS_CAR_GO: float = 0.4                         # через сколько после T_GS_LEAVE трогается

# Запись камеры 04: зеленовато-серая ИК-картинка, где выживает только красный
const FOOTAGE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float static_amt = 0.0;
uniform float time_s = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 c = SCREEN_UV - 0.5;
	vec2 uv = 0.5 + c * (1.0 - 0.07 * amount * dot(c, c));
	float row = floor(uv.y * 240.0);
	uv.x += amount * (h(vec2(row, floor(time_s * 30.0))) - 0.5) * 0.003;
	vec3 col = texture(screen_tex, uv).rgb;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	lum = 1.0 - exp(-lum * 3.2);                    // автоусиление ночной камеры
	float red = clamp((col.r - max(col.g, col.b) * 1.6) * 5.0, 0.0, 1.0);
	vec3 mono = vec3(lum) * vec3(0.86, 1.0, 0.9);
	mono = (mono - 0.5) * 1.2 + 0.52;
	vec3 tape = mix(mono, col * vec3(1.7, 0.45, 0.45), red);
	tape += (h(uv * 731.0 + time_s * 17.0) - 0.5) * 0.13;
	tape *= 0.9 + 0.1 * sin(uv.y * 900.0);
	tape *= 1.0 - 0.6 * smoothstep(0.35, 0.8, length(c));
	vec3 outc = mix(col, tape, amount);
	float sn = h(floor(SCREEN_UV * vec2(320.0, 240.0)) + floor(time_s * 24.0) * 7.0);
	outc = mix(outc, vec3(sn * 0.62 + 0.06), static_amt);
	COLOR = vec4(outc, 1.0);
}
"""

var cam: Camera3D
var cam_attr: CameraAttributesPractical
var car: Node3D
var car_body: EthanCar             # кузов и настоящий салон: вид от лица — изнутри него
var hood: Node3D
var wheel_spin: Node3D
var speed_needle: Node3D
var freshener: Node3D
var headlight_l: SpotLight3D
var headlight_r: SpotLight3D
var steam: CPUParticles3D
var deer_root: Node3D
var deer_eyes: Node3D
var deer_eye_meshes: Array[MeshInstance3D] = []
var hand_light: SpotLight3D
var dropped_light: Node3D
var forest_eyes: Node3D
var cam04: Node3D
var cam04_led: Node3D
var cam04_flash: OmniLight3D
var ir_light: SpotLight3D
var ethan_body: Node3D
var walker: SkinwalkerModel
var walker_eyes: Node3D
var oldman: Node3D
var headlamp: SpotLight3D
var spark_light: OmniLight3D
var gate_glow: OmniLight3D
var world_env: Environment
var moon_light: DirectionalLight3D
var eye_mesh: SphereMesh
var lamp_lights: Array[SpotLight3D] = []
var lamp_mats: Array[StandardMaterial3D] = []
var lamp_ks: Array[int] = []

# Экран
var footage_rect: ColorRect
var footage_mat: ShaderMaterial
var rec_box: Control
var rec_dot: Label
var date_label: Label
var time_label: Label
var bars: Array[ColorRect] = []
var crack: Control
var blood: TextureRect
var blood_drip: ColorRect
var black_rect: ColorRect
var flash_rect: ColorRect
var title_box: VBoxContainer
var sub_back: ColorRect
var sub_box: VBoxContainer
var speaker_label: Label
var line_label: Label
var warn_label: Label

# Звук
var muffle: AudioEffectLowPassFilter
var engine_player: AudioStreamPlayer
var radio_player: AudioStreamPlayer
var drone_player: AudioStreamPlayer
var horn_loop: AudioStreamPlayer
var steam_player: AudioStreamPlayer
var tick_player: AudioStreamPlayer
var crickets_player: AudioStreamPlayer
var wind_player: AudioStreamPlayer
var heart_player: AudioStreamPlayer
var hum_player: AudioStreamPlayer
var wheeze_player: AudioStreamPlayer
var static_player: AudioStreamPlayer
var tape_players: Array[AudioStreamPlayer] = []

# Заправка
var station: GasStation
var gs_bottles: Array[Node3D] = []
var gs_map: MeshInstance3D
var gs_attr: CameraAttributesPractical
var gs_arrive_path: Dictionary = {}
var gs_leave_path: Dictionary = {}
var gs_players: Array[AudioStreamPlayer] = []
var gs_room: AudioStreamPlayer
var gs_radio: AudioStreamPlayer
var gs_engine: AudioStreamPlayer
var gs_idle: AudioStreamPlayer
var title_place: Label
var time_card: Label

var _t: float = 0.0
var _fired: Dictionary = {}
var _trauma: float = 0.0
var _next_step_t: float = 0.0
var _step_idx: int = 0
var _car_crashed: bool = false
var _finished: bool = false
var _epi_t0: float = -1.0
var _epilogue_only: bool = false
var _spark_t0: float = -1.0
var _static_blip_until: float = -1.0
var _sub_tween: Tween = null
var _fade_tween: Tween = null
var _fresh_ang := Vector2.ZERO        # освежитель-ёлочка: (вперёд-назад, вбок)
var _fresh_vel := Vector2.ZERO
var _prev_speed: float = 0.0

func _ready() -> void:
	name = "IntroCutscene"
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_setup_audio_buses()
	_setup_environment()
	_build_ground_and_road()
	_build_streetlights()
	_build_deer_sign()
	_build_forest()
	_build_crash_site()
	_build_car()
	# Финал после карты «Шоссе» начинается с аварии — заправка ему не нужна
	if not (GameManager and GameManager.intro_epilogue):
		_build_station()
	_build_deer()
	_build_walk_props()
	_build_epilogue_props()
	_setup_camera()
	_build_overlay()

	if GameManager:
		GameManager.graphics_quality_changed.connect(_apply_graphics_quality)

	car.visible = false
	if GameManager and GameManager.intro_epilogue:
		GameManager.intro_epilogue = false
		_start_epilogue_only()
	_update_scene(0.0)

func _exit_tree() -> void:
	_remove_audio_buses()
	if VHSOverlay:
		VHSOverlay.set_fear(0.0)

func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	if not _epilogue_only:
		_run_timeline()
	if _finished:
		return
	if _epi_t0 >= 0.0:
		_run_epilogue()
	if not _finished:
		_update_scene(delta)

func _update_scene(delta: float) -> void:
	_update_car(delta)
	_update_deer()
	_update_props(delta)
	_update_camera(delta)
	_update_overlay()

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
	if _once("to_map_fade", T_TO_MAP - 0.7):
		_fade_black(1.0, 0.7)
	if _once("to_map", T_TO_MAP):
		_finish()
		return
	# ─ 1. Запись камеры 04: олень, который встаёт как человек ─
	if _once("vcr", T_VCR):
		_sfx("vcr_insert", -9.0, 1.0, false, BUS_MASTER)
	if _once("footage", T_FOOTAGE):
		tape_players.append(_sfx("tape_hiss", -18.0, 1.0, true, BUS_MASTER))
		tape_players.append(_sfx("forest_wind", -6.0, 1.0, true, BUS_TAPE))
		tape_players.append(_sfx("lamp_buzz", -18.0, 1.0, true, BUS_TAPE))
		_fade_black(0.0, 0.5)
	if _once("tape_rise", T_RISE_TAPE):
		_sfx("bone_crack", -3.0, 0.9, false, BUS_TAPE)
	if _once("tape_eyes", T_EYES_TAPE):
		_sfx("sub_hit", -9.0, 1.0, false, BUS_MASTER)
	if _once("tape_jump", T_JUMP_TAPE):
		VHSOverlay.glitch(0.8)
		_static_blip_until = _t + 0.16
		_sfx_for("tape_static", -15.0, 0.16, BUS_MASTER)
	if _once("static", T_STATIC):
		VHSOverlay.glitch(1.0)
		static_player = _sfx("tape_static", -16.0, 1.0, true, BUS_MASTER)
		for p in tape_players:
			_fade_out(p, 0.08)
		tape_players.clear()
	if _once("tape_voice", T_TAPE_VOICE):
		_sfx("tape_whisper", -3.0, 1.0, false, BUS_MASTER)
	if _once("tape_line_a", T_TAPE_VOICE + 0.05):
		_say(SAM_TAPE, "«Итан, если это попадёт к тебе — не приезжай…»", 2.9)
	if _once("tape_line_b", T_TAPE_VOICE + 3.35):
		_say(SAM_TAPE, "«Это не олень».", 1.1)
	if _once("eject", T_EJECT):
		_stop(static_player)
		static_player = null
		_sfx("vcr_stop", -9.0, 1.0, false, BUS_MASTER)
		_set_black(1.0)
		car.visible = true

	# ─ 2. Заправка, 21:40: последний свет перед лесом ─
	if _once("title", T_TITLE):
		create_tween().tween_property(title_box, "modulate:a", 1.0, 0.9)
		if station:
			# Пока на экране дата, из темноты слышно: сверчки, гудит вывеска, едет машина
			gs_players.append(_sfx("crickets", -30.0, 1.0, true))
			gs_players.append(_sfx("forest_wind", -31.0, 1.0, true))
			gs_players.append(_sfx("lamp_buzz", -29.0, 1.12, true))
			gs_room = _sfx("shop_room", -44.0, 1.0, true, BUS_MASTER)
			gs_radio = _sfx("shop_radio", -42.0, 1.0, true, BUS_MASTER)
			gs_players.append(gs_room)
			gs_players.append(gs_radio)
			gs_engine = _sfx("engine_ext", -44.0, 0.86, true)
			_fade_to(gs_engine, -22.0, 2.6)
	if _once("title_out", T_GS_ARRIVE - 0.8):
		create_tween().tween_property(title_box, "modulate:a", 0.0, 0.7)
	if _once("gs_arrive", T_GS_ARRIVE):
		_fade_black(0.0, 0.9)
		_fade_to(gs_engine, -13.0, 1.1)
	if _once("gs_slow", T_GS_ARRIVE + 1.2):
		if is_instance_valid(gs_engine):
			create_tween().tween_property(gs_engine, "pitch_scale", 0.55, 2.3)
		_fade_to(gs_engine, -17.0, 2.3)
	if _once("gs_tyres", T_GS_PARKED - 2.2):
		_sfx("tyres_roll", -15.0)
	if _once("gs_idle", T_GS_PARKED - 0.45):
		gs_idle = _sfx("engine_idle", -30.0, 1.0, true)
		_fade_to(gs_idle, -15.0, 0.35)
		_fade_out(gs_engine, 0.45)
		gs_engine = null
	if _once("gs_engine_off", T_GS_PARKED + 0.3):
		_stop(gs_idle)
		gs_idle = null
		_sfx("engine_off", -13.0)
		gs_players.append(_sfx("engine_tick", -27.0, 1.0, true))
	# Снаружи у витрины: хлопает дверца, шаги, колокольчик над дверью магазина
	if _once("gs_window", T_GS_WINDOW):
		_sfx("car_door", -16.0)
		_fade_to(gs_room, -36.0, 0.3)
		_fade_to(gs_radio, -34.0, 0.3)
	if _once("gs_steps", T_GS_WINDOW + 0.55):
		_sfx("steps_concrete", -17.0)
	if _once("gs_bell", T_GS_WINDOW + 1.9):
		_sfx("door_bell", -9.0)
	# У прилавка: всё, что снаружи, слышно через стекло
	if _once("gs_inside", T_GS_COUNTER):
		_set_muffle(1300.0, 0.05)
		_fade_to(gs_room, -20.0, 0.05)
		_fade_to(gs_radio, -25.0, 0.05)
	if _once("gs_bottles", T_GS_COUNTER + GS_BOTTLE_CLINK[0]):
		_sfx("bottles_clink", -9.0, 1.0, false, BUS_MASTER)
	if _once("gs_map", T_GS_COUNTER + 0.8):
		_sfx("map_paper", -12.0, 1.0, false, BUS_MASTER)
	if _once("gs_register", T_GS_COUNTER + 1.25):
		_sfx("cash_register", -11.0, 1.0, false, BUS_MASTER)
	if _once("gs_ask", T_GS_ASK):
		_fade_to(gs_radio, -29.0, 0.6)
		_cashier_says("cashier_ask", "Сегодня ночью — в Блэк-Пайн?", 1.7)
	if _once("gs_three", T_GS_THREE):
		_cashier_says("cashier_three", "Тогда запомни три вещи.", 1.4)
	if _once("gs_rule_1", T_GS_RULE_1):
		_cashier_says("cashier_rule_1", "Увидишь на дороге оленя — не останавливайся.", 2.7)
	if _once("gs_rule_2", T_GS_RULE_2):
		_cashier_says("cashier_rule_2", "Позовут по имени из леса — не отзывайся.", 2.4)
	if _once("gs_rule_3", T_GS_RULE_3):
		_cashier_says("cashier_rule_3", "Почувствуешь, что кто-то идёт следом, — не оборачивайся.", 3.35)
	if _once("gs_take", T_GS_TAKE):
		_sfx("bottles_take", -10.0, 1.0, false, BUS_MASTER)
		_fade_to(gs_radio, -25.0, 1.0)
	# Через дорогу: «Гольф» трогается от колонки и уходит по шоссе в темноту
	if _once("gs_leave", T_GS_LEAVE):
		_set_muffle(20000.0, 0.05)
		_fade_to(gs_room, -40.0, 0.05)
		_fade_to(gs_radio, -36.0, 0.05)
		gs_idle = _sfx("engine_idle", -16.0, 1.0, true)
	if _once("gs_pull_away", T_GS_LEAVE + GS_CAR_GO):
		gs_engine = _sfx("engine_ext", -16.0, 0.6, true)
		if is_instance_valid(gs_engine):
			create_tween().tween_property(gs_engine, "pitch_scale", 1.0, 2.6)
		_fade_to(gs_engine, -11.0, 1.6)
		_fade_out(gs_idle, 0.35)
		gs_idle = null
		_sfx("tyres_roll", -19.0, 1.25)
	if _once("gs_away", T_GS_LEAVE + 2.2):
		_fade_to(gs_engine, -26.0, 1.8)
	if _once("gs_end", T_GS_END):
		_fade_black(1.0, 0.6)
		for p in gs_players:
			_fade_out(p, 0.6)
		gs_players.clear()
		_fade_out(gs_engine, 0.6)
		gs_engine = null

	# ─ 2b. 23:06, шоссе через Блэк-Пайн: радио тонет в помехах ─
	if _once("drive", T_DRIVE):
		_set_muffle(20000.0, 0.05)
		_fade_black(0.0, 1.2)
		engine_player = _sfx("engine_ext", -18.0, 1.0, true)
		_fade_to(engine_player, -9.0, 1.4)
		radio_player = _sfx("radio_static", -27.0, 1.0, true)
		_show_time_card()
	if _once("radio_swell", T_RADIO_CUT - 0.9):
		_fade_to(radio_player, -18.0, 0.8)
	if _once("radio_cut", T_RADIO_CUT):
		_stop(radio_player)
		radio_player = null
		_sfx("radio_cut", -14.0)

	# ─ 3. Фонари гаснут, олень, сигнал, тормоза, занос, валун ─
	if _once("pov", T_POV):
		var outside := engine_player
		engine_player = _sfx("engine_int", -8.0, 1.0, true)
		_fade_out(outside, 0.12)
	for k in LAMP_DIE:
		if _once("lamp_%d" % k, LAMP_DIE[k]):
			_sfx("lamp_pop", -24.0 + (12 - k) * 3.6, randf_range(0.92, 1.06))
	if _once("drone", LAMP_DIE[12]):
		drone_player = _sfx("dread_drone", -22.0)
		_fade_to(drone_player, -9.0, 3.0)
	if _once("horn", T_HORN):
		_sfx("horn_double", -3.0)
	if _once("brake", T_BRAKE):
		_sfx("brake_squeal", -6.0)
		if engine_player:
			create_tween().tween_property(engine_player, "pitch_scale", 0.68, BRAKE_TIME)
	if _once("rear", T_REAR):
		_sfx("bone_crack", -2.0)
	if _once("deer_eyes", T_DEER_EYES):
		_sfx("creature_shriek", -3.0)
		_sfx("sub_hit", -6.0)
	if _once("swerve", T_SWERVE):
		_sfx("tire_screech", -2.0)
		_trauma = 0.55
	if _once("gravel", T_GRAVEL):
		_sfx("gravel_skid", -3.0)
		_trauma = 0.8
	if _once("crash", T_CRASH):
		_crash()

	# ─ 4. Звон в ушах, кабина, выход из машины ─
	# Сначала слышно, как мнётся металл и сыплется стекло, потом мир глохнет
	if _once("muffle", T_CRASH + 0.4):
		_set_muffle(380.0, 0.6)
	if _once("aftermath", T_CRASH + 0.9):
		horn_loop = _sfx("horn_stuck", -10.0, 1.0, true)
		steam_player = _sfx("steam_loop", -13.0, 1.0, true)
		tick_player = _sfx("engine_tick", -12.0, 1.0, true)
	if _once("heart_1", T_CRASH + 1.4):
		heart_player = _sfx_res("res://assets/heart.mp3", -30.0, 0.95, true, BUS_MASTER)
		_fade_to(heart_player, -9.0, 1.5)
	if _once("ears", T_EARS):
		_set_muffle(20000.0, 2.6)
	if _once("wake", T_WAKE):
		_fade_black(0.0, 0.9)
	if _once("cough", T_WAKE + 0.35):
		_sfx_res("res://assets/audio/player_cough_gasp.wav", -10.0, 0.95, false, BUS_MASTER)
	if _once("blink_1", T_WAKE + 1.3):
		_blink(0.18)
	if _once("blink_2", T_WAKE + 2.2):
		_blink(0.12)
	if _once("belt", T_BELT):
		_sfx("seatbelt", -8.0)
	if _once("glovebox", T_GLOVEBOX):
		_sfx("glovebox", -8.0)
	if _once("door_black", T_DOOR - 0.25):
		_fade_black(1.0, 0.3)
	if _once("door", T_DOOR):
		_sfx("door_creak", -5.0)
		crickets_player = _sfx("crickets", -36.0, 1.0, true)
		wind_player = _sfx("forest_wind", -32.0, 1.0, true)
		_fade_to(crickets_player, -18.0, 1.2)
		_fade_to(wind_player, -17.0, 1.2)
		_fade_to(horn_loop, -6.0, 0.8)          # дверь открыта — сигнал во всю мощь
		_fade_to(heart_player, -24.0, 3.0)
	if _once("fall_out", T_DOOR + 1.35):
		_sfx("body_fall", -5.0)
		_trauma = 0.4
	if _once("out", T_OUT):
		_fade_black(0.0, 0.8)
	if _once("torch", T_TORCH_ON):
		_sfx("flashlight_click", -8.0)

	# ─ 5. Сигнал смолкает сам — и замолкает весь лес ─
	if _once("horn_stop", T_HORN_STOP):
		_stop(horn_loop)
		horn_loop = null
		_sfx("horn_die", -6.0)
		_stop(crickets_player)
		crickets_player = null
		_fade_to(wind_player, -25.0, 0.6)
		_fade_to(steam_player, -21.0, 1.0)
		_fade_out(heart_player, 1.0)
		heart_player = null
		_trauma = 0.2
	if _once("voice", T_VOICE):
		_sfx("voice_call", -4.0)
		_say("ГОЛОС ИЗ ЛЕСА", "«Итан!.. Итан, я здесь!»", 2.8)
	if _once("answer", T_ANSWER):
		_say("ИТАН", "«Сэм?! СЭМ!»", 1.2)

	# ─ 6. Камера 04, падение, глаза, шёпот ─
	if _once("walk", T_WALK):
		_next_step_t = T_WALK + 0.35
		_fade_to(steam_player, -28.0, 4.0)
		_sfx("breath_panic", -18.0, 1.0, false, BUS_MASTER)
	if _once("cam04", T_CAM04):
		_say("ИТАН", "«04»… Камера Сэма. Значит, это снято здесь.", 2.3)
	if _once("trailcam", T_CAM04 + 0.45):
		_sfx("trailcam_click", -9.0)
		cam04_flash.light_energy = 2.5
	if _once("flashback", T_FLASHBACK):
		VHSOverlay.glitch(0.9)
		_sfx_for("tape_static", -13.0, FLASHBACK_LEN, BUS_MASTER)
		_sfx("sub_hit", -9.0, 1.1)
	if _once("fall", T_FALL):
		_fall()
	if _once("torch_drop", T_FALL + 0.08):
		_sfx("flashlight_drop", -5.0)
	if _once("breath_fall", T_FALL + 0.7):
		_sfx("breath_panic", -11.0, 1.04, false, BUS_MASTER)
	if _once("eyes_on", T_EYES):
		forest_eyes.visible = true
		_sfx("twig_snap", -7.0, 1.0, false, BUS_VERB)
		_sfx_res("res://assets/audio/monster/monster_clicks.wav", -17.0, 0.9, false, BUS_VERB)
	if _once("eyes_off", T_EYES + 0.85):
		forest_eyes.visible = false
	if _once("laugh", T_LAUGH):
		_fade_out(_sfx_res("res://assets/creepy_laugh.mp3", -16.0, 1.0, false, BUS_VERB, 1.25), 0.5, 1.6)
	if _once("hush", T_WHISPER - 0.9):
		_fade_to(wind_player, -42.0, 0.8)
		_fade_to(steam_player, -40.0, 0.8)
	if _once("whisper", T_WHISPER):
		_sfx("whisper_behind", -4.0, 1.0, false, BUS_NEAR)
		_say("ШЁПОТ ЗА СПИНОЙ", "«Итан… обернись. Посмотри на меня».", 3.9)
		VHSOverlay.set_fear(0.4)
	if _once("dont_look", T_DONT_LOOK):
		_flash_warning()
		VHSOverlay.glitch(0.9)
		_sfx("sub_hit", -4.0, 1.0, false, BUS_MASTER)
		_sfx_for("tape_static", -16.0, 0.25, BUS_MASTER)
	if _once("turn", T_TURN):
		_silence(0.35)
	if _once("scare", T_SCARE):
		_start_scare()

	# Шаги по гравию обочины
	if _t > T_WALK and _t < T_FALL - 0.2 and _t >= _next_step_t:
		_next_step_t = _t + 0.62
		_step_idx += 1
		_sfx("step_gravel_%d" % (1 + _step_idx % 4), -10.0, randf_range(0.93, 1.06))

func _run_epilogue() -> void:
	var b := _epi_t0
	var e := _t - b
	# ─ 7. Запись камеры 04: тень между соснами ─
	if _once("e_footage", b + E_FOOTAGE):
		tape_players.append(_sfx("tape_hiss", -18.0, 1.0, true, BUS_MASTER))
		tape_players.append(_sfx("forest_wind", -7.0, 1.0, true, BUS_TAPE))
		tape_players.append(_sfx("lamp_buzz", -20.0, 1.0, true, BUS_TAPE))
		_fade_black(0.0, 0.4)
	if _once("e_look", b + E_LOOK):
		_sfx("sub_hit", -11.0, 0.9, false, BUS_MASTER)
	if _once("e_static", b + E_STATIC):
		VHSOverlay.glitch(1.0)
		static_player = _sfx("tape_static", -15.0, 1.0, true, BUS_MASTER)
		for p in tape_players:
			_fade_out(p, 0.05)
		tape_players.clear()
	# ─ 8. Итана волокут к особняку ─
	if _once("e_drag", b + E_DRAG):
		_stop(static_player)
		static_player = null
		_set_black(1.0)
		walker.visible = false
		walker_eyes.visible = false
		ethan_body.visible = false
		wheeze_player =_sfx_res("res://assets/ded.mp3", -11.0, 0.95, true)
		hum_player = _sfx_res("res://assets/audio/electric_hum.wav", -36.0, 1.0, true)
		_fade_to(hum_player, -10.0, E_GATE - E_DRAG)
	if e >= E_DRAG and e < E_SLAM - 0.4:
		var pull := floori((e - E_DRAG) / DRAG_PERIOD)
		if _once("e_pull_%d" % pull, b + E_DRAG + pull * DRAG_PERIOD):
			_sfx("drag_pull", -7.0, randf_range(0.9, 1.05))
			_sfx_res("res://assets/audio/step_%d.mp3" % (1 + pull % 2), -9.0, 0.82)
	if _once("e_glimpse_1", b + E_DRAG + 0.5):
		_glimpse(1.5)
	if _once("e_glimpse_2", b + E_SPARK - 0.25):
		_glimpse(0.9)
	if _once("e_spark", b + E_SPARK):
		_sfx_res("res://assets/audio/electric_spark.wav", -4.0)
		_spark_t0 = _t
	if _once("e_spark_2", b + E_SPARK + 0.26):
		_sfx_res("res://assets/audio/electric_spark.wav", -10.0, 1.15)
	if _once("e_gate", b + E_GATE):
		_sfx("gate_creak", -5.0)
	if _once("e_slam", b + E_SLAM):
		_sfx("gate_slam", -2.0)
		_fade_to(wheeze_player, -22.0, 1.5)
	if _once("e_laugh", b + E_LAUGH):
		# Тот же смех, что на обочине: те же паузы
		_fade_out(_sfx_res("res://assets/creepy_laugh.mp3", -5.0, 1.0, false, BUS_WORLD, 1.25), 0.8, 2.2)
	if _once("e_fade", b + E_FADE):
		_silence(1.2)
	if _once("e_end", b + E_END):
		_finish()

func _crash() -> void:
	_car_crashed = true
	_sfx("crash_impact", 3.0)
	_sfx("tinnitus", -13.0, 1.0, false, BUS_MASTER)
	_stop_sounds(["tire_screech", "gravel_skid", "creature_shriek", "sub_hit", "brake_squeal", "bone_crack"])
	_stop(engine_player)
	_stop(drone_player)
	engine_player = null
	drone_player = null
	VHSOverlay.glitch(1.0)

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	black_rect.color.a = 1.0
	flash_rect.color.a = 0.9
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.35)

	_wreck_pose()
	_trauma = 0.0

# Машина застыла носом в валуне: морда смята, капот вздут, левая фара разбита, правая мигает
func _wreck_pose() -> void:
	car.position = Vector3(SWERVE_X, 0.0, CAR_START_Z - _car_distance(T_CRASH))
	car.rotation = Vector3(deg_to_rad(-4.0), deg_to_rad(SWERVE_YAW_DEG), deg_to_rad(3.0))
	car_body.set_wrecked(true)
	car_body.set_lights(true)
	headlight_l.visible = false
	headlight_r.visible = true
	headlight_r.position = EthanCar.wreck_point(EthanCar.HEAD_R) + Vector3(0.0, 0.0, -0.05)
	deer_root.visible = false
	steam.emitting = true

func _fall() -> void:
	_sfx("body_fall", -7.0, 1.08)
	_trauma = 0.75
	dropped_light.visible = true
	heart_player = _sfx_res("res://assets/heart.mp3", -12.0, 1.12, true, BUS_MASTER)
	_fade_to(heart_player, -4.0, 3.0)
	VHSOverlay.set_fear(0.25)
	_blink(0.08)

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
	_silence(0.05)
	var scare := SkinwalkerScare.new()
	add_child(scare)
	scare.finished.connect(_on_scare_finished.bind(scare))

func _on_scare_finished(scare: Node) -> void:
	_epi_t0 = _t
	_set_black(1.0)
	if is_instance_valid(scare):
		scare.queue_free()
	VHSOverlay.set_fear(0.0)
	walker.visible = true
	ethan_body.visible = true
	cam04.visible = false

# Сразу финал: авария уже была, Итан лежит у камеры 04
func _start_epilogue_only() -> void:
	_epilogue_only = true
	_t = T_SCARE + 0.5
	_car_crashed = true
	_wreck_pose()
	dropped_light.visible = true
	_on_scare_finished(null)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if GameManager:
		GameManager.intro_cutscene_played = true
		GameManager.active_map_path = "res://scenes/1level.json" if _epilogue_only else "res://scenes/Шоссе.json"
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

# ──────────────────────────────────────────────────────────────────────────────
#  Движение машины: 20 м/с, торможение после сигнала, занос влево в валун
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

func _car_speed(t: float) -> float:
	if _car_crashed or t < T_DRIVE or t >= T_CRASH:
		return 0.0
	if t <= T_HORN:
		return CAR_SPEED
	if t <= T_HORN + BRAKE_TIME:
		return lerpf(CAR_SPEED, CAR_BRAKE_SPEED, (t - T_HORN) / BRAKE_TIME)
	return CAR_BRAKE_SPEED

func _car_swerve(t: float) -> float:
	return smoothstep(0.0, 1.0, clampf((t - T_SWERVE) / (T_CRASH - T_SWERVE), 0.0, 1.0))

func _update_car(delta: float) -> void:
	if _car_crashed:
		return
	var before := car.global_transform
	if station and _t < T_DRIVE:
		car.transform = _station_car_xform()
	else:
		var s := _car_swerve(_t)
		car.position = Vector3(SWERVE_X * s, 0.0, CAR_START_Z - _car_distance(_t))
		car.rotation = Vector3(0.0, deg_to_rad(SWERVE_YAW_DEG) * s, deg_to_rad(-3.0) * sin(s * PI))
	if delta <= 0.0:
		return
	# Колёса катятся по пройденному пути и поворачивают вслед за курсом (в заносе — за рулём)
	var moved := car.global_position - before.origin
	var speed := moved.dot(-car.global_transform.basis.z) / delta
	var yaw_rate := wrapf(car.rotation.y - before.basis.get_euler().y, -PI, PI) / delta
	var steer := clampf(rad_to_deg(yaw_rate) * 0.35, -28.0, 28.0)
	if _t >= T_SWERVE and _t < T_CRASH:
		steer = 10.0 * smoothstep(T_SWERVE, T_SWERVE + 0.3, _t) - 5.0 * smoothstep(T_SWERVE + 0.45, T_CRASH, _t)
	if moved.length() > 50.0:
		speed = 0.0       # прыжок между кадрами (заправка → шоссе), а не езда
	car_body.set_motion(delta, speed, steer)

func _in_flashback() -> bool:
	return _epi_t0 < 0.0 and _t >= T_FLASHBACK and _t < T_FLASHBACK + FLASHBACK_LEN

func _update_deer() -> void:
	var show := false
	var rear := 0.0
	var tilt := 0.0
	var eyes := false
	var pos := DEER_POS
	if _epi_t0 < 0.0:
		if _t < T_EJECT:
			show = true
			rear = smoothstep(T_RISE_TAPE, T_RISE_TAPE + 2.2, _t)
			tilt = smoothstep(T_TILT_TAPE, T_TILT_TAPE + 1.0, _t)
			eyes = _t >= T_EYES_TAPE
			if _t >= T_JUMP_TAPE:
				pos = DEER_JUMP_POS
		elif _t >= T_DEER_SEEN and _t < T_CRASH:
			show = true
			rear = smoothstep(T_REAR, T_REAR + 0.6, _t)
			tilt = smoothstep(T_REAR + 0.35, T_REAR + 0.9, _t)
			eyes = _t >= T_DEER_EYES
		elif _in_flashback():
			show = true
			rear = 1.0
			tilt = 1.0
			eyes = true
	deer_root.visible = show
	if not show:
		return
	# Пивот у копыт: силуэт откидывается назад, вытягивается вверх и склоняет «голову»
	deer_root.position = pos
	deer_root.rotation.z = deg_to_rad(-16.0) * rear + deg_to_rad(24.0) * tilt
	deer_root.scale = Vector3(1.0 - 0.15 * rear, 1.0 + 0.3 * rear, 1.0)
	deer_eyes.visible = eyes
	var big := 2.2 if (_t < T_EJECT or _in_flashback()) else 1.0
	for m in deer_eye_meshes:
		m.scale = Vector3.ONE * big

# ──────────────────────────────────────────────────────────────────────────────
#  Фонари, кабина, камера 04, тень, старик
# ──────────────────────────────────────────────────────────────────────────────
func _update_props(delta: float) -> void:
	# Вспышка памяти — это запись 14 октября: разбитой машины на ней ещё нет
	car.visible = _epi_t0 >= 0.0 or (_t >= T_EJECT and not _in_flashback())
	_update_lamps()
	cam04_led.visible = fmod(_t, 1.0) < 0.5
	if cam04_flash.light_energy > 0.0:
		cam04_flash.light_energy = maxf(0.0, cam04_flash.light_energy - delta * 7.0)
	if _car_crashed:
		var dim := sin(_t * 23.0) < -0.85
		headlight_r.light_energy = 0.8 if dim else 5.0
		car_body.set_right_lamp(0.5 if dim else 2.6)
	else:
		# У колонки фары гаснут вместе с мотором и загораются перед отъездом;
		# стоп-сигналы — когда тормозит к колонке и перед оленем
		var parked := _t >= T_GS_PARKED + 0.4 and _t < T_GS_LEAVE - 0.2
		var brake := 0.0
		if _t >= T_GS_ARRIVE + 1.2 and _t < T_GS_PARKED + 0.4:
			brake = 0.8
		elif _t >= T_BRAKE:
			brake = 1.0
		headlight_l.visible = not parked
		headlight_r.visible = not parked
		car_body.set_lights(not parked, brake)
	_update_station()
	hand_light.visible = _epi_t0 < 0.0 and _t >= T_TORCH_ON and _t < T_FALL and not _in_flashback()
	_update_cockpit(delta)
	_update_walker(delta)
	_update_drag_lights()

func _flicker(t: float) -> float:
	return 0.07 if sin(t * 13.0) * cos(t * 7.3) > 0.55 else 1.0

func _lamp_level(k: int) -> float:
	if _epi_t0 >= 0.0 or _t >= T_CRASH:
		if k == LAMP_FLICKER:
			if _t < T_WAKE - 0.5 or (_t >= T_HORN_STOP and _t < T_HORN_STOP + 1.2):
				return 0.0
			return _flicker(_t)
		return 0.0 if k >= 7 and k <= 12 else 1.0
	if _t < T_EJECT:
		return _flicker(_t + 3.0) if k == 9 else 1.0
	if LAMP_DIE.has(k):
		var die_t: float = LAMP_DIE[k]
		if _t >= die_t:
			return 0.0
		if _t >= die_t - 0.3:
			return 1.0 if fmod(_t * 31.0, 1.0) < 0.5 else 0.15
	return 1.0

func _update_lamps() -> void:
	for i in lamp_ks.size():
		var lvl := _lamp_level(lamp_ks[i])
		lamp_lights[i].visible = lvl > 0.01
		lamp_lights[i].light_energy = 2.1 * lvl
		lamp_mats[i].albedo_color = LAMP_OFF.lerp(LAMP_ON, lvl)

func _update_cockpit(delta: float) -> void:
	var speed := _car_speed(_t)
	var accel := (speed - _prev_speed) / delta if delta > 0.0 else 0.0
	_prev_speed = speed
	var shot := _shot()
	if (shot != "pov" and shot != "wake") or delta <= 0.0:
		return
	speed_needle.rotation.y = deg_to_rad(lerpf(120.0, -120.0, clampf(speed * 3.6 / 200.0, 0.0, 1.0)))
	var steer := 0.0
	if _t >= T_SWERVE:
		steer = deg_to_rad(150.0) * smoothstep(T_SWERVE, T_SWERVE + 0.3, _t) - deg_to_rad(70.0) * smoothstep(T_SWERVE + 0.45, T_CRASH, _t)
	wheel_spin.rotation.y = steer
	# Ёлочка под зеркалом: торможение бросает её вперёд, занос — вбок
	var lateral := 8.0 if (_t > T_SWERVE and _t < T_CRASH) else 0.0
	var force := Vector2(-accel, lateral) / 0.12
	_fresh_vel += (force - _fresh_ang * 82.0 - _fresh_vel * 1.6) * delta
	_fresh_vel = _fresh_vel.clamp(Vector2(-20.0, -20.0), Vector2(20.0, 20.0))
	_fresh_ang = (_fresh_ang + _fresh_vel * delta).clamp(Vector2(-1.0, -1.0), Vector2(1.0, 1.0))
	freshener.rotation = Vector3(_fresh_ang.x, 0.0, _fresh_ang.y)

func _update_walker(delta: float) -> void:
	if not walker.visible:
		return
	var e := _t - _epi_t0
	var u := clampf((e - E_FOOTAGE) / (E_STOP - E_FOOTAGE), 0.0, 1.0)
	var moving := e < E_STOP
	walker.global_position = WALKER_FROM.lerp(WALKER_TO, u)
	var dir := (WALKER_TO - WALKER_FROM).normalized()
	walker.rotation.y = atan2(dir.x, dir.z)
	walker.update_motion(delta, "stalk" if moving else "idle", 1.38 if moving else 0.0)
	if e >= E_LOOK:
		walker.set_look_target(CAM04_POS)
		var head := walker.get_head_position()
		walker_eyes.visible = true
		walker_eyes.global_position = head + (CAM04_POS - head).normalized() * 0.12
		walker_eyes.look_at(CAM04_POS, Vector3.UP)

func _update_drag_lights() -> void:
	var in_drag := _epi_t0 >= 0.0 and _t - _epi_t0 >= E_DRAG
	oldman.visible = in_drag
	gate_glow.visible = in_drag
	spark_light.visible = in_drag
	if not in_drag:
		return
	var s := _t - _spark_t0
	var energy := 0.0
	if _spark_t0 >= 0.0:
		if s < 0.12:
			energy = 9.0
		elif s >= 0.26 and s < 0.34:
			energy = 4.5
	spark_light.light_energy = energy
	gate_glow.light_energy = 0.25 + 0.35 * smoothstep(E_DRAG, E_GATE, _t - _epi_t0)

# ──────────────────────────────────────────────────────────────────────────────
#  Камера: запись 04 → погоня → кабина → после удара → обочина → волок
# ──────────────────────────────────────────────────────────────────────────────
func _shot() -> String:
	if _epi_t0 >= 0.0:
		return "footage" if _t - _epi_t0 < E_DRAG else "drag"
	if _t < T_EJECT:
		return "footage"
	if station and _t < T_DRIVE:
		if _t < T_GS_WINDOW:
			return "gs_arrive"
		if _t < T_GS_COUNTER:
			return "gs_window"
		if _t < T_GS_LEAVE:
			return "gs_counter"
		return "gs_leave"
	if _t < T_POV:
		return "chase"
	if _t < T_CRASH:
		return "pov"
	if _t < T_OUT:
		return "wake"
	if _t < T_WALK:
		return "outside"
	if _in_flashback():
		return "flash"
	if _t < T_FALL:
		return "walk"
	return "fallen"

func _update_camera(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - delta * 1.2)
	cam.attributes = null
	var shot := _shot()
	ir_light.visible = shot == "footage" or shot == "flash"
	match shot:
		"footage", "flash":
			_camera_footage()
		"gs_arrive":
			_camera_gs_arrive()
		"gs_window":
			_camera_gs_window()
		"gs_counter":
			_camera_gs_counter()
		"gs_leave":
			_camera_gs_leave()
		"chase":
			_camera_chase()
		"pov":
			_camera_pov()
		"wake":
			_camera_wake()
		"outside":
			_camera_outside()
		"walk":
			_camera_walk()
		"fallen":
			_camera_fallen()
		"drag":
			_camera_drag(_t - _epi_t0)
	if _trauma > 0.0:
		var m := _trauma * _trauma * 0.12
		cam.global_position += cam.global_transform.basis * Vector3(randf_range(-m, m), randf_range(-m, m), 0.0)

func _camera_footage() -> void:
	cam.fov = FOOTAGE_FOV
	cam.global_position = CAM04_POS + Vector3(0.0, 0.02, -0.22)
	cam.look_at(FOOTAGE_TARGET, Vector3.UP)

func _camera_chase() -> void:
	cam.fov = 62.0
	var sway := Vector3(sin(_t * 0.7) * 0.25, sin(_t * 1.1) * 0.08, 0.0)
	cam.global_position = car.global_position + Vector3(-0.8, 1.85, 5.6) + sway
	cam.look_at(car.global_position + Vector3(0.0, 0.8, -10.0), Vector3.UP)

func _camera_pov() -> void:
	cam.fov = 70.0
	var b := car.global_transform.basis
	cam.global_position = car.global_transform * EthanCar.EYE
	cam.look_at(cam.global_position - b.z * 20.0 + Vector3(0.0, -1.1, 0.0), Vector3.UP)
	var s := _car_swerve(_t)
	if s > 0.0:
		cam.rotate_object_local(Vector3.BACK, deg_to_rad(9.0) * sin(s * PI))
	# Резкое торможение: голову бросает вперёд
	var brake := smoothstep(T_BRAKE, T_BRAKE + 0.3, _t) * (1.0 - smoothstep(T_HORN + BRAKE_TIME, T_HORN + BRAKE_TIME + 0.4, _t))
	cam.rotate_object_local(Vector3.RIGHT, deg_to_rad(-3.5) * brake)

func _camera_wake() -> void:
	cam.fov = 64.0
	var xf := car.global_transform
	var lift := smoothstep(T_WAKE, T_WAKE + 2.6, _t)
	var belt := smoothstep(T_BELT - 0.3, T_BELT + 0.3, _t) * (1.0 - smoothstep(T_GLOVEBOX - 0.2, T_GLOVEBOX + 0.3, _t))
	var glove := smoothstep(T_GLOVEBOX - 0.2, T_GLOVEBOX + 0.3, _t)
	var eye := EthanCar.EYE
	cam.global_position = xf * Vector3(eye.x + 0.1 * glove, lerpf(eye.y - 0.16, eye.y, lift), lerpf(eye.z - 0.14, eye.z, lift))
	# Голова поднимается от руля к капоту в пару, потом — к замку ремня и бардачку
	var target := Vector3(-0.15, lerpf(0.45, 0.85, lift), -3.2)
	target = target.lerp(EthanCar.BUCKLE, belt)
	target = target.lerp(EthanCar.GLOVEBOX, glove)
	cam.look_at(xf * target, xf.basis.y)
	cam.rotate_object_local(Vector3.BACK, deg_to_rad(lerpf(14.0, 3.0, lift) + sin(_t * 0.8) * 1.5))
	# Сознание возвращается: картинка понемногу обретает резкость
	var focus := smoothstep(T_WAKE, T_WAKE + 3.2, _t)
	cam_attr.dof_blur_far_distance = lerpf(0.4, 30.0, focus)
	cam_attr.dof_blur_far_transition = lerpf(1.0, 10.0, focus)
	cam_attr.dof_blur_amount = lerpf(0.16, 0.02, focus)
	cam.attributes = cam_attr

func _camera_outside() -> void:
	cam.fov = 60.0
	var rise := smoothstep(T_OUT + 0.2, T_OUT + 1.8, _t)
	var pos := OUT_LOW.lerp(OUT_STAND, rise)
	pos += Vector3(sin(_t * 1.3) * 0.04, sin(_t * 2.1) * 0.02, 0.0) * (1.0 - 0.5 * rise)
	var target := Vector3(-8.1, 0.7, -248.0)                                            # смятая морда в валуне
	target = target.lerp(Vector3(1.5, 0.9, -240.0), smoothstep(T_ROAD_LOOK, T_ROAD_LOOK + 1.3, _t))   # пустая дорога
	target = target.lerp(Vector3(0.6, 0.15, -245.0), smoothstep(T_TORCH_ON + 0.2, T_TORCH_ON + 1.4, _t) * 0.6)
	target = target.lerp(Vector3(-17.0, 1.7, -236.0), smoothstep(T_VOICE + 0.2, T_VOICE + 1.3, _t))   # голос из леса
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	cam.rotate_object_local(Vector3.BACK, deg_to_rad(sin(_t * 0.9) * 3.0 * (1.0 - 0.6 * rise)))

func _camera_walk() -> void:
	var w := clampf((_t - T_WALK) / (T_FALL - T_WALK), 0.0, 1.0)
	var pos := OUT_STAND.lerp(WALK_END, w)
	var ph := (_t - T_WALK) * 6.2
	pos.y += absf(sin(ph)) * 0.05 - 0.025          # прихрамывает после удара
	pos.x += sin(ph * 0.5) * 0.03
	cam.global_position = pos
	var ahead := pos + Vector3(0.15, -0.3, 6.0)
	var forest := Vector3(-17.0, 1.7, -236.0)
	var target := forest.lerp(ahead, smoothstep(T_WALK, T_WALK + 0.9, _t))
	var focus := smoothstep(T_CAM04 - 0.3, T_CAM04 + 0.6, _t) * (1.0 - 0.35 * smoothstep(T_FALL - 0.6, T_FALL, _t))
	cam.look_at(target.lerp(CAM04_POS, focus), Vector3.UP)
	# Фонарик ловит «04»: взгляд цепляется за камеру брата
	var zoom := smoothstep(T_CAM04 - 0.2, T_CAM04 + 0.9, _t) * (1.0 - smoothstep(T_FLASHBACK + FLASHBACK_LEN, T_FALL - 0.1, _t))
	cam.fov = lerpf(66.0, 34.0, zoom)

func _camera_fallen() -> void:
	var f := smoothstep(T_FALL, T_FALL + 0.4, _t)
	var low := WALK_END.lerp(FALLEN_POS, f)
	var target := (WALK_END + Vector3(0.0, -0.8, 4.0)).lerp(FOREST_EYES_POS + Vector3(0.0, -0.3, 0.0), smoothstep(T_FALL + 0.3, T_FALL + 1.2, _t))
	if _t >= T_TURN:
		# Итан оборачивается: взгляд уходит из чащи назад, к дороге
		var to_eyes := FOREST_EYES_POS - low
		to_eyes.y = 0.0
		var back := to_eyes.normalized().rotated(Vector3.UP, PI * smoothstep(T_TURN, T_TURN + 0.55, _t))
		target = low + back * 8.0 + Vector3(0.0, 0.1, 0.0)
	cam.global_position = low + Vector3(0.0, sin(_t * 3.1) * 0.012, 0.0)
	cam.look_at(target, Vector3.UP)
	cam.rotate_object_local(Vector3.BACK, deg_to_rad(11.0) * f * (1.0 - 0.6 * smoothstep(T_WHISPER, T_WHISPER + 1.5, _t)))
	cam.fov = lerpf(60.0, 70.0, f)

func _drag_offset(e: float) -> float:
	# Каждый рывок тянет тело на 0.6 м к особняку
	var pulls := maxf(0.0, (e - E_DRAG) / DRAG_PERIOD)
	var k := floorf(pulls)
	return (k + smoothstep(0.0, 0.45, pulls - k)) * 0.6

func _camera_drag(e: float) -> void:
	var pos := DRAG_FROM + Vector3(-_drag_offset(minf(e, E_SLAM)), 0.0, 0.0)
	cam.fov = 68.0
	cam.global_position = pos + Vector3(0.0, sin(e * 5.3) * 0.01, 0.0)
	cam.look_at(pos + Vector3(-2.0, 3.3, 0.15), Vector3.UP)
	cam.rotate_object_local(Vector3.BACK, deg_to_rad(8.0 + sin(e * 1.1) * 4.0))
	# Старик идёт спиной вперёд и тянет за ноги; налобный фонарь качается в такт шагам
	var sway := sin(e * TAU / DRAG_PERIOD)
	oldman.global_position = pos + Vector3(-1.7, -0.32, sway * 0.08)
	headlamp.look_at(pos + Vector3(sway * 0.4, 0.0, sway * 0.3), Vector3.UP)

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
#  Шоссе: земля, асфальт, обочины, разметка и знак «Осторожно, олени»
# ──────────────────────────────────────────────────────────────────────────────
func _build_ground_and_road() -> void:
	var road_len := ROAD_START_Z - ROAD_END_Z
	var mid_z := (ROAD_START_Z + ROAD_END_Z) * 0.5

	var ground := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(240.0, road_len + 80.0)
	gm.material = _mat(Color(0.045, 0.052, 0.038), 0.96)
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

	var shoulder_mat := _mat(Color(0.11, 0.095, 0.075), 0.98)
	var marking_mat := _mat(Color(0.72, 0.76, 0.82), 0.82)
	for side in [-1.0, 1.0]:
		var shoulder := MeshInstance3D.new()
		var sm := PlaneMesh.new()
		sm.size = Vector2(1.8, road_len)
		sm.material = shoulder_mat
		shoulder.mesh = sm
		shoulder.position = Vector3(side * 4.9, 0.012, mid_z)
		add_child(shoulder)
		add_child(_box(Vector3(0.13, 0.025, road_len), Vector3(side * 3.7, 0.045, mid_z), marking_mat))

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

func _build_deer_sign() -> void:
	# Жёлтый ромб с оленем: машина проезжает его в первом кадре шоссе — сразу после правил
	var root := Node3D.new()
	root.name = "DeerCrossingSign"
	root.position = DEER_SIGN_POS
	add_child(root)
	var pole_mat := _mat(Color(0.35, 0.36, 0.38), 0.5)
	pole_mat.metallic = 0.6
	root.add_child(_box(Vector3(0.09, 2.2, 0.09), Vector3(0.0, 1.1, 0.0), pole_mat))
	var rim := _box(Vector3(1.08, 1.08, 0.025), Vector3(0.0, 2.15, 0.04), _mat(Color(0.05, 0.05, 0.05), 0.6))
	rim.rotation_degrees.z = 45.0
	root.add_child(rim)
	var plate_mat := _mat(Color(0.95, 0.72, 0.08), 0.35)
	var plate := _box(Vector3(1.0, 1.0, 0.03), Vector3(0.0, 2.15, 0.055), plate_mat)
	plate.rotation_degrees.z = 45.0
	root.add_child(plate)
	var tex := TextureHelper.get_texture("res://assets/textures/Olen.png")
	if tex:
		var s := Sprite3D.new()
		s.texture = tex
		s.pixel_size = 0.82 / tex.get_size().y
		s.modulate = Color(0.04, 0.035, 0.03)
		s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		s.position = Vector3(0.0, 2.12, 0.075)
		root.add_child(s)

# ──────────────────────────────────────────────────────────────────────────────
#  Фонари вдоль шоссе (через 30 м, попеременно слева и справа), каждый гаснет сам
# ──────────────────────────────────────────────────────────────────────────────
func _build_streetlights() -> void:
	var pole_mat := _mat(Color(0.13, 0.16, 0.21), 0.38)
	pole_mat.metallic = 0.72
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.18, 7.2, 0.18)
	pole_mesh.material = pole_mat
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(1.7, 0.16, 0.19)
	arm_mesh.material = pole_mat
	var bulb_mesh := BoxMesh.new()
	bulb_mesh.size = Vector3(0.48, 0.1, 0.35)

	for k in range(-3, 19):
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

		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = LAMP_ON
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

		lamp_ks.append(k)
		lamp_lights.append(pool)
		lamp_mats.append(mat)

# ──────────────────────────────────────────────────────────────────────────────
#  Сосновый лес по обеим сторонам шоссе (MultiMesh: стволы и ярусы крон)
# ──────────────────────────────────────────────────────────────────────────────
func _build_forest() -> void:
	# Те же ели, что на картах, участками по 30 м и дальше от дороги
	var rng := RandomNumberGenerator.new()
	rng.seed = 311994
	var chunks: Dictionary = {}
	var z := ROAD_START_Z
	while z > ROAD_END_Z:
		for side in [-1.0, 1.0]:
			for row in range(4):
				var x: float = side * (9.6 + row * 6.0 + rng.randf_range(-1.2, 1.5))
				var tz := z + rng.randf_range(-1.8, 1.8)
				if _in_clearing(x, tz):
					continue
				var h := rng.randf_range(8.5, 13.5)
				var big := h > 10.0
				var key := [int(floor(tz / 30.0)), side, big]
				if not chunks.has(key):
					chunks[key] = []
				chunks[key].append([Vector3(x, 0.0, tz), Vector3(h * 0.5, h, h * 0.5), rng.randf() * TAU])
		z -= 4.5
	for key in chunks:
		NatureKit.add_spruce_chunk(self, chunks[key], key[2], posmod(key[0], 3), Color.WHITE, 38.0, 220.0)
	# Ель у обочины, на которой Сэм закрепил камеру 04: голый ствол, чтобы лапы не закрывали камеру
	NatureKit.add_spruce_chunk(self, [[CAM04_PINE_POS + Vector3.UP * 2.6, Vector3(6.5, 13.0, 6.5), 0.6]], true, 0, Color.WHITE, 40.0, 220.0)
	var bare_mesh := CylinderMesh.new()
	bare_mesh.top_radius = 0.27
	bare_mesh.bottom_radius = 0.31
	bare_mesh.height = 3.4
	bare_mesh.radial_segments = 10
	bare_mesh.rings = 1
	bare_mesh.material = NatureKit._bark_mat()
	var bare := MeshInstance3D.new()
	bare.mesh = bare_mesh
	bare.position = CAM04_PINE_POS + Vector3.UP * 1.7
	add_child(bare)

func _in_clearing(x: float, z: float) -> bool:
	# Место аварии: путь заноса, валун, обочина до камеры 04
	if x < 0.0 and x > -12.5 and z < -228.0 and z > -258.0:
		return true
	# Полоса, по которой Итана тащат в лес
	return x < -17.0 and x > -24.5 and z < -237.3 and z > -240.7

# ──────────────────────────────────────────────────────────────────────────────
#  Место аварии и машина Итана (красный хэтчбек, она же разбита на картах «Шоссе» и 6)
# ──────────────────────────────────────────────────────────────────────────────
func _build_crash_site() -> void:
	# Валун у обочины — как CrashSiteRock на 2-м уровне
	var rock := PrefabBuilder.build_prefab("prop_rock_large", Vector3(4.2, 3.2, 4.0), Color(0.32, 0.30, 0.28), false)
	rock.position = ROCK_POS
	rock.rotation_degrees = Vector3(5.0, 24.0, -6.0)
	add_child(rock)

func _build_car() -> void:
	car = Node3D.new()
	car.name = "EthanCarRoot"
	add_child(car)

	# Красный хэтчбек Итана (scripts/EthanCar.gd): снаружи и изнутри — одна и та же машина,
	# вид от лица снимается из её настоящего салона
	car_body = EthanCar.new()
	car.add_child(car_body)
	hood = car_body.hood
	wheel_spin = car_body.wheel_spin
	speed_needle = car_body.speed_needle
	freshener = car_body.freshener

	headlight_l = _make_headlight(EthanCar.HEAD_L, true)
	headlight_r = _make_headlight(EthanCar.HEAD_R, false)

	steam = _build_steam()
	steam.position = EthanCar.STEAM_POINT
	car.add_child(steam)

func _make_headlight(at: Vector3, shadows: bool) -> SpotLight3D:
	var hl := SpotLight3D.new()
	hl.light_color = Color(1.0, 0.95, 0.82)
	hl.light_energy = 10.0
	hl.spot_range = 55.0
	hl.spot_angle = 30.0
	hl.spot_attenuation = 0.6
	hl.shadow_enabled = shadows
	hl.light_volumetric_fog_energy = 2.5
	hl.position = at + Vector3(0.0, 0.0, -0.06)
	hl.rotation_degrees.x = -4.0
	car.add_child(hl)
	return hl

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
#  Заправка, 21:40: магазин и кассирша из scripts/GasStation.gd, объявление о Сэме,
#  бутылки и карта на прилавке, путь «Гольфа» к колонке и обратно на шоссе
# ──────────────────────────────────────────────────────────────────────────────
func _build_station() -> void:
	station = GasStation.new()
	station.name = "GasStation"
	station.build_environment = false     # небо, туман и луна — общие с шоссе
	station.position = GS_ORIGIN
	add_child(station)
	_build_sam_poster()
	_build_counter_props()
	# К колонке: по своей полосе, плавно вправо через съезд, вдоль островка
	var arrive: Array = [Vector2(1.75, 36.0)]
	arrive.append_array(_bezier(Vector2(1.75, 18.0), Vector2(1.75, 9.0), Vector2(11.6, 8.0), Vector2(11.6, -3.4), 28))
	gs_arrive_path = _make_path(arrive)
	# Обратно: вперёд вдоль островка, через дальний съезд — на шоссе и в лес
	var leave: Array = _bezier(Vector2(11.6, -3.4), Vector2(11.6, -9.5), Vector2(1.75, -9.0), Vector2(1.75, -21.0), 28)
	leave.append(Vector2(1.75, -320.0))
	gs_leave_path = _make_path(leave)
	gs_attr = CameraAttributesPractical.new()
	gs_attr.dof_blur_amount = 0.09

# Свежее объявление среди старых пожелтевших «ПРОПАЛ»: Итан видит брата на стекле
func _build_sam_poster() -> void:
	var root := Node3D.new()
	root.name = "SamPoster"
	root.position = GS_POSTER
	root.rotation.x = 0.025
	station.add_child(root)
	root.add_child(_box(Vector3(0.006, 0.46, 0.34), Vector3.ZERO, _mat(Color(0.84, 0.84, 0.8), 0.9)))
	var tape_mat := _mat(Color(0.7, 0.68, 0.55), 0.5)
	for c in [Vector2(0.21, 0.15), Vector2(0.21, -0.15), Vector2(-0.21, 0.15), Vector2(-0.21, -0.15)]:
		root.add_child(_box(Vector3(0.007, 0.035, 0.06), Vector3(-0.0005, c.x, c.y), tape_mat))
	# Фото — ксерокопия: тёмный квадрат, светлая голова и плечи
	root.add_child(_box(Vector3(0.007, 0.17, 0.15), Vector3(-0.001, 0.03, 0.0), _mat(Color(0.07, 0.07, 0.07), 0.9)))
	var face := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	face.mesh = sm
	face.material_override = _mat(Color(0.38, 0.37, 0.34), 0.9)
	face.scale = Vector3(0.002, 0.07, 0.052)
	face.position = Vector3(-0.0045, 0.05, 0.0)
	root.add_child(face)
	root.add_child(_box(Vector3(0.002, 0.045, 0.12), Vector3(-0.0045, -0.025, 0.0), _mat(Color(0.3, 0.29, 0.27), 0.9)))
	var ink := Color(0.06, 0.04, 0.035)
	var at := GS_POSTER + Vector3(-0.006, 0.0, 0.0)
	station._text("ПРОПАЛ", at + Vector3(0.0, 0.175, 0.0), -PI * 0.5, 0.055, ink, 4)
	station._text("СЭМ КОУЛ", at + Vector3(0.0, -0.085, 0.0), -PI * 0.5, 0.034, ink, 2)
	station._text("с 14 октября 1994", at + Vector3(0.0, -0.125, 0.0), -PI * 0.5, 0.022, ink)
	station._text("шоссе через Блэк-Пайн", at + Vector3(0.0, -0.155, 0.0), -PI * 0.5, 0.019, ink)
	station._text("Видели его? Сообщите шерифу", at + Vector3(0.0, -0.19, 0.0), -PI * 0.5, 0.017, Color(0.35, 0.05, 0.04))

# Три бутылки газировки (из них потом и будут броски в игре) и карта с кругом посреди леса
func _build_counter_props() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.2, 0.46, 0.26, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.06
	glass.metallic_specular = 0.9
	var soda := _mat(Color(0.12, 0.05, 0.02), 0.3)
	var cap := _mat(Color(0.62, 0.6, 0.52), 0.35)
	cap.metallic = 0.8
	var paper := _mat(Color(0.78, 0.7, 0.46), 0.7)
	for i in 3:
		var b := Node3D.new()
		b.name = "Bottle%d" % i
		b.position = GS_BOTTLES[i]
		b.visible = false
		station.add_child(b)
		b.add_child(_cyl(0.026, 0.026, 0.12, Vector3(0.0, 0.07, 0.0), soda))
		b.add_child(_cyl(0.0305, 0.0305, 0.055, Vector3(0.0, 0.08, 0.0), paper))
		b.add_child(_cyl(0.03, 0.03, 0.17, Vector3(0.0, 0.085, 0.0), glass))
		b.add_child(_cyl(0.012, 0.03, 0.05, Vector3(0.0, 0.195, 0.0), glass))
		b.add_child(_cyl(0.012, 0.012, 0.045, Vector3(0.0, 0.24, 0.0), glass))
		b.add_child(_cyl(0.0135, 0.0135, 0.012, Vector3(0.0, 0.266, 0.0), cap))
		gs_bottles.append(b)
	gs_map = MeshInstance3D.new()
	gs_map.name = "EthanMap"
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.3, 0.42)
	var mm := StandardMaterial3D.new()
	mm.albedo_texture = _map_texture()
	mm.roughness = 0.95
	pm.material = mm
	gs_map.mesh = pm
	gs_map.position = GS_MAP_POS
	gs_map.rotation.y = 0.32
	gs_map.visible = false
	station.add_child(gs_map)

# Дорожная карта: бумага со сгибами, лес, шоссе через него и круг красной ручкой
func _map_texture() -> ImageTexture:
	var w := 192
	var h := 272
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var grain := FastNoiseLite.new()
	grain.frequency = 0.05
	var edge := FastNoiseLite.new()
	edge.seed = 7
	edge.frequency = 0.03
	var center := Vector2(w * 0.56, h * 0.47)
	for y in h:
		for x in w:
			var col := Color(0.8, 0.75, 0.6).darkened(0.07 * (grain.get_noise_2d(x, y) * 0.5 + 0.5))
			if Vector2(x, y).distance_to(center) + edge.get_noise_2d(x, y) * 26.0 < 78.0:
				col = col.lerp(Color(0.36, 0.5, 0.33), 0.72)
			img.set_pixel(x, y, col)
	for y in h:
		img.set_pixel(w / 2, y, img.get_pixel(w / 2, y).darkened(0.25))
	for x in w:
		for yy in [h / 3, h * 2 / 3]:
			img.set_pixel(x, yy, img.get_pixel(x, yy).darkened(0.22))
	# Шоссе снизу вверх через лес, просёлки в стороны
	for y in h:
		var rx := int(w * 0.43 + sin(y * 0.02) * 16.0)
		for k in range(-1, 2):
			img.set_pixel(clampi(rx + k, 0, w - 1), y, Color(0.6, 0.16, 0.1))
	for x in range(0, int(w * 0.43)):
		var ry := int(h * 0.8 + x * 0.12)
		img.set_pixel(x, clampi(ry, 0, h - 1), Color(0.35, 0.33, 0.3))
	# Круг ручкой посреди леса — туда, где Сэм ставил камеры
	for i in 360:
		var a := TAU * float(i) / 360.0
		var r := 22.0 + sin(a * 3.0) * 1.5
		for k in 2:
			var p := center + Vector2(cos(a), sin(a)) * (r + float(k))
			img.set_pixel(clampi(int(p.x), 0, w - 1), clampi(int(p.y), 0, h - 1), Color(0.72, 0.05, 0.04))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int) -> Array:
	var pts := []
	for i in n + 1:
		var u := float(i) / float(n)
		var v := 1.0 - u
		pts.append(p0 * v * v * v + p1 * 3.0 * v * v * u + p2 * 3.0 * v * u * u + p3 * u * u * u)
	return pts

func _make_path(pts: Array) -> Dictionary:
	var acc := PackedFloat32Array([0.0])
	for i in range(1, pts.size()):
		acc.append(acc[i - 1] + (pts[i] as Vector2).distance_to(pts[i - 1]))
	return {"pts": pts, "acc": acc, "len": acc[acc.size() - 1]}

func _path_pos(path: Dictionary, s: float) -> Vector2:
	var pts: Array = path["pts"]
	var acc: PackedFloat32Array = path["acc"]
	s = clampf(s, 0.0, path["len"])
	var i := acc.bsearch(s)
	if i <= 0:
		return pts[0]
	if i >= pts.size():
		return pts[pts.size() - 1]
	var seg := acc[i] - acc[i - 1]
	var u := (s - acc[i - 1]) / seg if seg > 0.0001 else 0.0
	return (pts[i - 1] as Vector2).lerp(pts[i], u)

# Машина смотрит вдоль -Z при повороте 0; курс — по соседним точкам пути
func _path_xform(path: Dictionary, s: float) -> Transform3D:
	var p := _path_pos(path, s)
	var d := _path_pos(path, s + 1.0) - _path_pos(path, s - 1.0)
	return Transform3D(Basis(Vector3.UP, atan2(-d.x, -d.y)), GS_ORIGIN + Vector3(p.x, 0.0, p.y))

func _station_car_xform() -> Transform3D:
	if _t < T_GS_LEAVE + GS_CAR_GO:
		# Тормозит всю дорогу от шоссе до колонки
		var u := clampf((_t - T_GS_ARRIVE + 0.5) / (T_GS_PARKED - T_GS_ARRIVE + 0.5), 0.0, 1.0)
		return _path_xform(gs_arrive_path, float(gs_arrive_path["len"]) * (1.0 - pow(1.0 - u, 2.0)))
	var e := _t - T_GS_LEAVE - GS_CAR_GO
	return _path_xform(gs_leave_path, 0.5 * GS_CAR_ACCEL * e * e)

func _update_station() -> void:
	if not station:
		return
	if _t >= T_DRIVE:
		if station.visible:
			station.visible = false
			station.process_mode = Node.PROCESS_MODE_DISABLED
		return
	# Куда смотрит кассирша: в журнал → на дверь (колокольчик) → на Итана и его карту → в окно → вслед машине
	var look: Vector3 = car.global_position + Vector3(0.0, 1.0, 0.0)
	if _t < T_GS_WINDOW + 1.95:
		look = GS_ORIGIN + GS_MAGAZINE
	elif _t < T_GS_COUNTER:
		look = GS_ORIGIN + GS_DOOR
	elif _t < T_GS_COUNTER + 0.9 or (_t >= T_GS_COUNTER + 2.0 and _t < T_GS_TAKE + 0.2):
		look = cam.global_position
	elif _t < T_GS_COUNTER + 2.0:
		look = GS_ORIGIN + GS_MAP_POS
	elif _t < T_GS_LEAVE:
		look = GS_ORIGIN + GS_WINDOW_DARK
	station.cashier.set_look_target(look)
	# Бутылки встают на прилавок по одной и уходят в рюкзак; карта выезжает из-под руки
	for i in gs_bottles.size():
		var put: float = T_GS_COUNTER + GS_BOTTLE_CLINK[i]
		gs_bottles[i].visible = _t >= put - 0.12 and _t < T_GS_TAKE + 0.08 + 0.12 * i
		gs_bottles[i].position = GS_BOTTLES[i] + Vector3(0.0, 0.06 * (1.0 - smoothstep(put - 0.12, put, _t)), 0.0)
	gs_map.visible = _t >= T_GS_COUNTER + 0.75 and _t < T_GS_TAKE + 0.55
	var slide := smoothstep(T_GS_COUNTER + 0.75, T_GS_COUNTER + 1.05, _t)
	gs_map.position = GS_MAP_POS + Vector3(-0.26, 0.0, 0.05) * (1.0 - slide)

# Кассирша говорит вполголоса: губы по буквам, звук фразы и субтитр
func _cashier_says(sound_name: String, line: String, speech: float) -> void:
	_sfx(sound_name, -6.0, 1.0, false, BUS_MASTER)
	if station:
		station.cashier.say(line, speech)
	_say(CASHIER, "«%s»" % line, speech + 0.25)

func _show_time_card() -> void:
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(time_card, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.4)
	tw.tween_property(time_card, "modulate:a", 0.0, 0.6)

func _camera_gs_arrive() -> void:
	cam.fov = 50.0
	var u := smoothstep(T_GS_ARRIVE, T_GS_WINDOW, _t)
	cam.global_position = GS_ORIGIN + GS_CAM_ARRIVE + Vector3(0.25 * u, sin(_t * 0.6) * 0.02, -0.5 * u)
	var follow := car.global_position + Vector3(0.0, 0.8, 0.0)
	cam.look_at(follow.lerp(GS_ORIGIN + Vector3(16.0, 2.0, -1.0), 0.35), Vector3.UP)

func _camera_gs_window() -> void:
	var e := _t - T_GS_WINDOW
	var pull := smoothstep(1.4, 2.3, e)
	cam.fov = 44.0
	cam.global_position = GS_ORIGIN + GS_CAM_WINDOW + Vector3(0.05 * e, 0.0, 0.0)
	cam.look_at((GS_ORIGIN + GS_POSTER).lerp(station.cashier.get_head_position(), pull), Vector3.UP)
	# Фокус: сначала лист на стекле, потом — кассирша за ним
	gs_attr.dof_blur_far_enabled = true
	gs_attr.dof_blur_far_distance = lerpf(1.3, 7.0, pull)
	gs_attr.dof_blur_far_transition = lerpf(1.2, 3.0, pull)
	gs_attr.dof_blur_near_enabled = pull > 0.02
	gs_attr.dof_blur_near_distance = lerpf(0.2, 2.4, pull)
	gs_attr.dof_blur_near_transition = 1.0
	cam.attributes = gs_attr

func _camera_gs_counter() -> void:
	var e := _t - T_GS_COUNTER
	var counter := GS_ORIGIN + Vector3(24.75, 1.0, 1.25)
	var look := counter.lerp(GS_ORIGIN + GS_MAP_POS, smoothstep(0.7, 1.3, e)).lerp(station.cashier.get_head_position(), smoothstep(1.8, 2.7, e))
	cam.global_position = GS_ORIGIN + GS_CAM_COUNTER + Vector3(sin(_t * 0.9) * 0.01, sin(_t * 1.3) * 0.008, sin(_t * 0.7) * 0.01)
	cam.look_at(look, Vector3.UP)
	cam.fov = lerpf(52.0, 40.0, smoothstep(T_GS_ASK, T_GS_TAKE, _t))

func _camera_gs_leave() -> void:
	# Камера почти стоит: машина проходит перед ней влево и тает на шоссе, а в светлом окне остаётся кассирша
	var e := _t - T_GS_LEAVE
	cam.fov = 46.0
	cam.global_position = GS_ORIGIN + GS_CAM_LEAVE + Vector3(0.0, sin(_t * 0.5) * 0.02, -0.12 * e)
	var store := GS_ORIGIN + Vector3(17.0, 1.6, -1.5)
	var follow := car.global_position + Vector3(0.0, 0.8, 0.0)
	cam.look_at(store.lerp(follow, 0.45 * smoothstep(0.3, 2.6, e)), Vector3.UP)

func _cyl(top_r: float, bottom_r: float, h: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = h
	cm.radial_segments = 16
	cm.rings = 1
	cm.material = mat
	mi.mesh = cm
	mi.position = pos
	return mi

# ──────────────────────────────────────────────────────────────────────────────
#  «Олень» на дороге (силуэт Olen.png), глаза загораются, когда он встаёт
# ──────────────────────────────────────────────────────────────────────────────
func _build_deer() -> void:
	deer_root = Node3D.new()
	deer_root.name = "Deer"
	deer_root.position = DEER_POS
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
		var eye := _make_eye(Vector3((p.x - half.x) * px, (half.y - p.y) * px, 0.03))
		deer_eyes.add_child(eye)
		deer_eye_meshes.append(eye)
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
	cam04 = Node3D.new()
	cam04.name = "ForestCamera04"
	cam04.position = CAM04_POS
	# Объектив смотрит вдоль шоссе — туда, где на записи стоял «олень»
	cam04.rotation_degrees.y = 90.0
	add_child(cam04)
	cam04.add_child(_box(Vector3(0.16, 0.34, 0.24), Vector3.ZERO, _mat(Color(0.16, 0.17, 0.14), 0.8)))
	var lens_mat := _mat(Color(0.04, 0.05, 0.07), 0.15)
	lens_mat.metallic = 0.6
	cam04.add_child(_box(Vector3(0.03, 0.08, 0.08), Vector3(0.09, 0.07, 0.0), lens_mat))

	var number := Label3D.new()
	number.text = "04"
	number.font_size = 40
	number.pixel_size = 0.005
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
	# ИК-вспышка: камера сработала на движение и сняла Итана
	cam04_flash = OmniLight3D.new()
	cam04_flash.light_color = Color(0.9, 0.06, 0.03)
	cam04_flash.light_energy = 0.0
	cam04_flash.omni_range = 3.5
	cam04_flash.position = Vector3(0.14, 0.0, 0.0)
	cam04.add_child(cam04_flash)
	# ИК-подсветка камеры: на записи дорога светлая, а «олень» — чёрный силуэт на ней
	ir_light = SpotLight3D.new()
	ir_light.light_color = Color(0.9, 0.95, 1.0)
	ir_light.light_energy = 7.0
	ir_light.spot_range = 36.0
	ir_light.spot_angle = 50.0
	ir_light.spot_attenuation = 0.8
	ir_light.shadow_enabled = true
	ir_light.light_volumetric_fog_energy = 0.6
	ir_light.visible = false
	add_child(ir_light)
	ir_light.position = CAM04_POS + Vector3(0.0, 0.1, -0.2)
	ir_light.look_at(Vector3(-6.5, 0.4, -246.0), Vector3.UP)

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
	var metal := _mat(Color(0.12, 0.13, 0.15), 0.3)
	metal.metallic = 0.8
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
	dropped_light.look_at(DROPPED_LIGHT_AIM, Vector3.UP)

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

# ──────────────────────────────────────────────────────────────────────────────
#  Эпилог: тело Итана, тень между соснами, старик с налобным фонарём, калитка
# ──────────────────────────────────────────────────────────────────────────────
func _build_epilogue_props() -> void:
	ethan_body = Node3D.new()
	ethan_body.name = "EthanBody"
	ethan_body.position = BODY_POS
	ethan_body.rotation_degrees.y = 25.0
	ethan_body.visible = false
	add_child(ethan_body)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.75
	cap.material = _mat(Color(0.08, 0.1, 0.16), 0.9)
	torso.mesh = cap
	torso.rotation_degrees.z = 90.0
	ethan_body.add_child(torso)
	ethan_body.add_child(_box(Vector3(0.44, 0.2, 0.34), Vector3(0.25, 0.05, 0.32), _mat(Color(0.12, 0.13, 0.1), 0.9)))

	walker = SkinwalkerModel.new()
	walker.name = "TallShadow"
	walker.position = WALKER_FROM
	walker.visible = false
	add_child(walker)
	walker_eyes = Node3D.new()
	walker_eyes.visible = false
	add_child(walker_eyes)
	for x in [-0.05, 0.05]:
		var e := _make_eye(Vector3(x, 0.0, 0.0))
		e.scale = Vector3.ONE * 1.3
		walker_eyes.add_child(e)
	var walker_glow := OmniLight3D.new()
	walker_glow.light_color = Color(1.0, 0.15, 0.08)
	walker_glow.light_energy = 1.6
	walker_glow.omni_range = 1.6
	walker_glow.position = Vector3(0.0, 0.0, -0.15)
	walker_eyes.add_child(walker_glow)

	# Старик: силуэт против неба и налобный фонарь, бьющий Итану в лицо
	oldman = Node3D.new()
	oldman.name = "OldMan"
	oldman.visible = false
	add_child(oldman)
	var coat := MeshInstance3D.new()
	var coat_mesh := CapsuleMesh.new()
	coat_mesh.radius = 0.26
	coat_mesh.height = 1.7
	coat_mesh.material = _mat(Color(0.04, 0.04, 0.045), 0.95)
	coat.mesh = coat_mesh
	coat.position = Vector3(0.0, 0.85, 0.0)
	oldman.add_child(coat)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.12
	head_mesh.height = 0.24
	head_mesh.material = coat_mesh.material
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.78, 0.0)
	oldman.add_child(head)
	headlamp = SpotLight3D.new()
	headlamp.position = Vector3(0.12, 1.84, 0.0)
	headlamp.light_color = Color(1.0, 0.85, 0.18)
	headlamp.light_energy = 3.0
	headlamp.spot_range = 9.0
	headlamp.spot_angle = 36.0
	headlamp.light_volumetric_fog_energy = 2.0
	oldman.add_child(headlamp)
	var bulb := MeshInstance3D.new()
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.035
	bulb_mesh.height = 0.07
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(1.0, 0.9, 0.5)
	bulb_mesh.material = bulb_mat
	bulb.mesh = bulb_mesh
	bulb.position = headlamp.position
	oldman.add_child(bulb)
	var lamp_glow := OmniLight3D.new()
	lamp_glow.light_color = Color(1.0, 0.82, 0.18)
	lamp_glow.light_energy = 0.9
	lamp_glow.omni_range = 2.4
	lamp_glow.position = headlamp.position
	oldman.add_child(lamp_glow)

	# Электрическая калитка особняка: синие искры за деревьями
	spark_light = OmniLight3D.new()
	spark_light.position = DRAG_FROM + Vector3(-8.0, 2.2, 0.5)
	spark_light.light_color = Color(0.45, 0.65, 1.0)
	spark_light.omni_range = 14.0
	spark_light.light_energy = 0.0
	spark_light.visible = false
	add_child(spark_light)
	gate_glow = OmniLight3D.new()
	gate_glow.position = DRAG_FROM + Vector3(-9.0, 1.6, 0.0)
	gate_glow.light_color = Color(0.4, 0.55, 1.0)
	gate_glow.omni_range = 9.0
	gate_glow.light_energy = 0.25
	gate_glow.visible = false
	add_child(gate_glow)

# ──────────────────────────────────────────────────────────────────────────────
#  Камера, фонарик в руке, расфокус после удара
# ──────────────────────────────────────────────────────────────────────────────
func _setup_camera() -> void:
	cam = Camera3D.new()
	cam.name = "IntroCamera"
	cam.fov = 62.0
	cam.near = 0.05
	cam.far = 400.0
	cam.current = true
	add_child(cam)

	cam_attr = CameraAttributesPractical.new()
	cam_attr.dof_blur_far_enabled = true
	cam_attr.dof_blur_far_distance = 0.4
	cam_attr.dof_blur_far_transition = 1.0
	cam_attr.dof_blur_amount = 0.16

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
#  Экран: запись камеры 04, трещины и кровь, полосы кадра, дата, субтитры
# ──────────────────────────────────────────────────────────────────────────────
func _build_overlay() -> void:
	var foot_layer := CanvasLayer.new()
	foot_layer.name = "Footage04"
	foot_layer.layer = 30
	add_child(foot_layer)
	footage_mat = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FOOTAGE_SHADER
	footage_mat.shader = shader
	footage_rect = ColorRect.new()
	footage_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	footage_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footage_rect.material = footage_mat
	foot_layer.add_child(footage_rect)

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

	# Разбитое лобовое стекло и кровь со лба — только в кабине после удара
	crack = CrackOverlay.new()
	crack.set_anchors_preset(Control.PRESET_FULL_RECT)
	crack.visible = false
	layer.add_child(crack)
	var g := Gradient.new()
	g.set_color(0, Color(0.42, 0.0, 0.0, 0.85))
	g.set_color(1, Color(0.3, 0.0, 0.0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.0, 0.0)
	gt.fill_to = Vector2(0.62, 0.55)
	gt.width = 256
	gt.height = 256
	blood = TextureRect.new()
	blood.texture = gt
	blood.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blood.stretch_mode = TextureRect.STRETCH_SCALE
	blood.visible = false
	layer.add_child(blood)
	blood_drip = ColorRect.new()
	blood_drip.color = Color(0.3, 0.0, 0.0, 0.8)
	blood_drip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_drip.anchor_left = 0.11
	blood_drip.anchor_right = 0.114
	blood_drip.anchor_top = 0.0
	blood_drip.anchor_bottom = 0.02
	blood_drip.visible = false
	layer.add_child(blood_drip)

	# Надписи записи: REC, номер камеры, дата и время
	rec_box = Control.new()
	rec_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	rec_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rec_box.visible = false
	layer.add_child(rec_box)
	var tape_col := Color(0.92, 0.94, 0.9)
	rec_dot = _corner_label("● REC", Color(1.0, 0.26, 0.2), 0.05, 0.05, 0.4, HORIZONTAL_ALIGNMENT_LEFT)
	rec_box.add_child(rec_dot)
	rec_box.add_child(_corner_label("ЛЕСНАЯ КАМЕРА 04", tape_col, 0.5, 0.05, 0.95, HORIZONTAL_ALIGNMENT_RIGHT))
	date_label = _corner_label("14.10.1994", tape_col, 0.05, 0.88, 0.5, HORIZONTAL_ALIGNMENT_LEFT)
	rec_box.add_child(date_label)
	time_label = _corner_label("02:13:07", tape_col, 0.5, 0.88, 0.95, HORIZONTAL_ALIGNMENT_RIGHT)
	rec_box.add_child(time_label)

	# Кинематографичные чёрные полосы сверху и снизу
	for is_top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if is_top else 0.9
		bar.anchor_bottom = 0.1 if is_top else 1.0
		layer.add_child(bar)
		bars.append(bar)

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
	var date_title := _make_label("31 ОКТЯБРЯ 1994", 42, Color(0.92, 0.93, 0.95))
	date_title.add_theme_font_override("font", VHSOverlay.tracked_font(6))
	title_box.add_child(date_title)
	title_place = _make_label("Последняя заправка перед лесом Блэк-Пайн · 21:40", 18, Color(0.62, 0.66, 0.74))
	title_box.add_child(title_place)
	layer.add_child(title_box)

	# Подпись времени поверх кадра шоссе: прошло полтора часа
	time_card = _make_label("23:06 · Шоссе через лес Блэк-Пайн", 18, Color(0.74, 0.77, 0.84))
	time_card.add_theme_font_override("font", VHSOverlay.tracked_font(3))
	time_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	time_card.anchor_left = 0.06
	time_card.anchor_right = 0.7
	time_card.anchor_top = 0.11
	time_card.anchor_bottom = 0.17
	time_card.modulate.a = 0.0
	layer.add_child(time_card)

	# Тёмная подложка: шёпот Сэма должен читаться поверх белого шума
	sub_back = ColorRect.new()
	sub_back.color = Color(0.0, 0.0, 0.0, 0.72)
	sub_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub_back.anchor_left = 0.06
	sub_back.anchor_right = 0.94
	sub_back.anchor_top = 0.73
	sub_back.anchor_bottom = 0.9
	sub_back.modulate.a = 0.0
	layer.add_child(sub_back)

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

func _update_overlay() -> void:
	var shot := _shot()
	var amount := 1.0 if shot == "footage" or shot == "flash" else 0.0
	var st := 0.0
	if _epi_t0 < 0.0:
		if _t >= T_STATIC and _t < T_EJECT:
			st = 1.0
		elif _t < _static_blip_until:
			st = 0.6
		elif shot == "flash":
			st = 0.3 + 0.25 * sin(_t * 90.0)
	elif _t - _epi_t0 >= E_STATIC and _t - _epi_t0 < E_DRAG:
		st = 1.0
	footage_rect.visible = amount > 0.0 or st > 0.0
	footage_mat.set_shader_parameter("amount", amount)
	footage_mat.set_shader_parameter("static_amt", st)
	footage_mat.set_shader_parameter("time_s", _t)
	rec_box.visible = amount > 0.0 and st < 0.9
	sub_back.modulate.a = sub_box.modulate.a if st >= 0.9 else 0.0
	for b in bars:
		b.visible = amount == 0.0 and st == 0.0
	if rec_box.visible:
		rec_dot.modulate.a = 1.0 if fmod(_t, 1.0) < 0.6 else 0.15
		var epi := _epi_t0 >= 0.0
		date_label.text = "31.10.1994" if epi else "14.10.1994"
		var secs := (_t - _epi_t0 + 84104.0) if epi else (_t + 7987.0)    # 23:21:44 и 02:13:07
		time_label.text = "%02d:%02d:%02d" % [int(secs / 3600.0) % 24, int(secs / 60.0) % 60, int(secs) % 60]

	var in_cab := _epi_t0 < 0.0 and _t >= T_WAKE - 0.1 and _t < T_DOOR + 0.1
	crack.visible = in_cab
	blood.visible = in_cab
	blood_drip.visible = in_cab
	if in_cab:
		var beat := pow(maxf(0.0, sin(_t * TAU * 1.15)), 8.0)
		blood.modulate.a = 0.6 + 0.3 * beat
		blood_drip.anchor_bottom = lerpf(0.02, 0.34, smoothstep(T_WAKE, T_DOOR, _t))

func _corner_label(text: String, color: Color, left: float, top: float, right: float, align: HorizontalAlignment) -> Label:
	var l := _make_label(text, 22, color)
	l.add_theme_font_override("font", VHSOverlay.tracked_font(3))
	l.horizontal_alignment = align
	l.anchor_left = left
	l.anchor_right = right
	l.anchor_top = top
	l.anchor_bottom = top + 0.06
	return l

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

func _set_black(alpha: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	black_rect.color.a = alpha

# Моргание: веки на миг смыкаются
func _blink(hold: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(black_rect, "color:a", 1.0, 0.07)
	_fade_tween.tween_interval(hold)
	_fade_tween.tween_property(black_rect, "color:a", 0.0, 0.16)

# Проблеск сознания посреди темноты
func _glimpse(hold: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(black_rect, "color:a", 0.0, 0.35)
	_fade_tween.tween_interval(hold)
	_fade_tween.tween_property(black_rect, "color:a", 1.0, 0.45)

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

func _box(box_size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = box_size
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	return mi

# Брусок от точки a до точки b (стойки кабины, крыша)
func _beam(a: Vector3, b: Vector3, thickness: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(thickness, thickness, a.distance_to(b))
	bm.material = mat
	mi.mesh = bm
	mi.transform = Transform3D(Basis.looking_at(b - a, Vector3.UP), (a + b) * 0.5)
	return mi

# ──────────────────────────────────────────────────────────────────────────────
#  Звук: свои шины (заглушение после удара, отражения леса, плёнка, шёпот слева)
# ──────────────────────────────────────────────────────────────────────────────
func _setup_audio_buses() -> void:
	_remove_audio_buses()
	var world := _add_bus(BUS_WORLD, BUS_MASTER)
	muffle = AudioEffectLowPassFilter.new()
	muffle.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(world, muffle)
	AudioServer.set_bus_effect_enabled(world, 0, false)
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = -0.8
	AudioServer.add_bus_effect(world, limiter)

	var verb := _add_bus(BUS_VERB, BUS_WORLD)
	var rv := AudioEffectReverb.new()
	rv.room_size = 0.8
	rv.damping = 0.6
	rv.wet = 0.4
	rv.dry = 0.7
	rv.predelay_msec = 50.0
	rv.hipass = 0.1
	AudioServer.add_bus_effect(verb, rv)

	var tape := _add_bus(BUS_TAPE, BUS_MASTER)
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 300.0
	AudioServer.add_bus_effect(tape, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 3600.0
	AudioServer.add_bus_effect(tape, lp)

	var near := _add_bus(BUS_NEAR, BUS_MASTER)
	var pan := AudioEffectPanner.new()
	pan.pan = -0.55
	AudioServer.add_bus_effect(near, pan)

func _add_bus(bus_name: String, send: String) -> int:
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, send)
	return idx

func _remove_audio_buses() -> void:
	for bus_name in [BUS_NEAR, BUS_TAPE, BUS_VERB, BUS_WORLD]:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx > 0:
			AudioServer.remove_bus(idx)

# Звон в ушах: мир снаружи глохнет, потом медленно возвращается
func _set_muffle(cutoff: float, duration: float) -> void:
	var idx := AudioServer.get_bus_index(BUS_WORLD)
	if idx == -1 or not muffle:
		return
	var closing := cutoff < 19000.0
	if closing:
		AudioServer.set_bus_effect_enabled(idx, 0, true)
	var tw := create_tween()
	tw.tween_property(muffle, "cutoff_hz", cutoff, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT if closing else Tween.EASE_IN)
	if not closing:
		tw.tween_callback(func() -> void:
			var i := AudioServer.get_bus_index(BUS_WORLD)
			if i != -1:
				AudioServer.set_bus_effect_enabled(i, 0, false))

func _sfx(sound_name: String, db: float = 0.0, pitch: float = 1.0, loop: bool = false, bus: String = BUS_WORLD) -> AudioStreamPlayer:
	return _sfx_res(SND + sound_name + ".wav", db, pitch, loop, bus)

func _sfx_res(path: String, db: float = 0.0, pitch: float = 1.0, loop: bool = false, bus: String = BUS_WORLD, from: float = 0.0) -> AudioStreamPlayer:
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	if loop:
		stream = _looped(stream)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = bus if AudioServer.get_bus_index(bus) != -1 else BUS_MASTER
	add_child(p)
	if not loop:
		p.finished.connect(p.queue_free)
	p.play(from)
	return p

# Короткий кусок петли (вспышка помех)
func _sfx_for(sound_name: String, db: float, duration: float, bus: String = BUS_WORLD) -> void:
	_fade_out(_sfx(sound_name, db, 1.0, true, bus), 0.05, duration)

# Петля без щелчка на стыке: повтор внутри самого потока
func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav = wav.duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
		return wav
	if stream is AudioStreamMP3:
		var mp3 := (stream as AudioStreamMP3).duplicate() as AudioStreamMP3
		mp3.loop = true
		return mp3
	return stream

func _fade_to(p: AudioStreamPlayer, db: float, duration: float) -> void:
	if is_instance_valid(p):
		create_tween().tween_property(p, "volume_db", db, duration)

func _fade_out(p: AudioStreamPlayer, fade: float, delay: float = 0.0) -> void:
	if not is_instance_valid(p):
		return
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)

func _stop(p: AudioStreamPlayer) -> void:
	if is_instance_valid(p):
		p.stop()
		p.queue_free()

func _stop_sounds(names: Array) -> void:
	for c in get_children():
		if c is AudioStreamPlayer and c.stream:
			for n in names:
				if c.stream.resource_path.ends_with("/" + str(n) + ".wav"):
					_stop(c)

# Всё стихает: перед скримером тишина должна быть полной
func _silence(fade: float) -> void:
	for c in get_children():
		if c is AudioStreamPlayer:
			_fade_out(c, fade)
	engine_player = null
	radio_player = null
	drone_player = null
	horn_loop = null
	steam_player = null
	tick_player = null
	crickets_player = null
	wind_player = null
	heart_player = null
	hum_player = null
	wheeze_player = null
	static_player = null
	tape_players.clear()

# ──────────────────────────────────────────────────────────────────────────────
#  Трещины на лобовом стекле: паутина вокруг точки удара
# ──────────────────────────────────────────────────────────────────────────────
class CrackOverlay extends Control:
	var center := Vector2(0.64, 0.34)
	var lines: Array = []    # [точки в долях высоты экрана от центра, толщина, прозрачность]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 1031
		var radial: Array = []
		var count := 14
		for i in count:
			var a := TAU * i / count + rng.randf_range(-0.18, 0.18)
			var length := rng.randf_range(0.18, 0.62)
			var pts := PackedVector2Array([Vector2.ZERO])
			var p := Vector2.ZERO
			var travelled := 0.0
			while travelled < length:
				var step := rng.randf_range(0.025, 0.06)
				a += rng.randf_range(-0.22, 0.22)
				p += Vector2(cos(a), sin(a)) * step
				pts.append(p)
				travelled += step
			radial.append(pts)
			lines.append([pts, rng.randf_range(1.2, 2.0), rng.randf_range(0.35, 0.55)])
		for r in [0.045, 0.1, 0.19]:
			for i in count:
				var pa = _point_at(radial[i], r)
				var pb = _point_at(radial[(i + 1) % count], r * rng.randf_range(0.85, 1.15))
				if pa != null and pb != null:
					var mid: Vector2 = (pa + pb) * 0.5 + Vector2(rng.randf_range(-0.01, 0.01), rng.randf_range(-0.01, 0.01))
					lines.append([PackedVector2Array([pa, mid, pb]), 1.0, rng.randf_range(0.25, 0.4)])
		for i in 10:
			var a := rng.randf() * TAU
			var p0 := Vector2(cos(a), sin(a)) * rng.randf_range(0.0, 0.02)
			lines.append([PackedVector2Array([p0, p0 + Vector2(cos(a + 1.7), sin(a + 1.7)) * rng.randf_range(0.01, 0.03)]), 1.0, 0.5])

	func _point_at(pts: PackedVector2Array, r: float) -> Variant:
		for p in pts:
			if p.length() >= r:
				return p
		return null

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		var h := size.y
		var c := Vector2(size.x * center.x, size.y * center.y)
		for l in lines:
			var src: PackedVector2Array = l[0]
			var pts := PackedVector2Array()
			for p in src:
				pts.append(c + p * h)
			draw_polyline(pts, Color(0.9, 0.93, 1.0, l[2]), l[1], true)
