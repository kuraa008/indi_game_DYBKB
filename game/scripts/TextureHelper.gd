class_name TextureHelper
extends RefCounted

# ══════════════════════════════════════════════════════════════════════════════
#  TextureHelper.gd — Менеджер текстур стен, картин и луны для Escape in Skinwalker
#  Обеспечивает бесшовный трипланарный маппинг и синхронизацию редактора и игры
# ══════════════════════════════════════════════════════════════════════════════

static var _cache: Dictionary = {}
static var _wall_mats: Dictionary = {}

const SURFACE := "res://assets/textures/surface/"
# Старые файлы и их замена: новая текстура, рельеф, множитель цвета и масштаб
const UPGRADES := {
	"wood_furniture.png": ["wood", 0.9, Color(0.9, 0.82, 0.72), 0.7],
	"wood_door.png": ["wood", 0.9, Color(0.5, 0.36, 0.24), 0.72],
	"fabric.png": ["fabric", 0.7, Color(1.08, 1.08, 1.08), 0.42],
	"metal_worn.png": ["metal", 0.5, Color(1.1, 1.1, 1.1), 0.7],
	"concrete.png": ["concrete", 0.9, Color(0.92, 0.92, 0.92), 0.8],
	"forest_floor.png": ["", 1.0, Color.WHITE, 1.0, "soil_n"],
	"dirt_path.png": ["", 1.0, Color.WHITE, 1.0, "soil_n"],
	"board_weathered.png": ["", 0.8, Color.WHITE, 1.0, "wood_h_n"],
}


# Подменяет старую текстуру материала на новую из assets/textures/surface
static func upgrade_material(m: StandardMaterial3D, file: String) -> void:
	var key := file.get_file()
	if not upgrades_on or not UPGRADES.has(key):
		return
	var u: Array = UPGRADES[key]
	var base: String = u[0]
	var normal: String = (u[4] if u.size() > 4 else base + "_n")
	if base != "":
		m.albedo_texture = get_texture(SURFACE + base + ".png")
		m.albedo_color = Color(m.albedo_color.r * u[2].r, m.albedo_color.g * u[2].g, m.albedo_color.b * u[2].b, m.albedo_color.a)
		m.uv1_scale *= u[3]
	m.normal_enabled = true
	m.normal_texture = get_texture(SURFACE + normal + ".png")
	m.normal_scale = u[1]


# Старые варианты стен: на карте «Шоссе» новые текстуры не используются
const LEGACY_WALLS := {
	"plaster": {
		"path": "res://assets/textures/house/plaster.png",
		"triplanar_scale": Vector3(0.3, 0.3, 0.3),
		"name": "Штукатурка",
	},
	"wallpaper_vintage": {
		"name": "Винтажные обои",
		"icon": "📜",
		"path": "res://assets/textures/wallpaper_vintage.png",
		"roughness": 0.80,
		"metallic": 0.0,
		"triplanar_scale": Vector3(0.6, 0.6, 0.6)
	},
	"concrete_floor": {
		"path": "res://assets/textures/house/concrete.png",
		"triplanar_scale": Vector3(0.25, 0.25, 0.25),
		"name": "Бетон",
	},
	"wood_planks": {
		"name": "Деревянные доски",
		"icon": "🪵",
		"path": "res://assets/textures/wood_planks.png",
		"normal": "res://assets/textures/nature/wood_planks_n.png",
		"roughness": 0.75,
		"metallic": 0.0,
		"triplanar_scale": Vector3(0.5, 0.5, 0.5)
	},
	"concrete_grunge": {
		"name": "Бетон и штукатурка",
		"icon": "🏛",
		"path": "res://assets/textures/concrete_grunge.png",
		"normal": "res://assets/textures/nature/concrete_grunge_n.png",
		"roughness": 0.95,
		"metallic": 0.02,
		"triplanar_scale": Vector3(0.4, 0.4, 0.4)
	},
	"board_weathered": {
		"path": "res://assets/textures/house/board_weathered.png",
		"triplanar_scale": Vector3(0.5, 0.5, 0.5),
		"name": "Старые доски",
	},
}
static var upgrades_on := true


