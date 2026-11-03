extends CharacterBody3D

# ──────────────────────────────────────────────
#  Constants
# ──────────────────────────────────────────────
const WALK_SPEED:            float = 4.2
const SPRINT_SPEED:          float = 6.2
const JUMP_VELOCITY:         float = 5.5
const MOUSE_SENSITIVITY:     float = 0.0018
const GRAVITY:               float = 9.8
const BATTERY_DRAIN_RATE:    float = 0.0   # battery drain disabled per user request
const BATTERY_RECHARGE_RATE: float = 0.0

# ──────────────────────────────────────────────
#  Nodes
# ──────────────────────────────────────────────
var head:         Node3D
var camera:       Camera3D
var interact_ray: RayCast3D
var breath_sys:   Node
var flashlight:   SpotLight3D
var heart_audio:  AudioStreamPlayer
var ded_audio:    AudioStreamPlayer
var player_body:  Node3D   # PlayerBody3D — 2D-спрайты персонажа
var player_hands: PlayerHands = null  # 3D руки от первого лица

# ── Перенос и бросок предметов (будильник, пульт, стулья, ключи) ──
var carry_pivot:      Node3D = null
var held_object:      Node3D = null
var throw_charge:     float = 0.0
var is_charging_throw: bool = false
var event_r_down:     bool = false
const MAX_THROW_CHARGE_TIME: float = 1.1
var highlight_material: StandardMaterial3D = null
var current_highlighted_node: Node = null

# ── Автоприцел и выбор предметов стрелками D-Pad ──
var nearby_interactables: Array[Node] = []
var active_interactable_idx: int = 0
var manual_selection_timer: float = 0.0

# Collision refs
var col_node:  CollisionShape3D
var col_shape: CapsuleShape3D

# ──────────────────────────────────────────────
#  State
# ──────────────────────────────────────────────
var is_dead:           bool  = false
var flash_flicker_t:   float = 0.0
var flash_base_energy: float = 4.5
var heart_target_vol:  float = -80.0

# Jump / landing
var was_on_floor: bool = false
var blocked_move_timer: float = 0.0
var auto_jump_cooldown: float = 0.0

# Crouch
var is_crouching: bool = false

# Flashlight battery
var flash_battery:  float = 100.0   # 0 – 100 percent
var flashlight_on:  bool  = true
var is_in_cutscene: bool  = false

# ──────────────────────────────────────────────
#  Стамина (Выносливость)
# ──────────────────────────────────────────────
var stamina:               float = 100.0
var max_stamina:           float = 100.0
var stamina_drain_sprint:  float = 20.0   # ~5 секунд чистого спринта
var stamina_drain_jump:    float = 14.0   # Расход на прыжок
var stamina_recovery_rate: float = 16.0   # Скорость восстановления в покое
var stamina_recover_delay: float = 0.8    # Задержка перед отдыхом
var stamina_delay_timer:   float = 0.0
var is_exhausted:          bool  = false
var is_sprinting:          bool  = false

# ──────────────────────────────────────────────
#  Укрытия (Шкаф и Кровать)
# ──────────────────────────────────────────────
var is_hiding:        bool    = false
var hiding_node = null
var hiding_type:      String  = ""      # "wardrobe" или "bed"
var unhidden_pos:     Vector3 = Vector3.ZERO
var hiding_base_yaw:  float   = 0.0
var hiding_saved_camera_near: float = 0.05
var hiding_saved_head_position: Vector3 = Vector3(0, 1.62, 0)
var hiding_saved_hands_visible: bool = false
var hiding_saved_body_visible: bool = false
var under_bed_light: OmniLight3D = null
var wardrobe_light:  OmniLight3D = null
var dust_particles:  GPUParticles3D = null

# ── Подглядывание в замочную скважину дверей ──
var is_peeking_keyhole: bool = false
var peeking_door_ref: Node3D = null
var keyhole_saved_head_pos: Vector3 = Vector3.ZERO
var keyhole_saved_head_rot: Vector3 = Vector3.ZERO
var keyhole_base_yaw: float = 0.0




# ──────────────────────────────────────────────
#  Тряска камеры, дыхание и пульс сердца
# ──────────────────────────────────────────────
var bob_t:               float = 0.0
var breath_sway_t:       float = 0.0
var heart_pulse_t:       float = 0.0
var last_heart_thump:    float = 0.0
var base_cam_fov:        float = 80.0
var cam_land_spring:     float = 0.0
var cam_land_pitch:      float = 0.0
var cam_dip:             float = 0.0
var mouse_input_raw:     Vector2 = Vector2.ZERO
var mouse_vel_smooth:    float = 0.0
var strafe_tilt:         float = 0.0
var fall_velocity_saved: float = 0.0

# ──────────────────────────────────────────────
#  Шаги персонажа и звуковая реакция
# ──────────────────────────────────────────────
var player_step_audio: AudioStreamPlayer3D = null
var player_step_streams: Array[AudioStream] = []
var step_stream_idx: int = 0
var step_cycle_t:      float = 0.0
var last_step_contact: int = 0

# ── Состояние ввода геймпада для курков и кнопок ──
var prev_joy_rt: bool = false
var prev_joy_lt: bool = false
var prev_joy_a:  bool = false
var prev_joy_b:  bool = false
var prev_joy_y:  bool = false
var prev_joy_x:  bool = false
var prev_joy_rb: bool = false

func _ready() -> void:
	_build_player()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if GameManager:
		GameManager.graphics_quality_changed.connect(_on_graphics_quality_changed)
		_on_graphics_quality_changed(GameManager.graphics_quality)

	_setup_input_map()

func _setup_input_map() -> void:
	# 1. Движение: W, A, S, D + Левый стик + D-Pad
	_register_action("move_forward", [
		_key_event(KEY_W),
		_joy_motion_event(JOY_AXIS_LEFT_Y, -1.0)
	])
	_register_action("move_back", [
		_key_event(KEY_S),
		_joy_motion_event(JOY_AXIS_LEFT_Y, 1.0)
	])
	_register_action("move_left", [
		_key_event(KEY_A),
		_joy_motion_event(JOY_AXIS_LEFT_X, -1.0)
	])
	_register_action("move_right", [
		_key_event(KEY_D),
		_joy_motion_event(JOY_AXIS_LEFT_X, 1.0)
	])

	# 2. Прыжок: Пробел + Кнопка A (XBox A / PS Cross)
	_register_action("jump", [
		_key_event(KEY_SPACE),
		_joy_btn_event(JOY_BUTTON_A)
	])

	# 3. Присед: Ctrl + C + Кнопка B (XBox B / PS Circle)
	_register_action("crouch", [
		_key_event(KEY_CTRL),
		_key_event(KEY_C),
		_joy_btn_event(JOY_BUTTON_B)
	])

	# 4. Бег: Shift + LB (ближний левый шифт)
	_register_action("sprint", [
		_key_event(KEY_SHIFT),
		_joy_btn_event(JOY_BUTTON_LEFT_SHOULDER)
	])

	# 5. Взаимодействие (ЛКМ / E / RT): двери, шкаф, записки, переключатели, механизмы
	_register_action("interact", [
		_mouse_btn_event(MOUSE_BUTTON_LEFT),
		_key_event(KEY_E),
		_joy_motion_event(JOY_AXIS_TRIGGER_RIGHT, 1.0)
	])

	# 6. Взять предмет (E / Y): подбор ключей, лома, батареек, предметов
	_register_action("pick_up", [
		_key_event(KEY_E),
		_joy_btn_event(JOY_BUTTON_Y)
	])

	# 7. Выброс предмета (ПКМ / LT): выбросить предмет из рук или рюкзака
	_register_action("drop_item", [
		_mouse_btn_event(MOUSE_BUTTON_RIGHT),
		_joy_motion_event(JOY_AXIS_TRIGGER_LEFT, 1.0)
	])

	# 8. Рюкзак-инвентарь: Tab + Кнопка X на геймпаде
	_register_action("toggle_backpack", [
		_key_event(KEY_TAB),
		_joy_btn_event(JOY_BUTTON_X)
	])

	# 9. Задержка дыхания (ТОЛЬКО В ШКАФУ): Q + Кнопка Y на геймпаде
	_register_action("hold_breath", [
		_key_event(KEY_Q),
		_joy_btn_event(JOY_BUTTON_Y)
	])

	# 10. Фонарик: F + D-Pad Up / L3
	_register_action("toggle_flashlight", [
		_key_event(KEY_F),
		_joy_btn_event(JOY_BUTTON_DPAD_UP),
		_joy_btn_event(JOY_BUTTON_LEFT_STICK)
	])

	# 11. Бросок отвлечения: G + D-Pad Down
	_register_action("throw_distraction", [
		_key_event(KEY_G),
		_joy_btn_event(JOY_BUTTON_DPAD_DOWN)
	])
	_register_action("throw_item", [
		_key_event(KEY_G),
		_joy_btn_event(JOY_BUTTON_DPAD_DOWN)
	])

	# 12. Сигнальная ракета: H + RB
	_register_action("use_road_flare", [
		_key_event(KEY_H),
		_joy_btn_event(JOY_BUTTON_RIGHT_SHOULDER)
	])

	# 13. Навигация хотбара / стрелки D-Pad (выбор предметов / слотов)
	_register_action("dpad_left", [_joy_btn_event(JOY_BUTTON_DPAD_LEFT), _key_event(KEY_LEFT)])
	_register_action("dpad_right", [_joy_btn_event(JOY_BUTTON_DPAD_RIGHT), _key_event(KEY_RIGHT)])

func _key_event(k: Key) -> InputEventKey:
	var ev = InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	return ev

func _mouse_btn_event(b: MouseButton) -> InputEventMouseButton:
	var ev = InputEventMouseButton.new()
	ev.button_index = b
	return ev

func _joy_btn_event(b: JoyButton) -> InputEventJoypadButton:
	var ev = InputEventJoypadButton.new()
	ev.button_index = b
	return ev

func _joy_motion_event(axis: JoyAxis, val: float) -> InputEventJoypadMotion:
	var ev = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = val
	return ev

