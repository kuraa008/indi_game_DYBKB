class_name DevConsole
extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
#  DevConsole.gd — Внутриигровая консоль разработчика (кнопка [~ / Ё])
#  Поддерживает команды: admin, noclip, noAI, nodie, passai, speed, aispeed,
#  deleteobj, setobj, teleport, map, clear, help.
#  Включает интерактивный список подсказок снизу с автофильтрацией.
# ══════════════════════════════════════════════════════════════════════════════

const COMMAND_DEFS: Array[Dictionary] = [
	{"cmd": "admin", "syntax": "admin", "desc": "Вкл/выкл права разработчика"},
	{"cmd": "noclip", "syntax": "noclip", "desc": "Свободный полет сквозь стены (Space/Shift)"},
	{"cmd": "noai", "syntax": "noai", "desc": "Заморозить/отключить ИИ монстра"},
	{"cmd": "nodie", "syntax": "nodie", "desc": "Бессмертие игрока (Godmode)"},
	{"cmd": "passai", "syntax": "passai", "desc": "Показать 3D-линию пути монстра сквозь стены"},
	{"cmd": "polygon", "syntax": "polygon", "desc": "Мини-полигон ИИ (играть за монстра против бота)"},
	{"cmd": "minimap", "syntax": "minimap", "desc": "Вкл/выкл 2D радар дома [кнопка M]"},
	{"cmd": "possess", "syntax": "possess", "desc": "Вселиться/наблюдать от лица монстра (Noclip+God)"},
	{"cmd": "speed", "syntax": "speed 1.5", "desc": "Скорость игрока (дефолт = 1.0)"},
	{"cmd": "aispeed", "syntax": "aispeed 0.7", "desc": "Скорость Скинвокера (дефолт = 1.0)"},
	{"cmd": "deleteobj", "syntax": "deleteobj", "desc": "Удалить объект в прицеле"},
	{"cmd": "setobj", "syntax": "setobj item_battery", "desc": "Спавн объекта (battery, crowbar, door...)"},
	{"cmd": "map", "syntax": "map [1..N / list / main]", "desc": "Список и смена карт из JSON или сцен"},
	{"cmd": "skinwalkerfun", "syntax": "skinwalkerfun", "desc": "Секретный режим полигона (пасхалка Скинвокера)"},
	{"cmd": "clear", "syntax": "clear", "desc": "Очистить лог консоли"},
	{"cmd": "help", "syntax": "help", "desc": "Подробная справка по командам"},
]

var is_open: bool = false
var is_admin: bool = false

var root_panel: PanelContainer
var output_label: RichTextLabel
var input_field: LineEdit
var hints_container: HFlowContainer
var hints_panel: PanelContainer

var command_history: Array[String] = []
var history_index: int = -1

