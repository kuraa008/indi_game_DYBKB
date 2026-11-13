extends Cutscene

# ГЛАВА 5 · «Имя». Огонь в очаге. Итан бросает череп в огонь — существо врывается:
# окно разлетается, стул летит в стену. Итан встаёт между ним и огнём и кричит
# ему в лицо (кнопка «Назвать имя»): «ДЖОЗЕФ КРЕЙН!» Существо замирает. Череп
# трескается, существо падает на колени, шкура сползает, как мокрая одежда — под
# ней старый худой человек с седой бородой. «Марта… Мальчики… Я не хотел… Зима
# была такая долгая…» Он тянется к стулу во главе стола и рассыпается в пепел.
# Огонь гаснет. Тишина без копыт. И голос Сэма — его собственный: «Итан…»
#
# args.from_gameplay = true — череп уже брошен в огонь (реплика «Ты не мой отец…»
# и бросок — в геймплее), кат-сцена начинается с того, как существо врывается.

const STAND := Vector3(-1.55, 1.62, 0.6)     # перед очагом Досыма: его полка-бревно не загораживает топку
const SAM_WALL := Vector3(-2.62, 0.0, 1.62)    # у стены рядом с очагом (очаг Досыма шириной ±1.05 по z)
const KNEEL_AT := Vector3(-1.05, 0.0, -0.62)
const OUTSIDE := Vector3(0.8, 0.0, -3.5)

var house: Dictionary
var fire: CutsceneKit.Fire
var sam: PlayerModel
var crane: PlayerModel
var sw: SkinwalkerModel
var skin_mat: ShaderMaterial
var skull_rig: Node3D
var fire_skull: Node3D
var ash_pile: MeshInstance3D
var ash_fx: CPUParticles3D
var _sw_mode := ""
var _sw_t := 0.0
var _sw_from := Vector3.ZERO
var _crane_pose := {}
var slide := 0.0
var wet := 0.0


func build() -> void:
	set_env(Color(0.02, 0.025, 0.04), Color(0.26, 0.28, 0.38), 0.75, 0.012, Color(0.05, 0.05, 0.07), 1.25)
	house = CraneHouse.build(self)
	(house.hearth_ash as Node3D).visible = false
	fire = CutsceneKit.fire(self, house.fire_pos, 1.0)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.9
	moon.rotation_degrees = Vector3(-68, 30, 0)
	moon.shadow_enabled = true
	add_child(moon)
	# Дрова у очага, сломанные доски
	var wood := CutsceneKit.tmat("board_weathered.png", Color(0.42, 0.34, 0.27), 1.6)
	for i in 5:
		CutsceneKit.box(self, Vector3(0.5, 0.05, 0.08), CraneHouse.HEARTH + Vector3(0.6 + i * 0.03, 0.03 + i * 0.05, -0.75 + i * 0.05), wood, Vector3(0, 30 + i * 22, 0))
	# Сэм у стены
	sam = CutsceneCast.sam()
	add_child(sam)
	sam.position = SAM_WALL
	sam.rotation_degrees = Vector3(0, 90, 0)
	CutsceneCast.pose(sam, CutsceneCast.sit_floor())
	# Существо — за окном; Крейн спрятан внутри него
	sw = CutsceneCast.skinwalker()
	add_child(sw)
	sw.position = OUTSIDE
	sw.rotation_degrees = Vector3(0, 0, 0)
	sw.visible = false
	skin_mat = CutsceneCast.sw_slide_material(sw)
	crane = CutsceneCast.crane()
	add_child(crane)
	crane.position = KNEEL_AT
	crane.visible = false
	_crane_pose = CutsceneCast.with(CutsceneCast.kneel(), {"head": Vector3(0.02, 0, 0), "neck": Vector3(0.05, 0, 0), "spineA": Vector3(0.2, 0, 0), "chest": Vector3(0.1, 0, 0)})
	CutsceneCast.pose(crane, _crane_pose)
	# Череп: в руках у камеры и второй — в огне
	skull_rig = Node3D.new()
	cam.add_child(skull_rig)
	skull_rig.position = Vector3(0.02, -0.2, -0.5)
	var sk := CutsceneKit.deer_skull(skull_rig)
	sk.rotation_degrees = Vector3(-18, 78, 0)
	sk.scale = Vector3.ONE * 1.1
	for s in [-1.0, 1.0]:
		var h := CutsceneCast.hand(s < 0.0)
		skull_rig.add_child(h)
		h.position = Vector3(0.1 * s, -0.065, 0.01 if s < 0.0 else 0.04)
		h.rotation_degrees = Vector3(-15, -30 * s, 65 * s)
		h.curl = 0.6
	fire_skull = CutsceneKit.deer_skull(self)
	fire_skull.position = house.fire_pos + Vector3(0.05, 0.08, 0.0)
	fire_skull.rotation_degrees = Vector3(10, 120, 20)
	fire_skull.visible = false
	# Пепел
	ash_pile = CutsceneKit.ball(self, 0.4, KNEEL_AT + Vector3(0, 0.0, 0), CutsceneKit.mat(Color(0.2, 0.19, 0.18), 1.0), Vector3(1.0, 0.01, 1.0), 12)
	ash_fx = CutsceneKit.debris(self, KNEEL_AT + Vector3(0, 1.2, 0), Vector3(0.25, 0.45, 0.25), 160, Color(0.35, 0.34, 0.33), 0.012, 2.6)
	ash_fx.gravity = Vector3(0, -0.6, 0)
	ash_fx.explosiveness = 0.15


