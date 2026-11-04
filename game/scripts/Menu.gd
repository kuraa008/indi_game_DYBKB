extends Node3D

const TextureHelper = preload("res://scripts/TextureHelper.gd")

# При каждом выпуске новой сборки увеличить GAME_BUILD и число в файле VERSION
const GAME_BUILD: int = 8
const VERSION_URL: String = "https://raw.githubusercontent.com/kuraa008/indi_game_DYBKB/main/VERSION"
const DOWNLOAD_URL: String = "https://github.com/kuraa008/indi_game_DYBKB/raw/main/game/release.zip"

# ══════════════════════════════════════════════════════════════════════════════
#  Menu.gd — Главное меню: ночная дорога в тумане на старой кассете
#  • Камера низко над пустой дорогой, впереди один фонарь и фигура
#  • При сбоях плёнки фигура оказывается в другом месте
#  • Слева список пунктов, настройки меняются стрелками или мышью
# ══════════════════════════════════════════════════════════════════════════════

# Аудио
var menu_music_player:        AudioStreamPlayer
var sfx_hover:                AudioStreamPlayer
var sfx_select:               AudioStreamPlayer
var heartbeat_audio:          AudioStreamPlayer
var figure_audio:             AudioStreamPlayer

# 3D Камера
var menu_camera:              Camera3D
var cam_base_pos:             Vector3 = Vector3(-0.12, 1.0, 0.0)
var cam_base_yaw:             float = 0.0
var cam_yaw:                  float = 0.0
var cam_pitch:                float = 0.05
var cam_pan:                  float = 0.0
var is_rmb_dragging:          bool = false
var cam_trauma:               float = 0.0

# Окружение
var world_env_node:           WorldEnvironment
var world_env:                Environment
var moon_light:               DirectionalLight3D
var lamp_light:               SpotLight3D = null
var lamp_glow:                MeshInstance3D = null

# Фигура на дороге
var figure_model:             SkinwalkerModel = null
var figure_timer:             float = 14.0
var figure_spot:              int = 0
var figure_spots: Array[Vector3] = [
	Vector3( 0.15, 0.0, -30.0),
	Vector3(-2.40, 0.0, -33.0),
	Vector3( 1.30, 0.0, -25.0),
	Vector3( 3.60, 0.0, -36.0),
	Vector3(-0.60, 0.0, -21.0),
]

# Скример при взгляде назад
var jumpscare_flash:          ColorRect = null
var is_jumpscare_active:      bool = false
var can_trigger_jumpscare:    bool = true
var jumpscare_cooldown:       float = 0.0

# UI элементы
const COLOR_DIM    := Color(0.46, 0.47, 0.45)
const COLOR_VALUE  := Color(0.72, 0.73, 0.70)
const COLOR_BRIGHT := Color(0.90, 0.91, 0.88)
const COLOR_FAINT  := Color(0.33, 0.34, 0.32)
const COLOR_ACCENT := Color(1.0, 0.07, 0.05)

var selected_index:           int = 0
var ui_root:                  Control
var main_screen:              Control
var settings_screen:          Control
var item_labels:              Array[Label] = []
var item_bars:                Array[ColorRect] = []

# Настройки
var is_modal_open:            bool = false
var settings_index:           int = 0
var setting_labels:           Array[Label] = []
var setting_values:           Array[Label] = []
var setting_bars:             Array[ColorRect] = []
var sound_segments:           Array[ColorRect] = []
var setting_desc:             Label = null

var elapsed_time:             float = 0.0

const MENU_OPTIONS = [
	"ИГРАТЬ",
	"НАСТРОЙКИ",
	"ВЫХОД"
]

const SETTINGS_ROWS = [
	{"id": "sound",  "title": "ЗВУК",             "desc": "Общая громкость игры."},
	{"id": "sens",   "title": "ЧУВСТВИТЕЛЬНОСТЬ", "desc": "Как быстро поворачивается камера от движения мыши."},
	{"id": "gfx",    "title": "ГРАФИКА",          "desc": "Если игра тормозит, поставь значение ниже."},
	{"id": "vhs",    "title": "VHS",              "desc": "Эффект старой кассеты: помехи, шум и строки на экране."},
	{"id": "dyn",    "title": "АВТО-КАЧЕСТВО",    "desc": "При просадке FPS картинка рисуется мельче, а интерфейс остаётся чётким."},
	{"id": "res",    "title": "РАЗРЕШЕНИЕ",       "desc": "АВТО — на весь экран. Остальные значения открывают игру в окне."},
	{"id": "models", "title": "МОДЕЛИ",           "desc": "РЕАЛИЗМ — текущие модели. РЕТРО — простые, как в ранней версии."},
]

