extends Node3D
# ══════════════════════════════════════════════════════════════════════════════
#  PlayerBody3D.gd — Тело персонажа от первого лица
#  • РЕАЛИЗМ: 3D-модель PlayerModel, видна только при взгляде вниз. Голова и руки
#    скрыты (руки в кадре — PlayerHands), тени нет: так тело не тратит кадры зря
#  • LEGACY (Alpha 0.1): классический 2D-спрайт с маятниковым покачиванием
# ══════════════════════════════════════════════════════════════════════════════

const TEX_PATH = "res://assets/textures/player_character/"

# ── Legacy Rig (Alpha 0.1) ──
var sprite_legs_legacy: Sprite3D
var tex_legs_idle:   Texture2D
var tex_legs_walk_0: Texture2D
var tex_legs_walk_1: Texture2D

# ── 3D-модель ──
var model: PlayerModel = null
var player_ref = null
var camera_ref: Camera3D = null

const LEGS_SHOW_PITCH: float = -20.0

var anim_t:         float = 0.0
var walk_cycle_t:   float = 0.0
var last_frame:     int = -1
var current_crouch: float = 0.0
var current_look:   float = 0.0

func _ready() -> void:
	_load_textures()
	_build_legacy_sprites()
	_build_model()

func _load_textures() -> void:
	tex_legs_idle   = _try_load(TEX_PATH + "player_legs.png")
	tex_legs_walk_0 = _try_load(TEX_PATH + "player_legs_walk_0.png")
	tex_legs_walk_1 = _try_load(TEX_PATH + "player_legs_walk_1.png")

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

func _build_model() -> void:
	model = PlayerModel.new()
	model.name = "PlayerModel"
	# Модель лицом вдоль +Z, игрок смотрит вдоль -Z. Масштаб ставит её глаза на высоту камеры
	model.rotation.y = PI
	model.scale = Vector3.ONE * (1.62 / PlayerModel.EYE_Y)
	model.set_first_person(true)
	add_child(model)
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
	var show_legs = camera_pitch_deg <= LEGS_SHOW_PITCH
	if model:
		model.visible = show_legs and not is_legacy
	if not show_legs or not is_legacy:
		if sprite_legs_legacy: sprite_legs_legacy.visible = false
	if not show_legs:
		return
	if is_legacy:
		_update_legacy(camera_pitch_deg, delta, is_moving, speed, is_crouching)
	else:
		_update_model(camera_pitch_deg, delta, is_moving, speed, is_crouching)

# ──────────────────────────────────────────────────────────────────────────────
#  1. 3D-модель: походка и положение относительно камеры
# ──────────────────────────────────────────────────────────────────────────────
func _update_model(camera_pitch_deg: float, delta: float, is_moving: bool, speed: float, is_crouching: bool) -> void:
	if not model:
		return
	current_crouch = lerpf(current_crouch, 1.0 if is_crouching else 0.0, minf(1.0, delta * 8.0))
	var mode := "idle"
	if is_crouching:
		mode = "crouch"
	elif is_moving:
		mode = "run" if speed > 4.8 else "walk"
	model.update_motion(delta, mode, speed if is_moving else 0.0)
	# Тело позади камеры: при взгляде вниз плечи и грудь не закрывают пол и ноги
	var down = clampf(-camera_pitch_deg / 80.0, 0.0, 1.0)
	model.position.z = lerpf(0.26 + down * 0.04, 0.66, current_crouch)

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
