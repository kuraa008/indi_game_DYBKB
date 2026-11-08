extends Node

# Улица у дома Итана (пролог, Jan-ky; ставит Main на карте «Улица» рядом с CityStreetScene Досыма).
# Два-три дня после звонка. Итан выходит из подъезда с сумкой и идёт к машине мимо
# объявлений «ПРОПАЛ ЧЕЛОВЕК».
#   — у объявления [ЛКМ / E]: первое — «Сэм…», второе — «Куда же ты делся…»;
#   — у машины [ЛКМ / E] «Сесть в машину» → дверь, затемнение → IntroCutscene (дорога, заправка,
#     авария) → карта «Шоссе».
# Точки объявлений и машину берёт из CityStreetScene (_posters, CAR_POS).

const CAR_POS := Vector3(6.0, 0.0, 29.5)
const INTRO_SND := "res://assets/audio/intro/"

var _layer: CanvasLayer
var _black: ColorRect
var _sub: Label
var _sub_tween: Tween
var _seen := 0
var _leaving := false


class Spot extends StaticBody3D:
	var hint := ""
	var on_use: Callable

	func get_interaction_hint() -> String:
		return hint

	func interact(_opener: Node = null) -> void:
		on_use.call()


func _ready() -> void:
	name = "StreetCar"
	_build_ui()
	_setup.call_deferred()
	_title()


func _setup() -> void:
	var street := get_parent().get_node_or_null("CityStreetScene")
	var posters: Array = street.get("_posters") if street else []
	for p in posters:
		var s := _spot(Vector3(0.34, 0.47, 0.05), "[ЛКМ / E]  Осмотреть объявление", _on_poster)
		s.global_position = p[0]
		s.rotation_degrees = Vector3(0, p[1], 0)
	var car := _spot(Vector3(4.0, 1.45, 1.9), "[ЛКМ / E]  Сесть в машину", _on_car)
	car.global_position = CAR_POS + Vector3(0, 0.7, 0)


func _spot(size: Vector3, hint: String, use: Callable) -> Spot:
	var s := Spot.new()
	s.hint = hint
	s.on_use = use
	s.set_meta("item_type", "story_spot")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	s.add_child(col)
	get_parent().add_child(s)
	return s


func _on_poster() -> void:
	_seen += 1
	if _seen == 1:
		_say("ИТАН", "Сэм…", 2.0)
	elif _seen == 2:
		_say("ИТАН", "Куда же ты делся…", 2.4)


func _on_car() -> void:
	if _leaving:
		return
	_leaving = true
	var player = GameManager.player_ref
	if is_instance_valid(player):
		player.set("is_in_cutscene", true)
		player.set("velocity", Vector3.ZERO)
	_play(INTRO_SND + "car_door.wav", -4.0)
	var tw := create_tween()
	tw.tween_property(_black, "color:a", 1.0, 0.8)
	await tw.finished
	await get_tree().create_timer(0.4).timeout
	preload("res://scripts/cutscenes/PrologueFlow.gd").drive_away(get_tree())


# «Два дня спустя»: улица — первая сцена после звонка
func _title() -> void:
	_black.color.a = 1.0
	var card := Label.new()
	card.text = "ДВА ДНЯ СПУСТЯ"
	card.add_theme_font_size_override("font_size", 40)
	card.add_theme_color_override("font_color", Color(0.92, 0.93, 0.95))
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.modulate.a = 0.0
	_layer.add_child(card)
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(card, "modulate:a", 1.0, 0.8)
	tw.tween_interval(1.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.7)
	tw.tween_property(_black, "color:a", 0.0, 1.2)
	tw.tween_callback(card.queue_free)


func _play(path: String, db: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_black)
	_sub = Label.new()
	_sub.add_theme_font_size_override("font_size", 22)
	_sub.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	_sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_sub.add_theme_constant_override("outline_size", 4)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.anchor_top = 1.0
	_sub.anchor_bottom = 1.0
	_sub.offset_top = -120
	_sub.offset_bottom = -80
	_sub.modulate.a = 0.0
	_layer.add_child(_sub)


func _say(who: String, text: String, hold: float) -> void:
	_sub.text = "%s: %s" % [who, text]
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_sub, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_interval(hold)
	_sub_tween.tween_property(_sub, "modulate:a", 0.0, 0.4)
