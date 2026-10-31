extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  PlayerBody3D.gd — Тело и ноги персонажа от первого лица (Alpha 1.0)
#  • РЕАЛИЗМ (Alpha 1.0):
#    - Раздельный кинематический риг левой и правой ноги (player_leg_l, player_leg_r)
#    - Независимая походка в противофазе 180° (swing, lift, heel-strike, push-off)
#    - Отсутствие неестественного раскачивания всего тела ("соломка")
#    - Высококачественная фильтрация (TEXTURE_FILTER_LINEAR_WITH_MIPMAPS) и затенение
#    - Нижний край теплой куртки/рубашки (Jacket Hem) для заземления камеры
#    - Реалистичное дыхание в покое и плавная адаптация при приседе [Ctrl / C]
#  • LEGACY (Alpha 0.1):
#    - Классический монолитный 2D-спрайт с маятниковым покачиванием
# ══════════════════════════════════════════════════════════════════════════════

const TEX_PATH = "res://assets/textures/player_character/"

# ── Legacy Rig (Alpha 0.1) ──
var sprite_legs_legacy: Sprite3D
var tex_legs_idle:   Texture2D
var tex_legs_walk_0: Texture2D
var tex_legs_walk_1: Texture2D

# ── Realistic Rig (Alpha 1.0) ──
var realistic_root:    Node3D
var left_leg_pivot:    Node3D
var right_leg_pivot:   Node3D
var sprite_leg_l:      Sprite3D
var sprite_leg_r:      Sprite3D
var jacket_hem:        MeshInstance3D

var tex_leg_l:         Texture2D
var tex_leg_r:         Texture2D

var player_ref = null
var camera_ref: Camera3D = null

const LEGS_SHOW_PITCH: float = -20.0

var anim_t:         float = 0.0
var walk_cycle_t:   float = 0.0
var last_frame:     int = -1
var current_crouch: float = 0.0

func _ready() -> void:
	_load_textures()
	_build_legacy_sprites()
	_build_realistic_rig()

func _load_textures() -> void:
	tex_legs_idle   = _try_load(TEX_PATH + "player_legs.png")
	tex_legs_walk_0 = _try_load(TEX_PATH + "player_legs_walk_0.png")
	tex_legs_walk_1 = _try_load(TEX_PATH + "player_legs_walk_1.png")
	tex_leg_l       = _try_load(TEX_PATH + "player_leg_l.png")
	tex_leg_r       = _try_load(TEX_PATH + "player_leg_r.png")

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_legacy_sprites() -> void:
	sprite_legs_legacy = Sprite3D.new()
	sprite_legs_legacy.name = "LegsSpriteLegacy"
	sprite_legs_legacy.texture = tex_legs_idle
	sprite_legs_legacy.pixel_size = 0.00185
	sprite_legs_legacy.shaded = true
	sprite_legs_legacy.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite_legs_legacy.alpha_scissor_threshold = 0.2
	sprite_legs_legacy.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite_legs_legacy.double_sided = true
	sprite_legs_legacy.visible = false
	add_child(sprite_legs_legacy)

func _build_realistic_rig() -> void:
	realistic_root = Node3D.new()
	realistic_root.name = "RealisticLegsRig"
	realistic_root.visible = false
	add_child(realistic_root)

	# 1. Левая нога
	left_leg_pivot = Node3D.new()
	left_leg_pivot.name = "LeftLegPivot"
	left_leg_pivot.position = Vector3(-0.13, 0.0, 0.0)
	realistic_root.add_child(left_leg_pivot)

	sprite_leg_l = Sprite3D.new()
	sprite_leg_l.name = "SpriteLegL"
	sprite_leg_l.texture = tex_leg_l if tex_leg_l else tex_legs_idle
	sprite_leg_l.pixel_size = 0.00185
	sprite_leg_l.shaded = true
	sprite_leg_l.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite_leg_l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_leg_l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite_leg_l.double_sided = true
	sprite_leg_l.render_priority = 2
	# Смещение центра спрайта, чтобы точка вращения была в области тазобедренного сустава
	sprite_leg_l.offset = Vector2(0, -180)
	left_leg_pivot.add_child(sprite_leg_l)

	# 2. Правая нога
	right_leg_pivot = Node3D.new()
	right_leg_pivot.name = "RightLegPivot"
	right_leg_pivot.position = Vector3(0.13, 0.0, 0.0)
	realistic_root.add_child(right_leg_pivot)

	sprite_leg_r = Sprite3D.new()
	sprite_leg_r.name = "SpriteLegR"
	sprite_leg_r.texture = tex_leg_r if tex_leg_r else tex_legs_idle
	sprite_leg_r.pixel_size = 0.00185
	sprite_leg_r.shaded = true
	sprite_leg_r.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite_leg_r.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite_leg_r.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite_leg_r.double_sided = true
	sprite_leg_r.render_priority = 2
	sprite_leg_r.offset = Vector2(0, -180)
	right_leg_pivot.add_child(sprite_leg_r)

	# 3. Край походной куртки (Jacket Hem) для заземления тела
	jacket_hem = MeshInstance3D.new()
	jacket_hem.name = "JacketHem"
	var hem_mesh = BoxMesh.new()
	hem_mesh.size = Vector3(0.56, 0.12, 0.22)
	var j_mat = StandardMaterial3D.new()
	# Красно-черная ткань фланелевой куртки
	j_mat.albedo_color = Color(0.38, 0.14, 0.12)
	j_mat.roughness = 0.95
	j_mat.metallic = 0.02
	hem_mesh.material = j_mat
	jacket_hem.mesh = hem_mesh
	jacket_hem.position = Vector3(0.0, 0.48, 0.06)
	realistic_root.add_child(jacket_hem)

