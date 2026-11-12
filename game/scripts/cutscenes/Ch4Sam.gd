extends Cutscene

# ГЛАВА 4 · «Сэм». Дом Крейна. На стуле «Старший» сидит Сэм: живой, худой, грязный,
# с пустыми глазами, руки привязаны полосками оленьей кожи. Он видит Итана,
# открывает рот — и ни звука. «Сэм… Сэм, это я.» Сэм беззвучно плачет и пишет
# пальцем на пыльном столе: «ПОЗДНО. ОНО ИДЁТ. ОГОНЬ — ОЧАГ». У дальней стены — очаг.
# Итан перерезает ремни; Сэм не может стоять, Итан сажает его к стене у очага.
# Снаружи — стук копыт. Медленный. Уверенный. КОНЕЦ ГЛАВЫ 4.

const WORDS := CraneHouse.SAM_WORDS
const SAM_SEAT := CraneHouse.ELDER
const SAM_WALL := CraneHouse.SAM_WALL
const C_ENTER := Vector3(2.35, 1.62, 1.45)
const C_ACROSS := Vector3(0.1, 1.56, 1.3)
const C_KNEEL := Vector3(-1.65, 0.98, 1.6)

var house: Dictionary
var sam: PlayerModel
var mouth: MeshInstance3D
var straps: Array = []
var knife_rig: Node3D
var sw: SkinwalkerModel
var _pose_from := {}
var _pose_to := {}
var _pose_u := 1.0
var _pose_speed := 1.0
var _writing := false
var _write_t := 0.0
var _sw_walk := false


