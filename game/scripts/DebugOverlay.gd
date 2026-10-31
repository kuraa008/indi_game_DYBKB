class_name DebugOverlay
extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
#  DebugOverlay.gd — Информационная панель отладки [F1] и хитбоксы/путь [F2]
#  • F1: Счётчик FPS, состояние и форма ИИ, координаты, объект под ногами,
#        объект в прицеле, проверка условий побега, ошибки объектов.
#        Панель полупрозрачная (не перекрывает обзор игры).
#  • F2: 3D-визуализация хитбоксов и коллизий сквозь стены.
#  • passai: 3D-визуализация линии траектории движения Скинвокера в реальном времени.
# ══════════════════════════════════════════════════════════════════════════════

var is_hud_visible: bool = false
var is_hitboxes_visible: bool = false

var root_panel: PanelContainer
var info_label: RichTextLabel

# 3D отрисовщик хитбоксов и линии пути passai
var debug_3d_node: Node3D = null
var imm_mesh: ImmediateMesh = null
var hitbox_mesh_inst: MeshInstance3D = null
var debug_mat: StandardMaterial3D = null

func _init() -> void:
	layer = 120

func _ready() -> void:
	_build_ui()
	_setup_3d_renderer()
	visible = false

func _build_ui() -> void:
	root_panel = PanelContainer.new()
	root_panel.name = "DebugHUDPanel"
	root_panel.anchors_preset = Control.PRESET_TOP_LEFT
	root_panel.anchor_left = 0.0
	root_panel.anchor_top = 0.0
	root_panel.anchor_right = 0.0
	root_panel.anchor_bottom = 0.0
	root_panel.offset_left = 20
	root_panel.offset_top = 20
	root_panel.offset_right = 480
	root_panel.offset_bottom = 540
	root_panel.custom_minimum_size = Vector2(460, 520)

	# Полупрозрачный стильный фон со скруглением и аккуратной окантовкой
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.48)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.35, 0.55, 0.85, 0.55)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	root_panel.add_theme_stylebox_override("panel", style)
	add_child(root_panel)

	info_label = RichTextLabel.new()
	info_label.bbcode_enabled = true
	info_label.scroll_active = false
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_label.add_theme_font_size_override("normal_font_size", 12)
	root_panel.add_child(info_label)

func _setup_3d_renderer() -> void:
	imm_mesh = ImmediateMesh.new()
	hitbox_mesh_inst = MeshInstance3D.new()
	hitbox_mesh_inst.name = "Debug3DOverlayRenderer"
	hitbox_mesh_inst.mesh = imm_mesh

	debug_mat = StandardMaterial3D.new()
	debug_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_mat.vertex_color_use_as_albedo = true
	debug_mat.no_depth_test = true
	debug_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hitbox_mesh_inst.material_override = debug_mat

	# Добавляем MeshInstance3D в корневое окно для честного 3D-рендеринга
	get_tree().root.call_deferred("add_child", hitbox_mesh_inst)

func _exit_tree() -> void:
	if hitbox_mesh_inst and is_instance_valid(hitbox_mesh_inst):
		hitbox_mesh_inst.queue_free()

func toggle_hud() -> void:
	is_hud_visible = !is_hud_visible
	visible = is_hud_visible
	if is_hud_visible and GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		GameManager.ui_ref.call("show_hint", "Меню отладки: ВКЛЮЧЕНО [F1]", 2.0)