const WALL_TEXTURES = {
	"siding": {
		"path": "res://assets/textures/house/siding.png",
		"triplanar_scale": Vector3(0.42, 0.42, 0.42),
		"name": "Старая обшивка",
	},
	"plaster": {
		"path": "res://assets/textures/surface/plaster.png",
		"triplanar_scale": Vector3(0.5, 0.5, 0.5),
		"name": "Штукатурка",
		"normal": "res://assets/textures/surface/plaster_n.png",
		"normal_scale": 0.8,
	},
	"tile_clean": {
		"path": "res://assets/textures/house/tile_clean.png",
		"triplanar_scale": Vector3(0.45, 0.45, 0.45),
		"name": "Плитка",
	},
	"concrete_floor": {
		"path": "res://assets/textures/surface/concrete.png",
		"triplanar_scale": Vector3(0.32, 0.32, 0.32),
		"name": "Бетон",
		"normal": "res://assets/textures/surface/concrete_n.png",
		"normal_scale": 1.0,
	},
	"board_weathered": {
		"path": "res://assets/textures/house/board_weathered.png",
		"triplanar_scale": Vector3(0.5, 0.5, 0.5),
		"name": "Старые доски",
		"normal": "res://assets/textures/surface/wood_h_n.png",
		"normal_scale": 0.8,
	},
	"brick_red": {
		"name": "Красный кирпич",
		"icon": "🧱",
		"path": "res://assets/textures/nature/brick_red_v2.png",
		"normal": "res://assets/textures/nature/brick_red_v2_n.png",
		"normal_scale": 1.25,
		"roughness": 0.85,
		"metallic": 0.05,
		"triplanar_scale": Vector3(0.5, 0.5, 0.5)
	},
	"brick_dark": {
		"name": "Темный камень",
		"icon": "🪨",
		"path": "res://assets/textures/brick_dark.png",
		"normal": "res://assets/textures/nature/brick_dark_n.png",
		"roughness": 0.90,
		"metallic": 0.05,
		"triplanar_scale": Vector3(0.45, 0.45, 0.45)
	},
	"wallpaper_vintage": {
		"name": "Винтажные обои",
		"icon": "📜",
		"path": "res://assets/textures/surface/wallpaper.png",
		"roughness": 0.80,
		"metallic": 0.0,
		"triplanar_scale": Vector3(0.7, 0.7, 0.7),
		"normal": "res://assets/textures/surface/wallpaper_n.png",
		"normal_scale": 0.7,
	},
	"wood_planks": {
		"name": "Деревянные доски",
		"icon": "🪵",
		"path": "res://assets/textures/wood_planks.png",
		"normal": "res://assets/textures/nature/wood_planks_n.png",
		"roughness": 0.75,
		"metallic": 0.0,
		"triplanar_scale": Vector3(0.5, 0.5, 0.5)
	},
	"concrete_grunge": {
		"name": "Бетон и штукатурка",
		"icon": "🏛",
		"path": "res://assets/textures/concrete_grunge.png",
		"normal": "res://assets/textures/nature/concrete_grunge_n.png",
		"roughness": 0.95,
		"metallic": 0.02,
		"triplanar_scale": Vector3(0.4, 0.4, 0.4)
	},
	"tile_morgue": {
		"name": "Кафель морга",
		"icon": "🔲",
		"path": "res://assets/textures/tile_morgue.png",
		"roughness": 0.30,
		"metallic": 0.12,
		"triplanar_scale": Vector3(0.5, 0.5, 0.5)
	},
	"blood_wall": {
		"name": "Кровавая стена",
		"icon": "🩸",
		"path": "res://assets/textures/blood_wall.png",
		"roughness": 0.80,
		"metallic": 0.04,
		"triplanar_scale": Vector3(0.5, 0.5, 0.5)
	},
	"rusted_metal": {
		"name": "Ржавый металл",
		"icon": "🔩",
		"path": "res://assets/textures/nature/car_rust.png",
		"normal": "res://assets/textures/nature/car_rust_n.png",
		"roughness": 0.65,
		"metallic": 0.55,
		"triplanar_scale": Vector3(0.4, 0.4, 0.4)
	}
}

const PAINTINGS = {
	"portrait": {
		"name": "Портрет предка",
		"icon": "👤",
		"path": "res://assets/textures/painting_portrait.png",
		"desc": "Старинный портрет с пронзительным взглядом"
	},
	"landscape": {
		"name": "Мрачный лес",
		"icon": "🌲",
		"path": "res://assets/textures/painting_landscape.png",
		"desc": "Ночной туманный лес и горы"
	},
	"moon": {
		"name": "Кровавая луна",
		"icon": "🌕",
		"path": "res://assets/textures/painting_moon.png",
		"desc": "Багровая луна над одинокой хижиной"
	},
	"skinwalker": {
		"name": "Тень в чаще",
		"icon": "👹",
		"path": "res://assets/textures/painting_skinwalker.png",
		"desc": "Скинвокер с горящими глазами в темноте"
	},
	"entity": {
		"name": "Искаженный лик",
		"icon": "👻",
		"path": "res://assets/textures/painting_entity.png",
		"desc": "Кричащий призрак, возникающий из пустоты"
	},
	"vintage": {
		"name": "Череп и свеча",
		"icon": "💀",
		"path": "res://assets/textures/painting_vintage.png",
		"desc": "Готический натюрморт vanitas"
	}
}

