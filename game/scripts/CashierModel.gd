extends Node3D
class_name CashierModel

# Процедурная 3D-модель кассирши с заправки: пожилая уставшая женщина в рабочем халате.
# Сетка на скелете и анимация из кода, как у LumberjackModel. Лицо смотрит вдоль локальной +Z.
# Три основные анимации: "stand" — стоит и делает мелкие движения, "talk" — говорит с жестами,
# "walk" — ходит туда-сюда вдоль оси X на pace_width метров. "counter" — стоит, опираясь на прилавок.
# Вызывать каждый кадр: update_motion(delta, "talk"). Для разговора у прилавка: use_counter = true.
# say(текст, секунды) проговаривает фразу: рот двигается по буквам. Без say режим "talk" повторяет PHRASES.

const THIGH: float = 0.37
const SHIN: float = 0.37
const UPPER_ARM: float = 0.28
const FOREARM: float = 0.25
const SHOULDER_X: float = 0.158
const SHOULDER_Y: float = 0.075
# Голова строится в тех же размерах, что у лесоруба, затем сжимается по высоте
const HEAD_SCALE := Vector3(0.9, 0.76, 0.93)
# Точка опоры ладони на прилавке в осях груди
const COUNTER_HAND := Vector3(0.2, -0.27, 0.3)
const POSES := {
	"stand":   {"lean": 0.02, "lean_on": 0.0},
	"counter": {"lean": 0.13, "lean_on": 1.0},
	"talk":    {"lean": 0.05, "lean_on": 0.0},
	"walk":    {"lean": 0.06, "lean_on": 0.0},
}

# Форма рта для букв: раскрытие челюсти и ширина губ (минус — трубочкой, плюс — в стороны)
const VISEMES := {
	"а": [1.0, 0.15], "я": [0.85, 0.2], "о": [0.62, -0.75], "ё": [0.6, -0.6], "у": [0.26, -1.0], "ю": [0.3, -0.9],
	"э": [0.6, 0.45], "е": [0.5, 0.5], "и": [0.22, 0.85], "ы": [0.28, 0.5],
	"м": [0.0, -0.05], "б": [0.0, -0.05], "п": [0.0, -0.05], "в": [0.08, 0.05], "ф": [0.08, 0.05],
	"ш": [0.16, -0.45], "щ": [0.16, -0.45], "ж": [0.16, -0.45], "ч": [0.14, -0.3],
	"с": [0.1, 0.45], "з": [0.1, 0.45], "ц": [0.1, 0.4], "т": [0.12, 0.2], "д": [0.14, 0.2], "н": [0.14, 0.2], "л": [0.2, 0.1], "р": [0.18, 0.05],
	"к": [0.2, 0.0], "г": [0.2, 0.0], "х": [0.2, 0.0], "й": [0.14, 0.4],
}
const PHRASES := [
	"Увидишь на дороге оленя — не останавливайся.",
	"Позовут по имени из леса — не отзывайся.",
	"Почувствуешь, что кто-то идёт следом, — не оборачивайся.",
]

static var _mesh: ArrayMesh = null
static var _bone_defs: Array = []
static var _globals: Array[Transform3D] = []
static var _ids := {}
static var _rng := RandomNumberGenerator.new()

# Настройки: ширина прогулки, скорость, разговор у прилавка
@export var pace_width := 3.0
@export var walk_speed := 0.8
@export var use_counter := false

var rig: Node3D
var skeleton: Skeleton3D

var _b := {}
var _mode := "stand"
var _t := 0.0
var _lean := 0.02
var _lean_on := 0.0
var _talk := 0.0
var _look_yaw := 0.0
var _look_pitch := 0.0
# Речь
var _say_letters: Array = []
var _say_times: Array = []
var _say_t := -1.0
var _say_dur := 0.0
var _phrase := 0
var _phrase_wait := 0.3
var _open := 0.0
var _wide := 0.0
var _emph := 0.0
var _gest := 0.0
# Ходьба
var _walk := 0.0
var _phase := 0.0
var _pace_center := Vector3.ZERO
var _pace_ready := false
var _pace_dir := 1.0
var _pace_turn := 0.0
var _home_yaw := 0.0
# Мелкие движения, когда стоит
var _idle_in := 1.0
var _idle_kind := ""
var _idle_i := 0
var _idle_t := 0.0
var _g_glasses := 0.0
var _g_clasp := 0.0
var _g_look := 0.0
var _g_sigh := 0.0
var _g_neck := 0.0
# Глаза и брови
var _blink := 0.0
var _blink_in := 2.2
var _blink_phase := -1.0
var _gaze := Vector2.ZERO
var _gaze_to := Vector2.ZERO
var _gaze_in := 1.5
var _brow := 0.0


func _init() -> void:
	if _mesh == null:
		_build_mesh()
	rig = Node3D.new()
	rig.name = "Rig"
	add_child(rig)
	skeleton = Skeleton3D.new()
	skeleton.name = "Skeleton"
	rig.add_child(skeleton)
	for d in _bone_defs:
		var i := skeleton.add_bone(d.name)
		_b[d.name] = i
		if d.parent >= 0:
			skeleton.set_bone_parent(i, d.parent)
		skeleton.set_bone_rest(i, d.rest)
	skeleton.reset_bone_poses()
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = _mesh
	body.extra_cull_margin = 1.0
	skeleton.add_child(body)
	body.skeleton = NodePath("..")
	_apply()


# ══════════════════════════════════════════════
#  Публичное API
# ══════════════════════════════════════════════
func update_motion(delta: float, mode: String = "") -> void:
	if mode != "" and POSES.has(mode):
		if mode == "walk" and _mode != "walk":
			_start_pace()
		_mode = mode
	_t += delta
	var tg: Dictionary = POSES[_mode]
	var k := minf(1.0, delta * 3.0)
	var at_counter := use_counter and _mode == "talk"
	_lean = lerpf(_lean, 0.13 if at_counter else tg["lean"], k)
	_lean_on = lerpf(_lean_on, 1.0 if at_counter else tg["lean_on"], k)
	_update_walk(delta)
	_update_idle(delta)
	_talk = lerpf(_talk, 1.0 if _mode == "talk" else 0.0, minf(1.0, delta * 6.0))
	_update_speech(delta)
	_update_eyes(delta)
	_apply()


# Проговаривает фразу за указанное время
func say(text: String, duration: float = -1.0) -> void:
	if _mode != "walk":
		_mode = "talk"
	_say_letters.clear()
	_say_times.clear()
	var total := 0.0
	for c in text.to_lower():
		var w := 1.0
		if c == " ":
			w = 0.7
		elif c in ",.—-!?…":
			w = 3.2
		elif c in "ьъ":
			continue
		elif c in "аяоёуюэеиы":
			w = 1.55
		_say_letters.append(c)
		_say_times.append(total)
		total += w
	_say_dur = duration if duration > 0.0 else total * 0.062
	for i in _say_times.size():
		_say_times[i] = _say_times[i] / total * _say_dur
	_say_t = 0.0


func is_speaking() -> bool:
	return _say_t >= 0.0


func _start_pace() -> void:
	_pace_center = position
	_pace_dir = 1.0
	_pace_turn = 0.0
	_home_yaw = rotation.y
	_pace_ready = true


# Идёт вдоль оси X, на краю останавливается и разворачивается
func _update_walk(delta: float) -> void:
	var moving := false
	if _mode == "walk":
		var yaw_target := PI * 0.5 * _pace_dir
		if _pace_turn > 0.0:
			_pace_turn -= delta
			rotation.y = lerp_angle(rotation.y, yaw_target, 1.0 - exp(-delta * 3.2))
		else:
			rotation.y = lerp_angle(rotation.y, yaw_target, 1.0 - exp(-delta * 7.0))
			position.x += _pace_dir * walk_speed * delta * clampf(_walk * 1.3, 0.0, 1.0)
			moving = true
			if (position.x - _pace_center.x) * _pace_dir >= pace_width * 0.5:
				_pace_dir = -_pace_dir
				_pace_turn = 1.15
	elif _pace_ready:
		rotation.y = lerp_angle(rotation.y, _home_yaw, 1.0 - exp(-delta * 4.0))
	# На развороте переступает мелкими шагами
	var to_walk := 1.0 if moving else (0.42 if _mode == "walk" else 0.0)
	_walk = lerpf(_walk, to_walk, 1.0 - exp(-delta * 5.0))
	var stride := 2.0 * (THIGH + SHIN) * sin(0.3)
	_phase += delta * walk_speed * PI / stride * (0.35 + 0.65 * _walk) * (1.0 if _walk > 0.01 else 0.0)


