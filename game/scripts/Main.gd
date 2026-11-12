extends Node3D

const TextureHelper = preload("res://scripts/TextureHelper.gd")
const ParallaxHorizon = preload("res://scripts/ParallaxHorizon.gd")

# ══════════════════════════════════════════════
#  Main.gd — сборщик сцены
#  Все параметры можно менять в редакторе (Inspector)
# ══════════════════════════════════════════════

# ─────────────────────────────────────────────
#  @export — меняй в Godot Inspector на сцене Main.tscn
# ─────────────────────────────────────────────
@export_group("Карта")
@export var wall_height:     float   = 3.6   ## Высота стен (метры)
@export var map_json_path:   String  = "res://scenes/Карта_6.json"

@export_group("Спавн")
@export var player_spawn:  Vector3 = Vector3(-9.0, 0.0, -13.0)
@export var enemy_spawn:   Vector3 = Vector3(9.5,  0.0,  -1.5)
@export var lumberjack_spawn: Vector3 = Vector3(-2.0, 0.0, 1.0)
@export var crowbar_pos:   Vector3 = Vector3(-4.5, 0.5, -15.0)
@export var key_pos:       Vector3 = Vector3(7.0,  0.5,   6.5)

@export_group("Атмосфера")
@export_range(0.0, 0.03, 0.001) var fog_density:   float = 0.003
@export_range(0.5, 3.0,  0.1)   var ambient_energy: float = 1.3
@export_range(0.0, 2.0,  0.1)   var sun_energy:     float = 1.0

# ─────────────────────────────────────────────
#  Внутренние ссылки
# ─────────────────────────────────────────────
var nav_region: NavigationRegion3D   # вся геометрия внутри
var navigation_bounds := AABB()
var navigation_bounds_valid := false
var navigation_async_region := true
var navigation_async_map := true
var outdoor_ambient_player: AudioStreamPlayer = null
var house_ambient_player: AudioStreamPlayer = null
var world_env_node: WorldEnvironment = null
var moon_light: DirectionalLight3D = null
var moon_clouds: Array[Node3D] = []
var stars_node: MultiMeshInstance3D = null
var door_configured_key_color: String = "gold"
var door_configured_requires_power: bool = false
var door_configured_requires_boards: bool = true
var door_configured_texture: String = "door_dark_oak"
var door_configured_rot: Vector3 = Vector3.ZERO
var door_configured_sz: Vector3 = Vector3(1.02, 2.15, 0.15)
var door_configured_lock_id: int = 0
var has_exit_door_spawned: bool = false
var has_enemy_spawn: bool = false
var has_lumberjack_spawn: bool = false
var highway_map: bool = false
var highway_trees: Array = []

# ══════════════════════════════════════════════
func _ready() -> void:
	if GameManager and GameManager.active_map_path != "":
		map_json_path = GameManager.active_map_path
	# После пролога старая карта больше не нужна: Итан очнётся в подвале дома отца
	if GameManager and GameManager.wake_in_basement and "1level" in map_json_path.to_lower():
		map_json_path = "res://scenes/Шоссе.json"
		GameManager.active_map_path = map_json_path

	GameManager.reset_state()
	# На «Шоссе» и во дворе остаются прежние текстуры
	TextureHelper.upgrades_on = not _is_highway()
	_setup_world()

	_setup_nav_region()
	_load_map()
	_setup_house_switches_and_lights()
	var kit := preload("res://scripts/ApartmentKit.gd")
	kit.cache_begin("%s_%s" % [map_json_path, GameManager.wake_in_basement])
	_spawn_player()
	kit.cache_end()
	if has_enemy_spawn:
		_spawn_enemy()
	if has_lumberjack_spawn:
		_spawn_lumberjack()
	_spawn_items()
	_setup_door()
	_setup_audio()
	_setup_ui()
	_setup_missions()
	# Выпекаем навмеш с открытыми дверными проёмами
	await get_tree().physics_frame
	_bake_nav_mesh()
	# Сетка считается в фоне. Враги начинают ходить, когда она готова
	await nav_region.bake_finished
	nav_region.navigation_mesh = nav_region.navigation_mesh
	# Wait for actual geometry, not just the initial empty map iteration.
	var nav_map := nav_region.get_navigation_map()
	for i in range(120):
		await get_tree().physics_frame
		if NavigationServer3D.region_get_bounds(nav_region.get_rid()).size.length_squared() > 1.0 and NavigationServer3D.map_get_iteration_id(nav_map) > 0:
			break
	NavigationServer3D.region_set_use_async_iterations(nav_region.get_rid(), navigation_async_region)
	NavigationServer3D.map_set_use_async_iterations(nav_map, navigation_async_map)
	var enemy: Variant = GameManager.enemy_ref
	if is_instance_valid(enemy):
		enemy.set_physics_process(true)
	var lj: Variant = GameManager.lumberjack_ref
	if is_instance_valid(lj):
		lj.set_physics_process(true)

	if GameManager:
		GameManager.graphics_quality_changed.connect(_apply_graphics_quality)

func _process(delta: float) -> void:
	# Купол ночных звезд следует за игроком
	if stars_node and is_instance_valid(stars_node):
		var cam = get_viewport().get_camera_3d()
		if cam and is_instance_valid(cam):
			stars_node.global_position = cam.global_position

	# Дрейф туч в ночном небе
	for c in moon_clouds:
		if is_instance_valid(c):
			var spd = c.get_meta("drift_speed", 0.5)
			c.position.x += spd * delta
			if c.position.x > 80.0:
				c.position.x = -80.0

# ══════════════════════════════════════════════
#  Освещение, ночной небосвод и графика
# ══════════════════════════════════════════════
func _setup_world() -> void:
	world_env_node = WorldEnvironment.new()
	var env: Environment = null
	if ResourceLoader.exists("res://assets/night_env.tres"):
		env = load("res://assets/night_env.tres").duplicate()
	if not env:
		env = Environment.new()
		env.background_mode = Environment.BG_SKY
		var sky = Sky.new()
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.015, 0.02, 0.04)
		sky_mat.sky_horizon_color = Color(0.05, 0.07, 0.13)
		sky_mat.ground_bottom_color = Color(0.008, 0.01, 0.018)
		sky_mat.ground_horizon_color = Color(0.04, 0.065, 0.12)
		sky_mat.sun_angle_max = 0.0
		sky.sky_material = sky_mat
		env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.03, 0.04, 0.08)
	env.ambient_light_energy = 0.28
	env.ambient_light_sky_contribution = 0.0
	env.fog_enabled          = true
	env.fog_light_color      = Color(0.035, 0.05, 0.09)
	env.fog_density          = 0.0025
	world_env_node.environment = env
	add_child(world_env_node)

	_build_sky_and_moon()
	_apply_graphics_quality(GameManager.graphics_quality)

	# Красный ориентир у двери
	var door_light = OmniLight3D.new()
	door_light.name         = "door_light"
	door_light.position     = Vector3(-0.9, 1.8, 10.0)
	door_light.light_color  = Color(1.0, 0.04, 0.0)
	door_light.light_energy = 3.5
	door_light.omni_range   = 7.0
	add_child(door_light)

	# Очень слабый синеватый свет в подвале (спавн игрока)
	var base_light = OmniLight3D.new()
	base_light.name         = "base_light"
	base_light.position     = Vector3(-9, 2.0, -13)
	base_light.light_color  = Color(0.2, 0.25, 0.5)
	base_light.light_energy = 0.6
	base_light.omni_range   = 6.0
	add_child(base_light)

