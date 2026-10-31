extends CharacterBody3D

# ══════════════════════════════════════════════════════════════════════════════
#  SurvivorBot.gd — Автономный Бот-Выживший для полигона и обучения ИИ
#  • Полноценная 4-ракурсная текстурированная 3D-модель игрока (front, back, left, right)
#  • Динамический фонарик в руке с объемным лучом
#  • Тактика обмана («Mindgame & Juking»):
#    - Спринт-петляние по комнатам без вечного сидения в шкафах
#    - Ложные повороты (Corner Juke): забегает за угол в одну сторону, затем резко в другую
#    - Захлопывание дверей в лицо монстру со смещением в сторону
#    - Бросок бутылок-приманок для дезориентации
#    - Разворот на 180° вокруг мебели (Double Back)
#    - Внезапный рывок из укрытия (Burst Escape), если монстр подошел близко
# ══════════════════════════════════════════════════════════════════════════════

enum BotState { WANDER, FLEE_RUN, JUKE, DOUBLE_BACK, TEMP_HIDE, BURST_OUT }
var state: BotState = BotState.WANDER

var nav_agent: NavigationAgent3D
var speed_walk: float = 2.8
var speed_run:  float = 5.6
var speed_sprint_burst: float = 6.8

var is_hiding: bool = false
var current_hiding_spot: Node3D = null
var hiding_type: String = ""
var hiding_timer: float = 0.0
var max_hide_duration: float = 3.5
var breath_held: bool = false

# ── Визуализация: 4-ракурсный направленный спрайт персонажа ──
var body_sprite: Sprite3D = null
var tex_front: Texture2D = null
var tex_back:  Texture2D = null
var tex_left:  Texture2D = null
var tex_right: Texture2D = null

var flashlight: SpotLight3D = null
var scent_aura: OmniLight3D = null

var waypoints: Array[Vector3] = []
var wp_idx: int = 0
var repath_timer: float = 0.0

# ── Тактические таймеры и переменные обмана ──
var can_throw_bottle: bool = true
var bottle_cooldown: float = 0.0
var last_door_passed: Node = null

var juke_timer: float = 0.0
var juke_fake_dir: Vector3 = Vector3.ZERO
var juke_real_dir: Vector3 = Vector3.ZERO
var double_back_cooldown: float = 0.0

var step_timer: float = 0.0
var step_audio: AudioStreamPlayer3D = null
var anim_walk_t: float = 0.0
var threat_position: Vector3 = Vector3.ZERO
var threat_age: float = 100.0
var decision_timer: float = 0.0
var escape_target: Vector3 = Vector3.ZERO
var recent_targets: Array[Vector3] = []
var progress_anchor: Vector3 = Vector3.ZERO
var no_progress_time: float = 0.0
var hide_exit_position: Vector3 = Vector3.ZERO
var oxygen: float = 1.0
var breath_recovery: float = 0.0

signal survivor_thrown_bottle(pos: Vector3, target_noise_pos: Vector3)
signal survivor_slammed_door(door_node: Node)
signal survivor_hid(hiding_spot: Node3D)
signal survivor_burst_out
signal survivor_juked
signal survivor_caught

func _ready() -> void:
	_load_character_textures()
	_build_visual_character()
	_setup_nav()

func _load_character_textures() -> void:
	const P_DIR = "res://assets/textures/player_character/"
	if ResourceLoader.exists(P_DIR + "player_front.png"):
		tex_front = load(P_DIR + "player_front.png")
	if ResourceLoader.exists(P_DIR + "player_back.png"):
		tex_back  = load(P_DIR + "player_back.png")
	if ResourceLoader.exists(P_DIR + "player_left.png"):
		tex_left  = load(P_DIR + "player_left.png")
	if ResourceLoader.exists(P_DIR + "player_right.png"):
		tex_right = load(P_DIR + "player_right.png")

