class_name Safe
extends StaticBody3D

# ══════════════════════════════════════════════════════════════════════════════
#  Safe.gd — Механический стальной сейф с кодовым замком и лутом
#  • 3-значный шифр (подсказка находится на алтаре или в записке)
#  • Щелчки поворотного диска и тяжелый звук ригелей при открытии
#  • Внутри находится СИНИЙ предохранитель для электрощитка
# ══════════════════════════════════════════════════════════════════════════════

@export var safe_code: String = "742"
@export var is_unlocked: bool = false
@export var is_looted: bool = false

var safe_door: Node3D = null
var dial_knob: Node3D = null
var sfx_player: AudioStreamPlayer3D = null

var input_code: String = ""
var is_entering_code: bool = false
var modal_ui: Control = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta("item_type", "safe")
	safe_door = get_node_or_null("SafeDoor")
	dial_knob = get_node_or_null("Dial")
	if GameManager and GameManager.safe_code != "":
		safe_code = GameManager.safe_code
	_setup_audio()

func _setup_audio() -> void:
	sfx_player = AudioStreamPlayer3D.new()
	sfx_player.max_distance = 18.0
	sfx_player.unit_size = 3.5
	add_child(sfx_player)

func interact(_opener: Node3D = null) -> void:
	if is_unlocked:
		if not is_looted:
			is_looted = true
			GameManager.pick_up_colored_key("silver")
			GameManager.pick_up_fuse("blue")
			GameManager.add_score("player", 150, "Сейф открыт: получен СЕРЕБРЯНЫЙ ключ!")
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "СЕЙФ ОТКРЫТ! Внутри найден СЕРЕБРЯНЫЙ КЛЮЧ (+150 очков)!", 4.5)
		else:
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Сейф открыт. Ключ уже забран.", 2.0)
		return

	# Открываем интерфейс ввода кода
	_open_code_dialog()

func _open_code_dialog() -> void:
	if modal_ui and is_instance_valid(modal_ui):
		modal_ui.queue_free()

	input_code = ""

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.75)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 220)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.12, 0.14, 0.18, 0.98)
	pstyle.border_width_left = 1
	pstyle.border_width_right = 1
	pstyle.border_width_top = 1
	pstyle.border_width_bottom = 1
	pstyle.border_color = Color(0.3, 0.6, 0.9)
	pstyle.corner_radius_top_left = 6
	pstyle.corner_radius_top_right = 6
	pstyle.corner_radius_bottom_left = 6
	pstyle.corner_radius_bottom_right = 6
	pstyle.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", pstyle)
	bg.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title = Label.new()
	title.text = "СТАЛЬНОЙ СЕЙФ: ВВЕДИТЕ ШИФР"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vb.add_child(title)

	var display_lbl = Label.new()
	display_lbl.text = "[ _ _ _ ]"
	display_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display_lbl.add_theme_font_size_override("font_size", 22)
	display_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	vb.add_child(display_lbl)

	# Цифровая клавиатура 1-9, 0
	var grid = GridContainer.new()
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)

	for digit in range(1, 10):
		var btn = Button.new()
		btn.text = str(digit)
		btn.custom_minimum_size = Vector2(42, 32)
		var d_val = str(digit)
		btn.pressed.connect(func(): _press_digit(d_val, display_lbl, bg))
		grid.add_child(btn)

	var btn_0 = Button.new()
	btn_0.text = "0"
	btn_0.custom_minimum_size = Vector2(42, 32)
	btn_0.pressed.connect(func(): _press_digit("0", display_lbl, bg))
	grid.add_child(btn_0)

	vb.add_child(grid)

	var b_cancel = Button.new()
	b_cancel.text = "Отойти от сейфа"
	b_cancel.pressed.connect(func():
		bg.queue_free()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	)
	vb.add_child(b_cancel)

	modal_ui = bg
	if GameManager.ui_ref:
		GameManager.ui_ref.add_child(bg)
	else:
		add_child(bg)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _press_digit(d: String, lbl: Label, modal: Control) -> void:
	if input_code.length() < 3:
		input_code += d
		_play_sfx("res://assets/audio/safe_click.wav")
		if dial_knob:
			dial_knob.rotation_degrees.z += 36.0

		var mask = ""
		for i in range(3):
			if i < input_code.length():
				mask += input_code[i] + " "
			else:
				mask += "_ "
		lbl.text = "[ " + mask.strip_edges() + " ]"

	if input_code.length() == 3:
		if input_code == safe_code:
			_unlock_safe()
			modal.queue_free()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			lbl.text = "[ ОШИБКА ]"
			var tw = create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(func():
				input_code = ""
				lbl.text = "[ _ _ _ ]"
			)

func _unlock_safe() -> void:
	is_unlocked = true
	_play_sfx("res://assets/audio/safe_open.wav")

	if safe_door:
		var tw = create_tween()
		tw.tween_property(safe_door, "rotation_degrees:y", 95.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if GameManager.ui_ref:
		GameManager.ui_ref.call("show_hint", "СЕЙФ ОТКРЫТ! Заберите синий предохранитель [E]", 4.5)

func _play_sfx(path: String) -> void:
	var s = ResourceLoader.load(path)
	if s and sfx_player:
		sfx_player.stream = s
		sfx_player.play()