const SOUND_BAR_X := 34.0
const SOUND_SEGMENT_W := 15.0
const SOUND_SEGMENT_GAP := 2.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_environment()
	_setup_camera()
	_build_road_scene()
	_setup_figure()
	_setup_jumpscare_system()
	_setup_audio()
	_build_ui()
	_update_selection(0, false)
	VHSOverlay.set_fear(0.0)
	VHSOverlay.glitch(0.8)
	_setup_update_check()

# ──────────────────────────────────────────────────────────────────────────────
#  Проверка обновлений: номер сборки сравнивается с файлом VERSION на GitHub
# ──────────────────────────────────────────────────────────────────────────────
func _setup_update_check() -> void:
	var build_lbl = Label.new()
	build_lbl.name = "BuildLabel"
	build_lbl.text = "сборка %d" % GAME_BUILD
	build_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	build_lbl.offset_left = -150.0
	build_lbl.offset_top = -40.0
	build_lbl.offset_right = -24.0
	build_lbl.offset_bottom = -14.0
	build_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_lbl.add_theme_font_size_override("font_size", 13)
	build_lbl.add_theme_color_override("font_color", COLOR_FAINT)
	ui_root.add_child(build_lbl)

	var request = HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(_on_update_check_completed.bind(request))
	# Без интернета кнопка просто не появится, игра работает как обычно
	if request.request(VERSION_URL) != OK:
		request.queue_free()

func _on_update_check_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest) -> void:
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var latest_text = body.get_string_from_utf8().strip_edges()
	if not latest_text.is_valid_int() or latest_text.to_int() <= GAME_BUILD:
		return
	var update_btn = Button.new()
	update_btn.name = "UpdateButton"
	update_btn.text = "Вышло обновление — скачать сборку %s" % latest_text
	update_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	update_btn.offset_left = -400.0
	update_btn.offset_top = 28.0
	update_btn.offset_right = -28.0
	update_btn.offset_bottom = 72.0
	update_btn.pressed.connect(func(): OS.shell_open(DOWNLOAD_URL))
	ui_root.add_child(update_btn)

# ──────────────────────────────────────────────────────────────────────────────
#  1. Окружение и туман
# ──────────────────────────────────────────────────────────────────────────────
func _setup_environment() -> void:
	world_env_node = WorldEnvironment.new()
	world_env = Environment.new()
	world_env.background_mode = Environment.BG_COLOR
	world_env.background_color = Color(0.205, 0.225, 0.192)

	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color(0.36, 0.42, 0.34)
	world_env.ambient_light_energy = 0.30

	world_env.fog_enabled = true
	world_env.fog_light_color = Color(0.205, 0.225, 0.192)
	world_env.fog_density = 0.034
	world_env.fog_sky_affect = 1.0

	moon_light = DirectionalLight3D.new()
	moon_light.name = "NightFill"
	moon_light.rotation_degrees = Vector3(-52, 25, 0)
	moon_light.light_color = Color(0.70, 0.82, 0.68)
	moon_light.light_energy = 0.05
	add_child(moon_light)

	# Рассеянный свет на ближнем участке дороги, чтобы был виден асфальт
	var road_fill = SpotLight3D.new()
	road_fill.name = "RoadFill"
	road_fill.position = Vector3(0.0, 5.0, 2.0)
	road_fill.rotation_degrees.x = -28.0
	road_fill.light_color = Color(0.72, 0.80, 0.68)
	road_fill.light_energy = 1.8
	road_fill.spot_range = 34.0
	road_fill.spot_angle = 48.0
	road_fill.spot_attenuation = 1.2
	road_fill.light_volumetric_fog_energy = 0.0
	add_child(road_fill)

	_apply_menu_graphics(GameManager.graphics_quality)

	world_env_node.environment = world_env
	add_child(world_env_node)

func _apply_menu_graphics(quality: String) -> void:
	if not world_env:
		return
	var high = quality in ["ultra", "high"]
	world_env.ssao_enabled = quality != "low"
	world_env.ssao_radius = 0.75
	world_env.ssao_intensity = 1.05
	world_env.ssil_enabled = false
	world_env.ssr_enabled = high
	world_env.glow_enabled = quality != "low"
	world_env.glow_bloom = 0.05
	world_env.glow_intensity = 0.7
	world_env.glow_hdr_threshold = 0.9
	world_env.sdfgi_enabled = false
	world_env.volumetric_fog_enabled = high
	world_env.volumetric_fog_density = 0.012
	world_env.volumetric_fog_albedo = Color(0.55, 0.62, 0.52)
	world_env.volumetric_fog_anisotropy = 0.35
	world_env.volumetric_fog_temporal_reprojection_enabled = true
	world_env.tonemap_mode = Environment.TONE_MAPPER_ACES if quality != "low" else Environment.TONE_MAPPER_LINEAR
	world_env.tonemap_exposure = 1.0
	world_env.tonemap_white = 6.0
	world_env.adjustment_enabled = false
	if lamp_light:
		lamp_light.shadow_enabled = quality != "low"

	# Без объёмного тумана и ACES тот же цвет выглядит светлее
	var haze = Color(0.205, 0.225, 0.192)
	if quality == "medium":
		haze = Color(0.135, 0.150, 0.126)
	elif quality == "low":
		haze = Color(0.052, 0.060, 0.049)
	world_env.fog_light_color = haze
	world_env.background_color = haze
	world_env.ambient_light_energy = 0.30 if quality != "low" else 0.12

