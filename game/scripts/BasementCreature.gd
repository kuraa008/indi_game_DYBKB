extends Node

# Существо в подвале (глава 2). Ходит наверху, время от времени спускается проверить
# подвал, идёт на громкие звуки. Внизу им управляет обычный ИИ скинволкера, но поимку
# решает эта сцена: Итан не умирает, а начинает снова с места пробуждения.
#
# Начало главы: сразу после пробуждения оно спускается. У игрока есть несколько секунд,
# чтобы залезть в шкаф. Если успел, существо нюхает воздух у места, где лежал Итан, и зовёт
# голосом Сэма; на экране кнопка «Ответить». Ответил — оно открывает шкаф.

signal opening_finished

const ENEMY_SCENE := "res://scenes/Enemy.tscn"
const CUT := "res://assets/audio/cutscenes/"
const MONSTER := "res://assets/audio/monster/"
# Запись голоса можно положить сюда; пока её нет, звучит общий звук подражания
const VOICE_CALL := "res://assets/audio/cutscenes/voice/mimic_sam_here.wav"
const VOICE_FALLBACK := "res://assets/audio/monster/monster_mimic.wav"
const CALL_TEXT := "Итан… Ты здесь? Отзовись, брат…"

const PARK_POS := Vector3(-54.4, -2.6, -217.9)     # комнатка за дверью, игрок туда не попадёт
const LANDING := Vector3(-54.4, -2.62, -220.0)     # площадка наверху лестницы
const STAIRS_FOOT := Vector3(-54.4, -4.15, -224.2)
const WAKE_SPOT := Vector3(-58.0, -4.15, -227.5)
const WARDROBE := Vector3(-59.0, -4.2, -219.72)

const OPENING_DELAY := 2.5      # после пробуждения: копыта на лестнице
const OPENING_HIDE_TIME := 9.0  # столько у игрока до того, как оно спустится
const SNIFF_SECONDS := 2.2
const ANSWER_WINDOW := 6.0
const VISIT_EVERY := Vector2(75.0, 115.0)
const WARNING_SECONDS := 6.5    # от первого стука до появления на площадке
const NOISE_WARNING := 3.0      # на громкий звук спускается быстрее
const VISIT_SECONDS := 32.0
const LEAVE_TIMEOUT := 14.0
const CATCH_DISTANCE := 1.5
const CATCH_HOLD := 0.35
const CALM_AFTER_CATCH := 45.0

enum Phase { IDLE, OPENING_WAIT, OPENING_WALK, OPENING_SNIFF, OPENING_CALL, OPENING_LEAVE, WARNING, VISIT, LEAVING }

var chapter: Node
var enemy: CharacterBody3D
var phase: int = Phase.IDLE
var opening_done := false
var answered := false
var visits := 0
var catches := 0

var _player: CharacterBody3D
var _t := 0.0                # время в текущей фазе
var _next_visit := 0.0
var _visit_warning := WARNING_SECONDS
var _catch_hold := 0.0
var _step_clock := 0.0
var _steps_above := 0.0      # пока > 0, наверху слышны шаги
var _quiet_above := 0.0      # пауза: стоит и слушает
var _prompt: Label
var _enabled := true


func _ready() -> void:
	name = "BasementCreature"
	set_physics_process(false)


func begin(player: CharacterBody3D) -> void:
	_player = player
	GameManager.is_godmode = true
	enemy = load(ENEMY_SCENE).instantiate()
	enemy.name = "BasementSkinwalker"
	chapter.get_parent().add_child(enemy)
	GameManager.enemy_ref = enemy
	_park()
	_build_prompt()
	chapter.alerted.connect(_on_alert)
	_start_opening()
	set_physics_process(true)


func stop() -> void:
	_enabled = false
	set_physics_process(false)
	_park()
	_hide_prompt()
	GameManager.is_godmode = false


# ─── Положение существа ─────────────────────────────────────

func _park() -> void:
	if not is_instance_valid(enemy):
		return
	enemy.set_physics_process(false)
	enemy.visible = false
	enemy.velocity = Vector3.ZERO
	enemy.global_position = PARK_POS
	_set_collision(false)


func _appear(at: Vector3) -> void:
	enemy.global_position = at
	enemy.velocity = Vector3.ZERO
	enemy.call("reset_ai")
	enemy.set("_clock", 99.0)
	enemy.set("_last_contact", 99.0)
	enemy.visible = true
	_set_collision(true)
	enemy.set_physics_process(true)
	_catch_hold = 0.0


# Обычный ИИ ведёт существо сам; в постановочные моменты он выключен, а шагает и
# двигает ногами эта сцена
func _set_ai(on: bool) -> void:
	if is_instance_valid(enemy) and enemy.visible:
		enemy.set_physics_process(on)


