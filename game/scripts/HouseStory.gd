class_name HouseStory
extends RefCounted

# Надписи и следы в доме отца для глав 1 и 3:
# детские имена «СЭМ» и «ИТАН» в углу комнаты Сэма, над ними надпись кровью,
# и следы когтей на стенах прихожей — выше, чем дотянется человек.
# Всё ставится прямо в главу шоссе, чтобы внутренности дома прятались вместе с остальным.

const FY := 3.48   # пол второго этажа
const GY := 0.16   # пол первого этажа


static func build(chapter: Node3D) -> void:
	chapter.add_child(load("res://scripts/FatherYard.gd").new())
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
	# Надпись нарисована пальцем: неровные мазки, засохшие края, потёки вниз
	var blood := StandardMaterial3D.new()
	blood.albedo_texture = load("res://assets/textures/house/blood_message.png")
	blood.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blood.roughness = 0.62
	blood.metallic_specular = 0.35
	blood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var sheet := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.92, 0.6)
	quad.material = blood
	sheet.mesh = quad
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chapter.add_child(sheet)
	sheet.global_position = Vector3(-69.4, FY + 0.9, wall_z + 0.002)
	sheet.rotation_degrees = Vector3(0.0, 0.0, -2.0)


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


# Следы когтей: глубокие рваные борозды, щепки по краям и засохшая кровь
static func _claw_marks(chapter: Node3D, at: Vector3, yaw: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/house/claw_marks.png")
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.95
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var mark := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.42, 0.58)
	quad.material = mat
	mark.mesh = quad
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	chapter.add_child(mark)
	var out := Vector3(1.0 if yaw > 0.0 else -1.0, 0.0, 0.0)
	mark.global_position = at + out * 0.003
	mark.rotation_degrees = Vector3(0.0, yaw, fposmod(at.z * 37.0, 14.0) - 7.0)
