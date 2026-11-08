extends Cutscene

# КОНЕЦ ГЛАВЫ 1 · «За углом». Итан идёт вдоль стены гаража (стена справа),
# доходит до угла и поворачивает направо. Оно уже ждало его там. Дальше — темнота.
# Гараж, поленница и дом — с карты «Шоссе» (Досым), чтобы угол совпадал с игрой.
# Камера в конце смотрит на юго-западный угол гаража: x = -53.15, z = -213.15.

const MAP := "res://scenes/Шоссе.json"
const START := Vector3(-53.6, 1.5, -207.4)
const AT_CORNER := Vector3(-53.6, 1.47, -212.75)
const PAST_CORNER := Vector3(-53.5, 1.45, -213.62)
const CREATURE := Vector3(-52.05, 0.0, -213.72)

var sw: SkinwalkerModel
var hand: CutsceneCast.Hand
var _scare := false
var _scare_t := 0.0


func build() -> void:
	set_env(Color(0.015, 0.02, 0.03), Color(0.16, 0.19, 0.28), 0.9, 0.012, Color(0.05, 0.06, 0.09), 1.15)
	CutsceneKit.map_area(self, MAP, Vector3(-53, 0, -212), 34.0)
	CutsceneKit.ground(self, Vector3(-53, 0.0, -212), Vector2(90, 90), CutsceneKit.tmat("forest_floor.png", Color(0.55, 0.6, 0.5), 0.35))
	CutsceneKit.grass(self, Vector3(-55.0, 0, -209), Vector2(3, 10), 60, 11, 0.7)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 1.1
	moon.rotation_degrees = Vector3(-30, -70, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)
	# Существо: стоит сразу за углом, лицом к Итану
	sw = CutsceneCast.skinwalker()
	add_child(sw)
	sw.position = CREATURE
	sw.rotation_degrees = Vector3(0, -90, 0)
	CutsceneCast.sw_pose(sw, {"pitch": 0.45, "neck": 0.3, "hx": 0.25, "hz": 0.3, "lsx": 0.1, "rsx": -0.2, "lex": -0.4, "rex": -0.6, "lkn": 0.3, "rkn": 0.25, "lth": -0.15, "rth": -0.1})
	var rim := OmniLight3D.new()
	rim.light_color = Color(0.5, 0.6, 0.9)
	rim.light_energy = 1.6
	rim.omni_range = 4.5
	rim.position = CREATURE + Vector3(1.6, 2.6, -1.0)
	add_child(rim)
	var face := OmniLight3D.new()
	face.light_color = Color(0.55, 0.62, 0.8)
	face.light_energy = 0.9
	face.omni_range = 2.6
	face.position = CREATURE + Vector3(-0.8, 1.9, 0.4)
	add_child(face)
	# Правая ладонь скользит по доскам
	hand = CutsceneCast.hand(false)
	cam.add_child(hand)
	hand.position = Vector3(0.3, -0.24, -0.34)
	hand.rotation_degrees = Vector3(10, -75, -80)
	hand.curl = 0.15


func tick(delta: float) -> void:
	if _scare:
		_scare_t += delta
		sw.apply_scare_pose(clampf(_scare_t * 3.0, 0.0, 1.0))
		# Склонилось к самому лицу
		sw._rot("spineA", 0.34)
		sw._rot("spineB", 0.4)
		sw._rot("chest", 0.22)
		sw._rot("neckA", 0.25)
		cam_look = cam_look.lerp(sw.get_head_position(), minf(1.0, delta * 9.0))


func run() -> void:
	var wind := loop("amb_night_wind", -12.0, 0.4)
	handheld = 0.6
	breathe = 1.0
	# Спиной к стене, шаг за шагом вдоль досок
	shot(START, START + Vector3(-0.2, -0.05, -3.0), 62.0)
	fade_in(0.8)
	sfx("ethan_breath_held", -8.0)
	move_to(AT_CORNER, 3.4, Tween.TRANS_LINEAR)
	for i in 4:
		sfx("step_grass_%d" % (i + 1), -16.0)
		if i == 1:
			sfx("hand_slide_wood", -12.0)
		await wait(0.85)
	# Угол. Направо.
	handheld = 0.3
	hand.visible = false
	move_to(PAST_CORNER, 0.6)
	look_to(PAST_CORNER + Vector3(2.5, 0.1, -0.1), 0.6, Tween.TRANS_SINE, Tween.EASE_IN)
	await wait(0.55)
	# Оно уже ждало
	_scare = true
	var hit := sfx("stinger_hit", 0.0)
	var cry := sfx("res://assets/audio/intro/creature_shriek.wav", -6.0)
	shake(1.2)
	stop(wind, 0.1)
	move_to(PAST_CORNER + Vector3(-0.25, -0.1, 0.05), 0.35, Tween.TRANS_EXPO, Tween.EASE_OUT)
	if vhs():
		vhs().call("glitch", 0.9)
	await wait(0.66)
	# Дальше — темнота
	black(1.0)
	silence(0.05)
	stop(cry, 0.05)
	await wait(1.4)
	sfx("res://assets/audio/intro/body_fall.wav", -10.0)
	await wait(2.4)
	stop(hit, 1.0)
	await wait(0.4)
