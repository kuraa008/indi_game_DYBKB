extends CanvasLayer

# ══════════════════════════════════════════════
#  Минимальный HUD:
#  • Прицел (точка)
#  • Инвентарь (два иконки, правый угол)
#  • Контекстная подсказка (E)
#  • Story hints (затухают)
#  • СКРИМЕР при поимке
#  • Победа (простой текст)
# ══════════════════════════════════════════════

const TextureHelper = preload("res://scripts/TextureHelper.gd")

const HUD_TEXT   := Color(0.86, 0.87, 0.84)
const HUD_DIM    := Color(0.52, 0.53, 0.50)
const HUD_ACCENT := Color(0.95, 0.12, 0.09)

const CONTROLS_LIST = [
	["WASD", "идти"],
	["SHIFT", "бежать"],
	["C", "присесть"],
	["ЛКМ / E", "действие"],
	["F", "фонарик"],
	["TAB", "рюкзак"],
	["ПКМ", "выбросить предмет"],
	["Q (зажать)", "не дышать рядом с монстром"],
	["M", "микрофон"],
]

var root_ctrl:    Control
var crowbar_icon: Label = null
var key_icon:     Label = null
var battery_icon: Label = null
var battery_lbl:  Label = null
var bottle_icon:  Label = null
var bottle_lbl:   Label = null
var fuse_red_icon:   Label = null
var fuse_blue_icon:  Label = null
var fuse_green_icon: Label = null
var interact_lbl: Label
var hint_label:   Label
var hint_timer:   float = 0.0

# ── Индикатор выносливости (Stamina Bar) ──
var stamina_container: PanelContainer = null
var stamina_bar:       ProgressBar = null
var end_screens:       Array[Node] = []

# Виньетка страха и сердцебиения
var fear_vignette: ColorRect
var cinematic_lens_rect: ColorRect = null
var cinematic_shader_mat: ShaderMaterial = null


# Укрытия (шкаф и кровать)
var hiding_overlay:     Control
var hiding_left_panel:  ColorRect
var hiding_right_panel: ColorRect
var hiding_top_panel:   ColorRect
var wardrobe_slats:     Control
var hiding_prompt:      Label
var oxygen_container:    Control
var oxygen_progress_bar: ProgressBar
var oxygen_status_label: Label
var oxygen_bar_fill:     StyleBoxFlat

# Записка
var note_overlay:   PanelContainer
var note_edit:      TextEdit
var note_text_lbl:  Label

# ── Рюкзак-инвентарь (Backpack Inventory - 6 слотов) ──
var backpack_overlay: Control = null
var backpack_container: Control = null
var backpack_dim_rect: ColorRect = null
var backpack_slot_buttons: Array[Button] = []
var backpack_active_lbl: Label = null
var backpack_desc_lbl: Label = null
var backpack_nav_hint: Label = null
var backpack_close_btn: Button = null
var backpack_cursor_index: int = 0
var backpack_open_tween: Tween = null
var hand_left_rect: TextureRect = null
var hand_right_rect: TextureRect = null

# ── Быстрый хотбар предметов на HUD [1]..[6] ──
var hotbar_container: PanelContainer = null
var hotbar_slots: Array[PanelContainer] = []
var hotbar_slot_buttons: Array[Button] = []
var hotbar_slot_icons: Array[Label] = []
var hotbar_slot_numbers: Array[Label] = []
var hotbar_slot_counts: Array[Label] = []
var hotbar_fade_timer: float = 3.5

# ── Что мешает открыть дверь ──
var door_info_lbl: Label = null
var door_info_text: String = ""
var exit_info_text: String = ""

# ── Счётчик кассеты и подсказка по кнопкам ──
var tape_dot: ColorRect = null
var tape_lbl: Label = null
var tape_time: float = 0.0
var controls_help: Control = null

# ── Пауза ──
var pause_root: ColorRect = null
var pause_first_btn: Button = null

# ── Виджет микрофона (Real Mic Sound Detection) ──
var mic_container: Control = null
var mic_icon: Label = null
var mic_bar: ProgressBar = null
var mic_status_lbl: Label = null

# ── Оверлей пристального взгляда монстра (Scary Stare Mechanic) ──
var stare_overlay: Control = null
var stare_rect: TextureRect = null
var stare_vignette: ColorRect = null
var stare_warning_lbl: Label = null
var stare_pulse_tween: Tween = null

# ── Оверлей подглядывания в замочную скважину ──
var keyhole_overlay: Control = null
var keyhole_texture_rect: TextureRect = null
var keyhole_hint_lbl: Label = null

# ── Предупреждение о реакции врага на свет фонарика ──
var flash_warn_container: PanelContainer = null
var flash_warn_lbl: Label = null
var flash_warn_bar: ProgressBar = null

# ══════════════════════════════════════════════
func _ready() -> void:
	# Пауза и её кнопки должны работать при остановленном дереве
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	VHSOverlay.set_fear(0.0)
	VHSOverlay.glitch(0.7)
	GameManager.connect("inventory_changed", _refresh_inventory)
	GameManager.connect("game_won",          _on_win)
	GameManager.connect("game_over",         _on_game_over)
	GameManager.connect("note_opened",       _on_note_opened)
	GameManager.connect("note_closed",       _on_note_closed)
	if GameManager.has_signal("throwables_changed"):
		GameManager.connect("throwables_changed", _on_throwables_changed)
	if GameManager.has_signal("graphics_quality_changed"):
		GameManager.connect("graphics_quality_changed", _on_gfx_quality_changed)
	if GameManager.has_signal("backpack_toggled"):
		GameManager.connect("backpack_toggled", _on_backpack_toggled)
	if GameManager.has_signal("active_item_changed"):
		GameManager.connect("active_item_changed", _on_active_item_changed)
	if GameManager.has_signal("stamina_changed"):
		GameManager.connect("stamina_changed", _on_stamina_changed)
	if GameManager.has_signal("monster_stare_changed"):
		GameManager.connect("monster_stare_changed", _on_monster_stare_changed)
	if GameManager.has_signal("mic_status_changed"):
		GameManager.connect("mic_status_changed", _on_mic_status_changed)

# ══════════════════════════════════════════════
#  BUILD — Минималистичный реалистичный HUD (только стамина)
# ══════════════════════════════════════════════
func _build_ui() -> void:
	root_ctrl = Control.new()
	root_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_ctrl)

	# ── Страх / Стук сердца виньетка ──────────
	fear_vignette = ColorRect.new()
	fear_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	fear_vignette.color = Color(0.85, 0.05, 0.05, 0.0)
	fear_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(fear_vignette)

	# ── Интерактивный прицел (Crosshair & Throw Charge) ──
	_build_crosshair_ui()

	# ── Реалистичный индикатор выносливости (Stamina Bar) ──
	_build_stamina_ui()

	# ── Быстрый хотбар предметов [1]..[6] (убран: инвентарь только через Tab) ──
	# _build_hotbar_ui()

	# ── [E] Контекстная подсказка взаимодействия ──
	interact_lbl = Label.new()
	interact_lbl.text = ""
	interact_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_lbl.add_theme_font_size_override("font_size", 17)
	interact_lbl.add_theme_color_override("font_color", HUD_TEXT)
	interact_lbl.set_anchor_and_offset(SIDE_RIGHT, 0.80, 0)
	interact_lbl.set_anchor_and_offset(SIDE_LEFT, 0.20, 0)
	interact_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1,   -45)
	interact_lbl.set_anchor_and_offset(SIDE_TOP,    1,   -75)
	root_ctrl.add_child(interact_lbl)

	# ── История/события (затухает) ─────────────
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode        = TextServer.AUTOWRAP_WORD
	hint_label.add_theme_font_size_override("font_size", 17)
	hint_label.add_theme_color_override("font_color", HUD_TEXT)
	hint_label.set_anchor_and_offset(SIDE_RIGHT, 0.90, 0)
	hint_label.set_anchor_and_offset(SIDE_LEFT, 0.10, 0)
	hint_label.set_anchor_and_offset(SIDE_BOTTOM, 1,   -134)
	hint_label.set_anchor_and_offset(SIDE_TOP,    1,   -184)
	hint_label.visible = false
	root_ctrl.add_child(hint_label)

	# ── Окно чтения порванной записки ────────
	_build_note_overlay()

	# ── Оверлей укрытия (шкаф / кровать) ─────
	_build_hiding_overlay()

	# ── Оверлей походного рюкзака (6 слотов) ─
	_build_backpack_ui()

	# ── Что мешает открыть дверь ──
	_build_door_info()

	# ── Виджет микрофона (реакция ИИ на голос) ──
	_build_mic_hud()

	# ── Оверлей пристального взгляда монстра ──
	_build_stare_overlay()

	# ── Оверлей замочной скважины для подглядывания сквозь дверь ──
	_build_keyhole_overlay()

	# ── Предупреждение о реакции врага на свет фонарика ──
	_build_flashlight_warning_ui()

	# ── Кинематографичный пост-процессинг объектива (35mm зерно, хроматика, виньетка) ──
	_build_cinematic_lens_postprocess()

	# ── Счётчик кассеты, подсказка по кнопкам и пауза ──
	_build_tape_counter()
	_build_controls_help()
	_build_pause_menu()

func _build_cinematic_lens_postprocess() -> void:
	cinematic_lens_rect = ColorRect.new()
	cinematic_lens_rect.name = "CinematicLensOverlay"
	cinematic_lens_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	cinematic_lens_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ResourceLoader.exists("res://shaders/horror_cinematic.gdshader"):
		cinematic_shader_mat = ShaderMaterial.new()
		cinematic_shader_mat.shader = load("res://shaders/horror_cinematic.gdshader")
		cinematic_lens_rect.material = cinematic_shader_mat

	root_ctrl.add_child(cinematic_lens_rect)
	_on_gfx_quality_changed(GameManager.graphics_quality if GameManager else "ultra")

func _build_stamina_ui() -> void:
	stamina_container = PanelContainer.new()
	stamina_container.name = "StaminaContainer"
	stamina_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 90)
	stamina_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -90)
	stamina_container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -16)
	stamina_container.set_anchor_and_offset(SIDE_TOP, 1.0, -19)
	stamina_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	root_ctrl.add_child(stamina_container)

	stamina_bar = ProgressBar.new()
	stamina_bar.show_percentage = false
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	stamina_bar.custom_minimum_size = Vector2(0, 3)

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.12)
	stamina_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = HUD_TEXT
	stamina_bar.add_theme_stylebox_override("fill", bar_fg)

	stamina_container.add_child(stamina_bar)

func _on_stamina_changed(cur_stamina: float, max_stamina: float, is_exhausted: bool) -> void:
	if not stamina_bar or not stamina_container:
		return

	stamina_bar.max_value = max_stamina
	stamina_bar.value = cur_stamina

	var fg_mat = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fg_mat:
		fg_mat.bg_color = HUD_ACCENT if is_exhausted else HUD_TEXT

