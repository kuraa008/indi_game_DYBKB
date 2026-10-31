extends RefCounted
## Only small, explicitly allowed props can move. Never move a collider's scene parent.
const MOVABLE := ["prop_chair", "prop_crate", "prop_barrel", "prop_trash_bin", "prop_nightstand"]
var actor: CharacterBody3D
var jobs: Array[Dictionary] = []
var movable: Array[Node3D] = []
var door_timer := 0.0
var push_timer := 0.0

func _init(owner_body: CharacterBody3D) -> void:
	actor = owner_body

func scan() -> void:
	jobs.clear()
	movable.clear()
	var scene := actor.get_tree().current_scene
	if not is_instance_valid(scene):
		return
	for node in scene.find_children("*", "Node3D", true, false):
		if node.has_meta("prefab_type"):
			var prefab_kind := str(node.get_meta("prefab_type"))
			if prefab_kind in MOVABLE:
				var parts := node.find_children("*", "PhysicsBody3D", true, false)
				if not parts.is_empty():
					var part: PhysicsBody3D = parts[0]
					# A prefab body owns its visuals and collider; only this body moves.
					if not movable.has(part):
						_register_movable(part)
			elif prefab_kind in ["prop_tv", "prop_crt_tv", "prop_fridge", "prop_toilet", "prop_light_switch"]:
				jobs.append({"node": node, "action": prefab_kind})
			continue
		var kind := str(node.get_meta("item_type", node.get_meta("prop_type", "")))
		if kind in MOVABLE and node is PhysicsBody3D and not movable.has(node):
			_register_movable(node)

func _register_movable(node: PhysicsBody3D) -> void:
	movable.append(node)
	jobs.append({"node": node, "action": "tidy"})
	if not node.has_meta("ai_home"):
		node.set_meta("ai_home", node.global_position)

func tick(delta: float) -> void:
	door_timer = maxf(0.0, door_timer - delta)
	push_timer = maxf(0.0, push_timer - delta)

func open_ahead(direction: Vector3) -> bool:
	if door_timer > 0.0:
		return false
	var side := Vector3(-direction.z, 0, direction.x)
	# Cover the width of the body, including oblique approaches to a wide leaf.
	for lateral in [0.0, -0.30, 0.30]:
		var origin: Vector3 = actor.global_position + Vector3.UP + side * lateral
		var q := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.85, 1, [actor.get_rid()])
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty():
			continue
		var node: Node = hit.collider
		for i in range(5):
			if not is_instance_valid(node):
				break
			if node.has_method("open_by_enemy"):
				if node.has_method("_door_controller"):
					node = node.call("_door_controller")
				if node.call("is_door_locked") or node.get("is_open") == true:
					break
				door_timer = 0.25
				return node.call("open_by_enemy", actor) == true
			node = node.get_parent()
	return false

func push_ahead(direction: Vector3) -> bool:
	if push_timer > 0.0:
		return false
	push_timer = 0.65
	for prop in movable:
		if not is_instance_valid(prop) or prop.is_queued_for_deletion():
			continue
		var to_prop := prop.global_position - actor.global_position
		to_prop.y = 0.0
		if to_prop.length() > 1.6 or to_prop.normalized().dot(direction) < 0.35:
			continue
		var side := Vector3(-direction.z, 0, direction.x)
		if prop.get_instance_id() % 2 == 0:
			side = -side
		for offset in [side * 0.45, -side * 0.45, direction * 0.4]:
			if shift(prop, offset):
				return true
	return false

