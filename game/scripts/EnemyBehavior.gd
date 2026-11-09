extends CharacterBody3D
class_name EnemyBehavior
## Скинволкер. Простые и жёсткие правила:
## видит вплотную с любой стороны, заметил — кричит и бежит быстрее игрока,
## идёт кратчайшим путём по навмешу и пересчитывает его на бегу, нигде долго не стоит.
const Navigator = preload("res://scripts/EnemyNavigator.gd")
const WorldActions = preload("res://scripts/EnemyWorldActions.gd")
const Brain = preload("res://scripts/EnemyBrain.gd")
const GRAVITY := 18.0
const SENSE_INTERVAL := 0.1
# Зрение
const SIGHT_HALF_ANGLE := 75.0
const FOCUS_HALF_ANGLE := 140.0
const CLOSE_SENSE := 2.6          # вплотную чувствует с любой стороны
const INSTANT_NOTICE := 7.0       # ближе этого замечает сразу
# Скорости
const SPEED_PATROL := 2.6
const SPEED_SEARCH := 4.4
const SPEED_HUNT := 5.8           # почти как спринт игрока (6.2)
const SPEED_HUNT_FAR := 6.4       # издалека чуть быстрее спринта
const HUNT_FAR_DIST := 14.0
# Долгая погоня: после рывка бежит чуть медленнее спринта, но всё ещё быстрее шага
const HUNT_BURST_SECONDS := 5.0
const SPEED_HUNT_LONG := 4.4
# Вплотную бежит наравне со спринтом: бегом можно удержать дистанцию, шагом нет
const SPEED_HUNT_CLOSE := 5.0
# Не догнал за это время и отстал: бросает погоню и ищет
const HUNT_GIVE_UP_SECONDS := 12.0
const HUNT_GIVE_UP_DISTANCE := 6.0
const HUNT_CLOSE_DIST := 5.0
const ACCEL := 28.0
# Погоня
const TRACK_SECONDS := 0.8        # после потери из виду ещё чует, куда свернул игрок
const HUNT_MEMORY := 3.0          # потом бежит туда, куда игрок направлялся
const SEARCH_SECONDS := 14.0
const CATCH_HOLD := 0.35
const START_GRACE := 10.0
# Путь
const REPATH_SECONDS := 0.2
const POINT_REACHED := 0.4
const STUCK_WINDOW := 0.6
const STUCK_MIN_MOVE := 0.25
# Числовые ID состояний используют HUD и отладка
enum State { PATROL, ROUTINE, ALERT, HUNT, SEARCH, INVESTIGATE_BASEMENT, RAGE, AMBUSH, INSPECT_HIDING, STAKEOUT_HIDING, LISTEN, LURK, DASH }
var state: State = State.PATROL
var state_timer := 0.0
var ai_thought := "Обхожу дом"
# Настройки (читает AIReport)
var speed_patrol := SPEED_PATROL
var speed_search := SPEED_SEARCH
var speed_hunt := SPEED_HUNT
var speed_rage := SPEED_HUNT_FAR
var hearing_walk := 12.0
var hearing_run := 26.0
var hearing_normal := 8.0
var hearing_exhale := 16.0
var sight_range := 30.0
var hunt_lose_time := HUNT_MEMORY
var search_duration := SEARCH_SECONDS
var catch_distance := 1.6
# Общие поля (читают Enemy.gd, отладка, миникарта)
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
var awareness := 0.0
var is_blinded_by_light := false
var flashlight_suspicion_timer := 0.0
# Поля, которые читает модель (оставлены ради совместимости)
var _job_started := false
var _dash_recover := 0.0
var _silent := false
var _listen_heard := false
var _listen_pos := Vector3.ZERO
var _visible := false
var _stun := 0.0
var _clock := 0.0
var _desired_speed := 0.0
var _catch_hold := 0.0
var _last_contact := 0.0
var _doing_world_action := false
var _retreat_time := 0.0
# Внутреннее
var _sense_timer := 0.0
var _last_player_hidden := false
var _goal := Vector3.ZERO
var _goal_age := 0.0
var _pause := 0.0
var _search_index := 0
var _search_origin := Vector3.ZERO
var _recent_goals: Array[Vector3] = []
var _scan_timer := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _path_target := Vector3.INF
var _repath_t := 0.0
var _grid_wait := false
var _stuck_anchor := Vector3.ZERO
var _stuck_t := 0.0
var _stuck_count := 0
var _side_t := 0.0
var _side_dir := Vector3.ZERO
var _speed_now := 0.0
var _lit_time := 0.0
# Шаги для сцен без модели (Enemy.gd переопределяет _animate)
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
	_stuck_anchor = global_position
	monster_step_audio = AudioStreamPlayer3D.new()
	monster_step_audio.name = "MonsterStepAudio"
	monster_step_audio.unit_size = 3.5
	monster_step_audio.max_distance = 25.0
	monster_step_audio.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(monster_step_audio)
	for p in ["res://assets/audio/step_1.mp3", "res://assets/audio/step_2.mp3"]:
		if ResourceLoader.exists(p):
			monster_step_streams.append(load(p))