func build() -> void:
	set_env(Color(0.02, 0.025, 0.04), Color(0.3, 0.33, 0.44), 0.85, 0.01, Color(0.04, 0.05, 0.08), 1.3)
	house = CraneHouse.build(self)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.68, 0.95)
	moon.light_energy = 1.5
	moon.rotation_degrees = Vector3(-68, 30, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 30.0
	add_child(moon)
	var fill := OmniLight3D.new()
	fill.light_color = Color(0.55, 0.62, 0.85)
	fill.light_energy = 0.6
	fill.omni_range = 3.5
	fill.position = Vector3(0.4, 1.9, 0.6)
	add_child(fill)
	var hearth_glow := OmniLight3D.new()
	hearth_glow.light_color = Color(0.55, 0.62, 0.88)
	hearth_glow.light_energy = 0.9
	hearth_glow.omni_range = 3.2
	hearth_glow.position = Vector3(-2.0, 2.1, 0.9)
	add_child(hearth_glow)
	# Лунный свет из дыры в крыше над трубой: камни очага должны читаться в его кадре
	var hearth_key := OmniLight3D.new()
	hearth_key.light_color = Color(0.62, 0.7, 0.95)
	hearth_key.light_energy = 1.5
	hearth_key.omni_range = 3.0
	hearth_key.position = Vector3(-1.75, 1.45, -0.15)
	add_child(hearth_key)
	# Сэм на стуле «Старший»
	# (тот же Сэм с ремнями из оленьей кожи, что сидит в игре до кат-сцены)
	var tied := CraneHouse.sam_tied(self)
	sam = tied.sam
	straps = tied.straps
	_pose_to = CutsceneCast.sit_tied()
	_add_mouth()
	# Нож в руке Итана (для ремней)
	knife_rig = Node3D.new()
	cam.add_child(knife_rig)
	knife_rig.position = Vector3(0.18, -0.45, -0.3)
	var h := CutsceneCast.hand(false)
	knife_rig.add_child(h)
	h.curl = 0.85
	h.rotation_degrees = Vector3(0, 0, -80)
	CutsceneKit.box(h, Vector3(0.012, 0.004, 0.11), Vector3(0.0, -0.01, -0.13), CutsceneKit.mat(Color(0.7, 0.72, 0.75), 0.25, 0.9))
	knife_rig.visible = false
	# Существо снаружи: пройдёт мимо окна
	sw = CutsceneCast.skinwalker()
	add_child(sw)
	sw.position = Vector3(1.8, 0, 3.45)
	sw.rotation_degrees = Vector3(0, -90, 0)
	sw.visible = false


func _add_mouth() -> void:
	var ba := BoneAttachment3D.new()
	ba.bone_name = "head"
	sam.skeleton.add_child(ba)
	mouth = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.012
	sm.height = 0.024
	mouth.mesh = sm
	mouth.material_override = CutsceneKit.mat(Color(0.02, 0.01, 0.01), 1.0)
	mouth.position = Vector3(0.0, 0.03, 0.1)
	mouth.scale = Vector3(1.0, 0.15, 0.4)
	ba.add_child(mouth)


func _go_pose(p: Dictionary, dur: float) -> void:
	_pose_from = CutsceneCast.mix_pose(_pose_from if _pose_u < 1.0 and not _pose_from.is_empty() else _pose_to, _pose_to, _pose_u) if not _pose_to.is_empty() else p
	_pose_to = p
	_pose_u = 0.0
	_pose_speed = 1.0 / maxf(dur, 0.01)


func tick(delta: float) -> void:
	if _pose_u < 1.0:
		_pose_u = minf(1.0, _pose_u + delta * _pose_speed)
		var u := _pose_u * _pose_u * (3.0 - 2.0 * _pose_u)
		CutsceneCast.pose(sam, CutsceneCast.mix_pose(_pose_from, _pose_to, u))
	if _writing:
		_write_t += delta
		var p := CutsceneCast.with(_pose_to, {
			"shL": Vector3(-0.98, 0.12 + 0.1 * sin(_write_t * 2.2), -0.05 + 0.06 * sin(_write_t * 1.3)),
			"elL": Vector3(-0.42 + 0.08 * sin(_write_t * 4.7), 0, 0),
		})
		CutsceneCast.pose(sam, p)
	if _sw_walk:
		sw.position.x -= delta * 0.9
		sw.update_motion(delta, "walk", 0.9)


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	var amb := loop("amb_crane_house", -12.0, 1.0)
	handheld = 0.5
	breathe = 0.9
	# Из игры камера начинает оттуда, где стоял игрок (если он с той же стороны стола, что и вход)
	var start := C_ENTER
	var seen: Vector3 = args.get("cam_pos", C_ENTER)
	if from_game and seen.z > 0.2 and absf(seen.x) < 2.8 and seen.z < 2.3:
		start = Vector3(seen.x, 1.62, seen.z)
	shot(start, SAM_SEAT + Vector3(0, 1.05, 0), 54.0)
	fade_in(0.6 if from_game else 1.6)
	sfx("step_grass_1", -16.0)
	glide(C_ENTER + Vector3(-0.7, 0.0, -0.3), SAM_SEAT + Vector3(0, 1.0, 0), 3.5, 48.0)
	await wait(2.6)
	# Сэм поднимает голову и открывает рот — ни звука
	_go_pose(CutsceneCast.with(CutsceneCast.sit_tied(), {"neck": Vector3(0.0, 0, 0), "head": Vector3(-0.18, 0.1, 0.0), "spineA": Vector3(0.12, 0, 0), "chest": Vector3(0.08, 0, 0)}), 1.8)
	await wait(1.6)
	tween_prop(mouth, "scale", Vector3(1.0, 0.75, 0.4), 0.5)
	sfx("sam_voiceless", -6.0)
	await wait(1.4)
	tween_prop(mouth, "scale", Vector3(1.0, 0.2, 0.4), 0.8)
	# «Сэм… Сэм, это я.»
	glide(C_ACROSS, SAM_SEAT + Vector3(0, 1.05, 0), 2.2, 44.0)
	await line("ethan_sam_eto_ya", "ИТАН", "Сэм… Сэм, это я.", 0.6)
	# Плачет беззвучно, мотает головой
	sfx("sam_sob", -8.0)
	_go_pose(CutsceneCast.with(_pose_to, {"head": Vector3(-0.05, -0.2, 0.08)}), 0.6)
	await wait(0.7)
	_go_pose(CutsceneCast.with(_pose_to, {"head": Vector3(-0.05, 0.2, -0.08)}), 0.6)
	await wait(0.7)
	_go_pose(CutsceneCast.with(CutsceneCast.sit_tied(), {"head": Vector3(0.45, 0.0, 0.0), "neck": Vector3(0.2, 0, 0), "spineA": Vector3(0.3, 0, 0), "chest": Vector3(0.18, 0, 0)}), 1.0)
	await wait(1.0)
	# Пишет пальцем на пыльном столе
	_writing = true
	var scratch := loop("finger_dust", -10.0)
	shot(Vector3(0.05, 1.45, 0.48), Vector3(-0.02, CraneHouse.TABLE_Y, -0.22), 50.0)
	handheld = 0.3
	var writing: Label3D = house.writing
	for i in WORDS.length() + 1:
		writing.text = WORDS.substr(0, i)
		await wait(0.16 if WORDS[mini(i, WORDS.length() - 1)] != "\n" else 0.45)
	stop(scratch, 0.2)
	_writing = false
	await wait(1.6)
	# У дальней стены — старый каменный очаг
	glide(Vector3(0.75, 1.5, 1.35), CraneHouse.HEARTH + Vector3(0.25, 0.95, 0), 1.6, 46.0)
	await wait(2.4)
	# Ремни: нож, рывок — ремень падает
	knife_rig.visible = true
	shot(SAM_SEAT + Vector3(0.78, 0.98, -0.32), SAM_SEAT + Vector3(0.21, 0.5, 0.05), 46.0)
	for i in 2:
		var st: Node3D = straps[1 - i]
		if i == 1:
			shot(SAM_SEAT + Vector3(-0.78, 0.98, -0.32), SAM_SEAT + Vector3(-0.21, 0.5, 0.05), 46.0)
		tween_prop(knife_rig, "position", Vector3(0.05, -0.2, -0.38), 0.35)
		await wait(0.4)
		sfx("strap_cut", -4.0)
		tween_prop(knife_rig, "position", Vector3(0.22, -0.25, -0.34), 0.2)
		tween_prop(st, "position", st.position + Vector3(0, -0.48, 0.04), 0.35, Tween.TRANS_QUAD, Tween.EASE_IN)
		tween_prop(st, "rotation_degrees", Vector3(60, 20, 0), 0.35)
		await wait(0.9)
	knife_rig.visible = false
	# Сэм пытается встать — ноги не держат
	shot(C_ACROSS + Vector3(0.6, -0.1, -0.2), SAM_SEAT + Vector3(0, 0.9, 0), 50.0)
	_go_pose(CutsceneCast.with(CutsceneCast.sit_table(), {"hips_pos": Vector3(0, -0.25, 0.1), "spineA": Vector3(0.55, 0, 0), "chest": Vector3(0.3, 0, 0), "head": Vector3(0.3, 0, 0), "shL": Vector3(-0.6, 0, -0.3), "shR": Vector3(-0.6, 0, 0.3)}), 0.8)
	await wait(0.9)
	# Ноги не держат: сползает со стула вбок, на пол между стулом и очагом
	shot(SAM_SEAT + Vector3(-1.75, 1.2, -0.95), SAM_SEAT + Vector3(-0.4, 0.5, -0.1), 50.0)
	sfx("body_slump", -2.0)
	_go_pose(CutsceneCast.with(CutsceneCast.sit_floor(), {"spineA": Vector3(0.2, 0, 0), "head": Vector3(0.4, 0.1, 0.1)}), 0.4)
	tween_prop(sam, "position", SAM_SEAT + Vector3(-0.62, 0, -0.14), 0.4, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(sam, "rotation_degrees", Vector3(0, 28, 0), 0.4)
	shake(0.4)
	await wait(1.5)
	# Итан тащит его к стене у очага
	black(1.0)
	sfx("drag_body", -6.0)
	await wait(1.3)
	sam.position = SAM_WALL
	sam.rotation_degrees = Vector3(0, 90, 0)
	_pose_from = {}
	_pose_to = CutsceneCast.sit_floor()
	_pose_u = 1.0
	CutsceneCast.pose(sam, _pose_to)
	(house.chairs.elder as Node3D).rotation_degrees.y = 160.0
	shot(C_KNEEL, SAM_WALL + Vector3(0.1, 0.75, 0), 52.0)
	handheld = 0.4
	fade_in(0.6)
	await wait(1.6)
	# Снаружи — копыта. Медленно. Уверенно. Тень в пустом окне.
	sw.visible = true
	_sw_walk = true
	look_to(CraneHouse.WIN_R + Vector3(0.0, 0.05, 0.0), 1.6)
	for i in 6:
		sfx("hoof_ground_%d" % (i % 4 + 1), -6.0 + i * 0.5, 1.0, sw.global_position, 6.0)
		await wait(0.95)
	look_to(SAM_WALL + Vector3(0.1, 0.8, 0), 1.4)
	await wait(1.6)
	fade_out(1.6)
	stop(amb, 1.6)
	await wait(1.8)
	await card("КОНЕЦ ГЛАВЫ 4", "", 2.6, 0.8)
