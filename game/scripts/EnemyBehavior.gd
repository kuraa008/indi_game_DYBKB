extends CharacterBody3D
class_name EnemyBehavior
## Fixed, sensory-driven NPC. No training files, global player tracking or wall sliding heuristics.
const Navigator = preload("res://scripts/EnemyNavigator.gd")
const WorldActions = preload("res://scripts/EnemyWorldActions.gd")
const Brain = preload("res://scripts/EnemyBrain.gd")
const GRAVITY := 18.0
const LOST_SIGHT_SECONDS := 10.0
const SEARCH_SECONDS := 18.0
# Preserve numeric state IDs consumed by HUD/debug tooling.
enum State { PATROL, ROUTINE, ALERT, HUNT, SEARCH, INVESTIGATE_BASEMENT, RAGE, AMBUSH, INSPECT_HIDING, STAKEOUT_HIDING }
var state: State = State.PATROL
var state_timer := 0.0
var ai_thought := "Обхожу дом"
var speed_patrol := 1.38
var speed_search := 2.02
var speed_hunt := 4.52
var speed_rage := 4.52
var hearing_walk := 12.0
var hearing_run := 26.0
var hearing_normal := 8.0
var hearing_exhale := 16.0
var sight_range := 32.0
var hunt_lose_time := LOST_SIGHT_SECONDS
var search_duration := SEARCH_SECONDS
var catch_distance := 1.75
var last_known_player_pos := Vector3.ZERO
var time_since_last_seen := 999.0
var last_nav_target := Vector3.ZERO
var current_debug_path := PackedVector3Array()
var navigation_stall_time := 0.0
var navigation_recoveries := 0
var stuck_timer := 0.0
var target_yaw := 0.0
var anim_t := 0.0
var hunt_rage_buildup := 0.0
var routine_action := ""
var routine_target_node: Variant = null
var witnessed_hiding_spot: Variant = null
var stakeout_target_spot: Variant = null
var stakeout_timer: float = 0.0
var silence_timer: float = 0.0
var hiding_spot_cooldowns: Dictionary = {}
var search_points: Array[Vector3] = []
var waypoints: Array[Vector3] = []
var navigator: RefCounted
var world_actions: RefCounted
var brain: RefCounted
var _sense_timer := 0.0
var _visible := false
var _last_player_hidden := false
var _goal := Vector3.ZERO
var _goal_age := 0.0
var _pause := 0.0
var _search_origin := Vector3.ZERO
var _search_index := 0
var _job: Dictionary = {}
var _job_started := false
var _job_duration := 0.0
var _job_timer := 0.0
var _job_cooldowns: Dictionary = {}
var _barricade_done := false
var _barricade_retry := 0.0
var _stun := 0.0
var _clock := 0.0
var _desired_speed := 0.0
var _progress_anchor := Vector3.ZERO
var _progress_timer := 0.0
var _scan_timer := 0.0
var _doing_world_action := false
var _home := Vector3.ZERO
var _blocked_time := 0.0
var _retreat_time := 0.0
var _retreat_goal := Vector3.ZERO
var _retreat_cooldown := 0.0
var _safe_trail: Array[Vector3] = []

# ── Реакция на свет фонарика ──
var flashlight_suspicion_timer: float = 0.0
var is_blinded_by_light: bool = false
var has_warned_light: bool = false

# ── Звуки шагов скинволкера ──
var monster_step_audio: AudioStreamPlayer3D = null
var monster_step_streams: Array[AudioStream] = []
var monster_step_idx: int = 0
var monster_step_cycle: float = 0.0
var monster_last_step_phase: int = 0

func uses_fixed_behavior() -> bool:
	return true

func _ready() -> void:
	floor_snap_length = 0.45
	floor_max_angle = deg_to_rad(60.0)
	floor_constant_speed = true
	floor_block_on_wall = true
	max_slides = 6
	safe_margin = 0.02
	_build_visual()
	navigator = Navigator.new(self)
	world_actions = WorldActions.new(self)
	brain = Brain.new(self)
	GameManager.noise_made.connect(on_noise_heard)
	GameManager.door_state_changed.connect(on_door_altered)
	GameManager.enemy_go_basement.connect(_on_go_basement)
	_goal = global_position
	_home = global_position
	_progress_anchor = global_position

	monster_step_audio = AudioStreamPlayer3D.new()
	monster_step_audio.name = "MonsterStepAudio"
	monster_step_audio.unit_size = 3.5
	monster_step_audio.max_distance = 25.0
	monster_step_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(monster_step_audio)

	if ResourceLoader.exists("res://assets/audio/step_1.mp3"):
		monster_step_streams.append(load("res://assets/audio/step_1.mp3"))
	if ResourceLoader.exists("res://assets/audio/step_2.mp3"):
		monster_step_streams.append(load("res://assets/audio/step_2.mp3"))