func _build_sky_and_moon() -> void:
	var sky_root = Node3D.new()
	sky_root.name = "SkyElements"
	add_child(sky_root)

	# 1. Текстурированная полная Луна (SphereMesh с moon_surface.png)
	var moon_pos = Vector3(18.0, 48.0, -75.0)
	var moon_mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 5.2
	sphere.height = 10.4
	var moon_mat = StandardMaterial3D.new()
	var moon_tex = TextureHelper.get_texture("res://assets/textures/moon_surface.png")
	if moon_tex:
		moon_mat.albedo_texture = moon_tex
		moon_mat.roughness = 0.8
		moon_mat.emission_enabled = true
		moon_mat.emission_texture = moon_tex
		moon_mat.emission = Color(0.88, 0.94, 1.0)
		moon_mat.emission_energy_multiplier = 0.7
	else:
		moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_mat.albedo_color = Color(0.92, 0.95, 1.0)
	sphere.surface_set_material(0, moon_mat)
	moon_mesh_inst.mesh = sphere
	moon_mesh_inst.position = moon_pos
	moon_mesh_inst.rotation_degrees = Vector3(15, -35, 10)
	sky_root.add_child(moon_mesh_inst)

	# 2. Ореол свечения вокруг луны
	var glow_tex = TextureHelper.get_texture("res://assets/textures/moon_glow.png")

	# Внутренний ореол
	var halo = MeshInstance3D.new()
	var hm = QuadMesh.new()
	hm.size = Vector2(28.0, 28.0)
	var hmat = StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow_tex:
		hmat.albedo_texture = glow_tex
		hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hmat.albedo_color = Color(0.70, 0.84, 1.0, 0.7)
	else:
		hmat.albedo_color = Color(0.55, 0.72, 0.98, 0.25)
	hm.surface_set_material(0, hmat)
	halo.mesh = hm
	halo.position = moon_pos + Vector3(0, 0, 1.2)
	halo.rotation_degrees = Vector3(30, -15, 0)
	sky_root.add_child(halo)

	# Внешнее мягкое рассеивание
	var outer_halo = MeshInstance3D.new()
	var ohm = QuadMesh.new()
	ohm.size = Vector2(58.0, 58.0)
	var ohmat = StandardMaterial3D.new()
	ohmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ohmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow_tex:
		ohmat.albedo_texture = glow_tex
		ohmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ohmat.albedo_color = Color(0.35, 0.55, 0.85, 0.28)
	else:
		ohmat.albedo_color = Color(0.35, 0.55, 0.85, 0.10)
	ohm.surface_set_material(0, ohmat)
	outer_halo.mesh = ohm
	outer_halo.position = moon_pos + Vector3(0, 0, 0.8)
	outer_halo.rotation_degrees = Vector3(30, -15, 0)
	sky_root.add_child(outer_halo)

	# 3. Высокие ночные облака над головой (мягкие горизонтальные квады без кубиков)
	for c_i in range(8):
		var cloud = MeshInstance3D.new()
		var cm = QuadMesh.new()
		cm.size = Vector2(randf_range(35.0, 65.0), randf_range(20.0, 45.0))
		cm.orientation = PlaneMesh.FACE_Y
		var cmat = StandardMaterial3D.new()
		cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cmat.albedo_color = Color(0.04, 0.06, 0.10, randf_range(0.18, 0.30))
		cm.material = cmat
		cloud.mesh = cm
		cloud.position = Vector3(randf_range(-60.0, 60.0), randf_range(68.0, 85.0), randf_range(-50.0, 50.0))
		cloud.set_meta("drift_speed", randf_range(0.4, 1.0))
		sky_root.add_child(cloud)
		moon_clouds.append(cloud)

	# 4. Купол ночных звёзд (мягкие круглые биллборды, не кубики!)
	stars_node = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var star_mesh = QuadMesh.new()
	star_mesh.size = Vector2(0.22, 0.22)
	var star_mat = StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.vertex_color_use_as_albedo = true
	star_mesh.material = star_mat
	mm.mesh = star_mesh
	mm.instance_count = 280

	for s_i in range(280):
		var theta = randf_range(0.0, TAU)
		var phi = randf_range(0.12, 1.35)
		var r = randf_range(70.0, 110.0)
		var sx = r * sin(phi) * cos(theta)
		var sy = r * cos(phi) + 14.0
		var sz_pos = r * sin(phi) * sin(theta) - 20.0

		var t = Transform3D()
		t.origin = Vector3(sx, sy, sz_pos)
		var tint_choice = randf()
		var s_col: Color
		if tint_choice < 0.6:
			s_col = Color(randf_range(0.85, 1.0), randf_range(0.9, 1.0), 1.0, randf_range(0.6, 1.0))
		elif tint_choice < 0.85:
			s_col = Color(randf_range(0.7, 0.85), randf_range(0.85, 1.0), 1.0, randf_range(0.65, 1.0))
		else:
			s_col = Color(1.0, randf_range(0.8, 0.95), randf_range(0.6, 0.8), randf_range(0.6, 0.95))
		mm.set_instance_transform(s_i, t)
		mm.set_instance_color(s_i, s_col)

	stars_node.multimesh = mm
	sky_root.add_child(stars_node)

	# Живой многослойный параллакс горизонта (Горы и Ночной Город)
	var parallax = ParallaxHorizon.new()
	sky_root.add_child(parallax)

	# 5. Мягкий лунный свет с кинематографичными размытыми тенями (оптимизирован для высокого FPS)
	moon_light = DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.rotation_degrees = Vector3(-42, 28, 0)
	moon_light.light_color = Color(0.68, 0.80, 1.0)
	moon_light.light_energy = 0.24
	moon_light.shadow_enabled = true
	moon_light.shadow_blur = 1.4
	moon_light.directional_shadow_max_distance = 65.0
	moon_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(moon_light)

func _apply_graphics_quality(quality: String) -> void:
	if not world_env_node or not world_env_node.environment:
		return
	var env = world_env_node.environment
	# Reset shared lighting when cycling presets so high settings do not leak down.
	env.ambient_light_color = Color(0.03, 0.04, 0.08)
	env.ambient_light_energy = 0.28
	if moon_light:
		moon_light.light_energy = 0.24
	match quality:
		"ultra", "high":
			# Readable night lighting with restrained contact shadows and haze.
			env.ambient_light_color = Color(0.36, 0.43, 0.56)
			env.ambient_light_energy = 0.65
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 1.25
			env.tonemap_white = 6.5
			# SSAO — глубокое затенение углов и поверхностей
			env.ssao_enabled = true
			env.ssao_radius = 0.75
			env.ssao_intensity = 1.05
			env.ssao_power = 1.0
			env.ssao_detail = 0.35
			env.ssao_horizon = 0.06
			env.ssao_sharpness = 0.85
			# SSIL — жёсткое bounce-освещение
			env.ssil_enabled = true
			env.ssil_radius = 2.5
			env.ssil_intensity = 1.0
			env.ssil_sharpness = 0.75
			# SSR — зеркала, мокрые полы
			env.ssr_enabled = true
			env.ssr_max_steps = 32
			env.ssr_fade_in = 0.10
			env.ssr_fade_out = 3.5
			env.ssr_depth_tolerance = 0.2
			# SDFGI ВЫКЛЮЧЕНО — артефакты кубов!
			env.sdfgi_enabled = false
			# GLOW — кинематографический ужасный блум
			env.glow_enabled = true
			env.glow_normalized = false
			env.glow_bloom = 0.06
			env.glow_intensity = 0.55
			env.glow_strength = 0.85
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.glow_hdr_threshold = 1.3
			env.glow_hdr_scale = 2.5
			# Объёмный туман — жуткая ночная дымка
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.006
			env.volumetric_fog_albedo = Color(0.42, 0.50, 0.62)
			env.volumetric_fog_emission = Color(0.018, 0.028, 0.05)
			env.volumetric_fog_emission_energy = 0.20
			env.volumetric_fog_anisotropy = 0.45
			env.volumetric_fog_length = 64.0
			env.volumetric_fog_detail_spread = 2.0
			env.volumetric_fog_temporal_reprojection_enabled = true
			env.volumetric_fog_temporal_reprojection_amount = 0.90
			# Туман дальних дистанций
			env.fog_enabled = true
			env.fog_light_color = Color(0.10, 0.14, 0.22)
			env.fog_density = 0.0012
			# Коррекция цвета — noir horror
			env.adjustment_enabled = true
			env.adjustment_brightness = 1.04
			env.adjustment_contrast = 1.04
			env.adjustment_saturation = 0.97
			if moon_light:
				moon_light.shadow_enabled = true
				moon_light.shadow_blur = 1.8
				moon_light.light_energy = 0.55
			# Высокое отличается от ультра самыми дорогими эффектами
			if quality == "high":
				env.ssil_enabled = false
				env.volumetric_fog_enabled = false
				env.ssr_enabled = false
		"medium":
			env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
			env.tonemap_exposure = 1.0
			env.tonemap_white = 5.0
			env.ssao_enabled = true
			env.ssao_radius = 1.2
			env.ssao_intensity = 1.6
			env.ssao_power = 1.0
			env.ssao_detail = 0.2
			env.ssao_horizon = 0.1
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.sdfgi_enabled = false
			env.glow_enabled = true
			env.glow_bloom = 0.08
			env.glow_intensity = 0.6
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.volumetric_fog_enabled = false
			env.fog_enabled = true
			env.fog_density = 0.015
			env.fog_depth_begin = 3.0
			env.fog_depth_end = 38.0
			env.adjustment_enabled = true
			env.adjustment_brightness = 1.0
			env.adjustment_contrast = 1.08
			env.adjustment_saturation = 1.0
			if moon_light:
				moon_light.shadow_enabled = true
				moon_light.shadow_blur = 1.2
		"low":
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.sdfgi_enabled = false
			env.glow_enabled = false
			env.volumetric_fog_enabled = false
			env.fog_enabled = true
			env.fog_density = 0.012
			env.fog_depth_begin = 5.0
			env.fog_depth_end = 32.0
			env.adjustment_enabled = false
			if moon_light:
				moon_light.shadow_enabled = false



