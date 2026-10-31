extends Control

# ══════════════════════════════════════════════════════════════════════════════
#  WirePuzzleUI.gd — Интерактивный электрический щиток проводов (Among Us стиль)
#  • 4 цветных провода (Красный, Синий, Зелёный, Жёлтый)
#  • Перетаскивание проводов мышью с физической отрисовкой кабеля
#  • Искры, щелчки контактов, гул реле и разблокировка электрозамка
# ══════════════════════════════════════════════════════════════════════════════

signal solved
signal closed

var target_door: Node = null
var is_solved: bool = false

# Цвета проводов
const WIRE_COLORS = [
	{"name": "Красный",  "col": Color(0.95, 0.15, 0.15), "glow": Color(1.0, 0.3, 0.3)},
	{"name": "Синий",    "col": Color(0.18, 0.45, 0.95), "glow": Color(0.4, 0.65, 1.0)},
	{"name": "Жёлтый",   "col": Color(0.96, 0.85, 0.12), "glow": Color(1.0, 0.95, 0.4)},
	{"name": "Розовый",  "col": Color(0.92, 0.18, 0.78), "glow": Color(1.0, 0.4, 0.9)}
]

var left_indices: Array[int] = [0, 1, 2, 3]
var right_indices: Array[int] = [0, 1, 2, 3]
var connections: Dictionary = {}  # left_idx -> right_idx

var dragging_left_idx: int = -1
var drag_pos: Vector2 = Vector2.ZERO

var panel_rect: Rect2 = Rect2()
var left_terminals: Array[Vector2] = []
var right_terminals: Array[Vector2] = []

var audio_player: AudioStreamPlayer = null
var status_lbl: Label = null
var led_rect: ColorRect = null

func _init() -> void:
	name = "WirePuzzleUI"
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP

func _ready() -> void:
	_setup_audio()
	_shuffle_right_side()
	_build_ui()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "WireAudio"
	add_child(audio_player)

func _shuffle_right_side() -> void:
	right_indices = [0, 1, 2, 3]
	# Перемешиваем правые клеммы так, чтобы они не стояли 1-к-1
	for i in range(10):
		var a = randi() % 4
		var b = randi() % 4
		var tmp = right_indices[a]
		right_indices[a] = right_indices[b]
		right_indices[b] = tmp
	# Если случайно совпали все 4 подряд — гарантированно сдвигаем
	if right_indices == [0, 1, 2, 3]:
		right_indices = [1, 2, 3, 0]

func _build_ui() -> void:
	# Темный полупрозрачный фон
	var dark_bg = ColorRect.new()
	dark_bg.set_anchors_preset(PRESET_FULL_RECT)
	dark_bg.color = Color(0.02, 0.02, 0.04, 0.85)
	dark_bg.mouse_filter = MOUSE_FILTER_PASS
	add_child(dark_bg)

	# Главный металлический щиток по центру
	var pw: float = 620.0
	var ph: float = 520.0
	var vp_size = get_viewport_rect().size
	var px = (vp_size.x - pw) * 0.5
	var py = (vp_size.y - ph) * 0.5
	panel_rect = Rect2(px, py, pw, ph)

	# Вычисляем координаты клемм
	left_terminals.clear()
	right_terminals.clear()
	var term_y_start = py + 120.0
	var term_spacing = 85.0
	for i in range(4):
		left_terminals.append(Vector2(px + 45.0, term_y_start + i * term_spacing))
		right_terminals.append(Vector2(px + pw - 45.0, term_y_start + i * term_spacing))

	# Верхняя полоска состояния
	status_lbl = Label.new()
	status_lbl.text = "СОЕДИНИТЕ ЦВЕТНЫЕ ПРОВОДА ДЛЯ ПОДАЧИ ПИТАНИЯ"
	status_lbl.position = Vector2(px + 20, py + 18)
	status_lbl.size = Vector2(pw - 80, 24)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
	add_child(status_lbl)

	# Кнопка закрытия [X] (как на скриншоте Among Us)
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(px + pw - 38, py + 12)
	close_btn.size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.pressed.connect(close_panel)
	add_child(close_btn)

	# Индикатор питания
	led_rect = ColorRect.new()
	led_rect.position = Vector2(px + 24, py + 22)
	led_rect.size = Vector2(16, 16)
	led_rect.color = Color(0.85, 0.15, 0.15)
	add_child(led_rect)

func open_for_door(door_node: Node) -> void:
	target_door = door_node
	is_solved = false
	connections.clear()
	dragging_left_idx = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	queue_redraw()