func _build_visual_character() -> void:
	# Физический коллайдер-капсула человека
	var col = CollisionShape3D.new()
	col.name = "BodyCollider"
	var cap = CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 1.78
	col.shape = cap
	col.position = Vector3(0, 0.89, 0)
	add_child(col)

	# Основной направленный 3D-спрайт выжившего
	body_sprite = Sprite3D.new()
	body_sprite.name = "SurvivorSprite"
	body_sprite.texture = tex_front if tex_front else null
	body_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	body_sprite.pixel_size = 0.0022
	body_sprite.position = Vector3(0, 0.90, 0)
	body_sprite.shaded = true
	body_sprite.double_sided = true
	body_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	body_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	body_sprite.modulate = Color(1.15, 1.15, 1.15, 1.0)
	add_child(body_sprite)

	# Легкая теплая био-аура (видна скинвокеру в темноте)
	scent_aura = OmniLight3D.new()
	scent_aura.name = "ScentAura"
	scent_aura.light_color = Color(0.4, 0.8, 1.0)
	scent_aura.light_energy = 0.45
	scent_aura.omni_range = 3.5
	scent_aura.shadow_enabled = false
	scent_aura.position = Vector3(0, 1.2, 0)
	add_child(scent_aura)

	# Голова и фонарик
	var head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.55, 0)
	add_child(head)

	flashlight = SpotLight3D.new()
	flashlight.name = "SurvivorFlashlight"
	flashlight.spot_range = 16.0
	flashlight.spot_angle = 38.0
	flashlight.spot_angle_attenuation = 0.85
	flashlight.light_color = Color(0.98, 0.94, 0.82)
	flashlight.light_energy = 2.2
	flashlight.shadow_enabled = true
	flashlight.position = Vector3(0.18, -0.15, -0.2)
	head.add_child(flashlight)

	# 3D шаги
	step_audio = AudioStreamPlayer3D.new()
	step_audio.unit_size = 4.0
	step_audio.max_distance = 28.0
	if ResourceLoader.exists("res://assets/audio/player_step.wav"):
		step_audio.stream = load("res://assets/audio/player_step.wav")
	add_child(step_audio)

func _setup_nav() -> void:
	nav_agent = NavigationAgent3D.new()
	nav_agent.path_desired_distance = 0.3
	nav_agent.target_desired_distance = 0.8
	add_child(nav_agent)

func set_waypoints(pts: Array[Vector3]) -> void:
	waypoints = pts.duplicate()
	wp_idx = 0

func _physics_process(delta: float) -> void:
	if GameManager.game_ended:
		velocity = Vector3.ZERO
		return
	decision_timer = maxf(0.0, decision_timer - delta)
	breath_recovery = maxf(0.0, breath_recovery - delta)
	if breath_held:
		oxygen = maxf(0.0, oxygen - delta / 7.0)
		if oxygen <= 0.0:
			breath_held = false
			breath_recovery = 3.5
	else:
		oxygen = minf(1.0, oxygen + delta / 5.0)
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = -0.5

	# ── Защита от вылета за пределы карты ──
	if global_position.y < -0.8 or global_position.y > 6.0:
		global_position.y = 0.1
		velocity.y = 0.0

	var nav_map = get_world_3d().navigation_map
	if not is_hiding and nav_map.is_valid() and NavigationServer3D.map_get_iteration_id(nav_map) > 0:
		var closest = NavigationServer3D.map_get_closest_point(nav_map, global_position)
		if global_position.distance_to(closest) > 2.0:
			global_position = closest + Vector3(0, 0.05, 0)
			velocity = Vector3.ZERO

	if bottle_cooldown > 0.0:
		bottle_cooldown -= delta
	else:
		can_throw_bottle = true

	if double_back_cooldown > 0.0:
		double_back_cooldown -= delta

	var enemy = GameManager.enemy_ref
	var e_pos = enemy.global_position if (enemy and is_instance_valid(enemy)) else Vector3.ZERO
	var e_dist = global_position.distance_to(e_pos) if (enemy and is_instance_valid(enemy)) else 999.0
	var has_los = _check_los_to_enemy(enemy)

	var enemy_sprinting = (enemy and "velocity" in enemy and enemy.velocity.length() > 4.5)
	var heard_threat = enemy_sprinting and e_dist < 15.0
	threat_age += delta
	if (has_los and e_dist < 32.0) or heard_threat:
		threat_position = e_pos
		threat_age = 0.0

	match state:
		BotState.WANDER:
			_do_wander(delta, e_dist, has_los, heard_threat)
		BotState.FLEE_RUN:
			_do_flee_run(delta, enemy, e_dist, has_los)
		BotState.JUKE:
			_do_juke(delta)
		BotState.DOUBLE_BACK:
			_do_double_back(delta, enemy)
		BotState.TEMP_HIDE:
			_do_temp_hide(delta, e_dist)
		BotState.BURST_OUT:
			_do_burst_out(delta, enemy)

	if not is_hiding:
		move_and_slide()
		_handle_footsteps(delta)
		_check_door_interactions()
		_update_sprite_perspective()