# ═══════════════════════════════════════════
#  Главный цикл
# ═══════════════════════════════════════════
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
	if _scan_timer <= 0.0:
		_scan_timer = 12.0
		world_actions.scan()
		_build_patrol_points()
	world_actions.tick(delta)
	navigator.tick(delta)
	brain.tick(delta)
	_desired_speed = 0.0
	_sense_timer -= delta
	if _sense_timer <= 0.0:
		_sense_timer = SENSE_INTERVAL
		_check_senses()
		_check_hiding_nearby()
	_check_flashlight(delta)
	_stun = maxf(0.0, _stun - delta)
	hunt_rage_buildup = move_toward(hunt_rage_buildup, 1.0 if state == State.HUNT else 0.0, delta * 0.5)

	if _stun > 0.0:
		_brake(delta)
	else:
		match state:
			State.HUNT, State.RAGE, State.DASH: _do_hunt(delta)
			State.SEARCH, State.ALERT, State.INVESTIGATE_BASEMENT, State.LISTEN, State.LURK, State.AMBUSH: _do_search(delta)
			State.INSPECT_HIDING: _do_inspect_hiding(delta)
			State.STAKEOUT_HIDING: _do_stakeout_hiding(delta)
			_: _do_patrol(delta)
	velocity.y = -0.5 if is_on_floor() else velocity.y - GRAVITY * delta
	_try_step(Vector3(velocity.x, 0, velocity.z) * delta)
	move_and_slide()
	_check_catch()
	_animate(delta)

func _player() -> Variant:
	var player: Variant = GameManager.player_ref
	return player if is_instance_valid(player) and player is Node3D else null

func _has_player() -> bool:
	return _player() != null

func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

# ═══════════════════════════════════════════
#  Зрение и слух
# ═══════════════════════════════════════════
func _door_of(col: Object) -> Node:
	var curr: Node = col as Node
	for i in range(5):
		if not is_instance_valid(curr):
			break
		if "is_open" in curr:
			return curr
		curr = curr.get_parent()
	return null

func _is_furniture(col: Object) -> bool:
	var curr: Node = col as Node
	for i in range(5):
		if not is_instance_valid(curr):
			break
		if curr.has_meta("prefab_type"):
			var v := str(curr.get_meta("prefab_type"))
			if v.begins_with("prop_") and not ("wall" in v):
				return true
		curr = curr.get_parent()
	return false

# Луч от глаз: стена и закрытая дверь заслоняют, мебель — только если through_furniture выключен
func _ray_visible(point: Vector3, accepted: Variant = null, ignore_walls: bool = false, through_furniture: bool = false) -> bool:
	var from_pos := global_position + Vector3.UP * 1.65
	var exclude_list: Array[RID] = [get_rid()]
	var space := get_world_3d().direct_space_state
	for i in range(10):
		var q := PhysicsRayQueryParameters3D.create(from_pos, point, 1, exclude_list)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return true
		var col: Object = hit.collider
		if not is_instance_valid(col):
			return true
		if is_instance_valid(accepted) and (col == accepted or (accepted is Node and accepted.is_ancestor_of(col))):
			return true
		if col.has_method("die") or "player" in str(col.get("name")).to_lower():
			return true
		var door := _door_of(col)
		if door != null:
			if not bool(door.get("is_open")):
				return false
			exclude_list.append(hit.rid)
			continue
		if (through_furniture and _is_furniture(col)) or ignore_walls:
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
	# Вплотную видит и чует с любой стороны
	if dist <= CLOSE_SENSE:
		return _ray_visible(player.global_position + Vector3.UP * 1.0, player, false, true)
	var hunting := state in [State.HUNT, State.RAGE, State.DASH]
	var reach: float = sight_range + brain.sight_bonus()
	if not hunting:
		if player.get("flashlight_on") == false:
			reach *= 0.6
		if player.get("is_crouching") == true:
			reach *= 0.85
	if dist > reach:
		return false
	var flat := Vector3(offset.x, 0, offset.z)
	var half := FOCUS_HALF_ANGLE if hunting else SIGHT_HALF_ANGLE
	if (-global_transform.basis.z).dot(flat.normalized()) < cos(deg_to_rad(half)):
		return false
	for h in [1.6, 1.1, 0.5]:
		if _ray_visible(player.global_position + Vector3.UP * h, player):
			return true
	return false

