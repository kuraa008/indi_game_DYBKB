class_name ParallaxHorizon
extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  ParallaxHorizon.gd — Многослойный живой горизонт (Горы и Ночной Город)
#  Создает ощущение бескрайнего мира с панорамными горами, светящимся городом
#  вдали, мигающими авиационными маяками и динамическим параллакс-смещением
# ══════════════════════════════════════════════════════════════════════════════

const TextureHelper = preload("res://scripts/TextureHelper.gd")

var layer_far_mountains: Node3D = null
var layer_mid_mountains: Node3D = null
var layer_city: Node3D = null

var beacon_materials: Array[StandardMaterial3D] = []
var beacon_time: float = 0.0

# Коэффициенты следования за камерой (чем ближе к 1.0, тем дальше кажется объект)
const PARALLAX_FAR_MOUNTAINS: float = 0.96
const PARALLAX_MID_MOUNTAINS: float = 0.91
const PARALLAX_CITY: float = 0.86

func _ready() -> void:
	name = "ParallaxHorizon"
	build_horizon()

func build_horizon() -> void:
	if layer_far_mountains:
		return
	_build_far_mountains()
	_build_mid_mountains()
	_build_city_skyline()

func _process(delta: float) -> void:
	# 1. Мигание красных авиационных маяков на небоскребах
	beacon_time += delta
	var beacon_on: bool = fmod(beacon_time, 1.2) < 0.65
	var beacon_energy: float = 3.5 if beacon_on else 0.15
	for mat in beacon_materials:
		mat.emission_energy_multiplier = beacon_energy

	# 2. Параллакс следование за активной камерой
	if not is_inside_tree():
		return
	var vp = get_viewport()
	if not vp:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if not cam or not is_instance_valid(cam):
		return

	var cam_pos = cam.global_position
	var base_y = cam_pos.y * 0.25 # Горизонт плавно удерживается на уровне взгляда

	if layer_far_mountains and is_instance_valid(layer_far_mountains):
		layer_far_mountains.global_position = Vector3(
			cam_pos.x * PARALLAX_FAR_MOUNTAINS,
			base_y - 2.0,
			cam_pos.z * PARALLAX_FAR_MOUNTAINS
		)

	if layer_mid_mountains and is_instance_valid(layer_mid_mountains):
		layer_mid_mountains.global_position = Vector3(
			cam_pos.x * PARALLAX_MID_MOUNTAINS,
			base_y - 1.0,
			cam_pos.z * PARALLAX_MID_MOUNTAINS
		)

	if layer_city and is_instance_valid(layer_city):
		layer_city.global_position = Vector3(
			cam_pos.x * PARALLAX_CITY,
			base_y,
			cam_pos.z * PARALLAX_CITY
		)

# ──────────────────────────────────────────────────────────────────────────────
#  Слой 1: Дальние величественные горные хребты (Far Mountains)
# ──────────────────────────────────────────────────────────────────────────────
func _build_far_mountains() -> void:
	layer_far_mountains = Node3D.new()
	layer_far_mountains.name = "LayerFarMountains"
	add_child(layer_far_mountains)

	var mountain_mat = StandardMaterial3D.new()
	mountain_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mountain_mat.albedo_color = Color(0.018, 0.024, 0.045)
	mountain_mat.roughness = 0.95
	mountain_mat.metallic = 0.0
	mountain_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var num_peaks = 28
	var radius_base = 290.0

	for i in range(num_peaks):
		var angle = (float(i) / float(num_peaks)) * TAU + randf_range(-0.06, 0.06)
		var dist = radius_base + randf_range(-25.0, 25.0)
		var px = cos(angle) * dist
		var pz = sin(angle) * dist

		var peak_height = randf_range(50.0, 95.0)
		var peak_base_w = randf_range(45.0, 85.0)
		var peak_base_d = randf_range(40.0, 80.0)

		var mesh_inst = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(peak_base_w, peak_height, peak_base_d)
		prism.surface_set_material(0, mountain_mat)
		mesh_inst.mesh = prism
		mesh_inst.position = Vector3(px, peak_height * 0.45 - 6.0, pz)
		mesh_inst.rotation_degrees = Vector3(randf_range(-3, 3), rad_to_deg(angle) + randf_range(-20, 20), randf_range(-3, 3))
		layer_far_mountains.add_child(mesh_inst)

# ──────────────────────────────────────────────────────────────────────────────
#  Слой 2: Средний хребет и холмы (Mid Mountains)
# ──────────────────────────────────────────────────────────────────────────────
func _build_mid_mountains() -> void:
	layer_mid_mountains = Node3D.new()
	layer_mid_mountains.name = "LayerMidMountains"
	add_child(layer_mid_mountains)

	var mid_mat = StandardMaterial3D.new()
	mid_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mid_mat.albedo_color = Color(0.012, 0.016, 0.032)
	mid_mat.roughness = 0.9
	mid_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

	var num_peaks = 36
	var radius_base = 210.0

	for i in range(num_peaks):
		var angle = (float(i) / float(num_peaks)) * TAU + randf_range(-0.08, 0.08)
		# Пропускаем сектор города, чтобы город открывался эффектной панорамой
		var deg = rad_to_deg(angle)
		if deg > 15.0 and deg < 75.0:
			continue

		var dist = radius_base + randf_range(-20.0, 20.0)
		var px = cos(angle) * dist
		var pz = sin(angle) * dist

		var peak_height = randf_range(28.0, 56.0)
		var peak_base_w = randf_range(30.0, 58.0)
		var peak_base_d = randf_range(28.0, 55.0)

		var mesh_inst = MeshInstance3D.new()
		var prism = PrismMesh.new()
		prism.size = Vector3(peak_base_w, peak_height, peak_base_d)
		prism.surface_set_material(0, mid_mat)
		mesh_inst.mesh = prism
		mesh_inst.position = Vector3(px, peak_height * 0.45 - 4.0, pz)
		mesh_inst.rotation_degrees = Vector3(randf_range(-2, 2), rad_to_deg(angle) + randf_range(-25, 25), randf_range(-2, 2))
		layer_mid_mountains.add_child(mesh_inst)

