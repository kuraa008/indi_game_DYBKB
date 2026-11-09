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
	_cellar_door(chapter)


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


# Дверь на южной стене прачечной, между корытом и каменной раковиной.
# Этим путём Итана затащили вниз. Изнутри у неё нет ни засова, ни замка, открыть её нельзя.
static func _cellar_door(chapter: Node3D) -> void:
	var root := Node3D.new()
	root.name = "CellarDoor"
	chapter.add_child(root)
	root.global_position = Vector3(-60.93, -4.2, -240.7)
	root.rotation.y = PI
	var stone: Array = []
	var dark: Array = []
	var light: Array = []
	var iron: Array = []
	# Бетонная коробка проёма и порог
	stone.append(_box(Vector3(0.16, 2.26, 0.12), Vector3(-0.64, 1.13, -0.06)))
	stone.append(_box(Vector3(0.16, 2.26, 0.12), Vector3(0.64, 1.13, -0.06)))
	stone.append(_box(Vector3(1.44, 0.18, 0.15), Vector3(0, 2.35, -0.075)))
	stone.append(_box(Vector3(1.12, 0.05, 0.16), Vector3(0, 0.025, -0.08)))
	# Вертикальные доски полотна с тонкими щелями
	var plank_w := 0.186
	for i in range(6):
		var x := -0.465 + plank_w * i
		var tall := 2.17 + 0.012 * float((i * 7) % 3)
		var group: Array = dark if i % 2 == 0 else light
		group.append(_box(Vector3(plank_w - 0.007, tall, 0.05), Vector3(x, 0.05 + tall * 0.5, -0.05)))
	# Кованые полосы с петлями, заклёпки и кольцо. Запирается дверь только снаружи
	for y: float in [0.38, 1.12, 1.86]:
		iron.append(_box(Vector3(0.98, 0.07, 0.012), Vector3(-0.03, y, -0.081)))
		iron.append(_box(Vector3(0.09, 0.12, 0.05), Vector3(-0.56, y, -0.07)))
		for k in range(5):
			iron.append(_box(Vector3(0.024, 0.024, 0.012), Vector3(-0.42 + 0.21 * k, y, -0.092)))
	iron.append(_box(Vector3(0.12, 0.17, 0.012), Vector3(0.36, 1.0, -0.081)))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.043
	ring.outer_radius = 0.06
	ring.rings = 12
	ring.ring_segments = 6
	iron.append([ring, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0.36, 0.95, -0.1))])

	var wood_tex: Texture2D = load("res://assets/textures/wood_planks.png")
	_merged(root, stone, Color(0.2, 0.19, 0.175), 0.97, 0.0, load("res://assets/textures/concrete_grunge.png"))
	_merged(root, dark, Color(0.2, 0.145, 0.095), 0.92, 0.0, wood_tex)
	_merged(root, light, Color(0.26, 0.19, 0.125), 0.92, 0.0, wood_tex)
	_merged(root, iron, Color(0.085, 0.078, 0.07), 0.62, 0.65, null)

	var spot: Area3D = load("res://scripts/StorySpot.gd").new()
	spot.name = "CellarDoorSpot"
	spot.setup("Открыть дверь", _on_cellar_door.bind(spot), Vector3(1.2, 2.2, 0.24))
	chapter.add_child(spot)
	spot.global_position = root.global_position + Vector3(0, 1.1, 0.12)


static func _on_cellar_door(spot: Node3D) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = load("res://assets/audio/cutscenes/door_handle_slow.wav")
	spot.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		GameManager.ui_ref.call("show_hint", "Заперто снаружи. Здесь не выйти.", 2.5)


static func _box(size: Vector3, pos: Vector3) -> Array:
	var box := BoxMesh.new()
	box.size = size
	return [box, Transform3D(Basis.IDENTITY, pos)]


static func _merged(parent: Node3D, parts: Array, color: Color, rough: float, metal: float, tex: Texture2D) -> void:
	var st := SurfaceTool.new()
	for part in parts:
		st.append_from(part[0], 0, part[1])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if tex:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = Vector3.ONE * 0.8
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = mat
	parent.add_child(mesh)
