extends CharacterBody3D

# ══════════════════════════════════════════════════════════════════════════════
#  Lumberjack.gd — Персонаж «Лесопил»
#  • 4-ракурсная текстурированная 2.5D модель со спрайтами (front, back, left, right)
#    и процедурной анимацией шагов (как у скинвокера и игрока)
#  • ИИ с патрулированием СТРОГО внутри дома («где есть потолок и пол»)
#  • При обнаружении игрока останавливается, вскидывает ружье, целится и стреляет
#  • Открывает незапертые двери на своем пути
#  • Реалистичные звуки: шаги, взвод курка, выстрел двустволки, помпа перезарядки
# ══════════════════════════════════════════════════════════════════════════════

enum State { PATROL, INVESTIGATE, CHASE, AIMING, SHOOT, RELOAD, STAKEOUT_HIDING }
var current_state: State = State.PATROL
var stakeout_target_spot: Variant = null
var stakeout_timer: float = 0.0
var silence_timer: float = 0.0
var hiding_spot_cooldowns: Dictionary = {}

# ── Параметры перемещения ──
const WALK_SPEED: float = 1.68
const INVESTIGATE_SPEED: float = 2.22
const CHASE_SPEED: float = 3.37
const RELOAD_SPEED: float = 2.87
const GRAVITY: float = 18.0
const BASE_SPRITE_Y: float = 1.05

var nav_agent: NavigationAgent3D = null
var current_target_pos: Vector3 = Vector3.ZERO
var last_nav_target: Vector3 = Vector3.ZERO
var nav_repath_timer: float = 0.0
var wait_timer: float = 0.0
var stuck_timer: float = 0.0
var last_pos_for_stuck: Vector3 = Vector3.ZERO

# ── Маршрутные точки патрулирования (внутри дома и вокруг дома) ──
var indoor_anchors: Array[Vector3] = [
	Vector3(-6.0, 0.0, -8.0),   # Стартовый коридор
	Vector3(-12.0, 0.0, -6.0),  # Западная комната
	Vector3(-10.0, 0.0, 5.0),   # Юго-западная спальня
	Vector3(-2.0, 0.0, 1.0),    # Центральный зал особняка
	Vector3(5.0, 0.0, -12.0),   # Северо-восточная библиотека
	Vector3(7.0, 0.0, 6.5),     # Юго-восточная гостиная
	Vector3(11.0, 0.0, 3.0),    # Восточный коридор
	Vector3(-5.0, 0.0, 7.0),    # Южный коридор
	Vector3(0.0, 0.0, -8.0),    # Северный перекресток
	Vector3(-4.5, 0.0, -15.0),  # Западная спальня
	Vector3(-16.0, 0.0, 0.0),   # Западный двор / тропа
	Vector3(16.0, 0.0, 0.0),    # Восточный двор / сад
	Vector3(0.0, 0.0, 15.0),    # Южный двор / ворота
	Vector3(0.0, 0.0, -18.0),   # Северный задний двор
	Vector3(10.0, 0.0, 12.0),   # Угол вокруг дома
	Vector3(-12.0, 0.0, -14.0)  # Задний угол дома
]

# ── Стрельба, преследование и прицеливание ──
const AIM_DURATION: float = 0.35
const RELOAD_DURATION: float = 1.9
const SHOT_DAMAGE: float = 40.0
const SIGHT_MAX_DIST: float = 35.0
const MAX_SHOOT_RANGE: float = 30.0

var aim_timer: float = 0.0
var aim_lost_sight_timer: float = 0.0
var reload_timer: float = 0.0
var shotgun_loaded: bool = true
var melee_cooldown: float = 0.0
var chase_memory_timer: float = 0.0
var time_since_last_seen: float = 999.0
var last_known_player_pos: Vector3 = Vector3.ZERO
var player_in_sight: bool = false
var check_sight_timer: float = 0.0
var witnessed_hiding_spot: Variant = null
var _last_player_hidden: bool = false
var search_points: Array[Vector3] = []
var search_index: int = 0
var is_in_cutscene: bool = false

# ── 4-ракурсный направленный спрайт персонажа ──
var lumberjack_sprite: Sprite3D = null
var tex_front: Texture2D = null
var tex_front_walk_0: Texture2D = null
var tex_front_walk_1: Texture2D = null
var tex_back: Texture2D = null
var tex_back_walk_0: Texture2D = null
var tex_back_walk_1: Texture2D = null
var tex_left: Texture2D = null
var tex_left_walk_0: Texture2D = null
var tex_left_walk_1: Texture2D = null
var tex_right: Texture2D = null
var tex_right_walk_0: Texture2D = null
var tex_right_walk_1: Texture2D = null

var _current_view: String = "front"
var walk_cycle_t: float = 0.0
var last_step_phase: int = 0

# ── Спецэффекты оружия и свет ──
var muzzle_flash_light: OmniLight3D = null
var headlamp: SpotLight3D = null

# ── Аудио ──
var step_audio: AudioStreamPlayer3D = null
var gun_audio: AudioStreamPlayer3D = null
var voice_audio: AudioStreamPlayer3D = null
var breath_audio: AudioStreamPlayer3D = null
var creepy_sounds: Array[AudioStream] = []
var creepy_timer: float = 6.0

var sfx_shot: AudioStream = null
var sfx_cock: AudioStreamWAV = null
var sfx_pump: AudioStreamWAV = null
var sfx_step: AudioStreamWAV = null
var lumberjack_step_streams: Array[AudioStream] = []
var lumberjack_step_idx: int = 0
var sfx_grunt: AudioStreamWAV = null
var sfx_impact: AudioStreamWAV = null

# ── Реакция на свет фонарика игрока ──
var flashlight_suspicion_timer: float = 0.0
var is_blinded_by_light: bool = false
var has_warned_light: bool = false

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	name = "Lumberjack"
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(60.0)
	floor_constant_speed = true
	floor_block_on_wall = true
	max_slides = 6
	safe_margin = 0.03

	_generate_sound_effects()
	_load_textures()
	_build_collision()
	_build_visual_sprite()
	_setup_navigation()
	_setup_audio_players()

	if GameManager:
		GameManager.noise_made.connect(_on_noise_made)
		if GameManager.has_signal("door_state_changed"):
			GameManager.door_state_changed.connect(_on_door_altered)

	# Добавляем точку спавна в список патрульных комнат
	var my_spawn = global_position
	my_spawn.y = 0.0
	var found = false
	for a in indoor_anchors:
		if a.distance_to(my_spawn) < 1.0:
			found = true
			break
	if not found:
		indoor_anchors.append(my_spawn)

	# Первый выбор целевой комнаты внутри дома
	call_deferred("_pick_new_patrol_target")
	call_deferred("_discover_indoor_points")

func _build_collision() -> void:
	var col = CollisionShape3D.new()
	col.name = "Collision"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.90
	col.shape = cap
	col.position = Vector3(0, 0.95, 0)
	add_child(col)

func _load_textures() -> void:
	const DIR = "res://assets/textures/lumberjack/"
	tex_front        = _try_load(DIR + "lumberjack_front.png")
	tex_front_walk_0 = _try_load(DIR + "lumberjack_front_walk_0.png")
	tex_front_walk_1 = _try_load(DIR + "lumberjack_front_walk_1.png")

	tex_back         = _try_load(DIR + "lumberjack_back.png")
	tex_back_walk_0  = _try_load(DIR + "lumberjack_back_walk_0.png")
	tex_back_walk_1  = _try_load(DIR + "lumberjack_back_walk_1.png")

	tex_left         = _try_load(DIR + "lumberjack_left.png")
	tex_left_walk_0  = _try_load(DIR + "lumberjack_left_walk_0.png")
	tex_left_walk_1  = _try_load(DIR + "lumberjack_left_walk_1.png")

	tex_right        = _try_load(DIR + "lumberjack_right.png")
	tex_right_walk_0 = _try_load(DIR + "lumberjack_right_walk_0.png")
	tex_right_walk_1 = _try_load(DIR + "lumberjack_right_walk_1.png")