# ══════════════════════════════════════════════
#  Быстрый HUD Хотбар предметов [1]..[6]
# ══════════════════════════════════════════════
func _build_hotbar_ui() -> void:
	hotbar_container = PanelContainer.new()
	hotbar_container.name = "HUDHotbar"
	hotbar_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 172)
	hotbar_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -172)
	hotbar_container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -38)
	hotbar_container.set_anchor_and_offset(SIDE_TOP, 1.0, -96)
	hotbar_container.mouse_filter = Control.MOUSE_FILTER_PASS

	var hb_style = StyleBoxFlat.new()
	hb_style.bg_color = Color(0.02, 0.03, 0.05, 0.65)
	hb_style.border_width_left = 1
	hb_style.border_width_right = 1
	hb_style.border_width_top = 1
	hb_style.border_width_bottom = 1
	hb_style.border_color = Color(0.32, 0.36, 0.44, 0.45)
	hb_style.content_margin_left = 5
	hb_style.content_margin_right = 5
	hb_style.content_margin_top = 4
	hb_style.content_margin_bottom = 4
	hotbar_container.add_theme_stylebox_override("panel", hb_style)
	root_ctrl.add_child(hotbar_container)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hotbar_container.add_child(hbox)

	hotbar_slots.clear()
	hotbar_slot_buttons.clear()
	hotbar_slot_icons.clear()
	hotbar_slot_numbers.clear()
	hotbar_slot_counts.clear()

	for i in range(6):
		var slot_p = PanelContainer.new()
		slot_p.custom_minimum_size = Vector2(48, 48)
		slot_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		slot_p.mouse_filter = Control.MOUSE_FILTER_PASS

		var slot_style = StyleBoxFlat.new()
		slot_style.bg_color = Color(0.06, 0.08, 0.12, 0.70)
		slot_style.border_width_left = 1
		slot_style.border_width_right = 1
		slot_style.border_width_top = 1
		slot_style.border_width_bottom = 1
		slot_style.border_color = Color(0.28, 0.32, 0.38, 0.55)
		slot_p.add_theme_stylebox_override("panel", slot_style)
		hbox.add_child(slot_p)

		# Кнопка для клика мыши
		var btn = Button.new()
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.flat = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		var slot_idx = i
		btn.pressed.connect(func():
			GameManager.set_active_backpack_slot(slot_idx)
			_flash_hotbar()
		)
		slot_p.add_child(btn)

		# Внутренний контейнер
		var inner = Control.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_p.add_child(inner)

		# Цифра слота (1..6)
		var num_lbl = Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.add_theme_font_size_override("font_size", 9)
		num_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85, 0.75))
		num_lbl.position = Vector2(4, 2)
		inner.add_child(num_lbl)

		# Иконка предмета
		var icn_lbl = Label.new()
		icn_lbl.text = "·"
		icn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icn_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icn_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		icn_lbl.add_theme_font_size_override("font_size", 19)
		icn_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92))
		inner.add_child(icn_lbl)

		# Количество (x3)
		var cnt_lbl = Label.new()
		cnt_lbl.text = ""
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cnt_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		cnt_lbl.offset_right = -4
		cnt_lbl.offset_bottom = -2
		cnt_lbl.add_theme_font_size_override("font_size", 9)
		cnt_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
		inner.add_child(cnt_lbl)

		hotbar_slots.append(slot_p)
		hotbar_slot_buttons.append(btn)
		hotbar_slot_icons.append(icn_lbl)
		hotbar_slot_numbers.append(num_lbl)
		hotbar_slot_counts.append(cnt_lbl)

	_refresh_hotbar()

func _refresh_hotbar() -> void:
	if hotbar_slots.is_empty():
		return
	var items: Array[Dictionary] = GameManager.get_backpack_items()
	var active_idx: int = GameManager.active_item_index

	for i in range(6):
		var slot_p = hotbar_slots[i]
		var icn = hotbar_slot_icons[i]
		var num = hotbar_slot_numbers[i]
		var cnt = hotbar_slot_counts[i]
		var itm: Dictionary = items[i] if i < items.size() else {}
		var has_item: bool = not itm.is_empty() and itm.get("id", "empty") != "empty"
		var is_active: bool = (i == active_idx) and has_item

		var s = StyleBoxFlat.new()

		if is_active:
			# Активный экипированный слот — яркая золотистая кайма и янтарный фон
			s.bg_color = Color(0.24, 0.18, 0.05, 0.85)
			s.border_width_left = 2
			s.border_width_right = 2
			s.border_width_top = 2
			s.border_width_bottom = 2
			s.border_color = Color(1.0, 0.85, 0.32, 0.98)
			num.add_theme_color_override("font_color", Color(1.0, 0.95, 0.55))
		elif has_item:
			# Слот с предметом — темно-графитовый с серебристой каймой
			s.bg_color = Color(0.08, 0.10, 0.14, 0.75)
			s.border_width_left = 1
			s.border_width_right = 1
			s.border_width_top = 1
			s.border_width_bottom = 1
			s.border_color = Color(0.45, 0.50, 0.58, 0.65)
			num.add_theme_color_override("font_color", Color(0.80, 0.84, 0.90, 0.85))
		else:
			# Пустой карман — прозрачный
			s.bg_color = Color(0.03, 0.04, 0.06, 0.40)
			s.border_width_left = 1
			s.border_width_right = 1
			s.border_width_top = 1
			s.border_width_bottom = 1
			s.border_color = Color(0.20, 0.22, 0.26, 0.35)
			num.add_theme_color_override("font_color", Color(0.50, 0.53, 0.58, 0.45))

		slot_p.add_theme_stylebox_override("panel", s)

		if has_item:
			var iid = str(itm.get("id", ""))
			var short_tag = "—"
			var tag_color = Color(1.0, 1.0, 1.0)
			if itm.has("key_id"):
				short_tag = "№%d" % int(itm["key_id"])
				var DoorScript = load("res://scripts/Door.gd")
				var th = DoorScript.get_lock_theme(int(itm["key_id"]))
				tag_color = th.get("color", Color(1.0, 0.85, 0.25))
			elif iid == "crowbar":
				short_tag = "ЛОМ"
				tag_color = Color(0.95, 0.35, 0.30)
			elif iid == "battery":
				short_tag = "АКК"
				tag_color = Color(0.35, 0.95, 0.45)
			elif iid == "bottle":
				short_tag = "БУТ"
				tag_color = Color(0.45, 0.85, 0.90)
			elif iid == "fuse_red":
				short_tag = "ПР-К"
				tag_color = Color(1.0, 0.35, 0.35)
			elif iid == "fuse_blue":
				short_tag = "ПР-С"
				tag_color = Color(0.35, 0.70, 1.0)
			elif iid == "fuse_green":
				short_tag = "ПР-З"
				tag_color = Color(0.35, 1.0, 0.45)
			elif iid == "road_flare":
				short_tag = "РАК"
				tag_color = Color(1.0, 0.55, 0.20)
			else:
				short_tag = str(itm.get("name", "—")).substr(0, 3).to_upper()

			icn.text = short_tag
			icn.modulate = tag_color
			var count_val: int = int(itm.get("count", 1))
			cnt.text = "x%d" % count_val if count_val > 1 else ""
		else:
			icn.text = "·"
			icn.modulate = Color(0.40, 0.42, 0.46, 0.35)
			cnt.text = ""

func _flash_hotbar() -> void:
	hotbar_fade_timer = 3.5
	if hotbar_container:
		hotbar_container.modulate.a = 1.0

func _build_door_info() -> void:
	door_info_lbl = Label.new()
	door_info_lbl.name = "DoorInfo"
	door_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	door_info_lbl.add_theme_font_size_override("font_size", 16)
	door_info_lbl.add_theme_color_override("font_color", HUD_TEXT)
	door_info_lbl.set_anchor_and_offset(SIDE_RIGHT, 0.85, 0)
	door_info_lbl.set_anchor_and_offset(SIDE_LEFT, 0.15, 0)
	door_info_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -84)
	door_info_lbl.set_anchor_and_offset(SIDE_TOP, 1.0, -170)
	door_info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	door_info_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	door_info_lbl.visible = false
	root_ctrl.add_child(door_info_lbl)

func _refresh_door_info() -> void:
	if not door_info_lbl:
		return
	var text = exit_info_text if exit_info_text != "" else door_info_text
	door_info_lbl.text = text
	door_info_lbl.visible = text != ""

func update_door_inspector(info: Dictionary) -> void:
	door_info_text = ""
	if not info.is_empty() and not bool(info.get("is_open", false)):
		var lines: Array[String] = []
		if bool(info.get("boards_needed", false)):
			lines.append("Заколочено досками." if bool(info.get("has_crowbar", false)) else "Заколочено досками. Нужен лом.")
		if bool(info.get("requires_wire_panel", false)) and not bool(info.get("wire_panel_solved", false)):
			lines.append("Щиток не подключён. Соедини провода.")
		elif bool(info.get("requires_power", false)) and not bool(info.get("is_powered", false)):
			lines.append("Нет питания." if int(info.get("power_cells_have", 0)) >= 1 else "Нет питания. Нужна батарея.")
		var lock_id = int(info.get("lock_id", 0))
		var is_unlocked = bool(info.get("door_key_unlocked", false)) or lock_id <= 0
		if not is_unlocked and not bool(info.get("has_key", false)):
			var th = info.get("lock_theme", {})
			lines.append("Заперто. Нужен %s ключ №%d." % [str(th.get("name", "")).to_lower(), lock_id])
		door_info_text = "\n".join(lines)
	_refresh_door_info()

func update_escape_checklist(chk: Dictionary) -> void:
	exit_info_text = ""
	if not chk.is_empty() and chk.get("is_exit", false) and not chk.get("is_open", false):
		var lines: Array[String] = []
		if chk.get("boards_needed", false) and not chk.get("boards_done", false):
			lines.append("Заколочено досками." if GameManager.has_crowbar else "Заколочено досками. Нужен лом.")
		if chk.get("power_needed", false) and not chk.get("power_done", false):
			lines.append("Нет питания." if GameManager.battery_cells >= 1 else "Нет питания. Нужна батарея.")
		if chk.get("key_needed", false) and not chk.get("key_done", false):
			if not GameManager.has_key_color(str(chk.get("key_color", "gold"))):
				lines.append("Заперто. Нужен %s ключ." % str(chk.get("key_name_ru", "золотой")).to_lower())
		if not lines.is_empty():
			exit_info_text = "ВЫХОД\n" + "\n".join(lines)
	_refresh_door_info()

func _build_note_overlay() -> void:
	note_overlay = PanelContainer.new()
	note_overlay.set_anchors_preset(Control.PRESET_CENTER)
	note_overlay.size = Vector2(520, 360)
	note_overlay.position = Vector2(-260, -180)
	note_overlay.visible = false
	root_ctrl.add_child(note_overlay)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	note_overlay.add_child(vb)

	var title = Label.new()
	title.text = "ЗАПИСКА"
	title.add_theme_font_override("font", VHSOverlay.tracked_font(3))
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", HUD_TEXT)
	vb.add_child(title)

	note_edit = TextEdit.new()
	note_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note_edit.add_theme_font_size_override("font_size", 17)
	vb.add_child(note_edit)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)

	var save_btn = Button.new()
	save_btn.text = "СОХРАНИТЬ"
	save_btn.pressed.connect(func():
		if note_edit:
			GameManager.save_note_text(note_edit.text)
	)
	hb.add_child(save_btn)

	var close_btn = Button.new()
	close_btn.text = "ESC  ЗАКРЫТЬ"
	close_btn.pressed.connect(func():
		GameManager.close_note()
	)
	hb.add_child(close_btn)
	vb.add_child(hb)

func _on_note_opened(text: String) -> void:
	if note_edit:
		note_edit.text = text
	if note_overlay:
		note_overlay.visible = true

func _on_note_closed() -> void:
	if note_overlay:
		note_overlay.visible = false