func _check_senses() -> void:
	var player: Variant = _player()
	if player == null:
		_visible = false
		return
	var hidden: bool = player.get("is_hiding") == true
	# Видел, как игрок залез в укрытие
	if hidden and not _last_player_hidden and time_since_last_seen < 1.5:
		var spot: Variant = player.get("hiding_node")
		if is_instance_valid(spot):
			witnessed_hiding_spot = spot
	_last_player_hidden = hidden
	var seen := _can_see_player() and _clock >= START_GRACE
	if seen and state not in [State.HUNT, State.RAGE, State.DASH]:
		var dist: float = global_position.distance_to(player.global_position)
		# Близко замечает сразу, издалека за долю секунды
		var need := 0.0 if dist < INSTANT_NOTICE else lerpf(0.25, 0.8, clampf((dist - INSTANT_NOTICE) / 20.0, 0.0, 1.0))
		if player.get("is_crouching") == true and dist > CLOSE_SENSE:
			need += 0.25
		awareness += SENSE_INTERVAL
		if awareness < need:
			_visible = false
			_face_point(player.global_position, SENSE_INTERVAL, 8.0)
			return
	elif not seen:
		awareness = 0.0
	_visible = seen
	if seen:
		_last_contact = _clock
		last_known_player_pos = player.global_position
		time_since_last_seen = 0.0
		brain.conclude_noise_investigation(true)
		if state not in [State.HUNT, State.RAGE, State.DASH, State.INSPECT_HIDING, State.STAKEOUT_HIDING]:
			_begin_hunt()

func _begin_hunt() -> void:
	var was_hunting := state in [State.HUNT, State.RAGE]
	_set_state(State.HUNT)
	ai_thought = "Вижу! Бегу!"
	if not was_hunting:
		_speed_now = maxf(_speed_now, SPEED_HUNT * 0.9)
		VHSOverlay.glitch(0.7)
		if has_method("scream"):
			call("scream")
		elif has_method("play_creepy_voice"):
			call("play_creepy_voice", "groan")

func on_noise_heard(pos: Vector3, radius: float) -> void:
	if _doing_world_action or GameManager.game_ended or _stun > 0.0:
		return
	var dist := global_position.distance_to(pos)
	if dist > radius:
		return
	var direct := _ray_visible(pos + Vector3.UP * 0.5, null, false, true)
	if not direct and dist > radius * 0.65:
		return
	brain.note_player_evidence(pos, 0.5)
	_last_contact = _clock
	var target := walkable_point(pos)
	if state in [State.HUNT, State.RAGE, State.DASH]:
		if not _visible and time_since_last_seen > TRACK_SECONDS:
			last_known_player_pos = target
		return
	if state == State.STAKEOUT_HIDING:
		if is_instance_valid(stakeout_target_spot) and pos.distance_to(stakeout_target_spot.global_position) < 3.2:
			stakeout_timer = 99.0
		return
	if state == State.INSPECT_HIDING:
		return
	# Топот рядом и на виду: сразу погоня
	var p_ref: Variant = _player()
	if p_ref != null and p_ref.get("is_sprinting") == true and p_ref.global_position.distance_to(pos) < 3.5 and direct and dist < 16.0:
		last_known_player_pos = p_ref.global_position
		time_since_last_seen = 0.0
		_begin_hunt()
		return
	if state == State.SEARCH and _search_origin.distance_to(target) < 2.0:
		return
	_start_search(target, true)
	ai_thought = "Слышу! Бегу на звук"