# ══════════════════════════════════════════════
#  NavigationRegion — вся геометрия карты внутри
# ══════════════════════════════════════════════
func _setup_nav_region() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	navigation_async_region = NavigationServer3D.region_get_use_async_iterations(nav_region.get_rid())
	# Initial registration and the runtime bake must publish in order. Do not
	# build an empty region on a worker while its geometry is being replaced.
	NavigationServer3D.region_set_use_async_iterations(nav_region.get_rid(), false)

	var nm = NavigationMesh.new()
	# Navigation follows physical collision geometry, including edited maps.
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.cell_size         = 0.10
	nm.cell_height       = 0.10
	nm.agent_height      = 2.0
	nm.agent_radius      = 0.35
	nm.agent_max_climb   = 0.55
	nm.agent_max_slope   = 60.0
	# Actual bounds are collected from the map, including relocated houses/spawns.
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	navigation_async_map = NavigationServer3D.map_get_use_async_iterations(nav_region.get_navigation_map())
	NavigationServer3D.map_set_use_async_iterations(nav_region.get_navigation_map(), false)
	NavigationServer3D.map_set_cell_size(nav_region.get_navigation_map(), 0.10)
	NavigationServer3D.map_set_cell_height(nav_region.get_navigation_map(), 0.10)

func _bake_nav_mesh() -> void:
	if navigation_bounds_valid:
		var bounds := navigation_bounds.expand(player_spawn).expand(enemy_spawn).grow(8.0)
		nav_region.navigation_mesh.filter_baking_aabb = bounds
	else:
		nav_region.navigation_mesh.filter_baking_aabb = AABB(player_spawn, Vector3.ZERO).expand(enemy_spawn).grow(40.0)
	# На время запекания сетки временно отключаем коллизию дверных полотен,
	# чтобы навигационная сетка бесшовно соединяла все комнаты через двери
	var disabled_door_colliders: Array[CollisionShape3D] = []
	for node in find_children("*", "CollisionShape3D", true, false):
		var p = node.get_parent()
		if p:
			var is_door = p.name == "Panel" or p.name.begins_with("Door") or p.has_method("is_door_locked") or p.has_method("open_by_enemy")
			var it = str(p.get_meta("item_type", ""))
			if is_door or it.begins_with("door") or it.begins_with("custom_door"):
				if not node.disabled:
					node.disabled = true
					disabled_door_colliders.append(node)

	# Bake only the playable bounds, not the entire kilometre-wide terrain.
	# Коллизии читаются сразу в этом вызове, расчёт уходит в отдельный поток
	nav_region.bake_navigation_mesh(true)

	# Мгновенно возвращаем физическую коллизию дверей для игрока и монстра
	for col in disabled_door_colliders:
		if is_instance_valid(col):
			col.disabled = false


# ══════════════════════════════════════════════
#  Загрузка карты из JSON
# ══════════════════════════════════════════════
var custom_items_spawned: bool = false


