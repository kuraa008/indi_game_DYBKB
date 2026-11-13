class_name DebugOverlay
extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
#  DebugOverlay.gd — панель отладки [F1] и хитбоксы с путём существа [F2]
#  • F1: производительность (FPS, отрисовки, память), сюжет (карта, глава, задача),
#        игрок (позиция, состояние, что под прицелом), существо (режим, дистанция,
#        видит ли игрока, сценарий главы) и короткие проверки.
#  • F2: 3D-хитбоксы и коллизии сквозь стены, линия пути существа (passai).
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
	root_panel.offset_right = 560
	root_panel.offset_bottom = 380
	root_panel.custom_minimum_size = Vector2(540, 0)

	# Полупрозрачный стильный фон со скруглением и аккуратной окантовкой
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.03, 0.035, 0.78)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 1, 1, 0.08)
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
	info_label.fit_content = true
	info_label.add_theme_font_size_override("normal_font_size", 13)
	info_label.add_theme_font_size_override("bold_font_size", 12)
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
		GameManager.ui_ref.call("show_hint", "Отладка: F1 закрыть", 1.5)

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
	var lines: PackedStringArray = []
	var player = GameManager.player_ref if is_instance_valid(GameManager.player_ref) else null
	var scene := get_tree().current_scene

	# ── Производительность ──
	var fps := int(round(Engine.get_frames_per_second()))
	var fps_col := C_OK if fps >= 55 else (C_WARN if fps >= 30 else C_BAD)
	lines.append(_head("ПРОИЗВОДИТЕЛЬНОСТЬ"))
	lines.append("FPS %s  ·  кадр %.1f мс  ·  качество %s  ·  VHS %s" % [
		_col(str(fps), fps_col), 1000.0 / maxf(1.0, float(fps)), str(GameManager.graphics_quality).to_upper(),
		"вкл" if GameManager.vhs_enabled else "выкл"])
	lines.append("Отрисовок %d  ·  объектов %d  ·  память %.0f МБ" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0])

	# ── Сюжет ──
	lines.append("")
	lines.append(_head("СЮЖЕТ"))
	lines.append("Карта: %s" % _col(str(GameManager.active_map_path).get_file().get_basename(), C_VALUE))
	var chapter := _chapter_name(scene)
	lines.append("Глава: %s" % (_col(chapter, C_VALUE) if chapter != "" else _col("нет сюжетного скрипта", C_DIM)))
	var task := _current_task(scene)
	lines.append("Задача: %s" % (_col(task, C_VALUE) if task != "" else _col("нет", C_DIM)))
	var flags: PackedStringArray = []
	if GameManager.is_godmode:
		flags.append("обычная смерть выключена (поимку решает глава)" if _director_info(scene) != "" else "бессмертие")
	if GameManager.is_no_ai:
		flags.append("ИИ выключен")
	if GameManager.is_noclip:
		flags.append("noclip")
	if Phone.is_ringing():
		flags.append("звонит телефон")
	if not flags.is_empty():
		lines.append("Флаги: %s" % _col(", ".join(flags), C_WARN))

	# ── Игрок ──
	lines.append("")
	lines.append(_head("ИГРОК"))
	if player == null:
		lines.append(_col("нет игрока в сцене", C_DIM))
	else:
		var p: Vector3 = player.global_position
		lines.append("Позиция %s  ·  скорость %.1f м/с" % [_col("%.1f, %.1f, %.1f" % [p.x, p.y, p.z], C_VALUE), Vector2(player.velocity.x, player.velocity.z).length()])
		lines.append("Состояние: %s  ·  фонарик %s" % [_col(_player_state(player), C_VALUE), "вкл" if player.get("flashlight_on") == true else "выкл"])
		lines.append("Под ногами: %s" % _get_player_ground_info(player))
		lines.append("В прицеле: %s" % _get_player_target_info(player))

	# ── Существо ──
	lines.append("")
	lines.append(_head("СУЩЕСТВО"))
	var enemy = GameManager.enemy_ref if is_instance_valid(GameManager.enemy_ref) else null
	if enemy == null:
		lines.append(_col("на этой карте его нет", C_DIM))
	elif not enemy.visible:
		lines.append(_col("не здесь: ходит наверху / ждёт", C_DIM) + _director_info(scene))
	else:
		var dist: float = enemy.global_position.distance_to(player.global_position) if player else 0.0
		var sees: bool = enemy.has_method("_can_see_player") and bool(enemy.call("_can_see_player"))
		lines.append("Режим: %s%s" % [_col(_get_enemy_state_name(enemy), C_BAD if int(enemy.get("state")) in [3, 6, 12] else C_VALUE), _director_info(scene)])
		lines.append("До игрока %s  ·  видит игрока: %s  ·  скорость %.1f м/с" % [
			_col("%.1f м" % dist, C_BAD if dist < 4.0 else C_VALUE), _col("ДА", C_BAD) if sees else "нет", enemy.velocity.length()])
		var thought = enemy.call("get_current_thought") if enemy.has_method("get_current_thought") else ""
		if str(thought) != "":
			lines.append("Мысль: %s" % _col(str(thought), C_DIM))

	# ── Проверки ──
	var problems: PackedStringArray = []
	if player and player.global_position.y < -15.0:
		problems.append("игрок провалился под карту")
	if scene and scene.find_child("NavRegion", true, false) == null and enemy != null:
		problems.append("нет навигационной сетки: существо не найдёт путь")
	if fps > 0 and fps < 30:
		problems.append("FPS ниже 30")
	lines.append("")
	lines.append(_head("ПРОВЕРКИ"))
	lines.append(_col("всё в порядке", C_OK) if problems.is_empty() else _col("; ".join(problems), C_BAD))
	lines.append(_col("F1 закрыть  ·  F2 хитбоксы и путь существа", C_DIM))
	info_label.text = "\n".join(lines)


