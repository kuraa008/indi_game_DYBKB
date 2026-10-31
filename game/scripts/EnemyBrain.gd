extends RefCounted
## Adaptive brain for the Skinwalker AI.
## Accumulates knowledge about the player across the session and escalates
## difficulty over time.  Attached to EnemyBehavior as `brain`.
##
## Intelligence grows from 0 → 1 over ~60 min of gameplay.
## At low intelligence the monster behaves normally (current baseline).
## At high intelligence it patrols hot-zones, checks proven hiding spots,
## ignores decoys, predicts player movement and takes shortcuts / flanks.

# ── Constants ────────────────────────────────────────────────────────────────
const CELL_SIZE := 2.0          # heat-map resolution (metres)
const HEAT_SAMPLE_INTERVAL := 0.4
const HEAT_DECAY_RATE := 0.002  # per second — slow fade, hot zones stay
const MAX_INTELLIGENCE_TIME := 3600.0  # seconds to reach full intelligence
const PREDICTION_HISTORY := 40  # position snapshots for movement prediction
const NOISE_MEMORY_TTL := 120.0 # how long we remember a noise event
const SHORTCUT_COOLDOWN := 4.0  # seconds between shortcut attempts

# ── Heat-map ─────────────────────────────────────────────────────────────────
var heat_map: Dictionary = {}         # Vector2i → float  (cell → accumulated heat)
var _heat_timer := 0.0

# ── Intelligence ─────────────────────────────────────────────────────────────
var session_time := 0.0
var intelligence := 0.0  # 0.0 … 1.0
var intelligence_override := -1.0 # >= 0.0 means manual override (for test polygon)

# ── Hiding-spot memory ───────────────────────────────────────────────────────
## Remembers spots where the monster actually CAUGHT the player hiding.
var caught_hiding_spots: Array[Dictionary] = []  # {node_id, position, catches}

# ── Trap / distraction skepticism ────────────────────────────────────────────
## Every noise event the monster investigates gets recorded.
## If the monster arrives and finds no player → it was a decoy.
var noise_events: Array[Dictionary] = []
## {position, time, was_decoy, type}
var total_decoys := 0
var total_real_noises := 0

# ── Player movement prediction ───────────────────────────────────────────────
var player_trail: Array[Vector3] = []      # recent positions
var player_velocity_avg := Vector3.ZERO    # smoothed velocity
var predicted_player_pos := Vector3.ZERO   # where we think the player will be
var _trail_timer := 0.0

# ── Shortcut / flanking ─────────────────────────────────────────────────────
var shortcut_target := Vector3.ZERO
var shortcut_active := false
var _shortcut_cooldown := 0.0

# ── Ambush ───────────────────────────────────────────────────────────────────
var ambush_position := Vector3.ZERO
var is_ambushing := false
var _ambush_timer := 0.0
var _ambush_patience := 0.0   # how long to wait

# ── Investigated noise tracking ─────────────────────────────────────────────
var _investigating_noise := false
var _investigated_noise_pos := Vector3.ZERO
var _investigated_noise_time := 0.0

# ── Back-reference ───────────────────────────────────────────────────────────
var actor: CharacterBody3D  # the EnemyBehavior node

func _init(owner: CharacterBody3D) -> void:
	actor = owner

# ══════════════════════════════════════════════════════════════════════════════
#  TICK — called every physics frame from EnemyBehavior._physics_process
# ══════════════════════════════════════════════════════════════════════════════
func tick(delta: float) -> void:
	session_time += delta
	if intelligence_override >= 0.0:
		intelligence = intelligence_override
	else:
		intelligence = clampf(session_time / MAX_INTELLIGENCE_TIME, 0.0, 1.0)

	_shortcut_cooldown = maxf(0.0, _shortcut_cooldown - delta)

	# ── Heat-map sampling ────────────────────────────────────────────────
	_heat_timer += delta
	if _heat_timer >= HEAT_SAMPLE_INTERVAL:
		_heat_timer = 0.0
		_sample_heat_map()
		_decay_heat_map(HEAT_SAMPLE_INTERVAL)

	# ── Player trail for prediction ──────────────────────────────────────
	_trail_timer += delta
	if _trail_timer >= 0.3:
		_trail_timer = 0.0
		_sample_player_trail()

	# ── Noise event cleanup ──────────────────────────────────────────────
	_cleanup_old_noises()

	# ── Ambush patience countdown ────────────────────────────────────────
	if is_ambushing:
		_ambush_timer += delta
		if _ambush_timer >= _ambush_patience:
			is_ambushing = false

