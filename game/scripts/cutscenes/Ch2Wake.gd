extends Cutscene

# НАЧАЛО ГЛАВЫ 2 · «Пробуждение» (≈16 с). Подвал Досыма под домом на карте «Шоссе».
# Итан приходит в себя на холодном бетонном полу главной комнаты: голова раскалывается,
# пахнет сыростью и землёй — это подвал их дома. Фонарик разбит, свет падает только
# полосками сквозь щели в полу дома. Итан садится: столб с отметками роста, отцовский шкаф
# у стены. Сверху — копыта. За приоткрытой дверью наверху лестницы проходит тень,
# дверь со скрипом открывается, и стук спускается по ступенькам: тк… тк… тк…
#
# Итан лежит там же, куда его кладёт игра (HighwayChapter.BASEMENT_WAKE), и в конце смотрит
# на лестницу (BASEMENT_LOOK). Дальше — геймплей (HighwayChapter._run_basement_wake).
# args.from_gameplay = true — без затемнения в конце.

const MAP := "res://scenes/Шоссе.json"
const WAKE := Vector3(-58.0, -4.2, -227.5)          # HighwayChapter.BASEMENT_WAKE (на полу)
const LOOK := Vector3(-54.4, -4.2, -221.0)          # HighwayChapter.BASEMENT_LOOK
const POST := Vector3(-58.5, -4.2, -225.0)          # столб с отметками роста, отметки на южной грани
const WARDROBE := Vector3(-59.0, -4.2, -219.72)     # отцовский шкаф у северной стены
const DOOR_HINGE := Vector3(-54.86, -2.69, -219.15)  # дверь наверху лестницы, петли с дальней от Итана стороны
const DOOR_TOP := Vector3(-54.4, -1.75, -219.3)
const LANDING := Vector3(-54.3, -2.7, -220.1)
const LIE := Vector3(-57.7, -4.03, -227.3)
const SIT := Vector3(-57.75, -3.34, -227.45)
const DOOR_ID := 3035                                # дверь с карты не строим: здесь своя, она открывается

var door_leaf: Node3D
var hall_light: OmniLight3D      # свет в тамбуре за дверью (через люк в потолке тамбура)
var legs: Node3D                 # тень того, кто стоит за дверью: видна только тень
var ceiling_dust: CPUParticles3D


func build() -> void:
	set_env(Color(0.0, 0.0, 0.0), Color(0.42, 0.47, 0.62), 3.2, 0.02, Color(0.04, 0.05, 0.07), 1.5)
	# Только подвал: дом над ним в кадр не попадает
	CutsceneKit.map_area(self, MAP, Vector3(-58.0, 0.0, -225.0), 11.0, [], [DOOR_ID], AABB(), true, -0.3)
	_door()
	_floor_light()
	_details()


# Дверь наверху лестницы приоткрыта; за ней тамбур, где светлее
func _door() -> void:
	# Минус — створка уходит в тамбур, за край проёма: из подвала её не видно
	var d := CutsceneKit.door(self, DOOR_HINGE, Vector3.ZERO, 0.92, 1.95, "wood_door.png")
	door_leaf = d.leaf
	door_leaf.rotation_degrees = Vector3(0, -6, 0)
	hall_light = OmniLight3D.new()
	hall_light.light_color = Color(0.5, 0.58, 0.8)
	hall_light.light_energy = 3.2
	hall_light.omni_range = 3.4
	hall_light.shadow_enabled = true
	hall_light.position = Vector3(-54.4, -1.3, -218.0)
	add_child(hall_light)
	# Полоска света под дверью
	CutsceneKit.box(self, Vector3(0.86, 0.004, 0.05), Vector3(-54.4, -2.69, -219.32), CutsceneKit.glow(Color(0.55, 0.62, 0.85), 0.9), Vector3.ZERO, false)
	legs = CutsceneKit.node(self, Vector3(-55.4, -2.69, -218.4), Vector3.ZERO, "Legs")
	var dark := CutsceneKit.mat(Color(0.02, 0.02, 0.02), 0.6)
	for s in [-1.0, 1.0]:
		var leg := CutsceneKit.cyl(legs, 0.035, 0.05, 1.5, Vector3(0.12 * s, 0.75, 0.0), dark)
		leg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


