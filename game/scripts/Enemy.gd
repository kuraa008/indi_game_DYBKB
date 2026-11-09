extends EnemyBehavior

var col_node:       CollisionShape3D
var col_shape:      CapsuleShape3D
var model:          SkinwalkerModel

var walk_cycle_t:    float = 0.0
var last_step_phase: int = 0
var _clearance_timer: float = 0.0
var _anim_accum: float = 0.0
var step_audio:      AudioStreamPlayer3D
var voice_audio:     AudioStreamPlayer3D = null
var creepy_sounds:   Array[AudioStream] = []
var creepy_timer:    float = 7.0
var eye_spot:        SpotLight3D = null
var eye_glow:        OmniLight3D = null

func _build_visual() -> void:
	# Коллизия монстра (высота 2.0м, проходит в стандартные двери 2.2м)
	col_node = CollisionShape3D.new()
	col_shape = CapsuleShape3D.new()
	col_shape.height = 1.9
	col_shape.radius = 0.26
	col_node.shape = col_shape
	col_node.position = Vector3(0, 0.95, 0)
	add_child(col_node)

	# Процедурная 3D-модель скинвокера (модель смотрит вдоль +Z, а враг — вдоль -Z)
	model = SkinwalkerModel.new()
	model.name = "SkinwalkerModel"
	model.rotation.y = PI
	add_child(model)

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
	_on_quality_for_lights(GameManager.graphics_quality)
	if not GameManager.graphics_quality_changed.is_connected(_on_quality_for_lights):
		GameManager.graphics_quality_changed.connect(_on_quality_for_lights)

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

# Тень от взгляда монстра самая дорогая: движущийся прожектор перерисовывает её каждый кадр
func _on_quality_for_lights(quality: String) -> void:
	if eye_spot and is_instance_valid(eye_spot):
		eye_spot.shadow_enabled = quality == "ultra"