func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(ProjectSettings.globalize_path(path))
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null

func _build_visual_sprite() -> void:
	lumberjack_sprite = Sprite3D.new()
	lumberjack_sprite.name = "LumberjackSprite"
	lumberjack_sprite.texture = tex_front
	lumberjack_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# При высоте спрайта 1024px, pixel_size = 0.0022 дает рост персонажа ~2.0м в игре
	lumberjack_sprite.pixel_size = 0.0022
	lumberjack_sprite.position = Vector3(0, BASE_SPRITE_Y, 0)
	lumberjack_sprite.shaded = true
	lumberjack_sprite.double_sided = true
	lumberjack_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	lumberjack_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(lumberjack_sprite)

	# Налобный фонарик охотника — светит ярким желтым пучком вперед по направлению взгляда
	headlamp = SpotLight3D.new()
	headlamp.name = "Headlamp"
	headlamp.position = Vector3(0, 1.65, 0.15)
	headlamp.light_color = Color(1.0, 0.85, 0.18)
	headlamp.light_energy = 2.8
	headlamp.spot_range = 20.0
	headlamp.spot_angle = 38.0
	headlamp.spot_angle_attenuation = 0.85
	headlamp.shadow_enabled = true
	add_child(headlamp)

	var headlamp_glow = OmniLight3D.new()
	headlamp_glow.name = "HeadlampGlow"
	headlamp_glow.position = Vector3(0, 1.65, 0.2)
	headlamp_glow.light_color = Color(1.0, 0.82, 0.18)
	headlamp_glow.light_energy = 0.9
	headlamp_glow.omni_range = 2.2
	add_child(headlamp_glow)

	# Вспышка дула ружья (Muzzle Flash)
	muzzle_flash_light = OmniLight3D.new()
	muzzle_flash_light.name = "MuzzleFlash"
	muzzle_flash_light.position = Vector3(0, 1.25, -0.75)
	muzzle_flash_light.light_color = Color(1.0, 0.72, 0.28)
	muzzle_flash_light.light_energy = 0.0
	muzzle_flash_light.omni_range = 8.0
	muzzle_flash_light.shadow_enabled = true
	add_child(muzzle_flash_light)

func _setup_navigation() -> void:
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.40
	nav_agent.target_desired_distance = 0.80
	nav_agent.max_speed = 3.9
	add_child(nav_agent)

func _setup_audio_players() -> void:
	step_audio = AudioStreamPlayer3D.new()
	step_audio.name = "StepAudio"
	step_audio.max_distance = 24.0
	step_audio.unit_size = 4.0
	add_child(step_audio)

	gun_audio = AudioStreamPlayer3D.new()
	gun_audio.name = "GunAudio"
	gun_audio.max_distance = 45.0
	gun_audio.unit_size = 8.0
	add_child(gun_audio)

	voice_audio = AudioStreamPlayer3D.new()
	voice_audio.name = "VoiceAudio"
	voice_audio.max_distance = 32.0
	voice_audio.unit_size = 6.0
	add_child(voice_audio)

	# 3D тяжёлое дыхание деда (слышно сквозь стены и в коридорах)
	breath_audio = AudioStreamPlayer3D.new()
	breath_audio.name = "DedBreathAudio"
	var b_stream = load("res://assets/ded.mp3")
	if b_stream:
		if b_stream is AudioStreamMP3:
			(b_stream as AudioStreamMP3).loop = true
		breath_audio.stream = b_stream
		breath_audio.unit_size = 4.5
		breath_audio.max_distance = 28.0
		breath_audio.volume_db = -3.0
		breath_audio.autoplay = true
	add_child(breath_audio)

	_load_creepy_sounds()

func _load_creepy_sounds() -> void:
	creepy_sounds.clear()
	var sound_paths = [
		"res://assets/creepy_groan.mp3",
		"res://assets/creepy_mutter.mp3",
		"res://assets/creepy_laugh.mp3",
		"res://assets/creepy_whisper.mp3"
	]
	for p in sound_paths:
		if ResourceLoader.exists(p):
			var snd = load(p)
			if snd:
				creepy_sounds.append(snd)

func play_creepy_voice(specific_type: String = "") -> void:
	if not voice_audio or creepy_sounds.is_empty():
		return
	if voice_audio.playing:
		return

	var pick_snd: AudioStream = null
	match specific_type:
		"laugh":
			if ResourceLoader.exists("res://assets/creepy_laugh.mp3"):
				pick_snd = load("res://assets/creepy_laugh.mp3")
		"mutter":
			if ResourceLoader.exists("res://assets/creepy_mutter.mp3"):
				pick_snd = load("res://assets/creepy_mutter.mp3")
		"groan":
			if ResourceLoader.exists("res://assets/creepy_groan.mp3"):
				pick_snd = load("res://assets/creepy_groan.mp3")
		"whisper":
			if ResourceLoader.exists("res://assets/creepy_whisper.mp3"):
				pick_snd = load("res://assets/creepy_whisper.mp3")
		_:
			pick_snd = creepy_sounds.pick_random()

	if not pick_snd:
		pick_snd = creepy_sounds.pick_random()

	# «тем ближе тем громче звуки»: динамическая подстройка громкости в зависимости от расстояния до игрока
	var p = GameManager.player_ref if GameManager else null
	if p and is_instance_valid(p):
		var dist = global_position.distance_to(p.global_position)
		var prox = clampf(1.0 - dist / 30.0, 0.0, 1.0)
		voice_audio.volume_db = lerpf(-10.0, 5.0, prox)
		voice_audio.unit_size = lerpf(4.0, 8.5, prox)
	else:
		voice_audio.volume_db = 0.0

	voice_audio.stream = pick_snd
	voice_audio.pitch_scale = randf_range(0.92, 1.08)
	voice_audio.play()

# ══════════════════════════════════════════════════════════════════════════════
#  Проверка нахождения (свободное перемещение по всему дому и двору)
# ══════════════════════════════════════════════════════════════════════════════
func is_indoor(_pos: Vector3) -> bool:
	return true

