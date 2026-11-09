extends CanvasLayer

# Телефон Итана (автозагрузка Phone). Клавиша P, на геймпаде нажатие правого стика.
# Интерфейс собирается при первом показе, а когда телефон убран, _process выключен:
# на FPS он не влияет.
#
# Звонок из сюжета:
#   var result: String = await Phone.incoming_call("Неизвестный номер")
#   if result == Phone.ANSWERED:
#       Cutscene.play(get_tree(), "res://scenes/cutscenes/PoliceCall.tscn", "...", {"from_gameplay": true})
#
# Настройки звонка (все необязательны):
#   subtitle        подпись под именем, по умолчанию «Входящий вызов»
#   ring_seconds    сколько звонит, 0 = пока игрок не ответит
#   can_decline     есть ли кнопка «Сбросить», по умолчанию да
#   noise_radius    каждый гудок слышит враг в этом радиусе (для пряток), 0 = не слышит
#   repeat_after    после «Сбросить» перезвонить через столько секунд
#   decline_line    реплика Итана после «Сбросить»
#
# Наполнение: add_news, add_message, add_contact, clear_content.
# Для сохранений: get_state и set_state.

signal opened
signal closed
signal call_answered(caller: String)
signal call_declined(caller: String)
signal call_missed(caller: String)
signal contact_pressed(contact_name: String)
signal message_received(chat: String, text: String)
signal page_opened(page: int)
signal _call_resolved(result: String)

const ANSWERED := "answered"
const DECLINED := "declined"
const MISSED := "missed"
const BUSY := "busy"

const ACTION := "phone"
const SND_VIBRATE := "res://assets/audio/cutscenes/phone_vibrate.wav"
const SND_TAP := "res://assets/audio/cutscenes/phone_tap.wav"
const RING_PERIOD := 2.4
const ANSWER_GUARD := 0.45     # нажатие прыжка в момент звонка не должно принять вызов
const TOAST_SECONDS := 4.0
const MAX_RECENT_CALLS := 5
const CLASSMATES_CHAT := "Одногруппники"
const PUT_OFF_CALL_LINE := "Потом… Позвоню потом."

const BODY_SIZE := Vector2(300, 640)
const BODY_MARGIN := 34.0
const BEZEL := 9.0
const SCREEN_RADIUS := 34.0
const STATUS_HEIGHT := 38.0
const INDICATOR_HEIGHT := 24.0
const SIDE_PADDING := 14.0

const C_BLACK := Color(0.0, 0.0, 0.0)
const C_FRAME := Color(0.055, 0.057, 0.065)
const C_METAL := Color(0.33, 0.34, 0.38)
const C_APP := Color(0.035, 0.035, 0.042)
const C_CARD := Color(0.11, 0.11, 0.125)
const C_PRESS := Color(0.17, 0.17, 0.19)
const C_LINE := Color(0.2, 0.2, 0.22)
const C_TEXT := Color(0.96, 0.96, 0.97)
const C_DIM := Color(0.56, 0.56, 0.6)
const C_BLUE := Color(0.04, 0.52, 1.0)
const C_GREEN := Color(0.19, 0.82, 0.35)
const C_RED := Color(1.0, 0.27, 0.23)
const C_ORANGE := Color(1.0, 0.58, 0.08)
const C_GREY := Color(0.42, 0.43, 0.47)
const AVATAR_COLORS := [Color(0.35, 0.47, 0.72), Color(0.55, 0.4, 0.68), Color(0.32, 0.58, 0.55), Color(0.72, 0.47, 0.32)]

const WEEKDAYS := ["Воскресенье", "Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота"]
const MONTHS := ["января", "февраля", "марта", "апреля", "мая", "июня", "июля", "августа", "сентября", "октября", "ноября", "декабря"]

const WALL_SHADER := """
shader_type canvas_item;
uniform vec3 top_color;
uniform vec3 bottom_color;
uniform vec3 glow_color;
uniform float corner = 34.0;
uniform vec2 box = vec2(282.0, 622.0);
void fragment() {
	vec2 q = abs(UV * box - box * 0.5) - box * 0.5 + corner;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner;
	float g = smoothstep(0.85, 0.0, distance(UV * vec2(1.0, 2.2), vec2(0.72, 0.62)));
	vec3 c = mix(top_color, bottom_color, UV.y) + glow_color * g;
	COLOR = vec4(c, 1.0 - smoothstep(-1.0, 0.0, d));
}
"""

enum Page { HOME, NEWS, CHATS, CONTACTS, THREAD, CALL, NOTES, NOTE }

var enabled := true
var has_signal := true
var clock_text := ""           # пусто: системное время
var date_text := ""            # пусто: системная дата
var allow_in_cutscene := false # сюжет разрешает телефон, пока игрок обездвижен (диван в прологе)

var _news: Array = []
var _chats: Dictionary = {}    # имя -> Array сообщений {text, mine}
var _unread: Dictionary = {}   # имя -> число
var _contacts: Array = []
var _recent_calls: Array = []  # {name, result}
var _notes: Array = []         # журнал найденных записок {title, text}
var _note_open := -1

var _built := false
var _root: Control
var _body: Control
var _wall: ColorRect
var _clock: Label
var _signal_glyph: Glyph
var _column: VBoxContainer
var _head: HBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _foot: PanelContainer
var _indicator: Button
var _page: int = Page.HOME
var _thread := ""
var _toast: PanelContainer
var _toast_name: Label
var _toast_text: Label
var _toast_left := 0.0
var _audio: AudioStreamPlayer
var _font: SystemFont
var _font_bold: SystemFont

var _shown := false
var _locked := false
var _call_active := false
var _ringing := false
var _caller := ""
var _call_opts: Dictionary = {}
var _ring_left := 0.0
var _ring_clock := 0.0
var _guard_left := 0.0
var _answer_btn: Button
var _decline_btn: Button
var _return_after_call := false


