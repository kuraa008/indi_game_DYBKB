import sys
sys.stdout.reconfigure(encoding='utf-8')

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

with open(GAME + r'\scripts\Enemy.gd', 'r', encoding='utf-8') as f:
    code = f.read()

# 1. Waypoints initialization on ready - clamp to navmesh
old_ready_wp = """\t_build_visual()
\t_setup_nav_agent()
\twp_idx = randi() % waypoints.size()"""

new_ready_wp = """\t_build_visual()
\t_setup_nav_agent()
\tcall_deferred("_validate_and_clamp_waypoints")
\twp_idx = randi() % waypoints.size()"""

if old_ready_wp in code:
    code = code.replace(old_ready_wp, new_ready_wp, 1)
    print("✅ Waypoint validation on ready added")
else:
    print("⚠️ old_ready_wp not found")

# Add _validate_and_clamp_waypoints method
old_wp_array = """var waypoints: Array[Vector3] = [
\tVector3(0.0,   0.5,  1.0),
\tVector3(8.0,   0.5, -4.0),
\tVector3(11.0,  0.5,  4.5),
\tVector3(6.0,   0.5,  7.5),
\tVector3(-3.0,  0.5,  3.5),
\tVector3(-10.0, 0.5, -3.0),
\tVector3(-5.0,  0.5, -6.5),
\tVector3(3.0,   0.5, -9.0),
\tVector3(10.0,  0.5, -10.0),
]
var wp_idx: int = 0"""

new_wp_array = """var waypoints: Array[Vector3] = [
\tVector3(0.0,   0.5,  1.0),
\tVector3(6.0,   0.5, -2.0),
\tVector3(9.0,   0.5,  3.0),
\tVector3(4.0,   0.5,  6.0),
\tVector3(-2.0,  0.5,  2.5),
\tVector3(-7.0,  0.5, -2.0),
\tVector3(-4.0,  0.5, -5.0),
\tVector3(1.0,   0.5, -7.0),
\tVector3(7.0,   0.5, -7.0),
]
var wp_idx: int = 0

func _validate_and_clamp_waypoints() -> void:
\tawait get_tree().physics_frame
\tawait get_tree().physics_frame
\tvar nav_map = get_world_3d().navigation_map
\tif not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
\t\treturn
\tfor i in range(waypoints.size()):
\t\tvar clamped = NavigationServer3D.map_get_closest_point(nav_map, waypoints[i])
\t\tif clamped.distance_to(waypoints[i]) < 6.0:
\t\t\twaypoints[i] = clamped"""

if old_wp_array in code:
    code = code.replace(old_wp_array, new_wp_array, 1)
    print("✅ Clear waypoints and _validate_and_clamp_waypoints added")
else:
    print("⚠️ old_wp_array not found")

# 2. Fix _do_patrol: never get trapped at unreachable waypoints
old_do_patrol_check = """\tif _flat_dist(global_position, waypoints[wp_idx]) < 1.5:
\t\t# Выбор следующей точки: с шансом 35% выбираем точку в любимой комнате игрока!
\t\tif randf() < 0.35 and brain != null:
\t\t\tvar fav_room = brain.get_favorite_room()
\t\t\tvar room_pts: Array[int] = []
\t\t\tfor idx in range(waypoints.size()):
\t\t\t\tif SkinwalkerBrain.get_room_for_pos(waypoints[idx]) == fav_room:
\t\t\t\t\troom_pts.append(idx)
\t\t\tif not room_pts.is_empty():
\t\t\t\twp_idx = room_pts[randi() % room_pts.size()]
\t\t\telse:
\t\t\t\twp_idx = (wp_idx + 1) % waypoints.size()
\t\telse:
\t\t\twp_idx = (wp_idx + 1) % waypoints.size()

\t\t# Шанс заняться делами (умеренный 18%, чтобы монстр не простаивал)
\t\tif randf() < 0.18 and _start_routine_activity():
\t\t\treturn

\t\tif randf() < 0.20:
\t\t\tpatrol_pause = randf_range(0.3, 0.7)"""

