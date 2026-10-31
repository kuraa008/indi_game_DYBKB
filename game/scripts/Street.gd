extends Node3D

const TextureHelper = preload("res://scripts/TextureHelper.gd")
const ParallaxHorizon = preload("res://scripts/ParallaxHorizon.gd")

# ==============================================================================
#  Street.gd — Локация 'Улица' (Escape to Street)
#  Ночная туманная улица с дорогой, фонарями, заборами и машиной для побега
# ==============================================================================

var player_instance: CharacterBody3D = null
var ui_instance: CanvasLayer = null
var car_node: Node3D = null
var ambient_audio: AudioStreamPlayer = null
var escaped: bool = false
var elapsed_time: float = 0.0

var street_lights: Array[SpotLight3D] = []
var moon_clouds: Array[Node3D] = []
var street_env_node: WorldEnvironment = null
var moon_dir_light: DirectionalLight3D = null
var stars_node: MultiMeshInstance3D = null

func _ready() -> void:
	name = 'Street'
	_setup_environment()
	_build_sky_and_moon()
	_setup_audio()
	_build_ground_and_road()
	_build_house_facade()
	_build_street_elements()
	_build_escape_car()
	_spawn_player()
	_spawn_ui()

	if GameManager:
		GameManager.game_ended = false
		GameManager.graphics_quality_changed.connect(_apply_graphics_quality)
		_apply_graphics_quality(GameManager.graphics_quality)

func _process(delta: float) -> void:
	elapsed_time += delta

	# Купол ночных звезд следует за игроком
	if stars_node and is_instance_valid(stars_node):
		var cam = get_viewport().get_camera_3d()
		if cam and is_instance_valid(cam):
			stars_node.global_position = cam.global_position

	# Медленный зловещий дрейф верхних туч
	for c in moon_clouds:
		if is_instance_valid(c):
			var spd = c.get_meta("drift_speed", 0.5)
			c.position.x += spd * delta
			if c.position.x > 80.0:
				c.position.x = -80.0

	# Мерцание фонарей для хоррор-атмосферы
	for i in range(street_lights.size()):
		var light = street_lights[i]
		if is_instance_valid(light):
			var noise_val = sin(elapsed_time * (5.0 + i * 2.0)) * cos(elapsed_time * 8.3)
			if noise_val > 0.85:
				light.light_energy = randf_range(0.2, 0.7)
			else:
				light.light_energy = 2.4

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_7:
			get_tree().change_scene_to_file('res://scenes/DebugEditor.tscn')
		elif event.keycode == KEY_ESCAPE and escaped:
			get_tree().change_scene_to_file('res://scenes/Menu.tscn')

# ------------------------------------------------------------------------------
#  Окружение и ночной туман
# ------------------------------------------------------------------------------
func _setup_environment() -> void:
	street_env_node = WorldEnvironment.new()
	var env: Environment = null
	if ResourceLoader.exists("res://assets/night_env.tres"):
		env = load("res://assets/night_env.tres").duplicate() as Environment
	if not env:
		env = Environment.new()
		env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.04, 0.05, 0.09)
	env.ambient_light_energy = 0.32
	env.ambient_light_sky_contribution = 0.0

	# Густой ночной туман
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.08, 0.12)
	env.fog_density = 0.028
	env.fog_depth_begin = 4.0
	env.fog_depth_end = 65.0

	# Объемный туман для кинематографичной хоррор атмосферы
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.035
	env.volumetric_fog_albedo = Color(0.08, 0.10, 0.16)

	street_env_node.environment = env
	add_child(street_env_node)

	# Лунный бледный свет
	moon_dir_light = DirectionalLight3D.new()
	moon_dir_light.name = 'MoonLight'
	moon_dir_light.rotation_degrees = Vector3(-42, 28, 0)
	moon_dir_light.light_color = Color(0.70, 0.82, 1.0)
	moon_dir_light.light_energy = 0.20
	moon_dir_light.shadow_enabled = true
	add_child(moon_dir_light)

