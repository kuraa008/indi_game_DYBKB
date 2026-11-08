extends Control

# Просмотр всех сюжетных кат-сцен по порядку (для команды и проверки).
# Запуск: открыть scenes/cutscenes/CutsceneGallery.tscn и нажать F6.
# Каждая кат-сцена после конца (или Esc) возвращает сюда.

const SELF := "res://scenes/cutscenes/CutsceneGallery.tscn"
const DIR := "res://scenes/cutscenes/"
const ITEMS := [
	["ПРОЛОГ · Предыстория (текст)", "Backstory", {}],
	["ПРОЛОГ · Звонок из полиции (после «Ответить»)", "PoliceCall", {}],
	["ПРОЛОГ · Дорога, заправка, авария (вступление в игре)", "@intro", {}],
	["ГЛАВА 1 · За углом гаража", "Ch1Corner", {}],
	["Финал карты «Шоссе» → 1-й уровень (существо уносит Итана)", "@epilogue", {}],
	["ГЛАВА 2 · Пробуждение в подвале (≈12 с)", "Ch2Wake", {}],
	["ГЛАВА 2 · Лаз и крышка: выход во двор", "Ch2Tunnel", {}],
	["ГЛАВА 3 · «Это… моё» (комната отца)", "Ch3Mine", {}],
	["ГЛАВА 4 · Итан находит Сэма", "Ch4Sam", {}],
	["ГЛАВА 5 · Имя. Смерть Крейна", "Ch5Crane", {}],
	["ГЛАВА 5 · Рассвет у дома", "Ch5Dawn", {}],
	["ФИНАЛ · Заправка: разговор, «Марта…», отъезд", "Finale", {"part": "all"}],
	["ФИНАЛ · Секретный кадр (если обернуться)", "Finale", {"part": "walk_secret"}],
	["ПЛОХАЯ КОНЦОВКА · Семья в сборе", "BadEnding", {}],
]


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.04)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 120
	box.offset_right = -120
	box.offset_top = 40
	box.offset_bottom = -40
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Кат-сцены · Escape in Skinwalker (Jan-ky)"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Esc внутри кат-сцены — вернуться сюда. Голоса — черновые (Windows TTS), их заменит запись."
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(0.55, 0.58, 0.64))
	box.add_child(hint)
	for it in ITEMS:
		var b := Button.new()
		b.text = it[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 18)
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(_open.bind(it[1], it[2]))
		box.add_child(b)
	var back := Button.new()
	back.text = "← В главное меню"
	back.custom_minimum_size = Vector2(0, 34)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	box.add_child(back)


func _open(id: String, extra: Dictionary) -> void:
	var gm := get_node_or_null("/root/GameManager")
	match id:
		"@intro":
			if gm:
				gm.set("intro_epilogue", false)
			get_tree().change_scene_to_file("res://scenes/IntroCutscene.tscn")
		"@epilogue":
			if gm:
				gm.set("intro_epilogue", true)
			get_tree().change_scene_to_file("res://scenes/IntroCutscene.tscn")
		_:
			Cutscene.play(get_tree(), DIR + id + ".tscn", SELF, extra)