func _update_sprite_perspective() -> void:
	if not body_sprite:
		return
	var cam = get_viewport().get_camera_3d()
	if not cam:
		return

	var to_cam = (cam.global_position - global_position)
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.001:
		return
	to_cam = to_cam.normalized()

	var fwd = -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()

	var right = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var dot_fwd = fwd.dot(to_cam)
	var dot_right = right.dot(to_cam)

	if dot_fwd > 0.60:
		body_sprite.texture = tex_front if tex_front else tex_back
	elif dot_fwd < -0.60:
		body_sprite.texture = tex_back if tex_back else tex_front
	elif dot_right > 0.0:
		body_sprite.texture = tex_right if tex_right else tex_front
	else:
		body_sprite.texture = tex_left if tex_left else tex_front

	# Покачивание при беге
	var h_vel = Vector2(velocity.x, velocity.z).length()
	if h_vel > 0.3:
		anim_walk_t += 0.016 * h_vel * 3.5
		body_sprite.position.y = 0.90 + sin(anim_walk_t) * 0.04
	else:
		body_sprite.position.y = move_toward(body_sprite.position.y, 0.90, 0.02)

func _handle_footsteps(delta: float) -> void:
	var h_spd = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and h_spd > 0.4:
		var freq = 0.28 if state in [BotState.FLEE_RUN, BotState.BURST_OUT] else 0.52
		step_timer += delta
		if step_timer >= freq:
			step_timer = 0.0
			if step_audio and step_audio.stream:
				step_audio.pitch_scale = randf_range(0.92, 1.12)
				step_audio.play()
			var noise_rad = 16.0 if h_spd > 4.5 else 7.0
			GameManager.emit_signal("noise_made", global_position, noise_rad)
	else:
		step_timer = 0.0

func _do_wander(delta: float, _e_dist: float, has_los: bool, heard_threat: bool) -> void:
	breath_held = false
	if has_los or heard_threat:
		state = BotState.FLEE_RUN
		decision_timer = 0.0
		return
	if waypoints.is_empty():
		velocity = Vector3.ZERO
		return
	repath_timer += delta
	if repath_timer > 1.0 or nav_agent.is_navigation_finished():
		repath_timer = 0.0
		wp_idx = (wp_idx + 1) % waypoints.size()
		nav_agent.target_position = waypoints[wp_idx]
	_follow_route(delta, speed_walk)

func _do_flee_run(delta: float, _enemy: Node3D, _e_dist: float, has_los: bool) -> void:
	breath_held = false
	if threat_age > 12.0 and not has_los:
		state = BotState.WANDER
		return
	if decision_timer <= 0.0:
		decision_timer = 0.9
		if not has_los and threat_age > 1.0 and threat_age < 6.0:
			var spot = _find_nearest_hiding()
			if spot:
				current_hiding_spot = spot
				hiding_type = str(spot.get_meta("hiding_type", "wardrobe"))
				hiding_timer = 0.0
				max_hide_duration = 11.0
				nav_agent.target_position = _hide_approach(spot)
				state = BotState.TEMP_HIDE
				return
		if not has_los and can_throw_bottle and threat_age < 5.0:
			_throw_distraction_bottle(_enemy)
		escape_target = _choose_escape_target()
		nav_agent.target_position = escape_target
	_follow_route(delta, speed_run)