func _apply_graphics_quality(quality: String) -> void:
	if not street_env_node or not street_env_node.environment:
		return
	var env = street_env_node.environment
	env.ambient_light_color = Color(0.04, 0.05, 0.09)
	env.ambient_light_energy = 0.32
	if moon_dir_light:
		moon_dir_light.light_energy = 0.20
	match quality:
		"ultra", "high":
			env.ambient_light_color = Color(0.36, 0.43, 0.56)
			env.ambient_light_energy = 0.65
			env.ssao_enabled = true
			env.ssao_radius = 0.75
			env.ssao_intensity = 1.05
			env.ssao_power = 1.0
			env.ssao_detail = 0.5
			env.ssao_horizon = 0.08
			env.ssil_enabled = true
			env.ssil_radius = 2.5
			env.ssil_intensity = 1.0
			env.ssr_enabled = true
			env.ssr_max_steps = 48
			env.glow_enabled = true
			env.glow_bloom = 0.06
			env.glow_intensity = 0.55
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.sdfgi_enabled = false
			env.volumetric_fog_enabled = true
			env.volumetric_fog_density = 0.006
			env.volumetric_fog_albedo = Color(0.42, 0.50, 0.62)
			env.volumetric_fog_anisotropy = 0.35
			env.volumetric_fog_temporal_reprojection_enabled = true
			env.volumetric_fog_temporal_reprojection_amount = 0.96
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 1.25
			env.fog_density = 0.004
			env.adjustment_enabled = true
			env.adjustment_brightness = 1.04
			env.adjustment_contrast = 1.04
			env.tonemap_white = 5.5
			if moon_dir_light:
				moon_dir_light.shadow_enabled = true
				moon_dir_light.shadow_blur = 1.5
				moon_dir_light.light_energy = 0.55
		"medium":
			env.ssao_enabled = true
			env.ssao_radius = 1.2
			env.ssao_intensity = 1.6
			env.ssao_power = 1.0
			env.ssao_detail = 0.2
			env.ssao_horizon = 0.1
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.glow_enabled = true
			env.glow_bloom = 0.08
			env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
			env.sdfgi_enabled = false
			env.volumetric_fog_enabled = false
			env.fog_enabled = true
			env.fog_density = 0.028
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 1.0
			if moon_dir_light:
				moon_dir_light.shadow_enabled = true
				moon_dir_light.shadow_blur = 1.2
		"low":
			env.ssao_enabled = false
			env.ssil_enabled = false
			env.ssr_enabled = false
			env.glow_enabled = false
			env.sdfgi_enabled = false
			env.volumetric_fog_enabled = false
			env.fog_enabled = true
			env.fog_density = 0.02
			env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
			if moon_dir_light:
				moon_dir_light.shadow_enabled = false