func _init() -> void:
	layer = 125

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.name = "DevConsolePanel"
	root_panel.set_anchor_and_offset(SIDE_LEFT, 0.04, 0)
	root_panel.set_anchor_and_offset(SIDE_RIGHT, 0.96, 0)
	root_panel.set_anchor_and_offset(SIDE_TOP, 0.02, 0)
	root_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.52, 0)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.07, 0.10, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.50, 0.75, 0.85)
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 10
	root_panel.add_theme_stylebox_override("panel", style)
	add_child(root_panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	root_panel.add_child(vb)

	# Заголовок консоли
	var header_hb = HBoxContainer.new()
	var title = Label.new()
	title.text = "КОНСОЛЬ РАЗРАБОТЧИКА [~ / Ё] — Введите 'help' для справки"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "Закрыть [ESC]"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close_console)
	header_hb.add_child(close_btn)
	vb.add_child(header_hb)

	# Лог вывода сообщений
	output_label = RichTextLabel.new()
	output_label.bbcode_enabled = true
	output_label.scroll_following = true
	output_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output_label.add_theme_font_size_override("normal_font_size", 13)
	output_label.text = "[color=#55aaff]Skinwalker Developer Console v1.2 готова к работе.[/color]\n"
	vb.add_child(output_label)

	# Поле ввода команд
	var in_hb = HBoxContainer.new()
	in_hb.add_theme_constant_override("separation", 6)

	var prompt_lbl = Label.new()
	prompt_lbl.text = ">"
	prompt_lbl.add_theme_font_size_override("font_size", 16)
	prompt_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.4))
	in_hb.add_child(prompt_lbl)

	input_field = LineEdit.new()
	input_field.placeholder_text = "Введите команду (например: admin, noclip, passai, speed 2, help)..."
	input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_field.add_theme_font_size_override("font_size", 13)
	var in_style = StyleBoxFlat.new()
	in_style.bg_color = Color(0.10, 0.13, 0.18, 0.9)
	in_style.border_width_left = 1
	in_style.border_width_right = 1
	in_style.border_width_top = 1
	in_style.border_width_bottom = 1
	in_style.border_color = Color(0.35, 0.45, 0.65)
	in_style.corner_radius_top_left = 4
	in_style.corner_radius_top_right = 4
	in_style.corner_radius_bottom_left = 4
	in_style.corner_radius_bottom_right = 4
	input_field.add_theme_stylebox_override("normal", in_style)
	input_field.text_submitted.connect(_on_command_submitted)
	input_field.text_changed.connect(_on_input_text_changed)
	in_hb.add_child(input_field)

	var exec_btn = Button.new()
	exec_btn.text = "Выполнить"
	exec_btn.add_theme_font_size_override("font_size", 12)
	exec_btn.pressed.connect(func(): _on_command_submitted(input_field.text))
	in_hb.add_child(exec_btn)
	vb.add_child(in_hb)

	# Подсказки (выпадающий список, отображается только когда пользователь пишет)
	hints_panel = PanelContainer.new()
	hints_panel.name = "HintsDynamicDropdown"
	var hp_style = StyleBoxFlat.new()
	hp_style.bg_color = Color(0.05, 0.08, 0.12, 0.94)
	hp_style.border_width_left = 1
	hp_style.border_width_right = 1
	hp_style.border_width_top = 1
	hp_style.border_width_bottom = 1
	hp_style.border_color = Color(0.30, 0.50, 0.75, 0.85)
	hp_style.corner_radius_top_left = 6
	hp_style.corner_radius_top_right = 6
	hp_style.corner_radius_bottom_left = 6
	hp_style.corner_radius_bottom_right = 6
	hp_style.content_margin_left = 8
	hp_style.content_margin_right = 8
	hp_style.content_margin_top = 6
	hp_style.content_margin_bottom = 6
	hp_style.shadow_color = Color(0, 0, 0, 0.4)
	hp_style.shadow_size = 6
	hints_panel.add_theme_stylebox_override("panel", hp_style)

	var hints_vb = VBoxContainer.new()
	hints_vb.add_theme_constant_override("separation", 4)

	var hints_hdr = Label.new()
	hints_hdr.text = "Подсказки (кликните или нажмите Tab для автозаполнения):"
	hints_hdr.add_theme_font_size_override("font_size", 11)
	hints_hdr.add_theme_color_override("font_color", Color(0.65, 0.85, 1.0))
	hints_vb.add_child(hints_hdr)

	hints_container = HFlowContainer.new()
	hints_container.add_theme_constant_override("h_separation", 6)
	hints_container.add_theme_constant_override("v_separation", 4)
	hints_vb.add_child(hints_container)

	hints_panel.add_child(hints_vb)
	vb.add_child(hints_panel)
	hints_panel.visible = false

func _create_hint_button(label_text: String, fill_str: String) -> Button:
	var btn = Button.new()
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 11)
	btn.focus_mode = Control.FOCUS_NONE

	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.12, 0.17, 0.24, 0.90)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.35, 0.55, 0.80, 0.70)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.content_margin_left = 6
	btn_style.content_margin_right = 6
	btn_style.content_margin_top = 2
	btn_style.content_margin_bottom = 2
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_color_override("font_color", Color(0.60, 0.92, 1.0))

	btn.pressed.connect(func(): _select_hint(fill_str))
	return btn