func close_panel() -> void:
	emit_signal("closed")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_TAB or event.keycode == KEY_E:
			get_viewport().set_input_as_handled()
			close_panel()
			return

	if is_solved:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_check_click_start(event.position)
			else:
				_check_click_release(event.position)
	elif event is InputEventMouseMotion:
		if dragging_left_idx >= 0:
			drag_pos = event.position
			queue_redraw()

func _check_click_start(mpos: Vector2) -> void:
	for i in range(4):
		var t_pos = left_terminals[i]
		if mpos.distance_to(t_pos) < 36.0:
			# Нажали на левую клемму — начинаем тянуть провод
			dragging_left_idx = i
			drag_pos = mpos
			_play_sfx_click()
			queue_redraw()
			return

func _check_click_release(mpos: Vector2) -> void:
	if dragging_left_idx < 0:
		return

	var connected = false
	var left_col_idx = left_indices[dragging_left_idx]

	for r in range(4):
		var r_pos = right_terminals[r]
		if mpos.distance_to(r_pos) < 40.0:
			var right_col_idx = right_indices[r]
			if left_col_idx == right_col_idx:
				# ПРАВИЛЬНОЕ СОЕДИНЕНИЕ!
				connections[dragging_left_idx] = r
				connected = true
				_play_sfx_spark()
				_check_win_condition()
			else:
				# НЕПРАВИЛЬНЫЙ ЦВЕТ
				_play_sfx_buzz()
			break

	if not connected:
		_play_sfx_buzz()

	dragging_left_idx = -1
	queue_redraw()

func _check_win_condition() -> void:
	if connections.size() == 4:
		is_solved = true
		if led_rect:
			led_rect.color = Color(0.15, 0.95, 0.25)
		if status_lbl:
			status_lbl.text = "ПИТАНИЕ ПОДАНО! ЗАМОК РАЗБЛОКИРОВАН!"
			status_lbl.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		_play_sfx_power_on()
		emit_signal("solved")
		if target_door and target_door.has_method("_on_wire_panel_solved"):
			target_door.call("_on_wire_panel_solved")

		# Через секунду автоматически закрываем окно и возвращаем управление
		var timer = get_tree().create_timer(1.2)
		timer.timeout.connect(close_panel)

func _draw() -> void:
	if panel_rect.size == Vector2.ZERO:
		return

	# Корпус электрощитка (металлический шкаф)
	draw_rect(panel_rect, Color(0.14, 0.16, 0.18), true)
	draw_rect(panel_rect, Color(0.35, 0.38, 0.42), false, 3.0)

	# Внутренняя ниша шкафа (глубокий темный фон)
	var inner = panel_rect.grow(-18)
	draw_rect(inner, Color(0.06, 0.07, 0.08), true)

	var cx = panel_rect.position.x + panel_rect.size.x * 0.5
	# Вертикальные кабели в глубине шкафа (как на фото)
	draw_line(Vector2(cx - 16, inner.position.y), Vector2(cx - 16, inner.position.y + inner.size.y), Color(0.12, 0.35, 0.85, 0.4), 8.0)
	draw_line(Vector2(cx, inner.position.y), Vector2(cx, inner.position.y + inner.size.y), Color(0.85, 0.15, 0.15, 0.4), 9.0)
	draw_line(Vector2(cx + 16, inner.position.y), Vector2(cx + 16, inner.position.y + inner.size.y), Color(0.85, 0.75, 0.12, 0.4), 8.0)
	# Металлические скобы-держатели
	draw_rect(Rect2(cx - 26, inner.position.y + 70, 52, 12), Color(0.38, 0.40, 0.45), true)
	draw_rect(Rect2(cx - 26, inner.position.y + 200, 52, 12), Color(0.38, 0.40, 0.45), true)

	# Гофры / кабельные каналы по центру сверху
	draw_rect(Rect2(cx - 35, panel_rect.position.y + 18, 25, 45), Color(0.22, 0.24, 0.28), true)
	draw_rect(Rect2(cx + 10, panel_rect.position.y + 18, 25, 45), Color(0.22, 0.24, 0.28), true)

	# Отрисовка левых клемм
	for i in range(4):
		var lp = left_terminals[i]
		var col_info = WIRE_COLORS[left_indices[i]]
		# Желтая наклейка-стикер над клеммой (как на фото Among Us)
		draw_rect(Rect2(lp.x - 30, lp.y - 20, 26, 6), Color(0.92, 0.82, 0.18), true)
		# Корпус клеммы
		draw_rect(Rect2(lp.x - 30, lp.y - 14, 45, 28), Color(0.25, 0.26, 0.28), true)
		draw_rect(Rect2(lp.x - 30, lp.y - 14, 45, 28), Color(0.45, 0.48, 0.52), false, 1.5)
		# Цветная гильза провода
		draw_rect(Rect2(lp.x + 15, lp.y - 8, 14, 16), col_info["col"], true)
		# Медная оголенная жила
		draw_circle(lp + Vector2(28, 0), 4.5, Color(0.85, 0.55, 0.25))

	# Отрисовка правых клемм
	for r in range(4):
		var rp = right_terminals[r]
		var col_info = WIRE_COLORS[right_indices[r]]
		# Корпус клеммы
		draw_rect(Rect2(rp.x - 15, rp.y - 14, 45, 28), Color(0.25, 0.26, 0.28), true)
		draw_rect(Rect2(rp.x - 15, rp.y - 14, 45, 28), Color(0.45, 0.48, 0.52), false, 1.5)
		# Цветная гильза провода
		draw_rect(Rect2(rp.x - 29, rp.y - 8, 14, 16), col_info["col"], true)
		# Медная оголенная жила
		draw_circle(rp - Vector2(28, 0), 4.5, Color(0.85, 0.55, 0.25))

	# Отрисовка соединенных проводов
	for left_idx in connections.keys():
		var right_idx = connections[left_idx]
		var p1 = left_terminals[left_idx] + Vector2(28, 0)
		var p2 = right_terminals[right_idx] - Vector2(28, 0)
		var col_info = WIRE_COLORS[left_indices[left_idx]]
		_draw_wire_cable(p1, p2, col_info["col"])

	# Отрисовка провода в процессе перетаскивания
	if dragging_left_idx >= 0:
		var p1 = left_terminals[dragging_left_idx] + Vector2(28, 0)
		var col_info = WIRE_COLORS[left_indices[dragging_left_idx]]
		_draw_wire_cable(p1, drag_pos, col_info["col"])

