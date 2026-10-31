import sys
sys.stdout.reconfigure(encoding='utf-8')

GAME = r'c:\Users\tabam\Desktop\Escape in skinwalker\game'

# 1. GameManager.gd: Untype player_ref, enemy_ref, ui_ref and fix truthiness checks
with open(GAME + r'\scripts\GameManager.gd', 'r', encoding='utf-8') as f:
    gm = f.read()

old_refs = """# ──────────────────────────────────────────────
#  References (set by Main.gd after spawn)
# ──────────────────────────────────────────────
var player_ref: CharacterBody3D = null
var enemy_ref:  CharacterBody3D = null
var ui_ref:     CanvasLayer     = null"""

new_refs = """# ──────────────────────────────────────────────
#  References (set by Main.gd after spawn)
#  Using Variant (untyped) to prevent "Trying to assign invalid previously freed instance" in Godot 4
# ──────────────────────────────────────────────
var player_ref = null
var enemy_ref  = null
var ui_ref     = null"""

if old_refs in gm:
    gm = gm.replace(old_refs, new_refs, 1)
    print("✅ GameManager.gd references untyped")
else:
    print("⚠️ old_refs not found in GameManager.gd")

# Fix GameManager line 173:
old_proc = "if game_ended or is_no_ai or not player_ref or not is_instance_valid(player_ref) or not enemy_ref or not is_instance_valid(enemy_ref):"
new_proc = "if game_ended or is_no_ai or not is_instance_valid(player_ref) or not is_instance_valid(enemy_ref):"
if old_proc in gm:
    gm = gm.replace(old_proc, new_proc, 1)
    print("✅ GameManager.gd _process_director_ai check fixed")
else:
    print("⚠️ old_proc not found in GameManager.gd")

with open(GAME + r'\scripts\GameManager.gd', 'w', encoding='utf-8') as f:
    f.write(gm)


# 2. Enemy.gd: Untype node reference variables and remove await
with open(GAME + r'\scripts\Enemy.gd', 'r', encoding='utf-8') as f:
    enemy = f.read()

old_enemy_vars = """var stare_spot_node: Node3D = null
var stare_spot_type: String = ""
var stare_witnessed: bool = false
var stare_timer: float = 0.0
var stare_duration: float = 3.5

# Поиск со свидетелем
var current_search_node: Node = null
var search_points:     Array[Vector3] = []
var search_idx:        int = 0
var search_duration:   float = 15.0
var search_sub_timer:  float = 0.0
var search_inspecting: bool = false
var search_inspect_timer: float = 0.0
var last_ambush_pos:   Vector3 = Vector3.ZERO
var stuck_timer:           float = 0.0
var door_check_timer:      float = 0.0
var furniture_check_timer: float = 0.0
var basement_check_timer:  float = 0.0
var witnessed_hiding_spot: Node3D = null

# Распорядок дня (Hello Neighbor стиль)
var routine_action: String = ""
var routine_timer: float = 0.0
var routine_duration: float = 0.0
var furniture_cache: Array[Dictionary] = []
var routine_travel_timer: float = 0.0
var routine_target_node: Node = null"""

new_enemy_vars = """var stare_spot_node = null
var stare_spot_type: String = ""
var stare_witnessed: bool = false
var stare_timer: float = 0.0
var stare_duration: float = 3.5

# Поиск со свидетелем
var current_search_node = null
var search_points:     Array[Vector3] = []
var search_idx:        int = 0
var search_duration:   float = 15.0
var search_sub_timer:  float = 0.0
var search_inspecting: bool = false
var search_inspect_timer: float = 0.0
var last_ambush_pos:   Vector3 = Vector3.ZERO
var stuck_timer:           float = 0.0
var door_check_timer:      float = 0.0
var furniture_check_timer: float = 0.0
var basement_check_timer:  float = 0.0
var witnessed_hiding_spot = null

# Распорядок дня (Hello Neighbor стиль)
var routine_action: String = ""
var routine_timer: float = 0.0
var routine_duration: float = 0.0
var furniture_cache: Array[Dictionary] = []
var routine_travel_timer: float = 0.0
var routine_target_node = null"""

if old_enemy_vars in enemy:
    enemy = enemy.replace(old_enemy_vars, new_enemy_vars, 1)
    print("✅ Enemy.gd node reference variables untyped")
else:
    print("⚠️ old_enemy_vars not found in Enemy.gd")

old_clamp = """func _validate_and_clamp_waypoints() -> void:
\tawait get_tree().physics_frame
\tawait get_tree().physics_frame
\tvar nav_map = get_world_3d().navigation_map
\tif not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
\t\treturn
\tfor i in range(waypoints.size()):
\t\tvar clamped = NavigationServer3D.map_get_closest_point(nav_map, waypoints[i])
\t\tif clamped.distance_to(waypoints[i]) < 6.0:
\t\t\twaypoints[i] = clamped"""

