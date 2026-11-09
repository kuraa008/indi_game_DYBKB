extends "res://scripts/ApartmentKit.gd"

# Пролог, «Обычный день» (карта «Квартира»): доесть пиццу, сварить кофе, оттереть
# плиту, собрать одежду, запустить стирку, завалиться на диван и листать телефон.
# Потом дождь, лай за стеной и звонок с неизвестного номера:
# «Ответить» ведёт в кат-сцену «Звонок» и на улицу, «Сбросить» — звонят снова.
#
# Вещи квартиры слиты в общие меши, поэтому одежду этот файл строит заново
# отдельными кусками, а исходный меш одежды скрывает.

const PROPS_PATH := "ApartmentScene/ApartmentProps"
const SFX := "res://assets/audio/"
const CUT := "res://assets/audio/cutscenes/"

const PIZZA_BOX := Vector3(0.05, 0.47, 0.25)
const TURKA := Vector3(5.215, 0.943, -5.88)
const STOVE_TOP := Vector3(5.36, 0.93, -6.02)
const WASHER_CENTER := Vector3(6.83, 0.45, 0.5)
const WASHER_DISPLAY := Vector3(6.526, 0.778, 0.54)
const SOFA_CENTER := Vector3(0.25, 0.58, 1.75)
const SOFA_SEAT := Vector3(0.25, 0.01, 1.45)
const SOFA_EYE_HEIGHT := 1.12

const BOIL_SECONDS := 7.0
const FOAM_LEAD := 1.6
const WIPES_NEEDED := 4
const BROWSE_LIMIT := 22.0     # столько Итан листает телефон, если игрок ничего не открывает
const QUIET_BEFORE_CALL := 6.0
const REDIAL_AFTER := 5.0

const CALLER := "Неизвестный номер"

var spots: Dictionary = {}     # имя -> Spot, для проверок
var pizza_eaten := false
var coffee_started := false
var coffee_spilled := false
var coffee_taken := false
var wipes := 0
var clothes_left := 0
var washer_running := false
var on_sofa := false

var _clothes: Dictionary = {}  # имя -> MeshInstance3D
var _missions: MissionTracker
var _player: CharacterBody3D
var _head: Node3D
var _layer: CanvasLayer
var _black: ColorRect
var _sub: Label
var _sub_tween: Tween
var _flame: MeshInstance3D
var _flame_light: OmniLight3D
var _foam: MeshInstance3D
var _stain_material: StandardMaterial3D


class Spot extends Area3D:
	var hint := ""
	var on_use: Callable

	func get_interaction_hint() -> String:
		return hint

	func interact(_opener: Node = null) -> void:
		on_use.call()


func _ready() -> void:
	name = "PrologueApartment"
	_build_ui()
	_rebuild_clothes()
	_add_spots()
	_start_missions.call_deferred()


func _exit_tree() -> void:
	Phone.allow_in_cutscene = false


# ─── Одежда ─────────────────────────────────────────────────

