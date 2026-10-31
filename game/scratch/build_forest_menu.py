import sys
sys.stdout.reconfigure(encoding='utf-8')

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

menu_code = r'''extends Node3D

const TextureHelper = preload("res://scripts/TextureHelper.gd")
const PrefabBuilder = preload("res://scripts/PrefabBuilder.gd")

# ══════════════════════════════════════════════════════════════════════════════
#  Menu.gd — Главное Меню: В центре тёмного леса со Скинвокером
#  • Игрок в центре зловещей лесной поляны (360° глухой сосновый бор)
#  • Свободный обзор 360° на правую кнопку мыши (ПКМ)
#  • Живой перемещающийся монстр-хищник: крадётся между соснами,
#    выглядывает из-за стволов со светящимися глазами, перебегает поляну
#  • Брошенный тактический фонарь в траве с объёмным лучом сквозь туман
#  • Полнолуние сквозь кроны деревьев, объёмный туман UE5, ACES тонемаппинг
# ══════════════════════════════════════════════════════════════════════════════

# Аудио
var menu_music_player:        AudioStreamPlayer
var sfx_hover:                AudioStreamPlayer
var sfx_select:               AudioStreamPlayer
var jumpscare_audio:          AudioStreamPlayer
var heartbeat_audio:          AudioStreamPlayer

# 3D Камера
var menu_camera:              Camera3D
var cam_base_pos:             Vector3 = Vector3(0.0, 1.35, 0.0)
var cam_base_yaw:             float = 0.0
var cam_base_pitch:           float = -0.05
var cam_yaw:                  float = 0.0
var cam_pitch:                float = -0.05
var is_rmb_dragging:          bool = false
var cam_trauma:               float = 0.0

# Окружение
var world_env_node:           WorldEnvironment
var world_env:                Environment
var moon_light:               DirectionalLight3D
var stars_node:               MultiMeshInstance3D
var moon_clouds:              Array[Node3D] = []

# Фонарик в лесу
var dropped_flashlight:       SpotLight3D = null

# ── Перемещающийся Скинвокер в лесу ──
var monster_root:             Node3D = null
var monster_sprite:           Sprite3D = null
var monster_eye_light:        OmniLight3D = null
var monster_step_audio:       AudioStreamPlayer3D = null
var monster_growl_audio:      AudioStreamPlayer3D = null

enum MonsterStalkState { LURK_PEEK, SNEAK_WALK, DART, CIRCLE }
var monster_state:            MonsterStalkState = MonsterStalkState.LURK_PEEK
var monster_state_timer:      float = 0.0
var monster_pos:              Vector3 = Vector3(-6.5, 0.0, -14.0)
var monster_target_pos:       Vector3 = Vector3(5.5, 0.0, -13.0)
var monster_walk_cycle_t:     float = 0.0
var monster_last_step:        int = 0
var monster_look_target:      Vector3 = Vector3.ZERO
var monster_peek_tilt:        float = 0.0

# Точки патрулирования и засад среди деревьев
var stalk_spots: Array[Vector3] = [
	Vector3(-7.5, 0.0, -13.5), # За левой толстой сосной
	Vector3(-2.0, 0.0, -10.5), # Прогалины в лучах фонарика
	Vector3( 5.5, 0.0, -12.5), # За поваленным деревом справа
	Vector3( 1.5, 0.0, -7.0),  # Опасно близко к камере!
	Vector3(-4.5, 0.0, -19.0), # В глубине тумана
	Vector3( 8.0, 0.0, -16.0), # В чащобе справа
	Vector3(-1.0, 0.0,  9.5),  # Сзади игрока за сосной!
	Vector3(-9.0, 0.0, -8.0),  # Слева на опушке
]
var stalk_idx: int = 0

# Скример при взгляде назад
var jumpscare_monster:        Node3D = null
var jumpscare_sprite:         Sprite3D = null
var jumpscare_eye_light:      OmniLight3D = null
var jumpscare_flash:          ColorRect = null
var is_jumpscare_active:      bool = false
var jumpscare_timer:          float = 0.0
var can_trigger_jumpscare:    bool = true
var jumpscare_cooldown:       float = 0.0

# Текстуры монстра
var tex_m_front_idle:         Texture2D
var tex_m_front_walk_0:       Texture2D
var tex_m_front_walk_1:       Texture2D
var tex_m_back:               Texture2D
var tex_m_left_walk_0:        Texture2D
var tex_m_left_walk_1:        Texture2D
var tex_m_right_walk_0:       Texture2D
var tex_m_right_walk_1:       Texture2D

# UI элементы
var selected_index:           int = 0
var ui_root:                  Control
var banner_rects:             Array[TextureRect] = []
var cursor_labels:            Array[Label] = []
var item_labels:              Array[Label] = []

# Модальные окна
var modal_settings:           Control
var modal_chapters:           Control
var modal_credits:            Control
var is_modal_open:            bool = false
var settings_btn_gfx:         Button = null

var elapsed_time:             float = 0.0

const MENU_OPTIONS = [
	"ИГРАТЬ",
	"ГЛАВЫ",
	"НАСТРОЙКИ",
	"РЕДАКТОР КАРТ",
	"ВЫХОД"
]

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_environment()
	_setup_camera()
	_setup_sky_and_moon()
	_build_3d_forest()
	_setup_forest_monster()
	_setup_jumpscare_system()
	_setup_audio()
	_build_ui()
	_update_selection(0, false)

# ──────────────────────────────────────────────────────────────────────────────
#  1. Окружение, свет луны и графика
# ──────────────────────────────────────────────────────────────────────────────
func _setup_environment() -> void:
	world_env_node = WorldEnvironment.new()
	world_env = Environment.new()
	world_env.background_mode = Environment.BG_SKY

	var sky = Sky.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.012, 0.018, 0.038)
	sky_mat.sky_horizon_color = Color(0.035, 0.055, 0.095)
	sky_mat.ground_bottom_color = Color(0.006, 0.009, 0.015)
	sky_mat.ground_horizon_color = Color(0.035, 0.055, 0.095)
	sky_mat.sun_angle_max = 0.0
	sky.sky_material = sky_mat
	world_env.sky = sky

	world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.ambient_light_color = Color(0.025, 0.035, 0.055)
	world_env.ambient_light_energy = 0.60

	world_env.fog_enabled = true
	world_env.fog_light_color = Color(0.03, 0.045, 0.08)
	world_env.fog_density = 0.003

	_apply_menu_graphics(GameManager.graphics_quality if GameManager else "ultra")

	world_env_node.environment = world_env
	add_child(world_env_node)

	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonDirectional"
	moon_light.rotation_degrees = Vector3(-48, 35, 0)
	moon_light.light_color = Color(0.68, 0.80, 1.0)
	moon_light.light_energy = 0.38
	moon_light.shadow_enabled = true
	moon_light.shadow_bias = 0.05
	moon_light.shadow_blur = 1.8
	add_child(moon_light)

func _apply_menu_graphics(quality: String) -> void:
	if not world_env:
		return
	match quality:
		"ultra", "high":
			world_env.ssao_enabled = true
			world_env.ssao_radius = 1.8
			world_env.ssao_intensity = 2.8
			world_env.ssao_power = 1.3
			world_env.ssil_enabled = true
			world_env.ssil_radius = 4.5
			world_env.ssil_intensity = 1.3
			world_env.ssr_enabled = true
			world_env.glow_enabled = true
			world_env.glow_bloom = 0.16
			world_env.glow_intensity = 0.85
			world_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			world_env.sdfgi_enabled = false
			world_env.volumetric_fog_enabled = true
			world_env.volumetric_fog_density = 0.024
			world_env.volumetric_fog_albedo = Color(0.05, 0.075, 0.12)
			world_env.volumetric_fog_anisotropy = 0.40
			world_env.volumetric_fog_temporal_reprojection_enabled = true
			world_env.tonemap_mode = Environment.TONE_MAPPER_ACES
			world_env.tonemap_exposure = 1.05
			world_env.tonemap_white = 6.0
			world_env.adjustment_enabled = true
			world_env.adjustment_contrast = 1.15
			world_env.adjustment_saturation = 0.92
			if moon_light:
				moon_light.shadow_enabled = true
		"medium":
			world_env.ssao_enabled = true
			world_env.ssil_enabled = false
			world_env.ssr_enabled = false
			world_env.glow_enabled = true
			world_env.glow_bloom = 0.08
			world_env.sdfgi_enabled = false
			world_env.volumetric_fog_enabled = false
			world_env.fog_enabled = true
			world_env.fog_density = 0.02
			world_env.tonemap_mode = Environment.TONE_MAPPER_ACES
			world_env.tonemap_exposure = 1.0
			world_env.adjustment_enabled = false
			if moon_light:
				moon_light.shadow_enabled = true
		"low":
			world_env.ssao_enabled = false
			world_env.ssil_enabled = false
			world_env.ssr_enabled = false
			world_env.glow_enabled = false
			world_env.sdfgi_enabled = false
			world_env.volumetric_fog_enabled = false
			world_env.fog_enabled = true
			world_env.fog_density = 0.015
			world_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			world_env.adjustment_enabled = false
			if moon_light:
				moon_light.shadow_enabled = false

func _setup_camera() -> void:
	menu_camera = Camera3D.new()
	menu_camera.name = "MenuCamera"
	menu_camera.position = cam_base_pos
	menu_camera.fov = 76.0
	menu_camera.far = 400.0
	menu_camera.current = true
	add_child(menu_camera)
	menu_camera.rotation = Vector3(cam_pitch, cam_yaw, 0.0)

# ──────────────────────────────────────────────────────────────────────────────
#  2. Луна, звезды и облака
# ──────────────────────────────────────────────────────────────────────────────
func _setup_sky_and_moon() -> void:
	var sky_root = Node3D.new()
	sky_root.name = "SkyElements"
	add_child(sky_root)

	# Луна сквозь ветви сосен
	var moon_pos = Vector3(15.0, 32.0, -45.0)
	var moon_mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 4.2
	sphere.height = 8.4
	var moon_mat = StandardMaterial3D.new()
	var moon_tex = TextureHelper.get_texture("res://assets/textures/moon_surface.png")
	if moon_tex:
		moon_mat.albedo_texture = moon_tex
		moon_mat.emission_enabled = true
		moon_mat.emission_texture = moon_tex
		moon_mat.emission = Color(0.85, 0.92, 1.0)
		moon_mat.emission_energy_multiplier = 0.8
	else:
		moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_mat.albedo_color = Color(0.92, 0.95, 1.0)
	moon_mesh_inst.material_override = moon_mat
	moon_mesh_inst.mesh = sphere
	moon_mesh_inst.position = moon_pos
	sky_root.add_child(moon_mesh_inst)

	# Ореол луны
	var halo = MeshInstance3D.new()
	var hm = QuadMesh.new()
	hm.size = Vector2(22.0, 22.0)
	var hmat = StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var glow_tex = TextureHelper.get_texture("res://assets/textures/moon_glow.png")
	if glow_tex:
		hmat.albedo_texture = glow_tex
		hmat.albedo_color = Color(0.65, 0.80, 1.0, 0.65)
	else:
		hmat.albedo_color = Color(0.45, 0.65, 0.95, 0.22)
	hm.material = hmat
	halo.mesh = hm
	halo.position = moon_pos + Vector3(0, 0, 0.6)
	sky_root.add_child(halo)

	# Облака
	for i in range(5):
		var cloud = MeshInstance3D.new()
		var cm = QuadMesh.new()
		cm.size = Vector2(randf_range(28.0, 50.0), randf_range(16.0, 32.0))
		cm.orientation = PlaneMesh.FACE_Y
		var cmat = StandardMaterial3D.new()
		cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cmat.albedo_color = Color(0.03, 0.045, 0.08, randf_range(0.18, 0.30))
		cm.material = cmat
		cloud.mesh = cm
		cloud.position = Vector3(randf_range(-40.0, 40.0), randf_range(30.0, 45.0), randf_range(-50.0, 20.0))
		cloud.set_meta("drift_speed", randf_range(0.3, 0.8))
		sky_root.add_child(cloud)
		moon_clouds.append(cloud)

	# Звезды
	stars_node = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sm = QuadMesh.new()
	sm.size = Vector2(0.24, 0.24)
	var smat = StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	smat.vertex_color_use_as_albedo = true
	sm.material = smat
	mm.mesh = sm
	mm.instance_count = 200
	for si in range(200):
		var theta = randf_range(0.0, TAU)
		var phi = randf_range(0.15, 1.30)
		var r = randf_range(65.0, 95.0)
		var sx = r * sin(phi) * cos(theta)
		var sy = r * cos(phi) + 10.0
		var sz = r * sin(phi) * sin(theta)
		var t = Transform3D()
		t.origin = Vector3(sx, sy, sz)
		mm.set_instance_transform(si, t)
		mm.set_instance_color(si, Color(randf_range(0.8, 1.0), randf_range(0.85, 1.0), 1.0, randf_range(0.5, 0.95)))
	stars_node.multimesh = mm
	sky_root.add_child(stars_node)

# ──────────────────────────────────────────────────────────────────────────────
#  3. Сборка 3D леса вокруг игрока (360° поляна)
# ──────────────────────────────────────────────────────────────────────────────
func _build_3d_forest() -> void:
	var forest_root = Node3D.new()
	forest_root.name = "ForestRoot"
	add_child(forest_root)

	# 1. Земля поляны
	var ground = MeshInstance3D.new()
	ground.name = "ForestGround"
	var gm = PlaneMesh.new()
	gm.size = Vector2(140.0, 140.0)
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.045, 0.052, 0.038)
	gmat.roughness = 0.96
	gm.material = gmat
	ground.mesh = gm
	ground.position = Vector3(0, 0, 0)
	forest_root.add_child(ground)

	# 2. Деревья леса вокруг поляны (360 градусов)
	# Кольцо 1 — ближние деревья вокруг поляны (6 - 13м)
	var inner_trees = [
		Vector3(-5.5, 0, -8.5),  Vector3( 5.0, 0, -9.0),
		Vector3(-8.5, 0, -13.5), Vector3( 7.5, 0, -14.0),
		Vector3(-3.5, 0, -17.0), Vector3( 3.5, 0, -18.5),
		Vector3(-9.5, 0, -4.0),  Vector3( 9.0, 0, -4.5),
		Vector3(-8.0, 0,  4.5),  Vector3( 7.5, 0,  4.0),
		Vector3(-4.5, 0,  9.5),  Vector3( 4.0, 0,  9.0),
		Vector3(-0.5, 0,  12.0), Vector3(-6.5, 0,  12.5),
		Vector3( 6.5, 0,  12.0), Vector3(-11.0, 0, 0.0),
		Vector3( 11.5, 0, 0.0),  Vector3(-1.5, 0, -23.0),
	]
	for i in range(inner_trees.size()):
		var pos = inner_trees[i]
		var is_dead = (i % 4 == 1)
		var t_type = "prop_tree_dead" if is_dead else "prop_tree_pine"
		var t_sz = Vector3(3.2, 7.0, 3.2) if is_dead else Vector3(4.0, 8.5, 4.0)
		var tree = PrefabBuilder.build_prefab(t_type, t_sz, Color.WHITE, false, "")
		tree.position = pos
		tree.rotation_degrees.y = randf_range(0, 360)
		forest_root.add_child(tree)

	# Кольцо 2 и 3 — средний и дальний плотный сосновый лес (15 - 45м)
	for i in range(55):
		var angle = randf_range(0, TAU)
		var dist = randf_range(14.0, 48.0)
		var px = cos(angle) * dist
		var pz = sin(angle) * dist
		var is_dead = (randf() < 0.25)
		var t_type = "prop_tree_dead" if is_dead else "prop_tree_pine"
		var sc = randf_range(0.85, 1.35)
		var t_sz = Vector3(3.5 * sc, 7.5 * sc, 3.5 * sc)
		var tree = PrefabBuilder.build_prefab(t_type, t_sz, Color.WHITE, false, "")
		tree.position = Vector3(px, 0, pz)
		tree.rotation_degrees.y = randf_range(0, 360)
		forest_root.add_child(tree)

	# Кусты и мёртвый валежник на поляне
	var bush_coords = [
		Vector3(-3.2, 0, -5.5), Vector3( 2.8, 0, -6.0),
		Vector3(-6.0, 0, -10.0), Vector3( 4.5, 0, -11.0),
		Vector3(-2.0, 0,  5.0), Vector3( 3.0, 0,  6.0),
		Vector3(-5.5, 0,  3.0), Vector3( 6.0, 0,  2.0),
	]
	for b_pos in bush_coords:
		var bush = PrefabBuilder.build_prefab("prop_bush_dead", Vector3(1.8, 1.4, 1.8), Color.WHITE, false, "")
		bush.position = b_pos
		bush.rotation_degrees.y = randf_range(0, 360)
		forest_root.add_child(bush)

	# Поваленное замшелое бревно впереди
	var log_mesh = MeshInstance3D.new()
	var log_m = CylinderMesh.new()
	log_m.top_radius = 0.28
	log_m.bottom_radius = 0.32
	log_m.height = 5.2
	var log_mat = StandardMaterial3D.new()
	log_mat.albedo_color = Color(0.18, 0.12, 0.08)
	log_mat.roughness = 0.95
	log_m.material = log_mat
	log_mesh.mesh = log_m
	log_mesh.position = Vector3(1.2, 0.25, -4.8)
	log_mesh.rotation_degrees = Vector3(0, 35, 88)
	forest_root.add_child(log_mesh)

	# Мшистые камни
	for r_pos in [Vector3(-2.8, 0.4, -4.2), Vector3(3.8, 0.5, -7.5), Vector3(-4.5, 0.6, -11.0)]:
		var rock = MeshInstance3D.new()
		var rm = SphereMesh.new()
		rm.radius = randf_range(0.5, 0.9)
		rm.height = rm.radius * 1.5
		var rmat = StandardMaterial3D.new()
		rmat.albedo_color = Color(0.15, 0.17, 0.14)
		rmat.roughness = 0.92
		rm.material = rmat
		rock.mesh = rm
		rock.position = r_pos
		rock.scale = Vector3(1.2, 0.7, 1.0)
		forest_root.add_child(rock)

	# 3. Брошенный в мох тактический фонарь с объёмным лучом
	var flash_stand = Node3D.new()
	flash_stand.position = Vector3(0.6, 0.35, -2.4)
	flash_stand.rotation_degrees = Vector3(12.0, -15.0, -25.0)
	forest_root.add_child(flash_stand)

	var flash_body = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.045
	cyl.bottom_radius = 0.055
	cyl.height = 0.32
	var f_mat = StandardMaterial3D.new()
	f_mat.albedo_color = Color(0.12, 0.13, 0.15)
	f_mat.metallic = 0.8
	f_mat.roughness = 0.3
	cyl.material = f_mat
	flash_body.mesh = cyl
	flash_body.rotation_degrees.x = 90.0
	flash_stand.add_child(flash_body)

	# Яркий луч света, пробивающий туман между соснами
	dropped_flashlight = SpotLight3D.new()
	dropped_flashlight.name = "ForestFlashlight"
	dropped_flashlight.light_color = Color(1.0, 0.96, 0.88)
	dropped_flashlight.light_energy = 5.2
	dropped_flashlight.spot_range = 38.0
	dropped_flashlight.spot_angle = 32.0
	dropped_flashlight.spot_attenuation = 1.1
	dropped_flashlight.shadow_enabled = true
	dropped_flashlight.shadow_blur = 1.4
	if "light_volumetric_fog_energy" in dropped_flashlight:
		dropped_flashlight.set("light_volumetric_fog_energy", 2.4)
	dropped_flashlight.rotation_degrees = Vector3(0, 180, 0)
	flash_stand.add_child(dropped_flashlight)

# ──────────────────────────────────────────────────────────────────────────────
#  4. Скинвокер в лесу: живой перемещающийся хищник
# ──────────────────────────────────────────────────────────────────────────────
func _setup_forest_monster() -> void:
	_load_monster_textures()

	monster_root = Node3D.new()
	monster_root.name = "ForestMonster"
	monster_pos = stalk_spots[0]
	monster_root.position = monster_pos
	add_child(monster_root)

	monster_sprite = Sprite3D.new()
	monster_sprite.name = "MonsterSprite"
	monster_sprite.texture = tex_m_front_idle
	monster_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	monster_sprite.pixel_size = 0.0028
	monster_sprite.position = Vector3(0, 1.25, 0)
	monster_sprite.shaded = true
	monster_sprite.double_sided = true
	monster_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	monster_root.add_child(monster_sprite)

	# Светящиеся зловещие глаза во тьме
	for eye_x in [-0.07, 0.07]:
		var eye = MeshInstance3D.new()
		var em = SphereMesh.new()
		em.radius = 0.024
		em.height = 0.048
		var emat = StandardMaterial3D.new()
		emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emat.albedo_color = Color(1.0, 0.22, 0.12)
		em.material = emat
		eye.mesh = em
		eye.position = Vector3(eye_x, 1.92, -0.15)
		monster_root.add_child(eye)

	# Ореол глаз в тумане
	monster_eye_light = OmniLight3D.new()
	monster_eye_light.light_color = Color(1.0, 0.25, 0.10)
	monster_eye_light.light_energy = 1.4
	monster_eye_light.omni_range = 2.4
	monster_eye_light.position = Vector3(0, 1.90, -0.2)
	monster_root.add_child(monster_eye_light)

	# 3D звук шагов по хвое и веткам
	monster_step_audio = AudioStreamPlayer3D.new()
	monster_step_audio.unit_size = 4.0
	monster_step_audio.max_distance = 32.0
	if ResourceLoader.exists("res://assets/audio/monster_step.wav"):
		monster_step_audio.stream = load("res://assets/audio/monster_step.wav")
	monster_step_audio.volume_db = -4.0
	monster_root.add_child(monster_step_audio)

	# 3D звук утробного рыка / дыхания
	monster_growl_audio = AudioStreamPlayer3D.new()
	monster_growl_audio.unit_size = 5.0
	monster_growl_audio.max_distance = 35.0
	if ResourceLoader.exists("res://assets/audio/skinwalker_scream.wav"):
		monster_growl_audio.stream = load("res://assets/audio/skinwalker_scream.wav")
	monster_growl_audio.pitch_scale = 0.48
	monster_growl_audio.volume_db = -9.0
	monster_root.add_child(monster_growl_audio)

func _load_monster_textures() -> void:
	const D = "res://assets/textures/enemy_character/"
	tex_m_front_idle   = _try_load_tex(D + "monster_front.png")
	tex_m_front_walk_0 = _try_load_tex(D + "monster_front_walk_0.png")
	tex_m_front_walk_1 = _try_load_tex(D + "monster_front_walk_1.png")
	tex_m_back         = _try_load_tex(D + "monster_back.png")
	tex_m_left_walk_0  = _try_load_tex(D + "monster_left_walk_0.png")
	tex_m_left_walk_1  = _try_load_tex(D + "monster_left_walk_1.png")
	tex_m_right_walk_0 = _try_load_tex(D + "monster_right_walk_0.png")
	tex_m_right_walk_1 = _try_load_tex(D + "monster_right_walk_1.png")

func _try_load_tex(p: String) -> Texture2D:
	if ResourceLoader.exists(p):
		return load(p) as Texture2D
	return null

# ──────────────────────────────────────────────────────────────────────────────
#  5. Логика перемещения монстра по лесу
# ──────────────────────────────────────────────────────────────────────────────
func _update_forest_monster(delta: float) -> void:
	if not monster_root or not monster_sprite:
		return

	monster_state_timer += delta

	# Пульсация глаз
	var eye_pulse = 1.3 + sin(elapsed_time * 4.0) * 0.7
	if monster_eye_light:
		monster_eye_light.light_energy = eye_pulse

	match monster_state:
		MonsterStalkState.LURK_PEEK:
			# Монстр затаился за деревом и пристально наблюдает за игроком
			var to_cam = (cam_base_pos - monster_root.position)
			to_cam.y = 0
			if to_cam.length_squared() > 0.1:
				monster_look_target = to_cam.normalized()

			# Дыхание монстра и покачивание головы
			var breathe = sin(elapsed_time * 2.2) * 0.025
			monster_sprite.position.y = 1.25 + breathe
			monster_peek_tilt = sin(elapsed_time * 1.5) * deg_to_rad(6.0)
			monster_sprite.rotation.z = monster_peek_tilt
			monster_sprite.texture = tex_m_front_idle if tex_m_front_idle else tex_m_front_walk_0

			# Через 3.5 - 6.0 секунд крадётся к следующей точке леса
			if monster_state_timer > randf_range(3.8, 5.8):
				monster_state = MonsterStalkState.SNEAK_WALK
				monster_state_timer = 0.0
				stalk_idx = (stalk_idx + 1) % stalk_spots.size()
				monster_target_pos = stalk_spots[stalk_idx]
				if monster_growl_audio and randf() < 0.40:
					monster_growl_audio.play()

		MonsterStalkState.SNEAK_WALK:
			# Крадущееся перемещение между деревьями
			var to_target = monster_target_pos - monster_root.position
			to_target.y = 0.0
			var dist = to_target.length()

			if dist < 0.6 or monster_state_timer > 8.0:
				# Достиг дерева — останавливается выглядывать
				monster_state = MonsterStalkState.LURK_PEEK
				monster_state_timer = 0.0
				monster_sprite.rotation.z = 0.0
				return

			var move_dir = to_target.normalized()
			var move_speed = 3.2 # Плавная жуткая скорость
			monster_root.position += move_dir * move_speed * delta

			# Шаги и процедурная анимация ходьбы
			monster_walk_cycle_t += delta * 7.5
			var step_phase = int(monster_walk_cycle_t) % 2
			if step_phase != monster_last_step:
				monster_last_step = step_phase
				if monster_step_audio and randf() < 0.65:
					monster_step_audio.pitch_scale = randf_range(0.85, 1.15)
					monster_step_audio.play()

			var step_bob = abs(sin(monster_walk_cycle_t * PI)) * 0.045
			monster_sprite.position.y = 1.25 - step_bob
			monster_sprite.rotation.z = sin(monster_walk_cycle_t * PI) * 0.035

			# Выбор направленной текстуры в зависимости от вектора движения относительно камеры
			var to_cam = (cam_base_pos - monster_root.position).normalized()
			var dot = move_dir.dot(to_cam)
			var cross_y = move_dir.cross(to_cam).y

			if dot > 0.55:
				monster_sprite.texture = tex_m_front_walk_0 if step_phase == 0 else tex_m_front_walk_1
			elif dot < -0.55:
				monster_sprite.texture = tex_m_back if tex_m_back else tex_m_front_idle
			elif cross_y > 0.0:
				monster_sprite.texture = tex_m_left_walk_0 if step_phase == 0 else tex_m_left_walk_1
			else:
				monster_sprite.texture = tex_m_right_walk_0 if step_phase == 0 else tex_m_right_walk_1

# ──────────────────────────────────────────────────────────────────────────────
#  6. Скример при повороте камеры назад в чащу
# ──────────────────────────────────────────────────────────────────────────────
func _setup_jumpscare_system() -> void:
	jumpscare_monster = Node3D.new()
	jumpscare_monster.name = "JumpscareMonster"
	jumpscare_monster.position = Vector3(0.0, 0.0, 2.2) # Прямо за спиной игрока!
	jumpscare_monster.visible = false
	add_child(jumpscare_monster)

	jumpscare_sprite = Sprite3D.new()
	jumpscare_sprite.texture = tex_m_front_walk_0 if tex_m_front_walk_0 else tex_m_front_idle
	jumpscare_sprite.pixel_size = 0.0035 # Огромный монстр прямо перед глазами
	jumpscare_sprite.position = Vector3(0, 1.25, 0)
	jumpscare_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	jumpscare_sprite.shaded = false
	jumpscare_monster.add_child(jumpscare_sprite)

	jumpscare_eye_light = OmniLight3D.new()
	jumpscare_eye_light.light_color = Color(1.0, 0.1, 0.05)
	jumpscare_eye_light.light_energy = 4.5
	jumpscare_eye_light.omni_range = 3.5
	jumpscare_eye_light.position = Vector3(0, 1.8, -0.3)
	jumpscare_monster.add_child(jumpscare_eye_light)

	jumpscare_flash = ColorRect.new()
	jumpscare_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	jumpscare_flash.color = Color(0.9, 0.05, 0.05, 0.0)
	jumpscare_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(jumpscare_flash)

func _trigger_jumpscare() -> void:
	is_jumpscare_active = true
	can_trigger_jumpscare = false
	jumpscare_timer = 0.0
	cam_trauma = 1.0

	if jumpscare_monster:
		jumpscare_monster.visible = true

	if jumpscare_audio and jumpscare_audio.stream:
		jumpscare_audio.play()

	if heartbeat_audio:
		heartbeat_audio.volume_db = 0.0

	if jumpscare_flash:
		var tw = create_tween()
		tw.tween_property(jumpscare_flash, "color:a", 0.55, 0.05)
		tw.tween_property(jumpscare_flash, "color:a", 0.0, 0.45)

func _update_jumpscare(delta: float) -> void:
	if is_jumpscare_active:
		jumpscare_timer += delta
		if jumpscare_timer > 1.2:
			is_jumpscare_active = false
			if jumpscare_monster:
				jumpscare_monster.visible = false
			jumpscare_cooldown = 12.0
	elif not can_trigger_jumpscare:
		jumpscare_cooldown -= delta
		if jumpscare_cooldown <= 0.0:
			can_trigger_jumpscare = true

# ──────────────────────────────────────────────────────────────────────────────
#  7. Аудио
# ──────────────────────────────────────────────────────────────────────────────
func _setup_audio() -> void:
	menu_music_player = AudioStreamPlayer.new()
	menu_music_player.name = "MenuMusic"
	var ost = _try_load_res("res://assets/dreamambient.mp3")
	if not ost:
		ost = _try_load_res("res://assets/ambient1.mp3")
	if not ost:
		ost = _try_load_res("res://assets/menu.mp3")
	if ost:
		if ost is AudioStreamMP3:
			(ost as AudioStreamMP3).loop = true
		menu_music_player.stream = ost
		menu_music_player.volume_db = -6.0
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

	jumpscare_audio = AudioStreamPlayer.new()
	var sc_snd = _try_load_res("res://assets/audio/skinwalker_scream.wav")
	if sc_snd:
		jumpscare_audio.stream = sc_snd
		jumpscare_audio.volume_db = 2.0
	add_child(jumpscare_audio)

	heartbeat_audio = AudioStreamPlayer.new()
	var hb_snd = _try_load_res("res://assets/heart.mp3")
	if hb_snd:
		if hb_snd is AudioStreamMP3:
			(hb_snd as AudioStreamMP3).loop = true
		heartbeat_audio.stream = hb_snd
		heartbeat_audio.volume_db = -80.0
		heartbeat_audio.autoplay = true
	add_child(heartbeat_audio)

func _try_load_res(p: String) -> Resource:
	if ResourceLoader.exists(p):
		return load(p)
	return null

# ──────────────────────────────────────────────────────────────────────────────
#  8. Пользовательский интерфейс (UI)
# ──────────────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	# Мягкое затемнение левой трети экрана под текст меню
	var left_shadow = TextureRect.new()
	left_shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad = Gradient.new()
	grad.set_color(0, Color(0.015, 0.02, 0.035, 0.88))
	grad.set_color(1, Color(0.015, 0.02, 0.035, 0.0))
	var gtex = GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.0, 0.5)
	gtex.fill_to = Vector2(0.55, 0.5)
	left_shadow.texture = gtex
	left_shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ui_root.add_child(left_shadow)

	# Главный контейнер меню
	var menu_margin = MarginContainer.new()
	menu_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_margin.add_theme_constant_override("margin_left", 60)
	menu_margin.add_theme_constant_override("margin_top", 50)
	menu_margin.add_theme_constant_override("margin_bottom", 60)
	ui_root.add_child(menu_margin)

	var main_vbox = VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_theme_constant_override("separation", 14)
	menu_margin.add_child(main_vbox)

	# Заголовок
	var title_lbl = Label.new()
	title_lbl.text = "SKINWALKER"
	title_lbl.add_theme_font_size_override("font_size", 54)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.65, 0.08, 0.08, 0.85))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	main_vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "ESCAPE · НЕ ДЫШИ В ЛЕСУ"
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(0.72, 0.22, 0.22))
	sub_lbl.add_theme_constant_override("line_spacing", 4)
	main_vbox.add_child(sub_lbl)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(260, 2)
	sep.color = Color(0.55, 0.15, 0.15, 0.6)
	main_vbox.add_child(sep)

	var spacer_top = Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 16)
	main_vbox.add_child(spacer_top)

	# Пункты меню
	banner_rects.clear()
	cursor_labels.clear()
	item_labels.clear()

	for idx in range(MENU_OPTIONS.size()):
		var opt_text = MENU_OPTIONS[idx]

		var row = Control.new()
		row.custom_minimum_size = Vector2(340, 52)
		main_vbox.add_child(row)

		# Плашка подсветки
		var banner = TextureRect.new()
		banner.set_anchors_preset(Control.PRESET_FULL_RECT)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.visible = false
		var b_grad = Gradient.new()
		b_grad.set_color(0, Color(0.85, 0.88, 0.95, 0.92))
		b_grad.set_color(1, Color(0.85, 0.88, 0.95, 0.0))
		var b_tex = GradientTexture2D.new()
		b_tex.gradient = b_grad
		b_tex.fill_from = Vector2(0.0, 0.5)
		b_tex.fill_to = Vector2(0.9, 0.5)
		banner.texture = b_tex
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		row.add_child(banner)
		banner_rects.append(banner)

		# Маркер стрелки
		var cursor = Label.new()
		cursor.text = "▶"
		cursor.position = Vector2(8, 12)
		cursor.add_theme_font_size_override("font_size", 18)
		cursor.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
		cursor.visible = false
		row.add_child(cursor)
		cursor_labels.append(cursor)

		# Текст пункта
		var item_lbl = Label.new()
		item_lbl.text = opt_text
		item_lbl.position = Vector2(36, 12)
		item_lbl.add_theme_font_size_override("font_size", 21)
		item_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
		item_lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
		item_lbl.add_theme_constant_override("shadow_offset_x", 2)
		item_lbl.add_theme_constant_override("shadow_offset_y", 2)
		row.add_child(item_lbl)
		item_labels.append(item_lbl)

		# Кнопка для мыши
		var btn = Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_entered.connect(func(): _on_item_hovered(idx))
		btn.pressed.connect(func(): _on_item_clicked(idx))
		row.add_child(btn)

	# Нижняя панель подсказок
	var bottom_bar = MarginContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_bar.add_theme_constant_override("margin_bottom", 16)
	bottom_bar.add_theme_constant_override("margin_left", 35)
	bottom_bar.add_theme_constant_override("margin_right", 35)
	ui_root.add_child(bottom_bar)

	var hint_hbox = HBoxContainer.new()
	bottom_bar.add_child(hint_hbox)

	var ver_lbl = Label.new()
	ver_lbl.text = "v1.2.0 • FOREST"
	ver_lbl.add_theme_font_size_override("font_size", 13)
	ver_lbl.add_theme_color_override("font_color", Color(0.70, 0.72, 0.78, 0.65))
	hint_hbox.add_child(ver_lbl)

	var spacer_b = Control.new()
	spacer_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_hbox.add_child(spacer_b)

	var hint_lbl = Label.new()
	hint_lbl.text = "[ПКМ] ОСМОТРЕТЬСЯ 360°     [W / S / МЫШЬ] ВЫБОР     [ENTER / ЛКМ] ПРИНЯТЬ"
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 0.75))
	hint_hbox.add_child(hint_lbl)

	_build_settings_modal()
	_build_chapters_modal()
	_build_credits_modal()

# ──────────────────────────────────────────────────────────────────────────────
#  9. Навигация и ввод
# ──────────────────────────────────────────────────────────────────────────────
func _update_selection(new_index: int, play_sound: bool = true) -> void:
	if is_modal_open:
		return
	selected_index = clampi(new_index, 0, MENU_OPTIONS.size() - 1)

	if play_sound and sfx_hover and sfx_hover.stream:
		sfx_hover.play()

	for i in range(MENU_OPTIONS.size()):
		var is_sel = (i == selected_index)
		banner_rects[i].visible = is_sel
		cursor_labels[i].visible = is_sel

		if is_sel:
			item_labels[i].add_theme_color_override("font_color", Color(0.08, 0.08, 0.12))
			item_labels[i].add_theme_color_override("font_shadow_color", Color(0.9, 0.9, 0.9, 0.3))
		else:
			item_labels[i].add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
			item_labels[i].add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))

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
		1: _show_modal(modal_chapters)
		2: _show_modal(modal_settings)
		3: _open_editor()
		4: _quit()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			is_rmb_dragging = event.pressed
			if is_rmb_dragging:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_rmb_dragging and event is InputEventMouseMotion:
		var sens = 0.0032
		cam_yaw -= event.relative.x * sens
		cam_pitch = clampf(cam_pitch - event.relative.y * sens, deg_to_rad(-35.0), deg_to_rad(45.0))
		if menu_camera:
			menu_camera.rotation = Vector3(cam_pitch, cam_yaw, 0.0)

		# Скример при повороте назад (угол > 125°)
		var angle_diff = wrapf(cam_yaw - cam_base_yaw, -PI, PI)
		if abs(angle_diff) > deg_to_rad(125.0) and can_trigger_jumpscare and not is_jumpscare_active:
			_trigger_jumpscare()
		return

	if is_modal_open:
		if event.is_action_pressed("ui_cancel"):
			_close_modals()
		return

	if event.is_action_pressed("ui_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		var next_idx = (selected_index - 1 + MENU_OPTIONS.size()) % MENU_OPTIONS.size()
		_update_selection(next_idx, true)
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and event.pressed and event.keycode == KEY_S):
		var next_idx = (selected_index + 1) % MENU_OPTIONS.size()
		_update_selection(next_idx, true)
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_ENTER):
		_execute_action(selected_index)

# ──────────────────────────────────────────────────────────────────────────────
#  10. Модальные окна (Настройки, Главы, Авторы)
# ──────────────────────────────────────────────────────────────────────────────
func _show_modal(m: Control) -> void:
	if not m:
		return
	is_modal_open = true
	m.visible = true

func _close_modals() -> void:
	is_modal_open = false
	if modal_settings: modal_settings.visible = false
	if modal_chapters: modal_chapters.visible = false
	if modal_credits:  modal_credits.visible = false

func _create_modal_base(title_text: String) -> Dictionary:
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.02, 0.03, 0.05, 0.88)
	overlay.visible = false
	ui_root.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 360)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.11, 0.95)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.45, 0.50, 0.58, 0.6)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	panel.add_child(vb)

	var tlbl = Label.new()
	tlbl.text = title_text
	tlbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tlbl.add_theme_font_size_override("font_size", 26)
	tlbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vb.add_child(tlbl)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.4, 0.45, 0.55, 0.5)
	vb.add_child(sep)

	return {"overlay": overlay, "vbox": vb}

func _build_settings_modal() -> void:
	var base = _create_modal_base("⚙ НАСТРОЙКИ")
	modal_settings = base["overlay"]
	var vb: VBoxContainer = base["vbox"]

	var vol_box = HBoxContainer.new()
	var vol_lbl = Label.new()
	vol_lbl.text = "Громкость звука:"
	vol_lbl.custom_minimum_size = Vector2(180, 0)
	vol_box.add_child(vol_lbl)

	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = 0.8
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.value_changed.connect(func(v): AudioServer.set_bus_volume_db(0, linear_to_db(v)))
	vol_box.add_child(vol_slider)
	vb.add_child(vol_box)

	var sens_box = HBoxContainer.new()
	var sens_lbl = Label.new()
	sens_lbl.text = "Чувствительность:"
	sens_lbl.custom_minimum_size = Vector2(180, 0)
	sens_box.add_child(sens_lbl)

	var sens_slider = HSlider.new()
	sens_slider.min_value = 0.5
	sens_slider.max_value = 2.5
	sens_slider.step = 0.1
	sens_slider.value = 1.0
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_box.add_child(sens_slider)
	vb.add_child(sens_box)

	var q_lbl = "💀 УЛЬТРА (UE5)"
	if GameManager:
		if GameManager.graphics_quality == "medium": q_lbl = "🔥 СРЕДНЯЯ"
		elif GameManager.graphics_quality == "low": q_lbl = "⚡ НИЗКАЯ"
	settings_btn_gfx = _create_dialog_btn("🖥 ГРАФИКА: " + q_lbl, _on_toggle_graphics_quality)
	vb.add_child(settings_btn_gfx)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vb.add_child(spacer)

	var btn_back = _create_dialog_btn("НАЗАД", _close_modals)
	vb.add_child(btn_back)

func _on_toggle_graphics_quality() -> void:
	if GameManager:
		var nq = GameManager.cycle_graphics_quality()
		_apply_menu_graphics(nq)
		var n_lbl = "💀 УЛЬТРА (UE5)"
		if nq == "medium": n_lbl = "🔥 СРЕДНЯЯ"
		elif nq == "low": n_lbl = "⚡ НИЗКАЯ"
		if is_instance_valid(settings_btn_gfx):
			settings_btn_gfx.text = "🖥 ГРАФИКА: " + n_lbl

func _build_chapters_modal() -> void:
	var base = _create_modal_base("📖 ВЫБОР ГЛАВЫ")
	modal_chapters = base["overlay"]
	var vb: VBoxContainer = base["vbox"]

	var ch1_box = HBoxContainer.new()
	var ch1_lbl = Label.new()
	ch1_lbl.text = "Глава 1: Ночь в хижине"
	ch1_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch1_box.add_child(ch1_lbl)

	var btn_ch1 = _create_dialog_btn("ИГРАТЬ", _start_game)
	btn_ch1.custom_minimum_size = Vector2(110, 36)
	ch1_box.add_child(btn_ch1)
	vb.add_child(ch1_box)

	var ch2_box = HBoxContainer.new()
	var ch2_lbl = Label.new()
	ch2_lbl.text = "Глава 2: Ночное шоссе"
	ch2_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ch2_box.add_child(ch2_lbl)

	var btn_ch2 = _create_dialog_btn("ИГРАТЬ", _start_chapter_2)
	btn_ch2.custom_minimum_size = Vector2(110, 36)
	ch2_box.add_child(btn_ch2)
	vb.add_child(ch2_box)

	var sep2 = ColorRect.new()
	sep2.custom_minimum_size = Vector2(0, 1)
	sep2.color = Color(0.3, 0.35, 0.45, 0.4)
	vb.add_child(sep2)

	var btn_editor = _create_dialog_btn("🛠 РЕДАКТОР КАРТ", _open_editor)
	vb.add_child(btn_editor)

	var btn_back = _create_dialog_btn("НАЗАД", _close_modals)
	vb.add_child(btn_back)

func _build_credits_modal() -> void:
	var base = _create_modal_base("🎬 АВТОРЫ")
	modal_credits = base["overlay"]
	var vb: VBoxContainer = base["vbox"]

	var cr_lbl = Label.new()
	cr_lbl.text = "ESCAPE IN SKINWALKER\n\nРазработка и ИИ: Antigravity AI & Team\nДвижок: Godot Engine 4.x\nЗвуки и Музыка: Escape in Skinwalker OST\n\nСпасибо за игру!"
	cr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_lbl.add_theme_font_size_override("font_size", 14)
	cr_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.94))
	vb.add_child(cr_lbl)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer)

	var btn_back = _create_dialog_btn("НАЗАД", _close_modals)
	vb.add_child(btn_back)

func _create_dialog_btn(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 15)

	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.18, 0.22, 0.28)
	sn.corner_radius_top_left = 4
	sn.corner_radius_top_right = 4
	sn.corner_radius_bottom_left = 4
	sn.corner_radius_bottom_right = 4

	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.30, 0.36, 0.46)
	sh.corner_radius_top_left = 4
	sh.corner_radius_top_right = 4
	sh.corner_radius_bottom_left = 4
	sh.corner_radius_bottom_right = 4

	b.add_theme_stylebox_override("normal", sn)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sh)
	b.pressed.connect(cb)
	return b

# ──────────────────────────────────────────────────────────────────────────────
#  11. Главный цикл процесса меню
# ──────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	elapsed_time += delta

	# Дрейф ночных облаков
	for c in moon_clouds:
		if is_instance_valid(c):
			var spd = c.get_meta("drift_speed", 0.5)
			c.position.x += spd * delta
			if c.position.x > 50.0:
				c.position.x = -50.0

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

	# Движение и живое дыхание камеры
	if menu_camera:
		var cam_sway_x = sin(elapsed_time * 0.65) * 0.015
		var cam_sway_y = cos(elapsed_time * 0.95) * 0.012
		menu_camera.position = cam_base_pos + Vector3(cam_sway_x, cam_sway_y, 0.0) + shake_offset

		if not is_rmb_dragging:
			menu_camera.rotation = Vector3(
				cam_pitch + sin(elapsed_time * 0.8) * 0.003,
				cam_yaw + cos(elapsed_time * 0.6) * 0.003,
				0.0
			)

	# Мерцание брошенного фонарика в лесу
	if dropped_flashlight and is_instance_valid(dropped_flashlight):
		var n_flicker = sin(elapsed_time * 11.0) * cos(elapsed_time * 17.3)
		if n_flicker > 0.92:
			dropped_flashlight.light_energy = randf_range(1.5, 3.5)
		else:
			dropped_flashlight.light_energy = 5.2

	# Обновление перемещающегося монстра в лесу
	_update_forest_monster(delta)

	# Обновление скримера
	_update_jumpscare(delta)

# ──────────────────────────────────────────────────────────────────────────────
#  12. Переходы между сценами
# ──────────────────────────────────────────────────────────────────────────────
func _start_game() -> void:
	if GameManager:
		GameManager.active_map_path = "res://scenes/Карта_6.json"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _start_chapter_2() -> void:
	get_tree().change_scene_to_file("res://scenes/Street.tscn")

func _open_editor() -> void:
	get_tree().change_scene_to_file("res://scenes/DebugEditor.tscn")

func _quit() -> void:
	get_tree().quit()
'''

with open(GAME + r'\scripts\Menu.gd', 'w', encoding='utf-8') as f:
    f.write(menu_code)

print("✅ Forest Menu.gd written successfully!")