func _register_action(action_name: String, events: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for ev in events:
		if ev:
			var has_ev = false
			for existing in InputMap.action_get_events(action_name):
				if existing is InputEventKey and ev is InputEventKey and (existing.keycode == ev.keycode or existing.physical_keycode == ev.physical_keycode):
					has_ev = true
					break
				elif existing is InputEventMouseButton and ev is InputEventMouseButton and existing.button_index == ev.button_index:
					has_ev = true
					break
				elif existing is InputEventJoypadButton and ev is InputEventJoypadButton and existing.button_index == ev.button_index:
					has_ev = true
					break
				elif existing is InputEventJoypadMotion and ev is InputEventJoypadMotion and existing.axis == ev.axis and signf(existing.axis_value) == signf(ev.axis_value):
					has_ev = true
					break
			if not has_ev:
				InputMap.action_add_event(action_name, ev)


func _build_player() -> void:
	# ── CharacterBody3D физика лестниц и скольжения ──────
	floor_snap_length     = 0.35        # Прилипает к полу на спуске (без микро-прыжков)
	floor_max_angle       = deg_to_rad(60.0) # Макс угол пола = 60° (гладкий подъем)
	floor_stop_on_slope   = false       # Не тормозить на наклонах
	floor_block_on_wall   = false       # Не застревать в стенах при подъёме
	floor_constant_speed  = true        # Постоянная скорость подъёма и спуска
	wall_min_slide_angle  = 0.0         # Скольжение по стенам под ЛЮБЫМ углом (без застревания!)
	motion_mode           = CharacterBody3D.MOTION_MODE_GROUNDED
	max_slides            = 8           # Плавный обход углов и дверных проемов
	# ── Collision ────────────────────────────
	col_node  = CollisionShape3D.new()
	col_shape = CapsuleShape3D.new()
	col_shape.height   = 1.75
	col_shape.radius   = 0.26          # 0.26 вместо 0.32: свободный проход в любые двери и вокруг мебели!
	col_node.shape     = col_shape
	col_node.position  = Vector3(0, 0.88, 0)
	add_child(col_node)

	# ── Head pivot ───────────────────────────
	head          = Node3D.new()
	head.name     = "Head"
	head.position = Vector3(0, 1.62, 0)
	add_child(head)

	# ── Camera ───────────────────────────────
	camera         = Camera3D.new()
	camera.name    = "Camera3D"
	camera.current = true
	camera.fov     = base_cam_fov
	head.add_child(camera)

	# ── 3D РУКИ И ФОНАРИК (Левая рука — фонарик [F], Правая — активный предмет) ──
	player_hands = PlayerHands.new()
	player_hands.name = "PlayerHands"
	camera.add_child(player_hands)
	player_hands.setup(camera, self)
	flashlight = player_hands.left_spot_light

	# ── Interact ray ─────────────────────────
	interact_ray                      = RayCast3D.new()
	interact_ray.name                 = "InteractRay"
	interact_ray.target_position      = Vector3(0, 0, -2.8)
	interact_ray.enabled              = true
	interact_ray.collide_with_areas   = true
	camera.add_child(interact_ray)

	# ── Физический захват и перенос предметов ──
	carry_pivot = Node3D.new()
	carry_pivot.name = "CarryPivot"
	carry_pivot.position = Vector3(0.28, -0.30, -0.55)
	camera.add_child(carry_pivot)
	_setup_highlight_material()

	# ── Breath system ────────────────────────
	breath_sys = Node.new()
	breath_sys.name = "BreathSystem"
	breath_sys.set_script(load("res://scripts/BreathSystem.gd"))
	add_child(breath_sys)

	# ── Heartbeat audio (индикатор приближения врага) ──────
	heart_audio = AudioStreamPlayer.new()
	var h_stream = load("res://assets/heart.mp3")
	if h_stream:
		if h_stream is AudioStreamMP3:
			(h_stream as AudioStreamMP3).loop = true
		heart_audio.stream = h_stream
		heart_audio.volume_db = -80.0
		heart_audio.autoplay = true
	add_child(heart_audio)

	# ── Звуковой индикатор приближения Деда (Лесоруба) ──
	ded_audio = AudioStreamPlayer.new()
	var d_stream = load("res://assets/ded.mp3")
	if d_stream:
		if d_stream is AudioStreamMP3:
			(d_stream as AudioStreamMP3).loop = true
		ded_audio.stream = d_stream
		ded_audio.volume_db = -80.0
		ded_audio.autoplay = true
	add_child(ded_audio)

	# ── Тело персонажа (2D-спрайты, видны в зеркале и при взгляде вниз) ──
	player_body = Node3D.new()
	player_body.name = "PlayerBody3D"
	player_body.set_script(load("res://scripts/PlayerBody3D.gd"))
	add_child(player_body)
	# setup() вызовем после добавления в дерево (через call_deferred)
	call_deferred("_setup_player_body")

	# ── Звук шагов персонажа (3D аудио) ──
	player_step_audio = AudioStreamPlayer3D.new()
	player_step_audio.name = "PlayerStepAudio"
	player_step_audio.unit_size = 3.5
	player_step_audio.max_distance = 25.0
	if ResourceLoader.exists("res://assets/audio/step_1.mp3"):
		player_step_streams.append(load("res://assets/audio/step_1.mp3"))
	if ResourceLoader.exists("res://assets/audio/step_2.mp3"):
		player_step_streams.append(load("res://assets/audio/step_2.mp3"))
	if player_step_streams.is_empty() and ResourceLoader.exists("res://assets/audio/player_step.wav"):
		player_step_streams.append(load("res://assets/audio/player_step.wav"))
	if not player_step_streams.is_empty():
		player_step_audio.stream = player_step_streams[0]
	add_child(player_step_audio)

	# ── Мягкий рассеянный свет под кроватью (адаптация глаз к темноте) ──
	under_bed_light = OmniLight3D.new()
	under_bed_light.name = "UnderBedLight"
	under_bed_light.light_color = Color(0.75, 0.80, 0.95)
	under_bed_light.light_energy = 0.55
	under_bed_light.omni_range = 5.0
	under_bed_light.omni_attenuation = 1.1
	under_bed_light.shadow_enabled = false
	under_bed_light.visible = false
	add_child(under_bed_light)

	# ── Мягкий неслепящий свет внутри шкафа (слабо видно щели и комнату) ──
	wardrobe_light = OmniLight3D.new()
	wardrobe_light.name = "WardrobeLight"
	wardrobe_light.light_color = Color(0.85, 0.78, 0.65)
	wardrobe_light.light_energy = 0.45
	wardrobe_light.omni_range = 3.5
	wardrobe_light.omni_attenuation = 1.1
	wardrobe_light.shadow_enabled = false
	wardrobe_light.visible = false
	add_child(wardrobe_light)

	# ── Объемные пылинки в воздухе (эффект кинематографичного реализма) ──
	_setup_volumetric_dust()

func _setup_volumetric_dust() -> void:
	# Отключено, чтобы не создавать артефактов летающих кубиков перед камерой
	pass

func _on_graphics_quality_changed(_quality: String) -> void:
	if dust_particles and is_instance_valid(dust_particles):
		dust_particles.visible = false

# ──────────────────────────────────────────────
#  Инициализация тела персонажа
# ──────────────────────────────────────────────
func _setup_player_body() -> void:
	if player_body and player_body.has_method("setup"):
		player_body.call("setup", self, camera)
	if GameManager and not GameManager.active_item_changed.is_connected(_on_active_item_changed):
		GameManager.active_item_changed.connect(_on_active_item_changed)

func _on_active_item_changed(_idx: int, _item_data: Dictionary) -> void:
	# Если в руках был застрявший физический предмет (старый ключ/лом в carry_pivot), гарантированно убираем его!
	if held_object != null and is_instance_valid(held_object):
		var ht = str(held_object.get_meta("item_type", "")).to_lower()
		if "key" in ht or "crowbar" in ht or "battery" in ht or "fuse" in ht or "bottle" in ht:
			var obj = held_object
			held_object = null
			if is_instance_valid(obj):
				if obj.get_parent() == carry_pivot:
					carry_pivot.remove_child(obj)
				obj.queue_free()
	if carry_pivot:
		for ch in carry_pivot.get_children():
			var cht = str(ch.get_meta("item_type", "")).to_lower()
			if "key" in cht or "crowbar" in cht or "battery" in cht or "fuse" in cht or "bottle" in cht or ch.name.to_lower().begins_with("key"):
				carry_pivot.remove_child(ch)
				ch.queue_free()


# ──────────────────────────────────────────────
#  Ввод мыши (с ограничением угла в укрытии)
# ──────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if is_dead or is_in_cutscene or GameManager.is_reading_note:
		return

	# [Tab / X / Геймпад X] — Открыть / закрыть рюкзак-инвентарь
	if event.is_action_pressed("toggle_backpack"):
		GameManager.toggle_backpack()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_X:
			GameManager.toggle_backpack()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_ESCAPE and GameManager.is_backpack_open:
			GameManager.close_backpack()
			get_viewport().set_input_as_handled()
			return

		elif event.keycode == KEY_C and is_peeking_keyhole:
			exit_keyhole_peek()
			get_viewport().set_input_as_handled()
			return

		elif not GameManager.is_backpack_open and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var slot_idx = event.keycode - KEY_1
			_select_quick_slot(slot_idx)
			get_viewport().set_input_as_handled()
			return

		elif not GameManager.is_backpack_open and (event.keycode == KEY_0 or event.keycode == KEY_APOSTROPHE):
			_select_quick_slot(-1)
			get_viewport().set_input_as_handled()
			return

	if event is InputEventJoypadButton and event.pressed:
		GameManager.is_gamepad = true
		if event.button_index == JOY_BUTTON_X:
			GameManager.toggle_backpack()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index in [JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK] and GameManager.is_backpack_open:
			GameManager.close_backpack()
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_DPAD_UP:
			flashlight_on = not flashlight_on
			if player_hands:
				player_hands.set_flashlight_state(flashlight_on, 1.0 if flashlight_on else 0.0)
			elif flashlight:
				flashlight.visible = flashlight_on
			GameManager.emit_signal("flashlight_toggled", flashlight_on)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == JOY_BUTTON_DPAD_DOWN:
			_throw_distraction()
			get_viewport().set_input_as_handled()
			return

	if GameManager.is_backpack_open:
		return

	# Колесико мыши: если смотрим на дверь — скрытно регулируем щель приоткрывания!
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var inter = _get_interactable()
			var door_target = _find_door_in_hierarchy(inter)
			if door_target and not is_hiding and not is_peeking_keyhole:
				var step = 12.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -12.0
				door_target.call("stealth_peek_adjust", step, self)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_cycle_quick_slot(-1)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_cycle_quick_slot(1)
				get_viewport().set_input_as_handled()
				return

	if event is InputEventMouseMotion:
		mouse_input_raw = event.relative
		if is_peeking_keyhole:
			# Ограниченный обзор сквозь замочную скважину
			head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY * GameManager.mouse_sensitivity * 0.5)
			head.rotation.y = clamp(head.rotation.y, keyhole_base_yaw - deg_to_rad(32.0), keyhole_base_yaw + deg_to_rad(32.0))
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY * GameManager.mouse_sensitivity * 0.5)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-16.0), deg_to_rad(16.0))
			return
		elif is_hiding:
			if hiding_type == "wardrobe":
				# Свободный горизонтальный обзор сквозь щели шкафа: только влево-вправо, верх/низ убран!
				head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY * GameManager.mouse_sensitivity)
				head.rotation.y = clamp(head.rotation.y, deg_to_rad(-75), deg_to_rad(75))
				head.rotation.x = 0.0
			elif hiding_type == "bed":
				# Обзор из-под кровати: строго влево-вправо, без верх/низ!
				head.rotate_y(-event.relative.x * MOUSE_SENSITIVITY * GameManager.mouse_sensitivity)
				head.rotation.y = clamp(head.rotation.y, deg_to_rad(-80), deg_to_rad(80))
				head.rotation.x = 0.0
		else:
			rotate_y(-event.relative.x * MOUSE_SENSITIVITY * GameManager.mouse_sensitivity)
			head.rotate_x(-event.relative.y * MOUSE_SENSITIVITY * GameManager.mouse_sensitivity)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))


