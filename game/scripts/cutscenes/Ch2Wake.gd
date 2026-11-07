extends Cutscene

# НАЧАЛО ГЛАВЫ 2 · «Пробуждение» (10–15 с). Итан приходит в себя на холодном полу
# подвала: голова раскалывается, пахнет сыростью и землёй — это подвал их дома.
# Он садится, узнаёт столб с отметками роста и отцовский шкаф. Сверху — копыта:
# тк… тк… тк… медленно, по ступенькам, вниз. Дальше управление сразу у игрока.
#
# Камера в конце: сидит на полу у центра подвала, смотрит на лестницу.
# args.from_gameplay = true — без затемнения в конце (игра продолжается в той же позе).

const LIE := Vector3(0.8, 0.17, 1.4)
const SIT := Vector3(0.75, 0.86, 1.35)
const STAIRS_TOP := Vector3(-2.9, 2.4, -2.1)
const POST := Vector3(-0.2, 0.0, -0.4)
const WARDROBE := Vector3(2.85, 0.0, -1.6)

var door_light: OmniLight3D


func build() -> void:
	set_env(Color(0.0, 0.0, 0.0), Color(0.36, 0.36, 0.4), 1.25, 0.02, Color(0.05, 0.05, 0.06), 1.5)
	build_basement(self)
	door_light = OmniLight3D.new()
	door_light.light_color = Color(0.55, 0.6, 0.75)
	door_light.light_energy = 1.6
	door_light.omni_range = 4.0
	door_light.position = Vector3(-2.9, 2.6, -2.35)
	add_child(door_light)
	# Свет из дома сквозь щели пола: холодные пятна на земле
	for p in [Vector3(-1.4, 2.3, -1.95), Vector3(0.2, 2.3, -0.5), Vector3(1.3, 2.3, 0.8), Vector3(2.2, 2.3, 1.95)]:
		var sl := SpotLight3D.new()
		sl.light_color = Color(0.62, 0.68, 0.85)
		sl.light_energy = 3.5
		sl.spot_range = 3.4
		sl.spot_angle = 26.0
		sl.shadow_enabled = false
		add_child(sl)
		sl.position = p
		sl.rotation_degrees = Vector3(-90, 0, 0)