func _rebuild_clothes() -> void:
	_hide_baked_clothes()
	var shirt := func(p: Vector2) -> bool:
		var ax := absf(p.x)
		var torso := ax < 0.2 and absf(p.y) < 0.32
		var sleeve := ax < 0.38 and p.y > -0.32 + (ax - 0.2) * 0.55 and p.y < -0.13 + (ax - 0.2) * 0.8
		return (torso or sleeve) and (p - Vector2(0, -0.37)).length() > 0.1
	var jeans := func(p: Vector2) -> bool:
		var ax := absf(p.x)
		if p.y < -0.12:
			return ax < 0.2 and p.y > -0.5
		var w := 0.19 - (p.y + 0.12) * 0.07
		return ax > 0.012 + (p.y + 0.12) * 0.05 and ax < w + (p.y + 0.12) * 0.05 and p.y < 0.54
	var hoodie := func(p: Vector2) -> bool:
		var ax := absf(p.x)
		var torso := ax < 0.27 and absf(p.y) < 0.34
		var sleeve := ax < 0.6 and p.y > -0.34 + (ax - 0.27) * 0.45 and p.y < -0.14 + (ax - 0.27) * 0.65
		return torso or sleeve or (p - Vector2(0, -0.44)).length() < 0.17
	var folded := func(p: Vector2) -> bool:
		return absf(p.x) < 0.17 and absf(p.y) < 0.15

	_rng.seed = 7741
	_cloth(_xf(Vector3(1.12, FL, -3.07), Vector3(0, -18, 0)), shirt, Vector2(0.4, 0.34), 0.03, Color(0.66, 0.64, 0.58))
	_clothes["shirt"] = _flush(_vmat(0.92))
	_cloth(_xf(Vector3(-0.03, FL, -3.32), Vector3(0, 25, 0)), jeans, Vector2(0.22, 0.56), 0.032, Color(0.22, 0.3, 0.46))
	_clothes["jeans"] = _flush(_vmat(0.92))
	_cloth(_xf(Vector3(1.7, FL + 0.02, -4.75), Vector3(0, 12, 0)), hoodie, Vector2(0.62, 0.62), 0.05, Color(0.36, 0.39, 0.33))
	_clothes["hoodie"] = _flush(_vmat(0.92))
	for q in [[Vector3(0.61, FL, -5.1), 40.0], [Vector3(0.88, FL, -4.85), -30.0]]:
		_base = _xf(q[0], Vector3(0, q[1], 0))
		var sock := Color(0.72, 0.7, 0.64)
		_bl(Vector3(0.042, 0.016, 0.08), Vector3(0, 0.015, -0.03), sock)
		_bl(Vector3(0.04, 0.018, 0.055), Vector3(0.022, 0.015, 0.07), sock.darkened(0.08), Vector3(0, -32, 0))
	_clothes["socks"] = _flush(_vmat(0.92))
	# Сложенная футболка на кровати остаётся на месте
	_cloth(_xf(Vector3(-1.62, FL + 0.49, -3.3), Vector3(0, 80, 0)), folded, Vector2(0.18, 0.16), 0.055, Color(0.52, 0.2, 0.17), 0.016)
	_flush(_vmat(0.92))
	clothes_left = _clothes.size()


# Одежду ApartmentProps строит последней, поэтому её меш — последний дочерний
func _hide_baked_clothes() -> void:
	var props := get_parent().get_node_or_null(PROPS_PATH)
	if props == null:
		return
	var children := props.get_children()
	children.reverse()
	for child in children:
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false
			return


# ─── Точки действий ─────────────────────────────────────────

func _add_spots() -> void:
	_spot("pizza", PIZZA_BOX + Vector3(0, 0.05, 0), Vector3(0.46, 0.2, 0.46), "Доесть пиццу", _on_pizza)
	_spot("turka", TURKA + Vector3(0, 0.05, 0), Vector3(0.3, 0.24, 0.3), "Сварить кофе", _on_turka)
	_spot("shirt", Vector3(1.12, 0.08, -3.07), Vector3(0.78, 0.2, 0.7), "Подобрать рубашку", _on_cloth.bind("shirt"))
	_spot("jeans", Vector3(-0.03, 0.08, -3.32), Vector3(0.55, 0.2, 1.12), "Подобрать джинсы", _on_cloth.bind("jeans"))
	_spot("hoodie", Vector3(1.7, 0.08, -4.75), Vector3(1.2, 0.2, 1.2), "Подобрать толстовку", _on_cloth.bind("hoodie"))
	_spot("socks", Vector3(0.745, 0.08, -4.975), Vector3(0.75, 0.2, 0.75), "Подобрать носки", _on_cloth.bind("socks"))
	_spot("washer", WASHER_CENTER, Vector3(0.66, 0.98, 0.66), "Загрузить стиралку", _on_washer)
	_spot("sofa", SOFA_CENTER, Vector3(2.3, 1.04, 1.1), "Завалиться на диван", _on_sofa)