func set_intelligence_override(val: float) -> void:
	intelligence_override = clampf(val, 0.0, 1.0)
	intelligence = intelligence_override
	session_time = intelligence_override * MAX_INTELLIGENCE_TIME

func clear_intelligence_override() -> void:
	intelligence_override = -1.0
	intelligence = clampf(session_time / MAX_INTELLIGENCE_TIME, 0.0, 1.0)

# ══════════════════════════════════════════════════════════════════════════════
#  HEAT-MAP
# ══════════════════════════════════════════════════════════════════════════════
func _cell_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))

func _sample_heat_map() -> void:
	var player: Variant = _player()
	if player == null:
		return
	var key := _cell_key(player.global_position)
	heat_map[key] = float(heat_map.get(key, 0.0)) + 1.0

func _decay_heat_map(elapsed: float) -> void:
	var decay := HEAT_DECAY_RATE * elapsed
	var to_erase: Array[Vector2i] = []
	for key: Vector2i in heat_map:
		heat_map[key] = float(heat_map[key]) - decay
		if float(heat_map[key]) <= 0.0:
			to_erase.append(key)
	for key in to_erase:
		heat_map.erase(key)

## Returns the N hottest cells as world positions (centre of cell, y=0).
func get_hot_zones(count: int = 6) -> Array[Vector3]:
	var sorted_keys: Array = heat_map.keys()
	sorted_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return float(heat_map[a]) > float(heat_map[b]))
	var result: Array[Vector3] = []
	for i in range(mini(count, sorted_keys.size())):
		var k: Vector2i = sorted_keys[i]
		result.append(Vector3((k.x + 0.5) * CELL_SIZE, 0.0, (k.y + 0.5) * CELL_SIZE))
	return result

## Heat value at a world position.
func heat_at(pos: Vector3) -> float:
	return float(heat_map.get(_cell_key(pos), 0.0))

## Returns list of cells formatted for visual display: [{pos: Vector3, heat: float, intensity: float}]
func get_heat_map_data() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if heat_map.is_empty():
		return result
	var max_val := 0.01
	for k: Vector2i in heat_map:
		var v: float = float(heat_map[k])
		if v > max_val:
			max_val = v
	for k: Vector2i in heat_map:
		var v: float = float(heat_map[k])
		result.append({
			"pos": Vector3((k.x + 0.5) * CELL_SIZE, 0.05, (k.y + 0.5) * CELL_SIZE),
			"heat": v,
			"intensity": clampf(v / max_val, 0.08, 1.0)
		})
	return result

## Pick a patrol target biased toward hot zones.  Returns null if no data.
func suggest_patrol_target() -> Variant:
	if heat_map.is_empty() or intelligence < 0.1:
		return null
	# Chance to patrol a hot zone increases with intelligence
	if randf() > lerpf(0.15, 0.75, intelligence):
		return null
	var zones := get_hot_zones(8)
	if zones.is_empty():
		return null
	return zones[randi() % zones.size()]

# ══════════════════════════════════════════════════════════════════════════════
#  HIDING-SPOT MEMORY
# ══════════════════════════════════════════════════════════════════════════════

## Called when the monster actually catches the player in a hiding spot.
func record_catch_at_hiding_spot(spot_node: Variant) -> void:
	if not is_instance_valid(spot_node):
		return
	var nid: int = spot_node.get_instance_id()
	for entry in caught_hiding_spots:
		if entry.node_id == nid:
			entry.catches += 1
			return
	caught_hiding_spots.append({
		"node_id": nid,
		"position": spot_node.global_position,
		"catches": 1,
		"node_ref": weakref(spot_node)
	})