# Значки рисуются кодом: файлов не нужно, и в любом размере они остаются чёткими.
class Glyph extends Control:
	var kind := ""
	var tint := Color.WHITE
	var filled := true
	var phase := 0.0

	func _init(glyph_kind: String, side: Vector2, color: Color = Color.WHITE) -> void:
		kind = glyph_kind
		tint = color
		custom_minimum_size = side
		size = side
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_phase(value: float) -> void:
		phase = value
		queue_redraw()

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		match kind:
			"phone":
				_handset(s, 0.0)
			"hangup":
				_handset(s, deg_to_rad(135.0))
			"message":
				draw_circle(Vector2(0.5, 0.46) * s, 0.36 * s, tint)
				draw_colored_polygon(_scaled([Vector2(0.27, 0.62), Vector2(0.2, 0.86), Vector2(0.48, 0.76)], s), tint)
			"news":
				draw_rect(Rect2(Vector2(0.18, 0.2) * s, Vector2(0.64, 0.6) * s), tint)
				var ink := Color(0, 0, 0, 0.55)
				draw_rect(Rect2(Vector2(0.25, 0.28) * s, Vector2(0.22, 0.2) * s), ink)
				for y in [0.3, 0.42, 0.56, 0.68]:
					var from_x: float = 0.53 if y < 0.5 else 0.25
					draw_line(Vector2(from_x, y) * s, Vector2(0.75, y) * s, ink, maxf(1.0, 0.05 * s))
			"person":
				draw_circle(Vector2(0.5, 0.36) * s, 0.18 * s, tint)
				var body: Array[Vector2] = []
				for i in range(17):
					var a: float = PI + PI * float(i) / 16.0
					body.append(Vector2(0.5 + cos(a) * 0.32, 0.86 + sin(a) * 0.28) * s)
				draw_colored_polygon(PackedVector2Array(body), tint)
			"camera":
				draw_rect(Rect2(Vector2(0.14, 0.32) * s, Vector2(0.72, 0.46) * s), tint)
				draw_rect(Rect2(Vector2(0.38, 0.24) * s, Vector2(0.24, 0.1) * s), tint)
				draw_circle(Vector2(0.5, 0.55) * s, 0.16 * s, Color(0, 0, 0, 0.6))
			"photo":
				draw_circle(Vector2(0.68, 0.34) * s, 0.09 * s, tint)
				draw_colored_polygon(_scaled([Vector2(0.14, 0.78), Vector2(0.4, 0.38), Vector2(0.6, 0.78)], s), tint)
				draw_colored_polygon(_scaled([Vector2(0.48, 0.78), Vector2(0.66, 0.52), Vector2(0.86, 0.78)], s), tint)
			"weather":
				draw_circle(Vector2(0.62, 0.36) * s, 0.16 * s, Color(1.0, 0.83, 0.25))
				for p in [Vector2(0.36, 0.62), Vector2(0.52, 0.54), Vector2(0.68, 0.64)]:
					draw_circle(p * s, 0.15 * s, tint)
				draw_rect(Rect2(Vector2(0.32, 0.62) * s, Vector2(0.38, 0.15) * s), tint)
			"gear":
				var c := Vector2(0.5, 0.5) * s
				for i in range(8):
					var dir := Vector2.from_angle(TAU * float(i) / 8.0)
					draw_line(c, c + dir * 0.36 * s, tint, 0.13 * s)
				draw_circle(c, 0.27 * s, tint)
				draw_circle(c, 0.11 * s, Color(0.42, 0.43, 0.47))
			"back":
				draw_polyline(_scaled([Vector2(0.62, 0.2), Vector2(0.32, 0.5), Vector2(0.62, 0.8)], s), tint, maxf(2.0, 0.1 * s), true)
			"signal":
				for i in range(4):
					var h: float = size.y * (0.4 + 0.2 * float(i))
					var col := tint if filled else Color(tint, 0.25)
					draw_rect(Rect2(float(i) * 4.0, size.y - h, 3.0, h), col)
			"battery":
				draw_rect(Rect2(0.5, 0.5, size.x - 4.0, size.y - 1.0), Color(tint, 0.45), false, 1.0)
				draw_rect(Rect2(2.0, 2.0, (size.x - 7.0) * 0.72, size.y - 4.0), tint)
				draw_rect(Rect2(size.x - 3.0, size.y * 0.32, 2.0, size.y * 0.36), Color(tint, 0.45))
			"lens":
				draw_circle(size * 0.5, s * 0.5, Color(0.0, 0.0, 0.0))
				draw_circle(size * 0.5, s * 0.3, Color(0.05, 0.06, 0.12))
				draw_circle(size * Vector2(0.38, 0.38), s * 0.08, Color(0.32, 0.36, 0.5))
			"pulse":
				var center := size * 0.5
				for i in range(2):
					var t: float = fmod(phase + float(i) * 0.5, 1.0)
					draw_arc(center, s * (0.3 + 0.2 * t), 0.0, TAU, 64, Color(tint, (1.0 - t) * 0.4), 1.5, true)

	func _handset(s: float, turn: float) -> void:
		draw_set_transform(size * 0.5, turn, Vector2.ONE)
		var c := Vector2(0.2, -0.2) * s
		var r: float = 0.46 * s
		draw_arc(c, r, deg_to_rad(100.0), deg_to_rad(170.0), 20, tint, 0.15 * s, true)
		for a in [100.0, 170.0]:
			draw_circle(c + Vector2.from_angle(deg_to_rad(a)) * r, 0.14 * s, tint)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _scaled(points: Array, s: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for p in points:
			out.append(p * s)
		return out


func _ready() -> void:
	layer = 90
	_register_action()
	_load_prologue_content()
	set_process(false)


func _register_action() -> void:
	if InputMap.has_action(ACTION):
		return
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_P
	InputMap.action_add_event(ACTION, key)
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_RIGHT_STICK
	InputMap.action_add_event(ACTION, pad)


# Пролог, «Обычный день»: суббота, новость про оленя, переписка про курсовую,
# контакты «Папа» и «Сэм», которым Итан так и не звонит.
func _load_prologue_content() -> void:
	date_text = "Суббота"
	add_news("Жители окраины снова жалуются на крупного чёрного оленя у дороги", "", "Сегодня")
	add_news("К вечеру в городе обещают дождь", "", "Сегодня")
	add_contact("Папа", "", PUT_OFF_CALL_LINE)
	add_contact("Сэм", "", PUT_OFF_CALL_LINE)
	add_message(CLASSMATES_CHAT, "Кто в понедельник сдаёт курсовую?", false, false)
	add_message(CLASSMATES_CHAT, "Я не успеваю", false, false)
	add_message(CLASSMATES_CHAT, "Итан, ты?", false, false)
	_unread.clear()


# ─── Наполнение ──────────────────────────────────────────────

func add_news(title: String, body: String = "", time: String = "") -> void:
	_news.push_front({"title": title, "body": body, "time": time})
	_refresh_if_on(Page.NEWS)


# line: реплика Итана при нажатии на контакт, вместо звонка
func add_contact(contact_name: String, note: String = "", line: String = "") -> void:
	for c in _contacts:
		if c.name == contact_name:
			c.note = note
			c.line = line
			return
	_contacts.append({"name": contact_name, "note": note, "line": line})
	_refresh_if_on(Page.CONTACTS)


# notify: показать всплывашку с вибрацией и пометить как непрочитанное
func add_message(chat: String, text: String, mine: bool = false, notify: bool = true) -> void:
	if not _chats.has(chat):
		_chats[chat] = []
	_chats[chat].append({"text": text, "mine": mine})
	if notify and not mine:
		if not (_shown and _page == Page.THREAD and _thread == chat):
			_unread[chat] = int(_unread.get(chat, 0)) + 1
			_show_toast(chat, text)
		message_received.emit(chat, text)
	if _shown and (_page == Page.HOME or _page == Page.CHATS or (_page == Page.THREAD and _thread == chat)):
		_render()


# Журнал: найденная записка остаётся в телефоне, Итан её сфотографировал
func add_note(title: String, text: String) -> void:
	for n in _notes:
		if n.title == title:
			return
	_notes.append({"title": title, "text": text})
	_refresh_if_on(Page.NOTES)


func notes_count() -> int:
	return _notes.size()


func clear_content() -> void:
	_news.clear()
	_chats.clear()
	_unread.clear()
	_contacts.clear()
	_recent_calls.clear()
	_notes.clear()
	if _shown:
		_render()


func unread_count() -> int:
	var total := 0
	for n in _unread.values():
		total += int(n)
	return total


func get_state() -> Dictionary:
	return {"news": _news.duplicate(true), "chats": _chats.duplicate(true), "unread": _unread.duplicate(),
		"contacts": _contacts.duplicate(true), "calls": _recent_calls.duplicate(true), "notes": _notes.duplicate(true),
		"enabled": enabled, "has_signal": has_signal, "clock": clock_text, "date": date_text}


func set_state(state: Dictionary) -> void:
	_news = state.get("news", []).duplicate(true)
	_chats = state.get("chats", {}).duplicate(true)
	_unread = state.get("unread", {}).duplicate()
	_contacts = state.get("contacts", []).duplicate(true)
	_recent_calls = state.get("calls", []).duplicate(true)
	_notes = state.get("notes", []).duplicate(true)
	enabled = state.get("enabled", true)
	has_signal = state.get("has_signal", true)
	clock_text = state.get("clock", "")
	date_text = state.get("date", "")
	if _shown:
		_render()


# ─── Открыть и закрыть ──────────────────────────────────────

func is_open() -> bool:
	return _shown


func is_ringing() -> bool:
	return _ringing


func can_open() -> bool:
	var p := _player()
	if not enabled or p == null or _call_active or GameManager.game_ended:
		return false
	if GameManager.is_backpack_open or GameManager.is_reading_note:
		return false
	if p.get("is_in_cutscene") == true and not allow_in_cutscene:
		return false
	return p.get("is_dead") != true and p.get("is_hiding") != true


func open(page: int = Page.HOME) -> bool:
	if _shown or not can_open():
		return false
	_show_ui()
	_page = page
	_render()
	opened.emit()
	return true


func close() -> void:
	if _call_active:
		return
	_hide_ui()


func _show_ui() -> void:
	_ensure_ui()
	_shown = true
	_lock_player()
	_body.visible = true
	_toast.visible = false
	_toast_left = 0.0
	_body.position.y = get_viewport().get_visible_rect().size.y
	var target_y: float = _body_target_y()
	var tw := create_tween()
	tw.tween_property(_body, "position:y", target_y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_update_processing()


func _hide_ui() -> void:
	if not _shown:
		return
	_shown = false
	_unlock_player()
	if _built:
		_body.visible = false
	_update_processing()
	closed.emit()


func _body_target_y() -> float:
	return get_viewport().get_visible_rect().size.y - BODY_SIZE.y - BODY_MARGIN * 0.6


func _player() -> Node:
	var p = GameManager.player_ref
	return p if is_instance_valid(p) else null


# Управление игроком замораживается тем же флагом, что и у рюкзака. is_in_cutscene
# не подходит: при нём лесоруб перестаёт замечать игрока.
func _lock_player() -> void:
	_locked = true
	GameManager.is_backpack_open = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _unlock_player() -> void:
	if not _locked:
		return
	_locked = false
	_finish_unlock()


# Игрок опрашивает клавиши в физическом кадре: если отпустить его сразу, Esc выпустит мышь
func _finish_unlock() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if _locked:
		return
	GameManager.is_backpack_open = false
	if _player() != null and not GameManager.game_ended:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ─── Звонок ─────────────────────────────────────────────────

func incoming_call(caller: String, opts: Dictionary = {}) -> String:
	if _call_active:
		return BUSY
	_call_active = true
	_return_after_call = _shown
	var result := MISSED
	while true:
		_start_ringing(caller, opts)
		result = await _call_resolved
		var wait: float = float(opts.get("repeat_after", 0.0))
		if result != DECLINED or wait <= 0.0:
			break
		_remember_call(caller, result)
		_hide_ui()
		_say(str(opts.get("decline_line", "")))
		await get_tree().create_timer(wait).timeout
		if _player() == null or GameManager.game_ended:
			result = MISSED
			break
	_call_active = false
	_remember_call(caller, result)
	if _return_after_call and result != ANSWERED and can_open_after_call():
		_page = Page.HOME
		_render()
	else:
		_hide_ui()
	match result:
		ANSWERED:
			call_answered.emit(caller)
		DECLINED:
			call_declined.emit(caller)
		MISSED:
			call_missed.emit(caller)
	return result


# Экран уже открыт, поэтому флаг рюкзака здесь не считается помехой.
func can_open_after_call() -> bool:
	var p := _player()
	return p != null and p.get("is_dead") != true and not GameManager.game_ended


func _remember_call(caller: String, result: String) -> void:
	_recent_calls.push_front({"name": caller, "result": result})
	_recent_calls.resize(mini(_recent_calls.size(), MAX_RECENT_CALLS))


func _start_ringing(caller: String, opts: Dictionary) -> void:
	if GameManager.is_backpack_open and not _locked:
		GameManager.close_backpack()
	if GameManager.is_reading_note:
		GameManager.close_note()
	_caller = caller
	_call_opts = opts
	_ringing = true
	_ring_left = float(opts.get("ring_seconds", 0.0))
	_ring_clock = 0.0
	_guard_left = ANSWER_GUARD
	if not _shown:
		_show_ui()
	_page = Page.CALL
	_render()
	_ring_pulse()
	_update_processing()


func _resolve_call(result: String) -> void:
	if not _ringing:
		return
	_ringing = false
	_answer_btn = null
	_decline_btn = null
	_stop_sound()
	_update_processing()
	_call_resolved.emit(result)


func _on_answer() -> void:
	if _guard_left <= 0.0:
		_play(SND_TAP)
		_resolve_call(ANSWERED)


func _on_decline() -> void:
	if _guard_left <= 0.0 and bool(_call_opts.get("can_decline", true)):
		_play(SND_TAP)
		_resolve_call(DECLINED)


func _ring_pulse() -> void:
	_play(SND_VIBRATE)
	var radius: float = float(_call_opts.get("noise_radius", 0.0))
	var p := _player()
	if radius > 0.0 and p is Node3D:
		GameManager.emit_noise((p as Node3D).global_position, radius, "phone")


func _say(line: String) -> void:
	if line != "" and GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		GameManager.ui_ref.call("show_hint", line, 3.0)


# ─── Кадр и ввод ────────────────────────────────────────────

func _update_processing() -> void:
	set_process(_shown or _ringing or _toast_left > 0.0)


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		if _toast_left <= 0.0:
			_toast.visible = false
			_update_processing()
	if _shown:
		# Рюкзак и его клавиши могли снять блокировку
		GameManager.is_backpack_open = true
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		var p := _player()
		if p == null or p.get("is_dead") == true or GameManager.game_ended:
			if _ringing:
				_resolve_call(MISSED)
			if not _call_active:
				_hide_ui()
			return
	if not _ringing:
		return
	if _guard_left > 0.0:
		_guard_left -= delta
		if _guard_left <= 0.0:
			_focus_call_button()
	_ring_clock += delta
	if _ring_clock >= RING_PERIOD:
		_ring_clock = 0.0
		_ring_pulse()
	if _ring_left > 0.0:
		_ring_left -= delta
		if _ring_left <= 0.0:
			_resolve_call(MISSED)


# На геймпаде фокус ставится на «Сбросить»: случайное нажатие A не примет звонок.
func _focus_call_button() -> void:
	if not GameManager.is_gamepad:
		return
	var btn: Button = _decline_btn if is_instance_valid(_decline_btn) else _answer_btn
	if is_instance_valid(btn):
		btn.grab_focus()


func _focus_first_button() -> void:
	if not GameManager.is_gamepad or _page == Page.CALL:
		return
	var btn := _first_button(_list)
	if btn != null:
		btn.grab_focus()


func _first_button(node: Node) -> Button:
	for child in node.get_children():
		if child is Button:
			return child
		var found := _first_button(child)
		if found != null:
			return found
	return null


func _input(event: InputEvent) -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	if event.is_action_pressed(ACTION) and not event.is_echo():
		if not _call_active:
			if _shown:
				close()
			else:
				open()
			if _shown or can_open():
				get_viewport().set_input_as_handled()
		return
	if not _shown:
		return
	var back := false
	var swallow := false
	if event is InputEventKey and event.pressed and not event.echo:
		back = event.keycode == KEY_ESCAPE
		swallow = event.keycode in [KEY_TAB, KEY_X]
	elif event is InputEventJoypadButton and event.pressed:
		back = event.button_index == JOY_BUTTON_B
		swallow = event.button_index in [JOY_BUTTON_X, JOY_BUTTON_START, JOY_BUTTON_BACK]
	if back:
		_go_back()
	if back or swallow:
		get_viewport().set_input_as_handled()


func _go_back() -> void:
	if _ringing:
		_on_decline()
	elif _page == Page.THREAD:
		_open_page(Page.CHATS)
	elif _page == Page.NOTE:
		_open_page(Page.NOTES)
	elif _page != Page.HOME:
		_open_page(Page.HOME)
	else:
		close()


# ─── Корпус ─────────────────────────────────────────────────

func _ensure_ui() -> void:
	if _built:
		return
	_built = true
	_font = _system_font(400)
	_font_bold = _system_font(600)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Theme.new()
	_root.theme.default_font = _font
	add_child(_root)

	_body = Control.new()
	_body.size = BODY_SIZE
	_body.position.x = get_viewport().get_visible_rect().size.x - BODY_SIZE.x - BODY_MARGIN
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.visible = false
	_root.add_child(_body)

	# Кнопки на рёбрах лежат под корпусом и выступают на пару пикселей
	_side_key(Vector2(-2, 128), Vector2(4, 46))
	_side_key(Vector2(-2, 186), Vector2(4, 46))
	_side_key(Vector2(BODY_SIZE.x - 2, 158), Vector2(4, 74))

	var frame := Panel.new()
	frame.size = BODY_SIZE
	var frame_style := _box(C_FRAME, 43, 2, C_METAL)
	frame_style.shadow_color = Color(0, 0, 0, 0.55)
	frame_style.shadow_size = 22
	frame.add_theme_stylebox_override("panel", frame_style)
	_body.add_child(frame)

	var screen := Control.new()
	screen.position = Vector2(BEZEL, BEZEL)
	screen.size = BODY_SIZE - Vector2(BEZEL, BEZEL) * 2.0
	_body.add_child(screen)

	_wall = ColorRect.new()
	_wall.size = screen.size
	_wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = WALL_SHADER
	mat.shader = shader
	mat.set_shader_parameter("corner", SCREEN_RADIUS)
	mat.set_shader_parameter("box", screen.size)
	_wall.material = mat
	screen.add_child(_wall)

	_build_status_bar(screen)

	_column = VBoxContainer.new()
	_column.position = Vector2(SIDE_PADDING, STATUS_HEIGHT)
	_column.size = Vector2(screen.size.x - SIDE_PADDING * 2.0, screen.size.y - STATUS_HEIGHT - INDICATOR_HEIGHT)
	_column.add_theme_constant_override("separation", 8)
	screen.add_child(_column)

	_head = HBoxContainer.new()
	_head.custom_minimum_size.y = 42
	_head.add_theme_constant_override("separation", 6)
	_column.add_child(_head)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.follow_focus = true
	_column.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 0)
	_scroll.add_child(_list)

	# Поле ввода только для вида: Итан отвечает по сюжету, а не с клавиатуры
	_foot = PanelContainer.new()
	_foot.add_theme_stylebox_override("panel", _box(C_CARD, 18, 1, C_LINE, 9))
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := _label("Сообщение", 14, C_DIM)
	_foot.add_child(hint)
	_column.add_child(_foot)

	_indicator = Button.new()
	_indicator.size = Vector2(150, INDICATOR_HEIGHT)
	_indicator.position = Vector2((screen.size.x - 150.0) * 0.5, screen.size.y - INDICATOR_HEIGHT)
	_indicator.flat = true
	_indicator.focus_mode = Control.FOCUS_NONE
	_indicator.pressed.connect(func():
		if not _ringing and _page != Page.HOME:
			_tap_page(Page.HOME)
	)
	screen.add_child(_indicator)
	var pill := Panel.new()
	pill.size = Vector2(108, 4)
	pill.position = Vector2(21, 11)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.72), 2))
	_indicator.add_child(pill)

	_build_toast()

	_audio = AudioStreamPlayer.new()
	add_child(_audio)


