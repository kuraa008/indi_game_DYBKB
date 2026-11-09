extends Node

# Инструменты редактора карт: телепорт камеры и показ окружения, собранного кодом.
# [J] открывает окно телепорта, [B] переносит камеру к точке под курсором.
# Квартира, улица, лес и дом Крейна почти целиком строятся скриптами: такие вещи видно
# в редакторе как фон, но двигать и сохранять можно только объекты самой карты.

const SPOTS := {
	"шоссе": [
		["Крыльцо", Vector3(-46, 2, -225)], ["Гараж, машина под брезентом", Vector3(-44, 2, -211)],
		["Сарай", Vector3(-70, 2, -235.5)], ["Поленница", Vector3(-58, 2, -209)], ["Люк и колодец", Vector3(-58, 2, -234)],
		["Прихожая", Vector3(-57.6, 2, -226.6)], ["Комната отца", Vector3(-66, 5, -222)], ["Комната Сэма", Vector3(-69.4, 5, -229.5)],
		["Подвал", Vector3(-58, -2.6, -227.5)],
	],
	"улица": [
		["Подъезд и домофон", Vector3(0.7, 1.7, 3)], ["Двор, кусты", Vector3(-16, 1.7, 20)], ["Парковка", Vector3(22, 1.7, 20)],
		["Гаражи", Vector3(30, 1.7, 2)], ["Машина Итана", Vector3(3, 1.7, 26.5)], ["Тумба", Vector3(-7, 1.7, 26.5)], ["Остановка", Vector3(-20, 1.7, 23)],
	],
	"квартира": [
		["Комната", Vector3(1.5, 1.6, -1)], ["Спальня", Vector3(0, 1.6, -4.6)], ["Коридор", Vector3(3.45, 1.6, 0)], ["Кухня", Vector3(6, 1.6, -2.5)], ["Ванная", Vector3(5.3, 1.6, 1.2)],
	],
	"крейна": [
		["Поляна", Vector3(13, 1.7, 1.2)], ["Внутри дома", Vector3(2, 1.6, 1.2)], ["Колодец", Vector3(8, 1.7, -1.2)],
	],
	"лесная": [
		["Начало тропы", Vector3(177, 1.7, 23)], ["Ручей", Vector3(103, 1.7, 11)], ["Поваленное дерево", Vector3(101, 1.7, 7)], ["Выход к дому Крейна", Vector3(24, 1.7, 2)], ["Дом Крейна", Vector3(13, 1.7, 1.2)],
	],
}

const LIST_LIMIT := 300

var ed
var scenery: Node3D
var scenery_shown := true

var _x: LineEdit
var _y: LineEdit
var _z: LineEdit
var _search: LineEdit
var _list: ItemList
var _found: Array = []


func teleport(pos: Vector3) -> void:
	ed.editor_cam.position = Vector3.ZERO
	ed.cam_pivot.global_position = pos
	ed._update_cam_rotation()
	ed.show_notification("🧭 Камера: %.1f  %.1f  %.1f" % [pos.x, pos.y, pos.z])


func teleport_under_cursor() -> void:
	if ed._is_mouse_over_ui():
		return
	var mouse: Vector2 = ed.get_viewport().get_mouse_position()
	var hit: Vector3 = ed._get_ground_position(mouse)
	var flat: Vector3 = ed.editor_cam.global_position - hit
	flat.y = 0.0
	teleport(hit + flat.normalized() * 0.7 + Vector3.UP * 1.7)


# ── Окружение, собранное кодом ──

func refresh_scenery(path: String) -> void:
	if scenery and is_instance_valid(scenery):
		scenery.queue_free()
	scenery = null
	var lower := path.to_lower()
	var script_path := ""
	if "квартира" in lower:
		script_path = "res://scripts/ApartmentScene.gd"
	elif "улица" in lower:
		script_path = "res://scripts/CityStreetScene.gd"
	elif "крейна" in lower or "лесная" in lower:
		script_path = "res://scripts/CraneHouseMap.gd"
	elif "шоссе" not in lower:
		return
	scenery = Node3D.new()
	scenery.name = "CodeScenery"
	scenery.visible = scenery_shown
	ed.add_child(scenery)
	if script_path != "":
		scenery.add_child(load(script_path).new())
	else:
		HouseStory.build(scenery)
	set_scenery_solid(false)


# В редакторе фон не должен мешать выделять объекты; в тесте он снова твёрдый
func set_scenery_solid(solid: bool) -> void:
	if scenery and is_instance_valid(scenery):
		_set_solid(scenery, solid)


