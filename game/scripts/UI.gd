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
var gfx_btn:      Button = null
var backpack_btn: Button = null

# ── Индикатор выносливости (Stamina Bar) ──
var stamina_container: PanelContainer = null
var stamina_bar:       ProgressBar = null
var stamina_icon:      Label = null
var end_screens:       Array[Node] = []

# Виньетка страха и сердцебиения
var fear_vignette: ColorRect
var cinematic_lens_rect: ColorRect = null
var cinematic_shader_mat: ShaderMaterial = null
var vhs_rec_label: Label = null
var vhs_counter_label: Label = null
var vhs_date_label: Label = null
var vhs_time := 0.0


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

# ── Чек-лист двери побега и инспектор замков ──
var escape_door_card: PanelContainer = null
var escape_step_boards_lbl: Label = null
var escape_step_power_lbl: Label = null
var escape_step_key_lbl: Label = null
var escape_status_lbl: Label = null

var door_inspect_card: PanelContainer = null
var door_inspect_title: Label = null
var door_inspect_status_badge: Label = null
var door_inspect_lock_lbl: Label = null
var door_inspect_lock_status: Label = null
var door_inspect_boards_lbl: Label = null
var door_inspect_boards_status: Label = null
var door_inspect_power_lbl: Label = null
var door_inspect_action_prompt: Label = null

# ── Связка ключей и инструментов на HUD ──
var keyring_card: PanelContainer = null
var keyring_items_vbox: VBoxContainer = null

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
	_build_ui()
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
	interact_lbl.add_theme_font_size_override("font_size", 14)
	interact_lbl.add_theme_color_override("font_color", Color(0.88, 0.85, 0.72, 0.95))
	interact_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	interact_lbl.add_theme_constant_override("shadow_offset_x", 1)
	interact_lbl.add_theme_constant_override("shadow_offset_y", 1)
	interact_lbl.set_anchor_and_offset(SIDE_LEFT,   0.20, 0)
	interact_lbl.set_anchor_and_offset(SIDE_RIGHT,  0.80, 0)
	interact_lbl.set_anchor_and_offset(SIDE_BOTTOM, 1,   -45)
	interact_lbl.set_anchor_and_offset(SIDE_TOP,    1,   -75)
	root_ctrl.add_child(interact_lbl)

	# ── История/события (затухает) ─────────────
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode        = TextServer.AUTOWRAP_WORD
	hint_label.add_theme_font_size_override("font_size", 14)
	hint_label.add_theme_color_override("font_color",        Color(0.88, 0.82, 0.62))
	hint_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	hint_label.add_theme_constant_override("shadow_offset_x", 1)
	hint_label.add_theme_constant_override("shadow_offset_y", 1)
	hint_label.set_anchor_and_offset(SIDE_LEFT,   0.10, 0)
	hint_label.set_anchor_and_offset(SIDE_RIGHT,  0.90, 0)
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

	# ── Чек-лист двери победы и инспектор дверей/замков ───────────────
	_build_escape_door_card()
	_build_door_inspect_card()

	# ── Связка ключей и инструментов на HUD ──
	_build_keyring_hud()

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

	# ── Водяной знак версии игры ──
	var alpha_lbl = Label.new()
	alpha_lbl.name = "AlphaVersionLabel"
	alpha_lbl.text = "alpha 0.1"
	alpha_lbl.add_theme_font_size_override("font_size", 11)
	alpha_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70, 0.40))
	alpha_lbl.set_anchor_and_offset(SIDE_RIGHT, 1.0, -18)
	alpha_lbl.set_anchor_and_offset(SIDE_TOP, 0.0, 14)
	alpha_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	alpha_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(alpha_lbl)

	# ── Маленькое объяснение кнопок как надпись alpha 0.1 ──
	var guide_lbl = Label.new()
	guide_lbl.name = "ControlsGuideLabel"
	guide_lbl.text = "WASD — Ходить  •  Shift — Бег  •  C — Присесть  •  E — Действие  •  F — Фонарик  •  Tab — Рюкзак  •  ПКМ — Сброс  •  F3 — Графика  •  F4 — VHS"
	guide_lbl.add_theme_font_size_override("font_size", 10)
	guide_lbl.add_theme_color_override("font_color", Color(0.70, 0.70, 0.70, 0.40))
	guide_lbl.set_anchor_and_offset(SIDE_RIGHT, 1.0, -18)
	guide_lbl.set_anchor_and_offset(SIDE_TOP, 0.0, 32)
	guide_lbl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	guide_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(guide_lbl)

	var tw_g = create_tween()
	tw_g.tween_interval(16.0)
	tw_g.tween_property(guide_lbl, "modulate:a", 0.30, 4.0)

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
	_build_vhs_hud()
	_on_vhs_changed(GameManager.vhs_enabled)
	if not GameManager.vhs_changed.is_connected(_on_vhs_changed):
		GameManager.vhs_changed.connect(_on_vhs_changed)

# Надписи видеокамеры: мигающий REC, счётчик плёнки, дата и время записи
func _build_vhs_hud() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
	font.font_weight = 700
	var make := func(lbl_name: String, size: int, col: Color) -> Label:
		var l := Label.new()
		l.name = lbl_name
		l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", size)
		l.add_theme_color_override("font_color", col)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		l.add_theme_constant_override("shadow_offset_x", 2)
		l.add_theme_constant_override("shadow_offset_y", 2)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root_ctrl.add_child(l)
		return l

	vhs_rec_label = make.call("VhsRec", 28, Color(0.95, 0.12, 0.08, 0.92))
	vhs_rec_label.text = "● REC"
	vhs_rec_label.set_anchor_and_offset(SIDE_LEFT, 0.0, 28)
	vhs_rec_label.set_anchor_and_offset(SIDE_TOP, 0.0, 56)

	vhs_counter_label = make.call("VhsCounter", 20, Color(0.92, 0.92, 0.86, 0.82))
	vhs_counter_label.set_anchor_and_offset(SIDE_LEFT, 0.0, 28)
	vhs_counter_label.set_anchor_and_offset(SIDE_TOP, 0.0, 94)

	vhs_date_label = make.call("VhsDate", 22, Color(0.92, 0.92, 0.86, 0.82))
	vhs_date_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	vhs_date_label.offset_left = -28
	vhs_date_label.offset_right = -28
	vhs_date_label.offset_top = -96
	vhs_date_label.offset_bottom = -40
	vhs_date_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	vhs_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_update_vhs_hud(0.0)

func _on_vhs_changed(enabled: bool) -> void:
	if cinematic_shader_mat:
		cinematic_shader_mat.set_shader_parameter("vhs_amount", 1.0 if enabled else 0.0)
	for l in [vhs_rec_label, vhs_counter_label, vhs_date_label]:
		if l:
			l.visible = enabled

func _update_vhs_hud(delta: float) -> void:
	if not vhs_rec_label:
		return
	vhs_time += delta
	# Плёнка чувствует монстра: чем он ближе, тем сильнее срывы картинки
	var stress := 0.0
	var e = GameManager.enemy_ref
	var cam := get_viewport().get_camera_3d()
	if is_instance_valid(e) and cam and e is Node3D:
		stress = clampf(1.0 - cam.global_position.distance_to(e.global_position) / 14.0, 0.0, 1.0)
	if cinematic_shader_mat:
		cinematic_shader_mat.set_shader_parameter("vhs_stress", stress * stress)
	vhs_rec_label.modulate.a = 1.0 if fmod(vhs_time, 1.0) < 0.6 else 0.0
	var sec := int(vhs_time)
	vhs_counter_label.text = "SP  %d:%02d:%02d" % [sec / 3600, (sec / 60) % 60, sec % 60]
	# Запись начинается ночью 31 октября и идёт в реальном времени
	var clock := 23 * 3600 + 47 * 60 + sec
	vhs_date_label.text = "%02d:%02d:%02d\nОКТ. 31 1994" % [(clock / 3600) % 24, (clock / 60) % 60, clock % 60]