# ──────────────────────────────────────────────
#  Оверлей укрытия (шкаф / кровать)
# ──────────────────────────────────────────────
func _build_hiding_overlay() -> void:
	hiding_overlay = Control.new()
	hiding_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	hiding_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hiding_overlay.visible = false
	root_ctrl.add_child(hiding_overlay)

	# ── Шкаф: створки слева и справа с широким обзором в центре ──
	hiding_left_panel = ColorRect.new()
	hiding_left_panel.color = Color(0.10, 0.06, 0.04, 0.96)
	hiding_left_panel.set_anchor_and_offset(SIDE_RIGHT, 0.22, 0)
	hiding_left_panel.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	hiding_left_panel.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	hiding_left_panel.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_overlay.add_child(hiding_left_panel)

	var edge_l = ColorRect.new()
	edge_l.color = Color(0.24, 0.15, 0.08, 1.0)
	edge_l.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	edge_l.set_anchor_and_offset(SIDE_LEFT, 1, -8)
	edge_l.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	edge_l.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_left_panel.add_child(edge_l)

	hiding_right_panel = ColorRect.new()
	hiding_right_panel.color = Color(0.10, 0.06, 0.04, 0.96)
	hiding_right_panel.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0)
	hiding_right_panel.set_anchor_and_offset(SIDE_LEFT, 0.78, 0)
	hiding_right_panel.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	hiding_right_panel.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_overlay.add_child(hiding_right_panel)

	var edge_r = ColorRect.new()
	edge_r.color = Color(0.24, 0.15, 0.08, 1.0)
	edge_r.set_anchor_and_offset(SIDE_RIGHT, 0, 8)
	edge_r.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	edge_r.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	edge_r.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_right_panel.add_child(edge_r)

	# Горизонтальные полупрозрачные жалюзи шкафа (видно сквозь них)
	wardrobe_slats = Control.new()
	wardrobe_slats.set_anchor_and_offset(SIDE_RIGHT, 0.78, 0)
	wardrobe_slats.set_anchor_and_offset(SIDE_LEFT, 0.22, 0)
	wardrobe_slats.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	wardrobe_slats.set_anchor_and_offset(SIDE_TOP, 0, 0)
	wardrobe_slats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hiding_overlay.add_child(wardrobe_slats)

	for s_idx in range(7):
		var slat = ColorRect.new()
		var y_rel = 0.08 + s_idx * 0.13
		slat.color = Color(0.12, 0.07, 0.04, 0.65)
		slat.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
		slat.set_anchor_and_offset(SIDE_LEFT, 0, 0)
		slat.set_anchor_and_offset(SIDE_BOTTOM, y_rel, 12)
		slat.set_anchor_and_offset(SIDE_TOP, y_rel, 0)
		wardrobe_slats.add_child(slat)

	# ── Кровать: легкий навес каркаса сверху (широкий обзор пола и комнаты снизу) ──
	hiding_top_panel = ColorRect.new()
	hiding_top_panel.color = Color(0.08, 0.06, 0.05, 0.78)
	hiding_top_panel.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	hiding_top_panel.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	hiding_top_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.22, 0)
	hiding_top_panel.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_overlay.add_child(hiding_top_panel)

	var bed_fringe = ColorRect.new()
	bed_fringe.color = Color(0.18, 0.12, 0.08, 1.0)
	bed_fringe.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	bed_fringe.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	bed_fringe.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	bed_fringe.set_anchor_and_offset(SIDE_TOP, 1, -10)
	hiding_top_panel.add_child(bed_fringe)

	hiding_prompt = Label.new()
	hiding_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hiding_prompt.add_theme_font_size_override("font_size", 16)
	hiding_prompt.add_theme_color_override("font_color", HUD_TEXT)
	hiding_prompt.set_anchor_and_offset(SIDE_RIGHT, 0.9, 0)
	hiding_prompt.set_anchor_and_offset(SIDE_LEFT, 0.1, 0)
	hiding_prompt.set_anchor_and_offset(SIDE_BOTTOM, 1, -16)
	hiding_prompt.set_anchor_and_offset(SIDE_TOP, 1, -44)
	hiding_overlay.add_child(hiding_prompt)

	# ── Индикатор запаса кислорода и задержки дыхания ──
	oxygen_container = Control.new()
	oxygen_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 170)
	oxygen_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -170)
	oxygen_container.set_anchor_and_offset(SIDE_BOTTOM, 1, -48)
	oxygen_container.set_anchor_and_offset(SIDE_TOP, 1, -94)
	hiding_overlay.add_child(oxygen_container)

	oxygen_status_label = Label.new()
	oxygen_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oxygen_status_label.add_theme_font_size_override("font_size", 16)
	oxygen_status_label.add_theme_color_override("font_color", HUD_TEXT)
	oxygen_status_label.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	oxygen_status_label.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	oxygen_status_label.set_anchor_and_offset(SIDE_BOTTOM, 0, 20)
	oxygen_status_label.set_anchor_and_offset(SIDE_TOP, 0, 0)
	oxygen_status_label.text = "Воздух: 15.0 с"
	oxygen_container.add_child(oxygen_status_label)

	oxygen_progress_bar = ProgressBar.new()
	oxygen_progress_bar.min_value = 0.0
	oxygen_progress_bar.max_value = 15.0
	oxygen_progress_bar.value = 15.0
	oxygen_progress_bar.show_percentage = false
	oxygen_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_progress_bar.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	oxygen_progress_bar.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	oxygen_progress_bar.set_anchor_and_offset(SIDE_BOTTOM, 0, 31)
	oxygen_progress_bar.set_anchor_and_offset(SIDE_TOP, 0, 28)

	var bg_box = StyleBoxFlat.new()
	bg_box.bg_color = Color(1, 1, 1, 0.12)
	oxygen_progress_bar.add_theme_stylebox_override("background", bg_box)

	oxygen_bar_fill = StyleBoxFlat.new()
	oxygen_bar_fill.bg_color = HUD_TEXT
	oxygen_progress_bar.add_theme_stylebox_override("fill", oxygen_bar_fill)
	oxygen_container.add_child(oxygen_progress_bar)

func set_hiding_mode(mode: String) -> void:
	if not hiding_overlay:
		return
	if mode == "":
		hiding_overlay.visible = false
		return

	hiding_overlay.visible = true
	if oxygen_progress_bar:
		oxygen_progress_bar.value = 15.0
	if mode == "wardrobe":
		# Occlusion comes from actual cabinet geometry, not a screen-space mask.
		hiding_left_panel.visible = false
		hiding_right_panel.visible = false
		if wardrobe_slats: wardrobe_slats.visible = false
		hiding_top_panel.visible = false
		hiding_prompt.text = "[ЛКМ / RT] Выйти    [Q / Y, зажать] Не дышать"
	elif mode == "bed":
		hiding_left_panel.visible = false
		hiding_right_panel.visible = false
		if wardrobe_slats: wardrobe_slats.visible = false
		hiding_top_panel.visible = true
		hiding_prompt.text = "[ЛКМ / RT] Вылезти    [Q / Y, зажать] Не дышать"

# ══════════════════════════════════════════════
#  ВИДЖЕТ МИКРОФОНА (ЗВУКОВАЯ РЕАКЦИЯ ИИ)
# ══════════════════════════════════════════════
func _build_mic_hud() -> void:
	mic_container = HBoxContainer.new()
	mic_container.name = "MicContainer"
	mic_container.set_anchor_and_offset(SIDE_RIGHT, 0.0, 170)
	mic_container.set_anchor_and_offset(SIDE_LEFT, 0.0, 30)
	mic_container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -14)
	mic_container.set_anchor_and_offset(SIDE_TOP, 1.0, -34)
	mic_container.add_theme_constant_override("separation", 8)
	mic_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(mic_container)

	mic_icon = Label.new()
	mic_icon.text = "МИК"
	mic_icon.add_theme_font_size_override("font_size", 12)
	mic_icon.add_theme_color_override("font_color", HUD_DIM)
	mic_container.add_child(mic_icon)

	mic_bar = ProgressBar.new()
	mic_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mic_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mic_bar.custom_minimum_size = Vector2(0, 2)
	mic_bar.show_percentage = false
	mic_bar.min_value = 0.0
	mic_bar.max_value = 100.0
	mic_bar.value = 0.0

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(1, 1, 1, 0.10)
	mic_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = HUD_DIM
	mic_bar.add_theme_stylebox_override("fill", bar_fg)
	mic_container.add_child(mic_bar)

	mic_status_lbl = Label.new()
	mic_status_lbl.text = ""
	mic_status_lbl.add_theme_font_size_override("font_size", 12)
	mic_status_lbl.add_theme_color_override("font_color", HUD_DIM)
	mic_container.add_child(mic_status_lbl)

func _on_mic_status_changed(enabled: bool, volume: float, triggered: bool) -> void:
	if not mic_bar or not mic_container:
		return

	mic_status_lbl.text = "" if enabled else "ВЫКЛ  M"
	mic_bar.visible = enabled
	mic_bar.value = clamp(volume * 1000.0, 0.0, 100.0) if enabled else 0.0
	var fg = mic_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fg:
		fg.bg_color = HUD_ACCENT if triggered else HUD_DIM

# ══════════════════════════════════════════════
#  ОВЕРЛЕЙ ПРИСТАЛЬНОГО ВЗГЛЯДА МОНСТРА
# ══════════════════════════════════════════════
func _build_stare_overlay() -> void:
	stare_overlay = Control.new()
	stare_overlay.name = "StareOverlay"
	stare_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	stare_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stare_overlay.visible = false
	root_ctrl.add_child(stare_overlay)

	stare_vignette = ColorRect.new()
	stare_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	stare_vignette.color = Color(0.12, 0.01, 0.01, 0.65)
	stare_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stare_overlay.add_child(stare_vignette)

	stare_warning_lbl = Label.new()
	stare_warning_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stare_warning_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stare_warning_lbl.add_theme_font_size_override("font_size", 17)
	stare_warning_lbl.add_theme_color_override("font_color", HUD_ACCENT)
	stare_warning_lbl.set_anchor_and_offset(SIDE_RIGHT, 0.95, 0)
	stare_warning_lbl.set_anchor_and_offset(SIDE_LEFT, 0.05, 0)
	stare_warning_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.90, 0)
	stare_warning_lbl.set_anchor_and_offset(SIDE_TOP, 0.80, 0)
	stare_overlay.add_child(stare_warning_lbl)

# ══════════════════════════════════════════════
#  Оверлей подглядывания в замочную скважину
# ══════════════════════════════════════════════
func _build_keyhole_overlay() -> void:
	keyhole_overlay = Control.new()
	keyhole_overlay.name = "KeyholeOverlay"
	keyhole_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	keyhole_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keyhole_overlay.visible = false
	root_ctrl.add_child(keyhole_overlay)

	keyhole_texture_rect = TextureRect.new()
	keyhole_texture_rect.name = "KeyholeTextureRect"
	keyhole_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	keyhole_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	keyhole_texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	keyhole_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	keyhole_texture_rect.texture = _create_keyhole_texture()
	keyhole_overlay.add_child(keyhole_texture_rect)

	keyhole_hint_lbl = Label.new()
	keyhole_hint_lbl.text = "[C / E / WASD] Отойти"
	keyhole_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyhole_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keyhole_hint_lbl.add_theme_font_size_override("font_size", 14)
	keyhole_hint_lbl.add_theme_color_override("font_color", HUD_DIM)
	keyhole_hint_lbl.set_anchor_and_offset(SIDE_RIGHT, 0.9, 0)
	keyhole_hint_lbl.set_anchor_and_offset(SIDE_LEFT, 0.1, 0)
	keyhole_hint_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -32)
	keyhole_hint_lbl.set_anchor_and_offset(SIDE_TOP, 1.0, -60)
	keyhole_overlay.add_child(keyhole_hint_lbl)

