extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  Polygon.gd — Полигон наблюдения на основе карты прототипа (prototype map.json)
#  • Аутентичная геометрия особняка из res://assets/prototype map.json
#  • Режим 1: Вы — Скинвокер (Хищник). Вы охотитесь на бота-выжившего,
#             который закрывает за собой двери, бросает бутылки-приманки,
#             петляет по комнатам, делает Corner Jukes и вырывается из шкафов.
#             У Скинвокера активны хищное ночное зрение и тепловая био-видимость.
#             Записывает сессию отдельно; поведение основного ИИ не изменяет.
#  • Режим 2: Вы — Выживший против фиксированного ИИ скинвокера.
#             Корректный экран смерти при поимке без зависания и крашей.
#  • Режим 3: Наблюдатель (Свободная камера сверху).
# ══════════════════════════════════════════════════════════════════════════════

const PROTOTYPE_MAP_PATH   = "res://assets/prototype map.json"
const SAVE_RECORDING_PATH  = "user://skinwalker_playstyle_recording.json"

var nav_region: NavigationRegion3D
var bot_node: CharacterBody3D = null
var monster_player: CharacterBody3D = null
var real_player_node: CharacterBody3D = null
var enemy_ai_node: CharacterBody3D = null
var free_camera_node: Camera3D = null
var death_overlay_ui: Control = null

var world_env: WorldEnvironment = null
var we_resource: Environment = null

var current_role: int = 1 # 1: Игрок = Монстр, 2: Игрок = Выживший, 3: Авто-тест

var player_spawn: Vector3 = Vector3(-9.0, 0.0, -13.0)
var enemy_spawn: Vector3  = Vector3(9.5, 0.0, -1.5)
var bot_waypoints: Array[Vector3] = []

var hud_layer: CanvasLayer
var status_label: RichTextLabel
var predator_vignette: ColorRect = null
var game_ui: CanvasLayer = null
var exit_door_node: Node3D = null
var escape_items_node: Node3D = null
var monster_idle_timer: float = 0.0
var monster_last_pos: Vector3 = Vector3.ZERO

# ── Адаптивный ИИ (Brain) телеметрия и 3D визуализация ──
var brain_panel: PanelContainer = null
var brain_label: RichTextLabel = null
var heatmap_root: Node3D = null
var show_heatmap: bool = true
var heatmap_timer: float = 0.0
var ai_level_presets: Array[float] = [0.0, 0.25, 0.50, 0.75, 1.0, -1.0] # -1 = auto
var ai_level_preset_idx: int = 5 # default to auto

# ── Запись сессии ──
var is_recording: bool = true
var recorded_samples: Array[Dictionary] = []
var sample_timer: float = 0.0
var total_record_time: float = 0.0
var current_action_name: String = "ПОИСК / ПАТРУЛЬ"

# Тактические метрики игрока
var time_ambushing: float = 0.0
var time_stalking: float = 0.0
var time_sprinting: float = 0.0
var attacks_count: int = 0
var flank_cutoffs_count: int = 0
var direct_chases_count: int = 0
var distractions_ignored: int = 0
var distractions_followed: int = 0
var doors_kicked: int = 0
var hiding_spots_checked: int = 0

# Флаги отслеживания событий
var last_had_los: bool = false
var last_distraction_time: float = -999.0
var last_distraction_pos: Vector3 = Vector3.ZERO
var tracking_distraction: bool = false

# Уведомления об обманах бота
var last_event_msg: String = ""
var event_msg_timer: float = 0.0

func _ready() -> void:
	# Инструмент разработчика: обычные кнопки Godot вместо оформления игры
	get_window().theme = ThemeDB.get_default_theme()
	GameManager.reset_state()
	GameManager.generate_new_safe_code()
	if not GameManager.game_over.is_connected(_on_game_over):
		GameManager.game_over.connect(_on_game_over)
	if not GameManager.game_won.is_connected(_on_game_won):
		GameManager.game_won.connect(_on_game_won)

	heatmap_root = Node3D.new()
	heatmap_root.name = "HeatmapVisualizer"
	add_child(heatmap_root)

	_setup_environment()
	_build_prototype_mansion()
	_setup_hud()
	call_deferred("_apply_role", 2)

func _setup_environment() -> void:
	world_env = WorldEnvironment.new()
	we_resource = Environment.new()
	we_resource.background_mode = Environment.BG_COLOR
	we_resource.background_color = Color(0.04, 0.05, 0.07)
	we_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we_resource.ambient_light_color = Color(0.24, 0.28, 0.36)
	we_resource.ambient_light_energy = 1.6
	world_env.environment = we_resource
	add_child(world_env)

	# Направленный лунный свет
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 40, 0)
	sun.light_color = Color(0.70, 0.80, 0.95)
	sun.light_energy = 0.6
	add_child(sun)

func _build_prototype_mansion() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	add_child(nav_region)
	NavigationServer3D.map_set_cell_size(nav_region.get_navigation_map(), 0.10)
	NavigationServer3D.map_set_cell_height(nav_region.get_navigation_map(), 0.10)

	var nm = NavigationMesh.new()
	nm.agent_radius = 0.35
	nm.agent_height = 1.95
	nm.agent_max_climb = 0.35
	nm.cell_size = 0.10
	nm.cell_height = 0.10
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_region.navigation_mesh = nm

	# Пол особняка
	_build_floor(Vector3(-0.5, 0.0, -3.5), Vector3(36, 0.3, 36))
	# Потолок особняка
	_build_ceil(Vector3(-0.5, 3.2, -3.5), Vector3(36, 0.3, 36))

	# Читаем prototype map.json
	var file = FileAccess.open(PROTOTYPE_MAP_PATH, FileAccess.READ)
	if not file:
		push_warning("prototype map.json не найден — строим базовую геометрию")
		_build_fallback_geometry()
		return

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		_build_fallback_geometry()
		return
	file.close()

	bot_waypoints.clear()
	var objects: Array = json.data.get("objects", [])
	for obj in objects:
		var o_type: String  = obj.get("type", "cube")
		var obj_id: int     = obj.get("id", -1)
		var pa              = obj.get("position", [0, 1, 0])
		var ra              = obj.get("rotation", [0, 0, 0])
		var sa              = obj.get("scale",    [1, 2, 1])
		var color_s: String = obj.get("color", "#7d8590")

		var pos = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
		var rot = Vector3(float(ra[0]), float(ra[1]), float(ra[2]))
		var sz  = Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
		var col = Color.html(color_s)

		match o_type:
			"marker":
				var c_str = str(obj.get("comment", "")).to_lower()
				var n_str = str(obj.get("name", "")).to_lower()
				if "враг" in c_str or "враг" in n_str or "enemy" in n_str:
					enemy_spawn = pos
					enemy_spawn.y = 0.0
				elif "игрок" in c_str or "игрок" in n_str:
					player_spawn = pos
					player_spawn.y = 0.0
				var wp = pos
				wp.y = 0.0
				bot_waypoints.append(wp)
			"cube":
				if obj_id == 82:
					_build_exit_door(pos, rot.y)
				else:
					_build_wall(pos, sz, col)
					if sz.x > 3.0 or sz.z > 3.0:
						var room_pt = pos + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
						room_pt.y = 0.0
						bot_waypoints.append(room_pt)

	# Расставляем интерактивные двери и укрытия (шкафы, кровати, столы)
	_build_prop("door_simple", Vector3(-6.5, 0, -8.5), 90.0)
	_build_prop("door_simple", Vector3(0.0, 0, -8.5), 90.0)
	_build_prop("door_simple", Vector3(4.5, 0, -6.5), 0.0)
	_build_prop("door_simple", Vector3(-4.5, 0, 1.0), 0.0)

	_build_prop("prop_wardrobe", Vector3(-12.5, 0, -15.5), 0.0)
	_build_prop("prop_wardrobe", Vector3(11.5, 0, -15.5), 180.0)
	_build_prop("prop_wardrobe", Vector3(10.5, 0, 5.5), 90.0)
	_build_prop("prop_bed", Vector3(-11.0, 0, -2.5), 90.0)
	_build_prop("prop_table", Vector3(0.0, 0, -2.0), 0.0)
	_build_prop("prop_sofa", Vector3(8.0, 0, -2.0), -90.0)

	# Освещение в комнатах
	_add_ceiling_lamp(Vector3(-7.0, 2.7, -13.0))
	_add_ceiling_lamp(Vector3(7.0, 2.7, -13.0))
	_add_ceiling_lamp(Vector3(-7.0, 2.7, 0.0))
	_add_ceiling_lamp(Vector3(7.0, 2.7, 0.0))

	if bot_waypoints.size() < 4:
		bot_waypoints = [
			Vector3(-9, 0, -13), Vector3(-4, 0, -13), Vector3(0, 0, -13),
			Vector3(7, 0, -13), Vector3(7, 0, -2), Vector3(0, 0, -2),
			Vector3(-9, 0, -2), Vector3(-9, 0, 6), Vector3(0, 0, 6), Vector3(7, 0, 6)
		]

	_spawn_escape_quest()
	_bake_walkable_routes()