func toggle_hitboxes() -> void:
	is_hitboxes_visible = !is_hitboxes_visible
	if not is_hitboxes_visible and not GameManager.show_ai_path:
		if imm_mesh:
			imm_mesh.clear_surfaces()
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		var status = "ВКЛЮЧЕНЫ" if is_hitboxes_visible else "ОТКЛЮЧЕНЫ"
		GameManager.ui_ref.call("show_hint", "3D Хитбоксы: %s [F2]" % status, 2.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			toggle_hud()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			toggle_hitboxes()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_hud_visible:
		_update_hud_info()
	if is_hitboxes_visible or GameManager.show_ai_path:
		_render_3d_debug()
	elif imm_mesh and imm_mesh.get_surface_count() > 0:
		imm_mesh.clear_surfaces()

func _update_hud_info() -> void:
	var text = ""

	# 1. СИСТЕМА И ПРОИЗВОДИТЕЛЬНОСТЬ
	var fps = Engine.get_frames_per_second()
	var frame_ms = 1000.0 / max(1, fps)
	var fps_color = "#55ff55" if fps >= 55 else ("#ffbb44" if fps >= 30 else "#ff4444")
	var gfx = GameManager.graphics_quality.to_upper() if GameManager and "graphics_quality" in GameManager else "HIGH"
	text += "[b][color=#55aaff]═══ [F1] ОТЛАДКА И СИСТЕМА ═══[/color][/b]\n"
	text += "FPS: [b][color=%s]%d[/color][/b] (%.1f ms) | Качество: %s\n\n" % [fps_color, fps, frame_ms, gfx]

	# 2. ИГРОК И КООРДИНАТЫ
	var player = GameManager.player_ref if GameManager else null
	if player and is_instance_valid(player):
		var p_pos = player.global_position
		var p_vel = player.velocity
		var cam: Camera3D = null
		if player.has_node("Head/Camera"):
			cam = player.get_node("Head/Camera") as Camera3D
		elif player.has_node("Camera"):
			cam = player.get_node("Camera") as Camera3D
		elif player.has_node("Camera3D"):
			cam = player.get_node("Camera3D") as Camera3D
		elif player.find_child("Camera", true, false):
			cam = player.find_child("Camera", true, false) as Camera3D

		var pitch_deg = cam.rotation_degrees.x if cam else 0.0
		var yaw_deg = player.rotation_degrees.y

		var stance = "ОБЫЧНЫЙ"
		if player.get("is_hiding") == true:
			stance = "В УКРЫТИИ (Шкаф/Кровать)"
		elif player.get("is_crouching") == true:
			stance = "ПРИСЕД (Ctrl)"
		elif p_vel.length() > 4.6:
			stance = "СПРИНТ (Shift)"

		var noclip_str = " [color=#44ffbb][NOCLIP][/color]" if (GameManager and GameManager.is_noclip) else ""
		var god_str = " [color=#ff5588][GODMODE][/color]" if (GameManager and GameManager.is_godmode) else ""
		var batt_val = player.get("flash_battery")
		var batt_pct = batt_val if batt_val != null else 100.0

		text += "[b][color=#eedd88]► ИГРОК[/color][/b]%s%s\n" % [noclip_str, god_str]
		text += "Позиция: [color=#55ffdd]X: %.2f,  Y: %.2f,  Z: %.2f[/color]\n" % [p_pos.x, p_pos.y, p_pos.z]
		text += "Скорость: [color=#88ff88]%.2f м/с[/color] | Взгляд: Yaw: %.1f°, Pitch: %.1f°\n" % [p_vel.length(), yaw_deg, pitch_deg]
		text += "Стойка: %s | Фонарик: %s (%.0f%%)\n\n" % [
			stance,
			"ВКЛ" if player.get("flashlight_on") else "ВЫКЛ",
			batt_pct
		]

		# 3. НА ЧЁМ СТОИМ
		var ground_info = _get_player_ground_info(player)
		text += "[b][color=#eedd88]► ОБЪЕКТ ПОД НОГАМИ[/color][/b]\n"
		text += ground_info + "\n\n"

		# 4. НА ЧТО СМОТРИМ
		var look_info = _get_player_look_info(player, cam)
		text += "[b][color=#eedd88]► ОБЪЕКТ В ПРИЦЕЛЕ[/color][/b]\n"
		text += look_info + "\n\n"
	else:
		text += "[color=#ff5555]Игрок не найден в сцене.[/color]\n\n"

	# 5. ИИ ВРАГА
	var enemy = GameManager.enemy_ref if GameManager else null
	text += "[b][color=#ff7777]► ИИ ВРАГА (СКИНВОКЕР)[/color][/b]\n"
	if enemy and is_instance_valid(enemy):
		var e_state_name = _get_enemy_state_name(enemy)
		var e_pos = enemy.global_position
		var e_dist = e_pos.distance_to(player.global_position) if (player and is_instance_valid(player)) else 0.0
		var can_see = enemy.call("_can_see_player") if enemy.has_method("_can_see_player") else false
		var see_str = "[color=#ff3333]ДА (ВИДИТ!)[/color]" if can_see else "[color=#88aa88]НЕТ[/color]"
		var noai_str = " [color=#ffdd55][ЗАМОРОЖЕН][/color]" if (GameManager and GameManager.is_no_ai) else ""
		var passai_str = " [color=#ffaa33][PASS-AI ON][/color]" if (GameManager and GameManager.show_ai_path) else ""

		text += "Режим / Форма: [b][color=#ff5555]%s[/color][/b]%s%s\n" % [e_state_name, noai_str, passai_str]
		var thought_str = enemy.call("get_current_thought") if enemy.has_method("get_current_thought") else ""
		if thought_str != "":
			text += "[Мысль] [color=#ffdd66]%s[/color]\n" % thought_str
		text += "Позиция: (%.1f, %.1f, %.1f) | До игрока: [b]%.1f м[/b]\n" % [e_pos.x, e_pos.y, e_pos.z, e_dist]
		text += "Прямой контакт: %s | Скорость: %.1f м/с\n\n" % [see_str, enemy.velocity.length()]
	else:
		text += "Враг отсутствует в сцене.\n\n"

	# 6. УСЛОВИЯ ПОБЕГА
	text += "[b][color=#77dd77]► УСЛОВИЯ ПОБЕГА[/color][/b]\n"
	if GameManager:
		var pwr = "ВКЛ (Свет)" if GameManager.room_lights_on else "ВЫКЛ (Темно)"
		var brd = "СОРВАНЫ (Лом)" if GameManager.door_boards_broken else "ЗАКОЛОЧЕНО"
		var keys_list = GameManager.keys_inventory
		var keys = str(keys_list) if not keys_list.is_empty() else "НЕТ"
		text += "Свет в доме: %s | Батареи: %d/3\n" % [pwr, GameManager.battery_cells]
		text += "Доски: %s | Ключи: %s\n" % [brd, keys]
		text += "Шифр сейфа: [color=#ffdd44]%s[/color] | Бутылок: %d\n\n" % [GameManager.safe_code, GameManager.throwables_count]

	# 7. ДИАГНОСТИКА И ОШИБКИ
	text += "[b][color=#55aaff]► ЦЕЛОСТНОСТЬ И ОШИБКИ[/color][/b]\n"
	var checks: Array[String] = []
	var cur_scene = get_tree().current_scene if get_tree() else null
	if cur_scene and is_instance_valid(cur_scene):
		var nav = cur_scene.find_child("NavRegion", true, false) as NavigationRegion3D
		if nav and nav.navigation_mesh:
			checks.append("[OK] Навмеш: Сгенерирован (размер ячейки 0.1м)")
		else:
			checks.append("[!] Навмеш: Не найден в активной сцене")
	else:
		checks.append("[!] Сцена ожидает загрузки")

	if player and is_instance_valid(player) and player.global_position.y < -15.0:
		checks.append("[X] ОШИБКА: Игрок провалился под карту!")
	elif player and is_instance_valid(player):
		checks.append("[OK] Позиция игрока: В пределах карты")

	text += "\n".join(checks)
	info_label.text = text

func _get_player_ground_info(player: CharacterBody3D) -> String:
	if not player or not is_instance_valid(player):
		return "Игрок не найден"
	if not player.is_on_floor():
		return "[color=#88aacc]В воздухе / Прыжок[/color]"

	for i in range(player.get_slide_collision_count()):
		var col = player.get_slide_collision(i)
		if not col:
			continue
		var collider = col.get_collider()
		if collider and is_instance_valid(collider):
			var c_name = collider.name
			var it = collider.get_meta("item_type") if collider.has_meta("item_type") else ""
			var meta_str = " (тип: %s)" % str(it) if str(it) != "" else ""
			var pos_str = ""
			if col.has_method("get_position"):
				var p = col.get_position()
				pos_str = " [Pos: %.1f, %.1f, %.1f]" % [p.x, p.y, p.z]
			return "[color=#88ffaa]%s[/color]%s%s" % [c_name, meta_str, pos_str]

	return "[color=#88ffaa]Пол / Земля[/color]"

func _get_player_look_info(player: CharacterBody3D, cam: Camera3D) -> String:
	if not cam or not is_instance_valid(cam):
		return "Камера недоступна"
	if not player or not is_instance_valid(player) or not player.is_inside_tree():
		return "Игрок вне сцены"

	var space = player.get_world_3d().direct_space_state if player.get_world_3d() else null
	if not space:
		return "Физическое пространство недоступно"

	var from = cam.global_position
	var to = from - cam.global_transform.basis.z * 15.0
	var q = PhysicsRayQueryParameters3D.create(from, to, 1)
	var exc: Array[RID] = []
	if player:
		exc.append(player.get_rid())
	q.exclude = exc
	q.collide_with_areas = true
	var hit = space.intersect_ray(q)

	if hit.is_empty() or not hit.collider:
		return "[color=#778899]Пусто (дальше 15м)[/color]"

	var col = hit.collider
	if not is_instance_valid(col):
		return "[color=#778899]Пусто[/color]"
	var dist = from.distance_to(hit.position)
	var c_name = col.name
	var p_node = col.get_parent()
	var it = col.get_meta("item_type") if col.has_meta("item_type") else ""
	if str(it) == "" and p_node and is_instance_valid(p_node) and p_node.has_meta("item_type"):
		it = p_node.get_meta("item_type")

	var extra = ""
	if col.has_method("is_door_locked"):
		var locked = col.call("is_door_locked")
		extra += " | Дверь: " + ("[color=#ff5555]ЗАПЕРТА[/color]" if locked else "[color=#55ff55]ОТКРЫТА[/color]")
	elif col.has_meta("is_powered"):
		extra += " | Питание: " + str(col.get_meta("is_powered"))

	return "[b][color=#55ffdd]%s[/color][/b] (дист: %.1fм)%s%s" % [c_name, dist, (" [тип: " + str(it) + "]") if str(it) != "" else "", extra]

func _get_enemy_state_name(enemy: Node) -> String:
	var state_val = enemy.get("state")
	if state_val == null:
		return "НЕИЗВЕСТНО"
	match state_val:
		0: return "ПАТРУЛЬ (PATROL)"
		1: return "ДОМАШНИЕ ДЕЛА (ROUTINE)"
		2: return "ТРЕВОГА / НА ЗВУК (ALERT)"
		3: return "СМЕРТЕЛЬНАЯ ПОГОНЯ (HUNT)"
		4: return "ПОИСК В КОМНАТАХ (SEARCH)"
		5: return "ПРОВЕРКА ПОДВАЛА (BASEMENT)"
		6: return "ЯРОСТЬ (RAGE)"
		7: return "ЗАСАДА ЗА ДВЕРЬЮ (AMBUSH)"
	return str(state_val)

# ══════════════════════════════════════════════════════════════════════════════
#  3D Хитбокс-рендер и отображение пути passai
# ══════════════════════════════════════════════════════════════════════════════
func _render_3d_debug() -> void:
	if not hitbox_mesh_inst or not is_instance_valid(hitbox_mesh_inst) or not imm_mesh:
		return

	imm_mesh.clear_surfaces()
	imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	# 1. Хитбоксы (F2)
	if is_hitboxes_visible:
		# Хитбокс Игрока (Зеленый)
		if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
			var p = GameManager.player_ref
			_draw_capsule_wireframe(p.global_position + Vector3(0, 0.88, 0), 0.32, 1.75, Color(0.2, 1.0, 0.3, 0.85))

		# Хитбокс Монстра (Красный)
		if GameManager.enemy_ref and is_instance_valid(GameManager.enemy_ref):
			var e = GameManager.enemy_ref
			_draw_capsule_wireframe(e.global_position + Vector3(0, 0.95, 0), 0.28, 1.90, Color(1.0, 0.2, 0.2, 0.90))

		# Хитбоксы дверей (Желтые)
		var doors = get_tree().get_nodes_in_group("doors")
		for d in doors:
			if is_instance_valid(d) and d is Node3D:
				_draw_node_collision_wireframe(d, Color(1.0, 0.9, 0.2, 0.75))

	# 2. Линия пути ИИ (passai)
	if GameManager.show_ai_path and GameManager.enemy_ref and is_instance_valid(GameManager.enemy_ref):
		var e = GameManager.enemy_ref
		var path = e.call("get_debug_navigation_path") if e.has_method("get_debug_navigation_path") else PackedVector3Array()
		if path.size() >= 2:
			var path_col = Color(1.0, 0.52, 0.1, 0.95)
			var e_state = e.get("state")
			if e_state == 3: # HUNT
				path_col = Color(1.0, 0.15, 0.15, 0.98) # Алый
			elif e_state == 0: # PATROL
				path_col = Color(0.2, 0.85, 1.0, 0.92) # Голубой
			elif e_state == 2: # ALERT
				path_col = Color(1.0, 0.95, 0.2, 0.95) # Желтый
			_draw_ai_path_wireframe(path, path_col)

	imm_mesh.surface_end()

func _draw_ai_path_wireframe(path: PackedVector3Array, col: Color) -> void:
	var y_lift = Vector3(0, 0.16, 0)
	for i in range(path.size() - 1):
		var p1 = path[i] + y_lift
		var p2 = path[i + 1] + y_lift

		# Линия между соседними точками навмеша
		imm_mesh.surface_set_color(col)
		imm_mesh.surface_add_vertex(p1)
		imm_mesh.surface_set_color(col)
		imm_mesh.surface_add_vertex(p2)

		# Вертикальный маячок на угле поворота
		imm_mesh.surface_set_color(Color(col.r, col.g, col.b, 0.45))
		imm_mesh.surface_add_vertex(p1)
		imm_mesh.surface_set_color(col)
		imm_mesh.surface_add_vertex(p1 + Vector3(0, 0.65, 0))

	# Финальная точка назначения пути
	var end_pt = path[path.size() - 1] + y_lift
	var rad = 0.35
	var target_col = Color(1.0, 1.0, 0.3, 0.95)
	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(-rad, 0, 0))
	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(0, 0, rad))

	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(0, 0, rad))
	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(rad, 0, 0))

	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(rad, 0, 0))
	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(0, 0, -rad))

	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(0, 0, -rad))
	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(-rad, 0, 0))

	# Шпиль-указатель цели
	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt)
	imm_mesh.surface_set_color(target_col)
	imm_mesh.surface_add_vertex(end_pt + Vector3(0, 1.4, 0))