static func get_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path]

	# 1. Попытка через ResourceLoader
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			_cache[path] = res
			return res

	# 2. Прямая загрузка из файла на диске (для свежесозданных файлов и кастомных картинок)
	var global_path = ProjectSettings.globalize_path(path)
	var target_file = global_path if FileAccess.file_exists(global_path) else path
	if FileAccess.file_exists(target_file):
		var img = Image.new()
		var err = img.load(target_file)
		if err == OK:
			var tex = ImageTexture.create_from_image(img)
			_cache[path] = tex
			return tex

	return null

static func create_wall_material(texture_key: String, tint_color: Color = Color.WHITE) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.metallic = 0.05

	if texture_key == "" or texture_key == "none":
		mat.albedo_color = tint_color
		return mat

	var t_info = LEGACY_WALLS.get(texture_key) if not upgrades_on and LEGACY_WALLS.has(texture_key) else WALL_TEXTURES.get(texture_key)
	var t_path = ""
	if t_info:
		t_path = t_info["path"]
		mat.roughness = t_info.get("roughness", 0.85)
		mat.metallic = t_info.get("metallic", 0.05)
	elif FileAccess.file_exists(texture_key) or ResourceLoader.exists(texture_key):
		t_path = texture_key

	if t_path != "":
		var tex = get_texture(t_path)
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = tint_color
			# Включаем трипланарное наложение, чтобы текстура никогда не растягивалась
			mat.uv1_triplanar = true
			var sc = t_info.get("triplanar_scale", Vector3(0.5, 0.5, 0.5)) if t_info else Vector3(0.5, 0.5, 0.5)
			mat.uv1_scale = sc
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			var nrm_path: String = t_info.get("normal", "") if t_info else ""
			if nrm_path != "":
				var nrm_tex = get_texture(nrm_path)
				if nrm_tex:
					mat.normal_enabled = true
					mat.normal_texture = nrm_tex
					mat.normal_scale = t_info.get("normal_scale", 1.0)
			return mat

	mat.albedo_color = tint_color
	return mat

static func apply_wall_texture_to_node(node: Node, texture_key: String, tint_color: Color = Color.WHITE) -> void:
	if node == null:
		return
	# Один материал на текстуру и оттенок: одинаковые стены рисуются инстансингом
	var mat_key := "wall|%s|%s|%s" % [texture_key, tint_color.to_html(), upgrades_on]
	var mat = _wall_mats.get(mat_key)
	if mat == null:
		mat = create_wall_material(texture_key, tint_color)
		_wall_mats[mat_key] = mat
	_apply_mat_recursive(node, mat)
	if node is Node3D:
		node.set_meta("wall_texture", texture_key)

static func _apply_mat_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		var mi = node as MeshInstance3D
		# Если это не холст картины или лампочка
		if not mi.name.to_lower().contains("canvas") and not mi.name.to_lower().contains("bulb") and not mi.name.to_lower().contains("knob"):
			mi.set_surface_override_material(0, mat)
	for ch in node.get_children():
		_apply_mat_recursive(ch, mat)

const TREE_DRAWINGS = {
	"skinwalker": {
		"name": "Лик Скинвокера",
		"icon": "👹",
		"path": "res://assets/textures/tree_drawing_skinwalker.png",
		"desc": "Рогатый череп, вырезанный на коре, и ритуальный круг"
	},
	"warning": {
		"name": "Предупреждение жертвы",
		"icon": "⚠️",
		"path": "res://assets/textures/tree_drawing_warning.png",
		"desc": "Перечёркнутый глаз, бегущий человек и кровавая надпись RUN"
	},
	"claws": {
		"name": "Следы когтей",
		"icon": "🩸",
		"path": "res://assets/textures/tree_drawing_claws.png",
		"desc": "Глубокие борозды когтей чудовища со свежей кровью"
	}
}