const C_HEAD := "#d8d4c8"
const C_VALUE := "#e9e6dc"
const C_DIM := "#8a8780"
const C_OK := "#7fcf8a"
const C_WARN := "#e2b75a"
const C_BAD := "#e06a5c"


func _head(title: String) -> String:
	return "[b][color=%s]%s[/color][/b]" % [C_HEAD, title]


func _col(text: String, color: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


# Сюжетный скрипт сцены: по имени узла, который ставит Main
func _chapter_name(scene: Node) -> String:
	if scene == null:
		return ""
	var known := [
		["HouseChapter3", "3 · комната отца"],
		["BasementChapter", "2 · подвал"],
		["PrologueApartment", "пролог · квартира"],
		["StreetCar", "пролог · улица"],
		["CraneHouseSam", "4 · дом Крейна"],
		["FinaleStation", "финал · заправка"],
		["HighwayChapter", "1 · дом отца"],
	]
	for pair in known:
		var node := scene.get_node_or_null(pair[0])
		if node != null and (not ("visible" in node) or bool(node.get("visible"))):
			return pair[1]
	return ""


func _current_task(scene: Node) -> String:
	if scene == null:
		return ""
	for tracker in scene.find_children("*", "MissionTracker", true, false):
		if is_instance_valid(tracker) and tracker.visible and not tracker.is_queued_for_deletion() and tracker.has_method("current_text"):
			var text := str(tracker.call("current_text"))
			if text != "":
				return text
	return ""


func _player_state(player: Node) -> String:
	if player.get("is_dead") == true:
		return "погиб"
	if player.get("is_in_cutscene") == true:
		return "кат-сцена"
	if player.get("is_hiding") == true:
		return "в укрытии"
	if Phone.is_open():
		return "в телефоне"
	if GameManager.is_reading_note:
		return "читает записку"
	if GameManager.is_backpack_open:
		return "окно открыто (рюкзак, записка, замок)"
	if player.get("is_crouching") == true:
		return "присел"
	if player.get("is_sprinting") == true:
		return "бежит"
	return "идёт" if Vector2(player.velocity.x, player.velocity.z).length() > 0.3 else "стоит"


# То, с чем игрок взаимодействует, и подсказка, которую он видит
func _get_player_target_info(player: Node) -> String:
	var target: Node = player.call("_get_interactable") if player.has_method("_get_interactable") else null
	if target == null:
		return _col("ничего", C_DIM)
	var hint := ""
	var n: Node = target
	for _i in range(4):
		if n == null:
			break
		if n.has_method("get_interaction_hint"):
			hint = str(n.call("get_interaction_hint"))
			break
		n = n.get_parent()
	var kind := str(target.get_meta("item_type", ""))
	var dist: float = (target as Node3D).global_position.distance_to(player.global_position) if target is Node3D else 0.0
	var label := hint if hint != "" else str(target.name)
	return "%s  ·  %.1f м%s" % [_col(label.strip_edges(), C_VALUE), dist, (" · " + kind) if kind != "" else ""]


# Сценарий главы, который ведёт существо (подвал или дом)
func _director_info(scene: Node) -> String:
	if scene == null:
		return ""
	for path in ["HouseChapter3/BasementCreature", "BasementChapter/BasementCreature"]:
		var cr := scene.get_node_or_null(path)
		if cr == null:
			continue
		if cr.get("mode") != null:
			return "  ·  обход: " + ("ходит по кругу" if str(cr.get("mode")) == "patrol" else "ищет / гонится") + "  ·  поймал раз: %d" % int(cr.get("catches"))
		var phases := ["ждёт наверху", "спускается (начало)", "идёт к месту пробуждения", "нюхает", "зовёт голосом Сэма", "уходит", "стучит наверху", "проверяет подвал", "уходит наверх"]
		var ph := int(cr.get("phase"))
		return "  ·  сценарий: %s  ·  поймал раз: %d" % [phases[ph] if ph < phases.size() else str(ph), int(cr.get("catches"))]
	return ""

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
			if str(c_name).begins_with("@"):
				c_name = "пол карты"
			var it = collider.get_meta("item_type") if collider.has_meta("item_type") else ""
			var meta_str = " (тип: %s)" % str(it) if str(it) != "" else ""
			var pos_str = ""
			if col.has_method("get_position"):
				var p = col.get_position()
				pos_str = " [Pos: %.1f, %.1f, %.1f]" % [p.x, p.y, p.z]
			return "[color=#88ffaa]%s[/color]%s%s" % [c_name, meta_str, pos_str]

	return "[color=#88ffaa]Пол / Земля[/color]"

func _get_enemy_state_name(enemy: Node) -> String:
	var state_val = enemy.get("state")
	if state_val == null:
		return "неизвестно"
	var names := ["обход", "дела по дому", "тревога", "погоня", "поиск", "проверяет подвал", "ярость",
		"засада", "проверяет укрытие", "слушает у укрытия", "слушает", "крадётся", "рывок"]
	var i := int(state_val)
	return names[i] if i >= 0 and i < names.size() else str(state_val)


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
