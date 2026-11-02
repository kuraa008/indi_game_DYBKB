extends Node3D

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
var is_modal_open:            bool = false
var settings_btn_gfx:         Button = null
var settings_btn_vhs: Button = null
var settings_btn_dyn: Button = null
var settings_btn_legacy:      Button = null

var elapsed_time:             float = 0.0

const MENU_OPTIONS = [
	"ИГРАТЬ",
	"НАСТРОЙКИ",
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
	world_env.ambient_light_sky_contribution = 0.0

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
	world_env.ambient_light_color = Color(0.025, 0.035, 0.055)
	world_env.ambient_light_energy = 0.60
	match quality:
		"ultra", "high":
			world_env.ambient_light_color = Color(0.25, 0.32, 0.46)
			world_env.ambient_light_energy = 0.55
			world_env.ssao_enabled = true
			world_env.ssao_radius = 0.75
			world_env.ssao_intensity = 1.05
			world_env.ssao_power = 1.0
			world_env.ssil_enabled = true
			world_env.ssil_radius = 2.5
			world_env.ssil_intensity = 1.0
			world_env.ssr_enabled = true
			world_env.glow_enabled = true
			world_env.glow_bloom = 0.06
			world_env.glow_intensity = 0.55
			world_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			world_env.sdfgi_enabled = false
			world_env.volumetric_fog_enabled = true
			world_env.volumetric_fog_density = 0.007
			world_env.volumetric_fog_albedo = Color(0.42, 0.50, 0.62)
			world_env.volumetric_fog_anisotropy = 0.40
			world_env.volumetric_fog_temporal_reprojection_enabled = true
			world_env.tonemap_mode = Environment.TONE_MAPPER_ACES
			world_env.tonemap_exposure = 1.20
			world_env.tonemap_white = 6.0
			world_env.adjustment_enabled = true
			world_env.adjustment_contrast = 1.04
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
	_build_menu_road(forest_root)

	# 2. Деревья леса вокруг поляны (360 градусов)
	# Кольцо 1 — ближние деревья вокруг поляны (6 - 13м)
	var inner_trees = [
		Vector3(-10.0, 0, -7.0),  Vector3(10.0, 0, -8.0),
		Vector3(-11.0, 0, -14.0), Vector3(11.0, 0, -15.0),
		Vector3(-12.0, 0, -22.0), Vector3(12.0, 0, -23.0),
		Vector3(-9.5, 0, -31.0),  Vector3(9.5, 0, -32.0),
		Vector3(-13.0, 0, -40.0), Vector3(13.0, 0, -41.0),
		Vector3(-10.5, 0, -50.0), Vector3(10.5, 0, -51.0),
		Vector3(-15.0, 0,  3.0),  Vector3(15.0, 0,  2.0),
		Vector3(-17.0, 0, -60.0), Vector3(17.0, 0, -61.0),
		Vector3(-20.0, 0, -30.0), Vector3(20.0, 0, -31.0),
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
		var side = -1.0 if randf() < 0.5 else 1.0
		var px = side * randf_range(10.0, 43.0)
		var pz = randf_range(-72.0, 24.0)
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
		bush.position = Vector3(signf(b_pos.x) * (9.0 + absf(b_pos.x) * 0.35), b_pos.y, b_pos.z - 4.0)
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
	log_mesh.position = Vector3(-9.5, 0.25, -4.8)
	log_mesh.rotation_degrees = Vector3(0, 35, 88)
	forest_root.add_child(log_mesh)

	# Мшистые камни
	for r_pos in [Vector3(-9.0, 0.4, -4.2), Vector3(10.0, 0.5, -7.5), Vector3(-11.5, 0.6, -11.0)]:
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
func _build_menu_road(parent: Node3D) -> void:
	var road = MeshInstance3D.new()
	road.name = "MoonlitForestRoad"
	var road_mesh = PlaneMesh.new()
	road_mesh.size = Vector2(14.0, 100.0)
	var road_mat = StandardMaterial3D.new()
	road_mat.albedo_texture = TextureHelper.get_texture("res://assets/textures/highway_asphalt.png")
	road_mat.albedo_color = Color(0.32, 0.36, 0.44)
	road_mat.roughness = 0.92
	road_mat.metallic = 0.04
	road_mat.uv1_scale = Vector3(1.0, 7.0, 1.0)
	road_mesh.material = road_mat
	road.mesh = road_mesh
	road.position = Vector3(0.0, 0.018, -38.0)
	parent.add_child(road)

	var marking_mat = StandardMaterial3D.new()
	marking_mat.albedo_color = Color(0.72, 0.76, 0.82)
	marking_mat.roughness = 0.82
	for side in [-1.0, 1.0]:
		var edge_line = MeshInstance3D.new()
		var edge_mesh = BoxMesh.new()
		edge_mesh.size = Vector3(0.13, 0.025, 92.0)
		edge_mesh.material = marking_mat
		edge_line.mesh = edge_mesh
		edge_line.position = Vector3(side * 6.25, 0.045, -38.0)
		parent.add_child(edge_line)

	for z in range(-5, -69, -8):
		var dash = MeshInstance3D.new()
		var dash_mesh = BoxMesh.new()
		dash_mesh.size = Vector3(0.12, 0.025, 3.1)
		dash_mesh.material = marking_mat
		dash.mesh = dash_mesh
		dash.position = Vector3(0.0, 0.045, float(z))
		parent.add_child(dash)

	var pole_mat = StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.13, 0.16, 0.21)
	pole_mat.metallic = 0.72
	pole_mat.roughness = 0.38
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_mat.albedo_color = Color(1.0, 0.78, 0.52)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.48, 0.20)
	lamp_mat.emission_energy_multiplier = 2.2
	for z in [-9.0, -22.0, -35.0, -48.0, -61.0]:
		for side in [-1.0, 1.0]:
			var lamp_root = Node3D.new()
			lamp_root.position = Vector3(side * 8.0, 0.0, z)
			parent.add_child(lamp_root)

			var pole = MeshInstance3D.new()
			var pole_mesh = BoxMesh.new()
			pole_mesh.size = Vector3(0.18, 7.2, 0.18)
			pole_mesh.material = pole_mat
			pole.mesh = pole_mesh
			pole.position.y = 3.6
			lamp_root.add_child(pole)

			var arm = MeshInstance3D.new()
			var arm_mesh = BoxMesh.new()
			arm_mesh.size = Vector3(1.7, 0.16, 0.19)
			arm_mesh.material = pole_mat
			arm.mesh = arm_mesh
			arm.position = Vector3(-side * 0.68, 7.0, 0.0)
			lamp_root.add_child(arm)

			var bulb = MeshInstance3D.new()
			var bulb_mesh = BoxMesh.new()
			bulb_mesh.size = Vector3(0.48, 0.1, 0.35)
			bulb_mesh.material = lamp_mat
			bulb.mesh = bulb_mesh
			bulb.position = Vector3(-side * 1.42, 6.88, 0.0)
			lamp_root.add_child(bulb)

			var pool = SpotLight3D.new()
			pool.light_color = Color(1.0, 0.66, 0.38)
			pool.light_energy = 2.1
			pool.spot_range = 12.0
			pool.spot_angle = 62.0
			pool.spot_attenuation = 1.25
			pool.shadow_enabled = z == -9.0 and side < 0.0
			pool.position = Vector3(-side * 1.42, 6.7, 0.0)
			pool.rotation_degrees.x = -90.0
			lamp_root.add_child(pool)

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

	jumpscare_audio = AudioStreamPlayer.new()
	var sc_snd = _try_load_res("res://assets/scream.mp3")
	if not sc_snd:
		sc_snd = _try_load_res("res://assets/audio/skinwalker_scream.wav")
	if sc_snd:
		jumpscare_audio.stream = sc_snd
		jumpscare_audio.volume_db = 4.0
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

	# Subtle found-footage grain over the menu camera.
	var film_overlay = TextureRect.new()
	film_overlay.name = "FilmGrainOverlay"
	film_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	film_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film_overlay.texture = TextureHelper.get_texture("res://assets/textures/ui/horror_film_grunge_overlay.png")
	film_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	film_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	film_overlay.modulate = Color(0.72, 0.78, 0.88, 0.18)
	ui_root.add_child(film_overlay)

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
	var menu_margin = Control.new()
	menu_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(menu_margin)

	# Small surveillance readout makes the forest feel like a captured scene.
	var feed_panel = PanelContainer.new()
	feed_panel.name = "CameraFeedLabel"
	feed_panel.visible = false
	feed_panel.anchor_left = 1.0
	feed_panel.anchor_right = 1.0
	feed_panel.offset_left = -250.0
	feed_panel.offset_right = -36.0
	feed_panel.offset_top = 34.0
	feed_panel.offset_bottom = 78.0
	feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var feed_style = StyleBoxFlat.new()
	feed_style.bg_color = Color(0.015, 0.022, 0.03, 0.68)
	feed_style.border_color = Color(0.55, 0.10, 0.10, 0.52)
	feed_style.set_border_width_all(1)
	feed_style.content_margin_left = 12.0
	feed_style.content_margin_right = 12.0
	feed_style.content_margin_top = 7.0
	feed_style.content_margin_bottom = 7.0
	feed_panel.add_theme_stylebox_override("panel", feed_style)
	var feed_row = HBoxContainer.new()
	feed_row.add_theme_constant_override("separation", 8)
	feed_panel.add_child(feed_row)
	var rec_dot = ColorRect.new()
	rec_dot.custom_minimum_size = Vector2(8, 8)
	rec_dot.color = Color(0.88, 0.12, 0.10)
	rec_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	feed_row.add_child(rec_dot)
	var feed_label = Label.new()
	feed_label.text = "REC   //   ЛЕСНАЯ КАМЕРА 04"
	feed_label.add_theme_font_size_override("font_size", 12)
	feed_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88, 0.92))
	feed_row.add_child(feed_label)
	ui_root.add_child(feed_panel)

	var main_vbox = VBoxContainer.new()
	main_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	main_vbox.offset_left = 60.0
	main_vbox.offset_top = -92.0
	main_vbox.offset_right = 400.0
	main_vbox.offset_bottom = 92.0
	main_vbox.custom_minimum_size = Vector2(340, 184)
	main_vbox.add_theme_constant_override("separation", 14)
	menu_margin.add_child(main_vbox)

	# Заголовок
	var title_lbl = Label.new()
	title_lbl.text = "SKINWALKER"
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.96, 0.96, 0.98))
	title_lbl.add_theme_color_override("font_shadow_color", Color(0.65, 0.08, 0.08, 0.85))
	title_lbl.add_theme_constant_override("shadow_offset_x", 3)
	title_lbl.add_theme_constant_override("shadow_offset_y", 3)
	title_lbl.visible = false
	main_vbox.add_child(title_lbl)

	var sub_lbl = Label.new()
	sub_lbl.text = "ESCAPE · НЕ ДЫШИ В ЛЕСУ"
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", Color(0.72, 0.22, 0.22))
	sub_lbl.add_theme_constant_override("line_spacing", 4)
	sub_lbl.visible = false
	main_vbox.add_child(sub_lbl)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(260, 2)
	sep.color = Color(0.55, 0.15, 0.15, 0.6)
	sep.visible = false
	main_vbox.add_child(sep)

	var spacer_top = Control.new()
	spacer_top.custom_minimum_size = Vector2(0, 0)
	main_vbox.add_child(spacer_top)

	# Пункты меню
	banner_rects.clear()
	cursor_labels.clear()
	item_labels.clear()

	for idx in range(MENU_OPTIONS.size()):
		var opt_text = MENU_OPTIONS[idx]

		var row = Control.new()
		row.custom_minimum_size = Vector2(340, 52)
		row.size_flags_horizontal = Control.SIZE_FILL
		row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		main_vbox.add_child(row)

		# Плашка подсветки
		var banner = TextureRect.new()
		banner.set_anchors_preset(Control.PRESET_FULL_RECT)
		banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		banner.visible = false
		banner.texture = TextureHelper.get_texture("res://assets/textures/ui/menu_brush_banner.png")
		banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		banner.stretch_mode = TextureRect.STRETCH_SCALE
		row.add_child(banner)
		banner_rects.append(banner)

		# Маркер стрелки
		var cursor = Label.new()
		cursor.text = "▶"
		cursor.position = Vector2(8, 12)
		cursor.add_theme_font_size_override("font_size", 18)
		cursor.add_theme_color_override("font_color", Color(0.06, 0.07, 0.09))
		cursor.visible = false
		row.add_child(cursor)
		cursor_labels.append(cursor)

		# Текст пункта
		var item_lbl = Label.new()
		item_lbl.text = opt_text
		item_lbl.position = Vector2(36, 12)
		item_lbl.add_theme_font_size_override("font_size", 22)
		item_lbl.add_theme_color_override("font_color", Color(0.48, 0.49, 0.53))
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

	_build_settings_modal()

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
			item_labels[i].add_theme_color_override("font_color", Color(0.06, 0.07, 0.09))
			item_labels[i].add_theme_color_override("font_shadow_color", Color(0.9, 0.9, 0.9, 0.3))
		else:
			item_labels[i].add_theme_color_override("font_color", Color(0.48, 0.49, 0.53))
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
		1: _show_modal(modal_settings)
		2: _quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_7:
		get_tree().change_scene_to_file("res://scenes/DebugEditor.tscn")
		return

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
#  10. Модальное окно настроек
# ──────────────────────────────────────────────────────────────────────────────
func _show_modal(m: Control) -> void:
	if not m:
		return
	is_modal_open = true
	m.visible = true