static func create_painting_canvas_material(art_key: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.65
	mat.metallic = 0.02
	var p_info = PAINTINGS.get(art_key)
	var p_path = p_info["path"] if p_info else (art_key if (FileAccess.file_exists(art_key) or ResourceLoader.exists(art_key)) else "")
	if p_path != "":
		var tex = get_texture(p_path)
		if tex:
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			return mat
	mat.albedo_color = Color(0.25, 0.20, 0.18)
	return mat

static func apply_painting_art_to_node(node: Node3D, art_key: String) -> void:
	if node == null:
		return
	var mat = create_painting_canvas_material(art_key)
	for ch in node.get_children():
		if ch is MeshInstance3D and ch.name.to_lower().contains("canvas"):
			ch.set_surface_override_material(0, mat)
		for sub_ch in ch.get_children():
			if sub_ch is MeshInstance3D and sub_ch.name.to_lower().contains("canvas"):
				sub_ch.set_surface_override_material(0, mat)
	node.set_meta("painting_art", art_key)

static func create_tree_drawing_material(drawing_key: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.85
	mat.metallic = 0.02
	var d_info = TREE_DRAWINGS.get(drawing_key)
	var d_path = d_info["path"] if d_info else (drawing_key if (FileAccess.file_exists(drawing_key) or ResourceLoader.exists(drawing_key)) else "")
	if d_path != "":
		var tex = get_texture(d_path)
		if tex:
			mat.albedo_texture = tex
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			if drawing_key == "skinwalker":
				mat.emission_enabled = true
				mat.emission_texture = tex
				mat.emission = Color(0.75, 0.15, 0.12)
				mat.emission_energy_multiplier = 0.35
			elif drawing_key == "warning":
				mat.emission_enabled = true
				mat.emission_texture = tex
				mat.emission = Color(0.85, 0.20, 0.15)
				mat.emission_energy_multiplier = 0.20
			return mat
	mat.albedo_color = Color(0.35, 0.22, 0.15)
	return mat

static func apply_tree_drawing_to_node(node: Node3D, drawing_key: String) -> void:
	if node == null:
		return
	var mat = create_tree_drawing_material(drawing_key)
	var carving_mi: MeshInstance3D = null
	for ch in node.get_children():
		if ch.name == "Carving" or (ch is MeshInstance3D and (ch.name.to_lower().contains("carv") or ch.name.to_lower().contains("drawing"))):
			carving_mi = ch
			break
		for sub_ch in ch.get_children():
			if sub_ch.name == "Carving" or (sub_ch is MeshInstance3D and (sub_ch.name.to_lower().contains("carv") or sub_ch.name.to_lower().contains("drawing"))):
				carving_mi = sub_ch
				break

	if carving_mi:
		carving_mi.set_surface_override_material(0, mat)
	node.set_meta("tree_drawing", drawing_key)

# ══════════════════════════════════════════════════════════════════════════════
#  Текстуры и материалы дверей (дерево, филенка, амбарные доски, металл, хоррор)
# ══════════════════════════════════════════════════════════════════════════════
const DOOR_TEXTURES = {
	"door_dark_oak": {
		"name": "Темный дуб",
		"icon": "🪵",
		"path": "res://assets/textures/door_dark_oak.png",
		"roughness": 0.80,
		"metallic": 0.05,
		"desc": "Состаренный темный дуб с коваными железными накладками и клепками"
	},
	"door_classic_panel": {
		"name": "Резная филенка",
		"icon": "🚪",
		"path": "res://assets/textures/door_classic_panel.png",
		"roughness": 0.65,
		"metallic": 0.02,
		"desc": "Классическая четырехфиленчатая дверь из благородного красного дерева"
	},
	"door_barn_rustic": {
		"name": "Амбарные доски",
		"icon": "🌲",
		"path": "res://assets/textures/door_barn_rustic.png",
		"roughness": 0.85,
		"metallic": 0.05,
		"desc": "Массивные сосновые доски с диагональным Z-брусом и болтами"
	},
	"door_peeling_paint": {
		"name": "Облезлая краска",
		"icon": "🏚",
		"path": "res://assets/textures/door_peeling_paint.png",
		"roughness": 0.90,
		"metallic": 0.02,
		"desc": "Хоррор: потрескавшаяся краска, гнилое дерево и следы когтей скинвокера"
	},
	"door_metal_reinforced": {
		"name": "Бронедверь",
		"icon": "🔩",
		"path": "res://assets/textures/door_metal_reinforced.png",
		"roughness": 0.45,
		"metallic": 0.85,
		"desc": "Тяжелая бронесталь с окном-решеткой и полосой предупреждения"
	},
	"door_smooth_walnut": {
		"name": "Гладкий орех",
		"icon": "🟫",
		"path": "res://assets/textures/door_smooth_walnut.png",
		"roughness": 0.70,
		"metallic": 0.03,
		"desc": "Благородный полированный орех с тонкой золоченой инкрустацией"
	}
}

static func create_door_material(texture_key: String, tint_color: Color = Color.WHITE) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.roughness = 0.75
	mat.metallic = 0.05
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	if texture_key == "" or texture_key == "none":
		mat.albedo_color = Color(0.40, 0.24, 0.14)
		return mat

	var d_info = DOOR_TEXTURES.get(texture_key)
	var d_path = d_info["path"] if d_info else (texture_key if (FileAccess.file_exists(texture_key) or ResourceLoader.exists(texture_key)) else "")
	if d_info:
		mat.roughness = d_info.get("roughness", 0.75)
		mat.metallic = d_info.get("metallic", 0.05)

	if d_path != "":
		var tex = get_texture(d_path)
		if tex:
			mat.albedo_texture = tex
			mat.albedo_color = tint_color
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			return mat

	mat.albedo_color = Color(0.40, 0.24, 0.14)
	return mat

static func apply_door_texture_to_node(node: Node, texture_key: String, tint_color: Color = Color.WHITE) -> void:
	if node == null or node.has_meta("keep_door_look"):
		return
	var mat = create_door_material(texture_key, tint_color)
	var has_tex = (mat.albedo_texture != null)

	# Ищем все меши полотна двери (DoorLeaf / PanelMesh)
	var target_leaves: Array[MeshInstance3D] = []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var n_low = mi.name.to_lower()
		if mi.name == "DoorLeaf" or mi.name == "PanelMesh" or n_low.contains("doorleaf") or n_low.contains("leaf"):
			target_leaves.append(mi)

	if target_leaves.is_empty():
		var panel = node.find_child("Panel", true, false)
		var search_root = panel if panel else node
		for ch in search_root.get_children():
			if ch is MeshInstance3D and not ch.name.to_lower().contains("knob") and not ch.name.to_lower().contains("keyhole") and not ch.name.to_lower().contains("frame"):
				target_leaves.append(ch)
				break

	for leaf_mi in target_leaves:
		leaf_mi.set_surface_override_material(0, mat)
		leaf_mi.extra_cull_margin = 16.0
		leaf_mi.ignore_occlusion_culling = true
		# Если установлена текстура двери, скрываем процедурные бруски, но ВСЕГДА оставляем 3D фурнитуру (ручки, петли, замочные скважины)
		for ch in leaf_mi.get_children():
			if ch is MeshInstance3D:
				var c_low = ch.name.to_lower()
				var is_hw = c_low.contains("handle") or c_low.contains("knob") or c_low.contains("lever") or c_low.contains("rosette") or c_low.contains("stem") or c_low.contains("hinge") or c_low.contains("cap") or c_low.contains("bolt") or c_low.contains("keyhole") or c_low.contains("esc") or c_low.contains("kick") or c_low.contains("plate") or c_low.contains("rivet") or c_low.contains("lock")
				if is_hw:
					ch.visible = true
				else:
					ch.visible = not has_tex
				ch.extra_cull_margin = 16.0

	# Настраиваем дверную раму/косяк для надежного контраста со стеной
	var frame_mat = StandardMaterial3D.new()
	frame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if texture_key == "door_metal_reinforced":
		frame_mat.albedo_color = Color(0.16, 0.18, 0.20)
		frame_mat.metallic = 0.8
		frame_mat.roughness = 0.4
	else:
		# Глубокий темный косяк (черненый орех/чугун), чтобы дверь никогда не сливалась со стенами
		frame_mat.albedo_color = Color(0.12, 0.08, 0.06)
		frame_mat.roughness = 0.9
		frame_mat.metallic = 0.05

	for ch in node.get_children():
		if ch is MeshInstance3D and not (ch in target_leaves) and (ch.name.begins_with("fl") or ch.name.begins_with("fr") or ch.name.begins_with("ft") or ch.name.to_lower().contains("frame")):
			ch.set_surface_override_material(0, frame_mat)
			ch.extra_cull_margin = 16.0

	node.set_meta("door_texture", texture_key)
	var p_node = node.find_child("Panel", true, false)
	if p_node:
		p_node.set_meta("door_texture", texture_key)

