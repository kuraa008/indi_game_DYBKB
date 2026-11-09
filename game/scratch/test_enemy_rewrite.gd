extends Node3D

var failures := 0
var enemy: CharacterBody3D
var player: CharacterBody3D
var wall: StaticBody3D

func check(value: bool, message: String) -> void:
	print(("PASS: " if value else "FAIL: ") + message)
	if not value:
		failures += 1

func box(pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = pos
	add_child(body)
	return body

func drive(goal: Vector3, frames: int = 1500) -> bool:
	enemy.navigator.clear()
	enemy._path.clear()
	enemy._path_target = Vector3.INF
	for i in range(frames):
		await get_tree().physics_frame
		var dt := 1.0 / 60.0
		enemy.navigator.tick(dt)
		enemy.world_actions.tick(dt)
		enemy._go(goal, 3.5, dt)
		enemy.velocity.y = -0.5 if enemy.is_on_floor() else enemy.velocity.y - 18.0 * dt
		enemy._try_step(Vector3(enemy.velocity.x, 0, enemy.velocity.z) * dt)
		enemy.move_and_slide()
		if enemy.global_position.distance_to(goal) < 0.65:
			return true
	print("route timeout: ", enemy.global_position, " pending=", enemy.navigator.pending, " path=", enemy._path)
	return false

func _ready() -> void:
	GameManager.set_process(false)
	GameManager.reset_state()
	GameManager.is_godmode = true
	box(Vector3(0, -0.2, 0), Vector3(28, 0.4, 28))
	wall = box(Vector3(0, 1.4, 0), Vector3(0.4, 2.8, 8))
	enemy = load("res://scenes/Enemy.tscn").instantiate()
	enemy.position = Vector3(-4, 0.03, 0)
	add_child(enemy)
	enemy.set_physics_process(false)
	GameManager.enemy_ref = enemy
	player = CharacterBody3D.new()
	player.position = Vector3(4, 0.03, 0)
	add_child(player)
	GameManager.player_ref = player
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not enemy._can_see_player(), "A solid wall blocks sight")
	var reached: bool = await drive(Vector3(4, 0.03, 0))
	check(reached, "Physical A* walks around an eight-metre wall")
	check(enemy.global_position.x > 3.0, "Enemy finishes on the other side without teleporting")
	# Change the geometry while the same NPC stays alive.
	var dynamic_wall := box(Vector3(5, 1.4, 0), Vector3(0.4, 2.8, 5))
	await get_tree().physics_frame
	reached = await drive(Vector3(8, 0.03, 0))
	check(reached, "A new physical obstruction is included in the next route")
	# Start at real body clearance, inside the larger planning capsule's margin.
	for contact in [Vector3(-0.48, 0.03, 0), Vector3(0.48, 0.03, 0), Vector3(0, 0.03, 4.28)]:
		enemy.global_position = contact
		enemy.velocity = Vector3.ZERO
		enemy.navigator.blocked_spots.clear()
		await get_tree().physics_frame
		var destination := Vector3(-4, 0.03, 0) if contact.x >= 0.0 else Vector3(4, 0.03, 0)
		check(await drive(destination), "Escapes wall contact at " + str(contact))
	wall.queue_free()
	dynamic_wall.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Only one doorway connects two halves of the floor; walking around is impossible.
	box(Vector3(-7.4, 1.4, -6), Vector3(13.2, 2.8, 0.4))
	box(Vector3(7.4, 1.4, -6), Vector3(13.2, 2.8, 0.4))
	var door := PrefabBuilder.build_prefab("door_simple", Vector3(1.6, 2.2, 0.15), Color.BROWN, false)
	door.position = Vector3(0, 0, -6)
	add_child(door)
	var panel: Node = door.find_child("Panel", true, false)
	var controller: Node = panel.call("_door_controller")
	enemy.global_position = Vector3(0, 0.03, -3)
	enemy.velocity = Vector3.ZERO
	enemy.navigator.blocked_spots.clear()
	await get_tree().physics_frame
	check(await drive(Vector3(0, 0.03, -9)), "Enemy opens and crosses a closed house door")
	check(controller.get("is_open") == true, "Door root and leaf use the same controller")
	controller.call("interact", player)
	await get_tree().create_timer(0.6).timeout
	enemy.navigator.blocked_spots.clear()
	check(await drive(Vector3(0, 0.03, -3)), "Enemy reopens the house door from the other side")
	# Chasing memory depends on vision, not repeated hearing events.
	enemy._set_state(enemy.State.HUNT)
	enemy.last_known_player_pos = Vector3(-4, 0.03, 0)
	enemy.time_since_last_seen = enemy.HUNT_MEMORY - 0.01
	# Звук уточняет цель погони, но не продлевает память
	enemy.on_noise_heard(Vector3(-6, 0.03, 0), 30.0)
	enemy._do_hunt(0.01)
	check(enemy.state == enemy.State.HUNT, "Just before memory runs out it still follows the last sighting")
	enemy.time_since_last_seen = enemy.HUNT_MEMORY + 0.01
	enemy._do_hunt(0.01)
	check(enemy.state == enemy.State.SEARCH, "When memory runs out it switches to searching")
	enemy.state_timer = 60.0
	enemy._do_search(0.01)
	check(enemy.state == enemy.State.PATROL, "Unsuccessful search ends and the enemy calms down")
	check(enemy.uses_fixed_behavior() and enemy.speed_hunt == enemy.SPEED_HUNT, "Polygon profiles do not change the new enemy")
	# Free a player while mirrors/UI still have access to GameManager.
	player.queue_free()
	await get_tree().physics_frame
	check(enemy._player() == null, "Freed player references are safe")
	GameManager.player_ref = null
	GameManager.enemy_ref = null
	print("ENEMY REWRITE FAILURES: ", failures)
	get_tree().quit(0 if failures == 0 else 1)