new_do_patrol_check = """\tvar reached_wp = _flat_dist(global_position, waypoints[wp_idx]) < 1.8
\tif not reached_wp and is_instance_valid(nav_agent) and nav_agent.is_navigation_finished() and state_timer > 1.2:
\t\treached_wp = true
\tif state_timer > 7.0:
\t\treached_wp = true

\tif reached_wp:
\t\tstate_timer = 0.0
\t\t# Выбор следующей точки: с шансом 35% выбираем точку в любимой комнате игрока!
\t\tif randf() < 0.35 and brain != null:
\t\t\tvar fav_room = brain.get_favorite_room()
\t\t\tvar room_pts: Array[int] = []
\t\t\tfor idx in range(waypoints.size()):
\t\t\t\tif SkinwalkerBrain.get_room_for_pos(waypoints[idx]) == fav_room:
\t\t\t\t\troom_pts.append(idx)
\t\t\tif not room_pts.is_empty():
\t\t\t\twp_idx = room_pts[randi() % room_pts.size()]
\t\t\telse:
\t\t\t\twp_idx = (wp_idx + 1) % waypoints.size()
\t\telse:
\t\t\twp_idx = (wp_idx + 1) % waypoints.size()

\t\t# Шанс заняться делами (умеренный 18%, чтобы монстр не простаивал)
\t\tif randf() < 0.18 and _start_routine_activity():
\t\t\treturn

\t\tif randf() < 0.20:
\t\t\tpatrol_pause = randf_range(0.3, 0.7)"""

if old_do_patrol_check in code:
    code = code.replace(old_do_patrol_check, new_do_patrol_check, 1)
    print("✅ _do_patrol waypoint auto-advance patched")
else:
    print("⚠️ old_do_patrol_check not found")

# 3. Fix _advance_search: never get stuck in front of furniture
old_advance_search_end = """\tif _flat_dist(global_position, current_tgt) < 1.3:
\t\tsearch_inspecting = true
\t\tsearch_inspect_timer = 0.0"""

new_advance_search_end = """\tsearch_sub_timer += delta
\tvar reached_search_point = _flat_dist(global_position, current_tgt) < 1.65
\tif not reached_search_point and is_instance_valid(nav_agent) and nav_agent.is_navigation_finished() and search_sub_timer > 0.8:
\t\treached_search_point = true
\tif search_sub_timer > 4.5:
\t\treached_search_point = true

\tif reached_search_point:
\t\tsearch_sub_timer = 0.0
\t\tsearch_inspecting = true
\t\tsearch_inspect_timer = 0.0"""

if old_advance_search_end in code:
    code = code.replace(old_advance_search_end, new_advance_search_end, 1)
    print("✅ _advance_search un-stuck patched")
else:
    print("⚠️ old_advance_search_end not found")

# 4. Fix _nav_move_to corner freeze
old_nav_corner = """\tvar next = nav_agent.get_next_path_position()
\tif not nav_agent.is_navigation_finished():
\t\tvar to_next = Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
\t\tif to_next.length_squared() > 0.02:
\t\t\tdir = to_next.normalized()
\t\telif dist_to_tgt > 0.8:
\t\t\tif _has_direct_clear_path(target):
\t\t\t\tdir = _flat_dir(global_position, target)"""