func _build_sky_and_moon() -> void:
	var sky_root = Node3D.new()
	sky_root.name = "SkyElements"
	add_child(sky_root)

	# 1. Полнолуние (Большая детальная луна с кратерами и эмиссией)
	var moon_pos = Vector3(18.0, 42.0, -65.0)
	var moon_mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 4.8
	sphere.height = 9.6
	var moon_mat = StandardMaterial3D.new()
	var moon_tex = TextureHelper.get_texture("res://assets/textures/moon_surface.png")
	if moon_tex:
		moon_mat.albedo_texture = moon_tex
		moon_mat.roughness = 0.8
		moon_mat.emission_enabled = true
		moon_mat.emission_texture = moon_tex
		moon_mat.emission = Color(0.85, 0.92, 1.0)
		moon_mat.emission_energy_multiplier = 0.6
	else:
		moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_mat.albedo_color = Color(0.92, 0.95, 1.0)
	sphere.material = moon_mat
	moon_mesh_inst.mesh = sphere
	moon_mesh_inst.position = moon_pos
	moon_mesh_inst.rotation_degrees = Vector3(15, -35, 10)
	sky_root.add_child(moon_mesh_inst)

	# 2. Ореол свечения вокруг луны (Корона и свечение)
	var glow_tex = TextureHelper.get_texture("res://assets/textures/moon_glow.png")

	# Внутренний ореол
	var halo = MeshInstance3D.new()
	var hm = QuadMesh.new()
	hm.size = Vector2(26.0, 26.0)
	var hmat = StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow_tex:
		hmat.albedo_texture = glow_tex
		hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hmat.albedo_color = Color(0.65, 0.80, 1.0, 0.65)
	else:
		hmat.albedo_color = Color(0.55, 0.72, 0.98, 0.22)
	hm.material = hmat
	halo.mesh = hm
	halo.position = moon_pos + Vector3(0, 0, 1.2)
	halo.rotation_degrees = Vector3(30, -15, 0)
	sky_root.add_child(halo)

	# Внешнее мягкое рассеивание
	var outer_halo = MeshInstance3D.new()
	var ohm = QuadMesh.new()
	ohm.size = Vector2(52.0, 52.0)
	var ohmat = StandardMaterial3D.new()
	ohmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ohmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow_tex:
		ohmat.albedo_texture = glow_tex
		ohmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ohmat.albedo_color = Color(0.35, 0.55, 0.85, 0.25)
	else:
		ohmat.albedo_color = Color(0.35, 0.55, 0.85, 0.08)
	ohm.material = ohmat
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

	# 4. Мерцающий купол ночных звезд (280 мягких биллборд-звезд, не кубиков!)
	stars_node = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var star_mesh = QuadMesh.new()
	star_mesh.size = Vector2(0.24, 0.24)
	var star_mat = StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	star_mat.vertex_color_use_as_albedo = true
	star_mesh.material = star_mat
	mm.mesh = star_mesh
	mm.instance_count = 280

	for s_i in range(280):
		var theta = randf_range(0.0, TAU)
		var phi = randf_range(0.15, 1.35)
		var r = randf_range(65.0, 95.0)
		var sx = r * sin(phi) * cos(theta)
		var sy = r * cos(phi) + 12.0
		var sz = r * sin(phi) * sin(theta) - 25.0

		var t = Transform3D()
		t.origin = Vector3(sx, sy, sz)
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

	# 5. Живой многослойный параллакс горизонта (Горы и Ночной Город)
	var parallax = ParallaxHorizon.new()
	sky_root.add_child(parallax)

# ------------------------------------------------------------------------------
#  Звуки улицы (ветер + крик вдали)
# ------------------------------------------------------------------------------
func _setup_audio() -> void:
	ambient_audio = AudioStreamPlayer.new()
	var s: AudioStream = null
	if ResourceLoader.exists('res://assets/ambient_night.mp3'):
		s = load('res://assets/ambient_night.mp3')
	elif ResourceLoader.exists('res://assets/ambient1.mp3'):
		s = load('res://assets/ambient1.mp3')
	if s:
		if s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
		ambient_audio.stream = s
		ambient_audio.volume_db = -2.0
		add_child(ambient_audio)
		ambient_audio.play()

# ------------------------------------------------------------------------------
#  Земля и дорога
# ------------------------------------------------------------------------------
func _build_ground_and_road() -> void:
	# Трава / земля по бокам
	var ground = MeshInstance3D.new()
	ground.name = 'StreetGround'
	var pm = PlaneMesh.new()
	pm.size = Vector2(90, 110)
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.04, 0.05, 0.035)
	gmat.roughness = 0.95
	pm.material = gmat
	ground.mesh = pm
	ground.position = Vector3(0, 0, -25)

	var sb = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(90, 0.2, 110)
	col.shape = shape
	col.position = Vector3(0, -0.1, 0)
	sb.add_child(col)
	ground.add_child(sb)
	add_child(ground)

	# Асфальт / гравийная дорога (по центру)
	var road = MeshInstance3D.new()
	road.name = 'Road'
	var rpm = PlaneMesh.new()
	rpm.size = Vector2(7.0, 90.0)
	var rmat = StandardMaterial3D.new()
	rmat.albedo_color = Color(0.08, 0.08, 0.09)
	rmat.roughness = 0.9
	rpm.material = rmat
	road.mesh = rpm
	road.position = Vector3(0, 0.01, -25)
	add_child(road)

	# Обочины дороги
	for side in [-3.6, 3.6]:
		var shoulder = MeshInstance3D.new()
		var spm = PlaneMesh.new()
		spm.size = Vector2(0.8, 90.0)
		var smat = StandardMaterial3D.new()
		smat.albedo_color = Color(0.12, 0.10, 0.08)
		spm.material = smat
		shoulder.mesh = spm
		shoulder.position = Vector3(side, 0.015, -25)
		add_child(shoulder)

	# Невидимые границы улицы
	_build_invisible_wall(Vector3(-10, 2, -25), Vector3(1, 6, 100))
	_build_invisible_wall(Vector3(10, 2, -25), Vector3(1, 6, 100))
	_build_invisible_wall(Vector3(0, 2, 8), Vector3(25, 6, 1))
	_build_invisible_wall(Vector3(0, 2, -62), Vector3(25, 6, 1))