func _system_font(weight: int) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Arial"])
	f.font_weight = weight
	return f


func _side_key(pos: Vector2, side: Vector2) -> void:
	var key := Panel.new()
	key.position = pos
	key.size = side
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.add_theme_stylebox_override("panel", _box(C_METAL.darkened(0.25), 2))
	_body.add_child(key)


func _build_status_bar(screen: Control) -> void:
	_clock = _label("", 14, C_TEXT, true)
	_clock.position = Vector2(26, 11)
	screen.add_child(_clock)

	var lens := Glyph.new("lens", Vector2(15, 15))
	lens.position = Vector2((screen.size.x - 15.0) * 0.5, 11)
	screen.add_child(lens)

	_signal_glyph = Glyph.new("signal", Vector2(15, 11))
	_signal_glyph.position = Vector2(screen.size.x - 66, 15)
	screen.add_child(_signal_glyph)

	var battery := Glyph.new("battery", Vector2(26, 12))
	battery.position = Vector2(screen.size.x - 46, 14)
	screen.add_child(battery)


func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.add_theme_stylebox_override("panel", _box(Color(0.1, 0.1, 0.115, 0.95), 18, 0, Color.BLACK, 12))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_toast.offset_left = -374.0
	_toast.offset_right = -34.0
	_toast.offset_top = -124.0
	_toast.offset_bottom = -34.0
	_root.add_child(_toast)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_toast.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 7)
	column.add_child(top)
	var tile := Panel.new()
	tile.custom_minimum_size = Vector2(18, 18)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", _box(C_GREEN, 5))
	tile.add_child(Glyph.new("message", Vector2(18, 18)))
	top.add_child(tile)
	top.add_child(_label("СООБЩЕНИЯ", 11, C_DIM))
	top.add_child(_expander())
	top.add_child(_label("P открыть", 11, C_DIM))

	_toast_name = _label("", 15, C_TEXT, true)
	column.add_child(_toast_name)
	_toast_text = _label("", 14, C_TEXT)
	_toast_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_toast_text.clip_text = true
	column.add_child(_toast_text)


