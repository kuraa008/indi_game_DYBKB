extends Node3D

# Галерея поз ИИ: снимки для проверки анимаций. Запуск с окном: --path game res://scratch/ai_pose_gallery.tscn
var cam: Camera3D
var shots := []

func light(pos: Vector3, energy: float = 6.0) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.omni_range = 14.0
	l.light_energy = energy
	add_child(l)

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://scratch/g_%s.png" % name_)
	print("SHOT ", name_)

func _sw_pose(model: SkinwalkerModel, gait: String, speed: float, seconds: float) -> void:
	for i in range(int(seconds * 60.0)):
		model.update_motion(1.0 / 60.0, gait, speed)
		await get_tree().process_frame

func _lj_pose(model: LumberjackModel, mode: String, speed: float, seconds: float) -> void:
	for i in range(int(seconds * 60.0)):
		model.update_motion(1.0 / 60.0, mode, speed)
		await get_tree().process_frame

func _ready() -> void:
	GameManager.set_process(false)
	GameManager.vhs_enabled = false
	GameManager.set_resolution_mode("1280x720")
	var floor_body := StaticBody3D.new()
	var fm := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.28)
	plane.material = mat
	fm.mesh = plane
	floor_body.add_child(fm)
	add_child(floor_body)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.1, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.6)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	light(Vector3(2, 4, 3), 8.0)
	light(Vector3(-3, 3, 2), 4.0)
	cam = Camera3D.new()
	cam.position = Vector3(2.6, 1.3, 3.4)
	cam.current = true
	add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))

	# ── Скинвокер ──
	var sw := SkinwalkerModel.new()
	add_child(sw)
	for g in [["walk", 1.4, 1.5], ["stalk", 2.0, 1.5], ["listen", 0.0, 1.5], ["lurk", 0.0, 2.0], ["creep", 2.2, 1.5], ["dash", 9.6, 0.8], ["recover", 0.0, 0.7]]:
		await _sw_pose(sw, g[0], g[1], g[2])
		await _shot("sw_" + g[0])
	sw.visible = false

	# Глаза в темноте: только их и видно
	var dark := SkinwalkerModel.new()
	add_child(dark)
	e.ambient_light_energy = 0.02
	for c in get_children():
		if c is OmniLight3D:
			c.visible = false
	dark.set_eye_glow(3.6)
	await _sw_pose(dark, "lurk", 0.0, 2.0)
	cam.position = Vector3(1.0, 1.1, 9.0)
	cam.look_at(Vector3(0, 0.9, 0))
	await _shot("sw_eyes_dark")
	dark.visible = false
	e.ambient_light_energy = 0.7
	for c in get_children():
		if c is OmniLight3D:
			c.visible = true

	# ── Лесоруб ──
	cam.position = Vector3(2.4, 1.4, 3.0)
	cam.look_at(Vector3(0, 0.8, 0))
	var lj := LumberjackModel.new()
	add_child(lj)
	for m in [["exercise", 0.0, 2.6, "squat"], ["exercise", 0.0, 1.0, "squat2"], ["stretch", 0.0, 2.0, "stretch"], ["look", 0.0, 1.5, "look"], ["check", 0.0, 1.5, "check"], ["winded", 2.8, 1.5, "winded"], ["aim", 0.0, 1.0, "aim"]]:
		await _lj_pose(lj, m[0], m[1], m[2])
		await _shot("lj_" + m[3])
	# Махи руками во второй половине цикла зарядки
	lj._t = 9.0
	await _lj_pose(lj, "exercise", 0.0, 1.0)
	await _shot("lj_armswing")
	# Удар
	await _lj_pose(lj, "walk", 0.0, 0.8)
	lj.melee_strike()
	await _lj_pose(lj, "melee", 0.0, 0.28)
	await _shot("lj_melee_windup")
	await _lj_pose(lj, "melee", 0.0, 0.2)
	await _shot("lj_melee_hit")
	lj.visible = false

	# Мебель: настоящие префабы и расчёт посадки из Lumberjack.gd
	var ctrl: Node = load("res://scenes/Lumberjack.tscn").instantiate()
	add_child(ctrl)
	ctrl.set_physics_process(false)
	ctrl.global_position = Vector3(30, 0, 30)
	var sofa := PrefabBuilder.build_prefab("prop_sofa", Vector3(2.4, 0.95, 1.05), Color.WHITE, false)
	sofa.set_meta("prefab_type", "prop_sofa")
	add_child(sofa)
	var bed := PrefabBuilder.build_prefab("prop_bed", Vector3(1.48, 0.88, 2.12), Color.WHITE, false)
	bed.set_meta("prefab_type", "prop_bed")
	bed.position = Vector3(-4.5, 0, 0)
	add_child(bed)
	var chair := PrefabBuilder.build_prefab("prop_armchair", Vector3(1.1, 0.95, 1.0), Color.WHITE, false)
	chair.set_meta("prefab_type", "prop_armchair")
	chair.position = Vector3(4.5, 0, 0)
	add_child(chair)
	var seated := LumberjackModel.new()
	add_child(seated)
	seated.global_transform = ctrl._sit_transform(sofa)
	await _lj_pose(seated, "sit", 0.0, 2.2)
	await _shot("lj_sit_sofa")
	seated.global_transform = ctrl._lie_transform(sofa)
	await _lj_pose(seated, "lie", 0.0, 2.2)
	await _shot("lj_lie_sofa")
	cam.position = Vector3(-2.2, 1.6, 2.6)
	cam.look_at(Vector3(-4.5, 0.6, 0))
	seated.global_transform = ctrl._lie_transform(bed)
	await _lj_pose(seated, "lie", 0.0, 1.0)
	await _shot("lj_lie_bed")
	cam.position = Vector3(6.6, 1.3, 3.0)
	cam.look_at(Vector3(4.5, 0.7, 0))
	seated.global_transform = ctrl._sit_transform(chair)
	await _lj_pose(seated, "sit", 0.0, 1.0)
	await _shot("lj_sit_chair")
	print("GALLERY DONE")
	get_tree().quit()