func _close_modals() -> void:
	is_modal_open = false
	if modal_settings: modal_settings.visible = false

func _create_modal_base(title_text: String) -> Dictionary:
	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.012, 0.015, 0.022, 0.92)
	overlay.visible = false
	ui_root.add_child(overlay)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 420)
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.045, 0.055, 0.97)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.52, 0.14, 0.14, 0.85)
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)

	# VCR Header Row
	var header_row = HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	header_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(header_row)

	var rec_dot = ColorRect.new()
	rec_dot.custom_minimum_size = Vector2(10, 10)
	rec_dot.color = Color(0.88, 0.12, 0.10)
	rec_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_row.add_child(rec_dot)

	var tlbl = Label.new()
	tlbl.text = "[ %s // СИСТЕМА ]" % title_text.to_upper()
	tlbl.add_theme_font_size_override("font_size", 20)
	tlbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	tlbl.add_theme_color_override("font_shadow_color", Color(0.65, 0.08, 0.08, 0.85))
	tlbl.add_theme_constant_override("shadow_offset_x", 2)
	tlbl.add_theme_constant_override("shadow_offset_y", 2)
	header_row.add_child(tlbl)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0.65, 0.15, 0.15, 0.8)
	vb.add_child(sep)

	return {"overlay": overlay, "vbox": vb}