# Пока стоит, время от времени поправляет очки, складывает руки, оглядывается, вздыхает, трёт шею
func _update_idle(delta: float) -> void:
	var w_glasses := 0.0
	var w_clasp := 0.0
	var w_look := 0.0
	var w_sigh := 0.0
	var w_neck := 0.0
	if _mode == "stand":
		if _idle_kind == "":
			_idle_in -= delta
			if _idle_in <= 0.0:
				_idle_kind = ["glasses", "look", "clasp", "sigh", "neck", "look"][_idle_i % 6]
				_idle_i += 1
				_idle_t = 0.0
		else:
			_idle_t += delta
			var length: float = {"glasses": 2.4, "look": 3.0, "clasp": 5.0, "sigh": 2.6, "neck": 3.6}[_idle_kind]
			var e := smoothstep(0.0, 0.55, _idle_t) * (1.0 - smoothstep(length - 0.6, length, _idle_t))
			match _idle_kind:
				"glasses": w_glasses = e
				"look": w_look = e
				"clasp": w_clasp = e
				"sigh": w_sigh = e
				"neck": w_neck = e
			if _idle_t >= length:
				_idle_kind = ""
				_idle_in = randf_range(1.5, 3.5)
	else:
		_idle_kind = ""
		_idle_in = 1.0
	var k := 1.0 - exp(-delta * 8.0)
	_g_glasses = lerpf(_g_glasses, w_glasses, k)
	_g_clasp = lerpf(_g_clasp, w_clasp, k)
	_g_look = lerpf(_g_look, w_look, k)
	_g_sigh = lerpf(_g_sigh, w_sigh, k)
	_g_neck = lerpf(_g_neck, w_neck, k)


func _update_speech(delta: float) -> void:
	var to_open := 0.0
	var to_wide := 0.0
	if _say_t >= 0.0:
		_say_t += delta
		if _say_t >= _say_dur:
			_say_t = -1.0
			_phrase_wait = 1.1
		else:
			# Рот готовится к следующей букве чуть заранее
			var at := _say_t + 0.035
			var i := _say_times.bsearch(at, true) - 1
			var c: String = _say_letters[clampi(i, 0, _say_letters.size() - 1)]
			if VISEMES.has(c):
				to_open = VISEMES[c][0]
				to_wide = VISEMES[c][1]
	elif _mode == "talk":
		_phrase_wait -= delta
		if _phrase_wait <= 0.0:
			say(PHRASES[_phrase])
			_phrase = (_phrase + 1) % PHRASES.size()
	var k := 1.0 - exp(-delta * 24.0)
	_open = lerpf(_open, to_open, k)
	_wide = lerpf(_wide, to_wide, k)
	# Ударные слоги: голова и рука подчёркивают их, затухают медленно
	_emph = maxf(_emph - delta * 2.6, _open)
	_gest = lerpf(_gest, 1.0 if _say_t >= 0.0 else 0.0, 1.0 - exp(-delta * 3.0))


func _update_eyes(delta: float) -> void:
	_blink_in -= delta
	if _blink_in <= 0.0 and _blink_phase < 0.0:
		_blink_phase = 0.0
		_blink_in = randf_range(2.0, 5.0)
	if _blink_phase >= 0.0:
		_blink_phase += delta / 0.17
		_blink = sin(minf(_blink_phase, 1.0) * PI)
		if _blink_phase >= 1.0:
			_blink_phase = -1.0
			_blink = 0.0
	# Короткие скачки взгляда: не смотрит всё время в одну точку
	_gaze_in -= delta
	if _gaze_in <= 0.0:
		_gaze_in = randf_range(0.7, 2.6)
		var amount := 0.1 if _say_t >= 0.0 else 0.26
		_gaze_to = Vector2(randf_range(-amount, amount), randf_range(-amount, amount) * 0.5)
		if randf() < 0.45:
			_gaze_to = Vector2.ZERO
	_gaze = _gaze.lerp(_gaze_to, 1.0 - exp(-delta * 30.0))
	var to_brow := clampf(_emph * 0.9, 0.0, 1.0) * _gest + sin(_t * 0.4) * 0.05
	_brow = lerpf(_brow, to_brow, 1.0 - exp(-delta * 7.0))


# Смотрит на точку в мире (например, на игрока). null — смотрит прямо
func set_look_target(world_point: Variant) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if world_point is Vector3:
		var local: Vector3 = global_transform.affine_inverse() * (world_point as Vector3)
		var from := Vector3(0.0, 1.5, 0.0)
		var v := local - from
		if v.z > 0.0:
			yaw = clampf(atan2(v.x, v.z), -1.0, 1.0)
			pitch = clampf(atan2(-v.y, Vector2(v.x, v.z).length()), -0.4, 0.4)
	_look_yaw = lerp_angle(_look_yaw, yaw, 0.1)
	_look_pitch = lerpf(_look_pitch, pitch, 0.1)


func get_head_position() -> Vector3:
	var pose := skeleton.get_bone_global_pose(_b["head"])
	return skeleton.global_transform * (pose * Vector3(0.0, 0.1, 0.09))


# ══════════════════════════════════════════════
#  Анимация
# ══════════════════════════════════════════════
func _rot(bone: String, x: float, y: float = 0.0, z: float = 0.0) -> void:
	skeleton.set_bone_pose_rotation(_b[bone], Quaternion(Basis.from_euler(Vector3(x, y, z), EULER_ORDER_XYZ)))


func _ik(sfx: String, side: float, target: Vector3) -> Quaternion:
	var s_pos := Vector3(SHOULDER_X * side, SHOULDER_Y, 0.0)
	var v := target - s_pos
	var d := clampf(v.length(), 0.14, UPPER_ARM + FOREARM - 0.004)
	var dir := v.normalized()
	var a := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, UPPER_ARM * UPPER_ARM - a * a))
	var pole := Vector3(side * 0.6, -0.5, -0.6).lerp(Vector3(side * 0.22, -1.0, 0.05), clampf(_g_glasses + _g_neck * 0.5, 0.0, 1.0))
	pole = (pole - dir * pole.dot(dir)).normalized()
	var elbow := s_pos + dir * a + pole * h
	var wrist := s_pos + dir * d
	var u1 := (elbow - s_pos).normalized()
	var u2 := (wrist - elbow).normalized()
	var q1 := Quaternion(Vector3.DOWN, u1)
	var q2 := Quaternion(Vector3.DOWN, q1.inverse() * u2)
	skeleton.set_bone_pose_rotation(_b["sh" + sfx], q1)
	skeleton.set_bone_pose_rotation(_b["el" + sfx], q2)
	return q1 * q2


# Поворот кисти: куда смотрят пальцы и куда ладонь
static func _hand_basis(fingers: Vector3, palm: Vector3) -> Basis:
	var y := -fingers.normalized()
	var z := (palm - y * palm.dot(y)).normalized()
	return Basis(y.cross(z), y, z)