func _create_keyhole_texture() -> ImageTexture:
	var w = 480
	var h = 270
	var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cx = float(w) * 0.5
	var cy_top = float(h) * 0.44
	var r_top = 34.0
	var slot_top_y = cy_top + 8.0
	var slot_bot_y = cy_top + 62.0
	var slot_w_top = 13.0
	var slot_w_bot = 24.0

	for y in range(h):
		var fy = float(y)
		for x in range(w):
			var fx = float(x)
			var dx = fx - cx
			var dy = fy - cy_top
			var in_hole = false

			# 1. Круглая верхняя часть
			var d_circ = sqrt(dx * dx + dy * dy)
			if d_circ <= r_top:
				in_hole = true

			# 2. Нижняя трапециевидная щель
			if fy >= slot_top_y and fy <= slot_bot_y:
				var t = (fy - slot_top_y) / (slot_bot_y - slot_top_y)
				var hw = lerpf(slot_w_top, slot_w_bot, t)
				if absf(dx) <= hw:
					in_hole = true

			if in_hole:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				var dist = 999.0
				if dy <= 8.0:
					dist = maxf(0.0, d_circ - r_top)
				else:
					var t = clampf((fy - slot_top_y) / (slot_bot_y - slot_top_y), 0.0, 1.0)
					var hw = lerpf(slot_w_top, slot_w_bot, t)
					var dx_slot = maxf(0.0, absf(dx) - hw)
					var dy_slot = maxf(0.0, fy - slot_bot_y)
					dist = sqrt(dx_slot * dx_slot + dy_slot * dy_slot)

				if dist <= 3.5:
					# Латунная фаска скважины
					img.set_pixel(x, y, Color(0.35, 0.28, 0.15, 0.95))
				elif dist <= 7.0:
					var a_edge = clampf((dist - 3.5) / 3.5, 0.0, 1.0)
					var col = Color(0.20, 0.15, 0.08, 0.96).lerp(Color(0.02, 0.02, 0.02, 0.98), a_edge)
					img.set_pixel(x, y, col)
				else:
					img.set_pixel(x, y, Color(0.015, 0.015, 0.018, 0.98))

	return ImageTexture.create_from_image(img)

func show_keyhole_overlay(active: bool) -> void:
	if not keyhole_overlay:
		return
	if active:
		keyhole_overlay.visible = true
		keyhole_overlay.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(keyhole_overlay, "modulate:a", 1.0, 0.20)
	else:
		var tw = create_tween()
		tw.tween_property(keyhole_overlay, "modulate:a", 0.0, 0.18)
		tw.tween_callback(func(): keyhole_overlay.visible = false)

# ══════════════════════════════════════════════
#  Предупреждение о реакции врага на свет фонарика
# ══════════════════════════════════════════════
func _build_flashlight_warning_ui() -> void:
	flash_warn_container = PanelContainer.new()
	flash_warn_container.name = "FlashlightWarningContainer"
	flash_warn_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 180)
	flash_warn_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -180)
	flash_warn_container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -84)
	flash_warn_container.set_anchor_and_offset(SIDE_TOP, 1.0, -122)
	flash_warn_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_warn_container.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.03, 0.03, 0.88)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.92, 0.28, 0.25, 0.90)
	style.set_content_margin_all(4)
	flash_warn_container.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(flash_warn_container)

	var vb = VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 3)
	flash_warn_container.add_child(vb)

	flash_warn_lbl = Label.new()
	flash_warn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flash_warn_lbl.add_theme_font_size_override("font_size", 12)
	flash_warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.85, 0.95))
	flash_warn_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	flash_warn_lbl.text = "Враг щурится от света фонарика    [F] Погасить свет"
	vb.add_child(flash_warn_lbl)

	flash_warn_bar = ProgressBar.new()
	flash_warn_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flash_warn_bar.custom_minimum_size.y = 4
	flash_warn_bar.show_percentage = false
	flash_warn_bar.min_value = 0.0
	flash_warn_bar.max_value = 100.0
	flash_warn_bar.value = 100.0

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.08, 0.02, 0.02, 0.8)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.95, 0.28, 0.25, 0.95)
	flash_warn_bar.add_theme_stylebox_override("background", bar_bg)
	flash_warn_bar.add_theme_stylebox_override("fill", bar_fill)
	vb.add_child(flash_warn_bar)

func show_flashlight_warning(_active: bool = false, _time_left: float = 0.0, _enemy_name: String = "") -> void:
	if flash_warn_container:
		flash_warn_container.visible = false
	return

func _on_monster_stare_changed(active: bool, _spot_type: String, witnessed: bool) -> void:
	if not stare_overlay:
		return

	if stare_pulse_tween:
		stare_pulse_tween.kill()

	if not active:
		var t = create_tween()
		t.tween_property(stare_overlay, "modulate:a", 0.0, 0.35)
		t.tween_callback(func(): stare_overlay.visible = false)
		return

	# Никаких 2D фото-скримеров! Во время слежки — только напряженная виньетка и предупреждение задержки дыхания
	var btn_hint = "[LB / R3]" if (GameManager and GameManager.is_gamepad) else "[Q]"
	if witnessed:
		stare_warning_lbl.text = "%s  Задержи дыхание. Оно рядом." % btn_hint
		stare_warning_lbl.add_theme_color_override("font_color", HUD_ACCENT)
	else:
		stare_warning_lbl.text = "%s  Задержи дыхание" % btn_hint
		stare_warning_lbl.add_theme_color_override("font_color", HUD_TEXT)

	stare_overlay.visible = true
	stare_overlay.modulate.a = 0.0

	var tw = create_tween()
	tw.tween_property(stare_overlay, "modulate:a", 1.0, 0.45)

	stare_pulse_tween = create_tween().set_loops()
	stare_pulse_tween.tween_property(stare_vignette, "color:a", 0.65, 0.50)
	stare_pulse_tween.tween_property(stare_vignette, "color:a", 0.25, 0.50)

func pulse_heartbeat(amount: float) -> void:
	if GameManager.vhs_enabled:
		VHSOverlay.glitch(clampf(amount * 0.35, 0.0, 0.5))
	elif cinematic_shader_mat:
		var target_f = clamp(amount * 0.75, 0.0, 1.0)
		cinematic_shader_mat.set_shader_parameter("fear_factor", target_f)
		var t = create_tween()
		t.tween_method(func(val): cinematic_shader_mat.set_shader_parameter("fear_factor", val), target_f, 0.0, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif fear_vignette:
		var target_a = clamp(amount * 0.35, 0.0, 0.45)
		fear_vignette.color.a = target_a
		var t = create_tween()
		t.tween_property(fear_vignette, "color:a", 0.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func flash_fear(amount: float) -> void:
	pulse_heartbeat(amount)

func _on_throwables_changed(count: int) -> void:
	if bottle_lbl:
		bottle_lbl.text = "x%d" % count
	if bottle_icon:
		bottle_icon.modulate = Color(1.0, 1.0, 1.0) if count > 0 else Color(0.25, 0.25, 0.25)

# ══════════════════════════════════════════════
#  ИНВЕНТАРЬ-РЮКЗАК (6 СЛОТОВ, МИНИМАЛИЗМ)
# ══════════════════════════════════════════════
func _build_backpack_ui() -> void:
	backpack_overlay = Control.new()
	backpack_overlay.name = "BackpackOverlay"
	backpack_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	backpack_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backpack_overlay.visible = false
	root_ctrl.add_child(backpack_overlay)

	# Затемнение заднего плана
	backpack_dim_rect = ColorRect.new()
	backpack_dim_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	backpack_dim_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	backpack_dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	backpack_dim_rect.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			GameManager.close_backpack()
	)
	backpack_overlay.add_child(backpack_dim_rect)

	backpack_container = PanelContainer.new()
	backpack_container.name = "BackpackContainer"
	backpack_container.size = Vector2(580, 240)
	backpack_container.custom_minimum_size = Vector2(580, 240)
	backpack_container.pivot_offset = Vector2(290, 120)
	backpack_container.set_anchors_preset(Control.PRESET_CENTER)
	backpack_container.offset_left = -290
	backpack_container.offset_right = 290
	backpack_container.offset_top = -120
	backpack_container.offset_bottom = 120
	backpack_overlay.add_child(backpack_container)

	var main_vb = VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 10)
	backpack_container.add_child(main_vb)

	# 1. Заголовок
	var header_hb = HBoxContainer.new()
	main_vb.add_child(header_hb)

	var title_lbl = Label.new()
	title_lbl.text = "РЮКЗАК"
	title_lbl.add_theme_font_override("font", VHSOverlay.tracked_font(3))
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", HUD_TEXT)
	header_hb.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "TAB  ЗАКРЫТЬ"
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(func():
		GameManager.close_backpack()
	)
	backpack_close_btn = close_btn
	header_hb.add_child(close_btn)

	# 2. Ряд из 6 слотов
	var slots_hb = HBoxContainer.new()
	slots_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_hb.add_theme_constant_override("separation", 8)
	main_vb.add_child(slots_hb)

	backpack_slot_buttons.clear()
	for i in range(6):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(82, 82)
		btn.size = Vector2(82, 82)
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_STOP

		var slot_idx = i
		btn.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				if ev.button_index == MOUSE_BUTTON_LEFT:
					_on_slot_clicked(slot_idx)
				elif ev.button_index == MOUSE_BUTTON_RIGHT:
					_on_slot_right_clicked(slot_idx)
		)
		btn.mouse_entered.connect(func(): _on_slot_hovered(slot_idx))

		slots_hb.add_child(btn)
		backpack_slot_buttons.append(btn)

	# 3. Описание выбранного предмета
	backpack_active_lbl = Label.new()
	backpack_active_lbl.add_theme_font_size_override("font_size", 15)
	backpack_active_lbl.add_theme_color_override("font_color", HUD_TEXT)
	main_vb.add_child(backpack_active_lbl)

	backpack_desc_lbl = Label.new()
	backpack_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	backpack_desc_lbl.custom_minimum_size = Vector2(540, 0)
	backpack_desc_lbl.add_theme_font_size_override("font_size", 14)
	backpack_desc_lbl.add_theme_color_override("font_color", HUD_DIM)
	main_vb.add_child(backpack_desc_lbl)

	# 4. Подсказка
	var nav_hint = Label.new()
	nav_hint.add_theme_font_size_override("font_size", 13)
	nav_hint.add_theme_color_override("font_color", HUD_DIM)
	backpack_nav_hint = nav_hint
	main_vb.add_child(nav_hint)