func _physics_process(delta: float) -> void:
	if GameManager.game_ended or GameManager.is_no_ai:
		velocity = Vector3.ZERO
		return
	_clock += delta
	state_timer += delta
	anim_t += delta
	time_since_last_seen += delta
	_goal_age += delta
	_scan_timer -= delta
	_barricade_retry = maxf(0.0, _barricade_retry - delta)
	if _scan_timer <= 0.0:
		_scan_timer = 12.0
		world_actions.scan()
		_build_patrol_points()
	world_actions.tick(delta)
	navigator.tick(delta)
	brain.tick(delta)
	_retreat_cooldown = maxf(0.0, _retreat_cooldown - delta)
	_desired_speed = 0.0
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = 0.12
		_check_senses()
	_check_flashlight_reaction(delta)
	_stun = maxf(0.0, _stun - delta)

	# Проверка укрытия рядом (во всех состояниях, кроме уже активного прислушивания или осмотра)
	if state != State.STAKEOUT_HIDING and state != State.INSPECT_HIDING:
		if _sense_timer <= 0.06:
			var p_ref: Variant = _player()
			if p_ref != null and p_ref.get("is_hiding") == true:
				var h_spot: Variant = p_ref.get("hiding_node")
				if is_instance_valid(h_spot) and h_spot is Node3D:
					var s_dist: float = global_position.distance_to(h_spot.global_position)
					var s_cd: float = float(hiding_spot_cooldowns.get(h_spot.get_instance_id(), 0.0))
					if s_dist <= 3.2 and (state in [State.HUNT, State.RAGE] or _clock >= s_cd):
						if witnessed_hiding_spot == h_spot:
							_set_state(State.INSPECT_HIDING)
						else:
							stakeout_target_spot = h_spot
							stakeout_timer = 0.0
							silence_timer = 0.0
							_set_state(State.STAKEOUT_HIDING)

	if _stun > 0.0:
		_brake(delta, 12.0)
	elif _retreat_time > 0.0:
		_do_retreat(delta)
	else:
		match state:
			State.HUNT, State.RAGE: _do_hunt(delta)
			State.SEARCH, State.ALERT, State.INVESTIGATE_BASEMENT: _do_search(delta)
			State.AMBUSH: _do_ambush(delta)
			State.ROUTINE: _do_routine(delta)
			State.INSPECT_HIDING: _do_inspect_hiding(delta)
			State.STAKEOUT_HIDING: _do_stakeout_hiding(delta)
			_: _do_patrol(delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	_try_step(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	if is_on_floor() and navigator.body_clear(global_position, false):
		if _safe_trail.is_empty() or global_position.distance_to(_safe_trail[-1]) > 0.5:
			_safe_trail.append(global_position)
			if _safe_trail.size() > 16:
				_safe_trail.pop_front()
	_update_progress(delta)
	_check_catch_always()
	_animate(delta)

func _player() -> Variant:
	var player: Variant = GameManager.player_ref
	return player if is_instance_valid(player) and player is Node3D else null

func _has_player() -> bool:
	return _player() != null

func _is_furniture_or_door(col: Object) -> bool:
	if not is_instance_valid(col):
		return true
	if col is CollisionObject3D and col.is_in_group("doors"):
		return true
	var curr: Node = col as Node
	var depth := 0
	while is_instance_valid(curr) and depth < 5:
		if curr.is_in_group("doors") or curr.has_method("open_by_enemy") or curr.has_method("is_door_locked"):
			return true
		for meta_key in ["prefab_type", "item_type", "prop_type", "door_type"]:
			if curr.has_meta(meta_key):
				var val := str(curr.get_meta(meta_key)).to_lower()
				if "door" in val or "table" in val or "chair" in val or "desk" in val or "dresser" in val or "nightstand" in val or "bed" in val or "cupboard" in val or "shelf" in val or "sofa" in val or "couch" in val or "counter" in val or "prop_" in val:
					return true
		var n_name := curr.name.to_lower()
		if "door" in n_name or "table" in n_name or "chair" in n_name or "desk" in n_name or "dresser" in n_name or "nightstand" in n_name or "bed" in n_name or "cupboard" in n_name or "shelf" in n_name or "sofa" in n_name or "counter" in n_name:
			return true
		curr = curr.get_parent()
		depth += 1
	return false

func _ray_visible(point: Vector3, accepted: Variant = null, ignore_walls: bool = false) -> bool:
	var from_pos := global_position + Vector3.UP * 1.65
	var exclude_list: Array[RID] = [get_rid()]
	var space := get_world_3d().direct_space_state
	for i in range(12):
		var q := PhysicsRayQueryParameters3D.create(from_pos, point, 1, exclude_list)
		q.collide_with_areas = false
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return true
		var col: Object = hit.collider
		if not is_instance_valid(col):
			return true
		if is_instance_valid(accepted) and (col == accepted or (accepted is Node and accepted.is_ancestor_of(col))):
			return true
		if col.has_method("die") or "player" in col.name.to_lower():
			return true
		if _is_furniture_or_door(col):
			exclude_list.append(hit.rid)
			continue
		if ignore_walls:
			exclude_list.append(hit.rid)
			continue
		return false
	return false

func _can_see_player() -> bool:
	var player: Variant = _player()
	if player == null or player.get("is_dead") == true or player.get("is_hiding") == true:
		return false
	var offset: Vector3 = player.global_position - global_position
	var dist := offset.length()
	if dist > sight_range + brain.sight_bonus():
		return false

	# 1. При активной охоте монстр чует и видит игрока сквозь любые стены, столы и двери!
	if state in [State.HUNT, State.RAGE]:
		return true

	# 2. Непосредственная близость (в пределах 2.2м прямо рядом с монстром)
	if dist <= 2.2:
		return true

	# 3. Вне зоны прямого чутья: конус обзора (проверяем горизонтальный угол, чтобы высота не срезала обзор)
	var flat := Vector3(offset.x, 0, offset.z)
	if flat.length() > 2.0 and (-global_transform.basis.z).dot(flat.normalized()) < cos(deg_to_rad(80.0)):
		return false

	# Физическая трассировка к голове, груди, поясу и ногам (если чисто по вертикали — видит на любой высоте!)
	return _ray_visible(player.global_position + Vector3.UP * 1.65, player) \
		or _ray_visible(player.global_position + Vector3.UP * 1.25, player) \
		or _ray_visible(player.global_position + Vector3.UP * 0.65, player) \
		or _ray_visible(player.global_position + Vector3.UP * 0.25, player)

func _check_senses() -> void:
	var player: Variant = _player()
	if player == null:
		_visible = false
		return
	var hidden: bool = player.get("is_hiding") == true
	if hidden and not _last_player_hidden and time_since_last_seen < 1.2:
		var spot: Variant = player.get("hiding_node")
		if is_instance_valid(spot) and _ray_visible(player.global_position + Vector3.UP, spot):
			witnessed_hiding_spot = spot
	_last_player_hidden = hidden
	_visible = _can_see_player()
	if _visible:
		last_known_player_pos = player.global_position
		time_since_last_seen = 0.0
		witnessed_hiding_spot = null
		brain.conclude_noise_investigation(true)
		if state != State.HUNT and state != State.RAGE and _stun <= 0.0:
			_set_state(State.HUNT)
			ai_thought = "Вижу игрока — преследую!"

# ──────────────────────────────────────────────
#  Реакция на свет фонарика (справедливый баланс)
# ──────────────────────────────────────────────
func _check_flashlight_reaction(delta: float) -> void:
	if state in [State.HUNT, State.RAGE, State.INSPECT_HIDING]:
		_decay_flashlight_suspicion(delta)
		return

	var player: Variant = _player()
	if player == null or player.get("is_dead") == true or player.get("is_hiding") == true:
		_decay_flashlight_suspicion(delta)
		return

	if not player.get("flashlight_on"):
		_decay_flashlight_suspicion(delta)
		return

	var cam: Variant = player.get_node_or_null("Head/Camera3D")
	if not cam:
		cam = player.get("camera")
	if not cam or not (cam is Camera3D):
		_decay_flashlight_suspicion(delta)
		return

	var p_eye: Vector3 = cam.global_position
	var monster_center: Vector3 = global_position + Vector3(0, 1.25, 0)
	var dist: float = p_eye.distance_to(monster_center)

	# Максимальная дистанция луча фонарика: 14 метров
	if dist > 14.0:
		_decay_flashlight_suspicion(delta)
		return

	# Проверяем, светит ли фонарик игрока прямо на скинвокера (конус луча ~26 градусов)
	var cam_dir: Vector3 = -cam.global_transform.basis.z
	var to_monster: Vector3 = (monster_center - p_eye).normalized()
	var dot_beam: float = cam_dir.dot(to_monster)
	if dot_beam < 0.89:
		_decay_flashlight_suspicion(delta)
		return

	# Проверяем прямую трассировку (стены, закрытые двери блокируют свет)
	if not _ray_visible(p_eye, player):
		_decay_flashlight_suspicion(delta)
		return

	# СВЕТ ПОПАЛ НА СКИНВОКЕРА!
	is_blinded_by_light = true
	flashlight_suspicion_timer += delta

	# Монстр замирает и разворачивается к лучу света
	_brake(delta, 10.0)
	var p_pos: Vector3 = player.global_position
	var flat_look: Vector3 = (p_pos - global_position).normalized()
	flat_look.y = 0.0
	if flat_look.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat_look.x, -flat_look.z), 4.0 * delta)

	ai_thought = "Свет обжигает глаза..."

	# Оповещаем UI с таймером
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_flashlight_warning"):
		var time_left: float = maxf(0.0, 2.0 - flashlight_suspicion_timer)
		GameManager.ui_ref.call("show_flashlight_warning", true, time_left, "Скинвокер")

	# Если игрок не погасил фонарик за 2.0 секунды — монстр начинает преследование!
	if flashlight_suspicion_timer >= 2.0:
		flashlight_suspicion_timer = 0.0
		is_blinded_by_light = false
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_flashlight_warning"):
			GameManager.ui_ref.call("show_flashlight_warning", false, 0.0)
		last_known_player_pos = player.global_position
		time_since_last_seen = 0.0
		witnessed_hiding_spot = null
		brain.conclude_noise_investigation(true)
		_set_state(State.HUNT)
		ai_thought = "Свет выдал жертву — преследую!"

