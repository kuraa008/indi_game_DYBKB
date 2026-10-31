extends Node3D

func _ready() -> void:
	GameManager.graphics_quality = "ultra"
	GameManager.set_process(false)
	var main = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().process_frame
	get_tree().current_scene = main
	await get_tree().create_timer(1.0).timeout
	for i in range(4):
		await get_tree().physics_frame
	GameManager.is_godmode = true
	GameManager.player_ref.set_physics_process(false)
	GameManager.enemy_ref.set_physics_process(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var player = GameManager.player_ref
	player.global_position = Vector3(-157, 0.35, -33)
	player.camera.global_position = Vector3(-157, 1.8, -33)
	player.camera.look_at(Vector3(-171, 1.6, -35))
	for i in range(40):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var outdoor := get_viewport().get_texture().get_image()
	print("CAPTURE OUTDOOR: ", outdoor.save_png("res://scratch/high_outdoor.png"))
	player.global_position = Vector3(-166, 0.35, -32)
	player.camera.global_position = Vector3(-166, 1.8, -32)
	player.camera.look_at(Vector3(-164, 1.4, -34))
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var indoor := get_viewport().get_texture().get_image()
	print("CAPTURE INDOOR: ", indoor.save_png("res://scratch/high_indoor.png"))
	get_tree().quit()