func _spot(key: String, pos: Vector3, side: Vector3, action: String, use: Callable) -> void:
	var s := Spot.new()
	s.hint = "[ЛКМ / E]  " + action
	s.on_use = use
	s.set_meta("item_type", "story_spot")
	s.monitoring = false
	s.monitorable = false
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = side
	col.shape = shape
	s.add_child(col)
	add_child(s)
	s.global_position = pos
	spots[key] = s


func _drop_spot(key: String) -> void:
	if spots.has(key):
		(spots[key] as Node).queue_free()
		spots.erase(key)


func _start_missions() -> void:
	while not is_instance_valid(GameManager.player_ref) or not GameManager.player_ref.is_inside_tree():
		await get_tree().process_frame
	_player = GameManager.player_ref
	_head = _player.get("head")
	_missions = MissionTracker.new()
	_missions.setup([
		{"text": "Поесть", "done": func(): return pizza_eaten},
		{"text": "Сварить кофе", "done": func(): return coffee_spilled or coffee_taken},
		{"text": "Вытереть плиту", "done": func(): return wipes >= WIPES_NEEDED},
		{"text": "Собрать одежду", "done": func(): return clothes_left == 0},
		{"text": "Постирать вещи", "done": func(): return washer_running},
		{"text": "Отдохнуть", "done": func(): return on_sofa},
	])
	add_child(_missions)


# ─── Дела ───────────────────────────────────────────────────

func _on_pizza() -> void:
	if pizza_eaten:
		return
	pizza_eaten = true
	_drop_spot("pizza")
	_play(SFX + "bag_item_select.wav", -6.0)
	_cover_pizza()
	_say("Вчерашняя. Сойдёт.", 2.0)


# Диск пиццы слит с коробкой: сверху ложится пустое жирное дно
func _cover_pizza() -> void:
	var bottom := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.372, 0.002, 0.372)
	bottom.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.46, 0.34, 0.22)
	mat.roughness = 0.9
	bottom.material_override = mat
	add_child(bottom)
	bottom.global_position = PIZZA_BOX + Vector3(0, 0.036, 0)
	bottom.rotation_degrees = Vector3(0, 12, 0)


func _on_turka() -> void:
	if coffee_started:
		return
	coffee_started = true
	_drop_spot("turka")
	_play(CUT + "fire_ignite.wav", -14.0)
	_light_burner()
	var boil := _play(SFX + "car_steam.wav", -30.0, true, TURKA)
	_spot("turka", TURKA + Vector3(0, 0.05, 0), Vector3(0.3, 0.24, 0.3), "Снять турку", _take_coffee.bind(boil))
	await get_tree().create_timer(BOIL_SECONDS - FOAM_LEAD, false).timeout
	if coffee_taken:
		return
	if boil:
		var louder := create_tween()
		louder.tween_property(boil, "volume_db", -18.0, FOAM_LEAD)
	_raise_foam()
	await get_tree().create_timer(FOAM_LEAD, false).timeout
	if coffee_taken:
		return
	coffee_spilled = true
	_drop_spot("turka")
	if boil:
		boil.queue_free()
	_put_out_burner()
	_foam.visible = false
	_show_stain()
	_play(CUT + "fire_die.wav", -14.0)
	_say("Чёрт! Убежал…", 2.2)
	_spot("stove", STOVE_TOP, Vector3(0.66, 0.26, 0.66), _wipe_action(), _on_wipe)


# Успел снять: кофе готов, плиту вытирать не придётся
func _take_coffee(boil: Node) -> void:
	if coffee_spilled or coffee_taken:
		return
	coffee_taken = true
	wipes = WIPES_NEEDED
	_drop_spot("turka")
	if boil:
		boil.queue_free()
	_put_out_burner()
	if is_instance_valid(_foam):
		_foam.visible = false
	_play(SFX + "bag_item_select.wav", -8.0)