func _on_backpack_toggled(is_open: bool) -> void:
	if not backpack_overlay or not backpack_container:
		return

	if backpack_open_tween and backpack_open_tween.is_valid():
		backpack_open_tween.kill()

	if is_open:
		backpack_cursor_index = GameManager.active_item_index if GameManager.active_item_index >= 0 else 0
		if hotbar_container:
			hotbar_container.visible = false
		backpack_overlay.visible = true
		_refresh_backpack()
		_update_backpack_desc(backpack_cursor_index)
		_play_ui_sound("res://assets/audio/bag_open.wav", -3.5)

		var vp_size = get_viewport().get_visible_rect().size
		var target_y = (vp_size.y - backpack_container.size.y) * 0.5
		var start_y = target_y + 40.0

		backpack_container.position.y = start_y
		backpack_dim_rect.color.a = 0.0

		backpack_open_tween = create_tween().set_parallel(true)
		backpack_open_tween.tween_property(backpack_container, "position:y", target_y, 0.22)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		backpack_open_tween.tween_property(backpack_dim_rect, "color:a", 0.65, 0.20)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		if GameManager.is_gamepad:
			call_deferred("_warp_mouse_to_slot", backpack_cursor_index)
	else:
		_play_ui_sound("res://assets/audio/bag_close.wav", -3.5)
		var vp_size = get_viewport().get_visible_rect().size
		var target_y = (vp_size.y - backpack_container.size.y) * 0.5
		var hide_y = target_y + 40.0

		backpack_open_tween = create_tween().set_parallel(true)
		backpack_open_tween.tween_property(backpack_container, "position:y", hide_y, 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		backpack_open_tween.tween_property(backpack_dim_rect, "color:a", 0.0, 0.18)\
			.set_trans(Tween.TRANS_LINEAR)
		backpack_open_tween.chain().tween_callback(func():
			if not GameManager.is_backpack_open:
				backpack_overlay.visible = false
				if hotbar_container:
					hotbar_container.visible = true
					_refresh_hotbar()
					_flash_hotbar()
		)

func _play_ui_sound(path: String, volume_db: float = 0.0) -> void:
	if ResourceLoader.exists(path):
		var asp = AudioStreamPlayer.new()
		asp.stream = load(path)
		asp.volume_db = volume_db
		add_child(asp)
		asp.play()
		asp.finished.connect(asp.queue_free)

func _on_active_item_changed(_idx: int, _item: Dictionary) -> void:
	_refresh_backpack()
	_refresh_hotbar()
	_flash_hotbar()

func _on_slot_clicked(idx: int) -> void:
	var items = GameManager.get_backpack_items()
	if idx >= 0 and idx < items.size():
		var itm = items[idx]
		if itm.get("id", "empty") != "empty":
			_play_ui_sound("res://assets/audio/bag_item_select.wav", -4.5)
			GameManager.set_active_backpack_slot(idx)
			_refresh_backpack()
		else:
			_update_backpack_desc(idx)

func _on_slot_right_clicked(idx: int) -> void:
	var items = GameManager.get_backpack_items()
	if idx >= 0 and idx < items.size():
		var itm = items[idx]
		if itm.get("id", "empty") != "empty":
			var ok = GameManager.drop_backpack_slot(idx)
			if ok:
				_play_ui_sound("res://assets/audio/bag_item_select.wav", -2.5)
				_refresh_backpack()
				_refresh_hotbar()

func _on_slot_hovered(idx: int) -> void:
	backpack_cursor_index = idx
	_update_backpack_desc(idx)

func _warp_mouse_to_slot(idx: int) -> void:
	if idx >= 0 and idx < backpack_slot_buttons.size():
		var btn = backpack_slot_buttons[idx]
		if btn and btn.is_inside_tree():
			get_viewport().warp_mouse(btn.get_global_rect().get_center())

func _handle_gamepad_backpack_click(is_right_click: bool = false) -> void:
	var mpos = get_viewport().get_mouse_position()
	if not is_right_click:
		if backpack_close_btn and backpack_close_btn.is_inside_tree() and backpack_close_btn.get_global_rect().has_point(mpos):
			GameManager.close_backpack()
			return

	var target_slot = -1
	for i in range(backpack_slot_buttons.size()):
		var btn = backpack_slot_buttons[i]
		if btn and btn.is_inside_tree() and btn.get_global_rect().has_point(mpos):
			target_slot = i
			break

	if target_slot == -1:
		target_slot = backpack_cursor_index

	if target_slot >= 0 and target_slot < 6:
		backpack_cursor_index = target_slot
		if is_right_click:
			_on_slot_right_clicked(target_slot)
		else:
			_on_slot_clicked(target_slot)

func _process_backpack_gamepad_cursor(delta: float) -> void:
	var sx: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var sy: float = Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(sx) < 0.18 and absf(sy) < 0.18:
		sx = Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
		sy = Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)

	if absf(sx) > 0.18 or absf(sy) > 0.18:
		GameManager.is_gamepad = true
		var cur_pos = get_viewport().get_mouse_position()
		var move_speed = 950.0
		var target_pos = cur_pos + Vector2(sx, sy) * move_speed * delta
		var vp_rect = get_viewport().get_visible_rect()
		target_pos.x = clampf(target_pos.x, 2.0, vp_rect.size.x - 2.0)
		target_pos.y = clampf(target_pos.y, 2.0, vp_rect.size.y - 2.0)
		get_viewport().warp_mouse(target_pos)

		for i in range(backpack_slot_buttons.size()):
			var btn = backpack_slot_buttons[i]
			if btn and btn.is_inside_tree() and btn.get_global_rect().has_point(target_pos):
				if backpack_cursor_index != i:
					backpack_cursor_index = i
					_update_backpack_desc(backpack_cursor_index)
					_refresh_backpack()
				break

func _refresh_backpack() -> void:
	if backpack_slot_buttons.is_empty():
		return
	if backpack_nav_hint:
		if GameManager.is_gamepad:
			backpack_nav_hint.text = "[A] Взять в руку    [LT / Y] Выбросить    [B] Закрыть"
		else:
			backpack_nav_hint.text = "[ЛКМ] Взять в руку    [ПКМ] Выбросить"
	var items = GameManager.get_backpack_items()
	var act_idx = GameManager.active_item_index

	for i in range(6):
		var btn = backpack_slot_buttons[i]
		for c in btn.get_children():
			c.queue_free()

		var is_active = (i == act_idx)
		var is_cursor = (GameManager.is_gamepad and i == backpack_cursor_index)
		var itm = items[i] if i < items.size() else null
		var has_item = (itm != null and itm.get("id", "empty") != "empty")

		var s = StyleBoxFlat.new()
		s.bg_color = Color(1, 1, 1, 0.09) if has_item else Color(1, 1, 1, 0.03)
		if is_active and has_item:
			s.bg_color = Color(1, 1, 1, 0.14)
			s.border_width_bottom = 2
			s.border_color = HUD_ACCENT
		if is_cursor:
			s.border_width_left = 1
			s.border_width_right = 1
			s.border_width_top = 1
			s.border_width_bottom = 1
			s.border_color = HUD_TEXT

		var sh = s.duplicate()
		sh.bg_color = Color(1, 1, 1, s.bg_color.a + 0.07)
		btn.add_theme_stylebox_override("normal", s)
		btn.add_theme_stylebox_override("hover", sh)
		btn.add_theme_stylebox_override("pressed", sh)

		var num_lbl = Label.new()
		num_lbl.text = str(i + 1)
		num_lbl.position = Vector2(6, 3)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		num_lbl.add_theme_font_size_override("font_size", 11)
		num_lbl.add_theme_color_override("font_color", HUD_DIM)
		btn.add_child(num_lbl)

		if not has_item:
			continue

		var name_lbl = Label.new()
		var cnt_val = itm.get("count", 1)
		name_lbl.text = str(itm["name"]) + (" x%d" % cnt_val if cnt_val > 1 else "")
		name_lbl.position = Vector2(4, 20)
		name_lbl.size = Vector2(74, 50)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", HUD_TEXT)
		btn.add_child(name_lbl)

		# Цвет важен только там, где он что-то значит: ключи и предохранители
		var chip_color = _item_chip_color(itm)
		if chip_color.a > 0.0:
			var chip = ColorRect.new()
			chip.color = chip_color
			chip.position = Vector2(29, 72)
			chip.size = Vector2(24, 3)
			chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(chip)

	_update_backpack_desc(act_idx)

func _item_chip_color(itm: Dictionary) -> Color:
	if itm.has("key_id"):
		var DoorScript = load("res://scripts/Door.gd")
		return DoorScript.get_lock_theme(int(itm["key_id"])).get("color", HUD_TEXT)
	match str(itm.get("id", "")):
		"fuse_red": return Color(0.9, 0.2, 0.2)
		"fuse_blue": return Color(0.25, 0.5, 0.95)
		"fuse_green": return Color(0.25, 0.8, 0.35)
	return Color(0, 0, 0, 0)

func _update_backpack_desc(idx: int) -> void:
	if not backpack_desc_lbl or not backpack_active_lbl:
		return
	var items = GameManager.get_backpack_items()
	if idx >= 0 and idx < items.size():
		var itm = items[idx]
		if itm.get("id", "empty") != "empty":
			var in_hand = "  (в руке)" if idx == GameManager.active_item_index else ""
			backpack_active_lbl.text = str(itm["name"]) + in_hand
			backpack_desc_lbl.text = itm.get("desc", "")
			return
	backpack_active_lbl.text = "Пусто"
	backpack_desc_lbl.text = ""

# ══════════════════════════════════════════════
#  Helpers
# ══════════════════════════════════════════════
func _icon(t: String, sz: int) -> Label:
	var l = Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", sz)
	return l


# ══════════════════════════════════════════════
#  Process
# ══════════════════════════════════════════════
func _process(delta: float) -> void:
	if GameManager.game_ended:
		return
	_update_tape_counter(delta)
	if hint_label.visible:
		hint_timer -= delta
		if hint_timer <= 0.6:
			hint_label.modulate.a = max(0.0, hint_timer / 0.6)
		if hint_timer <= 0.0:
			hint_label.visible = false

	if stamina_container and stamina_bar:
		if stamina_bar.value >= stamina_bar.max_value - 0.5:
			# Когда стамина полная — полупрозрачна (0.35), не отвлекает
			stamina_container.modulate.a = lerp(stamina_container.modulate.a, 0.35, delta * 2.5)
		else:
			# При беге и трате — мгновенно видна на 100%
			stamina_container.modulate.a = lerp(stamina_container.modulate.a, 1.0, delta * 10.0)

	# ── Плавное угасание хотбара в покое для хоррор-погружения ──
	if hotbar_container and not GameManager.is_backpack_open:
		if hotbar_fade_timer > 0.0:
			hotbar_fade_timer -= delta
			hotbar_container.modulate.a = lerpf(hotbar_container.modulate.a, 1.0, delta * 12.0)
		else:
			hotbar_container.modulate.a = lerpf(hotbar_container.modulate.a, 0.55, delta * 2.5)

	# ── Виртуальный курсор мыши на стике геймпада при открытом рюкзаке ──
	if GameManager and GameManager.is_backpack_open:
		_process_backpack_gamepad_cursor(delta)

	# ── Динамическая виньетка страха: нарастает по мере приближения монстра ──
	_update_proximity_fear(delta)

	# ── Обновление индикатора кислорода при нахождении в укрытии ──
	_update_hiding_hud(delta)

func _update_hiding_hud(_delta: float) -> void:
	if not hiding_overlay or not hiding_overlay.visible:
		return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		return

	var oxygen: float = 15.0
	var is_held: bool = false
	if player.has_method("get_oxygen_seconds"):
		oxygen = float(player.call("get_oxygen_seconds"))
	if player.has_method("is_breath_held"):
		is_held = bool(player.call("is_breath_held"))

	var rec_timer: float = 0.0
	if player.has_method("get_breath_recovery_seconds"):
		rec_timer = float(player.call("get_breath_recovery_seconds"))

	if oxygen_progress_bar:
		oxygen_progress_bar.value = oxygen

	if oxygen_status_label and oxygen_bar_fill:
		var low_air = oxygen < 4.0
		oxygen_bar_fill.bg_color = HUD_ACCENT if low_air else HUD_TEXT
		oxygen_status_label.add_theme_color_override("font_color", HUD_ACCENT if low_air else HUD_TEXT)
		if oxygen <= 0.2:
			oxygen_status_label.text = "Воздух кончился"
		elif is_held:
			oxygen_status_label.text = "Не дышишь: %0.1f с" % oxygen
		elif rec_timer > 0.0:
			oxygen_status_label.text = "Отдышка: %0.1f с" % rec_timer
		elif low_air:
			oxygen_status_label.text = "Мало воздуха: %0.1f с" % oxygen
		else:
			oxygen_status_label.text = "Воздух: %0.1f с" % oxygen