# ──────────────────────────────────────────────
#  Физический цикл
# ──────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead or is_in_cutscene:
		velocity = Vector3.ZERO
		return
	auto_jump_cooldown = maxf(0.0, auto_jump_cooldown - delta)

	# ── Сэмплирование аналоговых курков и кнопок геймпада ──
	var joy_rt_axis: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_RIGHT)
	var joy_lt_axis: float = Input.get_joy_axis(0, JOY_AXIS_TRIGGER_LEFT)
	var rt_is_down: bool = joy_rt_axis > 0.35
	var lt_is_down: bool = joy_lt_axis > 0.35
	var rt_just_pressed: bool = rt_is_down and not prev_joy_rt
	var lt_just_pressed: bool = lt_is_down and not prev_joy_lt
	prev_joy_rt = rt_is_down
	prev_joy_lt = lt_is_down

	var joy_a_down: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_A)
	var joy_a_just_pressed: bool = joy_a_down and not prev_joy_a
	prev_joy_a = joy_a_down

	var joy_y_down: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	var joy_y_just_pressed: bool = joy_y_down and not prev_joy_y
	prev_joy_y = joy_y_down

	var joy_x_down: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_X)
	var joy_x_just_pressed: bool = joy_x_down and not prev_joy_x
	prev_joy_x = joy_x_down

	var joy_lb_down: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(0, JOY_BUTTON_LEFT_STICK)
	var joy_b_down: bool  = Input.is_joy_button_pressed(0, JOY_BUTTON_B)
	var joy_rb_down: bool = Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)
	var joy_rb_just_pressed: bool = joy_rb_down and not prev_joy_rb
	prev_joy_rb = joy_rb_down

	if rt_is_down or lt_is_down or joy_a_down or joy_b_down or joy_x_down or joy_y_down or joy_lb_down or joy_rb_down:
		GameManager.is_gamepad = true

	if joy_x_just_pressed:
		GameManager.toggle_backpack()

	if GameManager.is_reading_note:
		velocity = Vector3.ZERO
		move_and_slide()
		if Input.is_action_just_pressed("ui_cancel") or Input.is_action_just_pressed("interact") or rt_just_pressed or joy_b_down or joy_a_just_pressed:
			GameManager.close_note()
		return

	if GameManager.is_backpack_open:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	# ── Обзор правым стиком геймпада (Камера) ──
	var joy_look_x = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var joy_look_y = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(joy_look_x) > 0.15 or absf(joy_look_y) > 0.15:
		GameManager.is_gamepad = true
		var deadzone = 0.15
		var sign_x = signf(joy_look_x)
		var sign_y = signf(joy_look_y)
		var norm_x = maxf(0.0, (absf(joy_look_x) - deadzone) / (1.0 - deadzone))
		var norm_y = maxf(0.0, (absf(joy_look_y) - deadzone) / (1.0 - deadzone))
		var input_x = pow(norm_x, 1.5) * sign_x
		var input_y = pow(norm_y, 1.5) * sign_y
		var look_speed = 3.2

		if is_peeking_keyhole:
			head.rotate_y(-input_x * look_speed * 0.5 * delta)
			head.rotation.y = clamp(head.rotation.y, keyhole_base_yaw - deg_to_rad(32.0), keyhole_base_yaw + deg_to_rad(32.0))
			head.rotate_x(-input_y * look_speed * 0.5 * delta)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-16.0), deg_to_rad(16.0))
		elif is_hiding:
			if hiding_type == "wardrobe":
				head.rotate_y(-input_x * look_speed * delta)
				head.rotation.y = clamp(head.rotation.y, deg_to_rad(-75), deg_to_rad(75))
				head.rotation.x = 0.0
			elif hiding_type == "bed":
				# Обзор из-под кровати: строго влево-вправо, без верх/низ!
				head.rotate_y(-input_x * look_speed * delta)
				head.rotation.y = clamp(head.rotation.y, deg_to_rad(-80), deg_to_rad(80))
				head.rotation.x = 0.0
		else:
			rotate_y(-input_x * look_speed * delta)
			head.rotate_x(-input_y * look_speed * delta)
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-82), deg_to_rad(82))

	# ── Noclip режим свободного полета сквозь стены ──
	if GameManager.is_noclip:
		if col_node:
			col_node.disabled = true
		var input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var cam_basis = camera.global_transform.basis
		var fly_dir = (cam_basis * Vector3(input.x, 0, input.y)).normalized()
		var fly_up = 0.0
		if Input.is_key_pressed(KEY_SPACE):
			fly_up += 1.0
		if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_SHIFT):
			fly_up -= 1.0
		var noclip_speed = 14.0 * GameManager.speed_multiplier
		if fly_dir.length() > 0.01 or fly_up != 0.0:
			var move_v = (fly_dir + Vector3(0, fly_up, 0)).normalized() * noclip_speed
			global_position += move_v * delta
		velocity = Vector3.ZERO
		_update_hover_hint()
		_update_flashlight(delta)
		return
	elif col_node and col_node.disabled and not is_hiding:
		col_node.disabled = false

	# ── Подглядывание в замочную скважину ─────
	if is_peeking_keyhole:
		velocity = Vector3.ZERO
		move_and_slide()

		var move_in = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
		if move_in.length_squared() > 0.04 or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("ui_cancel"):
			exit_keyhole_peek()
		elif peeking_door_ref and (not is_instance_valid(peeking_door_ref) or peeking_door_ref.get("is_open") == true):
			exit_keyhole_peek()

		_update_hover_hint()
		_update_flashlight(delta)
		_update_heartbeat(delta)
		return

	# ── В укрытии (шкаф / кровать) ────────────
	if is_hiding:
		velocity = Vector3.ZERO
		# Дыхательное покачивание в укрытии (замирает при Q)
		var b_y = 0.0
		if breath_sys and not breath_sys.call("is_breath_held"):
			breath_sway_t += delta * 1.5
			b_y = sin(breath_sway_t) * 0.003
		camera.position.y = lerp(camera.position.y, b_y, delta * 8.0)
		camera.position.x = lerp(camera.position.x, 0.0, delta * 8.0)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 8.0)
		if hiding_type in ["wardrobe", "bed"]:
			head.rotation.x = 0.0
			camera.rotation.x = 0.0

		if Input.is_action_just_pressed("interact") or rt_just_pressed:
			exit_hiding()

		_update_hover_hint()
		_update_flashlight(delta)
		_update_heartbeat(delta)

		if Input.is_action_just_pressed("ui_cancel"):
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	var on_floor_now := is_on_floor()

	# ── Гравитация и прыжок ───────────────────
	if not on_floor_now:
		velocity.y -= GRAVITY * delta
		fall_velocity_saved = velocity.y
	else:
		if was_on_floor == false:
			# Приземление с живым сотрясением камеры в зависимости от высоты падения
			var impact_intensity: float = clampf(abs(fall_velocity_saved) / 9.5, 0.15, 1.2)
			cam_land_spring = -0.065 * impact_intensity
			cam_land_pitch = deg_to_rad(2.6) * impact_intensity
			if impact_intensity > 0.45:
				_play_player_step(false, false)
		fall_velocity_saved = 0.0
		if velocity.y < 0.0:
			velocity.y = -0.1

		var wants_jump = Input.is_action_just_pressed("jump") or joy_a_just_pressed
		if wants_jump and not is_crouching:
			if stamina >= 8.0 and not is_exhausted:
				velocity.y = JUMP_VELOCITY
				stamina = max(0.0, stamina - stamina_drain_jump)
				stamina_delay_timer = stamina_recover_delay
				cam_land_pitch = deg_to_rad(-1.6) # Легкий толчок камеры вверх на взлете
				if stamina <= 0.0:
					is_exhausted = true
			elif stamina < 8.0 or is_exhausted:
				velocity.y = JUMP_VELOCITY * 0.55
				cam_land_pitch = deg_to_rad(-0.8)

	was_on_floor = on_floor_now

	# ── Ползание / Присед (Ctrl / C / Gamepad B) ──────────────
	is_crouching = Input.is_action_pressed("crouch") or joy_b_down
	var target_cap_h  := 1.0  if is_crouching else 1.75
	var target_head_y := 0.88 if is_crouching else 1.62
	col_shape.height    = lerp(col_shape.height,    target_cap_h,  delta * 8.0)
	col_node.position.y = col_shape.height * 0.5 + 0.005
	head.position.y     = lerp(head.position.y,     target_head_y, delta * 8.0)

	# ── Движение с органичной инерцией (WASD + Левый стик) ───────
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var joy_lx = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var joy_ly = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(joy_lx) > 0.15 or absf(joy_ly) > 0.15:
		GameManager.is_gamepad = true
		var deadzone = 0.15
		var norm_x = signf(joy_lx) * maxf(0.0, (absf(joy_lx) - deadzone) / (1.0 - deadzone))
		var norm_y = signf(joy_ly) * maxf(0.0, (absf(joy_ly) - deadzone) / (1.0 - deadzone))
		var joy_vec = Vector2(norm_x, norm_y)
		if joy_vec.length() > input.length():
			input = joy_vec

	var dir: Vector3   = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var is_moving: bool = dir.length_squared() > 0.001

	# Бег (Shift / LB левый ближний шифт / L3)
	var wants_sprint: bool = (Input.is_action_pressed("sprint") or joy_lb_down) and not is_crouching and is_moving and on_floor_now
	var can_sprint: bool   = wants_sprint and not is_exhausted and stamina > 0.0
	is_sprinting = can_sprint

	var cur_speed: float
	if is_crouching:
		cur_speed = WALK_SPEED * 0.55
	elif can_sprint:
		cur_speed = SPRINT_SPEED
		stamina = max(0.0, stamina - stamina_drain_sprint * delta)
		stamina_delay_timer = stamina_recover_delay
		if stamina <= 0.0:
			stamina = 0.0
			is_exhausted = true
	else:
		if is_exhausted:
			cur_speed = WALK_SPEED * 0.85
		else:
			var analog_scale = clampf(input.length(), 0.45, 1.0)
			cur_speed = WALK_SPEED * analog_scale

	cur_speed *= GameManager.speed_multiplier

	# ── Восстановление выносливости ──────────
	if not can_sprint:
		if stamina_delay_timer > 0.0:
			stamina_delay_timer -= delta
		else:
			var recovery_mult: float = 1.0
			if not is_moving:
				recovery_mult = 1.35
			if is_crouching:
				recovery_mult = 1.6
			stamina = min(max_stamina, stamina + stamina_recovery_rate * recovery_mult * delta)
			if is_exhausted and stamina >= 22.0:
				is_exhausted = false

	# Сообщаем об обновлении выносливости
	GameManager.emit_signal("stamina_changed", stamina, max_stamina, is_exhausted)

	# Плавный набор скорости и торможение (Organic acceleration)
	var target_vel: Vector3 = dir * cur_speed
	var accel: float = 14.0 if on_floor_now else 6.5
	var deaccel: float = 13.0 if on_floor_now else 3.5

	if is_moving:
		velocity.x = lerpf(velocity.x, target_vel.x, delta * accel)
		velocity.z = lerpf(velocity.z, target_vel.z, delta * accel)
		# Step-assist: преодоление дверных порогов и ступеней без спотыканий
		if on_floor_now:
			_try_step_up(dir, delta)
	else:
		velocity.x = lerpf(velocity.x, 0.0, delta * deaccel)
		velocity.z = lerpf(velocity.z, 0.0, delta * deaccel)

	move_and_slide()

	# ── Живая динамическая камера (Organic Head Bob, Lean & Impact) ──
	# 1. Динамический угол обзора (Sprint FOV Zoom)
	var target_fov: float = base_cam_fov
	if is_sprinting:
		target_fov = base_cam_fov + 7.5
	elif is_crouching:
		target_fov = base_cam_fov - 3.0
	camera.fov = lerpf(camera.fov, target_fov, delta * 5.0)

	# 2. Наклон при стрейфе (A/D) и вращении мыши (Strafe Lean & Mouse Bank)
	var target_strafe_tilt: float = -input.x * (0.028 if is_sprinting else 0.018)
	mouse_vel_smooth = lerpf(mouse_vel_smooth, mouse_input_raw.x, delta * 10.0)
	mouse_input_raw = Vector2.ZERO
	var target_mouse_bank: float = clampf(-mouse_vel_smooth * 0.00035, -0.018, 0.018)
	strafe_tilt = lerpf(strafe_tilt, target_strafe_tilt + target_mouse_bank, delta * 8.0)

	# 3. Восстановление пружины приземления и сотрясения
	cam_land_spring = lerpf(cam_land_spring, 0.0, delta * 8.5)
	cam_land_pitch = lerpf(cam_land_pitch, 0.0, delta * 7.5)
	cam_dip = lerpf(cam_dip, 0.0, delta * 12.0)

	# 4. Тряска камеры при ходьбе и дыхание
	var h_speed: float = Vector2(velocity.x, velocity.z).length()
	if on_floor_now and is_moving and h_speed > 0.25:
		var bob_speed: float = 14.5 if is_sprinting else (7.2 if is_crouching else 10.2)
		bob_t += delta * bob_speed

		# Двухгармоничный покач: y опускается на каждый шаг
		var amp_x: float = 0.022 if is_sprinting else (0.008 if is_crouching else 0.013)
		var amp_y: float = 0.038 if is_sprinting else (0.012 if is_crouching else 0.018)
		var amp_roll: float = 0.016 if is_sprinting else (0.006 if is_crouching else 0.009)
		var amp_pitch: float = 0.008 if is_sprinting else 0.004

		var target_x: float = cos(bob_t) * amp_x
		var target_y: float = -abs(sin(bob_t)) * amp_y + cam_land_spring - cam_dip
		var target_roll: float = -cos(bob_t) * amp_roll + strafe_tilt
		var target_cam_pitch: float = -abs(sin(bob_t)) * amp_pitch + cam_land_pitch

		camera.position.x = lerpf(camera.position.x, target_x, delta * 14.0)
		camera.position.y = lerpf(camera.position.y, target_y, delta * 14.0)
		camera.rotation.z = lerpf(camera.rotation.z, target_roll, delta * 12.0)
		camera.rotation.x = lerpf(camera.rotation.x, target_cam_pitch, delta * 12.0)
	else:
		# Покой: возврат крена и естественное живое дыхание
		var target_roll: float = strafe_tilt
		camera.position.x = lerpf(camera.position.x, 0.0, delta * 7.0)
		camera.rotation.z = lerpf(camera.rotation.z, target_roll, delta * 7.0)
		camera.rotation.x = lerpf(camera.rotation.x, cam_land_pitch, delta * 8.0)

		if breath_sys and breath_sys.call("is_breath_held"):
			camera.position.y = lerpf(camera.position.y, cam_land_spring, delta * 10.0)
		else:
			var breath_freq: float = 2.8 if is_exhausted else (3.5 if heart_target_vol > -25.0 else 1.6)
			var breath_amp: float = 0.010 if is_exhausted else 0.005
			breath_sway_t += delta * breath_freq
			var breath_y: float = sin(breath_sway_t) * breath_amp + cam_land_spring
			camera.position.y = lerpf(camera.position.y, breath_y, delta * 6.0)

	# ── Звуки шагов и шум перемещения ─────────
	var h_vel: float = Vector2(velocity.x, velocity.z).length()
	var is_moving_on_floor: bool = on_floor_now and h_vel > 0.3 and dir.length() > 0.01
	if is_moving_on_floor:
		var step_freq: float = 13.0 if is_sprinting else (7.0 if is_crouching else 9.5)
		step_cycle_t += delta * step_freq
		var step_phase: int = int(step_cycle_t / PI)
		if step_phase != last_step_contact:
			last_step_contact = step_phase
			cam_dip = 0.012 if is_sprinting else 0.006 # Микро-толчок шага в камеру
			_play_player_step(is_sprinting, is_crouching)
	else:
		step_cycle_t = 0.0

	# ── Физический перенос и сброс предмета ──
	# Выбрасывание происходит СТРОГО на ПКМ / LT!
	# ЛКМ и RT — это ВСЕГДА ВЗАИМОДЕЙСТВИЕ, НИ В КОЕМ СЛУЧАЕ НЕ ВЫБРАСЫВАЮТ!
	var wants_drop = Input.is_action_just_pressed("drop_item") or lt_just_pressed
	if held_object != null and is_instance_valid(held_object):
		# ПКМ / LT — Выброс удерживаемого предмета на пол
		if wants_drop:
			_drop_held_object()
	else:
		# ПКМ / LT — Выброс активного предмета из рюкзака на пол
		if wants_drop:
			if not GameManager.is_backpack_open and GameManager.active_item_index != -1:
				GameManager.drop_active_item()

		# Клавиша [G] / D-Pad Down — Бросок отвлекающего предмета (бутылка)
		if Input.is_action_just_pressed("throw_distraction"):
			_throw_distraction()

	# ── Автоприцел и обнаружение предметов перед игроком ──
	_update_nearby_interactables(delta)

	# D-Pad Left / Right (стрелки) — выбор предмета из нескольких рядом, либо смена слота рюкзака
	var has_multi_interactables: bool = nearby_interactables.size() > 1
	if Input.is_action_just_pressed("dpad_left"):
		if has_multi_interactables:
			_cycle_interactable_target(-1)
		else:
			_cycle_backpack_slot(-1)
	elif Input.is_action_just_pressed("dpad_right"):
		if has_multi_interactables:
			_cycle_interactable_target(1)
		else:
			_cycle_backpack_slot(1)

	if Input.is_action_just_pressed("use_road_flare"):
		_use_road_flare()

	# ── Фонарик [F] (на левой руке) ───────────
	if Input.is_action_just_pressed("toggle_flashlight"):
		flashlight_on = not flashlight_on
		if player_hands:
			player_hands.set_flashlight_state(flashlight_on, 1.0 if flashlight_on else 0.0)
		elif flashlight:
			flashlight.visible = flashlight_on
		GameManager.emit_signal("flashlight_toggled", flashlight_on)

	# ── Взаимодействие [ЛКМ / E / RT] (двери, шкафы, записки, рубильники) ──
	var is_interact_pressed: bool = (
		Input.is_action_just_pressed("interact") or
		rt_just_pressed
	)
	if is_interact_pressed:
		_try_interact()

	# ── Взять предмет [E / Y] (лом, ключи, батарейки, предохранители, предметы) ──
	var is_pickup_pressed: bool = (
		not is_hiding and not is_interact_pressed and (
			Input.is_action_just_pressed("pick_up") or
			joy_y_just_pressed
		)
	)
	if is_pickup_pressed:
		_try_pick_up()

	_update_hover_hint()
	_update_flashlight(delta)
	_update_heartbeat(delta)
	_update_player_body(delta)

	if Input.is_action_just_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Защита от падения в бездну
	if global_position.y < -30.0:
		velocity = Vector3.ZERO
		global_position = GameManager.player_spawn + Vector3(0, 0.5, 0)

func _cycle_backpack_slot(step: int) -> void:
	var items = GameManager.get_backpack_items()
	if items.is_empty():
		return
	var cur = GameManager.active_item_index
	if cur == -1:
		cur = 0 if step > 0 else items.size() - 1
	else:
		cur = posmod(cur + step, items.size())
	GameManager.set_active_backpack_slot(cur)