# Подвал: главная комната (лестница к двери, верстак, шкаф, столб с отметками),
# проходы в кладовую и котельную. Пол под домом — потолок с щелями между досками.
static func build_basement(root: Node3D) -> void:
	var stone := CutsceneKit.tmat("concrete.png", Color(0.55, 0.53, 0.5), 0.8, 0.95)
	var earth := CutsceneKit.tmat("dirt_path.png", Color(0.55, 0.5, 0.44), 0.5)
	var wood := CutsceneKit.tmat("board_weathered.png", Color(0.55, 0.47, 0.4), 1.4)
	var beam_m := CutsceneKit.tmat("wood_furniture.png", Color(0.42, 0.33, 0.25), 1.2)
	# Пол, стены (фундамент), потолок-пол дома
	CutsceneKit.box(root, Vector3(8, 0.1, 7), Vector3(0, -0.05, 0), earth)
	CutsceneKit.wall(root, Vector3(-3.5, 0, 3.3), Vector3(-3.5, 0, -3.3), 2.35, 0.3, stone)
	CutsceneKit.wall(root, Vector3(3.5, 0, -3.3), Vector3(3.5, 0, 3.3), 2.35, 0.3, stone, Rect2(4.2, 0.0, 0.9, 1.95))
	CutsceneKit.wall(root, Vector3(-3.5, 0, -3.3), Vector3(3.5, 0, -3.3), 2.35, 0.3, stone, Rect2(4.6, 0.0, 0.95, 1.95))
	CutsceneKit.wall(root, Vector3(3.5, 0, 3.3), Vector3(-3.5, 0, 3.3), 2.35, 0.3, stone)
	# Балки и доски пола над головой; в щели пробивается свет из дома
	for i in 9:
		var x := -3.2 + i * 0.8
		CutsceneKit.box(root, Vector3(0.1, 0.16, 6.6), Vector3(x, 2.27, 0), beam_m)
	var gaps := [-2.05, -0.62, 0.71, 1.83]
	var z := -3.3
	while z < 3.3:
		var w := 0.19
		var gap := 0.0
		for g in gaps:
			if absf(z - g) < 0.1:
				gap = 0.012
		# Над лестницей — проём в полу дома (лестничный колодец)
		if z > -2.75 and z < -0.75:
			CutsceneKit.box(root, Vector3(5.75, 0.04, w - gap), Vector3(0.525, 2.37, z + w * 0.5), wood)
		else:
			CutsceneKit.box(root, Vector3(6.8, 0.04, w - gap), Vector3(0, 2.37, z + w * 0.5), wood)
		z += w
	for g in gaps:
		var slit := CutsceneKit.box(root, Vector3(6.6, 0.01, 0.01), Vector3(0, 2.395, g + 0.1), CutsceneKit.glow(Color(0.65, 0.72, 0.9), 1.4), Vector3.ZERO, false)
		slit.name = "Slit"
	CutsceneKit.box(root, Vector3(0.3, 0.3, 6.6), Vector3(-0.2, 2.1, 0), beam_m)
	# Деревянный столб с отметками роста братьев
	CutsceneKit.box(root, Vector3(0.2, 2.2, 0.2), POST + Vector3(0, 1.1, 0), beam_m)
	var marks := [["С — 6", 1.12], ["И — 4", 1.0], ["С — 7", 1.18], ["И — 5", 1.06], ["С — 10", 1.36], ["И — 7", 1.2], ["С — 14", 1.6], ["И — 11", 1.43], ["С — 18", 1.8], ["И — 15", 1.7]]
	for m in marks:
		var y: float = m[1]
		var s: String = m[0]
		var right := s.begins_with("С")
		CutsceneKit.box(root, Vector3(0.12, 0.006, 0.004), POST + Vector3(0.0 if right else 0.0, y, 0.102), CutsceneKit.mat(Color(0.15, 0.11, 0.08), 0.9))
		CutsceneKit.text3d(root, s, POST + Vector3(0.07 if right else -0.07, y + 0.012, 0.103), Vector3.ZERO, 0.00055, Color(0.2, 0.14, 0.1), 28)
	# Лестница к основной двери (левая стена), дверь приоткрыта
	for i in 10:
		var step := CutsceneKit.box(root, Vector3(0.9, 0.05, 0.3), Vector3(-2.9, 0.2 + i * 0.205, 2.3 - i * 0.43), wood)
		step.name = "Step%d" % i
	for s in [-1.0, 1.0]:
		CutsceneKit.beam(root, Vector3(-2.9 + 0.47 * s, 0.0, 2.55), Vector3(-2.9 + 0.47 * s, 2.25, -1.85), Vector2(0.06, 0.22), beam_m)
	# Колодец лестницы: площадка и дверь наверху, из-под двери — полоска света
	CutsceneKit.box(root, Vector3(1.05, 0.08, 1.0), Vector3(-2.9, 2.27, -2.2), wood)
	for x in [-3.42, -2.38]:
		CutsceneKit.box(root, Vector3(0.06, 2.4, 2.0), Vector3(x, 3.55, -1.75), wood)
	CutsceneKit.box(root, Vector3(1.1, 2.4, 0.06), Vector3(-2.9, 3.55, -2.75), wood)
	var d := CutsceneKit.door(root, Vector3(-3.32, 2.31, -2.68), Vector3.ZERO, 0.84, 2.0)
	(d.leaf as Node3D).rotation_degrees = Vector3(0, -6, 0)
	CutsceneKit.box(root, Vector3(0.8, 0.012, 0.02), Vector3(-2.9, 2.315, -2.64), CutsceneKit.glow(Color(0.7, 0.75, 0.95), 1.6), Vector3.ZERO, false)
	# Верстак отца с ящиком, сундук под ним
	var bench := Vector3(1.6, 0, 3.0)
	CutsceneKit.box(root, Vector3(2.0, 0.08, 0.7), bench + Vector3(0, 0.9, 0), beam_m)
	for x in [-0.9, 0.9]:
		for zz in [-0.28, 0.28]:
			CutsceneKit.box(root, Vector3(0.08, 0.9, 0.08), bench + Vector3(x, 0.45, zz), beam_m)
	CutsceneKit.box(root, Vector3(0.55, 0.22, 0.28), bench + Vector3(-0.4, 1.05, 0.05), CutsceneKit.mat(Color(0.45, 0.12, 0.08), 0.5, 0.6))
	CutsceneKit.box(root, Vector3(0.8, 0.45, 0.45), bench + Vector3(0.3, 0.23, 0.0), CutsceneKit.tmat("wood_furniture.png", Color(0.38, 0.28, 0.2), 1.5))
	CutsceneKit.cyl(root, 0.03, 0.03, 0.09, bench + Vector3(0.55, 0.99, -0.1), CutsceneKit.mat(Color(0.85, 0.82, 0.72), 0.6))
	# Отцовский шкаф для рабочей одежды
	CutsceneKit.prefab(root, "prop_wardrobe", Vector3(1.2, 2.0, 0.6), WARDROBE, Vector3(0, -90, 0), Color(0.42, 0.33, 0.25))
	# Кладовая (полки с банками) за проёмом и тёмная котельная
	var shelf := Vector3(2.4, 0, -4.2)
	for k in 4:
		CutsceneKit.box(root, Vector3(1.6, 0.04, 0.4), shelf + Vector3(0, 0.3 + k * 0.45, 0), wood)
		for j in 6:
			var jar := CutsceneKit.cyl(root, 0.06, 0.06, 0.16, shelf + Vector3(-0.65 + j * 0.26, 0.4 + k * 0.45, 0.02), CutsceneKit.mat(Color(0.5, 0.42, 0.25, 1.0), 0.15))
			jar.material_override.set("metallic_specular", 0.8)
	CutsceneKit.box(root, Vector3(2.0, 2.3, 0.2), Vector3(2.4, 1.15, -4.5), stone)
	CutsceneKit.cobweb(root, Vector3(3.3, 2.15, -3.1), 0.6, Vector3(0, 225, 0))
	CutsceneKit.cobweb(root, Vector3(-3.3, 2.15, 3.1), 0.7, Vector3(0, 45, 0))
	CutsceneKit.dust(root, Vector3(0, 1.2, 0), Vector3(3, 1, 3), 80)
	# Тряпьё и разбитый фонарик там, где он лежал
	CutsceneKit.box(root, Vector3(0.12, 0.04, 0.05), LIE + Vector3(-0.5, -0.15, 0.4), CutsceneKit.mat(Color(0.12, 0.12, 0.13), 0.4, 0.6), Vector3(0, 30, 0))