func _build_stamina_ui() -> void:
	stamina_container = PanelContainer.new()
	stamina_container.name = "StaminaContainer"
	stamina_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -115)
	stamina_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 115)
	stamina_container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -18)
	stamina_container.set_anchor_and_offset(SIDE_TOP, 1.0, -32)
	stamina_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.05, 0.07, 0.65)
	p_style.border_width_left = 1
	p_style.border_width_right = 1
	p_style.border_width_top = 1
	p_style.border_width_bottom = 1
	p_style.border_color = Color(0.25, 0.28, 0.32, 0.55)
	p_style.corner_radius_top_left = 3
	p_style.corner_radius_top_right = 3
	p_style.corner_radius_bottom_left = 3
	p_style.corner_radius_bottom_right = 3
	p_style.set_content_margin_all(2)
	stamina_container.add_theme_stylebox_override("panel", p_style)
	root_ctrl.add_child(stamina_container)

	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 6)
	stamina_container.add_child(hb)

	stamina_icon = Label.new()
	stamina_icon.text = ""
	stamina_icon.add_theme_font_size_override("font_size", 9)
	stamina_icon.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.75))
	hb.add_child(stamina_icon)

	stamina_bar = ProgressBar.new()
	stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_bar.size_flags_vertical = Control.SIZE_FILL
	stamina_bar.show_percentage = false
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.07, 0.09, 0.8)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	stamina_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = Color(0.85, 0.89, 0.95, 0.85)
	bar_fg.corner_radius_top_left = 2
	bar_fg.corner_radius_top_right = 2
	bar_fg.corner_radius_bottom_left = 2
	bar_fg.corner_radius_bottom_right = 2
	stamina_bar.add_theme_stylebox_override("fill", bar_fg)

	hb.add_child(stamina_bar)

func _on_stamina_changed(cur_stamina: float, max_stamina: float, is_exhausted: bool) -> void:
	if not stamina_bar or not stamina_container:
		return

	stamina_bar.max_value = max_stamina
	stamina_bar.value = cur_stamina

	var ratio = cur_stamina / max(1.0, max_stamina)
	var fg_mat = stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat

	if is_exhausted:
		if fg_mat:
			fg_mat.bg_color = Color(0.92, 0.25, 0.25, 0.90)
		if stamina_icon:
			stamina_icon.text = ""
			stamina_icon.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	elif ratio < 0.30:
		if fg_mat:
			fg_mat.bg_color = Color(0.95, 0.68, 0.22, 0.90)
		if stamina_icon:
			stamina_icon.text = ""
			stamina_icon.add_theme_color_override("font_color", Color(0.95, 0.70, 0.25))
	else:
		if fg_mat:
			fg_mat.bg_color = Color(0.85, 0.89, 0.95, 0.85)
		if stamina_icon:
			stamina_icon.text = ""
			stamina_icon.add_theme_color_override("font_color", Color(0.85, 0.88, 0.92, 0.75))

# ══════════════════════════════════════════════
#  Быстрый HUD Хотбар предметов [1]..[6]
# ══════════════════════════════════════════════
func _build_hotbar_ui() -> void:
	hotbar_container = PanelContainer.new()
	hotbar_container.name = "HUDHotbar"
	hotbar_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -172)
	hotbar_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 172)
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
	hb_style.corner_radius_top_left = 6
	hb_style.corner_radius_top_right = 6
	hb_style.corner_radius_bottom_left = 6
	hb_style.corner_radius_bottom_right = 6
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
		slot_style.corner_radius_top_left = 5
		slot_style.corner_radius_top_right = 5
		slot_style.corner_radius_bottom_left = 5
		slot_style.corner_radius_bottom_right = 5
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
		s.corner_radius_top_left = 5
		s.corner_radius_top_right = 5
		s.corner_radius_bottom_left = 5
		s.corner_radius_bottom_right = 5

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

func _build_escape_door_card() -> void:
	escape_door_card = PanelContainer.new()
	escape_door_card.set_anchor_and_offset(SIDE_LEFT, 0.5, -200)
	escape_door_card.set_anchor_and_offset(SIDE_RIGHT, 0.5, 200)
	escape_door_card.set_anchor_and_offset(SIDE_TOP, 0, 16)
	escape_door_card.set_anchor_and_offset(SIDE_BOTTOM, 0, 150)
	escape_door_card.visible = false
	escape_door_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.94)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 3
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.72, 0.32, 0.90)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.set_content_margin_all(8)
	escape_door_card.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(escape_door_card)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	escape_door_card.add_child(vb)

	var title = Label.new()
	title.text = "ВЫХОДНАЯ ДВЕРЬ ОСОБНЯКА"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.60))
	vb.add_child(title)

	escape_step_boards_lbl = Label.new()
	escape_step_boards_lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(escape_step_boards_lbl)

	escape_step_power_lbl = Label.new()
	escape_step_power_lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(escape_step_power_lbl)

	escape_step_key_lbl = Label.new()
	escape_step_key_lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(escape_step_key_lbl)

	escape_status_lbl = Label.new()
	escape_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	escape_status_lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(escape_status_lbl)

func _build_door_inspect_card() -> void:
	door_inspect_card = PanelContainer.new()
	door_inspect_card.set_anchor_and_offset(SIDE_LEFT, 0.5, -215)
	door_inspect_card.set_anchor_and_offset(SIDE_RIGHT, 0.5, 215)
	door_inspect_card.set_anchor_and_offset(SIDE_TOP, 0, 16)
	door_inspect_card.set_anchor_and_offset(SIDE_BOTTOM, 0, 155)
	door_inspect_card.visible = false
	door_inspect_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.95)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 3
	style.border_width_bottom = 2
	style.border_color = Color(0.85, 0.72, 0.32, 0.90)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.set_content_margin_all(8)
	door_inspect_card.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(door_inspect_card)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 3)
	door_inspect_card.add_child(vb)

	var header_hb = HBoxContainer.new()
	vb.add_child(header_hb)

	door_inspect_title = Label.new()
	door_inspect_title.text = "ДВЕРЬ"
	door_inspect_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	door_inspect_title.add_theme_font_size_override("font_size", 13)
	door_inspect_title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.60))
	header_hb.add_child(door_inspect_title)

	door_inspect_status_badge = Label.new()
	door_inspect_status_badge.text = "[ЗАПЕРТА]"
	door_inspect_status_badge.add_theme_font_size_override("font_size", 11)
	door_inspect_status_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	header_hb.add_child(door_inspect_status_badge)

	# Замок
	var lock_hb = HBoxContainer.new()
	lock_hb.name = "LockRow"
	vb.add_child(lock_hb)

	door_inspect_lock_lbl = Label.new()
	door_inspect_lock_lbl.text = "Замок:"
	door_inspect_lock_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	door_inspect_lock_lbl.add_theme_font_size_override("font_size", 11)
	lock_hb.add_child(door_inspect_lock_lbl)

	door_inspect_lock_status = Label.new()
	door_inspect_lock_status.text = "—"
	door_inspect_lock_status.add_theme_font_size_override("font_size", 11)
	lock_hb.add_child(door_inspect_lock_status)

	# Доски
	var boards_hb = HBoxContainer.new()
	boards_hb.name = "BoardsRow"
	vb.add_child(boards_hb)

	door_inspect_boards_lbl = Label.new()
	door_inspect_boards_lbl.text = "Доски:"
	door_inspect_boards_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	door_inspect_boards_lbl.add_theme_font_size_override("font_size", 11)
	boards_hb.add_child(door_inspect_boards_lbl)

	door_inspect_boards_status = Label.new()
	door_inspect_boards_status.text = "—"
	door_inspect_boards_status.add_theme_font_size_override("font_size", 11)
	boards_hb.add_child(door_inspect_boards_status)

	# Электрощиток / Питание
	door_inspect_power_lbl = Label.new()
	door_inspect_power_lbl.text = ""
	door_inspect_power_lbl.add_theme_font_size_override("font_size", 10)
	door_inspect_power_lbl.visible = false
	vb.add_child(door_inspect_power_lbl)

	# Действие
	door_inspect_action_prompt = Label.new()
	door_inspect_action_prompt.text = "[E] Открыть"
	door_inspect_action_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	door_inspect_action_prompt.add_theme_font_size_override("font_size", 11)
	door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	vb.add_child(door_inspect_action_prompt)