func _light_burner() -> void:
	_flame = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.068
	mesh.bottom_radius = 0.05
	mesh.height = 0.018
	_flame.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 0.5, 1.0)
	_flame.material_override = mat
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
	_flame.global_position = TURKA + Vector3(0, -0.012, 0)
	_flame_light = OmniLight3D.new()
	_flame_light.light_color = Color(0.35, 0.55, 1.0)
	_flame_light.light_energy = 0.6
	_flame_light.omni_range = 1.1
	add_child(_flame_light)
	_flame_light.global_position = TURKA + Vector3(0, 0.03, 0)


func _put_out_burner() -> void:
	_flame.queue_free()
	_flame_light.queue_free()


func _raise_foam() -> void:
	_foam = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05
	mesh.bottom_radius = 0.045
	mesh.height = 0.03
	_foam.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.3, 0.18)
	mat.roughness = 0.75
	_foam.material_override = mat
	add_child(_foam)
	_foam.global_position = TURKA + Vector3(0, 0.086, 0)
	_foam.scale = Vector3(0.8, 0.05, 0.8)
	var tw := create_tween().set_parallel()
	tw.tween_property(_foam, "scale", Vector3(1.08, 1.0, 1.08), FOAM_LEAD)
	tw.tween_property(_foam, "global_position:y", TURKA.y + 0.102, FOAM_LEAD)


func _show_stain() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.95))
	gradient.set_offset(1, 0.62)
	gradient.set_color(1, Color(1, 1, 1, 0.0))
	gradient.add_point(0.5, Color(1, 1, 1, 0.95))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	_stain_material = StandardMaterial3D.new()
	_stain_material.albedo_texture = tex
	_stain_material.albedo_color = Color(0.3, 0.14, 0.05, 1.0)
	_stain_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stain_material.roughness = 0.2
	for piece in [[Vector3(-0.015, 0, -0.02), Vector2(0.4, 0.34)], [Vector3(0.1, 0, 0.09), Vector2(0.2, 0.16)]]:
		var blot := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = piece[1]
		blot.mesh = plane
		blot.material_override = _stain_material
		blot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		blot.name = "CoffeeStain"
		add_child(blot)
		blot.global_position = Vector3(TURKA.x, 0.905, TURKA.z) + piece[0]


func _wipe_action() -> String:
	return "Оттереть плиту (%d/%d)" % [wipes, WIPES_NEEDED]


func _on_wipe() -> void:
	if wipes >= WIPES_NEEDED:
		return
	wipes += 1
	_play(CUT + "hand_slide_wood.wav", -8.0)
	_stain_material.albedo_color.a = 1.0 - float(wipes) / float(WIPES_NEEDED)
	if wipes < WIPES_NEEDED:
		(spots["stove"] as Spot).hint = "[ЛКМ / E]  " + _wipe_action()
		return
	_drop_spot("stove")
	for child in get_children():
		if str(child.name).begins_with("CoffeeStain"):
			child.queue_free()


func _on_cloth(key: String) -> void:
	if not _clothes.has(key):
		return
	(_clothes[key] as Node).queue_free()
	_clothes.erase(key)
	_drop_spot(key)
	clothes_left -= 1
	_play(CUT + "sheet_flutter.wav", -10.0)
	var total := 4
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		GameManager.ui_ref.call("show_hint", "Одежда %d/%d" % [total - clothes_left, total], 1.6)


func _on_washer() -> void:
	if washer_running:
		return
	if clothes_left > 0:
		_say("Сначала соберу вещи.", 2.0)
		return
	washer_running = true
	_drop_spot("washer")
	_play(SFX + "switch_pull.wav", -6.0)
	_play(SFX + "electric_hum.wav", -24.0, true, WASHER_CENTER)
	var display := Label3D.new()
	display.text = "1:28"
	display.font_size = 28
	display.pixel_size = 0.0012
	display.modulate = Color(0.35, 1.0, 0.45)
	display.outline_size = 0
	add_child(display)
	display.global_position = WASHER_DISPLAY
	display.rotation_degrees = Vector3(0, -90, 0)
	_say("Третья неделя… Пора уже.", 2.4)