func reset_state() -> void:
	if is_peeking_keyhole:
		exit_keyhole_peek()
	if is_hiding:
		exit_hiding()
	is_dead = false
	is_hiding = false
	is_crouching = false
	velocity = Vector3.ZERO
	stamina = max_stamina
	is_exhausted = false
	stamina_delay_timer = 0.0
	if head:
		head.position = Vector3(0, 1.62, 0)
		head.rotation = Vector3.ZERO
	if camera:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		camera.fov = base_cam_fov
	if player_hands:
		player_hands.visible = true
	if col_node and col_shape:
		col_node.disabled = false
		col_shape.height = 1.75
		col_node.position = Vector3(0, 0.88, 0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.emit_signal("stamina_changed", stamina, max_stamina, is_exhausted)

# ──────────────────────────────────────────────
#  Step-Assist: Плавное преодоление порогов и ступеней (не застревать!)
# ──────────────────────────────────────────────
func _try_step_up(move_dir: Vector3, delta: float) -> void:
	if not is_on_floor() or is_crouching or is_hiding:
		return
	var flat_dir := Vector3(move_dir.x, 0.0, move_dir.z).normalized()
	if flat_dir.length_squared() < 0.01:
		return

	var space := get_world_3d().direct_space_state
	var my_rid := get_rid()
	var base_pos := global_position

	# 1. Проверяем нижний луч (уровень порога/голени: y +0.08)
	var low_from := base_pos + Vector3(0.0, 0.08, 0.0)
	var forward_dist := 0.36
	var low_to := low_from + flat_dir * forward_dist

	var query_low := PhysicsRayQueryParameters3D.create(low_from, low_to, 1, [my_rid])
	var hit_low := space.intersect_ray(query_low)

	if hit_low.is_empty():
		return

	# 2. На пути есть нижнее препятствие. Проверяем верхний луч (y +0.32)
	var step_max_h := 0.32
	var high_from := base_pos + Vector3(0.0, step_max_h, 0.0)
	var high_to := high_from + flat_dir * (forward_dist + 0.12)

	var query_high := PhysicsRayQueryParameters3D.create(high_from, high_to, 1, [my_rid])
	var hit_high := space.intersect_ray(query_high)

	# Если и на высоте 32см стена — это высокая стена/дверь, зашагнуть нельзя
	if not hit_high.is_empty():
		return

	# 3. Верх свободен! Ищем точную ступень лучом вниз
	var down_from := high_to
	var down_to := high_to - Vector3(0.0, step_max_h + 0.10, 0.0)

	var query_down := PhysicsRayQueryParameters3D.create(down_from, down_to, 1, [my_rid])
	var hit_down := space.intersect_ray(query_down)

	if not hit_down.is_empty() and hit_down.normal.y > 0.65:
		var step_h: float = hit_down.position.y - base_pos.y
		if step_h > 0.02 and step_h <= step_max_h:
			# Проверка высоты потолка
			var head_from := base_pos + Vector3(0.0, 1.70, 0.0)
			var head_to := head_from + flat_dir * forward_dist
			var query_head := PhysicsRayQueryParameters3D.create(head_from, head_to, 1, [my_rid])
			if space.intersect_ray(query_head).is_empty():
				# Плавный подъем на ступеньку без залипания
				global_position.y = lerpf(global_position.y, hit_down.position.y + 0.03, delta * 25.0)
				velocity.y = 0.0

# ──────────────────────────────────────────────
#  Быстрые слоты инвентаря [1]..[6] и колесико мыши
# ──────────────────────────────────────────────
func _select_quick_slot(slot_idx: int) -> void:
	if is_hiding or is_dead:
		return
	if held_object != null and is_instance_valid(held_object):
		_drop_held_object()
	GameManager.set_active_backpack_slot(slot_idx)
	if GameManager.ui_ref and GameManager.ui_ref.has_method("_flash_hotbar"):
		GameManager.ui_ref.call("_flash_hotbar")

func _cycle_quick_slot(step: int) -> void:
	if is_hiding or is_dead:
		return
	if held_object != null and is_instance_valid(held_object):
		_drop_held_object()

	var items: Array[Dictionary] = GameManager.get_backpack_items()
	var cur_idx: int = GameManager.active_item_index
	var total_slots: int = GameManager.MAX_BACKPACK_SLOTS

	var candidate: int = cur_idx + step
	if candidate < -1:
		candidate = total_slots - 1
	elif candidate >= total_slots:
		candidate = -1

	if candidate == -1:
		_select_quick_slot(-1)
		return

	if candidate < items.size() and items[candidate].get("id", "empty") != "empty":
		_select_quick_slot(candidate)
	else:
		var found = false
		for _i in range(total_slots):
			candidate = candidate + step
			if candidate < -1: candidate = total_slots - 1
			elif candidate >= total_slots: candidate = -1
			if candidate == -1:
				_select_quick_slot(-1)
				found = true
				break
			elif candidate < items.size() and items[candidate].get("id", "empty") != "empty":
				_select_quick_slot(candidate)
				found = true
				break
		if not found:
			_select_quick_slot(-1)


# ──────────────────────────────────────────────
#  Укрытия: Вход и Выход
# ──────────────────────────────────────────────
func enter_hiding(node: Node3D) -> void:
	if is_hiding:
		return
	if breath_sys and (breath_sys.get("exhale_active") == true or breath_sys.get("oxygen") <= 0.4):
		if GameManager.ui_ref:
			GameManager.ui_ref.call("show_hint", "Вы задыхаетесь! Нужно отдышаться перед тем, как прятаться!", 2.5)
		return
	is_hiding = true
	hiding_node = node
	hiding_type = str(node.get_meta("hiding_type", ""))
	if hiding_type == "":
		var itype = str(node.get_meta("item_type", "")).to_lower()
		if "bed" in itype or "bed" in node.name.to_lower():
			hiding_type = "bed"
		else:
			hiding_type = "wardrobe"
	unhidden_pos = global_position
	hiding_saved_camera_near = camera.near
	hiding_saved_head_position = head.position
	camera.near = 0.015
	if player_hands is Node3D:
		hiding_saved_hands_visible = player_hands.visible
		player_hands.hide()
	if player_body is Node3D:
		hiding_saved_body_visible = player_body.visible
		player_body.hide()
	if carry_pivot is Node3D:
		carry_pivot.visible = false

	velocity = Vector3.ZERO
	if col_node:
		col_node.disabled = true

	if hiding_type == "wardrobe":
		# Встаем у передней щели створок шкафа, глядя наружу в комнату
		var anchor = node.get_node_or_null("HideAnchor") as Node3D
		global_position = anchor.global_position if anchor else node.to_global(Vector3(0, 0.05, 0.18))
		hiding_base_yaw = node.global_rotation.y + PI
		rotation.y = hiding_base_yaw
		head.position = Vector3(0, 1.62, 0)
		head.rotation = Vector3.ZERO
		camera.position = Vector3.ZERO
		if under_bed_light:
			under_bed_light.visible = false
		if wardrobe_light:
			wardrobe_light.position = head.position
			wardrobe_light.visible = true
		if GameManager.ui_ref:
			GameManager.ui_ref.call("set_hiding_mode", "wardrobe")
	elif hiding_type == "bed":
		# Залезаем под край кровати прямо на уровне пола (НЕ под землю!)
		global_position = node.to_global(Vector3(0.55, 0.02, 0.0))
		hiding_base_yaw = node.global_rotation.y + deg_to_rad(90.0)
		rotation.y = hiding_base_yaw
		head.position = Vector3(0, 0.22, 0)
		head.rotation = Vector3.ZERO
		camera.position = Vector3.ZERO
		if wardrobe_light:
			wardrobe_light.visible = false
		if under_bed_light:
			under_bed_light.position = Vector3(0, 0.25, 0)
			under_bed_light.visible = true
		if GameManager.ui_ref:
			GameManager.ui_ref.call("set_hiding_mode", "bed")

func exit_hiding() -> void:
	if not is_hiding:
		return
	is_hiding = false
	if col_node:
		col_node.disabled = false

	if under_bed_light:
		under_bed_light.visible = false
	if wardrobe_light:
		wardrobe_light.visible = false

	if GameManager.has_method("set_monster_stare"):
		GameManager.call("set_monster_stare", false, "", false)

	global_position = unhidden_pos
	head.position = hiding_saved_head_position
	camera.near = hiding_saved_camera_near
	if player_hands is Node3D:
		player_hands.visible = hiding_saved_hands_visible
	if player_body is Node3D:
		player_body.visible = hiding_saved_body_visible
	if carry_pivot is Node3D:
		carry_pivot.visible = true
	head.rotation = Vector3.ZERO
	camera.position = Vector3.ZERO

	if GameManager.ui_ref:
		GameManager.ui_ref.call("set_hiding_mode", "")

	hiding_node = null
	hiding_type = ""

func force_eject_from_hiding() -> void:
	if not is_hiding:
		return
	var forward_dir = -global_transform.basis.z
	forward_dir.y = 0.0
	if forward_dir.length_squared() < 0.01:
		forward_dir = Vector3(0, 0, 1)
	else:
		forward_dir = forward_dir.normalized()
	exit_hiding()
	# Резкий физический импульс вываливания из укрытия
	velocity = forward_dir * 4.2 + Vector3.UP * 1.8
	apply_cough_camera_trauma(1.5, 0.08)
	if GameManager.ui_ref:
		GameManager.ui_ref.call("show_hint", "КИСЛОРОД ЗАКОНЧИЛСЯ! Вы с громким кашлем вывалились из укрытия!", 4.0)
		if GameManager.ui_ref.has_method("flash_fear"):
			GameManager.ui_ref.call("flash_fear", 0.85)

func apply_cough_camera_trauma(duration: float = 1.4, intensity: float = 0.08) -> void:
	var tw = create_tween()
	var steps = int(duration / 0.04)
	for i in range(steps):
		var frac = 1.0 - float(i) / float(steps)
		var mag = intensity * frac
		tw.tween_callback(func():
			if is_instance_valid(camera):
				camera.h_offset = randf_range(-mag, mag)
				camera.v_offset = randf_range(-mag * 0.7, mag * 0.7)
		)
		tw.tween_interval(0.04)
	tw.tween_callback(func():
		if is_instance_valid(camera):
			camera.h_offset = 0.0
			camera.v_offset = 0.0
	)


# ──────────────────────────────────────────────
#  Метание бутылки для отвлечения ИИ
# ──────────────────────────────────────────────
func _throw_distraction() -> void:
	if GameManager.throwables_count <= 0:
		return

	# Проверяем, что в правой руке:
	var active_id = GameManager.get_active_item_id()
	if active_id != "bottle":
		# Если в руках другой предмет (лом/ключ), переключаем на бутылку если есть
		for idx in range(GameManager.MAX_BACKPACK_SLOTS):
			var it = GameManager.get_backpack_items()[idx]
			if it.get("id", "") == "bottle":
				GameManager.set_active_backpack_slot(idx)
				break

	if player_hands and player_hands.is_throwing:
		return

	if not GameManager.use_throwable():
		return

	if player_hands:
		player_hands.play_throw_animation(func(): _spawn_thrown_bottle_projectile())
	else:
		_spawn_thrown_bottle_projectile()

func _use_road_flare() -> void:
	if is_hiding or is_dead:
		return
	if not GameManager.use_road_flare():
		return

	var flare = Node3D.new()
	flare.name = "BurningRoadFlare"
	var body_mesh = MeshInstance3D.new()
	var body = CylinderMesh.new()
	body.top_radius = 0.055
	body.bottom_radius = 0.075
	body.height = 0.46
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.55, 0.075, 0.035)
	body_mat.roughness = 0.75
	body.material = body_mat
	body_mesh.mesh = body
	body_mesh.rotation_degrees.z = 82.0
	body_mesh.position.y = 0.16
	flare.add_child(body_mesh)

	var ember = MeshInstance3D.new()
	var ember_mesh = SphereMesh.new()
	ember_mesh.radius = 0.10
	ember_mesh.height = 0.20
	var ember_mat = StandardMaterial3D.new()
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ember_mat.albedo_color = Color(1.0, 0.22, 0.045)
	ember_mat.emission_enabled = true
	ember_mat.emission = Color(1.0, 0.10, 0.025)
	ember_mat.emission_energy_multiplier = 3.0
	ember_mesh.material = ember_mat
	ember.mesh = ember_mesh
	ember.position = Vector3(0.04, 0.24, 0)
	flare.add_child(ember)

	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.12, 0.035)
	light.light_energy = 3.2
	light.omni_range = 8.0
	light.shadow_enabled = true
	flare.add_child(light)

	var flare_pos = global_position - camera.global_transform.basis.z * 1.4
	flare_pos.y = global_position.y + 0.12
	var scene_root = get_tree().current_scene if get_tree().current_scene else get_parent()
	scene_root.add_child(flare)
	flare.global_position = flare_pos
	GameManager.emit_noise(flare.global_position, 38.0, "road_flare")
	_schedule_flare_pulse(flare, 2)

	var lifetime = Timer.new()
	lifetime.wait_time = 13.0
	lifetime.one_shot = true
	flare.add_child(lifetime)
	lifetime.timeout.connect(flare.queue_free)
	lifetime.start()

func _schedule_flare_pulse(flare: Node3D, pulses_left: int) -> void:
	if pulses_left <= 0:
		return
	get_tree().create_timer(2.8).timeout.connect(func():
		if is_instance_valid(flare):
			GameManager.emit_noise(flare.global_position, 34.0, "road_flare")
			_schedule_flare_pulse(flare, pulses_left - 1)
	)