func _build_settings_modal() -> void:
	var base = _create_modal_base("НАСТРОЙКИ")
	modal_settings = base["overlay"]
	var vb: VBoxContainer = base["vbox"]

	# Звук
	var vol_box = HBoxContainer.new()
	vol_box.add_theme_constant_override("separation", 10)
	var vol_lbl = Label.new()
	vol_lbl.text = "ГРОМКОСТЬ ЗВУКА:"
	vol_lbl.custom_minimum_size = Vector2(210, 0)
	vol_lbl.add_theme_font_size_override("font_size", 15)
	vol_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	vol_box.add_child(vol_lbl)

	var vol_val = Label.new()
	vol_val.text = "80%"
	vol_val.custom_minimum_size = Vector2(45, 0)
	vol_val.add_theme_font_size_override("font_size", 14)
	vol_val.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))

	var vol_slider = HSlider.new()
	vol_slider.min_value = 0.0
	vol_slider.max_value = 1.0
	vol_slider.step = 0.05
	vol_slider.value = 0.8
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.value_changed.connect(func(v):
		AudioServer.set_bus_volume_db(0, linear_to_db(v))
		vol_val.text = "%d%%" % int(v * 100)
	)
	vol_slider.mouse_entered.connect(func():
		if sfx_hover and sfx_hover.stream: sfx_hover.play()
	)
	vol_box.add_child(vol_slider)
	vol_box.add_child(vol_val)
	vb.add_child(vol_box)

	# Чувствительность мыши
	var sens_box = HBoxContainer.new()
	sens_box.add_theme_constant_override("separation", 10)
	var sens_lbl = Label.new()
	sens_lbl.text = "ЧУВСТВИТЕЛЬНОСТЬ:"
	sens_lbl.custom_minimum_size = Vector2(210, 0)
	sens_lbl.add_theme_font_size_override("font_size", 15)
	sens_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.88))
	sens_box.add_child(sens_lbl)

	var sens_val = Label.new()
	sens_val.text = "1.0x"
	sens_val.custom_minimum_size = Vector2(45, 0)
	sens_val.add_theme_font_size_override("font_size", 14)
	sens_val.add_theme_color_override("font_color", Color(0.9, 0.35, 0.35))

	var sens_slider = HSlider.new()
	sens_slider.min_value = 0.5
	sens_slider.max_value = 2.5
	sens_slider.step = 0.1
	sens_slider.value = 1.0
	sens_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_slider.value_changed.connect(func(v):
		sens_val.text = "%.1fx" % v
	)
	sens_slider.mouse_entered.connect(func():
		if sfx_hover and sfx_hover.stream: sfx_hover.play()
	)
	sens_box.add_child(sens_slider)
	sens_box.add_child(sens_val)
	vb.add_child(sens_box)

	# Пресет графики
	var q_lbl = "УЛЬТРА (UE5)"
	if GameManager:
		if GameManager.graphics_quality == "high": q_lbl = "ВЫСОКАЯ"
		elif GameManager.graphics_quality == "medium": q_lbl = "СРЕДНЯЯ"
		elif GameManager.graphics_quality == "low": q_lbl = "НИЗКАЯ"
	settings_btn_gfx = _create_dialog_btn("ГРАФИКА: " + q_lbl, _on_toggle_graphics_quality)
	vb.add_child(settings_btn_gfx)

	# Эффект VHS-записи и динамическое разрешение
	settings_btn_vhs = _create_dialog_btn(_vhs_btn_text(), _on_toggle_vhs)
	vb.add_child(settings_btn_vhs)
	settings_btn_dyn = _create_dialog_btn(_dyn_btn_text(), _on_toggle_dynamic_res)
	vb.add_child(settings_btn_dyn)

	# Режим графики: Реализм vs Legacy
	var leg_lbl = "РЕАЛИЗМ (ALPHA 1)"
	if GameManager and GameManager.is_legacy_graphics:
		leg_lbl = "LEGACY RETRO (0.1)"
	settings_btn_legacy = _create_dialog_btn("РЕЖИМ МОДЕЛЕЙ: " + leg_lbl, _on_toggle_legacy_graphics)
	vb.add_child(settings_btn_legacy)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vb.add_child(spacer)

	var btn_back = _create_dialog_btn("◀  НАЗАД В МЕНЮ", _close_modals)
	vb.add_child(btn_back)