# ══════════════════════════════════════════════════════════════════════════════
#  Физический цикл и ИИ
# ══════════════════════════════════════════════════════════════════════════════
func _physics_process(delta: float) -> void:
	if is_in_cutscene:
		velocity = Vector3.ZERO
		return

	if GameManager and GameManager.game_ended:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5

	# Периодическая проверка видимости игрока (каждые 0.1 сек)
	check_sight_timer -= delta
	if check_sight_timer <= 0.0:
		check_sight_timer = 0.10
		_update_player_line_of_sight()

	# Проверка освещения фонариком игрока
	_check_flashlight_illumination(delta)
	melee_cooldown = maxf(0.0, melee_cooldown - delta)

	# «тем ближе тем громче»: обновление громкости 3D дыхания деда
	if breath_audio:
		var p_ref = GameManager.player_ref if GameManager else null
		if is_instance_valid(p_ref):
			var dist = global_position.distance_to(p_ref.global_position)
			var prox = clampf(1.0 - dist / 26.0, 0.0, 1.0)
			breath_audio.volume_db = lerpf(-14.0, 3.5, prox)
			if current_state in [State.CHASE, State.AIMING]:
				breath_audio.pitch_scale = 1.25
			else:
				breath_audio.pitch_scale = 1.0

	# Периодические жуткие звуки деда (смех, бормотание, хрипы, шепот)
	creepy_timer -= delta
	if creepy_timer <= 0.0:
		creepy_timer = randf_range(8.0, 16.0)
		play_creepy_voice()

	# Проверка укрытия рядом при обычном патрулировании, поиске или погоне
	if current_state in [State.PATROL, State.INVESTIGATE, State.CHASE] and current_state != State.STAKEOUT_HIDING:
		var p_node = GameManager.player_ref
		if p_node and is_instance_valid(p_node) and p_node.get("is_hiding") == true:
			var spot_node = p_node.get("hiding_node")
			if is_instance_valid(spot_node) and spot_node is Node3D:
				var s_dist = global_position.distance_to(spot_node.global_position)
				var now_sec = Time.get_ticks_msec() * 0.001
				var s_cd = float(hiding_spot_cooldowns.get(spot_node.get_instance_id(), 0.0))
				if s_dist <= 3.2 and (current_state == State.CHASE or now_sec >= s_cd):
					if witnessed_hiding_spot == spot_node:
						current_state = State.CHASE
					else:
						stakeout_target_spot = spot_node
						stakeout_timer = 0.0
						silence_timer = 0.0
						current_state = State.STAKEOUT_HIDING
						_play_sound(sfx_grunt, voice_audio, 0.5, 0.85)

	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.INVESTIGATE:
			_process_investigate(delta)
		State.CHASE:
			_process_chase(delta)
		State.AIMING:
			_process_aiming(delta)
		State.SHOOT:
			_process_shoot(delta)
		State.RELOAD:
			_process_reload(delta)
		State.STAKEOUT_HIDING:
			_process_stakeout_hiding(delta)

	_animate(delta)
	_try_step(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	_check_close_melee()

func _try_step(motion: Vector3) -> void:
	if motion.length() < 0.001:
		return
	if not test_move(global_transform, motion):
		return
	# Если перед персонажем ступенька, порог или подъем лестницы — шагаем вверх
	for height in [0.12, 0.22, 0.35, 0.48, 0.55]:
		var lift: Vector3 = Vector3.UP * float(height)
		var raised := global_transform.translated(lift)
		if not test_move(global_transform, lift) and not test_move(raised, motion.normalized() * 0.25):
			move_and_collide(lift)
			return

# ── Проверка принадлежности коллайдера игроку ──
func _is_player_collider(col: Object, player: Node) -> bool:
	if not is_instance_valid(col):
		return false
	if col == player or col.get_parent() == player or player.is_ancestor_of(col) or (col is Node and col.is_ancestor_of(player)):
		return true
	var p_parent = player.get_parent()
	if p_parent and (col == p_parent or p_parent.is_ancestor_of(col)):
		return true
	var nm = col.name.to_lower()
	if nm == "player" or "playerbody" in nm or "hitbox" in nm:
		return true
	return false

# ── Проверка прямой видимости игрока ──
func _update_player_line_of_sight() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player) or player.get("is_dead") == true:
		player_in_sight = false
		return

	var hidden: bool = player.get("is_hiding") == true
	if hidden and not _last_player_hidden and time_since_last_seen < 1.5:
		var spot: Variant = player.get("hiding_node")
		if is_instance_valid(spot):
			witnessed_hiding_spot = spot
	_last_player_hidden = hidden

	# Игрок спрятан в шкафу или под кроватью — прямой видимости нет
	if hidden:
		player_in_sight = false
		return

	var head_pos = global_position + Vector3(0, 1.65, 0)
	var p_center = player.global_position + Vector3(0, 1.15, 0)
	var dist = head_pos.distance_to(p_center)

	if dist > SIGHT_MAX_DIST:
		player_in_sight = false
		return

	# Угол обзора при спокойном патрулировании
	var to_player = p_center - head_pos
	var forward = -global_transform.basis.z
	var to_player_flat = Vector2(to_player.x, to_player.z)
	var forward_flat = Vector2(forward.x, forward.z)

	if current_state == State.PATROL and to_player_flat.length_squared() > 0.001 and forward_flat.length_squared() > 0.001:
		var h_angle_deg = rad_to_deg(abs(forward_flat.angle_to(to_player_flat)))
		if h_angle_deg > 85.0:
			player_in_sight = false
			return

	var space = get_world_3d().direct_space_state
	if not space:
		player_in_sight = false
		return

	var target_points: Array[Vector3] = [
		player.global_position + Vector3(0, 1.65, 0),
		player.global_position + Vector3(0, 1.15, 0),
		player.global_position + Vector3(0, 0.65, 0),
		player.global_position + Vector3(0, 0.25, 0)
	]

	var my_rid = get_rid()
	var spotted_point: Variant = null

	for tp in target_points:
		var dir = (tp - head_pos).normalized()
		var start_pt = head_pos + dir * 0.10
		var query = PhysicsRayQueryParameters3D.create(start_pt, tp + dir * 0.85)
		query.exclude = [my_rid]
		query.collision_mask = 1 | 2
		query.collide_with_areas = false
		var hit = space.intersect_ray(query)

		if not hit.is_empty():
			if _is_player_collider(hit.collider, player):
				spotted_point = tp
				break
			# Проверяем сквозь открытую дверь
			var col = hit.collider
			if col and (col.get("is_open") == true or (col.get_parent() and col.get_parent().get("is_open") == true)):
				var pass_query = PhysicsRayQueryParameters3D.create(hit.position + dir * 0.15, tp + dir * 0.85)
				var pass_exclude: Array[RID] = [my_rid]
				if col is CollisionObject3D:
					pass_exclude.append(col.get_rid())
				pass_query.exclude = pass_exclude
				pass_query.collision_mask = 1 | 2
				pass_query.collide_with_areas = false
				var pass_hit = space.intersect_ray(pass_query)
				if not pass_hit.is_empty() and _is_player_collider(pass_hit.collider, player):
					spotted_point = tp
					break

	if spotted_point != null:
		_on_player_spotted(spotted_point)
	else:
		player_in_sight = false

func _on_player_spotted(p_pos: Vector3) -> void:
	player_in_sight = true
	last_known_player_pos = p_pos
	time_since_last_seen = 0.0
	chase_memory_timer = 9.0

	# При обнаружении игрока лесопил начинает активную ПОГОНЮ!
	if current_state in [State.PATROL, State.INVESTIGATE]:
		current_state = State.CHASE
		_set_nav_target(p_pos)
		_play_sound(sfx_cock, gun_audio, 1.0)
		play_creepy_voice("laugh")

# ── Логика состояний ──
func _process_patrol(delta: float) -> void:
	if player_in_sight:
		return

	if is_blinded_by_light:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		return

	if wait_timer > 0.0:
		wait_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		return

	_navigate_towards_target(WALK_SPEED, delta)
	_check_stuck(delta)

	var dist_to_target = global_position.distance_to(current_target_pos)
	if dist_to_target < 1.3:
		wait_timer = randf_range(1.5, 3.0)
		_pick_new_patrol_target()
	elif nav_agent and nav_agent.is_navigation_finished() and dist_to_target > 2.5:
		_pick_new_patrol_target()

func _process_investigate(delta: float) -> void:
	if player_in_sight:
		return

	if is_blinded_by_light:
		velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
		return

	_navigate_towards_target(INVESTIGATE_SPEED, delta)
	_check_stuck(delta)

	if global_position.distance_to(current_target_pos) < 1.3 or (nav_agent and nav_agent.is_navigation_finished()):
		if not search_points.is_empty():
			search_index += 1
			if search_index < search_points.size():
				_set_nav_target(search_points[search_index])
				return
		wait_timer = randf_range(1.5, 3.0)
		current_state = State.PATROL
		_pick_new_patrol_target()