func _start_juke() -> void:
	state = BotState.JUKE
	juke_timer = 0.38 # 0.38 секунды бежит в фейковую сторону
	var fwd = -global_transform.basis.z
	var side = global_transform.basis.x
	var pick_left = randf() > 0.5
	juke_fake_dir = (fwd + (side * (-1.0 if pick_left else 1.0))).normalized()
	juke_real_dir = (fwd + (side * (1.0 if pick_left else -1.0))).normalized()
	emit_signal("survivor_juked")

func _do_juke(delta: float) -> void:
	juke_timer -= delta
	if juke_timer > 0.0:
		# Фальшивое направление (обман охотника)
		velocity.x = juke_fake_dir.x * speed_run
		velocity.z = juke_fake_dir.z * speed_run
		rotation.y = lerp_angle(rotation.y, atan2(-juke_fake_dir.x, -juke_fake_dir.z), delta * 14.0)
	else:
		# Резкий разворот в настоящее спасительное направление на форсаже!
		velocity.x = juke_real_dir.x * speed_sprint_burst
		velocity.z = juke_real_dir.z * speed_sprint_burst
		rotation.y = lerp_angle(rotation.y, atan2(-juke_real_dir.x, -juke_real_dir.z), delta * 16.0)
		state = BotState.FLEE_RUN

func _start_double_back(enemy: Node3D) -> void:
	state = BotState.DOUBLE_BACK
	double_back_cooldown = 8.0
	juke_timer = 0.45

func _do_double_back(delta: float, enemy: Node3D) -> void:
	juke_timer -= delta
	if juke_timer > 0.0 and enemy:
		# Огибаем монстра по дуге на форсаже
		var flank_dir = (enemy.global_position - global_position).cross(Vector3.UP).normalized()
		if randf() > 0.5: flank_dir = -flank_dir
		var escape_dir = (flank_dir + transform.basis.z).normalized()
		velocity.x = escape_dir.x * speed_sprint_burst
		velocity.z = escape_dir.z * speed_sprint_burst
		rotation.y = lerp_angle(rotation.y, atan2(-escape_dir.x, -escape_dir.z), delta * 14.0)
	else:
		state = BotState.FLEE_RUN

func _do_temp_hide(delta: float, e_dist: float) -> void:
	if not is_instance_valid(current_hiding_spot):
		exit_hiding()
		return
	if not is_hiding:
		hiding_timer += delta
		# Never disappear at a distant unreachable path endpoint or in plain sight.
		if _check_los_to_enemy(GameManager.enemy_ref) or hiding_timer > 6.0:
			exit_hiding()
			return
		var approach: Vector3 = _hide_approach(current_hiding_spot)
		if global_position.distance_to(approach) > 1.15:
			_follow_route(delta, speed_run)
			return
		hide_exit_position = global_position
		is_hiding = true
		hiding_timer = 0.0
		var anchor = current_hiding_spot.find_child("HideAnchor", true, false) as Node3D
		if anchor:
			global_position = anchor.global_position
		get_node("BodyCollider").set_deferred("disabled", true)
		visible = false
		if flashlight: flashlight.visible = false
		emit_signal("survivor_hid", current_hiding_spot)
	hiding_timer += delta
	velocity = Vector3.ZERO
	breath_held = e_dist < 6.0 and oxygen > 0.0 and breath_recovery <= 0.0
	# Stay quiet as the monster passes. Leave only when safe or air runs out.
	if (hiding_timer > 3.0 and e_dist > 9.0) or hiding_timer > max_hide_duration or (oxygen < 0.08 and e_dist < 3.0):
		exit_hiding()

