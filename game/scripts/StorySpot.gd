extends Area3D

# Невидимая точка действия для сюжетных задач: игрок наводит прицел и нажимает [ЛКМ / E].
# Это Area3D, поэтому она не мешает ходить и может лежать поверх мебели.

var hint := ""
var on_use: Callable
var highlight: Node        # что обводить, когда игрок смотрит на точку


func setup(action: String, use: Callable, side: Vector3) -> void:
	hint = "[ЛКМ / E]  " + action
	on_use = use
	monitoring = false
	monitorable = false
	set_meta("item_type", "story_spot")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = side
	col.shape = shape
	add_child(col)


func get_highlight_node() -> Node:
	return highlight if is_instance_valid(highlight) else null


func get_interaction_hint() -> String:
	return hint


func interact(_opener: Node = null) -> void:
	on_use.call()