func alert_player_cough(pos: Vector3) -> void:
	if GameManager.game_ended or _stun > 0.0:
		return
	var dist := global_position.distance_to(pos)
	if dist > 55.0:
		return
	if state == State.STAKEOUT_HIDING:
		stakeout_timer = 99.0
		return
	if dist < 22.0:
		last_known_player_pos = pos
		time_since_last_seen = TRACK_SECONDS + 0.1
		_begin_hunt()
		ai_thought = "Кашель! Жертва рядом!"
	else:
		_start_search(walkable_point(pos), true)

func on_door_altered(door: Node, _open: bool) -> void:
	if not is_instance_valid(door) or not door is Node3D:
		return
	_repath_t = 0.0
	if global_position.distance_to(door.global_position) > 2.6:
		on_noise_heard(door.global_position, 10.0)

func on_light_altered(_on: bool) -> void:
	pass

func _on_go_basement() -> void:
	if state == State.PATROL:
		_start_search(walkable_point(GameManager.player_spawn), false)

func trigger_rage() -> void:
	var player: Variant = _player()
	if player != null:
		last_known_player_pos = player.global_position
		time_since_last_seen = TRACK_SECONDS + 0.1
		_begin_hunt()

func shock_by_electricity(duration: float = 8.0) -> void:
	_stun = clampf(duration, 0.5, 8.0)
	_start_search(global_position, false)

# Луч фонарика выдаёт игрока: монстр замирает на миг и бросается
func _check_flashlight(delta: float) -> void:
	if state in [State.HUNT, State.RAGE, State.DASH, State.INSPECT_HIDING]:
		_lit_time = 0.0
		is_blinded_by_light = false
		return
	var player: Variant = _player()
	if player == null or player.get("is_hiding") == true or player.get("flashlight_on") != true or _clock < START_GRACE:
		_lit_time = maxf(0.0, _lit_time - delta)
		is_blinded_by_light = false
		return
	var cam: Variant = player.get_node_or_null("Head/Camera3D")
	if not (cam is Camera3D):
		return
	var center := global_position + Vector3.UP * 1.25
	if cam.global_position.distance_to(center) > 16.0 or (-cam.global_transform.basis.z).dot((center - cam.global_position).normalized()) < 0.89 or not _ray_visible(cam.global_position, player):
		_lit_time = maxf(0.0, _lit_time - delta)
		is_blinded_by_light = false
		return
	is_blinded_by_light = true
	_lit_time += delta
	flashlight_suspicion_timer = _lit_time
	if _lit_time >= 0.5:
		_lit_time = 0.0
		is_blinded_by_light = false
		last_known_player_pos = player.global_position
		time_since_last_seen = 0.0
		_begin_hunt()
		ai_thought = "Свет! Вижу тебя!"

# Игрок спрятался рядом: прислушивается у укрытия
func _check_hiding_nearby() -> void:
	if state in [State.STAKEOUT_HIDING, State.INSPECT_HIDING]:
		return
	var player: Variant = _player()
	if player == null or player.get("is_hiding") != true:
		return
	var spot: Variant = player.get("hiding_node")
	if not (is_instance_valid(spot) and spot is Node3D):
		return
	var d: float = _flat_dist(global_position, spot.global_position)
	var cooldown: float = float(hiding_spot_cooldowns.get(spot.get_instance_id(), 0.0))
	if d > 3.2 or (state != State.HUNT and _clock < cooldown):
		return
	if not _ray_visible(spot.global_position + Vector3.UP, spot, false, true):
		return
	if witnessed_hiding_spot == spot:
		_set_state(State.INSPECT_HIDING)
		GameManager.set_monster_stare(true, "wardrobe", true)
		ai_thought = "Я видел, куда ты залез!"
	else:
		stakeout_target_spot = spot
		stakeout_timer = 0.0
		silence_timer = 0.0
		_set_state(State.STAKEOUT_HIDING)

