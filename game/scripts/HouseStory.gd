class_name HouseStory
extends RefCounted

# Надписи и следы в доме отца для глав 1 и 3:
# детские имена «СЭМ» и «ИТАН» в углу комнаты Сэма, над ними надпись кровью,
# и следы когтей на стенах прихожей — выше, чем дотянется человек.
# Всё ставится прямо в главу шоссе, чтобы внутренности дома прятались вместе с остальным.

const FY := 3.48   # пол второго этажа
const GY := 0.16   # пол первого этажа


static func build(chapter: Node3D) -> void:
	_names_and_blood(chapter)
	_claw_marks(chapter, Vector3(-58.84, GY + 2.3, -226.6), 90.0)
	_claw_marks(chapter, Vector3(-53.16, GY + 2.4, -223.4), -90.0)
	_claw_marks(chapter, Vector3(-58.84, FY + 2.2, -229.8), 90.0)


# Угол комнаты Сэма у окна: шкаф у западной стены, на южной стене за шкафом у пола
# детские имена, а слева от шкафа — надпись кровью
static func _names_and_blood(chapter: Node3D) -> void:
	var wall_z := -230.835   # чуть перед южной стеной со стороны комнаты Сэма
	var pencil := Color(0.24, 0.22, 0.2)
	_label(chapter, "СЭМ", Vector3(-70.62, FY + 0.3, wall_z), 0.0, 5.0, pencil, 40, 0.0022, false)
	_label(chapter, "ИТАН", Vector3(-70.38, FY + 0.19, wall_z), 0.0, -4.0, pencil, 40, 0.0022, false)
	var blood := Color(0.42, 0.02, 0.02)
	_label(chapter, "ИТАН, ЕСЛИ ТЫ\nЭТО ЧИТАЕШЬ —\nБЕГИ\nОНО ИДЁТ", Vector3(-69.4, FY + 0.95, wall_z), 0.0, -3.0,
		blood, 56, 0.0019, true)
	# Потёки крови вниз от букв
	var drip_mat := StandardMaterial3D.new()
	drip_mat.albedo_color = Color(0.32, 0.01, 0.01)
	drip_mat.roughness = 0.35
	var rng := RandomNumberGenerator.new()
	rng.seed = 1994
	for i in range(9):
		var len := rng.randf_range(0.08, 0.32)
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(rng.randf_range(0.006, 0.012), len * 0.7)
		qm.material = drip_mat
		q.mesh = qm
		chapter.add_child(q)
		q.global_position = Vector3(rng.randf_range(-69.75, -69.05), FY + 0.72 - len * 0.35 + rng.randf_range(-0.04, 0.04), wall_z + 0.002)
		q.rotation_degrees = Vector3.ZERO


static func _label(chapter: Node3D, text: String, at: Vector3, yaw: float, roll: float, col: Color, size: int, px: float, outline: bool) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.line_spacing = -6.0
	if outline:
		l.outline_size = 4
		l.outline_modulate = Color(col.r * 0.6, 0.0, 0.0, 0.85)
	else:
		l.outline_size = 0
	chapter.add_child(l)
	l.global_position = at
	l.rotation_degrees = Vector3(0.0, yaw, roll)


# Четыре длинные борозды от когтей, наискось
static func _claw_marks(chapter: Node3D, at: Vector3, yaw: float) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.06, 0.04)
	dark.roughness = 1.0
	var light := StandardMaterial3D.new()
	light.albedo_color = Color(0.55, 0.42, 0.3)
	light.roughness = 1.0
	var side := Vector3(0.0, 0.0, 1.0) if absf(yaw) == 90.0 else Vector3(1.0, 0.0, 0.0)
	var out := Vector3(1.0 if yaw > 0.0 else -1.0, 0.0, 0.0)
	for k in range(4):
		var off := side * (k * 0.07 - 0.1) + Vector3.UP * (k * 0.03)
		for layer in [[dark, Vector2(0.018, 0.75), 0.004], [light, Vector2(0.03, 0.78), 0.002]]:
			var q := MeshInstance3D.new()
			var qm := QuadMesh.new()
			qm.size = layer[1]
			qm.material = layer[0]
			q.mesh = qm
			chapter.add_child(q)
			q.global_position = at + off + out * layer[2]
			q.rotation_degrees = Vector3(0.0, yaw, 22.0)
