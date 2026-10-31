class_name Minimap
extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
#  Minimap.gd — 2D Тактический радар / миникарта дома и полигона [Кнопка M]
#  • Отображает стены, перегородки и контур дома/арены
#  • Зеленая точка + стрелка: Игрок
#  • Красная точка + конус зрения: Скинвокер
#  • Оранжевая линия: траектория движения passai в реальном времени
#  • Желтые сегменты: Двери (зеленые — открыты, красные — заперты)
#  • Синие квадраты: Шкафы и кровати
# ══════════════════════════════════════════════════════════════════════════════

var is_minimap_visible: bool = false

var map_panel: PanelContainer
var radar_canvas: Control
var header_label: Label

# Настройки масштаба карты
# 1 метр в 3D = map_scale пикселей на 2D радаре
var map_scale: float = 6.8
var map_center: Vector2 = Vector2(120, 120)
var radar_size: Vector2 = Vector2(240, 240)

func _init() -> void:
	layer = 115

func _ready() -> void:
	_build_ui()
	visible = false

func _build_ui() -> void:
	map_panel = PanelContainer.new()
	map_panel.name = "MinimapPanel"
	map_panel.anchors_preset = Control.PRESET_TOP_RIGHT
	map_panel.anchor_left = 1.0
	map_panel.anchor_top = 0.0
	map_panel.anchor_right = 1.0
	map_panel.anchor_bottom = 0.0
	map_panel.offset_left = -266
	map_panel.offset_top = 16
	map_panel.offset_right = -16
	map_panel.offset_bottom = 300
	map_panel.custom_minimum_size = Vector2(250, 280)

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.03, 0.05, 0.08, 0.72)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.25, 0.45, 0.75, 0.75)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 8
	panel_style.shadow_color = Color(0, 0, 0, 0.5)
	panel_style.shadow_size = 10
	map_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(map_panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	map_panel.add_child(vb)

	header_label = Label.new()
	header_label.text = "ТАКТИЧЕСКИЙ РАДАР [M]"
	header_label.add_theme_font_size_override("font_size", 11)
	header_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(header_label)

	radar_canvas = Control.new()
	radar_canvas.custom_minimum_size = radar_size
	radar_canvas.draw.connect(_on_radar_draw)
	vb.add_child(radar_canvas)

	var legend = Label.new()
	legend.text = "Зеленый: Игрок   Красный: Монстр   Желтый: Двери   Синий: Шкаф"
	legend.add_theme_font_size_override("font_size", 9)
	legend.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(legend)

func toggle_minimap() -> void:
	is_minimap_visible = !is_minimap_visible
	visible = is_minimap_visible
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		var s = "ВКЛЮЧЕНА" if is_minimap_visible else "ОТКЛЮЧЕНА"
		GameManager.ui_ref.call("show_hint", "2D Миникарта: %s [M]" % s, 1.5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			# Не перехватываем, если открыта консоль разработчика
			if GameManager.dev_console and GameManager.dev_console.get("is_open") == true:
				return
			toggle_minimap()
			get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if is_minimap_visible and radar_canvas:
		radar_canvas.queue_redraw()

func _world_to_map(w_pos: Vector3) -> Vector2:
	# Координаты X -> вправо, Z -> вниз по экрану
	return map_center + Vector2(w_pos.x * map_scale, w_pos.z * map_scale)

func _on_radar_draw() -> void:
	var canvas = radar_canvas
	# Фоновая сетка радара
	canvas.draw_rect(Rect2(Vector2.ZERO, radar_size), Color(0.02, 0.03, 0.05, 0.90), true)
	canvas.draw_rect(Rect2(Vector2.ZERO, radar_size), Color(0.2, 0.35, 0.55, 0.8), false, 1.5)

	# Кольца дальности радара
	for r in [40.0, 80.0, 115.0]:
		canvas.draw_arc(map_center, r, 0, TAU, 32, Color(0.15, 0.25, 0.40, 0.45), 1.0)

	# Осевые линии (N, S, W, E)
	canvas.draw_line(Vector2(map_center.x, 5), Vector2(map_center.x, radar_size.y - 5), Color(0.15, 0.25, 0.40, 0.35), 1.0)
	canvas.draw_line(Vector2(5, map_center.y), Vector2(radar_size.x - 5, map_center.y), Color(0.15, 0.25, 0.40, 0.35), 1.0)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(map_center.x - 4, 14), "N", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(0.4, 0.6, 0.8, 0.7))

	# 1. Стены и перегородки комнат
	var walls = get_tree().get_nodes_in_group("walls")
	for w in walls:
		if is_instance_valid(w) and w is Node3D:
			var w3d = w as Node3D
			var m_pos = _world_to_map(w3d.global_position)
			var w_sz = Vector2(2.0, 0.3) * map_scale
			if w3d.rotation.y != 0.0:
				w_sz = Vector2(w_sz.y, w_sz.x)
			canvas.draw_rect(Rect2(m_pos - w_sz * 0.5, w_sz), Color(0.40, 0.50, 0.65, 0.75), true)

	# 2. Укрытия (Шкафы и кровати - синие маркеры)
	var hidings = get_tree().get_nodes_in_group("hiding_spots")
	for h in hidings:
		if is_instance_valid(h) and h is Node3D:
			var h_pos = _world_to_map((h as Node3D).global_position)
			canvas.draw_rect(Rect2(h_pos - Vector2(4, 4), Vector2(8, 8)), Color(0.2, 0.6, 1.0, 0.9), true)
			canvas.draw_rect(Rect2(h_pos - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 1.0, 1.0, 0.8), false, 1.0)

	# 3. Двери
	var doors = get_tree().get_nodes_in_group("doors")
	for d in doors:
		if is_instance_valid(d) and d is Node3D:
			var d3d = d as Node3D
			var d_pos = _world_to_map(d3d.global_position)
			var is_open = d.get("is_open") == true
			var d_col = Color(0.3, 0.9, 0.4, 0.9) if is_open else Color(0.95, 0.85, 0.2, 0.9)
			canvas.draw_line(d_pos - Vector2(5, 0), d_pos + Vector2(5, 0), d_col, 3.0)

	# 4. Траектория пути passai Скинвокера
	if GameManager.enemy_ref and is_instance_valid(GameManager.enemy_ref):
		var enemy = GameManager.enemy_ref
		var path = enemy.call("get_debug_navigation_path") if enemy.has_method("get_debug_navigation_path") else PackedVector3Array()
		if path.size() >= 2:
			var pts: PackedVector2Array = []
			for p in path:
				pts.append(_world_to_map(p))
			var path_col = Color(1.0, 0.55, 0.15, 0.85)
			if enemy.get("state") == 3:
				path_col = Color(1.0, 0.2, 0.2, 0.90)
			for i in range(pts.size() - 1):
				canvas.draw_line(pts[i], pts[i+1], path_col, 2.0)
				canvas.draw_circle(pts[i], 2.5, path_col)
			if not pts.is_empty():
				canvas.draw_circle(pts[pts.size() - 1], 4.0, Color(1.0, 1.0, 0.3, 0.95))

	# 5. Скинвокер (Красный маркер + конус зрения)
	if GameManager.enemy_ref and is_instance_valid(GameManager.enemy_ref):
		var enemy = GameManager.enemy_ref
		var e_pos = _world_to_map(enemy.global_position)
		var e_yaw = enemy.rotation.y

		# Конус зрения (85 градусов)
		var view_dist = 45.0
		var fov_half = deg_to_rad(42.5)
		var dir_main = Vector2(-sin(e_yaw), -cos(e_yaw))
		var dir_l = Vector2(-sin(e_yaw - fov_half), -cos(e_yaw - fov_half))
		var dir_r = Vector2(-sin(e_yaw + fov_half), -cos(e_yaw + fov_half))

		var cone_pts = PackedVector2Array([
			e_pos,
			e_pos + dir_l * view_dist,
			e_pos + dir_main * (view_dist * 1.08),
			e_pos + dir_r * view_dist
		])
		canvas.draw_colored_polygon(cone_pts, Color(1.0, 0.15, 0.15, 0.18))
		canvas.draw_line(e_pos, e_pos + dir_l * view_dist, Color(1.0, 0.2, 0.2, 0.4), 1.0)
		canvas.draw_line(e_pos, e_pos + dir_r * view_dist, Color(1.0, 0.2, 0.2, 0.4), 1.0)

		# Маркер монстра
		canvas.draw_circle(e_pos, 5.5, Color(1.0, 0.15, 0.15, 0.95))
		canvas.draw_circle(e_pos, 7.0, Color(1.0, 0.4, 0.4, 0.5), false, 1.5)
		# Указатель взгляда
		canvas.draw_line(e_pos, e_pos + dir_main * 9.0, Color(1.0, 1.0, 1.0, 0.95), 2.0)

	# 6. Игрок (Зеленый маркер + направление)
	if GameManager.player_ref and is_instance_valid(GameManager.player_ref):
		var player = GameManager.player_ref
		var p_pos = _world_to_map(player.global_position)
		var p_yaw = player.rotation.y
		var p_dir = Vector2(-sin(p_yaw), -cos(p_yaw))

		canvas.draw_circle(p_pos, 5.0, Color(0.2, 1.0, 0.35, 0.95))
		canvas.draw_circle(p_pos, 6.5, Color(0.5, 1.0, 0.6, 0.5), false, 1.5)
		canvas.draw_line(p_pos, p_pos + p_dir * 8.0, Color(1.0, 1.0, 1.0, 0.95), 2.0)

		# Конус фонарика, если включен
		if player.get("flashlight_on") == true:
			var fl_pts = PackedVector2Array([
				p_pos,
				p_pos + Vector2(-sin(p_yaw - 0.35), -cos(p_yaw - 0.35)) * 35.0,
				p_pos + p_dir * 40.0,
				p_pos + Vector2(-sin(p_yaw + 0.35), -cos(p_yaw + 0.35)) * 35.0
			])
			canvas.draw_colored_polygon(fl_pts, Color(1.0, 0.95, 0.6, 0.22))
