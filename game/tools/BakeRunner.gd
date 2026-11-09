extends Node

var maps: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var kit = load("res://scripts/ApartmentKit.gd")
	kit.cache_bake = true
	await get_tree().create_timer(1.0).timeout
	for entry: Array in maps:
		GameManager.active_map_path = "res://scenes/%s.json" % entry[0]
		GameManager.wake_in_basement = entry[1]
		var old := get_tree().current_scene
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		await get_tree().process_frame
		while get_tree().current_scene == null or get_tree().current_scene == old:
			await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var size := 0
		if FileAccess.file_exists(kit._cache_path):
			size = FileAccess.open(kit._cache_path, FileAccess.READ).get_length()
		print("BAKED ", entry[0], " wake=", entry[1], " ", size / 1024, "KB")
	kit.cache_bake = false
	print("BAKE DONE")
	get_tree().quit()