# ═══════════════════════════════════════════
#  Поведение
# ═══════════════════════════════════════════
func _do_hunt(delta: float) -> void:
	var player: Variant = _player()
	var active: bool = player != null and player.get("is_dead") != true and player.get("is_hiding") != true
	# Только что свернул за угол: ещё чует, куда
	if active and time_since_last_seen <= TRACK_SECONDS:
		last_known_player_pos = player.global_position
	# Видел, как игрок спрятался: идёт прямо к укрытию
	if is_instance_valid(witnessed_hiding_spot) and player != null and player.get("is_hiding") == true:
		var spot: Node3D = witnessed_hiding_spot
		_go(walkable_point(spot.global_position), SPEED_HUNT, delta)
		ai_thought = "Знаю, где ты"
		return
	if time_since_last_seen > HUNT_MEMORY:
		_start_search(last_known_player_pos, false)
		return
	var target := last_known_player_pos
	var dist := _flat_dist(global_position, target)
	if state_timer > HUNT_GIVE_UP_SECONDS and dist > HUNT_GIVE_UP_DISTANCE:
		ai_thought = "Упустил..."
		_start_search(target, false)
		return
	if time_since_last_seen > TRACK_SECONDS:
		# Добежал до места, где потерял: дальше по направлению бега
		if dist < 1.0:
			var heading: Vector3 = brain.get_player_heading()
			var ahead: Vector3 = walkable_point(target + heading * 6.0) if heading.length_squared() > 0.1 else target
			if ahead.distance_to(target) > 1.5 and navigator.reachable_point(ahead):
				last_known_player_pos = ahead
				target = ahead
			else:
				_start_search(target, false)
				return
		ai_thought = "Где ты?.."
	elif _visible and player != null and player is CharacterBody3D and dist > 8.0:
		# Бежит наперерез
		var run := Vector3(player.velocity.x, 0, player.velocity.z)
		if run.length() > 1.0:
			var lead := walkable_point(player.global_position + run * 0.4)
			if navigator.reachable_point(lead):
				target = lead
		ai_thought = "Догоняю!"
	var speed := SPEED_HUNT_FAR if dist > HUNT_FAR_DIST else (SPEED_HUNT if state_timer < HUNT_BURST_SECONDS else SPEED_HUNT_LONG)
	if dist < HUNT_CLOSE_DIST:
		speed = minf(speed, SPEED_HUNT_CLOSE)
	_go(target, speed * brain.speed_multiplier(), delta)

func _start_search(origin: Vector3, from_noise: bool) -> void:
	_set_state(State.SEARCH)
	_search_origin = origin
	_search_index = 0
	search_points.clear()
	search_points.append(origin)
	# Куда игрок бежал, когда пропал
	var heading: Vector3 = brain.get_player_heading() if not from_noise else Vector3.ZERO
	if heading.length_squared() > 0.1:
		for ahead in [4.0, 8.0]:
			var p_ahead := walkable_point(origin + heading * ahead)
			if navigator.reachable_point(p_ahead):
				search_points.append(p_ahead)
	# Укрытия рядом: шкафы, кровати
	if brain.should_check_hiding_spots():
		for spot in brain.get_priority_hiding_spots(origin).slice(0, 3):
			if spot is Node3D:
				var near := walkable_point(spot.global_position)
				if near.distance_to(spot.global_position) < 2.5 and navigator.reachable_point(near):
					search_points.append(near)
	# Пара случайных проходов рядом
	for i in range(6):
		var a := randf() * TAU
		var p := walkable_point(origin + Vector3(cos(a), 0, sin(a)) * randf_range(3.0, 8.0))
		if navigator.reachable_point(p) and p.distance_to(origin) > 2.0:
			search_points.append(p)
		if search_points.size() >= 7:
			break
	if from_noise:
		brain.begin_noise_investigation(origin)
	_goal = search_points[0]
	_goal_age = 0.0
	ai_thought = "Ищу"

func _do_search(delta: float) -> void:
	if state_timer >= brain.search_time() * (SEARCH_SECONDS / 18.0):
		brain.conclude_noise_investigation(false)
		witnessed_hiding_spot = null
		_set_state(State.PATROL)
		ai_thought = "Потерял. Обхожу дом"
		return
	if _pause > 0.0:
		_pause -= delta
		_brake(delta)
		rotation.y += delta * 2.4
		return
	if _arrived(_goal, 0.8) or _goal_age > 6.0:
		_search_index += 1
		if _search_index >= search_points.size():
			_search_index = 0
		_goal = search_points[_search_index] if not search_points.is_empty() else global_position
		_goal_age = 0.0
		_pause = 0.35
		return
	_go(_goal, SPEED_SEARCH * brain.speed_multiplier(), delta)