func _load_map() -> void:
	# Земля разбита на 3 полосы по X для GPU frustum culling — убирает фриз при загрузке
	var grass_col = Color(0.16, 0.32, 0.14)
	var chunk_w   = 334.0
	var chunk_offsets = [-334.0, 0.0, 334.0]
	for ci in range(3):
		var body = StaticBody3D.new()
		body.name = "GrassChunk%d" % ci
		body.position = Vector3(chunk_offsets[ci], -0.25, 0.0)
		body.collision_layer = 1
		body.collision_mask  = 0
		var mi   = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = Vector3(chunk_w, 0.5, 1000.0)
		var mat  = StandardMaterial3D.new()
		mat.albedo_color = grass_col
		mat.roughness = 0.95
		mesh.surface_set_material(0, mat)
		mi.mesh = mesh
		# Оптимизация: трава не отбрасывает тени и не влияет на GI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode     = GeometryInstance3D.GI_MODE_DISABLED
		body.add_child(mi)
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(chunk_w, 0.5, 1000.0)
		col.shape = box
		body.add_child(col)
		nav_region.add_child(body)

	var file = FileAccess.open(map_json_path, FileAccess.READ)
	if not file:
		push_warning("map.json не найден — строим fallback")
		_fallback_walls()
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_warning("Ошибка JSON — строим fallback")
		file.close()
		_fallback_walls()
		return
	file.close()

	var is_legacy_map = map_json_path.to_lower().contains("prototype map")
	if json.data is Dictionary and (json.data.get("generator") == "MapForge" or json.data.has("version")):
		is_legacy_map = false

	# Если загружается оригинальный немодифицированный прототип особняка — добавляем крышу над домом
	if is_legacy_map:
		_box(Vector3(-0.5, wall_height + 0.15, -3.5), Vector3(36, 0.3, 36), Color(0.06, 0.05, 0.06), "mansion_ceil")
	var objects: Array = json.data.get("objects", [])
	for scan_obj in objects:
		if str(scan_obj.get("name", "")) == "Пикап Итана":
			highway_map = true
			break
	has_enemy_spawn = false
	has_lumberjack_spawn = false
	var _item_candidates: Dictionary = {}
	for obj in objects:
		var o_type: String  = obj.get("type", "cube")
		var obj_id: int     = obj.get("id", -1)
		var pa              = obj.get("position", [0, 1, 0])
		var ra              = obj.get("rotation", [0, 0, 0])
		var sa              = obj.get("scale",    [1, 2, 1])
		var color_s: String = obj.get("color", "#7d8590")

		var pos = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		var rot = Vector3(float(ra[0]), float(ra[1]), float(ra[2]))
		var sz  = Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
		var col = Color.html(color_s)
		# Стоячие ели шоссе строит глава: участками, так быстрее. Поваленные остаются обычными
		if highway_map and o_type == "prop_tree_pine" and absf(rot.x) < 1.0:
			highway_trees.append([pos, sz, deg_to_rad(rot.y), str(obj.get("name", "")) != "Ель за оградой"])
			continue
		if o_type in ["cube", "floor_custom", "road_segment", "door", "door_exit", "door_simple", "door_electric", "marker_player", "marker_enemy", "marker_lumberjack"]:
			var radius := Vector3(maxf(sz.x, sz.z) * 0.72, maxf(sz.y * 0.5, 1.0), maxf(sz.x, sz.z) * 0.72)
			if not navigation_bounds_valid:
				navigation_bounds = AABB(pos - radius, radius * 2.0)
				navigation_bounds_valid = true
			else:
				navigation_bounds = navigation_bounds.expand(pos - radius).expand(pos + radius)

		match o_type:
			"marker_player":
				player_spawn = pos
			"marker_enemy":
				enemy_spawn = pos
				has_enemy_spawn = true
			"marker_lumberjack", "marker_woodcutter", "custom_lumberjack":
				lumberjack_spawn = pos
				lumberjack_spawn.y = 0.0
				has_lumberjack_spawn = true
			"marker":
				var c_str = str(obj.get("comment", "")).to_lower()
				var n_str = str(obj.get("name", "")).to_lower()
				if "лесопил" in c_str or "лесопил" in n_str or "lumberjack" in n_str or "woodcutter" in n_str:
					lumberjack_spawn = pos
					lumberjack_spawn.y = 0.0
					has_lumberjack_spawn = true
				elif "враг" in c_str or "враг" in n_str or "enemy" in n_str or "скинвокер" in n_str:
					enemy_spawn = pos
					enemy_spawn.y = 0.0
					has_enemy_spawn = true
				elif "лом" in c_str or "ключ" in c_str or "crowbar" in c_str or "key" in c_str:
					var pt = pos
					pt.y = 0.45
					if not item_spawn_spots.has(pt):
						item_spawn_spots.append(pt)
				elif "игрок" in n_str:
					player_spawn = pos
					player_spawn.y = 0.0
			"door", "door_exit":
				GameManager.door_position = pos
				door_configured_rot = rot
				door_configured_sz = sz
				if obj.has("key_color"):
					door_configured_key_color = str(obj["key_color"])
				if obj.has("lock_id"):
					door_configured_lock_id = int(obj["lock_id"])
				if obj.has("requires_power"):
					door_configured_requires_power = bool(obj["requires_power"])
				if obj.has("requires_boards"):
					door_configured_requires_boards = bool(obj["requires_boards"])
				if obj.has("door_texture") and str(obj["door_texture"]) != "":
					door_configured_texture = str(obj["door_texture"])
			"door", "custom_door", "door_exit", "custom_door_exit", \
			"door_simple", "custom_door_simple", "door_electric", "custom_door_electric", \
			"door_metal", "custom_door_metal", "door_hatch", "custom_door_hatch":
				var d_node = PrefabBuilder.build_prefab(o_type, sz, col, false, obj.get("model_path", ""))
				d_node.name = "%s_%d" % [o_type, obj_id]
				d_node.position = pos
				d_node.rotation_degrees = rot
				d_node.scale = Vector3.ONE
				var obj_name_lower = str(obj.get("name", "")).to_lower()
				var is_exit_flag = bool(obj.get("is_exit", false)) or ("выход" in obj_name_lower) or ("exit" in obj_name_lower) or o_type in ["door_exit", "custom_door_exit"] or (o_type == "door" and _is_level_1())
				if is_exit_flag:
					d_node.set("is_exit", true)
					d_node.set_meta("is_exit", true)
					GameManager.door_position = pos
					has_exit_door_spawned = true
				if obj.has("door_texture") and str(obj["door_texture"]) != "":
					TextureHelper.apply_door_texture_to_node(d_node, str(obj["door_texture"]))
				if obj.has("key_color"):
					d_node.set("required_key_color", str(obj["key_color"]))
				if obj.has("lock_id"):
					d_node.set("lock_id", int(obj["lock_id"]))
					d_node.set_meta("lock_id", int(obj["lock_id"]))
				if obj.has("requires_wire_panel"):
					d_node.set("requires_wire_panel", bool(obj["requires_wire_panel"]))
					d_node.set_meta("requires_wire_panel", bool(obj["requires_wire_panel"]))
				if obj.has("requires_boards") or obj.has("has_boards") or obj.has("boards"):
					var brd = bool(obj.get("requires_boards", false)) or bool(obj.get("has_boards", false)) or bool(obj.get("boards", false))
					d_node.set("requires_boards", brd)
					d_node.set_meta("requires_boards", brd)
				if obj.has("is_hatch") or o_type.begins_with("door_hatch"):
					d_node.set("is_hatch", true)
					d_node.set_meta("is_hatch", true)
				if obj.has("requires_power"):
					d_node.set("requires_power", bool(obj["requires_power"]))
				if obj.has("is_locked"):
					d_node.set_meta("is_locked", bool(obj["is_locked"]))
				var pnl = d_node.find_child("Panel", true, false)
				if pnl:
					if is_exit_flag:
						pnl.set("is_exit", true)
						pnl.set_meta("is_exit", true)
					if obj.has("door_texture") and str(obj["door_texture"]) != "":
						pnl.set_meta("door_texture", str(obj["door_texture"]))
					if obj.has("key_color"): pnl.set("required_key_color", str(obj["key_color"]))
					if obj.has("lock_id"): pnl.set("lock_id", int(obj["lock_id"]))
					if obj.has("requires_wire_panel"): pnl.set("requires_wire_panel", bool(obj["requires_wire_panel"]))
					if obj.has("requires_power"): pnl.set("requires_power", bool(obj["requires_power"]))
					if obj.has("is_locked"): pnl.set_meta("is_locked", bool(obj["is_locked"]))
				_configure_door_controllers(d_node, obj)
				nav_region.add_child(d_node)
			"prop_fusebox", "custom_prop_fusebox":
				var fb = PrefabBuilder.build_prefab("prop_fusebox", sz, col, false)
				fb.name = "%s_%d" % [o_type, obj_id]
				fb.position = pos
				fb.rotation_degrees = rot
				if obj.has("lock_id"):
					fb.set("lock_id", int(obj["lock_id"]))
					fb.set_meta("lock_id", int(obj["lock_id"]))
				nav_region.add_child(fb)
			"item_crowbar", "custom_item_crowbar":
				_add_candidate_item(_item_candidates, "crowbar", pos, rot, obj)
			"item_key", "custom_item_key", "key", \
			"item_key_gold", "custom_item_key_gold", \
			"item_key_silver", "custom_item_key_silver", \
			"item_key_rusty", "custom_item_key_rusty", \
			"item_key_emerald", "custom_item_key_emerald", \
			"item_key_ruby", "custom_item_key_ruby", \
			"item_key_sapphire", "custom_item_key_sapphire":
				var kid: int = 1
				if obj.has("key_id"):
					kid = int(obj["key_id"])
				elif obj.has("lock_id"):
					kid = int(obj["lock_id"])
				elif o_type.ends_with("silver"):
					kid = 2
				elif o_type.ends_with("emerald"):
					kid = 3
				elif o_type.ends_with("ruby"):
					kid = 4
				elif o_type.ends_with("sapphire"):
					kid = 5
				elif o_type.ends_with("rusty"):
					kid = 6
				_add_candidate_item(_item_candidates, "key_id_%d" % kid, pos, rot, obj)
			"prop_alarm_clock", "alarm_clock", "custom_prop_alarm_clock":
				_add_candidate_item(_item_candidates, "alarm_clock", pos, rot, obj)
			"prop_tv_remote", "tv_remote", "remote", "custom_prop_tv_remote":
				_add_candidate_item(_item_candidates, "tv_remote", pos, rot, obj)
			"prop_note_safe", "item_note_safe", "custom_prop_note_safe":
				_make_item(pos, "note_safe")
			"prop_note", "custom_prop_note", "note":
				_make_item(pos, "note")
			"item_battery", "custom_item_battery":
				_make_item(pos, "battery")
				custom_items_spawned = true
			"item_fuse_red", "custom_item_fuse_red":
				_make_item(pos, "fuse_red")
				custom_items_spawned = true
			"item_fuse_blue", "custom_item_fuse_blue":
				_make_item(pos, "fuse_blue")
				custom_items_spawned = true
			"item_fuse_green", "custom_item_fuse_green":
				_make_item(pos, "fuse_green")
				custom_items_spawned = true
			"light_warm", "light_red":
				var l = OmniLight3D.new()
				l.position = pos
				l.light_color = col
				l.light_energy = 2.0
				l.omni_range = 8.0
				add_child(l)
			"custom_door", "custom_door_exit":
				GameManager.door_position = pos
				door_configured_rot = rot
				if obj.has("key_color"):
					door_configured_key_color = str(obj["key_color"])
				if obj.has("requires_power"):
					door_configured_requires_power = bool(obj["requires_power"])
				if obj.has("requires_boards"):
					door_configured_requires_boards = bool(obj["requires_boards"])
				if obj.has("door_texture") and str(obj["door_texture"]) != "":
					door_configured_texture = str(obj["door_texture"])
			"custom_enemy":
				enemy_spawn = pos
				has_enemy_spawn = true
			"custom_prop":
				var m_path = obj.get("model_path", "")
				if m_path != "" and ResourceLoader.exists(m_path):
					var m_res = load(m_path)
					if m_res and m_res is PackedScene:
						var m_node = m_res.instantiate()
						m_node.position = pos
						m_node.rotation_degrees = rot
						nav_region.add_child(m_node)
				else:
					_box(pos, sz, col, "prop_%d" % obj_id, true, rot)
			"floor_drag", "floor_custom", "ceiling_drag", "ceiling_custom", \
			"prop_blood_puddle", "prop_blood_wall", "prop_carpet", \
			"prop_nightstand", "prop_wardrobe", "prop_table", "prop_chair", "prop_bed", \
			"prop_dresser", "prop_cupboard", "prop_basement_entrance", \
			"prop_crate", "prop_barrel", "road_segment", "prop_car", "prop_rock_large":
				var is_prim = (o_type == "floor_drag" or o_type == "floor_custom" or o_type == "ceiling_drag" or o_type == "ceiling_custom")
				var base_sz = PrefabBuilder.get_prefab_base_size(o_type)
				if base_sz.x <= 0.01: base_sz.x = 1.0
				if base_sz.y <= 0.01: base_sz.y = 1.0
				if base_sz.z <= 0.01: base_sz.z = 1.0
				var build_sz = sz if is_prim else base_sz
				var prop_node = PrefabBuilder.build_prefab(o_type, build_sz, col, false, "")
				prop_node.name = "%s_%d" % [o_type, obj_id]
				prop_node.position = pos
				prop_node.rotation_degrees = rot
				if not is_prim:
					prop_node.scale = Vector3(sz.x / base_sz.x, sz.y / base_sz.y, sz.z / base_sz.z)
				nav_region.add_child(prop_node)
			"cube":
				if is_legacy_map and obj_id == 82:
					GameManager.door_position = pos
					door_configured_rot = rot
					continue
				if is_legacy_map and sz.y >= 1.9 and sz.y <= 2.2:
					sz.y  = wall_height
					pos.y = wall_height * 0.5
				# "collide": false — декор, сквозь который можно пройти (простыни, балки, бумаги)
				var w_node = _box(pos, sz, col, "wall_%d" % obj_id, bool(obj.get("collide", true)), rot)
				if obj.has("wall_texture") and str(obj["wall_texture"]) != "":
					TextureHelper.apply_wall_texture_to_node(w_node, str(obj["wall_texture"]), col)
					if str(obj["wall_texture"]) == "brick_red" and abs(rot.x) < 0.5 and abs(rot.z) < 0.5:
						NatureKit.add_protruding_bricks(w_node, sz, col, TextureHelper.WALL_TEXTURES["brick_red"]["triplanar_scale"].x)
			_:
				if is_legacy_map and obj_id == 82:
					GameManager.door_position = pos
					door_configured_rot = rot
					continue
				var is_door = ("door" in o_type and not ("hatch" in o_type))
				# Ель строится сразу в нужном размере: своя модель и узкая коллизия у больших
				var is_prim = (o_type == "cube" or o_type.begins_with("wall") or is_door or o_type == "prop_tree_pine")
				var base_sz = PrefabBuilder.get_prefab_base_size(o_type)
				if base_sz.x <= 0.01: base_sz.x = 1.0
				if base_sz.y <= 0.01: base_sz.y = 1.0
				if base_sz.z <= 0.01: base_sz.z = 1.0
				var build_sz = sz if is_prim else base_sz
				var any_node = PrefabBuilder.build_prefab(o_type, build_sz, col, false, obj.get("model_path", ""))
				any_node.name = "obj_%d" % obj_id
				any_node.position = pos
				any_node.rotation_degrees = rot
				if is_door:
					any_node.scale = Vector3.ONE
				elif not is_prim:
					any_node.scale = Vector3(sz.x / base_sz.x, sz.y / base_sz.y, sz.z / base_sz.z)
				if obj.has("painting_art") and str(obj["painting_art"]) != "":
					TextureHelper.apply_painting_art_to_node(any_node, str(obj["painting_art"]))
				if obj.has("tree_drawing") and str(obj["tree_drawing"]) != "":
					TextureHelper.apply_tree_drawing_to_node(any_node, str(obj["tree_drawing"]))
				if obj.has("door_texture") and str(obj["door_texture"]) != "":
					TextureHelper.apply_door_texture_to_node(any_node, str(obj["door_texture"]))
				if obj.has("key_color"):
					any_node.set("required_key_color", str(obj["key_color"]))
				if obj.has("requires_power"):
					any_node.set("requires_power", bool(obj["requires_power"]))
				if obj.has("is_locked"):
					any_node.set_meta("is_locked", bool(obj["is_locked"]))
				var pnl = any_node.find_child("Panel", true, false)
				if pnl:
					if obj.has("key_color"): pnl.set("required_key_color", str(obj["key_color"]))
					if obj.has("requires_power"): pnl.set("requires_power", bool(obj["requires_power"]))
					if obj.has("is_locked"): pnl.set_meta("is_locked", bool(obj["is_locked"]))
				_configure_door_controllers(any_node, obj)
				nav_region.add_child(any_node)

	_spawn_candidate_items(_item_candidates)

