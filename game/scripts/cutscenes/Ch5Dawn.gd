extends Cutscene

# ГЛАВА 5 · «Рассвет». Братья выходят из леса к дому: Сэм опирается на плечо Итана.
# У края леса Сэм тихо спрашивает: «Почему ты вернулся?» — «Опоздал. Но вернулся.»
# Солнце встаёт над крышей. В комнате отца открыто окно, и ветер шевелит смятую
# простыню на пустой кровати.
#
# args.with_dialogue = false — без диалога (если его уже сыграл геймплей по триггеру).
# Окно комнаты отца — нижнее окно западной стены дома «Шоссе» (z = -222): заколоченное
# окно с карты убрано и заменено открытым.

const MAP := "res://scenes/Шоссе.json"
const WINDOW_IDS := [1149, 1150, 1151, 1152, 1014]
const WIN := Vector3(-71.2, 1.245, -222.0)
const WALK_FROM := Vector3(-93.5, 0.0, -224.6)
const WALK_DIR := Vector3(1, 0, 0)

var ethan: PlayerModel
var sam: PlayerModel
var sheet: MeshInstance3D
var _walking := false
var _walk_s := 0.0


func build() -> void:
	sky_env(Color(0.36, 0.48, 0.66), Color(1.0, 0.72, 0.5), Color(0.18, 0.17, 0.16), 0.7)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.95, 0.78, 0.62)
	env.fog_density = 0.0045
	env.fog_sun_scatter = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.74, 0.5)
	sun.light_energy = 1.6
	sun.rotation_degrees = Vector3(-11, 90, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)
	CutsceneKit.map_area(self, MAP, Vector3(-66, 0, -225), 40.0, [], WINDOW_IDS, AABB(Vector3(-71.0, -0.5, -224.6), Vector3(4.5, 3.5, 5.2)))
	CutsceneKit.ground(self, Vector3(-75, 0.0, -225), Vector2(120, 120), CutsceneKit.tmat("forest_floor.png", Color(0.62, 0.66, 0.55), 0.35))
	CutsceneKit.grass(self, Vector3(-84, 0, -224.5), Vector2(22, 10), 260, 7, 0.8)
	CutsceneKit.forest(self, Vector3(-100, 0, -225), 6.0, 26.0, 70, 17, 10.0, 18.0, func(x: float, z: float) -> bool: return x > -92.0 or (absf(z + 224.6) < 2.2 and x > -99.0))
	_father_window()
	# Братья: Сэм висит на плече у Итана
	ethan = CutsceneCast.ethan()
	add_child(ethan)
	sam = CutsceneCast.sam()
	add_child(sam)
	for m in [ethan, sam]:
		m.rotation_degrees = Vector3(0, 90, 0)
	_place(0.0)


func _father_window() -> void:
	# Западная стена дома с карты — заново, но с проёмом окна (на карте окна — накладки)
	var planks := TextureHelper.create_wall_material("wood_planks", Color.html("8a8378ff"))
	CutsceneKit.wall(self, Vector3(-71.0, 0, -219.0), Vector3(-71.0, 0, -231.0), 3.4, 0.3, planks, Rect2(2.25, 0.64, 1.5, 1.21))
	# Открытая рама, за ней комната отца: кровать со смятой простынёй
	var frame := CutsceneKit.mat(Color(0.33, 0.27, 0.21), 0.8)
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, Vector3(0.12, 1.21, 0.08), WIN + Vector3(0, 0.0, 0.72 * s), frame)
		CutsceneKit.box(self, Vector3(0.12, 0.08, 1.52), WIN + Vector3(0, 0.605 * s, 0), frame)
	# Створки распахнуты наружу
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.6, 0.7, 0.75, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.1
	for s in [-1.0, 1.0]:
		var leaf := CutsceneKit.node(self, WIN + Vector3(-0.05, 0, 0.72 * s), Vector3(0, -60 * s, 0))
		CutsceneKit.box(leaf, Vector3(0.05, 1.12, 0.04), Vector3(-0.0, 0, -0.35 * s), frame)
		CutsceneKit.box(leaf, Vector3(0.05, 1.12, 0.04), Vector3(-0.0, 0, -0.7 * s), frame)
		CutsceneKit.box(leaf, Vector3(0.02, 1.08, 0.66), Vector3(0, 0, -0.35 * s), glass)
	var room_m := CutsceneKit.mat(Color(0.34, 0.3, 0.26), 0.95)
	var inside := Vector3(WIN.x + 1.6, 0.0, WIN.z)
	CutsceneKit.box(self, Vector3(3.0, 0.1, 3.4), inside + Vector3(0, 0.16, 0), CutsceneKit.tmat("wood_furniture.png", Color(0.5, 0.4, 0.31), 1.1))
	CutsceneKit.box(self, Vector3(0.1, 2.6, 3.4), inside + Vector3(1.5, 1.3, 0), room_m)
	for s in [-1.0, 1.0]:
		CutsceneKit.box(self, Vector3(3.0, 2.6, 0.1), inside + Vector3(0, 1.3, 1.7 * s), room_m)
	# Кровать отца длинной стороной к окну: рама, матрас, подушка и смятая простыня
	var bed_at := inside + Vector3(-0.45, 0.2, 0.0)
	var bed_wood := CutsceneKit.tmat("wood_furniture.png", Color(0.42, 0.32, 0.24), 1.4)
	CutsceneKit.box(self, Vector3(1.0, 0.32, 2.0), bed_at + Vector3(0, 0.22, 0), bed_wood)
	CutsceneKit.box(self, Vector3(1.0, 0.75, 0.06), bed_at + Vector3(0, 0.375, 1.0), bed_wood)
	CutsceneKit.box(self, Vector3(0.94, 0.14, 1.9), bed_at + Vector3(0, 0.45, 0), CutsceneKit.mat(Color(0.72, 0.7, 0.66), 0.95))
	CutsceneKit.ball(self, 0.22, bed_at + Vector3(0, 0.56, 0.75), CutsceneKit.mat(Color(0.8, 0.79, 0.75), 0.95), Vector3(1.6, 0.45, 0.9), 10)
	sheet = CutsceneKit.cloth(self, Vector2(1.1, 1.5), bed_at + Vector3(-0.05, 0.56, -0.15), Vector3(0, 0, 3), Color(0.88, 0.86, 0.82))
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.76, 0.52)
	beam.light_energy = 6.0
	beam.spot_range = 6.0
	beam.spot_angle = 22.0
	beam.shadow_enabled = true
	add_child(beam)
	beam.position = WIN + Vector3(-1.4, 0.9, 0.2)
	beam.look_at(inside + Vector3(0.5, 0.6, 0.0), Vector3.UP)