# ──────────────────────────────────────────────────────────────────────────────
#  Слой 3: Панорама ночного города со светящимися окнами и маяками (City Skyline)
# ──────────────────────────────────────────────────────────────────────────────
func _build_city_skyline() -> void:
	layer_city = Node3D.new()
	layer_city.name = "LayerCitySkyline"
	add_child(layer_city)

	var city_tex = TextureHelper.get_texture("res://assets/textures/city_windows.png")

	# Материал фасада зданий: 100% глубокий черный монолит с четкими горящими белыми окнами
	var building_mat: Material = null
	var city_shader = load("res://assets/shaders/city_building.gdshader")
	if city_shader:
		var sh_mat = ShaderMaterial.new()
		sh_mat.shader = city_shader
		if city_tex:
			sh_mat.set_shader_parameter("windows_tex", city_tex)
		sh_mat.set_shader_parameter("uv_scale", 0.045)
		sh_mat.set_shader_parameter("window_brightness", 1.6)
		building_mat = sh_mat
	else:
		var fallback_mat = StandardMaterial3D.new()
		fallback_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fallback_mat.albedo_color = Color(0.01, 0.01, 0.01)
		building_mat = fallback_mat

	# Общий материал для мигающих красных маячков
	var beacon_mat = StandardMaterial3D.new()
	beacon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beacon_mat.albedo_color = Color(1.0, 0.15, 0.15)
	beacon_mat.emission_enabled = true
	beacon_mat.emission = Color(1.0, 0.1, 0.1)
	beacon_mat.emission_energy_multiplier = 3.5
	beacon_materials.append(beacon_mat)

	# Располагаем город в живописном секторе горизонта (азимут 20° .. 70°, Z < 0)
	var city_center_angle = deg_to_rad(45.0)
	var city_angular_span = deg_to_rad(55.0)
	var num_buildings = 32
	var radius_base = 230.0

	for b_i in range(num_buildings):
		var t = float(b_i) / float(num_buildings - 1)
		var angle = (city_center_angle - city_angular_span * 0.5) + t * city_angular_span + randf_range(-0.02, 0.02)
		var dist = radius_base + randf_range(-25.0, 25.0)

		var bx = cos(angle) * dist
		var bz = sin(angle) * dist

		# Случайный силуэт здания: небоскреб, башня или широкий блок
		var b_h = randf_range(26.0, 72.0)
		var b_w = randf_range(12.0, 26.0)
		var b_d = randf_range(12.0, 24.0)

		var building_node = Node3D.new()
		building_node.name = "Building_%d" % b_i
		building_node.position = Vector3(bx, b_h * 0.5 - 5.0, bz)
		building_node.rotation_degrees.y = rad_to_deg(angle) + randf_range(-15.0, 15.0)

		# Основной корпус
		var b_mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(b_w, b_h, b_d)
		box.surface_set_material(0, building_mat)
		b_mesh_inst.mesh = box
		building_node.add_child(b_mesh_inst)

		# Верхняя ступень / надстройка для некоторых высоких зданий
		if b_h > 45.0:
			var top_h = randf_range(8.0, 16.0)
			var top_w = b_w * 0.6
			var top_d = b_d * 0.6
			var top_inst = MeshInstance3D.new()
			var top_box = BoxMesh.new()
			top_box.size = Vector3(top_w, top_h, top_d)
			top_box.surface_set_material(0, building_mat)
			top_inst.mesh = top_box
			top_inst.position = Vector3(0, (b_h * 0.5) + (top_h * 0.5), 0)
			building_node.add_child(top_inst)

			# Антенна / шпиль с красным маячком на вершине самых высоких зданий
			if randf() < 0.65:
				var spire_h = randf_range(6.0, 14.0)
				var spire_inst = MeshInstance3D.new()
				var cyl = CylinderMesh.new()
				cyl.top_radius = 0.08
				cyl.bottom_radius = 0.25
				cyl.height = spire_h
				var spire_mat = StandardMaterial3D.new()
				spire_mat.albedo_color = Color(0.1, 0.12, 0.15)
				spire_mat.roughness = 0.7
				cyl.surface_set_material(0, spire_mat)
				spire_inst.mesh = cyl
				var spire_base_y = (b_h * 0.5) + top_h + (spire_h * 0.5)
				spire_inst.position = Vector3(0, spire_base_y, 0)
				building_node.add_child(spire_inst)

				# Красный авиационный маяк
				var beacon = MeshInstance3D.new()
				var beacon_sphere = SphereMesh.new()
				beacon_sphere.radius = 0.55
				beacon_sphere.height = 1.1
				beacon_sphere.surface_set_material(0, beacon_mat)
				beacon.mesh = beacon_sphere
				beacon.position = Vector3(0, spire_base_y + (spire_h * 0.5) + 0.3, 0)
				building_node.add_child(beacon)

		layer_city.add_child(building_node)