func tick(delta: float) -> void:
	_sw_t += delta
	if skin_mat:
		skin_mat.set_shader_parameter("slide", slide)
		skin_mat.set_shader_parameter("wet", wet)
	match _sw_mode:
		"burst":
			# Влетает в окно и бросается к очагу
			var u := clampf(_sw_t / 0.95, 0.0, 1.0)
			sw.position = _sw_from.lerp(KNEEL_AT + Vector3(0.15, 0, -0.05), 1.0 - pow(1.0 - u, 2.2))
			sw.update_motion(delta, "sprint" if SkinwalkerModel.GAITS.has("sprint") else "run", 6.0, 1.0)
		"face":
			sw.apply_scare_pose(clampf(_sw_t * 2.5, 0.0, 1.0))
			sw._rot("spineA", 0.3)
			sw._rot("spineB", 0.35)
			sw._rot("chest", 0.2)
		"frozen":
			pass


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	var amb := loop("amb_crane_house", -16.0, 0.5)
	var fire_snd := loop("fire_loop", -8.0, 0.5, house.fire_pos, 5.0)
	handheld = 0.45
	breathe = 0.9
	shot(STAND + Vector3(0.1, 0, -0.05), house.fire_pos + Vector3(0, 0.35, 0), 56.0)
	if not from_game:
		var voices := sfx("voices_outside", -10.0)
		fade_in(1.4)
		await wait(2.4)
		# Итан закрывает глаза
		lids(0.0, 0.5)
		await wait(0.6)
		if voices:
			fade(voices, -40.0, 1.0)
		await line("ethan_not_father", "ИТАН", "Ты не мой отец. Мой отец сделал всё, чтобы я сюда не вернулся.", 0.3)
		lids(1.0, 0.4)
		await wait(0.4)
		# И бросает череп в огонь
		tween_prop(skull_rig, "position", Vector3(-0.05, -0.32, -1.2), 0.45, Tween.TRANS_QUAD, Tween.EASE_IN)
		await wait(0.42)
		skull_rig.visible = false
		fire_skull.visible = true
		sfx("fire_ignite", -4.0, 1.0, house.fire_pos, 5.0)
		tween_prop(fire, "level", 1.5, 0.3)
		await wait(0.9)
	else:
		skull_rig.visible = false
		fire_skull.visible = true
		fade_in(0.4)
		await wait(0.6)
	tween_prop(fire, "level", 1.0, 1.0)
	# Окно разлетается, стул летит в стену
	sfx("window_smash", 0.0, 1.0, CraneHouse.WIN_L, 6.0)
	sfx("res://assets/audio/intro/creature_shriek.wav", -4.0, 1.0, CraneHouse.WIN_L, 6.0)
	flash(Color(0.6, 0.65, 0.8, 0.25), 0.3)
	shake(1.0)
	glide(STAND + Vector3(0.25, 0, -0.3), CraneHouse.WIN_L + Vector3(0, -0.2, 0), 0.35, 60.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
	for i in house.shutters.size():
		var shn: Node3D = house.shutters[i]
		tween_prop(shn, "position", shn.position + Vector3(-0.6 + i * 1.2, -0.9, 1.6 + i * 0.4), 0.55, Tween.TRANS_QUAD, Tween.EASE_IN)
		tween_prop(shn, "rotation_degrees", Vector3(80, 40 * (i * 2 - 1), 30), 0.55)
	sw.visible = true
	sw.position = OUTSIDE + Vector3(0, 0, 0.6)
	sw.look_at_from_position(sw.position, Vector3(KNEEL_AT.x, 0, KNEEL_AT.z), Vector3.UP)
	sw.rotate_y(PI)
	_sw_from = sw.position
	_sw_t = 0.0
	_sw_mode = "burst"
	var younger: Node3D = house.chairs.younger
	tween_prop(younger, "position", Vector3(2.75, 1.0, -1.2), 0.45, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween_prop(younger, "rotation_degrees", Vector3(40, 200, 70), 0.45)
	await wait(0.4)
	sfx("chair_crash", -2.0, 1.0, Vector3(2.8, 1.0, -1.3), 6.0)
	sfx("creature_lunge", -2.0, 1.0, sw.position, 6.0)
	# Итан встаёт между ним и огнём
	glide(STAND + Vector3(0.35, -0.02, -0.55), KNEEL_AT + Vector3(0.2, 1.9, -0.1), 0.6, 58.0, Tween.TRANS_QUAD, Tween.EASE_OUT)
	await wait(0.6)
	_sw_mode = "face"
	_sw_t = 0.0
	shake(0.6)
	await wait(0.45)
	look_to(sw.get_head_position(), 0.3)
	await wait(0.4)
	# Время будто встаёт: кнопка «Назвать имя»
	muffle(700.0, 0.3)
	fade(fire_snd, -16.0, 0.3)
	var heart := loop("heartbeat_slow", -12.0, 0.3)
	await prompt("Назвать имя")
	muffle(20000.0, 0.05)
	stop(heart, 0.1)
	# «ДЖОЗЕФ КРЕЙН!»
	shake(1.0)
	var name_len := say_line("ethan_name", "ИТАН", "ДЖОЗЕФ КРЕЙН!", null, 3.0)
	await wait(maxf(0.3, name_len - 0.35))
	_sw_mode = "frozen"
	sfx("freeze_hit", -2.0)
	stop(amb, 0.05)
	fade(fire_snd, -12.0, 0.05)
	handheld = 0.1
	await wait(1.6)
	# Череп в огне трескается
	shot(STAND + Vector3(0.35, -0.95, -0.15), house.fire_pos + Vector3(0.05, 0.12, 0), 44.0)
	await wait(0.5)
	sfx("skull_crack", 0.0, 1.0, house.fire_pos, 5.0)
	tween_prop(fire_skull, "rotation_degrees", Vector3(35, 140, 45), 0.25)
	tween_prop(fire_skull, "scale", Vector3(1.05, 0.85, 1.05), 0.25)
	tween_prop(fire, "level", 1.6, 0.15)
	flash(Color(1.0, 0.6, 0.3, 0.3), 0.4)
	await wait(1.2)
	tween_prop(fire, "level", 1.0, 1.0)
	# Существо падает на колени
	shot(STAND + Vector3(-0.15, -0.15, 0.25), KNEEL_AT + Vector3(0, 1.4, 0), 52.0)
	handheld = 0.3
	_sw_mode = ""
	for h in sw.halos:
		h.visible = false
	var kneel_t := 0.0
	while kneel_t < 0.5 and not skipping:
		kneel_t += get_process_delta_time()
		var u := clampf(kneel_t / 0.5, 0.0, 1.0)
		CutsceneCast.sw_pose(sw, {"lth": lerpf(-0.04, -0.05, u), "rth": lerpf(-0.04, -0.05, u), "lkn": lerpf(0.1, 1.62, u), "rkn": lerpf(0.1, 1.62, u), "pitch": lerpf(0.14, 0.35, u), "neck": 0.3, "hx": 0.2, "lsx": 0.1, "rsx": 0.1, "lex": -0.5, "rex": -0.5})
		await get_tree().process_frame
	sfx("kneel_thud", -2.0, 1.0, KNEEL_AT, 5.0)
	shake(0.3)
	await wait(1.0)
	# Шкура сползает, как старая мокрая одежда
	sfx("skin_slide", -2.0, 1.0, KNEEL_AT, 5.0)
	crane.rotation.y = sw.rotation.y
	crane.visible = true
	tween_prop(self, "slide", 1.0, 4.0, Tween.TRANS_SINE, Tween.EASE_IN)
	tween_prop(self, "wet", 1.0, 1.5)
	glide(STAND + Vector3(0.0, -0.3, 0.05), KNEEL_AT + Vector3(0, 1.15, 0), 4.0, 46.0)
	await wait(4.2)
	sw.visible = false
	# Старик смотрит на стол с четырьмя тарелками
	_turn_crane(Vector3(0.0, 0.0, 0.0), 1.6)
	await wait(1.8)
	# Три четверти спереди: длинные волосы Крейна (модель Досыма) уходят за спину, лицо открыто
	shot(KNEEL_AT + Vector3(0.78, 1.1, 1.02), KNEEL_AT + Vector3(-0.05, 1.12, -0.02), 40.0)
	await line("crane_1", "КРЕЙН", "Марта… Мальчики…", 0.4, KNEEL_AT + Vector3(0, 1.2, 0), 2.0, 4.0)
	await line("crane_2", "КРЕЙН", "Я не хотел…", 0.4, KNEEL_AT + Vector3(0, 1.2, 0), 2.0, 4.0)
	await line("crane_3", "КРЕЙН", "Зима была такая долгая…", 0.4, KNEEL_AT + Vector3(0, 1.2, 0), 2.0, 4.0)
	# Тянется к стулу во главе стола — и рассыпается в пепел, не дотянувшись
	glide(STAND + Vector3(-0.1, -0.12, 0.3), KNEEL_AT + Vector3(-0.1, 1.0, 0.3), 2.0, 52.0)
	_turn_crane(CraneHouse.HEAD, 1.2)
	var reach := CutsceneCast.with(_crane_pose, {"shR": Vector3(-1.35, 0.0, 0.25), "elR": Vector3(-0.15, 0, 0), "shL": Vector3(-0.2, 0, -0.2), "head": Vector3(-0.05, 0, 0), "spineA": Vector3(0.35, 0, 0)})
	var rt := 0.0
	while rt < 1.6 and not skipping:
		rt += get_process_delta_time()
		CutsceneCast.pose(crane, CutsceneCast.mix_pose(_crane_pose, reach, clampf(rt / 1.6, 0.0, 1.0)))
		await get_tree().process_frame
	sfx("ash_crumble", -2.0, 1.0, KNEEL_AT, 5.0)
	ash_fx.restart()
	ash_fx.emitting = true
	var ash_v := 1.95
	tween_prop(ash_pile, "scale", Vector3(1.0, 0.22, 1.0), 3.0)
	var eyes_node := crane.skeleton.get_node_or_null("Eyes") as Node3D
	var beard_node := crane.skeleton.get_node_or_null("Beard") as Node3D
	# Волосы, брови, ремень с ножом — не на шейдере кожи: прячем вместе с бородой
	var hair_nodes: Array = []
	for nm in ["Hair", "Brows"]:
		var n := crane.skeleton.get_node_or_null(nm)
		if n:
			hair_nodes.append(n)
	var rags_node := crane.find_child("Rags", true, false) as Node3D
	while ash_v > -0.1 and not skipping:
		ash_v -= get_process_delta_time() * 0.68
		CutsceneCast.set_param(crane, "ash", ash_v)
		if eyes_node and ash_v < 1.66:
			eyes_node.visible = false
		if beard_node and ash_v < 1.5:
			beard_node.visible = false
		if ash_v < 1.5:
			for n in hair_nodes:
				n.visible = false
		if rags_node and ash_v < 0.9:
			rags_node.visible = false
		await get_tree().process_frame
	crane.visible = false
	# Огонь гаснет
	sfx("fire_die", -3.0, 1.0, house.fire_pos, 5.0)
	tween_prop(fire, "level", 0.0, 2.2)
	stop(fire_snd, 2.0)
	tween_prop(env, "ambient_light_energy", 0.6, 2.5)
	var moon_sam := OmniLight3D.new()
	moon_sam.light_color = Color(0.55, 0.63, 0.9)
	moon_sam.light_energy = 0.0
	moon_sam.omni_range = 2.6
	moon_sam.position = SAM_WALL + Vector3(0.9, 1.9, -0.2)
	add_child(moon_sam)
	tween_prop(moon_sam, "light_energy", 1.1, 2.5)
	await wait(3.4)
	# Тишина. Настоящая. И голос Сэма — свой
	look_to(SAM_WALL + Vector3(0.15, 0.82, 0.0), 2.2)
	await wait(2.6)
	await line("sam_ethan_weak", "СЭМ", "Итан…", 1.4, SAM_WALL + Vector3(0.2, 0.9, 0), 2.0, 4.0)
	await wait(1.0)
	fade_out(2.0)
	await wait(2.4)


func _turn_crane(target: Vector3, dur: float) -> void:
	var dir := target - crane.position
	var yaw := atan2(dir.x, dir.z)
	tween_prop(crane, "rotation:y", yaw, dur)