func _do_burst_out(delta: float, _enemy: Node3D) -> void:
	_follow_route(delta, speed_sprint_burst)
	juke_timer -= delta
	if juke_timer <= 0.0:
		state = BotState.FLEE_RUN

func _throw_distraction_bottle(enemy: Node3D) -> void:
	can_throw_bottle = false
	bottle_cooldown = 10.0
	var throw_dir = -transform.basis.z.rotated(Vector3.UP, randf_range(-PI * 0.5, PI * 0.5)).normalized()
	var landing_pos = global_position + throw_dir * randf_range(7.0, 12.0)
	landing_pos.y = 0.2

	emit_signal("survivor_thrown_bottle", global_position, landing_pos)
	GameManager.emit_noise(landing_pos, 22.0, "bottle")

	if ResourceLoader.exists("res://assets/audio/maglock_release.wav"):
		var p = AudioStreamPlayer3D.new()
		p.stream = load("res://assets/audio/maglock_release.wav")
		p.position = landing_pos
		p.unit_size = 5.5
		p.max_distance = 35.0
		get_parent().add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())

func _check_door_interactions() -> void:
	# Захлопываем дверь за собой при беге
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var c = col.get_collider()
		if c and (c.is_in_group("doors") or "door" in c.name.to_lower()):
			var door_node = c.get_parent() if c.has_method("interact") else c
			if door_node != last_door_passed:
				last_door_passed = door_node
				if door_node.has_method("interact") and state in [BotState.FLEE_RUN, BotState.BURST_OUT]:
					door_node.call("interact")
					emit_signal("survivor_slammed_door", door_node)

func _check_los_to_enemy(enemy: Node3D) -> bool:
	if not enemy or not is_instance_valid(enemy):
		return false
	if global_position.distance_to(enemy.global_position) > 32.0:
		return false
	var space = get_world_3d().direct_space_state
	var p1 = global_position + Vector3(0, 1.4, 0)
	var p2 = enemy.global_position + Vector3(0, 1.4, 0)
	var exc: Array[RID] = [get_rid(), enemy.get_rid()]
	var q = PhysicsRayQueryParameters3D.create(p1, p2, 1, exc)
	var hit = space.intersect_ray(q)
	return hit.is_empty()

func _find_nearest_hiding() -> Node3D:
	var best: Node3D = null
	var best_score: float = -INF
	for candidate in get_tree().get_nodes_in_group("hiding_spots"):
		if not is_instance_valid(candidate) or not candidate is Node3D:
			continue
		var approach: Vector3 = _hide_approach(candidate)
		if global_position.distance_to(approach) > 8.0 or approach.distance_to(threat_position) < 5.0:
			continue
		var path: PackedVector3Array = _reachable_path(approach)
		if path.is_empty() or not _occluded_from_threat(approach):
			continue
		var score: float = approach.distance_to(threat_position) - global_position.distance_to(approach)
		if score > best_score:
			best_score = score
			best = candidate
	return best

func get_breath_noise_level() -> float:
	if breath_recovery > 0.0:
		return 0.9
	if breath_held:
		return 0.02
	return 0.25 if is_hiding else 0.50

func die() -> void:
	if is_hiding:
		exit_hiding()
	emit_signal("survivor_caught")
	velocity = Vector3.ZERO
	is_hiding = false
	visible = true
	var p = get_parent()
	if p and p.has_method("_respawn_bot"):
		p.call("_respawn_bot")

func _hide_approach(spot: Node3D) -> Vector3:
	var marker = spot.find_child("ExitAnchor", true, false) as Node3D
	if marker:
		return marker.global_position
	return spot.to_global(Vector3(0, 0, 1.05))

