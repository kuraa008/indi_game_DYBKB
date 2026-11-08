class_name BasementExitHatch
extends StaticBody3D

# Люк в потолке тамбура над лестницей подвала (глава 2): через него Итан вылезает во двор.
# Игрок смотрит вверх на люк и нажимает действие — кат-сцена Jan-ky «Лаз» (Ch2Tunnel) поверх игры:
# последние метры лаза, крышка плечом, двор. После неё Итан стоит во дворе лицом к дому (END_POS).

const OUT_POS := Vector3(-58.0, 0.15, -233.5)   # на заднем дворе, прямо за стеной дома, у такого же люка на земле
const OUT_YAW := 0.0                              # спиной к дому, лицом к лесу
const END_POS := Vector3(-59.2, 0.15, -239.35)    # где кончается кат-сцена: отошёл к лесу
const END_LOOK := Vector3(-61.5, 0.15, -231.0)    # и обернулся на дом

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
	opener.set("is_in_cutscene", true)
	await Cutscene.overlay(self, "res://scenes/cutscenes/Ch2Tunnel.tscn", {"from_gameplay": true})
	opener.global_position = END_POS
	opener.rotation.y = atan2(END_POS.x - END_LOOK.x, END_POS.z - END_LOOK.z)
	opener.set("velocity", Vector3.ZERO)
	opener.set("is_in_cutscene", false)
	_busy = false


# Старый переход без кат-сцены (затемнение и перенос на OUT_POS) — если кат-сцену нужно отключить
func _fade_out_old(opener: Node3D) -> void:
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
