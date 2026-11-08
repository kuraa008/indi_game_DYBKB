extends RefCounted

# Цепочка пролога (Jan-ky), по сюжету Досыма:
#   меню → «Предыстория» → карта «Квартира» (игра) → телефон, «Ответить» → «Звонок» →
#   карта «Улица» (игра, объявления) → машина → IntroCutscene (дорога, заправка, авария) →
#   карта «Шоссе».
# Каждый переход — отдельная сцена, поэтому карта для Main.tscn кладётся в
# GameManager.active_map_path заранее (Main читает её в _ready).

const MAIN := "res://scenes/Main.tscn"
const APARTMENT := "res://scenes/Квартира.json"
const STREET := "res://scenes/Улица.json"
const INTRO := "res://scenes/IntroCutscene.tscn"
const BACKSTORY := "res://scenes/cutscenes/Backstory.tscn"
const POLICE_CALL := "res://scenes/cutscenes/PoliceCall.tscn"
const CH2_WAKE := "res://scenes/cutscenes/Ch2Wake.tscn"
const CH2_TUNNEL := "res://scenes/cutscenes/Ch2Tunnel.tscn"


# «Новая игра» из меню: предыстория, потом квартира
static func start_new_game(tree: SceneTree) -> void:
	var gm := tree.root.get_node_or_null("/root/GameManager")
	if gm:
		gm.set("active_map_path", APARTMENT)
		gm.set("intro_cutscene_played", false)
		gm.set("intro_epilogue", false)
		gm.set("wake_in_basement", false)
	Cutscene.play(tree, BACKSTORY, MAIN)


# Игрок ответил на звонок в квартире: кат-сцена «Звонок», потом улица
static func answer_call(tree: SceneTree) -> void:
	var gm := tree.root.get_node_or_null("/root/GameManager")
	if gm:
		gm.set("active_map_path", STREET)
	Cutscene.play(tree, POLICE_CALL, MAIN, {"from_gameplay": true})


# Игрок сел в машину на улице: дорога, заправка, авария (IntroCutscene) → «Шоссе»
static func drive_away(tree: SceneTree) -> void:
	var gm := tree.root.get_node_or_null("/root/GameManager")
	if gm:
		gm.set("intro_cutscene_played", false)
		gm.set("intro_epilogue", false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	tree.change_scene_to_file(INTRO)