func _setup_camera() -> void:
	menu_camera = Camera3D.new()
	menu_camera.name = "MenuCamera"
	menu_camera.position = cam_base_pos
	menu_camera.fov = 52.0
	menu_camera.far = 300.0
	menu_camera.current = true
	add_child(menu_camera)
	menu_camera.rotation = Vector3(cam_pitch, cam_yaw, 0.0)

# ──────────────────────────────────────────────────────────────────────────────
#  2. Дорога, лес и фонарь
# ──────────────────────────────────────────────────────────────────────────────
func _build_road_scene() -> void:
	var scene_root = Node3D.new()
	scene_root.name = "RoadScene"
	add_child(scene_root)

	var ground = MeshInstance3D.new()
	ground.name = "Ground"
	var ground_mesh = PlaneMesh.new()
	ground_mesh.size = Vector2(260.0, 260.0)
	var ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.022, 0.026, 0.020)
	ground_mat.roughness = 1.0
	ground_mesh.material = ground_mat
	ground.mesh = ground_mesh
	ground.position = Vector3(0.0, 0.0, -60.0)
	scene_root.add_child(ground)

	_build_menu_road(scene_root)
	_build_tree_line(scene_root)
	_build_street_lamp(scene_root)

func _build_menu_road(parent: Node3D) -> void:
	var road = MeshInstance3D.new()
	road.name = "Road"
	var road_mesh = PlaneMesh.new()
	road_mesh.size = Vector2(9.0, 170.0)

	var wet_noise = FastNoiseLite.new()
	wet_noise.frequency = 0.012
	wet_noise.fractal_octaves = 4
	var wet_tex = NoiseTexture2D.new()
	wet_tex.width = 512
	wet_tex.height = 512
	wet_tex.seamless = true
	wet_tex.noise = wet_noise

	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_texture = TextureHelper.get_texture("res://assets/textures/concrete_grunge.png")
	road_mat.albedo_color = Color(0.86, 0.88, 0.84)
	road_mat.roughness_texture = wet_tex
	road_mat.roughness = 0.62
	road_mat.uv1_scale = Vector3(1.5, 28.0, 1.0)
	road_mesh.material = road_mat
	road.mesh = road_mesh
	road.position = Vector3(0.0, 0.015, -70.0)
	parent.add_child(road)

	# Краска стёрта неровными пятнами
	var wear_noise = FastNoiseLite.new()
	wear_noise.frequency = 0.05
	wear_noise.fractal_octaves = 5
	var wear_tex = NoiseTexture2D.new()
	wear_tex.width = 256
	wear_tex.height = 256
	wear_tex.seamless = true
	wear_tex.noise = wear_noise

	var paint_mat = StandardMaterial3D.new()
	paint_mat.albedo_texture = wear_tex
	paint_mat.albedo_color = Color(0.74, 0.75, 0.70)
	paint_mat.roughness = 0.85

	for side in [-1.0, 1.0]:
		var edge = MeshInstance3D.new()
		var edge_mesh = BoxMesh.new()
		edge_mesh.size = Vector3(0.10, 0.01, 165.0)
		edge_mesh.material = paint_mat
		edge.mesh = edge_mesh
		edge.position = Vector3(side * 3.9, 0.026, -70.0)
		parent.add_child(edge)

	for i in range(22):
		var dash = MeshInstance3D.new()
		var dash_mesh = BoxMesh.new()
		dash_mesh.size = Vector3(0.14, 0.01, 3.0)
		dash_mesh.material = paint_mat
		dash.mesh = dash_mesh
		dash.position = Vector3(0.0, 0.026, -3.6 - i * 7.0)
		parent.add_child(dash)

# Стволы сливаются в сплошную стену по обе стороны дороги
func _build_tree_line(parent: Node3D) -> void:
	var bark = StandardMaterial3D.new()
	bark.albedo_color = Color(0.035, 0.038, 0.032)
	bark.roughness = 1.0
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.16
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 30.0
	trunk_mesh.radial_segments = 8
	trunk_mesh.rings = 1
	trunk_mesh.material = bark

	for i in range(170):
		var side = -1.0 if i % 2 == 0 else 1.0
		var trunk = MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		var near_road = randf() < 0.55
		var px = side * (randf_range(6.4, 13.0) if near_road else randf_range(13.0, 42.0))
		var pz = randf_range(-125.0, 30.0)
		# Перед самой камерой стволов нет: они закрыли бы кадр
		if absf(px) < 11.0 and pz > -9.0 and pz < 1.0:
			pz -= 12.0
		var sc = randf_range(0.7, 1.5)
		trunk.position = Vector3(px, 13.0, pz)
		trunk.scale = Vector3(sc, 1.0, sc)
		trunk.rotation_degrees = Vector3(randf_range(-1.5, 1.5), randf_range(0.0, 360.0), randf_range(-1.5, 1.5))
		trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(trunk)