func _do_patrol(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		_brake(delta)
		rotation.y += delta * 1.5
		return
	if _arrived(_goal, 0.8) or _goal_age > 14.0:
		_goal = _pick_patrol_goal()
		_goal_age = 0.0
		_pause = randf_range(0.0, 0.5)
		return
	# Долго не видел игрока: ходит быстрее
	var hunger := clampf((_clock - _last_contact - 20.0) / 40.0, 0.0, 1.0)
	_go(_goal, lerpf(SPEED_PATROL, SPEED_SEARCH * 0.85, hunger), delta)

# Чем дольше не видел игрока, тем чаще идёт в его часть дома
func _pick_patrol_goal() -> Vector3:
	if waypoints.is_empty():
		_build_patrol_points()
	if waypoints.is_empty():
		return global_position
	var player: Variant = _player()
	var hunger := clampf((_clock - _last_contact - 30.0) / 60.0, 0.0, 1.0) * 0.6
	var best: Vector3 = waypoints.pick_random()
	var best_score := -INF
	for i in range(6):
		var c: Vector3 = waypoints.pick_random()
		var score := randf() * 4.0 + minf(_flat_dist(global_position, c), 14.0) * 0.3
		for r in _recent_goals:
			score += minf(c.distance_to(r), 10.0) * 0.4
		if player != null and player.get("is_hiding") != true:
			score -= hunger * minf(_flat_dist(c, player.global_position), 30.0) * 0.6
		if score > best_score:
			best_score = score
			best = c
	_recent_goals.append(best)
	if _recent_goals.size() > 4:
		_recent_goals.pop_front()
	return best

func _build_patrol_points() -> void:
	if waypoints.size() >= 14:
		return
	waypoints.clear()
	var map := get_world_3d().navigation_map
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		for i in range(320):
			if waypoints.size() >= 24:
				break
			var p := NavigationServer3D.map_get_random_point(map, 1, true)
			if not navigator.reachable_point(p, 0.5):
				continue
			var crowded := false
			for wp in waypoints:
				if wp.distance_to(p) < 3.0:
					crowded = true
					break
			if not crowded:
				waypoints.append(p)
	if waypoints.size() < 6:
		for radius in [3.0, 6.0, 10.0]:
			for i in range(8):
				var a := TAU * float(i) / 8.0
				var p: Variant = navigator.floor_at(global_position + Vector3(cos(a), 0, sin(a)) * radius)
				if p != null and navigator.body_clear(p, false):
					waypoints.append(p)

func _do_inspect_hiding(delta: float) -> void:
	_brake(delta)
	if is_instance_valid(witnessed_hiding_spot):
		_face_point(witnessed_hiding_spot.global_position, delta, 6.0)
	if state_timer < 1.0:
		return
	GameManager.set_monster_stare(false, "", false)
	var player: Variant = _player()
	if player != null and is_instance_valid(witnessed_hiding_spot) and player.get("hiding_node") == witnessed_hiding_spot and player.get("is_hiding") == true:
		brain.record_catch_at_hiding_spot(witnessed_hiding_spot)
		if player.has_method("exit_hiding"):
			player.call("exit_hiding")
		if player.has_method("die") and not GameManager.is_godmode:
			player.call("die", self)
	witnessed_hiding_spot = null
	_start_search(last_known_player_pos, false)

# Стоит у укрытия и слушает: задержишь дыхание — уйдёт, нет — вытащит
func _do_stakeout_hiding(delta: float) -> void:
	_brake(delta)
	var player: Variant = _player()
	if player == null or player.get("is_hiding") != true or not is_instance_valid(stakeout_target_spot) or player.get("hiding_node") != stakeout_target_spot:
		stakeout_target_spot = null
		_start_search(global_position, false)
		return
	_face_point(stakeout_target_spot.global_position, delta, 4.5)
	var holding: bool = player.has_method("is_breath_held") and bool(player.call("is_breath_held"))
	if holding:
		silence_timer += delta
		stakeout_timer = maxf(0.0, stakeout_timer - delta * 0.5)
		ai_thought = "Прислушивается... (тишина %.1fс)" % maxf(0.0, 2.8 - silence_timer)
		if silence_timer >= 2.8:
			hiding_spot_cooldowns[stakeout_target_spot.get_instance_id()] = _clock + 35.0
			stakeout_target_spot = null
			_set_state(State.PATROL)
			_goal = _pick_patrol_goal()
			ai_thought = "Никого нет..."
	else:
		silence_timer = 0.0
		stakeout_timer += delta
		ai_thought = "Слышит дыхание... (%.1fс)" % maxf(0.0, 6.0 - stakeout_timer)
		if stakeout_timer >= 6.0:
			var spot: Variant = stakeout_target_spot
			stakeout_target_spot = null
			GameManager.set_monster_stare(false, "", false)
			brain.record_catch_at_hiding_spot(spot)
			if player.has_method("exit_hiding"):
				player.call("exit_hiding")
			if player.has_method("die") and not GameManager.is_godmode:
				player.call("die", self)
			_start_search(global_position, false)

func _check_catch() -> void:
	var player: Variant = _player()
	var dt := get_physics_process_delta_time()
	if player == null or _stun > 0.0 or GameManager.is_godmode or player.get("is_hiding") == true or player.get("is_dead") == true or _clock < START_GRACE:
		_catch_hold = 0.0
		return
	var near: bool = global_position.distance_to(player.global_position) < catch_distance and _ray_visible(player.global_position + Vector3.UP, player, false, true)
	if not near:
		_catch_hold = maxf(0.0, _catch_hold - dt)
		return
	if state not in [State.HUNT, State.RAGE]:
		last_known_player_pos = player.global_position
		time_since_last_seen = 0.0
		_begin_hunt()
	if _catch_hold <= 0.0:
		VHSOverlay.glitch(0.9)
	_catch_hold += dt
	if _catch_hold >= CATCH_HOLD and player.has_method("die"):
		_catch_hold = 0.0
		player.call("die", self)

func _set_state(next: State) -> void:
	if state in [State.INSPECT_HIDING, State.STAKEOUT_HIDING] and next not in [State.INSPECT_HIDING, State.STAKEOUT_HIDING]:
		GameManager.set_monster_stare(false, "", false)
	if next == State.STAKEOUT_HIDING:
		GameManager.set_monster_stare(true, "wardrobe", false)
	if next != State.STAKEOUT_HIDING:
		stakeout_target_spot = null
	if next != State.HUNT:
		awareness = 0.0
	state = next
	state_timer = 0.0
	_goal_age = 0.0
	_pause = 0.0
	_stuck_count = 0

# ═══════════════════════════════════════════
#  Движение: кратчайший путь по навмешу
# ═══════════════════════════════════════════
# Ближайшая к точке позиция, где монстр может стоять
func walkable_point(pos: Vector3) -> Vector3:
	var map := get_world_3d().navigation_map
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		var snapped := NavigationServer3D.map_get_closest_point(map, pos)
		if snapped.distance_to(pos) < 3.0:
			return snapped
	var floor_pt: Variant = navigator.floor_at(pos)
	return floor_pt if floor_pt != null else pos

func _arrived(point: Vector3, radius: float) -> bool:
	if _flat_dist(global_position, point) < radius:
		return true
	# Путь кончился рядом с точкой: дальше не пройти, считаем, что пришёл
	return not _path.is_empty() and _path_i >= _path.size() and _flat_dist(global_position, point) < 2.0

func _repath(target: Vector3) -> void:
	_repath_t = REPATH_SECONDS
	_path_target = target
	var map := get_world_3d().navigation_map
	var route := PackedVector3Array()
	if map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0:
		route = NavigationServer3D.map_get_path(map, global_position, target, true)
	var reaches: bool = route.size() >= 2 and route[-1].distance_to(target) < 1.2
	if not reaches and route.size() < 2:
		# Навмеша нет (полигон, тесты): поиск по сетке
		if not navigator.pending and navigator.cooldown <= 0.0:
			navigator.request(target)
		_grid_wait = true
		if not navigator.path.is_empty():
			route = navigator.path.duplicate()
	else:
		_grid_wait = false
	_path = route
	_path_i = 1 if route.size() > 1 else 0
	current_debug_path = _path

func _go(target: Vector3, speed: float, delta: float) -> void:
	_desired_speed = speed
	last_nav_target = target
	_repath_t -= delta
	if _repath_t <= 0.0 or _path_target.distance_to(target) > 0.7 or (_grid_wait and not navigator.pending and not navigator.path.is_empty()):
		_repath(target)
	# Обрезает пройденные точки и срезает углы, если путь прямо виден
	while _path_i < _path.size() and _flat_dist(global_position, _path[_path_i]) < POINT_REACHED:
		_path_i += 1
	if _path_i < _path.size() - 1:
		var skip := mini(_path_i + 2, _path.size() - 1)
		if navigator.segment_clear(global_position, _path[skip], false, true):
			_path_i = skip
	var next: Vector3 = target if _path_i >= _path.size() else _path[_path_i]
	if _path.is_empty() and _grid_wait:
		next = target
	var to_next := Vector3(next.x - global_position.x, 0, next.z - global_position.z)
	if to_next.length() < 0.05:
		_brake(delta)
		return
	var dir := to_next.normalized()
	world_actions.open_ahead(dir)
	# Застрял: шаг вбок и новый путь
	_stuck_t += delta
	if _stuck_t >= STUCK_WINDOW:
		if _flat_dist(global_position, _stuck_anchor) < STUCK_MIN_MOVE:
			_unstick(dir)
		else:
			_stuck_count = 0
		_stuck_anchor = global_position
		_stuck_t = 0.0
	if _side_t > 0.0:
		_side_t -= delta
		dir = (dir * 0.3 + _side_dir).normalized()
	# Последний метр до неподвижной цели — мягче, в погоне без торможения
	var want := speed
	if state != State.HUNT and _path_i >= _path.size() - 1:
		want = minf(speed, maxf(1.2, to_next.length() * 3.0))
	_speed_now = move_toward(_speed_now, want, ACCEL * delta)
	velocity.x = dir.x * _speed_now
	velocity.z = dir.z * _speed_now
	target_yaw = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 12.0, 1.0))

