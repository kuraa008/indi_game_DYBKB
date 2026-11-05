class_name MissionTracker
extends CanvasLayer

# Текущая задача в углу экрана: видна только одна, после выполнения сменяется следующей.
# Шаг: {"text": String, "done": Callable}. Шаг без done остаётся на экране до конца уровня.

var _steps: Array = []
var _index := -1
var _box: VBoxContainer
var _text: Label
var _swapping := false


func setup(steps: Array) -> void:
	_steps = steps


func current_text() -> String:
	return _text.text if is_instance_valid(_text) else ""


func finish() -> void:
	_index = _steps.size()
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 0.5)


func _ready() -> void:
	layer = 80
	_box = VBoxContainer.new()
	_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_box.offset_left = -470.0
	_box.offset_right = -34.0
	_box.offset_top = 30.0
	_box.offset_bottom = 110.0
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.modulate.a = 0.0
	add_child(_box)
	var cap := _label(15, Color(0.72, 0.68, 0.56))
	cap.text = "ЗАДАЧА"
	_box.add_child(cap)
	_text = _label(22, Color(0.95, 0.93, 0.86))
	_box.add_child(_text)
	_advance()


func _label(px: int, col: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _process(_delta: float) -> void:
	var pl = GameManager.player_ref
	visible = not (is_instance_valid(pl) and pl.get("is_in_cutscene") == true)
	if _swapping or _index < 0 or _index >= _steps.size():
		return
	var cond = _steps[_index].get("done")
	if cond is Callable and cond.call():
		_advance()


# Сразу пропускает шаги, которые игрок уже сделал раньше времени
func _advance() -> void:
	var next := _index + 1
	while next < _steps.size():
		var cond = _steps[next].get("done")
		if cond is Callable and cond.call():
			next += 1
		else:
			break
	_index = next
	if _index >= _steps.size():
		finish()
		return
	_swapping = true
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func(): _text.text = str(_steps[_index]["text"]))
	tw.tween_property(_box, "modulate:a", 1.0, 0.45)
	tw.tween_callback(func(): _swapping = false)
