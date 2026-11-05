class_name PrefabBuilder
extends RefCounted

const TextureHelper = preload("res://scripts/TextureHelper.gd")

# ══════════════════════════════════════════════════════════════════════════════
#  PrefabBuilder.gd — процедурный сборщик низкополигональных 3D-моделей
#  Обеспечивает 100% синхронизацию визуализации и физики между DebugEditor и Main
# ══════════════════════════════════════════════════════════════════════════════

static func get_prefab_base_size(type: String) -> Vector3:
	match type:
		"prop_table": return Vector3(1.80, 0.80, 0.95)
		"prop_chair": return Vector3(0.52, 0.96, 0.52)
		"prop_alarm_clock", "alarm_clock": return Vector3(0.25, 0.25, 0.25)
		"prop_tv_remote", "tv_remote", "remote": return Vector3(0.12, 0.05, 0.25)
		"prop_bed": return Vector3(1.48, 0.88, 2.12)
		"prop_wardrobe": return Vector3(1.40, 2.24, 0.70)
		"prop_nightstand": return Vector3(0.66, 0.74, 0.55)
		"prop_dresser": return Vector3(1.30, 1.10, 0.55)
		"prop_cupboard": return Vector3(0.80, 0.90, 0.35)
		"prop_sofa": return Vector3(2.40, 0.95, 1.05)
		"prop_armchair": return Vector3(1.10, 0.95, 1.00)
		"prop_tv": return Vector3(1.60, 1.00, 0.35)
		"prop_crt_tv": return Vector3(0.74, 0.86, 0.48)
		"prop_bookshelf": return Vector3(1.40, 2.20, 0.45)
		"prop_lamp_floor": return Vector3(0.60, 1.90, 0.60)
		"prop_grandfather_clock": return Vector3(0.65, 2.20, 0.45)
		"prop_occult_altar": return Vector3(1.30, 1.20, 0.80)
		"prop_safe": return Vector3(0.64, 0.74, 0.58)
		"prop_crate": return Vector3(1.00, 1.00, 1.00)
		"prop_barrel": return Vector3(0.70, 1.10, 0.70)
		"prop_carpet": return Vector3(3.60, 0.04, 2.40)
		"prop_blood_puddle": return Vector3(2.00, 0.04, 2.00)
		"prop_blood_wall": return Vector3(0.80, 1.20, 0.10)
		"prop_fridge": return Vector3(0.90, 2.00, 0.90)
		"prop_stove": return Vector3(0.85, 0.95, 0.85)
		"prop_kitchen_counter": return Vector3(1.20, 0.95, 0.75)
		"prop_toilet": return Vector3(0.60, 0.85, 0.75)
		"prop_bathtub": return Vector3(1.70, 0.65, 0.85)
		"prop_sink": return Vector3(0.65, 0.90, 0.55)
		"prop_shower_cabin": return Vector3(1.10, 2.10, 1.10)
		"prop_mirror": return Vector3(0.90, 1.60, 0.08)
		"prop_mirror_broken": return Vector3(0.80, 1.20, 0.08)
		"prop_car": return Vector3(2.00, 1.50, 4.40)
		"prop_car_wreck": return Vector3(2.10, 1.40, 4.40)
		"prop_ethan_car": return EthanCar.SIZE
		"prop_bench": return Vector3(1.60, 0.85, 0.65)
		"prop_streetlight": return Vector3(0.60, 4.20, 0.90)
		"prop_fence_section": return Vector3(2.50, 1.40, 0.12)
		"prop_trash_bin": return Vector3(0.65, 0.95, 0.65)
		"prop_hydrant": return Vector3(0.50, 0.80, 0.50)
		"prop_mailbox": return Vector3(0.40, 1.20, 0.55)
		"prop_tree", "prop_tree_pine": return Vector3(3.00, 6.00, 3.00)
		"prop_tree_dead": return Vector3(3.20, 5.80, 3.20)
		"prop_tree_carved", "prop_tree_warning", "prop_tree_claws": return Vector3(3.20, 6.20, 3.20)
		"prop_bush_dead": return Vector3(1.40, 1.20, 1.40)
		"prop_leaves_pile": return Vector3(2.40, 0.14, 2.40)
		"prop_bush_foliage": return Vector3(1.80, 1.40, 1.80)
		"prop_tree_deciduous": return Vector3(4.00, 6.50, 4.00)
		"prop_ivy_wall": return Vector3(1.80, 2.60, 0.15)
		"prop_power_pole": return Vector3(2.40, 7.50, 3.00)
		"prop_road_barrier": return Vector3(2.20, 1.00, 0.60)
		"prop_rock_large": return Vector3(4.50, 3.20, 4.00)
		"prop_window_boarded": return Vector3(1.60, 1.60, 0.25)
		"prop_basement_entrance": return Vector3(2.00, 1.25, 2.40)
		"prop_dog": return Vector3(0.70, 0.75, 1.10)
		"prop_plant_pot": return Vector3(0.60, 0.90, 0.60)
		"door", "door_simple", "custom_door_simple": return Vector3(1.02, 2.12, 0.15)
		"door_electric", "custom_door_electric": return Vector3(1.02, 2.12, 0.15)
		"door_exit", "custom_door_exit": return Vector3(1.02, 2.12, 0.15)
		"door_metal", "custom_door_metal": return Vector3(1.02, 2.12, 0.15)
		"door_hatch", "custom_door_hatch": return Vector3(1.50, 0.25, 1.50)
		"prop_fusebox": return Vector3(0.50, 0.68, 0.25)
		"prop_light_switch": return Vector3(0.20, 0.30, 0.10)
		"light_ceiling": return Vector3(0.50, 0.80, 0.50)
		"item_crowbar": return Vector3(0.40, 0.60, 0.40)
		"item_key", "item_key_gold", "item_key_silver", "item_key_rusty", "item_key_emerald": return Vector3(0.30, 0.40, 0.30)
		"item_battery": return Vector3(0.30, 0.40, 0.30)
		"item_fuse_red", "item_fuse_blue", "item_fuse_green": return Vector3(0.30, 0.40, 0.30)
		"prop_note", "prop_note_safe": return Vector3(0.40, 0.10, 0.30)
		"spawn_player", "marker_player": return Vector3(0.80, 1.80, 0.80)
		"spawn_enemy", "marker_enemy": return Vector3(0.90, 2.20, 0.90)
		"spawn_lumberjack", "marker_lumberjack": return Vector3(0.85, 2.00, 0.85)
		"road_segment": return Vector3(12.0, 0.12, 40.0)
		"roof_gable": return Vector3(12.0, 2.40, 8.0)
		"stairs_straight": return Vector3(1.60, 3.60, 4.20)
		"stairs_metal": return Vector3(1.40, 3.60, 4.20)
		"railing_wood": return Vector3(2.00, 1.00, 0.12)
		"railing_metal": return Vector3(2.00, 1.00, 0.08)
		"block_cube_1m": return Vector3(1.00, 1.00, 1.00)
		"block_plate_2m": return Vector3(2.00, 0.15, 2.00)
		"block_beam": return Vector3(0.15, 1.00, 0.15)
		"block_plank": return Vector3(1.50, 0.08, 0.30)
		"block_column_cyl": return Vector3(1.00, 3.00, 1.00)
		"block_prism": return Vector3(1.50, 1.00, 1.50)
		"column": return Vector3(0.80, 3.60, 0.80)
		"floor_slab": return Vector3(4.00, 0.25, 4.00)
		"cover_box": return Vector3(1.80, 1.20, 0.60)
		_:
			if "painting" in type:
				return Vector3(1.20, 0.90, 0.08)
			return Vector3.ONE

static func _is_legacy_mode() -> bool:
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		if gm and "is_legacy_graphics" in gm:
			return bool(gm.is_legacy_graphics)
	return false

static func build_realistic_door_leaf(panel: Node3D, p_w: float, p_h: float, p_th: float, p_mat: StandardMaterial3D, is_centered_origin: bool = false) -> MeshInstance3D:
	var leaf = MeshInstance3D.new()
	leaf.name = "DoorLeaf"
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(p_w, p_h, p_th)
	p_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	p_mesh.material = p_mat
	leaf.mesh = p_mesh
	leaf.position = Vector3(0, 0, 0) if is_centered_origin else Vector3(p_w * 0.5, p_h * 0.5, 0)
	leaf.extra_cull_margin = 16.0
	leaf.ignore_occlusion_culling = true
	panel.add_child(leaf)

	# Режим Legacy (Alpha 0.1): простое гладкое полотно с круглой ручкой
	if _is_legacy_mode():
		var knob = MeshInstance3D.new()
		knob.name = "DoorKnob"
		var km = SphereMesh.new()
		km.radius = 0.04
		km.height = 0.08
		var k_mat = StandardMaterial3D.new()
		k_mat.albedo_color = Color(0.85, 0.70, 0.20)
		k_mat.metallic = 0.8
		k_mat.roughness = 0.3
		knob.mesh = km
		knob.position = Vector3(p_w * 0.5 - 0.09, -p_h * 0.5 + 0.98, p_th * 0.5 + 0.04)
		leaf.add_child(knob)
		return leaf

	# 1. Архитектурные материалы обвязки и филёнок
	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = p_mat.albedo_color.darkened(0.10)
	frame_mat.roughness = 0.80
	frame_mat.metallic = 0.04
	frame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var panel_mat = StandardMaterial3D.new()
	panel_mat.albedo_color = p_mat.albedo_color.darkened(0.18)
	panel_mat.roughness = 0.86
	panel_mat.metallic = 0.02
	panel_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var trim_mat = StandardMaterial3D.new()
	trim_mat.albedo_color = p_mat.albedo_color.lightened(0.06)
	trim_mat.roughness = 0.72
	trim_mat.metallic = 0.05
	trim_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	# Размеры брусков
	var w_stile: float = 0.13
	var w_inner: float = max(0.2, p_w - (w_stile * 2.0))
	var w_mullion: float = 0.09
	var w_panel: float = max(0.1, (w_inner - w_mullion) * 0.5)

	var h_top: float = 0.14
	var h_mid: float = 0.18
	var h_bot: float = 0.24
	var y_mid: float = -p_h * 0.5 + 0.98
	var h_upper: float = max(0.2, (p_h * 0.5 - h_top) - (y_mid + h_mid * 0.5))
	var h_lower: float = max(0.2, (y_mid - h_mid * 0.5) - (-p_h * 0.5 + h_bot))

	# Вертикальные боковые бруски (Stiles)
	for sx in [-p_w * 0.5 + w_stile * 0.5, p_w * 0.5 - w_stile * 0.5]:
		var st = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(w_stile, p_h, p_th + 0.014)
		sm.material = frame_mat
		st.mesh = sm
		st.position = Vector3(sx, 0, 0)
		leaf.add_child(st)

	# Горизонтальные перемычки (Rails): Верхний, Замочный и Цокольный
	var top_r = MeshInstance3D.new()
	var tr_m = BoxMesh.new()
	tr_m.size = Vector3(w_inner, h_top, p_th + 0.014)
	tr_m.material = frame_mat
	top_r.mesh = tr_m
	top_r.position = Vector3(0, p_h * 0.5 - h_top * 0.5, 0)
	leaf.add_child(top_r)

	var mid_r = MeshInstance3D.new()
	var mr_m = BoxMesh.new()
	mr_m.size = Vector3(w_inner, h_mid, p_th + 0.014)
	mr_m.material = frame_mat
	mid_r.mesh = mr_m
	mid_r.position = Vector3(0, y_mid, 0)
	leaf.add_child(mid_r)

	var bot_r = MeshInstance3D.new()
	var br_m = BoxMesh.new()
	br_m.size = Vector3(w_inner, h_bot, p_th + 0.014)
	br_m.material = frame_mat
	bot_r.mesh = br_m
	bot_r.position = Vector3(0, -p_h * 0.5 + h_bot * 0.5, 0)
	leaf.add_child(bot_r)

	# Центральный вертикальный импост (Mullion)
	var y_center_upper: float = (p_h * 0.5 - h_top + y_mid + h_mid * 0.5) * 0.5
	var y_center_lower: float = (y_mid - h_mid * 0.5 + -p_h * 0.5 + h_bot) * 0.5

	var mul_up = MeshInstance3D.new()
	var mu_m = BoxMesh.new()
	mu_m.size = Vector3(w_mullion, h_upper, p_th + 0.014)
	mu_m.material = frame_mat
	mul_up.mesh = mu_m
	mul_up.position = Vector3(0, y_center_upper, 0)
	leaf.add_child(mul_up)

	var mul_dn = MeshInstance3D.new()
	var md_m = BoxMesh.new()
	md_m.size = Vector3(w_mullion, h_lower, p_th + 0.014)
	md_m.material = frame_mat
	mul_dn.mesh = md_m
	mul_dn.position = Vector3(0, y_center_lower, 0)
	leaf.add_child(mul_dn)

	# 4 Рельефные классические филёнки (Panels) с выступающим профилированным штапиком (Molding)
	var col_x = [-w_mullion * 0.5 - w_panel * 0.5, w_mullion * 0.5 + w_panel * 0.5]
	for px in col_x:
		# Верхние филёнки
		var pan_u = MeshInstance3D.new()
		var pu_m = BoxMesh.new()
		pu_m.size = Vector3(w_panel - 0.04, h_upper - 0.04, p_th + 0.006)
		pu_m.material = panel_mat
		pan_u.mesh = pu_m
		pan_u.position = Vector3(px, y_center_upper, 0)
		leaf.add_child(pan_u)

		# Рамка-штапик верхней филёнки
		var trim_u = MeshInstance3D.new()
		var tu_m = BoxMesh.new()
		tu_m.size = Vector3(w_panel, h_upper, p_th + 0.010)
		tu_m.material = trim_mat
		trim_u.mesh = tu_m
		trim_u.position = Vector3(px, y_center_upper, 0)
		leaf.add_child(trim_u)

		# Нижние филёнки
		var pan_d = MeshInstance3D.new()
		var pd_m = BoxMesh.new()
		pd_m.size = Vector3(w_panel - 0.04, h_lower - 0.04, p_th + 0.006)
		pd_m.material = panel_mat
		pan_d.mesh = pd_m
		pan_d.position = Vector3(px, y_center_lower, 0)
		leaf.add_child(pan_d)

		# Рамка-штапик нижней филёнки
		var trim_d = MeshInstance3D.new()
		var td_m = BoxMesh.new()
		td_m.size = Vector3(w_panel, h_lower, p_th + 0.010)
		td_m.material = trim_mat
		trim_d.mesh = td_m
		trim_d.position = Vector3(px, y_center_lower, 0)
		leaf.add_child(trim_d)

	# 2 Стальные шарнирные петли со стороны навески (Hinges)
	var hinge_mat = StandardMaterial3D.new()
	hinge_mat.albedo_color = Color(0.20, 0.22, 0.25)
	hinge_mat.metallic = 0.95
	hinge_mat.roughness = 0.25

	for hy in [p_h * 0.38, 0.0, -p_h * 0.38]:
		var h_cyl = MeshInstance3D.new()
		var hcm = CylinderMesh.new()
		hcm.top_radius = 0.014
		hcm.bottom_radius = 0.014
		hcm.height = 0.11
		hcm.material = hinge_mat
		h_cyl.mesh = hcm
		h_cyl.position = Vector3(-p_w * 0.5 + 0.01, hy, 0)
		leaf.add_child(h_cyl)

		for cap_y in [-0.055, 0.055]:
			var cap = MeshInstance3D.new()
			var c_sph = SphereMesh.new()
			c_sph.radius = 0.015
			c_sph.height = 0.025
			c_sph.material = hinge_mat
			cap.mesh = c_sph
			cap.position = Vector3(-p_w * 0.5 + 0.01, hy + cap_y, 0)
			leaf.add_child(cap)

	# Торцевой ригель замка (Latch bolt) со стороны открывания
	var bolt_face = MeshInstance3D.new()
	var bfm = BoxMesh.new()
	bfm.size = Vector3(0.006, 0.14, p_th * 0.70)
	bfm.material = hinge_mat
	bolt_face.mesh = bfm
	bolt_face.position = Vector3(p_w * 0.5 + 0.001, y_mid, 0)
	leaf.add_child(bolt_face)

	var latch_bolt = MeshInstance3D.new()
	var lbm = BoxMesh.new()
	lbm.size = Vector3(0.014, 0.026, 0.018)
	var brass_bolt = StandardMaterial3D.new()
	brass_bolt.albedo_color = Color(0.85, 0.75, 0.30)
	brass_bolt.metallic = 0.95
	brass_bolt.roughness = 0.2
	lbm.material = brass_bolt
	latch_bolt.mesh = lbm
	latch_bolt.position = Vector3(p_w * 0.5 + 0.008, y_mid + 0.01, 0)
	leaf.add_child(latch_bolt)

	# Двусторонняя латунная дверная ручка с накладкой и замочной скважиной
	var esc_mat = StandardMaterial3D.new()
	esc_mat.albedo_color = Color(0.24, 0.22, 0.18)
	esc_mat.metallic = 0.90
	esc_mat.roughness = 0.28

	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.90, 0.78, 0.32)
	brass_mat.metallic = 0.94
	brass_mat.roughness = 0.22

	for side in [-1.0, 1.0]:
		var esc = MeshInstance3D.new()
		var esc_m = BoxMesh.new()
		esc_m.size = Vector3(0.065, 0.24, 0.008)
		esc_m.material = esc_mat
		esc.mesh = esc_m
		esc.position = Vector3(p_w * 0.5 - 0.09, y_mid, (p_th * 0.5 + 0.007) * side)
		leaf.add_child(esc)

		# Замочная скважина
		var kh = MeshInstance3D.new()
		var khm = BoxMesh.new()
		khm.size = Vector3(0.014, 0.038, 0.006)
		var kh_dark = StandardMaterial3D.new()
		kh_dark.albedo_color = Color(0.03, 0.03, 0.03)
		khm.material = kh_dark
		kh.mesh = khm
		kh.position = Vector3(p_w * 0.5 - 0.09, y_mid - 0.045, (p_th * 0.5 + 0.010) * side)
		leaf.add_child(kh)

		# Розетка ручки
		var rosette = MeshInstance3D.new()
		var rsm = CylinderMesh.new()
		rsm.top_radius = 0.018
		rsm.bottom_radius = 0.018
		rsm.height = 0.014
		rsm.material = brass_mat
		rosette.mesh = rsm
		rosette.rotation_degrees = Vector3(90, 0, 0)
		rosette.position = Vector3(p_w * 0.5 - 0.09, y_mid + 0.045, (p_th * 0.5 + 0.011) * side)
		leaf.add_child(rosette)

		# Штифт ручки
		var stem = MeshInstance3D.new()
		var stem_m = CylinderMesh.new()
		stem_m.top_radius = 0.010
		stem_m.bottom_radius = 0.010
		stem_m.height = 0.035
		stem_m.material = brass_mat
		stem.mesh = stem_m
		stem.rotation_degrees = Vector3(90, 0, 0)
		stem.position = Vector3(p_w * 0.5 - 0.09, y_mid + 0.045, (p_th * 0.5 + 0.026) * side)
		leaf.add_child(stem)

		# Нажимной горизонтальный рычаг
		var lever = MeshInstance3D.new()
		var lev_m = BoxMesh.new()
		lev_m.size = Vector3(0.11, 0.020, 0.018)
		lev_m.material = brass_mat
		lever.mesh = lev_m
		lever.position = Vector3(p_w * 0.5 - 0.14, y_mid + 0.045, (p_th * 0.5 + 0.042) * side)
		leaf.add_child(lever)

	# Цокольная защитная пластина (Kickplate)
	var kickplate_mat = StandardMaterial3D.new()
	kickplate_mat.albedo_color = Color(0.24, 0.22, 0.18)
	kickplate_mat.metallic = 0.85
	kickplate_mat.roughness = 0.35
	for side in [-1.0, 1.0]:
		var kp = MeshInstance3D.new()
		kp.name = "Kickplate"
		var kpm = BoxMesh.new()
		kpm.size = Vector3(w_inner + 0.02, 0.18, 0.005)
		kpm.material = kickplate_mat
		kp.mesh = kpm
		kp.position = Vector3(0, -p_h * 0.5 + 0.11, (p_th * 0.5 + 0.005) * side)
		leaf.add_child(kp)

	return leaf

static func _build_realistic_crate(sb: StaticBody3D, sz: Vector3, is_ghost: bool) -> void:
	var body = MeshInstance3D.new()
	body.name = "CrateBody"
	var bm = BoxMesh.new()
	bm.size = sz
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.40, 0.28, 0.16)
	wood_mat.roughness = 0.88
	wood_mat.metallic = 0.02
	if is_ghost:
		wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wood_mat.albedo_color.a = 0.60
	bm.material = wood_mat
	body.mesh = bm
	sb.add_child(body)

	var frame_mat = StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.27, 0.18, 0.10)
	frame_mat.roughness = 0.82
	frame_mat.metallic = 0.05
	if is_ghost:
		frame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		frame_mat.albedo_color.a = 0.60

	var iron_mat = StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.20, 0.23)
	iron_mat.metallic = 0.92
	iron_mat.roughness = 0.32
	if is_ghost:
		iron_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		iron_mat.albedo_color.a = 0.60

	var b_th: float = 0.025
	var b_w: float = 0.095

	for vx in [-1.0, 1.0]:
		for vz in [-1.0, 1.0]:
			var post = MeshInstance3D.new()
			var pm = BoxMesh.new()
			pm.size = Vector3(b_w, sz.y, b_w)
			pm.material = frame_mat
			post.mesh = pm
			post.position = Vector3(vx * (sz.x * 0.5 - b_w * 0.5), 0, vz * (sz.z * 0.5 - b_w * 0.5))
			sb.add_child(post)

	for hy in [-1.0, 1.0]:
		var y_pos = hy * (sz.y * 0.5 - b_w * 0.5)
		for fz in [-1.0, 1.0]:
			var r_fb = MeshInstance3D.new()
			var r_m = BoxMesh.new()
			r_m.size = Vector3(sz.x - b_w * 2.0, b_w, b_th)
			r_m.material = frame_mat
			r_fb.mesh = r_m
			r_fb.position = Vector3(0, y_pos, fz * (sz.z * 0.5 + b_th * 0.5))
			sb.add_child(r_fb)
		for sx in [-1.0, 1.0]:
			var r_lr = MeshInstance3D.new()
			var r_m2 = BoxMesh.new()
			r_m2.size = Vector3(b_th, b_w, sz.z - b_w * 2.0)
			r_m2.material = frame_mat
			r_lr.mesh = r_m2
			r_lr.position = Vector3(sx * (sz.x * 0.5 + b_th * 0.5), y_pos, 0)
			sb.add_child(r_lr)

	var diag_len = sqrt(pow(sz.x - b_w * 2.0, 2) + pow(sz.y - b_w * 2.0, 2))
	var diag_angle = atan2(sz.y - b_w * 2.0, sz.x - b_w * 2.0)
	for fz in [-1.0, 1.0]:
		for ang_sign in [-1.0, 1.0]:
			var brace = MeshInstance3D.new()
			var b_mesh = BoxMesh.new()
			b_mesh.size = Vector3(diag_len, b_w * 0.75, b_th * 0.8)
			b_mesh.material = frame_mat
			brace.mesh = b_mesh
			brace.rotation = Vector3(0, 0, diag_angle * ang_sign)
			brace.position = Vector3(0, 0, fz * (sz.z * 0.5 + b_th * 0.4))
			sb.add_child(brace)

	var c_size: float = 0.11
	for cx in [-1.0, 1.0]:
		for cy in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				var bracket = MeshInstance3D.new()
				bracket.name = "CornerBracket"
				var bm_brk = BoxMesh.new()
				bm_brk.size = Vector3(c_size, c_size, c_size)
				bm_brk.material = iron_mat
				bracket.mesh = bm_brk
				bracket.position = Vector3(
					cx * (sz.x * 0.5 - c_size * 0.45),
					cy * (sz.y * 0.5 - c_size * 0.45),
					cz * (sz.z * 0.5 - c_size * 0.45)
				)
				sb.add_child(bracket)

				var rivet = MeshInstance3D.new()
				var rm = SphereMesh.new()
				rm.radius = 0.012
				rm.height = 0.016
				rm.material = iron_mat
				rivet.mesh = rm
				rivet.position = bracket.position + Vector3(cx * 0.05, cy * 0.05, cz * 0.05)
				sb.add_child(rivet)

	for hx in [-1.0, 1.0]:
		var handle_mount = MeshInstance3D.new()
		var hmm = BoxMesh.new()
		hmm.size = Vector3(b_th * 0.8, 0.06, 0.14)
		hmm.material = iron_mat
		handle_mount.mesh = hmm
		handle_mount.position = Vector3(hx * (sz.x * 0.5 + b_th * 0.5), 0, 0)
		sb.add_child(handle_mount)

		var handle_ring = MeshInstance3D.new()
		var hrm = CylinderMesh.new()
		hrm.top_radius = 0.009
		hrm.bottom_radius = 0.009
		hrm.height = 0.12
		hrm.material = iron_mat
		handle_ring.mesh = hrm
		handle_ring.rotation_degrees = Vector3(0, 0, 90)
		handle_ring.position = Vector3(hx * (sz.x * 0.5 + b_th * 1.2), -0.02, 0)
		sb.add_child(handle_ring)

static func _build_realistic_barrel(sb: StaticBody3D, sz: Vector3, is_ghost: bool) -> void:
	var r = sz.x * 0.5
	var h = sz.y

	var body = MeshInstance3D.new()
	body.name = "BarrelBody"
	var cyl = CylinderMesh.new()
	cyl.top_radius = r * 0.94
	cyl.bottom_radius = r * 0.94
	cyl.height = h
	cyl.radial_segments = 24
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.35, 0.23, 0.14)
	wood_mat.roughness = 0.84
	wood_mat.metallic = 0.03
	if is_ghost:
		wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wood_mat.albedo_color.a = 0.60
	cyl.material = wood_mat
	body.mesh = cyl
	sb.add_child(body)

	var belly = MeshInstance3D.new()
	var belly_cyl = CylinderMesh.new()
	belly_cyl.top_radius = r * 1.03
	belly_cyl.bottom_radius = r * 1.03
	belly_cyl.height = h * 0.50
	belly_cyl.radial_segments = 24
	belly_cyl.material = wood_mat
	belly.mesh = belly_cyl
	sb.add_child(belly)

	var iron_mat = StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.20, 0.23)
	iron_mat.metallic = 0.92
	iron_mat.roughness = 0.35
	if is_ghost:
		iron_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		iron_mat.albedo_color.a = 0.60

	var hoop_positions = [
		{"y": h * 0.42, "r": r * 0.96},
		{"y": h * 0.18, "r": r * 1.04},
		{"y": -h * 0.18, "r": r * 1.04},
		{"y": -h * 0.42, "r": r * 0.96}
	]

	for hp in hoop_positions:
		var hoop = MeshInstance3D.new()
		var hm = CylinderMesh.new()
		hm.top_radius = hp["r"]
		hm.bottom_radius = hp["r"]
		hm.height = 0.042
		hm.radial_segments = 24
		hm.material = iron_mat
		hoop.mesh = hm
		hoop.position = Vector3(0, hp["y"], 0)
		sb.add_child(hoop)

		for ang_deg in [0, 90, 180, 270]:
			var ang = deg_to_rad(ang_deg)
			var rivet = MeshInstance3D.new()
			var rm = SphereMesh.new()
			rm.radius = 0.012
			rm.height = 0.018
			rm.material = iron_mat
			rivet.mesh = rm
			rivet.position = Vector3(cos(ang) * (hp["r"] + 0.005), hp["y"], sin(ang) * (hp["r"] + 0.005))
			sb.add_child(rivet)

	var lid = MeshInstance3D.new()
	var lid_cyl = CylinderMesh.new()
	lid_cyl.top_radius = r * 0.88
	lid_cyl.bottom_radius = r * 0.88
	lid_cyl.height = 0.02
	lid_cyl.radial_segments = 24
	var lid_mat = StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.26, 0.17, 0.10)
	lid_mat.roughness = 0.90
	lid_cyl.material = lid_mat
	lid.mesh = lid_cyl
	lid.position = Vector3(0, h * 0.47, 0)
	sb.add_child(lid)

	var bung = MeshInstance3D.new()
	var bung_m = CylinderMesh.new()
	bung_m.top_radius = 0.035
	bung_m.bottom_radius = 0.035
	bung_m.height = 0.025
	bung_m.material = iron_mat
	bung.mesh = bung_m
	bung.position = Vector3(r * 0.38, h * 0.485, 0)
	sb.add_child(bung)