func _build_street_lamp(parent: Node3D) -> void:
	var lamp_root = Node3D.new()
	lamp_root.name = "StreetLamp"
	lamp_root.position = Vector3(5.1, 0.0, -38.0)
	parent.add_child(lamp_root)

	var metal = StandardMaterial3D.new()
	metal.albedo_color = Color(0.03, 0.035, 0.03)
	metal.roughness = 0.7

	var pole = MeshInstance3D.new()
	var pole_mesh = BoxMesh.new()
	pole_mesh.size = Vector3(0.16, 7.2, 0.16)
	pole_mesh.material = metal
	pole.mesh = pole_mesh
	pole.position.y = 3.6
	lamp_root.add_child(pole)

	var arm = MeshInstance3D.new()
	var arm_mesh = BoxMesh.new()
	arm_mesh.size = Vector3(1.3, 0.1, 0.12)
	arm_mesh.material = metal
	arm.mesh = arm_mesh
	arm.position = Vector3(-0.6, 7.15, 0.0)
	lamp_root.add_child(arm)

	var bulb_mat = StandardMaterial3D.new()
	bulb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bulb_mat.albedo_color = Color(0.93, 1.0, 0.90)
	bulb_mat.disable_fog = true
	var bulb = MeshInstance3D.new()
	var bulb_mesh = BoxMesh.new()
	bulb_mesh.size = Vector3(0.5, 0.05, 0.2)
	bulb_mesh.material = bulb_mat
	bulb.mesh = bulb_mesh
	bulb.position = Vector3(-1.05, 7.08, 0.0)
	lamp_root.add_child(bulb)

	lamp_light = SpotLight3D.new()
	lamp_light.light_color = Color(0.74, 0.92, 0.68)
	lamp_light.light_energy = 5.0
	lamp_light.spot_range = 13.0
	lamp_light.spot_angle = 58.0
	lamp_light.spot_attenuation = 0.9
	lamp_light.light_volumetric_fog_energy = 1.4
	lamp_light.shadow_enabled = GameManager.graphics_quality != "low"
	lamp_light.position = Vector3(-1.05, 7.0, 0.0)
	lamp_light.rotation_degrees.x = -90.0
	lamp_root.add_child(lamp_light)

	# Ореол в тумане виден и без объёмного света
	var glow_grad = Gradient.new()
	glow_grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	glow_grad.set_color(0, Color(1, 1, 1, 0.75))
	glow_grad.set_color(1, Color(1, 1, 1, 0))
	glow_grad.add_point(0.08, Color(1, 1, 1, 0.42))
	glow_grad.add_point(0.25, Color(1, 1, 1, 0.16))
	glow_grad.add_point(0.55, Color(1, 1, 1, 0.04))
	var glow_tex = GradientTexture2D.new()
	glow_tex.gradient = glow_grad
	glow_tex.fill = GradientTexture2D.FILL_RADIAL
	glow_tex.fill_from = Vector2(0.5, 0.5)
	glow_tex.fill_to = Vector2(1.0, 0.5)
	glow_tex.width = 256
	glow_tex.height = 256
	var glow_mat = StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.albedo_texture = glow_tex
	glow_mat.albedo_color = Color(0.56, 0.64, 0.52, 0.55)
	glow_mat.disable_fog = true
	var glow_mesh = QuadMesh.new()
	glow_mesh.size = Vector2(22.0, 22.0)
	glow_mesh.material = glow_mat
	lamp_glow = MeshInstance3D.new()
	lamp_glow.mesh = glow_mesh
	lamp_glow.position = Vector3(-1.05, 6.6, -0.6)
	lamp_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lamp_root.add_child(lamp_glow)

# ──────────────────────────────────────────────────────────────────────────────
#  3. Фигура на дороге
# ──────────────────────────────────────────────────────────────────────────────
func _setup_figure() -> void:
	figure_model = SkinwalkerModel.new()
	figure_model.name = "RoadFigure"
	figure_model.position = figure_spots[0]
	add_child(figure_model)

func _update_figure(delta: float) -> void:
	if not figure_model:
		return
	figure_model.update_motion(delta, "twitch" if fmod(elapsed_time, 7.0) < 2.5 else "idle", 0.0)
	figure_timer -= delta
	if figure_timer > 0.0:
		return
	figure_timer = randf_range(12.0, 24.0)
	figure_spot = (figure_spot + 1) % figure_spots.size()
	figure_model.position = figure_spots[figure_spot]
	VHSOverlay.glitch(0.95)
	if figure_audio and figure_audio.stream and randf() < 0.4:
		figure_audio.play()