func _build_keyring_hud() -> void:
	keyring_card = PanelContainer.new()
	keyring_card.name = "KeyringCard"
	keyring_card.set_anchor_and_offset(SIDE_LEFT, 0.0, 20)
	keyring_card.set_anchor_and_offset(SIDE_TOP, 0.0, 115)
	keyring_card.custom_minimum_size = Vector2(230, 0)
	keyring_card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.88)
	style.border_width_left = 2
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.82, 0.68, 0.28, 0.75)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.set_content_margin_all(6)
	keyring_card.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(keyring_card)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	keyring_card.add_child(vb)

	var title = Label.new()
	title.text = "КЛЮЧИ И ИНСТРУМЕНТЫ:"
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.40))
	vb.add_child(title)

	keyring_items_vbox = VBoxContainer.new()
	keyring_items_vbox.add_theme_constant_override("separation", 2)
	vb.add_child(keyring_items_vbox)

	_refresh_keyring_hud()

func _refresh_keyring_hud() -> void:
	if not keyring_items_vbox:
		return
	for ch in keyring_items_vbox.get_children():
		ch.queue_free()

	var count = 0
	var player = GameManager.player_ref
	var held_kid = 0
	if player and player.has_method("get_held_key_id"):
		held_kid = int(player.call("get_held_key_id"))

	# 1. Лом
	if GameManager.has_crowbar:
		count += 1
		var row = Label.new()
		row.text = "Лом-гвоздодер (срывает доски)"
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", Color(1.0, 0.75, 0.20))
		keyring_items_vbox.add_child(row)

	# 2. Ключи по ID
	var DoorScript = load("res://scripts/Door.gd")
	for kid in GameManager.keys_by_id:
		count += 1
		var th = DoorScript.get_lock_theme(kid)
		var row = Label.new()
		var in_hands = (kid == held_kid)
		row.text = "%s ключ №%d  —  Дверь №%d %s" % [th["name"], kid, kid, "[в руках]" if in_hands else ""]
		row.add_theme_font_size_override("font_size", 10)
		row.add_theme_color_override("font_color", th["color"])
		keyring_items_vbox.add_child(row)

	if keyring_card:
		keyring_card.visible = (count > 0)

	if count == 0:
		var empty_lbl = Label.new()
		empty_lbl.text = "— Нет ключей"
		empty_lbl.add_theme_font_size_override("font_size", 9)
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.58, 0.62))
		keyring_items_vbox.add_child(empty_lbl)

func update_door_inspector(info: Dictionary) -> void:
	if not door_inspect_card:
		return
	if info.is_empty():
		door_inspect_card.visible = false
		return

	door_inspect_card.visible = true

	var d_name = str(info.get("door_name", "ДВЕРЬ"))
	var is_open = bool(info.get("is_open", false))
	var is_exit = bool(info.get("is_exit", false))
	var lock_id = int(info.get("lock_id", 0))
	var has_key = bool(info.get("has_key", false))
	var is_unlocked = bool(info.get("door_key_unlocked", false)) or (lock_id <= 0)
	var requires_boards = bool(info.get("requires_boards", false))
	var boards_needed = bool(info.get("boards_needed", false))
	var has_cb = bool(info.get("has_crowbar", false))
	var th = info.get("lock_theme", {})

	door_inspect_title.text = d_name.to_upper()
	if is_open:
		door_inspect_status_badge.text = "[ОТКРЫТА]"
		door_inspect_status_badge.add_theme_color_override("font_color", Color(0.35, 0.95, 0.50))
	elif (lock_id > 0 and not is_unlocked) or boards_needed:
		door_inspect_status_badge.text = "[ЗАПЕРТА]"
		door_inspect_status_badge.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		door_inspect_status_badge.text = "[ЗАКРЫТА]"
		door_inspect_status_badge.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))

	# 1. Замок
	var lock_row = door_inspect_card.find_child("LockRow", true, false)
	if lock_id > 0:
		if lock_row: lock_row.visible = true
		var t_name = th.get("name", "Обычный")
		door_inspect_lock_lbl.text = "%s замок №%d:" % [t_name, lock_id]
		door_inspect_lock_lbl.add_theme_color_override("font_color", th.get("color", Color(1.0, 0.85, 0.2)))
		if is_unlocked:
			door_inspect_lock_status.text = "Отперт"
			door_inspect_lock_status.add_theme_color_override("font_color", Color(0.35, 0.95, 0.50))
		elif has_key:
			door_inspect_lock_status.text = "Ключ №%d есть — [E] Отпереть" % lock_id
			door_inspect_lock_status.add_theme_color_override("font_color", Color(0.25, 1.0, 0.45))
		else:
			door_inspect_lock_status.text = "Заперт (нужен ключ №%d)" % lock_id
			door_inspect_lock_status.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	else:
		if lock_row: lock_row.visible = false

	# 2. Доски
	var boards_row = door_inspect_card.find_child("BoardsRow", true, false)
	if requires_boards:
		if boards_row: boards_row.visible = true
		if not boards_needed:
			door_inspect_boards_status.text = "Сорваны"
			door_inspect_boards_status.add_theme_color_override("font_color", Color(0.35, 0.95, 0.50))
		elif has_cb:
			door_inspect_boards_status.text = "Лом готов — [E] Сорвать"
			door_inspect_boards_status.add_theme_color_override("font_color", Color(1.0, 0.78, 0.15))
		else:
			door_inspect_boards_status.text = "Заколочено (нужен лом)"
			door_inspect_boards_status.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	else:
		if boards_row: boards_row.visible = false

	# 3. Электрощиток / Питание
	var wp = bool(info.get("requires_wire_panel", false))
	var wp_solved = bool(info.get("wire_panel_solved", false))
	var pwr_needed = bool(info.get("requires_power", false))
	var pwr_done = bool(info.get("is_powered", false))

	if wp and not wp_solved:
		door_inspect_power_lbl.visible = true
		door_inspect_power_lbl.text = "Электрощиток: [E] Соединить цветные провода"
		door_inspect_power_lbl.add_theme_color_override("font_color", Color(0.35, 0.85, 1.0))
	elif pwr_needed and not pwr_done:
		door_inspect_power_lbl.visible = true
		var bats = int(info.get("power_cells_have", 0))
		if bats >= 1:
			door_inspect_power_lbl.text = "Энергосчетчик: [E] Вставить батарею и запитать замок"
			door_inspect_power_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.50))
		else:
			door_inspect_power_lbl.text = "Энергосчетчик: Обесточен (нужна батарея)"
			door_inspect_power_lbl.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	else:
		door_inspect_power_lbl.visible = false

	# 4. Итоговое действие
	if is_open:
		door_inspect_action_prompt.text = "[E]  Закрыть дверь"
		door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	elif boards_needed:
		if has_cb:
			door_inspect_action_prompt.text = "[E]  Сорвать доски ломом"
			door_inspect_action_prompt.add_theme_color_override("font_color", Color(1.0, 0.85, 0.20))
		else:
			door_inspect_action_prompt.text = "[Заколочено досками — нужен лом]"
			door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	elif wp and not wp_solved:
		door_inspect_action_prompt.text = "[E]  Открыть электрощиток"
		door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.35, 0.90, 1.0))
	elif pwr_needed and not pwr_done:
		if int(info.get("power_cells_have", 0)) >= 1:
			door_inspect_action_prompt.text = "[E]  Запитать счетчик батареей"
			door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.35, 1.0, 0.50))
		else:
			door_inspect_action_prompt.text = "[Обесточено — нужна батарея]"
			door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	elif lock_id > 0 and not is_unlocked:
		if has_key:
			door_inspect_action_prompt.text = "[E]  Отпереть замок ключом №%d" % lock_id
			door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.30, 1.0, 0.50))
		else:
			door_inspect_action_prompt.text = "[Заперто: нужен %s ключ №%d]" % [th.get("name", ""), lock_id]
			door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.95, 0.35, 0.35))
	elif is_exit:
		door_inspect_action_prompt.text = "[E]  Открыть выход"
		door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.35, 1.0, 0.60))
	else:
		door_inspect_action_prompt.text = "[E]  Открыть дверь"
		door_inspect_action_prompt.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))

