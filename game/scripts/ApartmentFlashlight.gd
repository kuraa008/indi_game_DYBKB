extends "res://scripts/ApartmentKit.gd"

# Фонарик Итана лежит в ящике письменного стола в спальне.
# В квартире фонарика в руках нет: открыть ящик → [держать E] взять фонарик → он в рюкзаке.
# Достать в руку и убрать обратно — слот рюкзака [1] или клавиша [F].
# На остальных картах фонарик уже есть (Main выдаёт его, если пролог пропустили).

const DESK_FRONT_X := -2.03          # передняя кромка стола со стороны стула
const DRAWER_Z := -3.63            # сбоку от стула, иначе его спинка загораживает ящик
const DRAWER_Y := 0.632              # центр ящика: висит под столешницей
const DRAWER_W := 0.3                # вдоль стола (Z)
const DRAWER_H := 0.085
const DRAWER_D := 0.4                # вглубь стола (X)
const OPEN_BY := 0.27

var drawer: Node3D
var flashlight_prop: Node3D
var _drawer_spot: Area3D
var _take_spot: Area3D
var _open := false


func _ready() -> void:
	name = "ApartmentFlashlight"
	_build_drawer()
	_build_flashlight()
	# Только в игре: в кат-сцене «Звонок» эта же квартира — просто декорация
	if _in_game():
		GameManager.take_flashlight_away()
		_add_spots.call_deferred()


func _in_game() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path.ends_with("Main.tscn")


# ── Ящик: передняя панель с ручкой, дно и стенки, внутри темно ──
func _build_drawer() -> void:
	drawer = Node3D.new()
	drawer.name = "DeskDrawer"
	add_child(drawer)
	drawer.position = Vector3(DESK_FRONT_X, DRAWER_Y, DRAWER_Z)
	var wood := Color(0.36, 0.23, 0.15)
	var inner := Color(0.24, 0.16, 0.11)
	var t := 0.012
	# Передняя панель (смотрит на +X, к стулу) и латунная ручка
	_bx(Vector3(0.018, DRAWER_H, DRAWER_W), Vector3(0.009, 0, 0), wood)
	_bx(Vector3(0.004, DRAWER_H - 0.016, DRAWER_W - 0.016), Vector3(0.019, 0, 0), wood.lightened(0.05))
	_bx(Vector3(0.01, 0.012, 0.1), Vector3(0.034, 0, 0), Color(0.62, 0.48, 0.24))
	for sz in [-0.04, 0.04]:
		_bx(Vector3(0.024, 0.01, 0.01), Vector3(0.024, 0, sz), Color(0.5, 0.38, 0.19))
	# Короб: дно, боковые стенки, задняя стенка
	_bx(Vector3(DRAWER_D, t, DRAWER_W - 0.02), Vector3(-DRAWER_D * 0.5, -DRAWER_H * 0.5 + t * 0.5, 0), inner)
	for s in [-1.0, 1.0]:
		_bx(Vector3(DRAWER_D, DRAWER_H - 0.012, t), Vector3(-DRAWER_D * 0.5, -0.006, s * (DRAWER_W * 0.5 - 0.01 - t * 0.5)), inner)
	_bx(Vector3(t, DRAWER_H - 0.012, DRAWER_W - 0.02), Vector3(-DRAWER_D + t * 0.5, -0.006, 0), inner)
	# Мелочи в ящике: батарейки, тетрадный лист, карандаш
	_bx(Vector3(0.12, 0.002, 0.14), Vector3(-0.28, -DRAWER_H * 0.5 + t + 0.001, 0.05), Color(0.82, 0.8, 0.72), Vector3(0, 14, 0))
	for k in range(2):
		_cy(0.007, 0.007, 0.05, Vector3(-0.3 - k * 0.018, -DRAWER_H * 0.5 + t + 0.007, -0.1), Color(0.75, 0.6, 0.15), Vector3(0, 0, 90), 10)
	_cy(0.0035, 0.0035, 0.14, Vector3(-0.3, -DRAWER_H * 0.5 + t + 0.004, -0.06), Color(0.74, 0.58, 0.18), Vector3(90, 30, 0), 6)
	_reparent_last(_flush(_vmat(0.7)), drawer)
	# Направляющие под столешницей, чтобы ящик не висел в воздухе
	for s in [-1.0, 1.0]:
		_bx(Vector3(0.44, 0.02, 0.02), Vector3(DESK_FRONT_X - 0.22, DRAWER_Y + DRAWER_H * 0.5 - 0.005, DRAWER_Z + s * (DRAWER_W * 0.5 + 0.012)), Color(0.22, 0.14, 0.09))
	_flush(_vmat(0.8))