func _spawn_thrown_bottle_projectile() -> void:
	var proj = RigidBody3D.new()
	proj.name = "ThrownBottle"
	proj.collision_layer = 4
	proj.collision_mask = 1
	proj.contact_monitor = true
	proj.max_contacts_reported = 3
	proj.continuous_cd = true
	proj.mass = 0.65

	# Модель бутылки
	var mi = MeshInstance3D.new()
	var cm = CylinderMesh.new()
	cm.top_radius = 0.055
	cm.bottom_radius = 0.065
	cm.height = 0.28
	var b_mat = StandardMaterial3D.new()
	b_mat.albedo_color = Color(0.25, 0.48, 0.35, 0.85)
	b_mat.roughness = 0.15
	b_mat.metallic = 0.1
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cm.surface_set_material(0, b_mat)
	mi.mesh = cm
	proj.add_child(mi)

	var neck = MeshInstance3D.new()
	var nm = CylinderMesh.new()
	nm.top_radius = 0.022
	nm.bottom_radius = 0.025
	nm.height = 0.12
	nm.surface_set_material(0, b_mat)
	neck.mesh = nm
	neck.position = Vector3(0, 0.18, 0)
	proj.add_child(neck)

	var col = CollisionShape3D.new()
	var cap = CapsuleShape3D.new()
	cap.radius = 0.065
	cap.height = 0.38
	col.shape = cap
	proj.add_child(col)

	var spawn_pos = camera.global_position - camera.global_transform.basis.z * 0.45 + camera.global_transform.basis.x * 0.18
	proj.global_position = spawn_pos
	get_parent().add_child(proj)

	var throw_dir = -camera.global_transform.basis.z.normalized()
	var forward_force = throw_dir * 17.5 + Vector3(0, 3.4, 0)
	proj.linear_velocity = forward_force
	proj.angular_velocity = Vector3(randf_range(-10, 10), randf_range(-10, 10), randf_range(-10, 10))

	proj.body_entered.connect(func(_body: Node):
		_on_bottle_impact(proj)
	)

	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(proj):
			_on_bottle_impact(proj)
	)