# ── Активное преследование (ПОГОНЯ КАК У СКИНВОКЕРА) ──
func _process_chase(delta: float) -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player) or player.get("is_dead") == true:
		current_state = State.PATROL
		_pick_new_patrol_target()
		return

	# Если лесопил видел, как игрок спрятался в шкаф или под кровать
	if is_instance_valid(witnessed_hiding_spot):
		_approach_and_inspect_hiding(delta)
		return

	# Если игрок спрятался рядом (в шкафу/под кроватью) — мгновенно начинаем прислушиваться без задержки!
	if player.get("is_hiding") == true:
		var spot_node = player.get("hiding_node")
		if is_instance_valid(spot_node) and spot_node is Node3D:
			var s_dist = global_position.distance_to(spot_node.global_position)
			if s_dist <= 3.2:
				stakeout_target_spot = spot_node
				stakeout_timer = 0.0
				silence_timer = 0.0
				current_state = State.STAKEOUT_HIDING
				_play_sound(sfx_grunt, voice_audio, 0.5, 0.85)
				return

	if player_in_sight:
		last_known_player_pos = player.global_position
		time_since_last_seen = 0.0
		chase_memory_timer = 10.0
	else:
		time_since_last_seen += delta
		chase_memory_timer -= delta

	var dist = global_position.distance_to(player.global_position)

	# ПРОВЕРКА ВОЗМОЖНОСТИ ВЫСТРЕЛА:
	# Если игрок в поле зрения, ружье заряжено и есть прямая линия огня:
	# СТРЕЛЯЕМ! В том числе когда цель далеко (до MAX_SHOOT_RANGE = 30м)!
	if player_in_sight and shotgun_loaded and dist <= MAX_SHOOT_RANGE and has_clear_shot_to_player():
		current_state = State.AIMING
		aim_timer = AIM_DURATION
		aim_lost_sight_timer = 0.0
		_play_sound(sfx_cock, gun_audio, -1.0)
		return

	# Обновляем навигационную цель к игроку каждые 0.15 сек
	nav_repath_timer -= delta
	if nav_repath_timer <= 0.0 or global_position.distance_to(last_nav_target) > 1.0:
		nav_repath_timer = 0.15
		_set_nav_target(last_known_player_pos)

	# Быстрое и неумолимое преследование
	_navigate_towards_target(CHASE_SPEED, delta)
	_check_stuck(delta)

	# Если потерял игрока из виду и добежал до последней точки
	if not player_in_sight:
		var reached_last = global_position.distance_to(last_known_player_pos) < 1.4
		if chase_memory_timer <= 0.0 or (reached_last and (nav_agent and nav_agent.is_navigation_finished())):
			current_state = State.INVESTIGATE
			_pick_search_points_near(last_known_player_pos)
			_play_sound(sfx_grunt, voice_audio, 1.0)

func _approach_and_inspect_hiding(delta: float) -> void:
	if not is_instance_valid(witnessed_hiding_spot):
		witnessed_hiding_spot = null
		current_state = State.PATROL
		return

	var spot_pos = witnessed_hiding_spot.global_position
	_set_nav_target(spot_pos)
	_navigate_towards_target(CHASE_SPEED, delta)

	if global_position.distance_to(spot_pos) < 2.8:
		velocity = Vector3.ZERO
		_look_towards(spot_pos, 1.0)
		_fire_shotgun()
		var player = GameManager.player_ref
		if player and is_instance_valid(player) and player.get("is_hiding") == true and player.get("hiding_node") == witnessed_hiding_spot:
			if player.has_method("exit_hiding"):
				player.call("exit_hiding")
			if player.has_method("die") and not GameManager.is_godmode:
				player.call("die", self)
		witnessed_hiding_spot = null
		shotgun_loaded = false
		current_state = State.RELOAD
		reload_timer = RELOAD_DURATION

func _process_stakeout_hiding(delta: float) -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player) or player.get("is_dead") == true or player.get("is_hiding") != true or not is_instance_valid(stakeout_target_spot) or player.get("hiding_node") != stakeout_target_spot:
		stakeout_target_spot = null
		current_state = State.PATROL
		_pick_new_patrol_target()
		return

	velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)

	_look_towards(stakeout_target_spot.global_position, delta * 8.0)

	var is_holding: bool = player.has_method("is_breath_held") and bool(player.call("is_breath_held"))
	if is_holding:
		silence_timer += delta
		stakeout_timer = maxf(0.0, stakeout_timer - delta * 0.5)
		if silence_timer >= 2.8:
			# Игрок задержал дыхание — лесопил решает, что укрытие пустое, и уходит по ДРУГОМУ маршруту!
			hiding_spot_cooldowns[stakeout_target_spot.get_instance_id()] = Time.get_ticks_msec() * 0.001 + 35.0
			stakeout_target_spot = null
			current_state = State.PATROL
			_pick_distant_patrol_target(14.0)
			return
	else:
		silence_timer = 0.0
		stakeout_timer += delta
		rotation.y += sin(Time.get_ticks_msec() * 0.003) * delta * 0.35
		if stakeout_timer >= 5.0:
			# Услышал дыхание — вскидывает ружье, стреляет в укрытие и убивает игрока!
			var target_spot = stakeout_target_spot
			stakeout_target_spot = null
			witnessed_hiding_spot = null
			_look_towards(target_spot.global_position, 1.0)
			_fire_shotgun()
			if player.has_method("exit_hiding"):
				player.call("exit_hiding")
			if player.has_method("die") and not GameManager.is_godmode:
				player.call("die", self)
			shotgun_loaded = false
			current_state = State.RELOAD
			reload_timer = RELOAD_DURATION
			return

func _pick_distant_patrol_target(min_dist: float = 14.0) -> void:
	var candidates: Array[Vector3] = []
	for anchor in indoor_anchors:
		if global_position.distance_to(anchor) >= min_dist:
			candidates.append(anchor)
	if not candidates.is_empty():
		_set_nav_target(candidates.pick_random())
	else:
		_pick_new_patrol_target()

func has_clear_shot_to_player() -> bool:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player) or player.get("is_dead") == true or player.get("is_hiding") == true:
		return false

	var space = get_world_3d().direct_space_state
	if not space:
		return false

	var my_rid = get_rid()
	var chest_pos = global_position + Vector3(0, 1.45, 0)
	var right_vec = global_transform.basis.x

	# Проверяем несколько ключевых точек на теле игрока (голова, грудь, пояс, плечи)
	var p_pos = player.global_position
	var target_points: Array[Vector3] = [
		p_pos + Vector3(0, 1.45, 0),                       # Грудь / шея
		p_pos + Vector3(0, 1.70, 0),                       # Голова
		p_pos + Vector3(0, 0.90, 0),                       # Пояс
		p_pos + Vector3(0, 1.30, 0) + right_vec * 0.28,    # Правое плечо
		p_pos + Vector3(0, 1.30, 0) - right_vec * 0.28     # Левое плечо
	]

	for tp in target_points:
		var dir = (tp - chest_pos).normalized()
		var start_pt = chest_pos + dir * 0.15
		var end_pt = tp + dir * 0.85
		var query = PhysicsRayQueryParameters3D.create(start_pt, end_pt)
		query.exclude = [my_rid]
		query.collision_mask = 1 | 2 # Стены (1) и персонажи (2)
		query.collide_with_areas = false
		var hit = space.intersect_ray(query)

		if not hit.is_empty():
			var col = hit.collider
			if _is_player_collider(col, player):
				return true
			# Если луч встретил открытую дверь — проверяем сквозь неё дальше
			if col and (col.get("is_open") == true or (col.get_parent() and col.get_parent().get("is_open") == true)):
				var pass_query = PhysicsRayQueryParameters3D.create(hit.position + dir * 0.15, end_pt)
				var pass_exclude: Array[RID] = [my_rid]
				if col is CollisionObject3D:
					pass_exclude.append(col.get_rid())
				pass_query.exclude = pass_exclude
				pass_query.collision_mask = 1 | 2
				pass_query.collide_with_areas = false
				var pass_hit = space.intersect_ray(pass_query)
				if not pass_hit.is_empty() and _is_player_collider(pass_hit.collider, player):
					return true

	return false

func _process_aiming(delta: float) -> void:
	# Плавное торможение перед выстрелом с удержанием цели
	velocity.x = move_toward(velocity.x, 0.0, delta * 12.0)
	velocity.z = move_toward(velocity.z, 0.0, delta * 12.0)

	var player = GameManager.player_ref
	if not player or not is_instance_valid(player) or player.get("is_dead") == true or player.get("is_hiding") == true:
		current_state = State.PATROL
		_pick_new_patrol_target()
		return

	# Поворот лицом к игроку
	_look_towards(player.global_position, delta * 16.0)

	# Если игрок скрылся за капитальной стеной — даем буфер 0.45с, чтобы мелкие препятствия не срывали выстрел издалека
	if not has_clear_shot_to_player():
		aim_lost_sight_timer += delta
		if aim_lost_sight_timer >= 0.45:
			current_state = State.CHASE
			_set_nav_target(last_known_player_pos)
			return
	else:
		aim_lost_sight_timer = 0.0

	aim_timer -= delta
	if aim_timer <= 0.0:
		current_state = State.SHOOT