func setup(player: CharacterBody3D, camera: Camera3D) -> void:
	player_ref = player
	camera_ref = camera

# ──────────────────────────────────────────────────────────────────────────────
#  Обновление положения и походки ног
# ──────────────────────────────────────────────────────────────────────────────
func update_body(camera_pitch_deg: float, delta: float = 0.016, is_moving: bool = false, speed: float = 0.0, is_crouching: bool = false) -> void:
	var is_legacy = false
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("GameManager"):
		var gm = tree.root.get_node("GameManager")
		if gm and "is_legacy_graphics" in gm:
			is_legacy = bool(gm.is_legacy_graphics)

	# Если смотрим вперёд или вверх — ноги скрыты
	if camera_pitch_deg > LEGS_SHOW_PITCH:
		if sprite_legs_legacy: sprite_legs_legacy.visible = false
		if realistic_root: realistic_root.visible = false
		return

	if is_legacy:
		if realistic_root: realistic_root.visible = false
		_update_legacy(camera_pitch_deg, delta, is_moving, speed, is_crouching)
	else:
		if sprite_legs_legacy: sprite_legs_legacy.visible = false
		_update_realistic(camera_pitch_deg, delta, is_moving, speed, is_crouching)

# ──────────────────────────────────────────────────────────────────────────────
#  1. Реалистичная раздельная кинематика ног (Alpha 1.0)
# ──────────────────────────────────────────────────────────────────────────────
func _update_realistic(camera_pitch_deg: float, delta: float, is_moving: bool, speed: float, is_crouching: bool) -> void:
	if not realistic_root or not left_leg_pivot or not right_leg_pivot:
		return

	realistic_root.visible = true
	anim_t += delta

	# Плавная интерполяция приседа
	var target_crouch = 1.0 if is_crouching else 0.0
	current_crouch = lerpf(current_crouch, target_crouch, delta * 8.0)

	# Прогресс наклона взгляда от -20° до -85°
	var t = clamp((-camera_pitch_deg - 20.0) / 65.0, 0.0, 1.0)
	var tilt_deg = lerp(26.0, 46.0, t) + (current_crouch * 6.0)
	var tilt_rad = deg_to_rad(tilt_deg)

	var base_pos_y = lerp(0.66, 0.58, t) - (current_crouch * 0.28)
	var base_pos_z = lerp(-0.04, -0.09, t) + (current_crouch * 0.05)

	var is_sprint = speed > 4.5
	var hip_spread = lerp(0.13, 0.16, current_crouch)

	if is_moving and speed > 0.3:
		# Частота шагов пропорциональна скорости
		var step_freq = 6.4 if is_sprint else (3.4 if is_crouching else 4.6)
		walk_cycle_t += delta * step_freq

		# Фазы шага левой и правой ноги (строго 180° в противофазе!)
		var phase_l = walk_cycle_t * PI
		var phase_r = walk_cycle_t * PI + PI

		# Длина шага и подъем стопы
		var stride_len = 0.070 if is_sprint else (0.028 if is_crouching else 0.048)
		var lift_h = 0.045 if is_sprint else (0.016 if is_crouching else 0.032)

		# ── Левая нога ──
		var z_l = cos(phase_l) * stride_len
		var swing_l = maxf(0.0, sin(phase_l))
		var y_lift_l = pow(swing_l, 1.3) * lift_h
		var pitch_l = -sin(phase_l) * (deg_to_rad(12.0) if is_sprint else deg_to_rad(7.0))

		# ── Правая нога ──
		var z_r = cos(phase_r) * stride_len
		var swing_r = maxf(0.0, sin(phase_r))
		var y_lift_r = pow(swing_r, 1.3) * lift_h
		var pitch_r = -sin(phase_r) * (deg_to_rad(12.0) if is_sprint else deg_to_rad(7.0))

		# Естественное вертикальное покачивание таза (2 раза за полный цикл шага)
		var pelvis_bob = -abs(sin(walk_cycle_t * PI)) * (0.018 if is_sprint else (0.008 if is_crouching else 0.012))

		# Тончайший перенос веса таза (1-2 мм, без маятникового наклона соломки!)
		var hip_shift_x = sin(walk_cycle_t * PI) * 0.008

		# Применение трансформаций
		left_leg_pivot.position = Vector3(-hip_spread + hip_shift_x, base_pos_y + y_lift_l + pelvis_bob, base_pos_z + z_l)
		left_leg_pivot.rotation = Vector3(tilt_rad + pitch_l, 0.0, deg_to_rad(-1.5))

		right_leg_pivot.position = Vector3(hip_spread + hip_shift_x, base_pos_y + y_lift_r + pelvis_bob, base_pos_z + z_r)
		right_leg_pivot.rotation = Vector3(tilt_rad + pitch_r, 0.0, deg_to_rad(1.5))

		if jacket_hem:
			jacket_hem.position = Vector3(hip_shift_x * 0.5, base_pos_y + 0.16 + pelvis_bob * 0.5, base_pos_z + 0.06)
			jacket_hem.rotation = Vector3(tilt_rad * 0.4, 0.0, 0.0)
	else:
		# Покой: плавное дыхание и естественная стойка человека
		walk_cycle_t = 0.0
		var breathe = sin(anim_t * 2.0) * 0.005
		var subtle_shift = sin(anim_t * 0.8) * 0.003

		var cur_lp = left_leg_pivot.position
		var tgt_lp = Vector3(-hip_spread - subtle_shift, base_pos_y + breathe, base_pos_z - 0.01)
		left_leg_pivot.position = cur_lp.lerp(tgt_lp, delta * 9.0)
		left_leg_pivot.rotation = Vector3(tilt_rad, 0.0, deg_to_rad(-1.5))

		var cur_rp = right_leg_pivot.position
		var tgt_rp = Vector3(hip_spread - subtle_shift, base_pos_y + breathe, base_pos_z + 0.01)
		right_leg_pivot.position = cur_rp.lerp(tgt_rp, delta * 9.0)
		right_leg_pivot.rotation = Vector3(tilt_rad, 0.0, deg_to_rad(1.5))

		if jacket_hem:
			var tgt_jp = Vector3(0.0, base_pos_y + 0.16 + breathe * 0.7, base_pos_z + 0.06)
			jacket_hem.position = jacket_hem.position.lerp(tgt_jp, delta * 9.0)
			jacket_hem.rotation = Vector3(tilt_rad * 0.4, 0.0, 0.0)

