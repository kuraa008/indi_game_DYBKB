extends Node

# Снимок панели F1 в доме (глава 3). Запуск с окном: --path game res://scratch/shot_f1.tscn


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	GameManager.reset_state()
	GameManager.active_map_path = "res://scenes/Шоссе.json"
	GameManager.wake_in_basement = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	await wait(2.0)
	var scene := get_tree().current_scene
	var player: CharacterBody3D = GameManager.player_ref
	while player.get("is_in_cutscene") == true:
		await wait(0.5)
	scene.get_node("BasementChapter")._finish_basement()
	await wait(0.5)
	player.global_position = Vector3(-56.5, 0.16, -229.5)
	player.set_process_unhandled_input(false)
	var overlay = GameManager.get("debug_overlay")
	if overlay:
		overlay.call("toggle_hud")
	await wait(1.5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://f1.png")
	get_tree().quit()