func _set_solid(node: Node, solid: bool) -> void:
	if node is CollisionObject3D:
		if solid:
			if node.has_meta("editor_layer"):
				node.collision_layer = node.get_meta("editor_layer")
		elif node.collision_layer != 0:
			node.set_meta("editor_layer", node.collision_layer)
			node.collision_layer = 0
	for child in node.get_children():
		_set_solid(child, solid)


# ── Окно телепорта ──

func open_panel() -> void:
	ed._close_active_modal()
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ed.ui_layer.add_child(bg)
	ed.active_modal = bg
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 560)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	style.set_border_width_all(1)
	style.border_color = Color(0.26, 0.44, 0.68)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var head := HBoxContainer.new()
	vb.add_child(head)
	var title := Label.new()
	title.text = "🧭 ТЕЛЕПОРТ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(ed._close_active_modal)
	head.add_child(close)

	var row := HBoxContainer.new()
	vb.add_child(row)
	var pos: Vector3 = ed.editor_cam.global_position
	_x = _field(row, "X", pos.x)
	_y = _field(row, "Y", pos.y)
	_z = _field(row, "Z", pos.z)
	var go := Button.new()
	go.text = "Перейти"
	go.pressed.connect(_go_to_fields)
	row.add_child(go)

	var spots: Array = _spots_for_map()
	if not spots.is_empty():
		var flow := HFlowContainer.new()
		vb.add_child(flow)
		for s in spots:
			var b := Button.new()
			b.text = s[0]
			b.pressed.connect(_jump.bind(s[1]))
			flow.add_child(b)

	_search = LineEdit.new()
	_search.placeholder_text = "Найти объект по имени"
	_search.text_changed.connect(_fill_list)
	vb.add_child(_search)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_clicked.connect(_on_item_clicked)
	vb.add_child(_list)
	_fill_list("")

	if scenery:
		var toggle := CheckButton.new()
		toggle.text = "Показывать окружение из кода (его нельзя двигать)"
		toggle.button_pressed = scenery_shown
		for state in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			toggle.add_theme_color_override(state, Color(0.82, 0.86, 0.92))
		toggle.toggled.connect(_on_scenery_toggled)
		vb.add_child(toggle)

	var hint := Label.new()
	hint.text = "[B] в редакторе — перенести камеру к точке под курсором"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.66, 0.75))
	vb.add_child(hint)
	_search.grab_focus()


func _field(row: HBoxContainer, caption: String, value: float) -> LineEdit:
	var l := Label.new()
	l.text = caption
	row.add_child(l)
	var e := LineEdit.new()
	e.text = "%.1f" % value
	e.custom_minimum_size = Vector2(80, 0)
	e.select_all_on_focus = true
	e.text_submitted.connect(func(_t: String) -> void: _go_to_fields())
	row.add_child(e)
	return e


func _go_to_fields() -> void:
	if not (_x.text.is_valid_float() and _y.text.is_valid_float() and _z.text.is_valid_float()):
		ed.show_notification("Введите три числа: X Y Z")
		return
	_jump(Vector3(_x.text.to_float(), _y.text.to_float(), _z.text.to_float()))


func _jump(pos: Vector3) -> void:
	ed._close_active_modal()
	teleport(pos)


func _spots_for_map() -> Array:
	var lower: String = str(ed.active_map_file_path).to_lower()
	for key in SPOTS:
		if key in lower:
			return SPOTS[key]
	return []


func _fill_list(query: String) -> void:
	_list.clear()
	_found.clear()
	var needle := query.strip_edges().to_lower()
	var nodes: Array = []
	var total := 0
	for child in ed.objects_root.get_children():
		if not (child is Node3D and child.has_meta("obj_type")):
			continue
		var label := str(child.get_meta("obj_name", "Объект"))
		if needle != "" and not needle in label.to_lower():
			continue
		total += 1
		if nodes.size() < LIST_LIMIT:
			nodes.append([label, child])
	nodes.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pair in nodes:
		var p: Vector3 = pair[1].global_position
		_list.add_item("%s   (%.0f, %.0f, %.0f)" % [pair[0], p.x, p.y, p.z])
		_found.append(pair[1])
	if total > nodes.size():
		_list.add_item("… показаны первые %d из %d, уточните поиск" % [nodes.size(), total], null, false)


func _on_item_clicked(index: int, _at: Vector2, _button: int) -> void:
	if index >= _found.size() or not is_instance_valid(_found[index]):
		return
	var node: Node3D = _found[index]
	ed._close_active_modal()
	ed._select_object(node)
	ed.editor_cam.position = Vector3.ZERO
	ed._focus_camera_on_selected()


func _on_scenery_toggled(on: bool) -> void:
	scenery_shown = on
	if scenery and is_instance_valid(scenery):
		scenery.visible = on