func _hand(sfx: String, side: float) -> void:
	# Опущенная рука: ладонь к бедру, большой палец вперёд. При ходьбе качается
	var swing := -side * sin(_phase) * _walk
	var down_basis := Basis(Vector3.UP, -side * PI * 0.5) * Basis(Vector3.RIGHT, -swing * 0.3)
	var down_wrist := Vector3(0.205 * side, -0.455 + sin(_t * 1.1) * 0.002 + absf(swing) * 0.025, 0.035 + swing * 0.11)
	# На прилавке: ладонь вниз, пальцы вперёд
	var flat_basis := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, 0.0, -1.0), Vector3(0.0, -1.0, 0.0))
	var flat_point := Vector3(COUNTER_HAND.x * side, COUNTER_HAND.y, COUNTER_HAND.z)
	var flat_wrist := flat_point + flat_basis.y * 0.055 - flat_basis.z * 0.03
	var wrist := down_wrist.lerp(flat_wrist, _lean_on)
	var hb := Quaternion(down_basis.orthonormalized()).slerp(Quaternion(flat_basis), _lean_on)

	# Жесты при разговоре: ладони приподняты и отбивают ударные слоги
	var g := _gest * (1.0 - _walk)
	if g > 0.001:
		var gest_basis := Basis(Vector3(-1.0, 0.0, 0.0), Vector3(0.0, -0.707, -0.707), Vector3(0.0, -0.707, 0.707))
		gest_basis = Basis(Vector3.RIGHT, -_emph * 0.28 + sin(_t * 1.7) * 0.08) * gest_basis
		if sfx == "R":
			var gw := Vector3(0.2 + sin(_t * 0.9) * 0.012, -0.135 + _emph * 0.022 + sin(_t * 1.3) * 0.006, 0.29)
			wrist = wrist.lerp(gw, g)
			hb = hb.slerp(Quaternion(gest_basis.orthonormalized()), g)
		elif _lean_on < 0.5:
			# Левая рука придерживает край халата и немного двигается
			var gw := Vector3(-0.15, -0.3 + sin(_t * 1.05 + 1.0) * 0.012 + _emph * 0.008, 0.2)
			wrist = wrist.lerp(gw, g * 0.85)
			hb = hb.slerp(Quaternion(_hand_basis(Vector3(0.75, -0.25, 0.45), Vector3(0.1, 0.1, -1.0))), g * 0.85)

	# Поправляет очки
	if sfx == "R" and _g_glasses > 0.001:
		var push := sin(clampf(_idle_t - 0.7, 0.0, 1.0) * PI) * 0.008
		var gw := Vector3(0.072, 0.175 + push, 0.165)
		wrist = wrist.lerp(gw, _g_glasses)
		hb = hb.slerp(Quaternion(_hand_basis(Vector3(-0.42, 0.82, 0.05), Vector3(-0.45, -0.1, -0.9))), _g_glasses)
	# Складывает руки на животе
	if _g_clasp > 0.001:
		var gw := Vector3(0.078 * side, -0.335 + sin(_t * 0.8) * 0.004, 0.2)
		wrist = wrist.lerp(gw, _g_clasp)
		hb = hb.slerp(Quaternion(_hand_basis(Vector3(-side * 0.93, -0.15, 0.2), Vector3(0.0, 0.2, -1.0))), _g_clasp)
	# Трёт шею
	if sfx == "L" and _g_neck > 0.001:
		var rub := sin(_t * 4.6) * 0.014
		var gw := Vector3(-0.085 + rub, 0.15 + rub * 0.4, -0.02)
		wrist = wrist.lerp(gw, _g_neck)
		hb = hb.slerp(Quaternion(_hand_basis(Vector3(0.45, 0.85, -0.1), Vector3(0.75, -0.3, -0.5))), _g_neck)

	var fore_q := _ik(sfx, side, wrist)
	skeleton.set_bone_pose_rotation(_b["hand" + sfx], fore_q.inverse() * hb)


func _apply() -> void:
	var br := sin(_t * 1.25)
	# Ноги: шаг как у лесоруба, но короче и медленнее
	var amp := 0.3 * _walk
	var knee := 0.06 + 0.08 * _walk
	var s_w := sin(_phase)
	var c_w := cos(_phase)
	var lth := -s_w * amp - knee * 0.42
	var rth := s_w * amp - knee * 0.42
	var lkn := knee + amp * 1.3 * pow(maxf(0.0, c_w), 1.3)
	var rkn := knee + amp * 1.3 * pow(maxf(0.0, -c_w), 1.3)
	var drop_l := THIGH * cos(lth) + SHIN * cos(lth + lkn)
	var drop_r := THIGH * cos(rth) + SHIN * cos(rth + rkn)
	# Стоя переносит вес с ноги на ногу, при ходьбе таз качается
	var sway := sin(_t * 0.31) * 0.012 * (1.0 - _walk) + s_w * 0.022 * _walk
	skeleton.set_bone_pose_position(_b["hips"], Vector3(sway, maxf(drop_l, drop_r) + 0.135, 0.0))
	_rot("hips", 0.0, s_w * 0.1 * _walk, -sway * 1.4)
	_rot("thL", lth, 0.0, -0.03 + sway * 1.4)
	_rot("thR", rth, 0.0, 0.03 + sway * 1.4)
	_rot("knL", lkn)
	_rot("knR", rkn)
	_rot("anL", -(lth + lkn) + maxf(0.0, c_w) * amp * 0.25)
	_rot("anR", -(rth + rkn) + maxf(0.0, -c_w) * amp * 0.25)

	# Сутулая спина
	var pitch := _lean + br * 0.006 - _g_sigh * sin(clampf(_idle_t / 2.6, 0.0, 1.0) * PI) * 0.05
	var twist := -s_w * 0.1 * _walk + _g_look * 0.14
	_rot("spineA", pitch * 0.55 + 0.03, twist * 0.5, sway * 0.7)
	_rot("chest", pitch * 0.45 + 0.05, twist * 0.5, sway * 0.7)

	# Голова держится прямо, медленно оглядывается и кивает, когда говорит
	var scan := (sin(_t * 0.27) * 0.16 + sin(_t * 0.83) * 0.03) * (1.0 - _talk) * (1.0 - _walk) + s_w * 0.06 * _walk
	scan += _g_look * 0.95 * (1.0 if sin(_t * 0.09) > 0.0 else -1.0) - twist * 0.6
	# При растирании шеи наклоняет голову
	var neck_tilt := _g_neck * 0.2 + _g_glasses * 0.06
	var nod := (_emph * 0.05 + sin(_t * 1.1) * 0.016) * _talk
	_rot("neck", -pitch * 0.6 + 0.02 + _look_pitch * 0.4)
	_rot("head", -pitch * 0.25 - 0.02 + br * 0.004 + nod + _look_pitch * 0.6 + neck_tilt, scan + _look_yaw, sin(_t * 0.5) * 0.02 + 0.03 - _g_neck * 0.1)

	_hand("L", -1.0)
	_hand("R", 1.0)

	_apply_face()


func _offset(bone: String, delta_pos: Vector3) -> void:
	var rest: Vector3 = skeleton.get_bone_rest(_b[bone]).origin
	skeleton.set_bone_pose_position(_b[bone], rest + delta_pos)


func _apply_face() -> void:
	_rot("jaw", _open * 0.2)
	var round_k := maxf(0.0, -_wide)
	var wide_k := maxf(0.0, _wide)
	for spec in [["cornerL", -1.0], ["cornerR", 1.0]]:
		var sd: float = spec[1]
		_offset(spec[0], Vector3(sd * (wide_k * 0.0034 - round_k * 0.0078), wide_k * 0.0012 - _open * 0.0028, round_k * 0.0035 - wide_k * 0.0012))
	_offset("lipU", Vector3(0.0, _open * 0.0016 + round_k * 0.0006, round_k * 0.0034))
	_offset("browL", Vector3(0.0, _brow * 0.0042, 0.0))
	_offset("browR", Vector3(0.0, _brow * 0.0042, 0.0))
	_rot("eyeL", _gaze.y, _gaze.x)
	_rot("eyeR", _gaze.y, _gaze.x)
	var lid := _blink * 0.68 + maxf(_gaze.y, 0.0) * 0.5
	_rot("lidUL", lid)
	_rot("lidUR", lid)


# ══════════════════════════════════════════════
#  Постройка геометрии (лофт из SkinwalkerModel)
# ══════════════════════════════════════════════
static func _bone(bname: String, parent: String, pos: Vector3) -> void:
	var pid: int = _ids[parent] if parent != "" else -1
	var rest := Transform3D(Basis(), pos)
	_ids[bname] = _bone_defs.size()
	_bone_defs.append({"name": bname, "parent": pid, "rest": rest})
	_globals.append(_globals[pid] * rest if pid >= 0 else rest)


static func _G(bname: String) -> Transform3D:
	return _globals[_ids[bname]]


static func _put(sf, geo: Dictionary, bone: String, local: Transform3D = Transform3D(), tint: Color = Color.WHITE) -> void:
	SkinwalkerModel._add(sf, SkinwalkerModel._xf(geo, _G(bone) * local), _ids[bone], tint)