func _get_available_json_maps() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var dirs = ["res://assets/", "res://scenes/", "user://"]
	var seen: Dictionary = {}
	for d in dirs:
		var da = DirAccess.open(d)
		if da:
			da.list_dir_begin()
			var fn = da.get_next()
			while fn != "":
				if not da.current_is_dir() and fn.ends_with(".json") and fn != "skinwalker_brain.json":
					var full_p = d + fn
					var clean_name = fn.trim_suffix(".json")
					if not seen.has(full_p):
						seen[full_p] = true
						list.append({
							"name": clean_name,
							"filename": fn,
							"path": full_p
						})
				fn = da.get_next()
	return list

func _update_hints_list(filter_text: String) -> void:
	for ch in hints_container.get_children():
		ch.queue_free()

	var needle = filter_text.strip_edges().to_lower()
	if needle.is_empty():
		hints_panel.visible = false
		return

	# Режим подсказок для команды map
	if needle.begins_with("map"):
		var json_maps = _get_available_json_maps()
		for i in range(json_maps.size()):
			var m = json_maps[i]
			var btn = _create_hint_button("map %d (%s)" % [i + 1, m["name"]], "map %d" % [i + 1])
			hints_container.add_child(btn)
		for sc in ["main", "polygon", "skinwalkerfun", "editor", "menu"]:
			var btn = _create_hint_button("map " + sc, "map " + sc)
			hints_container.add_child(btn)
		hints_panel.visible = (hints_container.get_child_count() > 0)
		return

	var count = 0
	for item in COMMAND_DEFS:
		var cmd_name = str(item.get("cmd", "")).to_lower()
		var syntax = str(item.get("syntax", ""))
		var desc = str(item.get("desc", ""))

		if cmd_name.begins_with(needle) or needle in cmd_name:
			var btn = _create_hint_button("%s : %s" % [syntax, desc], syntax.split(" ")[0])
			hints_container.add_child(btn)
			count += 1
			if count >= 8:
				break

	hints_panel.visible = (hints_container.get_child_count() > 0)

func _select_hint(cmd_to_fill: String) -> void:
	input_field.text = cmd_to_fill + " "
	input_field.caret_column = input_field.text.length()
	input_field.grab_focus()
	_update_hints_list(cmd_to_fill)

func _on_input_text_changed(new_text: String) -> void:
	if new_text.strip_edges().is_empty():
		hints_panel.visible = false
	else:
		_update_hints_list(new_text)

func toggle_console() -> void:
	if is_open:
		close_console()
	else:
		open_console()

func open_console() -> void:
	is_open = true
	visible = true
	input_field.text = ""
	history_index = command_history.size()
	hints_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	input_field.grab_focus()

func close_console() -> void:
	is_open = false
	visible = false
	input_field.release_focus()
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	# Кнопка [~] / [Ё]
	if event.keycode == KEY_QUOTELEFT or event.keycode == KEY_ASCIITILDE or event.unicode == 1105 or event.unicode == 1025 or event.as_text().to_lower() in ["quoteleft", "`", "asciitilde"]:
		toggle_console()
		get_viewport().set_input_as_handled()
		return

	if is_open:
		if event.keycode == KEY_ESCAPE:
			close_console()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_TAB:
			_autocomplete_tab()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_UP:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_DOWN:
			_navigate_history(1)
			get_viewport().set_input_as_handled()
			return

func _autocomplete_tab() -> void:
	var cur = input_field.text.strip_edges().to_lower()
	if cur.is_empty():
		return
	for item in COMMAND_DEFS:
		var c = str(item.get("cmd", "")).to_lower()
		if c.begins_with(cur):
			input_field.text = c + " "
			input_field.caret_column = input_field.text.length()
			_update_hints_list(c)
			break

func _navigate_history(dir: int) -> void:
	if command_history.is_empty():
		return
	history_index = clamp(history_index + dir, 0, command_history.size())
	if history_index < command_history.size():
		input_field.text = command_history[history_index]
		input_field.caret_column = input_field.text.length()
	else:
		input_field.text = ""
	_update_hints_list(input_field.text)

func print_log(msg: String) -> void:
	output_label.append_text(msg + "\n")