func _configure_door_controllers(root: Node3D, obj: Dictionary) -> void:
	var nodes_to_check: Array[Node] = [root]
	nodes_to_check.append_array(root.find_children("*", "Node3D", true, false))

	for part in nodes_to_check:
		if not part.has_method("open_by_enemy") and part != root:
			continue
		if obj.has("key_color"):
			part.set("required_key_color", str(obj["key_color"]))
			part.set_meta("required_key_color", str(obj["key_color"]))

		var lid: int = 0
		if obj.has("lock_id"):
			lid = int(obj["lock_id"])
		elif obj.has("key_id"):
			lid = int(obj["key_id"])
		elif obj.has("key_color") and str(obj["key_color"]) != "none" and str(obj["key_color"]) != "":
			var DoorScript = load("res://scripts/Door.gd")
			lid = DoorScript.color_to_lock_id(str(obj["key_color"]))
		elif obj.has("is_locked") and bool(obj["is_locked"]):
			lid = 1

		if lid > 0:
			part.set("lock_id", lid)
			part.set_meta("lock_id", lid)
			part.set_meta("is_locked", true)
		else:
			part.set("lock_id", 0)
			part.set_meta("lock_id", 0)
			part.set_meta("is_locked", false)

		if obj.has("requires_wire_panel"):
			part.set("requires_wire_panel", bool(obj["requires_wire_panel"]))
			part.set_meta("requires_wire_panel", bool(obj["requires_wire_panel"]))
		if obj.has("is_hatch") or obj.get("type", "").begins_with("door_hatch"):
			part.set("is_hatch", true)
			part.set_meta("is_hatch", true)
		for key in ["requires_power", "requires_boards"]:
			if obj.has(key):
				part.set(key, bool(obj[key]))
				part.set_meta(key, bool(obj[key]))
		if obj.has("has_boards"):
			part.set("requires_boards", bool(obj["has_boards"]))
			part.set_meta("requires_boards", bool(obj["has_boards"]))
		if obj.has("boards"):
			part.set("requires_boards", bool(obj["boards"]))
			part.set_meta("requires_boards", bool(obj["boards"]))

func _add_candidate_item(dict: Dictionary, itype: String, pos: Vector3, rot: Vector3, obj: Dictionary) -> void:
	if not dict.has(itype):
		dict[itype] = []
	dict[itype].append({ "pos": pos, "rot": rot, "obj": obj })