func _decay_flashlight_suspicion(delta: float) -> void:
	if flashlight_suspicion_timer > 0.0:
		flashlight_suspicion_timer = maxf(0.0, flashlight_suspicion_timer - delta * 2.5)
		if flashlight_suspicion_timer <= 0.0:
			has_warned_light = false
			is_blinded_by_light = false
			if GameManager.ui_ref and GameManager.ui_ref.has_method("show_flashlight_warning"):
				GameManager.ui_ref.call("show_flashlight_warning", false, 0.0)

func _do_hunt(delta: float) -> void:
	var player: Variant = _player()
	var player_active: bool = is_instance_valid(player) and not player.get("is_dead") and not player.get("is_hiding")
	if player_active:
		last_known_player_pos = player.global_position
		time_since_last_seen = 0.0

	if time_since_last_seen >= brain.hunt_memory_time():
		_start_search(last_known_player_pos)
		return
	if is_instance_valid(witnessed_hiding_spot):
		var spot_pos: Vector3 = witnessed_hiding_spot.global_position
		if _flat_dist(global_position, spot_pos) < 1.8 and _ray_visible(spot_pos + Vector3.UP, witnessed_hiding_spot):
			_set_state(State.INSPECT_HIDING)
			GameManager.set_monster_stare(true, "wardrobe", true)
			return
		var approach: Variant = _approach_point(witnessed_hiding_spot)
		if approach != null:
			_nav_move_to(approach, speed_hunt * brain.speed_multiplier(), delta)
		return

	# Если игрок спрятался в шкаф/кровать прямо во время погони — сразу прислушиваемся!
	if not player_active and is_instance_valid(player) and player.get("is_hiding") == true:
		var h_spot = player.get("hiding_node")
		if is_instance_valid(h_spot) and h_spot is Node3D:
			var s_dist = global_position.distance_to(h_spot.global_position)
			if s_dist <= 3.2:
				stakeout_target_spot = h_spot
				stakeout_timer = 0.0
				silence_timer = 0.0
				_set_state(State.STAKEOUT_HIDING)
				ai_thought = "Слышу дыхание рядом... Прислушиваюсь!"
				return

	ai_thought = "Догоняю жертву!"
	if _flat_dist(global_position, last_known_player_pos) < 0.45 and not _visible and not player_active:
		_brake(delta, 12.0)
		rotation.y += sin(state_timer * 1.8) * delta * 0.8
	else:
		if navigator.failed and navigator.cooldown <= 0.0:
			navigator.clear()
		# Brain: try to flank / take a shortcut
		var _sc: Variant = brain.suggest_shortcut(global_position, last_known_player_pos)
		if _sc != null:
			var floor_pt: Variant = navigator.floor_at(_sc)
			if floor_pt != null and navigator.body_clear(floor_pt):
				_nav_move_to(floor_pt, speed_hunt * brain.speed_multiplier(), delta)
				return
		brain.clear_shortcut()
		_nav_move_to(last_known_player_pos, speed_hunt * brain.speed_multiplier(), delta)