func _update_proximity_fear(delta: float) -> void:
	if not fear_vignette:
		return
	var enemy = GameManager.enemy_ref
	var player = GameManager.player_ref
	var target_alpha = 0.0
	var tint = Color(0.12, 0.015, 0.02)
	if is_instance_valid(enemy) and is_instance_valid(player):
		var dist = player.global_position.distance_to(enemy.global_position)
		var enemy_state = enemy.get("state")
		var is_hunting = enemy_state != null and int(enemy_state) in [3, 6]
		if is_hunting:
			target_alpha = clampf((18.0 - dist) / 18.0, 0.0, 1.0) * 0.24
		elif dist < 12.0:
			target_alpha = clampf((12.0 - dist) / 12.0, 0.0, 1.0) * 0.12
	# С кассетой страх виден по помехам: чем ближе монстр, тем хуже запись
	if GameManager.vhs_enabled:
		VHSOverlay.set_fear(move_toward(VHSOverlay.fear, clampf(target_alpha / 0.24, 0.0, 1.0) * 0.7, delta * 0.8))
		target_alpha = 0.0
	fear_vignette.color = Color(tint.r, tint.g, tint.b, move_toward(fear_vignette.color.a, target_alpha, delta * 0.45))

# ══════════════════════════════════════════════
#  Public API
# ══════════════════════════════════════════════
func show_hint(text: String, duration: float = 3.5) -> void:
	if not hint_label:
		return
	if GameManager.is_gamepad:
		text = _format_gamepad_hints(text)
	hint_label.text = text
	hint_label.visible = true
	hint_label.modulate.a = 1.0
	hint_timer = duration

func _format_gamepad_hints(text: String) -> String:
	var t = text
	t = t.replace("[E]", "[RT]")
	t = t.replace("[E ", "[RT ")
	t = t.replace("[E / Esc]", "[RT / B]")
	t = t.replace("[C / E / WASD]", "[B / RT / Стик]")
	t = t.replace("[Таб]", "[X]")
	t = t.replace("[Tab]", "[X]")
	t = t.replace("[ПКМ]", "[LT / Y]")
	t = t.replace("[ЛКМ]", "[RT]")
	t = t.replace("[Shift]", "[LB]")
	t = t.replace("[F]", "[D-Pad ▲]")
	t = t.replace("[Q]", "[LB / R3]")
	t = t.replace("[G]", "[D-Pad ▼]")
	t = t.replace("[Колесико]", "[D-Pad ◄/►]")
	t = t.replace("[◄", "[D-Pad ◄")
	t = t.replace("[C]", "[B]")
	t = t.replace("[Space]", "[A]")
	t = t.replace("[Пробел]", "[A]")
	t = t.replace("[Ctrl]", "[B]")
	t = t.replace("[Esc]", "[Start]")
	return t

func show_interact_hint(text: String) -> void:
	if GameManager.is_gamepad:
		text = _format_gamepad_hints(text)
	else:
		text = text.replace("[E]", "[ЛКМ / E]")
	interact_lbl.text = text

func show_alert(_t: String) -> void:
	pass   # убрали, не нужен

# ══════════════════════════════════════════════
#  Inventory
# ══════════════════════════════════════════════
func _refresh_inventory() -> void:
	if crowbar_icon:
		crowbar_icon.modulate = Color(1.0, 1.0, 1.0) if GameManager.has_crowbar else Color(0.18, 0.18, 0.18)
	if key_icon:
		key_icon.modulate     = GameManager.get_key_display_color()
		if GameManager.has_key:
			key_icon.text = "КЛЮЧ"
		else:
			key_icon.text = ""

	if fuse_red_icon:
		fuse_red_icon.modulate = Color(1.0, 0.25, 0.25) if GameManager.has_fuse_red else Color(0.18, 0.18, 0.18)
	if fuse_blue_icon:
		fuse_blue_icon.modulate = Color(0.25, 0.65, 1.0) if GameManager.has_fuse_blue else Color(0.18, 0.18, 0.18)
	if fuse_green_icon:
		fuse_green_icon.modulate = Color(0.25, 1.0, 0.35) if GameManager.has_fuse_green else Color(0.18, 0.18, 0.18)

	var b_cnt = GameManager.battery_cells
	if battery_icon:
		if b_cnt > 0:
			battery_icon.modulate = Color(0.2, 0.95, 0.3)
			if battery_lbl: battery_lbl.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
		else:
			battery_icon.modulate = Color(0.18, 0.18, 0.18)
			if battery_lbl: battery_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
		if battery_lbl: battery_lbl.text = "%d/%d" % [b_cnt, GameManager.MAX_BATTERY_CELLS]

	_refresh_backpack()
	_refresh_hotbar()
	_flash_hotbar()

func _on_gfx_quality_changed(quality: String) -> void:
	if cinematic_lens_rect:
		cinematic_lens_rect.visible = (quality != "low") and not GameManager.vhs_enabled
	if cinematic_shader_mat:
		var high := quality in ["ultra", "high"]
		cinematic_shader_mat.set_shader_parameter("vignette_opacity", 0.35 if high else 0.50)
		cinematic_shader_mat.set_shader_parameter("grain_intensity", 0.009 if high else 0.016)
		cinematic_shader_mat.set_shader_parameter("chromatic_aberration", 0.0008 if high else 0.0015)
		cinematic_shader_mat.set_shader_parameter("lens_distortion", 0.005 if high else 0.008)


# ══════════════════════════════════════════════
#  СКРИМЕР (РЕАЛИСТИЧНЫЙ ДИНАМИЧЕСКИЙ ХОРРОР)
# ══════════════════════════════════════════════
func _on_game_over() -> void:
	_play_jumpscare()

func _load_ui_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var img = Image.new()
	if img.load(path) == OK:
		return ImageTexture.create_from_image(img)
	return null