func _build_invisible_wall(pos: Vector3, sz: Vector3) -> void:
	var sb = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = sz
	col.shape = box
	sb.position = pos
	sb.add_child(col)
	add_child(sb)

# ------------------------------------------------------------------------------
#  Фасад особняка позади игрока (крыльцо, дверь со светом)
# ------------------------------------------------------------------------------
func _build_house_facade() -> void:
	var house_root = Node3D.new()
	house_root.position = Vector3(0, 0, 6.0)
	add_child(house_root)

	# Деревянное крыльцо
	var porch = MeshInstance3D.new()
	var pbox = BoxMesh.new()
	pbox.size = Vector3(5.0, 0.4, 3.5)
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.24, 0.16, 0.10)
	pbox.material = pmat
	porch.mesh = pbox
	porch.position = Vector3(0, 0.2, 0)
	var psb = StaticBody3D.new()
	var pcol = CollisionShape3D.new()
	var pshape = BoxShape3D.new()
	pshape.size = pbox.size
	pcol.shape = pshape
	psb.add_child(pcol)
	porch.add_child(psb)
	house_root.add_child(porch)

	# Ступени крыльца
	for step_i in range(2):
		var step = MeshInstance3D.new()
		var sbox = BoxMesh.new()
		sbox.size = Vector3(3.5, 0.2, 0.6)
		sbox.material = pmat
		step.mesh = sbox
		step.position = Vector3(0, 0.1 - step_i * 0.1, -1.8 - step_i * 0.45)
		house_root.add_child(step)

	# Стена дома
	var wall = MeshInstance3D.new()
	var wbox = BoxMesh.new()
	wbox.size = Vector3(16.0, 6.0, 1.0)
	var wmat = StandardMaterial3D.new()
	wmat.albedo_color = Color(0.18, 0.13, 0.10)
	wbox.material = wmat
	wall.mesh = wbox
	wall.position = Vector3(0, 3.0, 1.5)
	var wsb = StaticBody3D.new()
	var wcol = CollisionShape3D.new()
	var wshape = BoxShape3D.new()
	wshape.size = wbox.size
	wcol.shape = wshape
	wsb.add_child(wcol)
	wall.add_child(wsb)
	house_root.add_child(wall)

	# Распахнутая дверь в дом
	var door_opening = MeshInstance3D.new()
	var dbox = BoxMesh.new()
	dbox.size = Vector3(1.3, 2.4, 0.2)
	var dmat = StandardMaterial3D.new()
	dmat.albedo_color = Color(0.1, 0.05, 0.02)
	dbox.material = dmat
	door_opening.mesh = dbox
	door_opening.position = Vector3(0, 1.2, 1.0)
	house_root.add_child(door_opening)

	# Жуткий красный свет изнутри дома
	var house_light = OmniLight3D.new()
	house_light.position = Vector3(0, 1.8, 1.5)
	house_light.light_color = Color(1.0, 0.15, 0.05)
	house_light.light_energy = 3.2
	house_light.omni_range = 7.0
	house_root.add_child(house_light)

