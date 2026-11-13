extends "res://scripts/BasementCreature.gd"

# Существо в доме, глава 3. Обходит дом по кругу (кухня → коридор → лестница → второй
# этаж → обратно), у дверей останавливается и слушает: стук копыт пропадает. Громкий звук
# (доски на окне, скрипучая доска, часы) ведёт его туда. Увидит — погоня, ИИ скинволкера.
# Поймает — Итан начинает с последней точки: двор, кладовка или комната отца.

const ROUTE := [
	Vector3(-64.0, 0.16, -229.0),   # кухня
	Vector3(-60.0, 0.16, -228.0),   # дверь кухни
	Vector3(-56.5, 0.16, -221.5),   # коридор у входа
	Vector3(-56.0, 3.48, -230.0),   # лестница наверх, второй этаж
	Vector3(-57.8, 3.48, -228.0),   # у комнаты Сэма
	Vector3(-64.5, 3.48, -228.5),   # комната Сэма
	Vector3(-57.8, 3.48, -222.5),   # у комнаты отца: стоит и слушает
	Vector3(-55.0, 3.48, -220.5),   # конец коридора
	Vector3(-55.0, 0.16, -229.5),   # обратно вниз
]
const PATROL_SPEED := 2.1
const LISTEN_TIME := Vector2(1.2, 3.2)
const LONG_LISTEN_AT := 6         # у двери отца стоит дольше
const LONG_LISTEN := Vector2(3.0, 5.5)
const SENSE_EVERY := 0.1
const CALM_BEFORE_PATROL := 1.5

var route_i := 2
var mode := "patrol"
var checkpoint := Vector3(-59.2, 0.15, -239.35)
var _wait_left := 0.0
var _sense_left := 0.0
var _calm := 0.0


func begin(player: CharacterBody3D) -> void:
	_player = player
	GameManager.is_godmode = true
	enemy = load(ENEMY_SCENE).instantiate()
	enemy.name = "HouseSkinwalker"
	chapter.get_parent().add_child(enemy)
	GameManager.enemy_ref = enemy
	_appear(ROUTE[route_i])
	_set_ai(false)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _enabled or not is_instance_valid(_player) or not is_instance_valid(enemy):
		return
	if bool(chapter.get("_busy")) or _player.get("is_in_cutscene") == true:
		return
	if mode == "patrol":
		_patrol(delta)
	else:
		_hunt_mode(delta)
	_check_catch(delta)


func _patrol(delta: float) -> void:
	# Шум или подозрение уже переключили ИИ: дальше он сам
	if int(enemy.get("state")) not in [0, 1]:
		_to_ai()
		return
	_sense_left -= delta
	if _sense_left <= 0.0:
		_sense_left = SENSE_EVERY
		enemy.call("_check_senses")
		enemy.call("_check_hiding_nearby")
		if int(enemy.get("state")) not in [0, 1]:
			_to_ai()
			return
	if _wait_left > 0.0:
		_wait_left -= delta
		_puppet(delta, null, 0.0)
		return
	var target: Vector3 = ROUTE[route_i]
	_puppet(delta, target, PATROL_SPEED)
	var pos: Vector3 = enemy.global_position
	if _flat(pos, target) < 0.7 and absf(pos.y - target.y) < 0.8:
		var range_v: Vector2 = LONG_LISTEN if route_i == LONG_LISTEN_AT else LISTEN_TIME
		_wait_left = randf_range(range_v.x, range_v.y)
		route_i = (route_i + 1) % ROUTE.size()


func _to_ai() -> void:
	mode = "ai"
	_calm = 0.0
	_set_ai(true)


# ИИ ищет или гонится; успокоился — возвращается на обход с ближайшей точки
func _hunt_mode(delta: float) -> void:
	if int(enemy.get("state")) in [0, 1]:
		_calm += delta
		if _calm >= CALM_BEFORE_PATROL:
			mode = "patrol"
			route_i = _nearest_route_point()
			_set_ai(false)
	else:
		_calm = 0.0


func _nearest_route_point() -> int:
	var best := 0
	var best_d := INF
	for i in range(ROUTE.size()):
		var p: Vector3 = ROUTE[i]
		var d: float = p.distance_to(enemy.global_position) + absf(p.y - enemy.global_position.y) * 3.0
		if d < best_d:
			best_d = d
			best = i
	return best


func _caught() -> void:
	catches += 1
	_set_ai(false)
	enemy.call("reset_ai")
	enemy.set("_clock", 99.0)
	# Уходит в дальний от игрока конец обхода
	var far := 0
	var far_d := -1.0
	for i in range(ROUTE.size()):
		var d: float = (ROUTE[i] as Vector3).distance_to(checkpoint)
		if d > far_d:
			far_d = d
			far = i
	enemy.global_position = ROUTE[far]
	enemy.velocity = Vector3.ZERO
	route_i = (far + 1) % ROUTE.size()
	mode = "patrol"
	chapter.call("caught", checkpoint)