# Упёрся: пробует боком туда, где свободно, и сразу строит путь заново
func _unstick(dir: Vector3) -> void:
	navigation_recoveries += 1
	_stuck_count += 1
	stuck_timer = float(_stuck_count) * STUCK_WINDOW
	var left := Vector3(-dir.z, 0, dir.x)
	_side_dir = left
	if not navigator.segment_clear(global_position, global_position + left * 0.6, false, true):
		_side_dir = -left
	if world_actions.push_ahead(dir):
		_side_dir = Vector3.ZERO
	_side_t = 0.35
	_repath_t = 0.0
	navigator.clear()
	# Совсем не пройти: меняет цель, а не бьётся
	if _stuck_count >= 3 and state in [State.PATROL, State.SEARCH]:
		_goal_age = 99.0
		_stuck_count = 0

# Совместимость: старые вызовы движения
func _nav_move_to(target: Vector3, speed: float, delta: float) -> void:
	_go(target, speed, delta)

func _brake(delta: float, _deceleration: float = 20.0) -> void:
	_speed_now = move_toward(_speed_now, 0.0, ACCEL * delta)
	velocity.x = move_toward(velocity.x, 0.0, ACCEL * delta)
	velocity.z = move_toward(velocity.z, 0.0, ACCEL * delta)

func _face_point(point: Vector3, delta: float, turn_speed: float) -> void:
	var to_point := Vector3(point.x - global_position.x, 0, point.z - global_position.z)
	if to_point.length_squared() > 0.04:
		rotation.y = lerp_angle(rotation.y, atan2(-to_point.x, -to_point.z), minf(1.0, delta * turn_speed))

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

func reset_ai() -> void:
	_set_state(State.PATROL)
	_goal = global_position
	velocity = Vector3.ZERO
	_speed_now = 0.0
	_visible = false
	awareness = 0.0
	_recent_goals.clear()
	_last_contact = _clock
	_stun = 0.0
	time_since_last_seen = 999.0
	witnessed_hiding_spot = null
	stakeout_target_spot = null
	stakeout_timer = 0.0
	silence_timer = 0.0
	hiding_spot_cooldowns.clear()
	search_points.clear()
	_path.clear()
	_path_i = 0
	_path_target = Vector3.INF
	_catch_hold = 0.0
	navigator.clear()
	navigator.blocked_spots.clear()
	brain.reset()

func get_debug_navigation_path() -> PackedVector3Array:
	return _path

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