## Should the monster check hiding spots during search?
func should_check_hiding_spots() -> bool:
	var base_chance := lerpf(0.25, 0.95, intelligence)
	# Boost if we've caught someone before
	if not caught_hiding_spots.is_empty():
		base_chance = minf(base_chance + 0.15, 1.0)
	return randf() < base_chance

## Returns nearby hiding spots the monster should check, sorted by priority.
func get_priority_hiding_spots(around: Vector3, radius: float = 14.0) -> Array[Node3D]:
	var result: Array[Node3D] = []
	var tree: SceneTree = actor.get_tree()
	if tree == null:
		return result

	# All hiding spots in the scene
	var all_spots: Array[Node] = tree.get_nodes_in_group("hiding_spots")
	var scored: Array[Dictionary] = []

	for spot in all_spots:
		if not is_instance_valid(spot) or not spot is Node3D:
			continue
		var dist := around.distance_to(spot.global_position)
		if dist > radius:
			continue
		var score := 10.0 - dist  # closer = higher priority
		# Boost spots where we caught someone
		for memory in caught_hiding_spots:
			if memory.node_id == spot.get_instance_id():
				score += 20.0 * memory.catches
				break
		# Boost spots in hot zones
		score += heat_at(spot.global_position) * 2.0
		scored.append({"node": spot, "score": score})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) > float(b.score))

	for entry in scored:
		result.append(entry.node as Node3D)
	return result

# ══════════════════════════════════════════════════════════════════════════════
#  TRAP / DISTRACTION SKEPTICISM
# ══════════════════════════════════════════════════════════════════════════════

## Record that we heard a noise and started investigating.
func begin_noise_investigation(pos: Vector3) -> void:
	_investigating_noise = true
	_investigated_noise_pos = pos
	_investigated_noise_time = session_time

## Called when the monster reaches the noise source and looks around.
## If no player found → mark as decoy.
func conclude_noise_investigation(found_player: bool) -> void:
	if not _investigating_noise:
		return
	_investigating_noise = false
	noise_events.append({
		"position": _investigated_noise_pos,
		"time": _investigated_noise_time,
		"was_decoy": not found_player
	})
	if found_player:
		total_real_noises += 1
	else:
		total_decoys += 1

## Should the monster ignore this noise?  Higher intelligence + more decoys = more skeptical.
func should_ignore_noise(pos: Vector3) -> bool:
	if intelligence < 0.15:
		return false  # too dumb to be skeptical yet

	# Base skepticism from intelligence
	var skepticism := lerpf(0.0, 0.55, intelligence)

	# Boost from past decoys
	var total := total_decoys + total_real_noises
	if total > 0:
		var decoy_ratio := float(total_decoys) / float(total)
		skepticism += decoy_ratio * 0.35

	skepticism = clampf(skepticism, 0.0, 0.85)

	# Noises near known decoy positions get extra skepticism
	for ev in noise_events:
		if ev.was_decoy and pos.distance_to(ev.position) < 4.0:
			skepticism = minf(skepticism + 0.2, 0.92)
			break

	return randf() < skepticism

func get_skepticism_percent() -> float:
	if intelligence < 0.15:
		return 0.0
	var s := lerpf(0.0, 0.55, intelligence)
	var total := total_decoys + total_real_noises
	if total > 0:
		s += (float(total_decoys) / float(total)) * 0.35
	return clampf(s, 0.0, 0.85) * 100.0

# ══════════════════════════════════════════════════════════════════════════════
#  PLAYER MOVEMENT PREDICTION
# ══════════════════════════════════════════════════════════════════════════════

func _sample_player_trail() -> void:
	var player: Variant = _player()
	if player == null:
		return
	player_trail.append(player.global_position)
	if player_trail.size() > PREDICTION_HISTORY:
		player_trail.pop_front()
	_update_prediction()