func _draw_node_collision_wireframe(node: Node, col: Color) -> void:
	for ch in node.find_children("*", "CollisionShape3D", true, false):
		if ch is CollisionShape3D and is_instance_valid(ch) and not ch.disabled:
			var shape = ch.shape
			if shape is BoxShape3D:
				_draw_box_wireframe(ch.global_transform, shape.size, col)
			elif shape is CapsuleShape3D:
				_draw_capsule_wireframe(ch.global_position, shape.radius, shape.height, col)

func _draw_box_wireframe(xform: Transform3D, sz: Vector3, col: Color) -> void:
	var h = sz * 0.5
	var corners = [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)
	]
	var world_corners: Array[Vector3] = []
	for c in corners:
		world_corners.append(xform * c)

	var edges = [
		[0,1], [1,2], [2,3], [3,0],
		[4,5], [5,6], [6,7], [7,4],
		[0,4], [1,5], [2,6], [3,7]
	]
	for e in edges:
		imm_mesh.surface_set_color(col)
		imm_mesh.surface_add_vertex(world_corners[e[0]])
		imm_mesh.surface_set_color(col)
		imm_mesh.surface_add_vertex(world_corners[e[1]])

func _draw_capsule_wireframe(center: Vector3, radius: float, height: float, col: Color) -> void:
	var half_h = max(0.0, height * 0.5 - radius)
	var steps = 12

	for y_off in [-half_h, half_h]:
		for i in range(steps):
			var a1 = (i / float(steps)) * TAU
			var a2 = ((i + 1) / float(steps)) * TAU
			var p1 = center + Vector3(cos(a1) * radius, y_off, sin(a1) * radius)
			var p2 = center + Vector3(cos(a2) * radius, y_off, sin(a2) * radius)
			imm_mesh.surface_set_color(col)
			imm_mesh.surface_add_vertex(p1)
			imm_mesh.surface_set_color(col)
			imm_mesh.surface_add_vertex(p2)

	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		var p1 = center + Vector3(cos(ang) * radius, -half_h, sin(ang) * radius)
		var p2 = center + Vector3(cos(ang) * radius, half_h, sin(ang) * radius)
		imm_mesh.surface_set_color(col)
		imm_mesh.surface_add_vertex(p1)
		imm_mesh.surface_set_color(col)
		imm_mesh.surface_add_vertex(p2)
