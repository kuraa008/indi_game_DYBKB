extends CanvasLayer

# Слой кассеты поверх всех сцен. Сбои вызываются через glitch(), страх — через set_fear().

var effect_rect:  ColorRect
var effect_mat:   ShaderMaterial
var burst:        float = 0.0
var fear:         float = 0.0
var next_glitch:  float = 9.0
var fonts:        Dictionary = {}

func _ready() -> void:
	layer = 127
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Экран нужно копировать заново: в HUD есть другие экранные шейдеры
	var copy = BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)

	effect_mat = ShaderMaterial.new()
	effect_mat.shader = load("res://shaders/vhs.gdshader")

	effect_rect = ColorRect.new()
	effect_rect.name = "VHSEffect"
	effect_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effect_rect.material = effect_mat
	add_child(effect_rect)

func _process(delta: float) -> void:
	# В редакторе карт и на полигоне помехи только мешают
	var cur_scene = get_tree().current_scene
	var dev_scene = cur_scene != null and cur_scene.name in ["DebugEditor", "Polygon"]
	visible = GameManager.vhs_enabled and not dev_scene
	if not visible:
		return

	next_glitch -= delta
	if next_glitch <= 0.0:
		next_glitch = randf_range(9.0, 24.0)
		glitch(randf_range(0.25, 0.55))

	burst = move_toward(burst, 0.0, delta * 2.4)
	effect_mat.set_shader_parameter("burst", burst)
	effect_mat.set_shader_parameter("fear", fear)

func glitch(amount: float = 0.7) -> void:
	burst = maxf(burst, amount)

func set_fear(amount: float) -> void:
	fear = clampf(amount, 0.0, 1.0)

# Шрифт интерфейса с разрядкой букв, как на титрах кассеты
func tracked_font(spacing: int) -> Font:
	if not fonts.has(spacing):
		var variation = FontVariation.new()
		variation.base_font = ThemeDB.get_project_theme().default_font
		variation.spacing_glyph = spacing
		fonts[spacing] = variation
	return fonts[spacing]
