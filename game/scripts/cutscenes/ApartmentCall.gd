extends Node

# Квартира Итана (пролог): звонок с неизвестного номера (Jan-ky, ставит Main на карте «Квартира»).
# Задачи «Обычного дня» (пицца, кофе, стирка, телевизор) — геймплей thebekshdet; пока их нет,
# телефон звонит сам через RING_AFTER секунд. По сюжету перед звонком начинается дождь
# и за стеной лает собака.
#   [ЛКМ / E] «Ответить» → кат-сцена «Звонок» → улица.
#   [ПКМ / Q] «Сбросить» → через несколько секунд звонят снова, Итан: «Да что ж такое…».
# Когда thebekshdet сделает задачи, достаточно вызвать ring() после последней задачи
# и поставить auto_ring = false.

const RING_AFTER := 35.0
const RAIN_AT := 22.0
const REDIAL_AFTER := 5.0
const SFX := "res://assets/audio/cutscenes/"

var auto_ring := true
var _t := 0.0
var _ringing := false
var _answered := false
var _declines := 0
var _redial_at := -1.0
var _rain_started := false
var _vibrate: AudioStreamPlayer
var _layer: CanvasLayer
var _panel: PanelContainer
var _sub: Label
var _sub_tween: Tween


func _ready() -> void:
	name = "ApartmentCall"
	_build_ui()


func _process(delta: float) -> void:
	if _answered:
		return
	_t += delta
	if not _rain_started and _t >= RAIN_AT:
		_rain_started = true
		_play("amb_rain_window", -14.0, true)
		_play("dog_bark_wall", -12.0)
	if auto_ring and not _ringing and _declines == 0 and _t >= RING_AFTER:
		ring()
	if _redial_at > 0.0 and _t >= _redial_at:
		_redial_at = -1.0
		ring()
		_say("ИТАН", "Да что ж такое…", 2.2)


func ring() -> void:
	if _ringing or _answered:
		return
	_ringing = true
	_vibrate = _play("phone_vibrate", -4.0, true)
	_panel.visible = true


func _input(event: InputEvent) -> void:
	if not _ringing or _answered:
		return
	var answer: bool = event.is_action_pressed("interact") or event.is_action_pressed("pick_up")
	var decline: bool = event.is_action_pressed("drop_item") or (event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).physical_keycode == KEY_Q)
	if answer:
		get_viewport().set_input_as_handled()
		_answer()
	elif decline:
		get_viewport().set_input_as_handled()
		_decline()


func _answer() -> void:
	_answered = true
	_ringing = false
	_panel.visible = false
	_play("phone_tap", -6.0)
	if is_instance_valid(_vibrate):
		_vibrate.stop()
	var player = GameManager.player_ref
	if is_instance_valid(player):
		player.set("is_in_cutscene", true)
	await get_tree().create_timer(0.25).timeout
	preload("res://scripts/cutscenes/PrologueFlow.gd").answer_call(get_tree())


func _decline() -> void:
	_ringing = false
	_declines += 1
	_panel.visible = false
	_play("phone_tap", -8.0)
	if is_instance_valid(_vibrate):
		_vibrate.stop()
	_redial_at = _t + REDIAL_AFTER


func _play(sound: String, db: float, loop: bool = false) -> AudioStreamPlayer:
	var st: AudioStream = load(SFX + sound + ".wav")
	if st == null:
		return null
	if loop and st is AudioStreamWAV:
		st = st.duplicate()
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(st as AudioStreamWAV).loop_end = int((st as AudioStreamWAV).get_length() * (st as AudioStreamWAV).mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	add_child(p)
	p.play()
	if not loop:
		p.finished.connect(p.queue_free)
	return p


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	# Входящий звонок: справа внизу, как экран телефона
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.07, 0.88)
	sb.border_color = Color(0.5, 0.55, 0.62, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -330
	_panel.offset_right = -36
	_panel.offset_top = -190
	_panel.offset_bottom = -40
	_panel.visible = false
	_layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	box.add_child(_label("Входящий вызов", 15, Color(0.6, 0.65, 0.72)))
	box.add_child(_label("Неизвестный номер", 24, Color(0.95, 0.95, 0.96)))
	box.add_child(_label("[ЛКМ / E]  Ответить", 18, Color(0.55, 0.9, 0.6)))
	box.add_child(_label("[ПКМ / Q]  Сбросить", 18, Color(0.95, 0.5, 0.48)))
	# Реплика Итана
	_sub = _label("", 22, Color(0.95, 0.95, 0.92))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.anchor_top = 1.0
	_sub.anchor_bottom = 1.0
	_sub.offset_top = -120
	_sub.offset_bottom = -80
	_sub.modulate.a = 0.0
	_layer.add_child(_sub)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _say(who: String, text: String, hold: float) -> void:
	_sub.text = "%s: %s" % [who, text]
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_sub, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_interval(hold)
	_sub_tween.tween_property(_sub, "modulate:a", 0.0, 0.4)
