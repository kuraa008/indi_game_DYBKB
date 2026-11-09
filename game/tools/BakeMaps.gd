extends Node

# Собирает модели окружения карт заранее и кладёт в assets/map_cache: с ними карты грузятся быстро.
# Запускать в окне (без --headless) перед сборкой exe, если менялись скрипты окружения:
#   Godot --path . res://tools/BakeMaps.tscn

const MAPS := [
	["Квартира", false],
	["Улица", false],
	["Шоссе", false],
	["Шоссе", true],
	["Дом_Крейна", false],
	["Лесная_тропа", false],
]


func _ready() -> void:
	var runner := Node.new()
	runner.set_script(load("res://tools/BakeRunner.gd"))
	runner.set("maps", MAPS)
	get_tree().root.add_child.call_deferred(runner)