func _try_load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return null

# ──────────────────────────────────────────────────────────────────────────────
#  4. Скример при повороте камеры назад
# ──────────────────────────────────────────────────────────────────────────────
func _setup_jumpscare_system() -> void:
	jumpscare_flash = ColorRect.new()
	jumpscare_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	jumpscare_flash.color = Color(0.0, 0.0, 0.0, 0.0)
	jumpscare_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(jumpscare_flash)

func _trigger_jumpscare() -> void:
	is_jumpscare_active = true
	can_trigger_jumpscare = false
	is_rmb_dragging = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Обернулся, а там пустота: музыка обрывается, свет гаснет, полсекунды тишины
	var music_db: float = menu_music_player.volume_db if menu_music_player else 0.0
	if menu_music_player:
		menu_music_player.volume_db = -80.0
	jumpscare_flash.color.a = 1.0
	VHSOverlay.glitch(0.7)
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
		return

	var scare := SkinwalkerScare.new()
	scare.approach_from = 3.6
	scare.approach_time = 0.24
	add_child(scare)
	VHSOverlay.glitch(1.0)
	await scare.finished
	if not is_inside_tree():
		return
	scare.queue_free()

	# Дорога снова перед глазами, будто ничего не было
	cam_yaw = cam_base_yaw
	if menu_camera:
		menu_camera.rotation = Vector3(cam_pitch, cam_yaw + cam_pan, 0.0)
	jumpscare_flash.color.a = 0.0
	if menu_music_player:
		menu_music_player.volume_db = music_db
	VHSOverlay.glitch(0.8)
	is_jumpscare_active = false
	jumpscare_cooldown = 12.0

func _update_jumpscare(delta: float) -> void:
	if not is_jumpscare_active and not can_trigger_jumpscare:
		jumpscare_cooldown -= delta
		if jumpscare_cooldown <= 0.0:
			can_trigger_jumpscare = true

# ──────────────────────────────────────────────────────────────────────────────
#  5. Аудио
# ──────────────────────────────────────────────────────────────────────────────
func _setup_audio() -> void:
	menu_music_player = AudioStreamPlayer.new()
	menu_music_player.name = "MenuMusic"
	var ost = _try_load_res("res://assets/menu.mp3")
	if not ost:
		ost = _try_load_res("res://assets/dreamambient.mp3")
	if ost:
		if ost is AudioStreamMP3:
			(ost as AudioStreamMP3).loop = true
		menu_music_player.stream = ost
		menu_music_player.volume_db = -4.0
		menu_music_player.autoplay = true
	add_child(menu_music_player)

	sfx_hover = AudioStreamPlayer.new()
	var h_snd = _try_load_res("res://assets/audio/menu_hover.wav")
	if h_snd:
		sfx_hover.stream = h_snd
		sfx_hover.volume_db = -8.0
	add_child(sfx_hover)

	sfx_select = AudioStreamPlayer.new()
	var s_snd = _try_load_res("res://assets/audio/menu_select.wav")
	if s_snd:
		sfx_select.stream = s_snd
		sfx_select.volume_db = -4.0
	add_child(sfx_select)

	heartbeat_audio = AudioStreamPlayer.new()
	var hb_snd = _try_load_res("res://assets/heart.mp3")
	if hb_snd:
		if hb_snd is AudioStreamMP3:
			(hb_snd as AudioStreamMP3).loop = true
		heartbeat_audio.stream = hb_snd
		heartbeat_audio.volume_db = -80.0
		heartbeat_audio.autoplay = true
	add_child(heartbeat_audio)

	figure_audio = AudioStreamPlayer.new()
	var growl = _try_load_res("res://assets/audio/skinwalker_scream.wav")
	if growl:
		figure_audio.stream = growl
		figure_audio.pitch_scale = 0.48
		figure_audio.volume_db = -24.0
	add_child(figure_audio)

func _try_load_res(p: String) -> Resource:
	if ResourceLoader.exists(p):
		return load(p)
	return null

# ──────────────────────────────────────────────────────────────────────────────
#  6. Интерфейс
# ──────────────────────────────────────────────────────────────────────────────
func _make_label(text: String, font_size: int, color: Color, spacing: int = 0) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if spacing > 0:
		lbl.add_theme_font_override("font", VHSOverlay.tracked_font(spacing))
	return lbl

func _make_screen() -> Control:
	var screen = Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(screen)
	return screen

