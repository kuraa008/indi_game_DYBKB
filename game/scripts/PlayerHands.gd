class_name PlayerHands
extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  PlayerHands.gd — Реалистичные 3D руки от первого лица (FPS Viewmodel)
#  • Левая рука: НАВСЕГДА держит металлический фонарик в нижнем левом углу.
#  • Правая рука: держит выбранный предмет из рюкзака (бутылка, лом, ключ и др.).
#  • Если правая рука пуста — она аккуратно опущена за пределы экрана.
#  • Анатомическая форма кистей: перчатка, ладонь, большой палец и 4 пальца хвата.
#  • Реалистичная анимация броска бутылки: замах, бросок, исчезновение из руки
#    и доставание новой бутылки только если они еще есть в рюкзаке!
# ══════════════════════════════════════════════════════════════════════════════

var camera_ref: Camera3D = null
var player_ref = null

# Левая рука (фонарик)
var left_arm_root: Node3D = null
var left_flashlight_lens: MeshInstance3D = null
var left_spot_light: SpotLight3D = null
var left_spill_light: SpotLight3D = null
var _hotspot_energy := 4.5
var _spill_energy := 1.4
var left_base_pos: Vector3 = Vector3(-0.2, -0.2, -0.34)

# Правая рука (предмет)
var right_arm_root: Node3D = null
var right_item_pivot: Node3D = null
var right_base_pos: Vector3 = Vector3(0.33, -0.33, -0.42)
var current_held_item_id: String = ""

# Анимация и физика
var bob_time: float = 0.0
var walk_phase: float = 0.0
var is_switching_item: bool = false
var is_throwing: bool = false
var switch_tween: Tween = null

func _ready() -> void:
	_build_left_hand_flashlight()
	_build_right_hand_item_holder()

	if GameManager:
		GameManager.active_item_changed.connect(_on_active_item_changed)
		GameManager.battery_changed.connect(_on_battery_changed)
		GameManager.graphics_quality_changed.connect(_on_graphics_quality_changed)

	call_deferred("_init_initial_item")
	_on_graphics_quality_changed(GameManager.graphics_quality if GameManager else "ultra")

func setup(p_cam: Camera3D, p_player: CharacterBody3D) -> void:
	camera_ref = p_cam
	player_ref = p_player

func _init_initial_item() -> void:
	var it = GameManager.get_active_item()
	if not it.is_empty():
		_set_held_item(str(it.get("id", "")), it, false)
	else:
		_set_held_item("empty", {}, false)

func _process(delta: float) -> void:
	bob_time += delta

	# Дыхание (плавное микродвижение)
	var breath_y = sin(bob_time * 1.6) * 0.0025
	var breath_x = cos(bob_time * 0.8) * 0.0018

	# Покачивание при ходьбе
	var is_moving = false
	var speed = 0.0
	if player_ref and is_instance_valid(player_ref):
		var vel = player_ref.velocity
		vel.y = 0.0
		speed = vel.length()
		is_moving = speed > 0.4 and player_ref.is_on_floor()

	var walk_x = 0.0
	var walk_y = 0.0
	if is_moving:
		walk_phase += delta * speed * 2.6
		walk_x = sin(walk_phase) * 0.008
		walk_y = abs(cos(walk_phase)) * 0.006
	else:
		walk_phase = lerp(walk_phase, 0.0, delta * 4.0)

	# Применяем покачивание к левой руке (фонарик)
	if left_arm_root:
		left_arm_root.position.x = left_base_pos.x + breath_x + walk_x * 0.5
		left_arm_root.position.y = left_base_pos.y + breath_y - walk_y * 0.7
		left_arm_root.rotation.z = walk_x * 0.35

	# Применяем покачивание к правой руке (если она активна и не в анимации броска/смены)
	if right_arm_root and not is_switching_item and not is_throwing:
		if current_held_item_id != "" and current_held_item_id != "empty":
			right_arm_root.position.x = right_base_pos.x - breath_x - walk_x * 0.5
			right_arm_root.position.y = right_base_pos.y + breath_y - walk_y * 0.7
			right_arm_root.rotation.z = -walk_x * 0.35