func update_escape_checklist(chk: Dictionary) -> void:
	if not escape_door_card:
		return

	if chk.is_empty() or not chk.get("is_exit", false) or chk.get("is_open", false):
		escape_door_card.visible = false
		return

	escape_door_card.visible = true

	# 1. Доски
	if chk.get("boards_needed", false):
		escape_step_boards_lbl.visible = true
		if chk.get("boards_done", false):
			escape_step_boards_lbl.text = "1. Доски:            Сорваны"
			escape_step_boards_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.50))
		else:
			var has_cb = GameManager.has_crowbar
			escape_step_boards_lbl.text = "1. Доски:            Заколочено " + ("(лом готов)" if has_cb else "(нужен лом)")
			escape_step_boards_lbl.add_theme_color_override("font_color", Color(0.95, 0.70, 0.25) if has_cb else Color(0.95, 0.35, 0.35))
	else:
		escape_step_boards_lbl.visible = false

	# 2. Питание
	if chk.get("power_needed", false):
		escape_step_power_lbl.visible = true
		if chk.get("power_done", false):
			escape_step_power_lbl.text = "2. Энергосчетчик:    Питание подано"
			escape_step_power_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.50))
		else:
			var has_bat = GameManager.battery_cells >= 1
			escape_step_power_lbl.text = "2. Энергосчетчик:    Обесточен " + ("(батарея есть)" if has_bat else "(нужна батарея)")
			escape_step_power_lbl.add_theme_color_override("font_color", Color(0.95, 0.70, 0.25) if has_bat else Color(0.95, 0.35, 0.35))
	else:
		escape_step_power_lbl.visible = false

	# 3. Замок
	if chk.get("key_needed", false):
		escape_step_key_lbl.visible = true
		var k_ru = str(chk.get("key_name_ru", "Золотой"))
		var k_col = str(chk.get("key_color", "gold"))
		if chk.get("key_done", false):
			escape_step_key_lbl.text = "3. Замок выхода:     Ключ есть"
			escape_step_key_lbl.add_theme_color_override("font_color", Color(0.35, 0.95, 0.50))
		else:
			var has_k = GameManager.has_key_color(k_col)
			escape_step_key_lbl.text = "3. Замок выхода:     Заперт (" + ("ключ готов" if has_k else "нужен " + k_ru + " ключ") + ")"
			escape_step_key_lbl.add_theme_color_override("font_color", Color(0.95, 0.70, 0.25) if has_k else Color(0.95, 0.35, 0.35))
	else:
		escape_step_key_lbl.visible = false

	# 4. Общий статус
	if chk.get("is_ready_to_open", false):
		escape_status_lbl.text = "Все условия выполнены. Нажмите [E], чтобы открыть выход."
		escape_status_lbl.add_theme_color_override("font_color", Color(0.35, 1.0, 0.65))
	else:
		escape_status_lbl.text = "Выполните условия для открытия выхода"
		escape_status_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.80))

