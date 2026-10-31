extends EnemyBehavior

var col_node:       CollisionShape3D
var col_shape:      CapsuleShape3D
var monster_sprite: Sprite3D

# Текстуры для разных ракурсов и шагов
var tex_monster_front_idle:   Texture2D
var tex_monster_front_walk_0: Texture2D
var tex_monster_front_walk_1: Texture2D

var tex_monster_back:         Texture2D

var tex_monster_left_idle:    Texture2D
var tex_monster_left_walk_0:  Texture2D
var tex_monster_left_walk_1:  Texture2D

var tex_monster_right_idle:   Texture2D
var tex_monster_right_walk_0: Texture2D
var tex_monster_right_walk_1: Texture2D

var _current_view:   String = ""
var walk_cycle_t:    float = 0.0
var last_step_phase: int = 0
var step_audio:      AudioStreamPlayer3D
var voice_audio:     AudioStreamPlayer3D = null
var creepy_sounds:   Array[AudioStream] = []
var creepy_timer:    float = 7.0
var eye_spot:        SpotLight3D = null
var eye_glow:        OmniLight3D = null

const BASE_SPRITE_Y: float = 1.165


func _build_visual() -> void:
	# Коллизия монстра (высота 2.0м, проходит в стандартные двери 2.2м)
	col_node = CollisionShape3D.new()
	col_shape = CapsuleShape3D.new()
	col_shape.height = 1.9
	col_shape.radius = 0.26
	col_node.shape = col_shape
	col_node.position = Vector3(0, 0.95, 0)
	add_child(col_node)

	_load_monster_textures()

	# Основной направленный билборд-спрайт
	monster_sprite = Sprite3D.new()
	monster_sprite.name = "MonsterSprite"
	monster_sprite.texture = tex_monster_front_idle
	monster_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	# При высоте персонажа 880px в холсте 1024, pixel_size = 0.0026 дает высоту 2.3м в мире
	monster_sprite.pixel_size = 0.0026
	monster_sprite.position = Vector3(0, BASE_SPRITE_Y, 0)
	monster_sprite.shaded = true
	monster_sprite.double_sided = true
	monster_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	monster_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	add_child(monster_sprite)

	# 3D звук тяжёлых зловещих шагов скинуокера
	step_audio = AudioStreamPlayer3D.new()
	step_audio.name = "StepAudio"
	step_audio.unit_size = 5.0
	step_audio.max_distance = 28.0
	var snd_step = _try_load_res("res://assets/audio/monster_step.wav")
	if snd_step:
		step_audio.stream = snd_step
		step_audio.volume_db = -3.0
	add_child(step_audio)

	# Красный свет монстра — прожектор взгляда вперед во тьму (куда он смотрит)
	eye_spot = SpotLight3D.new()
	eye_spot.name = "MonsterRedSpot"
	eye_spot.position = Vector3(0, 1.85, 0.1)
	eye_spot.light_color = Color(1.0, 0.12, 0.08)
	eye_spot.light_energy = 2.6
	eye_spot.spot_range = 16.0
	eye_spot.spot_angle = 45.0
	eye_spot.spot_angle_attenuation = 0.85
	eye_spot.shadow_enabled = true
	add_child(eye_spot)

	# Красный ореол зловещих светящихся глаз
	eye_glow = OmniLight3D.new()
	eye_glow.name = "MonsterEyeGlow"
	eye_glow.position = Vector3(0, 1.85, -0.15)
	eye_glow.light_color = Color(1.0, 0.15, 0.08)
	eye_glow.light_energy = 1.6
	eye_glow.omni_range = 2.8
	add_child(eye_glow)

	voice_audio = AudioStreamPlayer3D.new()
	voice_audio.name = "MonsterVoiceAudio"
	voice_audio.unit_size = 6.0
	voice_audio.max_distance = 35.0
	add_child(voice_audio)
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
	voice_audio.pitch_scale = randf_range(0.90, 1.05)
	voice_audio.play()