func _on_sofa() -> void:
	if on_sofa:
		return
	if not _chores_done():
		_say("Сначала дела.", 1.6)
		return
	on_sofa = true
	_drop_spot("sofa")
	_player.set("is_in_cutscene", true)
	await _fade(1.0, 0.45)
	_player.global_position = SOFA_SEAT
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_head.position.y = SOFA_EYE_HEIGHT
	_head.rotation = Vector3(-0.08, 0, 0)
	await _fade(0.0, 0.55)
	_run_phone_and_call()


func _chores_done() -> bool:
	return pizza_eaten and wipes >= WIPES_NEEDED and washer_running


# ─── Диван, телефон и звонок ────────────────────────────────

func _run_phone_and_call() -> void:
	Phone.allow_in_cutscene = true
	await get_tree().create_timer(0.8, false).timeout
	Phone.open()
	await _wait_for_browsing()
	_play(CUT + "amb_rain_window.wav", -14.0, true)
	_play(CUT + "dog_bark_wall.wav", -12.0)
	await get_tree().create_timer(QUIET_BEFORE_CALL, false).timeout
	var result: String = await Phone.incoming_call(CALLER, {
		"repeat_after": REDIAL_AFTER,
		"decline_line": "Да что ж такое…",
	})
	Phone.allow_in_cutscene = false
	if result == Phone.ANSWERED:
		preload("res://scripts/cutscenes/PrologueFlow.gd").answer_call(get_tree())


# Новости и контакты, как в сюжете; если игрок ничего не трогает, звонок всё равно придёт
func _wait_for_browsing() -> void:
	var seen := {}
	var note := func(page: int) -> void:
		seen[page] = true
	Phone.page_opened.connect(note)
	var waited := 0.0
	while waited < BROWSE_LIMIT and not (seen.has(Phone.Page.NEWS) and seen.has(Phone.Page.CONTACTS)):
		await get_tree().process_frame
		if not get_tree().paused:
			waited += get_process_delta_time()
	Phone.page_opened.disconnect(note)


# ─── Звук, затемнение, реплики ──────────────────────────────

func _play(path: String, db: float, loop: bool = false, at: Variant = null) -> Node:
	var st: AudioStream = load(path)
	if st == null:
		return null
	if loop and st is AudioStreamWAV:
		var wav := st.duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = int(wav.get_length() * wav.mix_rate)
		st = wav
	var p: Node
	if at is Vector3:
		var spatial := AudioStreamPlayer3D.new()
		spatial.stream = st
		spatial.volume_db = db
		spatial.unit_size = 3.0
		add_child(spatial)
		spatial.global_position = at
		spatial.play()
		p = spatial
	else:
		var flat := AudioStreamPlayer.new()
		flat.stream = st
		flat.volume_db = db
		add_child(flat)
		flat.play()
		p = flat
	if not loop:
		p.connect("finished", p.queue_free)
	return p


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
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.anchor_right = 1.0
	_sub.anchor_top = 1.0
	_sub.anchor_bottom = 1.0
	_sub.offset_top = -120
	_sub.offset_bottom = -80
	_sub.modulate.a = 0.0
	_layer.add_child(_sub)


func _fade(alpha: float, seconds: float) -> void:
	var tw := create_tween()
	tw.tween_property(_black, "color:a", alpha, seconds)
	await tw.finished


func _say(text: String, hold: float) -> void:
	_sub.text = "ИТАН: " + text
	if _sub_tween:
		_sub_tween.kill()
	_sub_tween = create_tween()
	_sub_tween.tween_property(_sub, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_interval(hold)
	_sub_tween.tween_property(_sub, "modulate:a", 0.0, 0.4)