func _draw_wire_cable(from: Vector2, to: Vector2, color: Color) -> void:
	# Изогнутый толстый кабель (с провисанием под силой тяжести)
	var mid = (from + to) * 0.5
	var dist = from.distance_to(to)
	var sag = clampf(dist * 0.22, 10.0, 65.0)
	var ctrl = mid + Vector2(0, sag)

	var points = PackedVector2Array()
	var num_pts = 24
	for step in range(num_pts + 1):
		var t = float(step) / float(num_pts)
		# Квадратичная кривая Безье
		var pt = (1.0 - t) * (1.0 - t) * from + 2.0 * (1.0 - t) * t * ctrl + t * t * to
		points.append(pt)

	# 1. Тень / внешний толстый резиновый контур
	draw_polyline(points, Color(0.04, 0.05, 0.06, 0.95), 14.0, true)
	# 2. Основной цветной провод
	draw_polyline(points, color, 9.0, true)
	# 3. Верхний световой блик (глянец изоляции)
	draw_polyline(points, Color(color.r + 0.35, color.g + 0.35, color.b + 0.35, 0.75), 3.0, true)

func _play_sfx_spark() -> void:
	if not audio_player: return
	var sample_count = int(44100 * 0.18)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 26.0)
		var spark = ((randf() * 2.0 - 1.0) * 0.8 + sin(t * 2200.0 * TAU) * 0.3) * env
		var val16 = int(clamp(spark, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.play()

func _play_sfx_buzz() -> void:
	if not audio_player: return
	var sample_count = int(44100 * 0.16)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 12.0)
		var buzz = (sin(t * 85.0 * TAU) * 0.7 + (randf() * 2.0 - 1.0) * 0.2) * env
		var val16 = int(clamp(buzz, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.play()

func _play_sfx_click() -> void:
	if not audio_player: return
	var sample_count = int(44100 * 0.05)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 80.0)
		var clk = sin(t * 1400.0 * TAU) * env
		var val16 = int(clamp(clk, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.play()

func _play_sfx_power_on() -> void:
	if not audio_player: return
	var sample_count = int(44100 * 0.55)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = clampf(t * 4.0, 0.0, 1.0) * exp(-t * 3.5)
		var hum = sin(t * 60.0 * TAU) * 0.6 + sin(t * 120.0 * TAU) * 0.35 + sin(t * 900.0 * TAU) * 0.25 * exp(-t * 25.0)
		var val16 = int(clamp(hum * env, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.play()