# ── Фонарик в ящике: тот же, что в руке — тёмный металл, насечка, хромированное кольцо ──
func _build_flashlight() -> void:
	flashlight_prop = Node3D.new()
	flashlight_prop.name = "Flashlight"
	drawer.add_child(flashlight_prop)
	flashlight_prop.position = Vector3(-0.12, -DRAWER_H * 0.5 + 0.012 + 0.0185, 0.0)
	flashlight_prop.rotation_degrees = Vector3(0, 84, 0)
	var body := Color(0.3, 0.31, 0.33)
	var dark := Color(0.11, 0.11, 0.12)
	var x := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)   # ось фонарика вдоль X
	_base = x
	_cy(0.0175, 0.0175, 0.15, Vector3(0, -0.005, 0), body, Vector3.ZERO, 16)
	_cy(0.0185, 0.0185, 0.022, Vector3(0, -0.085, 0), dark, Vector3.ZERO, 16)
	_cy(0.012, 0.011, 0.008, Vector3(0, -0.099, 0), Color(0.06, 0.06, 0.065), Vector3.ZERO, 12)
	for i in range(9):
		_cy(0.0182, 0.0182, 0.0035, Vector3(0, -0.06 + i * 0.0085, 0), dark, Vector3.ZERO, 16)
	_cy(0.024, 0.018, 0.03, Vector3(0, 0.085, 0), body, Vector3.ZERO, 16)
	_cy(0.0275, 0.0245, 0.026, Vector3(0, 0.113, 0), body, Vector3.ZERO, 16)
	_cy(0.0285, 0.0285, 0.006, Vector3(0, 0.127, 0), Color(0.72, 0.72, 0.74), Vector3.ZERO, 16)
	_cy(0.0255, 0.0255, 0.003, Vector3(0, 0.1305, 0), Color(0.9, 0.88, 0.8), Vector3.ZERO, 16)
	_reparent_last(_flush(_vmat(0.35, 0.7)), flashlight_prop)


func _reparent_last(mi: MeshInstance3D, parent: Node3D) -> void:
	mi.reparent(parent, false)
	mi.transform = Transform3D.IDENTITY


func _add_spots() -> void:
	var spot_script := load("res://scripts/StorySpot.gd")
	_drawer_spot = spot_script.new()
	_drawer_spot.setup("Открыть ящик", _toggle_drawer, Vector3(0.08, 0.12, DRAWER_W + 0.04))
	_drawer_spot.set_meta("instant_use", true)
	add_child(_drawer_spot)
	_drawer_spot.global_position = Vector3(DESK_FRONT_X + 0.06, DRAWER_Y, DRAWER_Z)
	_drawer_spot.highlight = drawer


func _toggle_drawer() -> void:
	_open = not _open
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(drawer, "position:x", DESK_FRONT_X + (OPEN_BY if _open else 0.0), 0.45)
	tw.parallel().tween_property(_drawer_spot, "global_position:x", DESK_FRONT_X + 0.06 + (OPEN_BY if _open else 0.0), 0.45)
	_drawer_spot.hint = "[ЛКМ / E]  " + ("Закрыть ящик" if _open else "Открыть ящик")
	_play("res://assets/audio/cutscenes/hand_slide_wood.wav", -10.0, 1.15 if _open else 0.95)
	if _open and is_instance_valid(flashlight_prop) and flashlight_prop.visible:
		tw.tween_callback(_add_take_spot)
	elif not _open and is_instance_valid(_take_spot):
		_take_spot.queue_free()


func _add_take_spot() -> void:
	if not _open or is_instance_valid(_take_spot):
		return
	_take_spot = load("res://scripts/StorySpot.gd").new()
	_take_spot.setup("Взять фонарик", _take_flashlight, Vector3(0.22, 0.08, 0.12))
	flashlight_prop.add_child(_take_spot)
	_take_spot.position = Vector3.ZERO
	_take_spot.highlight = flashlight_prop


func _take_flashlight() -> void:
	flashlight_prop.visible = false
	if is_instance_valid(_take_spot):
		_take_spot.queue_free()
	_play("res://assets/audio/bag_item_select.wav", -6.0, 1.0)
	GameManager.give_flashlight(false)
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		GameManager.ui_ref.call("show_hint", "Фонарик убран в рюкзак. Достать — [1] или [F]", 4.0)


func _play(path: String, db: float, pitch: float) -> void:
	var st: AudioStream = load(path)
	if st == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = 3.0
	add_child(p)
	p.global_position = drawer.global_position
	p.play()
	p.finished.connect(p.queue_free)