# Строка списка: красная метка слева и зона для мыши
func _make_row(parent: Control, y: float, width: float, height: float) -> Dictionary:
	var row = Control.new()
	row.position = Vector2(82.0, y - height * 0.5)
	row.size = Vector2(width, height)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(row)

	var bar = ColorRect.new()
	bar.position = Vector2(0.0, height * 0.5 - 9.0)
	bar.size = Vector2(3.0, 18.0)
	bar.color = COLOR_ACCENT
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	row.add_child(bar)

	return {"row": row, "bar": bar}

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	var signal_lbl = _make_label("НЕТ СИГНАЛА", 13, COLOR_FAINT, 3)
	signal_lbl.position = Vector2(63.0, 46.0)
	ui_root.add_child(signal_lbl)

	_build_main_screen()
	_build_settings_screen()
	settings_screen.visible = false

func _build_main_screen() -> void:
	main_screen = _make_screen()
	item_labels.clear()
	item_bars.clear()

	for idx in range(MENU_OPTIONS.size()):
		var parts = _make_row(main_screen, 428.0 + idx * 30.5, 240.0, 28.0)
		var row: Control = parts["row"]
		var lbl = _make_label(MENU_OPTIONS[idx], 18, COLOR_DIM, 3)
		lbl.position = Vector2(19.0, 2.0)
		row.add_child(lbl)
		item_labels.append(lbl)
		item_bars.append(parts["bar"])

		row.mouse_entered.connect(func(): _on_item_hovered(idx))
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_on_item_clicked(idx)
		)

func _build_settings_screen() -> void:
	settings_screen = _make_screen()

	var title = _make_label("НАСТРОЙКИ", 24, COLOR_BRIGHT, 5)
	title.position = Vector2(97.0, 178.0)
	settings_screen.add_child(title)

	setting_labels.clear()
	setting_values.clear()
	setting_bars.clear()
	sound_segments.clear()

	for idx in range(SETTINGS_ROWS.size()):
		var parts = _make_row(settings_screen, 273.0 + idx * 37.4, 640.0, 32.0)
		var row: Control = parts["row"]

		var lbl = _make_label(SETTINGS_ROWS[idx]["title"], 17, COLOR_DIM, 2)
		lbl.position = Vector2(20.0, 4.0)
		row.add_child(lbl)

		var val = _make_label("", 17, COLOR_VALUE, 2)
		val.position = Vector2(248.0, 4.0)
		row.add_child(val)

		setting_labels.append(lbl)
		setting_values.append(val)
		setting_bars.append(parts["bar"])

		if SETTINGS_ROWS[idx]["id"] == "sound":
			for s in range(10):
				var seg = ColorRect.new()
				seg.position = Vector2(248.0 + SOUND_BAR_X + s * (SOUND_SEGMENT_W + SOUND_SEGMENT_GAP), 15.0)
				seg.size = Vector2(SOUND_SEGMENT_W, 2.0)
				seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(seg)
				sound_segments.append(seg)

		row.mouse_entered.connect(func(): _select_setting(idx, true))
		row.gui_input.connect(func(ev: InputEvent): _on_setting_mouse(idx, ev))

	setting_desc = _make_label("", 14, COLOR_DIM, 1)
	setting_desc.position = Vector2(102.0, 508.0)
	settings_screen.add_child(setting_desc)

	var back_parts = _make_row(settings_screen, 568.0, 160.0, 30.0)
	var back_row: Control = back_parts["row"]
	var back_lbl = _make_label("ESC  НАЗАД", 17, COLOR_DIM, 2)
	back_lbl.position = Vector2(20.0, 3.0)
	back_row.add_child(back_lbl)
	back_row.mouse_entered.connect(func():
		back_lbl.add_theme_color_override("font_color", COLOR_BRIGHT)
		back_parts["bar"].visible = true
	)
	back_row.mouse_exited.connect(func():
		back_lbl.add_theme_color_override("font_color", COLOR_DIM)
		back_parts["bar"].visible = false
	)
	back_row.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_close_modals()
	)

	var keys_hint = _make_label("← →  ИЗМЕНИТЬ", 14, COLOR_FAINT, 2)
	keys_hint.position = Vector2(270.0, 558.0)
	settings_screen.add_child(keys_hint)

	_refresh_settings()

# ──────────────────────────────────────────────────────────────────────────────
#  7. Навигация и ввод
# ──────────────────────────────────────────────────────────────────────────────
func _play_hover() -> void:
	if sfx_hover and sfx_hover.stream:
		sfx_hover.play()

func _update_selection(new_index: int, play_sound: bool = true) -> void:
	if is_modal_open:
		return
	selected_index = clampi(new_index, 0, MENU_OPTIONS.size() - 1)

	if play_sound:
		_play_hover()

	for i in range(MENU_OPTIONS.size()):
		var is_sel = (i == selected_index)
		item_bars[i].visible = is_sel
		item_labels[i].add_theme_color_override("font_color", COLOR_BRIGHT if is_sel else COLOR_DIM)