# «Свет падал только полосками сквозь щели в полу»: щели между досками над головой светятся,
# под каждой на бетоне — полоска света, вокруг — слабое пятно.
# (light_projector у SpotLight3D здесь гасит свет целиком, поэтому полосы — отдельные плоскости.)
func _floor_light() -> void:
	var stripe := CutsceneKit.add_mat(Color(0.5, 0.58, 0.82, 0.55), _stripe_tex())
	var slit := CutsceneKit.glow(Color(0.65, 0.72, 0.92), 1.2)
	for c in [Vector3(-56.6, 0.0, -226.0), Vector3(-58.4, 0.0, -226.7), Vector3(-54.8, 0.0, -222.7), Vector3(-60.2, 0.0, -222.4)]:
		var sl := SpotLight3D.new()
		sl.light_color = Color(0.62, 0.68, 0.88)
		sl.light_energy = 2.2
		sl.spot_range = 5.0
		sl.spot_angle = 26.0
		sl.shadow_enabled = false
		add_child(sl)
		sl.position = Vector3(c.x, -0.76, c.z)
		sl.rotation_degrees = Vector3(-90, 0, 0)
		for z in [-0.42, -0.1, 0.02, 0.55]:
			CutsceneKit.box(self, Vector3(2.4, 0.004, 0.012), Vector3(c.x, -0.702, c.z + z), slit, Vector3.ZERO, false)
			var q := CutsceneKit.quad(self, Vector2(2.7, 0.09), Vector3(c.x, -4.195, c.z + z * 1.08), stripe, Vector3(-90, 0, 0))
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Полоска света: мягкие края поперёк, затухает к концам
static func _stripe_tex() -> ImageTexture:
	var img := Image.create(128, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		var across := clampf(1.0 - absf(y - 7.5) / 8.0, 0.0, 1.0)
		for x in 128:
			var along := pow(sin(PI * x / 127.0), 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, pow(across, 1.6) * along))
	return ImageTexture.create_from_image(img)