func _build_fallback_geometry() -> void:
	_build_floor(Vector3(0, 0, 0), Vector3(28, 0.3, 28))
	_build_wall(Vector3(0, 1.8, -14), Vector3(28, 3.6, 0.4), Color(0.4, 0.4, 0.45))
	_build_wall(Vector3(0, 1.8, 14), Vector3(28, 3.6, 0.4), Color(0.4, 0.4, 0.45))
	_build_wall(Vector3(-14, 1.8, 0), Vector3(0.4, 3.6, 28), Color(0.4, 0.4, 0.45))
	_build_wall(Vector3(14, 1.8, 0), Vector3(0.4, 3.6, 28), Color(0.4, 0.4, 0.45))
	_build_prop("prop_wardrobe", Vector3(-10, 0, -10), 0.0)
	_build_prop("prop_bed", Vector3(-8, 0, -4), 90.0)
	_build_exit_door(Vector3(0, 0, 14), 0.0)
	bot_waypoints = [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(8, 0, 8), Vector3(-8, 0, 8)]
	_spawn_escape_quest()
	_bake_walkable_routes()

func _bake_walkable_routes() -> void:
	# Door leaves are dynamic obstacles: baking them would disconnect whole rooms.
	var disabled_shapes: Array[CollisionShape3D] = []
	for shape in find_children("*", "CollisionShape3D", true, false):
		var parent = shape.get_parent()
		if parent == null or shape.disabled:
			continue
		var item_type: String = str(parent.get_meta("item_type", ""))
		if parent.name == "Panel" or parent.name.begins_with("Door") or parent.has_method("is_door_locked") or parent.has_method("open_by_enemy") or item_type.begins_with("door") or item_type.begins_with("custom_door"):
			shape.disabled = true
			disabled_shapes.append(shape)
	nav_region.bake_navigation_mesh(false)
	for shape in disabled_shapes:
		if is_instance_valid(shape):
			shape.disabled = false

func _build_floor(pos: Vector3, sz: Vector3) -> void:
	var sb = StaticBody3D.new()
	sb.position = pos
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.16, 0.15)
	mat.roughness = 0.85
	bm.surface_set_material(0, mat)
	mi.mesh = bm
	sb.add_child(mi)

	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = sz
	col.shape = box
	sb.add_child(col)
	nav_region.add_child(sb)

func _build_ceil(pos: Vector3, sz: Vector3) -> void:
	var sb = StaticBody3D.new()
	sb.position = pos
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.10, 0.09, 0.08)
	bm.surface_set_material(0, mat)
	mi.mesh = bm
	sb.add_child(mi)
	nav_region.add_child(sb)

func _build_wall(pos: Vector3, sz: Vector3, col: Color) -> void:
	var sb = StaticBody3D.new()
	sb.position = pos
	sb.add_to_group("walls")
	var mi = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = sz
	var mat = StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.90
	bm.surface_set_material(0, mat)
	mi.mesh = bm
	sb.add_child(mi)

	var c = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = sz
	c.shape = box
	sb.add_child(c)
	nav_region.add_child(sb)

func _build_prop(type_name: String, pos: Vector3, rot_y: float) -> void:
	var PrefabBuilderScript = load("res://scripts/PrefabBuilder.gd")
	if not PrefabBuilderScript:
		return
	var node = PrefabBuilderScript.build_prefab(type_name, Vector3(1, 1, 1), Color.WHITE, false, "")
	if node:
		node.position = pos
		node.rotation_degrees.y = rot_y
		if "wardrobe" in type_name or "bed" in type_name:
			node.add_to_group("hiding_spots")
		elif "door" in type_name:
			node.add_to_group("doors")
		nav_region.add_child(node)

func _add_ceiling_lamp(pos: Vector3) -> void:
	var l = OmniLight3D.new()
	l.position = pos
	l.light_color = Color(0.95, 0.85, 0.65)
	l.light_energy = 1.3
	l.omni_range = 9.0
	l.shadow_enabled = true
	add_child(l)

func _build_exit_door(pos: Vector3, rot_y: float) -> void:
	var PrefabBuilderScript = load("res://scripts/PrefabBuilder.gd")
	if not PrefabBuilderScript:
		return
	var d_node = PrefabBuilderScript.build_prefab("door_exit", Vector3(1.4, 2.4, 0.4), Color.WHITE, false, "")
	if d_node:
		d_node.name = "ExitDoor_82"
		d_node.position = pos
		d_node.rotation_degrees.y = rot_y
		d_node.set("requires_boards", true)
		d_node.set("requires_dual_keys", true)
		d_node.set("required_key_color", "dual")
		d_node.set("requires_power", false)
		d_node.set_meta("item_type", "door")
		d_node.set_meta("is_exit", true)
		d_node.add_to_group("doors")
		var pnl = d_node.find_child("Panel", true, false)
		if pnl:
			pnl.set("requires_boards", true)
			pnl.set("requires_dual_keys", true)
			pnl.set("required_key_color", "dual")
			pnl.set("requires_power", false)
			pnl.set_meta("item_type", "door")
			pnl.set_meta("is_exit", true)
		nav_region.add_child(d_node)
		exit_door_node = d_node

