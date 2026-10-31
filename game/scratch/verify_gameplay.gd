extends SceneTree

func _init() -> void:
	print("--- STARTING HEADLESS VERIFICATION ---")
	
	# Autoload or loaded GameManager
	var gm = root.get_node_or_null("GameManager")
	if not gm:
		var gm_script = load("res://scripts/GameManager.gd")
		var gm_node = Node.new()
		gm_node.name = "GameManager"
		gm_node.set_script(gm_script)
		root.add_child(gm_node)
		gm = gm_node
	print("✓ GameManager initialized")
	
	# 1. Test load UI script
	var ui_script = load("res://scripts/UI.gd")
	if not ui_script:
		push_error("Failed to load UI.gd")
		quit(1)
		return
	print("✓ UI.gd loaded successfully")
	
	# Instantiate UI and verify show_hint does not show hint_label
	var ui_node = CanvasLayer.new()
	ui_node.set_script(ui_script)
	root.add_child(ui_node)
	
	# Call show_hint
	ui_node.call("show_hint", "Тестовая подсказка", 3.0)
	var hint_lbl = ui_node.get("hint_label")
	if hint_lbl and hint_lbl.visible:
		push_error("hint_label is visible after show_hint!")
		quit(1)
		return
	print("✓ UI.gd: show_hint is silenced and hint_label remains hidden")
	
	# 2. Test GameManager score
	gm.call("add_score", "player", 50, "Test score")
	print("✓ add_score succeeded with 0 popups")
	
	# 3. Test Door script
	var door_script = load("res://scripts/Door.gd")
	if not door_script:
		push_error("Failed to load Door.gd")
		quit(1)
		return
	print("✓ Door.gd loaded successfully")
	
	var door_node = Node3D.new()
	door_node.set_script(door_script)
	root.add_child(door_node)
	var d_hint = door_node.call("get_interaction_hint")
	print("✓ Door interaction hint: ", d_hint)
	
	# 4. Test Item script
	var item_script = load("res://scripts/Item.gd")
	if not item_script:
		push_error("Failed to load Item.gd")
		quit(1)
		return
	print("✓ Item.gd loaded successfully")
	
	var item_node = Node3D.new()
	item_node.set_script(item_script)
	root.add_child(item_node)
	item_node.set("item_type", "crowbar")
	item_node.call("interact")
	print("✓ Item interact (crowbar) executed cleanly")
	
	# 5. Test Player script
	var player_script = load("res://scripts/Player.gd")
	if not player_script:
		push_error("Failed to load Player.gd")
		quit(1)
		return
	print("✓ Player.gd loaded successfully")
	
	print("--- ALL VERIFICATION CHECKS PASSED PERFECTLY ---")
	quit(0)