func _on_command_submitted(raw_cmd: String) -> void:
	var trimmed = raw_cmd.strip_edges()
	input_field.text = ""
	_update_hints_list("")
	if trimmed.is_empty():
		return

	command_history.append(trimmed)
	history_index = command_history.size()

	print_log("[color=#99bbdd]> " + trimmed + "[/color]")
	_execute_command(trimmed)

func _execute_command(cmd_str: String) -> void:
	var parts = cmd_str.split(" ", false)
	if parts.is_empty():
		return

	var cmd = parts[0].to_lower()
	var args: Array[String] = []
	for i in range(1, parts.size()):
		args.append(parts[i])

	match cmd:
		"admin":
			is_admin = !is_admin
			var col = "#55ff55" if is_admin else "#ff9955"
			print_log("[color=%s]Права разработчика (admin): %s[/color]" % [col, "АКТИВИРОВАНЫ" if is_admin else "ОТКЛЮЧЕНЫ"])

		"noclip":
			GameManager.is_noclip = !GameManager.is_noclip
			var player = GameManager.player_ref
			if player and is_instance_valid(player):
				var col_node = player.find_child("CollisionShape3D", true, false)
				if col_node and col_node is CollisionShape3D:
					col_node.disabled = GameManager.is_noclip
			var status = "ВКЛЮЧЕН (Полёт сквозь стены: WASD + Space/Shift)" if GameManager.is_noclip else "ВЫКЛЮЧЕН"
			print_log("[color=#44ffbb]Noclip: %s[/color]" % status)

		"noai":
			GameManager.is_no_ai = !GameManager.is_no_ai
			var enemy = GameManager.enemy_ref
			if enemy and is_instance_valid(enemy):
				enemy.set_physics_process(!GameManager.is_no_ai)
				if GameManager.is_no_ai:
					enemy.velocity = Vector3.ZERO
			var status = "ОТКЛЮЧЕН (Враг полностью заморожен)" if GameManager.is_no_ai else "ВКЛЮЧЕН (Враг активен)"
			print_log("[color=#ffdd55]ИИ Врага (noAI): %s[/color]" % status)

		"nodie":
			GameManager.is_godmode = !GameManager.is_godmode
			var status = "АКТИВИРОВАНО (Игрок бессмертен)" if GameManager.is_godmode else "ОТКЛЮЧЕНО"
			print_log("[color=#ff5588]Бессмертие (nodie): %s[/color]" % status)

		"passai":
			GameManager.show_ai_path = !GameManager.show_ai_path
			var status = "ВКЛЮЧЕНО (3D-линия маршрута Скинвокера видна сквозь стены)" if GameManager.show_ai_path else "ВЫКЛЮЧЕНО"
			var col = "#55ffaa" if GameManager.show_ai_path else "#ffaa55"
			print_log("[color=%s]Траектория ИИ (passai): %s[/color]" % [col, status])

		"possess":
			_cmd_possess()

		"polygon", "testai", "arena":
			print_log("[color=#55ffaa]Загрузка интерактивного полигона ИИ...[/color]")
			close_console()
			GameManager.change_scene_fast("res://scenes/Polygon.tscn")

		"minimap", "map2d":
			if GameManager.minimap:
				GameManager.minimap.toggle_minimap()
				var s = "ВКЛЮЧЕНА" if GameManager.minimap.is_minimap_visible else "ОТКЛЮЧЕНА"
				print_log("[color=#55ffaa]Миникарта: %s[/color]" % s)

		"speed":
			var mul: float = 1.0
			if not args.is_empty():
				mul = float(args[0])
			if mul <= 0.05:
				mul = 1.0
			GameManager.speed_multiplier = mul
			print_log("[color=#55ddff]Скорость игрока (speed): x%.2f (дефолт = 1.0)[/color]" % mul)

		"aispeed":
			var mul: float = 1.0
			if not args.is_empty():
				mul = float(args[0])
			if mul <= 0.05:
				mul = 1.0
			GameManager.enemy_speed_multiplier = mul
			print_log("[color=#ffaa55]Скорость Скинвокера (aispeed): x%.2f (дефолт = 1.0)[/color]" % mul)

		"deleteobj":
			_cmd_deleteobj()

		"setobj":
			if args.is_empty():
				print_log("[color=#ff6666]Ошибка: укажите тип объекта. Пример: setobj cube, setobj door_simple, setobj item_battery, setobj item_crowbar[/color]")
				return
			_cmd_setobj(args[0])

		"teleport", "tp":
			_cmd_teleport(args)

		"map":
			_cmd_map(args)

		"skinwalkerfun", "fun":
			_cmd_skinwalkerfun()

		"clear":
			output_label.text = ""

		"help":
			_print_help()

		_:
			print_log("[color=#ff6666]Неизвестная команда '%s'. Введите 'help' для справки.[/color]" % cmd)

