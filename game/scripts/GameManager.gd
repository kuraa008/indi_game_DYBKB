extends Node

# ──────────────────────────────────────────────
#  Signals
# ──────────────────────────────────────────────
signal enemy_go_basement       # Fired at 3:00 — enemy goes to check basement
signal game_won                # Player escaped
signal game_over               # Enemy caught player
signal inventory_changed       # Crowbar / key / battery picked up
signal note_opened(text: String)
signal note_closed
signal battery_changed(count: int)
signal door_state_changed(door: Node, is_open: bool)
signal light_state_changed(is_on: bool)
signal noise_made(pos: Vector3, radius: float)
signal throwables_changed(count: int)
signal graphics_quality_changed(quality: String)
signal legacy_graphics_changed(enabled: bool)
signal backpack_toggled(is_open: bool)
signal active_item_changed(index: int, item: Dictionary)
signal stamina_changed(current_stamina: float, max_stamina: float, is_exhausted: bool)
signal score_updated(player_score: int, monster_score: int, reason: String)
signal pain_triggered(who: String, penalty: int, reason: String)
signal monster_stare_changed(active: bool, spot_type: String, witnessed: bool)
signal mic_status_changed(enabled: bool, volume: float, triggered: bool)

var is_monster_staring: bool = false
var mic_enabled: bool = true
var mic_volume: float = 0.0
var mic_threshold: float = 0.065
var realistic_mode: bool = false


# ── Система очков, наград и боли ──
var player_score: int = 0
var monster_score: int = 0
var player_idle_timer: float = 0.0
var player_last_pos: Vector3 = Vector3.ZERO
var monster_hunt_timer: float = 0.0

const MAX_BACKPACK_SLOTS: int = 6
var is_backpack_open: bool = false
var active_item_index: int = -1
var show_viewmodel_arms: bool = false
var is_gamepad: bool = false

# ──────────────────────────────────────────────
#  Графика и качество (Высокая / Низкая [F3])
# ──────────────────────────────────────────────
var graphics_quality: String = "ultra"
var vhs_enabled: bool = true
var dynamic_resolution: bool = true
const SETTINGS_PATH := "user://settings.cfg"
const QUALITY_SCALE := {"ultra": 1.0, "high": 1.0, "medium": 0.9, "low": 0.75}
const MIN_SCALE: float = 0.6
var _res_scale: float = 1.0
var _res_timer: float = 0.0
var _res_good_time: float = 0.0
var _res_raise_block: float = 0.0
var _res_last_raise: float = -100.0
var _res_clock: float = 0.0
signal vhs_changed(enabled: bool)
var is_legacy_graphics: bool = false
var intro_cutscene_played: bool = false

# ──────────────────────────────────────────────
#  Случайный шифр для сейфа и записок
# ──────────────────────────────────────────────
var safe_code: String = ""

# ──────────────────────────────────────────────
#  Цветные ключи инвентаря
# ──────────────────────────────────────────────
var keys_inventory: Array[String] = []
var keys_by_id: Array[int] = []

# ──────────────────────────────────────────────
#  Throwables (Bottles / rocks for distraction)
# ──────────────────────────────────────────────
var throwables_count: int = 3
var road_flares_count: int = 0

# ──────────────────────────────────────────────
#  References (set by Main.gd after spawn)
#  Using Variant (untyped) to prevent "Trying to assign invalid previously freed instance" in Godot 4
# ──────────────────────────────────────────────
var player_ref = null
var enemy_ref  = null
var lumberjack_ref = null
var last_killer = null
var ui_ref     = null

# ──────────────────────────────────────────────
#  Inventory
# ──────────────────────────────────────────────
var has_crowbar:        bool = false
var has_key:            bool = false
var door_boards_broken: bool = false
var has_fuse_red:       bool = false
var has_fuse_blue:      bool = false
var has_fuse_green:     bool = false
var stored_props:       Array[Dictionary] = []

# ──────────────────────────────────────────────
#  Батарейки для фонарика
# ──────────────────────────────────────────────
var battery_cells:     int = 0
const MAX_BATTERY_CELLS: int = 3     # нужно 3 для электродвери
var electric_door_unlocked: bool = false

# ──────────────────────────────────────────────
#  Электропитание по ID (для электродверей и щитков)
#  Каждой электродвери с ID X требуется 3 питания (power_by_id[X] >= 3)
# ──────────────────────────────────────────────
var power_by_id: Dictionary = {} # int id -> int count (0..3)

func get_power_count(p_id: int) -> int:
	return int(power_by_id.get(p_id, 0))

func add_power(p_id: int, amount: int = 1) -> int:
	var cur = get_power_count(p_id) + amount
	power_by_id[p_id] = cur
	emit_signal("inventory_changed")
	return cur

func is_power_complete(p_id: int) -> bool:
	return get_power_count(p_id) >= 3

func reset_power_all() -> void:
	power_by_id.clear()