func _on_item_hovered(idx: int) -> void:
	if is_modal_open or is_rmb_dragging or idx == selected_index:
		return
	_update_selection(idx, true)

func _on_item_clicked(idx: int) -> void:
	if is_modal_open or is_rmb_dragging:
		return
	selected_index = idx
	_execute_action(selected_index)

func _execute_action(idx: int) -> void:
	if sfx_select and sfx_select.stream:
		sfx_select.play()

	match idx:
		0: _start_game()
		1: _open_settings()
		2: _quit()

func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and event.keycode == keycode

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_7:
		get_tree().change_scene_to_file("res://scenes/DebugEditor.tscn")
		return

	if event is InputEventMouseButton and not is_modal_open:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rmb_dragging = event.pressed
			if is_rmb_dragging:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_jumpscare_active:
		return

	if is_rmb_dragging and event is InputEventMouseMotion:
		var sens = 0.0032
		cam_yaw -= event.relative.x * sens
		cam_pitch = clampf(cam_pitch - event.relative.y * sens, deg_to_rad(-35.0), deg_to_rad(45.0))
		if menu_camera:
			menu_camera.rotation = Vector3(cam_pitch, cam_yaw + cam_pan, 0.0)

		# Скример при повороте назад (угол > 125°)
		var angle_diff = wrapf(cam_yaw - cam_base_yaw, -PI, PI)
		if abs(angle_diff) > deg_to_rad(125.0) and can_trigger_jumpscare and not is_jumpscare_active:
			_trigger_jumpscare()
		return

	if is_modal_open:
		_input_settings(event)
		return

	if event.is_action_pressed("ui_up") or _is_key(event, KEY_W):
		var next_idx = (selected_index - 1 + MENU_OPTIONS.size()) % MENU_OPTIONS.size()
		_update_selection(next_idx, true)
	elif event.is_action_pressed("ui_down") or _is_key(event, KEY_S):
		var next_idx = (selected_index + 1) % MENU_OPTIONS.size()
		_update_selection(next_idx, true)
	elif event.is_action_pressed("ui_accept") or _is_key(event, KEY_ENTER):
		_execute_action(selected_index)