func _process_shoot(_delta: float) -> void:
	_fire_shotgun()
	shotgun_loaded = false
	current_state = State.RELOAD
	reload_timer = RELOAD_DURATION

func _process_reload(delta: float) -> void:
	reload_timer -= delta

	# ВО ВРЕМЯ ПЕРЕЗАРЯДКИ ЛЕСОПИЛ НЕ СТОИТ, А ПРОДОЛЖАЕТ ПРЕСЛЕДОВАТЬ ИГРОКА!
	var player = GameManager.player_ref
	if player and is_instance_valid(player) and player.get("is_dead") != true:
		if player_in_sight:
			last_known_player_pos = player.global_position
		_set_nav_target(last_known_player_pos)
		_navigate_towards_target(RELOAD_SPEED, delta)
	else:
		_navigate_towards_target(INVESTIGATE_SPEED, delta)

	# Звук помпы/досылания патрона
	if reload_timer <= (RELOAD_DURATION * 0.5) and reload_timer > (RELOAD_DURATION * 0.5 - delta):
		_play_sound(sfx_pump, gun_audio, -2.0)

	if reload_timer <= 0.0:
		shotgun_loaded = true
		_play_sound(sfx_cock, gun_audio, -1.0)
		var dist = global_position.distance_to(last_known_player_pos)
		if player_in_sight and dist <= MAX_SHOOT_RANGE and has_clear_shot_to_player():
			current_state = State.AIMING
			aim_timer = 0.30
			aim_lost_sight_timer = 0.0
		else:
			current_state = State.CHASE

func _check_close_melee() -> void:
	if GameManager and (GameManager.game_ended or GameManager.is_godmode):
		return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player) or player.get("is_dead") == true or player.get("is_hiding") == true:
		return

	var dist = global_position.distance_to(player.global_position)
	if dist <= 1.4 and melee_cooldown <= 0.0:
		melee_cooldown = 1.15
		_play_sound(sfx_grunt, voice_audio, 2.0, randf_range(0.9, 1.1))
		if player.has_method("take_damage"):
			player.call("take_damage", 25.0, self)
		if player is CharacterBody3D:
			var push_dir = (player.global_position - global_position).normalized()
			push_dir.y = 0.0
			player.velocity += push_dir * 4.5

# ── Выстрел из ружья ──
func _fire_shotgun() -> void:
	# 1. Громкий звук выстрела
	_play_sound(sfx_shot, gun_audio, 4.0)

	# 2. Вспышка пороховых газов
	if muzzle_flash_light:
		muzzle_flash_light.light_energy = 6.0
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(muzzle_flash_light):
			muzzle_flash_light.light_energy = 0.0
	)

	# 3. Шум выстрела привлекает скинвокера и слышен по всему дому
	if GameManager:
		GameManager.emit_noise(global_position, 42.0, "gunshot")

	# 4. Выстрел видимыми летящими снарядами картечи (шлейф + подсветка + искры)
	var chest_pos = global_position + Vector3(0, 1.45, 0)
	var forward_dir = -global_transform.basis.z
	var muzzle_offset = forward_dir * 0.30
	var space = get_world_3d().direct_space_state
	var barrel_pos = chest_pos + muzzle_offset
	if space:
		var m_query = PhysicsRayQueryParameters3D.create(chest_pos, chest_pos + forward_dir * 0.60)
		m_query.exclude = [get_rid()]
		m_query.collision_mask = 1
		var m_hit = space.intersect_ray(m_query)
		if not m_hit.is_empty():
			barrel_pos = m_hit.position - forward_dir * 0.05

	var player = GameManager.player_ref
	var base_target = global_position - global_transform.basis.z * 10.0 + Vector3(0, 1.25, 0)
	if player and is_instance_valid(player):
		base_target = player.global_position + Vector3(0, 1.15, 0)

	var aim_dir = (base_target - barrel_pos).normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = -global_transform.basis.z

	var tree_root = get_tree().current_scene if get_tree() else get_parent()
	if not tree_root:
		tree_root = get_parent()

	# Спавним 5 видимых светящихся дробинок с легким конусом разброса
	var pellet_damage = 18.0
	for i in range(5):
		var spread_dir = aim_dir
		if i > 0:
			var spread_x = randf_range(-0.045, 0.045)
			var spread_y = randf_range(-0.035, 0.035)
			var right_vec = global_transform.basis.x
			var up_vec = global_transform.basis.y
			spread_dir = (aim_dir + right_vec * spread_x + up_vec * spread_y).normalized()

		var pellet = ShotgunPellet.new()
		tree_root.add_child(pellet)
		pellet.setup(barrel_pos, spread_dir, 65.0, self, pellet_damage, (i == 0))

# ── Навигация и открытие дверей ──
func _set_nav_target(target: Vector3) -> void:
	current_target_pos = target
	last_nav_target = target
	if nav_agent:
		var space = get_world_3d()
		if space:
			var map = space.navigation_map
			if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
				var snapped = NavigationServer3D.map_get_closest_point(map, target)
				if snapped.distance_to(target) < 4.0:
					target = snapped
		nav_agent.target_position = target

func _navigate_towards_target(speed: float, delta: float) -> void:
	var move_dir := Vector3.ZERO
	var target_y := global_position.y

	if nav_agent and not nav_agent.is_navigation_finished():
		var next_nav = nav_agent.get_next_path_position()
		target_y = next_nav.y
		move_dir = next_nav - global_position
		move_dir.y = 0.0

	# Страховочный вектор к цели, если навигация временно пересчитывается
	if move_dir.length_squared() < 0.01 and current_target_pos != Vector3.ZERO and global_position.distance_to(current_target_pos) > 0.8:
		target_y = current_target_pos.y
		move_dir = current_target_pos - global_position
		move_dir.y = 0.0

	if move_dir.length_squared() > 0.01:
		move_dir = move_dir.normalized()

		# Проверяем препятствие перед собой: если это ступени лестницы — НЕ объезжаем, а шагаем вверх!
		if test_move(global_transform, move_dir * 0.40):
			var is_stair := false
			for h in [0.18, 0.32, 0.48]:
				var lift: Vector3 = Vector3.UP * float(h)
				var raised := global_transform.translated(lift)
				if not test_move(global_transform, lift) and not test_move(raised, move_dir * 0.35):
					is_stair = true
					break
			if not is_stair:
				for angle in [0.55, -0.55, 1.1, -1.1, 1.6, -1.6]:
					var alt = move_dir.rotated(Vector3.UP, angle)
					if not test_move(global_transform, alt * 0.45):
						move_dir = alt
						break

		# Помощь при подъеме по лестницам: если навигационная точка выше персонажа
		if target_y > global_position.y + 0.15:
			if is_on_floor() or is_on_wall():
				velocity.y = maxf(velocity.y, speed * 0.85)

		velocity.x = move_toward(velocity.x, move_dir.x * speed, delta * 18.0)
		velocity.z = move_toward(velocity.z, move_dir.z * speed, delta * 18.0)
		_look_towards(global_position + move_dir, delta * 9.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 10.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 10.0)

	_check_and_open_doors(move_dir)

func _check_stuck(delta: float) -> void:
	stuck_timer += delta
	if stuck_timer >= 1.8:
		stuck_timer = 0.0
		if global_position.distance_to(last_pos_for_stuck) < 0.30:
			if current_state == State.PATROL:
				_pick_new_patrol_target()
			elif current_state == State.CHASE:
				nav_repath_timer = 0.0
				velocity += Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized() * 1.5
		last_pos_for_stuck = global_position