func _spawn_escape_quest() -> void:
	if is_instance_valid(escape_items_node):
		escape_items_node.queue_free()
	escape_items_node = Node3D.new()
	escape_items_node.name = "EscapeQuestItems"
	nav_region.add_child(escape_items_node)

	# Лом (Crowbar) — коридор (маркер 85)
	_spawn_item(Vector3(-4.5, 0.45, -15.0), "crowbar", escape_items_node)

	# Золотой ключ (Gold Key) — южная комната (маркер 84)
	_spawn_item(Vector3(7.0, 0.45, 6.5), "key_gold", escape_items_node)

	# Записка с шифром (Safe Code Note) — центральный стол
	_spawn_item(Vector3(0.0, 0.85, -2.0), "note_safe", escape_items_node)

	# Стальной сейф (Safe) — спальня рядом со шкафом
	# Внутри Серебряный ключ (Silver Key)
	_spawn_safe(Vector3(-12.0, 0.0, -13.5), 0.0, escape_items_node)

	# Сброс двери выхода
	if is_instance_valid(exit_door_node):
		exit_door_node.set("is_open", false)
		var pnl = exit_door_node.find_child("Panel", true, false)
		if pnl:
			pnl.set("is_open", false)
			pnl.rotation = Vector3.ZERO
		var hinge = exit_door_node.find_child("Hinge", true, false)
		if hinge:
			hinge.rotation = Vector3.ZERO
		var boards = exit_door_node.find_child("Boards", true, false)
		if boards:
			boards.visible = true

func _spawn_item(pos: Vector3, type: String, parent_node: Node) -> Area3D:
	var area = Area3D.new()
	area.set_script(load("res://scripts/Item.gd"))
	area.set_meta("item_type", type)
	area.position = pos
	parent_node.add_child(area)
	return area

func _spawn_safe(pos: Vector3, rot_y: float, parent_node: Node) -> Node3D:
	var PrefabBuilderScript = load("res://scripts/PrefabBuilder.gd")
	if not PrefabBuilderScript:
		return null
	var safe_node = PrefabBuilderScript.build_prefab("prop_safe", Vector3(0.9, 1.1, 0.9), Color.WHITE, false, "")
	if safe_node:
		safe_node.position = pos
		safe_node.rotation_degrees.y = rot_y
		parent_node.add_child(safe_node)
	return safe_node

func _setup_hud() -> void:
	# Игровой UI со стаминой, укрытиями, записками и инвентарем
	var ui_scene = load("res://scenes/UI.tscn")
	if ui_scene:
		game_ui = ui_scene.instantiate() as CanvasLayer
		add_child(game_ui)
		GameManager.ui_ref = game_ui

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 110
	add_child(hud_layer)

	# Хищная виньетка при игре за скинвокера
	predator_vignette = ColorRect.new()
	predator_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	predator_vignette.color = Color(0.65, 0.05, 0.05, 0.08)
	predator_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(predator_vignette)

	# Нижняя панель телеметрии
	var panel = PanelContainer.new()
	panel.anchors_preset = Control.PRESET_BOTTOM_WIDE
	panel.anchor_left = 0.0
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 20
	panel.offset_right = -20
	panel.offset_top = -68
	panel.offset_bottom = -12
	panel.custom_minimum_size = Vector2(0, 56)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.04, 0.07, 0.75)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.85, 0.35, 0.25, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", style)
	hud_layer.add_child(panel)

	status_label = RichTextLabel.new()
	status_label.bbcode_enabled = true
	status_label.scroll_active = false
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	status_label.add_theme_font_size_override("normal_font_size", 12)
	panel.add_child(status_label)

	# Верхняя правая панель: АДАПТИВНЫЙ ИИ
	brain_panel = PanelContainer.new()
	brain_panel.name = "BrainPanel"
	brain_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	brain_panel.anchor_left = 1.0
	brain_panel.anchor_top = 0.0
	brain_panel.anchor_right = 1.0
	brain_panel.anchor_bottom = 0.0
	brain_panel.offset_left = -450
	brain_panel.offset_top = 16
	brain_panel.offset_right = -16
	brain_panel.offset_bottom = 236
	brain_panel.custom_minimum_size = Vector2(434, 220)

	var b_style = StyleBoxFlat.new()
	b_style.bg_color = Color(0.02, 0.05, 0.09, 0.88)
	b_style.border_width_left = 1
	b_style.border_width_right = 1
	b_style.border_width_top = 1
	b_style.border_width_bottom = 1
	b_style.border_color = Color(0.25, 0.70, 0.95, 0.85)
	b_style.corner_radius_top_left = 8
	b_style.corner_radius_top_right = 8
	b_style.corner_radius_bottom_left = 8
	b_style.corner_radius_bottom_right = 8
	b_style.content_margin_left = 12
	b_style.content_margin_right = 12
	b_style.content_margin_top = 8
	b_style.content_margin_bottom = 8
	brain_panel.add_theme_stylebox_override("panel", b_style)
	hud_layer.add_child(brain_panel)

	brain_label = RichTextLabel.new()
	brain_label.bbcode_enabled = true
	brain_label.scroll_active = false
	brain_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brain_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	brain_label.add_theme_font_size_override("normal_font_size", 12)
	brain_panel.add_child(brain_label)

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return

	if GameManager.game_ended:
		if event.keycode == KEY_R or (current_role != 2 and event.keycode == KEY_1):
			_apply_role(current_role)
		elif event.keycode == KEY_P or (current_role != 2 and event.keycode == KEY_2):
			current_role = (current_role % 3) + 1
			_apply_role(current_role)
		return

	# Переключение ролей: [P] всегда, [2] — только когда не за Выжившего (чтобы не перехватывать быстрый слот 2)
	if event.keycode == KEY_P or (current_role != 2 and event.keycode == KEY_2):
		current_role = (current_role % 3) + 1
		_apply_role(current_role)
		return

	# Респавн бота в роли Монстра
	if current_role == 1 and event.keycode == KEY_1:
		_respawn_bot()
		return

	# В роли 2 (Выживший) клавиши 1-6 зарезервированы для быстрого инвентаря игрока!
	if current_role == 2 and event.keycode >= KEY_1 and event.keycode <= KEY_6:
		return

	if event.keycode == KEY_T:
		ai_level_preset_idx = (ai_level_preset_idx + 1) % ai_level_presets.size()
		var preset: float = ai_level_presets[ai_level_preset_idx]
		if is_instance_valid(enemy_ai_node) and enemy_ai_node.get("brain") != null:
			var b: Variant = enemy_ai_node.get("brain")
			if preset < 0.0:
				b.call("clear_intelligence_override")
			else:
				b.call("set_intelligence_override", preset)
	elif event.keycode == KEY_H:
		show_heatmap = not show_heatmap
		if heatmap_root:
			heatmap_root.visible = show_heatmap
	elif event.keycode == KEY_B:
		if is_instance_valid(enemy_ai_node) and enemy_ai_node.get("brain") != null:
			enemy_ai_node.get("brain").call("reset")
	elif event.keycode == KEY_R:
		if current_role == 1:
			_toggle_recording()
		else:
			_apply_role(current_role)
	elif event.keycode == KEY_3 and current_role != 2:
		GameManager.get_node("AIReport").save_report()

func _toggle_recording() -> void:
	is_recording = not is_recording
	if is_recording:
		recorded_samples.clear()
		total_record_time = 0.0
		time_ambushing = 0.0
		time_stalking = 0.0
		time_sprinting = 0.0
		attacks_count = 0
		flank_cutoffs_count = 0
		direct_chases_count = 0
		distractions_ignored = 0
		distractions_followed = 0
		doors_kicked = 0
		hiding_spots_checked = 0
	else:
		_save_demonstration_dataset()