func _build_note_overlay() -> void:
	note_overlay = PanelContainer.new()
	note_overlay.set_anchors_preset(Control.PRESET_CENTER)
	note_overlay.size = Vector2(520, 360)
	note_overlay.position = Vector2(-260, -180)
	note_overlay.visible = false

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.92, 0.88, 0.77, 0.98) # Пожелтевшая старая бумага
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(0.42, 0.30, 0.16)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 8
	style.set_content_margin_all(18)
	note_overlay.add_theme_stylebox_override("panel", style)
	root_ctrl.add_child(note_overlay)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	note_overlay.add_child(vb)

	var title = Label.new()
	title.text = "ОБРЫВОК ЗАПИСКИ (МОЖНО ПИСАТЬ И РЕДАКТИРОВАТЬ)"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.35, 0.22, 0.12))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	note_edit = TextEdit.new()
	note_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	note_edit.add_theme_font_size_override("font_size", 15)
	note_edit.add_theme_color_override("font_color", Color(0.15, 0.10, 0.05))
	note_edit.add_theme_color_override("caret_color", Color(0.2, 0.1, 0.05))

	var edit_style = StyleBoxFlat.new()
	edit_style.bg_color = Color(0.96, 0.93, 0.85, 0.85)
	edit_style.border_width_left = 1
	edit_style.border_width_right = 1
	edit_style.border_width_top = 1
	edit_style.border_width_bottom = 1
	edit_style.border_color = Color(0.7, 0.6, 0.45)
	edit_style.corner_radius_top_left = 4
	edit_style.corner_radius_top_right = 4
	edit_style.corner_radius_bottom_left = 4
	edit_style.corner_radius_bottom_right = 4
	edit_style.set_content_margin_all(10)
	note_edit.add_theme_stylebox_override("normal", edit_style)
	note_edit.add_theme_stylebox_override("focus", edit_style)
	vb.add_child(note_edit)

	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 16)

	var save_btn = Button.new()
	save_btn.text = "Сохранить надпись"
	save_btn.add_theme_font_size_override("font_size", 12)
	var btn_s = StyleBoxFlat.new()
	btn_s.bg_color = Color(0.32, 0.48, 0.28)
	btn_s.corner_radius_top_left = 4
	btn_s.corner_radius_top_right = 4
	btn_s.corner_radius_bottom_left = 4
	btn_s.corner_radius_bottom_right = 4
	btn_s.set_content_margin_all(6)
	save_btn.add_theme_stylebox_override("normal", btn_s)
	save_btn.pressed.connect(func():
		if note_edit:
			GameManager.save_note_text(note_edit.text)
	)
	hb.add_child(save_btn)

	var close_btn = Button.new()
	close_btn.text = "Закрыть [ESC]"
	close_btn.add_theme_font_size_override("font_size", 12)
	var btn_c = StyleBoxFlat.new()
	btn_c.bg_color = Color(0.55, 0.28, 0.24)
	btn_c.corner_radius_top_left = 4
	btn_c.corner_radius_top_right = 4
	btn_c.corner_radius_bottom_left = 4
	btn_c.corner_radius_bottom_right = 4
	btn_c.set_content_margin_all(6)
	close_btn.add_theme_stylebox_override("normal", btn_c)
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
	hiding_left_panel.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	hiding_left_panel.set_anchor_and_offset(SIDE_RIGHT, 0.22, 0)
	hiding_left_panel.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_left_panel.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	hiding_overlay.add_child(hiding_left_panel)

	var edge_l = ColorRect.new()
	edge_l.color = Color(0.24, 0.15, 0.08, 1.0)
	edge_l.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	edge_l.set_anchor_and_offset(SIDE_LEFT, 1, -8)
	edge_l.set_anchor_and_offset(SIDE_TOP, 0, 0)
	edge_l.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	hiding_left_panel.add_child(edge_l)

	hiding_right_panel = ColorRect.new()
	hiding_right_panel.color = Color(0.10, 0.06, 0.04, 0.96)
	hiding_right_panel.set_anchor_and_offset(SIDE_LEFT, 0.78, 0)
	hiding_right_panel.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0)
	hiding_right_panel.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_right_panel.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	hiding_overlay.add_child(hiding_right_panel)

	var edge_r = ColorRect.new()
	edge_r.color = Color(0.24, 0.15, 0.08, 1.0)
	edge_r.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	edge_r.set_anchor_and_offset(SIDE_RIGHT, 0, 8)
	edge_r.set_anchor_and_offset(SIDE_TOP, 0, 0)
	edge_r.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	hiding_right_panel.add_child(edge_r)

	# Горизонтальные полупрозрачные жалюзи шкафа (видно сквозь них)
	wardrobe_slats = Control.new()
	wardrobe_slats.set_anchor_and_offset(SIDE_LEFT, 0.22, 0)
	wardrobe_slats.set_anchor_and_offset(SIDE_RIGHT, 0.78, 0)
	wardrobe_slats.set_anchor_and_offset(SIDE_TOP, 0, 0)
	wardrobe_slats.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	wardrobe_slats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hiding_overlay.add_child(wardrobe_slats)

	for s_idx in range(7):
		var slat = ColorRect.new()
		var y_rel = 0.08 + s_idx * 0.13
		slat.color = Color(0.12, 0.07, 0.04, 0.65)
		slat.set_anchor_and_offset(SIDE_LEFT, 0, 0)
		slat.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
		slat.set_anchor_and_offset(SIDE_TOP, y_rel, 0)
		slat.set_anchor_and_offset(SIDE_BOTTOM, y_rel, 12)
		wardrobe_slats.add_child(slat)

	# ── Кровать: легкий навес каркаса сверху (широкий обзор пола и комнаты снизу) ──
	hiding_top_panel = ColorRect.new()
	hiding_top_panel.color = Color(0.08, 0.06, 0.05, 0.78)
	hiding_top_panel.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	hiding_top_panel.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	hiding_top_panel.set_anchor_and_offset(SIDE_TOP, 0, 0)
	hiding_top_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.22, 0)
	hiding_overlay.add_child(hiding_top_panel)

	var bed_fringe = ColorRect.new()
	bed_fringe.color = Color(0.18, 0.12, 0.08, 1.0)
	bed_fringe.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	bed_fringe.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	bed_fringe.set_anchor_and_offset(SIDE_TOP, 1, -10)
	bed_fringe.set_anchor_and_offset(SIDE_BOTTOM, 1, 0)
	hiding_top_panel.add_child(bed_fringe)

	hiding_prompt = Label.new()
	hiding_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hiding_prompt.add_theme_font_size_override("font_size", 14)
	hiding_prompt.add_theme_color_override("font_color", Color(0.92, 0.88, 0.72))
	hiding_prompt.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	hiding_prompt.add_theme_constant_override("shadow_offset_x", 1)
	hiding_prompt.add_theme_constant_override("shadow_offset_y", 1)
	hiding_prompt.set_anchor_and_offset(SIDE_LEFT, 0.1, 0)
	hiding_prompt.set_anchor_and_offset(SIDE_RIGHT, 0.9, 0)
	hiding_prompt.set_anchor_and_offset(SIDE_BOTTOM, 1, -16)
	hiding_prompt.set_anchor_and_offset(SIDE_TOP, 1, -44)
	hiding_overlay.add_child(hiding_prompt)

	# ── Индикатор запаса кислорода и задержки дыхания ──
	oxygen_container = Control.new()
	oxygen_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -170)
	oxygen_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 170)
	oxygen_container.set_anchor_and_offset(SIDE_BOTTOM, 1, -48)
	oxygen_container.set_anchor_and_offset(SIDE_TOP, 1, -94)
	hiding_overlay.add_child(oxygen_container)

	oxygen_status_label = Label.new()
	oxygen_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	oxygen_status_label.add_theme_font_size_override("font_size", 13)
	oxygen_status_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	oxygen_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	oxygen_status_label.add_theme_constant_override("shadow_offset_x", 1)
	oxygen_status_label.add_theme_constant_override("shadow_offset_y", 1)
	oxygen_status_label.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	oxygen_status_label.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	oxygen_status_label.set_anchor_and_offset(SIDE_TOP, 0, 0)
	oxygen_status_label.set_anchor_and_offset(SIDE_BOTTOM, 0, 20)
	oxygen_status_label.text = "🫁 Кислород: 15.0 с  [Зажмите Q / Y]"
	oxygen_container.add_child(oxygen_status_label)

	oxygen_progress_bar = ProgressBar.new()
	oxygen_progress_bar.min_value = 0.0
	oxygen_progress_bar.max_value = 15.0
	oxygen_progress_bar.value = 15.0
	oxygen_progress_bar.show_percentage = false
	oxygen_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_progress_bar.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	oxygen_progress_bar.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	oxygen_progress_bar.set_anchor_and_offset(SIDE_TOP, 0, 24)
	oxygen_progress_bar.set_anchor_and_offset(SIDE_BOTTOM, 0, 36)

	var bg_box = StyleBoxFlat.new()
	bg_box.bg_color = Color(0.04, 0.06, 0.10, 0.85)
	bg_box.border_color = Color(0.30, 0.45, 0.60, 0.8)
	bg_box.border_width_left = 1
	bg_box.border_width_right = 1
	bg_box.border_width_top = 1
	bg_box.border_width_bottom = 1
	bg_box.corner_radius_top_left = 4
	bg_box.corner_radius_top_right = 4
	bg_box.corner_radius_bottom_left = 4
	bg_box.corner_radius_bottom_right = 4
	oxygen_progress_bar.add_theme_stylebox_override("background", bg_box)

	oxygen_bar_fill = StyleBoxFlat.new()
	oxygen_bar_fill.bg_color = Color(0.20, 0.75, 0.95, 0.92)
	oxygen_bar_fill.corner_radius_top_left = 3
	oxygen_bar_fill.corner_radius_top_right = 3
	oxygen_bar_fill.corner_radius_bottom_left = 3
	oxygen_bar_fill.corner_radius_bottom_right = 3
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
		hiding_prompt.text = "[ЛКМ / RT] Выйти из шкафа   •   [Зажмите Q / Y] Задержать дыхание"
	elif mode == "bed":
		hiding_left_panel.visible = false
		hiding_right_panel.visible = false
		if wardrobe_slats: wardrobe_slats.visible = false
		hiding_top_panel.visible = true
		hiding_prompt.text = "[ЛКМ / RT] Вылезти из-под кровати   •   [Зажмите Q / Y] Задержать дыхание"

