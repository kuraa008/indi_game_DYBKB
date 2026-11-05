extends Area3D

# ──────────────────────────────────────────────
#  Item pickup — crowbar or key
#  item_type is stored in node meta before add_child()
# ──────────────────────────────────────────────

var item_type:  String = "crowbar"
var key_id:     int    = 1
var collected:  bool   = false
var base_y:     float  = 0.0
var anim_time:  float  = 0.0

func _ready() -> void:
	item_type = str(get_meta("item_type", "crowbar")).to_lower()
	var is_a_key := false
	if item_type == "key" or item_type.begins_with("key") or item_type.begins_with("item_key") or item_type.begins_with("custom_item_key") or has_meta("key_id") or has_meta("lock_id"):
		is_a_key = true

	if is_a_key:
		if has_meta("key_id"):
			key_id = int(get_meta("key_id"))
		elif has_meta("lock_id"):
			key_id = int(get_meta("lock_id"))
		elif item_type.begins_with("key_id_"):
			key_id = int(item_type.trim_prefix("key_id_"))
		elif item_type.begins_with("item_key_id_"):
			key_id = int(item_type.trim_prefix("item_key_id_"))
		elif "silver" in item_type:
			key_id = 2
		elif "emerald" in item_type:
			key_id = 3
		elif "ruby" in item_type:
			key_id = 4
		elif "sapphire" in item_type:
			key_id = 5
		elif "rusty" in item_type:
			key_id = 6
		else:
			key_id = 1
		if key_id <= 0:
			key_id = 1
		set_meta("key_id", key_id)
		set_meta("is_pickable", true)
		item_type = "key"
	elif item_type in ["crowbar", "item_crowbar", "custom_item_crowbar"]:
		item_type = "crowbar"
		set_meta("item_type", "crowbar")
		set_meta("is_pickable", true)
	elif item_type in ["bottle", "item_bottle", "custom_item_bottle"]:
		item_type = "bottle"
		set_meta("item_type", "bottle")
		set_meta("is_pickable", true)
	else:
		item_type = item_type.trim_prefix("custom_").trim_prefix("item_")
		set_meta("item_type", item_type)
		set_meta("is_pickable", true)

	base_y    = position.y
	_build_collision()
	_build_visual()

# ──────────────────────────────────────────────
func _build_collision() -> void:
	var col    = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.36 if item_type == "crowbar" else 0.22
	col.shape     = sphere
	add_child(col)