func _process(delta: float) -> void:
	_clamp_active_player_bounds()

	if current_role == 1:
		if is_instance_valid(monster_player) and is_instance_valid(bot_node):
			_process_recorder(delta)
	elif current_role == 2:
		_process_role2_hud(delta)
	elif current_role == 3:
		_process_role3_hud(delta)

	_update_brain_hud(delta)
	_update_heatmap_visuals(delta)

func _clamp_active_player_bounds() -> void:
	if current_role == 1 and is_instance_valid(monster_player):
		if monster_player.global_position.y < -1.5 or abs(monster_player.global_position.x) > 22.0 or abs(monster_player.global_position.z) > 24.0:
			monster_player.global_position = enemy_spawn + Vector3(0, 0.1, 0)
			monster_player.velocity = Vector3.ZERO
	elif current_role == 2 and is_instance_valid(real_player_node):
		if real_player_node.global_position.y < -1.5 or abs(real_player_node.global_position.x) > 22.0 or abs(real_player_node.global_position.z) > 24.0:
			real_player_node.global_position = player_spawn + Vector3(0, 0.1, 0)
			real_player_node.velocity = Vector3.ZERO

func _process_recorder(delta: float) -> void:
	var m_pos = monster_player.global_position
	var b_pos = bot_node.global_position
	var dist = m_pos.distance_to(b_pos)
	var m_vel = monster_player.velocity.length()
	var has_los = _check_direct_los(m_pos, b_pos)

	# 1. Анализ реакции на потерю контакта
	if last_had_los and not has_los:
		call_deferred("_evaluate_los_reaction_after_delay", m_pos, b_pos)
	last_had_los = has_los

	# 2. Анализ реакции на отвлечение
	if tracking_distraction and (total_record_time - last_distraction_time) < 3.0:
		var dist_to_noise = m_pos.distance_to(last_distraction_pos)
		if dist_to_noise < 4.0:
			distractions_followed += 1
			tracking_distraction = false
		elif dist < 6.0 and has_los:
			distractions_ignored += 1
			tracking_distraction = false

	# 3. Атака / Захват жертвы
	if dist < 2.4 and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_just_pressed("interact")):
		current_action_name = "ЗАХВАТ ВЫЖИВШЕГО!"
		attacks_count += 1
		_play_catch_fx()
		GameManager.add_score("monster", 300, "Скинвокер поймал выжившего (+300 очков)!")
		bot_node.call("die")
	elif m_vel < 0.35 and dist < 9.0 and not has_los:
		current_action_name = "ЗАСАДА ЗА УГЛОМ (Ожидание)"
		time_ambushing += delta
	elif m_vel > 5.0:
		current_action_name = "СПРИНТ-ПОГОНЯ"
		time_sprinting += delta
	elif m_vel > 0.6:
		current_action_name = "СКРЫТНЫЙ ПОДХОД"
		time_stalking += delta
	else:
		current_action_name = "ВЫЖИДАНИЕ / ОСМОТР"

	# Взаимодействие с дверьми и шкафами на [E]
	if Input.is_action_just_pressed("interact"):
		_try_monster_interact(m_pos)

	if is_recording:
		total_record_time += delta
		sample_timer += delta
		if sample_timer >= 0.15:
			sample_timer = 0.0
			recorded_samples.append({
				"t": snapped(total_record_time, 0.01),
				"dist": snapped(dist, 0.1),
				"speed": snapped(m_vel, 0.1),
				"has_los": has_los,
				"action": current_action_name,
				"hunter_pos": [snapped(m_pos.x, 0.1), snapped(m_pos.z, 0.1)],
				"bot_pos": [snapped(b_pos.x, 0.1), snapped(b_pos.z, 0.1)],
				"bot_state": bot_node.get("state")
			})

	# Обновление HUD
	var rec_badge = "[b][color=#ff4444]● ЗАПИСЬ[/color][/b]" if is_recording else "[color=#888888]○ ПАУЗА[/color]"
	var los_str = "[color=#55ff88]ВИДИТ[/color]" if has_los else "[color=#ffaa55]СКРЫЛСЯ[/color]"
	var event_str = ""
	if event_msg_timer > 0.0:
		event_msg_timer -= delta
		event_str = " | [b][color=#ffff44]%s[/color][/b]" % last_event_msg

	var pain_warning = ""

	status_label.text = "%s [color=#88ccff]Кадров:[/color] %d (%.0f с) | [color=#ffdd66]СЧЕТ:[/color] [b]Хищник %d | Бот %d[/b] | [color=#ffdd66]Тактика:[/color] [b]%s[/b] | [color=#88ccff]Дист:[/color] %.1fм | [color=#88ccff]LOS:[/color] %s%s%s\n[color=#ffffff][Shift][/color] Спринт  [color=#ffffff][ЛКМ/E][/color] Атака  [color=#ffffff][T][/color] IQ  [color=#ffffff][H][/color] Теплокарта  [color=#ffffff][1][/color] Респавн  [color=#ffffff][2][/color] Роль  [color=#ffffff][ESC][/color] Меню" % [
		rec_badge, recorded_samples.size(), total_record_time, GameManager.monster_score, GameManager.player_score, current_action_name, dist, los_str, event_str, pain_warning
	]

func _process_role2_hud(_delta: float) -> void:
	if not status_label:
		return

	var has_crowbar = GameManager.has_crowbar
	var has_code = (GameManager.safe_code != "" and GameManager.is_reading_note) or GameManager.has_key_color("silver")
	var has_silver = GameManager.has_key_color("silver")
	var has_gold = GameManager.has_key_color("gold")
	var boards_broken = GameManager.door_boards_broken

	var c_crowbar = "[color=#55ff88][+] Лом[/color]" if has_crowbar else "[color=#aaaaaa][ ] Лом[/color]"
	var c_code    = "[color=#55ff88][+] Шифр[/color]" if has_code else "[color=#aaaaaa][ ] Шифр сейфа[/color]"
	var c_silver  = "[color=#55ff88][+] Серебряный ключ[/color]" if has_silver else "[color=#aaaaaa][ ] Сейф (Серебряный ключ)[/color]"
	var c_gold    = "[color=#55ff88][+] Золотой ключ[/color]" if has_gold else "[color=#aaaaaa][ ] Золотой ключ[/color]"
	var c_door    = "[color=#55ff88][+] Доски сорваны[/color]" if boards_broken else "[color=#aaaaaa][ ] Доски на выходе[/color]"

	var dist_to_ai = 99.0
	if is_instance_valid(enemy_ai_node) and is_instance_valid(real_player_node):
		dist_to_ai = real_player_node.global_position.distance_to(enemy_ai_node.global_position)

	var pain_warning = ""

	status_label.text = "[color=#55ff88]ВЫ = ВЫЖИВШИЙ ПРОТИВ УМНОГО ИИ[/color] | [color=#ffdd66]СЧЕТ:[/color] [b]Вы %d | Скинвокер %d[/b] | [color=#88ccff]Враг:[/color] %.1fм%s\n[color=#ffdd88]Квест:[/color] %s | %s | %s | %s | %s\n[color=#ffffff][WASD][/color] Бег  [color=#ffffff][Shift][/color] Спринт  [color=#ffffff][1-6/Колесо][/color] Слоты  [color=#ffffff][Tab][/color] Рюкзак  [color=#ffffff][E][/color] Действие  [color=#ffffff][T][/color] IQ  [color=#ffffff][H][/color] Теплокарта  [color=#ffffff][P][/color] Роль  [color=#ffffff][R][/color] Респавн  [color=#ffffff][ESC][/color] Меню" % [
		GameManager.player_score, GameManager.monster_score, dist_to_ai, pain_warning,
		c_crowbar, c_code, c_silver, c_gold, c_door
	]