func _input_settings(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_close_modals()
	elif event.is_action_pressed("ui_up") or _is_key(event, KEY_W):
		_select_setting(posmod(settings_index - 1, SETTINGS_ROWS.size()), true)
	elif event.is_action_pressed("ui_down") or _is_key(event, KEY_S):
		_select_setting(posmod(settings_index + 1, SETTINGS_ROWS.size()), true)
	elif event.is_action_pressed("ui_left") or _is_key(event, KEY_A):
		_change_setting(settings_index, -1)
	elif event.is_action_pressed("ui_right") or _is_key(event, KEY_D):
		_change_setting(settings_index, 1)
	elif event.is_action_pressed("ui_accept") or _is_key(event, KEY_ENTER):
		_change_setting(settings_index, 1)

# ──────────────────────────────────────────────────────────────────────────────
#  8. Настройки
# ──────────────────────────────────────────────────────────────────────────────
func _open_settings() -> void:
	is_modal_open = true
	main_screen.visible = false
	settings_screen.visible = true
	_select_setting(0, false)
	_pan_camera(0.12)

func _close_modals() -> void:
	is_modal_open = false
	settings_screen.visible = false
	main_screen.visible = true
	_play_hover()
	_pan_camera(0.0)

func _pan_camera(target: float) -> void:
	var tw = create_tween()
	tw.tween_property(self, "cam_pan", target, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _select_setting(idx: int, play_sound: bool) -> void:
	if idx == settings_index and play_sound:
		return
	settings_index = idx
	if play_sound:
		_play_hover()
	_refresh_settings()

func _on_setting_mouse(idx: int, ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed):
		return
	if ev.button_index == MOUSE_BUTTON_RIGHT or ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_change_setting(idx, -1)
	elif ev.button_index == MOUSE_BUTTON_WHEEL_UP:
		_change_setting(idx, 1)
	elif ev.button_index == MOUSE_BUTTON_LEFT:
		var bar_left = 248.0 + SOUND_BAR_X
		if SETTINGS_ROWS[idx]["id"] == "sound" and ev.position.x >= bar_left:
			var ratio = (ev.position.x - bar_left) / (10.0 * (SOUND_SEGMENT_W + SOUND_SEGMENT_GAP))
			GameManager.set_sound_level(clampi(int(ceil(ratio * 10.0)) * 10, 0, 100))
			_commit_setting()
		else:
			_change_setting(idx, 1)

func _change_setting(idx: int, dir: int) -> void:
	match SETTINGS_ROWS[idx]["id"]:
		"sound":
			GameManager.set_sound_level(clampi(GameManager.sound_level + dir * 10, 0, 100))
		"sens":
			GameManager.mouse_sensitivity = clampf(snappedf(GameManager.mouse_sensitivity + dir * 0.1, 0.1), 0.3, 2.5)
		"gfx":
			var nq = GameManager.cycle_graphics_quality()
			if dir < 0:
				nq = GameManager.cycle_graphics_quality()
			_apply_menu_graphics(nq)
		"vhs":
			GameManager.vhs_enabled = not GameManager.vhs_enabled
			VHSOverlay.glitch(0.6)
		"dyn":
			GameManager.set_dynamic_resolution(not GameManager.dynamic_resolution)
		"res":
			var modes: Array = GameManager.RESOLUTION_MODES
			var cur = modes.find(GameManager.resolution_mode)
			GameManager.set_resolution_mode(modes[posmod(cur + dir, modes.size())])
		"models":
			GameManager.toggle_legacy_graphics()
	_commit_setting()

func _commit_setting() -> void:
	if sfx_select and sfx_select.stream:
		sfx_select.play()
	GameManager.save_settings()
	_refresh_settings()

func _setting_text(id: String) -> String:
	match id:
		"sound":
			return str(GameManager.sound_level)
		"sens":
			return "%.1f" % GameManager.mouse_sensitivity
		"gfx":
			var q = "ВЫСОКАЯ"
			if GameManager.graphics_quality == "ultra": q = "УЛЬТРА"
			elif GameManager.graphics_quality == "medium": q = "СРЕДНЯЯ"
			elif GameManager.graphics_quality == "low": q = "НИЗКАЯ"
			return "<  %s  >" % q
		"vhs":
			return "ВКЛ" if GameManager.vhs_enabled else "ВЫКЛ"
		"dyn":
			return "ВКЛ" if GameManager.dynamic_resolution else "ВЫКЛ"
		"res":
			var r = "АВТО" if GameManager.resolution_mode == "auto" else GameManager.resolution_mode
			return "<  %s  >" % r
		"models":
			return "<  %s  >" % ("РЕТРО" if GameManager.is_legacy_graphics else "РЕАЛИЗМ")
	return ""

func _refresh_settings() -> void:
	for i in range(SETTINGS_ROWS.size()):
		var is_sel = (i == settings_index)
		setting_bars[i].visible = is_sel
		setting_labels[i].add_theme_color_override("font_color", COLOR_BRIGHT if is_sel else COLOR_DIM)
		setting_values[i].add_theme_color_override("font_color", COLOR_BRIGHT if is_sel else COLOR_VALUE)
		setting_values[i].text = _setting_text(SETTINGS_ROWS[i]["id"])

	var filled = GameManager.sound_level / 10
	for s in range(sound_segments.size()):
		sound_segments[s].color = COLOR_BRIGHT if s < filled else Color(1, 1, 1, 0.16)

	if setting_desc:
		setting_desc.text = SETTINGS_ROWS[settings_index]["desc"]

# ──────────────────────────────────────────────────────────────────────────────
#  9. Главный цикл
# ──────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	elapsed_time += delta

	# Тряска экрана при скримере
	var shake_offset = Vector3.ZERO
	if cam_trauma > 0.0:
		cam_trauma = maxf(0.0, cam_trauma - delta * 1.5)
		var shake_mag = cam_trauma * cam_trauma * 0.16
		shake_offset = Vector3(
			randf_range(-shake_mag, shake_mag),
			randf_range(-shake_mag, shake_mag),
			randf_range(-shake_mag * 0.5, shake_mag * 0.5)
		)

	# Камера едва заметно дышит, как в руках оператора
	if menu_camera:
		var cam_sway_x = sin(elapsed_time * 0.45) * 0.012
		var cam_sway_y = cos(elapsed_time * 0.7) * 0.008
		menu_camera.position = cam_base_pos + Vector3(cam_sway_x, cam_sway_y, 0.0) + shake_offset

		if not is_rmb_dragging:
			menu_camera.rotation = Vector3(
				cam_pitch + sin(elapsed_time * 0.6) * 0.0015,
				cam_yaw + cam_pan + cos(elapsed_time * 0.5) * 0.0015,
				0.0
			)

	# Лампа фонаря иногда моргает
	if lamp_light:
		var blink = sin(elapsed_time * 11.0) * cos(elapsed_time * 17.3)
		var power = 0.55 if blink > 0.93 else 1.0
		lamp_light.light_energy = 5.0 * power
		if lamp_glow:
			lamp_glow.transparency = 0.0 if power > 0.9 else 0.45

	_update_figure(delta)
	_update_jumpscare(delta)

# ──────────────────────────────────────────────────────────────────────────────
#  10. Переходы между сценами
# ──────────────────────────────────────────────────────────────────────────────
func _start_game() -> void:
	if GameManager:
		GameManager.intro_cutscene_played = true
		GameManager.active_map_path = "res://scenes/1level.json"
	VHSOverlay.glitch(1.0)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _quit() -> void:
	get_tree().quit()
