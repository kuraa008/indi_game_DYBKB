extends Node3D

# Глава 4 в игре: Сэм в доме Крейна (Jan-ky; ставит Main на картах «Дом Крейна» и «Лесная тропа»
# рядом с CraneHouseMap Досыма).
#   — Сэм сидит на стуле «Старший», руки привязаны ремнями из оленьей кожи;
#   — задачи на экране: дойти до дома → войти → освободить Сэма;
#   — у Сэма [ЛКМ / E] «Перерезать ремни» → кат-сцена Ch4Sam поверх игры;
#   — после неё Сэм сидит у стены рядом с очагом, на столе его надпись, Итан стоит рядом.
# Дальше идёт глава 5. Для неё: сигнал sam_freed, флаг freed и GameManager.get_meta("ch4_sam_freed").

signal sam_freed

const CH4 := "res://scenes/cutscenes/Ch4Sam.tscn"
const Spot := preload("res://scripts/StorySpot.gd")
const AFTER_POS := Vector3(-1.35, 0.15, 1.3)   # где Итан стоит после кат-сцены
const NEAR := 9.0                                # «дошёл до дома»

var freed := false
var sam: PlayerModel
var straps: Array = []
var _spot: Area3D
var _missions: MissionTracker
var _busy := false


func _ready() -> void:
	name = "CraneHouseSam"
	var tied := CraneHouse.sam_tied(self)
	sam = tied.sam
	straps = tied.straps
	_spot = Spot.new()
	_spot.setup("Перерезать ремни", _on_cut, Vector3(0.85, 1.3, 0.85))
	add_child(_spot)
	_spot.position = CraneHouse.ELDER + Vector3(0, 0.75, 0)
	_missions = MissionTracker.new()
	var by_trail: bool = "лесная" in GameManager.active_map_path.to_lower()
	_missions.setup([
		{"text": "Иди по меткам к дому Крейна" if by_trail else "Подойди к дому Крейна", "done": func(): return _dist() < NEAR},
		{"text": "Войди в дом", "done": func(): return _inside()},
		{"text": "Освободи Сэма", "done": func(): return freed},
	])
	add_child(_missions)


func _player() -> Node3D:
	var p = GameManager.player_ref
	return p if is_instance_valid(p) else null


func _dist() -> float:
	var p := _player()
	return Vector2(p.global_position.x, p.global_position.z).length() if p else 999.0


func _inside() -> bool:
	var p := _player()
	return p != null and absf(p.global_position.x) < 2.85 and absf(p.global_position.z) < 2.35


func _on_cut() -> void:
	if _busy or freed:
		return
	var p := _player()
	if p == null:
		return
	_busy = true
	p.set("is_in_cutscene", true)
	p.set("velocity", Vector3.ZERO)
	var view := get_viewport().get_camera_3d()
	var from: Vector3 = view.global_position if view else CraneHouse.DOOR
	await Cutscene.overlay(self, CH4, {"from_gameplay": true, "cam_pos": from})
	_after()
	p.global_position = AFTER_POS
	var look := CraneHouse.SAM_WALL
	p.rotation.y = atan2(AFTER_POS.x - look.x, AFTER_POS.z - look.z)
	var head = p.get("head")
	if head is Node3D:
		head.rotation.x = -0.55   # Сэм сидит на полу: Итан смотрит на него сверху
	p.set("velocity", Vector3.ZERO)
	p.set("is_in_cutscene", false)
	_busy = false
	sam_freed.emit()


# То, чем кончилась кат-сцена: ремни срезаны, Сэм у очага, на пыльном столе надпись
func _after() -> void:
	freed = true
	GameManager.set_meta("ch4_sam_freed", true)
	_spot.queue_free()
	for i in straps.size():
		var st: Node3D = straps[i]
		st.position = CraneHouse.ELDER + Vector3(0.24 * (1.0 if i else -1.0), 0.03, 0.12 + 0.07 * i)
		st.rotation_degrees = Vector3(84, 35 + 110 * i, 0)
	CraneHouse.sam_by_hearth(sam)
	CraneHouse.dust_writing(self).text = CraneHouse.SAM_WORDS