func _build_visual() -> void:
	var mi  = MeshInstance3D.new()
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.4
	mat.metallic = 0.6


	match item_type:
		"crowbar":
			var crowbar = MeshInstance3D.new()
			crowbar.name = "CrowbarModel"
			crowbar.mesh = HouseKit.crowbar_mesh()
			add_child(crowbar)
		"key", "key_gold", "key_silver", "key_rusty", "key_emerald", "key_ruby", "key_sapphire", "item_key", "custom_item_key":
			# Реалистичный благородный ключ с фигурным кольцом, стержнем, зубцами и цветной биркой-брелоком с номером
			var DoorScript = load("res://scripts/Door.gd")
			var th = DoorScript.get_lock_theme(key_id)

			var metal_mat = StandardMaterial3D.new()
			metal_mat.albedo_color = th["color"]
			metal_mat.metallic = th["metallic"]
			metal_mat.roughness = th["roughness"]
			metal_mat.emission_enabled = true
			metal_mat.emission = th["emission"]
			metal_mat.emission_energy_multiplier = 0.65

			# 1. Круглая фигурная головка ключа (Bow)
			var bow = MeshInstance3D.new()
			var bm_bow = TorusMesh.new()
			bm_bow.inner_radius = 0.032
			bm_bow.outer_radius = 0.065
			bm_bow.material = metal_mat
			bow.mesh = bm_bow
			bow.rotation_degrees = Vector3(90, 0, 0)
			bow.position = Vector3(-0.10, 0, 0)
			add_child(bow)

			# Центральное кольцо головки
			var bow_cross = MeshInstance3D.new()
			var bcm = BoxMesh.new()
			bcm.size = Vector3(0.016, 0.012, 0.08)
			bcm.material = metal_mat
			bow_cross.mesh = bcm
			bow_cross.position = Vector3(-0.10, 0, 0)
			add_child(bow_cross)

			# 2. Шейка ключа (Shoulder collar)
			var collar = MeshInstance3D.new()
			var col_m = CylinderMesh.new()
			col_m.top_radius = 0.022
			col_m.bottom_radius = 0.018
			col_m.height = 0.03
			col_m.material = metal_mat
			collar.mesh = col_m
			collar.rotation_degrees = Vector3(0, 0, 90)
			collar.position = Vector3(-0.035, 0, 0)
			add_child(collar)

			# 3. Цилиндрический стержень ключа (Shaft)
			var shaft = MeshInstance3D.new()
			var sm = CylinderMesh.new()
			sm.top_radius = 0.014
			sm.bottom_radius = 0.014
			sm.height = 0.24
			sm.material = metal_mat
			shaft.mesh = sm
			shaft.rotation_degrees = Vector3(0, 0, 90)
			shaft.position = Vector3(0.09, 0, 0)
			add_child(shaft)

			# Продольная канавка на стержне (Milling flute)
			var flute = MeshInstance3D.new()
			var flm = BoxMesh.new()
			flm.size = Vector3(0.20, 0.005, 0.008)
			var dark_flute = StandardMaterial3D.new()
			dark_flute.albedo_color = Color(0.1, 0.1, 0.1)
			flm.material = dark_flute
			flute.mesh = flm
			flute.position = Vector3(0.09, 0, 0.014)
			add_child(flute)

			# 4. Бородка с 4 зубцами разной высоты (Bit & Bitting teeth)
			var teeth_heights = [0.038, 0.058, 0.032, 0.052]
			for ti in range(4):
				var tooth = MeshInstance3D.new()
				var tm = BoxMesh.new()
				tm.size = Vector3(0.024, teeth_heights[ti], 0.012)
				tm.material = metal_mat
				tooth.mesh = tm
				tooth.position = Vector3(0.12 + ti * 0.024, -teeth_heights[ti] * 0.5, 0)
				add_child(tooth)

			# 5. Соединительное кольцо для брелока (Split ring)
			var split_ring = MeshInstance3D.new()
			var srm = TorusMesh.new()
			srm.inner_radius = 0.018
			srm.outer_radius = 0.028
			var ring_mat = StandardMaterial3D.new()
			ring_mat.albedo_color = Color(0.75, 0.78, 0.82)
			ring_mat.metallic = 0.95
			ring_mat.roughness = 0.15
			srm.material = ring_mat
			split_ring.mesh = srm
			split_ring.position = Vector3(-0.165, 0, 0)
			split_ring.rotation_degrees = Vector3(0, 45, 90)
			add_child(split_ring)

			# 6. Прямоугольная бирка-брелок отеля с номером (Hotel key tag)
			var tag = MeshInstance3D.new()
			var tag_m = BoxMesh.new()
			tag_m.size = Vector3(0.14, 0.075, 0.012)
			var tag_mat = StandardMaterial3D.new()
			tag_mat.albedo_color = th["color"].lerp(Color(0.1, 0.1, 0.1), 0.25)
			tag_mat.metallic = 0.85
			tag_mat.roughness = 0.35
			tag_mat.emission_enabled = true
			tag_mat.emission = th["emission"]
			tag_mat.emission_energy_multiplier = 0.4
			tag_m.material = tag_mat
			tag.mesh = tag_m
			tag.position = Vector3(-0.25, 0, 0)
			tag.rotation_degrees = Vector3(0, 15, 0)
			add_child(tag)

			# Металлический ободок отверстия (Grommet)
			var grommet = MeshInstance3D.new()
			var grm = TorusMesh.new()
			grm.inner_radius = 0.010
			grm.outer_radius = 0.018
			grm.material = ring_mat
			grommet.mesh = grm
			grommet.position = Vector3(0.048, 0, 0)
			grommet.rotation_degrees = Vector3(90, 0, 0)
			tag.add_child(grommet)

			# Чёткий 3D номер на бирке
			var k_lbl = Label3D.new()
			k_lbl.name = "KeyNumber"
			k_lbl.text = "№%d" % key_id
			k_lbl.font_size = 32
			k_lbl.pixel_size = 0.0013
			k_lbl.outline_size = 5
			k_lbl.outline_modulate = Color(0, 0, 0, 1)
			k_lbl.modulate = Color(1.0, 0.98, 0.92, 1.0)
			k_lbl.position = Vector3(-0.015, 0.001, 0.008)
			tag.add_child(k_lbl)

			var k_glow = OmniLight3D.new()
			k_glow.light_color = th["emission"]
			k_glow.light_energy = 0.9
			k_glow.omni_range = 2.0
			add_child(k_glow)

			mi.visible = false

		"battery":
			# Battery cylinder with gold contact and green/black body
			var cm = CylinderMesh.new()
			cm.top_radius = 0.08
			cm.bottom_radius = 0.08
			cm.height = 0.32
			var bmat = StandardMaterial3D.new()
			bmat.albedo_color = Color(0.12, 0.55, 0.22) # Яркий зелёный корпус
			bmat.emission_enabled = true
			bmat.emission = Color(0.1, 0.4, 0.2)
			bmat.emission_energy_multiplier = 0.6
			cm.material = bmat
			mi.mesh = cm

			# Gold contact on top
			var cap_mesh = CylinderMesh.new()
			cap_mesh.top_radius = 0.035
			cap_mesh.bottom_radius = 0.035
			cap_mesh.height = 0.06
			var cap_mat = StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.95, 0.80, 0.10)
			cap_mat.metallic = 0.8
			cap_mesh.material = cap_mat
			var cap_inst = MeshInstance3D.new()
			cap_inst.mesh = cap_mesh
			cap_inst.position = Vector3(0, 0.17, 0)
			add_child(cap_inst)

		"road_flare":
			var flare_mesh = CylinderMesh.new()
			flare_mesh.top_radius = 0.055
			flare_mesh.bottom_radius = 0.075
			flare_mesh.height = 0.42
			var flare_mat = StandardMaterial3D.new()
			flare_mat.albedo_color = Color(0.72, 0.12, 0.055)
			flare_mat.roughness = 0.72
			flare_mesh.material = flare_mat
			mi.mesh = flare_mesh
			var flare_tip = MeshInstance3D.new()
			var tip_mesh = SphereMesh.new()
			tip_mesh.radius = 0.075
			tip_mesh.height = 0.15
			var tip_mat = StandardMaterial3D.new()
			tip_mat.albedo_color = Color(1.0, 0.24, 0.07)
			tip_mat.emission_enabled = true
			tip_mat.emission = Color(1.0, 0.12, 0.025)
			tip_mat.emission_energy_multiplier = 2.2
			tip_mesh.material = tip_mat
			flare_tip.mesh = tip_mesh
			flare_tip.position = Vector3(0, 0.2, 0)
			add_child(flare_tip)
			var flare_light = OmniLight3D.new()
			flare_light.light_color = Color(1.0, 0.16, 0.045)
			flare_light.light_energy = 1.8
			flare_light.omni_range = 3.8
			flare_light.shadow_enabled = false
			add_child(flare_light)

		"note", "note_safe", "note_safe_code":
			# Torn scrap of paper
			var pm = BoxMesh.new()
			pm.size = Vector3(0.36, 0.005, 0.28)
			var nmat = StandardMaterial3D.new()
			nmat.albedo_color = Color(0.92, 0.88, 0.76)
			nmat.roughness = 0.9
			pm.material = nmat
			mi.mesh = pm
			# Decorative torn strip
			var strip = MeshInstance3D.new()
			var smesh = BoxMesh.new()
			smesh.size = Vector3(0.32, 0.006, 0.04)
			var smat = StandardMaterial3D.new()
			smat.albedo_color = Color(0.35, 0.20, 0.10)
			smesh.material = smat
			strip.mesh = smesh
			strip.position = Vector3(0, 0.003, -0.08)
			add_child(strip)

			if item_type in ["note_safe", "note_safe_code"]:
				# Красная сургучная печать / метка
				var seal = MeshInstance3D.new()
				var sm = CylinderMesh.new()
				sm.top_radius = 0.04
				sm.bottom_radius = 0.04
				sm.height = 0.008
				var seal_mat = StandardMaterial3D.new()
				seal_mat.albedo_color = Color(0.85, 0.15, 0.1)
				sm.material = seal_mat
				seal.mesh = sm
				seal.position = Vector3(0.1, 0.005, 0.06)
				add_child(seal)

				var n_glow = OmniLight3D.new()
				n_glow.light_color = Color(1.0, 0.9, 0.6)
				n_glow.light_energy = 0.6
				n_glow.omni_range = 2.0
				add_child(n_glow)

		"light_switch":
			# Wall switch
			var sm = BoxMesh.new()
			sm.size = Vector3(0.14, 0.22, 0.04)
			var smat = StandardMaterial3D.new()
			smat.albedo_color = Color(0.88, 0.88, 0.90)
			sm.material = smat
			mi.mesh = sm

			var toggle = MeshInstance3D.new()
			var tm = BoxMesh.new()
			tm.size = Vector3(0.04, 0.08, 0.06)
			var tmat = StandardMaterial3D.new()
			tmat.albedo_color = Color(0.2, 0.2, 0.25)
			tm.material = tmat
			toggle.mesh = tm
			toggle.position = Vector3(0, 0, 0.03)
			add_child(toggle)

		"fuse_red", "fuse_blue", "fuse_green":
			var f_color = Color(1.0, 0.15, 0.15)
			if item_type == "fuse_blue":
				f_color = Color(0.2, 0.6, 1.0)
			elif item_type == "fuse_green":
				f_color = Color(0.2, 1.0, 0.3)

			# Стеклянная колба
			var glass_mesh = CylinderMesh.new()
			glass_mesh.top_radius = 0.05
			glass_mesh.bottom_radius = 0.05
			glass_mesh.height = 0.22
			var g_mat = StandardMaterial3D.new()
			g_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			g_mat.albedo_color = Color(0.9, 0.95, 1.0, 0.4)
			g_mat.roughness = 0.1
			glass_mesh.material = g_mat
			mi.mesh = glass_mesh

			# Светящийся сердечник
			var core = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.02
			cm.bottom_radius = 0.02
			cm.height = 0.16
			var c_mat = StandardMaterial3D.new()
			c_mat.albedo_color = f_color
			c_mat.emission_enabled = true
			c_mat.emission = f_color
			c_mat.emission_energy_multiplier = 2.0
			cm.material = c_mat
			core.mesh = cm
			add_child(core)

			# Латунные колпачки контактов
			var cap_mat = StandardMaterial3D.new()
			cap_mat.albedo_color = Color(0.85, 0.72, 0.25)
			cap_mat.metallic = 0.9
			cap_mat.roughness = 0.25
			for cy in [-0.11, 0.11]:
				var cap_m = CylinderMesh.new()
				cap_m.top_radius = 0.052
				cap_m.bottom_radius = 0.052
				cap_m.height = 0.04
				cap_m.material = cap_mat
				var cap_i = MeshInstance3D.new()
				cap_i.mesh = cap_m
				cap_i.position = Vector3(0, cy, 0)
				add_child(cap_i)

			var light = OmniLight3D.new()
			light.light_color = f_color
			light.light_energy = 1.4
			light.omni_range = 2.5
			add_child(light)

		"bottle":
			# Стеклянная винная бутылка для отвлечения
			set_meta("item_label", "бутылка")
			var b_body = MeshInstance3D.new()
			var bm = CylinderMesh.new()
			bm.top_radius = 0.045
			bm.bottom_radius = 0.05
			bm.height = 0.22
			var b_mat = StandardMaterial3D.new()
			b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			b_mat.albedo_color = Color(0.25, 0.45, 0.20, 0.70)
			b_mat.roughness = 0.15
			bm.material = b_mat
			b_body.mesh = bm
			add_child(b_body)

			var neck = MeshInstance3D.new()
			var nm = CylinderMesh.new()
			nm.top_radius = 0.016
			nm.bottom_radius = 0.025
			nm.height = 0.10
			nm.material = b_mat
			neck.mesh = nm
			neck.position = Vector3(0, 0.16, 0)
			add_child(neck)

			var cork = MeshInstance3D.new()
			var cm = CylinderMesh.new()
			cm.top_radius = 0.017
			cm.bottom_radius = 0.015
			cm.height = 0.03
			var cmat = StandardMaterial3D.new()
			cmat.albedo_color = Color(0.65, 0.45, 0.25)
			cm.material = cmat
			cork.mesh = cm
			cork.position = Vector3(0, 0.22, 0)
			add_child(cork)

		"alarm_clock", "prop_alarm_clock":
			# Ретро-будильник: круглый корпус, циферблат, 2 медных колокольчика сверху, ручка и ножки
			set_meta("is_pickable", true)
			set_meta("item_label", "будильник")
			var cm = CylinderMesh.new()
			cm.top_radius = 0.12
			cm.bottom_radius = 0.12
			cm.height = 0.08
			var clock_mat = StandardMaterial3D.new()
			clock_mat.albedo_color = Color(0.18, 0.20, 0.24)
			clock_mat.metallic = 0.85
			clock_mat.roughness = 0.3
			cm.material = clock_mat
			mi.mesh = cm
			mi.rotation_degrees = Vector3(90, 0, 0)

			# Белый циферблат
			var dial = MeshInstance3D.new()
			var dm = CylinderMesh.new()
			dm.top_radius = 0.10
			dm.bottom_radius = 0.10
			dm.height = 0.005
			var dmat = StandardMaterial3D.new()
			dmat.albedo_color = Color(0.95, 0.92, 0.85)
			dm.material = dmat
			dial.mesh = dm
			dial.position = Vector3(0, 0, 0.042)
			dial.rotation_degrees = Vector3(90, 0, 0)
			add_child(dial)

			# Стрелки
			var hand1 = MeshInstance3D.new()
			var hm1 = BoxMesh.new()
			hm1.size = Vector3(0.008, 0.06, 0.004)
			var hmat = StandardMaterial3D.new()
			hmat.albedo_color = Color(0.05, 0.05, 0.05)
			hm1.material = hmat
			hand1.mesh = hm1
			hand1.position = Vector3(0, 0.02, 0.046)
			add_child(hand1)

			# 2 латунных колокольчика
			var brass = StandardMaterial3D.new()
			brass.albedo_color = Color(0.95, 0.80, 0.25)
			brass.metallic = 0.95
			brass.roughness = 0.2
			for bx in [-0.09, 0.09]:
				var bell = MeshInstance3D.new()
				var bm_b = SphereMesh.new()
				bm_b.radius = 0.045
				bm_b.height = 0.06
				bm_b.material = brass
				bell.mesh = bm_b
				bell.position = Vector3(bx, 0.13, 0)
				add_child(bell)

			# Молоток между колокольчиками
			var hammer = MeshInstance3D.new()
			var hamm = BoxMesh.new()
			hamm.size = Vector3(0.025, 0.025, 0.025)
			hamm.material = brass
			hammer.mesh = hamm
			hammer.position = Vector3(0, 0.14, 0)
			add_child(hammer)

			# Ножки
			for lx in [-0.08, 0.08]:
				var leg = MeshInstance3D.new()
				var lm = CylinderMesh.new()
				lm.top_radius = 0.012
				lm.bottom_radius = 0.008
				lm.height = 0.04
				lm.material = brass
				leg.mesh = lm
				leg.position = Vector3(lx, -0.13, 0)
				add_child(leg)

			_setup_alarm_audio()

		"tv_remote", "prop_tv_remote", "remote":
			set_meta("is_pickable", true)
			set_meta("item_label", "пульт от ТВ")
			var bm = BoxMesh.new()
			bm.size = Vector3(0.09, 0.028, 0.24)
			var rmat = StandardMaterial3D.new()
			rmat.albedo_color = Color(0.12, 0.13, 0.15)
			rmat.roughness = 0.7
			bm.material = rmat
			mi.mesh = bm

			# Красная кнопка включения
			var pwr = MeshInstance3D.new()
			var pwm = CylinderMesh.new()
			pwm.top_radius = 0.012
			pwm.bottom_radius = 0.012
			pwm.height = 0.008
			var pmat = StandardMaterial3D.new()
			pmat.albedo_color = Color(0.9, 0.1, 0.1)
			pmat.emission_enabled = true
			pmat.emission = Color(0.8, 0.05, 0.05)
			pwm.material = pmat
			pwr.mesh = pwm
			pwr.position = Vector3(-0.025, 0.016, -0.09)
			add_child(pwr)

			# Кнопки каналов
			var b_mat = StandardMaterial3D.new()
			b_mat.albedo_color = Color(0.35, 0.36, 0.38)
			for rz in range(3):
				for rx in [-0.02, 0.02]:
					var btn = MeshInstance3D.new()
					var btm = BoxMesh.new()
					btm.size = Vector3(0.018, 0.008, 0.018)
					btm.material = b_mat
					btn.mesh = btm
					btn.position = Vector3(rx, 0.016, -0.05 + rz * 0.038)
					add_child(btn)

		_:
			var bm  = BoxMesh.new()
			bm.size = Vector3(0.3, 0.3, 0.3)
			bm.material = mat
			mat.albedo_color = Color(1, 1, 1)
			mi.mesh = bm

	add_child(mi)