# ══════════════════════════════════════════════
#  ВИДЖЕТ МИКРОФОНА (ЗВУКОВАЯ РЕАКЦИЯ ИИ)
# ══════════════════════════════════════════════
func _build_mic_hud() -> void:
	mic_container = PanelContainer.new()
	mic_container.name = "MicContainer"
	mic_container.set_anchor_and_offset(SIDE_LEFT, 0.0, 24)
	mic_container.set_anchor_and_offset(SIDE_RIGHT, 0.0, 195)
	mic_container.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -18)
	mic_container.set_anchor_and_offset(SIDE_TOP, 1.0, -34)
	mic_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.04, 0.05, 0.07, 0.65)
	p_style.border_width_left = 1
	p_style.border_width_right = 1
	p_style.border_width_top = 1
	p_style.border_width_bottom = 1
	p_style.border_color = Color(0.25, 0.28, 0.32, 0.55)
	p_style.corner_radius_top_left = 3
	p_style.corner_radius_top_right = 3
	p_style.corner_radius_bottom_left = 3
	p_style.corner_radius_bottom_right = 3
	p_style.set_content_margin_all(2)
	mic_container.add_theme_stylebox_override("panel", p_style)
	root_ctrl.add_child(mic_container)

	var hb = HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 5)
	mic_container.add_child(hb)

	mic_icon = Label.new()
	mic_icon.text = "MIC"
	mic_icon.add_theme_font_size_override("font_size", 9)
	mic_icon.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	hb.add_child(mic_icon)

	mic_bar = ProgressBar.new()
	mic_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mic_bar.size_flags_vertical = Control.SIZE_FILL
	mic_bar.show_percentage = false
	mic_bar.min_value = 0.0
	mic_bar.max_value = 100.0
	mic_bar.value = 0.0

	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.06, 0.07, 0.09, 0.8)
	bar_bg.corner_radius_top_left = 2
	bar_bg.corner_radius_top_right = 2
	bar_bg.corner_radius_bottom_left = 2
	bar_bg.corner_radius_bottom_right = 2
	mic_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fg = StyleBoxFlat.new()
	bar_fg.bg_color = Color(0.35, 0.85, 0.45, 0.85)
	bar_fg.corner_radius_top_left = 2
	bar_fg.corner_radius_top_right = 2
	bar_fg.corner_radius_bottom_left = 2
	bar_fg.corner_radius_bottom_right = 2
	mic_bar.add_theme_stylebox_override("fill", bar_fg)
	hb.add_child(mic_bar)

	mic_status_lbl = Label.new()
	mic_status_lbl.text = "ВКЛ [M]"
	mic_status_lbl.add_theme_font_size_override("font_size", 10)
	mic_status_lbl.add_theme_color_override("font_color", Color(0.70, 0.75, 0.80, 0.8))
	hb.add_child(mic_status_lbl)

func _on_mic_status_changed(enabled: bool, volume: float, triggered: bool) -> void:
	if not mic_bar or not mic_container:
		return

	var fg = mic_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if not enabled:
		mic_icon.text = "OFF"
		mic_bar.value = 0.0
		if fg: fg.bg_color = Color(0.35, 0.35, 0.35, 0.5)
		mic_status_lbl.text = "ВЫКЛ [M]"
		mic_status_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.7))
		return

	mic_icon.text = "MIC"
	var val = clamp(volume * 1000.0, 0.0, 100.0)
	mic_bar.value = val

	if triggered:
		if fg: fg.bg_color = Color(0.95, 0.20, 0.20, 0.95)
		mic_status_lbl.text = "ВКЛ [M]"
		mic_status_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.90, 0.8))
	else:
		if fg: fg.bg_color = Color(0.35, 0.85, 0.45, 0.85)
		mic_status_lbl.text = "ВКЛ [M]"
		mic_status_lbl.add_theme_color_override("font_color", Color(0.65, 0.88, 0.75, 0.8))

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
	stare_warning_lbl.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
	stare_warning_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	stare_warning_lbl.add_theme_constant_override("shadow_offset_x", 2)
	stare_warning_lbl.add_theme_constant_override("shadow_offset_y", 2)
	stare_warning_lbl.set_anchor_and_offset(SIDE_LEFT, 0.05, 0)
	stare_warning_lbl.set_anchor_and_offset(SIDE_RIGHT, 0.95, 0)
	stare_warning_lbl.set_anchor_and_offset(SIDE_TOP, 0.80, 0)
	stare_warning_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.90, 0)
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
	keyhole_hint_lbl.text = "Замочная скважина   •   [C / E / WASD] Отойти"
	keyhole_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	keyhole_hint_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	keyhole_hint_lbl.add_theme_font_size_override("font_size", 14)
	keyhole_hint_lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.75))
	keyhole_hint_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	keyhole_hint_lbl.add_theme_constant_override("shadow_offset_x", 1)
	keyhole_hint_lbl.add_theme_constant_override("shadow_offset_y", 1)
	keyhole_hint_lbl.set_anchor_and_offset(SIDE_LEFT, 0.1, 0)
	keyhole_hint_lbl.set_anchor_and_offset(SIDE_RIGHT, 0.9, 0)
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
	flash_warn_container.set_anchor_and_offset(SIDE_LEFT, 0.5, -180)
	flash_warn_container.set_anchor_and_offset(SIDE_RIGHT, 0.5, 180)
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
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
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
	flash_warn_lbl.text = "Враг щурится от света фонарика   •   [F] Погасить свет"
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
		stare_warning_lbl.text = "%s  Задержите дыхание (оно рядом!)" % btn_hint
		stare_warning_lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	else:
		stare_warning_lbl.text = "%s  Задержите дыхание" % btn_hint
		stare_warning_lbl.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45))

	stare_overlay.visible = true
	stare_overlay.modulate.a = 0.0

	var tw = create_tween()
	tw.tween_property(stare_overlay, "modulate:a", 1.0, 0.45)

	stare_pulse_tween = create_tween().set_loops()
	stare_pulse_tween.tween_property(stare_vignette, "color:a", 0.65, 0.50)
	stare_pulse_tween.tween_property(stare_vignette, "color:a", 0.25, 0.50)