static func _head_xf() -> Transform3D:
	return Transform3D(Basis().scaled(HEAD_SCALE), Vector3.ZERO)


# Деталь головы: координаты заданы в размерах головы лесоруба
static func _ph(sf, geo: Dictionary, local: Transform3D = Transform3D(), tint: Color = Color.WHITE, bone: String = "head") -> void:
	var world := _G("head") * _head_xf() * local
	SkinwalkerModel._add(sf, SkinwalkerModel._xf(geo, world), _ids[bone], tint)


static func _loft(rings: Array, nu: int, ps: int, disp: Callable = Callable(), uvk: float = 1.0) -> Dictionary:
	return SkinwalkerModel._loft(rings, nu, ps, disp, uvk)


static func _gauss(p: Vector3, c: Vector3, r: float) -> float:
	return exp(-(p - c).length_squared() / (r * r))


static func _mat(c0: Color, c1: Color, freq: float, rough: float, vcol: bool = false) -> StandardMaterial3D:
	var m := LumberjackModel._noise_mat(c0, c1, freq, rough)
	m.vertex_color_use_as_albedo = vcol
	return m


static func _knit_tex() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var rib := 0.86 if (x % 6) < 2 else 1.0
			var row := 0.93 if (y % 5) < 1 else 1.0
			var n := _rng.randf_range(-0.012, 0.012)
			var v := rib * row
			img.set_pixel(x, y, Color(0.3 * v + n, 0.265 * v + n, 0.2 * v + n))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# Полосы вдоль причёски: тёмные и седые пряди. В точке (0, 0) текстура белая, она нужна отдельным прядям
static func _hair_tex() -> ImageTexture:
	var img := Image.create(512, 8, true, Image.FORMAT_RGB8)
	var coarse := 0.85
	var fine := 0.0
	for x in 512:
		if x % 7 == 0:
			coarse = clampf(coarse + _rng.randf_range(-.09, .09), .72, 1.0)
		fine = clampf(fine * .6 + _rng.randf_range(-.09, .09), -.14, .14)
		var v := clampf(coarse + fine, .5, 1.0)
		for y in 8:
			img.set_pixel(x, y, Color(v, v, v))
	for y in 8:
		img.set_pixel(0, y, Color.WHITE)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func _build_mesh() -> void:
	_bone_defs.clear()
	_globals.clear()
	_ids.clear()
	_rng.seed = 90417

	_bone("hips", "", Vector3(0, 0.87, 0))
	_bone("spineA", "hips", Vector3(0, 0.15, 0))
	_bone("chest", "spineA", Vector3(0, 0.16, 0))
	_bone("neck", "chest", Vector3(0, 0.16, 0))
	_bone("head", "neck", Vector3(0, 0.09, 0))

	var smock = SkinwalkerModel.Surf.new()
	var knit = SkinwalkerModel.Surf.new()
	var slacks = SkinwalkerModel.Surf.new()
	var shoe = SkinwalkerModel.Surf.new()
	var skin = SkinwalkerModel.Surf.new()
	var face_sf = SkinwalkerModel.Surf.new()
	var hair = SkinwalkerModel.Surf.new()
	var misc = SkinwalkerModel.Surf.new()
	var lens = SkinwalkerModel.Surf.new()

	_build_torso(smock, knit, misc)
	_build_head(skin, face_sf, hair, misc, lens)
	for side in [-1.0, 1.0]:
		_build_arm(side, knit, skin)
		_build_leg(side, slacks, shoe, misc, skin)

	var mesh := ArrayMesh.new()
	SkinwalkerModel._commit(mesh, smock, _mat(Color(0.045, 0.125, 0.13), Color(0.095, 0.205, 0.205), 0.02, 0.92))
	SkinwalkerModel._commit(mesh, knit, LumberjackModel._tex_mat(_knit_tex(), 0.98))
	SkinwalkerModel._commit(mesh, slacks, _mat(Color(0.035, 0.032, 0.035), Color(0.075, 0.07, 0.07), 0.018, 0.94))
	SkinwalkerModel._commit(mesh, shoe, _mat(Color(0.15, 0.115, 0.085), Color(0.24, 0.19, 0.145), 0.03, 0.7))
	var skin_m := _mat(Color(0.6, 0.45, 0.39), Color(0.67, 0.51, 0.45), 0.045, 0.74, true)
	skin_m.normal_enabled = true
	skin_m.normal_texture = SkinwalkerModel._noise_tex(FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.18, true)
	skin_m.normal_scale = 0.05
	skin_m.uv1_scale = Vector3(3.0, 3.0, 3.0)
	SkinwalkerModel._commit(mesh, skin, skin_m)
	var face_m := StandardMaterial3D.new()
	face_m.vertex_color_use_as_albedo = true
	face_m.albedo_texture = load("res://assets/textures/cashier/face_albedo.png") as Texture2D
	face_m.normal_enabled = true
	face_m.normal_texture = load("res://assets/textures/cashier/face_normal.png") as Texture2D
	face_m.normal_scale = 0.3
	face_m.roughness = 0.6
	face_m.metallic_specular = 0.34
	SkinwalkerModel._commit(mesh, face_sf, face_m)
	var hair_m := StandardMaterial3D.new()
	hair_m.vertex_color_use_as_albedo = true
	hair_m.albedo_texture = _hair_tex()
	hair_m.roughness = 0.95
	hair_m.metallic_specular = 0.15
	hair_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	SkinwalkerModel._commit(mesh, hair, hair_m)
	var misc_m := StandardMaterial3D.new()
	misc_m.vertex_color_use_as_albedo = true
	misc_m.roughness = 0.8
	SkinwalkerModel._commit(mesh, misc, misc_m)
	var lens_m := StandardMaterial3D.new()
	lens_m.albedo_color = Color(0.7, 0.75, 0.75, 0.025)
	lens_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lens_m.roughness = 0.25
	lens_m.metallic_specular = 0.18
	SkinwalkerModel._commit(mesh, lens, lens_m)
	_mesh = mesh