func _load_creepy_sounds() -> void:
	creepy_sounds.clear()
	var sound_paths = [
		"res://assets/audio/monster/monster_growl.wav",
		"res://assets/audio/monster/monster_mimic.wav",
		"res://assets/audio/monster/monster_clicks.wav",
		"res://assets/audio/monster/monster_breath.wav"
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
			pick_snd = _try_load_res("res://assets/audio/monster/monster_clicks.wav")
		"mutter":
			pick_snd = _try_load_res("res://assets/audio/monster/monster_mimic.wav")
		"groan":
			pick_snd = _try_load_res("res://assets/audio/monster/monster_growl.wav")
		"whisper":
			pick_snd = _try_load_res("res://assets/audio/monster/monster_breath.wav")
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

# Крик, когда заметил игрока: перебивает любой другой звук
func scream() -> void:
	if not voice_audio:
		return
	var snd: AudioStream = _try_load_res("res://assets/audio/monster/monster_growl.wav")
	if snd == null:
		return
	voice_audio.stop()
	voice_audio.stream = snd
	voice_audio.pitch_scale = randf_range(1.25, 1.4)
	voice_audio.volume_db = 7.0
	voice_audio.unit_size = 12.0
	voice_audio.play()

func _try_load_res(path: String) -> Resource:
	if ResourceLoader.exists(path):
		return load(path)
	return null

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
	if not model:
		return

	var move_vel = Vector2(velocity.x, velocity.z).length()
	var is_moving = move_vel > 0.25
	var is_hunting = (state in [State.HUNT, State.RAGE])
	var is_hiding_focus := state in [State.INSPECT_HIDING, State.STAKEOUT_HIDING]
	var working := state == State.ROUTINE and _job_started

	var is_searching := state in [State.SEARCH, State.ALERT, State.INVESTIGATE_BASEMENT]
	var gait := "idle"
	if state == State.DASH:
		gait = "recover" if _dash_recover > 0.0 and not is_moving else "dash"
	elif state == State.LURK:
		gait = "creep" if is_moving else "lurk"
	elif state == State.LISTEN:
		gait = "listen"
	elif is_moving:
		if is_hunting and move_vel > 7.3:
			gait = "dash"
		elif is_hunting and move_vel > 2.6:
			gait = "run"
		elif is_hiding_focus or is_searching:
			gait = "stalk"
		else:
			gait = "walk"
	elif is_hiding_focus:
		gait = "twitch"
	elif working or is_hunting:
		gait = "stalk"
	elif is_searching:
		gait = "listen"

	_clearance_timer -= delta
	if _clearance_timer <= 0.0:
		_clearance_timer = 0.12
		model.set_clearance(_measure_clearance())

	var rage: float = hunt_rage_buildup * 0.5 if is_hunting else 0.0
	# Далёкий монстр анимируется реже и не отбрасывает тень
	var cam_far := get_viewport().get_camera_3d() if is_inside_tree() else null
	var dist_sq: float = global_position.distance_squared_to(cam_far.global_position) if cam_far else 0.0
	model.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if dist_sq > 625.0 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_anim_accum += delta
	if dist_sq > 1225.0 and _anim_accum < 0.066:
		return
	model.update_motion(_anim_accum, gait, move_vel if is_moving else 0.0, rage)
	_anim_accum = 0.0
	# Вблизи монстр следит головой за камерой и шевелит пальцами
	var cam = get_viewport().get_camera_3d() if is_inside_tree() else null
	var near_cam := false
	if cam:
		near_cam = global_position.distance_squared_to(cam.global_position) < 196.0
		if state == State.LISTEN and _listen_heard:
			model.set_look_target(_listen_pos)
		else:
			model.set_look_target(cam.global_position if near_cam else null)
	model.set_hands_animated(near_cam)

	# Шаг на каждый полуоборот цикла походки
	if is_moving:
		var step_phase := int(model.phase / PI)
		if step_phase != last_step_phase:
			last_step_phase = step_phase
			# Крадётся беззвучно, в рывке топает так, что слышно по всему дому
			if not _silent:
				if step_audio:
					step_audio.volume_db = 2.0 if state == State.DASH else (-11.0 if is_searching else -3.0)
				_play_footstep()

	# Красный взгляд и свечение глаз следуют за головой
	var head_pos := to_local(model.get_head_position())
	if eye_spot and is_instance_valid(eye_spot):
		eye_spot.position = head_pos
	if eye_glow and is_instance_valid(eye_glow):
		eye_glow.position = head_pos

	# Затаившись, гасит красный свет: выдают его только сами глаза
	var hiding_light := state == State.LURK
	model.set_eye_glow(5.0 if hiding_light and not is_moving else (2.6 if hiding_light else 1.0))
	if eye_spot and is_instance_valid(eye_spot):
		eye_spot.visible = not hiding_light
	# Пульсация и яркость красного света глаз и луча взгляда
	if eye_glow and is_instance_valid(eye_glow):
		eye_glow.omni_range = 0.9 if hiding_light else 2.8
		if hiding_light:
			eye_glow.light_energy = 0.3
		elif is_hunting or state == State.DASH:
			eye_glow.light_energy = 2.2 + sin(anim_t * 6.0) * 0.5
			if eye_spot and is_instance_valid(eye_spot):
				eye_spot.light_energy = 3.2
		else:
			eye_glow.light_energy = 1.4 + sin(anim_t * 2.8) * 0.35
			if eye_spot and is_instance_valid(eye_spot):
				eye_spot.light_energy = 2.4

	# Периодические зловещие звуки скинвокера («тем ближе тем громче»)
	if not hiding_light:
		creepy_timer -= delta
	if creepy_timer <= 0.0:
		creepy_timer = randf_range(8.0, 16.0)
		play_creepy_voice()

# Сколько места над головой здесь и чуть впереди: потолки по лучу, двери по расстоянию
func _measure_clearance() -> float:
	var best := 4.0
	var space := get_world_3d().direct_space_state
	var fwd := -global_transform.basis.z
	for off in [0.0, 0.7]:
		var base: Vector3 = global_position + fwd * float(off)
		var q := PhysicsRayQueryParameters3D.create(base + Vector3.UP * 1.0, base + Vector3.UP * 3.2, 1, [get_rid()])
		var hit := space.intersect_ray(q)
		if hit:
			best = minf(best, float(hit.position.y) - global_position.y)
	for d in get_tree().get_nodes_in_group("doors"):
		if d is Node3D:
			var dp: Vector3 = (d as Node3D).global_position - global_position
			dp.y = 0.0
			if dp.length_squared() < 1.7:
				best = minf(best, 2.12)
				break
	return best


func reset_to_patrol() -> void:
	reset_ai()
