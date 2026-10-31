extends Node
## Local diagnostic report for human/LLM review. Does not upload or train anything.

var samples: Array[Dictionary] = []
var events: Array[Dictionary] = []
var sample_timer: float = 0.0
var tracked_enemy_id: int = 0

func _ready() -> void:
	GameManager.noise_made.connect(_on_noise)
	GameManager.pain_triggered.connect(_on_pain)

func _process(delta: float) -> void:
	var enemy = GameManager.enemy_ref
	if not is_instance_valid(enemy):
		return
	if tracked_enemy_id != enemy.get_instance_id():
		tracked_enemy_id = enemy.get_instance_id()
		samples.clear()
		events.clear()
		sample_timer = 0.0
	sample_timer += delta
	if sample_timer >= 0.5:
		sample_timer = 0.0
		samples.append(_snapshot())
		if samples.size() > 240:
			samples.pop_front()

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_3 and event.physical_keycode != KEY_3:
		return
	var scene = get_tree().current_scene
	if scene == null or scene.name == "DebugEditor" or not is_instance_valid(GameManager.enemy_ref):
		return
	var focus = get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	save_report()
	get_viewport().set_input_as_handled()

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _snapshot() -> Dictionary:
	var data: Dictionary = {"time_seconds": GameManager.timer_elapsed}
	var enemy = GameManager.enemy_ref
	if is_instance_valid(enemy):
		data["enemy_position"] = _vec(enemy.global_position)
		data["enemy_velocity"] = _vec(enemy.velocity)
		data["controlled_by"] = "ai" if enemy.has_method("_nav_move_to") else "human_demonstrator"
		if enemy.has_method("_nav_move_to"):
			for key in ["state", "ai_thought", "state_timer", "stuck_timer", "navigation_stall_time", "navigation_recoveries"]:
				data[key] = enemy.get(key)
			data["target"] = _vec(enemy.get("last_nav_target"))
			data["last_known_player_position"] = _vec(enemy.get("last_known_player_pos"))
			var path: Array = []
			for point in enemy.get("current_debug_path"):
				path.append(_vec(point))
			data["navigation_path"] = path
	var player = GameManager.player_ref
	if is_instance_valid(player):
		data["player_position"] = _vec(player.global_position)
		data["player_velocity"] = _vec(player.velocity)
		data["player_hiding"] = player.get("is_hiding")
		if player.has_method("_choose_escape_target"):
			data["survivor_ai"] = {"state": player.get("state"), "threat_age": player.get("threat_age"), "oxygen": player.get("oxygen"), "no_progress_time": player.get("no_progress_time"), "escape_target": _vec(player.get("escape_target"))}
		if player.has_method("get_breath_noise_level"):
			data["breath_noise"] = player.call("get_breath_noise_level")
	return data

func _event(data: Dictionary) -> void:
	data["time_seconds"] = GameManager.timer_elapsed
	events.append(data)
	if events.size() > 300:
		events.pop_front()

func _on_noise(pos: Vector3, radius: float) -> void:
	_event({"event": "heard_noise", "position": _vec(pos), "radius": radius})

func _on_pain(who: String, penalty: int, reason: String) -> void:
	_event({"event": "pain", "recipient": who, "penalty": penalty, "reason": reason})

func save_report(output_path: String = "") -> String:
	var report: Dictionary = {
		"schema_version": 1,
		"purpose": "Описание ожидаемого поведения и запись фактического поведения ИИ для анализа человеком, Gemini или ChatGPT.",
		"created_at": Time.get_datetime_string_from_system(),
		"map": GameManager.active_map_path,
		"coordinates": "[x, y, z] в метрах; Y направлен вверх",
		"expected_behavior": [
			"В шкафу камера находится внутри полого корпуса; обзор через настоящую щель. Вход на глазах у врага не стирает его память.",
			"Бот-выживший выбирает достижимый путь с удалением от угрозы и разрывом видимости, не прячется на глазах у врага, задерживает дыхание с ограниченным запасом воздуха.",
			"Враг патрулирует и занимается мебелью. Увидев игрока, преследует; после 10 секунд без видимости ищет 18 секунд, затем успокаивается.",
			"Метка ШУМ появляется только в месте удара брошенной бутылки и видна сквозь стены. Шаги и дыхание не рисуют метку под игроком.",
			"Враг реагирует на слышимые звуки и зрение, обходит стены по навигационной сетке, ищет у последней известной позиции.",
			"При отсутствии прогресса более 0.85 секунды во время движения ИИ перестраивает физически проходимый маршрут. Ожидание двери или расчёта пути ограничено по времени.",
			"ИИ не должен бесконечно давить в стену или телепортироваться сквозь препятствие при обходе.",
			"Запертая дверь остаётся препятствием. Незакрытую на замок дверь открывает; подходящие небольшие предметы может сдвигать после проверки коллизий.",
			"Полигон сохраняет только запись сессии. Игровой ИИ не загружает профили обучения; режиссёр не подсказывает ему скрытое положение игрока."
		],
		"state_names": ["PATROL", "ROUTINE", "ALERT", "HUNT", "SEARCH", "INVESTIGATE_BASEMENT", "RAGE", "AMBUSH", "INSPECT_HIDING"],
		"sampling": {"interval_seconds": 0.5, "max_samples": 240, "note": "Последние 120 секунд; экспорт не меняет поведение ИИ и не обучает модель автоматически."},
		"current": _snapshot(),
		"history": samples,
		"events": events,
		"review_questions": ["Где ИИ перестал двигаться к цели?", "Достижима ли цель по navigation_path?", "Сработал ли обход?", "Соответствует ли реакция правилам expected_behavior?"]
	}
	var tuning: Dictionary = {}
	if is_instance_valid(GameManager.enemy_ref) and GameManager.enemy_ref.has_method("_nav_move_to"):
		for key in ["speed_patrol", "speed_search", "speed_hunt", "speed_rage", "hearing_walk", "hearing_run", "hearing_normal", "hearing_exhale", "sight_range", "hunt_lose_time", "search_duration"]:
			tuning[key] = GameManager.enemy_ref.get(key)
	report["tuning"] = tuning
	var scene = get_tree().current_scene
	if scene and scene.has_method("_build_demonstration_profile"):
		report["player_demonstration"] = scene.call("_build_demonstration_profile")
		report["demonstration_coordinates"] = "hunter_pos и bot_pos: [x, z] в метрах; это демонстрация желаемой тактики человеком, а не наблюдение ИИ."
	var folder: String = ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir()
	var path: String = folder.path_join("ai.json")
	if not output_path.is_empty():
		path = output_path
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		path = ProjectSettings.globalize_path("user://ai.json")
		file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Не удалось сохранить ai.json: %s" % FileAccess.get_open_error())
		if is_instance_valid(GameManager.ui_ref):
			GameManager.ui_ref.call("show_hint", "Не удалось записать ai.json: нет доступа к папке.", 5.0)
		return ""
	file.store_string(JSON.stringify(report, "\t", false))
	file.close()
	print("AI report saved: ", path)
	if is_instance_valid(GameManager.ui_ref):
		GameManager.ui_ref.call("show_hint", "Отчёт ИИ сохранён: " + path, 6.0)
	return path
