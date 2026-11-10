extends Cutscene

# ПЛОХАЯ КОНЦОВКА (игрок нажал «Ответить» в главе 5). «Я здесь, пап», — говорит Итан.
# Череп выпадает из рук. Голоса снаружи разом смолкают. Темнота.
# Последний кадр: дом Крейна, стол с четырьмя тарелками. На стуле «Отец» — что-то
# в отцовской одежде, на «Старшем» — Сэм, на «Младшем» — Итан. Глаза пустые, руки на
# столе. Во главе стола садится высокая чёрная фигура. Семья в сборе. КОНЕЦ.

const STAND := Vector3(-1.55, 1.62, 0.55)    # перед очагом Досыма: его полка-бревно не загораживает топку
const CAM_A := Vector3(2.55, 1.95, 2.25)
const CAM_B := Vector3(1.75, 1.7, 1.55)

var house: Dictionary
var fire: CutsceneKit.Fire
var skull_rig: Node3D
var family: Array = []
var sw: SkinwalkerModel
var _sit_u := -1.0


func build() -> void:
	set_env(Color(0.02, 0.025, 0.04), Color(0.22, 0.24, 0.33), 0.7, 0.015, Color(0.04, 0.04, 0.06), 1.25)
	house = CraneHouse.build(self)
	(house.hearth_ash as Node3D).visible = false
	fire = CutsceneKit.fire(self, house.fire_pos, 1.0)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.8
	moon.rotation_degrees = Vector3(-68, 30, 0)
	moon.shadow_enabled = true
	add_child(moon)
	# Череп в руках у камеры
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
	# Семья за столом — спрятана до последнего кадра
	var father := CutsceneCast.father_thing()
	var sam := CutsceneCast.sam()
	var ethan := CutsceneCast.ethan()
	CutsceneCast.eyes(sam, "empty")
	CutsceneCast.eyes(ethan, "empty")
	var seats := [[father, CraneHouse.FATHER + Vector3(0, 0, 0.04), 180.0], [sam, CraneHouse.ELDER + Vector3(0, 0, -0.04), 0.0], [ethan, CraneHouse.YOUNGER + Vector3(0.04, 0, 0), -90.0]]
	for seat in seats:
		var m: PlayerModel = seat[0]
		add_child(m)
		m.position = seat[1]
		m.rotation_degrees = Vector3(0, seat[2], 0)
		CutsceneCast.pose(m, CutsceneCast.with(CutsceneCast.sit_table(), {"head": Vector3(-0.02, 0, 0), "neck": Vector3(0.02, 0, 0)}))
		m.visible = false
		family.append(m)
	# Высокая чёрная фигура подходит к стулу во главе стола
	sw = CutsceneCast.skinwalker()
	add_child(sw)
	sw.position = CraneHouse.HEAD + Vector3(-0.95, 0, 1.25)
	sw.rotation_degrees = Vector3(0, 145, 0)
	sw.visible = false


func tick(delta: float) -> void:
	if _sit_u < 0.0:
		return
	if _sit_u < 1.0:
		_sit_u = minf(1.0, _sit_u + delta / 2.2)
	var u := _sit_u * _sit_u * (3.0 - 2.0 * _sit_u)
	CutsceneCast.sw_pose(sw, {
		"lth": lerpf(-0.04, -1.45, u), "rth": lerpf(-0.04, -1.45, u),
		"lkn": lerpf(0.1, 1.5, u), "rkn": lerpf(0.1, 1.5, u),
		"pitch": lerpf(0.14, 0.05, u), "neck": 0.1, "hx": lerpf(0.0, 0.08, u),
		"lsx": lerpf(0.04, -0.85, u), "rsx": lerpf(0.04, -0.85, u), "lsz": 0.12, "rsz": 0.12,
		"lex": lerpf(-0.2, -0.75, u), "rex": lerpf(-0.2, -0.75, u), "curl_l": 0.35, "curl_r": 0.35,
	})