func _check_and_open_doors(move_direction: Vector3 = Vector3.ZERO) -> void:
	var check_dir = move_direction
	if check_dir.length_squared() < 0.01:
		check_dir = -global_transform.basis.z
	check_dir.y = 0.0
	if check_dir.length_squared() < 0.001:
		return
	check_dir = check_dir.normalized()
	var side = Vector3(-check_dir.z, 0, check_dir.x)
	var space = get_world_3d().direct_space_state
	if not space:
		return

	# 3 луча по ширине корпуса (по центру и по бокам на 0.32м) с радиусом 2.0м
	for lateral in [0.0, -0.32, 0.32]:
		var origin = global_position + Vector3(0, 1.1, 0) + side * lateral
		var ray = PhysicsRayQueryParameters3D.create(origin, origin + check_dir * 2.0)
		ray.exclude = [get_rid()]
		ray.collision_mask = 1 | 2
		ray.collide_with_areas = false
		var hit = space.intersect_ray(ray)
		if not hit.is_empty():
			var node = hit.collider
			for i in range(5):
				if not is_instance_valid(node):
					break
				if node.has_method("open_by_enemy"):
					if node.has_method("_door_controller"):
						node = node.call("_door_controller")
					if node.has_method("is_door_locked") and node.call("is_door_locked"):
						break
					if node.get("is_open") == true:
						break
					node.call("open_by_enemy", self)
					return
				node = node.get_parent()

func _look_towards(target_pos: Vector3, speed: float) -> void:
	var dir = (target_pos - global_position)
	dir.y = 0.0
	if dir.length_squared() > 0.001:
		var target_angle = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, minf(speed, 1.0))

func _pick_new_patrol_target() -> void:
	var space = get_world_3d()
	if not space:
		return
	var map = space.navigation_map
	var valid_pt: Vector3 = Vector3.ZERO
	var found = false

	# 1. Пробуем получить случайную точку из навигационной сетки (в радиусе 32м по дому или двору)
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		for i in range(16):
			var rnd_pt = NavigationServer3D.map_get_random_point(map, 1, true)
			if rnd_pt.distance_to(global_position) > 4.0 and rnd_pt.distance_to(global_position) < 32.0:
				valid_pt = rnd_pt
				found = true
				break

	# 2. Если случайная не подошла — используем список маршрутных точек (внутри и вокруг дома)
	if not found and not indoor_anchors.is_empty():
		var shuffled = indoor_anchors.duplicate()
		shuffled.shuffle()
		for cand in shuffled:
			if cand.distance_to(global_position) > 3.0:
				if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
					valid_pt = NavigationServer3D.map_get_closest_point(map, cand)
				else:
					valid_pt = cand
				found = true
				break

	if found:
		_set_nav_target(valid_pt)

func _pick_search_points_near(origin: Vector3) -> void:
	search_points.clear()
	search_points.append(origin)
	search_index = 0
	var space = get_world_3d()
	var map = space.navigation_map if space else RID()
	for radius in [3.0, 6.0, 9.0]:
		for i in range(4):
			var a = TAU * float(i) / 4.0 + radius
			var pt = origin + Vector3(cos(a), 0, sin(a)) * radius
			if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
				var snapped = NavigationServer3D.map_get_closest_point(map, pt)
				if snapped.distance_to(pt) < 3.0:
					search_points.append(snapped)
			else:
				search_points.append(pt)
	_set_nav_target(search_points[0])

func _discover_indoor_points() -> void:
	var space = get_world_3d()
	if not space:
		return
	var map = space.navigation_map
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		for i in range(35):
			var p = NavigationServer3D.map_get_random_point(map, 1, true)
			if p.distance_to(global_position) < 35.0:
				var exists = false
				for a in indoor_anchors:
					if a.distance_to(p) < 3.0:
						exists = true
						break
				if not exists:
					indoor_anchors.append(p)

func on_noise_heard(noise_pos: Vector3, radius: float = 30.0, _source_type: String = "environment") -> void:
	_on_noise_made(noise_pos, radius, _source_type)

func _on_noise_made(noise_pos: Vector3, radius: float = 30.0, _source_type: String = "environment") -> void:
	var dist = global_position.distance_to(noise_pos)
	var max_hear = maxf(radius, 24.0)
	if dist <= max_hear:
		if current_state == State.STAKEOUT_HIDING:
			if is_instance_valid(stakeout_target_spot) and noise_pos.distance_to(stakeout_target_spot.global_position) < 3.2:
				stakeout_timer = 99.0
				return
		if current_state == State.CHASE and player_in_sight:
			return

		# Реакция на бег игрока: дед слышит бег и начинает активную погоню!
		var p_ref = GameManager.player_ref
		var is_player_running: bool = false
		if is_instance_valid(p_ref) and p_ref.get("is_sprinting") == true:
			if p_ref.global_position.distance_to(noise_pos) < 3.5:
				is_player_running = true

		if is_player_running:
			if dist < 14.0:
				current_state = State.CHASE
				last_known_player_pos = noise_pos
				_set_nav_target(noise_pos)
				_play_sound(sfx_cock, gun_audio, 1.0)
				play_creepy_voice("laugh")
				return
			else:
				current_state = State.INVESTIGATE
				_set_nav_target(noise_pos)
				play_creepy_voice("mutter")
				return

		if current_state in [State.PATROL, State.INVESTIGATE]:
			current_state = State.INVESTIGATE
			_set_nav_target(noise_pos)
			play_creepy_voice()

func alert_player_cough(cough_pos: Vector3) -> void:
	if GameManager and GameManager.game_ended:
		return
	if is_in_cutscene:
		return
	var dist = global_position.distance_to(cough_pos)
	if dist > 55.0:
		return
	if current_state == State.STAKEOUT_HIDING:
		stakeout_timer = 99.0
		return
	_play_sound(sfx_cock, gun_audio, 1.0)
	play_creepy_voice("laugh")
	if dist < 20.0:
		current_state = State.CHASE
		last_known_player_pos = cough_pos
		_set_nav_target(cough_pos)
	else:
		current_state = State.INVESTIGATE
		_set_nav_target(cough_pos)

func _on_door_altered(door: Node3D, is_open_now: bool) -> void:
	if not is_instance_valid(door):
		return
	if current_state == State.CHASE and player_in_sight:
		return
	var dist = global_position.distance_to(door.global_position)
	if dist < 20.0 and is_open_now:
		if current_state in [State.PATROL, State.INVESTIGATE]:
			current_state = State.INVESTIGATE
			_set_nav_target(door.global_position)
			_play_sound(sfx_grunt, voice_audio, 0.5)

# ══════════════════════════════════════════════════════════════════════════════
#  4-ракурсная анимация спрайта (front, back, left, right)
# ══════════════════════════════════════════════════════════════════════════════
func _update_directional_sprite() -> void:
	if not lumberjack_sprite:
		return

	var forward = -global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.001:
		forward = Vector3(0, 0, -1)
	else:
		forward = forward.normalized()

	var to_cam: Vector3 = Vector3.ZERO
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		to_cam = cam.global_position - global_position
		to_cam.y = 0.0
	elif GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		to_cam = GameManager.player_ref.global_position - global_position
		to_cam.y = 0.0

	if to_cam.length_squared() < 0.001:
		return
	to_cam = to_cam.normalized()

	var dot = forward.dot(to_cam)
	var cross_y = forward.cross(to_cam).y

	var front_thresh = 0.60 if _current_view == "front" else 0.70
	var back_thresh  = -0.60 if _current_view == "back" else -0.70

	if dot >= front_thresh:
		_current_view = "front"
	elif dot <= back_thresh:
		_current_view = "back"
	elif cross_y > 0.0:
		_current_view = "left"
	else:
		_current_view = "right"