# ------------------------------------------------------------------------------
#  Фонарные столбы, заборы и силуэты сосен
# ------------------------------------------------------------------------------
func _build_street_elements() -> void:
	# Фонарные столбы (Z = -6, -22, -38)
	var lamp_z_coords = [-6.0, -22.0, -38.0]
	for idx in range(lamp_z_coords.size()):
		var lz = lamp_z_coords[idx]
		var lx = 4.2 if idx % 2 == 0 else -4.2
		_build_lamp_post(Vector3(lx, 0, lz), -1.0 if lx > 0 else 1.0)

	# Заборы вдоль дороги
	for side_x in [-4.8, 4.8]:
		for z_pos in range(-52, 6, 4):
			_build_fence_section(Vector3(side_x, 0, z_pos))

	# Деревья вдоль улицы в тумане
	for tz in range(-55, 6, 6):
		_build_pine_tree(Vector3(-7.5 - randf_range(0, 3), 0, tz + randf_range(-1, 1)))
		_build_pine_tree(Vector3(7.5 + randf_range(0, 3), 0, tz + randf_range(-1, 1)))

	# Столбы ЛЭП с проводами
	for pz in [-8.0, -24.0, -42.0]:
		var pole = PrefabBuilder.build_prefab("prop_power_pole", Vector3(2.4, 7.2, 3.0), Color.WHITE, false)
		pole.position = Vector3(5.6, 0, pz)
		add_child(pole)

	# Корявые мертвые деревья
	for dtz in [-14.0, -30.0, -46.0]:
		var dtree = PrefabBuilder.build_prefab("prop_tree_dead", Vector3(3.2, 5.8, 3.2), Color.WHITE, false)
		dtree.position = Vector3(-7.6, 0, dtz)
		dtree.rotation_degrees.y = randf_range(0, 360)
		add_child(dtree)

	# Сухие колючие кусты вдоль заборов
	for bz in [-10.0, -20.0, -34.0, -46.0]:
		var bush = PrefabBuilder.build_prefab("prop_bush_dead", Vector3(1.4, 1.2, 1.4), Color.WHITE, false)
		bush.position = Vector3(4.9 if bz < -25 else -4.9, 0, bz)
		add_child(bush)

	# Аварийный дорожный барьер
	var bar1 = PrefabBuilder.build_prefab("prop_road_barrier", Vector3(2.2, 1.0, 0.6), Color.WHITE, false)
	bar1.position = Vector3(-2.2, 0, -20.0)
	bar1.rotation_degrees.y = 15.0
	add_child(bar1)

	# Разбитый брошенный остов авто на обочине в тумане
	var wreck = PrefabBuilder.build_prefab("prop_car_wreck", Vector3(2.1, 1.4, 4.4), Color.WHITE, false)
	wreck.position = Vector3(-4.6, 0, -32.0)
	wreck.rotation_degrees.y = -22.0
	add_child(wreck)

func _build_lamp_post(pos: Vector3, arm_dir: float) -> void:
	var post = MeshInstance3D.new()
	var post_mesh = CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.12
	post_mesh.height = 4.5
	var pmat = StandardMaterial3D.new()
	pmat.albedo_color = Color(0.2, 0.22, 0.25)
	post_mesh.material = pmat
	post.mesh = post_mesh
	post.position = pos + Vector3(0, 2.25, 0)

	var sb = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var cap = CylinderShape3D.new()
	cap.radius = 0.15
	cap.height = 4.5
	col.shape = cap
	sb.add_child(col)
	post.add_child(sb)
	add_child(post)

	# Перекладина фонаря над дорогой
	var arm = MeshInstance3D.new()
	var abox = BoxMesh.new()
	abox.size = Vector3(1.2, 0.1, 0.1)
	abox.material = pmat
	arm.mesh = abox
	arm.position = pos + Vector3(arm_dir * 0.6, 4.4, 0)
	add_child(arm)

	# Плафон фонаря
	var lamp_bulb = MeshInstance3D.new()
	var bmesh = SphereMesh.new()
	bmesh.radius = 0.18
	bmesh.height = 0.36
	var bmat = StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.albedo_color = Color(1.0, 0.9, 0.6)
	bmesh.material = bmat
	lamp_bulb.mesh = bmesh
	lamp_bulb.position = pos + Vector3(arm_dir * 1.1, 4.3, 0)
	add_child(lamp_bulb)

	# Конус света вниз на дорогу
	var spot = SpotLight3D.new()
	spot.position = pos + Vector3(arm_dir * 1.1, 4.2, 0)
	spot.rotation_degrees = Vector3(-85, 0, 0)
	spot.light_color = Color(1.0, 0.88, 0.65)
	spot.light_energy = 2.4
	spot.spot_range = 10.0
	spot.spot_angle = 50.0
	spot.shadow_enabled = true
	add_child(spot)
	street_lights.append(spot)

