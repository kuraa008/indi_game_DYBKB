class_name AcousticWave
extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  AcousticWave.gd — Визуальная акустическая волна шума (Sonar Ripple)
#  • Спавнится в точке шума при беге, броске бутылки, хлопке двери и т.д.
#  • Видна сквозь стены (no_depth_test), показывая хищнику источник звука
# ══════════════════════════════════════════════════════════════════════════════

var ring_mesh: MeshInstance3D
var label_3d: Label3D
var ring_mat: StandardMaterial3D

func _ready() -> void:
	# Игрок за ГГ никогда не видит эту волну в геймплее — только в режиме отладки (F1)!
	if GameManager and (not GameManager.debug_overlay or not GameManager.debug_overlay.visible):
		queue_free()
		return

	# Кольцевая волна на полу (только для режима отладки)
	ring_mesh = MeshInstance3D.new()
	var tm = TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.05
	ring_mesh.mesh = tm

	ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.no_depth_test = true
	ring_mat.render_priority = 100
	ring_mat.albedo_color = Color(0.25, 0.85, 1.0, 0.90)
	ring_mesh.material_override = ring_mat
	ring_mesh.position.y = 0.08
	add_child(ring_mesh)

	# 3D иконка над источником
	label_3d = Label3D.new()
	label_3d.text = "ШУМ"
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label_3d.no_depth_test = true
	label_3d.render_priority = 101
	label_3d.outline_render_priority = 100
	label_3d.font_size = 28
	label_3d.outline_size = 6
	label_3d.outline_modulate = Color(0, 0, 0, 0.8)
	label_3d.modulate = Color(0.3, 0.9, 1.0, 0.95)
	label_3d.position.y = 0.6
	add_child(label_3d)

	# Анимация расширения и затухания за 2.2 секунды
	scale = Vector3(0.25, 1.0, 0.25)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3(3.8, 1.0, 3.8), 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label_3d, "position:y", 1.4, 2.2)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(label_3d, "modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(label_3d, "outline_modulate:a", 0.0, 2.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tw.chain().tween_callback(queue_free)