# ──────────────────────────────────────────────────────────────────────────────
#  2. Классический ретро-режим ног (Alpha 0.1 Legacy)
# ──────────────────────────────────────────────────────────────────────────────
func _update_legacy(camera_pitch_deg: float, delta: float, is_moving: bool, speed: float, is_crouching: bool) -> void:
	if not sprite_legs_legacy:
		return

	sprite_legs_legacy.visible = true
	anim_t += delta

	var t = clamp((-camera_pitch_deg - 20.0) / 60.0, 0.0, 1.0)
	var tilt_deg = lerp(28.0, 48.0, t)
	var tilt_rad = deg_to_rad(tilt_deg)

	var base_pos_y = lerp(0.68, 0.60, t)
	var base_pos_z = lerp(-0.03, -0.07, t)

	if is_crouching:
		base_pos_y -= 0.30

	var is_sprint = speed > 4.5

	if is_moving and speed > 0.3:
		var anim_spd = 5.8 if is_sprint else (3.2 if is_crouching else 4.2)
		walk_cycle_t += delta * anim_spd

		var step_frame = int(walk_cycle_t) % 2
		if step_frame != last_frame:
			last_frame = step_frame
			if step_frame == 0:
				sprite_legs_legacy.texture = tex_legs_walk_0 if tex_legs_walk_0 else tex_legs_idle
			else:
				sprite_legs_legacy.texture = tex_legs_walk_1 if tex_legs_walk_1 else tex_legs_idle

		var step_bob = abs(sin(walk_cycle_t * PI)) * (0.045 if is_sprint else (0.018 if is_crouching else 0.032))
		var pos_y = base_pos_y - step_bob

		var step_sway = sin(walk_cycle_t * PI) * (0.035 if is_sprint else (0.012 if is_crouching else 0.022))
		var step_stride = cos(walk_cycle_t * PI) * (0.030 if is_sprint else 0.015)
		var pos_z = base_pos_z + step_stride

		sprite_legs_legacy.position = Vector3(0.0, pos_y, pos_z)
		sprite_legs_legacy.rotation = Vector3(tilt_rad, 0.0, step_sway)
	else:
		walk_cycle_t = 0.0
		last_frame = -1
		sprite_legs_legacy.texture = tex_legs_idle

		var breathe = sin(anim_t * 2.2) * 0.008
		sprite_legs_legacy.position = Vector3(0.0, base_pos_y + breathe, base_pos_z)
		sprite_legs_legacy.rotation = Vector3(tilt_rad, 0.0, lerp_angle(sprite_legs_legacy.rotation.z, 0.0, delta * 7.0))