# ─── Экраны ─────────────────────────────────────────────────

func _tap_page(page: int) -> void:
	_play(SND_TAP)
	_open_page(page)


func _open_page(page: int) -> void:
	_page = page
	_render()
	page_opened.emit(page)


func _refresh_if_on(page: int) -> void:
	if _shown and _page == page:
		_render()


func _now_text() -> String:
	return clock_text if clock_text != "" else Time.get_time_string_from_system().substr(0, 5)


func _today_text() -> String:
	if date_text != "":
		return date_text
	var d := Time.get_date_dict_from_system()
	return "%s, %d %s" % [WEEKDAYS[int(d.weekday)], int(d.day), MONTHS[int(d.month) - 1]]


func _set_wall(top: Color, bottom: Color, glow: Color) -> void:
	var mat := _wall.material as ShaderMaterial
	mat.set_shader_parameter("top_color", Vector3(top.r, top.g, top.b))
	mat.set_shader_parameter("bottom_color", Vector3(bottom.r, bottom.g, bottom.b))
	mat.set_shader_parameter("glow_color", Vector3(glow.r, glow.g, glow.b))


func _render() -> void:
	if not _built:
		return
	_clear(_head)
	_clear(_list)
	_answer_btn = null
	_decline_btn = null
	_head.visible = _page != Page.HOME and _page != Page.CALL
	_foot.visible = _page == Page.THREAD
	_clock.text = _now_text()
	_signal_glyph.filled = has_signal
	_signal_glyph.queue_redraw()
	match _page:
		Page.HOME:
			_set_wall(Color(0.09, 0.13, 0.24), Color(0.03, 0.04, 0.09), Color(0.2, 0.13, 0.3))
			_render_home()
		Page.NEWS:
			_set_wall(C_APP, C_APP, C_BLACK)
			_render_header("Новости")
			_render_news()
		Page.CHATS:
			_set_wall(C_APP, C_APP, C_BLACK)
			_render_header("Сообщения")
			_render_chats()
		Page.CONTACTS:
			_set_wall(C_APP, C_APP, C_BLACK)
			_render_header("Телефон")
			_render_contacts()
		Page.THREAD:
			_set_wall(C_APP, C_APP, C_BLACK)
			_render_thread_header()
			_render_thread()
		Page.NOTES:
			_set_wall(C_APP, C_APP, C_BLACK)
			_render_header("Записки")
			_render_notes()
		Page.NOTE:
			_set_wall(C_APP, C_APP, C_BLACK)
			_render_header(str(_notes[_note_open].title))
			_list.add_child(_wrapped(_notes[_note_open].text, 15, C_TEXT))
			_release_mouse(_list)
		Page.CALL:
			_set_wall(Color(0.08, 0.1, 0.16), Color(0.02, 0.025, 0.05), Color(0.08, 0.1, 0.16))
			_render_call()
	_scroll.scroll_vertical = 0
	_focus_first_button.call_deferred()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _render_header(title: String) -> void:
	_head.add_child(_back_button(func(): _go_back_tapped()))
	_head.add_child(_label(title, 21, C_TEXT, true))