func _cmd_deleteobj() -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		print_log("[color=#ff6666]Ошибка: игрок не найден в сцене.[/color]")
		return

	var cam: Camera3D = null
	if player.has_node("Head/Camera"):
		cam = player.get_node("Head/Camera") as Camera3D
	elif player.find_child("Camera", true, false):
		cam = player.find_child("Camera", true, false) as Camera3D
	elif player.find_child("Camera3D", true, false):
		cam = player.find_child("Camera3D", true, false) as Camera3D

	if not cam:
		print_log("[color=#ff6666]Ошибка: камера игрока не найдена.[/color]")
		return

	var space = player.get_world_3d().direct_space_state
	var from = cam.global_position
	var to = from - cam.global_transform.basis.z * 15.0
	var q = PhysicsRayQueryParameters3D.create(from, to, 1)
	var exc: Array[RID] = []
	exc.append(player.get_rid())
	q.exclude = exc
	var hit = space.intersect_ray(q)
	if hit.is_empty() or not hit.collider:
		print_log("[color=#ffaa55]Ничего не найдено в прицеле на дистанции 15 метров.[/color]")
		return

	var obj = hit.collider as Node
	var target_to_free = obj
	while target_to_free.get_parent() and target_to_free.get_parent() != get_tree().current_scene and not target_to_free.name.begins_with("chunk") and not target_to_free.name.begins_with("Grass"):
		if target_to_free.get_parent().name in ["ObjectsRoot", "NavRegion", "Main"]:
			break
		target_to_free = target_to_free.get_parent()

	var obj_name = target_to_free.name
	var obj_pos = target_to_free.global_position if target_to_free is Node3D else Vector3.ZERO
	target_to_free.queue_free()
	print_log("[color=#ff5555]Объект удален: '%s' на позиции (%.1f, %.1f, %.1f)[/color]" % [obj_name, obj_pos.x, obj_pos.y, obj_pos.z])

func _cmd_setobj(type_name: String) -> void:
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		print_log("[color=#ff6666]Ошибка: игрок не найден.[/color]")
		return

	var cam: Camera3D = null
	if player.has_node("Head/Camera"):
		cam = player.get_node("Head/Camera") as Camera3D
	elif player.find_child("Camera", true, false):
		cam = player.find_child("Camera", true, false) as Camera3D
	elif player.find_child("Camera3D", true, false):
		cam = player.find_child("Camera3D", true, false) as Camera3D

	var spawn_pos: Vector3
	if cam:
		var space = player.get_world_3d().direct_space_state
		var from = cam.global_position
		var to = from - cam.global_transform.basis.z * 10.0
		var q = PhysicsRayQueryParameters3D.create(from, to, 1)
		var exc: Array[RID] = []
		exc.append(player.get_rid())
		q.exclude = exc
		var hit = space.intersect_ray(q)
		if not hit.is_empty():
			spawn_pos = hit.position
		else:
			spawn_pos = from - cam.global_transform.basis.z * 3.0
	else:
		spawn_pos = player.global_position - player.global_transform.basis.z * 2.5

	var node = PrefabBuilder.build_prefab(type_name, Vector3(1, 1, 1), Color.WHITE, false, "")
	if not node:
		print_log("[color=#ff6666]Не удалось создать объект типа '%s'. Проверьте имя префаба.[/color]" % type_name)
		return

	node.position = spawn_pos
	var cur_scene = get_tree().current_scene
	var container = cur_scene.find_child("NavRegion", true, false)
	if not container:
		container = cur_scene
	container.add_child(node)
	print_log("[color=#55ff55]Создан объект '%s' на позиции (%.1f, %.1f, %.1f)[/color]" % [type_name, spawn_pos.x, spawn_pos.y, spawn_pos.z])