func run() -> void:
	var fire_snd := loop("fire_loop", -9.0, 0.4, house.fire_pos, 5.0)
	var voices := sfx("voices_outside", -6.0)
	handheld = 0.6
	breathe = 1.4
	shot(STAND, house.fire_pos + Vector3(0, 0.4, 0), 56.0)
	fade_in(0.5)
	shake(0.25)
	await wait(1.6)
	# «Я здесь, пап»
	await line("ethan_here", "ИТАН", "Я здесь, пап.", 0.2)
	# Череп выпадает из рук. Голоса разом смолкают
	tween_prop(skull_rig, "position", Vector3(0.05, -1.1, -0.55), 0.45, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(skull_rig, "rotation_degrees", Vector3(40, 0, 25), 0.45)
	await wait(0.4)
	if voices:
		voices.queue_free()
	stop(fire_snd, 0.05)
	sfx("skull_drop", -2.0)
	handheld = 0.0
	breathe = 0.0
	await wait(0.9)
	# Темнота
	black(1.0)
	await wait(2.6)
	# Последний кадр: семья в сборе
	for m in family:
		(m as Node3D).visible = true
	tween_prop(fire, "level", 0.55, 0.1)
	var drone := loop("drone_family", -14.0, 3.0)
	var fire2 := loop("fire_loop", -20.0, 2.0, house.fire_pos, 5.0)
	# Пустые глаза: Итан, Сэм, «отец» — руки на столе, никто не шевелится
	shot(Vector3(0.62, 1.22, -1.0), CraneHouse.YOUNGER + Vector3(0.04, 1.2, 0.0), 34.0)
	glide(Vector3(0.7, 1.22, -0.9), CraneHouse.YOUNGER + Vector3(0.04, 1.2, 0.0), 3.4, 32.0)
	fade_in(2.2)
	await wait(3.4)
	shot(Vector3(0.42, 1.25, 0.3), CraneHouse.ELDER + Vector3(0, 1.15, 0.08), 34.0)
	glide(Vector3(0.36, 1.24, 0.2), CraneHouse.ELDER + Vector3(0, 1.15, 0.08), 2.8, 32.0)
	await wait(2.8)
	shot(Vector3(-0.5, 1.3, -0.25), CraneHouse.FATHER + Vector3(0, 1.25, -0.06), 36.0)
	glide(Vector3(-0.45, 1.28, -0.2), CraneHouse.FATHER + Vector3(0, 1.25, -0.06), 2.8, 34.0)
	await wait(2.8)
	# Во главе стола садится высокая чёрная фигура (огонь за спиной)
	shot(Vector3(2.55, 1.72, 0.05), CraneHouse.HEAD + Vector3(0.2, 1.25, 0.0), 40.0)
	glide(Vector3(2.2, 1.66, 0.04), CraneHouse.HEAD + Vector3(0.1, 1.35, 0.0), 9.0, 36.0)
	await wait(1.2)
	sw.visible = true
	var walk_t := 0.0
	var from := sw.position
	var to := CraneHouse.HEAD + Vector3(-0.08, 0, 0.0)
	while walk_t < 2.4 and not skipping:
		walk_t += get_process_delta_time()
		sw.position = from.lerp(to, clampf(walk_t / 2.4, 0.0, 1.0))
		sw.update_motion(get_process_delta_time(), "walk", 0.55)
		if int(walk_t / 0.8) != int((walk_t - get_process_delta_time()) / 0.8):
			sfx("hoof_wood_%d" % (int(walk_t / 0.8) % 4 + 1), -10.0, 0.9, sw.global_position, 5.0)
		await get_tree().process_frame
	tween_prop(sw, "rotation_degrees", Vector3(0, 90, 0), 0.6)
	sfx("chair_scrape", -6.0, 1.0, CraneHouse.HEAD, 5.0)
	_sit_u = 0.0
	await wait(3.2)
	await card("Семья в сборе.", "", 2.6, 1.4)
	fade_out(2.0)
	stop(drone, 2.5)
	stop(fire2, 2.0)
	await wait(2.6)
	await card("КОНЕЦ", "", 3.0, 1.2)