func _details() -> void:
	# Разбитый фонарик там, где Итан лежал
	var torch := CutsceneKit.node(self, LIE + Vector3(0.55, -0.155, 0.45), Vector3(0, 35, 90), "Torch")
	var metal := CutsceneKit.mat(Color(0.09, 0.09, 0.1), 0.4, 0.7)
	CutsceneKit.cyl(torch, 0.019, 0.019, 0.16, Vector3.ZERO, metal)
	CutsceneKit.cyl(torch, 0.028, 0.022, 0.04, Vector3(0, 0.1, 0), metal)
	var glass := CutsceneKit.mat(Color(0.7, 0.75, 0.8, 0.5), 0.05, 0.3)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 7:
		var p := LIE + Vector3(0.62 + rng.randf_range(-0.08, 0.12), -0.168, 0.55 + rng.randf_range(-0.06, 0.12))
		CutsceneKit.box(self, Vector3(rng.randf_range(0.006, 0.016), 0.002, rng.randf_range(0.005, 0.012)), p, glass, Vector3(0, rng.randf_range(0, 180), 0), false)
	# Лампочка без света: до щитка в котельной она не горит
	var bulb_at := Vector3(-58.0, -0.7, -225.8)
	CutsceneKit.cyl(self, 0.004, 0.004, 0.32, bulb_at + Vector3(0, -0.16, 0), CutsceneKit.mat(Color(0.05, 0.05, 0.05), 0.8))
	CutsceneKit.ball(self, 0.035, bulb_at + Vector3(0, -0.36, 0), CutsceneKit.mat(Color(0.2, 0.19, 0.17, 1.0), 0.5), Vector3(1.0, 1.25, 1.0), 10)
	# Узкая полоса света из щели ложится на столб с отметками роста
	var post_light := SpotLight3D.new()
	post_light.light_color = Color(0.62, 0.68, 0.88)
	post_light.light_energy = 7.0
	post_light.spot_range = 4.2
	post_light.spot_angle = 9.0
	post_light.shadow_enabled = false
	add_child(post_light)
	post_light.look_at_from_position(Vector3(-58.45, -0.78, -226.2), POST + Vector3(0.0, 1.4, -0.15), Vector3.UP)
	CutsceneKit.cobweb(self, Vector3(-53.45, -0.9, -230.5), 0.6, Vector3(0, 225, 0))
	CutsceneKit.cobweb(self, Vector3(-61.7, -0.9, -219.5), 0.7, Vector3(0, 45, 0))
	CutsceneKit.cobweb(self, Vector3(-58.36, -0.95, -225.15), 0.35, Vector3(0, 180, 0))
	CutsceneKit.dust(self, Vector3(-56.8, -2.6, -225.6), Vector3(2.4, 1.5, 2.4), 70)
	# Земля, что сыплется с досок, когда наверху ступает копыто
	ceiling_dust = CutsceneKit.debris(self, Vector3(-57.2, -0.75, -226.4), Vector3(0.9, 0.02, 0.5), 45, Color(0.3, 0.27, 0.22), 0.012, 1.4)


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	var amb := loop("amb_basement", -14.0, 3.0)
	var ring := sfx("res://assets/audio/intro/tinnitus.wav", -14.0)
	muffle(900.0, 0.01)
	lids(0.0, 0.0)
	black(0.0)
	blur(0.012, 0.01, 0.006)
	vignette(0.6, 0.01)
	# Лежит на боку щекой на бетоне: полоска света, осколки фонарика
	shot(LIE, LIE + Vector3(1.9, 0.12, 1.6), 64.0, -1.25)
	await wait(0.6)
	lids(0.32, 1.1)
	await wait(1.4)
	sfx("ethan_groan", -6.0)
	lids(0.0, 0.25)
	await wait(0.8)
	# Переворачивается на спину: доски пола дома, свет в щелях
	shot(LIE + Vector3(0.0, 0.04, 0.0), LIE + Vector3(0.4, 3.0, 0.7), 64.0, -0.5)
	lids(0.6, 1.0)
	blur(0.007, 1.4, 0.003)
	tween_prop(self, "cam_roll", 0.0, 1.8)
	await wait(1.15)
	# Садится. Столб с отметками роста — их подвал
	sfx("body_shift", -8.0)
	glide(SIT, POST + Vector3(0.05, 1.35, -0.15), 1.6, 60.0, Tween.TRANS_SINE, Tween.EASE_OUT)
	lids(1.0, 1.2)
	blur(0.0, 1.8, 0.0)
	muffle(4000.0, 2.0)
	if ring:
		fade(ring, -24.0, 3.0)
	handheld = 0.7
	breathe = 1.0
	await wait(1.55)
	look_to(POST + Vector3(0.1, 1.72, -0.15), 0.9)
	await wait(1.0)
	# Отцовский шкаф у стены
	look_to(WARDROBE + Vector3(0.0, 1.05, -0.3), 1.1)
	await wait(1.0)
	# Сверху — копыта. По полу дома, к двери
	muffle(20000.0, 0.3)
	sfx("hoof_muffled_2", -3.0, 1.0, Vector3(-57.2, 0.1, -226.0), 8.0)
	ceiling_dust.restart()
	ceiling_dust.emitting = true
	sfx("dirt_trickle", -14.0)
	look_to(Vector3(-57.0, -1.2, -225.4), 0.45, Tween.TRANS_QUAD, Tween.EASE_OUT)
	blur(0.0, 0.5)
	handheld = 0.3
	sfx("ethan_gasp", -9.0)
	await wait(0.85)
	sfx("hoof_muffled_3", -5.0, 1.0, Vector3(-55.5, 0.1, -219.5), 8.0)
	look_to(DOOR_TOP, 0.8)
	await wait(0.6)
	# За дверью проходит тень: свет в щели гаснет и снова загорается
	tween_prop(legs, "position:x", -53.5, 1.1, Tween.TRANS_LINEAR)
	tween_prop(hall_light, "light_energy", 0.9, 0.45)
	await wait(0.5)
	tween_prop(hall_light, "light_energy", 3.2, 0.5)
	await wait(0.6)
	# Дверь медленно открывается
	sfx("res://assets/audio/monster/basement_door_open.wav", -7.0, 0.85, DOOR_TOP, 6.0)
	tween_prop(door_leaf, "rotation_degrees:y", -82.0, 2.0, Tween.TRANS_SINE, Tween.EASE_OUT)
	await wait(1.4)
	# Пустой тамбур, скобы на стене — и свет заслоняет что-то большое. В проёме темно
	sfx("creature_breath", -16.0, 0.9, DOOR_TOP, 4.0)
	tween_prop(hall_light, "light_energy", 0.1, 0.7, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween_prop(env, "ambient_light_energy", 2.3, 2.0)
	vignette(0.5, 1.6)
	await wait(0.8)
	# Тк… тк… тк… Медленно, по ступенькам. Вниз
	for i in 3:
		sfx("hoof_wood_%d" % (i + 1), -4.0 + i, 1.0, LANDING + Vector3(0.0, -0.13 * i, -0.3 - 0.27 * i), 6.0)
		await wait(0.85)
	if ring:
		stop(ring, 0.5)
	if not from_game:
		sfx("hoof_wood_4", -2.0, 1.0, LANDING + Vector3(0.0, -0.4, -1.1), 6.0)
		fade_out(0.9)
		stop(amb, 1.1)
		await wait(1.2)