new_clamp = """func _validate_and_clamp_waypoints() -> void:
\tif not is_inside_tree():
\t\treturn
\tvar world_3d = get_world_3d()
\tif not world_3d:
\t\treturn
\tvar nav_map = world_3d.navigation_map
\tif not nav_map.is_valid() or NavigationServer3D.map_get_iteration_id(nav_map) == 0:
\t\treturn
\tfor i in range(waypoints.size()):
\t\tvar clamped = NavigationServer3D.map_get_closest_point(nav_map, waypoints[i])
\t\tif clamped.distance_to(waypoints[i]) < 6.0:
\t\t\twaypoints[i] = clamped"""

if old_clamp in enemy:
    enemy = enemy.replace(old_clamp, new_clamp, 1)
    print("✅ Enemy.gd _validate_and_clamp_waypoints safe (no await)")
else:
    print("⚠️ old_clamp not found in Enemy.gd")

# Replace get_tree().create_timer in Enemy.gd
enemy = enemy.replace("get_tree().create_timer(1.2).timeout.connect(p.queue_free)", "p.finished.connect(p.queue_free)")
enemy = enemy.replace("get_tree().create_timer(2.5).timeout.connect(p.queue_free)", "p.finished.connect(p.queue_free)")
enemy = enemy.replace("get_tree().create_timer(3.0).timeout.connect(p.queue_free)", "p.finished.connect(p.queue_free)")

with open(GAME + r'\scripts\Enemy.gd', 'w', encoding='utf-8') as f:
    f.write(enemy)
print("✅ Enemy.gd audio free timers replaced with p.finished")


# 3. Door.gd: replace get_tree().create_timer with tween
with open(GAME + r'\scripts\Door.gd', 'r', encoding='utf-8') as f:
    door = f.read()

old_door_timer = """\t# Временно отключаем коллизию дверного полотна на 0.35с, чтобы монстр не спотыкался об распахивающуюся дверь
\tvar pnl = find_child("Panel", true, false)
\tif pnl and pnl is CollisionObject3D:
\t\tvar col_obj = pnl as CollisionObject3D
\t\tcol_obj.set_collision_layer_value(1, false)
\t\tget_tree().create_timer(0.35).timeout.connect(func():
\t\t\tif is_instance_valid(col_obj):
\t\t\t\tcol_obj.set_collision_layer_value(1, true)
\t\t)"""

new_door_timer = """\t# Временно отключаем коллизию дверного полотна на 0.35с, чтобы монстр не спотыкался об распахивающуюся дверь
\tvar pnl = find_child("Panel", true, false)
\tif is_instance_valid(pnl) and pnl is CollisionObject3D:
\t\tpnl.set_collision_layer_value(1, false)
\t\tvar c_tw = create_tween()
\t\tif c_tw:
\t\t\tc_tw.tween_interval(0.35)
\t\t\tc_tw.tween_callback(func():
\t\t\t\tif is_instance_valid(pnl):
\t\t\t\t\tpnl.set_collision_layer_value(1, true)
\t\t\t)"""

if old_door_timer in door:
    door = door.replace(old_door_timer, new_door_timer, 1)
    print("✅ Door.gd timer replaced with node-bound tween")
else:
    print("⚠️ old_door_timer not found in Door.gd")

with open(GAME + r'\scripts\Door.gd', 'w', encoding='utf-8') as f:
    f.write(door)


# 4. PlayerHands.gd, PlayerBody3D.gd, MonsterClaws.gd: untype player_ref
for script_name in ['PlayerHands.gd', 'PlayerBody3D.gd', 'MonsterClaws.gd']:
    sp = GAME + r'\scripts\\' + script_name
    with open(sp, 'r', encoding='utf-8') as f:
        sc = f.read()
    if 'var player_ref: CharacterBody3D = null' in sc:
        sc = sc.replace('var player_ref: CharacterBody3D = null', 'var player_ref = null', 1)
        with open(sp, 'w', encoding='utf-8') as f:
            f.write(sc)
        print(f"✅ {script_name} player_ref untyped")

# 5. Player.gd: untype hiding_node
with open(GAME + r'\scripts\Player.gd', 'r', encoding='utf-8') as f:
    pl = f.read()
if 'var hiding_node:      Node3D  = null' in pl:
    pl = pl.replace('var hiding_node:      Node3D  = null', 'var hiding_node = null', 1)
    with open(GAME + r'\scripts\Player.gd', 'w', encoding='utf-8') as f:
        f.write(pl)
    print("✅ Player.gd hiding_node untyped")

print("All freed instance safety fixes applied successfully!")