func shift(prop: Node3D, offset: Vector3) -> bool:
	if not is_instance_valid(prop) or not prop is PhysicsBody3D or offset.length() < 0.03:
		return false
	if actor.global_position.distance_to(prop.global_position) > 2.3:
		return false
	var exclusions: Array[RID] = [prop.get_rid()]
	for child in prop.find_children("*", "CollisionObject3D", true, false):
		exclusions.append(child.get_rid())
	var space := actor.get_world_3d().direct_space_state
	var shapes := prop.find_children("*", "CollisionShape3D", true, false)
	if shapes.is_empty():
		return false
	for collider in shapes:
		if collider.disabled or collider.shape == null:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = collider.shape
		q.transform = collider.global_transform
		q.transform.origin += Vector3.UP * 0.04
		q.motion = offset
		q.exclude = exclusions
		q.collision_mask = 1
		if space.cast_motion(q)[0] < 0.995:
			return false
		q.transform.origin += offset
		q.motion = Vector3.ZERO
		if not space.intersect_shape(q, 1).is_empty():
			return false
	# Prefabs can have their origin at the centre (crates) or at the feet (chairs).
	# Determine the support height from the collision shapes, not the origin.
	var bottom := INF
	var bounds := AABB()
	var have_bounds := false
	for collider in shapes:
		if collider.disabled or collider.shape == null:
			continue
		var world_bounds: AABB = collider.global_transform * collider.shape.get_debug_mesh().get_aabb()
		bounds = bounds.merge(world_bounds) if have_bounds else world_bounds
		have_bounds = true
		bottom = minf(bottom, world_bounds.position.y)
	if not have_bounds:
		return false
	if maxf(bounds.size.x, bounds.size.z) > 1.6 or bounds.size.y > 1.8:
		return false
	# Do not pull supporting furniture out from under a stack or an actor.
	var top := PhysicsShapeQueryParameters3D.new()
	var top_shape := BoxShape3D.new()
	top_shape.size = Vector3(maxf(0.1, bounds.size.x - 0.08), 0.10, maxf(0.1, bounds.size.z - 0.08))
	top.shape = top_shape
	top.transform.origin = Vector3(bounds.get_center().x, bounds.end.y + 0.07, bounds.get_center().z)
	top.collision_mask = 1
	top.exclude = exclusions
	if not space.intersect_shape(top, 1).is_empty():
		return false
	var support := bounds.get_center() + offset
	support.y = bottom
	for corner in [Vector3.ZERO, Vector3(bounds.size.x * 0.35, 0, bounds.size.z * 0.35), Vector3(-bounds.size.x * 0.35, 0, -bounds.size.z * 0.35), Vector3(-bounds.size.x * 0.35, 0, bounds.size.z * 0.35), Vector3(bounds.size.x * 0.35, 0, -bounds.size.z * 0.35)]:
		var floor_query := PhysicsRayQueryParameters3D.create(support + corner + Vector3.UP * 0.1, support + corner - Vector3.UP * 0.18, 1, exclusions)
		var hit := space.intersect_ray(floor_query)
		if hit.is_empty() or hit.normal.y < 0.7:
			return false
	var dest := prop.global_position + offset
	prop.global_position = dest
	return true

func perform(job: Dictionary, last_seen: Vector3) -> bool:
	var node: Variant = job.get("node")
	if not is_instance_valid(node):
		return false
	var action := str(job.get("action", ""))
	if action == "tidy":
		var home: Vector3 = node.get_meta("ai_home", node.global_position)
		var offset: Vector3 = (home - node.global_position).limit_length(0.45)
		if offset.length() < 0.03:
			offset = node.global_transform.basis.x.normalized() * 0.25
		return shift(node, offset)
	elif action == "barricade":
		var destination: Variant = null
		var best_cost := INF
		for door in actor.get_tree().get_nodes_in_group("doors"):
			if not is_instance_valid(door) or door.name == "Panel" or door.call("is_door_locked"):
				continue
			var offset: Vector3 = door.global_position - node.global_position
			if absf(offset.y) > 0.7:
				continue
			offset.y = 0.0
			if offset.length() > 2.0:
				continue
			var cost: float = offset.length() + door.global_position.distance_to(last_seen) * 0.15
			if cost < best_cost:
				best_cost = cost
				destination = offset.limit_length(0.6)
		if destination != null:
			return shift(node, destination)
		return false
	elif action in ["prop_tv", "prop_crt_tv"]:
		return _call_on_tree(node, "turn_on")
	elif action in ["prop_fridge", "prop_light_switch"]:
		return _call_on_tree(node, "interact", true)
	elif action == "prop_toilet" and ResourceLoader.exists("res://assets/audio/toilet_flush.wav"):
		var audio := AudioStreamPlayer3D.new()
		audio.stream = load("res://assets/audio/toilet_flush.wav")
		audio.max_distance = 14.0
		audio.volume_db = -10.0
		node.add_child(audio)
		audio.finished.connect(audio.queue_free)
		audio.play()
		return true
	return false

func _call_on_tree(node: Node, method: String, with_actor: bool = false) -> bool:
	if node.has_method(method):
		if with_actor:
			node.call(method, actor)
		else:
			node.call(method)
		return true
	for child in node.get_children():
		if _call_on_tree(child, method, with_actor):
			return true
	return false