func _cmd_teleport(args: Array[String]) -> void:
	var scene := get_tree().current_scene
	if scene and scene.has_method("editor_teleport") and args.size() >= 3 and args[0].is_valid_float() and args[1].is_valid_float() and args[2].is_valid_float():
		if scene.call("editor_teleport", Vector3(float(args[0]), float(args[1]), float(args[2]))):
			print_log("[color=#55ff55]Камера редактора перемещена.[/color]")
			return
	var player = GameManager.player_ref
	if not player or not is_instance_valid(player):
		print_log("[color=#ff6666]Ошибка: игрок не найден.[/color]")
		return

	if args.is_empty():
		print_log("[color=#ffaa55]Использование: teleport <X> <Y> <Z>, либо: teleport enemy, teleport door, teleport spawn[/color]")
		return

	var target_dest = args[0].to_lower()
	if target_dest == "enemy":
		if GameManager.enemy_ref and is_instance_valid(GameManager.enemy_ref):
			player.global_position = GameManager.enemy_ref.global_position + Vector3(0, 0.5, 2.0)
			print_log("[color=#55ff55]Телепортация к Врагу (Enemy)![/color]")
		else:
			print_log("[color=#ff6666]Враг не найден в сцене.[/color]")
		return
	elif target_dest == "door" or target_dest == "exit":
		if GameManager.door_position != Vector3.ZERO:
			player.global_position = GameManager.door_position + Vector3(0, 0.5, 1.5)
			print_log("[color=#55ff55]Телепортация к Двери выхода![/color]")
		else:
			print_log("[color=#ffaa55]Позиция двери выхода не задана.[/color]")
		return
	elif target_dest == "spawn":
		player.global_position = GameManager.player_spawn + Vector3(0, 0.5, 0)
		print_log("[color=#55ff55]Телепортация на точку спавна игрока![/color]")
		return

	if args.size() >= 3:
		var x = float(args[0])
		var y = float(args[1])
		var z = float(args[2])
		player.global_position = Vector3(x, y, z)
		print_log("[color=#55ff55]Телепортация на координаты (%.1f, %.1f, %.1f)[/color]" % [x, y, z])
	else:
		print_log("[color=#ff6666]Неверные аргументы. Пример: teleport 0 2 0 или teleport enemy[/color]")

func _cmd_possess() -> void:
	var player = GameManager.player_ref
	var enemy = GameManager.enemy_ref
	if not player or not is_instance_valid(player) or not enemy or not is_instance_valid(enemy):
		print_log("[color=#ff6666]Ошибка: игрок или монстр не найдены на карте.[/color]")
		return
	player.global_position = enemy.global_position + Vector3(0, 1.2, 0)
	GameManager.is_noclip = true
	GameManager.is_godmode = true
	var col_node = player.find_child("CollisionShape3D", true, false)
	if col_node and col_node is CollisionShape3D:
		col_node.disabled = true
	print_log("[color=#55ffaa]Вселение/наблюдение: перемещены в тело монстра (Noclip + Бессмертие включены).[/color]")

func _cmd_skinwalkerfun() -> void:
	print_log("[color=#ffaa33]Запуск секретного режима Skinwalker Fun...[/color]")
	close_console()
	GameManager.change_scene_fast("res://scenes/Polygon.tscn")