func _process_role3_hud(_delta: float) -> void:
	if not status_label:
		return
	var dist = 0.0
	if is_instance_valid(enemy_ai_node) and is_instance_valid(bot_node):
		dist = enemy_ai_node.global_position.distance_to(bot_node.global_position)
	status_label.text = "[color=#55aaff]АВТО-ТЕСТ (ИИ против Бота)[/color] | [color=#ffdd66]СЧЕТ:[/color] [b]Выживший %d | Скинвокер %d[/b] | Дистанция: %.1fм\n[color=#ffffff][T][/color] Симуляция IQ   [color=#ffffff][H][/color] Теплокарта 3D   [color=#ffffff][B][/color] Сброс мозга   [color=#ffffff][1][/color] Респавн   [color=#ffffff][2][/color] Сменить роль   [color=#ffffff][ESC][/color] Меню" % [
		GameManager.player_score, GameManager.monster_score, dist
	]

func _update_brain_hud(_delta: float) -> void:
	if not is_instance_valid(brain_label):
		return

	var brain: Variant = null
	var enemy_node: Node = null
	if is_instance_valid(enemy_ai_node):
		enemy_node = enemy_ai_node
		brain = enemy_ai_node.get("brain")

	if current_role == 1:
		brain_label.text = "[b][color=#ff4444]РЕЖИМ: ВЫ — СКИНВОКЕР[/color][/b]\n[color=#aaaaaa]Вы охотитесь на бота-выжившего.[/color]\n\n[color=#ffdd66]Тестирование умного ИИ:[/color]\nНажмите [b][color=#55ff88][2][/color][/b] — [b]Выживший против ИИ Скинвокера[/b]\nИли ещё раз [b][color=#55ff88][2][/color][/b] — [b]Авто-тест (наблюдение сверху)[/b]"
		return

	if not is_instance_valid(enemy_node) or brain == null:
		brain_label.text = "[b][color=#ff8844]АДАПТИВНЫЙ ИИ СКИНВОКЕРА[/color][/b]\n[color=#888888]Ожидание появления монстра...[/color]"
		return

	var stats: Dictionary = brain.call("get_stats")
	var iq: float = float(stats.get("intelligence", 0.0))
	var iq_pct: float = float(stats.get("intelligence_pct", 0.0))
	var thought: String = ""
	if enemy_node.has_method("get_ai_thought"):
		thought = enemy_node.call("get_ai_thought")
	else:
		thought = str(enemy_node.get("ai_thought"))

	var preset_name := "Авто (60м)"
	var current_preset: float = ai_level_presets[ai_level_preset_idx]
	if current_preset >= 0.0:
		preset_name = "Фикс: %d%%" % int(current_preset * 100.0)

	var total_bars := 12
	var filled_bars := int(round(iq * total_bars))
	var bar_str := ""
	for i in range(total_bars):
		if i < filled_bars:
			bar_str += "█"
		else:
			bar_str += "░"

	var stage_desc := ""
	if iq < 0.20:
		stage_desc = "[color=#88ccff]Базовый хищник (изучает особняк)[/color]"
	elif iq < 0.45:
		stage_desc = "[color=#ffdd66]Охотник (запоминает частые маршруты)[/color]"
	elif iq < 0.75:
		stage_desc = "[color=#ff9944]Опытный (проверяет шкафы, патрулирует частые зоны)[/color]"
	else:
		stage_desc = "[color=#ff3333][b]СВЕРХРАЗУМ (Засады, срезает углы, антиманка!)[/b][/color]"

	var tactic_str := "Патрулирование"
	if stats.get("shortcut_active", false):
		tactic_str = "[color=#55ffff][b]СРЕЗАНИЕ ПУТИ / ФЛАНК![/b][/color]"
	elif stats.get("is_ambushing", false):
		tactic_str = "[color=#ff44aa][b]ЗАСАДА В ГОРЯЧЕЙ ЗОНЕ![/b][/color]"
	elif enemy_node.get("state") == 3: # HUNT
		tactic_str = "[color=#ff4444]Погоня с прогнозом вектора бега[/color]"
	elif enemy_node.get("state") == 4: # SEARCH
		tactic_str = "[color=#ffaa55]Обыск с приоритетом шкафов и частых зон[/color]"

	var hm_status = "[color=#55ff88]ВКЛ[/color]" if show_heatmap else "[color=#888888]ВЫКЛ[/color]"

	brain_label.text = "[b][color=#ff4444]АДАПТИВНЫЙ ИИ СКИНВОКЕРА[/color][/b]  [color=#88ccff][b][%s][/b] %.1f%%[/color]\n%s\n[color=#ffff77]Мысль:[/color] %s\n[color=#88ccff]Горячих зон:[/color] %d  |  [color=#ff88ff]Шкафов раскрыто:[/color] %d (поймано %d)\n[color=#ffcc66]Скептицизм к уловкам:[/color] %.0f%% (Ложных: %d / Реальных: %d)\n[color=#88ffaa]Тактика:[/color] %s\n[color=#556677]──────────────────────────────────────────────[/color]\n[color=#ffffff][T][/color] Симуляция IQ: [b]%s[/b]  |  [color=#ffffff][H][/color] Теплокарта 3D: %s  |  [color=#ffffff][B][/color] Сброс" % [
		bar_str, iq_pct, stage_desc, thought,
		int(stats.get("hot_zones", 0)),
		int(stats.get("hiding_spots_remembered", 0)),
		int(stats.get("total_catches_at_hiding", 0)),
		float(stats.get("skepticism_pct", 0.0)),
		int(stats.get("decoys_detected", 0)),
		int(stats.get("real_noises", 0)),
		tactic_str,
		preset_name,
		hm_status
	]