func _puppet(delta: float, target: Variant, speed: float) -> void:
	_set_ai(false)
	enemy.set("anim_t", float(enemy.get("anim_t")) + delta)
	enemy.get("navigator").call("tick", delta)
	enemy.get("world_actions").call("tick", delta)
	if target is Vector3:
		enemy.call("_go", target, speed, delta)
	else:
		enemy.call("_brake", delta)
	var v: Vector3 = enemy.velocity
	v.y = -0.5 if enemy.is_on_floor() else v.y - 18.0 * delta
	enemy.velocity = v
	enemy.call("_try_step", Vector3(v.x, 0, v.z) * delta)
	enemy.move_and_slide()
	enemy.call("_animate", delta)


func _set_collision(on: bool) -> void:
	for shape in enemy.find_children("*", "CollisionShape3D", true, false):
		(shape as CollisionShape3D).disabled = not on


func is_down() -> bool:
	return is_instance_valid(enemy) and enemy.visible


# ─── Начало главы ───────────────────────────────────────────

func _start_opening() -> void:
	opening_done = false
	answered = false
	_set_phase(Phase.OPENING_WAIT)
	_steps_above = 0.0


func _opening(delta: float) -> void:
	match phase:
		Phase.OPENING_WAIT:
			if _t > OPENING_DELAY and _t - delta <= OPENING_DELAY:
				_play(MONSTER + "basement_door_open.wav", -6.0)
			if _t > OPENING_DELAY:
				_stairs_steps(delta)
			if _t >= OPENING_HIDE_TIME:
				_appear(LANDING)
				_set_phase(Phase.OPENING_WALK)
		Phase.OPENING_WALK:
			# Спрятался — спускается к месту, где лежал Итан, не торопясь.
			# Не спрятался — работает обычный ИИ: увидит и поймает.
			if not _player_hidden():
				_set_ai(true)
				return
			_puppet(delta, WAKE_SPOT, 2.2)
			if _flat(enemy.global_position, WAKE_SPOT) < 1.0 or _t > 12.0:
				_set_phase(Phase.OPENING_SNIFF)
				_play(MONSTER + "monster_breath.wav", -4.0)
		Phase.OPENING_SNIFF:
			_puppet(delta, null, 0.0)
			if _t >= SNIFF_SECONDS:
				_set_phase(Phase.OPENING_CALL)
				_voice()
				_show_prompt()
		Phase.OPENING_CALL:
			_puppet(delta, null, 0.0)
			if _t >= ANSWER_WINDOW:
				_hide_prompt()
				_set_phase(Phase.OPENING_LEAVE)
		Phase.OPENING_LEAVE:
			if _walk_up(delta):
				opening_done = true
				opening_finished.emit()
				_plan_next_visit()


func _player_hidden() -> bool:
	return _player.get("is_hiding") == true


# Вызвал ли ответ: существо идёт к шкафу и открывает его
func answer() -> void:
	if phase != Phase.OPENING_CALL:
		return
	answered = true
	_hide_prompt()
	_play(CUT + "voice/ethan_here.wav", 0.0)
	chapter.call("_say", "Я здесь…", 1.6)
	await get_tree().create_timer(1.2, false).timeout
	if _player.has_method("exit_hiding"):
		_player.call("exit_hiding")
	_caught()


# ─── Визиты ─────────────────────────────────────────────────

func _plan_next_visit() -> void:
	_set_phase(Phase.IDLE)
	_next_visit = randf_range(VISIT_EVERY.x, VISIT_EVERY.y)
	_visit_warning = WARNING_SECONDS


func _on_alert(_reason: String) -> void:
	if not _enabled or not opening_done:
		return
	if phase == Phase.IDLE:
		# Громкий звук: спускается почти сразу
		_next_visit = 0.0
		_visit_warning = NOISE_WARNING
	elif phase == Phase.LEAVING:
		_set_phase(Phase.VISIT)
		enemy.call("on_noise_heard", _player.global_position, 30.0)


func _idle(delta: float) -> void:
	_next_visit -= delta
	_ambient_above(delta)
	if _next_visit <= 0.0:
		_set_phase(Phase.WARNING)
		_play(MONSTER + "basement_door_open.wav", -8.0)


func _warning(delta: float) -> void:
	_stairs_steps(delta)
	if _t >= _visit_warning:
		visits += 1
		_appear(LANDING)
		enemy.call("_start_search", _player.global_position.lerp(STAIRS_FOOT, 0.5), true)
		_set_phase(Phase.VISIT)
		if randf() < 0.5:
			_voice_later()


func _visit(_delta: float) -> void:
	var hunting: bool = int(enemy.get("state")) == 3   # HUNT
	if _t >= VISIT_SECONDS and not hunting:
		_set_phase(Phase.LEAVING)


func _leaving(delta: float) -> void:
	# Уходя, всё равно смотрит: увидел — снова погоня
	if not _player_hidden() and bool(enemy.call("_can_see_player")):
		_set_phase(Phase.VISIT)
		_set_ai(true)
		enemy.call("_begin_hunt")
		return
	if _walk_up(delta):
		_plan_next_visit()