func _apply_active_texture(is_moving: bool, step_frame: int) -> void:
	if not lumberjack_sprite:
		return

	match _current_view:
		"front":
			if is_moving:
				var t = tex_front_walk_0 if step_frame == 0 else tex_front_walk_1
				lumberjack_sprite.texture = t if t else tex_front
			else:
				lumberjack_sprite.texture = tex_front
		"back":
			if is_moving:
				var t = tex_back_walk_0 if step_frame == 0 else tex_back_walk_1
				lumberjack_sprite.texture = t if t else tex_back
			else:
				lumberjack_sprite.texture = tex_back
		"left":
			if is_moving:
				var t = tex_left_walk_0 if step_frame == 0 else tex_left_walk_1
				lumberjack_sprite.texture = t if t else tex_left
			else:
				lumberjack_sprite.texture = tex_left
		"right":
			if is_moving:
				var t = tex_right_walk_0 if step_frame == 0 else tex_right_walk_1
				lumberjack_sprite.texture = t if t else tex_right
			else:
				lumberjack_sprite.texture = tex_right

func _animate(delta: float) -> void:
	if not lumberjack_sprite:
		return

	_update_directional_sprite()

	var move_vel = Vector2(velocity.x, velocity.z).length()
	var is_moving = move_vel > 0.25

	if is_moving:
		walk_cycle_t += delta * (move_vel * 3.8)
		var step_frame = int(walk_cycle_t) % 2
		if step_frame != last_step_phase:
			last_step_phase = step_frame
			if not lumberjack_step_streams.is_empty():
				var st = lumberjack_step_streams[lumberjack_step_idx % lumberjack_step_streams.size()]
				lumberjack_step_idx += 1
				_play_sound(st, step_audio, -15.0, randf_range(0.85, 1.05))
			else:
				_play_sound(sfx_step, step_audio, -15.0, randf_range(0.88, 1.12))

		_apply_active_texture(true, step_frame)

		var step_bob = abs(sin(walk_cycle_t * PI)) * 0.035
		lumberjack_sprite.position.y = BASE_SPRITE_Y - step_bob

		var step_sway = sin(walk_cycle_t * PI) * 0.025
		lumberjack_sprite.rotation.z = step_sway
	else:
		walk_cycle_t = 0.0
		_apply_active_texture(false, 0)
		lumberjack_sprite.position.y = lerp(lumberjack_sprite.position.y, BASE_SPRITE_Y, delta * 6.0)
		lumberjack_sprite.rotation.z = lerp(lumberjack_sprite.rotation.z, 0.0, delta * 6.0)

# ══════════════════════════════════════════════════════════════════════════════
#  Генерация процедурных звуковых эффектов
# ══════════════════════════════════════════════════════════════════════════════
func _generate_sound_effects() -> void:
	if ResourceLoader.exists("res://assets/audio/shotgun_shot.mp3"):
		sfx_shot = load("res://assets/audio/shotgun_shot.mp3")
	else:
		sfx_shot = _create_procedural_gunshot()
	sfx_cock = _create_procedural_cock()
	sfx_pump = _create_procedural_pump()
	lumberjack_step_streams.clear()
	if ResourceLoader.exists("res://assets/audio/step_1.mp3"):
		lumberjack_step_streams.append(load("res://assets/audio/step_1.mp3"))
	if ResourceLoader.exists("res://assets/audio/step_2.mp3"):
		lumberjack_step_streams.append(load("res://assets/audio/step_2.mp3"))
	sfx_step = _create_procedural_step()
	sfx_grunt = _create_procedural_grunt()
	sfx_impact = _create_procedural_bullet_impact()

