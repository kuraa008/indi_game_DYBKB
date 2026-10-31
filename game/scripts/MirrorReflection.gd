extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  MirrorReflection.gd — Реалистичное отражение игрока строго внутри стекла
#
#  Использует SubViewport + ViewportTexture, проецируемый на меш стекла:
#   • Отражение не может выйти за пределы рамы
#   • Ракурс персонажа (лицо, спина, бок) определяется со стороны игрока
#   • Плавное зеркальное перемещение и центрирование
# ══════════════════════════════════════════════════════════════════════════════

const MAX_DIST: float = 6.0

var tex_front: Texture2D
var tex_back:  Texture2D
var tex_left:  Texture2D
var tex_right: Texture2D

var glass_mesh: MeshInstance3D = null
var viewport: SubViewport = null
var char_rect: TextureRect = null
var bg_rect: ColorRect = null

var _current_view: String = ""
var _textures_loaded: bool = false

const VP_W: float = 512.0
const VP_H: float = 768.0
const CHAR_W: float = 340.0
const CHAR_H: float = 680.0


func _ready() -> void:
	for child in get_children():
		if child is Sprite3D:
			child.visible = false

	_setup_viewport_mirror()
	call_deferred("_load_textures")


func _setup_viewport_mirror() -> void:
	glass_mesh = _find_glass_mesh()
	if not glass_mesh:
		return

	viewport = SubViewport.new()
	viewport.name = "MirrorVP"
	viewport.size = Vector2i(int(VP_W), int(VP_H))
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	add_child(viewport)

	# Фон зеркала (глубокий тёмный стеклянный тон)
	bg_rect = ColorRect.new()
	bg_rect.name = "GlassBG"
	bg_rect.color = Color(0.14, 0.17, 0.22)
	bg_rect.size = Vector2(VP_W, VP_H)
	viewport.add_child(bg_rect)

	# Персонаж внутри вьюпорта
	char_rect = TextureRect.new()
	char_rect.name = "CharReflection"
	char_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	char_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	char_rect.size = Vector2(CHAR_W, CHAR_H)
	char_rect.pivot_offset = Vector2(CHAR_W * 0.5, CHAR_H)
	char_rect.position = Vector2((VP_W - CHAR_W) * 0.5, VP_H - CHAR_H - 12.0)
	char_rect.visible = false
	viewport.add_child(char_rect)

	# Проекция вьюпорта на материал стекла
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.metallic = 0.88
	mat.roughness = 0.08
	glass_mesh.material_override = mat


func _find_glass_mesh() -> MeshInstance3D:
	var parent_n3d = get_parent() as Node3D
	if not parent_n3d:
		return null

	var direct = parent_n3d.get_node_or_null("Glass") as MeshInstance3D
	if direct:
		return direct

	for sibling in parent_n3d.get_children():
		if sibling is MeshInstance3D:
			var mi = sibling as MeshInstance3D
			if mi.mesh is QuadMesh or (mi.mesh is BoxMesh and (mi.mesh as BoxMesh).size.z < 0.05):
				return mi
	return null


func _load_textures() -> void:
	const BASE = "res://assets/textures/player_character/"
	tex_front = _try_load(BASE + "player_front.png")
	tex_back  = _try_load(BASE + "player_back.png")
	tex_left  = _try_load(BASE + "player_left.png")
	tex_right = _try_load(BASE + "player_right.png")
	_textures_loaded = true
	if char_rect and tex_front:
		char_rect.texture = tex_front


func _try_load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _process(_delta: float) -> void:
	if not _textures_loaded or not is_instance_valid(char_rect) or not is_instance_valid(glass_mesh):
		return

	var gm = get_node_or_null("/root/GameManager")
	var player_ref: Variant = null
	if is_instance_valid(gm):
		player_ref = gm.get("player_ref")
	if not is_instance_valid(player_ref) or not (player_ref is Node3D):
		char_rect.visible = false
		return
	var player := player_ref as Node3D

	var mirror_sb = get_parent() as Node3D
	if not mirror_sb:
		return

	# ── 1. Позиция игрока относительно зеркала ───────────────────────────
	var local_p = mirror_sb.to_local(player.global_position)

	if local_p.z <= 0.08 or local_p.z > MAX_DIST:
		char_rect.visible = false
		return

	if abs(local_p.x) > 3.0:
		char_rect.visible = false
		return

	char_rect.visible = true

	# ── 2. Определение ракурса СО СТОРОНЫ ИГРОКА ───────────────────────────
	var to_player_world = (player.global_position - mirror_sb.global_position)
	var to_player_flat  = Vector3(to_player_world.x, 0, to_player_world.z).normalized()

	var cam_node = player.get("camera") as Camera3D
	var p_forward = -cam_node.global_transform.basis.z if cam_node else -player.global_transform.basis.z
	var p_fwd_flat = Vector3(p_forward.x, 0, p_forward.z).normalized()

	var dot     = p_fwd_flat.dot(to_player_flat)
	var cross_y = to_player_flat.cross(p_fwd_flat).y

	var view: String
	if dot <= -0.45:
		view = "front"
	elif dot >= 0.45:
		view = "back"
	elif cross_y > 0.0:
		view = "left"
	else:
		view = "right"

	_apply_view(view)

	# ── 3. Позиция и масштаб внутри стекла ────────────────────────────────
	# Смещение по X: сбалансированный коэффициент 150px/м
	var offset_x = -local_p.x * 150.0
	var base_x = (VP_W - CHAR_W) * 0.5
	char_rect.position.x = clamp(base_x + offset_x, -CHAR_W * 0.4, VP_W - CHAR_W * 0.6)

	# Масштаб по расстоянию:
	var dist_scale = clamp(1.9 / max(1.1, local_p.z), 0.45, 0.98)
	char_rect.scale = Vector2(dist_scale, dist_scale)

	# Плавное угасание вдали
	var alpha_dist = clamp((MAX_DIST - local_p.z) / 1.6, 0.0, 1.0)
	char_rect.modulate.a = alpha_dist


func _apply_view(view: String) -> void:
	if view == _current_view:
		return
	_current_view = view
	if not char_rect or not _textures_loaded:
		return
	match view:
		"front": if tex_front: char_rect.texture = tex_front
		"back":  if tex_back:  char_rect.texture = tex_back
		"left":  if tex_left:  char_rect.texture = tex_left
		"right": if tex_right: char_rect.texture = tex_right