var alarm_audio: AudioStreamPlayer3D = null
var alarm_ringing: bool = false
var alarm_timer: float = 0.0
var alarm_pulse_timer: float = 0.0

func _setup_alarm_audio() -> void:
	alarm_audio = AudioStreamPlayer3D.new()
	alarm_audio.name = "AlarmBellAudio"
	alarm_audio.max_distance = 45.0
	alarm_audio.unit_size = 8.0
	if ResourceLoader.exists("res://assets/audio/clock_bell.wav"):
		alarm_audio.stream = load("res://assets/audio/clock_bell.wav")
	add_child(alarm_audio)

func start_alarm() -> void:
	alarm_ringing = true
	alarm_timer = 10.0
	if alarm_audio:
		alarm_audio.play()
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("emit_noise"):
		gm.emit_noise(global_position, 35.0, "alarm")

func stop_alarm() -> void:
	alarm_ringing = false
	alarm_timer = 0.0
	if alarm_audio and alarm_audio.playing:
		alarm_audio.stop()

# ──────────────────────────────────────────────
#  Floating + spin animation
# ──────────────────────────────────────────────
func _process(delta: float) -> void:
	if collected or get_meta("is_held", false) or get_meta("inside_storage", false):
		return

	if alarm_ringing:
		alarm_timer -= delta
		alarm_pulse_timer += delta
		if alarm_pulse_timer >= 0.55:
			alarm_pulse_timer = 0.0
			var gm = get_node_or_null("/root/GameManager")
			if gm and gm.has_method("emit_noise"):
				gm.emit_noise(global_position, 35.0, "alarm")
		if alarm_timer <= 0.0:
			stop_alarm()

	if item_type in ["note", "note_safe", "note_safe_code", "light_switch", "alarm_clock", "tv_remote", "prop_alarm_clock", "prop_tv_remote"] or get_meta("rest_still", false):
		return # Лежат устойчиво на поверхности
	# Лом висит горизонтально и крутится, пока его не возьмут
	if item_type == "crowbar":
		rotation_degrees.y += delta * 70.0
		return
	anim_time     += delta
	position.y     = base_y + sin(anim_time * 2.4) * 0.1
	rotation_degrees.y += delta * 55.0