func run() -> void:
	var from_game: bool = args.get("from_gameplay", false)
	var amb := loop("amb_basement", -14.0, 3.0)
	var ring := sfx("res://assets/audio/intro/tinnitus.wav", -14.0)
	muffle(900.0, 0.01)
	lids(0.0, 0.0)
	black(0.0)
	blur(0.012, 0.01, 0.006)
	vignette(0.6, 0.01)
	# Лежит на боку у самого пола
	shot(LIE, LIE + Vector3(2.0, 0.2, -1.6), 64.0, -1.25)
	await wait(0.7)
	lids(0.32, 1.2)
	await wait(1.5)
	sfx("ethan_groan", -6.0)
	lids(0.0, 0.25)
	await wait(0.9)
	# Переворачивается: доски над головой, полоски света
	shot(LIE + Vector3(0.05, 0.05, 0), LIE + Vector3(0.6, 2.2, -0.2), 64.0, -0.5)
	lids(0.6, 1.0)
	blur(0.007, 1.5, 0.003)
	tween_prop(self, "cam_roll", 0.0, 2.2)
	await wait(1.6)
	# Садится
	sfx("body_shift", -8.0)
	glide(SIT, POST + Vector3(0.0, 1.15, 0.1), 1.6, 60.0, Tween.TRANS_SINE, Tween.EASE_OUT)
	lids(1.0, 1.2)
	blur(0.0015, 1.6, 0.0)
	muffle(4000.0, 2.0)
	if ring:
		fade(ring, -24.0, 3.0)
	handheld = 0.7
	breathe = 1.0
	await wait(1.8)
	# Узнаёт: столб, отметки «С — 18», «И — 15», отцовский шкаф
	look_to(POST + Vector3(0.0, 1.38, 0.1), 1.0)
	await wait(1.5)
	look_to(WARDROBE + Vector3(-0.3, 0.95, 0), 1.4)
	await wait(1.3)
	# Сверху — копыта. Медленно, по ступенькам. Вниз.
	muffle(20000.0, 0.3)
	vignette(0.35, 1.0)
	look_to(Vector3(-2.85, 2.45, -2.1), 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	handheld = 0.35
	sfx("ethan_gasp", -9.0)
	for i in 3:
		sfx("hoof_wood_%d" % (i + 1), -4.0 + i, 1.0, STAIRS_TOP + Vector3(0.2, 0.0, 0.4 + i * 0.43), 6.0)
		door_light.light_energy = 0.8 - 0.2 * i
		await wait(1.05)
	if ring:
		stop(ring, 0.5)
	if not from_game:
		sfx("hoof_wood_4", -2.0, 1.0, STAIRS_TOP + Vector3(0.2, -0.4, 1.3), 6.0)
		fade_out(1.2)
		stop(amb, 1.2)
		await wait(1.6)