# ══════════════════════════════════════════════════════════════════════════════
#  Генератор анатомической кисти и рукава
# ══════════════════════════════════════════════════════════════════════════════
func _build_arm_mesh_hierarchy(is_left: bool) -> Node3D:
	var root_node = Node3D.new()
	root_node.name = "ArmMesh"
	var show_arms: bool = GameManager.show_viewmodel_arms if GameManager else false
	root_node.visible = show_arms
	var sign_x = -1.0 if is_left else 1.0

	# 1. Предплечье / рукав куртки (выходит естественно из угла экрана)
	var sleeve = MeshInstance3D.new()
	sleeve.name = "Sleeve"
	var sm = CylinderMesh.new()
	sm.top_radius = 0.038
	sm.bottom_radius = 0.052
	sm.height = 0.28
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.12, 0.13, 0.16) # Темно-серая куртка героя
	s_mat.roughness = 0.85
	sm.surface_set_material(0, s_mat)
	sleeve.mesh = sm
	sleeve.rotation_degrees = Vector3(45.0, sign_x * 12.0, -sign_x * 10.0)
	sleeve.position = Vector3(sign_x * 0.02, -0.09, 0.12)
	root_node.add_child(sleeve)

	# 2. Манжета рукава
	var cuff = MeshInstance3D.new()
	cuff.name = "Cuff"
	var cm = CylinderMesh.new()
	cm.top_radius = 0.040
	cm.bottom_radius = 0.040
	cm.height = 0.03
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.09, 0.10, 0.12)
	c_mat.roughness = 0.95
	cm.surface_set_material(0, c_mat)
	cuff.mesh = cm
	cuff.rotation_degrees = sleeve.rotation_degrees
	cuff.position = sleeve.position - Vector3(sign_x * 0.008, -0.065, 0.08)
	root_node.add_child(cuff)

	# 3. Ладонь в темной тактической перчатке
	var palm = MeshInstance3D.new()
	palm.name = "Palm"
	var pm = BoxMesh.new()
	pm.size = Vector3(0.055, 0.038, 0.068)
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.20, 0.22, 0.26) # Матовая кожа/ткань перчатки
	g_mat.roughness = 0.65
	pm.surface_set_material(0, g_mat)
	palm.mesh = pm
	palm.position = Vector3(sign_x * 0.008, -0.01, -0.03)
	palm.rotation_degrees = Vector3(12.0, sign_x * 8.0, -sign_x * 15.0)
	root_node.add_child(palm)

	# 4. Четыре согнутых пальца хвата
	for i in range(4):
		var finger = MeshInstance3D.new()
		finger.name = "Finger_%d" % i
		var fm = CapsuleMesh.new()
		fm.radius = 0.008
		fm.height = 0.038
		fm.surface_set_material(0, g_mat)
		finger.mesh = fm
		var f_offset_z = -0.045 - i * 0.013
		finger.position = Vector3(sign_x * 0.024, -0.005, f_offset_z)
		finger.rotation_degrees = Vector3(55.0, sign_x * 12.0, sign_x * 40.0)
		root_node.add_child(finger)

	# 5. Большой палец, фиксирующий предмет сверху
	var thumb = MeshInstance3D.new()
	thumb.name = "Thumb"
	var tm = CapsuleMesh.new()
	tm.radius = 0.009
	tm.height = 0.036
	tm.surface_set_material(0, g_mat)
	thumb.mesh = tm
	thumb.position = Vector3(-sign_x * 0.018, 0.016, -0.032)
	thumb.rotation_degrees = Vector3(25.0, -sign_x * 25.0, -sign_x * 45.0)
	root_node.add_child(thumb)

	return root_node

# ══════════════════════════════════════════════════════════════════════════════
#  Левая рука — 3D Фонарик (направлен в центр обзора)
# ══════════════════════════════════════════════════════════════════════════════
func _build_left_hand_flashlight() -> void:
	left_arm_root = Node3D.new()
	left_arm_root.name = "LeftHandRoot"
	left_arm_root.position = left_base_pos
	add_child(left_arm_root)

	# Точка крепления фонарика: он лежит в кулаке и смотрит почти прямо вперёд
	var fl_pivot = Node3D.new()
	fl_pivot.name = "FlashlightPivot"
	fl_pivot.position = Vector3(0.0, 0.0, -0.05)
	fl_pivot.rotation_degrees = Vector3(4.0, -2.0, -6.0)
	left_arm_root.add_child(fl_pivot)

	_build_flashlight_body(fl_pivot)
	_build_left_hand_grip(fl_pivot)

	# Стекло / светящаяся линза фонарика
	left_flashlight_lens = MeshInstance3D.new()
	left_flashlight_lens.name = "Lens"
	var lens_m = CylinderMesh.new()
	lens_m.top_radius = 0.0255
	lens_m.bottom_radius = 0.0255
	lens_m.height = 0.004
	var lens_mat = StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.96, 0.93, 0.82)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(0.96, 0.93, 0.82)
	lens_mat.emission_energy_multiplier = 2.4
	lens_mat.roughness = 0.1
	lens_m.material = lens_mat
	left_flashlight_lens.mesh = lens_m
	left_flashlight_lens.rotation_degrees.x = 90.0
	left_flashlight_lens.position = Vector3(0, 0, -0.131)
	fl_pivot.add_child(left_flashlight_lens)

	# 1. Центральный яркий луч фонарика (Hotspot) с объемным туманом
	left_spot_light = SpotLight3D.new()
	left_spot_light.name = "FlashlightHotspot"
	left_spot_light.spot_range = 42.0
	left_spot_light.spot_angle = 36.0
	left_spot_light.spot_angle_attenuation = 1.0
	left_spot_light.light_color = Color(0.98, 0.95, 0.88)
	left_spot_light.light_energy = 4.5
	left_spot_light.shadow_enabled = true
	if "light_volumetric_fog_energy" in left_spot_light:
		left_spot_light.light_volumetric_fog_energy = 1.8
	left_spot_light.position = Vector3(0, 0, -0.14)
	fl_pivot.add_child(left_spot_light)

	# 2. Широкий рассеянный ореол фонарика (Spill light — освещает пол и стены по бокам)
	left_spill_light = SpotLight3D.new()
	left_spill_light.name = "FlashlightSpill"
	left_spill_light.spot_range = 24.0
	left_spill_light.spot_angle = 68.0
	left_spill_light.spot_angle_attenuation = 1.3
	left_spill_light.light_color = Color(0.90, 0.92, 0.98)
	left_spill_light.light_energy = 1.4
	left_spill_light.shadow_enabled = false
	left_spill_light.position = Vector3(0, 0, -0.14)
	fl_pivot.add_child(left_spill_light)

