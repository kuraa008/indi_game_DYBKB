extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  MirrorReflection.gd — Реалистичное отражение игрока строго внутри стекла
#
#  Использует SubViewport + ViewportTexture, проецируемый на меш стекла:
#   • Отражение не может выйти за пределы рамы
#   • РЕАЛИЗМ: 3D-модель в своём мире, камера стоит там же, где глаза игрока,
#     а стекло служит её окном, поэтому ракурс меняется как в настоящем зеркале
#   • LEGACY: плоский рисунок персонажа, ракурс выбирается со стороны игрока
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

# 3D-отражение
var world_root: Node3D = null
var mirror_cam: Camera3D = null
var mirror_model: PlayerModel = null
var glass_size := Vector2(0.74, 1.44)
var _legacy_active: bool = true

const VP_W: float = 512.0
const VP_H: float = 768.0
const CHAR_W: float = 340.0
const CHAR_H: float = 680.0


func _ready() -> void:
	for child in get_children():
		if child is Sprite3D:
			child.visible = false

	_setup_viewport_mirror()
	if viewport:
		_set_mode(false)
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

	_setup_world()

	# Проекция вьюпорта на материал стекла
	var mat = StandardMaterial3D.new()
	mat.albedo_texture = viewport.get_texture()
	mat.metallic = 0.0
	mat.roughness = 0.55
	mat.metallic_specular = 0.15
	# Зеркало видно и в тёмной комнате
	mat.emission_enabled = true
	mat.emission_texture = viewport.get_texture()
	mat.emission_energy_multiplier = 0.55
	glass_mesh.material_override = mat


func _setup_world() -> void:
	if glass_mesh.mesh is QuadMesh:
		glass_size = (glass_mesh.mesh as QuadMesh).size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X

	world_root = Node3D.new()
	world_root.name = "MirrorWorld"
	viewport.add_child(world_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.055)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.7)
	env.ambient_light_energy = 0.55
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_root.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.light_energy = 0.75
	light.rotation_degrees = Vector3(-35.0, 25.0, 0.0)
	world_root.add_child(light)

	mirror_cam = Camera3D.new()
	mirror_cam.projection = Camera3D.PROJECTION_FRUSTUM
	mirror_cam.far = 14.0
	mirror_cam.current = true
	world_root.add_child(mirror_cam)

	mirror_model = PlayerModel.new()
	mirror_model.name = "MirrorModel"
	mirror_model.scale = Vector3.ONE * (1.62 / PlayerModel.EYE_Y)
	mirror_model.set_first_person(false)
	mirror_model.set_shadows(false)
	world_root.add_child(mirror_model)


func _set_mode(legacy: bool) -> void:
	_legacy_active = legacy
	world_root.visible = not legacy
	bg_rect.visible = legacy
	if legacy:
		viewport.size = Vector2i(int(VP_W), int(VP_H))
		viewport.own_world_3d = false
		mirror_cam.current = false
	else:
		char_rect.visible = false
		viewport.size = Vector2i(int(round(VP_H * glass_size.x / glass_size.y)), int(VP_H))
		viewport.own_world_3d = true
		mirror_cam.current = true


# Отражение: игрок смотрит сквозь стекло как сквозь окно на своего двойника за плоскостью зеркала
func _update_world(delta: float, player: Node3D, mirror_sb: Node3D, local_p: Vector3) -> void:
	var cam_node = player.get("camera") as Camera3D
	var glass_pos: Vector3 = glass_mesh.position
	var eye: Vector3 = mirror_sb.to_local(cam_node.global_position if cam_node else player.global_position + Vector3(0, 1.62, 0)) - glass_pos
	eye.z = maxf(eye.z, 0.06)
	mirror_cam.position = eye
	mirror_cam.near = eye.z
	mirror_cam.size = glass_size.y
	mirror_cam.frustum_offset = Vector2(-eye.x, -eye.y)

	var feet := local_p - glass_pos
	mirror_model.position = Vector3(feet.x, feet.y, -feet.z)
	var fwd: Vector3 = mirror_sb.global_transform.basis.inverse() * (-player.global_transform.basis.z)
	mirror_model.rotation.y = atan2(fwd.x, -fwd.z)
	mirror_model.visible = player.get("is_hiding") != true

	var vel: Vector3 = player.get("velocity")
	var speed := Vector2(vel.x, vel.z).length()
	var mode := "idle"
	if player.get("is_crouching") == true:
		mode = "crouch"
	elif speed > 0.25:
		mode = "run" if speed > 4.8 else "walk"
	mirror_model.update_motion(delta, mode, speed)
	var head = player.get("head") as Node3D
	if head:
		mirror_model.set_look_pitch(head.rotation.x)


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


func _process(delta: float) -> void:
	if not _textures_loaded or not is_instance_valid(char_rect) or not is_instance_valid(glass_mesh):
		return

	var gm = get_node_or_null("/root/GameManager")
	var player_ref: Variant = null
	if is_instance_valid(gm):
		player_ref = gm.get("player_ref")
	if not is_instance_valid(player_ref) or not (player_ref is Node3D):
		char_rect.visible = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	var player := player_ref as Node3D

	var mirror_sb = get_parent() as Node3D
	if not mirror_sb:
		return

	# ── 1. Позиция игрока относительно зеркала ───────────────────────────
	var local_p = mirror_sb.to_local(player.global_position)

	# Вне зоны видимости зеркало не перерисовывается
	if local_p.z <= 0.08 or local_p.z > MAX_DIST or abs(local_p.x) > 3.0:
		char_rect.visible = false
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var legacy: bool = gm != null and gm.get("is_legacy_graphics") == true
	if legacy != _legacy_active:
		_set_mode(legacy)
	if not legacy:
		_update_world(delta, player, mirror_sb, local_p)
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