func _start_search(origin: Vector3) -> void:
	_set_state(State.SEARCH)
	_search_origin = origin
	_search_index = 0
	_barricade_done = false
	search_points.clear()
	search_points.append(origin)
	navigator.refresh_exclusions()
	for radius in [2.0, 4.0, 6.0]:
		for i in range(6):
			var angle: float = TAU * float(i) / 6.0 + radius
			var p: Variant = navigator.floor_at(origin + Vector3(cos(angle), 0, sin(angle)) * radius)
			if p != null and navigator.body_clear(p):
				search_points.append(p)
	# Brain: add smart search points (hot zones, remembered hiding spots)
	var smart_pts: Array = brain.get_smart_search_points(origin)
	for sp in smart_pts:
		search_points.append(sp)
	# Brain: check hiding spots nearby
	if brain.should_check_hiding_spots():
		var hiding: Array = brain.get_priority_hiding_spots(origin)
		for spot in hiding:
			search_points.append(spot.global_position)
	brain.begin_noise_investigation(origin)
	_goal = search_points[0]
	_goal_age = 0.0
	ai_thought = "Проверяю комнату и соседние проходы"

func _do_search(delta: float) -> void:
	if is_blinded_by_light:
		_brake(delta, 10.0)
		return
	if state_timer >= brain.search_time():
		witnessed_hiding_spot = null
		brain.conclude_noise_investigation(false)
		_set_state(State.PATROL)
		_pause = 2.0
		ai_thought = "След потерян. Возвращаюсь к делам"
		return
	if _pause > 0.0:
		_pause -= delta
		_brake(delta, 10.0)
		rotation.y += delta * 0.65
		return
	if not _barricade_done and state_timer > 3.0 and _barricade_retry <= 0.0:
		_barricade_retry = 2.0
		for prop in world_actions.movable:
			if is_instance_valid(prop) and global_position.distance_to(prop.global_position) < 1.7:
				if world_actions.perform({"node": prop, "action": "barricade"}, _search_origin):
					navigator.clear()
					_barricade_done = true
					break
	if _flat_dist(global_position, _goal) < 0.6 or _route_failed() or _goal_age > 5.0:
		# Brain: check nearby hiding spots before picking next point
		if brain.should_check_hiding_spots():
			var nearby_spots: Array = brain.get_priority_hiding_spots(global_position, 2.2)
			if not nearby_spots.is_empty():
				var spot: Node3D = nearby_spots[0]
				var player: Variant = _player()
				if player != null and player.get("is_hiding") == true and player.get("hiding_node") == spot:
					if witnessed_hiding_spot == spot:
						_set_state(State.INSPECT_HIDING)
						ai_thought = "ЧУЮ ЗАПАХ В ШКАФУ! ВЫХОДИ!"
						return
					elif _clock >= float(hiding_spot_cooldowns.get(spot.get_instance_id(), 0.0)):
						stakeout_target_spot = spot
						stakeout_timer = 0.0
						silence_timer = 0.0
						_set_state(State.STAKEOUT_HIDING)
						return
		_search_index += 1
		if _search_index >= search_points.size():
			_search_index = 0
		_goal = search_points[_search_index] if not search_points.is_empty() else global_position
		_goal_age = 0.0
		_pause = 0.9
		navigator.clear()
		return
	_nav_move_to(_goal, speed_search * brain.speed_multiplier(), delta)