# ──────────────────────────────────────────────
#  Переключатель света (для prop_light_switch)
# ──────────────────────────────────────────────
var room_lights_on: bool = false

# ──────────────────────────────────────────────
#  Записки (отображаемый текст)
# ──────────────────────────────────────────────
var current_note_text: String = ""
var is_reading_note:   bool   = false

# ──────────────────────────────────────────────
#  Map data (filled by Main.gd from JSON)
# ──────────────────────────────────────────────
var active_map_path: String = "res://scenes/1level.json"
var door_position: Vector3 = Vector3(-0.9, 0.5, 10.5)

func is_level_2() -> bool:
	if active_map_path != "":
		var p = active_map_path.to_lower()
		if "карта_2" in p or "karta_2" in p or "карта_6" in p or "karta_6" in p or "level2" in p or "level_2" in p or "2level" in p:
			return true
	var tree = Engine.get_main_loop() as SceneTree
	if tree and tree.current_scene and "map_json_path" in tree.current_scene:
		var p2 = str(tree.current_scene.get("map_json_path")).to_lower()
		if "карта_2" in p2 or "karta_2" in p2 or "карта_6" in p2 or "karta_6" in p2 or "level2" in p2 or "level_2" in p2 or "2level" in p2:
			return true
	return false

# Known world points
var player_spawn: Vector3 = Vector3(-9.0, 0.0, -13.0)
var enemy_spawn:  Vector3 = Vector3(9.5,  0.0,  -1.5)
var lumberjack_spawn: Vector3 = Vector3(-2.0, 0.0, 1.0)

# ──────────────────────────────────────────────
#  3-Minute timer
# ──────────────────────────────────────────────
const BASEMENT_CHECK_TIME: float = 180.0   # 3 minutes
var timer_elapsed: float        = 0.0
var basement_triggered: bool    = false

# ──────────────────────────────────────────────
#  Читы и Режим разработчика (Консоль [~] и Отладка [F1, F2])
# ──────────────────────────────────────────────
var is_noclip: bool = false
var is_godmode: bool = false
var is_no_ai: bool = false
var speed_multiplier: float = 1.0
var show_ai_path: bool = false
var enemy_speed_multiplier: float = 1.0

const DebugOverlayScript = preload("res://scripts/DebugOverlay.gd")
const DevConsoleScript = preload("res://scripts/DevConsole.gd")
const MinimapScript = preload("res://scripts/Minimap.gd")

var debug_overlay: Node = null
var dev_console: Node = null
var minimap: Node = null
var mic_detector: Node = null

# ── Режиссер напряжения (Director AI) ──
var director_idle_timer: float = 0.0
var director_grace_timer: float = 0.0

# ──────────────────────────────────────────────
#  Game loop
# ──────────────────────────────────────────────
var game_ended: bool = false

func _process(delta: float) -> void:
	_update_dynamic_resolution(delta)
	if game_ended:
		return
	timer_elapsed += delta
	if not basement_triggered and timer_elapsed >= BASEMENT_CHECK_TIME:
		basement_triggered = true
		emit_signal("enemy_go_basement")

	_process_director_ai(delta)
	_process_score_and_pain(delta)

func _process_score_and_pain(delta: float) -> void:
	if game_ended:
		return
	if is_instance_valid(enemy_ref) and enemy_ref.has_method("uses_fixed_behavior"):
		return

	# 2. Проверка ИИ врага (если больше минуты не нашел игрока)
	if is_instance_valid(enemy_ref) and enemy_ref.has_method("_nav_move_to") and not is_no_ai:
		var en_state = enemy_ref.get("state")
		# 3 = HUNT, 6 = RAGE
		if en_state not in [3, 6]:
			monster_hunt_timer += delta
			if monster_hunt_timer >= 60.0:
				monster_hunt_timer = 0.0
				trigger_pain("monster", "Не нашел и не атаковал выжившего за 60 секунд")
		else:
			monster_hunt_timer = 0.0

func _process_director_ai(delta: float) -> void:
	if game_ended or is_no_ai or not is_instance_valid(player_ref) or not is_instance_valid(enemy_ref):
		return
	if enemy_ref.has_method("uses_fixed_behavior"):
		return

	if director_grace_timer > 0.0:
		director_grace_timer -= delta
		return

	var p_vel = player_ref.velocity.length()
	var is_hiding = player_ref.get("is_hiding") == true
	if p_vel < 0.2 or is_hiding:
		director_idle_timer += delta
	else:
		director_idle_timer = max(0.0, director_idle_timer - delta * 0.5)

	# Если игрок долго сидит в укрытии/комнате (> 22 секунд):
	if director_idle_timer > 22.0:
		director_idle_timer = 0.0
		if enemy_ref.get("state") in [0, 1]: # PATROL or ROUTINE
			var p_pos = player_ref.global_position
			var offset = Vector3(randf_range(-7.0, 7.0), 0, randf_range(-7.0, 7.0))
			enemy_ref.call("on_noise_heard", p_pos + offset, 50.0)