func _spawn_candidate_items(candidates_dict: Dictionary) -> void:
	for item_type in candidates_dict.keys():
		var candidates: Array = candidates_dict[item_type]
		if candidates.is_empty():
			continue

		var key_id_val: int = 0
		var actual_item_type = item_type
		if item_type.begins_with("key_id_"):
			key_id_val = int(item_type.substr(7))
			actual_item_type = "key"

		# Рандомный выбор одного из возможных мест спавна (в тумбочке, комоде или на полу)
		var picked: Dictionary = candidates.pick_random()
		var p_pos: Vector3 = picked["pos"]

		var placed_in_drawer: bool = false
		if nav_region:
			for storage in nav_region.find_children("*", "Node3D", true, false):
				if storage.has_method("get_interaction_hint") or storage.get_meta("item_type", "") in ["prop_nightstand", "prop_dresser", "prop_cupboard"]:
					if storage.global_position.distance_to(p_pos) <= 0.85:
						var drawer = storage.find_child("Drawer", true, false)
						if not drawer:
							drawer = storage.find_child("Movable", true, false)
						if not drawer:
							drawer = storage.find_child("Door", true, false)
						if drawer:
							var item_node = Area3D.new()
							item_node.set_script(load("res://scripts/Item.gd"))
							item_node.set_meta("item_type", actual_item_type)
							if key_id_val > 0:
								item_node.set("key_id", key_id_val)
								item_node.set_meta("key_id", key_id_val)
							item_node.set_meta("inside_storage", true)
							drawer.add_child(item_node)
							item_node.position = Vector3(0.0, 0.04, 0.0)
							item_node.rotation_degrees = Vector3.ZERO
							placed_in_drawer = true
							custom_items_spawned = true
							break

		if not placed_in_drawer:
			_make_item(p_pos, actual_item_type, key_id_val)
			custom_items_spawned = true

func _setup_house_switches_and_lights() -> void:
	if not nav_region or _is_prologue_map():
		return
	# Проверяем, есть ли уже выключатели в nav_region
	for ch in nav_region.get_children():
		if ch.name.begins_with("prop_light_switch") or ch.get_meta("item_type", "") == "light_switch":
			return

	# 1. Потолочная люстра в стартовом коридоре
	var lamp = PrefabBuilder.build_prefab("light_ceiling", Vector3(0.6, 1.0, 0.6), Color(1.0, 0.9, 0.65), false, "")
	lamp.name = "hall_ceiling_lamp"
	lamp.position = Vector3(-8.5, wall_height - 0.85, -11.0)
	nav_region.add_child(lamp)

	# 2. Настенный выключатель на стене коридора на уровне глаз (y = 1.35)
	# Стена 69 находится на x = -6.5 (толщина 0.4, грань на x = -6.7)
	# Выключатель повернут лицом к коридору (-X)
	var sw = PrefabBuilder.build_prefab("prop_light_switch", Vector3(0.2, 0.3, 0.1), Color(0.88, 0.88, 0.90), false, "")
	sw.name = "prop_light_switch_start"
	sw.position = Vector3(-6.68, 1.35, -11.0)
	sw.rotation_degrees = Vector3(0, -90, 0)
	nav_region.add_child(sw)

func _fallback_walls() -> void:
	var c = Color(0.49, 0.52, 0.57)
	var h = wall_height
	_box(Vector3(0,    h*0.5, -18.5), Vector3(30, h, 0.5), c, "wN")
	_box(Vector3(0,    h*0.5,  11.0), Vector3(30, h, 0.5), c, "wS")
	_box(Vector3(-15.5, h*0.5, -3.5), Vector3(0.4, h, 30), c, "wW")
	_box(Vector3(14.5,  h*0.5, -3.5), Vector3(0.4, h, 30), c, "wE")