func _update_prediction() -> void:
	if player_trail.size() < 4:
		predicted_player_pos = Vector3.ZERO
		player_velocity_avg = Vector3.ZERO
		return
	# Weighted average velocity from recent samples
	var vel := Vector3.ZERO
	var weight := 0.0
	for i in range(1, player_trail.size()):
		var w := float(i)  # more recent = more weight
		vel += (player_trail[i] - player_trail[i - 1]) * w
		weight += w
	if weight > 0.01:
		player_velocity_avg = vel / weight / 0.3  # 0.3s sample interval
	else:
		player_velocity_avg = Vector3.ZERO

	# Predict where the player will be in 2-4 seconds (scales with intelligence)
	var look_ahead := lerpf(1.5, 4.0, intelligence)
	var last_pos := player_trail[-1]
	predicted_player_pos = last_pos + player_velocity_avg * look_ahead

## Get the predicted player position for flanking.
func get_predicted_position() -> Vector3:
	return predicted_player_pos

## What direction is the player most likely running?
func get_player_heading() -> Vector3:
	return player_velocity_avg.normalized() if player_velocity_avg.length_squared() > 0.1 else Vector3.ZERO

# ══════════════════════════════════════════════════════════════════════════════
#  SHORTCUT / FLANKING
# ══════════════════════════════════════════════════════════════════════════════

## During a chase, try to find a flanking route.
## Returns a Vector3 to move toward, or null if no shortcut found.
func suggest_shortcut(monster_pos: Vector3, player_pos: Vector3) -> Variant:
	if intelligence < 0.2 or _shortcut_cooldown > 0.0:
		return null

	# Only try shortcuts some of the time, scaling with intelligence
	if randf() > lerpf(0.15, 0.65, intelligence):
		return null

	var heading := get_player_heading()
	if heading.length_squared() < 0.1:
		return null

	# The player is running in direction `heading`.
	# Try to find a point ahead of the player that the monster can reach.
	var ahead_distance := lerpf(4.0, 10.0, intelligence)
	var intercept := player_pos + heading * ahead_distance

	# Check if the intercept point is closer for the monster than the direct path
	var direct_dist := monster_pos.distance_to(player_pos)
	var flank_dist := monster_pos.distance_to(intercept)

	# Flanking is only worth it if we can get there faster
	if flank_dist < direct_dist * 0.85:
		_shortcut_cooldown = SHORTCUT_COOLDOWN
		shortcut_active = true
		shortcut_target = intercept
		return intercept

	# Also try perpendicular cuts
	var perp := Vector3(-heading.z, 0, heading.x)
	for sign_mult: float in [1.0, -1.0]:
		var cut_point: Vector3 = player_pos + heading * (ahead_distance * 0.6) + perp * sign_mult * 3.0
		var cut_dist: float = monster_pos.distance_to(cut_point)
		if cut_dist < direct_dist * 0.9:
			_shortcut_cooldown = SHORTCUT_COOLDOWN
			shortcut_active = true
			shortcut_target = cut_point
			return cut_point

	return null

func clear_shortcut() -> void:
	shortcut_active = false

# ══════════════════════════════════════════════════════════════════════════════
#  AMBUSH
# ══════════════════════════════════════════════════════════════════════════════

## Suggest an ambush position in a hot zone near where the player tends to go.
func suggest_ambush() -> Variant:
	if intelligence < 0.35:
		return null
	if randf() > lerpf(0.1, 0.45, intelligence):
		return null
	var zones := get_hot_zones(4)
	if zones.is_empty():
		return null
	# Pick a zone that's not too far from the monster
	for zone in zones:
		if actor.global_position.distance_to(zone) < 20.0:
			is_ambushing = true
			_ambush_timer = 0.0
			_ambush_patience = lerpf(5.0, 15.0, intelligence)
			ambush_position = zone
			return zone
	return null

# ══════════════════════════════════════════════════════════════════════════════
#  SEARCH ENHANCEMENT — add hot zones and remembered hiding spots to search
# ══════════════════════════════════════════════════════════════════════════════