func _go_back_tapped() -> void:
	_play(SND_TAP)
	_go_back()


func _back_button(action: Callable) -> Button:
	var b := _plain_button(action)
	b.custom_minimum_size = Vector2(30, 42)
	var glyph := Glyph.new("back", Vector2(24, 24), C_BLUE)
	glyph.position = Vector2(0, 9)
	b.add_child(glyph)
	return b


func _render_home() -> void:
	_list.add_child(_gap(30))
	_list.add_child(_centered(_now_text(), 62, C_TEXT))
	_list.add_child(_centered(_today_text(), 14, Color(1, 1, 1, 0.8)))
	_list.add_child(_gap(232))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.add_child(_app_icon("Камера", "camera", C_GREY, -1))
	row.add_child(_app_icon("Записки", "news", C_ORANGE, Page.NOTES))
	row.add_child(_app_icon("Погода", "weather", Color(0.2, 0.48, 0.82), -1))
	row.add_child(_app_icon("Настройки", "gear", C_GREY, -1))
	_list.add_child(row)
	_list.add_child(_gap(16))

	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", _box(Color(1, 1, 1, 0.13), 24, 0, Color.BLACK, 9))
	var dock_row := HBoxContainer.new()
	dock_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_row.add_theme_constant_override("separation", 14)
	dock_row.add_child(_app_icon("", "phone", C_GREEN, Page.CONTACTS))
	dock_row.add_child(_app_icon("", "message", C_GREEN, Page.CHATS, unread_count()))
	dock_row.add_child(_app_icon("", "news", C_RED, Page.NEWS))
	dock.add_child(dock_row)
	_list.add_child(dock)
	_release_mouse(_list)


