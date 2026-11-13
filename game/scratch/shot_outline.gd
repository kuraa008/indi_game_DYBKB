extends Node

# Снимок обводки предмета под прицелом. Запуск с окном: --path game res://scratch/shot_outline.tscn


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	_start.call_deferred()


func _start() -> void:
	reparent(get_tree().root)
	GameManager.reset_state()
	GameManager.active_map_path = "res://scenes/Квартира.json"
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	await wait(2.5)
	var player: CharacterBody3D = GameManager.player_ref
	player.set_process_unhandled_input(false)
	var head: Node3D = player.get("head")
	var targets := [[Vector3(2.7, 1.0, -4.4), Vector3(1.4, 0.03, -4.4), "user://outline_door.png"],
		[Vector3(1.12, 0.02, -3.07), Vector3(1.1, 0.03, -4.2), "user://outline_sofa.png"]]
	for t in targets:
		player.global_position = t[1]
		var to: Vector3 = t[0] - (t[1] + Vector3(0, head.position.y, 0))
		player.rotation.y = atan2(-to.x, -to.z)
		head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
		await wait(0.6)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(t[2])
		var hl = player.get("current_highlighted_node")
		print("HL ", hl, " ", (hl.get("material_overlay") if hl is GeometryInstance3D else "-"), " inter ", player.call("_get_interactable"))
	get_tree().quit()