func pulse_heartbeat(amount: float) -> void:
	if cinematic_shader_mat:
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
	backpack_dim_rect.color = Color(0.01, 0.02, 0.03, 0.0)
	backpack_dim_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	backpack_dim_rect.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			GameManager.close_backpack()
	)
	backpack_overlay.add_child(backpack_dim_rect)

	# Минималистичная компактная панель инвентаря по центру
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

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.07, 0.10, 0.94)
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = Color(0.25, 0.30, 0.38, 0.85)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.set_content_margin_all(14)
	backpack_container.add_theme_stylebox_override("panel", panel_style)
	backpack_overlay.add_child(backpack_container)

	var main_vb = VBoxContainer.new()
	main_vb.add_theme_constant_override("separation", 10)
	backpack_container.add_child(main_vb)

	# 1. Заголовок и быстрые кнопки
	var header_hb = HBoxContainer.new()
	header_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vb.add_child(header_hb)

	var title_lbl = Label.new()
	title_lbl.text = "РЮКЗАК  •  alpha 0.1"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.88, 0.92, 0.98))
	header_hb.add_child(title_lbl)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(spacer)

	gfx_btn = Button.new()
	gfx_btn.name = "BackpackGfxBtn"
	gfx_btn.custom_minimum_size = Vector2(140, 26)
	var q = GameManager.graphics_quality if GameManager else "ultra"
	var q_lbl = "УЛЬТРА"
	if q == "medium": q_lbl = "СРЕДНЯЯ"
	elif q == "low": q_lbl = "НИЗКАЯ"
	gfx_btn.text = "Графика: %s" % q_lbl
	gfx_btn.add_theme_font_size_override("font_size", 10)
	gfx_btn.pressed.connect(func():
		if GameManager:
			GameManager.cycle_graphics_quality()
	)
	header_hb.add_child(gfx_btn)

	var close_btn = Button.new()
	close_btn.text = "Закрыть [Tab / X]"
	close_btn.custom_minimum_size = Vector2(100, 26)
	close_btn.add_theme_font_size_override("font_size", 10)
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

	# 3. Информационный блок выбранного слота
	var info_box = PanelContainer.new()
	var info_style = StyleBoxFlat.new()
	info_style.bg_color = Color(0.08, 0.10, 0.14, 0.85)
	info_style.border_width_left = 1
	info_style.border_width_right = 1
	info_style.border_width_top = 1
	info_style.border_width_bottom = 1
	info_style.border_color = Color(0.20, 0.24, 0.32, 0.70)
	info_style.corner_radius_top_left = 4
	info_style.corner_radius_top_right = 4
	info_style.corner_radius_bottom_left = 4
	info_style.corner_radius_bottom_right = 4
	info_style.set_content_margin_all(6)
	info_box.add_theme_stylebox_override("panel", info_style)
	main_vb.add_child(info_box)

	var info_vb = VBoxContainer.new()
	info_vb.add_theme_constant_override("separation", 2)
	info_box.add_child(info_vb)

	backpack_active_lbl = Label.new()
	backpack_active_lbl.add_theme_font_size_override("font_size", 11)
	backpack_active_lbl.add_theme_color_override("font_color", Color(0.96, 0.88, 0.55))
	info_vb.add_child(backpack_active_lbl)

	backpack_desc_lbl = Label.new()
	backpack_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	backpack_desc_lbl.add_theme_font_size_override("font_size", 10)
	backpack_desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.84, 0.90))
	info_vb.add_child(backpack_desc_lbl)

	# 4. Нижняя панель подсказок
	var nav_hint = Label.new()
	nav_hint.text = "[ЛКМ] Взять в руку   •   [ПКМ] Выбросить на пол   •   [Tab / Esc] Закрыть"
	nav_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nav_hint.add_theme_font_size_override("font_size", 10)
	nav_hint.add_theme_color_override("font_color", Color(0.60, 0.65, 0.75))
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
		if gfx_btn and gfx_btn.is_inside_tree() and gfx_btn.get_global_rect().has_point(mpos):
			if GameManager:
				GameManager.cycle_graphics_quality()
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
			backpack_nav_hint.text = "[A] Взять в руку   •   [LT / Y] Выбросить   •   [Стик] Курсор-мышь   •   [◄/►] Слоты   •   [B / X] Закрыть"
		else:
			backpack_nav_hint.text = "[ЛКМ] Взять в руку   •   [ПКМ] Выбросить на пол   •   [Tab / Esc] Закрыть"
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
		s.corner_radius_top_left = 5
		s.corner_radius_top_right = 5
		s.corner_radius_bottom_left = 5
		s.corner_radius_bottom_right = 5
		s.set_content_margin_all(5)

		if is_cursor:
			s.bg_color = Color(0.12, 0.22, 0.32, 0.95) if has_item else Color(0.08, 0.14, 0.22, 0.70)
			s.border_width_left = 3
			s.border_width_right = 3
			s.border_width_top = 3
			s.border_width_bottom = 3
			s.border_color = Color(0.35, 0.85, 1.0, 1.0)
		elif is_active and has_item:
			s.bg_color = Color(0.24, 0.18, 0.05, 0.90)
			s.border_width_left = 2
			s.border_width_right = 2
			s.border_width_top = 2
			s.border_width_bottom = 2
			s.border_color = Color(1.0, 0.85, 0.32, 0.98)
		elif has_item:
			s.bg_color = Color(0.10, 0.12, 0.17, 0.88)
			s.border_width_left = 1
			s.border_width_right = 1
			s.border_width_top = 1
			s.border_width_bottom = 1
			s.border_color = Color(0.35, 0.40, 0.50, 0.80)
		else:
			s.bg_color = Color(0.04, 0.05, 0.07, 0.50)
			s.border_width_left = 1
			s.border_width_right = 1
			s.border_width_top = 1
			s.border_width_bottom = 1
			s.border_color = Color(0.18, 0.20, 0.26, 0.40)

		btn.add_theme_stylebox_override("normal", s)

		var sh = s.duplicate()
		sh.bg_color = s.bg_color.lightened(0.15)
		sh.border_color = Color(0.85, 0.90, 1.0, 0.95)
		if is_active and has_item:
			sh.border_color = Color(1.0, 0.95, 0.55, 1.0)
		btn.add_theme_stylebox_override("hover", sh)

		var vb = VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 2)
		btn.add_child(vb)

		var top_hb = HBoxContainer.new()
		top_hb.alignment = BoxContainer.ALIGNMENT_CENTER
		top_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num_lbl = Label.new()
		num_lbl.text = "[%d]" % (i + 1)
		num_lbl.add_theme_font_size_override("font_size", 9)
		num_lbl.add_theme_color_override("font_color", Color(0.65, 0.70, 0.78))
		top_hb.add_child(num_lbl)

		if is_active and has_item:
			var act_badge = Label.new()
			act_badge.text = " [В РУКЕ]"
			act_badge.add_theme_font_size_override("font_size", 8)
			act_badge.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
			top_hb.add_child(act_badge)

		vb.add_child(top_hb)

		var short_tag = "—"
		var tag_color = Color(0.45, 0.48, 0.55)
		if has_item:
			var iid = str(itm.get("id", ""))
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
				short_tag = "ПР-КР"
				tag_color = Color(1.0, 0.35, 0.35)
			elif iid == "fuse_blue":
				short_tag = "ПР-СИ"
				tag_color = Color(0.35, 0.70, 1.0)
			elif iid == "fuse_green":
				short_tag = "ПР-ЗЕ"
				tag_color = Color(0.35, 1.0, 0.45)
			elif iid == "road_flare":
				short_tag = "РАКЕТА"
				tag_color = Color(1.0, 0.55, 0.20)
			else:
				short_tag = str(itm.get("name", "ПРЕДМЕТ")).substr(0, 5).to_upper()
				tag_color = Color(0.85, 0.88, 0.95)

		var tag_lbl = Label.new()
		tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag_lbl.text = short_tag
		tag_lbl.add_theme_font_size_override("font_size", 13)
		tag_lbl.add_theme_color_override("font_color", tag_color)
		vb.add_child(tag_lbl)

		var name_lbl = Label.new()
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if has_item:
			var cnt_val = itm.get("count", 1)
			var cnt_suffix = " x%d" % cnt_val if cnt_val > 1 else ""
			name_lbl.text = itm["name"] + cnt_suffix
			name_lbl.add_theme_font_size_override("font_size", 9)
			name_lbl.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
		else:
			name_lbl.text = "Пусто"
			name_lbl.add_theme_font_size_override("font_size", 8)
			name_lbl.add_theme_color_override("font_color", Color(0.40, 0.44, 0.50, 0.6))
		vb.add_child(name_lbl)

	_update_backpack_desc(act_idx)