func _play_jumpscare() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	VHSOverlay.set_fear(1.0)
	VHSOverlay.glitch(1.0)

	var jumpscare_container = Control.new()
	jumpscare_container.name = "RealHorrorJumpscare"
	jumpscare_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	jumpscare_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(jumpscare_container)

	# ── 1. ЗВУКОВОЙ ТЕРРОР: мощнейший многослойный взрыв ─────────────
	var is_lumberjack = false
	if GameManager and is_instance_valid(GameManager.last_killer):
		var k = GameManager.last_killer
		var k_name = str(k.name).to_lower()
		var k_script = str(k.get_script().resource_path).to_lower() if k.get_script() else ""
		if "lumberjack" in k_name or "лесопил" in k_name or "дед" in k_name or "lumberjack" in k_script:
			is_lumberjack = true

	if is_lumberjack:
		# Сокрушительный выстрел из ружья в упор
		var snd_shot = AudioStreamPlayer.new()
		var st_shot = load("res://assets/audio/shotgun_shot.mp3") if ResourceLoader.exists("res://assets/audio/shotgun_shot.mp3") else null
		if st_shot:
			snd_shot.stream = st_shot
			snd_shot.volume_db = 6.0
			jumpscare_container.add_child(snd_shot)
			snd_shot.play()

		# Зловещий тяжелый храп/хрип деда над поверженной жертвой
		var snd_ded = AudioStreamPlayer.new()
		var st_ded = load("res://assets/ded.mp3") if ResourceLoader.exists("res://assets/ded.mp3") else null
		if st_ded:
			snd_ded.stream = st_ded
			snd_ded.volume_db = 4.0
			jumpscare_container.add_child(snd_ded)
			snd_ded.play()
	else:
		# Новый мощный пронзительный скример монстра-скинвокера
		var snd_skinwalker = AudioStreamPlayer.new()
		var st_skinwalker = load("res://assets/scream.mp3") if ResourceLoader.exists("res://assets/scream.mp3") else load("res://assets/audio/skinwalker_scream.wav")
		if st_skinwalker:
			snd_skinwalker.stream = st_skinwalker
			snd_skinwalker.volume_db = 6.5
			jumpscare_container.add_child(snd_skinwalker)
			snd_skinwalker.play()

	# Глухой удар / сокрушительный саб-бас (костеломный импакт удара)
	var snd_impact = AudioStreamPlayer.new()
	var st_crash = load("res://assets/audio/car_crash.wav")
	if st_crash:
		snd_impact.stream = st_crash
		snd_impact.volume_db = 6.0
		snd_impact.pitch_scale = 0.74
		jumpscare_container.add_child(snd_impact)
		snd_impact.play()

	# Шок / ультразвуковой писк / радио-помехи
	var snd_static = AudioStreamPlayer.new()
	var st_static = load("res://assets/audio/tv_static.wav")
	if st_static:
		snd_static.stream = st_static
		snd_static.volume_db = -2.0
		snd_static.pitch_scale = 1.35
		jumpscare_container.add_child(snd_static)
		snd_static.play()

	# ── 2. ВСПОЛОХ КРОВИ НА ЭКРАНЕ (мгновенная зрительная вспышка) ──
	var red_flash = ColorRect.new()
	red_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	red_flash.color = Color(1.0, 0.04, 0.04, 0.92)
	red_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jumpscare_container.add_child(red_flash)

	# ── 3. ТЕМНАЯ КРОВАВАЯ ВИНЬЕТКА ПО КРАЯМ ─────────────────────────
	var vignette = ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.12, 0.01, 0.01, 0.75)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	jumpscare_container.add_child(vignette)

	# ── 4. КРОВАВЫЕ РАЗРЫВЫ КОГТЯМИ ПО ЭКРАНУ ──────────────────────
	var tex_claw = _load_ui_texture("res://assets/textures/ui/jumpscare_claw_slash.png")
	var claw_rect = TextureRect.new()
	claw_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	claw_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	claw_rect.stretch_mode = TextureRect.STRETCH_SCALE
	claw_rect.texture = tex_claw
	claw_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	claw_rect.modulate = Color(1.3, 0.2, 0.2, 0.0)
	claw_rect.pivot_offset = Vector2(960, 540)
	jumpscare_container.add_child(claw_rect)

	# Второй встречный взмах когтей
	var claw_rect2 = TextureRect.new()
	claw_rect2.set_anchors_preset(Control.PRESET_FULL_RECT)
	claw_rect2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	claw_rect2.stretch_mode = TextureRect.STRETCH_SCALE
	claw_rect2.texture = tex_claw
	claw_rect2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	claw_rect2.modulate = Color(1.3, 0.2, 0.2, 0.0)
	claw_rect2.pivot_offset = Vector2(960, 540)
	claw_rect2.flip_h = true
	claw_rect2.flip_v = true
	jumpscare_container.add_child(claw_rect2)

	# ── 5. АРТЕРИАЛЬНЫЕ БРЫЗГИ КРОВИ НА ОБЪЕКТИВЕ ──────────────────
	var tex_blood = _load_ui_texture("res://assets/textures/ui/jumpscare_blood_splatter.png")
	var blood_rect = TextureRect.new()
	blood_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blood_rect.stretch_mode = TextureRect.STRETCH_SCALE
	blood_rect.texture = tex_blood
	blood_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_rect.modulate = Color(1.0, 1.0, 1.0, 0.0)
	jumpscare_container.add_child(blood_rect)

	# ── 6. ПОЛНОЦЕННАЯ 3D КИНЕМАТОГРАФИЧНАЯ ДИНАМИКА ХОРРОРА ──────
	# (Никакого 2D слайдшоу! Вся сцена видна в честном 3D: морда монстра в упор,
	# когти, разлетающаяся кровь, тряска камеры и падение тела на пол)
	var total_steps = 22
	for i in range(total_steps):
		if not is_inside_tree() or not is_instance_valid(jumpscare_container):
			return

		var progress = float(i) / float(total_steps - 1)

		# Быстрое затухание вспышки (за первые 0.15 сек)
		if is_instance_valid(red_flash):
			red_flash.color.a = maxf(0.0, 0.92 - progress * 5.0)

		# Первый сокрушительный удар когтей (0.05 - 0.25 сек)
		if i == 2:
			claw_rect.modulate = Color(1.4, 0.3, 0.3, 0.98)
			claw_rect.scale = Vector2(1.15, 1.15)
			claw_rect.rotation_degrees = randf_range(-12.0, 12.0)
		elif i > 2 and is_instance_valid(claw_rect):
			claw_rect.modulate.a = maxf(0.0, claw_rect.modulate.a - 0.12)

		# Второй добивающий удар когтей (0.28 - 0.45 сек)
		if i == 7:
			claw_rect2.modulate = Color(1.5, 0.2, 0.2, 0.98)
			claw_rect2.scale = Vector2(1.2, 1.2)
			claw_rect2.rotation_degrees = randf_range(-15.0, 15.0)
		elif i > 7 and is_instance_valid(claw_rect2):
			claw_rect2.modulate.a = maxf(0.0, claw_rect2.modulate.a - 0.14)

		# Брызги крови заливают стекло объектива камеры и стекают вниз
		if i == 4:
			blood_rect.modulate = Color(1.1, 0.9, 0.9, 0.96)
		elif i > 4 and is_instance_valid(blood_rect):
			blood_rect.position.y += 2.2

		# Травматическая тряска интерфейса в унисон с камерой 3D
		var ui_shake = lerpf(35.0, 8.0, progress)
		jumpscare_container.position = Vector2(randf_range(-ui_shake, ui_shake), randf_range(-ui_shake * 0.7, ui_shake * 0.7))

		# Сужение туннельного зрения (агония)
		if is_instance_valid(vignette):
			vignette.color = Color(0.15 + progress * 0.25, 0.01, 0.01, minf(0.95, 0.4 + progress * 0.55))

		var frame_dt = 0.040 if i < 14 else 0.052
		await get_tree().create_timer(frame_dt).timeout

	# ── 7. ЗАТЕМНЕНИЕ В КРОВЬ И ПУСТОТУ (Падение на пол и смерть) ──
	if not is_inside_tree() or not is_instance_valid(root_ctrl):
		return

	var blood_wash = ColorRect.new()
	blood_wash.name = "BloodWash"
	blood_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_wash.color = Color(0.60, 0.02, 0.02, 0.90)
	blood_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(blood_wash)

	var blackout = ColorRect.new()
	blackout.name = "Blackout"
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.color = Color(0, 0, 0, 0)
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(blackout)

	var fade_tw = create_tween()
	fade_tw.tween_property(blackout, "color:a", 1.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fade_tw.finished

	if is_instance_valid(jumpscare_container):
		jumpscare_container.queue_free()
	if is_instance_valid(blood_wash):
		blood_wash.queue_free()

	await get_tree().create_timer(0.25).timeout
	_show_death_screen()


func clear_end_screens() -> void:
	for node in end_screens:
		if is_instance_valid(node):
			node.queue_free()
	end_screens.clear()
	if root_ctrl and is_instance_valid(root_ctrl):
		for ch in root_ctrl.get_children():
			if ch.name in ["RealHorrorJumpscare", "BloodWash", "Blackout"]:
				ch.queue_free()
	if GameManager:
		GameManager.game_ended = false
		GameManager.is_reading_note = false
		if GameManager.is_backpack_open:
			GameManager.close_backpack()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if pause_root and pause_root.visible:
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) or \
		   (event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_START, JOY_BUTTON_B]):
			_close_pause()
			get_viewport().set_input_as_handled()
		return

	# Горячие клавиши перезапуска при завершении игры (смерть или побег)
	if GameManager and GameManager.game_ended:
		if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R) or \
		   (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A):
			var cur_scene = get_tree().current_scene
			clear_end_screens()
			if cur_scene and cur_scene.name == "DebugEditor" and cur_scene.has_method("restart_playtest"):
				cur_scene.restart_playtest()
			else:
				if GameManager:
					GameManager.reset_state()
				get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()
			return
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_7:
			var cur_scene = get_tree().current_scene
			if cur_scene and cur_scene.name == "DebugEditor" and cur_scene.has_method("stop_playtest"):
				clear_end_screens()
				cur_scene.stop_playtest()
				get_viewport().set_input_as_handled()
				return
		elif (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE) or \
			 (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START):
			clear_end_screens()
			get_tree().change_scene_to_file("res://scenes/Menu.tscn")
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB or event.keycode == KEY_X:
			GameManager.toggle_backpack()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_ESCAPE:
			if GameManager.is_backpack_open:
				GameManager.close_backpack()
				get_viewport().set_input_as_handled()
				return
			elif GameManager.game_ended:
				clear_end_screens()
				get_tree().change_scene_to_file("res://scenes/Menu.tscn")
				get_viewport().set_input_as_handled()
				return
			elif _can_pause():
				_open_pause()
				get_viewport().set_input_as_handled()
				return
		elif GameManager.is_backpack_open and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			var slot_idx = event.keycode - KEY_1
			backpack_cursor_index = slot_idx
			_on_slot_clicked(slot_idx)
			get_viewport().set_input_as_handled()
			return

	if GameManager.is_backpack_open:
		if event is InputEventJoypadButton and event.pressed:
			GameManager.is_gamepad = true
			if event.button_index == JOY_BUTTON_DPAD_LEFT:
				backpack_cursor_index = posmod(backpack_cursor_index - 1, 6)
				_update_backpack_desc(backpack_cursor_index)
				_refresh_backpack()
				_warp_mouse_to_slot(backpack_cursor_index)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
				backpack_cursor_index = posmod(backpack_cursor_index + 1, 6)
				_update_backpack_desc(backpack_cursor_index)
				_refresh_backpack()
				_warp_mouse_to_slot(backpack_cursor_index)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == JOY_BUTTON_A:
				_handle_gamepad_backpack_click(false)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index in [JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER]:
				_handle_gamepad_backpack_click(true)
				get_viewport().set_input_as_handled()
				return
			elif event.button_index in [JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_START, JOY_BUTTON_BACK]:
				GameManager.close_backpack()
				get_viewport().set_input_as_handled()
				return
		elif event is InputEventJoypadMotion:
			if event.axis == JOY_AXIS_TRIGGER_LEFT and event.axis_value > 0.5:
				_handle_gamepad_backpack_click(true)
				get_viewport().set_input_as_handled()
				return
	else:
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_X:
				GameManager.toggle_backpack()
				get_viewport().set_input_as_handled()
				return
			elif event.button_index == JOY_BUTTON_START:
				if GameManager.game_ended:
					clear_end_screens()
					get_tree().change_scene_to_file("res://scenes/Menu.tscn")
					get_viewport().set_input_as_handled()
					return
				elif _can_pause():
					_open_pause()
					get_viewport().set_input_as_handled()
					return

func _show_death_screen() -> void:
	clear_end_screens()
	VHSOverlay.set_fear(0.0)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.94)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(bg)
	end_screens.append(bg)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	root_ctrl.add_child(vb)
	end_screens.append(vb)

	var msg = Label.new()
	msg.text                  = "ОН НАШЁЛ ТЕБЯ"
	msg.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_override("font", VHSOverlay.tracked_font(6))
	msg.add_theme_font_size_override("font_size", 34)
	msg.add_theme_color_override("font_color", HUD_ACCENT)
	vb.add_child(msg)

	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.name == "DebugEditor":
		var rst_btn = Button.new()
		rst_btn.text = "В ИСХОДНОЕ ПОЛОЖЕНИЕ  R"
		rst_btn.custom_minimum_size = Vector2(280, 44)
		rst_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rst_btn.add_theme_font_size_override("font_size", 16)
		rst_btn.pressed.connect(func():
			clear_end_screens()
			if cur_scene.has_method("restart_playtest"):
				cur_scene.restart_playtest()
		)
		vb.add_child(rst_btn)

		var ed_btn = Button.new()
		ed_btn.text = "ВЕРНУТЬСЯ В РЕДАКТОР  7"
		ed_btn.custom_minimum_size = Vector2(280, 44)
		ed_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ed_btn.add_theme_font_size_override("font_size", 16)
		ed_btn.pressed.connect(func():
			clear_end_screens()
			if cur_scene.has_method("stop_playtest"):
				cur_scene.stop_playtest()
		)
		vb.add_child(ed_btn)
	else:
		var camp_rst = Button.new()
		camp_rst.text = "НАЧАТЬ ЗАНОВО  R"
		camp_rst.custom_minimum_size = Vector2(280, 44)
		camp_rst.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		camp_rst.add_theme_font_size_override("font_size", 16)
		camp_rst.pressed.connect(func():
			clear_end_screens()
			if GameManager:
				GameManager.reset_state()
			get_tree().reload_current_scene()
		)
		vb.add_child(camp_rst)

	var sub_btn = Button.new()
	sub_btn.text = "В ГЛАВНОЕ МЕНЮ  ESC"
	sub_btn.custom_minimum_size = Vector2(280, 44)
	sub_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sub_btn.add_theme_font_size_override("font_size", 16)
	sub_btn.pressed.connect(func():
		clear_end_screens()
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	)
	vb.add_child(sub_btn)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ══════════════════════════════════════════════
#  ПОБЕДА
# ══════════════════════════════════════════════
func _on_win() -> void:
	show_alpha_end_screen()

# ══════════════════════════════════════════════
#  ФИНАЛЬНЫЙ ЭКРАН ALPHA ДЕМО
# ══════════════════════════════════════════════
func show_alpha_end_screen() -> void:
	clear_end_screens()
	if GameManager:
		GameManager.game_ended = true

	# Полноэкранный фон с плавным появлением (темный бархат)
	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_ctrl.add_child(bg)
	end_screens.append(bg)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 20)
	vb.modulate = Color(1, 1, 1, 0)
	root_ctrl.add_child(vb)
	end_screens.append(vb)

	# Главный заголовок по запросу игрока
	var msg = Label.new()
	msg.text = "Alpha заканчивается тут, спасибо поиграли"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", HUD_TEXT)
	vb.add_child(msg)

	# Подзаголовок
	var submsg = Label.new()
	submsg.text = "Ты выбрался."
	submsg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	submsg.add_theme_font_size_override("font_size", 15)
	submsg.add_theme_color_override("font_color", HUD_DIM)
	vb.add_child(submsg)

	# Отступ перед кнопками
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)

	# Кнопка «В главное меню»
	var menu_btn = Button.new()
	menu_btn.text = "В ГЛАВНОЕ МЕНЮ  ESC"
	menu_btn.custom_minimum_size = Vector2(300, 48)
	menu_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_btn.add_theme_font_size_override("font_size", 17)
	menu_btn.pressed.connect(func():
		clear_end_screens()
		if GameManager:
			GameManager.reset_state()
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	)
	vb.add_child(menu_btn)

	# Кнопка «Начать заново»
	var rst_btn = Button.new()
	rst_btn.text = "НАЧАТЬ ЗАНОВО  R"
	rst_btn.custom_minimum_size = Vector2(300, 48)
	rst_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rst_btn.add_theme_font_size_override("font_size", 17)
	rst_btn.pressed.connect(func():
		clear_end_screens()
		if GameManager:
			GameManager.reset_state()
		get_tree().reload_current_scene()
	)
	vb.add_child(rst_btn)

	# Кнопка «Выйти из игры»
	var exit_btn = Button.new()
	exit_btn.text = "ВЫЙТИ ИЗ ИГРЫ"
	exit_btn.custom_minimum_size = Vector2(300, 48)
	exit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	exit_btn.add_theme_font_size_override("font_size", 17)
	exit_btn.pressed.connect(func():
		get_tree().quit()
	)
	vb.add_child(exit_btn)

	# Плавное появление (Fade-in)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(bg, "color:a", 0.95, 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(vb, "modulate:a", 1.0, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	menu_btn.grab_focus()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ──────────────────────────────────────────────