new_nav_corner = """\tvar next = nav_agent.get_next_path_position()
\tif not nav_agent.is_navigation_finished():
\t\tvar to_next = Vector3(next.x - global_position.x, 0.0, next.z - global_position.z)
\t\tif to_next.length_squared() > 0.003:
\t\t\tdir = to_next.normalized()
\t\telif dist_to_tgt > 0.6:
\t\t\tvar path = nav_agent.get_current_navigation_path()
\t\t\tvar p_idx = nav_agent.get_current_navigation_path_index()
\t\t\tif p_idx + 1 < path.size():
\t\t\t\tvar p_next = path[p_idx + 1]
\t\t\t\tvar to_p = Vector3(p_next.x - global_position.x, 0.0, p_next.z - global_position.z)
\t\t\t\tif to_p.length_squared() > 0.003:
\t\t\t\t\tdir = to_p.normalized()
\t\t\tif dir == Vector3.ZERO:
\t\t\t\tif _has_direct_clear_path(target):
\t\t\t\t\tdir = _flat_dir(global_position, target)
\t\t\t\telse:
\t\t\t\t\tdir = -global_transform.basis.z"""

if old_nav_corner in code:
    code = code.replace(old_nav_corner, new_nav_corner, 1)
    print("✅ _nav_move_to corner freeze patched")
else:
    print("⚠️ old_nav_corner not found")

# 5. Fix _navigation_recovery_target
old_recovery_func = """func _navigation_recovery_target(target: Vector3, delta: float) -> Vector3:
\tvar now: int = Engine.get_physics_frames()
\t# Ignore intentional pauses, routines, and inspections between movement requests.
\tif now - navigation_last_request > 2:
\t\tnavigation_stall_time = 0.0
\t\tnavigation_anchor = global_position
\tnavigation_last_request = now
\tif recovery_time > 0.0:
\t\trecovery_time -= delta
\t\tif _flat_dist(global_position, recovery_target) > 0.35:
\t\t\treturn recovery_target
\t\trecovery_time = 0.0
\t\trepath_timer = 999.0
\t\tnavigation_anchor = global_position
\t\tnavigation_stall_time = 0.0
\tif _flat_dist(global_position, target) < 1.0:
\t\tnavigation_stall_time = 0.0
\t\treturn target
\tif _flat_dist(global_position, navigation_anchor) > 0.35:
\t\tnavigation_anchor = global_position
\t\tnavigation_stall_time = 0.0
\telse:
\t\tnavigation_stall_time += delta
\tif navigation_stall_time < 1.5:
\t\treturn target
\tnavigation_stall_time = 0.0
\tnavigation_recoveries += 1
\trepath_timer = 999.0
\t_check_and_breach_doors()
\tvar nav_map: RID = nav_agent.get_navigation_map()
\tif not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
\t\treturn target
\tvar best_score: float = -INF
\tvar found: bool = false
\t# Sample both sides and backwards. A detour is held long enough to leave a corner.
\tfor i in range(24):
\t\tvar angle: float = TAU * float(i) / 24.0
\t\t# Пробуем 3 радиуса: 1.2, 2.2 и 3.5м для широкого охвата
\t\tfor radius in [1.2, 2.2, 3.5]:
\t\t\tvar candidate: Vector3 = global_position + Vector3(cos(angle), 0.0, sin(angle)) * radius
\t\t\tvar on_mesh: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, candidate)
\t\t\tif _flat_dist(candidate, on_mesh) > 0.8 or absf(on_mesh.y - global_position.y) > 0.8:
\t\t\t\tcontinue
\t\t\tvar motion: Vector3 = Vector3(on_mesh.x - global_position.x, 0.0, on_mesh.z - global_position.z)
\t\t\tif motion.length() < 0.5:
\t\t\t\tcontinue
\t\tvar route: PackedVector3Array = NavigationServer3D.map_get_path(nav_map, on_mesh, target, true)
\t\tvar score: float = -_flat_dist(on_mesh, target)
\t\tif route.size() > 1:
\t\t\tscore += 10.0
\t\tif score > best_score:
\t\t\tbest_score = score
\t\t\trecovery_target = on_mesh
\t\t\tfound = true
\tif found:
\t\trecovery_time = 1.8
\t\tai_thought = "Путь заблокирован. Обхожу препятствие."
\t\treturn recovery_target
\t# Unreachable routine/search targets must not trap the state machine forever.
\tif state == State.ROUTINE:
\t\t_end_routine()
\t\t_set_state(State.PATROL)
\tif state == State.PATROL and not waypoints.is_empty():
\t\twp_idx = (wp_idx + 1) % waypoints.size()
\telif state == State.SEARCH and not search_points.is_empty():
\t\tsearch_idx = (search_idx + 1) % search_points.size()"""