# ── Рабочий халат без рукавов, ворот кофты, карманы, бейдж и ключи ──
static func _build_torso(smock, knit, misc) -> void:
	var folds := func(th: float, y: float, _c: float, s: float) -> float:
		var d := 0.003 * sin(th * 5.0 + y * 13.0) + 0.002 * sin(y * 31.0 + th * 3.0)
		if y < 0.0:
			d += 0.005 * sin(th * 13.0 + 0.7) * smoothstep(0.0, -0.18, y)
		# Мягкий живот под халатом
		d += 0.012 * pow(maxf(0.0, s), 2.0) * exp(-pow((y - 0.06) / 0.11, 2.0))
		return d * smoothstep(0.44, 0.34, y)
	var body := _loft([[-.2, .172, .132], [-.19, .176, .136], [-.1, .178, .137], [-.02, .175, .134], [.06, .165, .126], [.15, .158, .12], [.24, .163, .124], [.32, .178, .128], [.365, .195, .116], [.395, .172, .1], [.425, .115, .082], [.45, .066, .06], [.47, .05, .048]], 32, 4, folds)
	SkinwalkerModel._chain_weights(body, [0.0, 0.15, 0.16], [_ids.hips, _ids.spineA, _ids.chest], 0.08, 1.0)
	SkinwalkerModel._xf(body, _G("hips"))
	SkinwalkerModel._add(smock, body)

	var dark_stitch := Color(0.004, 0.012, 0.012)
	var button := Color(0.1, 0.095, 0.08)
	# Шов и пуговицы по центру халата
	for spec in [["hips", -.02, .36, .15], ["spineA", .085, .17, .135], ["chest", .03, .09, .118]]:
		_put(misc, LumberjackModel._box(.004, spec[2], .004), spec[0], Transform3D(Basis(), Vector3(.0, spec[1], spec[3])), dark_stitch)
	for spec in [["hips", -.12, .155], ["hips", -.02, .154], ["spineA", .0, .143], ["spineA", .1, .136], ["chest", .04, .124], ["chest", .098, .1]]:
		_put(misc, LumberjackModel._ball(Vector3(.0085, .0085, .004)), spec[0], Transform3D(Basis(), Vector3(.0, spec[1], spec[2])), button)

	# Карманы на животе
	for s in [-1.0, 1.0]:
		var yaw := Basis(Vector3.UP, 0.48 * s)
		_put(smock, LumberjackModel._box(.125, .125, .012), "hips", Transform3D(yaw, Vector3(.092 * s, -.075, .139)))
		_put(misc, LumberjackModel._box(.127, .006, .014), "hips", Transform3D(yaw, Vector3(.092 * s, -.015, .139)), dark_stitch)

	# Ручка в нагрудном кармане
	var chest_yaw := Basis(Vector3.UP, 0.42)
	_put(smock, LumberjackModel._box(.082, .075, .01), "chest", Transform3D(Basis(Vector3.UP, -0.42), Vector3(-.082, -.01, .113)))
	_put(misc, LumberjackModel._box(.082, .005, .012), "chest", Transform3D(Basis(Vector3.UP, -0.42), Vector3(-.082, .028, .113)), dark_stitch)
	_put(misc, LumberjackModel._box(.009, .05, .009), "chest", Transform3D(Basis(Vector3.UP, -0.42), Vector3(-.098, .04, .119)), Color(0.01, 0.01, 0.05))
	_put(misc, LumberjackModel._box(.003, .03, .004), "chest", Transform3D(Basis(Vector3.UP, -0.42), Vector3(-.098, .04, .124)), Color(0.2, 0.19, 0.16))

	# Бейдж: светлая пластина с полосой и «надписью»
	var tag_pos := Vector3(.088, .035, .112)
	_put(misc, LumberjackModel._box(.082, .032, .004), "chest", Transform3D(chest_yaw, tag_pos), Color(0.3, 0.28, 0.23))
	_put(misc, LumberjackModel._box(.082, .008, .0048), "chest", Transform3D(chest_yaw, tag_pos + Vector3(0, .012, 0)), Color(0.2, 0.02, 0.012))
	for i in 5:
		var x := -.026 + i * .013
		var off := chest_yaw * Vector3(x, -.004, .0028)
		_put(misc, LumberjackModel._box(.009, .008, .0012), "chest", Transform3D(chest_yaw, tag_pos + off), Color(0.012, 0.012, 0.012))

	# Ключи на кольце у правого бедра
	var ring_pos := Vector3(.165, .005, .085)
	_put(misc, LumberjackModel._ball(Vector3(.016, .016, .003)), "hips", Transform3D(Basis(Vector3.UP, 1.0), ring_pos), Color(0.09, 0.085, 0.07))
	for i in 3:
		var a := -0.35 + i * 0.35
		var key_b := Basis(Vector3.BACK, a)
		var key_pos := ring_pos + key_b * Vector3(0, -.05, .004)
		_put(misc, LumberjackModel._box(.009, .05, .002), "hips", Transform3D(key_b, key_pos), Color(0.13, 0.11, 0.06))
		_put(misc, LumberjackModel._box(.02, .018, .0025), "hips", Transform3D(key_b, key_pos + key_b * Vector3(0, .028, 0)), Color(0.11, 0.09, 0.05))

	# Ворот кофты
	var collar := _loft([[-.024, .072, .066], [-.008, .062, .058], [.012, .053, .051], [.03, .05, .049]], 18, 2, Callable(), .5)
	_put(knit, collar, "neck", Transform3D(Basis(), Vector3(0, 0, .002)))


# Кольца лица: профиль как у головы лесоруба, но кольца гуще всего вокруг рта
static func _face_rings() -> Array:
	var keys := [[-.062, .004, .004, .016], [-.056, .031, .037, .016], [-.035, .053, .067, .012], [.0, .067, .085, .007], [.05, .075, .096, .002], [.1, .081, .103, -.002], [.15, .084, .105, -.006], [.2, .078, .098, -.012], [.235, .016, .02, -.016], [.25, .004, .004, -.018]]
	var ys := [-.062, -.056, -.046, -.035, -.022, -.01, .0, .004, .008, .012, .016, .02, .024, .03, .04, .05, .062, .074, .08, .086, .092, .098, .104, .11, .116, .122, .128, .134, .14, .146, .152, .158, .165, .175, .2, .22, .235, .25]
	var rings := []
	for y in ys:
		var k := 0
		while k < keys.size() - 2 and y > keys[k + 1][0]:
			k += 1
		var a: Array = keys[maxi(k - 1, 0)]
		var b: Array = keys[k]
		var c: Array = keys[k + 1]
		var d: Array = keys[mini(k + 2, keys.size() - 1)]
		var t: float = (y - b[0]) / (c[0] - b[0])
		rings.append([y, SkinwalkerModel._crom(a[1], b[1], c[1], d[1], t), SkinwalkerModel._crom(a[2], b[2], c[2], d[2], t), 0.0, SkinwalkerModel._crom(a[3], b[3], c[3], d[3], t)])
	return rings


# Высота линии рта в координатах головы: её использует генератор текстуры лица
static func face_mouth_y() -> float:
	var nu := 128
	var face := _loft(_face_rings(), nu, 2, Callable(), .6)
	var pts: PackedVector3Array = face.pts
	var st: int = nu + 1
	var r0 := 0
	for i in int(face.rows) - 1:
		if absf(pts[i * st].y - .012) < absf(pts[r0 * st].y - .012):
			r0 = i
	return (pts[r0 * st].y + pts[(r0 + 1) * st].y) * 0.5


# Часть эллипсоида от полюса +Y до угла ang: веко. Край можно затемнить, как ресницы
static func _lid(r: Vector3, ang: float, edge: Color) -> Dictionary:
	var nu := 18
	var rows := 8
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in rows:
		var ph := float(i) / float(rows - 1) * ang
		var dark := smoothstep(0.86, 1.0, float(i) / float(rows - 1))
		for j in nu + 1:
			var th := float(j) / float(nu) * TAU
			pts.append(Vector3(sin(ph) * cos(th) * r.x, cos(ph) * r.y, sin(ph) * sin(th) * r.z))
			uvs.append(Vector2(float(j) / float(nu), float(i) / float(rows - 1)))
			cols.append(Color(0.84, 0.7, 0.65).lerp(edge, dark))
	return {"pts": pts, "uvs": uvs, "nu": nu, "rows": rows, "up": false, "col": cols}


# Трубка по эллипсу в плоскости XY
static func _ring(rx: float, ry: float, t: float) -> Dictionary:
	var nu := 6
	var rows := 37
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in rows:
		var a := float(i) / float(rows - 1) * TAU
		var o := Vector3(cos(a), sin(a), 0.0)
		for j in nu + 1:
			var th := float(j) / float(nu) * TAU
			pts.append(Vector3(o.x * rx, o.y * ry, 0.0) + o * cos(th) * t + Vector3(0, 0, sin(th) * t))
			uvs.append(Vector2.ZERO)
	return {"pts": pts, "uvs": uvs, "nu": nu, "rows": rows, "up": true}


static func _ball_hi(sc: Vector3) -> Dictionary:
	return SkinwalkerModel._xf(SkinwalkerModel._sphere(28, 12), Transform3D(Basis().scaled(sc), Vector3.ZERO))


# Ухо: сетка кольцами от углубления к краю. X — ширина, Y — высота, Z — наружу
static func _ear() -> Dictionary:
	var nu := 28
	var rows := 15
	var pts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	for i in rows:
		var t := float(i) / float(rows - 1)
		for j in nu + 1:
			var th := float(j) / float(nu) * TAU
			var top := sin(th)
			# Сверху шире, внизу узкая мочка
			var wide := .0135 + .0045 * smoothstep(-.3, .8, top) - .0035 * smoothstep(-.5, -1.0, top)
			var tall := .036 if top > 0.0 else .039
			var x := cos(th) * wide * t + .0012 * top
			var y := top * tall * t
			var lobe := smoothstep(-.55, -.9, top)
			var z := -.0048 * (1.0 - smoothstep(.15, .5, t)) * (1.0 - lobe)
			z += .0024 * exp(-pow((t - .62) / .1, 2.0)) * (1.0 - lobe)
			z += .0048 * exp(-pow((t - .9) / .075, 2.0)) * (1.0 - lobe * .75)
			z -= .0065 * smoothstep(.95, 1.0, t)
			pts.append(Vector3(x, y, z))
			uvs.append(Vector2(float(j) / float(nu), t))
			var pit := 1.0 - smoothstep(.1, .5, t)
			var fold := exp(-pow((t - .78) / .05, 2.0)) * (1.0 - lobe)
			var v := 1.0 - pit * .68 - fold * .34
			cols.append(Color(0.82 * v, 0.61 * v, 0.56 * v))
	return {"pts": pts, "uvs": uvs, "nu": nu, "rows": rows, "up": true, "col": cols}