func exit_hiding() -> void:
	if is_hiding:
		global_position = hide_exit_position
	is_hiding = false
	breath_held = false
	visible = true
	if flashlight: flashlight.visible = true
	get_node("BodyCollider").set_deferred("disabled", false)
	current_hiding_spot = null
	hiding_type = ""
	state = BotState.BURST_OUT
	juke_timer = 0.8
	escape_target = _choose_escape_target()
	nav_agent.target_position = escape_target
	decision_timer = 0.9
	emit_signal("survivor_burst_out")

func _reachable_path(target: Vector3) -> PackedVector3Array:
	var nav_map: RID = nav_agent.get_navigation_map()
	if not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
		return PackedVector3Array()
	var projected: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, target)
	if projected.distance_to(target) > 1.0:
		return PackedVector3Array()
	var path: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, global_position, projected, true)
	if path.is_empty() or path[path.size()-1].distance_to(projected) > 0.75:
		return PackedVector3Array()
	return path

func _occluded_from_threat(point: Vector3) -> bool:
	var excludes: Array[RID] = [get_rid()]
	if is_instance_valid(GameManager.enemy_ref):
		excludes.append(GameManager.enemy_ref.get_rid())
	var query = PhysicsRayQueryParameters3D.create(threat_position + Vector3.UP * 1.3, point + Vector3.UP * 1.3, 1, excludes)
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _choose_escape_target() -> Vector3:
	var candidates: Array[Vector3] = waypoints.duplicate()
	for i in range(12):
		var angle: float = TAU * float(i) / 12.0
		candidates.append(global_position + Vector3(cos(angle),0,sin(angle)) * 8.0)
	var best: Vector3 = global_position
	var best_score: float = -INF
	for candidate in candidates:
		var path: PackedVector3Array = _reachable_path(candidate)
		if path.size() < 2:
			continue
		var route_length: float = 0.0
		var clearance: float = INF
		for i in range(1, path.size()):
			route_length += path[i-1].distance_to(path[i])
			# Check segments as well as corners so a route cannot run through the hunter.
			var near: Vector3 = Geometry3D.get_closest_point_to_segment(threat_position, path[i-1], path[i])
			clearance = minf(clearance, near.distance_to(threat_position))
		var score: float = candidate.distance_to(threat_position) * 1.4 + minf(clearance, 10.0) * 2.0 - route_length * 0.35
		if clearance < 2.5: score -= 35.0
		if _occluded_from_threat(candidate): score += 8.0
		for previous in recent_targets:
			if previous.distance_to(candidate) < 2.0: score -= 6.0
		if score > best_score:
			best_score = score
			best = path[path.size()-1]
	recent_targets.append(best)
	if recent_targets.size() > 4: recent_targets.pop_front()
	return best

func _follow_route(delta: float, speed: float) -> void:
	var next: Vector3 = nav_agent.get_next_path_position()
	var direction: Vector3 = Vector3(next.x-global_position.x, 0, next.z-global_position.z).normalized()
	if nav_agent.is_navigation_finished(): direction = Vector3.ZERO
	if direction.length_squared() > 0.01 and test_move(global_transform, direction * 0.5):
		var best_dir: Vector3 = Vector3.ZERO
		for angle in [0.65, -0.65, 1.2, -1.2, 1.8, -1.8]:
			var alternative: Vector3 = direction.rotated(Vector3.UP, angle)
			if not test_move(global_transform, alternative * 0.55):
				best_dir = alternative
				break
		direction = best_dir
	velocity.x = move_toward(velocity.x, direction.x * speed, delta * 18.0)
	velocity.z = move_toward(velocity.z, direction.z * speed, delta * 18.0)
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 10.0)
	if global_position.distance_to(progress_anchor) > 0.35:
		progress_anchor = global_position
		no_progress_time = 0.0
	else:
		no_progress_time += delta
	if no_progress_time > 1.4:
		no_progress_time = 0.0
		if state == BotState.TEMP_HIDE:
			exit_hiding()
		else:
			escape_target = _choose_escape_target()
			nav_agent.target_position = escape_target
			decision_timer = 1.2