func _do_ambush(delta: float) -> void:
	if not brain.is_ambushing:
		_set_state(State.PATROL)
		_pause = 1.0
		return
	if _flat_dist(global_position, brain.ambush_position) < 1.2:
		_brake(delta, 12.0)
		rotation.y += sin(state_timer * 0.8) * delta * 0.4
		ai_thought = "Засада... жду жертву..."
	else:
		_nav_move_to(brain.ambush_position, speed_patrol * brain.speed_multiplier(), delta)
		ai_thought = "Иду на позицию засады"

func _do_patrol(delta: float) -> void:
	if is_blinded_by_light:
		_brake(delta, 10.0)
		return
	if _pause > 0.0:
		_pause -= delta
		_brake(delta, 10.0)
		return
	if _flat_dist(global_position, _goal) < 0.6 or _route_failed() or _goal_age > 18.0:
		if _choose_routine():
			return
		# Brain: try ambush at hot zone
		var _ambush_pt: Variant = brain.suggest_ambush()
		if _ambush_pt != null:
			_goal = _ambush_pt
			_set_state(State.AMBUSH)
			ai_thought = "Засада — жду жертву в привычном месте"
			return
		# Brain: patrol toward hot zones
		var _brain_target: Variant = brain.suggest_patrol_target()
		if _brain_target != null:
			_goal = _brain_target
			ai_thought = "Проверяю подозрительную зону"
		elif not waypoints.is_empty():
			_goal = waypoints.pick_random()
		else:
			_goal = global_position
		_goal_age = 0.0
		navigator.clear()
		_pause = randf_range(0.6, 1.4)
		_brake(delta, 10.0)
		return
	_nav_move_to(_goal, speed_patrol * brain.speed_multiplier(), delta)

func _approach_point(node: Node3D) -> Variant:
	navigator.refresh_exclusions()
	var best: Variant = null
	var best_distance := INF
	for radius in [1.3, 1.9, 2.5]:
		for i in range(8):
			var angle := TAU * float(i) / 8.0
			var p: Variant = navigator.floor_at(Vector3(node.global_position.x, global_position.y, node.global_position.z) + Vector3(cos(angle), 0, sin(angle)) * radius)
			if p == null or not navigator.body_clear(p):
				continue
			# Interaction positions must face the furniture, not the opposite side of a wall.
			var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP, node.global_position + Vector3.UP * 0.7, 1, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty() and hit.collider != node and not node.is_ancestor_of(hit.collider):
				continue
			var distance := global_position.distance_to(p)
			if distance < best_distance:
				best_distance = distance
				best = p
	return best

func _choose_routine() -> bool:
	var candidates: Array = world_actions.jobs.duplicate()
	candidates.shuffle()
	for candidate in candidates:
		var node: Variant = candidate.node
		if not is_instance_valid(node) or _clock < float(_job_cooldowns.get(node.get_instance_id(), 0.0)):
			continue
		if global_position.distance_to(node.global_position) > 28.0:
			continue
		var target: Variant = _approach_point(node)
		if target == null:
			continue
		_job = candidate
		_job_cooldowns[node.get_instance_id()] = _clock + 35.0
		_goal = target
		routine_target_node = node
		routine_action = str(candidate.action)
		_job_started = false
		_job_timer = 0.0
		_job_duration = randf_range(3.0, 6.0)
		_set_state(State.ROUTINE)
		return true
	return false

func _do_routine(delta: float) -> void:
	if not is_instance_valid(routine_target_node) or (not _job_started and (_route_failed() or state_timer > 16.0)):
		_set_state(State.PATROL)
		_goal = global_position
		return
	if not _job_started:
		ai_thought = "Иду заниматься делами"
		if _flat_dist(global_position, _goal) > 0.55:
			_nav_move_to(_goal, speed_patrol, delta)
			return
		_job_started = true
		_doing_world_action = true
		world_actions.perform(_job, last_known_player_pos)
		_doing_world_action = false
	_brake(delta, 12.0)
	_job_timer += delta
	var facing: Vector3 = routine_target_node.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), minf(1.0, delta * 5.0))
	match routine_action:
		"prop_crt_tv", "prop_tv": ai_thought = "Смотрю телевизор"
		"prop_fridge": ai_thought = "Осматриваю холодильник"
		"prop_light_switch": ai_thought = "Проверяю освещение"
		_: ai_thought = "Осматриваю и поправляю вещи"
	if _job_timer >= _job_duration:
		_set_state(State.PATROL)
		_goal = waypoints.pick_random() if not waypoints.is_empty() else global_position
		_pause = 1.0

func _build_patrol_points() -> void:
	navigator.refresh_exclusions()
	waypoints.clear()
	var map := get_world_3d().navigation_map
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		for i in range(24):
			var p := NavigationServer3D.map_get_random_point(map, 1, true)
			if p.distance_to(_home) < 28.0 and absf(p.y - global_position.y) < 0.8 and navigator.body_clear(p):
				waypoints.append(p)
	if waypoints.size() < 6:
		for radius in [3.0, 6.0, 10.0]:
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var p: Variant = navigator.floor_at(global_position + Vector3(cos(a), 0, sin(a)) * radius)
				if p != null and navigator.body_clear(p):
					waypoints.append(p)