static func _build_realistic_nightstand(sb: StaticBody3D, is_ghost: bool) -> void:
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.32, 0.19, 0.10)
	wood_mat.roughness = 0.78
	wood_mat.metallic = 0.03
	if is_ghost:
		wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wood_mat.albedo_color.a = 0.60

	var dark_wood = StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.22, 0.13, 0.07)
	dark_wood.roughness = 0.82
	if is_ghost:
		dark_wood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dark_wood.albedo_color.a = 0.60

	var trim_wood = StandardMaterial3D.new()
	trim_wood.albedo_color = Color(0.38, 0.23, 0.13)
	trim_wood.roughness = 0.72

	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.86, 0.72, 0.26)
	brass_mat.metallic = 0.92
	brass_mat.roughness = 0.25

	var body = MeshInstance3D.new()
	body.name = "CabinetBody"
	var bm_body = BoxMesh.new()
	bm_body.size = Vector3(0.60, 0.58, 0.50)
	bm_body.material = wood_mat
	body.mesh = bm_body
	body.position = Vector3(0, 0.39, 0)
	sb.add_child(body)

	var top_main = MeshInstance3D.new()
	var bm_tm = BoxMesh.new()
	bm_tm.size = Vector3(0.66, 0.035, 0.55)
	bm_tm.material = dark_wood
	top_main.mesh = bm_tm
	top_main.position = Vector3(0, 0.70, 0)
	sb.add_child(top_main)

	var top_bevel = MeshInstance3D.new()
	var bm_tb = BoxMesh.new()
	bm_tb.size = Vector3(0.63, 0.020, 0.525)
	bm_tb.material = trim_wood
	top_bevel.mesh = bm_tb
	top_bevel.position = Vector3(0, 0.675, 0)
	sb.add_child(top_bevel)

	var drawer_root = Node3D.new()
	drawer_root.name = "Drawer"

	var drawer_face = MeshInstance3D.new()
	var bm_df = BoxMesh.new()
	bm_df.size = Vector3(0.53, 0.18, 0.03)
	bm_df.material = wood_mat
	drawer_face.mesh = bm_df
	drawer_face.position = Vector3(0, 0.54, 0.255)
	drawer_root.add_child(drawer_face)

	var dr_trim = MeshInstance3D.new()
	var bm_dt = BoxMesh.new()
	bm_dt.size = Vector3(0.48, 0.14, 0.008)
	bm_dt.material = trim_wood
	dr_trim.mesh = bm_dt
	dr_trim.position = Vector3(0, 0.54, 0.272)
	drawer_root.add_child(dr_trim)

	var keyhole = MeshInstance3D.new()
	var khm = BoxMesh.new()
	khm.size = Vector3(0.012, 0.022, 0.004)
	var kh_mat = StandardMaterial3D.new()
	kh_mat.albedo_color = Color(0.05, 0.05, 0.05)
	khm.material = kh_mat
	keyhole.mesh = khm
	keyhole.position = Vector3(0, 0.575, 0.278)
	drawer_root.add_child(keyhole)

	var esc_back = MeshInstance3D.new()
	var ebm = BoxMesh.new()
	ebm.size = Vector3(0.065, 0.022, 0.006)
	ebm.material = brass_mat
	esc_back.mesh = ebm
	esc_back.position = Vector3(0, 0.525, 0.278)
	drawer_root.add_child(esc_back)

	var handle_ring = MeshInstance3D.new()
	var hrm = CylinderMesh.new()
	hrm.top_radius = 0.007
	hrm.bottom_radius = 0.007
	hrm.height = 0.055
	hrm.material = brass_mat
	handle_ring.mesh = hrm
	handle_ring.rotation_degrees = Vector3(0, 0, 90)
	handle_ring.position = Vector3(0, 0.512, 0.288)
	drawer_root.add_child(handle_ring)

	var dr_bot = MeshInstance3D.new()
	var bm_bot = BoxMesh.new()
	bm_bot.size = Vector3(0.48, 0.02, 0.40)
	bm_bot.material = wood_mat
	dr_bot.mesh = bm_bot
	dr_bot.position = Vector3(0, 0.46, 0.04)
	drawer_root.add_child(dr_bot)

	for sx in [-0.24, 0.24]:
		var dr_side = MeshInstance3D.new()
		var bm_side = BoxMesh.new()
		bm_side.size = Vector3(0.02, 0.14, 0.40)
		bm_side.material = wood_mat
		dr_side.mesh = bm_side
		dr_side.position = Vector3(sx, 0.53, 0.04)
		drawer_root.add_child(dr_side)

	var dr_back = MeshInstance3D.new()
	var bm_back = BoxMesh.new()
	bm_back.size = Vector3(0.48, 0.14, 0.02)
	bm_back.material = wood_mat
	dr_back.mesh = bm_back
	dr_back.position = Vector3(0, 0.53, -0.16)
	drawer_root.add_child(dr_back)

	sb.add_child(drawer_root)

	for x in [-0.24, 0.24]:
		for z in [-0.20, 0.20]:
			var leg = MeshInstance3D.new()
			var lm = BoxMesh.new()
			lm.size = Vector3(0.065, 0.09, 0.065)
			lm.material = dark_wood
			leg.mesh = lm
			leg.position = Vector3(x, 0.045, z)
			sb.add_child(leg)

static func _build_realistic_dresser(sb: StaticBody3D, is_ghost: bool) -> void:
	var wood_mat = StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.33, 0.19, 0.11)
	wood_mat.roughness = 0.74
	wood_mat.metallic = 0.03
	if is_ghost:
		wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		wood_mat.albedo_color.a = 0.60

	var dark_wood = StandardMaterial3D.new()
	dark_wood.albedo_color = Color(0.22, 0.12, 0.07)
	dark_wood.roughness = 0.80

	var trim_wood = StandardMaterial3D.new()
	trim_wood.albedo_color = Color(0.39, 0.23, 0.13)
	trim_wood.roughness = 0.70

	var brass_mat = StandardMaterial3D.new()
	brass_mat.albedo_color = Color(0.88, 0.74, 0.26)
	brass_mat.metallic = 0.94
	brass_mat.roughness = 0.24

	var body = MeshInstance3D.new()
	body.name = "DresserBody"
	var bm = BoxMesh.new()
	bm.size = Vector3(1.20, 0.96, 0.55)
	bm.material = wood_mat
	body.mesh = bm
	body.position = Vector3(0, 0.52, 0)
	sb.add_child(body)

	var crown_top = MeshInstance3D.new()
	var cm = BoxMesh.new()
	cm.size = Vector3(1.26, 0.04, 0.58)
	cm.material = dark_wood
	crown_top.mesh = cm
	crown_top.position = Vector3(0, 1.02, 0)
	sb.add_child(crown_top)

	var crown_sub = MeshInstance3D.new()
	var csm = BoxMesh.new()
	csm.size = Vector3(1.23, 0.02, 0.56)
	csm.material = trim_wood
	crown_sub.mesh = csm
	crown_sub.position = Vector3(0, 0.99, 0)
	sb.add_child(crown_sub)

	var plinth = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(1.22, 0.05, 0.56)
	pm.material = dark_wood
	plinth.mesh = pm
	plinth.position = Vector3(0, 0.065, 0)
	sb.add_child(plinth)

	for sx in [-0.54, 0.54]:
		for sz in [-0.22, 0.22]:
			var foot = MeshInstance3D.new()
			var fm = BoxMesh.new()
			fm.size = Vector3(0.09, 0.04, 0.09)
			fm.material = dark_wood
			foot.mesh = fm
			foot.position = Vector3(sx, 0.02, sz)
			sb.add_child(foot)

	for dy in range(3):
		var h_y = 0.19 + dy * 0.22
		var d_panel = MeshInstance3D.new()
		var dpm = BoxMesh.new()
		dpm.size = Vector3(1.12, 0.18, 0.015)
		dpm.material = trim_wood
		d_panel.mesh = dpm
		d_panel.position = Vector3(0, h_y, 0.282)
		sb.add_child(d_panel)

		var kh = MeshInstance3D.new()
		var kh_m = BoxMesh.new()
		kh_m.size = Vector3(0.012, 0.024, 0.005)
		var kh_mat = StandardMaterial3D.new()
		kh_mat.albedo_color = Color(0.05, 0.05, 0.05)
		kh_m.material = kh_mat
		kh.mesh = kh_m
		kh.position = Vector3(0, h_y + 0.035, 0.292)
		sb.add_child(kh)

		for hx in [-0.32, 0.32]:
			var esc = MeshInstance3D.new()
			var em = BoxMesh.new()
			em.size = Vector3(0.075, 0.024, 0.006)
			em.material = brass_mat
			esc.mesh = em
			esc.position = Vector3(hx, h_y, 0.292)
			sb.add_child(esc)

			var h_ring = MeshInstance3D.new()
			var hm_cyl = CylinderMesh.new()
			hm_cyl.top_radius = 0.008
			hm_cyl.bottom_radius = 0.008
			hm_cyl.height = 0.065
			hm_cyl.material = brass_mat
			h_ring.mesh = hm_cyl
			h_ring.rotation_degrees = Vector3(0, 0, 90)
			h_ring.position = Vector3(hx, h_y - 0.014, 0.302)
			sb.add_child(h_ring)

	var drawer_root = Node3D.new()
	drawer_root.name = "Drawer"

	var top_front = MeshInstance3D.new()
	var tf_m = BoxMesh.new()
	tf_m.size = Vector3(1.12, 0.19, 0.03)
	tf_m.material = wood_mat
	top_front.mesh = tf_m
	top_front.position = Vector3(0, 0.85, 0.28)
	drawer_root.add_child(top_front)

	var top_trim = MeshInstance3D.new()
	var ttm = BoxMesh.new()
	ttm.size = Vector3(1.08, 0.15, 0.012)
	ttm.material = trim_wood
	top_trim.mesh = ttm
	top_trim.position = Vector3(0, 0.85, 0.298)
	drawer_root.add_child(top_trim)

	var tkh = MeshInstance3D.new()
	var tkh_m = BoxMesh.new()
	tkh_m.size = Vector3(0.012, 0.024, 0.005)
	var tkh_mat = StandardMaterial3D.new()
	tkh_mat.albedo_color = Color(0.05, 0.05, 0.05)
	tkh_m.material = tkh_mat
	tkh.mesh = tkh_m
	tkh.position = Vector3(0, 0.885, 0.306)
	drawer_root.add_child(tkh)

	for hx in [-0.32, 0.32]:
		var esc = MeshInstance3D.new()
		var em = BoxMesh.new()
		em.size = Vector3(0.075, 0.024, 0.006)
		em.material = brass_mat
		esc.mesh = em
		esc.position = Vector3(hx, 0.85, 0.306)
		drawer_root.add_child(esc)

		var h_ring = MeshInstance3D.new()
		var hm_cyl = CylinderMesh.new()
		hm_cyl.top_radius = 0.008
		hm_cyl.bottom_radius = 0.008
		hm_cyl.height = 0.065
		hm_cyl.material = brass_mat
		h_ring.mesh = hm_cyl
		h_ring.rotation_degrees = Vector3(0, 0, 90)
		h_ring.position = Vector3(hx, 0.836, 0.316)
		drawer_root.add_child(h_ring)

	var top_bot = MeshInstance3D.new()
	var tb_m = BoxMesh.new()
	tb_m.size = Vector3(1.06, 0.02, 0.46)
	tb_m.material = wood_mat
	top_bot.mesh = tb_m
	top_bot.position = Vector3(0, 0.77, 0.04)
	drawer_root.add_child(top_bot)

	for sx in [-0.53, 0.53]:
		var top_side = MeshInstance3D.new()
		var ts_m = BoxMesh.new()
		ts_m.size = Vector3(0.02, 0.15, 0.46)
		ts_m.material = wood_mat
		top_side.mesh = ts_m
		top_side.position = Vector3(sx, 0.85, 0.04)
		drawer_root.add_child(top_side)

	var top_back = MeshInstance3D.new()
	var tbk_m = BoxMesh.new()
	tbk_m.size = Vector3(1.06, 0.15, 0.02)
	tbk_m.material = wood_mat
	top_back.mesh = tbk_m
	top_back.position = Vector3(0, 0.85, -0.19)
	drawer_root.add_child(top_back)

	sb.add_child(drawer_root)

static func build_prefab(type: String, sz: Vector3, color: Color, is_ghost: bool, custom_model_path: String = "") -> Node3D:
	var build_sz := sz
	var final_scale := Vector3.ZERO
	var plain := type.trim_prefix("custom_")
	if custom_model_path == "" and sz != Vector3.ZERO and plain != "prop_tree_pine" and plain != "cube" and not plain.begins_with("floor") and not plain.begins_with("ceiling") and not plain.begins_with("door"):
		var base_sz := get_prefab_base_size(type)
		if base_sz.x > 0.01 and base_sz.y > 0.01 and base_sz.z > 0.01 and not sz.is_equal_approx(base_sz):
			build_sz = base_sz
			final_scale = Vector3(sz.x / base_sz.x, sz.y / base_sz.y, sz.z / base_sz.z)
	var built := _build_prefab_raw(type, build_sz, color, is_ghost, custom_model_path)
	if built != null:
		if final_scale != Vector3.ZERO:
			built.scale = final_scale
		NatureKit.simplify_primitives(built)
		if not is_ghost:
			HouseKit.dress_prefab(built, type)
	return built