func _ready() -> void:
	_load_settings()
	_setup_gamepad_input_map()
	generate_new_safe_code()
	var ai_report = preload("res://scripts/AIReport.gd").new()
	ai_report.name = "AIReport"
	add_child(ai_report)

	debug_overlay = DebugOverlayScript.new()
	add_child(debug_overlay)

	dev_console = DevConsoleScript.new()
	add_child(dev_console)

	minimap = MinimapScript.new()
	add_child(minimap)

	mic_detector = load("res://scripts/MicrophoneDetector.gd").new()
	mic_detector.name = "MicrophoneDetector"
	add_child(mic_detector)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		is_gamepad = true
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.25:
			is_gamepad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		is_gamepad = false

func _add_joy_button_action(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return
	var ev_btn = InputEventJoypadButton.new()
	ev_btn.button_index = button
	InputMap.action_add_event(action, ev_btn)

func _add_joy_motion_action(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadMotion and ev.axis == axis and signf(ev.axis_value) == signf(value):
			return
	var ev_motion = InputEventJoypadMotion.new()
	ev_motion.axis = axis
	ev_motion.axis_value = value
	InputMap.action_add_event(action, ev_motion)

func _setup_gamepad_input_map() -> void:
	# Стики: Левый стик (ходьба)
	_add_joy_motion_action("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_motion_action("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_motion_action("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_motion_action("move_right", JOY_AXIS_LEFT_X, 1.0)

	# Кнопка A — Прыжок (Joy 0)
	_add_joy_button_action("jump", JOY_BUTTON_A)

	# Кнопка B — Присед (Joy 1)
	_add_joy_button_action("crouch", JOY_BUTTON_B)

	# Левый ближний шифт LB / L1 — Бег (Joy 9)
	_add_joy_button_action("sprint", JOY_BUTTON_LEFT_SHOULDER)

	# Правый курок RT — Взаимодействие (как ЛКМ: двери, шкаф, записки, рубильники)
	_add_joy_motion_action("interact", JOY_AXIS_TRIGGER_RIGHT, 1.0)

	# Кнопка Y — Взять предмет (как E: подбор лома, ключей, батареек, предметов)
	_add_joy_button_action("pick_up", JOY_BUTTON_Y)

	# Кнопка Y — Задержка дыхания в шкафу/укрытии (как Q)
	_add_joy_button_action("hold_breath", JOY_BUTTON_Y)

	# Задний левый курок LT — Выбросить / положить предмет (как ПКМ)
	_add_joy_motion_action("drop_item", JOY_AXIS_TRIGGER_LEFT, 1.0)

	# Кнопка X — Инвентарь / Рюкзак (Joy 2)
	_add_joy_button_action("toggle_backpack", JOY_BUTTON_X)

	# D-Pad Up / L3 — Фонарик [F]
	_add_joy_button_action("toggle_flashlight", JOY_BUTTON_DPAD_UP)
	_add_joy_button_action("toggle_flashlight", JOY_BUTTON_LEFT_STICK)

	# D-Pad Down — Бросок отвлекающего предмета [G]
	_add_joy_button_action("throw_distraction", JOY_BUTTON_DPAD_DOWN)

	# Правый бампер RB — Сигнальная ракета [H]
	_add_joy_button_action("use_road_flare", JOY_BUTTON_RIGHT_SHOULDER)

	# D-Pad Left / Right — стрелки: выбор предмета из нескольких рядом / смена слотов
	_add_joy_button_action("dpad_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button_action("dpad_right", JOY_BUTTON_DPAD_RIGHT)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_7:
			var cur_scene = get_tree().current_scene
			if cur_scene and cur_scene.name != "DebugEditor":
				get_tree().change_scene_to_file("res://scenes/DebugEditor.tscn")
		elif event.keycode == KEY_F3:
			toggle_graphics_quality()
		elif event.keycode == KEY_F4:
			set_vhs_enabled(not vhs_enabled)


# ──────────────────────────────────────────────
#  Safe Code & Quality Control
# ──────────────────────────────────────────────
func generate_new_safe_code() -> String:
	safe_code = "%03d" % randi_range(100, 999)
	return safe_code

func cycle_graphics_quality() -> String:
	match graphics_quality:
		"ultra":
			set_graphics_quality("high")
		"high":
			set_graphics_quality("medium")
		"medium":
			set_graphics_quality("low")
		"low":
			set_graphics_quality("ultra")
		_:
			set_graphics_quality("ultra")
	return graphics_quality

func toggle_graphics_quality() -> String:
	return cycle_graphics_quality()

func set_graphics_quality(quality: String) -> void:
	graphics_quality = quality
	_apply_viewport_quality()
	_save_settings()
	emit_signal("graphics_quality_changed", graphics_quality)

func set_dynamic_resolution(enabled: bool) -> void:
	dynamic_resolution = enabled
	_save_settings()
	if not enabled:
		_apply_viewport_quality()

func set_vhs_enabled(enabled: bool) -> void:
	vhs_enabled = enabled
	_save_settings()
	vhs_changed.emit(enabled)

# Первый запуск: встроенная графика получает среднее качество, дискретная — высокое.
# Дальше выбор игрока запоминается в user://settings.cfg
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		graphics_quality = str(cfg.get_value("video", "quality", graphics_quality))
		vhs_enabled = bool(cfg.get_value("video", "vhs", true))
		dynamic_resolution = bool(cfg.get_value("video", "dynamic_resolution", true))
	else:
		match RenderingServer.get_video_adapter_type():
			RenderingDevice.DEVICE_TYPE_DISCRETE_GPU:
				graphics_quality = "high"
			_:
				graphics_quality = "medium"
		_save_settings()
	_apply_viewport_quality()

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("video", "quality", graphics_quality)
	cfg.set_value("video", "vhs", vhs_enabled)
	cfg.set_value("video", "dynamic_resolution", dynamic_resolution)
	cfg.save(SETTINGS_PATH)

func _apply_viewport_quality() -> void:
	var vp := get_tree().root if is_inside_tree() else null
	if vp == null:
		return
	var heavy := graphics_quality in ["ultra", "high"]
	vp.msaa_3d = Viewport.MSAA_2X if heavy else Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if heavy else Viewport.SCREEN_SPACE_AA_FXAA
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	_res_scale = float(QUALITY_SCALE.get(graphics_quality, 1.0))
	_res_good_time = 0.0
	_res_raise_block = 0.0
	vp.scaling_3d_scale = _res_scale

# Динамическое разрешение: при просадке 3D-картинка рендерится мельче, UI остаётся чётким.
# Если повышение снова уронило FPS, повторная попытка откладывается на 30 секунд.
func _update_dynamic_resolution(delta: float) -> void:
	_res_clock += delta
	if not dynamic_resolution:
		return
	_res_timer += delta
	if _res_timer < 1.0:
		return
	_res_timer = 0.0
	_res_raise_block = maxf(0.0, _res_raise_block - 1.0)
	var fps := Engine.get_frames_per_second()
	var top := float(QUALITY_SCALE.get(graphics_quality, 1.0))
	var next := _res_scale
	if fps < 40.0:
		_res_good_time = 0.0
		next = maxf(MIN_SCALE, _res_scale - (0.1 if fps < 28.0 else 0.05))
		if _res_clock - _res_last_raise < 4.0:
			_res_raise_block = 30.0
	elif fps >= 57.0:
		_res_good_time += 1.0
		if _res_good_time >= 5.0 and _res_raise_block <= 0.0 and _res_scale < top:
			next = minf(top, _res_scale + 0.05)
			_res_last_raise = _res_clock
			_res_good_time = 0.0
	else:
		_res_good_time = 0.0
	if not is_equal_approx(next, _res_scale):
		_res_scale = next
		get_tree().root.scaling_3d_scale = _res_scale
func toggle_legacy_graphics() -> bool:
	is_legacy_graphics = not is_legacy_graphics
	emit_signal("legacy_graphics_changed", is_legacy_graphics)
	return is_legacy_graphics

func set_legacy_graphics(enabled: bool) -> void:
	is_legacy_graphics = enabled
	emit_signal("legacy_graphics_changed", is_legacy_graphics)

# ──────────────────────────────────────────────
#  Inventory actions
# ──────────────────────────────────────────────
func pick_up_crowbar() -> void:
	has_crowbar = true
	emit_signal("inventory_changed")

func pick_up_key() -> void:
	pick_up_id_key(1)

func pick_up_id_key(k_id: int) -> void:
	if not keys_by_id.has(k_id):
		keys_by_id.append(k_id)
	has_key = true
	match k_id:
		1:
			if not keys_inventory.has("gold"): keys_inventory.append("gold")
		2:
			if not keys_inventory.has("silver"): keys_inventory.append("silver")
		3:
			if not keys_inventory.has("emerald"): keys_inventory.append("emerald")
		4:
			if not keys_inventory.has("ruby"): keys_inventory.append("ruby")
		5:
			if not keys_inventory.has("sapphire"): keys_inventory.append("sapphire")
		6:
			if not keys_inventory.has("rusty"): keys_inventory.append("rusty")
	emit_signal("inventory_changed")

func has_key_id(k_id: int) -> bool:
	if k_id <= 0:
		return true
	if keys_by_id.has(k_id):
		return true
	match k_id:
		1: return keys_inventory.has("gold")
		2: return keys_inventory.has("silver")
		3: return keys_inventory.has("emerald")
		4: return keys_inventory.has("ruby")
		5: return keys_inventory.has("sapphire")
		6: return keys_inventory.has("rusty")
	return false

func pick_up_colored_key(color: String) -> void:
	var c = color.to_lower()
	if not keys_inventory.has(c):
		keys_inventory.append(c)
	var kid = 1
	match c:
		"gold": kid = 1
		"silver": kid = 2
		"emerald": kid = 3
		"ruby": kid = 4
		"sapphire": kid = 5
		"rusty": kid = 6
	if not keys_by_id.has(kid):
		keys_by_id.append(kid)
	has_key = true
	emit_signal("inventory_changed")

func has_key_color(color: String) -> bool:
	var c = color.to_lower()
	if c == "none" or c == "":
		return true
	if c in keys_inventory:
		return true
	var kid = 0
	match c:
		"gold": kid = 1
		"silver": kid = 2
		"emerald": kid = 3
		"ruby": kid = 4
		"sapphire": kid = 5
		"rusty": kid = 6
	if kid > 0 and keys_by_id.has(kid):
		return true
	if has_key and (c == "gold" or keys_inventory.is_empty()):
		return true
	return false

func get_key_display_color() -> Color:
	if not has_key and keys_inventory.is_empty():
		return Color(0.18, 0.18, 0.18)
	if keys_inventory.is_empty():
		return Color(1.0, 0.85, 0.15)
	match keys_inventory[0]:
		"gold": return Color(1.0, 0.85, 0.15)
		"silver": return Color(0.85, 0.90, 0.95)
		"rusty": return Color(0.72, 0.45, 0.25)
		"emerald": return Color(0.15, 0.95, 0.45)
		_: return Color(1.0, 0.85, 0.15)

func pick_up_battery() -> void:
	battery_cells += 1
	if player_ref and player_ref.has_method("recharge_battery"):
		player_ref.call("recharge_battery", 50.0)
	emit_signal("battery_changed", battery_cells)
	emit_signal("inventory_changed")
	if ui_ref and ui_ref.has_method("show_hint"):
		ui_ref.call("show_hint", "Батарея (%d/%d) убрана в рюкзак [Tab / X]" % [battery_cells, MAX_BATTERY_CELLS], 3.5)

func pick_up_road_flare() -> void:
	road_flares_count += 1
	emit_signal("inventory_changed")
	if ui_ref and ui_ref.has_method("show_hint"):
		ui_ref.call("show_hint", "Сигнальная ракета убрана в рюкзак [Tab / X]. Нажми [H], чтобы осветить путь.", 4.0)

func add_road_flare(count: int = 1) -> void:
	road_flares_count += count
	emit_signal("inventory_changed")

func pick_up_prop(prop_id: String, prop_name: String) -> void:
	var desc = "Предмет окружения."
	if prop_id == "alarm_clock":
		desc = "Механический ретро-будильник. При броске на [ПКМ / LT] заводится звонок и привлекает скинвокера."
	elif prop_id == "tv_remote":
		desc = "Пульт дистанционного управления. Можно включить телевизор и отвлечь монстра."
	stored_props.append({
		"id": prop_id,
		"name": prop_name,
		"icon": "—",
		"count": 1,
		"desc": desc
	})
	emit_signal("inventory_changed")

func pick_up_fuse(color: String) -> void:
	match color.to_lower():
		"red", "красный":
			has_fuse_red = true
		"blue", "синий":
			has_fuse_blue = true
		"green", "зеленый", "зелёный":
			has_fuse_green = true
	emit_signal("inventory_changed")
	if ui_ref and ui_ref.has_method("show_hint"):
		var col_name = "КРАСНЫЙ" if color.to_lower() in ["red", "красный"] else ("СИНИЙ" if color.to_lower() in ["blue", "синий"] else "ЗЕЛЁНЫЙ")
		ui_ref.call("show_hint", "%s предохранитель убран в рюкзак [Tab / X]" % col_name, 3.5)

# ──────────────────────────────────────────────
#  Управление рюкзаком (Backpack Inventory - 6 слотов)
# ──────────────────────────────────────────────
func get_backpack_items() -> Array[Dictionary]:
	var items: Array[Dictionary] = []

	# 1. Бутылки для отвлечения (если есть)
	if throwables_count > 0:
		items.append({
			"id": "bottle",
			"name": "Бутылка",
			"icon": "—",
			"count": throwables_count,
			"desc": "Стеклянная бутылка. Бросок на [G] создает звон и отвлекает скинвокера."
		})

	# 2. Лом (монтировка)
	if has_crowbar:
		items.append({
			"id": "crowbar",
			"name": "Монтировка-лом",
			"icon": "—",
			"count": 1,
			"desc": "Прочный стальной лом. Позволяет срывать доски с заколоченной выходной двери на [E]."
		})

	# 3. Найденные ключи по ID
	var DoorScript = load("res://scripts/Door.gd")
	for kid in keys_by_id:
		var th = DoorScript.get_lock_theme(kid)
		items.append({
			"id": "key_id_%d" % kid,
			"name": "%s ключ №%d" % [th["name"], kid],
			"icon": "—",
			"key_id": kid,
			"key_color": th["name"].to_lower(),
			"count": 1,
			"desc": "Ключ №%d (%s цвет). Подходит для открывания дверей с замком №%d на [E]." % [kid, th["name"], kid]
		})

	# Старые ключи (если есть)
	for k in keys_inventory:
		var kid = 1
		match k:
			"gold": kid = 1
			"silver": kid = 2
			"emerald": kid = 3
			"ruby": kid = 4
			"sapphire": kid = 5
			"rusty": kid = 6
		if keys_by_id.has(kid):
			continue
		var th = DoorScript.get_lock_theme(kid)
		items.append({
			"id": "key_" + k,
			"name": "%s ключ" % th["name"],
			"icon": "—",
			"key_color": k,
			"count": 1,
			"desc": "Ключ от запертой двери. Открывает замок цвета '%s' на [E]." % k
		})

	# 4. Батарейки
	if battery_cells > 0:
		items.append({
			"id": "battery",
			"name": "Батарея питания",
			"icon": "—",
			"count": battery_cells,
			"desc": "Элемент питания (%d/%d). Нужен для зарядки фонарика и питания энергощитка двери." % [battery_cells, MAX_BATTERY_CELLS]
		})

	# 5. Предохранители
	if has_fuse_red:
		items.append({
			"id": "fuse_red",
			"name": "Красный предохранитель",
			"icon": "—",
			"count": 1,
			"desc": "Высоковольтный красный предохранитель для распределительного щитка питания."
		})
	if has_fuse_blue:
		items.append({
			"id": "fuse_blue",
			"name": "Синий предохранитель",
			"icon": "—",
			"count": 1,
			"desc": "Высоковольтный синий предохранитель для распределительного щитка питания."
		})
	if has_fuse_green:
		items.append({
			"id": "fuse_green",
			"name": "Зеленый предохранитель",
			"icon": "—",
			"count": 1,
			"desc": "Высоковольтный зеленый предохранитель для распределительного щитка питания."
		})

	if road_flares_count > 0:
		items.append({
			"id": "road_flare",
			"name": "Сигнальная ракета",
			"icon": "—",
			"count": road_flares_count,
			"desc": "Ярко горит и несколько раз шумит. Брось её клавишей [H], чтобы осветить проход и увести монстра на звук."
		})

	# 6. Предметы окружения в рюкзаке (будильник, пульт)
	for prop in stored_props:
		items.append(prop)

	# Строгое ограничение: ровно MAX_BACKPACK_SLOTS (6) слотов
	var result: Array[Dictionary] = []
	for i in range(MAX_BACKPACK_SLOTS):
		if i < items.size():
			result.append(items[i])
		else:
			result.append({
				"id": "empty",
				"name": "Пусто",
				"icon": "—",
				"count": 0,
				"desc": "Свободный карман рюкзака. Здесь можно хранить найденные предметы и припасы."
			})

	return result

func toggle_backpack() -> void:
	if is_reading_note or game_ended:
		return
	is_backpack_open = not is_backpack_open
	if is_backpack_open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("backpack_toggled", is_backpack_open)

func open_backpack() -> void:
	if not is_backpack_open and not is_reading_note and not game_ended:
		is_backpack_open = true
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		emit_signal("backpack_toggled", true)

func close_backpack() -> void:
	if is_backpack_open:
		is_backpack_open = false
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		emit_signal("backpack_toggled", false)

func set_active_backpack_slot(idx: int) -> void:
	if idx < 0:
		if active_item_index != -1:
			active_item_index = -1
			emit_signal("active_item_changed", -1, {})
		return
	var items = get_backpack_items()
	if idx >= 0 and idx < items.size():
		var it = items[idx]
		if it.get("id", "empty") == "empty":
			if active_item_index != -1:
				active_item_index = -1
				emit_signal("active_item_changed", -1, {})
			return
		if active_item_index == idx:
			# Повторный клик — освободить правую руку
			active_item_index = -1
			emit_signal("active_item_changed", -1, {})
		else:
			active_item_index = idx
			emit_signal("active_item_changed", idx, it)

func get_active_item() -> Dictionary:
	var items = get_backpack_items()
	if active_item_index >= 0 and active_item_index < items.size():
		var it = items[active_item_index]
		if it.get("id", "empty") != "empty":
			return it
	return {}

func get_active_item_id() -> String:
	var it = get_active_item()
	return str(it.get("id", ""))

func spawn_world_item(pos: Vector3, type: String, key_id: int = 0) -> Node:
	var area = Area3D.new()
	area.set_script(load("res://scripts/Item.gd"))
	area.set_meta("item_type", type)
	if key_id > 0:
		area.set("key_id", key_id)
		area.set_meta("key_id", key_id)
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(area)
		area.global_position = pos
	return area

func drop_backpack_slot(idx: int, custom_drop_pos: Vector3 = Vector3.ZERO) -> bool:
	var items = get_backpack_items()
	if idx < 0 or idx >= items.size():
		return false
	var it = items[idx]
	var item_id = str(it.get("id", "empty"))
	if item_id == "empty":
		return false

	var drop_pos = custom_drop_pos
	if drop_pos == Vector3.ZERO and player_ref and is_instance_valid(player_ref):
		var cam = player_ref.camera if "camera" in player_ref and player_ref.camera else null
		if cam:
			drop_pos = player_ref.global_position - cam.global_transform.basis.z * 1.05
		else:
			drop_pos = player_ref.global_position - player_ref.global_transform.basis.z * 1.05
		drop_pos.y = player_ref.global_position.y + 0.35
	elif drop_pos == Vector3.ZERO:
		drop_pos = Vector3(0, 0.5, 0)

	var spawned: Node = null
	if item_id == "crowbar":
		has_crowbar = false
		spawned = spawn_world_item(drop_pos, "crowbar")
	elif item_id.begins_with("key_id_"):
		var kid = int(item_id.trim_prefix("key_id_"))
		keys_by_id.erase(kid)
		spawned = spawn_world_item(drop_pos, "key", kid)
	elif item_id.begins_with("key_"):
		var col = item_id.trim_prefix("key_")
		keys_inventory.erase(col)
		var kid = 1
		match col:
			"gold": kid = 1
			"silver": kid = 2
			"emerald": kid = 3
			"ruby": kid = 4
			"sapphire": kid = 5
			"rusty": kid = 6
		spawned = spawn_world_item(drop_pos, "key", kid)
	elif item_id == "battery":
		battery_cells = max(0, battery_cells - 1)
		spawned = spawn_world_item(drop_pos, "battery")
	elif item_id == "fuse_red":
		has_fuse_red = false
		spawned = spawn_world_item(drop_pos, "fuse_red")
	elif item_id == "fuse_blue":
		has_fuse_blue = false
		spawned = spawn_world_item(drop_pos, "fuse_blue")
	elif item_id == "fuse_green":
		has_fuse_green = false
		spawned = spawn_world_item(drop_pos, "fuse_green")
	elif item_id == "bottle":
		throwables_count = max(0, throwables_count - 1)
		spawned = spawn_world_item(drop_pos, "bottle")
	elif item_id == "road_flare":
		road_flares_count = max(0, road_flares_count - 1)
		spawned = spawn_world_item(drop_pos, "road_flare")
	else:
		var prop_idx = -1
		for p_i in range(stored_props.size()):
			if stored_props[p_i].get("id", "") == item_id:
				prop_idx = p_i
				break
		if prop_idx != -1:
			stored_props.remove_at(prop_idx)
			spawned = spawn_world_item(drop_pos, item_id)

	if active_item_index == idx:
		set_active_backpack_slot(-1)
	elif active_item_index > idx:
		active_item_index -= 1

	emit_signal("inventory_changed")
	return spawned != null

func drop_active_item(custom_drop_pos: Vector3 = Vector3.ZERO) -> bool:
	if active_item_index >= 0:
		return drop_backpack_slot(active_item_index, custom_drop_pos)
	return false

var active_note_node: Node = null

func open_note(text: String, note_node: Node = null) -> void:
	current_note_text = text
	active_note_node = note_node
	is_reading_note = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	emit_signal("note_opened", text)

func close_note() -> void:
	is_reading_note = false
	current_note_text = ""
	active_note_node = null
	if player_ref and not player_ref.is_dead:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("note_closed")

func save_note_text(new_text: String) -> void:
	current_note_text = new_text
	if active_note_node and is_instance_valid(active_note_node):
		active_note_node.set_meta("note_text", new_text)

func toggle_room_lights() -> bool:
	room_lights_on = not room_lights_on
	emit_signal("light_state_changed", room_lights_on)
	if is_instance_valid(enemy_ref) and enemy_ref.has_method("on_light_altered"):
		enemy_ref.call("on_light_altered", room_lights_on)
	return room_lights_on

func notify_door_opened(door: Node, is_open_now: bool) -> void:
	emit_signal("door_state_changed", door, is_open_now)
	if is_instance_valid(enemy_ref) and enemy_ref.has_method("on_door_altered") and not door_state_changed.is_connected(enemy_ref.on_door_altered):
		enemy_ref.call("on_door_altered", door, is_open_now)

func emit_noise(pos: Vector3, radius: float = 30.0, _source: String = "environment") -> void:
	emit_signal("noise_made", pos, radius)
	# Визуальная волна спавнится ИСКЛЮЧИТЕЛЬНО в режиме отладки (F1). Игрок за ГГ её не видит!
	if debug_overlay and is_instance_valid(debug_overlay) and debug_overlay.visible:
		_spawn_acoustic_wave(pos)

func set_monster_stare(active: bool, spot_type: String = "", witnessed: bool = false) -> void:
	is_monster_staring = active
	emit_signal("monster_stare_changed", active, spot_type, witnessed)

func set_mic_enabled(val: bool) -> void:
	mic_enabled = val
	emit_signal("mic_status_changed", mic_enabled, mic_volume, false)

func toggle_mic() -> bool:
	mic_enabled = not mic_enabled
	emit_signal("mic_status_changed", mic_enabled, mic_volume, false)
	return mic_enabled

func _spawn_acoustic_wave(pos: Vector3) -> void:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree or not tree.current_scene:
		return
	var wave_script = load("res://scripts/AcousticWave.gd")
	if wave_script:
		var wave = Node3D.new()
		wave.set_script(wave_script)
		tree.current_scene.add_child(wave)
		wave.global_position = pos

func add_score(who: String, amount: int, reason: String = "") -> void:
	if who == "player":
		player_score += amount
	elif who == "monster":
		monster_score += amount
	emit_signal("score_updated", player_score, monster_score, reason)

func trigger_pain(who: String, reason: String) -> void:
	if game_ended or who != "monster" or is_no_ai or not is_instance_valid(enemy_ref) or not enemy_ref.has_method("_nav_move_to"):
		return

	var tree = Engine.get_main_loop() as SceneTree

	if who == "monster":
		monster_score = max(0, monster_score - 40)
		emit_signal("pain_triggered", "monster", 40, reason)
		emit_signal("score_updated", player_score, monster_score, "Штраф Скинвокеру: " + reason)

		if tree and tree.current_scene and ResourceLoader.exists("res://assets/audio/skinwalker_scream.wav"):
			var p = AudioStreamPlayer.new()
			p.stream = load("res://assets/audio/skinwalker_scream.wav")
			p.volume_db = -5.0
			tree.current_scene.add_child(p)
			p.play()
			p.finished.connect(func(): p.queue_free())

func use_throwable() -> bool:
	if throwables_count > 0:
		throwables_count -= 1
		emit_signal("throwables_changed", throwables_count)
		if throwables_count <= 0:
			var cur_it = get_active_item()
			if cur_it.get("id", "") == "bottle":
				active_item_index = -1
				emit_signal("active_item_changed", -1, {})
		emit_signal("inventory_changed")
		return true
	return false

func add_throwables(count: int = 1) -> void:
	throwables_count += count
	emit_signal("throwables_changed", throwables_count)
	emit_signal("inventory_changed")

func pick_up_throwable(count: int = 1) -> void:
	add_throwables(count)

func use_road_flare() -> bool:
	if road_flares_count <= 0:
		return false
	road_flares_count -= 1
	emit_signal("inventory_changed")
	return true

func try_use_electric_door() -> String:
	if electric_door_unlocked:
		return "unlocked"
	if battery_cells >= MAX_BATTERY_CELLS:
		electric_door_unlocked = true
		return "unlocked"
	return "need_battery"


# ──────────────────────────────────────────────
#  Door interaction
#  Returns a string code so Door.gd knows what happened
# ──────────────────────────────────────────────
func try_use_on_door() -> String:
	if not door_boards_broken:
		if has_crowbar:
			door_boards_broken = true
			emit_signal("inventory_changed")
			return "boards_broken"
		else:
			return "no_crowbar"
	else:
		if has_key:
			return "unlocked"
		else:
			return "no_key"

# ──────────────────────────────────────────────
#  Enemy basement callback
# ──────────────────────────────────────────────
func enemy_checked_basement_empty() -> void:
	# Enemy didn't find player → go full RAGE
	if is_instance_valid(enemy_ref) and enemy_ref.has_method("trigger_rage"):
		enemy_ref.call("trigger_rage")

# ──────────────────────────────────────────────
#  End states
# ──────────────────────────────────────────────
func _win() -> void:
	if game_ended:
		return
	game_ended = true
	emit_signal("game_won")

func trigger_game_won() -> void:
	_win()

func trigger_game_over() -> void:
	if game_ended or is_godmode:
		return
	game_ended = true
	emit_signal("game_over")

func reset_state(keep_references: bool = false) -> void:
	game_ended = false
	timer_elapsed = 0.0
	basement_triggered = false
	has_crowbar = false
	has_key = false
	keys_inventory.clear()
	keys_by_id.clear()
	stored_props.clear()
	generate_new_safe_code()
	door_boards_broken = false
	has_fuse_red = false
	has_fuse_blue = false
	has_fuse_green = false
	battery_cells = 0
	power_by_id.clear()
	electric_door_unlocked = false
	room_lights_on = false
	throwables_count = 3
	road_flares_count = 0
	is_reading_note = false
	current_note_text = ""
	is_backpack_open = false
	active_item_index = -1
	if not keep_references:
		player_ref = null
		enemy_ref = null
		lumberjack_ref = null
		ui_ref = null
	player_score = 0
	monster_score = 0
	player_idle_timer = 0.0
	player_last_pos = Vector3.ZERO
	monster_hunt_timer = 0.0
	is_monster_staring = false
	emit_signal("inventory_changed")

func get_time_remaining() -> float:
	return max(0.0, BASEMENT_CHECK_TIME - timer_elapsed)

func get_timer_elapsed() -> float:
	return timer_elapsed