new_recovery_func = """func _navigation_recovery_target(target: Vector3, delta: float) -> Vector3:
\tvar now: int = Engine.get_physics_frames()
\tif now - navigation_last_request > 2:
\t\tnavigation_stall_time = 0.0
\t\tnavigation_anchor = global_position
\tnavigation_last_request = now

\tif recovery_time > 0.0:
\t\trecovery_time -= delta
\t\tif _flat_dist(global_position, recovery_target) > 0.35:
\t\t\treturn recovery_target
\t\trecovery_time = 0.0
\t\trepath_timer = 999.0
\t\tnavigation_anchor = global_position
\t\tnavigation_stall_time = 0.0

\tif _flat_dist(global_position, target) < 1.0:
\t\tnavigation_stall_time = 0.0
\t\treturn target

\tif _flat_dist(global_position, navigation_anchor) > 0.35:
\t\tnavigation_anchor = global_position
\t\tnavigation_stall_time = 0.0
\telse:
\t\tnavigation_stall_time += delta

\t# Быстрая реакция на застревание: 0.35 секунды вместо 1.5с
\tif navigation_stall_time < 0.35:
\t\treturn target

\tnavigation_stall_time = 0.0
\tnavigation_recoveries += 1
\trepath_timer = 999.0
\t_check_and_breach_doors()

\tvar nav_map: RID = nav_agent.get_navigation_map()
\tif not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
\t\treturn target

\tvar best_score: float = -INF
\tvar best_candidate: Vector3 = Vector3.ZERO
\tvar found: bool = false

\tfor i in range(16):
\t\tvar angle: float = TAU * float(i) / 16.0
\t\tfor rad in [1.5, 2.5]:
\t\t\tvar cand: Vector3 = global_position + Vector3(cos(angle), 0.0, sin(angle)) * rad
\t\t\tvar on_mesh: Vector3 = NavigationServer3D.map_get_closest_point(nav_map, cand)
\t\t\tif _flat_dist(cand, on_mesh) > 0.6 or absf(on_mesh.y - global_position.y) > 0.6:
\t\t\t\tcontinue
\t\t\tvar motion: Vector3 = Vector3(on_mesh.x - global_position.x, 0.0, on_mesh.z - global_position.z)
\t\t\tif motion.length() < 0.6:
\t\t\t\tcontinue
\t\t\tvar score: float = -_flat_dist(on_mesh, target)
\t\t\tif score > best_score:
\t\t\t\tbest_score = score
\t\t\t\tbest_candidate = on_mesh
\t\t\t\tfound = true

\tif found:
\t\trecovery_target = best_candidate
\t\trecovery_time = 1.4
\t\tai_thought = "Обхожу препятствие по дуге..."
\t\treturn recovery_target

\tif state == State.ROUTINE:
\t\t_end_routine()
\t\t_set_state(State.PATROL)
\tif state == State.PATROL and not waypoints.is_empty():
\t\twp_idx = (wp_idx + 1) % waypoints.size()
\telif state == State.SEARCH and not search_points.is_empty():
\t\tsearch_idx = (search_idx + 1) % search_points.size()"""

if old_recovery_func in code:
    code = code.replace(old_recovery_func, new_recovery_func, 1)
    print("✅ _navigation_recovery_target fast un-stuck patched")
else:
    print("⚠️ old_recovery_func not found, checking...")

with open(GAME + r'\scripts\Enemy.gd', 'w', encoding='utf-8') as f:
    f.write(code)

print("Saved Enemy.gd!")