func _update_backpack_desc(idx: int) -> void:
	if not backpack_desc_lbl or not backpack_active_lbl:
		return
	var items = GameManager.get_backpack_items()
	if idx >= 0 and idx < items.size():
		var itm = items[idx]
		if itm.get("id", "empty") != "empty":
			var act_txt = "В РУКЕ" if idx == GameManager.active_item_index else ("A / ЛКМ — взять в руку  •  LT / Y / ПКМ — выбросить" if GameManager.is_gamepad else "ЛКМ — взять в руку  •  ПКМ — выбросить")
			backpack_active_lbl.text = "%s   [%s]" % [itm["name"], act_txt]
			backpack_desc_lbl.text = itm.get("desc", "")
		else:
			backpack_active_lbl.text = "Слот [%d]  —  Пусто" % (idx + 1)
			backpack_desc_lbl.text = "Свободный слот. Подбирайте ключи, лом, батареи и припасы в особняке."

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
	_update_vhs_hud(delta)
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
		if is_held:
			oxygen_bar_fill.bg_color = Color(0.20, 0.90, 1.0, 0.95)
			oxygen_status_label.text = "🌬️ ДЫХАНИЕ ЗАДЕРЖАНО: %0.1f с  [Q / Y]" % oxygen
			oxygen_status_label.add_theme_color_override("font_color", Color(0.40, 0.95, 1.0))
		elif oxygen <= 0.2:
			oxygen_bar_fill.bg_color = Color(1.0, 0.20, 0.20, 0.95)
			oxygen_status_label.text = "💥 НЕТ КИСЛОРОДА! ПРИНУДИТЕЛЬНЫЙ ВЫДОХ!"
			oxygen_status_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		elif rec_timer > 0.0:
			oxygen_bar_fill.bg_color = Color(1.0, 0.65, 0.20, 0.95)
			oxygen_status_label.text = "😮‍💨 ПЕРЕДЫШКА (восстановление): %0.1f с" % rec_timer
			oxygen_status_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.30))
		elif oxygen < 4.0:
			oxygen_bar_fill.bg_color = Color(1.0, 0.55, 0.15, 0.95)
			oxygen_status_label.text = "⚠️ МАЛО ВОЗДУХА: %0.1f с  [Зажмите Q / Y]" % oxygen
			oxygen_status_label.add_theme_color_override("font_color", Color(1.0, 0.65, 0.20))
		else:
			oxygen_bar_fill.bg_color = Color(0.25, 0.65, 0.85, 0.85)
			oxygen_status_label.text = "🫁 Кислород: %0.1f с  [Зажмите Q / Y]" % oxygen
			oxygen_status_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))

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
	_refresh_keyring_hud()
	_flash_hotbar()

func _on_gfx_quality_changed(quality: String) -> void:
	if cinematic_shader_mat:
		var high := quality in ["ultra", "high"]
		cinematic_shader_mat.set_shader_parameter("vignette_opacity", 0.35 if high else 0.50)
		cinematic_shader_mat.set_shader_parameter("grain_intensity", 0.009 if high else 0.016)
		cinematic_shader_mat.set_shader_parameter("chromatic_aberration", 0.0008 if high else 0.0015)
		cinematic_shader_mat.set_shader_parameter("lens_distortion", 0.005 if high else 0.008)
	if gfx_btn:
		var q_title = "УЛЬТРА (MAX)"
		if quality == "high":
			q_title = "ВЫСОКАЯ"
		elif quality == "medium":
			q_title = "СРЕДНЯЯ"
		elif quality == "low":
			q_title = "НИЗКАЯ (60+ FPS)"
		gfx_btn.text = "[F3] %s" % q_title


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

	var is_lumberjack = false
	if GameManager and is_instance_valid(GameManager.last_killer):
		var k = GameManager.last_killer
		var k_name = str(k.name).to_lower()
		var k_script = str(k.get_script().resource_path).to_lower() if k.get_script() else ""
		if "lumberjack" in k_name or "лесопил" in k_name or "дед" in k_name or "lumberjack" in k_script:
			is_lumberjack = true

	if not is_lumberjack:
		_play_skinwalker_jumpscare()
		return

	var jumpscare_container = Control.new()
	jumpscare_container.name = "RealHorrorJumpscare"
	jumpscare_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	jumpscare_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(jumpscare_container)

	# ── 1. ЗВУКОВОЙ ТЕРРОР: мощнейший многослойный взрыв ─────────────
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


func _play_skinwalker_jumpscare() -> void:
	var scare := SkinwalkerScare.new()
	add_child(scare)
	await scare.finished
	if not is_inside_tree() or not is_instance_valid(root_ctrl):
		return
	var blackout = ColorRect.new()
	blackout.name = "Blackout"
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.color = Color.BLACK
	blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_ctrl.add_child(blackout)
	if is_instance_valid(scare):
		scare.queue_free()
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
	for ch in get_children():
		if ch is SkinwalkerScare:
			ch.queue_free()
	if GameManager:
		GameManager.game_ended = false
		GameManager.is_reading_note = false
		if GameManager.is_backpack_open:
			GameManager.close_backpack()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
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

func _show_death_screen() -> void:
	clear_end_screens()
	# clear_end_screens сбрасывает флаг, а на экране смерти игра должна оставаться законченной:
	# иначе монстр продолжает ходить за экраном, а клавиши R и ESC не срабатывают
	if GameManager:
		GameManager.game_ended = true

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
	msg.add_theme_font_size_override("font_size", 52)
	msg.add_theme_color_override("font_color", Color(0.85, 0.08, 0.06))
	vb.add_child(msg)

	var cur_scene = get_tree().current_scene
	if cur_scene and cur_scene.name == "DebugEditor":
		var rst_btn = Button.new()
		rst_btn.text = "В ИСХОДНОЕ ПОЛОЖЕНИЕ (R)"
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
		ed_btn.text = "ВЕРНУТЬСЯ В РЕДАКТОР (7)"
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
		camp_rst.text = "НАЧАТЬ ЗАНОВО (R)"
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
	sub_btn.text = "В ГЛАВНОЕ МЕНЮ (ESC)"
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
	bg.color = Color(0.02, 0.02, 0.04, 0.0)
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

	# Декоративный бейдж
	var badge = Label.new()
	badge.text = "✦  ДЕМО-ВЕРСИЯ  ✦"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 16)
	badge.add_theme_color_override("font_color", Color(0.95, 0.75, 0.25, 0.85))
	vb.add_child(badge)

	# Главный заголовок по запросу игрока
	var msg = Label.new()
	msg.text = "Alpha заканчивается тут, спасибо поиграли"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 42)
	msg.add_theme_color_override("font_color", Color(0.96, 0.94, 0.90))
	vb.add_child(msg)

	# Подзаголовок
	var submsg = Label.new()
	submsg.text = "Побег успешно завершён. Железная электро-дверь открыта."
	submsg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	submsg.add_theme_font_size_override("font_size", 18)
	submsg.add_theme_color_override("font_color", Color(0.65, 0.70, 0.75, 0.9))
	vb.add_child(submsg)

	# Отступ перед кнопками
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vb.add_child(spacer)

	# Кнопка «В главное меню»
	var menu_btn = Button.new()
	menu_btn.text = "В ГЛАВНОЕ МЕНЮ (ESC)"
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
	rst_btn.text = "НАЧАТЬ ЗАНОВО (R)"
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
	crosshair_dot.size = Vector2(4, 4)
	crosshair_dot.position = Vector2(-2, -2)
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
		var col = Color(1.0, 0.92, 0.50, 0.95)
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
	throw_charge_container.size = Vector2(64, 6)
	throw_charge_container.position = Vector2(-32, 22)
	throw_charge_container.visible = false

	throw_charge_bg = ColorRect.new()
	throw_charge_bg.name = "ChargeBG"
	throw_charge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_charge_bg.size = Vector2(64, 6)
	throw_charge_bg.color = Color(0.05, 0.05, 0.08, 0.75)
	throw_charge_container.add_child(throw_charge_bg)

	throw_charge_bar = ColorRect.new()
	throw_charge_bar.name = "ChargeFill"
	throw_charge_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	throw_charge_bar.size = Vector2(0, 4)
	throw_charge_bar.position = Vector2(1, 1)
	throw_charge_bar.color = Color(1.0, 0.65, 0.15, 0.95)
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
		tw.tween_property(crosshair_dot, "color", Color(1.0, 0.92, 0.45, 1.0), 0.12)
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
		var max_w = 62.0
		throw_charge_bar.size.x = clampf(charge_val, 0.0, 1.0) * max_w
		throw_charge_bar.color = Color(1.0, lerpf(0.75, 0.15, charge_val), 0.10, 0.95)

func set_crosshair_visible(v: bool) -> void:
	if crosshair_container:
		crosshair_container.visible = v