# ── Фонарик: металлический корпус с насечкой, хвостовик с кнопкой, расширенная головка ──
func _hand_mat(col: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	return m


func _cyl_z(parent: Node3D, r_front: float, r_back: float, length: float, z: float, mat: Material, sides: int = 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_back
	cm.bottom_radius = r_front
	cm.height = length
	cm.radial_segments = sides
	cm.rings = 1
	cm.material = mat
	mi.mesh = cm
	mi.rotation_degrees.x = -90.0
	mi.position = Vector3(0, 0, z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _build_flashlight_body(fl_pivot: Node3D) -> void:
	var body := _hand_mat(Color(0.3, 0.31, 0.33), 0.38, 0.75)
	var dark := _hand_mat(Color(0.12, 0.12, 0.13), 0.6, 0.5)
	var rubber := _hand_mat(Color(0.07, 0.07, 0.075), 0.9)
	var chrome := _hand_mat(Color(0.7, 0.7, 0.72), 0.18, 0.95)
	# Ствол, хвост и колпачок с резиновой кнопкой
	_cyl_z(fl_pivot, 0.0175, 0.0175, 0.15, 0.005, body)
	_cyl_z(fl_pivot, 0.0185, 0.0185, 0.022, 0.085, dark)
	_cyl_z(fl_pivot, 0.011, 0.012, 0.008, 0.099, rubber, 14)
	# Насечка на рукояти: тонкие тёмные кольца
	for i in range(9):
		_cyl_z(fl_pivot, 0.0182, 0.0182, 0.0035, 0.06 - float(i) * 0.0085, dark, 18)
	# Переход к головке, головка, хромированное кольцо у стекла
	_cyl_z(fl_pivot, 0.024, 0.018, 0.03, -0.085, body)
	_cyl_z(fl_pivot, 0.0275, 0.0245, 0.026, -0.113, body)
	_cyl_z(fl_pivot, 0.0285, 0.0285, 0.006, -0.127, chrome)
	# Рёбра охлаждения на головке
	for i in range(3):
		_cyl_z(fl_pivot, 0.0262, 0.0262, 0.003, -0.104 - float(i) * 0.006, dark, 20)


# ── Левая кисть: пальцы обхватывают корпус снизу, большой палец лежит сверху ──
func _seg(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.0005:
		return
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = len + r * 2.0
	cm.radial_segments = 12
	cm.rings = 4
	cm.material = mat
	mi.mesh = cm
	var y := d / len
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	mi.transform = Transform3D(Basis(x, y, x.cross(y)), (a + b) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _blob(parent: Node3D, at: Vector3, radii: Vector3, rot: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 18
	sm.rings = 10
	sm.material = mat
	mi.mesh = sm
	mi.transform = Transform3D(Basis.from_euler(rot * (PI / 180.0)) * Basis.from_scale(radii), at)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _ring_point(theta_deg: float, r: float, z: float) -> Vector3:
	var t := deg_to_rad(theta_deg)
	return Vector3(cos(t) * r, sin(t) * r, z)


func _build_left_hand_grip(fl_pivot: Node3D) -> void:
	var skin := _hand_mat(Color(0.58, 0.42, 0.33), 0.62)
	skin.rim_enabled = true
	skin.rim = 0.25
	var skin_dark := _hand_mat(Color(0.5, 0.35, 0.27), 0.7)
	var jacket := _hand_mat(Color(0.17, 0.18, 0.2), 0.9)
	var cuff := _hand_mat(Color(0.11, 0.115, 0.13), 0.95)
	var hand := Node3D.new()
	hand.name = "LeftHand"
	fl_pivot.add_child(hand)
	# Четыре пальца: от костяшек слева, под корпусом, кончики выходят справа
	var fr := [0.0088, 0.0092, 0.009, 0.0078]
	for i in range(4):
		var z := -0.036 + float(i) * 0.019
		var r: float = fr[i]
		var path := 0.0175 + r + 0.001
		var p0 := _ring_point(168.0, path + 0.006, z + 0.004)
		var p1 := _ring_point(236.0, path, z)
		var p2 := _ring_point(296.0, path, z - 0.002)
		var p3 := _ring_point(344.0 - float(i) * 6.0, path - 0.001, z - 0.003)
		_seg(hand, p0, p1, r, skin)
		_seg(hand, p1, p2, r * 0.95, skin)
		_seg(hand, p2, p3, r * 0.88, skin)
		# Ноготь на кончике
		_blob(hand, p3 + Vector3(0.002, 0.004, 0.0), Vector3(0.006, 0.0025, 0.006), Vector3(0, 0, 30), skin_dark)
		# Костяшка
		_blob(hand, p0 + Vector3(-0.003, 0.002, 0.0), Vector3(0.008, 0.008, 0.009), Vector3.ZERO, skin)
	# Тыльная сторона кисти и ладонь: от костяшек назад к запястью
	_blob(hand, Vector3(-0.036, 0.0, 0.006), Vector3(0.017, 0.03, 0.05), Vector3(4, 8, -8), skin)
	_blob(hand, Vector3(-0.022, -0.02, 0.012), Vector3(0.022, 0.016, 0.044), Vector3(0, 6, 0), skin)
	# Большой палец: от основания ладони поверх корпуса вперёд
	var t0 := Vector3(-0.03, 0.018, 0.022)
	var t1 := Vector3(-0.014, 0.027, -0.004)
	var t2 := Vector3(0.0, 0.029, -0.03)
	var t3 := Vector3(0.006, 0.0275, -0.05)
	_seg(hand, t0, t1, 0.012, skin)
	_seg(hand, t1, t2, 0.0098, skin)
	_seg(hand, t2, t3, 0.0088, skin)
	_blob(hand, t3 + Vector3(0.0, 0.006, -0.002), Vector3(0.0065, 0.0025, 0.007), Vector3.ZERO, skin_dark)
	# Запястье и предплечье уходят в левый нижний угол экрана
	var wrist := Vector3(-0.045, -0.012, 0.062)
	var dir := Vector3(-0.42, -0.5, 1.0).normalized()
	_seg(hand, Vector3(-0.038, -0.006, 0.035), wrist, 0.021, skin)
	_seg(hand, wrist, wrist + dir * 0.05, 0.023, skin)
	# Рукав куртки с манжетой
	var c0 := wrist + dir * 0.03
	_seg(hand, c0, c0 + dir * 0.025, 0.031, cuff)
	_seg(hand, c0 + dir * 0.02, c0 + dir * 0.36, 0.04, jacket)
	for k in range(3):
		var at := c0 + dir * (0.07 + 0.08 * float(k))
		_blob(hand, at + Vector3(0, 0.004, 0), Vector3(0.043, 0.012, 0.043), Vector3.ZERO, jacket)


func _on_graphics_quality_changed(quality: String) -> void:
	var is_low = (quality == "low")
	var is_high := quality in ["ultra", "high"]
	_hotspot_energy = 5.2 if is_high else 4.5
	_spill_energy = 1.8 if is_high else 1.4
	if left_spot_light:
		left_spot_light.shadow_enabled = not is_low
		left_spot_light.shadow_blur = 1.4 if is_high else 1.0
		left_spot_light.light_volumetric_fog_energy = 1.1 if is_high else 1.8
	if left_spill_light:
		left_spill_light.visible = (left_spot_light and left_spot_light.visible and not is_low)

func set_flashlight_state(is_on: bool, energy_ratio: float = 1.0) -> void:
	var is_low = (GameManager.graphics_quality == "low") if GameManager else false
	if left_spot_light:
		left_spot_light.visible = is_on
		left_spot_light.light_energy = _hotspot_energy * energy_ratio
		left_spot_light.shadow_enabled = not is_low
	if left_spill_light:
		left_spill_light.visible = is_on and not is_low
		left_spill_light.light_energy = _spill_energy * energy_ratio
	if left_flashlight_lens and left_flashlight_lens.mesh:
		var mat = left_flashlight_lens.mesh.material
		if mat is StandardMaterial3D:
			mat.emission_enabled = is_on
			mat.emission_energy_multiplier = 3.2 * energy_ratio

	# Легкий тактильный щелчок/наклон кисти при переключении
	if left_arm_root and is_inside_tree():
		var tw = create_tween()
		tw.tween_property(left_arm_root, "rotation_degrees:x", -5.0, 0.05).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(left_arm_root, "rotation_degrees:x", 0.0, 0.09).set_trans(Tween.TRANS_QUAD)

# ══════════════════════════════════════════════════════════════════════════════
#  Правая рука — Выбранный предмет
# ══════════════════════════════════════════════════════════════════════════════
func _build_right_hand_item_holder() -> void:
	right_arm_root = Node3D.new()
	right_arm_root.name = "RightHandRoot"
	# По умолчанию рука опущена за экран
	right_arm_root.position = Vector3(right_base_pos.x, -0.65, right_base_pos.z)
	right_arm_root.visible = false
	add_child(right_arm_root)

	var arm_mesh = _build_arm_mesh_hierarchy(false)
	right_arm_root.add_child(arm_mesh)

	# Точка крепления предмета в ладони
	right_item_pivot = Node3D.new()
	right_item_pivot.name = "ItemPivot"
	if GameManager and GameManager.show_viewmodel_arms:
		right_item_pivot.position = Vector3(-0.012, 0.02, -0.05)
	else:
		right_item_pivot.position = Vector3(-0.02, 0.0, -0.05)
	right_arm_root.add_child(right_item_pivot)

func _on_active_item_changed(_idx: int, item_data: Dictionary) -> void:
	var item_id = str(item_data.get("id", "empty"))
	_set_held_item(item_id, item_data, true)

func _on_battery_changed(_new_cells: int) -> void:
	if current_held_item_id == "battery":
		var it = GameManager.get_active_item()
		if not it.is_empty():
			_set_held_item("battery", it, false)

func _set_held_item(item_id: String, item_data: Dictionary, animate: bool = true) -> void:
	current_held_item_id = item_id

	if switch_tween and switch_tween.is_valid():
		switch_tween.kill()

	if item_id == "" or item_id == "empty":
		# Если рука пуста — плавно опускаем её вниз за пределы экрана
		if animate and is_inside_tree() and right_arm_root.visible:
			is_switching_item = true
			switch_tween = create_tween()
			switch_tween.tween_property(right_arm_root, "position:y", -0.65, 0.18)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			switch_tween.tween_callback(func():
				right_arm_root.visible = false
				is_switching_item = false
				_clear_right_item_meshes()
			)
		else:
			right_arm_root.position.y = -0.65
			right_arm_root.visible = false
			_clear_right_item_meshes()
		return

	# Если предмет выбран — достаем руку
	right_arm_root.visible = true
	if animate and is_inside_tree():
		is_switching_item = true
		switch_tween = create_tween()
		if right_arm_root.position.y > -0.45:
			# Если рука уже была вверху — опускаем и меняем
			switch_tween.tween_property(right_arm_root, "position:y", -0.50, 0.12)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			switch_tween.tween_callback(func():
				_spawn_held_item_mesh(item_id, item_data)
			)
		else:
			_spawn_held_item_mesh(item_id, item_data)

		# Поднимаем руку с новым предметом в позицию готовности
		switch_tween.tween_property(right_arm_root, "position:y", right_base_pos.y, 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		switch_tween.tween_callback(func(): is_switching_item = false)
	else:
		_spawn_held_item_mesh(item_id, item_data)
		right_arm_root.position.y = right_base_pos.y

func _clear_right_item_meshes() -> void:
	if right_item_pivot:
		for ch in right_item_pivot.get_children():
			ch.queue_free()

func _spawn_held_item_mesh(item_id: String, item_data: Dictionary) -> void:
	_clear_right_item_meshes()
	if not right_item_pivot:
		return
	right_item_pivot.visible = true

	match item_id:
		"bottle":
			_create_bottle_mesh()
		"crowbar":
			_create_crowbar_mesh()
		"battery":
			_create_battery_mesh()
		"fuse_red", "fuse_blue", "fuse_green":
			var col = Color(1.0, 0.2, 0.2)
			if "blue" in item_id: col = Color(0.2, 0.6, 1.0)
			elif "green" in item_id: col = Color(0.2, 1.0, 0.3)
			_create_fuse_mesh(col)
		"note", "note_safe":
			_create_note_mesh()
		"road_flare":
			_create_flare_mesh()
		"alarm_clock", "prop_alarm_clock":
			_create_clock_mesh()
		"tv_remote", "prop_tv_remote", "remote":
			_create_remote_mesh()
		_:
			if item_id == "key" or item_id.begins_with("key"):
				var k_col = str(item_data.get("key_color", "gold"))
				_create_key_mesh(k_col, item_data)

# ══════════════════════════════════════════════════════════════════════════════
#  Анимация броска бутылки
# ══════════════════════════════════════════════════════════════════════════════
func play_throw_animation(release_callback: Callable = Callable()) -> void:
	if is_throwing:
		return
	is_throwing = true

	var tw = create_tween()
	# 1. Замах назад и вверх (0.08s)
	tw.tween_property(right_arm_root, "position", right_base_pos + Vector3(0.03, 0.07, 0.06), 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(right_arm_root, "rotation_degrees", Vector3(25.0, -10.0, 12.0), 0.08)

	# 2. Мощный бросок вперёд и вниз (0.09s)
	tw.chain().tween_property(right_arm_root, "position", right_base_pos + Vector3(-0.02, -0.05, -0.14), 0.09)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(right_arm_root, "rotation_degrees", Vector3(-42.0, 8.0, -12.0), 0.09)

	# В момент высвобождения бутылки: СКРЫВАЕМ бутылку из руки и запускаем физ. снаряд!
	tw.chain().tween_callback(func():
		if right_item_pivot:
			right_item_pivot.visible = false
		if release_callback.is_valid():
			release_callback.call()
	)

	# 3. Возврат руки
	tw.chain().tween_interval(0.10)
	tw.chain().tween_property(right_arm_root, "position:y", right_base_pos.y - 0.28, 0.14)
	tw.chain().tween_callback(func():
		if right_item_pivot:
			right_item_pivot.visible = true
		# Проверяем, остались ли еще бутылки в рюкзаке
		if GameManager.throwables_count > 0:
			var it = GameManager.get_active_item()
			_spawn_held_item_mesh("bottle", it)
		else:
			# Бутылки закончились! Рука убирается
			GameManager.set_active_backpack_slot(-1)
	)

	# Если бутылки остались — поднимаем руку обратно с новой бутылкой; если нет — убираем вниз
	tw.chain().tween_property(right_arm_root, "position",
		right_base_pos if GameManager.throwables_count > 0 else Vector3(right_base_pos.x, -0.65, right_base_pos.z), 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(right_arm_root, "rotation_degrees", Vector3.ZERO, 0.18)
	tw.chain().tween_callback(func():
		is_throwing = false
		if GameManager.throwables_count <= 0:
			right_arm_root.visible = false
	)

# ══════════════════════════════════════════════════════════════════════════════
#  3D Модели предметов в правой руке
# ══════════════════════════════════════════════════════════════════════════════
func _create_bottle_mesh() -> void:
	var b_root = Node3D.new()
	b_root.rotation_degrees = Vector3(15.0, 10.0, -15.0)

	var body = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.030
	cyl.bottom_radius = 0.033
	cyl.height = 0.15
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.45, 0.28, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.12
	mat.metallic = 0.1
	cyl.surface_set_material(0, mat)
	body.mesh = cyl
	b_root.add_child(body)

	var neck = MeshInstance3D.new()
	var nc = CylinderMesh.new()
	nc.top_radius = 0.013
	nc.bottom_radius = 0.015
	nc.height = 0.065
	nc.surface_set_material(0, mat)
	neck.mesh = nc
	neck.position = Vector3(0, 0.105, 0)
	b_root.add_child(neck)

	var cork = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.011
	cm.bottom_radius = 0.010
	cm.height = 0.02
	var cork_mat = StandardMaterial3D.new()
	cork_mat.albedo_color = Color(0.62, 0.48, 0.32)
	cm.surface_set_material(0, cork_mat)
	cork.mesh = cm
	cork.position = Vector3(0, 0.145, 0)
	b_root.add_child(cork)

	right_item_pivot.add_child(b_root)

func _create_crowbar_mesh() -> void:
	var cb_root = Node3D.new()
	cb_root.scale = Vector3(0.58, 0.58, 0.58)
	cb_root.rotation_degrees = Vector3(-16.0, -24.0, -16.0)
	cb_root.position = Vector3(0.03, -0.05, -0.02)
	# Модель лежит вдоль X: в руке она стоит лапой вверх
	var model = MeshInstance3D.new()
	model.mesh = HouseKit.crowbar_mesh()
	model.rotation_degrees.z = 90.0
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cb_root.add_child(model)
	right_item_pivot.add_child(cb_root)

func _create_key_mesh(color_key: String, item_data: Dictionary = {}) -> void:
	var k_root = Node3D.new()
	k_root.scale = Vector3(0.48, 0.48, 0.48)
	k_root.rotation_degrees = Vector3(15.0, 32.0, -12.0)
	k_root.position = Vector3(0.03, -0.04, -0.02)

	var kid = 1
	if item_data.has("key_id"):
		kid = int(item_data["key_id"])
	elif item_data.has("id") and str(item_data["id"]).begins_with("key_id_"):
		kid = int(str(item_data["id"]).substr(7))
	elif color_key == "silver":
		kid = 2
	elif color_key == "emerald":
		kid = 3
	elif color_key == "rusty":
		kid = 6

	var DoorScript = load("res://scripts/Door.gd")
	var th = DoorScript.get_lock_theme(kid)

	var mat = StandardMaterial3D.new()
	mat.albedo_color = th["color"]
	mat.metallic = th["metallic"]
	mat.roughness = th["roughness"]
	mat.emission_enabled = true
	mat.emission = th["emission"]
	mat.emission_energy_multiplier = 0.45

	# Цилиндрический стержень
	var shaft = MeshInstance3D.new()
	var sm = CylinderMesh.new()
	sm.top_radius = 0.007
	sm.bottom_radius = 0.007
	sm.height = 0.16
	sm.surface_set_material(0, mat)
	shaft.mesh = sm
	shaft.rotation_degrees.x = 90.0
	k_root.add_child(shaft)

	# Фигурная головка
	var bow = MeshInstance3D.new()
	var bm = TorusMesh.new()
	bm.inner_radius = 0.018
	bm.outer_radius = 0.035
	bm.surface_set_material(0, mat)
	bow.mesh = bm
	bow.rotation_degrees.x = 90.0
	bow.position = Vector3(0, 0, 0.08)
	k_root.add_child(bow)

	# Зубцы бородки
	var bit = MeshInstance3D.new()
	var bit_m = BoxMesh.new()
	bit_m.size = Vector3(0.006, 0.024, 0.036)
	bit_m.surface_set_material(0, mat)
	bit.mesh = bit_m
	bit.position = Vector3(0, -0.014, -0.060)
	k_root.add_child(bit)

	# Кольцо и брелок с номером
	var ring = MeshInstance3D.new()
	var rm = TorusMesh.new()
	rm.inner_radius = 0.010
	rm.outer_radius = 0.018
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.8, 0.8, 0.8)
	r_mat.metallic = 0.95
	r_mat.roughness = 0.2
	rm.surface_set_material(0, r_mat)
	ring.mesh = rm
	ring.position = Vector3(0, 0, 0.11)
	k_root.add_child(ring)

	var tag = MeshInstance3D.new()
	var tm = BoxMesh.new()
	tm.size = Vector3(0.045, 0.085, 0.006)
	var t_mat = StandardMaterial3D.new()
	t_mat.albedo_color = th["color"].lerp(Color(0.1, 0.1, 0.1), 0.3)
	t_mat.metallic = 0.8
	t_mat.roughness = 0.3
	tm.surface_set_material(0, t_mat)
	tag.mesh = tm
	tag.position = Vector3(0, -0.02, 0.15)
	tag.rotation_degrees = Vector3(15, 0, 0)
	k_root.add_child(tag)

	var num_lbl = Label3D.new()
	num_lbl.text = "№%d" % kid
	num_lbl.font_size = 28
	num_lbl.pixel_size = 0.0009
	num_lbl.outline_size = 4
	num_lbl.outline_modulate = Color(0, 0, 0, 1)
	num_lbl.modulate = Color(1, 1, 1, 1)
	num_lbl.position = Vector3(0, 0, 0.004)
	tag.add_child(num_lbl)

	right_item_pivot.add_child(k_root)

func _create_battery_mesh() -> void:
	var bat_root = Node3D.new()
	bat_root.rotation_degrees = Vector3(15.0, 0.0, 10.0)

	var cell = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.022
	cm.bottom_radius = 0.022
	cm.height = 0.11
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.15, 0.65, 0.25)
	b_mat.metallic = 0.6
	b_mat.roughness = 0.4
	cm.surface_set_material(0, b_mat)
	cell.mesh = cm
	cell.rotation_degrees.x = 90.0
	bat_root.add_child(cell)

	var cap = MeshInstance3D.new()
	var cap_m = CylinderMesh.new()
	cap_m.top_radius = 0.007
	cap_m.bottom_radius = 0.007
	cap_m.height = 0.012
	var gold_mat = StandardMaterial3D.new()
	gold_mat.albedo_color = Color(0.95, 0.82, 0.22)
	gold_mat.metallic = 0.95
	cap_m.surface_set_material(0, gold_mat)
	cap.mesh = cap_m
	cap.rotation_degrees.x = 90.0
	cap.position = Vector3(0, 0, -0.060)
	bat_root.add_child(cap)

	right_item_pivot.add_child(bat_root)

func _create_fuse_mesh(glow_color: Color) -> void:
	var f_root = Node3D.new()
	f_root.rotation_degrees = Vector3(20.0, -10.0, 15.0)

	var tube = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.015
	tm.bottom_radius = 0.015
	tm.height = 0.09
	var g_mat = StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.85, 0.92, 1.0, 0.45)
	g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g_mat.roughness = 0.1
	tm.surface_set_material(0, g_mat)
	tube.mesh = tm
	tube.rotation_degrees.x = 90.0
	f_root.add_child(tube)

	var core = MeshInstance3D.new()
	var c_mesh = CylinderMesh.new()
	c_mesh.top_radius = 0.005
	c_mesh.bottom_radius = 0.005
	c_mesh.height = 0.065
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = glow_color
	c_mat.emission_enabled = true
	c_mat.emission = glow_color
	c_mat.emission_energy_multiplier = 2.0
	c_mesh.surface_set_material(0, c_mat)
	core.mesh = c_mesh
	core.rotation_degrees.x = 90.0
	f_root.add_child(core)

	for offset_z in [-0.045, 0.045]:
		var cap = MeshInstance3D.new()
		var cap_m = CylinderMesh.new()
		cap_m.top_radius = 0.016
		cap_m.bottom_radius = 0.016
		cap_m.height = 0.015
		var cap_mat = StandardMaterial3D.new()
		cap_mat.albedo_color = Color(0.82, 0.85, 0.90)
		cap_mat.metallic = 0.95
		cap_m.surface_set_material(0, cap_mat)
		cap.mesh = cap_m
		cap.rotation_degrees.x = 90.0
		cap.position = Vector3(0, 0, offset_z)
		f_root.add_child(cap)

	right_item_pivot.add_child(f_root)

func _create_note_mesh() -> void:
	var n_root = Node3D.new()
	n_root.rotation_degrees = Vector3(25.0, -15.0, 20.0)

	var page = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(0.11, 0.004, 0.15)
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.92, 0.88, 0.74)
	p_mat.roughness = 0.9
	pm.surface_set_material(0, p_mat)
	page.mesh = pm
	n_root.add_child(page)

	right_item_pivot.add_child(n_root)

func _create_flare_mesh() -> void:
	var f_root = Node3D.new()
	f_root.rotation_degrees = Vector3(25.0, -10.0, 15.0)

	var tube = MeshInstance3D.new()
	var tm = CylinderMesh.new()
	tm.top_radius = 0.016
	tm.bottom_radius = 0.016
	tm.height = 0.16
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.85, 0.15, 0.10)
	r_mat.roughness = 0.4
	tm.surface_set_material(0, r_mat)
	tube.mesh = tm
	tube.rotation_degrees.x = 90.0
	f_root.add_child(tube)

	var cap = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.014
	cm.bottom_radius = 0.014
	cm.height = 0.02
	var s_mat = StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.7, 0.7, 0.75)
	s_mat.metallic = 0.9
	cm.surface_set_material(0, s_mat)
	cap.mesh = cm
	cap.rotation_degrees.x = 90.0
	cap.position = Vector3(0, 0, -0.09)
	f_root.add_child(cap)

	right_item_pivot.add_child(f_root)

func _create_clock_mesh() -> void:
	var c_root = Node3D.new()
	c_root.rotation_degrees = Vector3(15.0, -20.0, 10.0)
	c_root.scale = Vector3(0.55, 0.55, 0.55)

	var body = MeshInstance3D.new()
	var bm = CylinderMesh.new()
	bm.top_radius = 0.09
	bm.bottom_radius = 0.09
	bm.height = 0.06
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.20, 0.22, 0.26)
	b_mat.metallic = 0.7
	b_mat.roughness = 0.3
	bm.surface_set_material(0, b_mat)
	body.mesh = bm
	body.rotation_degrees.x = 90.0
	c_root.add_child(body)

	var dial = MeshInstance3D.new()
	var dm = CylinderMesh.new()
	dm.top_radius = 0.075
	dm.bottom_radius = 0.075
	dm.height = 0.005
	var d_mat = StandardMaterial3D.new()
	d_mat.albedo_color = Color(0.92, 0.90, 0.82)
	dm.surface_set_material(0, d_mat)
	dial.mesh = dm
	dial.rotation_degrees.x = 90.0
	dial.position = Vector3(0, 0, -0.032)
	c_root.add_child(dial)

	for bx in [-0.065, 0.065]:
		var bell = MeshInstance3D.new()
		var blm = SphereMesh.new()
		blm.radius = 0.026
		blm.height = 0.035
		var bl_mat = StandardMaterial3D.new()
		bl_mat.albedo_color = Color(0.85, 0.65, 0.20)
		bl_mat.metallic = 0.95
		bl_mat.roughness = 0.2
		blm.surface_set_material(0, bl_mat)
		bell.mesh = blm
		bell.position = Vector3(bx, 0.095, 0.0)
		c_root.add_child(bell)

	right_item_pivot.add_child(c_root)

func _create_remote_mesh() -> void:
	var r_root = Node3D.new()
	r_root.rotation_degrees = Vector3(25.0, -15.0, 10.0)

	var body = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.045, 0.018, 0.13)
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.12, 0.12, 0.14)
	b_mat.roughness = 0.7
	bm.surface_set_material(0, b_mat)
	body.mesh = bm
	r_root.add_child(body)

	var btn_pwr = MeshInstance3D.new()
	var pm = BoxMesh.new()
	pm.size = Vector3(0.012, 0.006, 0.012)
	var p_mat = StandardMaterial3D.new()
	p_mat.albedo_color = Color(0.9, 0.1, 0.1)
	pm.surface_set_material(0, p_mat)
	btn_pwr.mesh = pm
	btn_pwr.position = Vector3(-0.01, 0.010, -0.045)
	r_root.add_child(btn_pwr)

	right_item_pivot.add_child(r_root)