func _cmd_map(args: Array[String]) -> void:
	var json_maps = _get_available_json_maps()
	if args.is_empty() or args[0].to_lower() in ["list", "help", "?"]:
		print_log("[b][color=#ffff55]══ СПИСОК ДОСТУПНЫХ JSON-КАРТ ══[/color][/b]")
		for i in range(json_maps.size()):
			var m = json_maps[i]
			print_log("[b][color=#55ffdd][%d][/color][/b] [color=#ffffff]%s[/color] [color=#778899](%s)[/color]" % [i + 1, m["name"], m["path"]])
		print_log("[color=#ffdd88]Также доступны сцены:[/color] main, polygon, skinwalkerfun, editor, menu, street, intro")
		print_log("[color=#88ffaa]Для загрузки введите:[/color] map 1  [color=#88aacc]или[/color]  map prototype map")
		return

	var target_arg = " ".join(args).strip_edges()
	var lower_arg = target_arg.to_lower()

	# Проверка на спец-сцены
	match lower_arg:
		"main", "game":
			print_log("[color=#55ffaa]Загрузка основной сцены...[/color]")
			close_console()
			GameManager.change_scene_fast("res://scenes/Main.tscn")
			return
		"polygon", "arena", "test", "fun", "skinwalkerfun":
			_cmd_skinwalkerfun()
			return
		"editor", "debug":
			print_log("[color=#55ffaa]Загрузка 3D редактора карт...[/color]")
			close_console()
			GameManager.change_scene_fast("res://scenes/DebugEditor.tscn")
			return
		"menu":
			print_log("[color=#55ffaa]Загрузка главного меню...[/color]")
			close_console()
			GameManager.change_scene_fast("res://scenes/Menu.tscn")
			return
		"street":
			print_log("[color=#55ffaa]Загрузка улицы (побег на машине)...[/color]")
			close_console()
			GameManager.change_scene_fast("res://scenes/Street.tscn")
			return
		"intro", "cutscene":
			print_log("[color=#55ffaa]Загрузка вступления (авария на шоссе)...[/color]")
			close_console()
			GameManager.change_scene_fast("res://scenes/IntroCutscene.tscn")
			return

	# Проверка по порядковому номеру карты (например: map 1)
	if lower_arg.is_valid_int():
		var idx = lower_arg.to_int() - 1
		if idx >= 0 and idx < json_maps.size():
			var chosen = json_maps[idx]
			GameManager.active_map_path = chosen["path"]
			print_log("[color=#55ffaa]Загрузка JSON-карты [%d] '%s'...[/color]" % [idx + 1, chosen["name"]])
			close_console()
			GameManager.change_scene_fast("res://scenes/Main.tscn")
			return
		else:
			print_log("[color=#ff6666]Ошибка: номер карты вне диапазона (1..%d). Введите 'map' для списка.[/color]" % json_maps.size())
			return

	# Проверка по совпадению имени JSON-карты
	for i in range(json_maps.size()):
		var m = json_maps[i]
		var m_name = m["name"].to_lower()
		var m_fn = m["filename"].to_lower()
		if lower_arg == m_name or lower_arg in m_name or lower_arg in m_fn:
			GameManager.active_map_path = m["path"]
			print_log("[color=#55ffaa]Загрузка JSON-карты '%s' (%s)...[/color]" % [m["name"], m["path"]])
			close_console()
			GameManager.change_scene_fast("res://scenes/Main.tscn")
			return

	# Если указан прямой путь к .tscn
	if target_arg.ends_with(".tscn") and ResourceLoader.exists(target_arg):
		print_log("[color=#55ffaa]Загрузка сцены: %s...[/color]" % target_arg)
		close_console()
		GameManager.change_scene_fast(target_arg)
		return

	print_log("[color=#ff6666]Карта '%s' не найдена. Введите 'map' для списка всех доступных карт из JSON.[/color]" % target_arg)

func _print_help() -> void:
	print_log("[b][color=#ffff55]══ СПИСОК ДОСТУПНЫХ КОМАНД ══[/color][/b]")
	for def in COMMAND_DEFS:
		print_log("[b][color=#55ffdd]%s[/color][/b] — %s" % [def.syntax, def.desc])
	print_log("[color=#88bbcc]Горячие клавиши: [~ / Ё] - открыть/закрыть консоль, [F1] - инфо HUD, [F2] - хитбоксы, [Tab] - автозаполнение[/color]")