func _create_procedural_gunshot() -> AudioStreamWAV:
	var sample_count = int(44100 * 0.65)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 9.5)
		var crack = (randf() * 2.0 - 1.0) * exp(-t * 35.0) * 1.2
		var boom = sin(t * 62.0 * TAU) * 0.75 * exp(-t * 6.0)
		var body = sin(t * 125.0 * TAU) * 0.45 * exp(-t * 12.0)
		var val = clamp((crack + boom + body + (randf() * 2.0 - 1.0) * 0.2 * env) * env, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(val * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	return wav

func _create_procedural_cock() -> AudioStreamWAV:
	var sample_count = int(44100 * 0.16)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 32.0)
		var click = sin(t * 2200.0 * TAU) * 0.6 + sin(t * 4400.0 * TAU) * 0.4
		var val = clamp(click * env, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(val * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	return wav

func _create_procedural_pump() -> AudioStreamWAV:
	var sample_count = int(44100 * 0.32)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 14.0)
		var scrape = (randf() * 2.0 - 1.0) * 0.4 * exp(-t * 18.0)
		var clack = sin(t * 1800.0 * TAU) * 0.5 * exp(-fposmod(t, 0.15) * 40.0)
		var val = clamp((scrape + clack) * env, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(val * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	return wav

func _create_procedural_step() -> AudioStreamWAV:
	var sample_count = int(44100 * 0.18)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 26.0)
		var thud = sin(t * 90.0 * TAU) * 0.7 + (randf() * 2.0 - 1.0) * 0.3
		var val = clamp(thud * env, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(val * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	return wav

func _play_sound(stream: AudioStream, player: AudioStreamPlayer3D, vol_db: float = 0.0, pitch: float = 1.0) -> void:
	if not player or not stream:
		return
	player.stream = stream
	player.volume_db = vol_db
	player.pitch_scale = pitch
	player.play()

func reset_ai() -> void:
	current_state = State.PATROL
	wait_timer = 0.0
	stuck_timer = 0.0
	aim_timer = 0.0
	reload_timer = 0.0
	player_in_sight = false
	flashlight_suspicion_timer = 0.0
	is_blinded_by_light = false
	has_warned_light = false
	velocity = Vector3.ZERO
	stakeout_target_spot = null
	stakeout_timer = 0.0
	silence_timer = 0.0
	hiding_spot_cooldowns.clear()
	witnessed_hiding_spot = null
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_flashlight_warning"):
		GameManager.ui_ref.call("show_flashlight_warning", false, 0.0)
	_pick_new_patrol_target()

func _create_procedural_grunt() -> AudioStreamWAV:
	var sample_count = int(44100 * 0.42)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = sin(clampf(t / 0.42, 0.0, 1.0) * PI)
		var f = 115.0 - t * 25.0
		var vocal = sin(t * f * TAU) * 0.5 + sin(t * f * 2.0 * TAU) * 0.3 + (randf() * 2.0 - 1.0) * 0.15
		var val = clamp(vocal * env * 0.65, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(val * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	return wav

# ──────────────────────────────────────────────
#  Реакция на свет фонарика игрока (справедливый баланс)
# ──────────────────────────────────────────────
func _check_flashlight_illumination(delta: float) -> void:
	if current_state in [State.AIMING, State.SHOOT, State.RELOAD]:
		_decay_flashlight_suspicion(delta)
		return

	var player = GameManager.player_ref
	if not player or not is_instance_valid(player) or player.get("is_dead") == true or player.get("is_hiding") == true:
		_decay_flashlight_suspicion(delta)
		return

	if player.get("flashlight_on") != true:
		_decay_flashlight_suspicion(delta)
		return

	var cam = player.get("camera")
	if not cam:
		_decay_flashlight_suspicion(delta)
		return

	var p_eye = cam.global_position
	var jack_center = global_position + Vector3(0, 1.25, 0)
	var dist = p_eye.distance_to(jack_center)

	# Максимальная дистанция луча для реакции: 14 метров
	if dist > 14.0:
		_decay_flashlight_suspicion(delta)
		return

	# Проверяем попадание в конус света фонарика игрока (половина угла ~ 26 градусов)
	var cam_dir = -cam.global_transform.basis.z
	var to_jack = (jack_center - p_eye).normalized()
	var dot_beam = cam_dir.dot(to_jack)
	if dot_beam < 0.89:
		_decay_flashlight_suspicion(delta)
		return

	# Проверяем прямую физическую видимость (стены, закрытые двери)
	var space = get_world_3d().direct_space_state
	if not space:
		_decay_flashlight_suspicion(delta)
		return

	var query = PhysicsRayQueryParameters3D.create(p_eye, jack_center)
	query.exclude = [player.get_rid(), get_rid()]
	query.collision_mask = 1
	query.collide_with_areas = false
	var hit = space.intersect_ray(query)

	if not hit.is_empty() and not _is_player_collider(hit.collider, self) and hit.collider != self:
		# Препятствие между лучом фонарика и лесопилом
		_decay_flashlight_suspicion(delta)
		return

	# СВЕТ ПОПАЛ НА ЛЕСОПИЛА!
	is_blinded_by_light = true
	flashlight_suspicion_timer += delta

	# Лесопил поворачивается лицом к источнику света
	_look_towards(player.global_position, 3.5 * delta)

	# Звук ворчания при первом попадании света
	if flashlight_suspicion_timer < 0.2 and not has_warned_light:
		has_warned_light = true
		_play_sound(sfx_grunt, voice_audio, 1.0, randf_range(0.9, 1.05))

	# Оповещаем UI с таймером
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_flashlight_warning"):
		var time_left = maxf(0.0, 2.0 - flashlight_suspicion_timer)
		GameManager.ui_ref.call("show_flashlight_warning", true, time_left, "Лесопил")

	# Если игрок не выключил фонарик за 2.0 секунды — лесопил целится и стреляет!
	if flashlight_suspicion_timer >= 2.0:
		flashlight_suspicion_timer = 0.0
		is_blinded_by_light = false
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_flashlight_warning"):
			GameManager.ui_ref.call("show_flashlight_warning", false, 0.0)
		_on_player_spotted(player.global_position + Vector3(0, 1.15, 0))

func _decay_flashlight_suspicion(delta: float) -> void:
	if flashlight_suspicion_timer > 0.0:
		flashlight_suspicion_timer = maxf(0.0, flashlight_suspicion_timer - delta * 2.5)
		if flashlight_suspicion_timer <= 0.0:
			has_warned_light = false
			is_blinded_by_light = false
			if GameManager.ui_ref and GameManager.ui_ref.has_method("show_flashlight_warning"):
				GameManager.ui_ref.call("show_flashlight_warning", false, 0.0)

func play_impact_sound_at(pos: Vector3) -> void:
	if not is_inside_tree() or not sfx_impact:
		return
	var p = AudioStreamPlayer3D.new()
	p.stream = sfx_impact
	p.position = pos
	p.max_distance = 28.0
	p.unit_size = 5.0
	p.volume_db = 2.0
	var scene_root = get_tree().current_scene if get_tree() else get_parent()
	if scene_root:
		scene_root.add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func _create_procedural_bullet_impact() -> AudioStreamWAV:
	var sample_count = int(44100 * 0.14)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 38.0)
		var ping = sin(t * (2400.0 - t * 8000.0) * TAU) * 0.55
		var snap = (randf() * 2.0 - 1.0) * exp(-t * 70.0) * 0.8
		var val = clamp((ping + snap) * env, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(val * 32767.0))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	return wav

# ══════════════════════════════════════════════════════════════════════════════
#  ShotgunPellet — Видимый летящий снаряд картечи со шлейфом и искрами
# ══════════════════════════════════════════════════════════════════════════════
class ShotgunPellet extends Node3D:
	var velocity: Vector3 = Vector3.ZERO
	var shooter: CharacterBody3D = null
	var damage: float = 38.0
	var lifetime: float = 2.2
	var has_hit: bool = false
	var mesh_inst: MeshInstance3D = null
	var pellet_light: OmniLight3D = null

	func setup(start_pos: Vector3, dir: Vector3, speed: float, p_shooter: CharacterBody3D, p_damage: float, is_lead: bool = true) -> void:
		global_position = start_pos
		velocity = dir * speed
		shooter = p_shooter
		damage = p_damage

		# Визуальный меш пули — яркий светящийся огненный трассер (хорошо виден в темноте)
		mesh_inst = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = 0.60
		mesh_inst.mesh = cyl
		mesh_inst.rotation.x = deg_to_rad(90.0)

		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.90, 0.35)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.70, 0.15)
		mat.emission_energy_multiplier = 4.0
		mesh_inst.material_override = mat
		add_child(mesh_inst)

		if dir.length_squared() > 0.001:
			look_at(start_pos + dir, Vector3.UP)

		# Яркий источник света пули, освещающий стены и пол по траектории полёта
		pellet_light = OmniLight3D.new()
		pellet_light.light_color = Color(1.0, 0.75, 0.20)
		pellet_light.light_energy = 3.5
		pellet_light.omni_range = 5.0
		add_child(pellet_light)

	func _physics_process(delta: float) -> void:
		if has_hit:
			return

		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return

		var space = get_world_3d().direct_space_state
		if not space:
			global_position += velocity * delta
			return

		var from_pos = global_position
		var to_pos = from_pos + velocity * delta

		var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		var exclude_rids: Array[RID] = []
		if shooter and is_instance_valid(shooter):
			exclude_rids.append(shooter.get_rid())
		query.exclude = exclude_rids
		query.collision_mask = 0xFFFFFFFF # Проверяем ВСЕ препятствия (стены, двери, мебель, пропы)
		query.collide_with_areas = false

		var hit = space.intersect_ray(query)
		if not hit.is_empty():
			var col = hit.collider
			if col and (col.get("is_open") == true or (col.get_parent() and col.get_parent().get("is_open") == true)):
				global_position = to_pos
				return

			has_hit = true
			var hit_pos = hit.position
			var hit_norm = hit.normal

			var player = GameManager.player_ref
			var is_player = false
			if player and is_instance_valid(player):
				if col == player or col.get_parent() == player or player.is_ancestor_of(col):
					is_player = true
				elif col.name.to_lower() in ["player", "playerbody", "hitbox"]:
					is_player = true

			if is_player:
				if player.get("is_dead") != true:
					player.call("take_damage", damage, shooter)
				_spawn_blood_impact(hit_pos)
			else:
				_spawn_wall_sparks(hit_pos, hit_norm)

			queue_free()
		else:
			global_position = to_pos

	func _spawn_wall_sparks(pos: Vector3, normal: Vector3) -> void:
		var parent = get_parent()
		if not parent:
			return

		if shooter and shooter.has_method("play_impact_sound_at"):
			shooter.call("play_impact_sound_at", pos)

		var sparks = CPUParticles3D.new()
		sparks.emitting = true
		sparks.one_shot = true
		sparks.explosiveness = 0.95
		sparks.lifetime = 0.35
		sparks.amount = 8
		sparks.position = pos + normal * 0.05
		sparks.direction = normal + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.5), randf_range(-0.4, 0.4))
		sparks.spread = 45.0
		sparks.initial_velocity_min = 2.0
		sparks.initial_velocity_max = 5.5
		sparks.gravity = Vector3(0, -9.8, 0)

		var spark_mesh = SphereMesh.new()
		spark_mesh.radius = 0.02
		spark_mesh.height = 0.04
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.8, 0.2)
		spark_mesh.material = mat
		sparks.mesh = spark_mesh

		parent.add_child(sparks)
		sparks.get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(sparks):
				sparks.queue_free()
		)

	func _spawn_blood_impact(pos: Vector3) -> void:
		var parent = get_parent()
		if not parent:
			return

		var blood = CPUParticles3D.new()
		blood.emitting = true
		blood.one_shot = true
		blood.explosiveness = 0.95
		blood.lifetime = 0.4
		blood.amount = 10
		blood.position = pos
		blood.spread = 180.0
		blood.initial_velocity_min = 1.0
		blood.initial_velocity_max = 3.0
		blood.gravity = Vector3(0, -8.0, 0)

		var b_mesh = SphereMesh.new()
		b_mesh.radius = 0.03
		b_mesh.height = 0.06
		var mat = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.7, 0.05, 0.05)
		b_mesh.material = mat
		blood.mesh = b_mesh

		parent.add_child(blood)
		blood.get_tree().create_timer(0.6).timeout.connect(func():
			if is_instance_valid(blood):
				blood.queue_free()
		)