func _vhs_btn_text() -> String:
	return "ЭФФЕКТ VHS: " + ("ВКЛ" if GameManager.vhs_enabled else "ВЫКЛ")

func _dyn_btn_text() -> String:
	return "АВТО-РАЗРЕШЕНИЕ: " + ("ВКЛ" if GameManager.dynamic_resolution else "ВЫКЛ")

func _on_toggle_vhs() -> void:
	GameManager.set_vhs_enabled(not GameManager.vhs_enabled)
	if is_instance_valid(settings_btn_vhs):
		settings_btn_vhs.text = _vhs_btn_text()

func _on_toggle_dynamic_res() -> void:
	GameManager.set_dynamic_resolution(not GameManager.dynamic_resolution)
	if is_instance_valid(settings_btn_dyn):
		settings_btn_dyn.text = _dyn_btn_text()

func _on_toggle_graphics_quality() -> void:
	if GameManager:
		var nq = GameManager.cycle_graphics_quality()
		_apply_menu_graphics(nq)
		var n_lbl = "УЛЬТРА (UE5)"
		if nq == "high": n_lbl = "ВЫСОКАЯ"
		elif nq == "medium": n_lbl = "СРЕДНЯЯ"
		elif nq == "low": n_lbl = "НИЗКАЯ"
		if is_instance_valid(settings_btn_gfx):
			settings_btn_gfx.text = "ГРАФИКА: " + n_lbl