func _app_icon(title: String, glyph: String, color: Color, page: int, badge: int = 0) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	var b := _plain_button(func(): _tap_app(page))
	b.custom_minimum_size = Vector2(52, 52)
	var style := _box(color, 13)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.08), 13))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.2), 13))
	var mark := Glyph.new(glyph, Vector2(38, 38))
	mark.position = Vector2(7, 7)
	b.add_child(mark)
	if badge > 0:
		var dot := Panel.new()
		dot.size = Vector2(20, 20)
		dot.position = Vector2(39, -6)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.add_theme_stylebox_override("panel", _box(C_RED, 10))
		var count := _label(str(badge), 12, Color.WHITE, true)
		count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_child(count)
		b.add_child(dot)
	column.add_child(b)
	if title != "":
		var caption := _label(title, 11, Color(1, 1, 1, 0.9))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
	return column


func _tap_app(page: int) -> void:
	if page >= 0:
		_tap_page(page)
	else:
		_play(SND_TAP)
		_say("Сейчас не до этого")


func _render_news() -> void:
	if _news.is_empty():
		_list.add_child(_centered("Новостей нет", 15, C_DIM))
	for item in _news:
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation", 3)
		var meta: String = "НОВОСТИ ОКРУГА" if item.time == "" else "НОВОСТИ ОКРУГА  ·  %s" % item.time
		entry.add_child(_gap(8))
		entry.add_child(_label(meta, 11, C_RED, true))
		entry.add_child(_wrapped(item.title, 16, C_TEXT, true))
		if item.body != "":
			entry.add_child(_wrapped(item.body, 13, C_DIM))
		entry.add_child(_gap(8))
		entry.add_child(_divider(0.0))
		_list.add_child(entry)
	_release_mouse(_list)


