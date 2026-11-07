class_name BasementExitHatch
extends StaticBody3D

# Люк в потолке тамбура над лестницей подвала (глава 2): через него Итан вылезает во двор.
# Игрок смотрит вверх на люк и нажимает действие — экран темнеет, и Итан уже наверху.

const OUT_POS := Vector3(-58.0, 0.15, -233.5)   # на заднем дворе, прямо за стеной дома, у такого же люка на земле
const OUT_YAW := 0.0                              # спиной к дому, лицом к лесу

var _busy := false


func _ready() -> void:
	set_meta("item_type", "basement_exit_hatch")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, 0.12, 0.9)
	col.shape = shape
	add_child(col)


func get_interaction_hint() -> String:
	return "[ЛКМ / E]  Вылезти через люк"


func interact(opener: Node = null) -> void:
	if _busy or opener == null or not (opener is Node3D):
		return
	_busy = true
	var layer := CanvasLayer.new()
	layer.layer = 120
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(shade)
	get_tree().root.add_child(layer)
	opener.set("is_in_cutscene", true)
	var creak := AudioStreamPlayer.new()
	if ResourceLoader.exists("res://assets/audio/monster/basement_door_open.wav"):
		creak.stream = load("res://assets/audio/monster/basement_door_open.wav")
		layer.add_child(creak)
		creak.play()
	var dark := layer.create_tween()
	dark.tween_property(shade, "color:a", 1.0, 0.6)
	await dark.finished
	opener.global_position = OUT_POS
	opener.rotation.y = OUT_YAW
	opener.set("velocity", Vector3.ZERO)
	await get_tree().create_timer(0.6).timeout
	var light := layer.create_tween()
	light.tween_property(shade, "color:a", 0.0, 0.9)
	await light.finished
	opener.set("is_in_cutscene", false)
	layer.queue_free()
	_busy = false