func _route_failed() -> bool:
	return navigator.failed and (navigator.path.is_empty() or navigator.cursor >= navigator.path.size())

func _nav_move_to(target: Vector3, speed: float, delta: float) -> void:
	_desired_speed = speed
	last_nav_target = target
	# A real wall contact can place the wider planning capsule inside the wall.
	# Recover before requesting a route from that invalid starting position.
	if _retreat_cooldown <= 0.0 and not navigator.body_clear(global_position, false) and is_on_wall():
		_begin_retreat(target - global_position)
		return
	if navigator.failed and navigator.goal.distance_to(target) > 1.0:
		navigator.clear()
	if not navigator.failed and not navigator.pending and navigator.cooldown <= 0.0 and (navigator.path.is_empty() or navigator.goal.distance_to(target) > 1.0):
		navigator.request(target)
	current_debug_path = navigator.path
	if navigator.pending:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var next: Vector3 = navigator.next_point()
	var to_next := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if to_next.length() < 0.08:
		_brake(delta, 16.0)
		return
	var direction := to_next.normalized()
	if world_actions.open_ahead(direction):
		navigator.refresh_exclusions()
	var preview := global_position + direction * minf(0.45, to_next.length())
	if not navigator.segment_clear(global_position, preview, false):
		if world_actions.open_ahead(direction):
			navigator.refresh_exclusions()
			_blocked_time = 0.0
			return
		velocity.x = 0.0
		velocity.z = 0.0
		_blocked_time += delta
		if world_actions.push_ahead(direction):
			navigator.clear()
			_blocked_time = 0.0
		elif _blocked_time > 0.65 and _retreat_cooldown <= 0.0:
			_begin_retreat(direction)
		return
	_blocked_time = 0.0
	# Slow for a corner and do not carry sideways inertia into an untested wall.
	var move_speed := minf(speed, maxf(0.6, to_next.length() * 4.0))
	move_speed = minf(move_speed, to_next.length() / maxf(delta, 0.001))
	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	target_yaw = atan2(-direction.x, -direction.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 10.0, 1.0))

func _update_progress(delta: float) -> void:
	if _retreat_time > 0.0 or _desired_speed <= 0.0 or navigator.pending or navigator.path.is_empty() or _flat_dist(global_position, last_nav_target) < 0.65:
		_progress_anchor = global_position
		_progress_timer = 0.0
		return
	_progress_timer += delta
	navigation_stall_time = _progress_timer
	stuck_timer = _progress_timer
	if _progress_timer > 0.85:
		_progress_timer = 0.0
		if _flat_dist(global_position, _progress_anchor) < 0.25 and _retreat_cooldown <= 0.0:
			_begin_retreat(navigator.next_point() - global_position)
		_progress_anchor = global_position

func _begin_retreat(blocked_direction: Vector3) -> void:
	if _retreat_time > 0.0:
		return
	navigation_recoveries += 1
	_retreat_cooldown = 1.5
	_blocked_time = 0.0
	navigator.remember_blocked_motion(blocked_direction)
	navigator.clear()
	velocity.x = 0.0
	velocity.z = 0.0
	var candidates: Array[Vector3] = []
	for i in range(_safe_trail.size() - 1, -1, -1):
		var distance := _flat_dist(global_position, _safe_trail[i])
		if distance >= 0.55 and distance <= 1.6:
			candidates.append(_safe_trail[i])
	var away := Vector3(-blocked_direction.x, 0, -blocked_direction.z).normalized()
	var wall_away := Vector3.ZERO
	for i in range(get_slide_collision_count()):
		var normal := get_slide_collision(i).get_normal()
		if absf(normal.y) < 0.3:
			wall_away += Vector3(normal.x, 0, normal.z)
	if wall_away.length_squared() > 0.01:
		away = wall_away.normalized()
	if away.length_squared() < 0.01:
		away = global_transform.basis.z.normalized()
	for angle in [0.0, 45.0, -45.0, 90.0, -90.0, 135.0, -135.0]:
		candidates.append(global_position + away.rotated(Vector3.UP, deg_to_rad(angle)) * 0.8)
	for point in candidates:
		if navigator.retreat_clear(point) and navigator.body_clear(point, false):
			_retreat_goal = point
			_retreat_time = 1.4
			ai_thought = "Отхожу от препятствия и выбираю обход"
			return
	navigator.request(last_nav_target, true)

func _do_retreat(delta: float) -> void:
	_retreat_time -= delta
	var offset := Vector3(_retreat_goal.x - global_position.x, 0, _retreat_goal.z - global_position.z)
	if offset.length() < 0.12 or _retreat_time <= 0.0 or not navigator.retreat_clear(_retreat_goal):
		_retreat_time = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		navigator.request(last_nav_target, true)
		return
	var speed := minf(1.4, offset.length() / maxf(delta, 0.001))
	velocity.x = offset.normalized().x * speed
	velocity.z = offset.normalized().z * speed