func _render_chats() -> void:
	if _chats.is_empty():
		_list.add_child(_centered("Сообщений нет", 15, C_DIM))
	for chat in _chats:
		var msgs: Array = _chats[chat]
		var last: String = msgs[-1].text if not msgs.is_empty() else ""
		var unread := int(_unread.get(chat, 0))
		var tile := _tile(66, func(): _open_thread(chat))
		var row: HBoxContainer = tile.get_child(0)
		row.add_child(_avatar(chat, 46))
		var text := _text_column()
		text.add_child(_label(chat, 15, C_TEXT, true))
		var preview := _label(last, 13, C_DIM)
		preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		preview.clip_text = true
		text.add_child(preview)
		row.add_child(text)
		if unread > 0:
			row.add_child(_badge(unread))
		_list.add_child(tile)
		_list.add_child(_divider(58.0))
	_release_mouse(_list)


func _open_thread(chat: String) -> void:
	_play(SND_TAP)
	_thread = chat
	_unread.erase(chat)
	_open_page(Page.THREAD)


func _render_thread_header() -> void:
	_head.add_child(_back_button(func(): _go_back_tapped()))
	_head.add_child(_avatar(_thread, 32))
	_head.add_child(_label(_thread, 16, C_TEXT, true))


func _render_thread() -> void:
	_list.add_child(_centered("Сегодня", 12, C_DIM))
	for msg in _chats.get(_thread, []):
		var line := HBoxContainer.new()
		var bubble := PanelContainer.new()
		var style := _box(C_BLUE if msg.mine else C_CARD, 16, 0, Color.BLACK, 0)
		style.set_content_margin(SIDE_LEFT, 12)
		style.set_content_margin(SIDE_RIGHT, 12)
		style.set_content_margin(SIDE_TOP, 7)
		style.set_content_margin(SIDE_BOTTOM, 8)
		if msg.mine:
			style.corner_radius_bottom_right = 4
		else:
			style.corner_radius_bottom_left = 4
		bubble.add_theme_stylebox_override("panel", style)
		var text := _label(msg.text, 14, Color.WHITE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# Короткое сообщение занимает свою ширину, длинное переносится
		var plain_width: float = _font.get_string_size(msg.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		text.custom_minimum_size.x = minf(ceilf(plain_width) + 2.0, 176.0)
		bubble.add_child(text)
		if msg.mine:
			line.add_child(_expander())
			line.add_child(bubble)
		else:
			line.add_child(bubble)
			line.add_child(_expander())
		_list.add_child(_gap(5))
		_list.add_child(line)
	_release_mouse(_list)
	_scroll_to_end.call_deferred()


func _scroll_to_end() -> void:
	await get_tree().process_frame
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _render_notes() -> void:
	if _notes.is_empty():
		_list.add_child(_centered("Записок нет", 15, C_DIM))
	for i in range(_notes.size()):
		var tile := _tile(52, _open_note.bind(i))
		var row: HBoxContainer = tile.get_child(0)
		row.add_child(_label(str(_notes[i].title), 15, C_TEXT, true))
		_list.add_child(tile)
		_list.add_child(_divider(0.0))
	_release_mouse(_list)


func _open_note(index: int) -> void:
	_play(SND_TAP)
	_note_open = index
	_open_page(Page.NOTE)


func _render_contacts() -> void:
	if not _recent_calls.is_empty():
		_list.add_child(_section("Недавние"))
		for call in _recent_calls:
			var missed: bool = call.result != ANSWERED
			var note: String = "принятый" if not missed else ("сброшенный" if call.result == DECLINED else "пропущенный")
			_list.add_child(_person_row(call.name, note, C_RED if missed else C_TEXT))
			_list.add_child(_divider(52.0))
	_list.add_child(_section("Контакты"))
	if _contacts.is_empty():
		_list.add_child(_centered("Контактов нет", 15, C_DIM))
	for c in _contacts:
		_list.add_child(_person_row(c.name, c.note, C_TEXT))
		_list.add_child(_divider(52.0))
	_release_mouse(_list)


func _person_row(person: String, note: String, name_color: Color) -> Button:
	var tile := _tile(56, func(): _press_contact(person))
	var row: HBoxContainer = tile.get_child(0)
	row.add_child(_avatar(person, 40))
	var text := _text_column()
	text.add_child(_label(person, 15, name_color, true))
	if note != "":
		text.add_child(_label(note, 12, C_DIM))
	row.add_child(text)
	var call_mark := Glyph.new("phone", Vector2(22, 22), C_BLUE)
	row.add_child(call_mark)
	return tile


func _press_contact(contact_name: String) -> void:
	_play(SND_TAP)
	contact_pressed.emit(contact_name)
	var line := ""
	for c in _contacts:
		if c.name == contact_name:
			line = str(c.get("line", ""))
	if line != "":
		_say(line)
	elif not has_signal:
		_say("Нет сети")
	elif _chats.has(contact_name):
		_open_thread(contact_name)


func _render_call() -> void:
	_list.add_child(_gap(54))
	var stage := CenterContainer.new()
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(190, 190)
	var pulse := Glyph.new("pulse", Vector2(190, 190), Color.WHITE)
	holder.add_child(pulse)
	var face := _avatar(_caller, 104)
	face.position = Vector2(43, 43)
	holder.add_child(face)
	stage.add_child(holder)
	_list.add_child(stage)
	var tw := pulse.create_tween().set_loops()
	tw.tween_method(pulse.set_phase, 0.0, 1.0, 1.7)
	_list.add_child(_gap(4))
	_list.add_child(_centered(_caller, 26, C_TEXT))
	_list.add_child(_gap(4))
	_list.add_child(_centered(str(_call_opts.get("subtitle", "Входящий вызов")), 14, C_DIM))
	_list.add_child(_gap(128))

	var buttons := HBoxContainer.new()
	buttons.add_child(_gap(8))
	if bool(_call_opts.get("can_decline", true)):
		var left := _call_button("Сбросить", "hangup", C_RED, _on_decline)
		_decline_btn = left.get_child(0)
		buttons.add_child(left)
	buttons.add_child(_expander())
	var right := _call_button("Ответить", "phone", C_GREEN.darkened(0.08), _on_answer)
	_answer_btn = right.get_child(0)
	buttons.add_child(right)
	buttons.add_child(_gap(8))
	_list.add_child(buttons)
	_release_mouse(_list)


func _call_button(title: String, glyph: String, color: Color, action: Callable) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	var b := _plain_button(action)
	b.custom_minimum_size = Vector2(68, 68)
	b.add_theme_stylebox_override("normal", _box(color, 34))
	b.add_theme_stylebox_override("hover", _box(color.lightened(0.12), 34))
	b.add_theme_stylebox_override("pressed", _box(color.darkened(0.18), 34))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), 34, 2, Color.WHITE))
	var mark := Glyph.new(glyph, Vector2(38, 38))
	mark.position = Vector2(15, 15)
	b.add_child(mark)
	column.add_child(b)
	column.add_child(_centered(title, 13, C_TEXT))
	return column