func _update_heatmap_visuals(delta: float) -> void:
	if not heatmap_root:
		return
	heatmap_root.visible = show_heatmap
	if not show_heatmap:
		return
	heatmap_timer += delta
	if heatmap_timer < 0.35:
		return
	heatmap_timer = 0.0

	var brain: Variant = null
	if is_instance_valid(enemy_ai_node):
		brain = enemy_ai_node.get("brain")

	for child in heatmap_root.get_children():
		child.queue_free()

	if brain == null:
		return

	# 1. Тепловая карта ячеек на полу
	var data: Array = brain.call("get_heat_map_data")
	for item in data:
		var pos: Vector3 = item.pos
		var intensity: float = float(item.intensity)
		var marker = MeshInstance3D.new()
		var plane = BoxMesh.new()
		plane.size = Vector3(1.8, 0.02, 1.8)
		marker.mesh = plane

		var mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if intensity < 0.5:
			mat.albedo_color = Color(0.1, 0.8, 0.4, 0.22).lerp(Color(1.0, 0.85, 0.1, 0.42), intensity * 2.0)
		else:
			mat.albedo_color = Color(1.0, 0.85, 0.1, 0.42).lerp(Color(1.0, 0.12, 0.12, 0.65), (intensity - 0.5) * 2.0)
		marker.material_override = mat
		marker.position = pos
		heatmap_root.add_child(marker)

	# 2. Метки запомненных укрытий (где скинвокер ловил игрока)
	var caught_spots: Array = brain.get("caught_hiding_spots")
	for entry in caught_spots:
		var spos: Vector3 = entry.get("position", Vector3.ZERO)
		var catches: int = int(entry.get("catches", 1))
		var spot_marker = MeshInstance3D.new()
		var cylinder = CylinderMesh.new()
		cylinder.top_radius = 0.55
		cylinder.bottom_radius = 0.55
		cylinder.height = 2.0
		spot_marker.mesh = cylinder
		var smat = StandardMaterial3D.new()
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.albedo_color = Color(0.95, 0.1, 0.75, 0.35)
		spot_marker.material_override = smat
		spot_marker.position = spos + Vector3(0, 1.0, 0)
		heatmap_root.add_child(spot_marker)

		var lbl = Label3D.new()
		lbl.text = "ЗАСВЕЧЕНО: ПОЙМАЛ x%d" % catches
		lbl.font_size = 26
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.modulate = Color(1.0, 0.35, 0.9)
		lbl.outline_modulate = Color(0, 0, 0, 1)
		lbl.outline_size = 4
		lbl.position = spos + Vector3(0, 2.3, 0)
		heatmap_root.add_child(lbl)

	# 3. Метка среза пути / фланкирования (shortcut target)
	if brain.get("shortcut_active") == true:
		var target: Vector3 = brain.get("shortcut_target")
		var fl_marker = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.8, 1.6, 0.8)
		fl_marker.mesh = box
		var fmat = StandardMaterial3D.new()
		fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fmat.albedo_color = Color(0.1, 0.95, 1.0, 0.55)
		fl_marker.material_override = fmat
		fl_marker.position = target + Vector3(0, 0.8, 0)
		heatmap_root.add_child(fl_marker)

		var fl_lbl = Label3D.new()
		fl_lbl.text = "ПЕРЕХВАТ НАПЕРЕРЕЗ!"
		fl_lbl.font_size = 30
		fl_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		fl_lbl.modulate = Color(0.2, 1.0, 1.0)
		fl_lbl.outline_modulate = Color(0, 0, 0, 1)
		fl_lbl.outline_size = 5
		fl_lbl.position = target + Vector3(0, 1.9, 0)
		heatmap_root.add_child(fl_lbl)

func _evaluate_los_reaction_after_delay(last_hunter_pos: Vector3, last_bot_pos: Vector3) -> void:
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(monster_player) or not is_instance_valid(bot_node):
		return
	var cur_m_pos = monster_player.global_position
	var move_vec = (cur_m_pos - last_hunter_pos).normalized()
	var direct_to_last = (last_bot_pos - last_hunter_pos).normalized()

	var dot = move_vec.dot(direct_to_last)
	if dot < 0.70 and monster_player.velocity.length() > 2.0:
		flank_cutoffs_count += 1
	else:
		direct_chases_count += 1

func _try_monster_interact(m_pos: Vector3) -> void:
	var doors = get_tree().get_nodes_in_group("doors")
	for d in doors:
		if is_instance_valid(d) and d is Node3D:
			if m_pos.distance_to(d.global_position) < 2.5:
				if d.has_method("interact"):
					d.call("interact")
					doors_kicked += 1
					return

	var spots = get_tree().get_nodes_in_group("hiding_spots")
	for s in spots:
		if is_instance_valid(s) and s is Node3D:
			if m_pos.distance_to(s.global_position) < 2.6:
				hiding_spots_checked += 1
				if bot_node and bot_node.get("is_hiding") and bot_node.get("current_hiding_spot") == s:
					bot_node.call("die")
					attacks_count += 1
					GameManager.add_score("monster", 300, "Скинвокер поймал выжившего в укрытии (+300 очков)!")
					_play_catch_fx()
					return

func _play_catch_fx() -> void:
	var sound_path = "res://assets/scream.mp3"
	if not ResourceLoader.exists(sound_path):
		sound_path = "res://assets/audio/skinwalker_scream.wav"
	if ResourceLoader.exists(sound_path):
		var p = AudioStreamPlayer.new()
		p.stream = load(sound_path)
		p.volume_db = 0.0
		add_child(p)
		p.play()
		p.finished.connect(func(): p.queue_free())

func _check_direct_los(from: Vector3, to: Vector3) -> bool:
	var space = get_world_3d().direct_space_state
	var p1 = from + Vector3(0, 1.2, 0)
	var p2 = to + Vector3(0, 1.2, 0)
	var exc: Array[RID] = []
	if monster_player: exc.append(monster_player.get_rid())
	if bot_node: exc.append(bot_node.get_rid())
	var q = PhysicsRayQueryParameters3D.create(p1, p2, 1, exc)
	var hit = space.intersect_ray(q)
	return hit.is_empty()

# ── Обработчики сигналов уловок бота ──
func _on_bot_thrown_bottle(pos: Vector3, landing_pos: Vector3) -> void:
	last_distraction_time = total_record_time
	last_distraction_pos = landing_pos
	tracking_distraction = true
	last_event_msg = "Выживший бросил бутылку-приманку!"
	event_msg_timer = 2.5

func _on_bot_slammed_door(door_node: Node) -> void:
	last_event_msg = "Выживший захлопнул дверь перед вами!"
	event_msg_timer = 2.5

func _on_bot_juked() -> void:
	last_event_msg = "Выживший сделал резкий Corner Juke обман!"
	event_msg_timer = 2.5

func _on_bot_burst_out() -> void:
	last_event_msg = "Выживший вырвался из укрытия на спринте!"
	event_msg_timer = 2.5

func _on_bot_hid(spot: Node3D) -> void:
	last_event_msg = "Выживший спрятался в укрытие!"
	event_msg_timer = 2.5

func _connect_bot_signals() -> void:
	if not is_instance_valid(bot_node):
		return
	if bot_node.has_signal("survivor_thrown_bottle") and not bot_node.survivor_thrown_bottle.is_connected(_on_bot_thrown_bottle):
		bot_node.survivor_thrown_bottle.connect(_on_bot_thrown_bottle)
	if bot_node.has_signal("survivor_slammed_door") and not bot_node.survivor_slammed_door.is_connected(_on_bot_slammed_door):
		bot_node.survivor_slammed_door.connect(_on_bot_slammed_door)
	if bot_node.has_signal("survivor_juked") and not bot_node.survivor_juked.is_connected(_on_bot_juked):
		bot_node.survivor_juked.connect(_on_bot_juked)
	if bot_node.has_signal("survivor_burst_out") and not bot_node.survivor_burst_out.is_connected(_on_bot_burst_out):
		bot_node.survivor_burst_out.connect(_on_bot_burst_out)
	if bot_node.has_signal("survivor_hid") and not bot_node.survivor_hid.is_connected(_on_bot_hid):
		bot_node.survivor_hid.connect(_on_bot_hid)