# Создаёт StaticBody3D и кладёт в nav_region
func _box(pos: Vector3, sz: Vector3, color: Color,
		  nm: String = "", collidable: bool = true, rot: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.name             = nm
	body.position         = pos
	body.rotation_degrees = rot

	var mi   = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = sz
	var mat  = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.05
	mesh.surface_set_material(0, mat)
	mi.mesh = mesh
	body.add_child(mi)

	if collidable:
		var col = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size  = sz
		col.shape = box
		body.add_child(col)

	nav_region.add_child(body)   # ← в nav_region, не в main!
	return body


# ══════════════════════════════════════════════
#  Спавн игрока
# ══════════════════════════════════════════════
func _spawn_player() -> void:
	var map_lower = map_json_path.to_lower()
	if "карта_6" in map_lower or "karta_6" in map_lower:
		# Создаем разбитую машину на месте аварии в лесу на Карте 6
		var wreck = PrefabBuilder.build_prefab("prop_ethan_car", EthanCar.SIZE, Color(0.5, 0.045, 0.035), false, "")
		wreck.name = "CrashSiteWreck"
		wreck.position = Vector3(-48.5, 0.25, 86.5)
		wreck.rotation_degrees = Vector3(-12.0, -38.0, -10.0)
		nav_region.add_child(wreck)

		# Камень, в который врезалась машина
		var rock = PrefabBuilder.build_prefab("prop_rock_large", Vector3(4.2, 3.2, 4.0), Color(0.32, 0.30, 0.28), false, "")
		rock.name = "CrashSiteRock"
		rock.position = Vector3(-49.5, 0.0, 88.0)
		rock.rotation_degrees = Vector3(5.0, 42.0, -8.0)
		nav_region.add_child(rock)

		add_child(ActDressing.new())

	if _is_highway():
		var starts_in_basement: bool = GameManager.wake_in_basement
		add_child(HighwayChapter.new())
		if starts_in_basement:
			add_child(preload("res://scripts/BasementChapter.gd").new())

	if _is_apartment():
		add_child(preload("res://scripts/ApartmentScene.gd").new())
		# «Обычный день»: задачи, диван, звонок через телефон → кат-сцена «Звонок» → улица
		add_child(preload("res://scripts/PrologueApartment.gd").new())

	if _is_crane_house():
		add_child(load("res://scripts/CraneHouseMap.gd").new())
		# Глава 4: Сэм на стуле «Старший», ремни → кат-сцена Ch4Sam (Jan-ky)
		add_child(load("res://scripts/cutscenes/CraneHouseSam.gd").new())

	if _is_street():
		add_child(preload("res://scripts/CityStreetScene.gd").new())
		# Объявления и посадка в машину → дорога и авария (Jan-ky)
		add_child(preload("res://scripts/cutscenes/StreetCar.gd").new())

	var p = load("res://scenes/Player.tscn").instantiate() as CharacterBody3D
	p.name     = "Player"
	p.position = player_spawn
	add_child(p)
	GameManager.player_ref   = p
	GameManager.player_spawn = player_spawn

func _spawn_enemy() -> void:
	var e = load("res://scenes/Enemy.tscn").instantiate() as CharacterBody3D
	e.name     = "Enemy"
	e.position = enemy_spawn
	add_child(e)
	e.set_physics_process(false)
	GameManager.enemy_ref  = e
	GameManager.enemy_spawn = enemy_spawn

func _spawn_lumberjack() -> void:
	var lj = load("res://scenes/Lumberjack.tscn").instantiate() as CharacterBody3D
	lj.name = "Lumberjack"
	# Спавним лесопила в отдельной выделенной точке спавна
	lj.position = lumberjack_spawn
	add_child(lj)
	lj.set_physics_process(false)
	if GameManager:
		GameManager.lumberjack_ref = lj
		GameManager.lumberjack_spawn = lumberjack_spawn

# ══════════════════════════════════════════════
#  Предметы: спавнятся в случайных комнатах на карте (ВДАЛИ от спавна игрока)
# ══════════════════════════════════════════════
var item_spawn_spots: Array[Vector3] = [
	Vector3(-12.0, 0.45, -6.0),  # Западная средняя комната (10м+ от игрока)
	Vector3(-10.0, 0.45,  5.0),  # Юго-западный угол
	Vector3(-2.0,  0.45,  1.0),  # Центральная комната
	Vector3(5.0,   0.45, -12.0), # Северо-восточный угол
	Vector3(12.0,  0.45, -6.0),  # Дальний восточный тупик
	Vector3(7.0,   0.45,  6.5),  # Юго-восток за колоннами
	Vector3(11.0,  0.45,  3.0),  # Дальний восточный коридор
	Vector3(-5.0,  0.45,  7.0),  # Южный коридор
	Vector3(0.0,   0.45, -8.0),  # Северный перекресток
	Vector3(-4.5,  0.45, -15.0), # Западная спальня (точка из прототипа)
]

func _spawn_items() -> void:
	if custom_items_spawned or _is_prologue_map():
		return
	# Фильтруем точки — предмет должен быть строго дальше 8 метров от спавна игрока
	var valid_spots: Array[Vector3] = []
	for s in item_spawn_spots:
		if s.distance_to(player_spawn) > 8.5:
			valid_spots.append(s)

	valid_spots.shuffle()

	var actual_crowbar_pos = valid_spots.pop_back()
	var actual_key_pos     = valid_spots.pop_back()
	var actual_note_pos    = valid_spots.pop_back()
	var actual_flare_pos = valid_spots.pop_back() if not valid_spots.is_empty() else null

	_make_item(actual_crowbar_pos, "crowbar")
	_make_item(actual_key_pos,     "key")
	if actual_note_pos != null:
		_make_item(actual_note_pos, "note_safe")
	if actual_flare_pos != null:
		_make_item(actual_flare_pos, "road_flare")


func _make_item(pos: Vector3, type: String, key_id: int = 0) -> void:
	var area = Area3D.new()
	area.set_script(load("res://scripts/Item.gd"))
	area.set_meta("item_type", type)
	if key_id > 0:
		area.set("key_id", key_id)
		area.set_meta("key_id", key_id)
	area.position = pos
	add_child(area)


# ══════════════════════════════════════════════
#  Дверь
# ══════════════════════════════════════════════
func _setup_door() -> void:
	# С карты шоссе уходят через сюжетную сцену, а не через дверь
	if has_exit_door_spawned or _is_highway() or _is_prologue_map():
		return

	var door_pos = GameManager.door_position
	if door_pos == Vector3.ZERO:
		door_pos = Vector3(-0.9, 0.0, 10.5)

	var door_root = Node3D.new()
	door_root.name     = "Door"
	door_root.position = door_pos
	door_root.rotation_degrees = door_configured_rot
	door_root.set_script(load("res://scripts/Door.gd"))
	door_root.set("has_electric_meter", door_configured_requires_power)
	door_root.set("required_key_color", door_configured_key_color)
	door_root.set("requires_power", door_configured_requires_power)
	door_root.set("requires_boards", door_configured_requires_boards)
	door_root.set("lock_id", door_configured_lock_id)
	door_root.set("is_exit", true)
	door_root.set_meta("requires_boards", door_configured_requires_boards)
	door_root.set_meta("door_texture", door_configured_texture)
	door_root.set_meta("item_type", "door")
	door_root.set_meta("lock_id", door_configured_lock_id)
	door_root.set_meta("is_exit", true)
	add_child(door_root)

	var frame_th: float = 0.075
	var eff_w: float = door_configured_sz.x if door_configured_sz.x > 0.3 else 1.02
	var eff_h: float = door_configured_sz.y if door_configured_sz.y > 0.5 else 2.12
	var target_th: float = door_configured_sz.z if door_configured_sz.z > 0.04 else 0.14
	var door_w: float = eff_w - (frame_th * 2.0)
	var door_h: float = eff_h - frame_th
	var door_th: float = 0.045

	var fmat = StandardMaterial3D.new()
	fmat.albedo_color = Color(0.20, 0.11, 0.06)
	fmat.roughness = 0.9

	# Откосы по бокам двери и верхняя перекладина
	for side_sign in [-1.0, 1.0]:
		var fm   = MeshInstance3D.new()
		fm.name  = "Frame_" + ("Left" if side_sign < 0 else "Right")
		var fmsh = BoxMesh.new()
		fmsh.size = Vector3(frame_th, eff_h, max(0.15, target_th * 1.15))
		fmsh.surface_set_material(0, fmat)
		fm.mesh     = fmsh
		fm.position = Vector3(side_sign * (eff_w * 0.5 - frame_th * 0.5), eff_h * 0.5, 0)
		door_root.add_child(fm)

	var fmt = MeshInstance3D.new()
	fmt.name = "Frame_Top"
	var fmt_m = BoxMesh.new()
	fmt_m.size = Vector3(eff_w, frame_th, max(0.15, target_th * 1.15))
	fmt_m.surface_set_material(0, fmat)
	fmt.mesh = fmt_m
	fmt.position = Vector3(0, eff_h - frame_th * 0.5, 0)
	door_root.add_child(fmt)

	# Петля двери для плавного распахивания
	var hinge = Node3D.new()
	hinge.name = "Hinge"
	hinge.position = Vector3(-eff_w * 0.5 + frame_th, 0, 0)
	door_root.add_child(hinge)

	# Панель двери
	var db = StaticBody3D.new()
	db.name     = "Panel"
	db.position = Vector3(door_w * 0.5, door_h * 0.5, 0)

	var dmat = StandardMaterial3D.new()
	dmat.albedo_color = Color(0.30, 0.17, 0.09)
	dmat.roughness = 0.85
	var dm = PrefabBuilder.build_realistic_door_leaf(db, door_w, door_h, door_th, dmat, true)

	var dc  = CollisionShape3D.new()
	dc.name = "Col"
	var db2 = BoxShape3D.new()
	db2.size = Vector3(door_w, door_h, door_th)
	dc.shape = db2
	db.add_child(dc)

	hinge.add_child(db)

	# Доски со шляпками кованых гвоздей
	var boards = Node3D.new()
	boards.name     = "Boards"
	boards.position = Vector3(0, 0, -door_th * 0.6)

	var nail_mat = StandardMaterial3D.new()
	nail_mat.albedo_color = Color(0.18, 0.18, 0.20)
	nail_mat.metallic = 0.92
	nail_mat.roughness = 0.35

	var heights = [0.45, 1.05, 1.65]
	for i in range(3):
		var bm   = MeshInstance3D.new()
		var bmsh = BoxMesh.new()
		bmsh.size = Vector3(door_w + 0.16, 0.15, 0.045)
		var bmat = StandardMaterial3D.new()
		bmat.albedo_color = Color(0.37, 0.24, 0.13)
		bmat.roughness = 0.85
		bmsh.surface_set_material(0, bmat)
		bm.mesh = bmsh
		bm.position = Vector3(0.0, heights[i], 0)
		bm.rotation_degrees = Vector3.ZERO
		boards.add_child(bm)

		for nx in [-door_w * 0.44, door_w * 0.44]:
			var nail = MeshInstance3D.new()
			var nm = CylinderMesh.new()
			nm.top_radius = 0.016
			nm.bottom_radius = 0.016
			nm.height = 0.04
			nm.material = nail_mat
			nail.mesh = nm
			nail.rotation_degrees = Vector3(90, 0, 0)
			nail.position = Vector3(nx, 0, -0.02)
			bm.add_child(nail)

	door_root.add_child(boards)
	door_root.set("boards_node", boards)
	if not door_configured_requires_boards:
		boards.visible = false

	# Энергосчетчик на правом откосе косяка
	var meter = Node3D.new()
	meter.name = "ElectricMeter"
	meter.position = Vector3(eff_w * 0.5 + 0.14, 1.15, 0.0)

	var m_body = MeshInstance3D.new()
	var m_bm = BoxMesh.new()
	m_bm.size = Vector3(0.24, 0.36, 0.20)
	var m_mat = StandardMaterial3D.new()
	m_mat.albedo_color = Color(0.22, 0.24, 0.28)
	m_mat.metallic = 0.7
	m_mat.roughness = 0.4
	m_bm.surface_set_material(0, m_mat)
	m_body.mesh = m_bm
	meter.add_child(m_body)

	var m_glass = MeshInstance3D.new()
	var g_mesh = CylinderMesh.new()
	g_mesh.top_radius = 0.08
	g_mesh.bottom_radius = 0.08
	g_mesh.height = 0.04
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.6)
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g_mat.roughness = 0.1
	g_mesh.surface_set_material(0, g_mat)
	m_glass.mesh = g_mesh
	m_glass.rotation_degrees = Vector3(90, 0, 0)
	m_glass.position = Vector3(0, 0.05, 0.10)
	meter.add_child(m_glass)

	var m_led = MeshInstance3D.new()
	m_led.name = "MeterLED"
	var led_mesh = SphereMesh.new()
	led_mesh.radius = 0.025
	led_mesh.height = 0.05
	var led_mat = StandardMaterial3D.new()
	led_mat.albedo_color = Color(0.9, 0.1, 0.1)
	led_mat.emission_enabled = true
	led_mat.emission = Color(0.9, 0.1, 0.1)
	led_mat.emission_energy_multiplier = 0.8
	led_mesh.surface_set_material(0, led_mat)
	m_led.mesh = led_mesh
	m_led.position = Vector3(0, -0.11, 0.11)
	meter.add_child(m_led)

	var m_light = OmniLight3D.new()
	m_light.name = "MeterLight"
	m_light.light_color = Color(1.0, 0.1, 0.1)
	m_light.light_energy = 0.5
	m_light.omni_range = 1.2
	m_light.position = Vector3(0, -0.11, 0.15)
	meter.add_child(m_light)

	door_root.add_child(meter)
	TextureHelper.apply_door_texture_to_node(door_root, door_configured_texture)