#  Интерактивный прицел (Crosshair & Throw Charge)
# ──────────────────────────────────────────────
var crosshair_container: Control = null
var crosshair_dot: ColorRect = null
var crosshair_ring: Control = null
var crosshair_hover_active: bool = false
var throw_charge_container: Control = null
var throw_charge_bar: ColorRect = null
var throw_charge_bg: ColorRect = null

func _build_crosshair_ui() -> void:
	crosshair_container = Control.new()
	crosshair_container.name = "CrosshairContainer"
	crosshair_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_container.set_anchors_preset(Control.PRESET_CENTER)
	root_ctrl.add_child(crosshair_container)

	# Центральная точка
	crosshair_dot = ColorRect.new()
	crosshair_dot.name = "CrosshairDot"
	crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_dot.size = Vector2(3, 3)
	crosshair_dot.position = Vector2(-1.5, -1.5)
	crosshair_dot.color = Color(1.0, 1.0, 1.0, 0.65)
	crosshair_container.add_child(crosshair_dot)

	# Кольцо фокусировки при наведении на интерактивные предметы
	crosshair_ring = Control.new()
	crosshair_ring.name = "CrosshairRing"
	crosshair_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_ring.size = Vector2(24, 24)
	crosshair_ring.position = Vector2(-12, -12)
	crosshair_ring.modulate.a = 0.0
	crosshair_ring.scale = Vector2(0.6, 0.6)
	crosshair_ring.pivot_offset = Vector2(12, 12)

	# 4 маркера фокуса по углам (bracket crosshair)
	for i in range(4):
		var b_line1 = ColorRect.new()
		var b_line2 = ColorRect.new()
		var col = Color(HUD_TEXT.r, HUD_TEXT.g, HUD_TEXT.b, 0.9)
		b_line1.color = col
		b_line2.color = col
		b_line1.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b_line2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match i:
			0:
				b_line1.size = Vector2(5, 2); b_line1.position = Vector2(0, 0)
				b_line2.size = Vector2(2, 5); b_line2.position = Vector2(0, 0)
			1:
				b_line1.size = Vector2(5, 2); b_line1.position = Vector2(19, 0)
				b_line2.size = Vector2(2, 5); b_line2.position = Vector2(22, 0)
			2:
				b_line1.size = Vector2(5, 2); b_line1.position = Vector2(0, 22)
				b_line2.size = Vector2(2, 5); b_line2.position = Vector2(0, 19)
			3:
				b_line1.size = Vector2(5, 2); b_line1.position = Vector2(19, 22)
				b_line2.size = Vector2(2, 5); b_line2.position = Vector2(22, 19)
		crosshair_ring.add_child(b_line1)
		crosshair_ring.add_child(b_line2)

	crosshair_container.add_child(crosshair_ring)

	# Полоска заряда броска (Throw Charge Meter)
	throw_charge_container = Control.new()
	throw_charge_container.name = "ThrowChargeContainer"
	throw_charge_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_charge_container.size = Vector2(64, 3)
	throw_charge_container.position = Vector2(-32, 22)
	throw_charge_container.visible = false

	throw_charge_bg = ColorRect.new()
	throw_charge_bg.name = "ChargeBG"
	throw_charge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_charge_bg.size = Vector2(64, 3)
	throw_charge_bg.color = Color(1, 1, 1, 0.12)
	throw_charge_container.add_child(throw_charge_bg)

	throw_charge_bar = ColorRect.new()
	throw_charge_bar.name = "ChargeFill"
	throw_charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_charge_bar.size = Vector2(0, 3)
	throw_charge_bar.color = HUD_TEXT
	throw_charge_container.add_child(throw_charge_bar)

	crosshair_container.add_child(throw_charge_container)

func set_crosshair_hover(hover: bool) -> void:
	if crosshair_hover_active == hover:
		return
	crosshair_hover_active = hover
	if not crosshair_ring or not crosshair_dot:
		return
	var tw = create_tween()
	tw.set_parallel(true)
	if hover:
		tw.tween_property(crosshair_ring, "modulate:a", 1.0, 0.12)
		tw.tween_property(crosshair_ring, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(crosshair_dot, "color", Color(1.0, 1.0, 1.0, 1.0), 0.12)
		tw.tween_property(crosshair_dot, "scale", Vector2(1.4, 1.4), 0.12)
	else:
		tw.tween_property(crosshair_ring, "modulate:a", 0.0, 0.15)
		tw.tween_property(crosshair_ring, "scale", Vector2(0.6, 0.6), 0.15)
		tw.tween_property(crosshair_dot, "color", Color(1.0, 1.0, 1.0, 0.65), 0.15)
		tw.tween_property(crosshair_dot, "scale", Vector2(1.0, 1.0), 0.15)

func update_throw_charge(charge_val: float) -> void:
	if not throw_charge_container or not throw_charge_bar:
		return
	if charge_val <= 0.01:
		throw_charge_container.visible = false
		throw_charge_bar.size.x = 0
	else:
		throw_charge_container.visible = true
		var max_w = 64.0
		throw_charge_bar.size.x = clampf(charge_val, 0.0, 1.0) * max_w
		throw_charge_bar.color = HUD_TEXT.lerp(HUD_ACCENT, charge_val)

func set_crosshair_visible(v: bool) -> void:
	if crosshair_container:
		crosshair_container.visible = v

# ──────────────────────────────────────────────
#  Счётчик кассеты
# ──────────────────────────────────────────────
func _build_tape_counter() -> void:
	tape_dot = ColorRect.new()
	tape_dot.color = HUD_ACCENT
	tape_dot.position = Vector2(30, 27)
	tape_dot.size = Vector2(8, 8)
	tape_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(tape_dot)

	tape_lbl = Label.new()
	tape_lbl.position = Vector2(46, 20)
	tape_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tape_lbl.add_theme_font_override("font", VHSOverlay.tracked_font(2))
	tape_lbl.add_theme_font_size_override("font_size", 14)
	tape_lbl.add_theme_color_override("font_color", HUD_DIM)
	root_ctrl.add_child(tape_lbl)

func _update_tape_counter(delta: float) -> void:
	if not tape_lbl or get_tree().paused:
		return
	tape_time += delta
	var total = int(tape_time)
	tape_lbl.text = "ЗАП  %02d:%02d:%02d" % [total / 3600, (total / 60) % 60, total % 60]
	tape_dot.visible = fmod(tape_time, 1.0) < 0.6

# ──────────────────────────────────────────────
#  Подсказка по кнопкам в начале игры
# ──────────────────────────────────────────────
func _add_controls_rows(parent: Control, rows: Array, x: float, y: float, step: float) -> void:
	for i in range(rows.size()):
		var key_lbl = Label.new()
		key_lbl.text = rows[i][0]
		key_lbl.position = Vector2(x, y + i * step)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_lbl.add_theme_font_size_override("font_size", 14)
		key_lbl.add_theme_color_override("font_color", HUD_TEXT)
		parent.add_child(key_lbl)

		var act_lbl = Label.new()
		act_lbl.text = rows[i][1]
		act_lbl.position = Vector2(x + 96, y + i * step)
		act_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		act_lbl.add_theme_font_size_override("font_size", 14)
		act_lbl.add_theme_color_override("font_color", HUD_DIM)
		parent.add_child(act_lbl)

func _build_controls_help() -> void:
	controls_help = Control.new()
	controls_help.name = "ControlsHelp"
	controls_help.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(controls_help)

	var rows = [
		["WASD", "идти"],
		["ЛКМ / E", "действие"],
		["F", "фонарик"],
		["TAB", "рюкзак"],
		["ESC", "пауза и все кнопки"],
	]
	_add_controls_rows(controls_help, rows, 30.0, 540.0, 24.0)

	var tw = create_tween()
	tw.tween_interval(22.0)
	tw.tween_property(controls_help, "modulate:a", 0.0, 2.5)
	tw.tween_callback(controls_help.hide)

# ──────────────────────────────────────────────
#  Пауза
# ──────────────────────────────────────────────
func _can_pause() -> bool:
	if GameManager.game_ended or GameManager.is_reading_note or GameManager.is_backpack_open:
		return false
	# Без захваченной мыши открыт сейф, щиток или другое окно
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return false
	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.name in ["DebugEditor", "Polygon"]:
		return false
	var player = GameManager.player_ref
	if is_instance_valid(player):
		if player.get("is_hiding") == true or player.get("is_peeking_keyhole") == true or player.get("is_in_cutscene") == true:
			return false
	return true

func _make_pause_button(text: String, y: float, cb: Callable) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.position = Vector2(92, y)
	btn.size = Vector2(300, 32)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_override("font", VHSOverlay.tracked_font(3))
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(cb)
	pause_root.add_child(btn)

	var bar = ColorRect.new()
	bar.color = Color(1.0, 0.07, 0.05)
	bar.position = Vector2(-10, 7)
	bar.size = Vector2(3, 18)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.visible = false
	btn.add_child(bar)
	btn.focus_entered.connect(func(): bar.visible = true)
	btn.focus_exited.connect(func(): bar.visible = false)
	btn.mouse_entered.connect(btn.grab_focus)
	return btn

func _build_pause_menu() -> void:
	pause_root = ColorRect.new()
	pause_root.name = "PauseMenu"
	pause_root.color = Color(0.0, 0.0, 0.0, 0.72)
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	root_ctrl.add_child(pause_root)

	var title = Label.new()
	title.text = "ПАУЗА"
	title.position = Vector2(97, 178)
	title.add_theme_font_override("font", VHSOverlay.tracked_font(5))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", HUD_TEXT)
	pause_root.add_child(title)

	pause_first_btn = _make_pause_button("ПРОДОЛЖИТЬ", 258.0, _close_pause)
	_make_pause_button("НАЧАТЬ ЗАНОВО", 295.0, func():
		get_tree().paused = false
		GameManager.reset_state()
		get_tree().reload_current_scene()
	)
	_make_pause_button("В ГЛАВНОЕ МЕНЮ", 332.0, func():
		get_tree().paused = false
		GameManager.reset_state()
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
	)

	var ctrl_title = Label.new()
	ctrl_title.text = "УПРАВЛЕНИЕ"
	ctrl_title.position = Vector2(620, 262)
	ctrl_title.add_theme_font_override("font", VHSOverlay.tracked_font(3))
	ctrl_title.add_theme_font_size_override("font_size", 15)
	ctrl_title.add_theme_color_override("font_color", HUD_DIM)
	pause_root.add_child(ctrl_title)
	_add_controls_rows(pause_root, CONTROLS_LIST, 620.0, 298.0, 25.0)

func _open_pause() -> void:
	pause_root.visible = true
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	pause_first_btn.grab_focus()
	VHSOverlay.glitch(0.5)

func _close_pause() -> void:
	pause_root.visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