# ── Голова: лицо с настоящим ртом, веки, глаза, очки и волосы ──
static func _build_head(skin, face_sf, hair, misc, lens) -> void:
	_put(skin, _loft([[-.05, .046, .046], [.1, .042, .042]], 12, 2), "neck", Transform3D(Basis(), Vector3(0, 0, .002)), Color(0.46, 0.37, 0.34))

	var nu := 128
	var face := _loft(_face_rings(), nu, 2, Callable(), .6)
	var st: int = nu + 1
	var rows: int = face.rows
	var pts: PackedVector3Array = face.pts
	# Линия рта проходит ровно между двумя рядами сетки: между ними будет настоящая щель
	var r0 := 0
	for i in rows - 1:
		if absf(pts[i * st].y - .012) < absf(pts[r0 * st].y - .012):
			r0 = i
	var y0 := (pts[r0 * st].y + pts[(r0 + 1) * st].y) * 0.5
	var row_y := PackedFloat32Array()
	row_y.resize(pts.size())
	var cols := PackedColorArray()
	var center := Vector3(0, .08, 0)
	for i in pts.size():
		var q := pts[i]
		row_y[i] = q.y
		var dy := q.y - y0
		var ax := absf(q.x)
		var front := smoothstep(.05, .09, q.z)
		# Уголки рта чуть опущены
		q.y -= 8.0 * pow(minf(ax, .03), 2.0) * exp(-pow(dy / .02, 2.0)) * front
		var p := q
		var d := 0.0
		var dark := 0.0
		var col := Color.WHITE
		for s in [-1.0, 1.0]:
			# Глазницы и нависающее веко
			var so := _gauss(p, Vector3(.035 * s, .085, .094), .024)
			d -= .0175 * so
			dark = maxf(dark, so * .28)
			# Мешок под глазом
			d += .0024 * _gauss(p, Vector3(.036 * s, .0645, .094), .011)
			# Скулы, румянец, брыли
			d += .0042 * _gauss(p, Vector3(.052 * s, .056, .08), .02)
			d += .0032 * _gauss(p, Vector3(.047 * s, -.012, .072), .017)
			d -= .004 * _gauss(p, Vector3(.068 * s, .145, .07), .022)
			# Носогубная складка как форма, без цвета
			var t := clampf((.048 - p.y) / .04, 0.0, 1.0)
			d -= .0016 * exp(-pow((ax - (.0165 + .0145 * t)) / .0034, 2.0)) * smoothstep(.052, .042, p.y) * smoothstep(.002, .012, p.y) * front
		# Нос: спинка, кончик, крылья, ноздри
		d += .0155 * exp(-pow(p.x / .0074, 2.0)) * exp(-pow((p.y - .07) / .027, 2.0)) * front
		d += .0155 * _gauss(p, Vector3(0, .047, .107), .0098)
		for s in [-1.0, 1.0]:
			d += .0036 * _gauss(p, Vector3(.0122 * s, .0405, .1), .0068)
			dark = maxf(dark, _gauss(p, Vector3(.0068 * s, .0355, .106), .0034) * .72)
		# Бровь: валик и редкие седые волосы, нарисованные на коже
		var yb := .1085 + .16 * ax
		d += .0018 * exp(-pow((p.y - yb) / .0075, 2.0)) * smoothstep(.07, .05, ax) * front
		# Переносица и морщины лба
		d -= .0042 * _gauss(p, Vector3(0, .108, .105), .012)
		# Губы: мягкая верхняя с ямкой посередине, нижняя полнее
		var u := minf(ax / .0225, 1.0)
		var hu := .0058 * (1.0 - u * u) * (1.0 - .28 * exp(-pow(ax / .0042, 2.0))) + .0006
		var hl := .0082 * (1.0 - u * u * u) + .0006
		var lip: float = smoothstep(hu + .0014, hu - .0003, dy) if dy >= 0.0 else smoothstep(hl + .0014, hl - .0003, -dy)
		lip *= smoothstep(.0245, .022, ax) * front
		d += .0021 * lip * (0.45 + 0.55 * smoothstep(.0, .004, absf(dy)))
		# Желобок над губой, вдавленность у рта, подбородок и ямка под губой
		d -= .0013 * exp(-pow(p.x / .0034, 2.0)) * smoothstep(.006, .012, dy) * smoothstep(.03, .02, dy)
		d -= .0024 * _gauss(p, Vector3(0, y0, .1), .022)
		d += .0058 * _gauss(p, Vector3(0, -.031, .098), .0135)
		d -= .0009 * _gauss(p, Vector3(0, y0 - .0165, .1), .0058)
		# Кожа круто уходит под причёску, поэтому край волос ровный
		var hairline := .153 + .9 * ax * ax - 1.2 * maxf(0.0, ax - .05)
		var under_hair := smoothstep(hairline - .014, hairline + .006, p.y) * smoothstep(-.02, .02, p.z)
		d -= .011 * under_hair
		d -= .024 * smoothstep(.1, .16, p.y) * smoothstep(.02, -.02, p.z)
		d -= .024 * smoothstep(.195, .225, p.y)
		p += (p - center).normalized() * d
		pts[i] = p
		var v := 1.0 - minf(1.0, dark)
		v *= lerpf(0.24, 1.0, smoothstep(-.03, .03, p.z))
		cols.append(Color(col.r * v, col.g * v, col.b * v))
	# Губы сомкнуты в покое: щель открывается только с челюстью
	var close_gap := (row_y[(r0 + 1) * st] - row_y[r0 * st]) * 0.5
	for j in st:
		var k_low := r0 * st + j
		var k_up := (r0 + 1) * st + j
		if absf(pts[k_low].x) < .021 and pts[k_low].z > 0.0:
			pts[k_low].y += close_gap
			pts[k_up].y -= close_gap
	face.pts = pts
	face.col = cols
	# Текстура лица: u — угол вокруг головы, v сверху вниз
	var face_uvs := PackedVector2Array()
	face_uvs.resize(pts.size())
	for i in pts.size():
		face_uvs[i] = Vector2(float(i % st) / float(nu), (.25 - row_y[i]) / (.25 + .062))
	face.uvs = face_uvs

	# Глубина рта по центру и поверхность у глаз
	var mouth_z := 0.0
	for j in nu + 1:
		var q := pts[r0 * st + j]
		if q.z > mouth_z:
			mouth_z = q.z
	var eye_z := 0.0
	for q in pts:
		if absf(q.x - .035) < .004 and absf(q.y - .085) < .004:
			eye_z = maxf(eye_z, q.z)

	var hx := _head_xf()
	_bone("jaw", "head", hx * Vector3(0, .05, -.015))
	_bone("cornerL", "head", hx * Vector3(-.0225, y0, mouth_z - .006))
	_bone("cornerR", "head", hx * Vector3(.0225, y0, mouth_z - .006))
	_bone("lipU", "head", hx * Vector3(0, y0 + .004, mouth_z))
	_bone("browL", "head", hx * Vector3(-.037, .115, .1))
	_bone("browR", "head", hx * Vector3(.037, .115, .1))

	# Веса: нижняя часть лица идёт за челюстью, уголки и губы за своими костями
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(pts.size() * 4)
	weights.resize(pts.size() * 4)
	for i in pts.size():
		var q := pts[i]
		var dy: float = row_y[i] - y0
		var ax := absf(q.x)
		var band := lerpf(.0004, .03, smoothstep(.017, .062, ax))
		var w_jaw := smoothstep(band, -band, dy) * smoothstep(-.04, .03, q.z)
		var cdist := Vector2(ax - .0225, dy)
		var w_corner := exp(-cdist.length_squared() / (.0135 * .0135)) * smoothstep(.05, .08, q.z)
		var fourth := -1
		var w_fourth := 0.0
		var w_u := exp(-pow(q.x / .017, 2.0)) * smoothstep(-.0002, .0005, dy) * smoothstep(.016, .004, dy) * smoothstep(.06, .08, q.z)
		if w_u > .001:
			fourth = _ids.lipU
			w_fourth = w_u
		else:
			var side_x := -.037 if q.x < 0.0 else .037
			var bd := Vector3(q.x - side_x, q.y - .118, 0.0).length()
			var w_b := exp(-bd * bd / (.03 * .03)) * smoothstep(.05, .08, q.z) * .95
			if w_b > .001:
				fourth = _ids.browL if q.x < 0.0 else _ids.browR
				w_fourth = w_b
		# Щель у уголков закрывается: уголок сильнее челюсти
		w_jaw *= 1.0 - w_corner * .6
		var total := w_jaw + w_corner + w_fourth
		if total > 1.0:
			w_jaw /= total
			w_corner /= total
			w_fourth /= total
			total = 1.0
		var b := i * 4
		bones[b] = _ids.head
		weights[b] = 1.0 - total
		bones[b + 1] = _ids.jaw
		weights[b + 1] = w_jaw
		bones[b + 2] = _ids.cornerL if q.x < 0.0 else _ids.cornerR
		weights[b + 2] = w_corner
		bones[b + 3] = fourth if fourth >= 0 else _ids.head
		weights[b + 3] = w_fourth
	face.bones = bones
	face.weights = weights

	# Сетка лица с прорезью рта
	var v_base: int = face_sf.v.size()
	var i_base: int = face_sf.idx.size()
	var head_world := _G("head") * hx
	var hole_x := PackedFloat32Array()
	hole_x.resize(st)
	for j in st:
		var q := pts[r0 * st + j]
		hole_x[j] = 1.0 if (absf(q.x) < .0195 and q.z > 0.0) else 0.0
	SkinwalkerModel._add(face_sf, SkinwalkerModel._xf(face, head_world), -1)
	var kept := PackedInt32Array()
	for t in range(i_base, face_sf.idx.size(), 3):
		var cut := true
		var r_min := 1 << 30
		var r_max := -1
		for k in 3:
			var rel: int = face_sf.idx[t + k] - v_base
			var r: int = rel / st
			r_min = mini(r_min, r)
			r_max = maxi(r_max, r)
			if hole_x[rel % st] < 0.5:
				cut = false
		if not cut or r_min != r0 or r_max != r0 + 1:
			kept.append_array([face_sf.idx[t], face_sf.idx[t + 1], face_sf.idx[t + 2]])
	face_sf.idx.resize(i_base)
	face_sf.idx.append_array(kept)

	# Внутри рта: тёмная полость, зубы, язык
	_ph(misc, LumberjackModel._ball(Vector3(.033, .036, .018)), Transform3D(Basis(), Vector3(0, y0 - .008, mouth_z - .033)), Color(0.004, 0.002, 0.002))
	_ph(misc, LumberjackModel._ball(Vector3(.0165, .0042, .0058)), Transform3D(Basis(), Vector3(0, y0 + .0058, mouth_z - .0092)), Color(0.27, 0.245, 0.17))
	_ph(misc, LumberjackModel._ball(Vector3(.0145, .0034, .0052)), Transform3D(Basis(), Vector3(0, y0 - .0052, mouth_z - .0082)), Color(0.27, 0.245, 0.17), "jaw")
	_ph(misc, LumberjackModel._ball(Vector3(.0145, .0052, .013)), Transform3D(Basis(), Vector3(0, y0 - .0088, mouth_z - .018)), Color(0.13, 0.035, 0.035), "jaw")

	# Глаза: круглые, поэтому по высоте компенсируют сжатие головы
	var ry := HEAD_SCALE.x / HEAD_SCALE.y
	var r_eye := .0108
	for s in [-1.0, 1.0]:
		var sfx := "L" if s < 0.0 else "R"
		var c := Vector3(.0345 * s, .0835, eye_z - .0062)
		_bone("eye" + sfx, "head", hx * c)
		_bone("lidU" + sfx, "head", hx * c)
		var eb := "eye" + sfx
		var ball := LumberjackModel._ball(Vector3(r_eye, r_eye * ry, r_eye))
		var ball_pts: PackedVector3Array = ball.pts
		var ball_cols := PackedColorArray()
		for q in ball_pts:
			var top := smoothstep(-.002, .011, q.y)
			var side := smoothstep(.004, .012, absf(q.x))
			var w := Color(0.085, 0.07, 0.058).lerp(Color(0.095, 0.045, 0.038), side * .75)
			ball_cols.append(w.lerp(Color(0.02, 0.015, 0.012), top * .8))
		ball.col = ball_cols
		_ph(misc, ball, Transform3D(Basis(), c), Color.WHITE, eb)
		_ph(misc, _ball_hi(Vector3(.0052, .0052 * ry, .0014)), Transform3D(Basis(), c + Vector3(0, 0, r_eye - .001)), Color(0.006, 0.006, 0.005), eb)
		_ph(misc, _ball_hi(Vector3(.0041, .0041 * ry, .0011)), Transform3D(Basis(), c + Vector3(0, 0, r_eye - .0005)), Color(0.026, 0.022, 0.016), eb)
		_ph(misc, _ball_hi(Vector3(.0021, .0021 * ry, .0009)), Transform3D(Basis(), c + Vector3(0, 0, r_eye - .0002)), Color(0.002, 0.002, 0.002), eb)
		_ph(misc, LumberjackModel._ball(Vector3(.00055, .00055 * ry, .0004)), Transform3D(Basis(), c + Vector3(-.0016, .0018, r_eye + .0002)), Color(0.2, 0.2, 0.2), eb)
		# Верхнее веко тяжёлое и прикрывает верх радужки, нижнее неподвижно
		var lid_r := Vector3(r_eye * 1.26, r_eye * ry * 1.2, r_eye * 1.17)
		_ph(skin, _lid(lid_r, 1.5, Color(0.11, 0.08, 0.07)), Transform3D(Basis(Vector3.RIGHT, -.16), c), Color.WHITE, "lidU" + sfx)
		var low_r := Vector3(r_eye * 1.22, r_eye * ry * 1.12, r_eye * 1.1)
		_ph(skin, _lid(low_r, 1.24, Color(0.48, 0.32, 0.29)), Transform3D(Basis(Vector3.BACK, PI), c))

	# Очки в тонкой оправе
	var frame := Color(0.016, 0.012, 0.009)
	for s in [-1.0, 1.0]:
		var c := Vector3(.0345 * s, .083, .1075)
		_ph(misc, _ring(.0235, .0205, .0011), Transform3D(Basis(), c), frame)
		_ph(lens, LumberjackModel._ball(Vector3(.023, .02, .0008)), Transform3D(Basis(), c))
		# Дужка уходит за ухо
		var from := Vector3(.058 * s, .088, .105)
		var to := Vector3(.0845 * s, .092, -.012)
		var yaw_b := Basis.looking_at((to - from).normalized(), Vector3.UP)
		_ph(misc, LumberjackModel._box(.0016, .0024, from.distance_to(to)), Transform3D(yaw_b, (from + to) * 0.5), frame)
	_ph(misc, LumberjackModel._box(.0225, .0018, .0018), Transform3D(Basis(), Vector3(0, .09, .1075)), frame)

	# Уши: завиток по краю, внутренний валик, углубление и мочка
	for s in [-1.0, 1.0]:
		var n := Vector3(s * .9, 0.0, .42).normalized()
		var ear_b := Basis(Vector3.UP.cross(n).normalized(), Vector3.UP, n) * Basis(Vector3.BACK, -s * .1)
		var ear_t := Transform3D(ear_b, Vector3(.0855 * s, .074, -.016))
		_ph(skin, _ear(), ear_t)
		var back_t := ear_t * Transform3D(Basis(), Vector3(0.0, -.002, -.006))
		_ph(skin, LumberjackModel._ball(Vector3(.0135, .03, .0075)), back_t, Color(0.5, 0.38, 0.35))

	# Волосы зачёсаны назад: кольца идут от затылка ко лбу, пряди текстуры сходятся к пучку.
	# Кольцо: [z, половина ширины, половина высоты, 0, -центр по высоте]
	var cap_rings := [[-.14, .012, .012, 0, -.095], [-.128, .05, .062, 0, -.104], [-.105, .072, .097, 0, -.112], [-.07, .084, .112, 0, -.124], [-.03, .088, .115, 0, -.13], [.01, .088, .103, 0, -.142], [.05, .085, .085, 0, -.15], [.075, .075, .072, 0, -.155], [.09, .05, .052, 0, -.165], [.096, .02, .025, 0, -.15], [.097, .004, .004, 0, -.14]]
	var bumps := func(th: float, y: float, _c: float, _s: float) -> float:
		return .0006 * sin(th * 21.0 + y * 6.0) + .0003 * sin(th * 53.0)
	var cap_t := Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	_ph(hair, _loft(cap_rings, 96, 4, bumps, 3.0), cap_t, Color(0.14, 0.127, 0.112))
	var bun_c := Vector3(0, .09, -.158)
	_ph(hair, LumberjackModel._ball(Vector3(.05, .05, .038)), Transform3D(Basis(), bun_c), Color(0.12, 0.11, 0.098))
	# Пряди вокруг пучка
	for n in 110:
		var g := _rng.randf_range(.08, .28)
		var u := _rng.randf_range(0.0, TAU)
		var v := _rng.randf_range(-.8, .8)
		var w := sqrt(1.0 - v * v)
		var q := bun_c + Vector3(w * cos(u) * .05, v * .05, w * sin(u) * .038)
		_strand(hair, q, Vector3(-sin(u), _rng.randf_range(-.15, .15), cos(u)), Vector3(cos(u), 0, sin(u)) * -.25, _rng.randf_range(.025, .045), _rng.randf_range(.002, .003), Color(g, g * .98, g * .94))