# ── Сохранение записи сессии ──
func _build_demonstration_profile() -> Dictionary:
	var total_time = max(1.0, total_record_time)
	var amb_pct = (time_ambushing / total_time) * 100.0
	var spr_pct = (time_sprinting / total_time) * 100.0
	var stl_pct = (time_stalking / total_time) * 100.0

	var total_los_events = max(1, flank_cutoffs_count + direct_chases_count)
	var flank_ratio = float(flank_cutoffs_count) / float(total_los_events)

	var total_distr = max(1, distractions_ignored + distractions_followed)
	var skepticism = float(distractions_ignored) / float(total_distr)

	var ambush_wait = snapped(clamp(time_ambushing * 0.35 + 2.0, 2.0, 5.5), 0.1)
	var chase_speed_mult = 1.12 if spr_pct > 30.0 else 0.95
	var wardrobe_chance = 0.85 if hiding_spots_checked > 0 else 0.50

	var profile = {
		"version": "2.0",
		"is_primary_ai": false,
		"affects_gameplay_ai": false,
		"author": "Player Demonstration",
		"description": "Запись сессии полигона для просмотра. Поведение основного ИИ фиксировано и не меняется.",
		"timestamp": Time.get_datetime_string_from_system(),
		"tactics": {
			"flank_cutoff_bias": snapped(flank_ratio, 0.05),
			"distraction_skepticism": snapped(skepticism, 0.05),
			"wardrobe_check_chance": snapped(wardrobe_chance, 0.05),
			"ambush_wait_time": ambush_wait,
			"chase_aggression": snapped(chase_speed_mult, 0.05)
		},
		"learned_ai_parameters": {
			"preferred_ambush_wait_time": ambush_wait,
			"stalk_distance_before_pounce": 5.2,
			"recommended_chase_speed_mult": snapped(chase_speed_mult, 0.05),
			"flank_cutoff_bias": snapped(flank_ratio, 0.05),
			"distraction_skepticism": snapped(skepticism, 0.05),
			"wardrobe_check_chance": snapped(wardrobe_chance, 0.05)
		},
		"training_summary": {
			"total_time_seconds": snapped(total_record_time, 0.1),
			"total_samples": recorded_samples.size(),
			"ambush_percent": snapped(amb_pct, 1.0),
			"stalking_percent": snapped(stl_pct, 1.0),
			"sprint_percent": snapped(spr_pct, 1.0),
			"attacks_count": attacks_count,
			"flank_cutoffs": flank_cutoffs_count,
			"doors_kicked": doors_kicked,
			"hiding_checked": hiding_spots_checked
		},
		"samples": recorded_samples
	}

	return profile

func _save_demonstration_dataset() -> void:
	var profile: Dictionary = _build_demonstration_profile()
	var json_str = JSON.stringify(profile, "\t")

	var f3 = FileAccess.open(SAVE_RECORDING_PATH, FileAccess.WRITE)
	if f3:
		f3.store_string(json_str)
		f3.close()

	print("Запись полигона сохранена. Настройки основного ИИ не изменены.")
	if status_label:
		status_label.text = "[color=#55ff88]Запись сохранена. ИИ игры защищён от изменений через полигон.[/color]\n[color=#ffffff][1][/color] Респавн   [color=#ffffff][2][/color] Проверить ИИ   [color=#ffffff][ESC][/color] Меню"

# ── Обработка поимки игрока в роли Выжившего (Режим 2) ──
func _on_game_over() -> void:
	if current_role == 2:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_play_catch_fx()
		_show_role2_death_overlay()

func _on_game_won() -> void:
	if current_role == 2:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_show_role2_victory_overlay()

func _show_role2_victory_overlay() -> void:
	if is_instance_valid(death_overlay_ui):
		death_overlay_ui.queue_free()

	death_overlay_ui = Control.new()
	death_overlay_ui.name = "Role2VictoryOverlay"
	death_overlay_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(death_overlay_ui)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.01, 0.05, 0.02, 0.94)
	death_overlay_ui.add_child(bg)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.custom_minimum_size = Vector2(520, 320)
	vb.add_theme_constant_override("separation", 14)
	death_overlay_ui.add_child(vb)

	var title = Label.new()
	title.text = "ПОБЕГ УСПЕШЕН!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.2, 0.95, 0.35))
	vb.add_child(title)

	var sub = Label.new()
	sub.text = "Вы собрали шифр, открыли сейф, нашли оба ключа и вырвались из особняка!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.85, 0.95, 0.85))
	vb.add_child(sub)

	var score_lbl = Label.new()
	score_lbl.text = "Итоговый счёт выжившего: %d очков | Счёт Скинвокера: %d очков" % [GameManager.player_score, GameManager.monster_score]
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 18)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vb.add_child(score_lbl)

	var btn_retry = Button.new()
	btn_retry.text = "СЫГРАТЬ ЕЩЕ РАЗ [R / 1]"
	btn_retry.custom_minimum_size = Vector2(280, 42)
	btn_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_retry.pressed.connect(func(): _apply_role(2))
	vb.add_child(btn_retry)

	var btn_monster = Button.new()
	btn_monster.text = "СТАТЬ СКИНВОКЕРОМ [2]"
	btn_monster.custom_minimum_size = Vector2(280, 42)
	btn_monster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_monster.pressed.connect(func(): _apply_role(1))
	vb.add_child(btn_monster)

	var btn_menu = Button.new()
	btn_menu.text = "В ГЛАВНОЕ МЕНЮ [ESC]"
	btn_menu.custom_minimum_size = Vector2(280, 42)
	btn_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	vb.add_child(btn_menu)

func _show_role2_death_overlay() -> void:
	if is_instance_valid(death_overlay_ui):
		death_overlay_ui.queue_free()

	death_overlay_ui = Control.new()
	death_overlay_ui.name = "Role2DeathOverlay"
	death_overlay_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(death_overlay_ui)

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.01, 0.01, 0.94)
	death_overlay_ui.add_child(bg)

	var vb = VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.custom_minimum_size = Vector2(480, 300)
	vb.add_theme_constant_override("separation", 14)
	death_overlay_ui.add_child(vb)

	var title = Label.new()
	title.text = "ВАС НАСТИГ СКИНВОКЕР"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(0.95, 0.15, 0.15))
	vb.add_child(title)

	var sub = Label.new()
	sub.text = "ИИ перенял повадки охотника и поймал вас в особняке!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	vb.add_child(sub)

	var score_lbl = Label.new()
	score_lbl.text = "Счёт выжившего: %d | Счёт Скинвокера: %d" % [GameManager.player_score, GameManager.monster_score]
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_lbl.add_theme_font_size_override("font_size", 16)
	score_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
	vb.add_child(score_lbl)

	var btn_retry = Button.new()
	btn_retry.text = "НАЧАТЬ ЗАНОВО [R / 1]"
	btn_retry.custom_minimum_size = Vector2(280, 42)
	btn_retry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_retry.pressed.connect(func(): _apply_role(2))
	vb.add_child(btn_retry)

	var btn_monster = Button.new()
	btn_monster.text = "СТАТЬ СКИНВОКЕРОМ [2]"
	btn_monster.custom_minimum_size = Vector2(280, 42)
	btn_monster.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_monster.pressed.connect(func(): _apply_role(1))
	vb.add_child(btn_monster)

	var btn_menu = Button.new()
	btn_menu.text = "В ГЛАВНОЕ МЕНЮ [ESC]"
	btn_menu.custom_minimum_size = Vector2(280, 42)
	btn_menu.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn_menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	vb.add_child(btn_menu)