func _place(s: float) -> void:
	var base := WALK_FROM + WALK_DIR * s
	ethan.position = base + Vector3(0, 0, -0.27)
	sam.position = base + Vector3(0, 0, 0.27)


func tick(delta: float) -> void:
	if not _walking:
		return
	_walk_s += delta * 0.72
	_place(_walk_s)
	ethan.update_motion(delta, "walk", 0.72)
	sam.update_motion(delta, "walk", 0.72)
	# Сэм закинул руку Итану на плечи, Итан держит его за пояс
	var se := ethan.skeleton
	var ss := sam.skeleton
	se.set_bone_pose_rotation(se.find_bone("shR"), Quaternion(Basis.from_euler(Vector3(-0.35, 0.0, 0.62), EULER_ORDER_XYZ)))
	se.set_bone_pose_rotation(se.find_bone("elR"), Quaternion(Basis.from_euler(Vector3(-1.2, 0.0, 0.0), EULER_ORDER_XYZ)))
	ss.set_bone_pose_rotation(ss.find_bone("shL"), Quaternion(Basis.from_euler(Vector3(-0.2, 0.0, -2.2), EULER_ORDER_XYZ)))
	ss.set_bone_pose_rotation(ss.find_bone("elL"), Quaternion(Basis.from_euler(Vector3(-0.5, 0.0, 0.0), EULER_ORDER_XYZ)))
	ss.set_bone_pose_rotation(ss.find_bone("spineA"), Quaternion(Basis.from_euler(Vector3(0.18, 0.0, 0.12), EULER_ORDER_XYZ)))
	ss.set_bone_pose_rotation(ss.find_bone("head"), Quaternion(Basis.from_euler(Vector3(0.3, 0.0, 0.1), EULER_ORDER_XYZ)))


func run() -> void:
	var with_dialogue: bool = args.get("with_dialogue", true)
	var amb := loop("amb_dawn", -10.0, 1.5)
	var cam_from := Vector3(-97.5, 1.75, -223.6)
	shot(cam_from, Vector3(-62.0, 5.5, -225.0), 46.0)
	fade_in(2.0)
	_walking = true
	glide(cam_from + Vector3(2.5, 0.05, -0.3), Vector3(-62.0, 6.2, -225.0), 12.0, 44.0, Tween.TRANS_LINEAR)
	for i in 3:
		sfx("step_grass_%d" % (i + 1), -18.0)
		await wait(0.7)
	if with_dialogue:
		await wait(1.0)
		await line("sam_why", "СЭМ", "Почему ты вернулся?", 2.2, sam.position + Vector3(0, 1.5, 0), -2.0, 8.0)
		await line("ethan_late", "ИТАН", "Опоздал… Но вернулся.", 1.0, ethan.position + Vector3(0, 1.5, 0), -2.0, 8.0)
	else:
		await wait(5.0)
	# Солнце встаёт над крышей
	await wait(2.0)
	shot(Vector3(-91.0, 1.2, -229.5), Vector3(-62.0, 7.5, -224.5), 42.0)
	glide(Vector3(-90.0, 1.25, -229.2), Vector3(-62.0, 8.2, -224.5), 6.0, 40.0)
	await wait(5.0)
	# Открытое окно комнаты отца, ветер шевелит простыню на пустой кровати
	var sheet_mat := sheet.material_override as ShaderMaterial
	shot(WIN + Vector3(-2.3, 0.35, 1.1), WIN + Vector3(1.6, -0.45, -0.05), 40.0)
	glide(WIN + Vector3(-1.5, 0.25, 0.6), WIN + Vector3(1.8, -0.5, -0.05), 7.0, 36.0)
	var flutter := loop("sheet_flutter", -10.0, 1.0, WIN + Vector3(1.6, -0.4, 0), 4.0)
	var wind_t := 0.0
	while wind_t < 6.5 and not skipping:
		wind_t += get_process_delta_time()
		sheet_mat.set_shader_parameter("wind", 0.55 + 0.45 * sin(wind_t * 0.8))
		await get_tree().process_frame
	fade_out(2.5)
	stop(amb, 2.5)
	stop(flutter, 2.5)
	await wait(2.8)