# Одна прядь: два сегмента по изогнутой линии, треугольное сечение
static func _strand(sf, p0: Vector3, dv: Vector3, bv: Vector3, l: float, w: float, col: Color) -> void:
	var head_t := _G("head") * _head_xf()
	var base: int = sf.v.size()
	var segs := 2
	for i in segs + 1:
		var t := float(i) / float(segs)
		var cw := w * (1.0 - t * 0.85)
		var c := p0 + dv * t * l + bv * t * t * l
		for j in 3:
			var a := float(j) / 3.0 * TAU
			var nrm := Vector3(cos(a), 0.0, sin(a))
			sf.v.append(head_t * (c + nrm * cw))
			sf.n.append((head_t.basis * nrm).normalized())
			sf.tan.append_array([1.0, 0.0, 0.0, 1.0])
			sf.uv.append(Vector2(0.0, 0.0))
			sf.col.append(col)
			sf.bones.append_array([_ids.head, 0, 0, 0])
			sf.weights.append_array([1.0, 0.0, 0.0, 0.0])
	for i in segs:
		for j in 3:
			var a := base + i * 3 + j
			var c := base + i * 3 + (j + 1) % 3
			var d := a + 3
			var e := c + 3
			sf.idx.append_array([a, c, d, c, e, d])