# ── Переключение ролей ──
func _apply_role(role: int) -> void:
	current_role = role
	GameManager.reset_state()
	GameManager.generate_new_safe_code()
	_spawn_escape_quest()

	if is_instance_valid(death_overlay_ui):
		death_overlay_ui.queue_free()
		death_overlay_ui = null
	if is_instance_valid(bot_node):
		bot_node.queue_free()
		bot_node = null
	if is_instance_valid(monster_player):
		monster_player.queue_free()
		monster_player = null
	if is_instance_valid(real_player_node):
		real_player_node.queue_free()
		real_player_node = null
	if is_instance_valid(enemy_ai_node):
		enemy_ai_node.queue_free()
		enemy_ai_node = null
	if is_instance_valid(free_camera_node):
		free_camera_node.queue_free()
		free_camera_node = null
	if is_instance_valid(heatmap_root):
		for child in heatmap_root.get_children():
			child.queue_free()

	if role == 1:
		# Режим 1: Игрок = Скинвокер (Наблюдение)
		if is_instance_valid(game_ui):
			game_ui.visible = false
		GameManager.ui_ref = null
		if we_resource:
			we_resource.ambient_light_energy = 1.6
			we_resource.ambient_light_color = Color(0.24, 0.28, 0.36)
		if predator_vignette:
			predator_vignette.visible = true
		_spawn_monster_player(enemy_spawn)
		_spawn_survivor_bot(player_spawn)
		is_recording = true
		recorded_samples.clear()
		total_record_time = 0.0
		monster_idle_timer = 0.0
		monster_last_pos = enemy_spawn
	elif role == 2:
		# Режим 2: Игрок = Выживший (Побег)
		if is_instance_valid(game_ui):
			game_ui.visible = true
			GameManager.ui_ref = game_ui
		if we_resource:
			we_resource.ambient_light_energy = 0.55
			we_resource.ambient_light_color = Color(0.12, 0.14, 0.18)
		if predator_vignette:
			predator_vignette.visible = false
		_spawn_player_real(player_spawn)
		_spawn_enemy_ai(enemy_spawn)
	elif role == 3:
		# Режим 3: Авто-тест (Свободная камера сверху)
		if is_instance_valid(game_ui):
			game_ui.visible = false
		GameManager.ui_ref = null
		if we_resource:
			we_resource.ambient_light_energy = 1.2
			we_resource.ambient_light_color = Color(0.18, 0.20, 0.25)
		if predator_vignette:
			predator_vignette.visible = false
		_spawn_free_camera(Vector3(-0.5, 18.0, -3.5))
		_spawn_survivor_bot(player_spawn)
		_spawn_enemy_ai(enemy_spawn)

	# Применяем выбранный пресет симуляции интеллекта
	if is_instance_valid(enemy_ai_node) and enemy_ai_node.get("brain") != null:
		var preset: float = ai_level_presets[ai_level_preset_idx]
		if preset >= 0.0:
			enemy_ai_node.get("brain").call("set_intelligence_override", preset)

func _spawn_monster_player(pos: Vector3) -> void:
	var pl_scene = load("res://scenes/Player.tscn")
	if pl_scene:
		monster_player = pl_scene.instantiate() as CharacterBody3D
	else:
		monster_player = CharacterBody3D.new()
		monster_player.set_script(load("res://scripts/Player.gd"))

	monster_player.name = "MonsterPlayer"
	monster_player.position = pos
	add_child(monster_player)
	GameManager.enemy_ref = monster_player

	# ── ХИЩНОЕ НОЧНОЕ ЗРЕНИЕ СКИНВОКЕРА (Predatory Night Vision) ──
	var cam = monster_player.get_node_or_null("Head/Camera3D")
	if not cam:
		cam = monster_player.find_child("Camera3D", true, false)
	if cam:
		var nv_omni = OmniLight3D.new()
		nv_omni.name = "PredatorNightVision"
		nv_omni.light_color = Color(0.86, 0.93, 1.0)
		nv_omni.light_energy = 2.2
		nv_omni.omni_range = 45.0
		nv_omni.omni_attenuation = 0.45
		nv_omni.shadow_enabled = false
		cam.add_child(nv_omni)

		var nv_spot = SpotLight3D.new()
		nv_spot.name = "PredatorSpotVision"
		nv_spot.light_color = Color(0.92, 0.96, 1.0)
		nv_spot.light_energy = 1.8
		nv_spot.spot_range = 55.0
		nv_spot.spot_angle = 65.0
		nv_spot.spot_angle_attenuation = 0.65
		nv_spot.shadow_enabled = false
		cam.add_child(nv_spot)

	# Скрываем человеческое тело
	var human_body = monster_player.get_node_or_null("PlayerBody3D")
	if not human_body:
		human_body = monster_player.find_child("PlayerBody3D", true, false)
	if human_body:
		human_body.visible = false
		human_body.queue_free()

	# Скрываем руки человека у монстра
	var hands = monster_player.get_node_or_null("Head/Camera3D/PlayerHands")
	if not hands and cam:
		hands = cam.get_node_or_null("PlayerHands")
	if hands:
		hands.visible = false
		hands.queue_free()

	# Модель / Спрайт Скинвокера для вида со стороны и зеркал
	var m_sprite = Sprite3D.new()
	m_sprite.name = "MonsterSprite"
	if ResourceLoader.exists("res://assets/textures/enemy_character/monster_front.png"):
		m_sprite.texture = load("res://assets/textures/enemy_character/monster_front.png")
	m_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	m_sprite.pixel_size = 0.0026
	m_sprite.position = Vector3(0, 1.15, 0)
	m_sprite.shaded = true
	m_sprite.double_sided = true
	m_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	monster_player.add_child(m_sprite)

	# Когтистые лапы Скинвокера от 1-го лица с анимацией замаха [ЛКМ]/[E]
	if cam:
		var claws_script = load("res://scripts/MonsterClaws.gd")
		if claws_script:
			var claws = Node3D.new()
			claws.set_script(claws_script)
			claws.name = "MonsterClaws"
			cam.add_child(claws)
			claws.call("setup", monster_player)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _spawn_survivor_bot(pos: Vector3) -> void:
	var bot_script = load("res://scripts/SurvivorBot.gd")
	bot_node = CharacterBody3D.new()
	bot_node.name = "SurvivorBot"
	bot_node.position = pos
	bot_node.set_script(bot_script)
	add_child(bot_node)
	bot_node.call("set_waypoints", bot_waypoints)
	_connect_bot_signals()
	GameManager.player_ref = bot_node

func _spawn_player_real(pos: Vector3) -> void:
	var pl_scene = load("res://scenes/Player.tscn")
	if pl_scene:
		real_player_node = pl_scene.instantiate() as CharacterBody3D
		real_player_node.position = pos
		add_child(real_player_node)
		GameManager.player_ref = real_player_node
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _spawn_enemy_ai(pos: Vector3) -> void:
	var en_scene = load("res://scenes/Enemy.tscn")
	if en_scene:
		enemy_ai_node = en_scene.instantiate() as CharacterBody3D
		enemy_ai_node.position = pos
		add_child(enemy_ai_node)
		GameManager.enemy_ref = enemy_ai_node

func _spawn_free_camera(pos: Vector3) -> void:
	free_camera_node = Camera3D.new()
	free_camera_node.name = "FreeCamera"
	free_camera_node.position = pos
	free_camera_node.rotation_degrees = Vector3(-88, 0, 0)
	free_camera_node.current = true
	add_child(free_camera_node)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _respawn_bot() -> void:
	if is_instance_valid(bot_node):
		if bot_waypoints.size() > 0:
			bot_node.global_position = bot_waypoints[randi() % bot_waypoints.size()]
		else:
			bot_node.global_position = player_spawn

func _exit_tree() -> void:
	get_window().theme = null