func _on_bottle_impact(proj: RigidBody3D) -> void:
	if not is_instance_valid(proj):
		return
	var impact_pos = proj.global_position

	GameManager.emit_noise(impact_pos, 32.0, "bottle")

	var sfx = AudioStreamPlayer3D.new()
	sfx.global_position = impact_pos
	sfx.max_distance = 45.0
	sfx.unit_size = 8.0
	sfx.stream = _create_shatter_audio()
	sfx.autoplay = true
	get_parent().add_child(sfx)
	sfx.finished.connect(sfx.queue_free)

	for k in range(7):
		var shard = MeshInstance3D.new()
		var sm = BoxMesh.new()
		sm.size = Vector3(randf_range(0.03, 0.07), randf_range(0.01, 0.03), randf_range(0.03, 0.07))
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.65, 0.85, 0.75, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.surface_set_material(0, mat)
		shard.mesh = sm
		shard.global_position = impact_pos + Vector3(randf_range(-0.1, 0.1), randf_range(0.05, 0.2), randf_range(-0.1, 0.1))
		get_parent().add_child(shard)
		var t = create_tween()
		var rand_offset = Vector3(randf_range(-1.2, 1.2), randf_range(0.1, 0.8), randf_range(-1.2, 1.2))
		t.tween_property(shard, "global_position", shard.global_position + rand_offset, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(shard, "scale", Vector3.ZERO, 0.45)
		t.tween_callback(shard.queue_free)

	proj.queue_free()

func _create_shatter_audio() -> AudioStreamWAV:
	var sample_count = int(44100 * 0.45)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for idx in range(sample_count):
		var time = float(idx) / 44100.0
		var env = exp(-time * 13.0)
		var noise = (randf() * 2.0 - 1.0)
		var clink = sin(time * 6200.0) * 0.4 + sin(time * 3800.0) * 0.3 + sin(time * 8400.0) * 0.3
		var sample = clamp((noise * 0.65 + clink) * env, -1.0, 1.0)
		var val16 = int(sample * 32767.0)
		pcm.encode_s16(idx * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	return wav


# ──────────────────────────────────────────────
#  Сердцебиение: звук и пульс камеры
# ──────────────────────────────────────────────
func _update_heartbeat(delta: float) -> void:
	# ── 1. Сердцебиение: индикатор близости Скинвокера / Врага ──
	# Чем ближе враг — тем громче. При задержке дыхания — бьётся ещё быстрее!
	var en = GameManager.enemy_ref if GameManager else null
	if heart_audio:
		if is_instance_valid(en) and en is Node3D and en.is_inside_tree() and not is_dead:
			var dist_enemy: float = global_position.distance_to(en.global_position)
			var max_enemy_dist: float = 24.0
			var min_enemy_dist: float = 1.6
			if dist_enemy <= max_enemy_dist:
				var prox: float = clampf(1.0 - (dist_enemy - min_enemy_dist) / (max_enemy_dist - min_enemy_dist), 0.0, 1.0)
				var target_vol: float = lerpf(-42.0, 3.5, prox)
				var target_pitch: float = lerpf(0.92, 1.45, prox)

				# При задерживании дыхания сердце бьётся ещё быстрее!
				if is_breath_held():
					target_pitch += 0.55

				# При нехватке кислорода в лёгких пульс дополнительно учащается
				var oxy_ratio = get_oxygen_ratio()
				if oxy_ratio < 0.35:
					target_pitch += 0.25 * (1.0 - oxy_ratio / 0.35)

				heart_audio.volume_db = lerpf(heart_audio.volume_db, target_vol, delta * 4.0)
				heart_audio.pitch_scale = lerpf(heart_audio.pitch_scale, target_pitch, delta * 4.5)
				if not heart_audio.playing:
					heart_audio.play()

				# Тряска и пульсация камеры при максимальном приближении врага
				if prox > 0.40 and camera and is_instance_valid(camera):
					heart_pulse_t += delta * (3.5 * target_pitch)
					var thump = abs(sin(heart_pulse_t * PI)) * 0.012 * prox
					camera.position.y += thump * 0.25
			else:
				heart_audio.volume_db = lerpf(heart_audio.volume_db, -80.0, delta * 2.5)
		else:
			heart_audio.volume_db = lerpf(heart_audio.volume_db, -80.0, delta * 2.5)

	# ── 2. Тяжёлое дыхание: индикатор близости Деда (Лесоруба) ──
	# Чем ближе дед — тем громче хриплое дыхание!
	var lj = GameManager.lumberjack_ref if GameManager else null
	if ded_audio:
		if is_instance_valid(lj) and lj is Node3D and lj.is_inside_tree() and not is_dead:
			var dist_ded: float = global_position.distance_to(lj.global_position)
			var max_ded_dist: float = 26.0
			var min_ded_dist: float = 2.0
			if dist_ded <= max_ded_dist:
				var ded_prox: float = clampf(1.0 - (dist_ded - min_ded_dist) / (max_ded_dist - min_ded_dist), 0.0, 1.0)
				var target_ded_vol: float = lerpf(-44.0, 3.5, ded_prox)
				var target_ded_pitch: float = lerpf(0.95, 1.30, ded_prox)

				# Если дед в режиме погони или прицеливания — дыхание ещё более яростное
				var lj_state = lj.get("current_state")
				if lj_state in [2, 3, 4]: # CHASE, AIMING, SHOOT
					target_ded_vol += 2.0
					target_ded_pitch += 0.18

				ded_audio.volume_db = lerpf(ded_audio.volume_db, target_ded_vol, delta * 4.0)
				ded_audio.pitch_scale = lerpf(ded_audio.pitch_scale, target_ded_pitch, delta * 4.5)
				if not ded_audio.playing:
					ded_audio.play()
			else:
				ded_audio.volume_db = lerpf(ded_audio.volume_db, -80.0, delta * 2.5)
		else:
			ded_audio.volume_db = lerpf(ded_audio.volume_db, -80.0, delta * 2.5)

func _update_flashlight(_delta: float) -> void:
	# Батарейка фонарика бесконечная (по запросу пользователя)
	flash_battery = 100.0

	if not flashlight_on:
		if player_hands and player_hands.left_spot_light and player_hands.left_spot_light.visible:
			player_hands.set_flashlight_state(false, 0.0)
		elif flashlight and flashlight.visible:
			flashlight.visible = false
		return

	if player_hands:
		player_hands.set_flashlight_state(true, 1.0)
	elif flashlight:
		flashlight.visible = true
		flashlight.light_energy = flash_base_energy


# ──────────────────────────────────────────────
#  Взаимодействие
# ──────────────────────────────────────────────
func _try_interact() -> void:
	if is_hiding:
		exit_hiding()
		return

	if GameManager.is_reading_note:
		GameManager.close_note()
		return

	var inter_obj = _get_interactable()

	# 1. Проверяем укрытия (шкаф / кровать): в укрытие можно спрятаться ВСЕГДА, в том числе с предметом в руках!
	var hiding_target = _find_hiding_spot_in_hierarchy(inter_obj)
	if hiding_target:
		enter_hiding(hiding_target)
		return

	# 2. Если смотрим на дверь — приоритетно взаимодействуем (отпереть ключом / открыть)
	var door_target = _find_door_in_hierarchy(inter_obj)
	if not door_target and inter_obj == null:
		door_target = _find_nearby_facing_door(2.4)

	if door_target and door_target.has_method("interact"):
		door_target.call("interact", self)
		return

	# 3. Если в руках есть предмет, проверяем взаимодействие с объектом
	if held_object != null and is_instance_valid(held_object):
		if inter_obj:
			var handler = inter_obj
			for _p in range(4):
				if handler.has_method("interact"):
					break
				if handler.get_parent():
					handler = handler.get_parent()
				else:
					break
			if handler and handler.has_method("interact"):
				handler.call("interact", self)
				return
		# При взгляде в пустоту ничего не выбрасывает (выброс строго на ПКМ)
		return

	# 4. Взаимодействие с интерактивными объектами мира (выключатели, ящики мебели, записки, сейф, алтарь)
	if inter_obj:
		var handler = inter_obj
		for _p in range(4):
			if handler.has_method("interact"):
				break
			if handler.get_parent():
				handler = handler.get_parent()
			else:
				break
		if handler and handler.has_method("interact"):
			handler.call("interact", self)
			return

# ──────────────────────────────────────────────
#  Подбор предметов (E на ПК / Y на геймпаде)
# ──────────────────────────────────────────────
func _try_pick_up() -> void:
	if is_hiding or is_dead or is_peeking_keyhole:
		return
	if GameManager.is_reading_note or GameManager.is_backpack_open:
		return

	var inter_obj = _get_interactable()
	if not inter_obj or not is_instance_valid(inter_obj):
		return

	# ЗАЩИТА ДВЕРЕЙ: Если смотрим на дверь — открываем / закрываем её, НИ В КОЕМ СЛУЧАЕ НЕ УДАЛЯЕМ И НЕ ПОДБИРАЕМ ЕЁ!
	var door_target = _find_door_in_hierarchy(inter_obj)
	if door_target != null:
		_try_interact()
		return

	var itype = str(inter_obj.get_meta("item_type", "")).to_lower()
	if itype == "" and inter_obj.get_parent():
		itype = str(inter_obj.get_parent().get_meta("item_type", "")).to_lower()

	# 1. Предохранители
	if itype in ["fuse_red", "fuse_blue", "fuse_green"]:
		var col = "red"
		if "blue" in itype: col = "blue"
		elif "green" in itype: col = "green"
		GameManager.pick_up_fuse(col)
		_play_pickup_sfx()
		inter_obj.queue_free()
		return

	# 2. Батарейка
	if itype == "battery" or itype == "item_battery":
		GameManager.pick_up_battery()
		_play_pickup_sfx()
		inter_obj.queue_free()
		return

	# 3. Ключи (по ID или цвету) — убираются в рюкзак, руки остаются свободными!
	# ВНИМАНИЕ: Проверяем строго key_id и типы ключей, НО НИКОГДА lock_id (lock_id принадлежит дверям и замкам!)
	var is_key = (itype == "key" or itype.begins_with("key") or itype.begins_with("item_key")) or (inter_obj.has_meta("key_id") and not inter_obj.has_meta("door_type") and not inter_obj.is_in_group("doors"))
	if is_key:
		var kid = 1
		if inter_obj.has_meta("key_id"):
			kid = int(inter_obj.get_meta("key_id"))
		elif inter_obj.get("key_id") != null and int(inter_obj.get("key_id")) > 0:
			kid = int(inter_obj.get("key_id"))
		elif itype.begins_with("key_"):
			var col = itype.trim_prefix("key_")
			match col:
				"gold": kid = 1
				"silver": kid = 2
				"emerald": kid = 3
				"ruby": kid = 4
				"sapphire": kid = 5
				"rusty": kid = 6
		GameManager.pick_up_id_key(kid)
		_play_pickup_sfx()
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
			var DoorScript = load("res://scripts/Door.gd")
			var th = DoorScript.get_lock_theme(kid)
			GameManager.ui_ref.call("show_hint", "%s ключ №%d убран в рюкзак [Tab / X]" % [th["name"], kid], 3.5)
		inter_obj.queue_free()
		return

	# 4. Лом (монтировка) — убирается в рюкзак
	if itype == "crowbar" or "crowbar" in itype:
		GameManager.has_crowbar = true
		GameManager.emit_signal("inventory_changed")
		_play_pickup_sfx()
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
			GameManager.ui_ref.call("show_hint", "Монтировка убрана в рюкзак [Tab / X]", 3.5)
		inter_obj.queue_free()
		return

	# 5. Бутылка для отвлечения — убирается в рюкзак
	if itype in ["bottle", "bottle_drink", "throwable"]:
		GameManager.add_throwables(1)
		_play_pickup_sfx()
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
			GameManager.ui_ref.call("show_hint", "Бутылка убрана в рюкзак [Tab / X]", 3.5)
		inter_obj.queue_free()
		return

	# 6. Сигнальная ракета — убирается в рюкзак
	if itype in ["road_flare", "flare"]:
		GameManager.add_road_flare(1)
		_play_pickup_sfx()
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
			GameManager.ui_ref.call("show_hint", "Сигнальная ракета убрана в рюкзак [Tab / X]", 3.5)
		inter_obj.queue_free()
		return

	# 7. Будильник — убирается в рюкзак
	if itype in ["alarm_clock", "prop_alarm_clock"]:
		GameManager.pick_up_prop("alarm_clock", "Будильник")
		_play_pickup_sfx()
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
			GameManager.ui_ref.call("show_hint", "Будильник убран в рюкзак [Tab / X]", 3.5)
		inter_obj.queue_free()
		return

	# 8. Пульт от телевизора — убирается в рюкзак
	if itype in ["tv_remote", "prop_tv_remote", "remote"]:
		GameManager.pick_up_prop("tv_remote", "Пульт ТВ")
		_play_pickup_sfx()
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
			GameManager.ui_ref.call("show_hint", "Пульт убран в рюкзак [Tab / X]", 3.5)
		inter_obj.queue_free()
		return

	# 9. Крупногабаритная мебель и физические предметы (стул) — переносятся в руках
	if held_object != null and is_instance_valid(held_object):
		return

	var is_pickable = inter_obj.get_meta("is_pickable", false)
	if not is_pickable and inter_obj.get_parent():
		is_pickable = inter_obj.get_parent().get_meta("is_pickable", false)

	if is_pickable or itype == "prop_chair":
		_pick_up_object(inter_obj)
		return

# ── Автоприцел и выбор предметов стрелками D-Pad ──
func _cycle_interactable_target(dir: int) -> void:
	if nearby_interactables.size() <= 1:
		return
	active_interactable_idx = (active_interactable_idx + dir + nearby_interactables.size()) % nearby_interactables.size()
	manual_selection_timer = 3.5
	_update_hover_hint()

func _update_nearby_interactables(delta: float) -> void:
	if manual_selection_timer > 0.0:
		manual_selection_timer -= delta

	if is_hiding or is_dead or is_peeking_keyhole or GameManager.is_reading_note:
		nearby_interactables.clear()
		active_interactable_idx = 0
		return

	if not is_inside_tree() or not get_world_3d():
		return

	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space:
		return

	var cam_pos: Vector3 = camera.global_position
	var cam_forward: Vector3 = -camera.global_transform.basis.z

	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.85
	query.shape = sphere
	query.transform = Transform3D(Basis(), cam_pos)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var hits: Array[Dictionary] = space.intersect_shape(query, 32)
	var found_map: Dictionary = {}

	for hit in hits:
		var c: Node = hit.get("collider")
		if not is_instance_valid(c):
			continue
		var root_cand: Node = null
		var cur: Node = c
		for _i in range(5):
			if cur == null:
				break
			if cur == self or cur == held_object:
				root_cand = null
				break
			if cur.has_meta("item_type") or cur.has_meta("is_pickable") or cur.has_meta("hiding_type") or cur.has_method("interact") or cur.has_method("get_interaction_hint") or cur.is_in_group("doors"):
				root_cand = cur
				break
			cur = cur.get_parent()

		if root_cand == null or root_cand == self or root_cand == held_object:
			continue

		var obj_pos: Vector3 = root_cand.global_position
		var to_obj: Vector3 = obj_pos - cam_pos
		var dist: float = to_obj.length()
		if dist < 0.1 or dist > 2.85:
			continue
		var dir: Vector3 = to_obj.normalized()
		var dot: float = cam_forward.dot(dir)
		# Конус обзора: ~130 градусов
		if dot < 0.35:
			continue

		# Быстрая проверка видимости
		var ray_q := PhysicsRayQueryParameters3D.create(cam_pos, obj_pos, 1, [get_rid()])
		ray_q.collide_with_areas = true
		var r_hit: Dictionary = space.intersect_ray(ray_q)
		if not r_hit.is_empty():
			var col: Node = r_hit.get("collider")
			if col != c and not root_cand.is_ancestor_of(col) and not col.is_ancestor_of(root_cand) and col != root_cand:
				continue

		found_map[root_cand.get_instance_id()] = root_cand

	if interact_ray and interact_ray.is_colliding():
		var direct_c: Node = interact_ray.get_collider()
		var direct_root: Node = null
		var cur2: Node = direct_c
		for _i in range(5):
			if cur2 == null: break
			if cur2.has_meta("item_type") or cur2.has_meta("is_pickable") or cur2.has_meta("hiding_type") or cur2.has_method("interact") or cur2.has_method("get_interaction_hint") or cur2.is_in_group("doors"):
				direct_root = cur2
				break
			cur2 = cur2.get_parent()
		if direct_root and direct_root != self and direct_root != held_object:
			found_map[direct_root.get_instance_id()] = direct_root

	var new_candidates: Array[Node] = []
	for k in found_map.keys():
		new_candidates.append(found_map[k])

	# Сортируем кандидатов слева-направо на экране камеры для естественного переключения стрелками
	var inv_cam: Transform3D = camera.global_transform.affine_inverse()
	new_candidates.sort_custom(func(a: Node, b: Node) -> bool:
		var pos_a: Vector3 = inv_cam * a.global_position
		var pos_b: Vector3 = inv_cam * b.global_position
		return pos_a.x < pos_b.x
	)

	var prev_selected: Node = null
	if active_interactable_idx >= 0 and active_interactable_idx < nearby_interactables.size():
		prev_selected = nearby_interactables[active_interactable_idx]

	nearby_interactables = new_candidates

	if nearby_interactables.is_empty():
		active_interactable_idx = 0
		return

	if manual_selection_timer > 0.0 and prev_selected != null and prev_selected in nearby_interactables:
		active_interactable_idx = nearby_interactables.find(prev_selected)
	else:
		# Автоприцел: приоритет прямому лучу, иначе объект ближе к центру экрана
		var direct_idx: int = -1
		if interact_ray and interact_ray.is_colliding():
			var direct_c: Node = interact_ray.get_collider()
			for i in range(nearby_interactables.size()):
				var n: Node = nearby_interactables[i]
				if n == direct_c or n.is_ancestor_of(direct_c) or (direct_c and direct_c.is_ancestor_of(n)):
					direct_idx = i
					break

		if direct_idx != -1:
			active_interactable_idx = direct_idx
		else:
			var best_idx: int = 0
			var best_score: float = -999.0
			for i in range(nearby_interactables.size()):
				var cand: Node = nearby_interactables[i]
				var to_c: Vector3 = (cand.global_position - cam_pos)
				var d_len: float = to_c.length()
				var d_dot: float = cam_forward.dot(to_c.normalized())
				var score: float = d_dot * 3.0 - (d_len / 3.0)
				if score > best_score:
					best_score = score
					best_idx = i
			active_interactable_idx = best_idx

	active_interactable_idx = clampi(active_interactable_idx, 0, nearby_interactables.size() - 1)

func _get_interactable() -> Node:
	if not nearby_interactables.is_empty() and active_interactable_idx >= 0 and active_interactable_idx < nearby_interactables.size():
		var sel: Node = nearby_interactables[active_interactable_idx]
		if is_instance_valid(sel):
			return sel

	if interact_ray and interact_ray.is_colliding():
		var c: Node = interact_ray.get_collider()
		for _i in range(5):
			if c == null:
				break
			if c.has_meta("item_type") or c.has_meta("hiding_type") or c.has_meta("is_pickable") or c.has_method("interact"):
				return c
			c = c.get_parent()

	return null

func _find_nearby_facing_door(max_dist: float = 2.4) -> Node:
	if not is_inside_tree():
		return null
	var doors = get_tree().get_nodes_in_group("doors")
	var best_door: Node = null
	var best_dot: float = 0.45
	var p_pos = global_position
	var look_dir = -camera.global_transform.basis.z
	look_dir.y = 0.0
	look_dir = look_dir.normalized()

	for d in doors:
		if not is_instance_valid(d):
			continue
		var ctrl = d.call("_door_controller") if d.has_method("_door_controller") else d
		var d_pos = ctrl.global_position
		var diff = d_pos - p_pos
		diff.y = 0.0
		var dist = diff.length()
		if dist <= max_dist:
			var dot = look_dir.dot(diff.normalized())
			if dot > best_dot:
				best_dot = dot
				best_door = ctrl
	return best_door

func _update_hover_hint() -> void:
	if not GameManager.ui_ref:
		return
	if is_hiding:
		var exit_hint = "[ЛКМ / RT]  Выйти из шкафа    [Зажмите Q / Y]  Задержать дыхание" if hiding_type == "wardrobe" else "[ЛКМ / RT]  Вылезти из-под кровати    [Зажмите Q / Y]  Задержать дыхание"
		GameManager.ui_ref.call("show_interact_hint", exit_hint)
		GameManager.ui_ref.call("update_escape_checklist", {})
		GameManager.ui_ref.call("set_crosshair_hover", false)
		_remove_highlight()
		return

	if is_peeking_keyhole:
		GameManager.ui_ref.call("show_interact_hint", "Замочная скважина    [ЛКМ / RT / WASD] Отойти")
		GameManager.ui_ref.call("update_escape_checklist", {})
		GameManager.ui_ref.call("set_crosshair_hover", false)
		_remove_highlight()
		return

	if GameManager.is_reading_note:
		GameManager.ui_ref.call("show_interact_hint", "[ЛКМ / RT / Esc]  Закрыть записку")
		GameManager.ui_ref.call("update_escape_checklist", {})
		GameManager.ui_ref.call("set_crosshair_hover", false)
		_remove_highlight()
		return

	# Если держим предмет в руках
	if held_object != null and is_instance_valid(held_object):
		_remove_highlight()
		var inter_obj = _get_interactable()
		var hiding_target = _find_hiding_spot_in_hierarchy(inter_obj)
		if hiding_target:
			var ht = str(hiding_target.get_meta("hiding_type", ""))
			if ht == "":
				ht = "bed" if ("bed" in hiding_target.name.to_lower() or "bed" in str(hiding_target.get_meta("item_type", "")).to_lower()) else "wardrobe"
			var h_text = "[ЛКМ / RT]  Спрятаться в шкафу" if ht == "wardrobe" else "[ЛКМ / RT]  Залезть под кровать"
			GameManager.ui_ref.call("show_interact_hint", "[ПКМ / LT] Выбросить    " + h_text)
			_apply_highlight(inter_obj)
			GameManager.ui_ref.call("set_crosshair_hover", true)
			return

		var h_type = get_held_item_type()
		var h_hint = ""
		match h_type:
			"alarm_clock", "prop_alarm_clock", "tv_remote", "prop_tv_remote", "remote", "prop_chair":
				h_hint = "[ПКМ / LT] Выбросить"
			"key", "key_gold", "key_silver", "key_rusty", "key_emerald", "item_key":
				var kid = 1
				if held_object.has_meta("key_id"):
					kid = int(held_object.get_meta("key_id"))
				elif held_object.get("key_id") != null and int(held_object.get("key_id")) > 0:
					kid = int(held_object.get("key_id"))
				h_hint = "[ПКМ / LT] Выбросить    Ключ №%d    [ЛКМ / RT] Отпереть дверь" % kid
			"crowbar":
				h_hint = "[ПКМ / LT] Выбросить    Лом    [ЛКМ / RT] Сорвать доски"
			_:
				h_hint = "[ПКМ / LT] Выбросить    [ЛКМ / RT] Использовать"

		inter_obj = _get_interactable()
		if inter_obj:
			var target_obj = inter_obj
			for _p in range(4):
				if target_obj.has_method("get_interaction_hint"):
					break
				if target_obj.get_parent():
					target_obj = target_obj.get_parent()
				else:
					break
			if target_obj.has_method("get_door_info"):
				var d_info = target_obj.call("get_door_info")
				GameManager.ui_ref.call("update_door_inspector", d_info)
			else:
				GameManager.ui_ref.call("update_door_inspector", {})
			if target_obj.has_method("get_interaction_hint"):
				h_hint += "   |   " + str(target_obj.call("get_interaction_hint"))
				_apply_highlight(inter_obj)
				GameManager.ui_ref.call("set_crosshair_hover", true)
			else:
				GameManager.ui_ref.call("set_crosshair_hover", false)
		else:
			GameManager.ui_ref.call("update_door_inspector", {})
			GameManager.ui_ref.call("set_crosshair_hover", false)

		GameManager.ui_ref.call("show_interact_hint", h_hint)
		return

	var inter = _get_interactable()
	if inter:
		_apply_highlight(inter)
		GameManager.ui_ref.call("set_crosshair_hover", true)

		var target_obj = inter
		for _p in range(4):
			if target_obj.has_method("get_interaction_hint") or target_obj.has_method("get_escape_checklist"):
				break
			if target_obj.get_parent():
				target_obj = target_obj.get_parent()
			else:
				break

		# Чек-лист двери побега и инспектор замков
		if target_obj.has_method("get_door_info"):
			var d_info = target_obj.call("get_door_info")
			GameManager.ui_ref.call("update_door_inspector", d_info)
			GameManager.ui_ref.call("update_escape_checklist", {})
		elif target_obj.has_method("get_escape_checklist"):
			var chk = target_obj.call("get_escape_checklist")
			GameManager.ui_ref.call("update_escape_checklist", chk)
			GameManager.ui_ref.call("update_door_inspector", {})
		else:
			GameManager.ui_ref.call("update_door_inspector", {})
			GameManager.ui_ref.call("update_escape_checklist", {})

		var multi_hint = ""
		if nearby_interactables.size() > 1:
			multi_hint = "    [◄ %d/%d ►]" % [active_interactable_idx + 1, nearby_interactables.size()]

		# Индивидуальная динамическая подсказка
		if target_obj.has_method("get_interaction_hint"):
			GameManager.ui_ref.call("show_interact_hint", str(target_obj.call("get_interaction_hint")) + multi_hint)
			return

		var h_spot = _find_hiding_spot_in_hierarchy(inter)
		if h_spot:
			var ht = str(h_spot.get_meta("hiding_type", ""))
			if ht == "":
				ht = "bed" if ("bed" in h_spot.name.to_lower() or "bed" in str(h_spot.get_meta("item_type", "")).to_lower()) else "wardrobe"
			var h_text = "[ЛКМ / RT]  Спрятаться в шкафу" if ht == "wardrobe" else "[ЛКМ / RT]  Залезть под кровать"
			GameManager.ui_ref.call("show_interact_hint", h_text + multi_hint)
			return

		var item_type = inter.get_meta("item_type") if inter.has_meta("item_type") else ""
		var hint := "[ЛКМ / RT] Взаимодействовать"
		if inter.has_meta("key_id") or item_type.begins_with("key") or item_type.begins_with("item_key"):
			var kid = 1
			if inter.has_meta("key_id"):
				kid = int(inter.get_meta("key_id"))
			elif inter.get("key_id") != null and int(inter.get("key_id")) > 0:
				kid = int(inter.get("key_id"))
			elif item_type.ends_with("silver"):
				kid = 2
			elif item_type.ends_with("emerald"):
				kid = 3
			elif item_type.ends_with("ruby"):
				kid = 4
			elif item_type.ends_with("sapphire"):
				kid = 5
			elif item_type.ends_with("rusty"):
				kid = 6
			var DoorScript = load("res://scripts/Door.gd")
			var th = DoorScript.get_lock_theme(kid)
			hint = "[E / Y]  Взять %s ключ №%d" % [th["name"], kid]
		else:
			match item_type:
				"crowbar":           hint = "[E / Y]  Взять лом"
				"door_hatch":        hint = ("[] Земной люк заперт снаружи" if (GameManager and GameManager.has_method("is_level_2") and GameManager.is_level_2()) else "[ЛКМ / RT]  Открыть / Закрыть люк")
				"door_metal":        hint = "[ЛКМ / RT]  Осмотреть дверь"
				"prop_chair":        hint = "[E / Y]  Поднять стул"
				"alarm_clock", "prop_alarm_clock": hint = "[E / Y]  Взять будильник"
				"tv_remote", "prop_tv_remote", "remote": hint = "[E / Y]  Взять пульт"
				"note_safe", "note_safe_code": hint = "[ЛКМ / RT]  Прочитать шифр"
				"bottle":            hint = "[E / Y]  Подобрать бутылку"
				"battery":           hint = "[E / Y]  Подобрать батарею"
				"road_flare":        hint = "[E / Y]  Подобрать сигнальную ракету"
				"fuse_red":          hint = "[E / Y]  Подобрать красный предохранитель"
				"fuse_blue":         hint = "[E / Y]  Подобрать синий предохранитель"
				"fuse_green":        hint = "[E / Y]  Подобрать зелёный предохранитель"
				"fusebox":           hint = "[ЛКМ / RT]  Электрощиток"
				"grandfather_clock": hint = "[ЛКМ / RT]  Осмотреть часы"
				"crt_tv":            hint = "[ЛКМ / RT]  Переключить телевизор"
				"occult_altar":      hint = "[ЛКМ / RT]  Осмотреть алтарь"
				"safe":              hint = "[ЛКМ / RT]  Открыть сейф"
				"note":              hint = "[ЛКМ / RT]  Читать записку"
				"light_switch":      hint = "[ЛКМ / RT]  Переключить свет"
				"door_electric":     hint = "[ЛКМ / RT]  Электро-замок"
				"door_simple":       hint = "[ЛКМ / RT]  Открыть / Закрыть дверь"
				"door":              hint = "[ЛКМ / RT]  Дверь выхода"
				"wardrobe":          hint = "[ЛКМ / RT]  Спрятаться в шкафу"
				"bed":               hint = "[ЛКМ / RT]  Залезть под кровать"
				"prop_nightstand", "nightstand": hint = "[ЛКМ / RT]  Открыть / Закрыть ящик"
				"prop_dresser", "dresser":       hint = "[ЛКМ / RT]  Открыть / Закрыть комод"
				"prop_cupboard", "cupboard":     hint = "[ЛКМ / RT]  Открыть / Закрыть шкафчик"
				"prop_basement_entrance", "basement_entrance": hint = ("[] Земной люк заперт снаружи" if (GameManager and GameManager.has_method("is_level_2") and GameManager.is_level_2()) else "[ЛКМ / RT]  Открыть / Закрыть подвал")
				_:
					var is_p = inter.get_meta("is_pickable", false)
					if not is_p and inter.get_parent():
						is_p = inter.get_parent().get_meta("is_pickable", false)
					if is_p:
						hint = "[E / Y]  Взять предмет"
					else:
						hint = "[ЛКМ / RT]  Взаимодействовать"
		GameManager.ui_ref.call("show_interact_hint", hint + multi_hint)
	else:
		_remove_highlight()
		GameManager.ui_ref.call("set_crosshair_hover", false)
		if GameManager.active_item_index != -1 and not GameManager.is_backpack_open:
			GameManager.ui_ref.call("show_interact_hint", "[ПКМ / LT]  Выбросить предмет на пол")
		else:
			GameManager.ui_ref.call("show_interact_hint", "")
		GameManager.ui_ref.call("update_escape_checklist", {})
		GameManager.ui_ref.call("update_door_inspector", {})

# ──────────────────────────────────────────────
#  Подбор, переноска и метание предметов
# ──────────────────────────────────────────────
func _pick_up_object(node: Node) -> void:
	if not node or not is_instance_valid(node):
		return
	if is_hiding:
		return

	# ЗАЩИТА ДВЕРЕЙ: Двери никогда нельзя переносить в руках или удалять!
	if _find_door_in_hierarchy(node) != null or node.is_in_group("doors") or node.has_meta("door_type") or str(node.get_meta("item_type", "")).begins_with("door"):
		_try_interact()
		return

	if held_object != null:
		_drop_held_object()

	_remove_highlight()

	var root_obj = node
	for _p in range(4):
		if root_obj.get_meta("is_pickable", false) or root_obj.has_meta("item_type"):
			break
		if root_obj.get_parent() and (root_obj.get_parent().get_meta("is_pickable", false) or root_obj.get_parent().has_meta("item_type")):
			root_obj = root_obj.get_parent()
		else:
			break

	var obj_type = str(root_obj.get_meta("item_type", "")).to_lower()
	var is_chair = (obj_type == "prop_chair")
	var is_key = (obj_type == "key" or obj_type.begins_with("key") or (root_obj.has_meta("key_id") and not root_obj.has_meta("door_type")))

	# Ключи, лом и карманные предметы никогда не привязываются к carry_pivot (руки свободны!)
	if is_key:
		var kid = 1
		if root_obj.has_meta("key_id"):
			kid = int(root_obj.get_meta("key_id"))
		elif root_obj.get("key_id") != null and int(root_obj.get("key_id")) > 0:
			kid = int(root_obj.get("key_id"))
		GameManager.pick_up_id_key(kid)
		_play_pickup_sfx()
		root_obj.queue_free()
		return
	elif obj_type == "crowbar" or "crowbar" in obj_type:
		GameManager.has_crowbar = true
		GameManager.emit_signal("inventory_changed")
		_play_pickup_sfx()
		root_obj.queue_free()
		return
	elif obj_type in ["bottle", "road_flare", "battery", "fuse_red", "fuse_blue", "fuse_green", "alarm_clock", "tv_remote"]:
		_try_pick_up()
		return

	if root_obj is CollisionObject3D:
		root_obj.collision_layer = 0
		root_obj.collision_mask = 0
	for ch in root_obj.find_children("*", "CollisionObject3D", true, false):
		ch.collision_layer = 0
		ch.collision_mask = 0

	if root_obj.get_parent():
		root_obj.get_parent().remove_child(root_obj)
	carry_pivot.add_child(root_obj)
	root_obj.position = Vector3.ZERO
	root_obj.rotation_degrees = Vector3.ZERO

	if not root_obj.has_meta("orig_scale"):
		root_obj.set_meta("orig_scale", root_obj.scale)

	if is_chair:
		carry_pivot.position = Vector3(0.0, -0.32, -1.05)
		root_obj.rotation_degrees = Vector3(10, 180, 0)
	else:
		carry_pivot.position = Vector3(0.26, -0.30, -0.65)
		root_obj.scale = Vector3(0.65, 0.65, 0.65)

	root_obj.set_meta("is_held", true)
	held_object = root_obj
	_play_pickup_sfx()

func _drop_held_object() -> void:
	if not held_object or not is_instance_valid(held_object):
		held_object = null
		return
	var drop_pos = global_position - camera.global_transform.basis.z * 0.95
	drop_pos.y = global_position.y + 0.15

	var obj = held_object
	held_object = null
	carry_pivot.remove_child(obj)
	get_tree().current_scene.add_child(obj)
	obj.global_position = drop_pos
	obj.rotation_degrees.x = 0
	obj.rotation_degrees.z = 0
	if obj.has_meta("orig_scale"):
		obj.scale = obj.get_meta("orig_scale")

	if obj is CollisionObject3D:
		obj.collision_layer = 1
	for ch in obj.find_children("*", "CollisionObject3D", true, false):
		ch.collision_layer = 1

	obj.set_meta("is_held", false)
	_play_pickup_sfx(0.85)

func _throw_held_object(power: float) -> void:
	if not held_object or not is_instance_valid(held_object):
		held_object = null
		throw_charge = 0.0
		is_charging_throw = false
		if GameManager.ui_ref:
			GameManager.ui_ref.call("update_throw_charge", 0.0)
		return

	var throw_speed = lerpf(5.0, 24.0, power)
	var throw_dir = (-camera.global_transform.basis.z + camera.global_transform.basis.y * (0.08 + 0.12 * power)).normalized()
	var spawn_pos = carry_pivot.global_position

	var obj_to_throw = held_object
	var obj_type = get_held_item_type()
	held_object = null
	throw_charge = 0.0
	is_charging_throw = false
	if GameManager.ui_ref:
		GameManager.ui_ref.call("update_throw_charge", 0.0)

	carry_pivot.remove_child(obj_to_throw)
	var scene_root = get_tree().current_scene
	scene_root.add_child(obj_to_throw)
	obj_to_throw.global_position = spawn_pos
	obj_to_throw.set_meta("is_held", false)
	if obj_to_throw.has_meta("orig_scale"):
		obj_to_throw.scale = obj_to_throw.get_meta("orig_scale")

	if obj_to_throw is CollisionObject3D:
		obj_to_throw.collision_layer = 1
	for ch in obj_to_throw.find_children("*", "CollisionObject3D", true, false):
		ch.collision_layer = 1

	var projectile = Node.new()
	projectile.name = "ThrownProjectile"
	scene_root.add_child(projectile)

	var p_vel = throw_dir * throw_speed
	var p_ang = Vector3(randf_range(-15, 15), randf_range(-15, 15), randf_range(-15, 15))

	var script_src = """
extends Node
var target_obj: Node3D = null
var vel: Vector3 = Vector3.ZERO
var ang_vel: Vector3 = Vector3.ZERO
var item_type: String = ""
var gravity: float = 14.0
var alive_time: float = 0.0
var has_impacted: bool = false

func _physics_process(delta: float) -> void:
	if not target_obj or not is_instance_valid(target_obj):
		queue_free()
		return
	alive_time += delta
	if alive_time > 8.0:
		queue_free()
		return
	vel.y -= gravity * delta
	target_obj.rotation_degrees += ang_vel * delta * 50.0

	var from_p = target_obj.global_position
	var to_p = from_p + vel * delta

	var space = target_obj.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_p, to_p)
	query.collision_mask = 1
	var hit = space.intersect_ray(query)

	if hit and not has_impacted:
		has_impacted = true
		target_obj.global_position = hit.position + hit.normal * 0.12
		vel = vel.bounce(hit.normal) * 0.35
		ang_vel *= 0.5
		_on_impact(hit.position)
		if vel.length() < 1.5:
			set_physics_process(false)
			queue_free()
	else:
		target_obj.global_position = to_p

func _on_impact(pos: Vector3) -> void:
	var gm = get_node_or_null("/root/GameManager")
	var noise_rad = 14.0
	match item_type:
		"prop_chair":
			noise_rad = 24.0
		"alarm_clock", "prop_alarm_clock":
			noise_rad = 28.0
			if target_obj.has_method("start_alarm"):
				target_obj.call("start_alarm")
		"tv_remote", "prop_tv_remote":
			noise_rad = 12.0
		_:
			noise_rad = 12.0

	if gm and gm.has_method("emit_noise"):
		gm.emit_noise(pos, noise_rad, "thrown_impact")

	var aud = AudioStreamPlayer3D.new()
	aud.position = pos
	aud.unit_size = 6.0
	aud.max_distance = 35.0
	target_obj.get_parent().add_child(aud)

	var sample_count = int(44100 * 0.28)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 18.0)
		var freq = 140.0 if item_type == "prop_chair" else 380.0
		var s = (sin(t * freq * TAU) * 0.6 + (randf() * 2.0 - 1.0) * 0.4) * env
		var val16 = int(clamp(s, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	aud.stream = wav
	aud.play()
	aud.finished.connect(aud.queue_free)
"""
	var p_script = GDScript.new()
	p_script.source_code = script_src
	p_script.reload()
	projectile.set_script(p_script)
	projectile.set("target_obj", obj_to_throw)
	projectile.set("vel", p_vel)
	projectile.set("ang_vel", p_ang)
	projectile.set("item_type", obj_type)

func _play_pickup_sfx(pitch: float = 1.0) -> void:
	var aud = AudioStreamPlayer.new()
	aud.volume_db = -8.0
	aud.pitch_scale = pitch
	add_child(aud)
	var sample_count = int(44100 * 0.14)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 28.0)
		var s = (sin(t * 320.0 * TAU) * 0.5 + (randf() * 2.0 - 1.0) * 0.3) * env
		var val16 = int(clamp(s, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	aud.stream = wav
	aud.play()
	aud.finished.connect(aud.queue_free)

func get_held_item_type() -> String:
	if held_object and is_instance_valid(held_object):
		return str(held_object.get_meta("item_type", "")).to_lower()
	return GameManager.get_active_item_id()

func get_held_key_id() -> int:
	if held_object and is_instance_valid(held_object):
		if held_object.has_meta("key_id"):
			return int(held_object.get_meta("key_id"))
		if held_object.has_meta("lock_id"):
			return int(held_object.get_meta("lock_id"))
		if held_object.get("key_id") != null and int(held_object.get("key_id")) > 0:
			return int(held_object.get("key_id"))
	var act_it = GameManager.get_active_item()
	if act_it.has("key_id"):
		return int(act_it["key_id"])
	var it = GameManager.get_active_item_id()
	if it.begins_with("key_id_"):
		return it.trim_prefix("key_id_").to_int()
	return 0

func get_held_key_color() -> String:
	var kid = get_held_key_id()
	if kid > 0:
		var DoorScript = load("res://scripts/Door.gd")
		var th = DoorScript.get_lock_theme(kid)
		return str(th.get("name", "gold")).to_lower()
	var act_it = GameManager.get_active_item()
	if act_it.has("key_color"):
		return str(act_it["key_color"]).to_lower()
	if held_object and is_instance_valid(held_object):
		var it = str(held_object.get_meta("item_type", "")).to_lower()
		if it.begins_with("key_"):
			return it.trim_prefix("key_")
		return str(held_object.get_meta("key_color", "gold"))
	return ""

func _setup_highlight_material() -> void:
	highlight_material = StandardMaterial3D.new()
	highlight_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	highlight_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	highlight_material.albedo_color = Color(1.0, 0.95, 0.45, 0.32)
	highlight_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	highlight_material.grow = true
	highlight_material.grow_amount = 0.012

func _apply_highlight(node: Node) -> void:
	if not node or not is_instance_valid(node):
		return

	# Динамический цвет подсветки в зависимости от соответствия ключа/лома!
	var hl_color = Color(1.0, 0.95, 0.45, 0.35)

	var target_door = node
	for _p in range(4):
		if target_door.has_method("get_door_info"):
			break
		if target_door.get_parent():
			target_door = target_door.get_parent()
		else:
			break

	if target_door and target_door.has_method("get_door_info"):
		var d_info: Dictionary = target_door.call("get_door_info")
		if d_info.get("requires_boards", false) and d_info.get("boards_needed", false):
			if d_info.get("has_crowbar", false):
				hl_color = Color(1.0, 0.78, 0.12, 0.55) # Лом подходит!
			else:
				hl_color = Color(0.95, 0.25, 0.25, 0.45) # Нужен лом
		elif int(d_info.get("lock_id", 0)) > 0 and not bool(d_info.get("door_key_unlocked", false)):
			var th: Dictionary = d_info.get("lock_theme", {})
			var th_col = th.get("color", Color(1.0, 0.85, 0.2))
			if d_info.get("has_key", false):
				hl_color = Color(th_col.r, th_col.g, th_col.b, 0.60) # Ключ подходит!
			else:
				hl_color = Color(0.95, 0.25, 0.25, 0.45) # Нужен ключ
		else:
			hl_color = Color(0.35, 0.90, 1.0, 0.35)
	elif node.has_meta("key_id") or str(node.get_meta("item_type", "")).begins_with("key"):
		var kid = 1
		if node.has_meta("key_id"):
			kid = int(node.get_meta("key_id"))
		elif node.has_meta("lock_id"):
			kid = int(node.get_meta("lock_id"))
		var DoorScript = load("res://scripts/Door.gd")
		var th = DoorScript.get_lock_theme(kid)
		var th_col = th.get("color", Color(1.0, 0.85, 0.2))
		hl_color = Color(th_col.r, th_col.g, th_col.b, 0.65)
	elif str(node.get_meta("item_type", "")) == "crowbar":
		hl_color = Color(1.0, 0.35, 0.15, 0.60)

	if highlight_material:
		highlight_material.albedo_color = hl_color

	if current_highlighted_node == node:
		return
	_remove_highlight()
	current_highlighted_node = node
	_set_overlay_recursive(node, highlight_material)

func _remove_highlight() -> void:
	if current_highlighted_node and is_instance_valid(current_highlighted_node):
		_set_overlay_recursive(current_highlighted_node, null)
	current_highlighted_node = null

func _set_overlay_recursive(n: Node, mat: Material) -> void:
	if n is GeometryInstance3D:
		n.material_overlay = mat
	for ch in n.get_children():
		_set_overlay_recursive(ch, mat)

func _toggle_tv_via_remote() -> void:
	var tvs: Array = []
	for n in get_tree().get_nodes_in_group("horror_tv"):
		tvs.append(n)
	if tvs.is_empty():
		for n in get_tree().current_scene.find_children("*", "Node3D", true, false):
			if n.has_method("toggle_power") or n.get_meta("item_type", "") == "crt_tv":
				tvs.append(n)
	if not tvs.is_empty():
		for tv in tvs:
			if tv.has_method("toggle_power"):
				tv.call("toggle_power")
			elif tv.has_method("interact"):
				tv.call("interact", self)

var player_health: float = 100.0
const MAX_PLAYER_HEALTH: float = 100.0

func take_damage(amount: float, killer: Variant = null) -> void:
	if is_dead or (GameManager and GameManager.is_godmode):
		return
	player_health -= amount
	if GameManager.ui_ref and GameManager.ui_ref.has_method("flash_fear"):
		GameManager.ui_ref.call("flash_fear", 0.75)
	if is_instance_valid(camera):
		var t = create_tween()
		t.tween_property(camera, "h_offset", randf_range(-0.06, 0.06), 0.05)
		t.tween_property(camera, "h_offset", 0.0, 0.08)
	if player_health <= 0.0:
		player_health = 0.0
		die(killer)


# ──────────────────────────────────────────────
#  API
# ──────────────────────────────────────────────
func get_breath_noise_level() -> float:
	return breath_sys.call("get_noise_level") if breath_sys else 0.5

func get_oxygen_ratio() -> float:
	return breath_sys.call("get_oxygen_ratio") if breath_sys else 1.0

func get_oxygen_seconds() -> float:
	return breath_sys.call("get_oxygen_seconds") if breath_sys else 15.0

func is_breath_held() -> bool:
	return breath_sys.call("is_breath_held") if breath_sys else false

func get_breath_recovery_seconds() -> float:
	return breath_sys.call("get_recovery_timer") if (breath_sys and breath_sys.has_method("get_recovery_timer")) else 0.0

func is_in_breath_recovery() -> bool:
	return breath_sys.call("is_in_recovery") if (breath_sys and breath_sys.has_method("is_in_recovery")) else false

func recharge_battery(amount: float) -> void:
	flash_battery = min(100.0, flash_battery + amount)
	if not flashlight_on:
		flashlight_on = true
		if player_hands:
			player_hands.set_flashlight_state(true, 1.0)
		elif flashlight:
			flashlight.visible = true

func get_battery_ratio() -> float:
	return flash_battery / 100.0

func die(killer: Variant = null) -> void:
	if is_dead or GameManager.is_godmode:
		return
	if is_peeking_keyhole:
		exit_keyhole_peek()
	if is_hiding:
		exit_hiding()
	is_dead = true
	velocity = Vector3.ZERO
	if player_hands:
		player_hands.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# 3D Хоррор-эффект: резкий захват взгляда монстром, зум в упор и сокрушительное падение на пол
	var enemy: Variant = killer if is_instance_valid(killer) else GameManager.enemy_ref
	if is_instance_valid(enemy) and enemy is Node3D and is_instance_valid(camera):
		# Тормозим монстра на месте расправы и разворачиваем лицом к камере
		if "velocity" in enemy:
			enemy.set("velocity", Vector3.ZERO)
		var to_player = global_position - enemy.global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.01:
			enemy.rotation.y = atan2(-to_player.x, -to_player.z)

		var enemy_head_pos: Vector3 = enemy.global_position + Vector3(0, 1.45, 0)
		var to_enemy: Vector3 = enemy_head_pos - camera.global_position
		if to_enemy.length_squared() > 0.01:
			var flat_dir := Vector3(to_enemy.x, 0, to_enemy.z).normalized()
			var target_yaw := atan2(-flat_dir.x, -flat_dir.z)
			var target_pitch := clampf(asin(clampf(to_enemy.normalized().y, -0.9, 0.9)), -1.1, 1.1)

			var tw := create_tween()
			# 1. Мгновенный рывок взгляда прямо в глаза монстра (0.06 сек)
			tw.tween_property(self, "rotation:y", target_yaw, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(head, "rotation:x", target_pitch, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			# FOV панч (глубокий пугающий зум в морду 75 -> 40)
			tw.parallel().tween_property(camera, "fov", 40.0, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

			# 2. Физический коллапс тела на пол (Death Fall)
			# Спустя 0.40 сек яростной атаки в лицо: тело обмякает, голова падает на пол, шея ломается набок
			tw.chain().tween_interval(0.38)
			tw.chain().tween_property(head, "position:y", 0.22, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(camera, "rotation:z", deg_to_rad(38.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.parallel().tween_property(head, "rotation:x", deg_to_rad(18.0), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	GameManager.last_killer = killer
	_start_death_camera_trauma()
	GameManager.trigger_game_over()

func _start_death_camera_trauma() -> void:
	var trauma_tw = create_tween()
	for i in range(18):
		var mag = lerpf(0.09, 0.01, float(i) / 18.0)
		trauma_tw.tween_callback(func():
			if is_instance_valid(camera):
				camera.h_offset = randf_range(-mag, mag)
				camera.v_offset = randf_range(-mag * 0.7, mag * 0.7)
		)
		trauma_tw.tween_interval(0.035)


# ──────────────────────────────────────────────
#  Тело персонажа: обновление ног и ракурсов
# ──────────────────────────────────────────────
func _update_player_body(delta: float) -> void:
	if not player_body or not player_body.has_method("update_body"):
		return
	var pitch_deg = rad_to_deg(head.rotation.x)
	var h_speed = Vector2(velocity.x, velocity.z).length()
	var is_moving = is_on_floor() and h_speed > 0.25
	player_body.call("update_body", pitch_deg, delta, is_moving, h_speed, is_crouching)

func _play_player_step(is_sprint: bool, is_crouch: bool) -> void:
	if player_step_audio:
		if not player_step_streams.is_empty():
			player_step_audio.stream = player_step_streams[step_stream_idx % player_step_streams.size()]
			step_stream_idx += 1
		if player_step_audio.stream:
			var vol = -10.0 if is_sprint else (-24.0 if is_crouch else -15.0)
			player_step_audio.volume_db = vol
			player_step_audio.pitch_scale = randf_range(0.95, 1.05)
			player_step_audio.play()

	# Бег привлекает слух скинвокера и деда со значительного расстояния
	if is_sprint:
		GameManager.emit_noise(global_position, 28.0, "player_run")
	elif not is_crouch:
		GameManager.emit_noise(global_position, 3.5, "player_walk")


func get_camera_pitch_deg() -> float:
	if head:
		return rad_to_deg(head.rotation.x)
	return 0.0


func get_player_body() -> Node3D:
	return player_body

# ──────────────────────────────────────────────
#  Подглядывание в замочную скважину и скрытное открытие
# ──────────────────────────────────────────────
func _find_door_in_hierarchy(node: Node) -> Node:
	if not node:
		return null
	var curr: Node = node
	for _i in range(5):
		if not curr:
			break
		if curr.has_method("stealth_peek_adjust") or curr.has_method("_toggle_simple_door") or curr.has_meta("door_type") or str(curr.get_meta("item_type", "")).begins_with("door"):
			if curr.has_method("_door_controller"):
				return curr.call("_door_controller")
			return curr
		curr = curr.get_parent()
	return null

func _find_hiding_spot_in_hierarchy(node: Node) -> Node3D:
	if not node:
		return null
	var curr: Node = node
	for _i in range(5):
		if not is_instance_valid(curr):
			break
		var itype = str(curr.get_meta("item_type", "")).to_lower()
		var htype = str(curr.get_meta("hiding_type", "")).to_lower()
		var ptype = str(curr.get_meta("prefab_type", "")).to_lower()
		var n_name = curr.name.to_lower()
		if itype in ["wardrobe", "bed", "prop_wardrobe", "prop_bed"] or htype in ["wardrobe", "bed"] or ptype in ["wardrobe", "bed", "prop_wardrobe", "prop_bed"] or curr.is_in_group("hiding_spots") or "wardrobe" in n_name or "bed" in n_name:
			if curr is Node3D:
				return curr as Node3D
		curr = curr.get_parent()
	return null

func enter_keyhole_peek(door: Node3D) -> void:
	if is_peeking_keyhole or is_hiding or is_dead:
		return
	is_peeking_keyhole = true
	peeking_door_ref = door
	velocity = Vector3.ZERO
	keyhole_saved_head_pos = head.position
	keyhole_saved_head_rot = head.rotation

	# Определение стороны, с которой находится игрок по отношению к двери
	var local_actor = door.global_transform.affine_inverse() * global_position
	var from_front = local_actor.z > 0.0
	var look_dir = -door.global_transform.basis.z if from_front else door.global_transform.basis.z
	var target_yaw = atan2(-look_dir.x, -look_dir.z)
	keyhole_base_yaw = target_yaw - rotation.y

	# Плавное опускание взгляда к замочной скважине (высота ~1.05м)
	var tw = create_tween()
	tw.tween_property(head, "position:y", 1.05, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(head, "rotation:y", keyhole_base_yaw, 0.22)
	tw.parallel().tween_property(head, "rotation:x", 0.0, 0.22)

	if player_hands:
		player_hands.visible = false

	if GameManager.ui_ref:
		GameManager.ui_ref.call("show_keyhole_overlay", true)
		GameManager.ui_ref.call("show_interact_hint", "Замочная скважина    [C / E / WASD] Отойти")

func exit_keyhole_peek() -> void:
	if not is_peeking_keyhole:
		return
	is_peeking_keyhole = false
	peeking_door_ref = null

	var tw = create_tween()
	var target_head_y = 0.88 if is_crouching else 1.62
	tw.tween_property(head, "position:y", target_head_y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(head, "rotation", Vector3.ZERO, 0.18)

	if player_hands and not is_hiding:
		player_hands.visible = true

	if GameManager.ui_ref:
		GameManager.ui_ref.call("show_keyhole_overlay", false)