## Returns extra search points based on accumulated knowledge.
func get_smart_search_points(origin: Vector3, count: int = 6) -> Array[Vector3]:
	var result: Array[Vector3] = []

	# Add hot zones near the search origin
	var zones := get_hot_zones(count)
	for zone in zones:
		if origin.distance_to(zone) < 16.0:
			result.append(zone)
		if result.size() >= count:
			break

	# Add positions of hiding spots where we caught the player
	for memory in caught_hiding_spots:
		if origin.distance_to(memory.position) < 14.0:
			result.append(memory.position)
		if result.size() >= count + 3:
			break

	return result

# ══════════════════════════════════════════════════════════════════════════════
#  INTELLIGENCE-SCALED PARAMETERS
# ══════════════════════════════════════════════════════════════════════════════

## How much faster the monster gets with intelligence (multiplier on speed).
func speed_multiplier() -> float:
	return lerpf(1.0, 1.12, intelligence)

## Extra sight range from being more alert.
func sight_bonus() -> float:
	return lerpf(0.0, 8.0, intelligence)

## How long the monster remembers the last seen position (replaces LOST_SIGHT_SECONDS).
func hunt_memory_time() -> float:
	return lerpf(10.0, 18.0, intelligence)

## How long the monster searches after losing sight.
func search_time() -> float:
	return lerpf(18.0, 35.0, intelligence)

# ══════════════════════════════════════════════════════════════════════════════
#  THOUGHT — generates a Russian thought string for debug display
# ══════════════════════════════════════════════════════════════════════════════

func get_thought_suffix() -> String:
	if intelligence < 0.15:
		return ""
	if is_ambushing:
		return " [Засада — жду жертву]"
	if shortcut_active:
		return " [Срезаю путь!]"
	if intelligence > 0.7 and not caught_hiding_spots.is_empty():
		return " [Помню где прятался...]"
	if intelligence > 0.5 and total_decoys > 2:
		return " [Не куплюсь на уловки]"
	if intelligence > 0.3:
		return " [Учусь...]"
	return ""

# ══════════════════════════════════════════════════════════════════════════════
#  STATS — for HUD display
# ══════════════════════════════════════════════════════════════════════════════

func get_stats() -> Dictionary:
	return {
		"intelligence": intelligence,
		"intelligence_pct": snapped(intelligence * 100.0, 0.1),
		"session_minutes": snapped(session_time / 60.0, 0.1),
		"hot_zones": heat_map.size(),
		"hiding_spots_remembered": caught_hiding_spots.size(),
		"total_catches_at_hiding": _total_catches(),
		"decoys_detected": total_decoys,
		"real_noises": total_real_noises,
		"skepticism_pct": snapped(get_skepticism_percent(), 1.0),
		"is_ambushing": is_ambushing,
		"shortcut_active": shortcut_active,
		"predicted_pos": predicted_player_pos,
		"player_heading": get_player_heading()
	}

func _total_catches() -> int:
	var total := 0
	for m in caught_hiding_spots:
		total += int(m.catches)
	return total

# ══════════════════════════════════════════════════════════════════════════════
#  RESET
# ══════════════════════════════════════════════════════════════════════════════

func reset() -> void:
	heat_map.clear()
	session_time = 0.0
	intelligence = 0.0
	caught_hiding_spots.clear()
	noise_events.clear()
	total_decoys = 0
	total_real_noises = 0
	player_trail.clear()
	player_velocity_avg = Vector3.ZERO
	predicted_player_pos = Vector3.ZERO
	shortcut_active = false
	is_ambushing = false
	_investigating_noise = false

# ══════════════════════════════════════════════════════════════════════════════
#  HELPERS
# ══════════════════════════════════════════════════════════════════════════════

func _player() -> Variant:
	var p: Variant = GameManager.player_ref
	return p if is_instance_valid(p) and p is Node3D else null

func _cleanup_old_noises() -> void:
	for i in range(noise_events.size() - 1, -1, -1):
		if session_time - float(noise_events[i].time) > NOISE_MEMORY_TTL:
			noise_events.remove_at(i)