static func _build_prefab_raw(type: String, sz: Vector3, color: Color, is_ghost: bool, custom_model_path: String = "") -> Node3D:
	var root = Node3D.new()
	# Preserve the catalogue identity without changing interaction item_type values.
	root.set_meta("prefab_type", type.trim_prefix("custom_"))

	# Кастомные модели (.glb, .gltf, .obj, .tscn)
	if custom_model_path != "" and ResourceLoader.exists(custom_model_path):
		var res = load(custom_model_path)
		if res:
			var model_inst: Node = null
			if res is PackedScene:
				model_inst = res.instantiate()
			elif res is Mesh:
				var mi_mesh = MeshInstance3D.new()
				mi_mesh.mesh = res
				model_inst = mi_mesh

			if model_inst:
				var sb = StaticBody3D.new()
				sb.collision_layer = 1
				sb.collision_mask = 0
				sb.add_child(model_inst)

				if not is_ghost:
					var col = CollisionShape3D.new()
					var box = BoxShape3D.new()
					box.size = sz
					col.shape = box
					sb.add_child(col)

				if sz != Vector3.ZERO:
					root.scale = sz
				root.add_child(sb)
				return root

	match type:
		# ─────────────────────────────────────────────────────────────
		#  АРХИТЕКТУРА И СТЕНЫ
		# ─────────────────────────────────────────────────────────────
		"cube":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.85
			if is_ghost:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.55
			bm.material = mat
			mi.mesh = bm
			sb.add_child(mi)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"cylinder":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var mi = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = sz.x * 0.5
			cm.bottom_radius = sz.z * 0.5
			cm.height = sz.y
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.85
			if is_ghost:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.55
			cm.material = mat
			mi.mesh = cm
			sb.add_child(mi)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = max(sz.x, sz.z) * 0.5
				shape.height = sz.y
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"prism":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var mi = MeshInstance3D.new()
			var pm = PrismMesh.new()
			pm.size = sz
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.roughness = 0.85
			if is_ghost:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.55
			pm.material = mat
			mi.mesh = pm
			sb.add_child(mi)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  ПОЛ И ПОТОЛОК (РАСТЯГИВАНИЕ ОТКУДА ДО КУДА)
		# ─────────────────────────────────────────────────────────────
		"floor_drag", "floor_custom":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.10, 0.09) if color == Color.WHITE else color
			mat.roughness = 0.90
			if is_ghost:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(0.2, 0.8, 1.0, 0.60) # подсвечиваем приятным неоном
			bm.material = mat
			mi.mesh = bm
			sb.add_child(mi)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"ceiling_drag", "ceiling_custom":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.06, 0.05, 0.06) if color == Color.WHITE else color
			mat.roughness = 0.95
			if is_ghost:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(0.9, 0.6, 1.0, 0.60)
			bm.material = mat
			mi.mesh = bm
			sb.add_child(mi)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"smart_house":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.25, 0.70, 1.0, 0.45) if is_ghost else Color(0.24, 0.22, 0.20)
			if is_ghost:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.material = mat
			mi.mesh = bm
			mi.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(mi)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  ДЕКОР ХОРРОРА: ЛУЖА КРОВИ (Плоская, сквозная)
		# ─────────────────────────────────────────────────────────────
		"prop_blood_puddle":
			var holder = Node3D.new()
			HouseKit.add_blood_pool(holder, Vector3(2.0, 0.04, 2.0))
			root.add_child(holder)

		# ─────────────────────────────────────────────────────────────
		#  ДЕКОР ХОРРОРА: КРОВЬ НА СТЕНЕ (Подтеки)
		# ─────────────────────────────────────────────────────────────
		"prop_blood_wall":
			var holder = Node3D.new()
			HouseKit.add_blood_wall(holder, Vector3(0.8, 1.2, 0.1))
			root.add_child(holder)

		# ─────────────────────────────────────────────────────────────
		#  ДЕКОР: СТАРЫЙ УЗОРНЫЙ КОВЕР
		# ─────────────────────────────────────────────────────────────
		"prop_carpet":
			var holder = Area3D.new()
			holder.collision_layer = 1
			holder.collision_mask = 0

			# Базовое сукно ковра
			var rug_mat = StandardMaterial3D.new()
			rug_mat.albedo_color = Color(0.34, 0.10, 0.12) # благородный темно-красный
			rug_mat.roughness = 0.95
			if is_ghost:
				rug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				rug_mat.albedo_color.a = 0.60

			var rug_base = MeshInstance3D.new()
			var bm_base = BoxMesh.new()
			bm_base.size = Vector3(sz.x, 0.02, sz.z)
			bm_base.material = rug_mat
			rug_base.mesh = bm_base
			rug_base.position = Vector3(0, 0.01, 0)
			holder.add_child(rug_base)

			# Золотисто-охристый орнаментальный кант
			var border_mat = StandardMaterial3D.new()
			border_mat.albedo_color = Color(0.55, 0.42, 0.18)
			border_mat.roughness = 0.90
			var border_mesh = MeshInstance3D.new()
			var bm_border = BoxMesh.new()
			bm_border.size = Vector3(sz.x * 0.88, 0.024, sz.z * 0.88)
			bm_border.material = border_mat
			border_mesh.mesh = bm_border
			border_mesh.position = Vector3(0, 0.012, 0)
			holder.add_child(border_mesh)

			# Центральный медальон
			var center_mat = StandardMaterial3D.new()
			center_mat.albedo_color = Color(0.24, 0.08, 0.10)
			var center_mesh = MeshInstance3D.new()
			var bm_center = BoxMesh.new()
			bm_center.size = Vector3(sz.x * 0.55, 0.028, sz.z * 0.55)
			bm_center.material = center_mat
			center_mesh.mesh = bm_center
			center_mesh.position = Vector3(0, 0.014, 0)
			holder.add_child(center_mesh)

			# Бахрома по краям (бежевая)
			var fringe_mat = StandardMaterial3D.new()
			fringe_mat.albedo_color = Color(0.70, 0.68, 0.60)
			for side in [-1.0, 1.0]:
				var fringe = MeshInstance3D.new()
				var fbm = BoxMesh.new()
				fbm.size = Vector3(sz.x * 0.96, 0.022, 0.06)
				fbm.material = fringe_mat
				fringe.mesh = fbm
				fringe.position = Vector3(0, 0.011, side * (sz.z * 0.5 + 0.025))
				holder.add_child(fringe)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(sz.x, 0.15, sz.z)
				col.shape = box
				holder.add_child(col)

			root.add_child(holder)

		# ─────────────────────────────────────────────────────────────
		#  МЕБЕЛЬ: ТУМБОЧКА
		# ─────────────────────────────────────────────────────────────
		"prop_nightstand":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "prop_nightstand")

			if _is_legacy_mode():
				var wood_mat = StandardMaterial3D.new()
				wood_mat.albedo_color = Color(0.34, 0.20, 0.11)
				wood_mat.roughness = 0.8
				if is_ghost:
					wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					wood_mat.albedo_color.a = 0.60

				var body = MeshInstance3D.new()
				var bm_body = BoxMesh.new()
				bm_body.size = Vector3(0.60, 0.60, 0.50)
				bm_body.material = wood_mat
				body.mesh = bm_body
				body.position = Vector3(0, 0.38, 0)
				sb.add_child(body)

				var top_plate = MeshInstance3D.new()
				var bm_top = BoxMesh.new()
				bm_top.size = Vector3(0.66, 0.04, 0.55)
				var dark_wood = StandardMaterial3D.new()
				dark_wood.albedo_color = Color(0.26, 0.15, 0.08)
				bm_top.material = dark_wood
				top_plate.mesh = bm_top
				top_plate.position = Vector3(0, 0.70, 0)
				sb.add_child(top_plate)

				var drawer_root = Node3D.new()
				drawer_root.name = "Drawer"

				var drawer = MeshInstance3D.new()
				var bm_dr = BoxMesh.new()
				bm_dr.size = Vector3(0.52, 0.18, 0.03)
				var light_wood = StandardMaterial3D.new()
				light_wood.albedo_color = Color(0.42, 0.26, 0.15)
				bm_dr.material = light_wood
				drawer.mesh = bm_dr
				drawer.position = Vector3(0, 0.54, 0.255)
				drawer_root.add_child(drawer)

				var knob = MeshInstance3D.new()
				var bm_knob = BoxMesh.new()
				bm_knob.size = Vector3(0.05, 0.04, 0.04)
				var brass_mat = StandardMaterial3D.new()
				brass_mat.albedo_color = Color(0.85, 0.70, 0.20)
				brass_mat.metallic = 0.7
				brass_mat.roughness = 0.3
				bm_knob.material = brass_mat
				knob.mesh = bm_knob
				knob.position = Vector3(0, 0.54, 0.28)
				drawer_root.add_child(knob)

				var dr_bot = MeshInstance3D.new()
				var bm_bot = BoxMesh.new()
				bm_bot.size = Vector3(0.48, 0.02, 0.40)
				bm_bot.material = wood_mat
				dr_bot.mesh = bm_bot
				dr_bot.position = Vector3(0, 0.46, 0.04)
				drawer_root.add_child(dr_bot)

				for sx in [-0.24, 0.24]:
					var dr_side = MeshInstance3D.new()
					var bm_side = BoxMesh.new()
					bm_side.size = Vector3(0.02, 0.14, 0.40)
					bm_side.material = wood_mat
					dr_side.mesh = bm_side
					dr_side.position = Vector3(sx, 0.53, 0.04)
					drawer_root.add_child(dr_side)

				var dr_back = MeshInstance3D.new()
				var bm_back = BoxMesh.new()
				bm_back.size = Vector3(0.48, 0.14, 0.02)
				bm_back.material = wood_mat
				dr_back.mesh = bm_back
				dr_back.position = Vector3(0, 0.53, -0.16)
				drawer_root.add_child(dr_back)

				sb.add_child(drawer_root)

				for x in [-0.24, 0.24]:
					for z in [-0.20, 0.20]:
						var leg = MeshInstance3D.new()
						var lm = BoxMesh.new()
						lm.size = Vector3(0.06, 0.08, 0.06)
						lm.material = dark_wood
						leg.mesh = lm
						leg.position = Vector3(x, 0.04, z)
						sb.add_child(leg)
			else:
				_build_realistic_nightstand(sb, is_ghost)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.66, 0.74, 0.55)
				col.shape = box
				col.position = Vector3(0, 0.37, 0)
				sb.add_child(col)

				sb.set_script(load("res://scripts/InteractiveStorage.gd"))
				sb.set("item_label", "ящик")
				sb.set("open_offset", Vector3(0, 0, 0.28))
				sb.set("move_duration", 0.30)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  МЕБЕЛЬ: СТАРЫЙ ШКАФ ДЛЯ ОДЕЖДЫ
		# ─────────────────────────────────────────────────────────────
		"prop_wardrobe":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "wardrobe")
			sb.set_meta("hiding_type", "wardrobe")

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.29, 0.17, 0.10)
			wood_mat.roughness = 0.85
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			# Hollow cabinet: the player sees real inner walls and the gap between doors.
			for panel_data in [
				[Vector3(-0.615,1.10,0), Vector3(0.07,2.10,0.62)],
				[Vector3(0.615,1.10,0), Vector3(0.07,2.10,0.62)],
				[Vector3(0,1.10,-0.285), Vector3(1.16,2.10,0.05)],
				[Vector3(0,2.115,0), Vector3(1.16,0.07,0.62)],
				[Vector3(0,0.085,0), Vector3(1.16,0.07,0.62)]
			]:
				var panel = MeshInstance3D.new()
				var panel_mesh = BoxMesh.new()
				panel_mesh.size = panel_data[1]
				panel_mesh.material = wood_mat
				panel.mesh = panel_mesh
				panel.position = panel_data[0]
				sb.add_child(panel)
			var hide_anchor = Marker3D.new()
			hide_anchor.name = "HideAnchor"
			hide_anchor.position = Vector3(0, 0.12, 0.08)
			sb.add_child(hide_anchor)
			var exit_anchor = Marker3D.new()
			exit_anchor.name = "ExitAnchor"
			exit_anchor.position = Vector3(0, 0.05, 1.05)
			sb.add_child(exit_anchor)

			# Верхний карниз (молдинг)
			var cornice = MeshInstance3D.new()
			var bm_corn = BoxMesh.new()
			bm_corn.size = Vector3(1.40, 0.09, 0.70)
			var dark_wood = StandardMaterial3D.new()
			dark_wood.albedo_color = Color(0.20, 0.11, 0.06)
			bm_corn.material = dark_wood
			cornice.mesh = bm_corn
			cornice.position = Vector3(0, 2.18, 0)
			sb.add_child(cornice)

			# Створки дверей (левая и правая)
			var door_mat = StandardMaterial3D.new()
			door_mat.albedo_color = Color(0.35, 0.21, 0.12)
			for x in [-0.35, 0.35]:
				var door = MeshInstance3D.new()
				var dm = BoxMesh.new()
				dm.size = Vector3(0.54, 2.00, 0.045)
				dm.material = door_mat
				door.mesh = dm
				door.position = Vector3(x, 1.10, 0.315)
				sb.add_child(door)

			# Латунные ручки на дверях
			var brass_mat = StandardMaterial3D.new()
			brass_mat.albedo_color = Color(0.85, 0.70, 0.20)
			brass_mat.metallic = 0.8
			brass_mat.roughness = 0.3
			for x in [-0.06, 0.06]:
				var hndl = MeshInstance3D.new()
				var hm = BoxMesh.new()
				hm.size = Vector3(0.03, 0.18, 0.04)
				hm.material = brass_mat
				hndl.mesh = hm
				hndl.position = Vector3(x, 1.10, 0.34)
				sb.add_child(hndl)

			# Нижний цоколь
			var plinth = MeshInstance3D.new()
			var pm = BoxMesh.new()
			pm.size = Vector3(1.34, 0.07, 0.65)
			pm.material = dark_wood
			plinth.mesh = pm
			plinth.position = Vector3(0, 0.035, 0)
			sb.add_child(plinth)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(1.40, 2.24, 0.70)
				col.shape = box
				col.position = Vector3(0, 1.12, 0)
				sb.add_child(col)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  АРХИТЕКТУРА: ЛЕСТНИЦЫ И ПЕРИЛА
		# ─────────────────────────────────────────────────────────────
		"stairs_straight":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.34, 0.22, 0.14)
			wood_mat.roughness = 0.8
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			var num_steps = 12
			var step_h = 3.6 / num_steps
			var step_d = 4.2 / num_steps
			var total_d = 4.2
			var w = 1.6

			# Ступени
			for i in range(num_steps):
				var step_m = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(w, step_h, step_d * 1.15)
				bm.material = wood_mat
				step_m.mesh = bm
				step_m.position = Vector3(0, (i + 0.5) * step_h, -total_d * 0.5 + (i + 0.5) * step_d)
				sb.add_child(step_m)

			# Боковые косоуры (тетивы)
			var side_mat = StandardMaterial3D.new()
			side_mat.albedo_color = Color(0.24, 0.15, 0.09)
			side_mat.roughness = 0.85
			for sx in [-w * 0.5, w * 0.5]:
				var beam = MeshInstance3D.new()
				var bm_b = BoxMesh.new()
				bm_b.size = Vector3(0.08, 0.25, sqrt(3.6 * 3.6 + total_d * total_d))
				bm_b.material = side_mat
				beam.mesh = bm_b
				beam.position = Vector3(sx, 1.8, 0)
				beam.rotation_degrees = Vector3(-rad_to_deg(atan2(3.6, total_d)), 0, 0)
				sb.add_child(beam)

			if not is_ghost:
				# Идеально гладкий пандус-клин (ConvexPolygonShape3D) без ступенчатых багов и застреваний
				var col = CollisionShape3D.new()
				var ramp = ConvexPolygonShape3D.new()
				var hw = w * 0.5
				var z_bot = -total_d * 0.5 - 0.15
				var z_top = total_d * 0.5 + 0.15
				ramp.points = PackedVector3Array([
					Vector3(-hw, 0.0, z_bot),
					Vector3( hw, 0.0, z_bot),
					Vector3(-hw, 3.6, z_top),
					Vector3( hw, 3.6, z_top),
					Vector3(-hw, -0.4, z_bot),
					Vector3( hw, -0.4, z_bot),
					Vector3(-hw, 3.1, z_top),
					Vector3( hw, 3.1, z_top),
				])
				col.shape = ramp
				sb.add_child(col)

			root.add_child(sb)

		"stairs_metal":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var metal_mat = StandardMaterial3D.new()
			metal_mat.albedo_color = Color(0.20, 0.22, 0.25)
			metal_mat.metallic = 0.85
			metal_mat.roughness = 0.45
			if is_ghost:
				metal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				metal_mat.albedo_color.a = 0.60

			var num_steps = 12
			var step_h = 3.6 / num_steps
			var step_d = 4.2 / num_steps
			var total_d = 4.2
			var w = 1.4

			for i in range(num_steps):
				var tread = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(w, 0.05, step_d * 1.1)
				bm.material = metal_mat
				tread.mesh = bm
				tread.position = Vector3(0, (i + 1) * step_h - 0.025, -total_d * 0.5 + (i + 0.5) * step_d)
				sb.add_child(tread)

			# Боковые металлические направляющие балки
			for sx in [-w * 0.5, w * 0.5]:
				var beam = MeshInstance3D.new()
				var bm_b = BoxMesh.new()
				bm_b.size = Vector3(0.06, 0.22, sqrt(3.6 * 3.6 + total_d * total_d))
				bm_b.material = metal_mat
				beam.mesh = bm_b
				beam.position = Vector3(sx, 1.8, 0)
				beam.rotation_degrees = Vector3(-rad_to_deg(atan2(3.6, total_d)), 0, 0)
				sb.add_child(beam)

			if not is_ghost:
				# Идеально гладкий пандус-клин (ConvexPolygonShape3D)
				var col = CollisionShape3D.new()
				var ramp = ConvexPolygonShape3D.new()
				var hw = w * 0.5
				var z_bot = -total_d * 0.5 - 0.15
				var z_top = total_d * 0.5 + 0.15
				ramp.points = PackedVector3Array([
					Vector3(-hw, 0.0, z_bot),
					Vector3( hw, 0.0, z_bot),
					Vector3(-hw, 3.6, z_top),
					Vector3( hw, 3.6, z_top),
					Vector3(-hw, -0.4, z_bot),
					Vector3( hw, -0.4, z_bot),
					Vector3(-hw, 3.1, z_top),
					Vector3( hw, 3.1, z_top),
				])
				col.shape = ramp
				sb.add_child(col)

			root.add_child(sb)

		"railing_wood":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.38, 0.24, 0.15)
			wood_mat.roughness = 0.75
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			# Верхний поручень
			var top_rail = MeshInstance3D.new()
			var bm_top = BoxMesh.new()
			bm_top.size = Vector3(2.0, 0.08, 0.12)
			bm_top.material = wood_mat
			top_rail.mesh = bm_top
			top_rail.position = Vector3(0, 0.96, 0)
			sb.add_child(top_rail)

			# Нижняя планка
			var bot_rail = MeshInstance3D.new()
			var bm_bot = BoxMesh.new()
			bm_bot.size = Vector3(2.0, 0.06, 0.10)
			bm_bot.material = wood_mat
			bot_rail.mesh = bm_bot
			bot_rail.position = Vector3(0, 0.08, 0)
			sb.add_child(bot_rail)

			# Балясины (7 штук)
			for i in range(7):
				var bx = -0.9 + i * 0.3
				var bal = MeshInstance3D.new()
				var bm_bal = BoxMesh.new()
				bm_bal.size = Vector3(0.06, 0.82, 0.06)
				bm_bal.material = wood_mat
				bal.mesh = bm_bal
				bal.position = Vector3(bx, 0.52, 0)
				sb.add_child(bal)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(2.0, 1.0, 0.12)
				col.shape = box
				col.position = Vector3(0, 0.50, 0)
				sb.add_child(col)

			root.add_child(sb)

		"railing_metal":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var metal_mat = StandardMaterial3D.new()
			metal_mat.albedo_color = Color(0.15, 0.15, 0.18)
			metal_mat.metallic = 0.9
			metal_mat.roughness = 0.4
			if is_ghost:
				metal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				metal_mat.albedo_color.a = 0.60

			var top_rail = MeshInstance3D.new()
			var bm_top = BoxMesh.new()
			bm_top.size = Vector3(2.0, 0.05, 0.06)
			bm_top.material = metal_mat
			top_rail.mesh = bm_top
			top_rail.position = Vector3(0, 0.975, 0)
			sb.add_child(top_rail)

			var bot_rail = MeshInstance3D.new()
			var bm_bot = BoxMesh.new()
			bm_bot.size = Vector3(2.0, 0.04, 0.05)
			bm_bot.material = metal_mat
			bot_rail.mesh = bm_bot
			bot_rail.position = Vector3(0, 0.06, 0)
			sb.add_child(bot_rail)

			# Прутья решетки (9 штук)
			for i in range(9):
				var bx = -0.9 + i * 0.225
				var bar = MeshInstance3D.new()
				var bm_bar = BoxMesh.new()
				bm_bar.size = Vector3(0.03, 0.88, 0.03)
				bm_bar.material = metal_mat
				bar.mesh = bm_bar
				bar.position = Vector3(bx, 0.52, 0)
				sb.add_child(bar)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(2.0, 1.0, 0.08)
				col.shape = box
				col.position = Vector3(0, 0.50, 0)
				sb.add_child(col)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  МЕБЕЛЬ: ДИВАНЫ, КРЕСЛА, ШКАФЫ И САНТЕХНИКА
		# ─────────────────────────────────────────────────────────────
		"prop_sofa":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var leather_mat = StandardMaterial3D.new()
			leather_mat.albedo_color = Color(0.28, 0.12, 0.10)
			leather_mat.roughness = 0.65
			if is_ghost:
				leather_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				leather_mat.albedo_color.a = 0.60

			# База дивана
			var base = MeshInstance3D.new()
			var bm_b = BoxMesh.new()
			bm_b.size = Vector3(2.2, 0.25, 0.95)
			bm_b.material = leather_mat
			base.mesh = bm_b
			base.position = Vector3(0, 0.20, 0)
			sb.add_child(base)

			# Подушки сиденья
			for px in [-0.52, 0.52]:
				var cushion = MeshInstance3D.new()
				var bm_c = BoxMesh.new()
				bm_c.size = Vector3(0.98, 0.18, 0.72)
				bm_c.material = leather_mat
				cushion.mesh = bm_c
				cushion.position = Vector3(px, 0.40, 0.06)
				sb.add_child(cushion)

			# Спинка
			var back = MeshInstance3D.new()
			var bm_back = BoxMesh.new()
			bm_back.size = Vector3(2.2, 0.55, 0.25)
			bm_back.material = leather_mat
			back.mesh = bm_back
			back.position = Vector3(0, 0.62, -0.35)
			sb.add_child(back)

			# 2 подлокотника
			for ax in [-1.02, 1.02]:
				var arm = MeshInstance3D.new()
				var bm_arm = BoxMesh.new()
				bm_arm.size = Vector3(0.22, 0.38, 0.92)
				bm_arm.material = leather_mat
				arm.mesh = bm_arm
				arm.position = Vector3(ax, 0.50, 0)
				sb.add_child(arm)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(2.2, 0.85, 0.95)
				col.shape = box
				col.position = Vector3(0, 0.425, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_armchair":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var cloth_mat = StandardMaterial3D.new()
			cloth_mat.albedo_color = Color(0.22, 0.28, 0.25)
			cloth_mat.roughness = 0.85
			if is_ghost:
				cloth_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				cloth_mat.albedo_color.a = 0.60

			# База и сиденье
			var seat = MeshInstance3D.new()
			var bm_s = BoxMesh.new()
			bm_s.size = Vector3(0.95, 0.38, 0.90)
			bm_s.material = cloth_mat
			seat.mesh = bm_s
			seat.position = Vector3(0, 0.26, 0)
			sb.add_child(seat)

			# Спинка
			var back = MeshInstance3D.new()
			var bm_b = BoxMesh.new()
			bm_b.size = Vector3(0.95, 0.52, 0.22)
			bm_b.material = cloth_mat
			back.mesh = bm_b
			back.position = Vector3(0, 0.62, -0.32)
			sb.add_child(back)

			# Подлокотники
			for ax in [-0.42, 0.42]:
				var arm = MeshInstance3D.new()
				var bm_arm = BoxMesh.new()
				bm_arm.size = Vector3(0.16, 0.32, 0.86)
				bm_arm.material = cloth_mat
				arm.mesh = bm_arm
				arm.position = Vector3(ax, 0.50, 0)
				sb.add_child(arm)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.95, 0.85, 0.90)
				col.shape = box
				col.position = Vector3(0, 0.425, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_bookshelf":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.28, 0.18, 0.11)
			wood_mat.roughness = 0.75
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			# Корпус шкафа
			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(1.4, 2.4, 0.45)
			bm.material = wood_mat
			body.mesh = bm
			body.position = Vector3(0, 1.2, 0)
			sb.add_child(body)

			# Полки и книги
			var book_colors = [Color(0.65, 0.15, 0.15), Color(0.18, 0.35, 0.65), Color(0.22, 0.50, 0.25), Color(0.75, 0.60, 0.20)]
			for py in [0.45, 0.95, 1.45, 1.95]:
				for b_idx in range(6):
					var book = MeshInstance3D.new()
					var b_mesh = BoxMesh.new()
					b_mesh.size = Vector3(0.16, 0.32, 0.28)
					var b_mat = StandardMaterial3D.new()
					b_mat.albedo_color = book_colors[(int(py * 2.0) + b_idx) % book_colors.size()]
					b_mesh.material = b_mat
					book.mesh = b_mesh
					book.position = Vector3(-0.48 + b_idx * 0.19, py + 0.16, 0.05)
					sb.add_child(book)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(1.4, 2.4, 0.45)
				col.shape = box
				col.position = Vector3(0, 1.2, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_dresser":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "prop_dresser")

			if _is_legacy_mode():
				var wood_mat = StandardMaterial3D.new()
				wood_mat.albedo_color = Color(0.35, 0.20, 0.12)
				wood_mat.roughness = 0.7
				if is_ghost:
					wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					wood_mat.albedo_color.a = 0.60

				var body = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(1.2, 1.0, 0.55)
				bm.material = wood_mat
				body.mesh = bm
				body.position = Vector3(0, 0.50, 0)
				sb.add_child(body)

				var brass_mat = StandardMaterial3D.new()
				brass_mat.albedo_color = Color(0.85, 0.72, 0.25)
				brass_mat.metallic = 0.9
				brass_mat.roughness = 0.3

				for dy in range(3):
					var h_y = 0.18 + dy * 0.22
					for hx in [-0.28, 0.28]:
						var handle = MeshInstance3D.new()
						var hm = BoxMesh.new()
						hm.size = Vector3(0.08, 0.03, 0.04)
						hm.material = brass_mat
						handle.mesh = hm
						handle.position = Vector3(hx, h_y, 0.29)
						sb.add_child(handle)

				var drawer_root = Node3D.new()
				drawer_root.name = "Drawer"

				var top_front = MeshInstance3D.new()
				var tf_m = BoxMesh.new()
				tf_m.size = Vector3(1.10, 0.19, 0.03)
				tf_m.material = wood_mat
				top_front.mesh = tf_m
				top_front.position = Vector3(0, 0.84, 0.28)
				drawer_root.add_child(top_front)

				for hx in [-0.28, 0.28]:
					var handle = MeshInstance3D.new()
					var hm = BoxMesh.new()
					hm.size = Vector3(0.08, 0.03, 0.04)
					hm.material = brass_mat
					handle.mesh = hm
					handle.position = Vector3(hx, 0.84, 0.30)
					drawer_root.add_child(handle)

				var top_bot = MeshInstance3D.new()
				var tb_m = BoxMesh.new()
				tb_m.size = Vector3(1.06, 0.02, 0.46)
				tb_m.material = wood_mat
				top_bot.mesh = tb_m
				top_bot.position = Vector3(0, 0.76, 0.04)
				drawer_root.add_child(top_bot)

				for sx in [-0.53, 0.53]:
					var top_side = MeshInstance3D.new()
					var ts_m = BoxMesh.new()
					ts_m.size = Vector3(0.02, 0.15, 0.46)
					ts_m.material = wood_mat
					top_side.mesh = ts_m
					top_side.position = Vector3(sx, 0.84, 0.04)
					drawer_root.add_child(top_side)

				var top_back = MeshInstance3D.new()
				var tbk_m = BoxMesh.new()
				tbk_m.size = Vector3(1.06, 0.15, 0.02)
				tbk_m.material = wood_mat
				top_back.mesh = tbk_m
				top_back.position = Vector3(0, 0.84, -0.19)
				drawer_root.add_child(top_back)

				sb.add_child(drawer_root)
			else:
				_build_realistic_dresser(sb, is_ghost)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(1.2, 1.0, 0.55)
				col.shape = box
				col.position = Vector3(0, 0.50, 0)
				sb.add_child(col)

				sb.set_script(load("res://scripts/InteractiveStorage.gd"))
				sb.set("item_label", "комод")
				sb.set("open_offset", Vector3(0, 0, 0.35))
				sb.set("move_duration", 0.32)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  МЕБЕЛЬ: НАВЕСНОЙ ШКАФЧИК / ПОЛКА С ДВЕРЦЕЙ
		# ─────────────────────────────────────────────────────────────
		"prop_cupboard", "custom_prop_cupboard":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "prop_cupboard")

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.36, 0.22, 0.13)
			wood_mat.roughness = 0.8
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			var dark_wood = StandardMaterial3D.new()
			dark_wood.albedo_color = Color(0.24, 0.14, 0.08)
			dark_wood.roughness = 0.85
			if is_ghost:
				dark_wood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				dark_wood.albedo_color.a = 0.60

			# Задняя стенка
			var back_mesh = MeshInstance3D.new()
			var bm_back = BoxMesh.new()
			bm_back.size = Vector3(0.80, 0.90, 0.02)
			bm_back.material = dark_wood
			back_mesh.mesh = bm_back
			back_mesh.position = Vector3(0, 0.45, -0.165)
			sb.add_child(back_mesh)

			# Боковые стенки
			for sx in [-0.39, 0.39]:
				var side = MeshInstance3D.new()
				var sm = BoxMesh.new()
				sm.size = Vector3(0.02, 0.90, 0.35)
				sm.material = wood_mat
				side.mesh = sm
				side.position = Vector3(sx, 0.45, 0)
				sb.add_child(side)

			# Верх и низ
			for sy in [0.01, 0.89]:
				var top_bot = MeshInstance3D.new()
				var tbm = BoxMesh.new()
				tbm.size = Vector3(0.80, 0.02, 0.35)
				tbm.material = wood_mat
				top_bot.mesh = tbm
				top_bot.position = Vector3(0, sy, 0)
				sb.add_child(top_bot)

			# Внутренние полочки (2 штуки)
			for py in [0.30, 0.60]:
				var shelf = MeshInstance3D.new()
				var sh_m = BoxMesh.new()
				sh_m.size = Vector3(0.76, 0.02, 0.33)
				sh_m.material = wood_mat
				shelf.mesh = sh_m
				shelf.position = Vector3(0, py, 0.01)
				sb.add_child(shelf)

			# Распашная дверка на петле слева
			var door_hinge = Node3D.new()
			door_hinge.name = "Door"
			door_hinge.position = Vector3(-0.38, 0.45, 0.175)

			var door_panel = MeshInstance3D.new()
			var dp_m = BoxMesh.new()
			dp_m.size = Vector3(0.76, 0.86, 0.025)
			var door_mat = StandardMaterial3D.new()
			door_mat.albedo_color = Color(0.40, 0.25, 0.15)
			door_mat.roughness = 0.75
			if is_ghost:
				door_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				door_mat.albedo_color.a = 0.60
			dp_m.material = door_mat
			door_panel.mesh = dp_m
			door_panel.position = Vector3(0.38, 0, 0)
			door_hinge.add_child(door_panel)

			# Латунная ручка на дверце
			var brass_m = StandardMaterial3D.new()
			brass_m.albedo_color = Color(0.85, 0.72, 0.25)
			brass_m.metallic = 0.85
			brass_m.roughness = 0.3
			var handle = MeshInstance3D.new()
			var hm = BoxMesh.new()
			hm.size = Vector3(0.03, 0.08, 0.04)
			hm.material = brass_m
			handle.mesh = hm
			handle.position = Vector3(0.70, 0, 0.025)
			door_hinge.add_child(handle)

			sb.add_child(door_hinge)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.80, 0.90, 0.35)
				col.shape = box
				col.position = Vector3(0, 0.45, 0)
				sb.add_child(col)

				sb.set_script(load("res://scripts/InteractiveStorage.gd"))
				sb.set("item_label", "шкафчик")
				sb.set("open_rotation", Vector3(0, 95, 0))
				sb.set("target_node", door_hinge)
				sb.set("move_duration", 0.35)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  АРХИТЕКТУРА: ВХОД В ПОДВАЛ (НАКЛОННЫЙ С ДВУМЯ СТВОРКАМИ)
		# ─────────────────────────────────────────────────────────────
		"prop_basement_entrance", "custom_prop_basement_entrance":
			var cellar_root = Node3D.new()
			cellar_root.name = "CellarEntrance"
			cellar_root.set_meta("item_type", "prop_basement_entrance")

			var concrete_mat = StandardMaterial3D.new()
			concrete_mat.albedo_color = Color(0.50, 0.48, 0.45) # состаренный выветренный бетон
			concrete_mat.roughness = 0.95
			if is_ghost:
				concrete_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				concrete_mat.albedo_color.a = 0.60

			var wood_m = StandardMaterial3D.new()
			wood_m.albedo_color = Color(0.33, 0.22, 0.14) # старое выветренное темное дерево
			wood_m.roughness = 0.90
			if is_ghost:
				wood_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_m.albedo_color.a = 0.60

			var iron_m = StandardMaterial3D.new()
			iron_m.albedo_color = Color(0.12, 0.12, 0.13) # кованое черненое железо
			iron_m.metallic = 0.85
			iron_m.roughness = 0.45
			if is_ghost:
				iron_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				iron_m.albedo_color.a = 0.60

			var dark_void_mat = StandardMaterial3D.new()
			dark_void_mat.albedo_color = Color(0.03, 0.03, 0.03)
			dark_void_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

			# ── 1. Неподвижная бетонная основа и спусковой колодец ──
			var sb_base = StaticBody3D.new()
			sb_base.name = "ConcreteBase"
			sb_base.collision_layer = 1
			sb_base.collision_mask = 0

			# Задняя бетонная стена (примыкание к дому)
			var back_wall = MeshInstance3D.new()
			var bm_bw = BoxMesh.new()
			bm_bw.size = Vector3(2.0, 1.25, 0.18)
			bm_bw.material = concrete_mat
			back_wall.mesh = bm_bw
			back_wall.position = Vector3(0, 0.625, -1.11)
			sb_base.add_child(back_wall)

			# Передний порог-ступенька
			var front_sill = MeshInstance3D.new()
			var bm_fs = BoxMesh.new()
			bm_fs.size = Vector3(2.0, 0.20, 0.18)
			bm_fs.material = concrete_mat
			front_sill.mesh = bm_fs
			front_sill.position = Vector3(0, 0.10, 1.11)
			sb_base.add_child(front_sill)

			# Левый и правый наклонные бетонные бордюры (парапеты)
			for side_x in [-0.91, 0.91]:
				var b_rear = MeshInstance3D.new()
				var bm_br = BoxMesh.new()
				bm_br.size = Vector3(0.18, 1.10, 0.75)
				bm_br.material = concrete_mat
				b_rear.mesh = bm_br
				b_rear.position = Vector3(side_x, 0.55, -0.65)
				sb_base.add_child(b_rear)

				var b_mid = MeshInstance3D.new()
				var bm_bm = BoxMesh.new()
				bm_bm.size = Vector3(0.18, 0.75, 0.75)
				bm_bm.material = concrete_mat
				b_mid.mesh = bm_bm
				b_mid.position = Vector3(side_x, 0.375, 0.05)
				sb_base.add_child(b_mid)

				var b_front = MeshInstance3D.new()
				var bm_bf = BoxMesh.new()
				bm_bf.size = Vector3(0.18, 0.40, 0.75)
				bm_bf.material = concrete_mat
				b_front.mesh = bm_bf
				b_front.position = Vector3(side_x, 0.20, 0.75)
				sb_base.add_child(b_front)

			# ── 2. Внутренние каменные ступени, уходящие вниз под землю ──
			var steps_data = [
				Vector3(0, 0.05, 0.65),
				Vector3(0, -0.22, 0.30),
				Vector3(0, -0.49, -0.05),
				Vector3(0, -0.76, -0.45)
			]
			for s_idx in range(steps_data.size()):
				var step_mesh = MeshInstance3D.new()
				var bm_step = BoxMesh.new()
				var step_len = 0.45 if s_idx < 3 else 0.65
				bm_step.size = Vector3(1.64, 0.22, step_len)
				bm_step.material = concrete_mat
				step_mesh.mesh = bm_step
				step_mesh.position = steps_data[s_idx]
				sb_base.add_child(step_mesh)

			# Темное глубинное полотно подвала в конце ступеней
			var void_mesh = MeshInstance3D.new()
			var vm = BoxMesh.new()
			vm.size = Vector3(1.64, 0.90, 0.05)
			vm.material = dark_void_mat
			void_mesh.mesh = vm
			void_mesh.position = Vector3(0, -0.45, -1.01)
			sb_base.add_child(void_mesh)

			# Физические коллайдеры основы
			if not is_ghost:
				var col_bw = CollisionShape3D.new()
				var cs_bw = BoxShape3D.new()
				cs_bw.size = Vector3(2.0, 1.25, 0.18)
				col_bw.shape = cs_bw
				col_bw.position = Vector3(0, 0.625, -1.11)
				sb_base.add_child(col_bw)

				var col_fs = CollisionShape3D.new()
				var cs_fs = BoxShape3D.new()
				cs_fs.size = Vector3(2.0, 0.20, 0.18)
				col_fs.shape = cs_fs
				col_fs.position = Vector3(0, 0.10, 1.11)
				sb_base.add_child(col_fs)

				for side_x in [-0.91, 0.91]:
					var col_curb = CollisionShape3D.new()
					var cs_curb = BoxShape3D.new()
					cs_curb.size = Vector3(0.18, 1.10, 2.22)
					col_curb.shape = cs_curb
					col_curb.position = Vector3(side_x, 0.55, 0.0)
					sb_base.add_child(col_curb)

				# Плавный пандус-коллайдер ступеней подвала (ConvexPolygonShape3D)
				var c_step = CollisionShape3D.new()
				var ramp_cellar = ConvexPolygonShape3D.new()
				ramp_cellar.points = PackedVector3Array([
					Vector3(-0.82,  0.15,  0.95),
					Vector3( 0.82,  0.15,  0.95),
					Vector3(-0.82, -0.76, -0.85),
					Vector3( 0.82, -0.76, -0.85),
					Vector3(-0.82, -0.30,  0.95),
					Vector3( 0.82, -0.30,  0.95),
					Vector3(-0.82, -1.15, -0.85),
					Vector3( 0.82, -1.15, -0.85),
				])
				c_step.shape = ramp_cellar
				sb_base.add_child(c_step)

			cellar_root.add_child(sb_base)

			# ── 3. Наклонная сборка двустворчатых дверей со стальными петлями ──
			var door_assembly = Node3D.new()
			door_assembly.name = "DoorAssembly"
			door_assembly.position = Vector3(0, 0.68, 0.0)
			door_assembly.rotation_degrees.x = 25.5

			var leaf_w = 0.81
			var leaf_len = 2.44
			var leaf_th = 0.04

			# Левая створка с петлями
			var left_hinge = Node3D.new()
			left_hinge.name = "LeftHinge"
			left_hinge.position = Vector3(-0.81, 0.03, 0.0)

			var left_leaf = MeshInstance3D.new()
			var ll_m = BoxMesh.new()
			ll_m.size = Vector3(leaf_w, leaf_th, leaf_len)
			ll_m.material = wood_m
			left_leaf.mesh = ll_m
			left_leaf.position = Vector3(leaf_w * 0.5, 0, 0)
			left_hinge.add_child(left_leaf)

			# Продольные швы деревянных досок
			for px in [-0.20, 0.0, 0.20]:
				var plank_groove = MeshInstance3D.new()
				var pgm = BoxMesh.new()
				pgm.size = Vector3(0.015, leaf_th + 0.005, leaf_len)
				var groove_mat = StandardMaterial3D.new()
				groove_mat.albedo_color = Color(0.20, 0.13, 0.08)
				pgm.material = groove_mat
				plank_groove.mesh = pgm
				plank_groove.position = Vector3(leaf_w * 0.5 + px, 0.002, 0)
				left_hinge.add_child(plank_groove)

			# 2 кованые стальные петли-стрелы на левой створке
			for pz in [-0.70, 0.70]:
				var strap = MeshInstance3D.new()
				var sm = BoxMesh.new()
				sm.size = Vector3(0.55, 0.02, 0.07)
				sm.material = iron_m
				strap.mesh = sm
				strap.position = Vector3(0.28, 0.03, pz)
				left_hinge.add_child(strap)

				var knuckle = MeshInstance3D.new()
				var km = BoxMesh.new()
				km.size = Vector3(0.06, 0.04, 0.09)
				km.material = iron_m
				knuckle.mesh = km
				knuckle.position = Vector3(0.02, 0.03, pz)
				left_hinge.add_child(knuckle)

			# Нащельник
			var center_batten = MeshInstance3D.new()
			var cbm = BoxMesh.new()
			cbm.size = Vector3(0.05, 0.025, leaf_len)
			var batten_mat = StandardMaterial3D.new()
			batten_mat.albedo_color = Color(0.27, 0.17, 0.10)
			cbm.material = batten_mat
			center_batten.mesh = cbm
			center_batten.position = Vector3(leaf_w, 0.03, 0)
			left_hinge.add_child(center_batten)

			# Металлическая ручка
			var handle_l = MeshInstance3D.new()
			var hlm = BoxMesh.new()
			hlm.size = Vector3(0.04, 0.05, 0.14)
			hlm.material = iron_m
			handle_l.mesh = hlm
			handle_l.position = Vector3(leaf_w - 0.08, 0.05, 0.15)
			left_hinge.add_child(handle_l)

			# Правая створка с петлями
			var right_hinge = Node3D.new()
			right_hinge.name = "RightHinge"
			right_hinge.position = Vector3(0.81, 0.03, 0.0)

			var right_leaf = MeshInstance3D.new()
			var rl_m = BoxMesh.new()
			rl_m.size = Vector3(leaf_w, leaf_th, leaf_len)
			rl_m.material = wood_m
			right_leaf.mesh = rl_m
			right_leaf.position = Vector3(-leaf_w * 0.5, 0, 0)
			right_hinge.add_child(right_leaf)

			for px in [-0.20, 0.0, 0.20]:
				var plank_groove = MeshInstance3D.new()
				var pgm = BoxMesh.new()
				pgm.size = Vector3(0.015, leaf_th + 0.005, leaf_len)
				var groove_mat = StandardMaterial3D.new()
				groove_mat.albedo_color = Color(0.20, 0.13, 0.08)
				pgm.material = groove_mat
				plank_groove.mesh = pgm
				plank_groove.position = Vector3(-leaf_w * 0.5 + px, 0.002, 0)
				right_hinge.add_child(plank_groove)

			for pz in [-0.70, 0.70]:
				var strap = MeshInstance3D.new()
				var sm = BoxMesh.new()
				sm.size = Vector3(0.55, 0.02, 0.07)
				sm.material = iron_m
				strap.mesh = sm
				strap.position = Vector3(-0.28, 0.03, pz)
				right_hinge.add_child(strap)

				var knuckle = MeshInstance3D.new()
				var km = BoxMesh.new()
				km.size = Vector3(0.06, 0.04, 0.09)
				km.material = iron_m
				knuckle.mesh = km
				knuckle.position = Vector3(-0.02, 0.03, pz)
				right_hinge.add_child(knuckle)

			var handle_r = MeshInstance3D.new()
			var hrm = BoxMesh.new()
			hrm.size = Vector3(0.04, 0.05, 0.14)
			hrm.material = iron_m
			handle_r.mesh = hrm
			handle_r.position = Vector3(-leaf_w + 0.08, 0.05, 0.15)
			right_hinge.add_child(handle_r)

			# Коллайдеры створок на петлях
			if not is_ghost:
				var sb_l = StaticBody3D.new()
				sb_l.name = "LeftLeafBody"
				sb_l.collision_layer = 1
				sb_l.collision_mask = 0
				sb_l.set_meta("item_type", "prop_basement_entrance")
				var cs_l = CollisionShape3D.new()
				var shape_l = BoxShape3D.new()
				shape_l.size = Vector3(leaf_w, leaf_th * 1.5, leaf_len)
				cs_l.shape = shape_l
				cs_l.position = Vector3(leaf_w * 0.5, 0, 0)
				sb_l.add_child(cs_l)
				left_hinge.add_child(sb_l)

				var sb_r = StaticBody3D.new()
				sb_r.name = "RightLeafBody"
				sb_r.collision_layer = 1
				sb_r.collision_mask = 0
				sb_r.set_meta("item_type", "prop_basement_entrance")
				var cs_r = CollisionShape3D.new()
				var shape_r = BoxShape3D.new()
				shape_r.size = Vector3(leaf_w, leaf_th * 1.5, leaf_len)
				cs_r.shape = shape_r
				cs_r.position = Vector3(-leaf_w * 0.5, 0, 0)
				sb_r.add_child(cs_r)
				right_hinge.add_child(sb_r)

			door_assembly.add_child(left_hinge)
			door_assembly.add_child(right_hinge)
			cellar_root.add_child(door_assembly)
			if not is_ghost:
				CellarLook.apply(cellar_root, true, true, true, true)

			if not is_ghost:
				cellar_root.set_script(load("res://scripts/InteractiveCellar.gd"))
				cellar_root.set("open_angle", 100.0)
				cellar_root.set("move_duration", 0.65)

			root.add_child(cellar_root)

		"prop_mirror":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			# Багетная золоченая рама
			var frame_mat = StandardMaterial3D.new()
			frame_mat.albedo_color = Color(0.78, 0.65, 0.22)
			frame_mat.metallic = 0.75
			frame_mat.roughness = 0.4
			if is_ghost:
				frame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				frame_mat.albedo_color.a = 0.60

			var frame = MeshInstance3D.new()
			var fm = BoxMesh.new()
			fm.size = Vector3(0.9, 1.6, 0.08)
			fm.material = frame_mat
			frame.mesh = fm
			frame.position = Vector3(0, 0.8, 0)
			sb.add_child(frame)

			# Зеркальное полотно (QuadMesh для 100% покрытия текстурой SubViewport)
			var glass_mat = StandardMaterial3D.new()
			glass_mat.albedo_color = Color(0.85, 0.90, 0.98)
			glass_mat.metallic = 0.98
			glass_mat.roughness = 0.04
			var glass = MeshInstance3D.new()
			glass.name = "Glass"
			var gm = QuadMesh.new()
			gm.size = Vector2(0.74, 1.44)
			gm.material = glass_mat
			glass.mesh = gm
			glass.position = Vector3(0, 0.8, 0.042)
			sb.add_child(glass)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.9, 1.6, 0.08)
				col.shape = box
				col.position = Vector3(0, 0.8, 0)
				sb.add_child(col)

				# ── Отражение персонажа (SubViewport на поверхность стекла) ────────────
				var refl_node = Node3D.new()
				refl_node.name = "PlayerReflection"
				refl_node.set_script(load("res://scripts/MirrorReflection.gd"))
				sb.add_child(refl_node)

			root.add_child(sb)

		"prop_sink":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var ceram_mat = StandardMaterial3D.new()
			ceram_mat.albedo_color = Color(0.94, 0.95, 0.97)
			ceram_mat.roughness = 0.15
			if is_ghost:
				ceram_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				ceram_mat.albedo_color.a = 0.60

			# Ножка-пьедестал
			var stand = MeshInstance3D.new()
			var sm = BoxMesh.new()
			sm.size = Vector3(0.25, 0.70, 0.25)
			sm.material = ceram_mat
			stand.mesh = sm
			stand.position = Vector3(0, 0.35, 0)
			sb.add_child(stand)

			# Чаша умывальника
			var basin = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.70, 0.20, 0.55)
			bm.material = ceram_mat
			basin.mesh = bm
			basin.position = Vector3(0, 0.80, 0)
			sb.add_child(basin)

			# Смеситель
			var chrome_mat = StandardMaterial3D.new()
			chrome_mat.albedo_color = Color(0.85, 0.88, 0.92)
			chrome_mat.metallic = 0.95
			chrome_mat.roughness = 0.2
			var tap = MeshInstance3D.new()
			var tm = BoxMesh.new()
			tm.size = Vector3(0.06, 0.14, 0.12)
			tm.material = chrome_mat
			tap.mesh = tm
			tap.position = Vector3(0, 0.95, -0.15)
			sb.add_child(tap)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.70, 0.90, 0.55)
				col.shape = box
				col.position = Vector3(0, 0.45, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_bathtub":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var tub_mat = StandardMaterial3D.new()
			tub_mat.albedo_color = Color(0.92, 0.93, 0.95)
			tub_mat.roughness = 0.2
			if is_ghost:
				tub_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				tub_mat.albedo_color.a = 0.60

			# Корпус ванны
			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(1.70, 0.55, 0.75)
			bm.material = tub_mat
			body.mesh = bm
			body.position = Vector3(0, 0.35, 0)
			sb.add_child(body)

			# 4 латунные ножки
			var brass_mat = StandardMaterial3D.new()
			brass_mat.albedo_color = Color(0.75, 0.60, 0.20)
			brass_mat.metallic = 0.85
			for lx in [-0.72, 0.72]:
				for lz in [-0.30, 0.30]:
					var foot = MeshInstance3D.new()
					var fm = BoxMesh.new()
					fm.size = Vector3(0.08, 0.12, 0.08)
					fm.material = brass_mat
					foot.mesh = fm
					foot.position = Vector3(lx, 0.06, lz)
					sb.add_child(foot)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(1.70, 0.65, 0.75)
				col.shape = box
				col.position = Vector3(0, 0.325, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_fridge":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var fridge_mat = StandardMaterial3D.new()
			fridge_mat.albedo_color = Color(0.85, 0.88, 0.86)
			fridge_mat.roughness = 0.35
			if is_ghost:
				fridge_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				fridge_mat.albedo_color.a = 0.60

			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.75, 1.75, 0.75)
			bm.material = fridge_mat
			body.mesh = bm
			body.position = Vector3(0, 0.875, 0)
			sb.add_child(body)

			# Хромированная ручка
			var chrome_mat = StandardMaterial3D.new()
			chrome_mat.albedo_color = Color(0.9, 0.9, 0.95)
			chrome_mat.metallic = 0.95
			var handle = MeshInstance3D.new()
			var hm = BoxMesh.new()
			hm.size = Vector3(0.04, 0.28, 0.05)
			hm.material = chrome_mat
			handle.mesh = hm
			handle.position = Vector3(0.30, 0.95, 0.39)
			sb.add_child(handle)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.75, 1.75, 0.75)
				col.shape = box
				col.position = Vector3(0, 0.875, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_stove":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var stove_mat = StandardMaterial3D.new()
			stove_mat.albedo_color = Color(0.18, 0.20, 0.22)
			stove_mat.roughness = 0.4
			if is_ghost:
				stove_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				stove_mat.albedo_color.a = 0.60

			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.75, 0.95, 0.75)
			bm.material = stove_mat
			body.mesh = bm
			body.position = Vector3(0, 0.475, 0)
			sb.add_child(body)

			# 4 конфорки сверху
			for bx in [-0.20, 0.20]:
				for bz in [-0.20, 0.20]:
					var burner = MeshInstance3D.new()
					var bm_burn = CylinderMesh.new()
					bm_burn.top_radius = 0.09
					bm_burn.bottom_radius = 0.09
					bm_burn.height = 0.02
					var burn_mat = StandardMaterial3D.new()
					burn_mat.albedo_color = Color(0.1, 0.1, 0.1)
					bm_burn.material = burn_mat
					burner.mesh = bm_burn
					burner.position = Vector3(bx, 0.96, bz)
					sb.add_child(burner)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.75, 0.95, 0.75)
				col.shape = box
				col.position = Vector3(0, 0.475, 0)
				sb.add_child(col)

			root.add_child(sb)
		"prop_table":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.36, 0.22, 0.13)
			wood_mat.roughness = 0.75
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			# Столешница
			var top = MeshInstance3D.new()
			var bm_top = BoxMesh.new()
			bm_top.size = Vector3(1.80, 0.08, 0.95)
			bm_top.material = wood_mat
			top.mesh = bm_top
			top.position = Vector3(0, 0.76, 0)
			sb.add_child(top)

			# Подстолье (рама под столешницей)
			var apron = MeshInstance3D.new()
			var bm_ap = BoxMesh.new()
			bm_ap.size = Vector3(1.62, 0.08, 0.77)
			var dark_wood = StandardMaterial3D.new()
			dark_wood.albedo_color = Color(0.28, 0.16, 0.09)
			bm_ap.material = dark_wood
			apron.mesh = bm_ap
			apron.position = Vector3(0, 0.68, 0)
			sb.add_child(apron)

			# 4 ножки
			for x in [-0.78, 0.78]:
				for z in [-0.37, 0.37]:
					var leg = MeshInstance3D.new()
					var lm = BoxMesh.new()
					lm.size = Vector3(0.08, 0.72, 0.08)
					lm.material = dark_wood
					leg.mesh = lm
					leg.position = Vector3(x, 0.36, z)
					sb.add_child(leg)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(1.80, 0.80, 0.95)
				col.shape = box
				col.position = Vector3(0, 0.40, 0)
				sb.add_child(col)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  МЕБЕЛЬ: ДЕРЕВЯННЫЙ СТУЛ
		# ─────────────────────────────────────────────────────────────
		"prop_chair":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "prop_chair")
			sb.set_meta("item_label", "стул")
			sb.set_meta("is_pickable", true)

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.40, 0.25, 0.15)
			wood_mat.roughness = 0.8
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			# Сиденье
			var seat = MeshInstance3D.new()
			var bm_seat = BoxMesh.new()
			bm_seat.size = Vector3(0.50, 0.05, 0.48)
			bm_seat.material = wood_mat
			seat.mesh = bm_seat
			seat.position = Vector3(0, 0.46, 0)
			sb.add_child(seat)

			# Ножки
			for x in [-0.20, 0.20]:
				for z in [-0.19, 0.19]:
					var leg = MeshInstance3D.new()
					var lm = BoxMesh.new()
					lm.size = Vector3(0.05, 0.44, 0.05)
					lm.material = wood_mat
					leg.mesh = lm
					leg.position = Vector3(x, 0.22, z)
					sb.add_child(leg)

			# Стойки спинки
			for x in [-0.20, 0.20]:
				var post = MeshInstance3D.new()
				var pm = BoxMesh.new()
				pm.size = Vector3(0.05, 0.48, 0.05)
				pm.material = wood_mat
				post.mesh = pm
				post.position = Vector3(x, 0.70, -0.215)
				sb.add_child(post)

			# Перекладина спинки верхняя
			var top_slat = MeshInstance3D.new()
			var tsm = BoxMesh.new()
			tsm.size = Vector3(0.45, 0.10, 0.04)
			tsm.material = wood_mat
			top_slat.mesh = tsm
			top_slat.position = Vector3(0, 0.90, -0.215)
			sb.add_child(top_slat)

			# Перекладина средняя
			var mid_slat = MeshInstance3D.new()
			var msm = BoxMesh.new()
			msm.size = Vector3(0.45, 0.06, 0.03)
			msm.material = wood_mat
			mid_slat.mesh = msm
			mid_slat.position = Vector3(0, 0.66, -0.215)
			sb.add_child(mid_slat)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(0.52, 0.96, 0.52)
				col.shape = box
				col.position = Vector3(0, 0.48, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_alarm_clock", "alarm_clock":
			var item = Area3D.new()
			item.set_script(load("res://scripts/Item.gd"))
			item.set_meta("item_type", "alarm_clock")
			item.set_meta("item_label", "будильник")
			item.set_meta("is_pickable", true)
			root.add_child(item)

		"prop_tv_remote", "tv_remote", "remote":
			var item = Area3D.new()
			item.set_script(load("res://scripts/Item.gd"))
			item.set_meta("item_type", "tv_remote")
			item.set_meta("item_label", "пульт от ТВ")
			item.set_meta("is_pickable", true)
			root.add_child(item)

		# ─────────────────────────────────────────────────────────────
		#  МЕБЕЛЬ: КРОВАТЬ С МАТРАСОМ И ПОДУШКОЙ
		# ─────────────────────────────────────────────────────────────
		"prop_bed":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "bed")
			sb.set_meta("hiding_type", "bed")

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.30, 0.16, 0.09)
			wood_mat.roughness = 0.85
			if is_ghost:
				wood_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				wood_mat.albedo_color.a = 0.60

			# Деревянный каркас
			var frame = MeshInstance3D.new()
			var bm_fr = BoxMesh.new()
			bm_fr.size = Vector3(1.45, 0.22, 2.10)
			bm_fr.material = wood_mat
			frame.mesh = bm_fr
			frame.position = Vector3(0, 0.18, 0)
			sb.add_child(frame)

			# Высокое изголовье
			var headboard = MeshInstance3D.new()
			var bm_hb = BoxMesh.new()
			bm_hb.size = Vector3(1.48, 0.85, 0.08)
			bm_hb.material = wood_mat
			headboard.mesh = bm_hb
			headboard.position = Vector3(0, 0.52, -1.02)
			sb.add_child(headboard)

			# Изножье
			var footboard = MeshInstance3D.new()
			var bm_fb = BoxMesh.new()
			bm_fb.size = Vector3(1.48, 0.42, 0.08)
			bm_fb.material = wood_mat
			footboard.mesh = bm_fb
			footboard.position = Vector3(0, 0.30, 1.02)
			sb.add_child(footboard)

			# Матрас
			var mat_mat = StandardMaterial3D.new()
			mat_mat.albedo_color = Color(0.70, 0.68, 0.62)
			mat_mat.roughness = 0.95
			var mattress = MeshInstance3D.new()
			var bm_mat = BoxMesh.new()
			bm_mat.size = Vector3(1.34, 0.20, 1.94)
			bm_mat.material = mat_mat
			mattress.mesh = bm_mat
			mattress.position = Vector3(0, 0.35, 0)
			sb.add_child(mattress)

			# Подушка
			var pillow_mat = StandardMaterial3D.new()
			pillow_mat.albedo_color = Color(0.80, 0.78, 0.72)
			var pillow = MeshInstance3D.new()
			var bm_pil = BoxMesh.new()
			bm_pil.size = Vector3(0.65, 0.10, 0.38)
			bm_pil.material = pillow_mat
			pillow.mesh = bm_pil
			pillow.position = Vector3(0, 0.48, -0.72)
			sb.add_child(pillow)

			# Одеяло (покрывало на нижнюю половину)
			var blanket_mat = StandardMaterial3D.new()
			blanket_mat.albedo_color = Color(0.22, 0.20, 0.26)
			blanket_mat.roughness = 0.95
			var blanket = MeshInstance3D.new()
			var bm_bl = BoxMesh.new()
			bm_bl.size = Vector3(1.36, 0.09, 1.15)
			bm_bl.material = blanket_mat
			blanket.mesh = bm_bl
			blanket.position = Vector3(0, 0.42, 0.38)
			sb.add_child(blanket)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var box = BoxShape3D.new()
				box.size = Vector3(1.48, 0.88, 2.12)
				col.shape = box
				col.position = Vector3(0, 0.44, 0)
				sb.add_child(col)

			root.add_child(sb)

		# ─────────────────────────────────────────────────────────────
		#  ГЕЙМПЛЕЙ: СПАВНЫ, ДВЕРЬ, ПРЕДМЕТЫ, СВЕТ, БОЧКИ, ЯЩИКИ
		# ─────────────────────────────────────────────────────────────
		"marker_player", "marker_enemy", "marker_lumberjack":
			var area = Area3D.new()
			area.collision_layer = 1
			area.collision_mask = 0
			area.monitoring = false
			area.monitorable = true

			# 1. Плоский круг-пьедестал спавна на полу
			var pad = MeshInstance3D.new()
			var pad_mesh = CylinderMesh.new()
			pad_mesh.top_radius = 0.55
			pad_mesh.bottom_radius = 0.60
			pad_mesh.height = 0.05
			var pad_mat = StandardMaterial3D.new()
			pad_mat.albedo_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.85)
			pad_mat.roughness = 0.4
			pad_mat.emission_enabled = true
			pad_mat.emission = color
			pad_mat.emission_energy_multiplier = 0.5
			pad_mesh.material = pad_mat
			pad.mesh = pad_mesh
			pad.position = Vector3(0, 0.025, 0)
			area.add_child(pad)

			# 2. Стрелка направления взгляда (на полу)
			var arrow = MeshInstance3D.new()
			var prism = PrismMesh.new()
			prism.size = Vector3(0.35, 0.5, 0.05)
			var amat = StandardMaterial3D.new()
			amat.albedo_color = Color(1.0, 1.0, 1.0)
			amat.emission_enabled = true
			amat.emission = color
			amat.emission_energy_multiplier = 0.8
			prism.material = amat
			arrow.mesh = prism
			arrow.position = Vector3(0, 0.055, -0.3)
			arrow.rotation_degrees = Vector3(-90, 0, 0)
			area.add_child(arrow)

			# 3. Полупрозрачный голографический силуэт
			var holo = MeshInstance3D.new()
			var cap = CapsuleMesh.new()
			cap.radius = 0.28
			cap.height = 1.6
			var hmat = StandardMaterial3D.new()
			hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			hmat.albedo_color = Color(color.r, color.g, color.b, 0.30 if not is_ghost else 0.15)
			hmat.emission_enabled = true
			hmat.emission = color
			hmat.emission_energy_multiplier = 0.4
			cap.material = hmat
			holo.mesh = cap
			holo.position = Vector3(0, 0.85, 0)
			area.add_child(holo)

			# Текстовая 3D метка над спавном
			var lbl = Label3D.new()
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.font_size = 28
			lbl.outline_size = 4
			lbl.outline_modulate = Color(0, 0, 0, 1)
			if type in ["marker_lumberjack", "spawn_lumberjack"]:
				lbl.text = "ЛЕСОПИЛ"
				lbl.modulate = Color(1.0, 0.65, 0.2)
			elif type in ["marker_enemy", "spawn_enemy"]:
				lbl.text = "СКИНВОКЕР"
				lbl.modulate = Color(1.0, 0.25, 0.25)
			else:
				lbl.text = "ИГРОК"
				lbl.modulate = Color(0.25, 1.0, 0.75)
			lbl.position = Vector3(0, 1.85, 0)
			area.add_child(lbl)

			# Коллизия ТОЛЬКО для клика мыши в редакторе (не блокирует физику CharacterBody3D)
			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = 0.65
				shape.height = 1.7
				col.shape = shape
				col.position = Vector3(0, 0.85, 0)
				area.add_child(col)

			root.add_child(area)


		"item_crowbar", "custom_item_crowbar":
			if not is_ghost:
				var item = Area3D.new()
				item.set_script(load("res://scripts/Item.gd"))
				item.set_meta("item_type", "crowbar")
				item.set_meta("item_label", "лом")
				item.set_meta("is_pickable", true)
				root.add_child(item)
			else:
				var area = Area3D.new()
				var col = CollisionShape3D.new()
				var sphere = SphereShape3D.new()
				sphere.radius = 0.5
				col.shape = sphere
				area.add_child(col)

				var mi = MeshInstance3D.new()
				var cm = CylinderMesh.new()
				cm.top_radius = 0.02
				cm.bottom_radius = 0.02
				cm.height = 0.65
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.85, 0.12, 0.08, 0.6)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				cm.material = mat
				mi.mesh = cm
				mi.rotation_degrees.z = 25.0
				area.add_child(mi)
				root.add_child(area)

		"item_key", "custom_item_key":
			if not is_ghost:
				var item = Area3D.new()
				item.set_script(load("res://scripts/Item.gd"))
				item.set_meta("item_type", "key")
				item.set_meta("item_label", "ключ")
				item.set_meta("lock_id", 1)
				item.set_meta("is_pickable", true)
				root.add_child(item)
			else:
				var area = Area3D.new()
				var col = CollisionShape3D.new()
				var sphere = SphereShape3D.new()
				sphere.radius = 0.4
				col.shape = sphere
				area.add_child(col)

				var mi = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(0.24, 0.08, 0.04)
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(1.0, 0.82, 0.15, 0.6)
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				bm.material = mat
				mi.mesh = bm
				area.add_child(mi)
				root.add_child(area)

		"light_warm", "light_red":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var mi = MeshInstance3D.new()
			var sm = SphereMesh.new()
			sm.radius = 0.25
			sm.height = 0.5
			var mat = StandardMaterial3D.new()
			mat.albedo_color = color
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 2.0
			sm.material = mat
			mi.mesh = sm
			sb.add_child(mi)

			var light = OmniLight3D.new()
			light.light_color = color
			light.light_energy = 2.5 if type == "light_red" else 1.8
			light.omni_range = 8.0
			sb.add_child(light)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = SphereShape3D.new()
				shape.radius = 0.35
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"prop_crate":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			if _is_legacy_mode():
				var mi = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = sz
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.48, 0.34, 0.20)
				mat.roughness = 0.9
				bm.material = mat
				mi.mesh = bm
				sb.add_child(mi)
			else:
				_build_realistic_crate(sb, sz, is_ghost)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"prop_barrel":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			if _is_legacy_mode():
				var mi = MeshInstance3D.new()
				var cyl = CylinderMesh.new()
				cyl.top_radius = sz.x * 0.5
				cyl.bottom_radius = sz.x * 0.5
				cyl.height = sz.y
				var mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.24, 0.30, 0.38)
				mat.metallic = 0.4
				mat.roughness = 0.6
				cyl.material = mat
				mi.mesh = cyl
				sb.add_child(mi)
			else:
				_build_realistic_barrel(sb, sz, is_ghost)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = sz.x * 0.5
				shape.height = sz.y
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"road_segment":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			# Асфальтовое полотно дороги
			var road_mi = MeshInstance3D.new()
			var road_mesh = BoxMesh.new()
			road_mesh.size = sz
			var road_mat = StandardMaterial3D.new()
			road_mat.albedo_color = Color(0.13, 0.14, 0.16)
			road_mat.roughness = 0.92
			road_mesh.material = road_mat
			road_mi.mesh = road_mesh
			sb.add_child(road_mi)

			# Обочины (гравий/песок по краям)
			for side in [-1.0, 1.0]:
				var shoulder_mi = MeshInstance3D.new()
				var sh_box = BoxMesh.new()
				sh_box.size = Vector3(sz.x * 0.08, sz.y * 1.02, sz.z)
				var sh_mat = StandardMaterial3D.new()
				sh_mat.albedo_color = Color(0.32, 0.28, 0.20)
				sh_box.material = sh_mat
				shoulder_mi.mesh = sh_box
				shoulder_mi.position = Vector3(side * (sz.x * 0.46), 0.005, 0)
				sb.add_child(shoulder_mi)

			# Осевая белая разметка (прерывистая линия)
			var num_stripes = max(2, int(sz.z / 6.0))
			var stripe_len = min(3.0, sz.z / (num_stripes * 2.0))
			for i in range(num_stripes):
				var mark_mi = MeshInstance3D.new()
				var mark_box = BoxMesh.new()
				mark_box.size = Vector3(0.28, sz.y * 1.05, stripe_len)
				var mark_mat = StandardMaterial3D.new()
				mark_mat.albedo_color = Color(0.92, 0.92, 0.90)
				mark_box.material = mark_mat
				mark_mi.mesh = mark_box
				var z_pos = -sz.z * 0.5 + (i + 0.5) * (sz.z / float(num_stripes))
				mark_mi.position = Vector3(0, 0.008, z_pos)
				sb.add_child(mark_mi)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				sb.add_child(col)

			root.add_child(sb)

		"prop_car":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			# Нижний кузов (шасси)
			var body_mi = MeshInstance3D.new()
			var body_mesh = BoxMesh.new()
			body_mesh.size = Vector3(1.85, 0.65, 4.2)
			var car_mat = StandardMaterial3D.new()
			car_mat.albedo_color = Color(0.20, 0.32, 0.48) if color == Color.WHITE else color
			car_mat.metallic = 0.65
			car_mat.roughness = 0.35
			body_mesh.material = car_mat
			body_mi.mesh = body_mesh
			body_mi.position = Vector3(0, 0.55, 0)
			sb.add_child(body_mi)

			# Кабина с крышей
			var cabin_mi = MeshInstance3D.new()
			var cabin_mesh = BoxMesh.new()
			cabin_mesh.size = Vector3(1.50, 0.60, 2.20)
			cabin_mesh.material = car_mat
			cabin_mi.mesh = cabin_mesh
			cabin_mi.position = Vector3(0, 1.15, -0.25)
			sb.add_child(cabin_mi)

			# Тонированные стёкла (лобовое, заднее, боковые)
			var glass_mat = StandardMaterial3D.new()
			glass_mat.albedo_color = Color(0.08, 0.12, 0.18, 0.90)
			glass_mat.metallic = 0.9
			glass_mat.roughness = 0.1

			var w_front = MeshInstance3D.new()
			var w_front_mesh = BoxMesh.new()
			w_front_mesh.size = Vector3(1.42, 0.45, 0.06)
			w_front_mesh.material = glass_mat
			w_front.mesh = w_front_mesh
			w_front.position = Vector3(0, 1.12, -1.36)
			w_front.rotation_degrees = Vector3(-18, 0, 0)
			sb.add_child(w_front)

			var w_back = MeshInstance3D.new()
			var w_back_mesh = BoxMesh.new()
			w_back_mesh.size = Vector3(1.42, 0.45, 0.06)
			w_back_mesh.material = glass_mat
			w_back.mesh = w_back_mesh
			w_back.position = Vector3(0, 1.12, 0.86)
			w_back.rotation_degrees = Vector3(18, 0, 0)
			sb.add_child(w_back)

			# 4 колеса с шинами и дисками
			var tire_mat = StandardMaterial3D.new()
			tire_mat.albedo_color = Color(0.06, 0.06, 0.07)
			tire_mat.roughness = 0.95
			var wheel_positions = [
				Vector3(-0.95, 0.35, -1.35),
				Vector3( 0.95, 0.35, -1.35),
				Vector3(-0.95, 0.35,  1.35),
				Vector3( 0.95, 0.35,  1.35)
			]
			for wp in wheel_positions:
				var wheel = MeshInstance3D.new()
				var cyl = CylinderMesh.new()
				cyl.top_radius = 0.35
				cyl.bottom_radius = 0.35
				cyl.height = 0.26
				cyl.material = tire_mat
				wheel.mesh = cyl
				wheel.position = wp
				wheel.rotation_degrees = Vector3(0, 0, 90)
				sb.add_child(wheel)

			# Передние фары (светятся в темноте)
			var headlight_mat = StandardMaterial3D.new()
			headlight_mat.albedo_color = Color(1.0, 0.95, 0.7)
			headlight_mat.emission_enabled = true
			headlight_mat.emission = Color(1.0, 0.92, 0.6)
			headlight_mat.emission_energy_multiplier = 2.0
			for x in [-0.62, 0.62]:
				var hl = MeshInstance3D.new()
				var hl_box = BoxMesh.new()
				hl_box.size = Vector3(0.28, 0.16, 0.08)
				hl_box.material = headlight_mat
				hl.mesh = hl_box
				hl.position = Vector3(x, 0.62, -2.12)
				sb.add_child(hl)

			# Задние красные фонари
			var taillight_mat = StandardMaterial3D.new()
			taillight_mat.albedo_color = Color(0.9, 0.05, 0.05)
			taillight_mat.emission_enabled = true
			taillight_mat.emission = Color(0.9, 0.05, 0.05)
			taillight_mat.emission_energy_multiplier = 1.6
			for x in [-0.62, 0.62]:
				var tl = MeshInstance3D.new()
				var tl_box = BoxMesh.new()
				tl_box.size = Vector3(0.28, 0.14, 0.08)
				tl_box.material = taillight_mat
				tl.mesh = tl_box
				tl.position = Vector3(x, 0.62, 2.12)
				sb.add_child(tl)

			# Бамперы
			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.12, 0.12, 0.14)
			var b_front = MeshInstance3D.new()
			var bf_box = BoxMesh.new()
			bf_box.size = Vector3(1.88, 0.22, 0.20)
			bf_box.material = b_mat
			b_front.mesh = bf_box
			b_front.position = Vector3(0, 0.36, -2.15)
			sb.add_child(b_front)

			var b_rear = MeshInstance3D.new()
			var br_box = BoxMesh.new()
			br_box.size = Vector3(1.88, 0.22, 0.20)
			br_box.material = b_mat
			b_rear.mesh = br_box
			b_rear.position = Vector3(0, 0.36, 2.15)
			sb.add_child(b_rear)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = Vector3(2.0, 1.5, 4.4)
				col.shape = shape
				col.position = Vector3(0, 0.75, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_rock_large":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			NatureKit.add_rock(sb, sz, color)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz * 1.05
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"roof_gable", "custom_roof_gable":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var roof_mat = StandardMaterial3D.new()
			roof_mat.albedo_color = Color(0.48, 0.16, 0.16) if color == Color.WHITE else color
			roof_mat.roughness = 0.90
			if is_ghost:
				roof_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				roof_mat.albedo_color.a = 0.5

			var w = sz.x
			var h = sz.y
			var d = sz.z
			var half_d = d * 0.5
			var pitch_deg = 28.0
			var pitch_rad = deg_to_rad(pitch_deg)
			var slope_len = half_d / cos(pitch_rad)
			var thickness = 0.25

			var mi_left = MeshInstance3D.new()
			var bm_left = BoxMesh.new()
			bm_left.size = Vector3(w + 0.4, thickness, slope_len)
			bm_left.material = roof_mat
			mi_left.mesh = bm_left
			mi_left.position = Vector3(0, h * 0.5, -d * 0.25)
			mi_left.rotation_degrees = Vector3(-pitch_deg, 0, 0)
			sb.add_child(mi_left)

			var mi_right = MeshInstance3D.new()
			var bm_right = BoxMesh.new()
			bm_right.size = Vector3(w + 0.4, thickness, slope_len)
			bm_right.material = roof_mat
			mi_right.mesh = bm_right
			mi_right.position = Vector3(0, h * 0.5, d * 0.25)
			mi_right.rotation_degrees = Vector3(pitch_deg, 0, 0)
			sb.add_child(mi_right)

			var ridge = MeshInstance3D.new()
			var r_box = BoxMesh.new()
			r_box.size = Vector3(w + 0.5, thickness * 1.1, 0.35)
			var rmat = StandardMaterial3D.new()
			rmat.albedo_color = Color(0.28, 0.10, 0.10) if color == Color.WHITE else color.darkened(0.15)
			r_box.material = rmat
			ridge.mesh = r_box
			ridge.position = Vector3(0, h + 0.05, 0)
			sb.add_child(ridge)

			var gable_mat = StandardMaterial3D.new()
			gable_mat.albedo_color = Color(0.48, 0.46, 0.42) if color == Color.WHITE else color.lightened(0.06)
			var g_front = MeshInstance3D.new()
			var gm = PrismMesh.new()
			gm.size = Vector3(d, h, 0.2)
			gm.material = gable_mat
			g_front.mesh = gm
			g_front.rotation_degrees.y = 90.0
			g_front.position = Vector3(w * 0.5 - 0.1, h * 0.5, 0)
			sb.add_child(g_front)

			var g_back = MeshInstance3D.new()
			g_back.mesh = gm
			g_back.rotation_degrees.y = 90.0
			g_back.position = Vector3(-w * 0.5 + 0.1, h * 0.5, 0)
			sb.add_child(g_back)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, h * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_sofa", "custom_prop_sofa":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var s_mat = StandardMaterial3D.new()
			s_mat.albedo_color = Color(0.35, 0.22, 0.18) if color == Color.WHITE else color
			s_mat.roughness = 0.85
			if is_ghost:
				s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				s_mat.albedo_color.a = 0.5

			# Основа дивана
			var base = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y * 0.42, sz.z)
			bm.material = s_mat
			base.mesh = bm
			base.position = Vector3(0, sz.y * 0.21, 0)
			sb.add_child(base)

			# Спинка
			var back = MeshInstance3D.new()
			var bkm = BoxMesh.new()
			bkm.size = Vector3(sz.x, sz.y * 0.65, sz.z * 0.22)
			bkm.material = s_mat
			back.mesh = bkm
			back.position = Vector3(0, sz.y * 0.65, -sz.z * 0.39)
			sb.add_child(back)

			# Подлокотники
			var arm_mat = StandardMaterial3D.new()
			arm_mat.albedo_color = s_mat.albedo_color * 0.85
			var arm_l = MeshInstance3D.new()
			var am = BoxMesh.new()
			am.size = Vector3(sz.x * 0.12, sz.y * 0.55, sz.z)
			am.material = arm_mat
			arm_l.mesh = am
			arm_l.position = Vector3(-sz.x * 0.44, sz.y * 0.32, 0)
			sb.add_child(arm_l)

			var arm_r = MeshInstance3D.new()
			arm_r.mesh = am
			arm_r.position = Vector3(sz.x * 0.44, sz.y * 0.32, 0)
			sb.add_child(arm_r)

			# Подушки сидений (3 штуки)
			var c_mat = StandardMaterial3D.new()
			c_mat.albedo_color = s_mat.albedo_color * 1.15
			var c_width = (sz.x * 0.72) / 3.0
			for i in range(3):
				var cush = MeshInstance3D.new()
				var cm = BoxMesh.new()
				cm.size = Vector3(c_width * 0.92, sz.y * 0.14, sz.z * 0.72)
				cm.material = c_mat
				cush.mesh = cm
				cush.position = Vector3(-c_width + i * c_width, sz.y * 0.45, sz.z * 0.08)
				sb.add_child(cush)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_armchair", "custom_prop_armchair":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var a_mat = StandardMaterial3D.new()
			a_mat.albedo_color = Color(0.28, 0.32, 0.40) if color == Color.WHITE else color
			a_mat.roughness = 0.85
			if is_ghost:
				a_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				a_mat.albedo_color.a = 0.5

			var seat = MeshInstance3D.new()
			var sm = BoxMesh.new()
			sm.size = Vector3(sz.x * 0.75, sz.y * 0.40, sz.z * 0.75)
			sm.material = a_mat
			seat.mesh = sm
			seat.position = Vector3(0, sz.y * 0.20, 0)
			sb.add_child(seat)

			var back = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x * 0.75, sz.y * 0.65, sz.z * 0.20)
			bm.material = a_mat
			back.mesh = bm
			back.position = Vector3(0, sz.y * 0.60, -sz.z * 0.35)
			sb.add_child(back)

			var arm_l = MeshInstance3D.new()
			var am = BoxMesh.new()
			am.size = Vector3(sz.x * 0.15, sz.y * 0.52, sz.z * 0.8)
			am.material = a_mat
			arm_l.mesh = am
			arm_l.position = Vector3(-sz.x * 0.42, sz.y * 0.30, 0)
			sb.add_child(arm_l)

			var arm_r = MeshInstance3D.new()
			arm_r.mesh = am
			arm_r.position = Vector3(sz.x * 0.42, sz.y * 0.30, 0)
			sb.add_child(arm_r)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_tv", "custom_prop_tv":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var tv_body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y * 0.85, sz.z * 0.18)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.08, 0.08, 0.10)
			bm.material = mat
			tv_body.mesh = bm
			tv_body.position = Vector3(0, sz.y * 0.55, 0)
			sb.add_child(tv_body)

			var screen = MeshInstance3D.new()
			var sm = BoxMesh.new()
			sm.size = Vector3(sz.x * 0.92, sz.y * 0.74, 0.02)
			var scr_mat = StandardMaterial3D.new()
			scr_mat.albedo_color = Color(0.02, 0.05, 0.08)
			scr_mat.emission_enabled = true
			scr_mat.emission = Color(0.1, 0.3, 0.6)
			scr_mat.emission_energy_multiplier = 0.5
			sm.material = scr_mat
			screen.mesh = sm
			screen.position = Vector3(0, sz.y * 0.55, sz.z * 0.10)
			sb.add_child(screen)

			var leg = MeshInstance3D.new()
			var lm = BoxMesh.new()
			lm.size = Vector3(sz.x * 0.35, sz.y * 0.12, sz.z * 0.6)
			lm.material = mat
			leg.mesh = lm
			leg.position = Vector3(0, sz.y * 0.06, 0)
			sb.add_child(leg)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_bookshelf", "custom_prop_bookshelf":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var w_mat = StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.32, 0.20, 0.12) if color == Color.WHITE else color
			var back = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y, sz.z * 0.1)
			bm.material = w_mat
			back.mesh = bm
			back.position = Vector3(0, sz.y * 0.5, -sz.z * 0.45)
			sb.add_child(back)

			var side_l = MeshInstance3D.new()
			var sm = BoxMesh.new()
			sm.size = Vector3(sz.x * 0.08, sz.y, sz.z)
			sm.material = w_mat
			side_l.mesh = sm
			side_l.position = Vector3(-sz.x * 0.46, sz.y * 0.5, 0)
			sb.add_child(side_l)

			var side_r = MeshInstance3D.new()
			side_r.mesh = sm
			side_r.position = Vector3(sz.x * 0.46, sz.y * 0.5, 0)
			sb.add_child(side_r)

			var book_colors = [Color(0.7,0.15,0.15), Color(0.15,0.4,0.7), Color(0.8,0.6,0.1), Color(0.2,0.5,0.2), Color(0.5,0.2,0.6)]
			for level in range(4):
				var sh = MeshInstance3D.new()
				var sh_m = BoxMesh.new()
				sh_m.size = Vector3(sz.x * 0.88, 0.05, sz.z * 0.9)
				sh_m.material = w_mat
				sh.mesh = sh_m
				var y_lvl = 0.15 + level * (sz.y * 0.25)
				sh.position = Vector3(0, y_lvl, 0)
				sb.add_child(sh)

				if level < 3:
					for bi in range(5):
						var bk = MeshInstance3D.new()
						var bkm = BoxMesh.new()
						bkm.size = Vector3(sz.x * 0.12, sz.y * 0.18, sz.z * 0.6)
						var b_mat = StandardMaterial3D.new()
						b_mat.albedo_color = book_colors[(level + bi) % book_colors.size()]
						bkm.material = b_mat
						bk.mesh = bkm
						bk.position = Vector3(-sz.x * 0.32 + bi * (sz.x * 0.16), y_lvl + sz.y * 0.10, 0)
						sb.add_child(bk)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_dresser", "custom_prop_dresser":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var d_mat = StandardMaterial3D.new()
			d_mat.albedo_color = Color(0.40, 0.25, 0.15) if color == Color.WHITE else color
			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			bm.material = d_mat
			body.mesh = bm
			body.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(body)

			var h_mat = StandardMaterial3D.new()
			h_mat.albedo_color = Color(0.85, 0.75, 0.3)
			h_mat.metallic = 0.8
			for i in range(3):
				var handle = MeshInstance3D.new()
				var hm = BoxMesh.new()
				hm.size = Vector3(sz.x * 0.25, 0.04, 0.05)
				hm.material = h_mat
				handle.mesh = hm
				handle.position = Vector3(0, sz.y * (0.25 + i * 0.28), sz.z * 0.52)
				sb.add_child(handle)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_lamp_floor", "custom_prop_lamp_floor":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var m_mat = StandardMaterial3D.new()
			m_mat.albedo_color = Color(0.25, 0.25, 0.28)
			m_mat.metallic = 0.6
			var base = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.25
			cm.bottom_radius = 0.25
			cm.height = 0.06
			cm.material = m_mat
			base.mesh = cm
			base.position = Vector3(0, 0.03, 0)
			sb.add_child(base)

			var pole = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.03
			pm.bottom_radius = 0.03
			pm.height = sz.y * 0.8
			pm.material = m_mat
			pole.mesh = pm
			pole.position = Vector3(0, sz.y * 0.4, 0)
			sb.add_child(pole)

			var shade = MeshInstance3D.new()
			var sm = CylinderMesh.new()
			sm.top_radius = 0.16
			sm.bottom_radius = 0.32
			sm.height = 0.36
			var sh_mat = StandardMaterial3D.new()
			sh_mat.albedo_color = Color(0.95, 0.88, 0.70)
			sh_mat.emission_enabled = true
			sh_mat.emission = Color(1.0, 0.85, 0.5)
			sh_mat.emission_energy_multiplier = 0.8
			sm.material = sh_mat
			shade.mesh = sm
			shade.position = Vector3(0, sz.y * 0.82, 0)
			sb.add_child(shade)

			if not is_ghost:
				var light = OmniLight3D.new()
				light.light_color = Color(1.0, 0.85, 0.55)
				light.light_energy = 1.4
				light.omni_range = 6.5
				light.position = Vector3(0, sz.y * 0.85, 0)
				sb.add_child(light)

				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = 0.32
				shape.height = sz.y
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_painting", "prop_painting_portrait", "prop_painting_landscape", \
		"prop_painting_moon", "prop_painting_skinwalker", "prop_painting_entity", \
		"prop_painting_vintage", "custom_prop_painting":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.24, 0.15, 0.08)
			f_mat.roughness = 0.85
			var frame = MeshInstance3D.new()
			frame.name = "Frame"
			var fm = BoxMesh.new()
			fm.size = sz
			fm.material = f_mat
			frame.mesh = fm
			frame.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(frame)

			# Определение ключа картины
			var art_key = "portrait"
			if "landscape" in type:
				art_key = "landscape"
			elif "moon" in type:
				art_key = "moon"
			elif "skinwalker" in type:
				art_key = "skinwalker"
			elif "entity" in type:
				art_key = "entity"
			elif "vintage" in type:
				art_key = "vintage"

			var canvas = MeshInstance3D.new()
			canvas.name = "Canvas"
			var cm = BoxMesh.new()
			cm.size = Vector3(sz.x * 0.84, sz.y * 0.82, 0.02)
			var cmat = TextureHelper.create_painting_canvas_material(art_key)
			cm.material = cmat
			canvas.mesh = cm
			canvas.position = Vector3(0, sz.y * 0.5, sz.z * 0.51)
			sb.add_child(canvas)

			var canvas_back = MeshInstance3D.new()
			canvas_back.name = "Canvas_Back"
			canvas_back.mesh = cm
			canvas_back.position = Vector3(0, sz.y * 0.5, -sz.z * 0.51)
			canvas_back.rotation_degrees = Vector3(0, 180, 0)
			sb.add_child(canvas_back)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.set_meta("painting_art", art_key)
			root.add_child(sb)

		"prop_plant_pot", "custom_prop_plant_pot":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var pot = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = sz.x * 0.45
			pm.bottom_radius = sz.x * 0.32
			pm.height = sz.y * 0.45
			var pmat = StandardMaterial3D.new()
			pmat.albedo_color = Color(0.70, 0.35, 0.18)
			pm.material = pmat
			pot.mesh = pm
			pot.position = Vector3(0, sz.y * 0.22, 0)
			sb.add_child(pot)

			var plant = MeshInstance3D.new()
			var leaf_m = SphereMesh.new()
			leaf_m.radius = sz.x * 0.42
			leaf_m.height = sz.y * 0.55
			var lmat = StandardMaterial3D.new()
			lmat.albedo_color = Color(0.18, 0.52, 0.22)
			lmat.roughness = 0.8
			leaf_m.material = lmat
			plant.mesh = leaf_m
			plant.position = Vector3(0, sz.y * 0.62, 0)
			sb.add_child(plant)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = sz.x * 0.45
				shape.height = sz.y
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_fridge", "custom_prop_fridge":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			var fmat = StandardMaterial3D.new()
			fmat.albedo_color = Color(0.88, 0.90, 0.92) if color == Color.WHITE else color
			fmat.metallic = 0.4
			fmat.roughness = 0.3
			bm.material = fmat
			body.mesh = bm
			body.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(body)

			var handle = MeshInstance3D.new()
			var hm = BoxMesh.new()
			hm.size = Vector3(0.05, sz.y * 0.25, 0.05)
			var hmat = StandardMaterial3D.new()
			hmat.albedo_color = Color(0.3, 0.3, 0.35)
			hm.material = hmat
			handle.mesh = hm
			handle.position = Vector3(sz.x * 0.38, sz.y * 0.65, sz.z * 0.52)
			sb.add_child(handle)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)


			root.add_child(sb)

		"prop_stove", "custom_prop_stove":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			var smat = StandardMaterial3D.new()
			smat.albedo_color = Color(0.20, 0.22, 0.24) if color == Color.WHITE else color
			bm.material = smat
			body.mesh = bm
			body.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(body)

			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.1, 0.1, 0.12)
			for bx in [-1, 1]:
				for bz in [-1, 1]:
					var burner = MeshInstance3D.new()
					var brm = CylinderMesh.new()
					brm.top_radius = sz.x * 0.16
					brm.bottom_radius = sz.x * 0.16
					brm.height = 0.03
					brm.material = b_mat
					burner.mesh = brm
					burner.position = Vector3(bx * (sz.x * 0.24), sz.y + 0.015, bz * (sz.z * 0.24))
					sb.add_child(burner)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_kitchen_counter", "custom_prop_kitchen_counter":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			var cmat = StandardMaterial3D.new()
			cmat.albedo_color = Color(0.72, 0.68, 0.60) if color == Color.WHITE else color
			bm.material = cmat
			body.mesh = bm
			body.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(body)

			var top = MeshInstance3D.new()
			var tm = BoxMesh.new()
			tm.size = Vector3(sz.x + 0.04, 0.06, sz.z + 0.04)
			var tmat = StandardMaterial3D.new()
			tmat.albedo_color = Color(0.25, 0.25, 0.28)
			tm.material = tmat
			top.mesh = tm
			top.position = Vector3(0, sz.y + 0.03, 0)
			sb.add_child(top)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_toilet", "custom_prop_toilet":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var w_mat = StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.92, 0.94, 0.96)
			w_mat.roughness = 0.2

			var base = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x * 0.7, sz.y * 0.42, sz.z * 0.6)
			bm.material = w_mat
			base.mesh = bm
			base.position = Vector3(0, sz.y * 0.21, sz.z * 0.1)
			sb.add_child(base)

			var bowl = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = sz.x * 0.32
			cm.bottom_radius = sz.x * 0.22
			cm.height = sz.y * 0.2
			cm.material = w_mat
			bowl.mesh = cm
			bowl.position = Vector3(0, sz.y * 0.45, sz.z * 0.1)
			sb.add_child(bowl)

			var tank = MeshInstance3D.new()
			var tm = BoxMesh.new()
			tm.size = Vector3(sz.x * 0.65, sz.y * 0.45, sz.z * 0.25)
			tm.material = w_mat
			tank.mesh = tm
			tank.position = Vector3(0, sz.y * 0.65, -sz.z * 0.32)
			sb.add_child(tank)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_bathtub", "custom_prop_bathtub":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.92, 0.94, 0.96)
			b_mat.roughness = 0.2

			var tub = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			bm.material = b_mat
			tub.mesh = bm
			tub.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(tub)

			var inner = MeshInstance3D.new()
			var im = BoxMesh.new()
			im.size = Vector3(sz.x * 0.85, sz.y * 0.5, sz.z * 0.85)
			var in_mat = StandardMaterial3D.new()
			in_mat.albedo_color = Color(0.80, 0.86, 0.90)
			im.material = in_mat
			inner.mesh = im
			inner.position = Vector3(0, sz.y * 0.76, 0)
			sb.add_child(inner)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_sink", "custom_prop_sink":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var w_mat = StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.92, 0.94, 0.96)

			var ped = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.10
			pm.bottom_radius = 0.12
			pm.height = sz.y * 0.65
			pm.material = w_mat
			ped.mesh = pm
			ped.position = Vector3(0, sz.y * 0.32, 0)
			sb.add_child(ped)

			var basin = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y * 0.32, sz.z)
			bm.material = w_mat
			basin.mesh = bm
			basin.position = Vector3(0, sz.y * 0.75, 0)
			sb.add_child(basin)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_shower_cabin", "custom_prop_shower_cabin":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var tray = MeshInstance3D.new()
			var tm = BoxMesh.new()
			tm.size = Vector3(sz.x, 0.1, sz.z)
			var tmat = StandardMaterial3D.new()
			tmat.albedo_color = Color(0.9, 0.92, 0.95)
			tm.material = tmat
			tray.mesh = tm
			tray.position = Vector3(0, 0.05, 0)
			sb.add_child(tray)

			var glass_mat = StandardMaterial3D.new()
			glass_mat.albedo_color = Color(0.7, 0.85, 0.95, 0.45)
			glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass_mat.roughness = 0.1

			var glass_l = MeshInstance3D.new()
			var glm = BoxMesh.new()
			glm.size = Vector3(0.04, sz.y * 0.92, sz.z)
			glm.material = glass_mat
			glass_l.mesh = glm
			glass_l.position = Vector3(-sz.x * 0.48, sz.y * 0.5, 0)
			sb.add_child(glass_l)

			var glass_b = MeshInstance3D.new()
			var gbm = BoxMesh.new()
			gbm.size = Vector3(sz.x, sz.y * 0.92, 0.04)
			gbm.material = glass_mat
			glass_b.mesh = gbm
			glass_b.position = Vector3(0, sz.y * 0.5, -sz.z * 0.48)
			sb.add_child(glass_b)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_mirror_broken", "custom_prop_mirror_broken":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.24, 0.16, 0.10)
			var frame = MeshInstance3D.new()
			var fm = BoxMesh.new()
			fm.size = sz
			fm.material = f_mat
			frame.mesh = fm
			frame.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(frame)

			# Поверхность стекла (QuadMesh для 100% покрытия текстурой SubViewport)
			var mirror = MeshInstance3D.new()
			var mm = QuadMesh.new()
			mm.size = Vector2(sz.x * 0.86, sz.y * 0.86)
			var mmat = StandardMaterial3D.new()
			mmat.albedo_color = Color(0.20, 0.25, 0.32, 0.95)
			mmat.metallic = 0.9
			mmat.roughness = 0.1
			mm.material = mmat
			mirror.name = "Glass"
			mirror.mesh = mm
			mirror.position = Vector3(0, sz.y * 0.5, sz.z * 0.5 + 0.005)
			sb.add_child(mirror)

			# Отражение игрока в зеркале (SubViewport на поверхность стекла)
			if not is_ghost:
				var refl_node = Node3D.new()
				refl_node.name = "PlayerReflection"
				refl_node.set_script(load("res://scripts/MirrorReflection.gd"))
				sb.add_child(refl_node)

			# Трещины на зеркале
			var c_mat = StandardMaterial3D.new()
			c_mat.albedo_color = Color(0.06, 0.06, 0.09)
			for i in range(4):
				var crack = MeshInstance3D.new()
				var ckm = BoxMesh.new()
				ckm.size = Vector3(sz.x * 0.55, 0.015, 0.03)
				ckm.material = c_mat
				crack.mesh = ckm
				crack.position = Vector3(0, sz.y * 0.5 + (i - 1.5) * 0.12, sz.z * 0.5 + 0.012)
				crack.rotation_degrees.z = -30.0 + i * 28.0
				sb.add_child(crack)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_window_v0", "prop_window_v1", "prop_window_v2", "prop_window_v3":
			HouseKit.add_window(root, int(type.right(1)))

		"prop_window_boarded", "custom_prop_window_boarded":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.35, 0.28, 0.20)
			var frame = MeshInstance3D.new()
			var fm = BoxMesh.new()
			fm.size = sz
			fm.material = f_mat
			frame.mesh = fm
			frame.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(frame)

			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.45, 0.30, 0.15)
			var angles = [25.0, -20.0, 5.0]
			for i in range(3):
				var board = MeshInstance3D.new()
				var brm = BoxMesh.new()
				brm.size = Vector3(sz.x * 1.05, 0.15, 0.08)
				brm.material = b_mat
				board.mesh = brm
				board.position = Vector3(0, sz.y * (0.3 + i * 0.22), sz.z * 0.52)
				board.rotation_degrees.z = angles[i]
				sb.add_child(board)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_dog", "custom_prop_dog":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var d_mat = StandardMaterial3D.new()
			d_mat.albedo_color = Color(0.60, 0.40, 0.22) if color == Color.WHITE else color
			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x * 0.55, sz.y * 0.45, sz.z * 0.8)
			bm.material = d_mat
			body.mesh = bm
			body.position = Vector3(0, sz.y * 0.45, 0)
			sb.add_child(body)

			var head = MeshInstance3D.new()
			var hm = BoxMesh.new()
			hm.size = Vector3(sz.x * 0.38, sz.y * 0.38, sz.z * 0.42)
			hm.material = d_mat
			head.mesh = hm
			head.position = Vector3(0, sz.y * 0.75, sz.z * 0.38)
			sb.add_child(head)

			var snout = MeshInstance3D.new()
			var snm = BoxMesh.new()
			snm.size = Vector3(sz.x * 0.22, sz.y * 0.18, sz.z * 0.25)
			var sn_mat = StandardMaterial3D.new()
			sn_mat.albedo_color = Color(0.20, 0.15, 0.10)
			snm.material = sn_mat
			snout.mesh = snm
			snout.position = Vector3(0, sz.y * 0.68, sz.z * 0.56)
			sb.add_child(snout)

			for lx in [-1, 1]:
				for lz in [-1, 1]:
					var leg = MeshInstance3D.new()
					var lm = BoxMesh.new()
					lm.size = Vector3(sz.x * 0.14, sz.y * 0.40, sz.z * 0.14)
					lm.material = d_mat
					leg.mesh = lm
					leg.position = Vector3(lx * (sz.x * 0.20), sz.y * 0.20, lz * (sz.z * 0.28))
					sb.add_child(leg)

			var tail = MeshInstance3D.new()
			var tm = BoxMesh.new()
			tm.size = Vector3(0.08, 0.08, sz.z * 0.35)
			tm.material = d_mat
			tail.mesh = tm
			tail.position = Vector3(0, sz.y * 0.60, -sz.z * 0.45)
			tail.rotation_degrees.x = 35.0
			sb.add_child(tail)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_tree", "custom_prop_tree":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var t_mat = StandardMaterial3D.new()
			t_mat.albedo_color = Color(0.35, 0.22, 0.12)
			var trunk = MeshInstance3D.new()
			var tm = CylinderMesh.new()
			tm.top_radius = sz.x * 0.08
			tm.bottom_radius = sz.x * 0.12
			tm.height = sz.y * 0.5
			tm.material = t_mat
			trunk.mesh = tm
			trunk.position = Vector3(0, sz.y * 0.25, 0)
			sb.add_child(trunk)

			var l_mat = StandardMaterial3D.new()
			l_mat.albedo_color = Color(0.18, 0.42, 0.16) if color == Color.WHITE else color
			l_mat.roughness = 0.9
			var foliage = MeshInstance3D.new()
			var fm = SphereMesh.new()
			fm.radius = sz.x * 0.48
			fm.height = sz.y * 0.65
			fm.material = l_mat
			foliage.mesh = fm
			foliage.position = Vector3(0, sz.y * 0.68, 0)
			sb.add_child(foliage)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = sz.x * 0.18
				shape.height = sz.y * 0.6
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.3, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_tree_pine", "custom_prop_tree_pine":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			NatureKit.add_spruce(sb, sz, color)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				# У больших елей стенка чуть шире ствола, под лапами можно ходить
				shape.radius = 0.6 if sz.y > 10.0 else sz.x * 0.18
				shape.height = sz.y * 0.5
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.25, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_tree_dead", "custom_prop_tree_dead":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.14, 0.12, 0.11)
			b_mat.roughness = 0.95

			# Искривленный ствол
			var trunk = MeshInstance3D.new()
			var tm = CylinderMesh.new()
			tm.top_radius = sz.x * 0.06
			tm.bottom_radius = sz.x * 0.14
			tm.height = sz.y * 0.65
			tm.material = b_mat
			trunk.mesh = tm
			trunk.position = Vector3(0, sz.y * 0.32, 0)
			trunk.rotation_degrees.z = 4.0
			sb.add_child(trunk)

			# Голые извилистые сучья
			var branch_angles = [
				Vector3(35, 20, 45), Vector3(-40, 110, -35),
				Vector3(25, -70, 50), Vector3(-30, -140, -40),
				Vector3(45, 170, 20), Vector3(15, -10, -55)
			]
			for i in range(branch_angles.size()):
				var rot_v = branch_angles[i]
				var br = MeshInstance3D.new()
				var bm = CylinderMesh.new()
				bm.top_radius = sz.x * 0.015
				bm.bottom_radius = sz.x * 0.045
				bm.height = sz.y * 0.38
				bm.material = b_mat
				br.mesh = bm
				br.position = Vector3(0, sz.y * (0.45 + i * 0.08), 0)
				br.rotation_degrees = rot_v
				sb.add_child(br)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = sz.x * 0.2
				shape.height = sz.y * 0.7
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.35, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_tree_carved", "custom_prop_tree_carved", \
		"prop_tree_warning", "custom_prop_tree_warning", \
		"prop_tree_claws", "custom_prop_tree_claws":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.18, 0.13, 0.10)
			b_mat.roughness = 0.95

			# Основной массивный ствол
			var trunk = MeshInstance3D.new()
			var tm = CylinderMesh.new()
			tm.top_radius = sz.x * 0.09
			tm.bottom_radius = sz.x * 0.16
			tm.height = sz.y * 0.65
			tm.material = b_mat
			trunk.mesh = tm
			trunk.position = Vector3(0, sz.y * 0.32, 0)
			sb.add_child(trunk)

			# Выпирающие узловатые корни в основании
			var root_mat = StandardMaterial3D.new()
			root_mat.albedo_color = Color(0.15, 0.10, 0.08)
			for ri in range(4):
				var r_node = MeshInstance3D.new()
				var rm = CylinderMesh.new()
				rm.top_radius = sz.x * 0.03
				rm.bottom_radius = sz.x * 0.06
				rm.height = sz.y * 0.18
				rm.material = root_mat
				r_node.mesh = rm
				var ang = ri * (TAU / 4.0) + 0.3
				r_node.position = Vector3(cos(ang) * sz.x * 0.14, sz.y * 0.05, sin(ang) * sz.x * 0.14)
				r_node.rotation_degrees = Vector3(35 * sin(ang), rad_to_deg(ang), 35 * cos(ang))
				sb.add_child(r_node)

			# Крона и ветви (мрачные изломанные сучья)
			var branch_angles = [
				Vector3(30, 25, 40), Vector3(-35, 115, -30),
				Vector3(20, -75, 45), Vector3(-25, -145, -35),
				Vector3(40, 160, 20)
			]
			for i in range(branch_angles.size()):
				var rot_v = branch_angles[i]
				var br = MeshInstance3D.new()
				var bm = CylinderMesh.new()
				bm.top_radius = sz.x * 0.015
				bm.bottom_radius = sz.x * 0.04
				bm.height = sz.y * 0.35
				bm.material = b_mat
				br.mesh = bm
				br.position = Vector3(0, sz.y * (0.42 + i * 0.07), 0)
				br.rotation_degrees = rot_v
				sb.add_child(br)

			# Ритуальная обмотка бечёвкой вокруг ствола
			var rope_mat = StandardMaterial3D.new()
			rope_mat.albedo_color = Color(0.40, 0.32, 0.22)
			for r_offset in [-0.18, 0.18]:
				var rope = MeshInstance3D.new()
				var rpm = TorusMesh.new()
				rpm.inner_radius = sz.x * 0.11
				rpm.outer_radius = sz.x * 0.125
				rpm.material = rope_mat
				rope.mesh = rpm
				rope.position = Vector3(0, sz.y * 0.28 + r_offset * sz.y * 0.5, 0)
				sb.add_child(rope)

			# Срез коры с рисунком (Carving)
			var drawing_type = "skinwalker"
			if type.contains("warning"):
				drawing_type = "warning"
			elif type.contains("claws"):
				drawing_type = "claws"

			var carving_node = MeshInstance3D.new()
			carving_node.name = "Carving"
			var cm = BoxMesh.new()
			var c_w = sz.x * 0.26
			var c_h = sz.y * 0.18
			cm.size = Vector3(c_w, c_h, 0.03)
			var draw_mat = TextureHelper.create_tree_drawing_material(drawing_type)
			cm.material = draw_mat
			carving_node.mesh = cm
			var trunk_r = sz.x * 0.13
			carving_node.position = Vector3(0, sz.y * 0.28, trunk_r + 0.01)
			sb.add_child(carving_node)
			sb.set_meta("tree_drawing", drawing_type)

			# Зловещий слабый отблеск на рисунке
			var glow_light = OmniLight3D.new()
			glow_light.name = "RitualGlow"
			glow_light.light_color = Color(0.85, 0.15, 0.10)
			glow_light.light_energy = 0.6
			glow_light.omni_range = 1.6
			glow_light.position = Vector3(0, sz.y * 0.28, trunk_r + 0.15)
			sb.add_child(glow_light)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = sz.x * 0.20
				shape.height = sz.y * 0.70
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.35, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_power_pole", "custom_prop_power_pole":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.24, 0.18, 0.12)

			# Вертикальный столб
			var pole = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.10
			pm.bottom_radius = 0.14
			pm.height = sz.y
			pm.material = p_mat
			pole.mesh = pm
			pole.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(pole)

			# Поперечная перекладина для изоляторов
			var beam = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x * 0.8, 0.12, 0.12)
			bm.material = p_mat
			beam.mesh = bm
			beam.position = Vector3(0, sz.y * 0.88, 0)
			sb.add_child(beam)

			# Керамические изоляторы
			var i_mat = StandardMaterial3D.new()
			i_mat.albedo_color = Color(0.85, 0.88, 0.85)
			for ix in [-sz.x * 0.32, 0.0, sz.x * 0.32]:
				var ins = MeshInstance3D.new()
				var im = CylinderMesh.new()
				im.top_radius = 0.03
				im.bottom_radius = 0.04
				im.height = 0.14
				im.material = i_mat
				ins.mesh = im
				ins.position = Vector3(ix, sz.y * 0.88 + 0.12, 0)
				sb.add_child(ins)

			# Провисшие черные электропровода
			var w_mat = StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.05, 0.05, 0.05)
			for wx in [-sz.x * 0.3, sz.x * 0.3]:
				var wire = MeshInstance3D.new()
				var wm = BoxMesh.new()
				wm.size = Vector3(0.02, 0.02, sz.z * 1.5)
				wm.material = w_mat
				wire.mesh = wm
				wire.position = Vector3(wx, sz.y * 0.85, 0)
				wire.rotation_degrees.x = 4.0
				sb.add_child(wire)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = 0.20
				shape.height = sz.y
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_road_barrier", "custom_prop_road_barrier":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			# Бетонные блоки ножек
			var c_mat = StandardMaterial3D.new()
			c_mat.albedo_color = Color(0.45, 0.45, 0.48)
			for bx in [-sz.x * 0.4, sz.x * 0.4]:
				var foot = MeshInstance3D.new()
				var fm = BoxMesh.new()
				fm.size = Vector3(0.25, 0.45, 0.6)
				fm.material = c_mat
				foot.mesh = fm
				foot.position = Vector3(bx, 0.22, 0)
				sb.add_child(foot)

			# Полосатая перекладина со знаком опасности
			var bar = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x, 0.28, 0.08)
			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.95, 0.82, 0.15) # Желтый
			bm.material = b_mat
			bar.mesh = bm
			bar.position = Vector3(0, 0.68, 0)
			sb.add_child(bar)

			# Черные полосы предупреждения
			var s_mat = StandardMaterial3D.new()
			s_mat.albedo_color = Color(0.1, 0.1, 0.12)
			for i in range(5):
				var stripe = MeshInstance3D.new()
				var sm = BoxMesh.new()
				sm.size = Vector3(0.08, 0.28, 0.085)
				sm.material = s_mat
				stripe.mesh = sm
				stripe.position = Vector3((i - 2) * (sz.x * 0.2), 0.68, 0)
				stripe.rotation_degrees.z = 25.0
				sb.add_child(stripe)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_ethan_car":
			# Машина Итана после удара о валун — тот же красный хэтчбек, что во вступлении.
			# Строится в настоящем размере: масштаб из карты сюда не передаётся
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			var ethan_car := EthanCar.new()
			ethan_car.set_wrecked(true)
			ethan_car.set_lights(true)
			sb.add_child(ethan_car)
			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = Vector3(EthanCar.SIZE.x, 1.3, EthanCar.SIZE.z - 0.3)
				col.shape = shape
				col.position = Vector3(0, 0.65, 0.15)
				sb.add_child(col)
			root.add_child(sb)

		"prop_car_wreck", "custom_prop_car_wreck":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			NatureKit.add_car_wreck(sb, sz)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_bush_dead", "custom_prop_bush_dead":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.20, 0.16, 0.12)
			b_mat.roughness = 0.95

			# Сухие переплетенные сучья
			for i in range(5):
				var twig = MeshInstance3D.new()
				var tm = PrismMesh.new()
				tm.size = Vector3(sz.x * (0.6 + i * 0.08), sz.y * (0.7 + i * 0.06), sz.z * 0.5)
				tm.material = b_mat
				twig.mesh = tm
				twig.position = Vector3((i - 2) * 0.08, sz.y * 0.4, 0)
				twig.rotation_degrees.y = i * 42.0
				twig.rotation_degrees.z = (i - 2) * 12.0
				sb.add_child(twig)

			# Сквозь куст можно пройти, поэтому коллизии нет

			root.add_child(sb)

		"prop_leaves_pile", "custom_prop_leaves_pile":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			# ── Куча опавшей листвы на земле ──────────────────────────
			var leaf_colors = [
				Color(0.58, 0.28, 0.12), # тёмно-оранжевая
				Color(0.68, 0.42, 0.14), # золотисто-охристая
				Color(0.38, 0.18, 0.10), # бурая прелая
				Color(0.48, 0.34, 0.16)  # оливково-жёлтая
			]

			for i in range(7):
				var patch = MeshInstance3D.new()
				var pm = CylinderMesh.new()
				var rad_x = sz.x * (0.35 + (i % 3) * 0.12)
				var rad_z = sz.z * (0.32 + ((i + 1) % 3) * 0.12)
				pm.top_radius = rad_x * 0.5
				pm.bottom_radius = rad_x * 0.55
				pm.height = 0.025 + i * 0.012
				var lmat = StandardMaterial3D.new()
				lmat.albedo_color = leaf_colors[i % leaf_colors.size()]
				lmat.roughness = 0.95
				pm.material = lmat
				patch.mesh = pm
				var angle = i * 52.0
				var dist = (i % 4) * 0.22
				patch.position = Vector3(cos(deg_to_rad(angle)) * dist, pm.height * 0.5, sin(deg_to_rad(angle)) * dist)
				patch.rotation_degrees.y = i * 38.0
				patch.rotation_degrees.z = (i % 3 - 1) * 3.0
				sb.add_child(patch)

			root.add_child(sb)

		"prop_bush_foliage", "custom_prop_bush_foliage":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			NatureKit.add_bush(sb, sz)

			# Сквозь куст можно пройти, поэтому коллизии нет

			root.add_child(sb)

		"prop_tree_deciduous", "custom_prop_tree_deciduous":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			# ── Лиственное дерево с пышной кроной ──────────────────────
			var trunk_mat = StandardMaterial3D.new()
			trunk_mat.albedo_color = Color(0.24, 0.18, 0.13)
			trunk_mat.roughness = 0.95

			var trunk = MeshInstance3D.new()
			var tm = CylinderMesh.new()
			tm.top_radius = 0.22
			tm.bottom_radius = 0.36
			tm.height = sz.y * 0.65
			tm.material = trunk_mat
			trunk.mesh = tm
			trunk.position = Vector3(0, sz.y * 0.325, 0)
			sb.add_child(trunk)

			# Крона из многоярусной листвы
			var canopy_colors = [
				Color(0.18, 0.32, 0.15),
				Color(0.22, 0.38, 0.18),
				Color(0.15, 0.27, 0.12),
				Color(0.20, 0.35, 0.16)
			]
			for i in range(8):
				var clump = MeshInstance3D.new()
				var cm = SphereMesh.new()
				var cr = sz.x * (0.28 + (i % 3) * 0.08)
				cm.radius = cr
				cm.height = cr * 1.8
				var cmat = StandardMaterial3D.new()
				cmat.albedo_color = canopy_colors[i % canopy_colors.size()]
				cmat.roughness = 0.85
				cm.material = cmat
				clump.mesh = cm
				var a = i * 45.0
				var r = sz.x * (0.22 + (i % 2) * 0.12)
				var y_pos = sz.y * (0.55 + (i / 8.0) * 0.32)
				clump.position = Vector3(cos(deg_to_rad(a)) * r, y_pos, sin(deg_to_rad(a)) * r)
				sb.add_child(clump)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = CylinderShape3D.new()
				cshape.radius = 0.35
				cshape.height = sz.y * 0.65
				col.shape = cshape
				col.position = Vector3(0, sz.y * 0.325, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_ivy_wall", "custom_prop_ivy_wall":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			# ── Настенный плющ / свисающая со стены листва ─────────────
			var ivy_colors = [
				Color(0.16, 0.32, 0.15),
				Color(0.20, 0.38, 0.18),
				Color(0.13, 0.26, 0.12)
			]
			for i in range(6):
				var leaf_panel = MeshInstance3D.new()
				var qm = QuadMesh.new()
				var pw = sz.x * (0.45 + (i % 3) * 0.18)
				var ph = sz.y * (0.35 + (i % 2) * 0.22)
				qm.size = Vector2(pw, ph)
				var imat = StandardMaterial3D.new()
				imat.albedo_color = ivy_colors[i % ivy_colors.size()]
				imat.roughness = 0.9
				imat.cull_mode = BaseMaterial3D.CULL_DISABLED
				qm.material = imat
				leaf_panel.mesh = qm
				var x_offset = (i - 2.5) * 0.28
				var y_offset = sz.y * (0.75 - i * 0.10)
				leaf_panel.position = Vector3(x_offset, y_offset, 0.02 + i * 0.01)
				leaf_panel.rotation_degrees.z = (i - 2) * 6.0
				sb.add_child(leaf_panel)

			root.add_child(sb)

		"prop_bench", "custom_prop_bench":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var w_mat = StandardMaterial3D.new()
			w_mat.albedo_color = Color(0.48, 0.30, 0.16)
			var seat = MeshInstance3D.new()
			var sm = BoxMesh.new()
			sm.size = Vector3(sz.x, 0.08, sz.z * 0.7)
			sm.material = w_mat
			seat.mesh = sm
			seat.position = Vector3(0, sz.y * 0.50, 0)
			sb.add_child(seat)

			var back = MeshInstance3D.new()
			var bkm = BoxMesh.new()
			bkm.size = Vector3(sz.x, sz.y * 0.45, 0.06)
			bkm.material = w_mat
			back.mesh = bkm
			back.position = Vector3(0, sz.y * 0.78, -sz.z * 0.32)
			sb.add_child(back)

			var m_mat = StandardMaterial3D.new()
			m_mat.albedo_color = Color(0.20, 0.22, 0.25)
			m_mat.metallic = 0.8
			for lx in [-1, 1]:
				var leg = MeshInstance3D.new()
				var lm = BoxMesh.new()
				lm.size = Vector3(0.08, sz.y * 0.50, sz.z * 0.65)
				lm.material = m_mat
				leg.mesh = lm
				leg.position = Vector3(lx * (sz.x * 0.44), sz.y * 0.25, 0)
				sb.add_child(leg)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_streetlight", "custom_prop_streetlight":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			NatureKit.add_streetlight(sb, sz.y)

			if not is_ghost:
				var light = OmniLight3D.new()
				light.light_color = Color(1.0, 0.92, 0.75)
				light.light_energy = 2.5
				light.omni_range = 14.0
				light.position = Vector3(0, sz.y + 0.1, 0.98)
				light.distance_fade_enabled = true
				light.distance_fade_begin = 55.0
				light.distance_fade_length = 12.0
				sb.add_child(light)

				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = 0.16
				shape.height = sz.y
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_fence_section", "custom_prop_fence_section":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.50, 0.35, 0.20) if color == Color.WHITE else color

			# Перекладины
			for py in [0.35, 0.80]:
				var rail = MeshInstance3D.new()
				var rm = BoxMesh.new()
				rm.size = Vector3(sz.x, 0.08, 0.05)
				rm.material = f_mat
				rail.mesh = rm
				rail.position = Vector3(0, sz.y * py, 0)
				sb.add_child(rail)

			# Штакетины (5 штук)
			var p_step = sz.x / 5.0
			for i in range(5):
				var picket = MeshInstance3D.new()
				var pkm = BoxMesh.new()
				pkm.size = Vector3(0.12, sz.y * 0.95, 0.04)
				pkm.material = f_mat
				picket.mesh = pkm
				picket.position = Vector3(-sz.x * 0.4 + i * p_step, sz.y * 0.48, 0.03)
				sb.add_child(picket)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_trash_bin", "custom_prop_trash_bin":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var t_mat = StandardMaterial3D.new()
			t_mat.albedo_color = Color(0.16, 0.18, 0.16)
			t_mat.roughness = 0.6
			var can = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = sz.x * 0.45
			cm.bottom_radius = sz.x * 0.38
			cm.height = sz.y
			cm.material = t_mat
			can.mesh = cm
			can.position = Vector3(0, sz.y * 0.5, 0)
			sb.add_child(can)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = sz.x * 0.45
				shape.height = sz.y
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_hydrant", "custom_prop_hydrant":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var r_mat = StandardMaterial3D.new()
			r_mat.albedo_color = Color(0.85, 0.15, 0.15)
			var body = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = sz.x * 0.35
			cm.bottom_radius = sz.x * 0.42
			cm.height = sz.y * 0.8
			cm.material = r_mat
			body.mesh = cm
			body.position = Vector3(0, sz.y * 0.4, 0)
			sb.add_child(body)

			var cap = MeshInstance3D.new()
			var cpm = CylinderMesh.new()
			cpm.top_radius = sz.x * 0.2
			cpm.bottom_radius = sz.x * 0.38
			cpm.height = sz.y * 0.22
			cpm.material = r_mat
			cap.mesh = cpm
			cap.position = Vector3(0, sz.y * 0.88, 0)
			sb.add_child(cap)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = CylinderShape3D.new()
				shape.radius = sz.x * 0.42
				shape.height = sz.y
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"prop_mailbox", "custom_prop_mailbox":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var post = MeshInstance3D.new()
			var pm = CylinderMesh.new()
			pm.top_radius = 0.06
			pm.bottom_radius = 0.08
			pm.height = sz.y * 0.65
			var pmat = StandardMaterial3D.new()
			pmat.albedo_color = Color(0.40, 0.28, 0.16)
			pm.material = pmat
			post.mesh = pm
			post.position = Vector3(0, sz.y * 0.32, 0)
			sb.add_child(post)

			var box = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(sz.x, sz.y * 0.38, sz.z)
			var bmat = StandardMaterial3D.new()
			bmat.albedo_color = Color(0.20, 0.38, 0.65)
			bm.material = bmat
			box.mesh = bm
			box.position = Vector3(0, sz.y * 0.80, 0)
			sb.add_child(box)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				col.position = Vector3(0, sz.y * 0.5, 0)
				sb.add_child(col)

			root.add_child(sb)

		"light_ceiling", "custom_light_ceiling":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0

			var cord = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.015
			cm.bottom_radius = 0.015
			cm.height = sz.y * 0.6
			var m_mat = StandardMaterial3D.new()
			m_mat.albedo_color = Color(0.1, 0.1, 0.1)
			cm.material = m_mat
			cord.mesh = cm
			cord.position = Vector3(0, sz.y * 0.7, 0)
			sb.add_child(cord)

			var shade = MeshInstance3D.new()
			var sm = CylinderMesh.new()
			sm.top_radius = 0.08
			sm.bottom_radius = 0.28
			sm.height = 0.2
			var sh_mat = StandardMaterial3D.new()
			sh_mat.albedo_color = Color(0.25, 0.3, 0.35)
			sm.material = sh_mat
			shade.mesh = sm
			shade.position = Vector3(0, sz.y * 0.38, 0)
			sb.add_child(shade)

			var bulb = MeshInstance3D.new()
			var bm = SphereMesh.new()
			bm.radius = 0.08
			bm.height = 0.16
			var bmat = StandardMaterial3D.new()
			bmat.albedo_color = Color(1.0, 0.9, 0.6)
			bmat.emission_enabled = true
			bmat.emission = Color(1.0, 0.9, 0.6)
			bmat.emission_energy_multiplier = 1.5
			bm.material = bmat
			bulb.mesh = bm
			bulb.position = Vector3(0, sz.y * 0.28, 0)
			sb.add_child(bulb)

			if not is_ghost:
				var light = OmniLight3D.new()
				light.light_color = Color(1.0, 0.9, 0.65)
				light.light_energy = 1.6
				light.omni_range = 9.0
				light.position = Vector3(0, sz.y * 0.25, 0)
				sb.add_child(light)

		"door", "door_exit", "custom_door", "custom_door_exit":
			var is_exit_type = (type == "door_exit" or type == "custom_door_exit")
			var d_root = Node3D.new()
			d_root.set_meta("item_type", "door")
			d_root.set_meta("door_type", "exit" if is_exit_type else "simple")
			d_root.set_meta("is_exit", is_exit_type)

			# Глубокий темный косяк (черненый дуб/чугун) — гарантирует 100% контраст с любыми стенами
			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.12, 0.08, 0.06)
			f_mat.roughness = 0.92
			f_mat.metallic = 0.08
			f_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

			var frame_th = 0.075
			var eff_w: float = sz.x if sz.x > 0.3 else 1.02
			var eff_h: float = sz.y if sz.y > 0.5 else 2.12
			var eff_th: float = sz.z if sz.z > 0.04 else 0.14

			var fl = MeshInstance3D.new()
			fl.name = "fl"
			var fl_m = BoxMesh.new()
			fl_m.size = Vector3(frame_th, eff_h, eff_th * 1.15)
			fl_m.material = f_mat
			fl.mesh = fl_m
			fl.position = Vector3(-eff_w * 0.5 + frame_th * 0.5, eff_h * 0.5, 0)
			fl.extra_cull_margin = 16.0
			d_root.add_child(fl)

			var fr = MeshInstance3D.new()
			fr.name = "fr"
			fr.mesh = fl_m
			fr.position = Vector3(eff_w * 0.5 - frame_th * 0.5, eff_h * 0.5, 0)
			fr.extra_cull_margin = 16.0
			d_root.add_child(fr)

			var ft = MeshInstance3D.new()
			ft.name = "ft"
			var ft_m = BoxMesh.new()
			ft_m.size = Vector3(eff_w, frame_th, eff_th * 1.15)
			ft_m.material = f_mat
			ft.mesh = ft_m
			ft.position = Vector3(0, eff_h - frame_th * 0.5, 0)
			ft.extra_cull_margin = 16.0
			d_root.add_child(ft)

			var hinge = Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(-eff_w * 0.5 + frame_th, 0, 0)
			d_root.add_child(hinge)

			var panel = StaticBody3D.new()
			panel.name = "Panel"
			panel.collision_layer = 1
			panel.collision_mask = 0
			panel.set_meta("item_type", "door")
			panel.set_meta("door_type", "exit" if is_exit_type else "simple")
			panel.set_meta("is_exit", is_exit_type)

			var p_w = max(0.4, eff_w - (frame_th * 2.0))
			var p_h = max(0.5, eff_h - frame_th)
			var p_th = 0.048

			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.32, 0.18, 0.10)
			p_mat.roughness = 0.9

			var pm = build_realistic_door_leaf(panel, p_w, p_h, p_th, p_mat)

			# Доски поверх двери (Boards) — скрыты по умолчанию, отображаются ТОЛЬКО если requires_boards == true
			var boards = Node3D.new()
			boards.name = "Boards"
			boards.position = Vector3(p_w * 0.5, 0, -p_th * 0.5 - 0.035)
			boards.visible = false

			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.38, 0.24, 0.13)
			b_mat.roughness = 0.88

			var nail_mat = StandardMaterial3D.new()
			nail_mat.albedo_color = Color(0.18, 0.18, 0.20)
			nail_mat.metallic = 0.92
			nail_mat.roughness = 0.35

			var heights = [0.45, 1.05, 1.65]
			var tilts = [-4.0, 3.5, -2.5]
			for i in range(3):
				var bm = MeshInstance3D.new()
				var bmsh = BoxMesh.new()
				bmsh.size = Vector3(p_w + 0.16, 0.15, 0.045)
				bmsh.material = b_mat
				bm.mesh = bmsh
				bm.position = Vector3(0, heights[i], 0)
				bm.rotation_degrees.z = tilts[i]
				boards.add_child(bm)

				for nx in [-p_w * 0.44, p_w * 0.44]:
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

			d_root.add_child(boards)
			TextureHelper.apply_door_texture_to_node(d_root, "door_dark_oak")

			# Энергосчетчик — скрыт по умолчанию, появляется ТОЛЬКО если requires_power == true
			var meter = Node3D.new()
			meter.name = "ElectricMeter"
			meter.position = Vector3(eff_w * 0.5 + 0.14, 1.15, 0)
			meter.visible = false

			var m_body = MeshInstance3D.new()
			var m_bm = BoxMesh.new()
			m_bm.size = Vector3(0.24, 0.36, 0.20)
			var m_mat = StandardMaterial3D.new()
			m_mat.albedo_color = Color(0.22, 0.24, 0.28)
			m_mat.metallic = 0.7
			m_mat.roughness = 0.4
			m_bm.material = m_mat
			m_body.mesh = m_bm
			meter.add_child(m_body)

			# Стекло циферблата
			var m_glass = MeshInstance3D.new()
			var g_mesh = CylinderMesh.new()
			g_mesh.top_radius = 0.08
			g_mesh.bottom_radius = 0.08
			g_mesh.height = 0.04
			var g_mat = StandardMaterial3D.new()
			g_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.6)
			g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g_mat.roughness = 0.1
			g_mesh.material = g_mat
			m_glass.mesh = g_mesh
			m_glass.rotation_degrees = Vector3(90, 0, 0)
			m_glass.position = Vector3(0, 0.05, 0.10)
			meter.add_child(m_glass)

			# Светодиодный индикатор питания (MeterLED)
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
			led_mesh.material = led_mat
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

			d_root.add_child(meter)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(p_w, p_h, p_th)
				col.shape = cshape
				col.position = Vector3(p_w * 0.5, p_h * 0.5, 0)
				col.name = "Col"
				panel.add_child(col)
				panel.set_script(load("res://scripts/Door.gd"))
				d_root.set_script(load("res://scripts/Door.gd"))
				d_root.set("boards_node", boards)
				d_root.set("has_electric_meter", false)
				d_root.set("required_key_color", "none")
				d_root.set("requires_boards", false)
				panel.set("boards_node", boards)
				panel.set("has_electric_meter", false)
				panel.set("required_key_color", "none")
				panel.set("requires_boards", false)

			hinge.add_child(panel)
			root.add_child(d_root)

		"door_simple", "custom_door_simple":
			var d_root = Node3D.new()
			d_root.set_meta("item_type", "door_simple")
			d_root.set_meta("door_type", "simple")
			d_root.set_meta("keep_door_look", true)
			root.set_meta("keep_door_look", true)

			var frame_th = 0.05
			var eff_w: float = sz.x if sz.x > 0.3 else 1.02
			var eff_h: float = sz.y if sz.y > 0.5 else 2.12
			var eff_th: float = sz.z if sz.z > 0.04 else 0.14

			var frame_mi = MeshInstance3D.new()
			frame_mi.name = "DoorFrame"
			frame_mi.mesh = HouseKit.door_frame_mesh(eff_w, eff_h, maxf(eff_th, 0.16))
			d_root.add_child(frame_mi)

			var hinge = Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(-eff_w * 0.5 + frame_th, 0, 0)
			d_root.add_child(hinge)

			var panel = StaticBody3D.new()
			panel.name = "Panel"
			panel.collision_layer = 1
			panel.collision_mask = 0
			panel.set_meta("item_type", "door_simple")
			panel.set_meta("door_type", "simple")
			panel.set_meta("keep_door_look", true)

			var p_w = max(0.4, eff_w - (frame_th * 2.0) - 0.006)
			var p_h = max(0.5, eff_h - frame_th - 0.012)
			var p_th = 0.05

			var pm = MeshInstance3D.new()
			pm.name = "HouseDoorLeaf"
			pm.mesh = HouseKit.door_leaf_mesh(p_w, p_h)
			pm.position = Vector3(0, 0.012, 0)
			pm.extra_cull_margin = 2.0
			panel.add_child(pm)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(p_w, p_h, p_th)
				col.shape = cshape
				col.position = Vector3(p_w * 0.5, p_h * 0.5, 0)
				col.name = "Col"
				panel.add_child(col)
				panel.set_script(load("res://scripts/Door.gd"))
				d_root.set_script(load("res://scripts/Door.gd"))
				panel.set("requires_boards", false)
				d_root.set("requires_boards", false)
				panel.set("required_key_color", "")
				d_root.set("required_key_color", "")
				panel.set("requires_power", false)
				d_root.set("requires_power", false)
				panel.set("has_electric_meter", false)
				d_root.set("has_electric_meter", false)

			hinge.add_child(panel)
			root.add_child(d_root)

		"door_electric", "custom_door_electric", "prop_electric_door", "custom_prop_electric_door":
			var d_root = Node3D.new()
			d_root.set_meta("item_type", "door_electric")
			d_root.set_meta("door_type", "electric")

			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.20, 0.22, 0.26)
			f_mat.metallic = 0.8
			f_mat.roughness = 0.4
			f_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

			var frame_th = 0.075
			var eff_w: float = sz.x if sz.x > 0.3 else 1.02
			var eff_h: float = sz.y if sz.y > 0.5 else 2.12
			var eff_th: float = sz.z if sz.z > 0.04 else 0.14

			var fl = MeshInstance3D.new()
			var fl_m = BoxMesh.new()
			fl_m.size = Vector3(frame_th, eff_h, eff_th * 1.15)
			fl_m.material = f_mat
			fl.mesh = fl_m
			fl.position = Vector3(-eff_w * 0.5 + frame_th * 0.5, eff_h * 0.5, 0)
			fl.extra_cull_margin = 16.0
			d_root.add_child(fl)

			var fr = MeshInstance3D.new()
			fr.mesh = fl_m
			fr.position = Vector3(eff_w * 0.5 - frame_th * 0.5, eff_h * 0.5, 0)
			fr.extra_cull_margin = 16.0
			d_root.add_child(fr)

			var ft = MeshInstance3D.new()
			var ft_m = BoxMesh.new()
			ft_m.size = Vector3(eff_w, frame_th, eff_th * 1.15)
			ft_m.material = f_mat
			ft.mesh = ft_m
			ft.position = Vector3(0, eff_h - frame_th * 0.5, 0)
			ft.extra_cull_margin = 16.0
			d_root.add_child(ft)

			var warn_bar = MeshInstance3D.new()
			var wbm = BoxMesh.new()
			wbm.size = Vector3(eff_w * 0.75, 0.07, eff_th * 1.2)
			var wmat = StandardMaterial3D.new()
			wmat.albedo_color = Color(0.95, 0.8, 0.1)
			wmat.emission_enabled = true
			wmat.emission = Color(0.8, 0.6, 0.05)
			wmat.emission_energy_multiplier = 0.6
			wmat.cull_mode = BaseMaterial3D.CULL_DISABLED
			wbm.material = wmat
			warn_bar.mesh = wbm
			warn_bar.position = Vector3(0, eff_h - frame_th - 0.04, 0)
			warn_bar.extra_cull_margin = 16.0
			d_root.add_child(warn_bar)

			var hinge = Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(-eff_w * 0.5 + frame_th, 0, 0)
			d_root.add_child(hinge)

			var panel = StaticBody3D.new()
			panel.name = "Panel"
			panel.collision_layer = 1
			panel.collision_mask = 0
			panel.set_meta("item_type", "door_electric")
			panel.set_meta("door_type", "electric")

			var p_w = max(0.4, eff_w - (frame_th * 2.0))
			var p_h = max(0.5, eff_h - frame_th)
			var p_th = 0.052

			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.16, 0.18, 0.22)
			p_mat.metallic = 0.75
			p_mat.roughness = 0.45
			p_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

			var pm = MeshInstance3D.new()
			pm.name = "DoorLeaf"
			var p_mesh = BoxMesh.new()
			p_mesh.size = Vector3(p_w, p_h, p_th)
			p_mesh.material = p_mat
			pm.mesh = p_mesh
			pm.position = Vector3(p_w * 0.5, p_h * 0.5, 0)
			pm.extra_cull_margin = 16.0
			pm.ignore_occlusion_culling = true
			panel.add_child(pm)

			for ry in [p_h * 0.28, p_h * 0.72]:
				var rib = MeshInstance3D.new()
				var rm = BoxMesh.new()
				rm.size = Vector3(p_w * 0.88, 0.06, p_th + 0.03)
				var rib_mat = StandardMaterial3D.new()
				rib_mat.albedo_color = Color(0.12, 0.13, 0.15)
				rib_mat.metallic = 0.8
				rm.material = rib_mat
				rib.mesh = rm
				rib.position = Vector3(p_w * 0.5, ry, 0)
				panel.add_child(rib)

			var knob_mat = StandardMaterial3D.new()
			knob_mat.albedo_color = Color(0.85, 0.72, 0.22)
			knob_mat.metallic = 0.8
			knob_mat.roughness = 0.3
			var knob = MeshInstance3D.new()
			var km = BoxMesh.new()
			km.size = Vector3(0.06, 0.12, p_th + 0.06)
			km.material = knob_mat
			knob.mesh = km
			knob.position = Vector3(p_w - 0.09, 0.98, 0)
			panel.add_child(knob)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(p_w, p_h, p_th)
				col.shape = cshape
				col.position = Vector3(p_w * 0.5, p_h * 0.5, 0)
				col.name = "Col"
				panel.add_child(col)
				panel.set_script(load("res://scripts/Door.gd"))
				d_root.set_script(load("res://scripts/Door.gd"))

				var maglock = Node3D.new()
				maglock.name = "ElectricMaglock"
				maglock.add_to_group("electric_maglocks")
				maglock.set_script(load("res://scripts/ElectricMaglock.gd"))
				maglock.position = Vector3(p_w - 0.12, p_h - 0.10, 0.05)
				panel.add_child(maglock)

			hinge.add_child(panel)
			TextureHelper.apply_door_texture_to_node(d_root, "door_metal_reinforced")
			root.add_child(d_root)

		"door_metal", "custom_door_metal":
			var d_root = Node3D.new()
			d_root.set_meta("item_type", "door_metal")
			d_root.set_meta("door_type", "metal")

			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.18, 0.20, 0.24)
			f_mat.metallic = 0.85
			f_mat.roughness = 0.35

			var frame_th = 0.075
			var eff_w: float = sz.x if sz.x > 0.3 else 1.02
			var eff_h: float = sz.y if sz.y > 0.5 else 2.12
			var eff_th: float = sz.z if sz.z > 0.04 else 0.14

			var fl = MeshInstance3D.new()
			var fl_m = BoxMesh.new()
			fl_m.size = Vector3(frame_th, eff_h, eff_th * 1.15)
			fl_m.material = f_mat
			fl.mesh = fl_m
			fl.position = Vector3(-eff_w * 0.5 + frame_th * 0.5, eff_h * 0.5, 0)
			d_root.add_child(fl)

			var fr = MeshInstance3D.new()
			fr.mesh = fl_m
			fr.position = Vector3(eff_w * 0.5 - frame_th * 0.5, eff_h * 0.5, 0)
			d_root.add_child(fr)

			var ft = MeshInstance3D.new()
			var ft_m = BoxMesh.new()
			ft_m.size = Vector3(eff_w, frame_th, eff_th * 1.15)
			ft_m.material = f_mat
			ft.mesh = ft_m
			ft.position = Vector3(0, eff_h - frame_th * 0.5, 0)
			d_root.add_child(ft)

			var hinge = Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(-eff_w * 0.5 + frame_th, 0, 0)
			d_root.add_child(hinge)

			var panel = StaticBody3D.new()
			panel.name = "Panel"
			panel.collision_layer = 1
			panel.collision_mask = 0
			panel.set_meta("item_type", "door_metal")
			panel.set_meta("door_type", "metal")

			var p_w = max(0.4, eff_w - (frame_th * 2.0))
			var p_h = max(0.5, eff_h - frame_th)
			var p_th = 0.052

			var p_mat = StandardMaterial3D.new()
			p_mat.albedo_color = Color(0.15, 0.17, 0.20)
			p_mat.metallic = 0.90
			p_mat.roughness = 0.30

			var pm = MeshInstance3D.new()
			pm.name = "DoorLeaf"
			var p_mesh = BoxMesh.new()
			p_mesh.size = Vector3(p_w, p_h, p_th)
			p_mesh.material = p_mat
			pm.mesh = p_mesh
			pm.position = Vector3(p_w * 0.5, p_h * 0.5, 0)
			panel.add_child(pm)

			var dark_steel = StandardMaterial3D.new()
			dark_steel.albedo_color = Color(0.24, 0.26, 0.30)
			dark_steel.metallic = 0.95
			dark_steel.roughness = 0.28

			# Диагональные Х-образные стальные рёбра жёсткости (бункерное усиление)
			for d_sign in [-1.0, 1.0]:
				var diag = MeshInstance3D.new()
				var dm = BoxMesh.new()
				var diag_len = sqrt(pow(p_w * 0.88, 2) + pow(p_h * 0.35, 2))
				dm.size = Vector3(diag_len, 0.05, p_th + 0.015)
				dm.material = dark_steel
				diag.mesh = dm
				diag.position = Vector3(p_w * 0.5, 0.45, 0)
				diag.rotation_degrees = Vector3(0, 0, d_sign * 22.0)
				panel.add_child(diag)

			# Бронированное смотровое окно с решёткой
			var win_frame = MeshInstance3D.new()
			var wfm = BoxMesh.new()
			wfm.size = Vector3(0.22, 0.26, p_th + 0.025)
			wfm.material = dark_steel
			win_frame.mesh = wfm
			win_frame.position = Vector3(p_w * 0.5, 1.50, 0)
			panel.add_child(win_frame)

			# Пуленепробиваемое тёмное стекло
			var glass = MeshInstance3D.new()
			var gm = BoxMesh.new()
			gm.size = Vector3(0.16, 0.20, 0.012)
			var g_mat = StandardMaterial3D.new()
			g_mat.albedo_color = Color(0.1, 0.15, 0.20, 0.45)
			g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g_mat.roughness = 0.08
			gm.material = g_mat
			glass.mesh = gm
			glass.position = Vector3(p_w * 0.5, 1.50, 0)
			panel.add_child(glass)

			for bx in [-0.04, 0.04]:
				var bar = MeshInstance3D.new()
				var barm = CylinderMesh.new()
				barm.top_radius = 0.007
				barm.bottom_radius = 0.007
				barm.height = 0.20
				barm.material = dark_steel
				bar.mesh = barm
				bar.position = Vector3(p_w * 0.5 + bx, 1.50, 0)
				panel.add_child(bar)

			# Тяжёлая промышленная нажимная ручка-рычаг (высота 0.98м)
			var handle_base = MeshInstance3D.new()
			var hbm = BoxMesh.new()
			hbm.size = Vector3(0.065, 0.20, p_th + 0.035)
			var chrome_mat = StandardMaterial3D.new()
			chrome_mat.albedo_color = Color(0.78, 0.80, 0.85)
			chrome_mat.metallic = 0.98
			chrome_mat.roughness = 0.15
			hbm.material = chrome_mat
			handle_base.mesh = hbm
			handle_base.position = Vector3(p_w - 0.09, 0.98, 0)
			panel.add_child(handle_base)

			var lever = MeshInstance3D.new()
			var lm = CylinderMesh.new()
			lm.top_radius = 0.014
			lm.bottom_radius = 0.014
			lm.height = 0.13
			lm.material = chrome_mat
			lever.mesh = lm
			lever.rotation_degrees = Vector3(0, 0, 90)
			lever.position = Vector3(p_w - 0.09 - 0.05, 0.98, p_th * 0.5 + 0.03)
			panel.add_child(lever)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(p_w, p_h, p_th)
				col.shape = cshape
				col.position = Vector3(p_w * 0.5, p_h * 0.5, 0)
				col.name = "Col"
				panel.add_child(col)
				panel.set_script(load("res://scripts/Door.gd"))
				d_root.set_script(load("res://scripts/Door.gd"))
				d_root.set("requires_wire_panel", true)
				panel.set("requires_wire_panel", true)

			hinge.add_child(panel)
			TextureHelper.apply_door_texture_to_node(d_root, "door_metal_reinforced")
			root.add_child(d_root)

		"door_hatch", "custom_door_hatch":
			var d_root = Node3D.new()
			d_root.set_meta("item_type", "door_hatch")
			d_root.set_meta("door_type", "hatch")
			d_root.set_meta("is_hatch", true)

			# Рама люка на полу из кованого стального уголка
			var f_mat = StandardMaterial3D.new()
			f_mat.albedo_color = Color(0.18, 0.19, 0.22)
			f_mat.roughness = 0.45
			f_mat.metallic = 0.88

			var frame_th = 0.12
			var frame_h = max(0.15, sz.y)

			# Стороны стальной рамы
			for side in [-1.0, 1.0]:
				var fl = MeshInstance3D.new()
				var fl_m = BoxMesh.new()
				fl_m.size = Vector3(frame_th, frame_h, sz.z)
				fl_m.material = f_mat
				fl.mesh = fl_m
				fl.position = Vector3(side * (sz.x * 0.5 - frame_th * 0.5), frame_h * 0.5, 0)
				d_root.add_child(fl)

				var ft = MeshInstance3D.new()
				var ft_m = BoxMesh.new()
				ft_m.size = Vector3(sz.x, frame_h, frame_th)
				ft_m.material = f_mat
				ft.mesh = ft_m
				ft.position = Vector3(0, frame_h * 0.5, side * (sz.z * 0.5 - frame_th * 0.5))
				d_root.add_child(ft)

			# 8 анкерных болтов по периметру рамы
			for bx in [-sz.x * 0.42, 0.0, sz.x * 0.42]:
				for bz in [-sz.z * 0.44, sz.z * 0.44]:
					var bolt = MeshInstance3D.new()
					var b_mesh = CylinderMesh.new()
					b_mesh.top_radius = 0.014
					b_mesh.bottom_radius = 0.014
					b_mesh.height = 0.02
					b_mesh.material = f_mat
					bolt.mesh = b_mesh
					bolt.position = Vector3(bx, frame_h + 0.005, bz)
					d_root.add_child(bolt)

			# Петли на задней грани
			var hinge = Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(0, frame_h, -sz.z * 0.5 + frame_th)
			d_root.add_child(hinge)

			var panel = StaticBody3D.new()
			panel.name = "Panel"
			panel.collision_layer = 1
			panel.collision_mask = 0
			panel.set_meta("item_type", "door_hatch")
			panel.set_meta("door_type", "hatch")
			panel.set_meta("is_hatch", true)

			var p_w = max(0.4, sz.x - (frame_th * 2.0))
			var p_l = max(0.4, sz.z - (frame_th * 2.0))
			var p_th = 0.08

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.32, 0.20, 0.12)
			wood_mat.roughness = 0.88

			var iron_mat = StandardMaterial3D.new()
			iron_mat.albedo_color = Color(0.16, 0.17, 0.20)
			iron_mat.metallic = 0.92
			iron_mat.roughness = 0.35

			# 1. Крышка люка из 4 отдельных дубовых досок с зазорами
			var num_planks = 4
			var plank_w = (p_w - 0.04) / float(num_planks)
			for pi in range(num_planks):
				var plank = MeshInstance3D.new()
				var pm_pl = BoxMesh.new()
				pm_pl.size = Vector3(plank_w - 0.012, p_th, p_l - 0.04)
				pm_pl.material = wood_mat
				plank.mesh = pm_pl
				var px = -p_w * 0.5 + 0.02 + (pi + 0.5) * plank_w
				plank.position = Vector3(px, -p_th * 0.5, p_l * 0.5)
				panel.add_child(plank)

			# 2. Две поперечные кованые железные стяжки (Cross braces)
			for pz_pos in [p_l * 0.22, p_l * 0.76]:
				var brace = MeshInstance3D.new()
				var brm = BoxMesh.new()
				brm.size = Vector3(p_w - 0.02, 0.016, 0.09)
				brm.material = iron_mat
				brace.mesh = brm
				brace.position = Vector3(0, 0.008, pz_pos)
				panel.add_child(brace)

				# Кованые заклёпки на каждой стяжке
				for bx in [-p_w * 0.38, -p_w * 0.13, p_w * 0.13, p_w * 0.38]:
					var rvt = MeshInstance3D.new()
					var rm_rvt = CylinderMesh.new()
					rm_rvt.top_radius = 0.012
					rm_rvt.bottom_radius = 0.012
					rm_rvt.height = 0.014
					rm_rvt.material = iron_mat
					rvt.mesh = rm_rvt
					rvt.position = Vector3(bx, 0.016, pz_pos)
					panel.add_child(rvt)

			# 3. Две мощные кованые накладные петли сзади
			for hx in [-p_w * 0.32, p_w * 0.32]:
				var strap = MeshInstance3D.new()
				var sm = BoxMesh.new()
				sm.size = Vector3(0.065, 0.018, 0.26)
				sm.material = iron_mat
				strap.mesh = sm
				strap.position = Vector3(hx, 0.009, 0.13)
				panel.add_child(strap)

			# 4. Утопленная чаша и стальное кольцо-ручка
			var cup = MeshInstance3D.new()
			var cup_m = CylinderMesh.new()
			cup_m.top_radius = 0.065
			cup_m.bottom_radius = 0.065
			cup_m.height = 0.015
			cup_m.material = iron_mat
			cup.mesh = cup_m
			cup.position = Vector3(0, -0.002, p_l * 0.50)
			panel.add_child(cup)

			var ring = MeshInstance3D.new()
			ring.name = "RingHandle"
			var rm = TorusMesh.new()
			rm.inner_radius = 0.038
			rm.outer_radius = 0.060
			var r_mat = StandardMaterial3D.new()
			r_mat.albedo_color = Color(0.75, 0.78, 0.82)
			r_mat.metallic = 0.95
			r_mat.roughness = 0.20
			rm.material = r_mat
			ring.mesh = rm
			ring.position = Vector3(0, 0.008, p_l * 0.50)
			panel.add_child(ring)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(p_w, p_th, p_l)
				col.shape = cshape
				col.position = Vector3(0, -p_th * 0.5, p_l * 0.5)
				col.name = "Col"
				panel.add_child(col)
				panel.set_script(load("res://scripts/Door.gd"))
				d_root.set_script(load("res://scripts/Door.gd"))
				d_root.set("is_hatch", true)
				panel.set("is_hatch", true)

			hinge.add_child(panel)
			TextureHelper.apply_door_texture_to_node(d_root, "door_heavy_bolts")
			root.add_child(d_root)

		"prop_fusebox", "custom_prop_fusebox":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "fusebox")

			var box_w = 0.50
			var box_h = 0.68
			var box_d = 0.18

			var m_mat = StandardMaterial3D.new()
			m_mat.albedo_color = Color(0.25, 0.28, 0.32)
			m_mat.metallic = 0.75
			m_mat.roughness = 0.45

			var box = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(box_w, box_h, box_d)
			bm.material = m_mat
			box.mesh = bm
			box.position = Vector3(0, box_h * 0.5, 0)
			sb.add_child(box)

			var in_mat = StandardMaterial3D.new()
			in_mat.albedo_color = Color(0.10, 0.11, 0.12)
			in_mat.roughness = 0.8
			var in_panel = MeshInstance3D.new()
			var ipm = BoxMesh.new()
			ipm.size = Vector3(box_w * 0.88, box_h * 0.88, 0.03)
			ipm.material = in_mat
			in_panel.mesh = ipm
			in_panel.position = Vector3(0, box_h * 0.5, box_d * 0.5 + 0.005)
			sb.add_child(in_panel)

			var danger = MeshInstance3D.new()
			var dm = BoxMesh.new()
			dm.size = Vector3(0.26, 0.08, 0.02)
			var dmat = StandardMaterial3D.new()
			dmat.albedo_color = Color(0.95, 0.8, 0.1)
			dmat.emission_enabled = true
			dmat.emission = Color(0.8, 0.6, 0.05)
			dmat.emission_energy_multiplier = 0.5
			dm.material = dmat
			danger.mesh = dm
			danger.position = Vector3(0, box_h * 0.78, box_d * 0.5 + 0.02)
			sb.add_child(danger)

			var socket_mat = StandardMaterial3D.new()
			socket_mat.albedo_color = Color(0.18, 0.18, 0.20)
			socket_mat.roughness = 0.6

			var fuse_xs = [-0.12, 0.0, 0.12]
			var fuse_names = ["FuseRed", "FuseBlue", "FuseGreen"]
			var fuse_cols = [Color(1.0, 0.15, 0.15), Color(0.2, 0.6, 1.0), Color(0.2, 1.0, 0.3)]

			for i in range(3):
				var sock = MeshInstance3D.new()
				var scm = CylinderMesh.new()
				scm.top_radius = 0.038
				scm.bottom_radius = 0.038
				scm.height = 0.04
				scm.material = socket_mat
				sock.mesh = scm
				sock.position = Vector3(fuse_xs[i], box_h * 0.52, box_d * 0.5 + 0.02)
				sb.add_child(sock)

				var f_mesh = MeshInstance3D.new()
				f_mesh.name = fuse_names[i]
				var fcm = CylinderMesh.new()
				fcm.top_radius = 0.025
				fcm.bottom_radius = 0.025
				fcm.height = 0.12
				var fmat = StandardMaterial3D.new()
				fmat.albedo_color = fuse_cols[i]
				fmat.emission_enabled = true
				fmat.emission = fuse_cols[i]
				fmat.emission_energy_multiplier = 2.0
				fcm.material = fmat
				f_mesh.mesh = fcm
				f_mesh.position = Vector3(fuse_xs[i], box_h * 0.52, box_d * 0.5 + 0.05)
				f_mesh.visible = false
				sb.add_child(f_mesh)

			var switch_base = MeshInstance3D.new()
			var sbm = BoxMesh.new()
			sbm.size = Vector3(0.18, 0.14, 0.04)
			var base_mat = StandardMaterial3D.new()
			base_mat.albedo_color = Color(0.15, 0.15, 0.16)
			sbm.material = base_mat
			switch_base.mesh = sbm
			switch_base.position = Vector3(0, box_h * 0.25, box_d * 0.5 + 0.02)
			sb.add_child(switch_base)

			var arm_pivot = Node3D.new()
			arm_pivot.name = "SwitchArm"
			arm_pivot.position = Vector3(0, box_h * 0.22, box_d * 0.5 + 0.04)
			arm_pivot.rotation_degrees.x = -35.0

			var blade = MeshInstance3D.new()
			var blm = BoxMesh.new()
			blm.size = Vector3(0.02, 0.14, 0.02)
			var cop_mat = StandardMaterial3D.new()
			cop_mat.albedo_color = Color(0.85, 0.50, 0.20)
			cop_mat.metallic = 0.95
			blm.material = cop_mat
			blade.mesh = blm
			blade.position = Vector3(0, 0.07, 0)
			arm_pivot.add_child(blade)

			var handle = MeshInstance3D.new()
			var hm = CylinderMesh.new()
			hm.top_radius = 0.022
			hm.bottom_radius = 0.022
			hm.height = 0.05
			var hmat = StandardMaterial3D.new()
			hmat.albedo_color = Color(0.7, 0.1, 0.1)
			hm.material = hmat
			handle.mesh = hm
			handle.position = Vector3(0, 0.14, 0)
			arm_pivot.add_child(handle)

			sb.add_child(arm_pivot)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(box_w, box_h, box_d + 0.1)
				col.shape = cshape
				col.position = Vector3(0, box_h * 0.5, 0)
				sb.add_child(col)
				sb.set_script(load("res://scripts/FuseBox.gd"))

			root.add_child(sb)

		"item_fuse_red", "custom_item_fuse_red", \
		"item_fuse_blue", "custom_item_fuse_blue", \
		"item_fuse_green", "custom_item_fuse_green":
			var f_type = "fuse_red"
			var f_col = Color(1.0, 0.15, 0.15)
			if "blue" in type:
				f_type = "fuse_blue"
				f_col = Color(0.2, 0.6, 1.0)
			elif "green" in type:
				f_type = "fuse_green"
				f_col = Color(0.2, 1.0, 0.3)

			var area = Area3D.new()
			area.collision_layer = 1 | 4
			area.collision_mask = 0
			area.set_meta("item_type", f_type)

			var col = CollisionShape3D.new()
			var sphere = SphereShape3D.new()
			sphere.radius = 0.45
			col.shape = sphere
			area.add_child(col)

			var mi = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.05
			cm.bottom_radius = 0.05
			cm.height = 0.22
			var g_mat = StandardMaterial3D.new()
			g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.4)
			cm.material = g_mat
			mi.mesh = cm
			area.add_child(mi)

			var core = MeshInstance3D.new()
			var core_m = CylinderMesh.new()
			core_m.top_radius = 0.02
			core_m.bottom_radius = 0.02
			core_m.height = 0.16
			var c_mat = StandardMaterial3D.new()
			c_mat.albedo_color = f_col
			c_mat.emission_enabled = true
			c_mat.emission = f_col
			c_mat.emission_energy_multiplier = 2.0
			core_m.material = c_mat
			core.mesh = core_m
			area.add_child(core)

			var cap_mat = StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.85, 0.72, 0.25)
			cap_mat.metallic = 0.9
			for cy in [-0.11, 0.11]:
				var cap_m = CylinderMesh.new()
				cap_m.top_radius = 0.052
				cap_m.bottom_radius = 0.052
				cap_m.height = 0.04
				cap_m.material = cap_mat
				var cap_i = MeshInstance3D.new()
				cap_i.mesh = cap_m
				cap_i.position = Vector3(0, cy, 0)
				area.add_child(cap_i)

			var light = OmniLight3D.new()
			light.light_color = f_col
			light.light_energy = 1.4
			light.omni_range = 2.5
			area.add_child(light)

			if not is_ghost:
				area.set_script(load("res://scripts/Item.gd"))

			root.add_child(area)

		"prop_grandfather_clock", "custom_prop_grandfather_clock":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "grandfather_clock")

			var c_w = 0.65
			var c_h = 2.20
			var c_d = 0.45

			var wood_mat = StandardMaterial3D.new()
			wood_mat.albedo_color = Color(0.24, 0.14, 0.08)
			wood_mat.roughness = 0.75

			var dark_wood = StandardMaterial3D.new()
			dark_wood.albedo_color = Color(0.15, 0.09, 0.05)
			dark_wood.roughness = 0.85

			var brass_mat = StandardMaterial3D.new()
			brass_mat.albedo_color = Color(0.85, 0.72, 0.22)
			brass_mat.metallic = 0.9
			brass_mat.roughness = 0.25

			var base = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(c_w, 0.38, c_d)
			bm.material = dark_wood
			base.mesh = bm
			base.position = Vector3(0, 0.19, 0)
			sb.add_child(base)

			var mid = MeshInstance3D.new()
			var mm = BoxMesh.new()
			mm.size = Vector3(c_w * 0.85, 1.15, c_d * 0.82)
			mm.material = wood_mat
			mid.mesh = mm
			mid.position = Vector3(0, 0.38 + 0.575, -c_d * 0.05)
			sb.add_child(mid)

			var hood = MeshInstance3D.new()
			var hm = BoxMesh.new()
			hm.size = Vector3(c_w * 0.95, 0.65, c_d * 0.95)
			hm.material = dark_wood
			hood.mesh = hm
			hood.position = Vector3(0, c_h - 0.325, 0)
			sb.add_child(hood)

			var dial = MeshInstance3D.new()
			var dm = CylinderMesh.new()
			dm.top_radius = 0.20
			dm.bottom_radius = 0.20
			dm.height = 0.03
			var dial_mat = StandardMaterial3D.new()
			dial_mat.albedo_color = Color(0.92, 0.88, 0.76)
			dm.material = dial_mat
			dial.mesh = dm
			dial.rotation_degrees.x = 90.0
			dial.position = Vector3(0, c_h - 0.325, c_d * 0.45)
			sb.add_child(dial)

			var hand1 = MeshInstance3D.new()
			var h1m = BoxMesh.new()
			h1m.size = Vector3(0.015, 0.12, 0.01)
			var blk_mat = StandardMaterial3D.new()
			blk_mat.albedo_color = Color(0.1, 0.1, 0.1)
			h1m.material = blk_mat
			hand1.mesh = h1m
			hand1.position = Vector3(0, c_h - 0.27, c_d * 0.47)
			sb.add_child(hand1)

			var hand2 = MeshInstance3D.new()
			var h2m = BoxMesh.new()
			h2m.size = Vector3(0.10, 0.015, 0.01)
			h2m.material = blk_mat
			hand2.mesh = h2m
			hand2.position = Vector3(0.04, c_h - 0.325, c_d * 0.47)
			sb.add_child(hand2)

			var pendulum_pivot = Node3D.new()
			pendulum_pivot.name = "Pendulum"
			pendulum_pivot.position = Vector3(0, 1.45, 0.06)

			var rod = MeshInstance3D.new()
			var rm = CylinderMesh.new()
			rm.top_radius = 0.01
			rm.bottom_radius = 0.01
			rm.height = 0.70
			rm.material = brass_mat
			rod.mesh = rm
			rod.position = Vector3(0, -0.35, 0)
			pendulum_pivot.add_child(rod)

			var bob = MeshInstance3D.new()
			var bob_m = CylinderMesh.new()
			bob_m.top_radius = 0.09
			bob_m.bottom_radius = 0.09
			bob_m.height = 0.03
			bob_m.material = brass_mat
			bob.mesh = bob_m
			bob.rotation_degrees.x = 90.0
			bob.position = Vector3(0, -0.70, 0)
			pendulum_pivot.add_child(bob)
			sb.add_child(pendulum_pivot)

			for gx in [-0.10, 0.10]:
				var weight = MeshInstance3D.new()
				var wm = CylinderMesh.new()
				wm.top_radius = 0.03
				wm.bottom_radius = 0.03
				wm.height = 0.30
				wm.material = brass_mat
				weight.mesh = wm
				weight.position = Vector3(gx, 1.10, 0.05)
				sb.add_child(weight)

			var door_pivot = Node3D.new()
			door_pivot.name = "ClockDoor"
			door_pivot.position = Vector3(-c_w * 0.38, 0.95, c_d * 0.36)

			var d_frame = MeshInstance3D.new()
			var dfm = BoxMesh.new()
			dfm.size = Vector3(c_w * 0.76, 1.05, 0.03)
			var glass_mat = StandardMaterial3D.new()
			glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass_mat.albedo_color = Color(0.8, 0.9, 1.0, 0.25)
			glass_mat.roughness = 0.05
			dfm.material = glass_mat
			d_frame.mesh = dfm
			d_frame.position = Vector3(c_w * 0.38, 0, 0)
			door_pivot.add_child(d_frame)
			sb.add_child(door_pivot)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(c_w, c_h, c_d)
				col.shape = cshape
				col.position = Vector3(0, c_h * 0.5, 0)
				sb.add_child(col)
				sb.set_script(load("res://scripts/GrandfatherClock.gd"))

			root.add_child(sb)

		"prop_crt_tv", "custom_prop_crt_tv":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "crt_tv")

			var tv_w = 0.74
			var tv_h = 0.54
			var tv_d = 0.48
			var leg_h = 0.32

			var wood_casing = StandardMaterial3D.new()
			wood_casing.albedo_color = Color(0.28, 0.17, 0.10)
			wood_casing.roughness = 0.65

			var body = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(tv_w, tv_h, tv_d)
			bm.material = wood_casing
			body.mesh = bm
			body.position = Vector3(0, leg_h + tv_h * 0.5, 0)
			sb.add_child(body)

			var bezel_mat = StandardMaterial3D.new()
			bezel_mat.albedo_color = Color(0.12, 0.12, 0.14)
			var bezel = MeshInstance3D.new()
			var bzm = BoxMesh.new()
			bzm.size = Vector3(tv_w * 0.94, tv_h * 0.90, 0.04)
			bzm.material = bezel_mat
			bezel.mesh = bzm
			bezel.position = Vector3(0, leg_h + tv_h * 0.5, tv_d * 0.5 + 0.01)
			sb.add_child(bezel)

			var screen = MeshInstance3D.new()
			screen.name = "Screen"
			var scm = BoxMesh.new()
			scm.size = Vector3(tv_w * 0.62, tv_h * 0.72, 0.02)
			var s_mat = StandardMaterial3D.new()
			s_mat.albedo_color = Color(0.04, 0.05, 0.06)
			s_mat.roughness = 0.15
			s_mat.metallic = 0.2
			scm.material = s_mat
			screen.mesh = scm
			screen.position = Vector3(-tv_w * 0.12, leg_h + tv_h * 0.5, tv_d * 0.5 + 0.025)
			sb.add_child(screen)

			var knob_mat = StandardMaterial3D.new()
			knob_mat.albedo_color = Color(0.8, 0.7, 0.3)
			knob_mat.metallic = 0.8
			for ky in [0.08, -0.06]:
				var knob = MeshInstance3D.new()
				var km = CylinderMesh.new()
				km.top_radius = 0.035
				km.bottom_radius = 0.035
				km.height = 0.03
				km.material = knob_mat
				knob.mesh = km
				knob.rotation_degrees.x = 90.0
				knob.position = Vector3(tv_w * 0.32, leg_h + tv_h * 0.5 + ky, tv_d * 0.5 + 0.03)
				sb.add_child(knob)

			var ant_mat = StandardMaterial3D.new()
			ant_mat.albedo_color = Color(0.7, 0.7, 0.75)
			ant_mat.metallic = 0.9
			for angle in [-24.0, 24.0]:
				var ant = MeshInstance3D.new()
				var am = CylinderMesh.new()
				am.top_radius = 0.006
				am.bottom_radius = 0.008
				am.height = 0.40
				am.material = ant_mat
				ant.mesh = am
				ant.rotation_degrees.z = angle
				ant.position = Vector3(angle * 0.004, leg_h + tv_h + 0.18, 0)
				sb.add_child(ant)

			var leg_mat = StandardMaterial3D.new()
			leg_mat.albedo_color = Color(0.18, 0.11, 0.07)
			for lx in [-tv_w * 0.4, tv_w * 0.4]:
				for lz in [-tv_d * 0.35, tv_d * 0.35]:
					var leg = MeshInstance3D.new()
					var lm = CylinderMesh.new()
					lm.top_radius = 0.025
					lm.bottom_radius = 0.015
					lm.height = leg_h
					lm.material = leg_mat
					leg.mesh = lm
					leg.position = Vector3(lx, leg_h * 0.5, lz)
					leg.rotation_degrees.z = -8.0 if lx > 0 else 8.0
					sb.add_child(leg)

			var s_light = SpotLight3D.new()
			s_light.name = "ScreenLight"
			s_light.light_color = Color(0.75, 0.88, 1.0)
			s_light.light_energy = 2.0
			s_light.spot_range = 9.0
			s_light.spot_angle = 55.0
			s_light.position = Vector3(-tv_w * 0.12, leg_h + tv_h * 0.5, tv_d * 0.5 + 0.05)
			# Вращение на 180°: луч светит ВПЕРЁД от экрана в комнату (+Z), а не назад в стену
			s_light.rotation_degrees = Vector3(0, 180.0, 0)
			s_light.visible = false
			sb.add_child(s_light)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(tv_w, tv_h + leg_h, tv_d)
				col.shape = cshape
				col.position = Vector3(0, (tv_h + leg_h) * 0.5, 0)
				sb.add_child(col)
				sb.set_script(load("res://scripts/HorrorTV.gd"))

			root.add_child(sb)

		"prop_occult_altar", "custom_prop_occult_altar":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "occult_altar")

			var a_w = 1.30
			var a_h = 0.88
			var a_d = 0.80

			var stone_mat = StandardMaterial3D.new()
			stone_mat.albedo_color = Color(0.14, 0.13, 0.15)
			stone_mat.roughness = 0.9

			var top = MeshInstance3D.new()
			var tm = BoxMesh.new()
			tm.size = Vector3(a_w, 0.12, a_d)
			tm.material = stone_mat
			top.mesh = tm
			top.position = Vector3(0, a_h, 0)
			sb.add_child(top)

			var cloth_mat = StandardMaterial3D.new()
			cloth_mat.albedo_color = Color(0.38, 0.05, 0.06)
			cloth_mat.roughness = 0.85
			var cloth = MeshInstance3D.new()
			var clm = BoxMesh.new()
			clm.size = Vector3(a_w * 1.02, 0.04, a_d * 1.02)
			clm.material = cloth_mat
			cloth.mesh = clm
			cloth.position = Vector3(0, a_h + 0.07, 0)
			sb.add_child(cloth)

			for lx in [-a_w * 0.42, a_w * 0.42]:
				for lz in [-a_d * 0.38, a_d * 0.38]:
					var leg = MeshInstance3D.new()
					var lm = CylinderMesh.new()
					lm.top_radius = 0.09
					lm.bottom_radius = 0.11
					lm.height = a_h
					lm.material = stone_mat
					leg.mesh = lm
					leg.position = Vector3(lx, a_h * 0.5, lz)
					sb.add_child(leg)

			var bone_mat = StandardMaterial3D.new()
			bone_mat.albedo_color = Color(0.85, 0.82, 0.72)
			bone_mat.roughness = 0.85

			var cranium = MeshInstance3D.new()
			var crm = SphereMesh.new()
			crm.radius = 0.11
			crm.height = 0.18
			crm.material = bone_mat
			cranium.mesh = crm
			cranium.position = Vector3(0, a_h + 0.18, 0)
			sb.add_child(cranium)

			var horn_mat = StandardMaterial3D.new()
			horn_mat.albedo_color = Color(0.20, 0.17, 0.15)
			for hx in [-1.0, 1.0]:
				var horn = MeshInstance3D.new()
				var hm = CylinderMesh.new()
				hm.top_radius = 0.015
				hm.bottom_radius = 0.035
				hm.height = 0.24
				hm.material = horn_mat
				horn.mesh = hm
				horn.rotation_degrees = Vector3(15.0, 0, -35.0 * hx)
				horn.position = Vector3(0.08 * hx, a_h + 0.28, -0.02)
				sb.add_child(horn)

			var book_mat = StandardMaterial3D.new()
			book_mat.albedo_color = Color(0.55, 0.22, 0.12)
			var book = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.24, 0.03, 0.32)
			bm.material = book_mat
			book.mesh = bm
			book.position = Vector3(0.32, a_h + 0.10, 0.05)
			book.rotation_degrees.y = -15.0
			sb.add_child(book)

			var wax_mat = StandardMaterial3D.new()
			wax_mat.albedo_color = Color(0.88, 0.85, 0.78)

			var flame_mat = StandardMaterial3D.new()
			flame_mat.albedo_color = Color(1.0, 0.65, 0.15)
			flame_mat.emission_enabled = true
			flame_mat.emission = Color(1.0, 0.60, 0.1)
			flame_mat.emission_energy_multiplier = 2.5

			var candle_pos = [
				Vector3(-0.35, a_h + 0.10, -0.15),
				Vector3(-0.25, a_h + 0.10, 0.20),
				Vector3(0.35, a_h + 0.10, -0.18)
			]

			for i in range(3):
				var cndl = MeshInstance3D.new()
				var cm = CylinderMesh.new()
				cm.top_radius = 0.025
				cm.bottom_radius = 0.025
				cm.height = 0.15 + (i * 0.04)
				cm.material = wax_mat
				cndl.mesh = cm
				cndl.position = candle_pos[i] + Vector3(0, cm.height * 0.5, 0)
				sb.add_child(cndl)

				var flame = MeshInstance3D.new()
				flame.name = "Flame%d" % (i + 1)
				var fm = SphereMesh.new()
				fm.radius = 0.022
				fm.height = 0.05
				fm.material = flame_mat
				flame.mesh = fm
				flame.position = cndl.position + Vector3(0, cm.height * 0.5 + 0.02, 0)
				sb.add_child(flame)

				var clight = OmniLight3D.new()
				clight.name = "CandleLight%d" % (i + 1)
				clight.light_color = Color(1.0, 0.65, 0.25)
				clight.light_energy = 1.3
				clight.omni_range = 4.5
				clight.position = flame.position
				sb.add_child(clight)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(a_w, a_h + 0.35, a_d)
				col.shape = cshape
				col.position = Vector3(0, (a_h + 0.35) * 0.5, 0)
				sb.add_child(col)
				sb.set_script(load("res://scripts/OccultAltar.gd"))

			root.add_child(sb)

		"prop_safe", "custom_prop_safe":
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			sb.set_meta("item_type", "safe")

			var s_w = 0.64
			var s_h = 0.74
			var s_d = 0.58

			var steel_mat = StandardMaterial3D.new()
			steel_mat.albedo_color = Color(0.18, 0.20, 0.23)
			steel_mat.metallic = 0.85
			steel_mat.roughness = 0.35

			var dark_steel = StandardMaterial3D.new()
			dark_steel.albedo_color = Color(0.10, 0.11, 0.13)
			dark_steel.metallic = 0.9
			dark_steel.roughness = 0.45

			var outer = MeshInstance3D.new()
			var om = BoxMesh.new()
			om.size = Vector3(s_w, s_h, s_d)
			om.material = steel_mat
			outer.mesh = om
			outer.position = Vector3(0, s_h * 0.5, 0)
			sb.add_child(outer)

			var cavity = MeshInstance3D.new()
			var cvm = BoxMesh.new()
			cvm.size = Vector3(s_w * 0.82, s_h * 0.82, s_d * 0.75)
			cvm.material = dark_steel
			cavity.mesh = cvm
			cavity.position = Vector3(0, s_h * 0.5, 0.05)
			sb.add_child(cavity)

			var door_pivot = Node3D.new()
			door_pivot.name = "SafeDoor"
			door_pivot.position = Vector3(-s_w * 0.42, s_h * 0.5, s_d * 0.5)

			var door_slab = MeshInstance3D.new()
			var dsm = BoxMesh.new()
			dsm.size = Vector3(s_w * 0.84, s_h * 0.84, 0.07)
			dsm.material = steel_mat
			door_slab.mesh = dsm
			door_slab.position = Vector3(s_w * 0.42, 0, 0)
			door_pivot.add_child(door_slab)

			var dial_pivot = Node3D.new()
			dial_pivot.name = "Dial"
			dial_pivot.position = Vector3(s_w * 0.42, 0.04, 0.04)

			var dial_disk = MeshInstance3D.new()
			var ddm = CylinderMesh.new()
			ddm.top_radius = 0.075
			ddm.bottom_radius = 0.075
			ddm.height = 0.025
			var dial_mat = StandardMaterial3D.new()
			dial_mat.albedo_color = Color(0.85, 0.72, 0.22)
			dial_mat.metallic = 0.95
			dial_mat.roughness = 0.2
			ddm.material = dial_mat
			dial_disk.mesh = ddm
			dial_disk.rotation_degrees.x = 90.0
			dial_pivot.add_child(dial_disk)

			var knob = MeshInstance3D.new()
			var km = CylinderMesh.new()
			km.top_radius = 0.035
			km.bottom_radius = 0.035
			km.height = 0.04
			km.material = steel_mat
			knob.mesh = km
			knob.rotation_degrees.x = 90.0
			knob.position = Vector3(0, 0, 0.02)
			dial_pivot.add_child(knob)

			door_pivot.add_child(dial_pivot)

			var handle_base = MeshInstance3D.new()
			var hbm = CylinderMesh.new()
			hbm.top_radius = 0.02
			hbm.bottom_radius = 0.02
			hbm.height = 0.05
			hbm.material = dial_mat
			handle_base.mesh = hbm
			handle_base.rotation_degrees.x = 90.0
			handle_base.position = Vector3(s_w * 0.42, -0.16, 0.05)
			door_pivot.add_child(handle_base)

			for sp_deg in [0.0, 60.0, 120.0]:
				var spoke = MeshInstance3D.new()
				var spm = BoxMesh.new()
				spm.size = Vector3(0.18, 0.02, 0.02)
				spm.material = dial_mat
				spoke.mesh = spm
				spoke.rotation_degrees.z = sp_deg
				spoke.position = Vector3(s_w * 0.42, -0.16, 0.07)
				door_pivot.add_child(spoke)

			sb.add_child(door_pivot)

			if not is_ghost:
				var col = CollisionShape3D.new()
				var cshape = BoxShape3D.new()
				cshape.size = Vector3(s_w, s_h, s_d)
				col.shape = cshape
				col.position = Vector3(0, s_h * 0.5, 0)
				sb.add_child(col)
				sb.set_script(load("res://scripts/Safe.gd"))

			root.add_child(sb)

		"item_battery", "custom_item_battery":
			var area = Area3D.new()
			area.collision_layer = 1 | 4
			area.collision_mask = 0
			area.set_meta("item_type", "battery")
			var col = CollisionShape3D.new()
			var sphere = SphereShape3D.new()
			sphere.radius = max(0.4, sz.x * 0.5)
			col.shape = sphere
			area.add_child(col)

			var mi = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.1
			cm.bottom_radius = 0.1
			cm.height = 0.35
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.12, 0.65, 0.25)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.45, 0.2)
			cm.material = mat
			mi.mesh = cm
			area.add_child(mi)

			var cap = MeshInstance3D.new()
			var cap_m = CylinderMesh.new()
			cap_m.top_radius = 0.04
			cap_m.bottom_radius = 0.04
			cap_m.height = 0.08
			var cmat = StandardMaterial3D.new()
			cmat.albedo_color = Color(0.95, 0.82, 0.15)
			cap_m.material = cmat
			cap.mesh = cap_m
			cap.position = Vector3(0, 0.19, 0)
			area.add_child(cap)

			if not is_ghost:
				area.set_script(load("res://scripts/Item.gd"))
			root.add_child(area)

		"prop_note", "custom_prop_note":
			var area = Area3D.new()
			area.collision_layer = 1 | 4
			area.collision_mask = 0
			area.set_meta("item_type", "note")
			var col = CollisionShape3D.new()
			var bshape = BoxShape3D.new()
			bshape.size = Vector3(0.5, 0.2, 0.5)
			col.shape = bshape
			area.add_child(col)

			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.38, 0.005, 0.28)
			var nmat = StandardMaterial3D.new()
			nmat.albedo_color = Color(0.88, 0.84, 0.72)
			bm.material = nmat
			mi.mesh = bm
			area.add_child(mi)

			var strip = MeshInstance3D.new()
			var smesh = BoxMesh.new()
			smesh.size = Vector3(0.34, 0.007, 0.04)
			var smat = StandardMaterial3D.new()
			smat.albedo_color = Color(0.35, 0.22, 0.12)
			smesh.material = smat
			strip.mesh = smesh
			strip.position = Vector3(0, 0.003, -0.09)
			area.add_child(strip)

			if not is_ghost:
				area.set_script(load("res://scripts/Item.gd"))
			root.add_child(area)

		"prop_light_switch", "custom_prop_light_switch":
			var area = Area3D.new()
			area.collision_layer = 1 | 4
			area.collision_mask = 0
			area.set_meta("item_type", "light_switch")
			var col = CollisionShape3D.new()
			var bshape = BoxShape3D.new()
			bshape.size = Vector3(0.3, 0.3, 0.2)
			col.shape = bshape
			area.add_child(col)

			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = Vector3(0.16, 0.24, 0.04)
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.88, 0.88, 0.90)
			bm.material = mat
			mi.mesh = bm
			area.add_child(mi)

			var tog = MeshInstance3D.new()
			tog.name = "Toggle"
			var tm = BoxMesh.new()
			tm.size = Vector3(0.04, 0.08, 0.06)
			var tmat = StandardMaterial3D.new()
			tmat.albedo_color = Color(0.2, 0.2, 0.25)
			tm.material = tmat
			tog.mesh = tm
			tog.position = Vector3(0, 0, 0.03)
			area.add_child(tog)

			if not is_ghost:
				area.set_script(load("res://scripts/LightSwitch.gd"))
			root.add_child(area)

		"item_key_gold", "item_key_silver", "item_key_rusty", "item_key_emerald", \
		"custom_item_key_gold", "custom_item_key_silver", "custom_item_key_rusty", "custom_item_key_emerald":
			var area = Area3D.new()
			area.collision_layer = 1 | 4
			area.collision_mask = 0
			var k_type = "key_gold"
			if "silver" in type: k_type = "key_silver"
			elif "rusty" in type: k_type = "key_rusty"
			elif "emerald" in type: k_type = "key_emerald"
			area.set_meta("item_type", k_type)

			if not is_ghost:
				area.set_script(load("res://scripts/Item.gd"))
			else:
				var col = CollisionShape3D.new()
				var sphere = SphereShape3D.new()
				sphere.radius = 0.3
				col.shape = sphere
				area.add_child(col)
				var mi = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(0.28, 0.1, 0.05)
				mi.mesh = bm
				area.add_child(mi)
			root.add_child(area)

		"prop_note_safe", "custom_prop_note_safe", "item_note_safe":
			var area = Area3D.new()
			area.collision_layer = 1 | 4
			area.collision_mask = 0
			area.set_meta("item_type", "note_safe")

			if not is_ghost:
				area.set_script(load("res://scripts/Item.gd"))
			else:
				var col = CollisionShape3D.new()
				var bs = BoxShape3D.new()
				bs.size = Vector3(0.4, 0.1, 0.3)
				col.shape = bs
				area.add_child(col)
				var mi = MeshInstance3D.new()
				var bm = BoxMesh.new()
				bm.size = Vector3(0.36, 0.005, 0.28)
				mi.mesh = bm
				area.add_child(mi)
			root.add_child(area)

		_:
			var sb = StaticBody3D.new()
			sb.collision_layer = 1
			sb.collision_mask = 0
			var mi = MeshInstance3D.new()
			var bm = BoxMesh.new()
			bm.size = sz
			mi.mesh = bm
			sb.add_child(mi)
			if not is_ghost:
				var col = CollisionShape3D.new()
				var shape = BoxShape3D.new()
				shape.size = sz
				col.shape = shape
				sb.add_child(col)
	# Ель сама строится в размере sz, второй масштаб сделал бы её гигантской
	if sz != Vector3.ZERO and type != "prop_tree_pine" and type != "custom_prop_tree_pine" and type != "cube" and not type.begins_with("floor") and not type.begins_with("ceiling") and not type.begins_with("door") and not type.begins_with("custom_door"):
		var base_sz = get_prefab_base_size(type)
		if base_sz.x > 0.01 and base_sz.y > 0.01 and base_sz.z > 0.01:
			root.scale = Vector3(sz.x / base_sz.x, sz.y / base_sz.y, sz.z / base_sz.z)

	return root
