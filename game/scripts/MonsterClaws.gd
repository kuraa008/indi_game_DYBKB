extends Node3D

# ─────────────────────────────────────────────────────────
#  MonsterClaws.gd
#  Процедурные когтистые лапы Скинвокера от 1-го лица.
#  Жуткие бледные хищные руки с длинными черными когтями.
#  Анимации: покачивание при шагах, хищное дыхание, удары [ЛКМ]/[E].
# ─────────────────────────────────────────────────────────

var left_arm: Node3D = null
var right_arm: Node3D = null

var left_rest_pos: Vector3 = Vector3(-0.32, -0.28, -0.46)
var right_rest_pos: Vector3 = Vector3(0.32, -0.28, -0.46)
var left_rest_rot: Vector3 = Vector3(deg_to_rad(12), deg_to_rad(15), deg_to_rad(-8))
var right_rest_rot: Vector3 = Vector3(deg_to_rad(12), deg_to_rad(-15), deg_to_rad(8))

var bob_t: float = 0.0
var breath_t: float = 0.0
var is_attacking: bool = false
var attack_side: int = 0 # 0 = left, 1 = right, 2 = both

var player_ref = null

func setup(player: CharacterBody3D) -> void:
	player_ref = player
	_build_arms()

func _build_arms() -> void:
	# Материал кожи монстра — трупно-бледный, пепельно-серый
	var skin_mat = StandardMaterial3D.new()
	skin_mat.albedo_color = Color(0.42, 0.44, 0.42)
	skin_mat.roughness = 0.85
	skin_mat.metallic = 0.05

	# Материал когтей — смоляно-черный острый кератин
	var claw_mat = StandardMaterial3D.new()
	claw_mat.albedo_color = Color(0.08, 0.06, 0.06)
	claw_mat.roughness = 0.3
	claw_mat.metallic = 0.4

	# ── Левая рука ──
	left_arm = _create_single_arm(false, skin_mat, claw_mat)
	left_arm.position = left_rest_pos
	left_arm.rotation = left_rest_rot
	add_child(left_arm)

	# ── Правая рука ──
	right_arm = _create_single_arm(true, skin_mat, claw_mat)
	right_arm.position = right_rest_pos
	right_arm.rotation = right_rest_rot
	add_child(right_arm)

func _create_single_arm(is_right: bool, skin_mat: Material, claw_mat: Material) -> Node3D:
	var arm_root = Node3D.new()

	# 1. Предплечье (длинное, худое)
	var forearm_mesh = CylinderMesh.new()
	forearm_mesh.top_radius = 0.038
	forearm_mesh.bottom_radius = 0.052
	forearm_mesh.height = 0.52
	forearm_mesh.radial_segments = 10
	forearm_mesh.material = skin_mat

	var forearm_inst = MeshInstance3D.new()
	forearm_inst.mesh = forearm_mesh
	forearm_inst.position = Vector3(0, 0, 0.22)
	forearm_inst.rotation.x = deg_to_rad(65)
	arm_root.add_child(forearm_inst)

	# 2. Кисть монстра
	var palm_mesh = BoxMesh.new()
	palm_mesh.size = Vector3(0.08, 0.035, 0.12)
	palm_mesh.material = skin_mat

	var palm_inst = MeshInstance3D.new()
	palm_inst.mesh = palm_mesh
	palm_inst.position = Vector3(0, 0.02, 0.0)
	arm_root.add_child(palm_inst)

	# 3. Четыре длинных смертоносных когтя
	var claw_offsets = [-0.032, -0.011, 0.011, 0.032]
	var claw_lengths = [0.11, 0.13, 0.13, 0.10]

	for i in range(4):
		var c_mesh = CylinderMesh.new()
		c_mesh.top_radius = 0.001
		c_mesh.bottom_radius = 0.010
		c_mesh.height = claw_lengths[i]
		c_mesh.radial_segments = 6
		c_mesh.material = claw_mat

		var c_inst = MeshInstance3D.new()
		c_inst.mesh = c_mesh
		# Позиция у основания кончиков пальцев
		c_inst.position = Vector3(claw_offsets[i], 0.01, -0.09)
		# Изогнуты вперед и слегка вниз как хищные когти
		var splay = claw_offsets[i] * 4.0
		c_inst.rotation = Vector3(deg_to_rad(-75), deg_to_rad(splay if is_right else -splay), 0)
		arm_root.add_child(c_inst)

	return arm_root

func _unhandled_input(event: InputEvent) -> void:
	if is_attacking:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		attack()
	elif event.is_action_pressed("interact"):
		attack()

func attack() -> void:
	if is_attacking or not is_instance_valid(left_arm) or not is_instance_valid(right_arm):
		return
	is_attacking = true

	var t = create_tween().set_parallel(true)
	if attack_side % 2 == 0:
		# Выпад левой когтистой лапой с диагональным рассекающим ударом
		t.tween_property(left_arm, "position", Vector3(-0.08, -0.16, -0.68), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(left_arm, "rotation", Vector3(deg_to_rad(28), deg_to_rad(-22), deg_to_rad(35)), 0.11)
		t.chain().tween_property(left_arm, "position", left_rest_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(left_arm, "rotation", left_rest_rot, 0.22)
	else:
		# Выпад правой когтистой лапой с диагональным рассекающим ударом
		t.tween_property(right_arm, "position", Vector3(0.08, -0.16, -0.68), 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(right_arm, "rotation", Vector3(deg_to_rad(28), deg_to_rad(22), deg_to_rad(-35)), 0.11)
		t.chain().tween_property(right_arm, "position", right_rest_pos, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(right_arm, "rotation", right_rest_rot, 0.22)

	attack_side += 1
	var recover_timer = get_tree().create_timer(0.33)
	recover_timer.timeout.connect(func(): is_attacking = false)

func _process(delta: float) -> void:
	if not is_instance_valid(left_arm) or not is_instance_valid(right_arm):
		return

	if is_attacking:
		return

	breath_t += delta * 2.8
	var speed = 0.0
	if is_instance_valid(player_ref):
		speed = Vector2(player_ref.velocity.x, player_ref.velocity.z).length()

	var is_moving = speed > 0.4
	if is_moving:
		bob_t += delta * clamp(speed * 1.8, 4.0, 11.0)
	else:
		bob_t = lerp(bob_t, 0.0, delta * 5.0)

	# Хищное дыхание лап (вверх-вниз и сжатие пальцев)
	var breath_y = sin(breath_t) * 0.008
	var breath_x = cos(breath_t * 0.5) * 0.004

	# Покачивание при шагах (тяжелая походка зверя)
	var bob_x = cos(bob_t * 0.5) * (0.016 if is_moving else 0.0)
	var bob_y = abs(sin(bob_t)) * (0.022 if is_moving else 0.0)

	var l_target = left_rest_pos + Vector3(breath_x + bob_x, breath_y - bob_y, 0)
	var r_target = right_rest_pos + Vector3(-breath_x - bob_x, breath_y - bob_y, 0)

	left_arm.position = lerp(left_arm.position, l_target, delta * 12.0)
	right_arm.position = lerp(right_arm.position, r_target, delta * 12.0)