func _try_load_res(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _load_monster_textures() -> void:
	const BASE_DIR = "res://assets/textures/enemy_character/"
	tex_monster_front_idle   = _try_load_tex(BASE_DIR + "monster_front.png")
	tex_monster_front_walk_0 = _try_load_tex(BASE_DIR + "monster_front_walk_0.png")
	tex_monster_front_walk_1 = _try_load_tex(BASE_DIR + "monster_front_walk_1.png")

	tex_monster_back         = _try_load_tex(BASE_DIR + "monster_back.png")

	tex_monster_left_idle    = _try_load_tex(BASE_DIR + "monster_left.png")
	tex_monster_left_walk_0  = _try_load_tex(BASE_DIR + "monster_left_walk_0.png")
	tex_monster_left_walk_1  = _try_load_tex(BASE_DIR + "monster_left_walk_1.png")

	tex_monster_right_idle   = _try_load_tex(BASE_DIR + "monster_right.png")
	tex_monster_right_walk_0 = _try_load_tex(BASE_DIR + "monster_right_walk_0.png")
	tex_monster_right_walk_1 = _try_load_tex(BASE_DIR + "monster_right_walk_1.png")

func _try_load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

# ══════════════════════════════════════════════
#  Расчет ракурса и анимация монстра
# ══════════════════════════════════════════════
func _update_directional_sprite() -> void:
	if not monster_sprite:
		return

	# Вектор направления взгляда монстра в горизонтальной плоскости (в Godot -Z это вперед)
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

	_calculate_and_apply_view(forward, to_cam)

func _calculate_and_apply_view(forward: Vector3, to_cam: Vector3) -> void:
	var dot = forward.dot(to_cam)
	var cross_y = forward.cross(to_cam).y

	# Порог с гистерезисом для предотвращения дерганий на границах
	var front_thresh = 0.60 if _current_view == "front" else 0.70
	var back_thresh  = -0.60 if _current_view == "back" else -0.70

	var view: String
	if dot >= front_thresh:
		view = "front"
	elif dot <= back_thresh:
		view = "back"
	elif cross_y > 0.0:
		view = "left"
	else:
		view = "right"

	_current_view = view

func _apply_active_texture(is_moving: bool, step_frame: int) -> void:
	if not monster_sprite:
		return

	match _current_view:
		"front":
			if is_moving:
				var t = tex_monster_front_walk_0 if step_frame == 0 else tex_monster_front_walk_1
				monster_sprite.texture = t if t else tex_monster_front_idle
			else:
				monster_sprite.texture = tex_monster_front_idle
		"back":
			monster_sprite.texture = tex_monster_back
		"left":
			if is_moving:
				var t = tex_monster_left_walk_0 if step_frame == 0 else tex_monster_left_walk_1
				monster_sprite.texture = t if t else tex_monster_left_idle
			else:
				monster_sprite.texture = tex_monster_left_idle
		"right":
			if is_moving:
				var t = tex_monster_right_walk_0 if step_frame == 0 else tex_monster_right_walk_1
				monster_sprite.texture = t if t else tex_monster_right_idle
			else:
				monster_sprite.texture = tex_monster_right_idle

func _play_footstep() -> void:
	if step_audio and step_audio.stream:
		step_audio.pitch_scale = randf_range(0.85, 1.15)
		step_audio.play()

func _play_heavy_footstep() -> void:
	# Тяжёлые топающие шаги во время погони — слышны издалека
	var p = AudioStreamPlayer3D.new()
	p.max_distance = 28.0
	p.unit_size = 6.0
	p.volume_db = lerp(-4.0, 2.0, hunt_rage_buildup)
	var snd = ResourceLoader.load("res://assets/audio/step_stone_0.wav") if ResourceLoader.exists("res://assets/audio/step_stone_0.wav") else null
	if not snd:
		snd = ResourceLoader.load("res://assets/audio/player_step_0.wav") if ResourceLoader.exists("res://assets/audio/player_step_0.wav") else null
	if not snd and step_audio and step_audio.stream:
		snd = step_audio.stream
	if snd:
		p.stream = snd
		p.pitch_scale = randf_range(0.52, 0.68) # Глубже и тяжелее шагов игрока
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)

func _animate(delta: float) -> void:
	if not monster_sprite:
		return

	_update_directional_sprite()

	var move_vel = Vector2(velocity.x, velocity.z).length()
	var is_moving = move_vel > 0.25
	var is_hunting = (state in [State.HUNT, State.RAGE])

	# Плавная процедурная анимация походки и шагов
	if is_moving:
		var anim_spd = clamp(move_vel * 0.95, 3.0, 8.5)
		walk_cycle_t += delta * anim_spd

		var step_frame = int(walk_cycle_t) % 2
		if step_frame != last_step_phase:
			last_step_phase = step_frame
			_play_footstep()

		_apply_active_texture(true, step_frame)

		# Вертикальное покачивание (опускание на шаге)
		var step_bob = abs(sin(walk_cycle_t * PI)) * (0.050 if is_hunting else 0.035)
		monster_sprite.position.y = BASE_SPRITE_Y - step_bob

		# Боковой наклон в такт шагам (перенос веса с ноги на ногу)
		var step_sway = sin(walk_cycle_t * PI) * (0.038 if is_hunting else 0.024)
		monster_sprite.rotation.z = step_sway

		if is_hunting:
			var pulse = sin(anim_t * 14.0) * 0.03
			monster_sprite.scale = Vector3(1.0 + pulse, 1.0 - pulse * 0.5, 1.0)
		else:
			monster_sprite.scale = Vector3.ONE
	else:
		# Ожидание / наблюдение / дыхание (плавно гасим наклон без рывков)
		_apply_active_texture(false, 0)
		var is_hiding_focus := state in [State.INSPECT_HIDING, State.STAKEOUT_HIDING]
		var breathe = sin(anim_t * (5.5 if is_hiding_focus else 2.2)) * (0.04 if is_hiding_focus else 0.015)
		var working := state == State.ROUTINE and _job_started
		var lean := 0.09 if working else (0.07 if is_hiding_focus else 0.0)
		var target_y = BASE_SPRITE_Y - lean + breathe
		monster_sprite.position.y = lerp(monster_sprite.position.y, target_y, delta * 6.0)
		var idle_tilt := sin(anim_t * 2.0) * 0.035 if working else 0.0
		monster_sprite.rotation.z = lerp_angle(monster_sprite.rotation.z, idle_tilt, delta * 7.0)
		if is_hiding_focus:
			var hunch = sin(anim_t * 5.5) * 0.025
			monster_sprite.scale = Vector3(1.0 + hunch, 1.0 - hunch, 1.0)
		else:
			monster_sprite.scale = Vector3.ONE

	# Пульсация и яркость красного света глаз и луча взгляда
	if eye_glow and is_instance_valid(eye_glow):
		if is_hunting:
			eye_glow.light_energy = 2.2 + sin(anim_t * 6.0) * 0.5
			if eye_spot and is_instance_valid(eye_spot):
				eye_spot.light_energy = 3.2
		else:
			eye_glow.light_energy = 1.4 + sin(anim_t * 2.8) * 0.35
			if eye_spot and is_instance_valid(eye_spot):
				eye_spot.light_energy = 2.4

	# Периодические зловещие звуки скинвокера («тем ближе тем громче»)
	creepy_timer -= delta
	if creepy_timer <= 0.0:
		creepy_timer = randf_range(8.0, 16.0)
		play_creepy_voice()

func reset_to_patrol() -> void:
	reset_ai()