func _build_fence_section(pos: Vector3) -> void:
	var f = MeshInstance3D.new()
	var b = BoxMesh.new()
	b.size = Vector3(0.12, 1.2, 3.8)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.17, 0.12)
	b.material = mat
	f.mesh = b
	f.position = pos + Vector3(0, 0.6, 0)

	var sb = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = b.size
	col.shape = shape
	sb.add_child(col)
	f.add_child(sb)
	add_child(f)

func _build_pine_tree(pos: Vector3) -> void:
	var tree = Node3D.new()
	tree.position = pos

	# Ствол
	var trunk = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.18
	cyl.bottom_radius = 0.28
	cyl.height = 4.0
	var tmat = StandardMaterial3D.new()
	tmat.albedo_color = Color(0.18, 0.12, 0.08)
	cyl.material = tmat
	trunk.mesh = cyl
	trunk.position = Vector3(0, 2.0, 0)
	tree.add_child(trunk)

	# Крона из конусов
	for tier in range(3):
		var fol = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.8 - tier * 0.4
		cone.height = 2.4
		var fmat = StandardMaterial3D.new()
		fmat.albedo_color = Color(0.04, 0.08, 0.05)
		cone.material = fmat
		fol.mesh = cone
		fol.position = Vector3(0, 3.2 + tier * 1.5, 0)
		tree.add_child(fol)

	add_child(tree)

# ------------------------------------------------------------------------------
#  Машина для побега в конце улицы (Z = -48)
# ------------------------------------------------------------------------------
func _build_escape_car() -> void:
	car_node = Node3D.new()
	car_node.name = 'EscapeCar'
	car_node.position = Vector3(0.5, 0, -48.0)
	add_child(car_node)

	# Корпус пикапа
	var body = MeshInstance3D.new()
	var bbox = BoxMesh.new()
	bbox.size = Vector3(2.2, 0.8, 4.4)
	var bmat = StandardMaterial3D.new()
	bmat.albedo_color = Color(0.15, 0.22, 0.35)
	bmat.roughness = 0.5
	bbox.material = bmat
	body.mesh = bbox
	body.position = Vector3(0, 0.7, 0)
	car_node.add_child(body)

	# Кабина
	var cabin = MeshInstance3D.new()
	var cbox = BoxMesh.new()
	cbox.size = Vector3(2.0, 0.8, 2.0)
	var cmat = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.12, 0.16, 0.24)
	cbox.material = cmat
	cabin.mesh = cbox
	cabin.position = Vector3(0, 1.45, 0.4)
	car_node.add_child(cabin)

	# Колёса (4 шт)
	for wx in [-1.15, 1.15]:
		for wz in [-1.4, 1.4]:
			var wheel = MeshInstance3D.new()
			var wcyl = CylinderMesh.new()
			wcyl.top_radius = 0.38
			wcyl.bottom_radius = 0.38
			wcyl.height = 0.25
			var wmat = StandardMaterial3D.new()
			wmat.albedo_color = Color(0.08, 0.08, 0.08)
			wcyl.material = wmat
			wheel.mesh = wcyl
			wheel.rotation_degrees = Vector3(0, 0, 90)
			wheel.position = Vector3(wx, 0.38, wz)
			car_node.add_child(wheel)

	# Коллизия машины
	var csb = StaticBody3D.new()
	var ccol = CollisionShape3D.new()
	var cshape = BoxShape3D.new()
	cshape.size = Vector3(2.4, 1.8, 4.6)
	ccol.shape = cshape
	ccol.position = Vector3(0, 0.9, 0)
	csb.add_child(ccol)
	car_node.add_child(csb)

	# Фары
	for fx in [-0.75, 0.75]:
		var bulb = MeshInstance3D.new()
		var s = SphereMesh.new()
		s.radius = 0.14
		s.height = 0.28
		var lm = StandardMaterial3D.new()
		lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		lm.albedo_color = Color(1.0, 0.98, 0.8)
		s.material = lm
		bulb.mesh = s
		bulb.position = Vector3(fx, 0.72, -2.2)
		car_node.add_child(bulb)

		var spot = SpotLight3D.new()
		spot.position = Vector3(fx, 0.72, -2.2)
		spot.rotation_degrees = Vector3(-5, 180, 0)
		spot.light_color = Color(1.0, 0.96, 0.85)
		spot.light_energy = 5.0
		spot.spot_range = 28.0
		spot.spot_angle = 35.0
		car_node.add_child(spot)

	# Зона триггера побега
	var area = Area3D.new()
	area.name = 'EscapeTrigger'
	var acol = CollisionShape3D.new()
	var ashape = BoxShape3D.new()
	ashape.size = Vector3(5.0, 3.0, 6.0)
	acol.shape = ashape
	acol.position = Vector3(0, 1.2, 0)
	area.add_child(acol)
	car_node.add_child(area)
	area.body_entered.connect(_on_escape_area_entered)