func _on_toggle_legacy_graphics() -> void:
	if GameManager:
		var is_leg = GameManager.toggle_legacy_graphics()
		var leg_lbl = "LEGACY RETRO (0.1)" if is_leg else "РЕАЛИЗМ (ALPHA 1)"
		if is_instance_valid(settings_btn_legacy):
			settings_btn_legacy.text = "РЕЖИМ МОДЕЛЕЙ: " + leg_lbl

func _create_dialog_btn(text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.85, 0.86, 0.90))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.96))
	b.add_theme_color_override("font_pressed_color", Color(1.0, 0.8, 0.8))

	var sn = StyleBoxFlat.new()
	sn.bg_color = Color(0.08, 0.09, 0.11, 0.95)
	sn.border_width_left = 1
	sn.border_width_right = 1
	sn.border_width_top = 1
	sn.border_width_bottom = 1
	sn.border_color = Color(0.35, 0.20, 0.20, 0.7)
	sn.corner_radius_top_left = 2
	sn.corner_radius_top_right = 2
	sn.corner_radius_bottom_left = 2
	sn.corner_radius_bottom_right = 2
	sn.set_content_margin_all(8)

	var sh = StyleBoxFlat.new()
	sh.bg_color = Color(0.24, 0.07, 0.07, 0.98)
	sh.border_width_left = 2
	sh.border_width_right = 2
	sh.border_width_top = 2
	sh.border_width_bottom = 2
	sh.border_color = Color(0.88, 0.22, 0.18, 0.95)
	sh.corner_radius_top_left = 2
	sh.corner_radius_top_right = 2
	sh.corner_radius_bottom_left = 2
	sh.corner_radius_bottom_right = 2
	sh.set_content_margin_all(8)

	var sp = StyleBoxFlat.new()
	sp.bg_color = Color(0.38, 0.10, 0.10, 1.0)
	sp.border_width_left = 2
	sp.border_width_right = 2
	sp.border_width_top = 2
	sp.border_width_bottom = 2
	sp.border_color = Color(1.0, 0.35, 0.30, 1.0)
	sp.corner_radius_top_left = 2
	sp.corner_radius_top_right = 2
	sp.corner_radius_bottom_left = 2
	sp.corner_radius_bottom_right = 2
	sp.set_content_margin_all(8)

	b.add_theme_stylebox_override("normal", sn)
	b.add_theme_stylebox_override("hover", sh)
	b.add_theme_stylebox_override("pressed", sp)
	b.add_theme_stylebox_override("focus", sh)
	b.mouse_entered.connect(func():
		if sfx_hover and sfx_hover.stream:
			sfx_hover.play()
	)
	b.pressed.connect(func():
		if sfx_select and sfx_select.stream:
			sfx_select.play()
		cb.call()
	)
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
		GameManager.intro_cutscene_played = true
		GameManager.active_map_path = "res://scenes/1level.json"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _quit() -> void:
	get_tree().quit()