# ══════════════════════════════════════════════
#  Аудио
# ══════════════════════════════════════════════
func _load_mp3(path: String) -> AudioStreamMP3:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStreamMP3:
			return res
	if FileAccess.file_exists(path):
		var bytes = FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			var s = AudioStreamMP3.new()
			s.data = bytes
			return s
	return null

func _setup_audio() -> void:
	if _is_level_2():
		# 1-е аудио: если он попадает внутрь дома
		house_ambient_player = AudioStreamPlayer.new()
		house_ambient_player.name = "HouseAmbient"
		var h_stream = _load_mp3("res://assets/ambient_house.mp3")
		if h_stream:
			h_stream.loop = true
			house_ambient_player.stream = h_stream
			house_ambient_player.volume_db = -45.0
			house_ambient_player.autoplay = true
		add_child(house_ambient_player)

		# Эмбиент найт: если он на улице
		outdoor_ambient_player = AudioStreamPlayer.new()
		outdoor_ambient_player.name = "OutdoorAmbient"
		var n_stream = _load_mp3("res://assets/ambient_night.mp3")
		if n_stream:
			n_stream.loop = true
			outdoor_ambient_player.stream = n_stream
			outdoor_ambient_player.volume_db = -1.5
			outdoor_ambient_player.autoplay = true
		add_child(outdoor_ambient_player)
	else:
		var ap = AudioStreamPlayer.new()
		ap.name = "Ambient"
		var stream = _load_mp3("res://assets/ambient1.mp3")
		if stream:
			stream.loop = true
			ap.stream    = stream
			ap.volume_db = -12.0
			ap.autoplay  = true
		add_child(ap)

		outdoor_ambient_player = AudioStreamPlayer.new()
		outdoor_ambient_player.name = "OutdoorAmbient"
		var dream_stream = _load_mp3("res://assets/dreamambient.mp3")
		if dream_stream:
			dream_stream.loop = true
			outdoor_ambient_player.stream = dream_stream
			outdoor_ambient_player.volume_db = 0.0
			outdoor_ambient_player.autoplay = true
		add_child(outdoor_ambient_player)

func _physics_process(delta: float) -> void:
	if not GameManager.player_ref or not is_instance_valid(GameManager.player_ref):
		return

	var p_pos = GameManager.player_ref.global_position + Vector3.UP * 0.5
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(p_pos, p_pos + Vector3.UP * 30.0)
	query.exclude = [GameManager.player_ref.get_rid()]
	var result = space_state.intersect_ray(query)
	var has_ceiling = not result.is_empty() and (result.position.y - p_pos.y) < 14.0

	if _is_level_2():
		# Вторая карта: внутри дома — 1 аудио, на улице — эмбиент найт
		var target_house_vol = -1.5 if has_ceiling else -45.0
		var target_night_vol = -45.0 if has_ceiling else -1.5

		if house_ambient_player and is_instance_valid(house_ambient_player):
			if not house_ambient_player.playing:
				house_ambient_player.play()
			house_ambient_player.volume_db = lerp(house_ambient_player.volume_db, target_house_vol, delta * 3.0)

		if outdoor_ambient_player and is_instance_valid(outdoor_ambient_player):
			if not outdoor_ambient_player.playing:
				outdoor_ambient_player.play()
			outdoor_ambient_player.volume_db = lerp(outdoor_ambient_player.volume_db, target_night_vol, delta * 3.0)
	else:
		if outdoor_ambient_player and is_instance_valid(outdoor_ambient_player) and outdoor_ambient_player.playing:
			var target_vol = -7.0 if has_ceiling else -3.0
			outdoor_ambient_player.volume_db = lerp(outdoor_ambient_player.volume_db, target_vol, delta * 2.0)

func _is_level_1() -> bool:
	var p = map_json_path.to_lower()
	if "1level" in p or "level1" in p or "1_level" in p:
		return true
	if GameManager and GameManager.active_map_path != "":
		var gp = GameManager.active_map_path.to_lower()
		if "1level" in gp or "level1" in gp or "1_level" in gp:
			return true
	return false

func _is_apartment() -> bool:
	return "квартира" in map_json_path.to_lower()

func _is_street() -> bool:
	return "улица" in map_json_path.to_lower()

# Карты пролога: без предметов, выхода и выключателей общей сцены
func _is_crane_house() -> bool:
	return "крейна" in map_json_path.to_lower() or "лесная" in map_json_path.to_lower()

func _is_prologue_map() -> bool:
	return _is_apartment() or _is_street() or _is_crane_house()

func _is_highway() -> bool:
	return highway_map or "шоссе" in map_json_path.to_lower()

func _is_level_2() -> bool:
	if GameManager and GameManager.has_method("is_level_2"):
		if GameManager.is_level_2():
			return true
	var p = map_json_path.to_lower()
	if "карта_2" in p or "karta_2" in p or "карта_6" in p or "karta_6" in p or "level2" in p or "level_2" in p or "2level" in p:
		return true
	if GameManager and GameManager.active_map_path != "":
		var gp = GameManager.active_map_path.to_lower()
		if "карта_2" in gp or "karta_2" in gp or "карта_6" in gp or "karta_6" in gp or "level2" in gp or "level_2" in gp or "2level" in gp:
			return true
	return false

# ══════════════════════════════════════════════
#  UI
# ══════════════════════════════════════════════
func _setup_missions() -> void:
	var tracker: MissionTracker = null
	if _is_level_1():
		tracker = MissionTracker.new()
		tracker.setup([
			{"text": "Найди лом", "done": func(): return GameManager.has_crowbar},
			{"text": "Сорви доски с двери", "done": func(): return GameManager.door_boards_broken},
			{"text": "Найди ключ от двери", "done": func(): return GameManager.has_key or GameManager.has_key_id(1)},
			{"text": "Открой дверь и выберись"},
		])
	elif _is_level_2():
		tracker = MissionTracker.new()
		tracker.setup([
			{"text": "Найди три предохранителя", "done": func(): return GameManager.has_fuse_red and GameManager.has_fuse_blue and GameManager.has_fuse_green},
			{"text": "Вставь их в щиток и открой электроворота"},
		])
	if tracker:
		add_child(tracker)


func _setup_ui() -> void:
	var ui = load("res://scenes/UI.tscn").instantiate() as CanvasLayer
	ui.name = "UI"
	add_child(ui)
	GameManager.ui_ref = ui