# ── Рука: рукав кофты с манжетой и тонкая кисть с полусогнутыми пальцами ──
static func _build_arm(side: float, knit, skin) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("sh" + sfx, "chest", Vector3(SHOULDER_X * side, SHOULDER_Y, 0))
	_bone("el" + sfx, "sh" + sfx, Vector3(0, -UPPER_ARM, 0))
	_bone("wr" + sfx, "el" + sfx, Vector3(0, -FOREARM, 0))
	_bone("hand" + sfx, "wr" + sfx, Vector3(0, -0.01, 0))
	var disp := func(th: float, y: float, _c: float, _s: float) -> float:
		return .0018 * sin(th * 5.0 + y * 34.0)
	var g := _loft([[.012, .012, .012], [.008, .028, .03], [-.012, .04, .044], [-.09, .046, .05], [-.18, .047, .048], [-.27, .043, .043], [-.3, .045, .044], [-.38, .043, .04], [-.47, .037, .031], [-.5, .04, .034], [-.53, .041, .035], [-.54, .012, .01]], 16, 3, disp, 1.3)
	SkinwalkerModel._chain_weights(g, [0.0, -UPPER_ARM, -FOREARM], [_ids["sh" + sfx], _ids["el" + sfx], _ids["wr" + sfx]], .045, -1.0)
	SkinwalkerModel._xf(g, _G("sh" + sfx))
	SkinwalkerModel._add(knit, g)
	var hb := "hand" + sfx
	_put(skin, _loft([[.012, .024, .019], [-.015, .029, .016], [-.05, .036, .014], [-.078, .036, .012], [-.09, .03, .011]], 10, 2, Callable(), .4), hb)
	for i in 4:
		var x := (i - 1.5) * .0172
		var l0: float = [.031, .036, .034, .027][i]
		var t0 := Transform3D(Basis(Vector3.RIGHT, -.32), Vector3(x, -.086, 0))
		_put(skin, _finger(l0, .0074), hb, t0)
		var t1 := t0 * Transform3D(Basis(Vector3.RIGHT, -.34), Vector3(0, -l0, 0))
		_put(skin, _finger(l0 * .72, .0067), hb, t1)
		var t2 := t1 * Transform3D(Basis(Vector3.RIGHT, -.24), Vector3(0, -l0 * .72, 0))
		_put(skin, _finger(l0 * .55, .006), hb, t2)
	var th_t := Transform3D(Basis.from_euler(Vector3(-.55, 0, .62 * side)), Vector3(.026 * side, -.03, .01))
	_put(skin, _loft([[.004, .0095, .0095], [-.022, .0085, .0085], [-.045, .0072, .0072]], 7, 2, Callable(), .3), hb, th_t)


static func _finger(l: float, r: float) -> Dictionary:
	return _loft([[.006, r * .8, r * .8], [.002, r, r], [-l * .5, r * .94, r * .94], [-l - .002, r * .92, r * .92], [-l - .006, r * .7, r * .7]], 8, 2, Callable(), .3)


# ── Нога: брюки и стоптанные туфли, видна полоска носка ──
static func _build_leg(side: float, slacks, shoe, misc, skin) -> void:
	var sfx := "L" if side < 0.0 else "R"
	_bone("th" + sfx, "hips", Vector3(.09 * side, -.05, 0))
	_bone("kn" + sfx, "th" + sfx, Vector3(0, -THIGH, 0))
	_bone("an" + sfx, "kn" + sfx, Vector3(0, -SHIN, 0))
	var disp := func(th: float, y: float, _c: float, _s: float) -> float:
		return .0028 * sin(th * 6.0 + y * 22.0)
	var g := _loft([[.08, .012, .012], [.055, .08, .086], [-.04, .094, .102], [-.18, .076, .082, 0, .005], [-.31, .062, .066, 0, .007], [-.37, .062, .069, 0, .01], [-.45, .059, .064, 0, .003], [-.57, .056, .063, 0, -.005], [-.66, .056, .06], [-.7, .058, .062], [-.71, .012, .012]], 18, 3, disp)
	SkinwalkerModel._chain_weights(g, [0.0, -THIGH, -SHIN], [_ids["th" + sfx], _ids["kn" + sfx], _ids["an" + sfx]], .05, -1.0)
	SkinwalkerModel._xf(g, _G("th" + sfx))
	SkinwalkerModel._add(slacks, g)
	var ab := "an" + sfx
	# Лодыжка в светлом носке
	_put(skin, _loft([[.075, .037, .04], [.0, .034, .037], [-.05, .036, .04]], 10, 2), ab, Transform3D(), Color(0.46, 0.44, 0.4))
	var f := _loft([[-.078, .012, .012], [-.066, .043, .04], [.0, .049, .046], [.07, .052, .038], [.125, .054, .034], [.17, .046, .028], [.195, .01, .01]], 14, 3, Callable(), .8)
	_put(shoe, f, ab, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -.052, 0)))
	var sole := _loft([[-.08, .018, .009], [-.066, .04, .011], [.0, .045, .011], [.07, .049, .011], [.125, .05, .011], [.165, .041, .011], [.19, .016, .009]], 14, 2)
	_put(misc, sole, ab, Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -.078, 0)), Color(0.13, 0.115, 0.095))