func _get_gm() -> Node:
	if has_node("/root/GameManager"):
		return get_node("/root/GameManager")
	return null

# ──────────────────────────────────────────────
#  Interaction (called by Player._try_interact)
# ──────────────────────────────────────────────
func interact(_opener: Node3D = null) -> void:
	if collected and item_type not in ["note", "note_safe", "note_safe_code", "light_switch"]:
		return
	var gm = _get_gm()

	match item_type:
		"crowbar":
			collected = true
			if gm:
				gm.call("pick_up_crowbar")
				gm.call("add_score", "player", 75, "Найден Лом")
			_pop_and_free()

		"key", "key_gold", "key_silver", "key_rusty", "key_emerald", "key_ruby", "key_sapphire", "item_key", "custom_item_key":
			collected = true
			if gm:
				gm.call("pick_up_id_key", key_id)
				var DoorScript = load("res://scripts/Door.gd")
				var th = DoorScript.get_lock_theme(key_id)
				gm.call("add_score", "player", 100, "Найден %s ключ №%d" % [th["name"], key_id])
			_pop_and_free()

		"battery":
			collected = true
			if gm:
				gm.call("pick_up_battery")
			_pop_and_free()

		"road_flare":
			collected = true
			if gm: gm.call("pick_up_road_flare")
			_pop_and_free()

		"fuse_red":
			collected = true
			if gm:
				gm.call("pick_up_fuse", "red")
			_pop_and_free()

		"fuse_blue":
			collected = true
			if gm:
				gm.call("pick_up_fuse", "blue")
			_pop_and_free()

		"fuse_green":
			collected = true
			if gm:
				gm.call("pick_up_fuse", "green")
			_pop_and_free()

		"bottle":
			collected = true
			if gm:
				gm.call("pick_up_throwable")
			_pop_and_free()

		"note_safe", "note_safe_code":
			var code_str = str(gm.get("safe_code")) if gm and str(gm.get("safe_code")) != "" else "742"
			var note_txt = "ЛИСТОК С КОДОМ ОТ СЕЙФА:\n\n«Шифр от стального сейфа в кабинете: [ %s ].\nВнутри заперт серебряный ключ от выхода!\nНе забудь запереть за собой!»" % code_str
			if not collected:
				collected = true
				if gm: gm.call("add_score", "player", 50, "Найден шифр от сейфа")
			if gm: gm.call("open_note", note_txt, self)

		"note":
			var note_content = get_meta("note_text",
				"«Оно пришло ночью... Не шуми, оно слышит каждый шаг и дыхание.\nЕсли вырубит электричество — ищи батареи для главного щитка у ворот.\nНе оборачивайся...»")
			if gm: gm.call("open_note", str(note_content), self)

		"alarm_clock", "prop_alarm_clock":
			if _opener and _opener.has_method("_pick_up_object"):
				_opener.call("_pick_up_object", self)

		"tv_remote", "prop_tv_remote", "remote":
			if _opener and _opener.has_method("_pick_up_object"):
				_opener.call("_pick_up_object", self)

		"light_switch":
			if gm:
				gm.call("toggle_room_lights")

func _pop_and_free() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3(1.6, 1.6, 1.6), 0.1)
	tween.tween_property(self, "scale", Vector3(0.0, 0.0, 0.0), 0.15)
	tween.tween_callback(queue_free)