func _try_step(motion: Vector3) -> void:
	if motion.length() < 0.001:
		return
	if not test_move(global_transform, motion):
		return
	for height in [0.12, 0.22, 0.35, 0.48, 0.55]:
		var lift: Vector3 = Vector3.UP * float(height)
		var raised := global_transform.translated(lift)
		if not test_move(global_transform, lift) and not test_move(raised, motion.normalized() * 0.25):
			move_and_collide(lift)
			return

func _brake(delta: float, deceleration: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, delta * deceleration)
	velocity.z = move_toward(velocity.z, 0.0, delta * deceleration)

func _check_catch_always() -> void:
	var player: Variant = _player()
	if player == null or _stun > 0.0 or GameManager.is_godmode or player.get("is_hiding") == true or player.get("is_dead") == true:
		return
	if global_position.distance_to(player.global_position) < catch_distance and _ray_visible(player.global_position + Vector3.UP, player):
		if player.has_method("die"):
			player.call("die", self)

func _do_inspect_hiding(delta: float) -> void:
	_brake(delta, 20.0)
	if state_timer < 1.5:
		return
	GameManager.set_monster_stare(false, "", false)
	var player: Variant = _player()
	if player != null and is_instance_valid(witnessed_hiding_spot) and player.get("hiding_node") == witnessed_hiding_spot and player.get("is_hiding") == true:
		brain.record_catch_at_hiding_spot(witnessed_hiding_spot)
		if player.has_method("exit_hiding"):
			player.call("exit_hiding")
		if player.has_method("die") and not GameManager.is_godmode:
			player.call("die", self)
	_start_search(last_known_player_pos)

func _do_stakeout_hiding(delta: float) -> void:
	_brake(delta, 14.0)
	var player: Variant = _player()
	if player == null or player.get("is_hiding") != true or not is_instance_valid(stakeout_target_spot) or player.get("hiding_node") != stakeout_target_spot:
		stakeout_target_spot = null
		_set_state(State.PATROL)
		_goal = waypoints.pick_random() if not waypoints.is_empty() else global_position
		return

	# Поворачиваемся лицом к укрытию
	var to_spot: Vector3 = stakeout_target_spot.global_position - global_position
	to_spot.y = 0.0
	if to_spot.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-to_spot.x, -to_spot.z), minf(1.0, delta * 4.5))

	var is_holding: bool = player.has_method("is_breath_held") and bool(player.call("is_breath_held"))

	if is_holding:
		# Игрок задержал дыхание — монстр прислушивается в тишине
		silence_timer += delta
		stakeout_timer = maxf(0.0, stakeout_timer - delta * 0.5)
		ai_thought = "Прислушивается... (тишина %.1fс)" % maxf(0.0, 2.8 - silence_timer)

		# Если задержал дыхание ~2.8 сек — монстр решает, что шкаф/кровать пустые, и уходит по ДРУГОМУ маршруту!
		if silence_timer >= 2.8:
			hiding_spot_cooldowns[stakeout_target_spot.get_instance_id()] = _clock + 35.0
			ai_thought = "Никого нет... Пойду дальше"
			var distant_wp: Variant = _pick_distant_waypoint(14.0)
			if distant_wp != null:
				_goal = distant_wp
			else:
				_goal = waypoints.pick_random() if not waypoints.is_empty() else global_position
			stakeout_target_spot = null
			_pause = 1.0
			_set_state(State.PATROL)
			return
	else:
		# Игрок НЕ задерживает дыхание — монстр слышит шорох и дыхание и продолжает караулить!
		silence_timer = 0.0
		stakeout_timer += delta
		ai_thought = "Слышит дыхание... караулит укрытие (%.1fс)" % maxf(0.0, 5.0 - stakeout_timer)
		rotation.y += sin(state_timer * 2.8) * delta * 0.35

		# Если игрок не задерживает дыхание > 5.0 сек — монстр раскрывает укрытие и убивает игрока!
		if stakeout_timer >= 5.0:
			var target_spot = stakeout_target_spot
			stakeout_target_spot = null
			witnessed_hiding_spot = null
			ai_thought = "Я СЛЫШУ ДЫХАНИЕ! ВЫХОДИ!"
			GameManager.set_monster_stare(false, "", false)
			brain.record_catch_at_hiding_spot(target_spot)
			if player.has_method("exit_hiding"):
				player.call("exit_hiding")
			if player.has_method("die") and not GameManager.is_godmode:
				player.call("die", self)
			_start_search(last_known_player_pos)
			return

func _pick_distant_waypoint(min_dist: float) -> Variant:
	var candidates: Array[Vector3] = []
	for wp in waypoints:
		if global_position.distance_to(wp) >= min_dist:
			candidates.append(wp)
	if not candidates.is_empty():
		return candidates.pick_random()
	var map := get_world_3d().navigation_map
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		for i in range(16):
			var p := NavigationServer3D.map_get_random_point(map, 1, true)
			if global_position.distance_to(p) >= min_dist and absf(p.y - global_position.y) < 1.0:
				return p
	return null