func _show_toast(chat: String, text: String) -> void:
	_ensure_ui()
	_play(SND_VIBRATE)
	if _shown:
		return
	_toast_name.text = chat
	_toast_text.text = text
	_toast.visible = true
	_toast_left = TOAST_SECONDS
	_update_processing()


func _play(path: String) -> void:
	_ensure_ui()
	if not ResourceLoader.exists(path):
		return
	_audio.stream = load(path)
	_audio.play()


func _stop_sound() -> void:
	if _built:
		_audio.stop()


# ─── Заготовки элементов ────────────────────────────────────

func _box(color: Color, radius: int, border: int = 0, border_color: Color = Color.BLACK, pad: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.corner_detail = 12
	if pad > 0:
		s.set_content_margin_all(pad)
	return s


func _label(text: String, size_px: int, color: Color, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", _font_bold)
	return l


func _wrapped(text: String, size_px: int, color: Color, bold: bool = false) -> Label:
	var l := _label(text, size_px, color, bold)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _centered(text: String, size_px: int, color: Color) -> Label:
	var l := _wrapped(text, size_px, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _gap(amount: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(amount, amount)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _expander() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _divider(indent: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(indent))
	var line := ColorRect.new()
	line.color = C_LINE
	line.custom_minimum_size.y = 1
	m.add_child(line)
	return m


func _section(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_child(_gap(8))
	v.add_child(_label(title, 13, C_DIM, true))
	v.add_child(_gap(3))
	return v


func _text_column() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	return v


func _avatar(person: String, side: float) -> Panel:
	var circle := Panel.new()
	circle.custom_minimum_size = Vector2(side, side)
	circle.size = Vector2(side, side)
	circle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var unknown := person.begins_with("Неизвестн") or person == ""
	var color: Color = C_GREY if unknown else AVATAR_COLORS[abs(person.hash()) % AVATAR_COLORS.size()]
	circle.add_theme_stylebox_override("panel", _box(color, int(side * 0.5)))
	if unknown:
		var mark := Glyph.new("person", Vector2(side, side), Color(1, 1, 1, 0.92))
		circle.add_child(mark)
	else:
		var letter := _label(person.substr(0, 1).to_upper(), int(side * 0.44), Color.WHITE, true)
		letter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		circle.add_child(letter)
	return circle


func _badge(count: int) -> Panel:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(22, 22)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.add_theme_stylebox_override("panel", _box(C_BLUE, 11))
	var number := _label(str(count), 12, Color.WHITE, true)
	number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_child(number)
	return dot


func _plain_button(action: Callable) -> Button:
	var b := Button.new()
	var empty := StyleBoxEmpty.new()
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", empty)
	b.add_theme_stylebox_override("pressed", empty)
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), 12, 2, C_BLUE))
	b.pressed.connect(action)
	return b


# Строка-кнопка: первый дочерний узел — ряд для содержимого
func _tile(height: float, action: Callable) -> Button:
	var b := _plain_button(action)
	b.custom_minimum_size.y = height
	b.add_theme_stylebox_override("hover", _box(Color(1, 1, 1, 0.04), 10))
	b.add_theme_stylebox_override("pressed", _box(C_PRESS, 10))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	b.add_child(row)
	return b


# Всё, кроме кнопок, пропускает мышь: иначе карточки перехватывают нажатия
func _release_mouse(node: Node) -> void:
	for child in node.get_children():
		if child is Control and not (child is Button):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_release_mouse(child)