# ------------------------------------------------------------------------------
#  Спавн персонажа и UI
# ------------------------------------------------------------------------------
func _spawn_player() -> void:
	var p_scene = load('res://scenes/Player.tscn')
	if p_scene:
		player_instance = p_scene.instantiate() as CharacterBody3D
		player_instance.position = Vector3(0, 0.5, 3.0)
		player_instance.rotation_degrees = Vector3(0, 180, 0)
		add_child(player_instance)
		if GameManager:
			GameManager.player_ref = player_instance

func _spawn_ui() -> void:
	var ui_sc = load('res://scenes/UI.tscn')
	if ui_sc:
		ui_instance = ui_sc.instantiate() as CanvasLayer
		add_child(ui_instance)
		if GameManager:
			GameManager.ui_ref = ui_instance

# ------------------------------------------------------------------------------
#  Побег игрока к машине
# ------------------------------------------------------------------------------
func _on_escape_area_entered(body: Node) -> void:
	if escaped:
		return
	if body is CharacterBody3D and (body == player_instance or body.name == 'Player'):
		_trigger_street_escape()

func _trigger_street_escape() -> void:
	escaped = true
	if GameManager:
		GameManager.game_ended = true

	if ambient_audio:
		ambient_audio.stop()

	_show_escape_screen()

func _show_escape_screen() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0.01, 0.05, 0.02, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override('separation', 20)
	canvas.add_child(vb)

	var title = Label.new()
	title.text = 'ТЫ ВЫБРАЛСЯ!'
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override('font_size', 56)
	title.add_theme_color_override('font_color', Color(0.25, 0.95, 0.40))
	vb.add_child(title)

	var desc = Label.new()
	desc.text = 'Машина завелась с полуоборота. Оставив позади проклятый дом
и силуэт Скинвокера во тьме, вы скрылись в ночи.'
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override('font_size', 16)
	desc.add_theme_color_override('font_color', Color(0.85, 0.90, 0.95))
	vb.add_child(desc)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)

	var btn_hb = HBoxContainer.new()
	btn_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hb.add_theme_constant_override('separation', 16)
	vb.add_child(btn_hb)

	var btn_again = Button.new()
	btn_again.text = 'ИГРАТЬ СНОВА'
	btn_again.custom_minimum_size = Vector2(180, 46)
	btn_again.add_theme_font_size_override('font_size', 16)
	btn_again.pressed.connect(func(): get_tree().change_scene_to_file('res://scenes/Main.tscn'))
	btn_hb.add_child(btn_again)

	var btn_menu = Button.new()
	btn_menu.text = 'В ГЛАВНОЕ МЕНЮ (ESC)'
	btn_menu.custom_minimum_size = Vector2(220, 46)
	btn_menu.add_theme_font_size_override('font_size', 16)
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file('res://scenes/Menu.tscn'))
	btn_hb.add_child(btn_menu)