func on_noise_heard(pos: Vector3, radius: float) -> void:
	if _doing_world_action or global_position.distance_to(pos) > radius or GameManager.game_ended or _stun > 0.0:
		return
	if state == State.STAKEOUT_HIDING:
		if is_instance_valid(stakeout_target_spot) and pos.distance_to(stakeout_target_spot.global_position) < 3.2:
			# При шумном выдохе/шорохе прямо в шкафу — мгновенное обнаружение!
			stakeout_timer = 99.0
			return
	# Sound never resets the ten-second visual memory and never gives live coordinates.
	if state in [State.HUNT, State.INSPECT_HIDING]:
		return

	# Реакция на бег игрока: если игрок бежит неподалёку, монстр мгновенно бросается на топот!
	var p_ref = GameManager.player_ref
	var is_player_running: bool = false
	if is_instance_valid(p_ref) and p_ref.get("is_sprinting") == true:
		if p_ref.global_position.distance_to(pos) < 3.5:
			is_player_running = true

	if is_player_running:
		ai_thought = "Слышу топот бегущей жертвы!"
		var dist_to_sound = global_position.distance_to(pos)
		if dist_to_sound < 14.0:
			_set_state(State.HUNT)
			last_known_player_pos = pos
			time_since_last_seen = 0.0
			return
		else:
			_start_search(pos)
			return

	# Brain: skepticism — ignore noises that look like decoys
	if brain.should_ignore_noise(pos):
		ai_thought = "Шум? Не куплюсь на уловки..."
		return
	if state == State.SEARCH:
		if search_points.size() < 22:
			search_points.append(pos)
		return
	_start_search(pos)

func alert_player_cough(pos: Vector3) -> void:
	if GameManager.game_ended or _stun > 0.0 or _doing_world_action:
		return
	var dist = global_position.distance_to(pos)
	if dist > 55.0:
		return
	if state == State.STAKEOUT_HIDING:
		stakeout_timer = 99.0
		return

	if ResourceLoader.exists("res://assets/audio/skinwalker_scream.wav"):
		var asp = AudioStreamPlayer3D.new()
		asp.stream = load("res://assets/audio/skinwalker_scream.wav")
		asp.unit_size = 6.0
		asp.max_distance = 45.0
		asp.volume_db = 4.0
		add_child(asp)
		asp.play()
		asp.finished.connect(func(): if is_instance_valid(asp): asp.queue_free())

	if dist < 22.0:
		_set_state(State.HUNT)
		last_known_player_pos = pos
		time_since_last_seen = 0.0
		ai_thought = "Слышу удушливый кашель! Жертва рядом!"
	else:
		_start_search(pos)
		ai_thought = "Громкий кашель в доме! Бегу на звук!"

func on_door_altered(door: Node, _open: bool) -> void:
	if not is_instance_valid(door) or not door is Node3D:
		return
	navigator.cooldown = 0.0
	if global_position.distance_to(door.global_position) > 2.2:
		on_noise_heard(door.global_position, 10.0)

func on_light_altered(_on: bool) -> void:
	# A global light event contains no position; it cannot reveal the player.
	pass

func _on_go_basement() -> void:
	if state == State.PATROL:
		_start_search(GameManager.player_spawn)

func trigger_rage() -> void:
	_start_search(last_known_player_pos)

func shock_by_electricity(duration: float = 8.0) -> void:
	_stun = clampf(duration, 0.5, 8.0)
	_set_state(State.SEARCH)
	_start_search(global_position)

func _set_state(next: State) -> void:
	if state == State.INSPECT_HIDING:
		GameManager.set_monster_stare(false, "", false)
	if next != State.STAKEOUT_HIDING:
		stakeout_target_spot = null
	if next == State.HUNT and state != State.HUNT:
		if has_method("play_creepy_voice"):
			call("play_creepy_voice", "groan")
	state = next
	state_timer = 0.0
	_goal_age = 0.0
	_pause = 0.0
	_progress_timer = 0.0
	navigator.clear()
	current_debug_path.clear()

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func reset_ai() -> void:
	_set_state(State.PATROL)
	_goal = global_position
	velocity = Vector3.ZERO
	_visible = false
	_stun = 0.0
	time_since_last_seen = 999.0
	witnessed_hiding_spot = null
	stakeout_target_spot = null
	stakeout_timer = 0.0
	silence_timer = 0.0
	hiding_spot_cooldowns.clear()
	search_points.clear()
	_job_cooldowns.clear()
	navigator.blocked_spots.clear()
	_safe_trail.clear()
	_retreat_time = 0.0
	_retreat_cooldown = 0.0
	_blocked_time = 0.0
	brain.reset()

func get_debug_navigation_path() -> PackedVector3Array:
	return navigator.path

func get_current_thought() -> String:
	return ai_thought + brain.get_thought_suffix()

func set_thought(text: String) -> void:
	ai_thought = text

func _build_visual() -> void:
	pass

func _animate(delta: float) -> void:
	var horiz_vel: float = Vector2(velocity.x, velocity.z).length()
	if horiz_vel > 0.4 and is_on_floor():
		monster_step_cycle += delta * horiz_vel * 1.55
		var step_phase: int = int(monster_step_cycle) % 2
		if step_phase != monster_last_step_phase:
			monster_last_step_phase = step_phase
			if not monster_step_streams.is_empty() and monster_step_audio:
				var st: AudioStream = monster_step_streams[monster_step_idx % monster_step_streams.size()]
				monster_step_idx += 1
				monster_step_audio.stream = st
				monster_step_audio.pitch_scale = randf_range(0.85, 1.05)
				monster_step_audio.volume_db = -13.0 if state in [State.HUNT, State.RAGE] else -16.0
				monster_step_audio.play()
	else:
		monster_step_cycle = 0.0