# Идёт к лестнице и поднимается; сверху скрывается из виду
func _walk_up(delta: float) -> bool:
	var target := STAIRS_FOOT if _flat(enemy.global_position, STAIRS_FOOT) > 0.8 and enemy.global_position.y < -3.4 else LANDING
	_puppet(delta, target, 2.6)
	if (target == LANDING and enemy.global_position.y > -3.0) or _t > LEAVE_TIMEOUT:
		_play_steps_up()
		_park()
		return true
	return false


# ─── Поимка ─────────────────────────────────────────────────

func _check_catch(delta: float) -> void:
	if not is_down() or _player.get("is_hiding") == true or _player.get("is_in_cutscene") == true:
		_catch_hold = 0.0
		return
	var near: bool = enemy.global_position.distance_to(_player.global_position) < CATCH_DISTANCE
	if near and bool(enemy.call("_can_see_player")):
		_catch_hold += delta
		if _catch_hold >= CATCH_HOLD:
			_caught()
	else:
		_catch_hold = maxf(0.0, _catch_hold - delta)


func _caught() -> void:
	catches += 1
	_hide_prompt()
	_park()
	chapter.call("caught")
	if not opening_done:
		_start_opening()
	else:
		_plan_next_visit()
		_next_visit = CALM_AFTER_CATCH


# ─── Кадр ───────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player) or not is_instance_valid(enemy):
		return
	if bool(chapter.get("_busy")) and phase != Phase.OPENING_CALL:
		return
	if _player.get("is_in_cutscene") == true and phase == Phase.OPENING_WAIT and _t == 0.0:
		return  # ждём конца кат-сцены пробуждения
	_t += delta
	if phase <= Phase.OPENING_LEAVE and phase != Phase.IDLE:
		_opening(delta)
	else:
		match phase:
			Phase.IDLE:
				_idle(delta)
			Phase.WARNING:
				_warning(delta)
			Phase.VISIT:
				_visit(delta)
			Phase.LEAVING:
				_leaving(delta)
	_check_catch(delta)


func _set_phase(next: int) -> void:
	phase = next
	_t = 0.0


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ─── Звуки и голос ──────────────────────────────────────────

# Наверху ходит, потом замирает и слушает: тишина страшнее стука
func _ambient_above(delta: float) -> void:
	if _quiet_above > 0.0:
		_quiet_above -= delta
		return
	if _steps_above <= 0.0:
		if randf() < delta * 0.12:
			_steps_above = randf_range(3.0, 7.0)
		return
	_steps_above -= delta
	_step_clock -= delta
	if _step_clock <= 0.0:
		_step_clock = randf_range(0.55, 0.75)
		_play(CUT + "hoof_muffled_%d.wav" % randi_range(1, 4), -16.0)
	if _steps_above <= 0.0 and randf() < 0.5:
		_quiet_above = randf_range(4.0, 8.0)


func _stairs_steps(delta: float) -> void:
	_step_clock -= delta
	if _step_clock <= 0.0:
		_step_clock = 0.62
		_play(CUT + "hoof_wood_%d.wav" % randi_range(1, 4), -6.0)


func _play_steps_up() -> void:
	_play(CUT + "hoof_wood_2.wav", -10.0)


func _voice() -> void:
	var path := VOICE_CALL if ResourceLoader.exists(VOICE_CALL) else VOICE_FALLBACK
	_play(path, -2.0)
	chapter.call("_say_as", "ГОЛОС СЭМА", CALL_TEXT, 3.6)


func _voice_later() -> void:
	await get_tree().create_timer(randf_range(6.0, 12.0), false).timeout
	if phase == Phase.VISIT and is_down():
		_voice()


func _play(path: String, db: float) -> void:
	if ResourceLoader.exists(path):
		chapter.call("_play", path, db)


# ─── Кнопка «Ответить» ──────────────────────────────────────

func _build_prompt() -> void:
	_prompt = Label.new()
	_prompt.text = "[Пробел]  Ответить"
	_prompt.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_color_override("font_color", Color(0.95, 0.9, 0.82))
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 0.62
	_prompt.anchor_bottom = 0.62
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.visible = false
	(chapter.get("_layer") as CanvasLayer).add_child(_prompt)


func _show_prompt() -> void:
	_prompt.visible = true
	_prompt.modulate.a = 0.0
	var tw := create_tween().set_loops(4)
	tw.tween_property(_prompt, "modulate:a", 1.0, 0.7)
	tw.tween_property(_prompt, "modulate:a", 0.45, 0.7)


func _hide_prompt() -> void:
	if is_instance_valid(_prompt):
		_prompt.visible = false


func _input(event: InputEvent) -> void:
	if phase != Phase.OPENING_CALL or not _prompt.visible:
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)
	if pressed:
		get_viewport().set_input_as_handled()
		answer()
