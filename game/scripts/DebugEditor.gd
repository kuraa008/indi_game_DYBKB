extends Node3D

const TextureHelper = preload("res://scripts/TextureHelper.gd")
const ParallaxHorizon = preload("res://scripts/ParallaxHorizon.gd")

# ══════════════════════════════════════════════════════════════════════════════
#  DebugEditor.gd — 3D Редактор карт и Полигон тестирования механик
#  В стиле Unity / Unreal / MapForge
#  [1] — Ставить объект
#  [2] — Удалить объект
#  [3] — Перемещать объект (Move / Grab)
#  [7] — Переключение между Редактором и Игрой (Полигон)
#  [TAB] — Каталог объектов (нижняя полка)
#  [R / Колесо] — Вращение на 360°
#  [F] — Перевернуть 180° / [T] — Наклон 90°
#  [End] — Опустить объект на пол
#  [PageUp / PageDown] — Поднять / Опустить по высоте
#  [Ctrl+D] — Дублировать объект
#  Поддержка кастомных 3D-моделей (.glb, .gltf, .obj, .tscn) из res://assets/custom_models/
# ══════════════════════════════════════════════════════════════════════════════

enum EditorMode { EDIT, PLAYTEST }
var current_mode: EditorMode = EditorMode.EDIT

# ──────────────────────────────────────────────────────────────────────────────
#  Узлы сцены
# ──────────────────────────────────────────────────────────────────────────────
var editor_cam: Camera3D
var cam_pivot: Node3D
var nav_region: NavigationRegion3D
var objects_root: Node3D
var ghost_root: Node3D
var selection_box: MeshInstance3D
var grid_mesh: MeshInstance3D

# ──────────────────────────────────────────────────────────────────────────────
#  UI элементы
# ──────────────────────────────────────────────────────────────────────────────
var ui_layer: CanvasLayer
var top_bar: PanelContainer
var btn_grid_mode: Button
var bottom_drawer: PanelContainer
var drawer_cards_container: HBoxContainer
var current_drawer_cat: String = "⭐ Все"
var current_search_query: String = ""
var search_edit: LineEdit = null
var inspector_panel: PanelContainer
var hotkeys_hint: Label
var notification_label: Label
var notif_timer: float = 0.0

# ── 3D Витрина предпросмотра моделей в каталоге ──
var preview_subviewport: SubViewport = null
var preview_pivot: Node3D = null
var preview_cam: Camera3D = null
var showcase_name_lbl: Label = null
var showcase_info_lbl: Label = null
var current_preview_prefab_id: String = ""

# ──────────────────────────────────────────────────────────────────────────────
#  Камера (FlyCam)
# ──────────────────────────────────────────────────────────────────────────────
var cam_yaw: float = -45.0
var cam_pitch: float = -30.0
var cam_speed: float = 14.0
var cam_fast_mult: float = 2.5
var is_rmb_down: bool = false
var saved_cam_transform: Transform3D
var saved_pivot_pos: Vector3 = Vector3(0.0, 8.0, 14.0)
var saved_cam_yaw: float = 0.0
var saved_cam_pitch: float = -20.0
var playtest_initial_player_spawn: Vector3 = Vector3(0, 0.5, 0)
var playtest_initial_enemy_spawn: Vector3 = Vector3(6, 0.5, 6)
var playtest_initial_lumberjack_spawn: Vector3 = Vector3(-2, 0.5, 1)

# Освещение и Fullbright
var world_env: Environment = null
var sun_light: DirectionalLight3D = null
var cam_light: OmniLight3D = null
var is_fullbright: bool = false
var btn_fullbright: Button = null
var moon_clouds: Array[Node3D] = []
var sky_elements_node: Node3D = null
var stars_node: MultiMeshInstance3D = null

# ──────────────────────────────────────────────────────────────────────────────
#  Режимы: Сеточный (Grid Snap) и Свободный (Free)
# ──────────────────────────────────────────────────────────────────────────────
var grid_snap_enabled: bool = true
var grid_size: float = 1.0

# ──────────────────────────────────────────────────────────────────────────────
#  Размещение, выбор и перемещение объектов
# ──────────────────────────────────────────────────────────────────────────────
var active_prefab_id: String = ""
var ghost_node: Node3D = null
var ghost_yaw: float = 0.0
var ghost_pitch: float = 0.0
var ghost_roll: float = 0.0

# Режим растягивания прямоугольника (Пол / Потолок от угла до угла)
var is_box_dragging: bool = false
var box_drag_start_pt: Vector3 = Vector3.ZERO
var dynamic_box_size: Vector3 = Vector3(4.0, 0.3, 4.0)
var dynamic_box_pos: Vector3 = Vector3.ZERO

var selected_node: Node3D = null
var is_grabbing_selected: bool = false
var is_mouse_dragging: bool = false
var pending_mouse_drag: bool = false
var mouse_drag_start_screen: Vector2 = Vector2.ZERO
var drag_ground_offset: Vector3 = Vector3.ZERO
var drag_elevation: float = 0.0
var drag_last_valid_pos: Vector3 = Vector3.ZERO
var mouse_press_pos: Vector2 = Vector2.ZERO
var grab_orig_transform: Transform3D
var next_obj_id: int = 100

# Инспектор: точные координаты, поворот 360° и фиксация
var _updating_inspector: bool = false
var insp_spin_x: SpinBox = null
var insp_spin_y: SpinBox = null
var insp_spin_z: SpinBox = null
var insp_spin_rot_x: SpinBox = null
var insp_spin_rot_y: SpinBox = null
var insp_spin_rot_z: SpinBox = null
var insp_lock_btn: Button = null

# Превью перед размещением
var ghost_info_badge: Label3D = null
var ghost_ring_mesh: MeshInstance3D = null
var catalog_preview_card: PanelContainer = null
var catalog_preview_lbl: Label = null

# Текущий файл карты и активное модальное окно
var active_map_file_path: String = "res://scenes/Карта_6.json"
var active_modal: Control = null

# ──────────────────────────────────────────────────────────────────────────────
#  История действий (Undo / Redo)
# ──────────────────────────────────────────────────────────────────────────────
var undo_stack: Array = []
var redo_stack: Array = []
const MAX_UNDO_STEPS: int = 30
var btn_undo: Button
var btn_redo: Button

#  Playtest узлы
# ──────────────────────────────────────────────────────────────────────────────
var test_player: CharacterBody3D = null
var test_enemy: CharacterBody3D = null
var test_lumberjack: CharacterBody3D = null
var test_ui: CanvasLayer = null
var test_overlay: CanvasLayer = null
var test_items: Array[Node] = []
var test_door: Node3D = null
var outdoor_ambient_player: AudioStreamPlayer = null
var playtest_snapshot: Array = []
var playtest_saved_next_id: int = 0

# ──────────────────────────────────────────────────────────────────────────────
#  Каталог стандартных префабов
# ──────────────────────────────────────────────────────────────────────────────
var PREFABS = {
	"wall_std": {
		"category": "Архитектура",
		"icon": "🧱",
		"name": "Стена стандартная",
		"type": "cube",
		"size": Vector3(3.0, 3.6, 0.4),
		"color": Color(0.49, 0.52, 0.57),
		"comment": "Стена 3x3.6x0.4м"
	},
	"wall_long": {
		"category": "Архитектура",
		"icon": "🧱",
		"name": "Стена длинная",
		"type": "cube",
		"size": Vector3(6.0, 3.6, 0.4),
		"color": Color(0.45, 0.48, 0.53),
		"comment": "Длинная стена 6x3.6м"
	},
	"wall_short": {
		"category": "Архитектура",
		"icon": "🧱",
		"name": "Стена короткая",
		"type": "cube",
		"size": Vector3(1.5, 3.6, 0.4),
		"color": Color(0.49, 0.52, 0.57),
		"comment": "Перегородка 1.5м"
	},
	"column": {
		"category": "Архитектура",
		"icon": "🏛",
		"name": "Колонна / Столб",
		"type": "cube",
		"size": Vector3(0.8, 3.6, 0.8),
		"color": Color(0.35, 0.38, 0.42),
		"comment": "Опорная колонна 0.8м"
	},
	"floor_custom": {
		"category": "Архитектура",
		"icon": "⬛",
		"name": "Пол (от угла до угла)",
		"type": "floor_custom",
		"size": Vector3(4.0, 0.3, 4.0),
		"color": Color(0.12, 0.10, 0.09),
		"comment": "Зажать ЛКМ и растянуть"
	},
	"ceiling_custom": {
		"category": "Архитектура",
		"icon": "⬜",
		"name": "Потолок (от угла до угла)",
		"type": "ceiling_custom",
		"size": Vector3(4.0, 0.3, 4.0),
		"color": Color(0.06, 0.05, 0.06),
		"comment": "Зажать ЛКМ и растянуть"
	},
	"floor_slab": {
		"category": "Архитектура",
		"icon": "⬛",
		"name": "Секция пола / платформа",
		"type": "cube",
		"size": Vector3(4.0, 0.25, 4.0),
		"color": Color(0.12, 0.10, 0.09),
		"comment": "Платформа 4x4м"
	},
	"cover_box": {
		"category": "Архитектура",
		"icon": "📦",
		"name": "Низкое укрытие",
		"type": "cube",
		"size": Vector3(1.8, 1.2, 0.6),
		"color": Color(0.32, 0.30, 0.28),
		"comment": "Укрытие от монстра"
	},
	# ─────────────────────────────────────────────────────────────
	#  ЛЕСТНИЦЫ И ПЕРИЛА
	# ─────────────────────────────────────────────────────────────
	"stairs_straight": {
		"category": "Лестницы",
		"icon": "🪜",
		"name": "Лестница деревянная",
		"type": "stairs_straight",
		"size": Vector3(1.6, 3.6, 4.2),
		"color": Color(0.34, 0.22, 0.14),
		"comment": "Деревянная прямая лестница на 12 ступеней с гладким подъёмом"
	},
	"stairs_metal": {
		"category": "Лестницы",
		"icon": "🪜",
		"name": "Лестница железная",
		"type": "stairs_metal",
		"size": Vector3(1.4, 3.6, 4.2),
		"color": Color(0.20, 0.22, 0.25),
		"comment": "Металлическая промышленная лестница с плавным подъёмом"
	},
	"railing_wood": {
		"category": "Лестницы",
		"icon": "🚧",
		"name": "Перила деревянные",
		"type": "railing_wood",
		"size": Vector3(2.0, 1.0, 0.12),
		"color": Color(0.38, 0.24, 0.15),
		"comment": "Деревянные перила с балясинами для лестниц и балконов"
	},
	"railing_metal": {
		"category": "Лестницы",
		"icon": "🚧",
		"name": "Перила кованые",
		"type": "railing_metal",
		"size": Vector3(2.0, 1.0, 0.08),
		"color": Color(0.15, 0.15, 0.18),
		"comment": "Кованые металлические перила с вертикальными прутьями"
	},
	# ─────────────────────────────────────────────────────────────
	#  БЛОКИ ДЛЯ СБОРКИ МОДЕЛЕЙ (Вместо Blender)
	# ─────────────────────────────────────────────────────────────
	"block_cube_1m": {
		"category": "🧱 Блоки",
		"icon": "🧊",
		"name": "Куб (1x1x1м)",
		"type": "cube",
		"size": Vector3(1.0, 1.0, 1.0),
		"color": Color(0.70, 0.65, 0.58),
		"comment": "Базовый блок для сборки"
	},
	"block_plate_2m": {
		"category": "🧱 Блоки",
		"icon": "➖",
		"name": "Тонкая плита (2x0.15x2м)",
		"type": "cube",
		"size": Vector3(2.0, 0.15, 2.0),
		"color": Color(0.55, 0.38, 0.22),
		"comment": "Столешница / полка / перекрытие"
	},
	"block_beam": {
		"category": "🧱 Блоки",
		"icon": "🥢",
		"name": "Балка / Ножка (0.15x1x0.15м)",
		"type": "cube",
		"size": Vector3(0.15, 1.0, 0.15),
		"color": Color(0.42, 0.28, 0.16),
		"comment": "Ножка мебели или стойка"
	},
	"block_plank": {
		"category": "🧱 Блоки",
		"icon": "🪵",
		"name": "Доска (1.5x0.08x0.3м)",
		"type": "cube",
		"size": Vector3(1.5, 0.08, 0.3),
		"color": Color(0.50, 0.32, 0.18),
		"comment": "Деревянная доска"
	},
	"block_column_cyl": {
		"category": "🧱 Блоки",
		"icon": "🏛",
		"name": "Колонна (Цилиндр 1x3x1м)",
		"type": "cylinder",
		"size": Vector3(1.0, 3.0, 1.0),
		"color": Color(0.62, 0.65, 0.70),
		"comment": "Круглый цилиндрический столб"
	},
	"block_prism": {
		"category": "🧱 Блоки",
		"icon": "🔺",
		"name": "Клин / Рампа (1.5x1x1.5м)",
		"type": "prism",
		"size": Vector3(1.5, 1.0, 1.5),
		"color": Color(0.48, 0.50, 0.55),
		"comment": "Скат крыши / рампа"
	},
	"spawn_player": {
		"category": "Персонажи",
		"icon": "👤",
		"name": "Спавн игрока",
		"type": "marker_player",
		"size": Vector3(0.8, 1.8, 0.8),
		"color": Color(0.15, 0.85, 0.65),
		"comment": "Точка старта игрока"
	},
	"spawn_enemy": {
		"category": "Персонажи",
		"icon": "👹",
		"name": "Спавн Скинвокера",
		"type": "marker_enemy",
		"size": Vector3(0.9, 2.2, 0.9),
		"color": Color(0.92, 0.15, 0.15),
		"comment": "Точка старта монстра"
	},
	"spawn_lumberjack": {
		"category": "Персонажи",
		"icon": "🪓",
		"name": "Спавн Лесопила",
		"type": "marker_lumberjack",
		"size": Vector3(0.85, 2.0, 0.85),
		"color": Color(0.95, 0.50, 0.15),
		"comment": "Точка старта Лесопила (стрелок с ружьем)"
	},
	"door_exit": {
		"category": "Геймплей",
		"icon": "🚪",
		"name": "Выходная дверь (счетчик/ключ)",
		"type": "door",
		"size": Vector3(1.4, 3.6, 0.4),
		"color": Color(0.40, 0.22, 0.12),
		"comment": "Единая выходная дверь (доски/энергосчетчик/ключ)"
	},
	"item_crowbar": {
		"category": "Геймплей",
		"icon": "🔧",
		"name": "Лом (Crowbar)",
		"type": "item_crowbar",
		"size": Vector3(0.4, 0.6, 0.4),
		"color": Color(0.35, 0.45, 0.95),
		"comment": "Предмет для взлома досок"
	},
	"item_key_gold": {
		"category": "Геймплей",
		"icon": "🟡",
		"name": "Золотой ключ",
		"type": "item_key_gold",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(1.0, 0.85, 0.15),
		"comment": "Ключ золотого цвета"
	},
	"item_key_silver": {
		"category": "Геймплей",
		"icon": "⚪",
		"name": "Серебряный ключ",
		"type": "item_key_silver",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(0.88, 0.92, 0.98),
		"comment": "Ключ серебряного цвета"
	},
	"item_key_rusty": {
		"category": "Геймплей",
		"icon": "🟤",
		"name": "Ржавый ключ",
		"type": "item_key_rusty",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(0.65, 0.38, 0.20),
		"comment": "Ржавый медный ключ"
	},
	"item_key_emerald": {
		"category": "Геймплей",
		"icon": "🟢",
		"name": "Изумрудный ключ",
		"type": "item_key_emerald",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(0.15, 0.95, 0.45),
		"comment": "Мистический зеленый ключ"
	},
	"item_key": {
		"category": "Геймплей",
		"icon": "🗝",
		"name": "Ключ (стандартный)",
		"type": "item_key",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(0.95, 0.80, 0.10),
		"comment": "Ключ от выхода"
	},
	"prop_note_safe": {
		"category": "Геймплей",
		"icon": "📜",
		"name": "Листок с кодом от сейфа",
		"type": "prop_note_safe",
		"size": Vector3(0.4, 0.1, 0.3),
		"color": Color(0.92, 0.88, 0.76),
		"comment": "Листок с подсказкой шифра от сейфа"
	},
	"light_warm": {
		"category": "Освещение",
		"icon": "💡",
		"name": "Лампа (Тёплый свет)",
		"type": "light_warm",
		"size": Vector3(0.4, 0.4, 0.4),
		"color": Color(1.0, 0.88, 0.60),
		"comment": "Мягкий свет (8м)"
	},
	"light_red": {
		"category": "Освещение",
		"icon": "🚨",
		"name": "Аварийный свет",
		"type": "light_red",
		"size": Vector3(0.4, 0.4, 0.4),
		"color": Color(1.0, 0.15, 0.10),
		"comment": "Тревожная красная лампа"
	},
	"prop_crate": {
		"category": "Пропсы",
		"icon": "📦",
		"name": "Деревянный ящик",
		"type": "prop_crate",
		"size": Vector3(1.0, 1.0, 1.0),
		"color": Color(0.48, 0.34, 0.20),
		"comment": "Ящик 1x1x1м"
	},
	"prop_barrel": {
		"category": "Пропсы",
		"icon": "🛢",
		"name": "Металлическая бочка",
		"type": "prop_barrel",
		"size": Vector3(0.7, 1.1, 0.7),
		"color": Color(0.24, 0.30, 0.38),
		"comment": "Бочка"
	},
	# ─────────────────────────────────────────────────────────────
	#  ДЕКОР ХОРРОРА (Кровь, ковры)
	# ─────────────────────────────────────────────────────────────
	"prop_blood_puddle": {
		"category": "Декор",
		"icon": "🩸",
		"name": "Лужа крови",
		"type": "prop_blood_puddle",
		"size": Vector3(2.0, 0.04, 2.0),
		"color": Color(0.38, 0.015, 0.02),
		"comment": "Плоская лужа крови на полу"
	},
	"prop_blood_wall": {
		"category": "Декор",
		"icon": "🩸",
		"name": "Кровь на стене",
		"type": "prop_blood_wall",
		"size": Vector3(0.8, 1.2, 0.1),
		"color": Color(0.36, 0.012, 0.02),
		"comment": "Кровавые брызги и подтеки"
	},
	"prop_carpet": {
		"category": "Декор",
		"icon": "🧶",
		"name": "Старый ковер",
		"type": "prop_carpet",
		"size": Vector3(3.6, 0.04, 2.4),
		"color": Color(0.34, 0.10, 0.12),
		"comment": "Винтажный узорный ковёр"
	},
	# ─────────────────────────────────────────────────────────────
	#  МЕБЕЛЬ ХОРРОРА (Шкаф, стол, стул, тумбочка, кровать)
	# ─────────────────────────────────────────────────────────────
	"prop_nightstand": {
		"category": "Мебель",
		"icon": "🗄",
		"name": "Тумбочка",
		"type": "prop_nightstand",
		"size": Vector3(0.66, 0.74, 0.55),
		"color": Color(0.34, 0.20, 0.11),
		"comment": "Деревянная прикроватная тумба"
	},
	"prop_wardrobe": {
		"category": "Мебель",
		"icon": "🚪",
		"name": "Шкаф для одежды",
		"type": "prop_wardrobe",
		"size": Vector3(1.40, 2.24, 0.70),
		"color": Color(0.29, 0.17, 0.10),
		"comment": "Высокий 2-створчатый шкаф"
	},
	"prop_table": {
		"category": "Мебель",
		"icon": "🪑",
		"name": "Стол деревянный",
		"type": "prop_table",
		"size": Vector3(1.80, 0.80, 0.95),
		"color": Color(0.36, 0.22, 0.13),
		"comment": "Обеденный/рабочий стол"
	},
	"prop_chair": {
		"category": "Мебель",
		"icon": "🪑",
		"name": "Стул деревянный",
		"type": "prop_chair",
		"size": Vector3(0.52, 0.96, 0.52),
		"color": Color(0.40, 0.25, 0.15),
		"comment": "Стул со спинкой"
	},
	"prop_bed": {
		"category": "Мебель",
		"icon": "🛏",
		"name": "Кровать старая",
		"type": "prop_bed",
		"size": Vector3(1.48, 0.88, 2.12),
		"color": Color(0.30, 0.16, 0.09),
		"comment": "Кровать с матрасом и подушкой"
	},
	# ─────────────────────────────────────────────────────────────
	#  УЛИЦА, ПРИРОДА И УМНЫЙ ДОМ
	# ─────────────────────────────────────────────────────────────
	"roof_gable": {
		"category": "Архитектура",
		"icon": "⛺",
		"name": "Двускатная крыша (Зона)",
		"type": "roof_gable",
		"size": Vector3(12.0, 2.4, 8.0),
		"color": Color(0.48, 0.16, 0.16),
		"comment": "Тяните зону: генерирует крышу со скатами и коньком"
	},
	"prop_window_boarded": {
		"category": "Архитектура",
		"icon": "🪟",
		"name": "Заколоченное окно",
		"type": "prop_window_boarded",
		"size": Vector3(1.6, 1.6, 0.25),
		"color": Color(0.35, 0.28, 0.20),
		"comment": "Окно с заколоченными крест-накрест досками"
	},
	"door_simple": {
		"category": "Архитектура",
		"icon": "🚪",
		"name": "Межкомнатная дверь",
		"type": "door_simple",
		"size": Vector3(1.2, 2.4, 0.15),
		"color": Color(0.40, 0.24, 0.14),
		"comment": "Обычная деревянная дверь: открывается и закрывается на [E]"
	},
	"door_metal": {
		"category": "Архитектура",
		"icon": "🚪",
		"name": "Железная дверь (с щитком)",
		"type": "door_metal",
		"size": Vector3(1.3, 2.5, 0.20),
		"color": Color(0.20, 0.22, 0.25),
		"comment": "Тяжелая бронированная дверь с электрощитком проводов"
	},
	"door_hatch": {
		"category": "Архитектура",
		"icon": "🕳️",
		"name": "Дверной люк (в полу)",
		"type": "door_hatch",
		"size": Vector3(1.5, 0.25, 1.5),
		"color": Color(0.35, 0.22, 0.14),
		"comment": "Напольный люк с откидной крышкой на петлях"
	},
	"prop_basement_entrance": {
		"category": "Архитектура",
		"icon": "🚪",
		"name": "Вход в подвал",
		"type": "prop_basement_entrance",
		"size": Vector3(2.0, 1.25, 2.4),
		"color": Color(0.42, 0.28, 0.16),
		"comment": "Наклонный уличный вход в подвал с деревянными створками"
	},
	"prop_sofa": {
		"category": "Мебель",
		"icon": "🛋",
		"name": "Диван",
		"type": "prop_sofa",
		"size": Vector3(2.4, 0.95, 1.05),
		"color": Color(0.35, 0.22, 0.18),
		"comment": "Мягкий диван с подушками и подлокотниками"
	},
	"prop_armchair": {
		"category": "Мебель",
		"icon": "🪑",
		"name": "Кресло",
		"type": "prop_armchair",
		"size": Vector3(1.1, 0.95, 1.0),
		"color": Color(0.28, 0.32, 0.40),
		"comment": "Удобное мягкое кресло со спинкой"
	},
	"prop_tv": {
		"category": "Мебель",
		"icon": "📺",
		"name": "Телевизор",
		"type": "prop_tv",
		"size": Vector3(1.6, 1.0, 0.35),
		"color": Color(0.08, 0.08, 0.10),
		"comment": "Телевизор со светящимся экраном"
	},
	"prop_bookshelf": {
		"category": "Мебель",
		"icon": "📚",
		"name": "Книжный шкаф",
		"type": "prop_bookshelf",
		"size": Vector3(1.4, 2.2, 0.45),
		"color": Color(0.32, 0.20, 0.12),
		"comment": "Шкаф с полками и разноцветными книгами"
	},
	"prop_dresser": {
		"category": "Мебель",
		"icon": "🗄",
		"name": "Комод",
		"type": "prop_dresser",
		"size": Vector3(1.3, 1.1, 0.55),
		"color": Color(0.40, 0.25, 0.15),
		"comment": "Комод с выдвижными ящиками и ручками"
	},
	"prop_cupboard": {
		"category": "Мебель",
		"icon": "🚪",
		"name": "Навесной шкафчик",
		"type": "prop_cupboard",
		"size": Vector3(0.80, 0.90, 0.35),
		"color": Color(0.36, 0.22, 0.13),
		"comment": "Навесной шкаф с открывающейся дверцей и полками"
	},
	"prop_lamp_floor": {
		"category": "Освещение",
		"icon": "🪔",
		"name": "Торшер напольный",
		"type": "prop_lamp_floor",
		"size": Vector3(0.6, 1.9, 0.6),
		"color": Color(0.95, 0.88, 0.70),
		"comment": "Светильник с тёплым светом"
	},
	"prop_painting_portrait": {
		"category": "🖼 Картины",
		"icon": "👤",
		"name": "Картина: Портрет предка",
		"type": "prop_painting_portrait",
		"size": Vector3(1.0, 1.4, 0.08),
		"color": Color.WHITE,
		"comment": "Старинный портрет со следящим взглядом"
	},
	"prop_painting_landscape": {
		"category": "🖼 Картины",
		"icon": "🌲",
		"name": "Картина: Мрачный лес",
		"type": "prop_painting_landscape",
		"size": Vector3(1.6, 1.1, 0.08),
		"color": Color.WHITE,
		"comment": "Ночной пейзаж с туманными соснами"
	},
	"prop_painting_moon": {
		"category": "🖼 Картины",
		"icon": "🌕",
		"name": "Картина: Кровавая луна",
		"type": "prop_painting_moon",
		"size": Vector3(1.3, 1.3, 0.08),
		"color": Color.WHITE,
		"comment": "Багровая луна над одинокой хижиной"
	},
	"prop_painting_skinwalker": {
		"category": "🖼 Картины",
		"icon": "👹",
		"name": "Картина: Тень в чаще",
		"type": "prop_painting_skinwalker",
		"size": Vector3(1.3, 1.3, 0.08),
		"color": Color.WHITE,
		"comment": "Силуэт Скинвокера с горящими глазами"
	},
	"prop_painting_entity": {
		"category": "🖼 Картины",
		"icon": "👻",
		"name": "Картина: Искаженный лик",
		"type": "prop_painting_entity",
		"size": Vector3(1.1, 1.4, 0.08),
		"color": Color.WHITE,
		"comment": "Кричащий призрак во тьме"
	},
	"prop_painting_vintage": {
		"category": "🖼 Картины",
		"icon": "💀",
		"name": "Картина: Череп и свеча",
		"type": "prop_painting_vintage",
		"size": Vector3(1.4, 1.1, 0.08),
		"color": Color.WHITE,
		"comment": "Готический натюрморт vanitas"
	},
	"prop_painting": {
		"category": "🖼 Картины",
		"icon": "🖼",
		"name": "Картина на стену (Базовая)",
		"type": "prop_painting",
		"size": Vector3(1.2, 0.9, 0.08),
		"color": Color.WHITE,
		"comment": "Картина в деревянной раме"
	},
	"prop_plant_pot": {
		"category": "Мебель",
		"icon": "🪴",
		"name": "Растение в горшке",
		"type": "prop_plant_pot",
		"size": Vector3(0.6, 0.9, 0.6),
		"color": Color(0.18, 0.52, 0.22),
		"comment": "Комнатный цветок в глиняном горшке"
	},
	"prop_fridge": {
		"category": "Мебель",
		"icon": "🧊",
		"name": "Холодильник",
		"type": "prop_fridge",
		"size": Vector3(0.9, 2.0, 0.9),
		"color": Color(0.88, 0.90, 0.92),
		"comment": "Двухкамерный холодильник с ручкой"
	},
	"prop_stove": {
		"category": "Мебель",
		"icon": "🍳",
		"name": "Кухонная плита",
		"type": "prop_stove",
		"size": Vector3(0.85, 0.95, 0.85),
		"color": Color(0.20, 0.22, 0.24),
		"comment": "Плита с 4 конфорками"
	},
	"prop_kitchen_counter": {
		"category": "Мебель",
		"icon": "🗄",
		"name": "Кухонная тумба",
		"type": "prop_kitchen_counter",
		"size": Vector3(1.2, 0.95, 0.75),
		"color": Color(0.72, 0.68, 0.60),
		"comment": "Столешница с тумбой"
	},
	"prop_toilet": {
		"category": "Ванная",
		"icon": "🚽",
		"name": "Унитаз",
		"type": "prop_toilet",
		"size": Vector3(0.6, 0.85, 0.75),
		"color": Color(0.92, 0.94, 0.96),
		"comment": "Белый фарфоровый унитаз с бачком"
	},
	"prop_bathtub": {
		"category": "Ванная",
		"icon": "🛁",
		"name": "Ванна",
		"type": "prop_bathtub",
		"size": Vector3(1.7, 0.65, 0.85),
		"color": Color(0.92, 0.94, 0.96),
		"comment": "Большая эмалированная ванна"
	},
	"prop_sink": {
		"category": "Ванная",
		"icon": "🚰",
		"name": "Раковина",
		"type": "prop_sink",
		"size": Vector3(0.65, 0.90, 0.55),
		"color": Color(0.92, 0.94, 0.96),
		"comment": "Умывальник на пьедестале"
	},
	"prop_shower_cabin": {
		"category": "Ванная",
		"icon": "🚿",
		"name": "Душевая кабина",
		"type": "prop_shower_cabin",
		"size": Vector3(1.1, 2.1, 1.1),
		"color": Color(0.7, 0.85, 0.95),
		"comment": "Стеклянная душевая кабина с поддоном"
	},
	"prop_mirror": {
		"category": "Мебель",
		"icon": "🪞",
		"name": "Зеркало настенное",
		"type": "prop_mirror",
		"size": Vector3(0.9, 1.6, 0.08),
		"color": Color(0.85, 0.90, 0.98),
		"comment": "Большое настенное зеркало в золоченой раме"
	},
	"prop_mirror_broken": {
		"category": "Ванная",
		"icon": "🪞",
		"name": "Сломанное зеркало",
		"type": "prop_mirror_broken",
		"size": Vector3(0.8, 1.2, 0.08),
		"color": Color(0.85, 0.90, 0.95),
		"comment": "Зеркало с металлическим отражением и трещинами"
	},
	"road_segment": {
		"category": "Улица",
		"icon": "🛣",
		"name": "Дорога асфальт",
		"type": "road_segment",
		"size": Vector3(12.0, 0.12, 40.0),
		"color": Color(0.13, 0.14, 0.16),
		"comment": "Секция дороги с разметкой и обочиной"
	},
	"prop_car": {
		"category": "Улица",
		"icon": "🚗",
		"name": "Машина для побега",
		"type": "prop_car",
		"size": Vector3(2.0, 1.5, 4.4),
		"color": Color(0.20, 0.32, 0.48),
		"comment": "Автомобиль с фарами и колесами"
	},
	"prop_bench": {
		"category": "Улица",
		"icon": "🪵",
		"name": "Скамейка уличная",
		"type": "prop_bench",
		"size": Vector3(1.6, 0.85, 0.65),
		"color": Color(0.48, 0.30, 0.16),
		"comment": "Парковая деревянная лавочка"
	},
	"prop_streetlight": {
		"category": "Улица",
		"icon": "🏮",
		"name": "Уличный фонарь",
		"type": "prop_streetlight",
		"size": Vector3(0.6, 4.2, 0.9),
		"color": Color(0.22, 0.24, 0.26),
		"comment": "Фонарный столб с ярким светом"
	},
	"prop_fence_section": {
		"category": "Улица",
		"icon": "🚧",
		"name": "Секция забора",
		"type": "prop_fence_section",
		"size": Vector3(2.5, 1.4, 0.12),
		"color": Color(0.50, 0.35, 0.20),
		"comment": "Деревянный штакетник"
	},
	"prop_trash_bin": {
		"category": "Улица",
		"icon": "🗑",
		"name": "Мусорный бак",
		"type": "prop_trash_bin",
		"size": Vector3(0.65, 0.95, 0.65),
		"color": Color(0.16, 0.18, 0.16),
		"comment": "Уличная урна для мусора"
	},
	"prop_hydrant": {
		"category": "Улица",
		"icon": "🚒",
		"name": "Пожарный гидрант",
		"type": "prop_hydrant",
		"size": Vector3(0.5, 0.8, 0.5),
		"color": Color(0.85, 0.15, 0.15),
		"comment": "Красный пожарный гидрант"
	},
	"prop_mailbox": {
		"category": "Улица",
		"icon": "📫",
		"name": "Почтовый ящик",
		"type": "prop_mailbox",
		"size": Vector3(0.4, 1.2, 0.55),
		"color": Color(0.20, 0.38, 0.65),
		"comment": "Американский почтовый ящик на столбике"
	},
	"prop_tree": {
		"category": "Природа",
		"icon": "🌳",
		"name": "Дерево лиственное",
		"type": "prop_tree",
		"size": Vector3(3.5, 5.5, 3.5),
		"color": Color(0.18, 0.42, 0.16),
		"comment": "Зелёное дерево с пышной кроной"
	},
	"prop_tree_pine": {
		"category": "Природа",
		"icon": "🌲",
		"name": "Ель хвойная",
		"type": "prop_tree_pine",
		"size": Vector3(3.0, 6.0, 3.0),
		"color": Color(0.12, 0.30, 0.14),
		"comment": "Высокая тёмно-зелёная ель"
	},
	"prop_tree_dead": {
		"category": "Природа",
		"icon": "🪵",
		"name": "Мёртвое сухое дерево",
		"type": "prop_tree_dead",
		"size": Vector3(3.2, 5.8, 3.2),
		"color": Color(0.15, 0.13, 0.12),
		"comment": "Зловещее искривлённое сухое дерево без листьев"
	},
	"prop_tree_carved": {
		"category": "Природа",
		"icon": "👹",
		"name": "Дерево с меткой Скинвокера",
		"type": "prop_tree_carved",
		"size": Vector3(3.2, 6.2, 3.2),
		"color": Color(0.18, 0.13, 0.10),
		"comment": "Ритуальное дерево с вырезанным рогатым ликом Скинвокера и алым отблеском"
	},
	"prop_tree_warning": {
		"category": "Природа",
		"icon": "⚠️",
		"name": "Дерево с предупреждением",
		"type": "prop_tree_warning",
		"size": Vector3(3.2, 6.2, 3.2),
		"color": Color(0.18, 0.13, 0.10),
		"comment": "Дерево с перечёркнутым глазом, бегущим человеком и кровавой надписью RUN"
	},
	"prop_tree_claws": {
		"category": "Природа",
		"icon": "🩸",
		"name": "Дерево со следами когтей",
		"type": "prop_tree_claws",
		"size": Vector3(3.2, 6.2, 3.2),
		"color": Color(0.18, 0.13, 0.10),
		"comment": "Дерево с глубокими кровоточащими бороздами от когтей чудовища"
	},
	"prop_bush_dead": {
		"category": "Природа",
		"icon": "🌾",
		"name": "Сухой кустарник",
		"type": "prop_bush_dead",
		"size": Vector3(1.4, 1.2, 1.4),
		"color": Color(0.22, 0.18, 0.14),
		"comment": "Колючий засохший куст у дороги"
	},
	"prop_leaves_pile": {
		"category": "Природа",
		"icon": "🍂",
		"name": "Опавшая листва",
		"type": "prop_leaves_pile",
		"size": Vector3(2.4, 0.14, 2.4),
		"color": Color(0.68, 0.38, 0.16),
		"comment": "Куча опавшей сухой осенней листвы на земле или полу"
	},
	"prop_bush_foliage": {
		"category": "Природа",
		"icon": "🌿",
		"name": "Куст с листвой",
		"type": "prop_bush_foliage",
		"size": Vector3(1.8, 1.4, 1.8),
		"color": Color(0.20, 0.38, 0.18),
		"comment": "Пышный кустарник с густой зелёной листвой"
	},
	"prop_tree_deciduous": {
		"category": "Природа",
		"icon": "🌳",
		"name": "Лиственное дерево",
		"type": "prop_tree_deciduous",
		"size": Vector3(4.0, 6.5, 4.0),
		"color": Color(0.22, 0.42, 0.18),
		"comment": "Дерево с мощным стволом и пышной многоярусной кроной листвы"
	},
	"prop_ivy_wall": {
		"category": "Природа",
		"icon": "🍃",
		"name": "Настенный плющ",
		"type": "prop_ivy_wall",
		"size": Vector3(1.8, 2.6, 0.15),
		"color": Color(0.18, 0.36, 0.16),
		"comment": "Свисающая со стены дикая листва и плющ"
	},
	"prop_power_pole": {
		"category": "Улица",
		"icon": "🗼",
		"name": "Столб ЛЭП с проводами",
		"type": "prop_power_pole",
		"size": Vector3(2.4, 7.5, 3.0),
		"color": Color(0.24, 0.18, 0.12),
		"comment": "Деревянный столб электропередач с изоляторами"
	},
	"prop_road_barrier": {
		"category": "Улица",
		"icon": "🚧",
		"name": "Дорожное заграждение",
		"type": "prop_road_barrier",
		"size": Vector3(2.2, 1.0, 0.6),
		"color": Color(0.95, 0.82, 0.15),
		"comment": "Полосатый аварийный барьер с бетонным основанием"
	},
	"prop_car_wreck": {
		"category": "Улица",
		"icon": "🚙",
		"name": "Разбитый остов авто",
		"type": "prop_car_wreck",
		"size": Vector3(2.1, 1.4, 4.4),
		"color": Color(0.38, 0.22, 0.14),
		"comment": "Ржавый разбитый автомобиль с вмятой крышей"
	},
	"prop_rock_large": {
		"category": "Природа",
		"icon": "🪨",
		"name": "Большая скала",
		"type": "prop_rock_large",
		"size": Vector3(4.5, 3.2, 4.0),
		"color": Color(0.32, 0.33, 0.36),
		"comment": "Массивный природный валун"
	},
	"door_electric": {
		"category": "⚡ Электрика",
		"icon": "⚡",
		"name": "Электро-дверь с Maglock",
		"type": "door_electric",
		"size": Vector3(1.6, 2.8, 0.4),
		"color": Color(0.20, 0.22, 0.26),
		"comment": "Дверь под высоким напряжением! Шок при касании, отпугивает монстра. Обесточивается через щиток."
	},
	"prop_fusebox": {
		"category": "⚡ Электрика",
		"icon": "🧰",
		"name": "Электрощиток с предохранителями",
		"type": "prop_fusebox",
		"size": Vector3(0.50, 0.68, 0.25),
		"color": Color(0.25, 0.28, 0.32),
		"comment": "Щиток на 3 предохранителя (Красный, Синий, Зелёный) с рубильником"
	},
	"item_fuse_red": {
		"category": "⚡ Электрика",
		"icon": "🔴",
		"name": "Красный предохранитель",
		"type": "item_fuse_red",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(1.0, 0.15, 0.15),
		"comment": "Стеклянный предохранитель для электрощитка [E]"
	},
	"item_fuse_blue": {
		"category": "⚡ Электрика",
		"icon": "🔵",
		"name": "Синий предохранитель",
		"type": "item_fuse_blue",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(0.2, 0.6, 1.0),
		"comment": "Предохранитель из стального сейфа [E]"
	},
	"item_fuse_green": {
		"category": "⚡ Электрика",
		"icon": "🟢",
		"name": "Зелёный предохранитель",
		"type": "item_fuse_green",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(0.2, 1.0, 0.3),
		"comment": "Предохранитель из напольных часов [E]"
	},
	"prop_grandfather_clock": {
		"category": "Мебель",
		"icon": "🕰",
		"name": "Напольные часы с маятником",
		"type": "prop_grandfather_clock",
		"size": Vector3(0.65, 2.20, 0.45),
		"color": Color(0.24, 0.14, 0.08),
		"comment": "Качающийся маятник, бьют колоколами привлекая скинвокера. Внутри зелёный предохранитель!"
	},
	"prop_crt_tv": {
		"category": "Мебель",
		"icon": "📺",
		"name": "Ретро-телевизор (Видео / VHS)",
		"type": "prop_crt_tv",
		"size": Vector3(0.74, 0.86, 0.48),
		"color": Color(0.28, 0.17, 0.10),
		"comment": "80s ТВ с кинескопом, шумом VHS и видео. Включается ночью и привлекает монстра!"
	},
	"prop_occult_altar": {
		"category": "Мебель",
		"icon": "🕯",
		"name": "Оккультный алтарь со свечами",
		"type": "prop_occult_altar",
		"size": Vector3(1.30, 1.20, 0.80),
		"color": Color(0.14, 0.13, 0.15),
		"comment": "Ритуальный алтарь с черепом, задуваемыми свечами и дневником с кодом от сейфа"
	},
	"prop_safe": {
		"category": "Мебель",
		"icon": "🔒",
		"name": "Стальной сейф с шифром",
		"type": "prop_safe",
		"size": Vector3(0.64, 0.74, 0.58),
		"color": Color(0.18, 0.20, 0.23),
		"comment": "Тяжелый сейф с 3-значным шифром. Внутри синий предохранитель!"
	},
	"item_battery": {
		"category": "Геймплей",
		"icon": "🔋",
		"name": "Батарея",
		"type": "item_battery",
		"size": Vector3(0.3, 0.4, 0.3),
		"color": Color(0.12, 0.65, 0.25),
		"comment": "Заряжает фонарик и питает электро-дверь [E]"
	},
	"prop_note": {
		"category": "Геймплей",
		"icon": "📜",
		"name": "Порванная записка",
		"type": "prop_note",
		"size": Vector3(0.4, 0.1, 0.3),
		"color": Color(0.88, 0.84, 0.72),
		"comment": "Обрывок с текстом выжившего [E]"
	},
	"prop_light_switch": {
		"category": "Геймплей",
		"icon": "💡",
		"name": "Выключатель света",
		"type": "prop_light_switch",
		"size": Vector3(0.2, 0.3, 0.1),
		"color": Color(0.88, 0.88, 0.90),
		"comment": "Настенный переключатель [E]"
	},
	"light_ceiling": {
		"category": "Освещение",
		"icon": "💡",
		"name": "Люстра потолочная",
		"type": "light_ceiling",
		"size": Vector3(0.5, 0.8, 0.5),
		"color": Color(1.0, 0.9, 0.65),
		"comment": "Подвесной комнатный светильник"
	},
	"prop_dog": {
		"category": "Животные",
		"icon": "🐕",
		"name": "Собака",
		"type": "prop_dog",
		"size": Vector3(0.7, 0.75, 1.1),
		"color": Color(0.60, 0.40, 0.22),
		"comment": "Верный низкополигональный пёс"
	}
}

# ══════════════════════════════════════════════════════════════════════════════
#  Инициализация
# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# Инструмент разработчика: обычные кнопки Godot вместо оформления игры
	get_window().theme = ThemeDB.get_default_theme()
	name = "DebugEditor"
	_scan_custom_models()
	_scan_user_prefabs()
	_setup_environment()
	_setup_camera()
	_setup_nav_region()
	_setup_grid()
	_setup_selection_box()
	_build_editor_ui()

	# Автозагрузка карты или создание чистого полигона
	# Приоритет: 1) GameManager.active_map_path, 2) Карта_6.json, 3) Карта_4.json, 4) prototype map.json
	var loaded_map = false
	var gm = _get_gm()
	if gm and str(gm.get("active_map_path")) != "" and FileAccess.file_exists(str(gm.get("active_map_path"))):
		loaded_map = load_map_from_json(str(gm.get("active_map_path")))
	if not loaded_map and FileAccess.file_exists("res://scenes/Карта_6.json"):
		loaded_map = load_map_from_json("res://scenes/Карта_6.json")
	if not loaded_map and FileAccess.file_exists("res://scenes/Карта_4.json"):
		loaded_map = load_map_from_json("res://scenes/Карта_4.json")
	if not loaded_map and FileAccess.file_exists("res://assets/prototype map.json"):
		loaded_map = load_map_from_json("res://assets/prototype map.json")
	if not loaded_map and FileAccess.file_exists("res://assets/map.json"):
		loaded_map = load_map_from_json("res://assets/map.json")
	if not loaded_map and FileAccess.file_exists("user://custom_map.json"):
		loaded_map = load_map_from_json("user://custom_map.json")
	if not loaded_map:
		create_clean_polygon()

	show_notification("Редактор готов! [1] Ставить | [2] Удалить | [3] Двигать | [Tab] Каталог | [7] Тест")

# ──────────────────────────────────────────────────────────────────────────────
#  Поиск и регистрация пользовательских 3D-моделей
# ──────────────────────────────────────────────────────────────────────────────
func _scan_custom_models() -> void:
	var dir_path = "res://assets/custom_models"
	var dir = DirAccess.open(dir_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			var ext = file_name.get_extension().to_lower()
			if ext in ["glb", "gltf", "obj", "tscn"]:
				var base_id = "custom_" + file_name.get_basename().to_lower()
				var full_path = dir_path + "/" + file_name
				var lower_name = file_name.to_lower()

				var m_type = "custom_prop"
				var m_icon = "🎨"
				var m_comment = "3D Модель (%s)" % ext.to_upper()

				if "door" in lower_name or "дверь" in lower_name:
					m_type = "custom_door"
					m_icon = "🚪"
					m_comment = "Кастомная интерактивная дверь"
				elif "crowbar" in lower_name or "лом" in lower_name:
					m_type = "custom_item_crowbar"
					m_icon = "🔧"
					m_comment = "Кастомный лом"
				elif "key" in lower_name or "ключ" in lower_name:
					m_type = "custom_item_key"
					m_icon = "🗝"
					m_comment = "Кастомный ключ"
				elif "enemy" in lower_name or "скинвокер" in lower_name or "monster" in lower_name:
					m_type = "custom_enemy"
					m_icon = "👹"
					m_comment = "Кастомный монстр"

				PREFABS[base_id] = {
					"category": "🎨 Мои модели",
					"icon": m_icon,
					"name": file_name.get_basename().capitalize(),
					"type": m_type,
					"model_path": full_path,
					"size": Vector3(1.5, 2.0, 1.5),
					"color": Color(0.85, 0.85, 0.90),
					"comment": m_comment
				}
		file_name = dir.get_next()

# ──────────────────────────────────────────────────────────────────────────────
#  Окружение и свет
# ──────────────────────────────────────────────────────────────────────────────
func _scan_user_prefabs() -> void:
	var dir_path = "user://custom_prefabs"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
		return
	var dir = DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file = FileAccess.open(dir_path + "/" + file_name, FileAccess.READ)
			if file:
				var json = JSON.new()
				if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
					var d: Dictionary = json.data
					var m_name = str(d.get("name", file_name.get_basename()))
					var sa = d.get("scale", [1, 1, 1])
					var sz = Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
					var col_str = str(d.get("color", "#ffffff"))
					var pid = "user_prefab_" + file_name.get_basename()
					PREFABS[pid] = {
						"category": "⭐ Мои модели",
						"icon": "🎨",
						"name": m_name,
						"type": str(d.get("type", "cube")),
						"size": sz,
						"color": Color.html(col_str),
						"comment": "Пользовательская модель: " + m_name,
						"model_path": str(d.get("model_path", ""))
					}
				file.close()
		file_name = dir.get_next()

# ──────────────────────────────────────────────────────────────────────────────
#  Окружение и свет
# ──────────────────────────────────────────────────────────────────────────────
# ──────────────────────────────────────────────────────────────────────────────
#  Окружение и свет
# ──────────────────────────────────────────────────────────────────────────────
func _setup_environment() -> void:
	var env_node = WorldEnvironment.new()
	if ResourceLoader.exists("res://assets/night_env.tres"):
		world_env = load("res://assets/night_env.tres").duplicate() as Environment
	if not world_env:
		world_env = Environment.new()
		world_env.background_mode = Environment.BG_SKY
		var sky = Sky.new()
		var sky_mat = ProceduralSkyMaterial.new()
		sky_mat.sky_top_color = Color(0.015, 0.02, 0.045)
		sky_mat.sky_horizon_color = Color(0.04, 0.065, 0.12)
		sky_mat.ground_bottom_color = Color(0.008, 0.01, 0.018)
		sky_mat.ground_horizon_color = Color(0.04, 0.065, 0.12)
		sky_mat.sun_angle_max = 0.0
		sky.sky_material = sky_mat
		world_env.sky = sky

	world_env.background_mode = Environment.BG_SKY
	world_env.fog_enabled = true
	world_env.fog_density = 0.002
	world_env.fog_light_color = Color(0.035, 0.05, 0.09)

	env_node.environment = world_env
	add_child(env_node)

	sun_light = DirectionalLight3D.new()
	sun_light.name = "EditorSun"
	sun_light.rotation_degrees = Vector3(-45, 25, 0)
	sun_light.light_color = Color(0.70, 0.82, 1.0)
	sun_light.light_energy = 0.45
	sun_light.shadow_enabled = true
	add_child(sun_light)

	_build_sky_and_moon()
	_apply_lighting_mode()


func _build_sky_and_moon() -> void:
	if sky_elements_node and is_instance_valid(sky_elements_node):
		sky_elements_node.queue_free()
	sky_elements_node = Node3D.new()
	sky_elements_node.name = "SkyElements"
	add_child(sky_elements_node)

	# 1. Текстурированная полная Луна (SphereMesh с moon_surface.png)
	var moon_pos = Vector3(18.0, 48.0, -75.0)
	var moon_mesh_inst = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 5.2
	sphere.height = 10.4
	var moon_mat = StandardMaterial3D.new()
	var moon_tex = TextureHelper.get_texture("res://assets/textures/moon_surface.png")
	if moon_tex:
		moon_mat.albedo_texture = moon_tex
		moon_mat.roughness = 0.8
		moon_mat.emission_enabled = true
		moon_mat.emission_texture = moon_tex
		moon_mat.emission = Color(0.88, 0.94, 1.0)
		moon_mat.emission_energy_multiplier = 0.7
	else:
		moon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		moon_mat.albedo_color = Color(0.92, 0.95, 1.0)
	sphere.material = moon_mat
	moon_mesh_inst.mesh = sphere
	moon_mesh_inst.position = moon_pos
	moon_mesh_inst.rotation_degrees = Vector3(15, -35, 10)
	sky_elements_node.add_child(moon_mesh_inst)

	# 2. Ореол свечения вокруг луны
	var glow_tex = TextureHelper.get_texture("res://assets/textures/moon_glow.png")

	var halo = MeshInstance3D.new()
	var hm = QuadMesh.new()
	hm.size = Vector2(28.0, 28.0)
	var hmat = StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow_tex:
		hmat.albedo_texture = glow_tex
		hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hmat.albedo_color = Color(0.70, 0.84, 1.0, 0.7)
	else:
		hmat.albedo_color = Color(0.55, 0.72, 0.98, 0.25)
	hm.material = hmat
	halo.mesh = hm
	halo.position = moon_pos + Vector3(0, 0, 1.2)
	halo.rotation_degrees = Vector3(30, -15, 0)
	sky_elements_node.add_child(halo)

	var outer_halo = MeshInstance3D.new()
	var ohm = QuadMesh.new()
	ohm.size = Vector2(58.0, 58.0)
	var ohmat = StandardMaterial3D.new()
	ohmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ohmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow_tex:
		ohmat.albedo_texture = glow_tex
		ohmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ohmat.albedo_color = Color(0.35, 0.55, 0.85, 0.28)
	else:
		ohmat.albedo_color = Color(0.35, 0.55, 0.85, 0.10)
	ohm.material = ohmat
	outer_halo.mesh = ohm
	outer_halo.position = moon_pos + Vector3(0, 0, 0.8)
	outer_halo.rotation_degrees = Vector3(30, -15, 0)
	sky_elements_node.add_child(outer_halo)

	# 3. Высокие ночные облака над головой (не закрывают луну)
	moon_clouds.clear()
	for c_i in range(8):
		var cloud = MeshInstance3D.new()
		var cm = BoxMesh.new()
		cm.size = Vector3(randf_range(32.0, 60.0), randf_range(1.0, 2.5), randf_range(25.0, 50.0))
		var cmat = StandardMaterial3D.new()
		cmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cmat.albedo_color = Color(0.04, 0.06, 0.10, randf_range(0.20, 0.35))
		cm.material = cmat
		cloud.mesh = cm
		cloud.position = Vector3(randf_range(-60.0, 60.0), randf_range(68.0, 85.0), randf_range(-50.0, 50.0))
		cloud.set_meta("drift_speed", randf_range(0.4, 1.0))
		sky_elements_node.add_child(cloud)
		moon_clouds.append(cloud)

	# 4. Купол ночных звёзд (280 звёзд)
	stars_node = MultiMeshInstance3D.new()
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var star_mesh = BoxMesh.new()
	star_mesh.size = Vector3(0.32, 0.32, 0.32)
	var star_mat = StandardMaterial3D.new()
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mat.vertex_color_use_as_albedo = true
	star_mesh.material = star_mat
	mm.mesh = star_mesh
	mm.instance_count = 280

	for s_i in range(280):
		var theta = randf_range(0.0, TAU)
		var phi = randf_range(0.12, 1.35)
		var r = randf_range(70.0, 110.0)
		var sx = r * sin(phi) * cos(theta)
		var sy = r * cos(phi) + 14.0
		var sz_pos = r * sin(phi) * sin(theta) - 20.0

		var t = Transform3D()
		t.origin = Vector3(sx, sy, sz_pos)
		var tint_choice = randf()
		var s_col: Color
		if tint_choice < 0.6:
			s_col = Color(randf_range(0.85, 1.0), randf_range(0.9, 1.0), 1.0, randf_range(0.6, 1.0))
		elif tint_choice < 0.85:
			s_col = Color(randf_range(0.7, 0.85), randf_range(0.85, 1.0), 1.0, randf_range(0.65, 1.0))
		else:
			s_col = Color(1.0, randf_range(0.8, 0.95), randf_range(0.6, 0.8), randf_range(0.6, 0.95))
		mm.set_instance_transform(s_i, t)
		mm.set_instance_color(s_i, s_col)

	stars_node.multimesh = mm
	sky_elements_node.add_child(stars_node)

	# 5. Живой многослойный параллакс горизонта (Горы и Ночной Город)
	var parallax = ParallaxHorizon.new()
	sky_elements_node.add_child(parallax)


func _apply_lighting_mode() -> void:
	if not world_env:
		return

	world_env.background_mode = Environment.BG_SKY
	world_env.fog_enabled = true
	world_env.fog_density = 0.002
	world_env.fog_light_color = Color(0.035, 0.05, 0.09)

	if current_mode == EditorMode.EDIT:
		# ─── РЕЖИМ РЕДАКТОРА ───
		if is_fullbright:
			world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			world_env.ambient_light_color = Color(0.92, 0.94, 0.98)
			world_env.ambient_light_energy = 1.8
			if sun_light:
				sun_light.visible = true
				sun_light.light_energy = 1.0
				sun_light.shadow_enabled = false
			if cam_light:
				cam_light.visible = true
				cam_light.light_energy = 0.8
		else:
			# Комфортная атмосфера ночи для строительства (хорошо видно стены и небо со звездами)
			world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			world_env.ambient_light_color = Color(0.20, 0.25, 0.35)
			world_env.ambient_light_energy = 0.95
			if sun_light:
				sun_light.visible = true
				sun_light.light_energy = 0.55
				sun_light.shadow_enabled = false
			if cam_light:
				cam_light.visible = true
				cam_light.light_energy = 0.50
	else:
		# ─── РЕЖИМ ПОЛИГОНА (ТЕСТ ГЕЙМПЛЕЯ) ───
		if is_fullbright:
			world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			world_env.ambient_light_color = Color(0.90, 0.92, 0.98)
			world_env.ambient_light_energy = 1.8
			if sun_light:
				sun_light.visible = true
				sun_light.light_energy = 1.0
				sun_light.shadow_enabled = false
			if cam_light:
				cam_light.visible = false
		else:
			# Полная тьма хоррора как в геймплее (фонарик игрока + лунный свет)
			world_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			world_env.ambient_light_color = Color(0.015, 0.02, 0.035)
			world_env.ambient_light_energy = 0.15
			if sun_light:
				sun_light.visible = true
				sun_light.light_energy = 0.35
				sun_light.shadow_enabled = true
			if cam_light:
				cam_light.visible = false

	_update_fullbright_button_ui()

func toggle_fullbright() -> void:
	is_fullbright = not is_fullbright
	_apply_lighting_mode()
	if is_fullbright:
		show_notification("💡 ОСВЕЩЕНИЕ: ЯРКИЙ РЕЖИМ (Всё видно!) [Ё]")
	else:
		show_notification("🌑 ОСВЕЩЕНИЕ: " + ("СТУДИЯ (Редактор) [Ё]" if current_mode == EditorMode.EDIT else "ХОРРОР (Тьма) [Ё]"))

func _update_fullbright_button_ui() -> void:
	if not btn_fullbright:
		return
	if is_fullbright:
		btn_fullbright.text = "💡 Свет ВКЛ [Ё]"
		btn_fullbright.modulate = Color(1.0, 1.0, 0.3)
	else:
		btn_fullbright.text = "🌑 Свет [Ё]"
		btn_fullbright.modulate = Color(1.0, 1.0, 1.0)

# ──────────────────────────────────────────────────────────────────────────────
#  Камера FlyCam
# ──────────────────────────────────────────────────────────────────────────────
func _setup_camera() -> void:
	cam_pivot = Node3D.new()
	cam_pivot.name = "CamPivot"
	cam_pivot.position = Vector3(0.0, 8.0, 14.0)
	add_child(cam_pivot)

	editor_cam = Camera3D.new()
	editor_cam.name = "EditorCamera"
	editor_cam.fov = 75.0
	editor_cam.far = 2500.0
	editor_cam.near = 0.15
	editor_cam.current = true
	cam_speed = 22.0
	cam_fast_mult = 3.8 # При зажатом Shift камера летит со скоростью ~85 м/с по карте 1000х1000
	cam_pivot.add_child(editor_cam)

	cam_light = OmniLight3D.new()
	cam_light.name = "EditorCamHeadlight"
	cam_light.omni_range = 35.0
	cam_light.light_energy = 0.50
	cam_light.light_color = Color(0.95, 0.97, 1.0)
	cam_light.shadow_enabled = false
	editor_cam.add_child(cam_light)

	_update_cam_rotation()

func _update_cam_rotation() -> void:
	cam_pivot.rotation_degrees = Vector3(0, cam_yaw, 0)
	editor_cam.rotation_degrees = Vector3(cam_pitch, 0, 0)

# ──────────────────────────────────────────────────────────────────────────────
#  Сетка полигона (Grid) — Слой коллизии 2 (Зеленая трава 1000х1000м)
# ──────────────────────────────────────────────────────────────────────────────
func _setup_grid() -> void:
	# Используем корневой узел-контейнер, который представляем как "grid_mesh" для совместимости
	grid_mesh = MeshInstance3D.new()
	grid_mesh.name = "FloorGridRoot"
	grid_mesh.mesh = null # Пустой, дочерние чанки несут реальные меши
	grid_mesh.position = Vector3.ZERO
	add_child(grid_mesh)

	# Зеленая трава: разбита на 3 полосы по оси X для GPU frustum culling
	# Без разбивки 1000x1000м = один draw call на весь экран — тяжелый фриз при загрузке
	var grass_mat = StandardMaterial3D.new()
	grass_mat.albedo_color = Color(0.16, 0.32, 0.14) # Зеленая трава
	grass_mat.roughness = 0.95

	var chunk_sz = Vector2(334.0, 1000.0)
	var chunk_offsets = [-334.0, 0.0, 334.0]
	for ci in range(3):
		var chunk = MeshInstance3D.new()
		chunk.name = "GrassChunk%d" % ci
		var plane = PlaneMesh.new()
		plane.size = chunk_sz
		plane.material = grass_mat
		chunk.mesh = plane
		chunk.position = Vector3(chunk_offsets[ci], -0.01, 0.0)
		# Оптимизация: отключаем тени от земли, не влияем на GI
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chunk.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		grid_mesh.add_child(chunk)

	# Один безграничный WorldBoundaryShape для физики — дешевле трёх BoxShape
	var sb = StaticBody3D.new()
	sb.collision_layer = 1 | 2
	sb.collision_mask = 0
	var col = CollisionShape3D.new()
	var shape = WorldBoundaryShape3D.new()
	shape.plane = Plane(Vector3.UP, 0)
	col.shape = shape
	sb.add_child(col)
	sb.set_meta("is_ground", true)
	grid_mesh.add_child(sb)


# ──────────────────────────────────────────────────────────────────────────────
#  Навигационная область и контейнеры
# ──────────────────────────────────────────────────────────────────────────────
func _setup_nav_region() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "NavRegion"
	var nm = NavigationMesh.new()
	# Используем физические коллайдеры вместо рендер-мешей — убирает GPU→CPU readback freeze
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.cell_size = 0.10
	nm.cell_height = 0.10
	nm.agent_height = 1.95
	nm.agent_radius = 0.30
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 45.0
	nav_region.navigation_mesh = nm
	add_child(nav_region)


	objects_root = Node3D.new()
	objects_root.name = "ObjectsRoot"
	nav_region.add_child(objects_root)

	ghost_root = Node3D.new()
	ghost_root.name = "GhostRoot"
	add_child(ghost_root)

# ──────────────────────────────────────────────────────────────────────────────
#  Визуализатор выделения
# ──────────────────────────────────────────────────────────────────────────────
func _setup_selection_box() -> void:
	selection_box = MeshInstance3D.new()
	selection_box.name = "SelectionBox"
	var box = BoxMesh.new()
	selection_box.mesh = box
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.2, 0.9, 1.0, 0.40)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	box.material = mat
	selection_box.visible = false

	# Оси координат Gizmo: Красная (+X), Зеленая (+Y), Синяя (+Z / Вперед)
	var axis_x = MeshInstance3D.new()
	axis_x.name = "GizmoAxisX"
	var xm = BoxMesh.new()
	xm.size = Vector3(1.2, 0.05, 0.05)
	var xmat = StandardMaterial3D.new()
	xmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	xmat.albedo_color = Color(1.0, 0.2, 0.2)
	xm.material = xmat
	axis_x.mesh = xm
	axis_x.position = Vector3(0.6, 0, 0)
	selection_box.add_child(axis_x)

	var axis_y = MeshInstance3D.new()
	axis_y.name = "GizmoAxisY"
	var ym = BoxMesh.new()
	ym.size = Vector3(0.05, 1.2, 0.05)
	var ymat = StandardMaterial3D.new()
	ymat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ymat.albedo_color = Color(0.2, 1.0, 0.2)
	ym.material = ymat
	axis_y.mesh = ym
	axis_y.position = Vector3(0, 0.6, 0)
	selection_box.add_child(axis_y)

	var axis_z = MeshInstance3D.new()
	axis_z.name = "GizmoAxisZ"
	var zm = BoxMesh.new()
	zm.size = Vector3(0.05, 0.05, 1.2)
	var zmat = StandardMaterial3D.new()
	zmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	zmat.albedo_color = Color(0.25, 0.65, 1.0)
	zm.material = zmat
	axis_z.mesh = zm
	axis_z.position = Vector3(0, 0, 0.6)
	selection_box.add_child(axis_z)

	add_child(selection_box)

# ══════════════════════════════════════════════════════════════════════════════
#  Главный цикл обновления
# ══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	if notif_timer > 0.0:
		notif_timer -= delta
		if notif_timer <= 0.0 and notification_label:
			notification_label.visible = false

	for c in moon_clouds:
		if is_instance_valid(c):
			var spd = c.get_meta("drift_speed", 0.5)
			c.position.x += spd * delta
			if c.position.x > 80.0:
				c.position.x = -80.0

	# Купол ночных звезд следует за камерой
	if stars_node and is_instance_valid(stars_node):
		var cam = get_viewport().get_camera_3d()
		if cam and is_instance_valid(cam):
			stars_node.global_position = cam.global_position

	if preview_pivot and is_instance_valid(preview_pivot) and bottom_drawer and bottom_drawer.visible:
		preview_pivot.rotate_y(delta * 0.9)

	if current_mode == EditorMode.EDIT:
		_process_flycam(delta)
		_process_ghost_preview()
		_process_object_dragging()
		_update_selection_box()
	elif current_mode == EditorMode.PLAYTEST:
		_process_playtest_ambient(delta)

func _process_flycam(delta: float) -> void:
	if not is_rmb_down:
		return

	var move_vec = Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		move_vec -= editor_cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		move_vec += editor_cam.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		move_vec -= editor_cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		move_vec += editor_cam.global_transform.basis.x
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		move_vec += Vector3.UP
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		move_vec -= Vector3.UP

	var speed = cam_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= cam_fast_mult

	if move_vec.length_squared() > 0.001:
		cam_pivot.global_position += move_vec.normalized() * speed * delta

# ──────────────────────────────────────────────────────────────────────────────
#  Ghost-превью (следование за курсором мыши)
# ──────────────────────────────────────────────────────────────────────────────
func _process_ghost_preview() -> void:
	if ghost_node == null:
		return

	var mpos = get_viewport().get_mouse_position()

	# Режим растягивания прямоугольника пола, потолка или умного дома
	if is_box_dragging and active_prefab_id in ["floor_custom", "ceiling_custom", "roof_gable"]:
		var ground_pt = _get_ground_position(mpos)
		if grid_snap_enabled:
			ground_pt.x = round(ground_pt.x / grid_size) * grid_size
			ground_pt.z = round(ground_pt.z / grid_size) * grid_size
		else:
			ground_pt.x = snappedf(ground_pt.x, 0.05)
			ground_pt.z = snappedf(ground_pt.z, 0.05)

		var min_x = min(box_drag_start_pt.x, ground_pt.x)
		var max_x = max(box_drag_start_pt.x, ground_pt.x)
		var min_z = min(box_drag_start_pt.z, ground_pt.z)
		var max_z = max(box_drag_start_pt.z, ground_pt.z)
		var min_s = 2.0 if active_prefab_id == "roof_gable" else 1.0
		var w = max(max_x - min_x, min_s)
		var d = max(max_z - min_z, min_s)
		var cx = (min_x + max_x) * 0.5
		var cz = (min_z + max_z) * 0.5
		var y_pos = 0.15
		var h = 0.3
		if active_prefab_id == "ceiling_custom":
			y_pos = 3.6
			h = 0.3
		elif active_prefab_id == "roof_gable":
			y_pos = 3.6
			h = 2.4

		dynamic_box_pos = Vector3(cx, y_pos, cz)
		dynamic_box_size = Vector3(w, h, d)

		ghost_node.position = dynamic_box_pos
		var def_sz: Vector3 = ghost_node.get_meta("prefab_size", Vector3(4.0, 0.3, 4.0))
		ghost_node.scale = Vector3(w / max(def_sz.x, 0.1), h / max(def_sz.y, 0.1), d / max(def_sz.z, 0.1))
		ghost_node.rotation_degrees = Vector3.ZERO
		return

	var sz: Vector3 = ghost_node.get_meta("prefab_size", Vector3.ONE)
	var is_wall_mounted = ("painting" in active_prefab_id or "light_wall" in active_prefab_id or "torch" in active_prefab_id or "wall_clock" in active_prefab_id or active_prefab_id == "prop_cupboard")

	var ghost_p_type = PREFABS[active_prefab_id].get("type", active_prefab_id) if PREFABS.has(active_prefab_id) else active_prefab_id
	var s_info = _get_surface_placement_info(mpos, sz, is_wall_mounted, ghost_node, ghost_p_type)
	var target_pos = s_info.position

	if active_prefab_id == "ceiling_custom":
		target_pos.y = 3.6
	elif active_prefab_id == "roof_gable":
		target_pos.y = 3.6

	ghost_node.position = target_pos
	if _is_primitive_box_type(ghost_p_type):
		ghost_node.scale = Vector3.ONE
	else:
		var base_sz = PrefabBuilder.get_prefab_base_size(ghost_p_type)
		if base_sz.x > 0.01 and base_sz.y > 0.01 and base_sz.z > 0.01:
			ghost_node.scale = Vector3(sz.x / base_sz.x, sz.y / base_sz.y, sz.z / base_sz.z)
		else:
			ghost_node.scale = Vector3.ONE
	ghost_node.rotation_degrees = Vector3(ghost_pitch, ghost_yaw, ghost_roll)

# ──────────────────────────────────────────────────────────────────────────────
#  Перемещение выбранного объекта
# ──────────────────────────────────────────────────────────────────────────────
func _process_object_dragging() -> void:
	if selected_node == null or not is_instance_valid(selected_node):
		is_grabbing_selected = false
		is_mouse_dragging = false
		return

	if not (is_grabbing_selected or is_mouse_dragging):
		return

	if selected_node.get_meta("is_locked", false):
		is_grabbing_selected = false
		is_mouse_dragging = false
		return

	var mpos = get_viewport().get_mouse_position()

	# Режим 3D-захвата [3] или дублирования: автоматическая привязка к поверхности под курсором
	if is_grabbing_selected:
		var sz: Vector3 = selected_node.get_meta("obj_scale", Vector3.ONE)
		var p_type = str(selected_node.get_meta("obj_type", ""))
		var is_wall_mounted = ("painting" in p_type or "light_wall" in p_type or "torch" in p_type or "wall_clock" in p_type or p_type == "prop_cupboard")
		var s_info = _get_surface_placement_info(mpos, sz, is_wall_mounted, selected_node, p_type)
		if s_info.valid:
			selected_node.position = s_info.position
			_update_selection_box()
			_update_inspector()
		return

	var hit = _project_mouse_to_plane(mpos, drag_elevation)
	if hit == null:
		return

	var target_pos = hit + drag_ground_offset

	# Защита от резкого рывка: не более 30м за один кадр
	var delta_xz = Vector2(target_pos.x - drag_last_valid_pos.x, target_pos.z - drag_last_valid_pos.z)
	if delta_xz.length() > 30.0:
		delta_xz = delta_xz.normalized() * 30.0
		target_pos.x = drag_last_valid_pos.x + delta_xz.x
		target_pos.z = drag_last_valid_pos.z + delta_xz.y

	drag_last_valid_pos = target_pos

	# Сетка: Snap 1м (или Shift = 0.1м точный шаг), Alt = полностью свободное плавное перемещение
	if grid_snap_enabled and not Input.is_key_pressed(KEY_ALT):
		var step = 0.1 if Input.is_key_pressed(KEY_SHIFT) else grid_size
		target_pos.x = round(target_pos.x / step) * step
		target_pos.z = round(target_pos.z / step) * step
	else:
		target_pos.x = snappedf(target_pos.x, 0.01)
		target_pos.z = snappedf(target_pos.z, 0.01)

	selected_node.position.x = target_pos.x
	selected_node.position.z = target_pos.z
	_update_selection_box()
	_update_inspector()

func _update_selection_box() -> void:
	if selected_node == null or not is_instance_valid(selected_node):
		selection_box.visible = false
		return

	selection_box.visible = true
	var sz: Vector3 = selected_node.get_meta("obj_scale", Vector3.ONE)
	var box_mesh: BoxMesh = selection_box.mesh as BoxMesh
	if box_mesh:
		box_mesh.size = sz + Vector3(0.08, 0.08, 0.08)
		var mat = box_mesh.surface_get_material(0) as StandardMaterial3D
		if mat:
			var is_locked = bool(selected_node.get_meta("is_locked", false))
			if is_locked:
				mat.albedo_color = Color(1.0, 0.25, 0.25, 0.45)
			else:
				mat.albedo_color = Color(0.2, 0.9, 1.0, 0.40)

	# Динамически масштабируем оси Gizmo под размер объекта
	var x_node = selection_box.get_node_or_null("GizmoAxisX") as MeshInstance3D
	var y_node = selection_box.get_node_or_null("GizmoAxisY") as MeshInstance3D
	var z_node = selection_box.get_node_or_null("GizmoAxisZ") as MeshInstance3D
	var axis_len = max(1.2, max(sz.x, max(sz.y, sz.z)) * 0.75)
	if x_node:
		var xm = x_node.mesh as BoxMesh
		if xm: xm.size = Vector3(axis_len, 0.05, 0.05)
		x_node.position = Vector3(axis_len * 0.5, 0, 0)
	if y_node:
		var ym = y_node.mesh as BoxMesh
		if ym: ym.size = Vector3(0.05, axis_len, 0.05)
		y_node.position = Vector3(0, axis_len * 0.5, 0)
	if z_node:
		var zm = z_node.mesh as BoxMesh
		if zm: zm.size = Vector3(0.05, 0.05, axis_len)
		z_node.position = Vector3(0, 0, axis_len * 0.5)

	var o_type = str(selected_node.get_meta("obj_type", ""))
	var center_offset = Vector3.ZERO
	if not _is_centered_origin_type(o_type):
		if selected_node.is_inside_tree():
			center_offset = selected_node.global_transform.basis.y * (sz.y * 0.5)
		else:
			center_offset = selected_node.transform.basis.y * (sz.y * 0.5)
	if selected_node.is_inside_tree():
		selection_box.global_position = selected_node.global_position + center_offset
		selection_box.global_rotation = selected_node.global_rotation
	else:
		selection_box.position = selected_node.position + center_offset
		selection_box.rotation = selected_node.rotation

# ══════════════════════════════════════════════════════════════════════════════
#  Система отмены и повтора (Undo / Redo)
# ══════════════════════════════════════════════════════════════════════════════
func _capture_scene_state() -> Array:
	var state_data: Array = []
	if not objects_root:
		return state_data
	for child in objects_root.get_children():
		if child is Node3D and child.has_meta("obj_type") and is_instance_valid(child) and not child.is_queued_for_deletion():
			state_data.append(_serialize_single_object(child))
	return state_data

func _record_undo() -> void:
	var current_snap = _capture_scene_state()
	undo_stack.append(current_snap)
	if undo_stack.size() > MAX_UNDO_STEPS:
		undo_stack.pop_front()
	redo_stack.clear()
	_update_undo_redo_buttons()

func _undo() -> void:
	if undo_stack.is_empty():
		show_notification("Нечего отменять [↩]")
		return
	var current_snap = _capture_scene_state()
	redo_stack.append(current_snap)
	var prev_state = undo_stack.pop_back()
	_restore_scene_state(prev_state)
	_update_undo_redo_buttons()
	show_notification("↩ Отмена действия [Ctrl+Z]")

func _redo() -> void:
	if redo_stack.is_empty():
		show_notification("Нечего повторять [↪]")
		return
	var current_snap = _capture_scene_state()
	undo_stack.append(current_snap)
	var next_state = redo_stack.pop_back()
	_restore_scene_state(next_state)
	_update_undo_redo_buttons()
	show_notification("↪ Повтор действия [Ctrl+Y]")

func _restore_scene_state(state_data: Array) -> void:
	_deselect_object()
	cancel_placement()
	for child in objects_root.get_children():
		objects_root.remove_child(child)
		child.queue_free()

	var max_id = 100
	for item in state_data:
		var cur_id = int(item.get("id", 0))
		if cur_id > max_id:
			max_id = cur_id
		_instantiate_object_from_data(item)
	next_obj_id = max_id + 1

func _update_undo_redo_buttons() -> void:
	if btn_undo:
		btn_undo.disabled = undo_stack.is_empty()
		btn_undo.modulate = Color(1, 1, 1, 1.0) if not undo_stack.is_empty() else Color(1, 1, 1, 0.4)
	if btn_redo:
		btn_redo.disabled = redo_stack.is_empty()
		btn_redo.modulate = Color(1, 1, 1, 1.0) if not redo_stack.is_empty() else Color(1, 1, 1, 0.4)

# ══════════════════════════════════════════════════════════════════════════════
#  Обработка ввода (Хоткеи 1, 2, 3, 7, Tab, Undo/Redo и др.)
# ══════════════════════════════════════════════════════════════════════════════
func _unhandled_input(event: InputEvent) -> void:
	if active_modal:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_active_modal()
			get_viewport().set_input_as_handled()
			return

	# [7] — Переключение между Редактором и Игрой (Полигон)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_7:
		toggle_editor_playtest()
		get_viewport().set_input_as_handled()
		return

	# [F4] — Переключение освещения (Fullbright: отключить тьму / всё видно)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F4:
		toggle_fullbright()
		get_viewport().set_input_as_handled()
		return

	if current_mode == EditorMode.PLAYTEST:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_R:
				restart_playtest()
				get_viewport().set_input_as_handled()
				return
			elif event.keycode == KEY_ESCAPE:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	# [Home] — Вернуть камеру в исходное положение
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_HOME:
		reset_editor_camera_to_initial()
		get_viewport().set_input_as_handled()
		return

	# [Ctrl+S] — Сохранить карту (быстрое сохранение в текущий файл, либо Save As при Shift)
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_S:
		if event.shift_pressed:
			_open_save_modal()
		else:
			quick_save_map()
		get_viewport().set_input_as_handled()
		return

	# [Ctrl+Z] — Undo (Отмена)
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_Z and not event.shift_pressed:
		_undo()
		get_viewport().set_input_as_handled()
		return

	# [Ctrl+Y] или [Ctrl+Shift+Z] — Redo (Повтор)
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and (event.keycode == KEY_Y or (event.shift_pressed and event.keycode == KEY_Z)):
		_redo()
		get_viewport().set_input_as_handled()
		return

	# [Ctrl+D] — Быстрое дублирование выбранного объекта
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_D:
		if selected_node and is_instance_valid(selected_node):
			_duplicate_selected()
			show_notification("Копия создана [Ctrl+D]! Перемещайте мышью.")
			get_viewport().set_input_as_handled()
			return

	# [1] — СТАВИТЬ (Place)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1:
		_action_hotkey_1()
		get_viewport().set_input_as_handled()
		return

	# [2] / [Delete] / [Backspace] — УДАЛИТЬ (Delete)
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_2 or event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE):
		_action_hotkey_2()
		get_viewport().set_input_as_handled()
		return

	# [3] — ПОСТАВИЛ И ВЫБРАЛ / ПЕРЕМЕЩАТЬ
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_3:
		_action_hotkey_3()
		get_viewport().set_input_as_handled()
		return

	# [TAB] — Открыть/закрыть каталог объектов
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle_bottom_drawer()
		get_viewport().set_input_as_handled()
		return

	# [G] — Переключить режим: Сеточный / Свободный
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_toggle_grid_mode()
		get_viewport().set_input_as_handled()
		return

	# [H] / [F1] — Справочник горячих клавиш и помощи
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_H or event.keycode == KEY_F1):
		_toggle_help_modal()
		get_viewport().set_input_as_handled()
		return

	# [End] — Опустить выбранный объект на пол
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_END:
		if selected_node:
			_drop_selected_to_floor()
			get_viewport().set_input_as_handled()
			return

	# [PageUp / PageDown] — Поднять / Опустить по высоте Y
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_PAGEUP:
			_change_selected_height(0.5 if not event.shift_pressed else 0.1)
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_PAGEDOWN:
			_change_selected_height(-0.5 if not event.shift_pressed else -0.1)
			get_viewport().set_input_as_handled()
			return

	# [ [ / ] ] или [+ / -] — Быстро изменить размер выбранного объекта
	if event is InputEventKey and event.pressed and not event.echo and selected_node and is_instance_valid(selected_node):
		if event.keycode == KEY_BRACKETLEFT or (event.keycode == KEY_MINUS and not event.ctrl_pressed):
			var step = 0.05 if event.shift_pressed else 0.2
			_resize_selected(Vector3(-step, -step, -step))
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_BRACKETRIGHT or (event.keycode == KEY_EQUAL and not event.ctrl_pressed):
			var step = 0.05 if event.shift_pressed else 0.2
			_resize_selected(Vector3(step, step, step))
			get_viewport().set_input_as_handled()
			return

	# [R] / [Q] — Вращение на 360° (R - вправо, Q - влево; Shift - шаг 15° вместо 45°)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			var step = 15.0 if event.shift_pressed else 45.0
			if ghost_node:
				ghost_yaw = fposmod(ghost_yaw + step, 360.0)
			elif selected_node:
				_rotate_selected(Vector3(0, step, 0))
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_Q and not is_rmb_down:
			var step = -15.0 if event.shift_pressed else -45.0
			if ghost_node:
				ghost_yaw = fposmod(ghost_yaw + step, 360.0)
			elif selected_node:
				_rotate_selected(Vector3(0, step, 0))
			get_viewport().set_input_as_handled()
			return

	# [F] — Сфокусировать камеру на выбранном объекте (или разворот призрака на 180°)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if selected_node and is_instance_valid(selected_node):
			_focus_camera_on_selected()
			get_viewport().set_input_as_handled()
			return
		elif ghost_node:
			ghost_yaw = fposmod(ghost_yaw + 180.0, 360.0)
			show_notification("Разворот 180° [F]")
			get_viewport().set_input_as_handled()
			return

	# [T] — Наклон по оси X (Pitch: вперед/назад, Shift: в обратную сторону)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		var step = -15.0 if event.shift_pressed else 15.0
		if ghost_node:
			ghost_pitch = fposmod(ghost_pitch + step, 360.0)
		elif selected_node:
			_rotate_selected(Vector3(step, 0, 0))
		show_notification("Наклон X (Pitch): %+.0f° [T]" % step)
		get_viewport().set_input_as_handled()
		return

	# [Y] — Крен по оси Z (Roll: влево/вправо, Shift: в обратную сторону)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y and not event.ctrl_pressed:
		var step = -15.0 if event.shift_pressed else 15.0
		if ghost_node:
			ghost_roll = fposmod(ghost_roll + step, 360.0)
		elif selected_node:
			_rotate_selected(Vector3(0, 0, step))
		show_notification("Крен Z (Roll): %+.0f° [Y]" % step)
		get_viewport().set_input_as_handled()
		return

	# [Стрелки] — Перемещение выбранного объекта по X / Z (Shift: точный шаг 0.1м)
	if event is InputEventKey and event.pressed and not event.echo and not is_rmb_down and selected_node:
		var n_step = 0.1 if event.shift_pressed else 0.5
		if event.keycode == KEY_UP:
			_nudge_selected_pos(Vector3(0, 0, -n_step))
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_DOWN:
			_nudge_selected_pos(Vector3(0, 0, n_step))
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_LEFT:
			_nudge_selected_pos(Vector3(-n_step, 0, 0))
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_RIGHT:
			_nudge_selected_pos(Vector3(n_step, 0, 0))
			get_viewport().set_input_as_handled()
			return

	# [Ctrl+D] — Дублировать объект
	if event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_D:
		if selected_node and not is_grabbing_selected:
			_duplicate_selected()
			get_viewport().set_input_as_handled()
			return

	# [Delete / Backspace] — Удалить
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
		_action_hotkey_2()
		get_viewport().set_input_as_handled()
		return

	# [Escape] — Отмена установки или захвата
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_grabbing_selected:
			selected_node.global_transform = grab_orig_transform
			is_grabbing_selected = false
			show_notification("Перемещение отменено")
			get_viewport().set_input_as_handled()
			return
		if ghost_node:
			cancel_placement()
			get_viewport().set_input_as_handled()
			return

	# Мышь: ПКМ (Полет камеры FlyCam)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if is_grabbing_selected:
				selected_node.global_transform = grab_orig_transform
				is_grabbing_selected = false
				show_notification("Перемещение отменено")
				get_viewport().set_input_as_handled()
				return
			if ghost_node:
				cancel_placement()
				get_viewport().set_input_as_handled()
				return

			is_rmb_down = event.pressed
			if is_rmb_down:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			get_viewport().set_input_as_handled()
			return

		# Колесико мыши: Вращение объекта на 360°
		# Обычное: Поворот Y (Yaw) | Alt: Наклон X (Pitch) | Ctrl: Крен Z (Roll) | Shift: шаг 5° вместо 15°
		if event.pressed and not is_rmb_down:
			var wheel_step: float = 5.0 if event.shift_pressed else 15.0
			var rot_axis: Vector3 = Vector3(0, 1, 0)
			if (is_grabbing_selected or is_mouse_dragging) and selected_node and is_instance_valid(selected_node):
				var dy = (0.10 if not event.shift_pressed else 0.02) * (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
				selected_node.position.y = snappedf(selected_node.position.y + dy, 0.01)
				drag_elevation = selected_node.position.y
				_update_inspector()
				_update_selection_box()
				show_notification("Высота: Y = %.2fм (Колесо мыши)" % selected_node.position.y)
				get_viewport().set_input_as_handled()
				return

			if event.alt_pressed:
				rot_axis = Vector3(1, 0, 0)
			elif event.ctrl_pressed:
				rot_axis = Vector3(0, 0, 1)

			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				if ghost_node:
					if event.alt_pressed:
						ghost_pitch = fposmod(ghost_pitch + wheel_step, 360.0)
					elif event.ctrl_pressed:
						ghost_roll = fposmod(ghost_roll + wheel_step, 360.0)
					else:
						ghost_yaw = fposmod(ghost_yaw + wheel_step, 360.0)
					get_viewport().set_input_as_handled()
					return
				elif selected_node:
					_rotate_selected(rot_axis * wheel_step)
					get_viewport().set_input_as_handled()
					return
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				if ghost_node:
					if event.alt_pressed:
						ghost_pitch = fposmod(ghost_pitch - wheel_step, 360.0)
					elif event.ctrl_pressed:
						ghost_roll = fposmod(ghost_roll - wheel_step, 360.0)
					else:
						ghost_yaw = fposmod(ghost_yaw - wheel_step, 360.0)
					get_viewport().set_input_as_handled()
					return
				elif selected_node:
					_rotate_selected(rot_axis * -wheel_step)
					get_viewport().set_input_as_handled()
					return

		# ЛКМ: Выбор, установка или перетаскивание (без мгновенного прыжка)
		if event.button_index == MOUSE_BUTTON_LEFT and not is_rmb_down:
			if event.pressed:
				mouse_press_pos = event.position
				if not _is_mouse_over_ui():
					if ghost_node:
						if active_prefab_id in ["floor_custom", "ceiling_custom", "roof_gable"]:
							var ground_pt = _get_ground_position(event.position)
							if grid_snap_enabled:
								ground_pt.x = round(ground_pt.x / grid_size) * grid_size
								ground_pt.z = round(ground_pt.z / grid_size) * grid_size
							box_drag_start_pt = ground_pt
							is_box_dragging = true
							show_notification("Тяните мышь для размера. Отпустите ЛКМ для завершения!")
						else:
							_place_ghost_object(false)
					elif is_grabbing_selected:
						is_grabbing_selected = false
						show_notification("Позиция зафиксирована")
					else:
						var picked = _pick_object_at_mouse()
						if picked:
							_select_object(picked)
							# Не прыгать сразу: запомнить начальную точку клика и смещение на плоскости высоты объекта
							pending_mouse_drag = true
							mouse_drag_start_screen = event.position
							drag_elevation = picked.position.y
							var hit = _project_mouse_to_plane(event.position, drag_elevation)
							if hit != null:
								drag_ground_offset = picked.position - hit
							else:
								drag_ground_offset = Vector3.ZERO
							drag_last_valid_pos = picked.position
						else:
							_deselect_object()
					get_viewport().set_input_as_handled()
					return
			else:
				pending_mouse_drag = false
				if is_box_dragging:
					is_box_dragging = false
					if ghost_node:
						_place_box_drag_object(false)
					get_viewport().set_input_as_handled()
					return
				if is_mouse_dragging:
					is_mouse_dragging = false
					get_viewport().set_input_as_handled()
					return

	# Движение мыши
	if event is InputEventMouseMotion:
		if is_rmb_down:
			cam_yaw -= event.relative.x * 0.22
			cam_pitch -= event.relative.y * 0.22
			cam_pitch = clamp(cam_pitch, -89.0, 89.0)
			_update_cam_rotation()
			get_viewport().set_input_as_handled()
			return
		elif pending_mouse_drag and selected_node and is_instance_valid(selected_node):
			# Активировать перетаскивание только если мышь сдвинулась более чем на 8 пикселей
			if event.position.distance_to(mouse_drag_start_screen) > 8.0:
				if not selected_node.get_meta("is_locked", false):
					is_mouse_dragging = true
					_record_undo()
				pending_mouse_drag = false

# ──────────────────────────────────────────────────────────────────────────────
#  Действия хоткеев 1, 2, 3
# ──────────────────────────────────────────────────────────────────────────────
func _action_hotkey_1() -> void:
	if ghost_node:
		if is_box_dragging or active_prefab_id in ["floor_custom", "ceiling_custom", "roof_gable"]:
			is_box_dragging = false
			_place_box_drag_object(false)
		else:
			_place_ghost_object(false)
	elif is_grabbing_selected:
		is_grabbing_selected = false
		show_notification("Позиция зафиксирована [1]")
	elif selected_node:
		_duplicate_selected()
		show_notification("Создана копия [1]")
	else:
		_toggle_bottom_drawer()
		show_notification("Выберите объект из каталога [Tab]")

func _action_hotkey_2() -> void:
	if ghost_node:
		cancel_placement()
		show_notification("Размещение отменено [2]")
	elif selected_node:
		_delete_selected()
	else:
		var hover = _pick_object_at_mouse()
		if hover:
			_select_object(hover)
			_delete_selected()
		else:
			show_notification("Нет объекта для удаления [2]")

func _action_hotkey_3() -> void:
	if ghost_node:
		if is_box_dragging or active_prefab_id in ["floor_custom", "ceiling_custom", "roof_gable"]:
			is_box_dragging = false
			var placed_box = _place_box_drag_object(true)
			if placed_box:
				show_notification("Поставлен и выбран [3]! Вращайте [R/Q] или изменяйте размер")
		else:
			var placed = _place_ghost_object(true)
			if placed:
				_select_object(placed)
				show_notification("Поставлен и выбран [3]! Вращайте [R/Q], опустите [End] или удалите [2]")
	elif selected_node:
		if selected_node.get_meta("is_locked", false):
			show_notification("🔒 Объект зафиксирован! Снимите фиксацию в Инспекторе.")
			return
		is_grabbing_selected = not is_grabbing_selected
		if is_grabbing_selected:
			_record_undo()
			grab_orig_transform = selected_node.global_transform
			drag_elevation = selected_node.position.y
			var hit = _project_mouse_to_plane(get_viewport().get_mouse_position(), drag_elevation)
			if hit != null:
				drag_ground_offset = selected_node.position - hit
			else:
				drag_ground_offset = Vector3.ZERO
			drag_last_valid_pos = selected_node.position
			show_notification("Перемещение [3]: двигайте мышь, [1/ЛКМ/3] - зафиксировать")
		else:
			show_notification("Позиция зафиксирована [3]")
	else:
		var hover = _pick_object_at_mouse()
		if hover:
			_select_object(hover)
			if not hover.get_meta("is_locked", false):
				is_grabbing_selected = true
				_record_undo()
				grab_orig_transform = hover.global_transform
				drag_elevation = hover.position.y
				var hit = _project_mouse_to_plane(get_viewport().get_mouse_position(), drag_elevation)
				if hit != null:
					drag_ground_offset = hover.position - hit
				else:
					drag_ground_offset = Vector3.ZERO
				drag_last_valid_pos = hover.position
				show_notification("Объект взят [3]! Двигайте мышь, [1/ЛКМ/3] - зафиксировать")
			else:
				show_notification("Объект выбран [3] (🔒 зафиксирован)")
		else:
			show_notification("Наведите на объект или выберите из каталога [Tab]")

func _toggle_grid_mode() -> void:
	grid_snap_enabled = not grid_snap_enabled
	_update_grid_button_ui()
	show_notification("Режим: " + ("📐 СЕТКА (Snap 1м)" if grid_snap_enabled else "🕊 СВОБОДНЫЙ (Free)"))

func _update_grid_button_ui() -> void:
	if not btn_grid_mode:
		return
	if grid_snap_enabled:
		btn_grid_mode.text = "📐 СЕТКА (1м) [G]"
		var sn = StyleBoxFlat.new()
		sn.bg_color = Color(0.12, 0.45, 0.65)
		sn.corner_radius_top_left = 4
		sn.corner_radius_top_right = 4
		sn.corner_radius_bottom_left = 4
		sn.corner_radius_bottom_right = 4
		btn_grid_mode.add_theme_stylebox_override("normal", sn)
	else:
		btn_grid_mode.text = "🕊 СВОБОДНЫЙ [G]"
		var sf = StyleBoxFlat.new()
		sf.bg_color = Color(0.48, 0.22, 0.60)
		sf.corner_radius_top_left = 4
		sf.corner_radius_top_right = 4
		sf.corner_radius_bottom_left = 4
		sf.corner_radius_bottom_right = 4
		btn_grid_mode.add_theme_stylebox_override("normal", sf)

func _is_mouse_over_ui() -> bool:
	var mpos = get_viewport().get_mouse_position()
	if top_bar and top_bar.visible and top_bar.get_global_rect().has_point(mpos):
		return true
	if bottom_drawer and bottom_drawer.visible and bottom_drawer.get_global_rect().has_point(mpos):
		return true
	if inspector_panel and inspector_panel.visible and inspector_panel.get_global_rect().has_point(mpos):
		return true
	return false

# ──────────────────────────────────────────────────────────────────────────────
#  Рейкаст для определения координат на плоскости высоты и 3D-поверхностях
# ──────────────────────────────────────────────────────────────────────────────
func _gather_collision_rids(node: Node, out_rids: Array[RID]) -> void:
	if not node or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		out_rids.append(node.get_rid())
	for child in node.get_children():
		_gather_collision_rids(child, out_rids)

func _is_centered_origin_type(t: String) -> bool:
	if t == "cube" or t == "floor_custom" or t == "ceiling_custom" or t == "roof_gable":
		return true
	if t.begins_with("wall") and not t.begins_with("wall_lamp") and not t.begins_with("wall_clock"):
		return true
	if t == "column" or t == "block_cube_1m" or t == "block_column_cyl" or t == "block_beam" or t == "floor_slab" or t == "cover_box":
		return true
	return false

func _is_primitive_box_type(t: String) -> bool:
	if t == "cube" or t == "floor_custom" or t == "ceiling_custom" or t == "roof_gable":
		return true
	if t.begins_with("wall") and not t.begins_with("wall_lamp") and not t.begins_with("wall_clock"):
		return true
	if t == "column" or t == "block_cube_1m" or t == "floor_slab" or t == "cover_box":
		return true
	return false

func _update_box_mesh_size(node: Node, new_sz: Vector3) -> void:
	if node is MeshInstance3D and node.mesh is BoxMesh:
		var bm = node.mesh.duplicate() as BoxMesh
		bm.size = new_sz
		node.mesh = bm
	elif node is CollisionShape3D and node.shape is BoxShape3D:
		var bs = node.shape.duplicate() as BoxShape3D
		bs.size = new_sz
		node.shape = bs
	for child in node.get_children():
		_update_box_mesh_size(child, new_sz)

func _get_surface_placement_info(screen_pos: Vector2, obj_size: Vector3, is_wall_mounted: bool = false, exclude_node: Node3D = null, obj_type: String = "") -> Dictionary:
	if not editor_cam or not is_instance_valid(editor_cam):
		return {"valid": false, "position": Vector3.ZERO, "normal": Vector3.UP, "is_surface": false}

	if obj_type == "":
		if exclude_node and exclude_node.has_meta("obj_type"):
			obj_type = str(exclude_node.get_meta("obj_type", ""))
		elif active_prefab_id != "" and PREFABS.has(active_prefab_id):
			obj_type = str(PREFABS[active_prefab_id].get("type", active_prefab_id))

	var y_offset: float = (obj_size.y * 0.5) if _is_centered_origin_type(obj_type) else 0.0

	var ray_origin = editor_cam.project_ray_origin(screen_pos)
	var ray_dir = editor_cam.project_ray_normal(screen_pos)
	var space_state = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 500.0)
	query.collision_mask = 1 | 2
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var excludes: Array[RID] = []
	if ghost_node:
		_gather_collision_rids(ghost_node, excludes)
	if selection_box:
		_gather_collision_rids(selection_box, excludes)
	if exclude_node:
		_gather_collision_rids(exclude_node, excludes)
	query.exclude = excludes

	var hit = space_state.intersect_ray(query)

	if hit.is_empty():
		var fallback = _project_mouse_to_plane(screen_pos, 0.0)
		var pos = fallback if fallback != null else editor_cam.global_position + (-editor_cam.global_transform.basis.z * 10.0)
		if grid_snap_enabled:
			pos.x = round(pos.x / grid_size) * grid_size
			pos.z = round(pos.z / grid_size) * grid_size
		else:
			pos.x = snappedf(pos.x, 0.05)
			pos.z = snappedf(pos.z, 0.05)
		pos.y = y_offset
		return {"valid": true, "position": pos, "normal": Vector3.UP, "is_surface": false}

	var hit_pos: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal

	# 1. Горизонтальная или покатая поверхность (пол, столешница, крышка тумбочки, полка, земля)
	if hit_normal.y > 0.35:
		var snap_x = hit_pos.x
		var snap_z = hit_pos.z
		var surface_y = hit_pos.y

		if grid_snap_enabled:
			snap_x = round(hit_pos.x / grid_size) * grid_size
			snap_z = round(hit_pos.z / grid_size) * grid_size
			var probe_origin = Vector3(snap_x, hit_pos.y + 0.6, snap_z)
			var probe_q = PhysicsRayQueryParameters3D.create(probe_origin, probe_origin + Vector3.DOWN * 2.5)
			probe_q.collision_mask = 1 | 2
			probe_q.exclude = excludes
			var probe_hit = space_state.intersect_ray(probe_q)
			if not probe_hit.is_empty() and probe_hit.normal.y > 0.35:
				surface_y = probe_hit.position.y
		else:
			snap_x = snappedf(hit_pos.x, 0.02)
			snap_z = snappedf(hit_pos.z, 0.02)

		var target_pos = Vector3(snap_x, surface_y + y_offset, snap_z)
		return {"valid": true, "position": target_pos, "normal": hit_normal, "is_surface": true}

	# 2. Вертикальная поверхность (стена)
	elif abs(hit_normal.y) <= 0.35:
		if is_wall_mounted:
			var target_pos = hit_pos + hit_normal * (obj_size.z * 0.5 + 0.02)
			return {"valid": true, "position": target_pos, "normal": hit_normal, "is_surface": true}
		else:
			var floor_probe = hit_pos + hit_normal * (max(obj_size.x, obj_size.z) * 0.5 + 0.08)
			var floor_q = PhysicsRayQueryParameters3D.create(floor_probe + Vector3.UP * 0.5, floor_probe + Vector3.DOWN * 50.0)
			floor_q.collision_mask = 1 | 2
			floor_q.exclude = excludes
			var floor_hit = space_state.intersect_ray(floor_q)
			var floor_y = 0.0
			if not floor_hit.is_empty():
				floor_y = floor_hit.position.y
			var target_pos = Vector3(floor_probe.x, floor_y + y_offset, floor_probe.z)
			if grid_snap_enabled:
				target_pos.x = round(target_pos.x / grid_size) * grid_size
				target_pos.z = round(target_pos.z / grid_size) * grid_size
			return {"valid": true, "position": target_pos, "normal": hit_normal, "is_surface": true}

	# 3. Наклонная вниз или потолочная поверхность
	else:
		var target_pos = hit_pos + hit_normal * (y_offset if y_offset > 0.01 else 0.02)
		return {"valid": true, "position": target_pos, "normal": hit_normal, "is_surface": true}

func _project_mouse_to_plane(screen_pos: Vector2, elevation_y: float = 0.0) -> Variant:
	if not editor_cam or not is_instance_valid(editor_cam):
		return null
	var ray_origin = editor_cam.project_ray_origin(screen_pos)
	var ray_dir = editor_cam.project_ray_normal(screen_pos)

	if abs(ray_dir.y) < 0.015:
		return null

	var plane = Plane(Vector3.UP, elevation_y)
	var hit = plane.intersects_ray(ray_origin, ray_dir)
	if hit != null:
		if ray_origin.distance_squared_to(hit) > 250000.0: # 500м
			return null
		return hit
	return null

func _get_ground_position(screen_pos: Vector2) -> Vector3:
	if not editor_cam or not is_instance_valid(editor_cam):
		return Vector3.ZERO
	var ray_origin = editor_cam.project_ray_origin(screen_pos)
	var ray_dir = editor_cam.project_ray_normal(screen_pos)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 500.0)
	query.collision_mask = 1 | 2
	var excludes: Array[RID] = []
	if ghost_node:
		_gather_collision_rids(ghost_node, excludes)
	if selection_box:
		_gather_collision_rids(selection_box, excludes)
	query.exclude = excludes
	var hit = space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position

	var p_hit = _project_mouse_to_plane(screen_pos, 0.0)
	if p_hit != null:
		return p_hit
	var fwd = -editor_cam.global_transform.basis.z
	var approx = editor_cam.global_position + fwd * 15.0
	approx.y = 0.0
	return approx

# ──────────────────────────────────────────────────────────────────────────────
#  Выбор объекта под курсором — Слой 1 (ТОЛЬКО объекты)
# ──────────────────────────────────────────────────────────────────────────────
func _pick_object_at_mouse() -> Node3D:
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = editor_cam.project_ray_origin(mouse_pos)
	var ray_dir = editor_cam.project_ray_normal(mouse_pos)

	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_dir * 300.0)
	query.collision_mask = 1
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result = space_state.intersect_ray(query)

	if result and result.collider:
		var col_node: Node = result.collider
		var target: Node = col_node
		while target and target.get_parent() != objects_root:
			target = target.get_parent()

		if target and target.get_parent() == objects_root:
			return target as Node3D

	return null

func _select_object(node: Node3D) -> void:
	if not node or not is_instance_valid(node):
		_deselect_object()
		return
	selected_node = node
	_update_inspector()
	show_notification("Взят: " + str(node.get_meta("obj_name", "Объект")) + " [1 - ставить, 2 - удалить, 3 - двигать]")

func _deselect_object() -> void:
	selected_node = null
	is_grabbing_selected = false
	is_mouse_dragging = false
	if inspector_panel:
		inspector_panel.visible = false
	if selection_box:
		selection_box.visible = false

# ══════════════════════════════════════════════════════════════════════════════
#  Манипуляции объектами (Вращение, Опускание на пол, Дублирование, Удаление)
# ══════════════════════════════════════════════════════════════════════════════
func _rotate_selected(rot_delta: Vector3) -> void:
	if not selected_node:
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован! Вращение заблокировано.")
		return
	_record_undo()
	var cur_rot = selected_node.rotation_degrees
	var new_rot = cur_rot + rot_delta
	new_rot.x = fposmod(new_rot.x, 360.0)
	new_rot.y = fposmod(new_rot.y, 360.0)
	new_rot.z = fposmod(new_rot.z, 360.0)
	selected_node.rotation_degrees = new_rot
	selected_node.set_meta("obj_rotation", new_rot)
	_update_inspector()

func _drop_selected_to_floor() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован! Перемещение заблокировано.")
		return
	_record_undo()
	var sz: Vector3 = selected_node.get_meta("obj_scale", Vector3.ONE)
	var obj_type = str(selected_node.get_meta("obj_type", ""))
	var y_offset = (sz.y * 0.5) if _is_centered_origin_type(obj_type) else 0.0

	var space_state = get_world_3d().direct_space_state
	var from_pt = selected_node.global_position + Vector3.UP * 0.1
	var to_pt = from_pt + Vector3.DOWN * 200.0
	var query = PhysicsRayQueryParameters3D.create(from_pt, to_pt)
	query.collision_mask = 1 | 2
	var excludes: Array[RID] = []
	_gather_collision_rids(selected_node, excludes)
	query.exclude = excludes
	var hit = space_state.intersect_ray(query)

	if not hit.is_empty():
		selected_node.position.y = hit.position.y + y_offset
	else:
		selected_node.position.y = y_offset

	_update_inspector()
	_update_selection_box()
	show_notification("⬇ Объект опущен на поверхность (Y = %.2fм)" % selected_node.position.y)

func _change_selected_height(delta_y: float) -> void:
	if not selected_node:
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован! Высота заблокирована.")
		return
	_record_undo()
	selected_node.position.y = clampf(selected_node.position.y + delta_y, -500.0, 500.0)
	_update_inspector()
	_update_selection_box()
	show_notification("Высота: Y = %.2fм" % selected_node.position.y)

func _focus_camera_on_selected() -> void:
	if not selected_node or not is_instance_valid(selected_node) or not editor_cam:
		return
	var target_pos = selected_node.global_position
	var sz: Vector3 = selected_node.get_meta("obj_scale", Vector3.ONE)
	var max_dim = max(sz.x, max(sz.y, sz.z))
	var dist = clamp(max_dim * 2.2, 3.5, 25.0)

	editor_cam.global_position = target_pos + Vector3(0, dist * 0.6, dist * 0.9)
	cam_pitch = -30.0
	cam_yaw = 0.0
	_update_cam_rotation()
	show_notification("🎯 Камера сфокусирована на объекте [F]")

func _duplicate_selected() -> void:
	if not selected_node:
		return

	_record_undo()
	var original_data = _serialize_single_object(selected_node)
	next_obj_id += 1
	original_data["id"] = next_obj_id
	original_data["name"] = str(original_data.get("name", "Объект")) + " (Копия)"
	original_data["is_locked"] = false
	var pos: Array = original_data.get("position", [0, 0, 0])
	pos[0] += 1.0
	pos[2] += 1.0
	original_data["position"] = pos

	var new_node = _instantiate_object_from_data(original_data)
	if new_node:
		_select_object(new_node)
		is_grabbing_selected = true
		grab_orig_transform = new_node.global_transform
		drag_elevation = new_node.position.y
		var hit = _project_mouse_to_plane(get_viewport().get_mouse_position(), drag_elevation)
		if hit != null:
			drag_ground_offset = new_node.position - hit
		else:
			drag_ground_offset = Vector3.ZERO
		drag_last_valid_pos = new_node.position
		show_notification("Объект скопирован [1 или ЛКМ - поставить]")

func _delete_selected() -> void:
	if not selected_node:
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован! Снимите блокировку в Инспекторе для удаления.")
		return
	_record_undo()
	var name_deleted = selected_node.get_meta("obj_name", "Объект")
	if selected_node.get_parent():
		selected_node.get_parent().remove_child(selected_node)
	selected_node.queue_free()
	_deselect_object()
	show_notification("Удалено [2]: " + str(name_deleted))

# ══════════════════════════════════════════════════════════════════════════════
#  Создание и установка объектов (Ghost Preview)
# ══════════════════════════════════════════════════════════════════════════════
func start_placing_prefab(prefab_id: String) -> void:
	if not PREFABS.has(prefab_id):
		return

	cancel_placement()
	_deselect_object()

	active_prefab_id = prefab_id
	ghost_yaw = 0.0
	ghost_pitch = 0.0
	ghost_roll = 0.0
	is_box_dragging = false
	if prefab_id == "roof_gable":
		dynamic_box_size = PREFABS["roof_gable"]["size"]
	else:
		dynamic_box_size = Vector3(4.0, 0.3, 4.0)

	var data = PREFABS[prefab_id]
	var model_path = data.get("model_path", "")
	ghost_node = _build_visual_node(data["type"], data["size"], data["color"], true, model_path)
	ghost_node.set_meta("prefab_size", data["size"])
	ghost_node.set_meta("prefab_type", data["type"])
	if model_path != "":
		ghost_node.set_meta("model_path", model_path)

	# 3D Бейдж с названием и точными габаритами для предпросмотра перед установкой
	ghost_info_badge = Label3D.new()
	ghost_info_badge.text = "%s %s\n📏 %.1fx%.1fx%.1fм\n[ЛКМ] Поставить | [R/Q] Вращение | [ПКМ] Отмена" % [
		data.get("icon", "📦"),
		data.get("name", prefab_id),
		data["size"].x, data["size"].y, data["size"].z
	]
	ghost_info_badge.font_size = 20
	ghost_info_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ghost_info_badge.modulate = Color(0.3, 0.9, 1.0)
	ghost_info_badge.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	ghost_info_badge.outline_size = 6
	ghost_info_badge.position = Vector3(0, data["size"].y + 0.35, 0)
	ghost_node.add_child(ghost_info_badge)

	# Голографический круговой проектор на земле
	ghost_ring_mesh = MeshInstance3D.new()
	var ring_torus = TorusMesh.new()
	var base_r = max(data["size"].x, data["size"].z) * 0.52
	ring_torus.inner_radius = max(0.4, base_r)
	ring_torus.outer_radius = ring_torus.inner_radius + 0.08
	ghost_ring_mesh.mesh = ring_torus
	var ring_mat = StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(0.2, 0.85, 1.0, 0.5)
	ring_torus.material = ring_mat
	ghost_ring_mesh.position = Vector3(0, 0.02, 0)
	ghost_node.add_child(ghost_ring_mesh)

	ghost_root.add_child(ghost_node)

	if prefab_id in ["floor_custom", "ceiling_custom", "roof_gable"]:
		show_notification("Установка: " + data["name"] + " (Зажмите ЛКМ и тяните размер, либо [1/3])")
	else:
		show_notification("Установка: " + data["name"] + " ([1] Поставить, [3] Поставить и выбрать, [2] Отмена)")

func cancel_placement() -> void:
	if ghost_node:
		ghost_node.queue_free()
		ghost_node = null
	ghost_info_badge = null
	ghost_ring_mesh = null
	active_prefab_id = ""
	is_box_dragging = false

func _place_ghost_object(keep_selected: bool = false) -> Node3D:
	if not ghost_node or not PREFABS.has(active_prefab_id):
		return null

	_record_undo()

	var data = PREFABS[active_prefab_id]
	next_obj_id += 1

	var obj_data = {
		"id": next_obj_id,
		"type": data["type"],
		"name": data["name"],
		"position": [ghost_node.position.x, ghost_node.position.y, ghost_node.position.z],
		"rotation": [ghost_pitch, ghost_yaw, ghost_roll],
		"scale": [data["size"].x, data["size"].y, data["size"].z],
		"color": data["color"].to_html(),
		"visible": true,
		"comment": data["comment"]
	}
	if data.has("model_path"):
		obj_data["model_path"] = data["model_path"]

	var new_obj = _instantiate_object_from_data(obj_data)
	if keep_selected:
		cancel_placement()
		_select_object(new_obj)
		show_notification("Поставлен и выбран [3]: " + data["name"])
	else:
		_select_object(new_obj)
		if not Input.is_key_pressed(KEY_SHIFT):
			cancel_placement()
		show_notification("Установлен [1]: " + data["name"])
	return new_obj

# ──────────────────────────────────────────────────────────────────────────────
#  Инстанцирование объектов на сцене
# ──────────────────────────────────────────────────────────────────────────────
func _instantiate_object_from_data(data: Dictionary) -> Node3D:
	var obj_type: String = data.get("type", "cube")
	var pa = data.get("position", [0, 1, 0])
	var ra = data.get("rotation", [0, 0, 0])
	var sa = data.get("scale", [1, 1, 1])
	var color_str: String = data.get("color", "#7d8590")
	var model_path: String = data.get("model_path", "")

	var pos = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	var rot = Vector3(float(ra[0]), float(ra[1]), float(ra[2]))
	var sz = Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
	var col = Color.html(color_str)

	var base_sz = PrefabBuilder.get_prefab_base_size(obj_type)
	if base_sz.x <= 0.01: base_sz.x = 1.0
	if base_sz.y <= 0.01: base_sz.y = 1.0
	if base_sz.z <= 0.01: base_sz.z = 1.0

	var is_prim = _is_primitive_box_type(obj_type)
	var build_sz = sz if is_prim else base_sz
	var node = _build_visual_node(obj_type, build_sz, col, false, model_path)
	node.position = pos
	node.rotation_degrees = rot

	var obj_id = int(data.get("id", 0))
	if obj_id <= 0:
		next_obj_id += 1
		obj_id = next_obj_id
	node.set_meta("obj_id", obj_id)
	node.set_meta("obj_type", obj_type)
	node.set_meta("obj_name", data.get("name", "Объект"))
	node.set_meta("obj_comment", str(data.get("comment", "")))
	node.set_meta("obj_scale", sz)
	node.set_meta("prefab_base_size", base_sz)
	node.set_meta("base_size", base_sz)

	if is_prim:
		_update_box_mesh_size(node, sz)
		node.scale = Vector3.ONE
	elif "door" in obj_type and not ("hatch" in obj_type):
		node.scale = Vector3.ONE
	else:
		node.scale = Vector3(sz.x / base_sz.x, sz.y / base_sz.y, sz.z / base_sz.z)
	node.set_meta("obj_rotation", rot)
	node.set_meta("obj_color", col)
	if data.has("is_locked"):
		node.set_meta("is_locked", bool(data["is_locked"]))
	if model_path != "":
		node.set_meta("model_path", model_path)

	# Наложение текстуры стены при наличии
	if data.has("wall_texture") and str(data["wall_texture"]) != "":
		var w_tex = str(data["wall_texture"])
		node.set_meta("wall_texture", w_tex)
		TextureHelper.apply_wall_texture_to_node(node, w_tex, col)

	# Наложение сюжета картины при наличии
	if data.has("painting_art") and str(data["painting_art"]) != "":
		var p_art = str(data["painting_art"])
		node.set_meta("painting_art", p_art)
		TextureHelper.apply_painting_art_to_node(node, p_art)
	elif "painting" in obj_type:
		var default_art = "portrait"
		if "landscape" in obj_type: default_art = "landscape"
		elif "moon" in obj_type: default_art = "moon"
		elif "skinwalker" in obj_type: default_art = "skinwalker"
		elif "entity" in obj_type: default_art = "entity"
		elif "vintage" in obj_type: default_art = "vintage"
		node.set_meta("painting_art", default_art)
		TextureHelper.apply_painting_art_to_node(node, default_art)

	# Наложение рисунка дерева при наличии
	if data.has("tree_drawing") and str(data["tree_drawing"]) != "":
		var t_draw = str(data["tree_drawing"])
		node.set_meta("tree_drawing", t_draw)
		TextureHelper.apply_tree_drawing_to_node(node, t_draw)
	elif "tree_carved" in obj_type or "tree_warning" in obj_type or "tree_claws" in obj_type:
		var default_td = "skinwalker"
		if "warning" in obj_type: default_td = "warning"
		elif "claws" in obj_type: default_td = "claws"
		node.set_meta("tree_drawing", default_td)
		TextureHelper.apply_tree_drawing_to_node(node, default_td)

	# Настройки двери, ключей и выключателей
	if data.has("door_texture") and str(data["door_texture"]) != "":
		var d_tex = str(data["door_texture"])
		node.set_meta("door_texture", d_tex)
		TextureHelper.apply_door_texture_to_node(node, d_tex)

	var pnl = node.find_child("Panel", true, false)
	if data.has("key_color"):
		var kc = str(data["key_color"])
		node.set_meta("key_color", kc)
		node.set("required_key_color", kc)
		if pnl:
			pnl.set_meta("key_color", kc)
			pnl.set("required_key_color", kc)

	if data.has("requires_power"):
		var req_pwr = bool(data["requires_power"])
		node.set_meta("requires_power", req_pwr)
		node.set("requires_power", req_pwr)
		node.set("has_electric_meter", req_pwr)
		if pnl:
			pnl.set_meta("requires_power", req_pwr)
			pnl.set("requires_power", req_pwr)
			pnl.set("has_electric_meter", req_pwr)
		var meter = node.find_child("ElectricMeter", true, false)
		if not meter and pnl:
			meter = pnl.find_child("ElectricMeter", true, false)
		if meter:
			meter.visible = req_pwr

	if data.has("requires_boards"):
		var req_bds = bool(data["requires_boards"])
		node.set_meta("requires_boards", req_bds)
		node.set("requires_boards", req_bds)
		if pnl:
			pnl.set_meta("requires_boards", req_bds)
			pnl.set("requires_boards", req_bds)
		var b_node = node.find_child("Boards", true, false)
		if not b_node and pnl:
			b_node = pnl.find_child("Boards", true, false)
		if b_node:
			b_node.visible = req_bds

	if data.has("lock_id"):
		var lid = int(data["lock_id"])
		node.set_meta("lock_id", lid)
		node.set("lock_id", lid)
		if pnl:
			pnl.set_meta("lock_id", lid)
			pnl.set("lock_id", lid)
		if node.has_method("_setup_padlock"):
			node.call("_setup_padlock")
		if pnl and pnl.has_method("_setup_padlock"):
			pnl.call("_setup_padlock")
		var fuse_lbl = node.find_child("FuseboxNumber", true, false)
		if fuse_lbl and fuse_lbl is Label3D:
			fuse_lbl.text = "ЦЕПЬ #%d" % lid

	if data.has("key_id"):
		var kid = int(data["key_id"])
		node.set_meta("key_id", kid)
		node.set("key_id", kid)
		if pnl:
			pnl.set_meta("key_id", kid)
			pnl.set("key_id", kid)
		var DoorScript = load("res://scripts/Door.gd")
		var th = DoorScript.get_lock_theme(kid)
		_recolor_key_node(node, th, kid)

	if data.has("requires_wire_panel"):
		var rwp = bool(data["requires_wire_panel"])
		node.set_meta("requires_wire_panel", rwp)
		node.set("requires_wire_panel", rwp)
		if pnl:
			pnl.set_meta("requires_wire_panel", rwp)
			pnl.set("requires_wire_panel", rwp)
		if node.has_method("_setup_wire_panel"):
			node.call("_setup_wire_panel")
		if pnl and pnl.has_method("_setup_wire_panel"):
			pnl.call("_setup_wire_panel")

	if data.has("target_light_id"):
		node.set_meta("target_light_id", int(data["target_light_id"]))
		node.set("target_light_id", int(data["target_light_id"]))
	if data.has("note_text"):
		node.set_meta("note_text", str(data["note_text"]))

	objects_root.add_child(node)
	return node

func _place_box_drag_object(keep_selected: bool = false) -> Node3D:
	if not ghost_node or not PREFABS.has(active_prefab_id):
		return null

	if active_prefab_id == "roof_gable":
		dynamic_box_size.y = max(2.0, dynamic_box_size.y)
		dynamic_box_pos.y = 3.6

	_record_undo()
	var data = PREFABS[active_prefab_id]
	next_obj_id += 1

	var final_pos = dynamic_box_pos
	var final_sz = dynamic_box_size
	if final_sz.x < 0.5:
		final_sz.x = 4.0
	if final_sz.z < 0.5:
		final_sz.z = 4.0
	if final_sz.y < 0.1:
		final_sz.y = 0.3

	if final_pos == Vector3.ZERO:
		final_pos = ghost_node.position

	var obj_data = {
		"id": next_obj_id,
		"type": data["type"],
		"name": data["name"],
		"position": [snappedf(final_pos.x, 0.01), snappedf(final_pos.y, 0.01), snappedf(final_pos.z, 0.01)],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [snappedf(final_sz.x, 0.01), snappedf(final_sz.y, 0.01), snappedf(final_sz.z, 0.01)],
		"color": data["color"].to_html(),
		"visible": true,
		"comment": "Секция %.1fx%.1fм" % [final_sz.x, final_sz.z]
	}

	var new_obj = _instantiate_object_from_data(obj_data)
	cancel_placement()
	_select_object(new_obj)
	show_notification("Создано: %s (%.1fx%.1fм)" % [data["name"], final_sz.x, final_sz.z])
	return new_obj

# ──────────────────────────────────────────────────────────────────────────────
#  Генератор жилого адаптированного дома по выделенной зоне
# ──────────────────────────────────────────────────────────────────────────────
func _generate_smart_house_in_box(center_pos: Vector3, house_size: Vector3) -> Node3D:
	_record_undo()

	var w = max(house_size.x, 8.0)
	var d = max(house_size.z, 8.0)
	var h = 3.6
	var wall_t = 0.4
	var hw = w * 0.5
	var hd = d * 0.5
	var y_wall = h * 0.5

	# 1. Деревянный пол
	next_obj_id += 1
	var floor_obj = _instantiate_object_from_data({
		"id": next_obj_id,
		"type": "floor_custom",
		"name": "Пол дома",
		"position": [center_pos.x, 0.15, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [w, 0.3, d],
		"color": "#2c1b10",
		"visible": true,
		"comment": "Деревянный пол (%.1fx%.1fм)" % [w, d]
	})

	# 2. ДВУСКАТНАЯ КРЫША (pitched gable roof)
	# Угол скатов ~27° — стандартная жилая крыша (уклон 1:2 от полуширины дома)
	var roof_col = "#6b2222"     # Тёмно-красная черепица
	var ridge_col = "#3d1510"    # Тёмный конёк
	var roof_pitch_deg = 27.0
	var pitch_rad = deg_to_rad(roof_pitch_deg)
	var roof_rise = (d * 0.5) * tan(pitch_rad)  # Высота конька над вершиной стен
	var ridge_y   = h + roof_rise               # Y позиция конька

	# Толщина ската (по нормали к поверхности)
	var roof_thickness = 0.35
	# Длина ската по гипотенузе
	var slope_len = (d * 0.5) / cos(pitch_rad)

	# Левый скат (наклонён на +pitch к оси X)
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Скат крыши (левый)",
		"position": [center_pos.x, h + roof_rise * 0.5, center_pos.z - d * 0.25],
		"rotation": [-roof_pitch_deg, 0.0, 0.0],
		"scale": [w + 0.6, roof_thickness, slope_len],
		"color": roof_col,
		"visible": true,
		"comment": "Левый скат двускатной крыши"
	})

	# Правый скат (наклонён на -pitch к оси X)
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Скат крыши (правый)",
		"position": [center_pos.x, h + roof_rise * 0.5, center_pos.z + d * 0.25],
		"rotation": [roof_pitch_deg, 0.0, 0.0],
		"scale": [w + 0.6, roof_thickness, slope_len],
		"color": roof_col,
		"visible": true,
		"comment": "Правый скат двускатной крыши"
	})

	# Конёк — горизонтальный брус вдоль крыши
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Конёк крыши",
		"position": [center_pos.x, ridge_y + roof_thickness * 0.5, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [w + 0.8, roof_thickness, 0.5],
		"color": ridge_col,
		"visible": true,
		"comment": "Конёк (верхний брус двускатной крыши)"
	})

	# Передний фронтон (треугольник передней торцевой стены)
	# Реализован как тонкий наклонный блок под конёк с обеих сторон
	var gable_h = roof_rise
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Фронтон передний (левая половина)",
		"position": [center_pos.x, h + gable_h * 0.5, center_pos.z + hd - wall_t * 0.5],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [w + 0.4, gable_h, wall_t],
		"color": "#5a524c",
		"visible": true,
		"comment": "Торцевая стена фронтона"
	})

	# Задний фронтон
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Фронтон задний",
		"position": [center_pos.x, h + gable_h * 0.5, center_pos.z - hd + wall_t * 0.5],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [w + 0.4, gable_h, wall_t],
		"color": "#5a524c",
		"visible": true,
		"comment": "Задняя торцевая стена фронтона"
	})

	# Невидимый потолок для raycast (определение «в помещении»)
	# Устанавливается на уровне стен, не рендерится, только физика
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "ceiling_custom",
		"name": "Потолок (коллизия)",
		"position": [center_pos.x, h + 0.15, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [w, 0.3, d],
		"color": "#181412",
		"visible": true,
		"comment": "Невидимый потолок для raycast-проверки «внутри»"
	})

	# 3. Периметр стен:

	# Задняя стена (-Z сторона)
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Стена задняя",
		"position": [center_pos.x, y_wall, center_pos.z - hd + wall_t * 0.5],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [w, h, wall_t],
		"color": "#5a524c",
		"visible": true,
		"comment": "Задняя наружная стена"
	})

	# Левая наружная стена (-X сторона)
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Стена левая",
		"position": [center_pos.x - hw + wall_t * 0.5, y_wall, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [wall_t, h, d],
		"color": "#5a524c",
		"visible": true,
		"comment": "Левая наружная стена"
	})

	# Правая наружная стена (+X сторона)
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Стена правая",
		"position": [center_pos.x + hw - wall_t * 0.5, y_wall, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [wall_t, h, d],
		"color": "#5a524c",
		"visible": true,
		"comment": "Правая наружная стена"
	})

	# Передняя стена (+Z сторона) с дверным проемом шириной 1.6м
	var door_w = 1.6
	var front_half_w = max((w - door_w) * 0.5, 1.0)
	var front_left_cx = center_pos.x - hw + front_half_w * 0.5
	var front_right_cx = center_pos.x + hw - front_half_w * 0.5
	var front_z = center_pos.z + hd - wall_t * 0.5

	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Стена передняя (левое крыло)",
		"position": [front_left_cx, y_wall, front_z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [front_half_w, h, wall_t],
		"color": "#5a524c",
		"visible": true,
		"comment": "Передняя наружная стена"
	})

	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Стена передняя (правое крыло)",
		"position": [front_right_cx, y_wall, front_z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [front_half_w, h, wall_t],
		"color": "#5a524c",
		"visible": true,
		"comment": "Передняя наружная стена"
	})

	# Перемычка над дверным проемом
	var lintel_h = 1.3
	var lintel_y = h - lintel_h * 0.5
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Перемычка над входом",
		"position": [center_pos.x, lintel_y, front_z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [door_w, lintel_h, wall_t],
		"color": "#5a524c",
		"visible": true,
		"comment": "Перемычка над дверью"
	})

	# Интерактивная входная дверь
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "door",
		"name": "Входная дверь",
		"position": [center_pos.x, 0.2, front_z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [1.4, 3.6, 0.4],
		"color": "#66381e",
		"visible": true,
		"comment": "Интерактивная выходная дверь с досками"
	})

	# 4. Межкомнатная перегородка с дверным проемом (делит дом на гостиную и спальню)
	var part_len = max(d - wall_t * 2.0, 4.0)
	var inner_door_w = 1.6
	var part_seg_len = max((part_len - inner_door_w) * 0.5, 1.0)
	var part_x = center_pos.x - w * 0.05
	var part_z1 = center_pos.z - hd + wall_t + part_seg_len * 0.5
	var part_z2 = center_pos.z + hd - wall_t - part_seg_len * 0.5

	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Перегородка комнат (север)",
		"position": [part_x, y_wall, part_z1],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [wall_t, h, part_seg_len],
		"color": "#4e4742",
		"visible": true,
		"comment": "Межкомнатная стена"
	})

	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Перегородка комнат (юг)",
		"position": [part_x, y_wall, part_z2],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [wall_t, h, part_seg_len],
		"color": "#4e4742",
		"visible": true,
		"comment": "Межкомнатная стена"
	})

	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "cube",
		"name": "Перемычка межкомнатная",
		"position": [part_x, lintel_y, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [wall_t, lintel_h, inner_door_w],
		"color": "#4e4742",
		"visible": true,
		"comment": "Перемычка межкомнатного проема"
	})

	# Центры комнат:
	var bed_room_cx = (center_pos.x - hw + part_x) * 0.5
	var living_room_cx = (part_x + center_pos.x + hw) * 0.5

	# 5. Мебель СПАЛЬНИ:
	# Кровать
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_bed",
		"name": "Кровать старая",
		"position": [bed_room_cx - 0.8, 0.15, center_pos.z - hd + 2.2],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [1.48, 0.88, 2.12],
		"color": "#4d2817",
		"visible": true,
		"comment": "Кровать в спальне"
	})

	# Прикроватная тумбочка с ключом от выхода
	var stand_pos = Vector3(bed_room_cx + 0.8, 0.15, center_pos.z - hd + 1.2)
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_nightstand",
		"name": "Тумбочка с ключом",
		"position": [stand_pos.x, stand_pos.y, stand_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [0.66, 0.74, 0.55],
		"color": "#52321c",
		"visible": true,
		"comment": "Прикроватная тумба"
	})

	# Ключ от выхода на тумбочке
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "item_key",
		"name": "Ключ от выхода",
		"position": [stand_pos.x, stand_pos.y + 0.82, stand_pos.z],
		"rotation": [0.0, 45.0, 0.0],
		"scale": [0.3, 0.4, 0.3],
		"color": "#f2cc1a",
		"visible": true,
		"comment": "Ключ от выходной двери"
	})

	# Шкаф для одежды
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_wardrobe",
		"name": "Шкаф для одежды",
		"position": [center_pos.x - hw + 0.9, 0.15, center_pos.z + 1.0],
		"rotation": [0.0, 90.0, 0.0],
		"scale": [1.40, 2.24, 0.70],
		"color": "#402213",
		"visible": true,
		"comment": "Шкаф в спальне"
	})

	# Винтажный ковер
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_carpet",
		"name": "Ковер спальни",
		"position": [bed_room_cx, 0.16, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [2.4, 0.04, 3.2],
		"color": "#561a1f",
		"visible": true,
		"comment": "Винтажный узорный ковер"
	})

	# Лампа в спальне
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "light_warm",
		"name": "Люстра спальни",
		"position": [bed_room_cx, 3.1, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [0.4, 0.4, 0.4],
		"color": "#ffe29a",
		"visible": true,
		"comment": "Теплый свет спальни"
	})

	# Спавн монстра в спальне
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "marker_enemy",
		"name": "Спавн Скинвокера",
		"position": [center_pos.x - hw + 2.0, 0.2, center_pos.z - hd + 2.0],
		"rotation": [0.0, 135.0, 0.0],
		"scale": [0.8, 2.0, 0.8],
		"color": "#e63946",
		"visible": true,
		"comment": "Спавн монстра"
	})

	# 6. Мебель ГОСТИНОЙ:
	# Большой стол
	var table_pos = Vector3(living_room_cx, 0.15, center_pos.z - 0.5)
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_table",
		"name": "Стол гостиной",
		"position": [table_pos.x, table_pos.y, table_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [1.80, 0.80, 0.95],
		"color": "#5c3821",
		"visible": true,
		"comment": "Обеденный/рабочий стол"
	})

	# Лом на столе
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "item_crowbar",
		"name": "Лом (Crowbar)",
		"position": [table_pos.x, table_pos.y + 0.85, table_pos.z],
		"rotation": [0.0, 20.0, 0.0],
		"scale": [0.4, 0.6, 0.4],
		"color": "#5973f2",
		"visible": true,
		"comment": "Предмет для взлома досок"
	})

	# Стулья
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_chair",
		"name": "Стул северный",
		"position": [table_pos.x, 0.15, table_pos.z - 0.85],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [0.52, 0.96, 0.52],
		"color": "#664026",
		"visible": true,
		"comment": "Стул со спинкой"
	})

	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_chair",
		"name": "Стул южный",
		"position": [table_pos.x, 0.15, table_pos.z + 0.85],
		"rotation": [0.0, 180.0, 0.0],
		"scale": [0.52, 0.96, 0.52],
		"color": "#664026",
		"visible": true,
		"comment": "Стул со спинкой"
	})

	# Ящик и бочка в углу
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_crate",
		"name": "Деревянный ящик",
		"position": [center_pos.x + hw - 1.2, 0.15, center_pos.z - hd + 1.2],
		"rotation": [0.0, 15.0, 0.0],
		"scale": [1.0, 1.0, 1.0],
		"color": "#7a5733",
		"visible": true,
		"comment": "Ящик с припасами"
	})

	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_barrel",
		"name": "Металлическая бочка",
		"position": [center_pos.x + hw - 1.2, 0.15, center_pos.z - hd + 2.5],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [0.7, 1.1, 0.7],
		"color": "#3d4d61",
		"visible": true,
		"comment": "Бочка"
	})

	# Лужа крови
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "prop_blood_puddle",
		"name": "Пятно крови",
		"position": [center_pos.x + hw - 2.5, 0.16, center_pos.z + 1.5],
		"rotation": [0.0, 45.0, 0.0],
		"scale": [1.8, 0.04, 1.8],
		"color": "#610405",
		"visible": true,
		"comment": "Лужа крови на полу"
	})

	# Люстра гостиной
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "light_warm",
		"name": "Люстра гостиной",
		"position": [living_room_cx, 3.1, center_pos.z],
		"rotation": [0.0, 0.0, 0.0],
		"scale": [0.4, 0.4, 0.4],
		"color": "#ffe29a",
		"visible": true,
		"comment": "Теплый свет зала"
	})

	# 7. Спавн игрока в гостиной перед выходом
	next_obj_id += 1
	_instantiate_object_from_data({
		"id": next_obj_id,
		"type": "marker_player",
		"name": "Спавн игрока",
		"position": [center_pos.x, 0.2, center_pos.z + hd - 2.5],
		"rotation": [0.0, 180.0, 0.0],
		"scale": [0.8, 1.8, 0.8],
		"color": "#26d9a6",
		"visible": true,
		"comment": "Спавн игрока у входа"
	})

	show_notification("🏠 Создан жилой дом (%.1fx%.1fм, 2 комнаты, мебель, дверь, свет и лут)!" % [w, d])
	_select_object(floor_obj)
	return floor_obj


func _build_visual_node(type: String, sz: Vector3, color: Color, is_ghost: bool, custom_model_path: String = "") -> Node3D:
	return PrefabBuilder.build_prefab(type, sz, color, is_ghost, custom_model_path)

func _set_selected_size(target_sz: Vector3) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован! Изменение размера заблокировано.")
		return
	_record_undo()
	var new_sz = target_sz
	new_sz.x = max(0.05, new_sz.x)
	new_sz.y = max(0.05, new_sz.y)
	new_sz.z = max(0.05, new_sz.z)

	var obj_type = str(selected_node.get_meta("obj_type", "cube"))
	var cur_sz: Vector3 = selected_node.get_meta("obj_scale", Vector3.ONE)
	var delta_y = new_sz.y - cur_sz.y
	selected_node.set_meta("obj_scale", new_sz)

	if _is_primitive_box_type(obj_type):
		_update_box_mesh_size(selected_node, new_sz)
		selected_node.scale = Vector3.ONE
		selected_node.set_meta("base_size", new_sz)
		if _is_centered_origin_type(obj_type):
			selected_node.position.y += delta_y * 0.5
	else:
		var base_sz: Vector3 = selected_node.get_meta("prefab_base_size", PrefabBuilder.get_prefab_base_size(obj_type))
		if base_sz.x <= 0.01: base_sz.x = 1.0
		if base_sz.y <= 0.01: base_sz.y = 1.0
		if base_sz.z <= 0.01: base_sz.z = 1.0
		selected_node.scale = Vector3(new_sz.x / base_sz.x, new_sz.y / base_sz.y, new_sz.z / base_sz.z)

	_update_inspector()
	_update_selection_box()
	show_notification("Размер: (%.2f, %.2f, %.2f)м" % [new_sz.x, new_sz.y, new_sz.z])

func _resize_selected(delta_sz: Vector3) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	var cur_sz: Vector3 = selected_node.get_meta("obj_scale", Vector3.ONE)
	_set_selected_size(cur_sz + delta_sz)

func _scale_selected_proportional(factor: float) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	var cur_sz: Vector3 = selected_node.get_meta("obj_scale", Vector3.ONE)
	_set_selected_size(cur_sz * factor)

func _reset_selected_size() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	var obj_type = str(selected_node.get_meta("obj_type", "cube"))
	var base_sz = selected_node.get_meta("prefab_base_size", PrefabBuilder.get_prefab_base_size(obj_type))
	_set_selected_size(base_sz)

func _apply_size_to_node(_node: Node, _new_sz: Vector3) -> void:
	pass

func _apply_color_to_node(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.mesh:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.85
		mat.metallic = 0.08
		node.set_surface_override_material(0, mat)
	for child in node.get_children():
		_apply_color_to_node(child, color)

func _recolor_selected(color: Color) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован! Покраска заблокирована.")
		return
	_record_undo()
	selected_node.set_meta("obj_color", color)
	_apply_color_to_node(selected_node, color)
	show_notification("🎨 Цвет изменен: #" + color.to_html(false))

func _nudge_selected_pos(offset: Vector3) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован! Смещение заблокировано.")
		return
	_record_undo()
	selected_node.position += offset
	_update_inspector()
	_update_selection_box()
	show_notification("Позиция: (%.2f, %.2f, %.2f)м" % [selected_node.position.x, selected_node.position.y, selected_node.position.z])

func _open_save_as_model_modal() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		show_notification("Сначала выберите объект для сохранения!")
		return
	_close_active_modal()

	var modal_bg = ColorRect.new()
	modal_bg.color = Color(0.02, 0.03, 0.05, 0.75)
	modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(modal_bg)
	active_modal = modal_bg

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 200)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	pstyle.border_width_left = 1
	pstyle.border_width_right = 1
	pstyle.border_width_top = 1
	pstyle.border_width_bottom = 1
	pstyle.border_color = Color(0.3, 0.85, 1.0)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", pstyle)
	modal_bg.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	var title = Label.new()
	title.text = "⭐ СОХРАНЕНИЕ МОДЕЛИ В КАТАЛОГ"
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vb.add_child(title)

	var name_lbl = Label.new()
	name_lbl.text = "Название модели (например: Мой стол, Шкафчик, Колонна):"
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vb.add_child(name_lbl)

	var name_edit = LineEdit.new()
	name_edit.text = str(selected_node.get_meta("obj_name", "Моя модель"))
	name_edit.placeholder_text = "Введите название..."
	vb.add_child(name_edit)

	var btn_hb = HBoxContainer.new()
	btn_hb.add_theme_constant_override("separation", 8)

	var btn_save = Button.new()
	btn_save.text = "⭐ Сохранить в каталог"
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save.pressed.connect(func():
		var m_name = name_edit.text.strip_edges()
		if m_name == "": m_name = "Моя модель"
		_save_selected_as_custom_prefab(m_name)
		_close_active_modal()
	)
	btn_hb.add_child(btn_save)

	var btn_cancel = Button.new()
	btn_cancel.text = "Отмена"
	btn_cancel.pressed.connect(_close_active_modal)
	btn_hb.add_child(btn_cancel)
	vb.add_child(btn_hb)

func _save_selected_as_custom_prefab(model_name: String) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	var o_type = selected_node.get_meta("obj_type", "cube")
	var sz = selected_node.get_meta("obj_scale", Vector3.ONE)
	var col = selected_node.get_meta("obj_color", Color.WHITE)
	var model_path = selected_node.get_meta("model_path", "")

	var pid = "user_model_" + str(Time.get_ticks_msec())
	PREFABS[pid] = {
		"category": "⭐ Мои модели",
		"icon": "🎨",
		"name": model_name,
		"type": o_type,
		"size": sz,
		"color": col,
		"comment": "Пользовательская модель: " + model_name,
		"model_path": model_path
	}

	var dir_path = "user://custom_prefabs"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dir_path)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))
	
	var file_path = dir_path + "/" + model_name.validate_filename() + ".json"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var pdata = {
			"name": model_name,
			"type": o_type,
			"scale": [sz.x, sz.y, sz.z],
			"color": "#" + col.to_html(false),
			"model_path": model_path
		}
		file.store_string(JSON.stringify(pdata, "  "))
		file.close()

	_filter_drawer_category("⭐ Мои модели")
	show_notification("⭐ Модель '%s' сохранена в каталог [Tab]!" % model_name)

func _open_import_model_dialog() -> void:
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.glb, *.gltf, *.obj, *.tscn ; 3D Модели"])
	fd.file_selected.connect(func(src_path: String):
		_import_model_file(src_path)
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	ui_layer.add_child(fd)
	fd.popup_centered(Vector2i(700, 450))

func _import_model_file(src_path: String) -> void:
	var file_name = src_path.get_file()
	var base_name = src_path.get_file().get_basename()
	var dest_dir = "user://custom_models"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dest_dir)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest_dir))
	
	var dest_path = dest_dir + "/" + file_name
	var da = DirAccess.open(dest_dir)
	if da:
		da.copy(src_path, dest_path)

	var pid = "imported_" + base_name.validate_filename()
	PREFABS[pid] = {
		"category": "⭐ Мои модели",
		"icon": "📦",
		"name": base_name.capitalize(),
		"type": "custom_prop",
		"size": Vector3(1.5, 1.5, 1.5),
		"color": Color.WHITE,
		"comment": "Импортированная 3D-модель: " + file_name,
		"model_path": dest_path
	}

	_filter_drawer_category("⭐ Мои модели")
	start_placing_prefab(pid)
	show_notification("📥 Модель '%s' импортирована в каталог!" % base_name)

# ══════════════════════════════════════════════════════════════════════════════
#  Сериализация и Нормализация MapForge JSON
# ══════════════════════════════════════════════════════════════════════════════
func _serialize_single_object(node: Node3D) -> Dictionary:
	var pos = node.position
	var rot = node.rotation_degrees
	var sz: Vector3 = node.get_meta("obj_scale", Vector3.ONE)
	if sz == Vector3.ONE and node.scale != Vector3.ONE and node.has_meta("prefab_base_size"):
		var base_sz = node.get_meta("prefab_base_size")
		sz = Vector3(node.scale.x * base_sz.x, node.scale.y * base_sz.y, node.scale.z * base_sz.z)
	var col: Color = node.get_meta("obj_color", Color.WHITE)

	var d = {
		"id": node.get_meta("obj_id", 0),
		"type": node.get_meta("obj_type", "cube"),
		"name": node.get_meta("obj_name", "Объект"),
		"position": [snappedf(pos.x, 0.001), snappedf(pos.y, 0.001), snappedf(pos.z, 0.001)],
		"rotation": [snappedf(rot.x, 0.01), snappedf(rot.y, 0.01), snappedf(rot.z, 0.01)],
		"scale": [snappedf(sz.x, 0.001), snappedf(sz.y, 0.001), snappedf(sz.z, 0.001)],
		"color": col.to_html(),
		"visible": true,
		"comment": node.get_meta("obj_comment", "")
	}

	var pnl = node.find_child("Panel", true, false)

	if node.has_meta("door_texture") and str(node.get_meta("door_texture")) != "":
		d["door_texture"] = str(node.get_meta("door_texture"))
	elif pnl and pnl.has_meta("door_texture") and str(pnl.get_meta("door_texture")) != "":
		d["door_texture"] = str(pnl.get_meta("door_texture"))

	if node.has_meta("model_path"):
		d["model_path"] = str(node.get_meta("model_path"))
	if node.has_meta("wall_texture") and str(node.get_meta("wall_texture")) != "":
		d["wall_texture"] = str(node.get_meta("wall_texture"))
	if node.has_meta("painting_art") and str(node.get_meta("painting_art")) != "":
		d["painting_art"] = str(node.get_meta("painting_art"))
	if node.has_meta("tree_drawing") and str(node.get_meta("tree_drawing")) != "":
		d["tree_drawing"] = str(node.get_meta("tree_drawing"))

	# Ключи и замки
	var key_col = ""
	if node.has_meta("key_color"):
		key_col = str(node.get_meta("key_color"))
	elif pnl and pnl.has_meta("key_color"):
		key_col = str(pnl.get_meta("key_color"))
	elif "required_key_color" in node:
		key_col = str(node.get("required_key_color"))
	if key_col != "" and key_col != "none":
		d["key_color"] = key_col

	# Требование питания (электродверь)
	var req_pwr = false
	if node.has_meta("requires_power"):
		req_pwr = bool(node.get_meta("requires_power"))
	elif pnl and pnl.has_meta("requires_power"):
		req_pwr = bool(pnl.get_meta("requires_power"))
	elif "requires_power" in node:
		req_pwr = bool(node.get("requires_power"))
	if req_pwr:
		d["requires_power"] = true

	# Требование досок (заколоченная дверь)
	var req_bds = false
	if node.has_meta("requires_boards"):
		req_bds = bool(node.get_meta("requires_boards"))
	elif pnl and pnl.has_meta("requires_boards"):
		req_bds = bool(pnl.get_meta("requires_boards"))
	elif "requires_boards" in node:
		req_bds = bool(node.get("requires_boards"))
	if req_bds:
		d["requires_boards"] = true

	# ID замка (0 = без замка)
	var eff_lid = 0
	if node.has_meta("lock_id"):
		eff_lid = int(node.get_meta("lock_id"))
	elif pnl and pnl.has_meta("lock_id"):
		eff_lid = int(pnl.get_meta("lock_id"))
	elif "lock_id" in node:
		eff_lid = int(node.get("lock_id"))
	d["lock_id"] = eff_lid

	# ID ключа
	var eff_kid = 0
	if node.has_meta("key_id"):
		eff_kid = int(node.get_meta("key_id"))
	elif pnl and pnl.has_meta("key_id"):
		eff_kid = int(pnl.get_meta("key_id"))
	elif "key_id" in node:
		eff_kid = int(node.get("key_id"))
	if eff_kid > 0:
		d["key_id"] = eff_kid

	# Электрощиток проводов
	var req_wp = false
	if node.has_meta("requires_wire_panel"):
		req_wp = bool(node.get_meta("requires_wire_panel"))
	elif pnl and pnl.has_meta("requires_wire_panel"):
		req_wp = bool(pnl.get_meta("requires_wire_panel"))
	elif "requires_wire_panel" in node:
		req_wp = bool(node.get("requires_wire_panel"))
	if req_wp:
		d["requires_wire_panel"] = true

	if node.has_meta("target_light_id"):
		d["target_light_id"] = int(node.get_meta("target_light_id"))
	elif "target_light_id" in node:
		d["target_light_id"] = int(node.get("target_light_id"))

	if node.has_meta("is_locked"):
		d["is_locked"] = bool(node.get_meta("is_locked"))
	if node.has_meta("note_text"):
		d["note_text"] = str(node.get_meta("note_text"))
	return d

func _normalize_loaded_object(data: Dictionary, is_legacy_prototype: bool = false) -> Dictionary:
	if not is_legacy_prototype:
		return data

	var o_type: String = data.get("type", "cube")
	var pa = data.get("position", [0, 1, 0])
	var sa = data.get("scale", [1, 1, 1])
	var sz = Vector3(float(sa[0]), float(sa[1]), float(sa[2]))
	var pos = Vector3(float(pa[0]), float(pa[1]), float(pa[2]))
	var oname: String = str(data.get("name", "")).to_lower()
	var ocomm: String = str(data.get("comment", "")).to_lower()

	# Только для старого файла prototype map.json (арена-прототип без явных типов)
	if o_type == "marker":
		if "лесопил" in oname or "лесопил" in ocomm or "lumberjack" in oname:
			data["type"] = "marker_lumberjack"
			data["name"] = "Спавн Лесопила"
		elif "враг" in oname or "враг" in ocomm or "enemy" in oname or "скинвокер" in oname:
			data["type"] = "marker_enemy"
			data["name"] = "Спавн врага"
		elif "лом" in oname or "лом" in ocomm or "crowbar" in oname or "crowbar" in ocomm:
			data["type"] = "item_crowbar"
			data["name"] = "Точка / Лом"
		elif "ключ" in oname or "ключ" in ocomm or "key" in oname or "key" in ocomm:
			data["type"] = "item_key"
			data["name"] = "Точка / Ключ"
		else:
			data["type"] = "marker_player"
			data["name"] = "Спавн игрока"
		sz = Vector3(0.8, 1.8, 0.8)
		pos.y = sz.y * 0.5
		data["scale"] = [sz.x, sz.y, sz.z]
		data["position"] = [pos.x, pos.y, pos.z]

	elif int(data.get("id", 0)) == 82 and ("выход" in ocomm or "доски" in ocomm or "door" in oname):
		data["type"] = "door"
		data["name"] = "Заколоченная дверь"
		sz = Vector3(1.4, 3.6, 0.4)
		pos.y = sz.y * 0.5
		data["scale"] = [sz.x, sz.y, sz.z]
		data["position"] = [pos.x, pos.y, pos.z]

	elif o_type == "cube":
		# В старом prototype map только стены имели высоту 2.0 (1.9..2.2) вместо 3.6
		if sz.y >= 1.9 and sz.y <= 2.2:
			sz.y = 3.6
			pos.y = sz.y * 0.5
			data["scale"] = [sz.x, sz.y, sz.z]
			data["position"] = [pos.x, pos.y, pos.z]

	return data

func quick_save_map() -> void:
	if active_map_file_path != "":
		save_map_to_json(active_map_file_path)
	else:
		_open_save_modal()

func save_map_to_json(path: String) -> bool:
	if path == "":
		_open_save_modal()
		return false

	var dir_path = path.get_base_dir()
	if dir_path != "":
		var glob_dir = ProjectSettings.globalize_path(dir_path)
		if not DirAccess.dir_exists_absolute(glob_dir):
			DirAccess.make_dir_recursive_absolute(glob_dir)

	var objects_array: Array = []
	for child in objects_root.get_children():
		if child is Node3D and is_instance_valid(child) and not child.is_queued_for_deletion():
			if child.has_meta("obj_type") or child.has_meta("prefab_type"):
				objects_array.append(_serialize_single_object(child))

	var map_data = {
		"generator": "MapForge",
		"version": 1,
		"meta": {
			"units": "метры",
			"up": "Y",
			"rotations": "градусы (X,Y,Z)"
		},
		"sceneComment": "Карта создана в Debug Editor MapForge",
		"sceneSize": [40, 4, 40],
		"objects": objects_array
	}

	var json_text = JSON.stringify(map_data, "  ")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		var global_p = ProjectSettings.globalize_path(path)
		file = FileAccess.open(global_p, FileAccess.WRITE)

	if not file:
		var err = FileAccess.get_open_error()
		show_notification("❌ Ошибка сохранения (код %d): %s" % [err, path])
		return false

	file.store_string(json_text)
	file.close()

	active_map_file_path = path
	var gm_save = _get_gm()
	if gm_save:
		gm_save.set("active_map_path", path)
	show_notification("💾 Карта сохранена: " + path.get_file())
	return true

func load_map_from_json(path: String) -> bool:
	var actual_path = path
	if not FileAccess.file_exists(actual_path):
		var glob_p = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(glob_p):
			actual_path = glob_p
		else:
			show_notification("Файл не найден: " + path)
			return false

	var file = FileAccess.open(actual_path, FileAccess.READ)
	if not file:
		return false

	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		file.close()
		show_notification("Ошибка парсинга JSON!")
		return false
	file.close()

	clear_all_objects()

	var data: Dictionary = json.data
	var objects: Array = data.get("objects", [])
	var max_id = 0
	var clean_path = path.replace("\\", "/").to_lower()
	var is_legacy: bool = (clean_path.ends_with("assets/prototype map.json") or clean_path == "res://assets/prototype map.json") and (data.get("generator") != "MapForge" and not data.has("version"))

	for obj in objects:
		var cur_id = int(obj.get("id", 0))
		if cur_id > max_id:
			max_id = cur_id
		var loaded_obj = obj
		if is_legacy:
			loaded_obj = _normalize_loaded_object(obj, true)
		_instantiate_object_from_data(loaded_obj)

	next_obj_id = max(max_id + 1, 100)
	active_map_file_path = path
	var gm_load = _get_gm()
	if gm_load:
		gm_load.set("active_map_path", path)
	show_notification("Загружена карта (%d объектов): %s" % [objects.size(), path.get_file()])
	return true

# ══════════════════════════════════════════════════════════════════════════════
#  Модальные окна сохранения и загрузки (с выбором имени и папки)
# ══════════════════════════════════════════════════════════════════════════════
func _close_active_modal() -> void:
	if active_modal and is_instance_valid(active_modal):
		active_modal.queue_free()
		active_modal = null

func _toggle_help_modal() -> void:
	if active_modal and is_instance_valid(active_modal) and active_modal.name == "HelpModalOverlay":
		_close_active_modal()
		return
	_open_help_modal()

func _open_help_modal() -> void:
	_close_active_modal()

	var modal_bg = ColorRect.new()
	modal_bg.name = "HelpModalOverlay"
	modal_bg.color = Color(0.02, 0.03, 0.05, 0.75)
	modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(modal_bg)
	active_modal = modal_bg

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 440)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.08, 0.10, 0.15, 0.98)
	pstyle.border_width_left = 1
	pstyle.border_width_right = 1
	pstyle.border_width_top = 1
	pstyle.border_width_bottom = 1
	pstyle.border_color = Color(0.28, 0.50, 0.85)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", pstyle)
	modal_bg.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)

	var header_hb = HBoxContainer.new()
	var title = Label.new()
	title.text = "⌨ СПРАВОЧНИК ГОРЯЧИХ КЛАВИШ И УПРАВЛЕНИЯ"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hb.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "✖ Закрыть"
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(_close_active_modal)
	header_hb.add_child(close_btn)
	vb.add_child(header_hb)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var shortcuts = [
		["ЛКМ", "Выбрать объект / Подтвердить установку"],
		["ПКМ (зажать)", "Свободный круговой осмотр камеры"],
		["W, A, S, D", "Полёт камеры в пространстве"],
		["1", "Ставить объект / Зафиксировать точку"],
		["2 / Delete / Backspace", "Удалить выбранный объект"],
		["3", "Взять и свободно перемещать объект"],
		["Ctrl + D", "Быстрое дублирование со смещением"],
		["F", "Сфокусировать камеру на выбранном объекте"],
		["R / Q", "Вращение по Y на 45° (с Shift — на 15°)"],
		["T / Y", "Наклон вперед/назад и крен в градусах"],
		["Shift + Колесико мыши", "Плавный подъем/опускание при перетаскивании"],
		["PageUp / PageDown", "Поднять / опустить объект по высоте Y"],
		["End", "Опустить объект ровно на пол"],
		["G", "Включить / выключить привязку к сетке"],
		["Alt (зажать)", "Полностью свободное перемещение без привязки"],
		["Tab", "Открыть или скрыть каталог объектов"],
		["Ctrl + S", "Открыть диалог сохранения карты в JSON"],
		["Ctrl + Z / Ctrl + Y", "История действий: Отмена / Повтор"],
		["Ё / ~", "Fullbright: выключить темноту в редакторе"],
		["7", "Мгновенный переход в режим тестирования (Игрок)"],
		["H / F1", "Открыть / закрыть это окно подсказок"]
	]

	for item in shortcuts:
		var k_lbl = Label.new()
		k_lbl.text = item[0]
		k_lbl.add_theme_font_size_override("font_size", 11)
		k_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		grid.add_child(k_lbl)

		var d_lbl = Label.new()
		d_lbl.text = item[1]
		d_lbl.add_theme_font_size_override("font_size", 11)
		d_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
		grid.add_child(d_lbl)

func _get_documents_maps_dir() -> String:
	var docs_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if docs_path == "":
		docs_path = OS.get_environment("USERPROFILE") + "/Documents"
	docs_path = docs_path.replace("\\", "/")
	var maps_dir = docs_path + "/Escape in Skinwalker/Maps"
	var global_dir = ProjectSettings.globalize_path(maps_dir)
	if not DirAccess.dir_exists_absolute(global_dir):
		DirAccess.make_dir_recursive_absolute(global_dir)
	return maps_dir

func _get_unique_default_map_name(target_dir: String) -> String:
	var d = target_dir.replace("\\", "/")
	if not d.ends_with("/"):
		d += "/"
	var index = 1
	while index < 9999:
		var candidate = "Карта_%d" % index
		var file_path = ProjectSettings.globalize_path(d + candidate + ".json")
		if not FileAccess.file_exists(file_path):
			return candidate
		index += 1
	return "Карта_1"

func _open_save_modal() -> void:
	_close_active_modal()

	var modal_bg = ColorRect.new()
	modal_bg.color = Color(0.02, 0.03, 0.05, 0.75)
	modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(modal_bg)
	active_modal = modal_bg

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(540, 340)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	pstyle.border_width_left = 1
	pstyle.border_width_right = 1
	pstyle.border_width_top = 1
	pstyle.border_width_bottom = 1
	pstyle.border_color = Color(0.26, 0.44, 0.68)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", pstyle)
	modal_bg.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 9)
	panel.add_child(vb)

	# Заголовок
	var head_hb = HBoxContainer.new()
	var title = Label.new()
	title.text = "💾 СОХРАНЕНИЕ КАРТЫ (Сохранить как)"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	head_hb.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_hb.add_child(spacer)

	var btn_x = Button.new()
	btn_x.text = " ✕ "
	btn_x.pressed.connect(_close_active_modal)
	head_hb.add_child(btn_x)
	vb.add_child(head_hb)

	# Папка
	var dir_lbl = Label.new()
	dir_lbl.text = "Папка сохранения:"
	dir_lbl.add_theme_font_size_override("font_size", 11)
	dir_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vb.add_child(dir_lbl)

	var default_dir = active_map_file_path.get_base_dir()
	if default_dir == "":
		default_dir = "res://scenes"
	var default_name = active_map_file_path.get_file().get_basename()
	if default_name == "":
		default_name = _get_unique_default_map_name(default_dir)

	var dir_edit = LineEdit.new()
	dir_edit.text = default_dir
	vb.add_child(dir_edit)

	# Быстрый выбор папок
	var quick_hb = HBoxContainer.new()
	quick_hb.add_theme_constant_override("separation", 6)

	var b_scenes = Button.new()
	b_scenes.text = "📁 res://scenes/"
	b_scenes.add_theme_font_size_override("font_size", 10)
	quick_hb.add_child(b_scenes)

	var b_assets = Button.new()
	b_assets.text = "📁 res://assets/"
	b_assets.add_theme_font_size_override("font_size", 10)
	quick_hb.add_child(b_assets)

	var b_user_maps = Button.new()
	b_user_maps.text = "📁 user://maps/"
	b_user_maps.add_theme_font_size_override("font_size", 10)
	quick_hb.add_child(b_user_maps)

	var b_docs = Button.new()
	b_docs.text = "📁 Документы"
	b_docs.add_theme_font_size_override("font_size", 10)
	quick_hb.add_child(b_docs)

	var b_browse = Button.new()
	b_browse.text = "🔍 Обзор..."
	b_browse.add_theme_font_size_override("font_size", 10)
	quick_hb.add_child(b_browse)

	var b_new_name = Button.new()
	b_new_name.text = "🎲 Уникальное имя"
	b_new_name.add_theme_font_size_override("font_size", 10)
	quick_hb.add_child(b_new_name)

	vb.add_child(quick_hb)

	# Имя файла
	var name_lbl = Label.new()
	name_lbl.text = "Имя карты (.json):"
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vb.add_child(name_lbl)

	var name_edit = LineEdit.new()
	name_edit.text = default_name
	name_edit.placeholder_text = "например: Карта_4, prototype map, Убежище..."
	vb.add_child(name_edit)

	b_scenes.pressed.connect(func():
		dir_edit.text = "res://scenes"
	)
	b_assets.pressed.connect(func():
		dir_edit.text = "res://assets"
	)
	b_user_maps.pressed.connect(func():
		dir_edit.text = "user://maps"
	)
	b_docs.pressed.connect(func():
		dir_edit.text = _get_documents_maps_dir()
	)
	b_new_name.pressed.connect(func():
		name_edit.text = _get_unique_default_map_name(dir_edit.text)
	)
	b_browse.pressed.connect(func():
		var fd = FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		fd.access = FileDialog.ACCESS_FILESYSTEM
		fd.dir_selected.connect(func(dir: String):
			dir_edit.text = dir
			name_edit.text = _get_unique_default_map_name(dir)
			fd.queue_free()
		)
		fd.canceled.connect(func(): fd.queue_free())
		ui_layer.add_child(fd)
		fd.popup_centered(Vector2i(650, 420))
	)

	# Превью полного пути
	var preview_lbl = Label.new()
	preview_lbl.add_theme_font_size_override("font_size", 10)
	preview_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	var update_preview = func(_dummy = ""):
		var d = dir_edit.text.strip_edges()
		if not d.ends_with("/") and not d.ends_with("\\"):
			d += "/"
		var n = name_edit.text.strip_edges()
		if not n.ends_with(".json"):
			n += ".json"
		preview_lbl.text = "Путь сохранения: " + d + n
	name_edit.text_changed.connect(update_preview)
	dir_edit.text_changed.connect(update_preview)
	update_preview.call()
	vb.add_child(preview_lbl)

	# Кнопки действия
	var bot_hb = HBoxContainer.new()
	bot_hb.add_theme_constant_override("separation", 10)

	var btn_save = Button.new()
	btn_save.text = " 💾 СОХРАНИТЬ КАРТУ "
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s_style = StyleBoxFlat.new()
	s_style.bg_color = Color(0.16, 0.48, 0.70)
	s_style.set_content_margin_all(8)
	btn_save.add_theme_stylebox_override("normal", s_style)
	btn_save.pressed.connect(func():
		var d = dir_edit.text.strip_edges()
		if not d.ends_with("/") and not d.ends_with("\\"):
			d += "/"
		var n = name_edit.text.strip_edges()
		if n == "":
			n = _get_unique_default_map_name(d)
		if not n.ends_with(".json"):
			n += ".json"
		var full_path = d + n
		var global_p = ProjectSettings.globalize_path(full_path)

		# Защита от случайного перезаписывания
		if FileAccess.file_exists(global_p):
			var warn_confirm = ConfirmationDialog.new()
			warn_confirm.title = "⚠️ Файл уже существует"
			warn_confirm.dialog_text = "Файл '%s' уже существует!\n\nВы действительно хотите его перезаписать,\nили сохранить как новую версию?" % n
			warn_confirm.ok_button_text = "⚠️ Заменить (Перезаписать)"
			warn_confirm.cancel_button_text = "Отмена"
			var b_copy = warn_confirm.add_button("✨ Новое имя (не заменять)", true, "save_copy")
			warn_confirm.custom_action.connect(func(act: StringName):
				if act == "save_copy":
					var unique_n = _get_unique_default_map_name(d) + ".json"
					save_map_to_json(d + unique_n)
					warn_confirm.queue_free()
					_close_active_modal()
			)
			warn_confirm.confirmed.connect(func():
				save_map_to_json(full_path)
				warn_confirm.queue_free()
				_close_active_modal()
			)
			warn_confirm.canceled.connect(func():
				warn_confirm.queue_free()
			)
			ui_layer.add_child(warn_confirm)
			warn_confirm.popup_centered()
			return

		if save_map_to_json(full_path):
			_close_active_modal()
	)
	bot_hb.add_child(btn_save)

	var btn_cancel = Button.new()
	btn_cancel.text = " Отмена "
	btn_cancel.pressed.connect(_close_active_modal)
	bot_hb.add_child(btn_cancel)
	vb.add_child(bot_hb)

func _open_load_modal() -> void:
	_close_active_modal()

	var modal_bg = ColorRect.new()
	modal_bg.color = Color(0.02, 0.03, 0.05, 0.75)
	modal_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(modal_bg)
	active_modal = modal_bg

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 390)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var pstyle = StyleBoxFlat.new()
	pstyle.bg_color = Color(0.09, 0.11, 0.16, 0.98)
	pstyle.border_width_left = 1
	pstyle.border_width_right = 1
	pstyle.border_width_top = 1
	pstyle.border_width_bottom = 1
	pstyle.border_color = Color(0.26, 0.44, 0.68)
	pstyle.corner_radius_top_left = 8
	pstyle.corner_radius_top_right = 8
	pstyle.corner_radius_bottom_left = 8
	pstyle.corner_radius_bottom_right = 8
	pstyle.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", pstyle)
	modal_bg.add_child(panel)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)

	# Заголовок
	var head_hb = HBoxContainer.new()
	var title = Label.new()
	title.text = "📂 ВЫБОР И ЗАГРУЗКА КАРТЫ"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	head_hb.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_hb.add_child(spacer)

	var btn_x = Button.new()
	btn_x.text = " ✕ "
	btn_x.pressed.connect(_close_active_modal)
	head_hb.add_child(btn_x)
	vb.add_child(head_hb)

	var list_lbl = Label.new()
	list_lbl.text = "Карты из Документов Windows и проекта:"
	list_lbl.add_theme_font_size_override("font_size", 11)
	list_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vb.add_child(list_lbl)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 180)
	vb.add_child(scroll)

	var cards_vb = VBoxContainer.new()
	cards_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vb.add_theme_constant_override("separation", 6)
	scroll.add_child(cards_vb)

	# Поиск карт в папках (приоритет папке Документы)
	var docs_maps_dir = _get_documents_maps_dir()
	var scan_dirs = ["res://scenes", "res://assets", docs_maps_dir, "user://maps", "user://"]
	var found_maps: Array[String] = []
	for s_dir in scan_dirs:
		var global_s_dir = ProjectSettings.globalize_path(s_dir)
		var d = DirAccess.open(global_s_dir)
		if d:
			d.list_dir_begin()
			var fn = d.get_next()
			while fn != "":
				if not d.current_is_dir() and fn.ends_with(".json"):
					var full_p = s_dir + ("/" if not s_dir.ends_with("/") else "") + fn
					if not found_maps.has(full_p):
						found_maps.append(full_p)
				fn = d.get_next()

	if found_maps.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "Пока нет сохраненных карт."
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		cards_vb.add_child(empty_lbl)
	else:
		for map_path in found_maps:
			var card_hb = HBoxContainer.new()
			var map_btn = Button.new()
			var is_doc = map_path.contains("Documents") or map_path.contains("Документы") or map_path.begins_with(docs_maps_dir)
			var icon_prefix = "📁 [Документы] " if is_doc else "📄 "
			map_btn.text = icon_prefix + map_path.get_file() + "   (" + map_path.get_base_dir() + ")"
			map_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			map_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var captured_p = map_path
			map_btn.pressed.connect(func():
				_record_undo()
				load_map_from_json(captured_p)
				_close_active_modal()
			)
			card_hb.add_child(map_btn)
			cards_vb.add_child(card_hb)

	# Кнопка открытия папки в Проводнике Windows
	var explorer_hb = HBoxContainer.new()
	explorer_hb.add_theme_constant_override("separation", 6)

	var explorer_btn = Button.new()
	explorer_btn.text = "📂 Открыть папку карт в Проводнике Windows"
	explorer_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	explorer_btn.pressed.connect(func():
		OS.shell_open(ProjectSettings.globalize_path(docs_maps_dir))
	)
	explorer_hb.add_child(explorer_btn)

	var browse_btn = Button.new()
	browse_btn.text = "🔍 Обзор..."
	browse_btn.pressed.connect(func():
		var fd = FileDialog.new()
		fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		fd.access = FileDialog.ACCESS_FILESYSTEM
		fd.filters = PackedStringArray(["*.json ; Файлы карт JSON (*.json)"])
		fd.file_selected.connect(func(path: String):
			_record_undo()
			load_map_from_json(path)
			_close_active_modal()
			fd.queue_free()
		)
		fd.canceled.connect(func(): fd.queue_free())
		ui_layer.add_child(fd)
		fd.popup_centered(Vector2i(680, 440))
	)
	explorer_hb.add_child(browse_btn)
	vb.add_child(explorer_hb)

	var close_btn = Button.new()
	close_btn.text = "Закрыть"
	close_btn.pressed.connect(_close_active_modal)
	vb.add_child(close_btn)

func clear_all_objects() -> void:
	_deselect_object()
	cancel_placement()
	for child in objects_root.get_children():
		objects_root.remove_child(child)
		child.queue_free()
	show_notification("Карта очищена")

func create_clean_polygon() -> void:
	clear_all_objects()

	# 1. Секция асфальтированной дороги
	next_obj_id = 1
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "road_segment", "name": "Дорога асфальт",
		"position": [22.0, 0.06, 0.0], "rotation": [0, 0, 0], "scale": [12.0, 0.12, 60.0],
		"color": "#212429", "comment": "Секция дороги с разметкой"
	})

	# 2. Автомобиль для побега на обочине дороги
	next_obj_id = 2
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "prop_car", "name": "Машина для побега",
		"position": [20.0, 0.15, 6.0], "rotation": [0, -10.0, 0], "scale": [2.0, 1.5, 4.4],
		"color": "#33527a", "comment": "Автомобиль для спасения"
	})

	# 3. Природные скалы и валуны на зеленой траве
	next_obj_id = 3
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "prop_rock_large", "name": "Большая скала",
		"position": [-28.0, 0.15, -15.0], "rotation": [0, 35.0, 0], "scale": [6.0, 4.2, 5.5],
		"color": "#52545c", "comment": "Природный массивный валун"
	})

	next_obj_id = 4
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "prop_rock_large", "name": "Скала малая",
		"position": [-35.0, 0.15, 12.0], "rotation": [0, -60.0, 0], "scale": [4.0, 3.0, 3.8],
		"color": "#52545c", "comment": "Природный валун"
	})

	# 4. Базовый дом: пол, стены, дверь и крыша
	next_obj_id = 5
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "floor_custom", "name": "Пол дома",
		"position": [-4.0, 0.15, 0.0], "rotation": [0, 0, 0], "scale": [16.0, 0.3, 12.0],
		"color": "#2c1b10", "comment": "Деревянный пол"
	})
	next_obj_id = 6
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "roof_gable", "name": "Крыша дома",
		"position": [-4.0, 3.6, 0.0], "rotation": [0, 0, 0], "scale": [16.5, 2.4, 12.5],
		"color": "#6b2222", "comment": "Двускатная крыша"
	})
	next_obj_id = 7
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "wall_long", "name": "Стена задняя",
		"position": [-4.0, 1.8, -5.8], "rotation": [0, 0, 0], "scale": [16.0, 3.6, 0.4],
		"color": "#5a524c", "comment": "Стена"
	})
	next_obj_id = 8
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "wall_long", "name": "Стена левая",
		"position": [-11.8, 1.8, 0.0], "rotation": [0, 0, 0], "scale": [0.4, 3.6, 12.0],
		"color": "#5a524c", "comment": "Стена"
	})
	next_obj_id = 9
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "wall_long", "name": "Стена правая",
		"position": [3.8, 1.8, 0.0], "rotation": [0, 0, 0], "scale": [0.4, 3.6, 12.0],
		"color": "#5a524c", "comment": "Стена"
	})
	next_obj_id = 10
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "door_electric", "name": "Электро-дверь входа",
		"position": [-4.0, 1.8, 5.8], "rotation": [0, 0, 0], "scale": [1.6, 3.6, 0.4],
		"color": "#333842", "comment": "Главная электронная дверь"
	})
	next_obj_id = 11
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "marker_player", "name": "Спавн игрока",
		"position": [-6.0, 0.0, -1.0], "rotation": [0, 0, 0], "scale": [0.8, 1.8, 0.8],
		"color": "#27e0a8", "comment": "Старт игрока"
	})
	next_obj_id = 12
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "marker_enemy", "name": "Спавн монстра",
		"position": [0.0, 0.0, -3.0], "rotation": [0, 0, 0], "scale": [0.9, 2.2, 0.9],
		"color": "#eb2626", "comment": "Старт Скинвокера"
	})
	next_obj_id = 13
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "item_battery", "name": "Батарея 1",
		"position": [-8.0, 0.4, -4.0], "rotation": [0, 0, 0], "scale": [0.3, 0.4, 0.3],
		"color": "#1fe04f", "comment": "Батарея для двери"
	})
	next_obj_id = 14
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "prop_note", "name": "Записка выжившего",
		"position": [-5.0, 0.4, 2.0], "rotation": [0, 15, 0], "scale": [0.4, 0.1, 0.3],
		"color": "#e0d6b8", "comment": "Порванная записка [E]"
	})
	next_obj_id = 15
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "prop_tree", "name": "Дерево у дома",
		"position": [10.0, 0.0, 8.0], "rotation": [0, 0, 0], "scale": [4.0, 6.0, 4.0],
		"color": "#2eb029", "comment": "Лиственное дерево"
	})
	next_obj_id = 16
	_instantiate_object_from_data({
		"id": next_obj_id, "type": "prop_dog", "name": "Пёс",
		"position": [-8.0, 0.0, 3.0], "rotation": [0, 40, 0], "scale": [0.7, 0.75, 1.1],
		"color": "#996638", "comment": "Собака"
	})

	show_notification("Создан полигон 1000x1000м: зеленый луг, дорога, машина, скалы и жилой дом!")

# ══════════════════════════════════════════════════════════════════════════════
#  Playtest Mode (Полигон тестирования механик) [7]
# ══════════════════════════════════════════════════════════════════════════════
func toggle_editor_playtest() -> void:
	if current_mode == EditorMode.EDIT:
		start_playtest()
	else:
		stop_playtest()

func reset_editor_camera_to_initial() -> void:
	var target_pos = Vector3(0.0, 8.0, 14.0)
	for child in objects_root.get_children():
		if child is Node3D and child.has_meta("obj_type") and child.get_meta("obj_type") == "marker_player":
			target_pos = child.position + Vector3(0.0, 5.0, 8.0)
			break
	cam_pivot.global_position = target_pos
	cam_yaw = 0.0
	cam_pitch = -25.0
	_update_cam_rotation()
	show_notification("🏠 Камера возвращена в исходное положение [Home]")

func start_playtest() -> void:
	current_mode = EditorMode.PLAYTEST
	saved_cam_transform = editor_cam.global_transform
	saved_pivot_pos = cam_pivot.global_position
	saved_cam_yaw = cam_yaw
	saved_cam_pitch = cam_pitch

	ui_layer.visible = false
	grid_mesh.visible = true
	selection_box.visible = false
	cancel_placement()
	_deselect_object()

	# Сохраняем полный снимок карты перед запуском теста
	playtest_saved_next_id = next_obj_id
	playtest_snapshot = _capture_scene_state()

	# Скрываем и отключаем все маркеры спавна и предметы редактора (чтобы не было второго игрока-болванки!)
	for child in objects_root.get_children():
		if child is Node3D and child.has_meta("obj_type"):
			var o_type = str(child.get_meta("obj_type"))
			if "marker" in o_type or "spawn" in o_type or "player" in o_type or "enemy" in o_type or "lumberjack" in o_type or o_type.begins_with("item_") or o_type.begins_with("custom_item_"):
				child.visible = false
				child.process_mode = Node.PROCESS_MODE_DISABLED

	# Применяем освещение для полигона (хоррор или fullbright)
	_apply_lighting_mode()

	var gm = _get_gm()
	if gm:
		gm.reset_state()

	var p_spawn = Vector3(0, 0.5, 0)
	var e_spawn = Vector3(6, 0.5, 6)
	var lj_spawn = Vector3(-2, 0.5, 1)
	var has_enemy_spawn = false
	var has_lumberjack_spawn = false

	for child in objects_root.get_children():
		if child is Node3D and child.has_meta("obj_type"):
			var o_type = child.get_meta("obj_type")
			if o_type == "marker_player":
				p_spawn = child.position
			elif o_type in ["marker_enemy", "custom_enemy"]:
				e_spawn = child.position
				has_enemy_spawn = true
			elif o_type in ["marker_lumberjack", "custom_lumberjack"]:
				lj_spawn = child.position
				has_lumberjack_spawn = true
			elif o_type in ["door", "custom_door"]:
				if gm:
					gm.door_position = child.position

	playtest_initial_player_spawn = p_spawn
	playtest_initial_enemy_spawn = e_spawn
	playtest_initial_lumberjack_spawn = lj_spawn

	show_notification("Запекание NavMesh полигона...")
	nav_region.bake_navigation_mesh(false)

	test_player = load("res://scenes/Player.tscn").instantiate() as CharacterBody3D
	test_player.position = p_spawn + Vector3(0, 0.4, 0)
	add_child(test_player)
	if gm:
		gm.player_ref = test_player
		gm.player_spawn = p_spawn

	if has_enemy_spawn:
		test_enemy = load("res://scenes/Enemy.tscn").instantiate() as CharacterBody3D
		test_enemy.position = e_spawn + Vector3(0, 0.4, 0)
		add_child(test_enemy)
		if gm:
			gm.enemy_ref = test_enemy
			gm.enemy_spawn = e_spawn

	if has_lumberjack_spawn:
		test_lumberjack = load("res://scenes/Lumberjack.tscn").instantiate() as CharacterBody3D
		test_lumberjack.position = lj_spawn + Vector3(0, 0.4, 0)
		add_child(test_lumberjack)
		if gm:
			gm.lumberjack_spawn = lj_spawn

	_spawn_playtest_items(p_spawn)

	test_ui = load("res://scenes/UI.tscn").instantiate() as CanvasLayer
	add_child(test_ui)
	if gm:
		gm.ui_ref = test_ui

	_build_playtest_overlay()

	# Запуск фонового уличного эмбиента dreamambient.mp3
	if outdoor_ambient_player == null or not is_instance_valid(outdoor_ambient_player):
		outdoor_ambient_player = AudioStreamPlayer.new()
		outdoor_ambient_player.name = "OutdoorAmbientPlayer"
		var dream_snd = _load_mp3("res://assets/dreamambient.mp3")
		if dream_snd:
			dream_snd.loop = true
			outdoor_ambient_player.stream = dream_snd
			outdoor_ambient_player.volume_db = 0.0
			outdoor_ambient_player.autoplay = true
		add_child(outdoor_ambient_player)
	elif not outdoor_ambient_player.playing:
		outdoor_ambient_player.play()

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	show_notification("Полигон запущен! [R] — в исходное, [7] — в редактор")

func _spawn_playtest_items(p_spawn: Vector3) -> void:
	var crowbar_candidates: Array = []
	var key_candidates: Dictionary = {} # key_id (int) -> Array of Node
	var battery_nodes: Array = []
	var fuse_nodes: Array = []
	var other_item_nodes: Array = []
	var has_electric_door: bool = false
	var electric_door_nodes: Array = []
	var fusebox_nodes: Array = []

	for child in objects_root.get_children():
		if child is Node3D and child.has_meta("obj_type"):
			var o_type = str(child.get_meta("obj_type"))
			if "electric" in o_type or child.has_meta("requires_power") or child.get("requires_power") == true:
				has_electric_door = true
				electric_door_nodes.append(child)
			if "fusebox" in o_type:
				fusebox_nodes.append(child)
			if o_type in ["item_crowbar", "custom_item_crowbar"]:
				crowbar_candidates.append(child)
			elif not ("door" in o_type or child.has_meta("door_type")) and ("key" in o_type or child.has_meta("key_id")):
				var kid = 1
				if child.has_meta("key_id"):
					kid = int(child.get_meta("key_id"))
				elif "silver" in o_type:
					kid = 2
				elif "emerald" in o_type:
					kid = 3
				elif "ruby" in o_type:
					kid = 4
				elif "sapphire" in o_type:
					kid = 5
				elif "rusty" in o_type:
					kid = 6
				if not key_candidates.has(kid):
					key_candidates[kid] = []
				key_candidates[kid].append(child)
			elif o_type in ["item_battery", "custom_item_battery", "battery"]:
				battery_nodes.append(child)
			elif "fuse" in o_type:
				fuse_nodes.append(child)
			elif o_type.begins_with("item_") or o_type.begins_with("custom_item_"):
				other_item_nodes.append(child)

	# 1. Спавн лома: если несколько точек с ломом, выбираем одну случайную!
	var spawned_crowbar = false
	if not crowbar_candidates.is_empty():
		var picked_cb = crowbar_candidates.pick_random()
		var it = _spawn_test_item(picked_cb.position, "crowbar")
		if it: test_items.append(it)
		spawned_crowbar = true

	# 2. Спавн ключей: для КАЖДОГО уникального ID ключа выбираем ровно 1 случайную точку!
	var spawned_key = false
	for kid in key_candidates.keys():
		var cands: Array = key_candidates[kid]
		if cands.is_empty():
			continue
		var picked_node = cands.pick_random()
		var p_pos = picked_node.position
		var placed_in_drawer = false

		# Проверяем, стоит ли ключ в мебели / тумбочке
		for storage in objects_root.get_children():
			if storage is Node3D and storage != picked_node:
				var s_type = str(storage.get_meta("obj_type", ""))
				if s_type in ["prop_nightstand", "prop_dresser", "prop_cupboard"] or storage.has_method("get_interaction_hint"):
					if storage.position.distance_to(p_pos) <= 0.85:
						var drawer = storage.find_child("Drawer", true, false)
						if not drawer: drawer = storage.find_child("Movable", true, false)
						if not drawer: drawer = storage.find_child("Door", true, false)
						if drawer:
							var it_drawer = Area3D.new()
							it_drawer.set_script(load("res://scripts/Item.gd"))
							it_drawer.set_meta("item_type", "key")
							it_drawer.set("key_id", kid)
							it_drawer.set_meta("key_id", kid)
							it_drawer.set_meta("inside_storage", true)
							drawer.add_child(it_drawer)
							it_drawer.position = Vector3(0.0, 0.04, 0.0)
							test_items.append(it_drawer)
							placed_in_drawer = true
							spawned_key = true
							break
		if not placed_in_drawer:
			var it = _spawn_test_item(p_pos, "key", kid)
			if it: test_items.append(it)
			spawned_key = true

	# 3. Спавн батарей питания
	for b_node in battery_nodes:
		var it_b = _spawn_test_item(b_node.position, "battery")
		if it_b: test_items.append(it_b)

	# 4. Спавн предохранителей
	for f_node in fuse_nodes:
		var f_name = str(f_node.get_meta("obj_type")).trim_prefix("custom_").trim_prefix("item_")
		var it_f = _spawn_test_item(f_node.position, f_name)
		if it_f: test_items.append(it_f)

	# 5. Спавн остальных предметов (бутылки, ракетницы и т.д.)
	for o_node in other_item_nodes:
		var o_name = str(o_node.get_meta("obj_type")).trim_prefix("custom_").trim_prefix("item_")
		var it_o = _spawn_test_item(o_node.position, o_name)
		if it_o: test_items.append(it_o)

	# 6. Если на карте есть электродверь, но нет электрощитка — спавним щиток рядом с дверью
	if has_electric_door and fusebox_nodes.is_empty() and not electric_door_nodes.is_empty():
		var target_door = electric_door_nodes[0]
		var door_id = 1
		if target_door.has_meta("lock_id"):
			door_id = int(target_door.get_meta("lock_id"))
		elif target_door.has_meta("key_id"):
			door_id = int(target_door.get_meta("key_id"))
		var fb = PrefabBuilder.build_prefab("prop_fusebox", Vector3(0.50, 0.68, 0.25), Color(0.25, 0.28, 0.32), false)
		var fb_pos = target_door.position + target_door.transform.basis.x * 1.5 + Vector3(0, 0.2, 0)
		fb.position = fb_pos
		fb.rotation = target_door.rotation
		fb.set_meta("lock_id", door_id)
		fb.set("lock_id", door_id)
		for ch in fb.get_children():
			ch.set_meta("lock_id", door_id)
			ch.set("lock_id", door_id)
		add_child(fb)
		test_items.append(fb)

	# 7. Резервный спавн, если на карте вообще не было лома, ключа или 3 питания для электродвери
	var total_power_on_map = battery_nodes.size() + fuse_nodes.size()
	var need_power_spawn = has_electric_door and (total_power_on_map < 3)
	if not spawned_crowbar or not spawned_key or need_power_spawn:
		var spots: Array[Vector3] = [
			Vector3(-12.0, 0.45, -6.0),
			Vector3(-10.0, 0.45,  5.0),
			Vector3(-2.0,  0.45,  1.0),
			Vector3(5.0,   0.45, -12.0),
			Vector3(12.0,  0.45, -6.0),
			Vector3(7.0,   0.45,  6.5),
			Vector3(11.0,  0.45,  3.0),
			Vector3(-5.0,  0.45,  7.0),
			Vector3(0.0,   0.45, -8.0),
			Vector3(-4.5,  0.45, -15.0)
		]
		var valid_spots: Array[Vector3] = []
		for s in spots:
			if s.distance_to(p_spawn) > 6.0:
				valid_spots.append(s)
		valid_spots.shuffle()
		if not spawned_crowbar and valid_spots.size() > 0:
			var it = _spawn_test_item(valid_spots.pop_back(), "crowbar")
			if it: test_items.append(it)
		if not spawned_key and valid_spots.size() > 0:
			var it = _spawn_test_item(valid_spots.pop_back(), "key", 1)
			if it: test_items.append(it)
		if need_power_spawn:
			var missing = 3 - total_power_on_map
			var power_items = ["fuse_red", "fuse_blue", "fuse_green", "battery"]
			for i in range(missing):
				if valid_spots.size() > 0:
					var p_item_name = power_items[i % power_items.size()]
					var it = _spawn_test_item(valid_spots.pop_back(), p_item_name)
					if it: test_items.append(it)

func restart_playtest() -> void:
	if current_mode != EditorMode.PLAYTEST:
		return

	if test_ui and is_instance_valid(test_ui) and test_ui.has_method("clear_end_screens"):
		test_ui.call("clear_end_screens")

	var gm = _get_gm()
	if gm:
		gm.reset_state(true)
		gm.player_ref = test_player
		gm.enemy_ref = test_enemy
		gm.lumberjack_ref = test_lumberjack
		gm.ui_ref = test_ui
		gm.game_ended = false

	# Очищаем временные предметы
	for it in test_items:
		if is_instance_valid(it):
			it.queue_free()
	test_items.clear()

	# Сбрасываем позицию игрока и статы без пересоздания карты
	if test_player and is_instance_valid(test_player):
		test_player.position = playtest_initial_player_spawn + Vector3(0, 0.4, 0)
		test_player.velocity = Vector3.ZERO
		test_player.rotation = Vector3.ZERO
		if test_player.has_method("reset_state"):
			test_player.call("reset_state")
		if test_player.get("held_object") != null:
			var ho = test_player.get("held_object")
			if is_instance_valid(ho):
				ho.queue_free()
			test_player.set("held_object", null)

	# Сбрасываем скинвокера
	if test_enemy and is_instance_valid(test_enemy):
		test_enemy.position = playtest_initial_enemy_spawn + Vector3(0, 0.4, 0)
		test_enemy.velocity = Vector3.ZERO
		test_enemy.rotation = Vector3.ZERO
		if test_enemy.has_method("reset_ai"):
			test_enemy.call("reset_ai")
		elif test_enemy.has_method("reset_to_patrol"):
			test_enemy.call("reset_to_patrol")
		elif "state" in test_enemy:
			test_enemy.set("state", 0)

	# Сбрасываем лесопила
	if test_lumberjack and is_instance_valid(test_lumberjack):
		test_lumberjack.position = playtest_initial_lumberjack_spawn + Vector3(0, 0.4, 0)
		test_lumberjack.velocity = Vector3.ZERO
		test_lumberjack.rotation = Vector3.ZERO
		if test_lumberjack.has_method("reset_ai"):
			test_lumberjack.call("reset_ai")
		else:
			test_lumberjack.set("current_state", 0)

	# Закрываем все открытые двери полигона и восстанавливаем их замки/питание
	for child in objects_root.get_children():
		if child is Node3D:
			if child.has_method("_toggle_simple_door") or child.has_method("interact"):
				if child.get("is_open") == true:
					child.call("_toggle_simple_door")
			child.set("door_key_unlocked", false)
			child.set("is_powered", false)
			child.set_meta("door_key_unlocked", false)
			child.set_meta("is_powered", false)
			if child.has_method("_setup_padlock"):
				child.call("_setup_padlock")
			var pnl = child.find_child("Panel", true, false)
			if pnl:
				if pnl.get("is_open") == true:
					pnl.call("_toggle_simple_door")
				pnl.set("door_key_unlocked", false)
				pnl.set("is_powered", false)
				pnl.set_meta("door_key_unlocked", false)
				pnl.set_meta("is_powered", false)
				if pnl.has_method("_setup_padlock"):
					pnl.call("_setup_padlock")
			var fb = child if child is FuseBox else null
			if not fb:
				for ch in child.get_children():
					if ch is FuseBox or ch.has_method("reset_fusebox"):
						fb = ch
						break
			if fb and fb.has_method("reset_fusebox"):
				fb.call("reset_fusebox")

	# Спавним предметы заново свежими!
	_spawn_playtest_items(playtest_initial_player_spawn)

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	show_notification("Полигон перезапущен! [R] — рестарт, [7] — редактор")

func _spawn_test_item(pos: Vector3, item_type: String, key_id: int = 0) -> Area3D:
	var area = Area3D.new()
	area.set_script(load("res://scripts/Item.gd"))
	area.set_meta("item_type", item_type)
	if key_id > 0:
		area.set("key_id", key_id)
		area.set_meta("key_id", key_id)
	area.position = pos
	add_child(area)
	return area

func _get_gm() -> Node:
	if has_node("/root/GameManager"):
		return get_node("/root/GameManager")
	return null

func _load_mp3(path: String) -> AudioStreamMP3:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStreamMP3:
			return res
	if FileAccess.file_exists(path):
		var bytes = FileAccess.get_file_as_bytes(path)
		if bytes.size() > 0:
			var s = AudioStreamMP3.new()
			s.data = bytes
			return s
	return null

func stop_playtest() -> void:
	current_mode = EditorMode.EDIT

	if outdoor_ambient_player and is_instance_valid(outdoor_ambient_player):
		outdoor_ambient_player.stop()
		outdoor_ambient_player.queue_free()
		outdoor_ambient_player = null

	if test_player and is_instance_valid(test_player):
		test_player.queue_free()
		test_player = null

	if test_enemy and is_instance_valid(test_enemy):
		test_enemy.queue_free()
		test_enemy = null

	if test_lumberjack and is_instance_valid(test_lumberjack):
		test_lumberjack.queue_free()
		test_lumberjack = null

	var gm = _get_gm()
	if gm:
		gm.player_ref = null
		gm.enemy_ref = null
		gm.reset_state()

	for it in test_items:
		if is_instance_valid(it):
			it.queue_free()
	test_items.clear()

	if test_ui and is_instance_valid(test_ui):
		test_ui.queue_free()
		test_ui = null

	if test_overlay and is_instance_valid(test_overlay):
		test_overlay.queue_free()
		test_overlay = null

	# Восстанавливаем первоначальное состояние всех объектов из снимка
	if not playtest_snapshot.is_empty():
		_restore_scene_state(playtest_snapshot)
		playtest_snapshot.clear()
		next_obj_id = playtest_saved_next_id
	else:
		for child in objects_root.get_children():
			if child is Node3D and child.has_meta("obj_type"):
				child.visible = true
				child.process_mode = Node.PROCESS_MODE_INHERIT

	# Восстанавливаем комфортный студийный свет редактора
	_apply_lighting_mode()

	# Возвращаем камеру редактора в исходное положение
	cam_pivot.global_position = saved_pivot_pos
	cam_yaw = saved_cam_yaw
	cam_pitch = saved_cam_pitch
	_update_cam_rotation()
	editor_cam.make_current()

	ui_layer.visible = true
	grid_mesh.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show_notification("Возврат в режим Редактора")

func _process_playtest_ambient(delta: float) -> void:
	if not outdoor_ambient_player or not is_instance_valid(outdoor_ambient_player) or not outdoor_ambient_player.playing:
		return
	if not test_player or not is_instance_valid(test_player):
		return

	var p_pos = test_player.global_position + Vector3.UP * 0.5
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(p_pos, p_pos + Vector3.UP * 40.0)
	query.exclude = [test_player.get_rid()]
	var result = space_state.intersect_ray(query)

	# В помещении под крышей глушим уличный эмбиент, на открытом лугу/улице звучит в полную силу
	var target_vol = -22.0 if not result.is_empty() else 0.0
	outdoor_ambient_player.volume_db = lerp(outdoor_ambient_player.volume_db, target_vol, delta * 2.5)

func _build_playtest_overlay() -> void:
	var canvas = CanvasLayer.new()
	canvas.name = "PlaytestOverlayLayer"
	add_child(canvas)
	test_overlay = canvas

	var banner = PanelContainer.new()
	banner.set_anchor_and_offset(SIDE_TOP, 0, 10)
	banner.set_anchor_and_offset(SIDE_LEFT, 0.5, -280)
	banner.set_anchor_and_offset(SIDE_RIGHT, 0.5, 280)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.14, 0.90)
	style.border_width_bottom = 2
	style.border_color = Color(0.95, 0.85, 0.2)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.set_content_margin_all(8)
	banner.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	banner.add_child(hbox)

	var lbl = Label.new()
	lbl.text = "РЕЖИМ ПОЛИГОНА (ТЕСТ)"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.2))
	lbl.add_theme_font_size_override("font_size", 13)
	hbox.add_child(lbl)

	var btn_restart = Button.new()
	btn_restart.text = "🔄 В ИСХОДНОЕ [R]"
	btn_restart.custom_minimum_size = Vector2(130, 24)
	btn_restart.add_theme_font_size_override("font_size", 12)
	btn_restart.pressed.connect(restart_playtest)
	hbox.add_child(btn_restart)

	var btn_exit = Button.new()
	btn_exit.text = "В РЕДАКТОР [7]"
	btn_exit.custom_minimum_size = Vector2(120, 24)
	btn_exit.add_theme_font_size_override("font_size", 12)
	btn_exit.pressed.connect(toggle_editor_playtest)
	hbox.add_child(btn_exit)

	canvas.add_child(banner)

# ══════════════════════════════════════════════════════════════════════════════
#  UI Редактора: Верхняя панель, Нижняя полка (Drawer), Инспектор
# ══════════════════════════════════════════════════════════════════════════════
func _build_editor_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "EditorUILayer"
	add_child(ui_layer)

	_build_top_bar()
	_build_bottom_drawer()
	_build_inspector()
	_build_hotkeys_hint()
	_build_notification()

func _build_top_bar() -> void:
	top_bar = PanelContainer.new()
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size = Vector2(0, 38)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.10, 0.96)
	style.border_width_bottom = 1
	style.border_color = Color(0.22, 0.28, 0.38)
	style.set_content_margin_all(4)
	top_bar.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(top_bar)

	var main_hb = HBoxContainer.new()
	main_hb.add_theme_constant_override("separation", 6)
	top_bar.add_child(main_hb)

	# Левая/центральная панель в ScrollContainer: никогда не вылезает за экран
	var top_scroll = ScrollContainer.new()
	top_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	top_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	top_scroll.custom_minimum_size = Vector2(100, 30)
	main_hb.add_child(top_scroll)

	var hb = HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)
	top_scroll.add_child(hb)

	# Logo
	var title = Label.new()
	title.text = " 🛠 MapForge "
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	hb.add_child(title)

	# Undo / Redo
	btn_undo = _create_top_btn("↩", "Отменить [Ctrl+Z]", _undo)
	hb.add_child(btn_undo)
	btn_redo = _create_top_btn("↪", "Повторить [Ctrl+Y]", _redo)
	hb.add_child(btn_redo)
	_update_undo_redo_buttons()

	# Каталог [Tab]
	var btn_catalog = _create_top_btn("📦 Каталог", "Открыть/закрыть каталог объектов [Tab]", _toggle_bottom_drawer)
	hb.add_child(btn_catalog)

	# Крыша
	var btn_smart_house = _create_top_btn("⛺ Крыша", "Создать двускатную крышу выделением зоны прямоугольника", func():
		start_placing_prefab("roof_gable")
	)
	btn_smart_house.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hb.add_child(btn_smart_house)

	# Сетка
	btn_grid_mode = Button.new()
	btn_grid_mode.pressed.connect(_toggle_grid_mode)
	_update_grid_button_ui()
	hb.add_child(btn_grid_mode)

	hb.add_child(_create_vsep())

	# 1, 2, 3
	var btn_act_place = _create_top_btn("1 Ставить", "Поставить объект [1]", _action_hotkey_1)
	hb.add_child(btn_act_place)

	var btn_act_del = _create_top_btn("2 Удалить", "Удалить выбранный объект [2 / Del]", _action_hotkey_2)
	btn_act_del.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45))
	hb.add_child(btn_act_del)

	var btn_act_move = _create_top_btn("3 Взять", "Поставить и выбрать / Двигать [3]", _action_hotkey_3)
	btn_act_move.add_theme_color_override("font_color", Color(0.45, 0.9, 1.0))
	hb.add_child(btn_act_move)

	hb.add_child(_create_vsep())

	# Сохранение и загрузка
	var btn_save_quick = _create_top_btn("💾 Сохранить", "Быстро сохранить карту [Ctrl+S]", quick_save_map)
	hb.add_child(btn_save_quick)

	var btn_save_as = _create_top_btn("💾 Как...", "Сохранить как новую карту [Ctrl+Shift+S]", _open_save_modal)
	hb.add_child(btn_save_as)

	var btn_home = _create_top_btn("🏠 Исходное", "Вернуть камеру в исходное положение [Home]", reset_editor_camera_to_initial)
	hb.add_child(btn_home)

	var btn_play_campaign = _create_top_btn("🚀 В игру", "Запустить прохождение на этой карте", func():
		save_map_to_json(active_map_file_path)
		var gm = _get_gm()
		if gm:
			gm.active_map_path = active_map_file_path
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	)
	hb.add_child(btn_play_campaign)

	var btn_load_custom = _create_top_btn("📂 Загрузить", "Выбрать и загрузить сохраненную карту", _open_load_modal)
	hb.add_child(btn_load_custom)

	var btn_load_orig = _create_top_btn("🏛 Прототип", "Загрузить оригинальную карту прототипа", func():
		_record_undo()
		load_map_from_json("res://assets/prototype map.json")
	)
	hb.add_child(btn_load_orig)

	var btn_clean = _create_top_btn("✨ Чистить", "Очистить и создать тестовый полигон", func():
		_record_undo()
		create_clean_polygon()
	)
	hb.add_child(btn_clean)

	var btn_help = _create_top_btn("❓ Справка [H]", "Показать список всех горячих клавиш и подсказок [H / F1]", _toggle_help_modal)
	btn_help.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hb.add_child(btn_help)

	hb.add_child(_create_vsep())

	# Свет [Ё] (Fullbright)
	btn_fullbright = Button.new()
	btn_fullbright.custom_minimum_size = Vector2(0, 26)
	btn_fullbright.add_theme_font_size_override("font_size", 11)
	var fstyle = StyleBoxFlat.new()
	fstyle.bg_color = Color(0.18, 0.20, 0.26)
	fstyle.corner_radius_top_left = 3
	fstyle.corner_radius_top_right = 3
	fstyle.corner_radius_bottom_left = 3
	fstyle.corner_radius_bottom_right = 3
	fstyle.set_content_margin_all(4)
	btn_fullbright.add_theme_stylebox_override("normal", fstyle)
	btn_fullbright.pressed.connect(toggle_fullbright)
	_update_fullbright_button_ui()
	hb.add_child(btn_fullbright)

	# Импорт 3D
	var btn_import_3d = _create_top_btn("📥 3D", "Импортировать 3D-модель (.glb, .gltf, .obj, .tscn)", _open_import_model_dialog)
	hb.add_child(btn_import_3d)

	# Фиксированная правая панель: ТЕСТ и Выход всегда на экране
	var right_hb = HBoxContainer.new()
	right_hb.add_theme_constant_override("separation", 6)
	main_hb.add_child(right_hb)

	# ТЕСТ [7]
	var btn_play = Button.new()
	btn_play.text = " ▶ ТЕСТ [7] "
	btn_play.custom_minimum_size = Vector2(85, 26)
	var play_style = StyleBoxFlat.new()
	play_style.bg_color = Color(0.14, 0.58, 0.24)
	play_style.corner_radius_top_left = 3
	play_style.corner_radius_top_right = 3
	play_style.corner_radius_bottom_left = 3
	play_style.corner_radius_bottom_right = 3
	play_style.set_content_margin_all(4)
	btn_play.add_theme_stylebox_override("normal", play_style)
	btn_play.add_theme_font_size_override("font_size", 11)
	btn_play.pressed.connect(toggle_editor_playtest)
	right_hb.add_child(btn_play)

	# Выход
	var btn_menu = _create_top_btn("✖ В Меню", "Выйти в главное меню", func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	right_hb.add_child(btn_menu)

func _create_top_btn(txt: String, tooltip: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = txt
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 11)
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.14, 0.16, 0.21)
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.set_content_margin_all(4)
	b.add_theme_stylebox_override("normal", s)
	b.pressed.connect(cb)
	return b

func _create_vsep() -> VSeparator:
	var v = VSeparator.new()
	v.add_theme_constant_override("separation", 6)
	return v

# ──────────────────────────────────────────────────────────────────────────────
#  Нижняя полка каталога (Bottom Drawer) — Увеличенная и удобная (215px)
# ──────────────────────────────────────────────────────────────────────────────
var drawer_count_lbl: Label = null

func _build_bottom_drawer() -> void:
	bottom_drawer = PanelContainer.new()
	bottom_drawer.set_anchor_and_offset(SIDE_BOTTOM, 1, -22)
	bottom_drawer.set_anchor_and_offset(SIDE_TOP, 1, -250)
	bottom_drawer.set_anchor_and_offset(SIDE_LEFT, 0, 8)
	bottom_drawer.set_anchor_and_offset(SIDE_RIGHT, 1, -8)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.11, 0.98)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 2
	style.border_color = Color(0.28, 0.45, 0.72)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.set_content_margin_all(8)
	bottom_drawer.add_theme_stylebox_override("panel", style)
	ui_layer.add_child(bottom_drawer)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	bottom_drawer.add_child(vb)

	# ── Верхняя строка панели: Поиск + Скролл категорий + Кнопка закрыть ──
	var header_hb = HBoxContainer.new()
	header_hb.add_theme_constant_override("separation", 6)
	vb.add_child(header_hb)

	drawer_count_lbl = Label.new()
	drawer_count_lbl.text = "📦 КАТАЛОГ:"
	drawer_count_lbl.add_theme_font_size_override("font_size", 11)
	drawer_count_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.3))
	header_hb.add_child(drawer_count_lbl)

	# Поле живого поиска
	search_edit = LineEdit.new()
	search_edit.placeholder_text = "🔍 Поиск объекта..."
	search_edit.custom_minimum_size = Vector2(170, 24)
	search_edit.add_theme_font_size_override("font_size", 11)
	search_edit.text_changed.connect(_on_search_query_changed)
	header_hb.add_child(search_edit)

	var search_clear_btn = Button.new()
	search_clear_btn.text = "✖"
	search_clear_btn.tooltip_text = "Сбросить поиск"
	search_clear_btn.custom_minimum_size = Vector2(24, 24)
	search_clear_btn.add_theme_font_size_override("font_size", 10)
	search_clear_btn.pressed.connect(func():
		search_edit.text = ""
		_on_search_query_changed("")
	)
	header_hb.add_child(search_clear_btn)

	# Скроллируемые категории (включая Гостиница, Ванна, Электричество, Защита)
	var cat_scroll = ScrollContainer.new()
	cat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	cat_scroll.custom_minimum_size = Vector2(100, 28)
	header_hb.add_child(cat_scroll)

	var cat_hb = HBoxContainer.new()
	cat_hb.add_theme_constant_override("separation", 4)
	cat_scroll.add_child(cat_hb)

	var categories = [
		"🏨 Гостиница", "🛁 Ванна", "⚡ Электричество", "🛡️ Защита", 
		"🧱 Архитектура", "🌳 Улица", "⭐ Все", "📁 Мои модели"
	]
	for cat in categories:
		var cat_btn = Button.new()
		cat_btn.text = cat
		cat_btn.add_theme_font_size_override("font_size", 10)
		var bs = StyleBoxFlat.new()
		bs.bg_color = Color(0.12, 0.15, 0.22)
		bs.corner_radius_top_left = 4
		bs.corner_radius_top_right = 4
		bs.corner_radius_bottom_left = 4
		bs.corner_radius_bottom_right = 4
		bs.set_content_margin_all(5)
		cat_btn.add_theme_stylebox_override("normal", bs)
		cat_btn.pressed.connect(func(): _filter_drawer_category(cat))
		cat_hb.add_child(cat_btn)

	var close_btn = Button.new()
	close_btn.text = " ✕ Свернуть [Tab] "
	close_btn.add_theme_font_size_override("font_size", 11)
	close_btn.pressed.connect(_toggle_bottom_drawer)
	header_hb.add_child(close_btn)

	# ── Всплывающая карточка предпросмотра при наведении курсора ──
	catalog_preview_card = PanelContainer.new()
	catalog_preview_card.set_anchor_and_offset(SIDE_BOTTOM, 1, -255)
	catalog_preview_card.set_anchor_and_offset(SIDE_TOP, 1, -360)
	catalog_preview_card.set_anchor_and_offset(SIDE_LEFT, 0, 14)
	catalog_preview_card.set_anchor_and_offset(SIDE_RIGHT, 0, 420)
	var prev_style = StyleBoxFlat.new()
	prev_style.bg_color = Color(0.06, 0.08, 0.13, 0.96)
	prev_style.border_width_left = 1
	prev_style.border_width_right = 1
	prev_style.border_width_top = 1
	prev_style.border_width_bottom = 1
	prev_style.border_color = Color(0.3, 0.75, 1.0, 0.8)
	prev_style.corner_radius_top_left = 6
	prev_style.corner_radius_top_right = 6
	prev_style.corner_radius_bottom_left = 6
	prev_style.corner_radius_bottom_right = 6
	prev_style.set_content_margin_all(8)
	catalog_preview_card.add_theme_stylebox_override("panel", prev_style)
	catalog_preview_card.visible = false
	ui_layer.add_child(catalog_preview_card)

	catalog_preview_lbl = Label.new()
	catalog_preview_lbl.add_theme_font_size_override("font_size", 10)
	catalog_preview_card.add_child(catalog_preview_lbl)

	# ── Нижняя область: 3D Витрина модели СЛЕВА + Скролл карточек СПРАВА ──
	var content_hb = HBoxContainer.new()
	content_hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_hb.add_theme_constant_override("separation", 10)
	vb.add_child(content_hb)

	# ── 3D Витрина модели (Showcase Viewport) ──
	var showcase_panel = PanelContainer.new()
	showcase_panel.custom_minimum_size = Vector2(215, 168)
	var sc_style = StyleBoxFlat.new()
	sc_style.bg_color = Color(0.04, 0.05, 0.08, 0.98)
	sc_style.border_width_left = 1
	sc_style.border_width_right = 1
	sc_style.border_width_top = 1
	sc_style.border_width_bottom = 1
	sc_style.border_color = Color(0.28, 0.58, 0.88, 0.85)
	sc_style.corner_radius_top_left = 6
	sc_style.corner_radius_top_right = 6
	sc_style.corner_radius_bottom_left = 6
	sc_style.corner_radius_bottom_right = 6
	sc_style.set_content_margin_all(5)
	showcase_panel.add_theme_stylebox_override("panel", sc_style)
	content_hb.add_child(showcase_panel)

	var sc_vb = VBoxContainer.new()
	sc_vb.add_theme_constant_override("separation", 2)
	showcase_panel.add_child(sc_vb)

	showcase_name_lbl = Label.new()
	showcase_name_lbl.text = "👁 3D МОДЕЛЬ"
	showcase_name_lbl.add_theme_font_size_override("font_size", 10)
	showcase_name_lbl.add_theme_color_override("font_color", Color(0.35, 0.92, 1.0))
	showcase_name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc_vb.add_child(showcase_name_lbl)

	var vp_cont = SubViewportContainer.new()
	vp_cont.stretch = true
	vp_cont.custom_minimum_size = Vector2(203, 118)
	vp_cont.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc_vb.add_child(vp_cont)

	preview_subviewport = SubViewport.new()
	preview_subviewport.size = Vector2i(203, 118)
	preview_subviewport.own_world_3d = true
	preview_subviewport.transparent_bg = false
	vp_cont.add_child(preview_subviewport)

	var sc_wenv = WorldEnvironment.new()
	var sc_env = Environment.new()
	sc_env.background_mode = Environment.BG_COLOR
	sc_env.background_color = Color(0.05, 0.06, 0.09)
	sc_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sc_env.ambient_light_color = Color(0.48, 0.52, 0.62)
	sc_env.ambient_light_energy = 1.15
	sc_wenv.environment = sc_env
	preview_subviewport.add_child(sc_wenv)

	preview_cam = Camera3D.new()
	preview_subviewport.add_child(preview_cam)
	preview_cam.position = Vector3(0, 0.8, 2.6)
	preview_cam.look_at(Vector3(0, 0, 0), Vector3.UP)

	var sc_light = DirectionalLight3D.new()
	sc_light.rotation_degrees = Vector3(-35, 45, 0)
	sc_light.light_color = Color(1.0, 0.96, 0.90)
	sc_light.light_energy = 1.4
	preview_subviewport.add_child(sc_light)

	var sc_fill = OmniLight3D.new()
	sc_fill.position = Vector3(-1.2, 1.2, 1.5)
	sc_fill.light_color = Color(0.55, 0.78, 1.0)
	sc_fill.light_energy = 0.95
	sc_fill.omni_range = 8.0
	preview_subviewport.add_child(sc_fill)

	preview_pivot = Node3D.new()
	preview_subviewport.add_child(preview_pivot)

	showcase_info_lbl = Label.new()
	showcase_info_lbl.text = "Наведите на объект"
	showcase_info_lbl.add_theme_font_size_override("font_size", 9)
	showcase_info_lbl.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78))
	showcase_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sc_vb.add_child(showcase_info_lbl)

	# ── Скролл карточек СПРАВА ──
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_hb.add_child(scroll)

	drawer_cards_container = HBoxContainer.new()
	drawer_cards_container.add_theme_constant_override("separation", 8)
	scroll.add_child(drawer_cards_container)

	_filter_drawer_category("🏨 Гостиница")

func _on_search_query_changed(new_text: String) -> void:
	current_search_query = new_text.strip_edges()
	_filter_drawer_category(current_drawer_cat)

func _filter_drawer_category(cat_name: String) -> void:
	_scan_custom_models()
	_scan_user_prefabs()
	current_drawer_cat = cat_name
	for child in drawer_cards_container.get_children():
		child.queue_free()

	var shown_count = 0
	var first_prefab_id = ""
	var q = current_search_query.to_lower()

	for prefab_id in PREFABS:
		var p_info = PREFABS[prefab_id]
		# Если пользователь ввёл поиск, ищем по всей базе префабов без ограничения категорией!
		if q == "" and not _is_prefab_in_category(prefab_id, p_info, cat_name):
			continue

		if q != "":
			var p_name = str(p_info.get("name", "")).to_lower()
			var p_comm = str(p_info.get("comment", "")).to_lower()
			var p_cat = str(p_info.get("category", "")).to_lower()
			if not (q in p_name or q in p_comm or q in p_cat or q in prefab_id.to_lower()):
				continue

		shown_count += 1
		if first_prefab_id == "":
			first_prefab_id = prefab_id

		var card = Button.new()
		card.custom_minimum_size = Vector2(150, 155)
		var sz: Vector3 = p_info.get("size", Vector3.ONE)
		var ic = p_info.get("icon", "📦")
		var nm = p_info.get("name", prefab_id)
		var cm = p_info.get("comment", "")
		card.text = "%s %s\n📏 %.1fx%.1fм\n%s" % [ic, nm, sz.x, sz.z, cm]
		card.alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_theme_font_size_override("font_size", 10)

		var cstyle = StyleBoxFlat.new()
		cstyle.bg_color = Color(0.11, 0.13, 0.19, 0.95)
		cstyle.border_width_left = 1
		cstyle.border_width_right = 1
		cstyle.border_width_top = 1
		cstyle.border_width_bottom = 1
		cstyle.border_color = Color(0.30, 0.42, 0.58)
		cstyle.corner_radius_top_left = 6
		cstyle.corner_radius_top_right = 6
		cstyle.corner_radius_bottom_left = 6
		cstyle.corner_radius_bottom_right = 6
		cstyle.set_content_margin_all(6)
		card.add_theme_stylebox_override("normal", cstyle)

		var captured_id = prefab_id
		card.mouse_entered.connect(func():
			_update_3d_preview(captured_id)
			_show_catalog_card_preview(captured_id)
		)
		card.mouse_exited.connect(func():
			_hide_catalog_card_preview()
		)
		card.pressed.connect(func():
			_update_3d_preview(captured_id)
			_hide_catalog_card_preview()
			start_placing_prefab(captured_id)
		)
		drawer_cards_container.add_child(card)

	if drawer_count_lbl:
		if q != "":
			drawer_count_lbl.text = "🔍 НАЙДЕНО: %d" % shown_count
		else:
			drawer_count_lbl.text = "📦 %s (%d):" % [cat_name, shown_count]

	# Сразу показываем 3D-модель первого предмета в витрине
	if first_prefab_id != "":
		_update_3d_preview(first_prefab_id)

func _is_prefab_in_category(prefab_id: String, p_info: Dictionary, cat_name: String) -> bool:
	if cat_name == "⭐ Все":
		return true

	var cat_lower = cat_name.to_lower()
	var p_cat = str(p_info.get("category", "")).to_lower()
	var p_name = str(p_info.get("name", "")).to_lower()
	var pid = prefab_id.to_lower()

	if "гостиниц" in cat_lower:
		return ("мебель" in p_cat or "декор" in p_cat or "картин" in p_cat or "пропс" in p_cat \
			or "гостиниц" in p_cat or "bed" in pid or "wardrobe" in pid or "table" in pid \
			or "chair" in pid or "nightstand" in pid or "carpet" in pid or "clock" in pid \
			or "sofa" in pid or "fridge" in pid or "stove" in pid or "counter" in pid \
			or "safe" in pid or "altar" in pid or "tv" in pid or "plant" in pid or "note" in pid \
			or "кровать" in p_name or "шкаф" in p_name or "стол" in p_name or "стул" in p_name \
			or "тумб" in p_name or "диван" in p_name or "ковер" in p_name or "ковёр" in p_name \
			or "часы" in p_name or "телевизор" in p_name or "картин" in p_name)

	if "ванн" in cat_lower:
		return ("ванн" in p_cat or "bath" in pid or "sink" in pid or "toilet" in pid \
			or "shower" in pid or "mirror" in pid or "pipe" in pid \
			or "ванн" in p_name or "раковин" in p_name or "унитаз" in p_name \
			or "душ" in p_name or "зеркал" in p_name)

	if "электричеств" in cat_lower or "электрик" in cat_lower:
		return ("электрик" in p_cat or "освещен" in p_cat or "switch" in pid or "light" in pid \
			or "lamp" in pid or "fuse" in pid or "battery" in pid or "generator" in pid \
			or "выключател" in p_name or "лампа" in p_name or "свет" in p_name \
			or "фонар" in p_name or "предохранител" in p_name or "батаре" in p_name \
			or "генератор" in p_name or "щиток" in p_name or "люстр" in p_name)

	if "защит" in cat_lower:
		return ("защит" in p_cat or "геймплей" in p_cat or "door" in pid or "lock" in pid or "key" in pid \
			or "crowbar" in pid or "board" in pid or "hide" in pid or "safe" in pid or "trap" in pid \
			or "дверь" in p_name or "замок" in p_name or "ключ" in p_name or "лом" in p_name \
			or "доск" in p_name or "укрыти" in p_name or "сейф" in p_name or "магнит" in p_name or "бутылк" in p_name)

	if "архитектур" in cat_lower:
		return ("архитектур" in p_cat or "блок" in p_cat or "лестниц" in p_cat \
			or "wall" in pid or "floor" in pid or "ceil" in pid or "stair" in pid \
			or "column" in pid or "roof" in pid or "window" in pid or "door_simple" in pid \
			or "стена" in p_name or "пол" in p_name or "потолок" in p_name or "лестниц" in p_name or "крыша" in p_name)

	if "улиц" in cat_lower or "природ" in cat_lower:
		return ("улиц" in p_cat or "природ" in p_cat or "животн" in p_cat \
			or "car" in pid or "road" in pid or "tree" in pid or "rock" in pid \
			or "barrel" in pid or "crate" in pid or "bench" in pid or "dog" in pid \
			or "дорог" in p_name or "машин" in p_name or "дерев" in p_name or "скал" in p_name or "скамейк" in p_name)

	if "мои модел" in cat_lower:
		return ("мои модел" in p_cat or "custom_" in pid)

	var cat_clean = cat_name.replace("⭐ ", "").replace("⚡ ", "").replace("🛋 ", "").replace("🚿 ", "").replace("🌳 ", "").replace("🪨 ", "").replace("🎮 ", "").replace("🧱 ", "").replace("💡 ", "").replace("🩸 ", "").replace("🐕 ", "").replace("🪜 ", "").replace("🏨 ", "").replace("🛁 ", "").replace("🛡️ ", "").replace("📁 ", "")
	return (cat_name in p_info.get("category", "")) or (cat_clean in p_info.get("category", ""))

func _update_3d_preview(prefab_id: String) -> void:
	if current_preview_prefab_id == prefab_id and preview_pivot and preview_pivot.get_child_count() > 0:
		return
	current_preview_prefab_id = prefab_id
	if not preview_pivot or not PREFABS.has(prefab_id):
		return

	# Очищаем предыдущую 3D модель
	for ch in preview_pivot.get_children():
		ch.queue_free()

	var data = PREFABS[prefab_id]
	var sz: Vector3 = data.get("size", Vector3.ONE)
	var col: Color = data.get("color", Color(0.8, 0.8, 0.8))
	var m_path: String = data.get("model_path", "")
	var nm = data.get("name", prefab_id)
	var ic = data.get("icon", "📦")
	var cat = data.get("category", "")

	# Создаем префаб в ghost-режиме (чистый 3D рендер)
	var model_node = PrefabBuilder.build_prefab(prefab_id, sz, col, true, m_path)
	if model_node:
		model_node.position = Vector3(0, -sz.y * 0.5, 0)
		preview_pivot.add_child(model_node)

	# Наводим камеру и подстраиваем дистанцию под размеры объекта
	if preview_cam:
		var max_dim = max(sz.x, max(sz.y, sz.z))
		var cam_dist = clamp(max_dim * 1.6 + 0.9, 1.2, 28.0)
		preview_cam.position = Vector3(0, max_dim * 0.35, cam_dist)
		preview_cam.look_at(Vector3(0, 0, 0), Vector3.UP)

	if showcase_name_lbl:
		showcase_name_lbl.text = "%s %s" % [ic, nm]
	if showcase_info_lbl:
		showcase_info_lbl.text = "📏 %.1fx%.1fx%.1fм  •  %s" % [sz.x, sz.y, sz.z, cat]

func _show_catalog_card_preview(prefab_id: String) -> void:
	if not PREFABS.has(prefab_id) or not catalog_preview_card or not catalog_preview_lbl:
		return
	var data = PREFABS[prefab_id]
	var sz: Vector3 = data.get("size", Vector3.ONE)
	var ic = data.get("icon", "📦")
	var nm = data.get("name", prefab_id)
	var cm = data.get("comment", "")
	var cat = data.get("category", "")
	catalog_preview_lbl.text = "👁 ПРЕДПРОСМОТР МОДЕЛИ:\n%s %s [%s]\n📏 Размеры: X=%.2fм | Y=%.2fм | Z=%.2fм\n📝 %s\n💡 ЛКМ - Выбрать | [R/Q] - Вращать 360°" % [
		ic, nm, cat, sz.x, sz.y, sz.z, cm
	]
	catalog_preview_card.visible = true

func _hide_catalog_card_preview() -> void:
	if catalog_preview_card:
		catalog_preview_card.visible = false

func _toggle_bottom_drawer() -> void:
	bottom_drawer.visible = not bottom_drawer.visible
	if not bottom_drawer.visible:
		_hide_catalog_card_preview()
	if bottom_drawer.visible:
		show_notification("Каталог открыт. Выберите предмет или нажмите [1/3] для установки.")


# ──────────────────────────────────────────────────────────────────────────────
#  Инспектор выделенного объекта — Панель свойств и инструментов моделирования
# ──────────────────────────────────────────────────────────────────────────────
var insp_name_lbl: Label
var insp_pos_lbl: Label
var insp_rot_lbl: Label
var insp_scale_lbl: Label
var insp_col_lbl: Label
var insp_wall_tex_section: VBoxContainer
var insp_painting_section: VBoxContainer
var insp_tree_drawing_section: VBoxContainer
var insp_door_section: VBoxContainer
var insp_door_exit_puzzles: VBoxContainer
var insp_door_cur_tex_lbl: Label
var insp_door_normal_btn: Button
var insp_door_locked_btn: Button
var insp_door_lock_row: HBoxContainer
var insp_door_lock_id_lbl: Label
var insp_door_theme_badge: Label
var insp_door_boards_btn: Button
var insp_door_wire_btn: Button
var insp_door_power_btn: Button

var insp_key_section: VBoxContainer
var insp_key_id_lbl: Label
var insp_key_theme_badge: Label

var insp_fusebox_section: VBoxContainer
var insp_fusebox_id_lbl: Label
var insp_fusebox_badge: Label

var insp_lightswitch_section: VBoxContainer
var insp_light_target_lbl: Label

func _build_inspector() -> void:
	inspector_panel = PanelContainer.new()
	inspector_panel.set_anchor_and_offset(SIDE_RIGHT, 1, -8)
	inspector_panel.set_anchor_and_offset(SIDE_LEFT, 1, -240)
	inspector_panel.set_anchor_and_offset(SIDE_TOP, 0, 42)
	inspector_panel.set_anchor_and_offset(SIDE_BOTTOM, 1, -225)


	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.10, 0.14, 0.95)
	style.border_width_left = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.4, 0.55)
	style.corner_radius_bottom_left = 6
	style.set_content_margin_all(8)
	inspector_panel.add_theme_stylebox_override("panel", style)
	inspector_panel.visible = false
	ui_layer.add_child(inspector_panel)

	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inspector_panel.add_child(scroll)

	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var header = Label.new()
	header.text = "🔍 ВЫБРАННЫЙ ОБЪЕКТ"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vb.add_child(header)

	insp_name_lbl = Label.new()
	insp_name_lbl.add_theme_font_size_override("font_size", 11)
	vb.add_child(insp_name_lbl)

	insp_pos_lbl = Label.new()
	insp_pos_lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(insp_pos_lbl)

	insp_rot_lbl = Label.new()
	insp_rot_lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(insp_rot_lbl)

	insp_scale_lbl = Label.new()
	insp_scale_lbl.add_theme_font_size_override("font_size", 10)
	vb.add_child(insp_scale_lbl)

	insp_col_lbl = Label.new()
	insp_col_lbl.add_theme_font_size_override("font_size", 10)
	insp_col_lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	vb.add_child(insp_col_lbl)

	var b_grab = Button.new()
	b_grab.text = "🖐 Переместить [3]"
	b_grab.add_theme_font_size_override("font_size", 11)
	b_grab.pressed.connect(_action_hotkey_3)
	vb.add_child(b_grab)

	var b_drop = Button.new()
	b_drop.text = "⬇ На пол [End]"
	b_drop.add_theme_font_size_override("font_size", 11)
	b_drop.add_theme_color_override("font_color", Color(0.3, 1.0, 0.6))
	b_drop.pressed.connect(_drop_selected_to_floor)
	vb.add_child(b_drop)

	# ─── Блокировка / Защита от изменений ───
	insp_lock_btn = Button.new()
	insp_lock_btn.text = "🔓 Зафиксировать объект"
	insp_lock_btn.add_theme_font_size_override("font_size", 11)
	insp_lock_btn.pressed.connect(_toggle_selected_lock)
	vb.add_child(insp_lock_btn)

	# ─── Точные координаты (X, Y, Z) ───
	var coords_header = Label.new()
	coords_header.text = "🎯 КООРДИНАТЫ (X, Y, Z)"
	coords_header.add_theme_font_size_override("font_size", 10)
	coords_header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vb.add_child(coords_header)

	var coord_row = HBoxContainer.new()
	coord_row.add_theme_constant_override("separation", 2)

	insp_spin_x = SpinBox.new()
	insp_spin_x.min_value = -1000.0
	insp_spin_x.max_value = 1000.0
	insp_spin_x.step = 0.05
	insp_spin_x.prefix = "X:"
	insp_spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_spin_x.value_changed.connect(_set_selected_coord_x)
	coord_row.add_child(insp_spin_x)

	insp_spin_y = SpinBox.new()
	insp_spin_y.min_value = -500.0
	insp_spin_y.max_value = 500.0
	insp_spin_y.step = 0.05
	insp_spin_y.prefix = "Y:"
	insp_spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_spin_y.value_changed.connect(_set_selected_coord_y)
	coord_row.add_child(insp_spin_y)

	insp_spin_z = SpinBox.new()
	insp_spin_z.min_value = -1000.0
	insp_spin_z.max_value = 1000.0
	insp_spin_z.step = 0.05
	insp_spin_z.prefix = "Z:"
	insp_spin_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_spin_z.value_changed.connect(_set_selected_coord_z)
	coord_row.add_child(insp_spin_z)

	vb.add_child(coord_row)

	# Смещение по X
	var nx_hb = HBoxContainer.new()
	nx_hb.add_theme_constant_override("separation", 2)
	var b_nx_m1 = Button.new()
	b_nx_m1.text = "X -1м"
	b_nx_m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_nx_m1.add_theme_font_size_override("font_size", 9)
	b_nx_m1.pressed.connect(func(): _nudge_selected_pos(Vector3(-1.0, 0, 0)))
	nx_hb.add_child(b_nx_m1)
	var b_nx_m01 = Button.new()
	b_nx_m01.text = "-0.1"
	b_nx_m01.add_theme_font_size_override("font_size", 9)
	b_nx_m01.pressed.connect(func(): _nudge_selected_pos(Vector3(-0.1, 0, 0)))
	nx_hb.add_child(b_nx_m01)
	var b_nx_p01 = Button.new()
	b_nx_p01.text = "+0.1"
	b_nx_p01.add_theme_font_size_override("font_size", 9)
	b_nx_p01.pressed.connect(func(): _nudge_selected_pos(Vector3(0.1, 0, 0)))
	nx_hb.add_child(b_nx_p01)
	var b_nx_p1 = Button.new()
	b_nx_p1.text = "X +1м"
	b_nx_p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_nx_p1.add_theme_font_size_override("font_size", 9)
	b_nx_p1.pressed.connect(func(): _nudge_selected_pos(Vector3(1.0, 0, 0)))
	nx_hb.add_child(b_nx_p1)
	vb.add_child(nx_hb)

	# Смещение по Y (Высота)
	var ny_hb = HBoxContainer.new()
	ny_hb.add_theme_constant_override("separation", 2)
	var b_ny_m1 = Button.new()
	b_ny_m1.text = "Y -1м"
	b_ny_m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_ny_m1.add_theme_font_size_override("font_size", 9)
	b_ny_m1.pressed.connect(func(): _change_selected_height(-1.0))
	ny_hb.add_child(b_ny_m1)
	var b_ny_m01 = Button.new()
	b_ny_m01.text = "-0.1"
	b_ny_m01.add_theme_font_size_override("font_size", 9)
	b_ny_m01.pressed.connect(func(): _change_selected_height(-0.10))
	ny_hb.add_child(b_ny_m01)
	var b_ny_p01 = Button.new()
	b_ny_p01.text = "+0.1"
	b_ny_p01.add_theme_font_size_override("font_size", 9)
	b_ny_p01.pressed.connect(func(): _change_selected_height(0.10))
	ny_hb.add_child(b_ny_p01)
	var b_ny_m025 = Button.new()
	b_ny_m025.text = "-0.25"
	b_ny_m025.add_theme_font_size_override("font_size", 9)
	b_ny_m025.pressed.connect(func(): _change_selected_height(-0.25))
	ny_hb.add_child(b_ny_m025)
	var b_ny_p025 = Button.new()
	b_ny_p025.text = "+0.25"
	b_ny_p025.add_theme_font_size_override("font_size", 9)
	b_ny_p025.pressed.connect(func(): _change_selected_height(0.25))
	ny_hb.add_child(b_ny_p025)
	var b_ny_p1 = Button.new()
	b_ny_p1.text = "Y +1м"
	b_ny_p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_ny_p1.add_theme_font_size_override("font_size", 9)
	b_ny_p1.pressed.connect(func(): _change_selected_height(1.0))
	ny_hb.add_child(b_ny_p1)
	vb.add_child(ny_hb)

	# Смещение по Z
	var nz_hb = HBoxContainer.new()
	nz_hb.add_theme_constant_override("separation", 2)
	var b_nz_m1 = Button.new()
	b_nz_m1.text = "Z -1м"
	b_nz_m1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_nz_m1.add_theme_font_size_override("font_size", 9)
	b_nz_m1.pressed.connect(func(): _nudge_selected_pos(Vector3(0, 0, -1.0)))
	nz_hb.add_child(b_nz_m1)
	var b_nz_m01 = Button.new()
	b_nz_m01.text = "-0.1"
	b_nz_m01.add_theme_font_size_override("font_size", 9)
	b_nz_m01.pressed.connect(func(): _nudge_selected_pos(Vector3(0, 0, -0.1)))
	nz_hb.add_child(b_nz_m01)
	var b_nz_p01 = Button.new()
	b_nz_p01.text = "+0.1"
	b_nz_p01.add_theme_font_size_override("font_size", 9)
	b_nz_p01.pressed.connect(func(): _nudge_selected_pos(Vector3(0, 0, 0.1)))
	nz_hb.add_child(b_nz_p01)
	var b_nz_p1 = Button.new()
	b_nz_p1.text = "Z +1м"
	b_nz_p1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_nz_p1.add_theme_font_size_override("font_size", 9)
	b_nz_p1.pressed.connect(func(): _nudge_selected_pos(Vector3(0, 0, 1.0)))
	nz_hb.add_child(b_nz_p1)
	vb.add_child(nz_hb)

	var pos_util_hb = HBoxContainer.new()
	pos_util_hb.add_theme_constant_override("separation", 2)
	var b_floor = Button.new()
	b_floor.text = "⬇ На пол [End]"
	b_floor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_floor.add_theme_font_size_override("font_size", 9)
	b_floor.pressed.connect(_drop_selected_to_floor)
	pos_util_hb.add_child(b_floor)
	var b_center = Button.new()
	b_center.text = "🎯 В центр (0, Y, 0)"
	b_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_center.add_theme_font_size_override("font_size", 9)
	b_center.pressed.connect(func():
		if selected_node and not selected_node.get_meta("is_locked", false):
			_record_undo()
			selected_node.position.x = 0.0
			selected_node.position.z = 0.0
			_update_inspector()
			_update_selection_box()
			show_notification("Объект центрирован: X=0, Z=0")
	)
	pos_util_hb.add_child(b_center)
	vb.add_child(pos_util_hb)

	# ─── Вращение на 360° по всем осям (X, Y, Z) ───
	var rot_header = Label.new()
	rot_header.text = "🔄 ВРАЩЕНИЕ НА 360° (X, Y, Z)"
	rot_header.add_theme_font_size_override("font_size", 10)
	rot_header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	vb.add_child(rot_header)

	var rot_spin_row = HBoxContainer.new()
	rot_spin_row.add_theme_constant_override("separation", 2)

	insp_spin_rot_x = SpinBox.new()
	insp_spin_rot_x.min_value = 0.0
	insp_spin_rot_x.max_value = 360.0
	insp_spin_rot_x.step = 1.0
	insp_spin_rot_x.prefix = "X:"
	insp_spin_rot_x.suffix = "°"
	insp_spin_rot_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_spin_rot_x.value_changed.connect(_set_selected_rot_x)
	rot_spin_row.add_child(insp_spin_rot_x)

	insp_spin_rot_y = SpinBox.new()
	insp_spin_rot_y.min_value = 0.0
	insp_spin_rot_y.max_value = 360.0
	insp_spin_rot_y.step = 1.0
	insp_spin_rot_y.prefix = "Y:"
	insp_spin_rot_y.suffix = "°"
	insp_spin_rot_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_spin_rot_y.value_changed.connect(_set_selected_rot_y)
	rot_spin_row.add_child(insp_spin_rot_y)

	insp_spin_rot_z = SpinBox.new()
	insp_spin_rot_z.min_value = 0.0
	insp_spin_rot_z.max_value = 360.0
	insp_spin_rot_z.step = 1.0
	insp_spin_rot_z.prefix = "Z:"
	insp_spin_rot_z.suffix = "°"
	insp_spin_rot_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_spin_rot_z.value_changed.connect(_set_selected_rot_z)
	rot_spin_row.add_child(insp_spin_rot_z)
	vb.add_child(rot_spin_row)

	# 1. Быстрые кнопки для Y (Yaw / Горизонталь)
	var lbl_rot_y = Label.new()
	lbl_rot_y.text = "Поворот Y (Yaw / Лево-Право):"
	lbl_rot_y.add_theme_font_size_override("font_size", 9)
	lbl_rot_y.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vb.add_child(lbl_rot_y)

	var rot_y_hb = HBoxContainer.new()
	rot_y_hb.add_theme_constant_override("separation", 2)
	var b_ry_m45 = Button.new()
	b_ry_m45.text = "⟲ -45° [Q]"
	b_ry_m45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_ry_m45.add_theme_font_size_override("font_size", 9)
	b_ry_m45.pressed.connect(func(): _rotate_selected(Vector3(0, -45, 0)))
	rot_y_hb.add_child(b_ry_m45)
	var b_ry_m15 = Button.new()
	b_ry_m15.text = "-15°"
	b_ry_m15.add_theme_font_size_override("font_size", 9)
	b_ry_m15.pressed.connect(func(): _rotate_selected(Vector3(0, -15, 0)))
	rot_y_hb.add_child(b_ry_m15)
	var b_ry_p15 = Button.new()
	b_ry_p15.text = "+15°"
	b_ry_p15.add_theme_font_size_override("font_size", 9)
	b_ry_p15.pressed.connect(func(): _rotate_selected(Vector3(0, 15, 0)))
	rot_y_hb.add_child(b_ry_p15)
	var b_ry_p45 = Button.new()
	b_ry_p45.text = "↻ +45° [R]"
	b_ry_p45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_ry_p45.add_theme_font_size_override("font_size", 9)
	b_ry_p45.pressed.connect(func(): _rotate_selected(Vector3(0, 45, 0)))
	rot_y_hb.add_child(b_ry_p45)
	var b_ry_180 = Button.new()
	b_ry_180.text = "180° [F]"
	b_ry_180.add_theme_font_size_override("font_size", 9)
	b_ry_180.pressed.connect(func(): _rotate_selected(Vector3(0, 180, 0)))
	rot_y_hb.add_child(b_ry_180)
	vb.add_child(rot_y_hb)

	# 2. Быстрые кнопки для X (Pitch / Наклон)
	var lbl_rot_x = Label.new()
	lbl_rot_x.text = "Наклон X (Pitch / Вперед-Назад):"
	lbl_rot_x.add_theme_font_size_override("font_size", 9)
	lbl_rot_x.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vb.add_child(lbl_rot_x)

	var rot_x_hb = HBoxContainer.new()
	rot_x_hb.add_theme_constant_override("separation", 2)
	var b_rx_m45 = Button.new()
	b_rx_m45.text = "⤸ -45°"
	b_rx_m45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_rx_m45.add_theme_font_size_override("font_size", 9)
	b_rx_m45.pressed.connect(func(): _rotate_selected(Vector3(-45, 0, 0)))
	rot_x_hb.add_child(b_rx_m45)
	var b_rx_m15 = Button.new()
	b_rx_m15.text = "-15°"
	b_rx_m15.add_theme_font_size_override("font_size", 9)
	b_rx_m15.pressed.connect(func(): _rotate_selected(Vector3(-15, 0, 0)))
	rot_x_hb.add_child(b_rx_m15)
	var b_rx_p15 = Button.new()
	b_rx_p15.text = "+15° [T]"
	b_rx_p15.add_theme_font_size_override("font_size", 9)
	b_rx_p15.pressed.connect(func(): _rotate_selected(Vector3(15, 0, 0)))
	rot_x_hb.add_child(b_rx_p15)
	var b_rx_p45 = Button.new()
	b_rx_p45.text = "⤹ +45°"
	b_rx_p45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_rx_p45.add_theme_font_size_override("font_size", 9)
	b_rx_p45.pressed.connect(func(): _rotate_selected(Vector3(45, 0, 0)))
	rot_x_hb.add_child(b_rx_p45)
	var b_rx_90 = Button.new()
	b_rx_90.text = "90°"
	b_rx_90.add_theme_font_size_override("font_size", 9)
	b_rx_90.pressed.connect(func(): _rotate_selected(Vector3(90, 0, 0)))
	rot_x_hb.add_child(b_rx_90)
	vb.add_child(rot_x_hb)

	# 3. Быстрые кнопки для Z (Roll / Боковой крен)
	var lbl_rot_z = Label.new()
	lbl_rot_z.text = "Крен Z (Roll / Боковой наклон):"
	lbl_rot_z.add_theme_font_size_override("font_size", 9)
	lbl_rot_z.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	vb.add_child(lbl_rot_z)

	var rot_z_hb = HBoxContainer.new()
	rot_z_hb.add_theme_constant_override("separation", 2)
	var b_rz_m45 = Button.new()
	b_rz_m45.text = "⤹ -45°"
	b_rz_m45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_rz_m45.add_theme_font_size_override("font_size", 9)
	b_rz_m45.pressed.connect(func(): _rotate_selected(Vector3(0, 0, -45)))
	rot_z_hb.add_child(b_rz_m45)
	var b_rz_m15 = Button.new()
	b_rz_m15.text = "-15°"
	b_rz_m15.add_theme_font_size_override("font_size", 9)
	b_rz_m15.pressed.connect(func(): _rotate_selected(Vector3(0, 0, -15)))
	rot_z_hb.add_child(b_rz_m15)
	var b_rz_p15 = Button.new()
	b_rz_p15.text = "+15° [Y]"
	b_rz_p15.add_theme_font_size_override("font_size", 9)
	b_rz_p15.pressed.connect(func(): _rotate_selected(Vector3(0, 0, 15)))
	rot_z_hb.add_child(b_rz_p15)
	var b_rz_p45 = Button.new()
	b_rz_p45.text = "⤸ +45°"
	b_rz_p45.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_rz_p45.add_theme_font_size_override("font_size", 9)
	b_rz_p45.pressed.connect(func(): _rotate_selected(Vector3(0, 0, 45)))
	rot_z_hb.add_child(b_rz_p45)
	var b_rz_90 = Button.new()
	b_rz_90.text = "90°"
	b_rz_90.add_theme_font_size_override("font_size", 9)
	b_rz_90.pressed.connect(func(): _rotate_selected(Vector3(0, 0, 90)))
	rot_z_hb.add_child(b_rz_90)
	vb.add_child(rot_z_hb)

	# Сброс углов (0, 0, 0)
	var b_reset_rot = Button.new()
	b_reset_rot.text = "⭕ Сбросить углы в 0° (0, 0, 0)"
	b_reset_rot.add_theme_font_size_override("font_size", 9)
	b_reset_rot.pressed.connect(_reset_selected_rotation)
	vb.add_child(b_reset_rot)

	# ─── Изменение размера ───
	var sz_header = Label.new()
	sz_header.text = "📐 ИЗМЕНЕНИЕ РАЗМЕРА"
	sz_header.add_theme_font_size_override("font_size", 10)
	sz_header.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vb.add_child(sz_header)

	var x_hb = HBoxContainer.new()
	var b_xm = Button.new()
	b_xm.text = "X -1м"
	b_xm.add_theme_font_size_override("font_size", 10)
	b_xm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_xm.pressed.connect(func(): _resize_selected(Vector3(-1.0, 0, 0)))
	x_hb.add_child(b_xm)
	var b_xm_fine = Button.new()
	b_xm_fine.text = "-0.2"
	b_xm_fine.add_theme_font_size_override("font_size", 10)
	b_xm_fine.pressed.connect(func(): _resize_selected(Vector3(-0.2, 0, 0)))
	x_hb.add_child(b_xm_fine)
	var b_xp_fine = Button.new()
	b_xp_fine.text = "+0.2"
	b_xp_fine.add_theme_font_size_override("font_size", 10)
	b_xp_fine.pressed.connect(func(): _resize_selected(Vector3(0.2, 0, 0)))
	x_hb.add_child(b_xp_fine)
	var b_xp = Button.new()
	b_xp.text = "X +1м"
	b_xp.add_theme_font_size_override("font_size", 10)
	b_xp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_xp.pressed.connect(func(): _resize_selected(Vector3(1.0, 0, 0)))
	x_hb.add_child(b_xp)
	vb.add_child(x_hb)

	var z_hb = HBoxContainer.new()
	var b_zm = Button.new()
	b_zm.text = "Z -1м"
	b_zm.add_theme_font_size_override("font_size", 10)
	b_zm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_zm.pressed.connect(func(): _resize_selected(Vector3(0, 0, -1.0)))
	z_hb.add_child(b_zm)
	var b_zm_fine = Button.new()
	b_zm_fine.text = "-0.2"
	b_zm_fine.add_theme_font_size_override("font_size", 10)
	b_zm_fine.pressed.connect(func(): _resize_selected(Vector3(0, 0, -0.2)))
	z_hb.add_child(b_zm_fine)
	var b_zp_fine = Button.new()
	b_zp_fine.text = "+0.2"
	b_zp_fine.add_theme_font_size_override("font_size", 10)
	b_zp_fine.pressed.connect(func(): _resize_selected(Vector3(0, 0, 0.2)))
	z_hb.add_child(b_zp_fine)
	var b_zp = Button.new()
	b_zp.text = "Z +1м"
	b_zp.add_theme_font_size_override("font_size", 10)
	b_zp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_zp.pressed.connect(func(): _resize_selected(Vector3(0, 0, 1.0)))
	z_hb.add_child(b_zp)
	vb.add_child(z_hb)

	var y_hb = HBoxContainer.new()
	var b_ym = Button.new()
	b_ym.text = "Y -0.5м"
	b_ym.add_theme_font_size_override("font_size", 10)
	b_ym.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_ym.pressed.connect(func(): _resize_selected(Vector3(0, -0.5, 0)))
	y_hb.add_child(b_ym)
	var b_ym_fine = Button.new()
	b_ym_fine.text = "-0.1"
	b_ym_fine.add_theme_font_size_override("font_size", 10)
	b_ym_fine.pressed.connect(func(): _resize_selected(Vector3(0, -0.1, 0)))
	y_hb.add_child(b_ym_fine)
	var b_yp_fine = Button.new()
	b_yp_fine.text = "+0.1"
	b_yp_fine.add_theme_font_size_override("font_size", 10)
	b_yp_fine.pressed.connect(func(): _resize_selected(Vector3(0, 0.1, 0)))
	y_hb.add_child(b_yp_fine)
	var b_yp = Button.new()
	b_yp.text = "Y +0.5м"
	b_yp.add_theme_font_size_override("font_size", 10)
	b_yp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_yp.pressed.connect(func(): _resize_selected(Vector3(0, 0.5, 0)))
	y_hb.add_child(b_yp)
	vb.add_child(y_hb)

	# Быстрые пресеты масштаба и сброс к базовому размеру
	var scale_preset_hb = HBoxContainer.new()
	var b_sc_half = Button.new()
	b_sc_half.text = "0.5x"
	b_sc_half.add_theme_font_size_override("font_size", 9)
	b_sc_half.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_sc_half.pressed.connect(func(): _scale_selected_proportional(0.5))
	scale_preset_hb.add_child(b_sc_half)

	var b_sc_reset = Button.new()
	b_sc_reset.text = "1.0x (База)"
	b_sc_reset.add_theme_font_size_override("font_size", 9)
	b_sc_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_sc_reset.pressed.connect(_reset_selected_size)
	scale_preset_hb.add_child(b_sc_reset)

	var b_sc_15 = Button.new()
	b_sc_15.text = "1.5x"
	b_sc_15.add_theme_font_size_override("font_size", 9)
	b_sc_15.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_sc_15.pressed.connect(func(): _scale_selected_proportional(1.5))
	scale_preset_hb.add_child(b_sc_15)

	var b_sc_2 = Button.new()
	b_sc_2.text = "2.0x"
	b_sc_2.add_theme_font_size_override("font_size", 9)
	b_sc_2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b_sc_2.pressed.connect(func(): _scale_selected_proportional(2.0))
	scale_preset_hb.add_child(b_sc_2)
	vb.add_child(scale_preset_hb)

	# ─── Палитра цвета (15 цветов) ───
	var col_header = Label.new()
	col_header.text = "🎨 ЦВЕТ ОБЪЕКТА"
	col_header.add_theme_font_size_override("font_size", 10)
	col_header.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	vb.add_child(col_header)

	var col_grid = GridContainer.new()
	col_grid.columns = 5
	col_grid.add_theme_constant_override("h_separation", 3)
	col_grid.add_theme_constant_override("v_separation", 3)

	var palette = [
		Color("#e74c3c"), Color("#e67e22"), Color("#f1c40f"), Color("#2ecc71"), Color("#1abc9c"),
		Color("#3498db"), Color("#9b59b6"), Color("#ffffff"), Color("#95a5a6"), Color("#34495e"),
		Color("#1e1e24"), Color("#8b4513"), Color("#4a2c11"), Color("#8b0000"), Color("#5c6b73")
	]
	for c in palette:
		var c_btn = Button.new()
		c_btn.custom_minimum_size = Vector2(38, 22)
		var c_style = StyleBoxFlat.new()
		c_style.bg_color = c
		c_style.corner_radius_top_left = 3
		c_style.corner_radius_top_right = 3
		c_style.corner_radius_bottom_left = 3
		c_style.corner_radius_bottom_right = 3
		c_style.border_width_left = 1
		c_style.border_width_top = 1
		c_style.border_width_right = 1
		c_style.border_width_bottom = 1
		c_style.border_color = Color(0.2, 0.2, 0.2, 0.6)
		c_btn.add_theme_stylebox_override("normal", c_style)
		var target_c = c
		c_btn.pressed.connect(func(): _recolor_selected(target_c))
		col_grid.add_child(c_btn)
	vb.add_child(col_grid)

	# ─── Текстура для выбранной стены ───
	insp_wall_tex_section = VBoxContainer.new()
	insp_wall_tex_section.name = "WallTexSection"
	insp_wall_tex_section.add_theme_constant_override("separation", 3)

	var tex_header = Label.new()
	tex_header.text = "🧱 ТЕКСТУРА СТЕНЫ"
	tex_header.add_theme_font_size_override("font_size", 10)
	tex_header.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	insp_wall_tex_section.add_child(tex_header)

	var tex_grid = GridContainer.new()
	tex_grid.columns = 2
	tex_grid.add_theme_constant_override("h_separation", 3)
	tex_grid.add_theme_constant_override("v_separation", 3)

	var btn_no_tex = Button.new()
	btn_no_tex.text = "◻ Без текстуры"
	btn_no_tex.add_theme_font_size_override("font_size", 9)
	btn_no_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_no_tex.pressed.connect(func(): _set_selected_wall_texture("none"))
	tex_grid.add_child(btn_no_tex)

	for t_id in TextureHelper.WALL_TEXTURES.keys():
		var t_data = TextureHelper.WALL_TEXTURES[t_id]
		var t_btn = Button.new()
		t_btn.text = t_data.get("icon", "🧱") + " " + t_data.get("name", t_id)
		t_btn.add_theme_font_size_override("font_size", 9)
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap_id = t_id
		t_btn.pressed.connect(func(): _set_selected_wall_texture(cap_id))
		tex_grid.add_child(t_btn)

	var btn_custom_tex = Button.new()
	btn_custom_tex.text = "📁 Своя текстура..."
	btn_custom_tex.add_theme_font_size_override("font_size", 9)
	btn_custom_tex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_custom_tex.pressed.connect(_open_custom_texture_dialog)
	tex_grid.add_child(btn_custom_tex)

	insp_wall_tex_section.add_child(tex_grid)
	vb.add_child(insp_wall_tex_section)

	# ─── Сюжет для выбранной картины ───
	insp_painting_section = VBoxContainer.new()
	insp_painting_section.name = "PaintingSection"
	insp_painting_section.add_theme_constant_override("separation", 3)

	var paint_header = Label.new()
	paint_header.text = "🖼 СЮЖЕТ КАРТИНЫ"
	paint_header.add_theme_font_size_override("font_size", 10)
	paint_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	insp_painting_section.add_child(paint_header)

	var paint_grid = GridContainer.new()
	paint_grid.columns = 2
	paint_grid.add_theme_constant_override("h_separation", 3)
	paint_grid.add_theme_constant_override("v_separation", 3)

	for p_id in TextureHelper.PAINTINGS.keys():
		var p_data = TextureHelper.PAINTINGS[p_id]
		var p_btn = Button.new()
		p_btn.text = p_data.get("icon", "🖼") + " " + p_data.get("name", p_id)
		p_btn.add_theme_font_size_override("font_size", 9)
		p_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap_pid = p_id
		p_btn.pressed.connect(func(): _set_selected_painting_art(cap_pid))
		paint_grid.add_child(p_btn)

	insp_painting_section.add_child(paint_grid)
	vb.add_child(insp_painting_section)

	# ─── Рисунок для выбранного ритуального дерева ───
	insp_tree_drawing_section = VBoxContainer.new()
	insp_tree_drawing_section.name = "TreeDrawingSection"
	insp_tree_drawing_section.add_theme_constant_override("separation", 3)

	var tree_draw_header = Label.new()
	tree_draw_header.text = "🌲 РИСУНОК НА ДЕРЕВЕ"
	tree_draw_header.add_theme_font_size_override("font_size", 10)
	tree_draw_header.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	insp_tree_drawing_section.add_child(tree_draw_header)

	var tree_draw_grid = GridContainer.new()
	tree_draw_grid.columns = 1
	tree_draw_grid.add_theme_constant_override("h_separation", 3)
	tree_draw_grid.add_theme_constant_override("v_separation", 3)

	for td_id in TextureHelper.TREE_DRAWINGS.keys():
		var td_data = TextureHelper.TREE_DRAWINGS[td_id]
		var td_btn = Button.new()
		td_btn.text = td_data.get("icon", "🌲") + " " + td_data.get("name", td_id)
		td_btn.add_theme_font_size_override("font_size", 9)
		td_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cap_tdid = td_id
		td_btn.pressed.connect(func(): _set_selected_tree_drawing(cap_tdid))
		tree_draw_grid.add_child(td_btn)

	insp_tree_drawing_section.add_child(tree_draw_grid)
	vb.add_child(insp_tree_drawing_section)

	# ─── Настройка двери (Текстура полотна, Ключ, Энергосчетчик, Доски) ───
	insp_door_section = VBoxContainer.new()
	insp_door_section.name = "DoorSection"
	insp_door_section.add_theme_constant_override("separation", 3)

	var door_header = Label.new()
	door_header.text = "🚪 НАСТРОЙКА ДВЕРИ"
	door_header.add_theme_font_size_override("font_size", 10)
	door_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	insp_door_section.add_child(door_header)

	insp_door_cur_tex_lbl = Label.new()
	insp_door_cur_tex_lbl.text = "Текстура: По умолчанию"
	insp_door_cur_tex_lbl.add_theme_font_size_override("font_size", 9)
	insp_door_cur_tex_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	insp_door_section.add_child(insp_door_cur_tex_lbl)

	var tex_title = Label.new()
	tex_title.text = "Текстура полотна двери:"
	tex_title.add_theme_font_size_override("font_size", 9)
	tex_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	insp_door_section.add_child(tex_title)

	var door_tex_grid = GridContainer.new()
	door_tex_grid.columns = 2
	door_tex_grid.add_theme_constant_override("h_separation", 3)
	door_tex_grid.add_theme_constant_override("v_separation", 3)

	for dt_id in TextureHelper.DOOR_TEXTURES.keys():
		var dt_data = TextureHelper.DOOR_TEXTURES[dt_id]
		var dt_btn = Button.new()
		dt_btn.text = dt_data.get("icon", "🚪") + " " + dt_data.get("name", dt_id)
		dt_btn.add_theme_font_size_override("font_size", 9)
		dt_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dt_btn.tooltip_text = dt_data.get("desc", "")
		var cap_dtid = dt_id
		dt_btn.pressed.connect(func(): _set_selected_door_texture(cap_dtid))
		door_tex_grid.add_child(dt_btn)

	insp_door_section.add_child(door_tex_grid)

	# ─── Режим двери и Замок по ID ───
	var mode_title = Label.new()
	mode_title.text = "Тип и замок двери:"
	mode_title.add_theme_font_size_override("font_size", 9)
	mode_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	insp_door_section.add_child(mode_title)

	var mode_hb = HBoxContainer.new()
	mode_hb.add_theme_constant_override("separation", 4)

	insp_door_normal_btn = Button.new()
	insp_door_normal_btn.text = "🔓 Обычная"
	insp_door_normal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_door_normal_btn.add_theme_font_size_override("font_size", 9)
	insp_door_normal_btn.pressed.connect(func(): _set_selected_door_mode(false))
	mode_hb.add_child(insp_door_normal_btn)

	insp_door_locked_btn = Button.new()
	insp_door_locked_btn.text = "🔒 С замком"
	insp_door_locked_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	insp_door_locked_btn.add_theme_font_size_override("font_size", 9)
	insp_door_locked_btn.pressed.connect(func(): _set_selected_door_mode(true))
	mode_hb.add_child(insp_door_locked_btn)
	insp_door_section.add_child(mode_hb)

	# Выбор ID замка: [-] [ ID 1 ] [+]
	insp_door_lock_row = HBoxContainer.new()
	insp_door_lock_row.add_theme_constant_override("separation", 4)

	var lock_id_title = Label.new()
	lock_id_title.text = "ID замка:"
	lock_id_title.add_theme_font_size_override("font_size", 9)
	insp_door_lock_row.add_child(lock_id_title)

	var btn_dec = Button.new()
	btn_dec.text = "◀"
	btn_dec.custom_minimum_size = Vector2(24, 20)
	btn_dec.pressed.connect(func(): _step_selected_door_lock_id(-1))
	insp_door_lock_row.add_child(btn_dec)

	insp_door_lock_id_lbl = Label.new()
	insp_door_lock_id_lbl.text = "1"
	insp_door_lock_id_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_door_lock_id_lbl.custom_minimum_size = Vector2(28, 20)
	insp_door_lock_id_lbl.add_theme_font_size_override("font_size", 10)
	insp_door_lock_row.add_child(insp_door_lock_id_lbl)

	var btn_inc = Button.new()
	btn_inc.text = "▶"
	btn_inc.custom_minimum_size = Vector2(24, 20)
	btn_inc.pressed.connect(func(): _step_selected_door_lock_id(1))
	insp_door_lock_row.add_child(btn_inc)

	insp_door_section.add_child(insp_door_lock_row)

	insp_door_theme_badge = Label.new()
	insp_door_theme_badge.text = "🟡 Золотой замок №1"
	insp_door_theme_badge.add_theme_font_size_override("font_size", 9)
	insp_door_section.add_child(insp_door_theme_badge)

	# Доски (нужен лом)
	insp_door_boards_btn = Button.new()
	insp_door_boards_btn.text = "🪵 Доски: БЕЗ ДОСОК"
	insp_door_boards_btn.add_theme_font_size_override("font_size", 9)
	insp_door_boards_btn.pressed.connect(_toggle_selected_door_boards)
	insp_door_section.add_child(insp_door_boards_btn)

	# Электрощиток с проводами (миниигра)
	insp_door_wire_btn = Button.new()
	insp_door_wire_btn.text = "⚡ Электрощиток: ВЫКЛ"
	insp_door_wire_btn.add_theme_font_size_override("font_size", 9)
	insp_door_wire_btn.pressed.connect(_toggle_selected_door_wire_panel)
	insp_door_section.add_child(insp_door_wire_btn)

	vb.add_child(insp_door_section)

	# ─── Настройка ключа ───
	insp_key_section = VBoxContainer.new()
	insp_key_section.name = "KeySection"
	insp_key_section.add_theme_constant_override("separation", 3)

	var key_header = Label.new()
	key_header.text = "🗝️ НАСТРОЙКА КЛЮЧА"
	key_header.add_theme_font_size_override("font_size", 10)
	key_header.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	insp_key_section.add_child(key_header)

	var key_row = HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 4)

	var k_id_title = Label.new()
	k_id_title.text = "ID ключа:"
	k_id_title.add_theme_font_size_override("font_size", 9)
	key_row.add_child(k_id_title)

	var k_dec = Button.new()
	k_dec.text = "◀"
	k_dec.custom_minimum_size = Vector2(24, 20)
	k_dec.pressed.connect(func(): _step_selected_key_id(-1))
	key_row.add_child(k_dec)

	insp_key_id_lbl = Label.new()
	insp_key_id_lbl.text = "1"
	insp_key_id_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_key_id_lbl.custom_minimum_size = Vector2(28, 20)
	insp_key_id_lbl.add_theme_font_size_override("font_size", 10)
	key_row.add_child(insp_key_id_lbl)

	var k_inc = Button.new()
	k_inc.text = "▶"
	k_inc.custom_minimum_size = Vector2(24, 20)
	k_inc.pressed.connect(func(): _step_selected_key_id(1))
	key_row.add_child(k_inc)

	insp_key_section.add_child(key_row)

	insp_key_theme_badge = Label.new()
	insp_key_theme_badge.text = "🟡 Золотой ключ №1"
	insp_key_theme_badge.add_theme_font_size_override("font_size", 9)
	insp_key_section.add_child(insp_key_theme_badge)

	vb.add_child(insp_key_section)

	# ─── Настройка электрощитка (питание) ───
	insp_fusebox_section = VBoxContainer.new()
	insp_fusebox_section.name = "FuseboxSection"
	insp_fusebox_section.add_theme_constant_override("separation", 3)

	var fb_header = Label.new()
	fb_header.text = "⚡ ЭЛЕКТРОЩИТОК (ПИТАНИЕ)"
	fb_header.add_theme_font_size_override("font_size", 10)
	fb_header.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
	insp_fusebox_section.add_child(fb_header)

	var fb_row = HBoxContainer.new()
	fb_row.add_theme_constant_override("separation", 4)

	var fb_id_title = Label.new()
	fb_id_title.text = "ID цепи:"
	fb_id_title.add_theme_font_size_override("font_size", 9)
	fb_row.add_child(fb_id_title)

	var fb_dec = Button.new()
	fb_dec.text = "◀"
	fb_dec.custom_minimum_size = Vector2(24, 20)
	fb_dec.pressed.connect(func(): _step_selected_fusebox_id(-1))
	fb_row.add_child(fb_dec)

	insp_fusebox_id_lbl = Label.new()
	insp_fusebox_id_lbl.text = "1"
	insp_fusebox_id_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	insp_fusebox_id_lbl.custom_minimum_size = Vector2(28, 20)
	insp_fusebox_id_lbl.add_theme_font_size_override("font_size", 10)
	fb_row.add_child(insp_fusebox_id_lbl)

	var fb_inc = Button.new()
	fb_inc.text = "▶"
	fb_inc.custom_minimum_size = Vector2(24, 20)
	fb_inc.pressed.connect(func(): _step_selected_fusebox_id(1))
	fb_row.add_child(fb_inc)

	insp_fusebox_section.add_child(fb_row)

	insp_fusebox_badge = Label.new()
	insp_fusebox_badge.text = "⚡ Питает электродверь №1 (нужно 3 питания)"
	insp_fusebox_badge.add_theme_font_size_override("font_size", 9)
	insp_fusebox_badge.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	insp_fusebox_section.add_child(insp_fusebox_badge)

	vb.add_child(insp_fusebox_section)

	# ─── Настройка выключателя света ───
	insp_lightswitch_section = VBoxContainer.new()
	insp_lightswitch_section.name = "LightSwitchSection"
	insp_lightswitch_section.add_theme_constant_override("separation", 3)

	var ls_header = Label.new()
	ls_header.text = "💡 ВЫКЛЮЧАТЕЛЬ СВЕТА"
	ls_header.add_theme_font_size_override("font_size", 10)
	ls_header.add_theme_color_override("font_color", Color(1.0, 0.95, 0.4))
	insp_lightswitch_section.add_child(ls_header)

	insp_light_target_lbl = Label.new()
	insp_light_target_lbl.text = "Привязка: Ближайшая лампа"
	insp_light_target_lbl.add_theme_font_size_override("font_size", 9)
	insp_lightswitch_section.add_child(insp_light_target_lbl)

	var ls_auto_btn = Button.new()
	ls_auto_btn.text = "🔍 Автопоиск ближайшей лампы"
	ls_auto_btn.add_theme_font_size_override("font_size", 9)
	ls_auto_btn.pressed.connect(_auto_bind_selected_lightswitch)
	insp_lightswitch_section.add_child(ls_auto_btn)

	vb.add_child(insp_lightswitch_section)

	# ─── Сохранить объект как модель в каталог ───
	var b_save_model = Button.new()
	b_save_model.text = "⭐ Сохранить в каталог [Модель]"
	b_save_model.add_theme_font_size_override("font_size", 10)
	var sm_style = StyleBoxFlat.new()
	sm_style.bg_color = Color(0.18, 0.42, 0.62)
	sm_style.corner_radius_top_left = 3
	sm_style.corner_radius_top_right = 3
	sm_style.corner_radius_bottom_left = 3
	sm_style.corner_radius_bottom_right = 3
	sm_style.set_content_margin_all(5)
	b_save_model.add_theme_stylebox_override("normal", sm_style)
	b_save_model.pressed.connect(_open_save_as_model_modal)
	vb.add_child(b_save_model)

	var b_dup = Button.new()
	b_dup.text = "📋 Дублировать [1 / Ctrl+D]"
	b_dup.add_theme_font_size_override("font_size", 10)
	b_dup.pressed.connect(_duplicate_selected)
	vb.add_child(b_dup)

	var b_del = Button.new()
	b_del.text = "🗑 Удалить [2 / Del]"
	b_del.add_theme_font_size_override("font_size", 10)
	b_del.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	b_del.pressed.connect(_action_hotkey_2)
	vb.add_child(b_del)

func _set_selected_wall_texture(texture_key: String) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur_col = selected_node.get_meta("obj_color", Color.WHITE)
	selected_node.set_meta("wall_texture", texture_key)
	TextureHelper.apply_wall_texture_to_node(selected_node, texture_key, cur_col)
	var t_name = TextureHelper.WALL_TEXTURES.get(texture_key, {}).get("name", texture_key) if texture_key != "none" else "Обычная (без текстуры)"
	show_notification("🧱 Стена: установлена текстура '%s'" % t_name)
	_update_inspector()

func _set_selected_painting_art(art_key: String) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	selected_node.set_meta("painting_art", art_key)
	TextureHelper.apply_painting_art_to_node(selected_node, art_key)
	var p_name = TextureHelper.PAINTINGS.get(art_key, {}).get("name", art_key)
	show_notification("🖼 Картина: установлен сюжет '%s'" % p_name)
	_update_inspector()

func _set_selected_tree_drawing(drawing_key: String) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	selected_node.set_meta("tree_drawing", drawing_key)
	TextureHelper.apply_tree_drawing_to_node(selected_node, drawing_key)
	var td_name = TextureHelper.TREE_DRAWINGS.get(drawing_key, {}).get("name", drawing_key)
	show_notification("🌲 Дерево: установлен рисунок '%s'" % td_name)
	_update_inspector()

func _open_custom_texture_dialog() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Изображения (*.png, *.jpg, *.webp)"])
	fd.file_selected.connect(func(path: String):
		_set_selected_wall_texture(path)
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	ui_layer.add_child(fd)
	fd.popup_centered(Vector2i(650, 420))

func _update_inspector() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		if inspector_panel:
			inspector_panel.visible = false
		return

	inspector_panel.visible = true
	var oname = selected_node.get_meta("obj_name", "Объект")
	var oid = selected_node.get_meta("obj_id", 0)
	var pos = selected_node.position
	var rot = selected_node.rotation_degrees
	var sz = selected_node.get_meta("obj_scale", Vector3.ONE)
	var col: Color = selected_node.get_meta("obj_color", Color.WHITE)

	if insp_name_lbl:
		insp_name_lbl.text = "%s (ID: %d)" % [oname, oid]
	if insp_pos_lbl:
		insp_pos_lbl.text = "Позиция: (%.2f, %.2f, %.2f)" % [pos.x, pos.y, pos.z]
	if insp_rot_lbl:
		insp_rot_lbl.text = "Поворот: (%.0f°, %.0f°, %.0f°)" % [rot.x, rot.y, rot.z]
	if insp_scale_lbl:
		insp_scale_lbl.text = "Размер: (%.2f, %.2f, %.2f)" % [sz.x, sz.y, sz.z]
	if insp_col_lbl:
		insp_col_lbl.text = "Цвет: #" + col.to_html(false)

	var is_locked = bool(selected_node.get_meta("is_locked", false))
	if insp_lock_btn:
		if is_locked:
			insp_lock_btn.text = "🔒 ЗАФИКСИРОВАН (Разблокировать)"
			insp_lock_btn.modulate = Color(1.0, 0.45, 0.45)
		else:
			insp_lock_btn.text = "🔓 Зафиксировать объект"
			insp_lock_btn.modulate = Color(1.0, 1.0, 1.0)

	_updating_inspector = true
	if insp_spin_x: insp_spin_x.value = pos.x
	if insp_spin_y: insp_spin_y.value = pos.y
	if insp_spin_z: insp_spin_z.value = pos.z
	if insp_spin_rot_x: insp_spin_rot_x.value = fposmod(rot.x, 360.0)
	if insp_spin_rot_y: insp_spin_rot_y.value = fposmod(rot.y, 360.0)
	if insp_spin_rot_z: insp_spin_rot_z.value = fposmod(rot.z, 360.0)
	_updating_inspector = false

	var o_type = str(selected_node.get_meta("obj_type", "")).to_lower()
	var is_wall_or_cube = (o_type == "cube" or "wall" in o_type or "floor" in o_type or "ceiling" in o_type)
	var is_painting = ("painting" in o_type or selected_node.has_meta("painting_art"))
	var is_tree_drawing = ("tree_carved" in o_type or "tree_warning" in o_type or "tree_claws" in o_type or selected_node.has_meta("tree_drawing"))

	var is_door = ("door" in o_type)
	var is_key = ("key" in o_type or selected_node.has_meta("key_id"))
	var is_lightswitch = ("light_switch" in o_type)

	if insp_wall_tex_section:
		insp_wall_tex_section.visible = is_wall_or_cube and not is_painting and not is_tree_drawing and not is_door
	if insp_painting_section:
		insp_painting_section.visible = is_painting
	if insp_tree_drawing_section:
		insp_tree_drawing_section.visible = is_tree_drawing

	if insp_door_section:
		insp_door_section.visible = is_door
		if is_door and selected_node:
			var cur_tex_id = str(selected_node.get_meta("door_texture", ""))
			if insp_door_cur_tex_lbl:
				if cur_tex_id != "" and TextureHelper.DOOR_TEXTURES.has(cur_tex_id):
					var dt = TextureHelper.DOOR_TEXTURES[cur_tex_id]
					insp_door_cur_tex_lbl.text = "Текстура: %s %s" % [dt.get("icon", "🚪"), dt.get("name", cur_tex_id)]
				else:
					insp_door_cur_tex_lbl.text = "Текстура: По умолчанию"

			var lock_id = int(selected_node.get_meta("lock_id", 0))
			if lock_id <= 0 and selected_node.has_meta("key_color"):
				var DoorScript = load("res://scripts/Door.gd")
				lock_id = DoorScript.color_to_lock_id(str(selected_node.get_meta("key_color")))

			var is_locked_mode = (lock_id > 0)
			if insp_door_normal_btn:
				insp_door_normal_btn.modulate = Color(0.6, 1.0, 0.6) if not is_locked_mode else Color(0.7, 0.7, 0.7)
			if insp_door_locked_btn:
				insp_door_locked_btn.modulate = Color(1.0, 0.8, 0.3) if is_locked_mode else Color(0.7, 0.7, 0.7)

			if insp_door_lock_row:
				insp_door_lock_row.visible = is_locked_mode
			if insp_door_theme_badge:
				insp_door_theme_badge.visible = is_locked_mode
				if is_locked_mode:
					var DoorScript = load("res://scripts/Door.gd")
					var th = DoorScript.get_lock_theme(lock_id)
					if insp_door_lock_id_lbl:
						insp_door_lock_id_lbl.text = "%d" % lock_id
					insp_door_theme_badge.text = "%s %s замок №%d (нужен ключ №%d)" % [th["icon"], th["name"], lock_id, lock_id]
					insp_door_theme_badge.add_theme_color_override("font_color", th["color"])

			var bds = bool(selected_node.get_meta("requires_boards", false))
			if insp_door_boards_btn:
				insp_door_boards_btn.text = "🪵 Доски: " + ("ЗАКОЛОЧЕНА (нужен лом)" if bds else "БЕЗ ДОСОК")
				insp_door_boards_btn.modulate = Color(1.0, 0.85, 0.5) if bds else Color(1.0, 1.0, 1.0)

			var wp = bool(selected_node.get_meta("requires_wire_panel", false))
			if insp_door_wire_btn:
				insp_door_wire_btn.text = "⚡ Электрощиток: " + ("ВКЛЮЧЕН (миниигра)" if wp else "ВЫКЛЮЧЕН")
				insp_door_wire_btn.modulate = Color(0.4, 0.9, 1.0) if wp else Color(1.0, 1.0, 1.0)

	if insp_key_section:
		insp_key_section.visible = is_key
		if is_key and selected_node:
			var k_id = int(selected_node.get_meta("key_id", 1))
			if insp_key_id_lbl:
				insp_key_id_lbl.text = "%d" % k_id
			if insp_key_theme_badge:
				var DoorScript = load("res://scripts/Door.gd")
				var th = DoorScript.get_lock_theme(k_id)
				insp_key_theme_badge.text = "%s %s ключ №%d (для двери №%d)" % [th["icon"], th["name"], k_id, k_id]
				insp_key_theme_badge.add_theme_color_override("font_color", th["color"])

	var is_fusebox = ("fusebox" in o_type or (selected_node.has_meta("item_type") and "fusebox" in str(selected_node.get_meta("item_type"))))
	if insp_fusebox_section:
		insp_fusebox_section.visible = is_fusebox
		if is_fusebox and selected_node:
			var fb_id = int(selected_node.get_meta("lock_id", 1))
			if insp_fusebox_id_lbl:
				insp_fusebox_id_lbl.text = "%d" % fb_id
			if insp_fusebox_badge:
				insp_fusebox_badge.text = "⚡ Питает электродверь №%d (нужно 3 питания)" % fb_id

	if insp_lightswitch_section:
		insp_lightswitch_section.visible = is_lightswitch
		if is_lightswitch and selected_node:
			var target_id = selected_node.get_meta("target_light_id", -1)
			if insp_light_target_lbl:
				insp_light_target_lbl.text = "Привязка: " + ("Ближайшая лампа" if target_id < 0 else "Лампа ID: %d" % target_id)

func _step_selected_fusebox_id(delta_id: int) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur_id = int(selected_node.get_meta("lock_id", 1))
	var new_id = clamp(cur_id + delta_id, 1, 30)
	selected_node.set_meta("lock_id", new_id)
	selected_node.set("lock_id", new_id)
	show_notification("⚡ Щиток: цепь №%d (питает электродверь №%d)" % [new_id, new_id])
	_update_inspector()

func _set_selected_door_texture(tex_key: String) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	selected_node.set_meta("door_texture", tex_key)
	TextureHelper.apply_door_texture_to_node(selected_node, tex_key)
	_update_inspector()
	var dt_info = TextureHelper.DOOR_TEXTURES.get(tex_key, {})
	var t_name = dt_info.get("name", tex_key)
	show_notification("🚪 Текстура двери: %s" % t_name)

func _set_selected_door_mode(is_locked_mode: bool) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var pnl = selected_node.find_child("Panel", true, false)
	if is_locked_mode:
		var cur_id = int(selected_node.get_meta("lock_id", 0))
		if cur_id <= 0: cur_id = 1
		selected_node.set_meta("lock_id", cur_id)
		selected_node.set("lock_id", cur_id)
		if pnl:
			pnl.set_meta("lock_id", cur_id)
			pnl.set("lock_id", cur_id)
		if selected_node.has_method("_setup_padlock"):
			selected_node.call("_setup_padlock")
		if pnl and pnl.has_method("_setup_padlock"):
			pnl.call("_setup_padlock")
		var DoorScript = load("res://scripts/Door.gd")
		var th = DoorScript.get_lock_theme(cur_id)
		show_notification("🔒 Дверь: заперта на %s замок №%d" % [th["name"], cur_id])
	else:
		selected_node.set_meta("lock_id", 0)
		selected_node.set("lock_id", 0)
		selected_node.set_meta("key_color", "none")
		selected_node.set("required_key_color", "none")
		if pnl:
			pnl.set_meta("lock_id", 0)
			pnl.set("lock_id", 0)
			pnl.set_meta("key_color", "none")
			pnl.set("required_key_color", "none")
		if selected_node.has_method("_setup_padlock"):
			selected_node.call("_setup_padlock")
		if pnl and pnl.has_method("_setup_padlock"):
			pnl.call("_setup_padlock")
		show_notification("🔓 Дверь: обычная, без замка")
	_update_inspector()

func _step_selected_door_lock_id(delta_id: int) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur_id = int(selected_node.get_meta("lock_id", 1))
	var new_id = clamp(cur_id + delta_id, 1, 30)
	selected_node.set_meta("lock_id", new_id)
	selected_node.set("lock_id", new_id)
	var pnl = selected_node.find_child("Panel", true, false)
	if pnl:
		pnl.set_meta("lock_id", new_id)
		pnl.set("lock_id", new_id)
	if selected_node.has_method("_setup_padlock"):
		selected_node.call("_setup_padlock")
	if pnl and pnl.has_method("_setup_padlock"):
		pnl.call("_setup_padlock")
	var DoorScript = load("res://scripts/Door.gd")
	var th = DoorScript.get_lock_theme(new_id)
	show_notification("🔒 Замок двери: %s №%d" % [th["name"], new_id])
	_update_inspector()

func _toggle_selected_door_wire_panel() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur = bool(selected_node.get_meta("requires_wire_panel", false))
	var new_val = not cur
	selected_node.set_meta("requires_wire_panel", new_val)
	selected_node.set("requires_wire_panel", new_val)
	var pnl = selected_node.find_child("Panel", true, false)
	if pnl:
		pnl.set_meta("requires_wire_panel", new_val)
		pnl.set("requires_wire_panel", new_val)
	if selected_node.has_method("_setup_wire_panel"):
		selected_node.call("_setup_wire_panel")
	if pnl and pnl.has_method("_setup_wire_panel"):
		pnl.call("_setup_wire_panel")
	_update_inspector()
	show_notification("⚡ Электрощиток: %s" % ("включен (миниигра проводов)" if new_val else "выключен"))

func _step_selected_key_id(delta_id: int) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur_id = int(selected_node.get_meta("key_id", 1))
	var new_id = clamp(cur_id + delta_id, 1, 30)
	selected_node.set_meta("key_id", new_id)
	selected_node.set("key_id", new_id)
	var DoorScript = load("res://scripts/Door.gd")
	var th = DoorScript.get_lock_theme(new_id)
	_recolor_key_node(selected_node, th, new_id)
	show_notification("🗝️ Ключ: %s №%d (для двери №%d)" % [th["name"], new_id, new_id])
	_update_inspector()

func _recolor_key_node(node: Node, th: Dictionary, new_id: int) -> void:
	for ch in node.find_children("*", "MeshInstance3D", true, false):
		if ch.name != "Col" and ch.mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = th["color"]
			mat.metallic = th["metallic"]
			mat.roughness = th["roughness"]
			mat.emission_enabled = true
			mat.emission = th["emission"]
			mat.emission_energy_multiplier = 0.85
			ch.mesh.material = mat
	for l in node.find_children("*", "OmniLight3D", true, false):
		l.light_color = th["emission"]
	var lbl = node.find_child("KeyNumber", true, false)
	if lbl and lbl is Label3D:
		lbl.text = "№%d" % new_id

func _set_selected_door_key(key_color: String) -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	selected_node.set_meta("key_color", key_color)
	selected_node.set("required_key_color", key_color)
	var pnl = selected_node.find_child("Panel", true, false)
	if pnl:
		pnl.set_meta("key_color", key_color)
		pnl.set("required_key_color", key_color)
	_update_inspector()
	show_notification("🚪 Дверь: требуется %s ключ" % key_color)

func _toggle_selected_door_power() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur = bool(selected_node.get_meta("requires_power", false))
	var new_pwr = not cur
	selected_node.set_meta("requires_power", new_pwr)
	selected_node.set("requires_power", new_pwr)
	selected_node.set("has_electric_meter", new_pwr)
	var pnl = selected_node.find_child("Panel", true, false)
	if pnl:
		pnl.set_meta("requires_power", new_pwr)
		pnl.set("requires_power", new_pwr)
		pnl.set("has_electric_meter", new_pwr)
	var meter = selected_node.find_child("ElectricMeter", true, false)
	if not meter and pnl:
		meter = pnl.find_child("ElectricMeter", true, false)
	if meter:
		meter.visible = new_pwr
	_update_inspector()
	show_notification("⚡ Энергосчетчик: %s" % ("требуется батарея" if new_pwr else "без питания"))

func _toggle_selected_door_boards() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur = bool(selected_node.get_meta("requires_boards", false))
	var new_bds = not cur
	selected_node.set_meta("requires_boards", new_bds)
	selected_node.set("requires_boards", new_bds)
	var pnl = selected_node.find_child("Panel", true, false)
	if pnl:
		pnl.set_meta("requires_boards", new_bds)
		pnl.set("requires_boards", new_bds)
	var b_node = selected_node.find_child("Boards", true, false)
	if not b_node and pnl:
		b_node = pnl.find_child("Boards", true, false)
	if b_node:
		b_node.visible = new_bds
	_update_inspector()
	show_notification("🪵 Доски: %s" % ("заколочена (нужен лом)" if new_bds else "чистая дверь"))

func _auto_bind_selected_lightswitch() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	selected_node.set_meta("target_light_id", -1)
	selected_node.set("target_light_id", -1)
	if selected_node.has_method("_bind_light"):
		selected_node.call("_bind_light")
	_update_inspector()
	show_notification("💡 Выключатель: режим автопривязки к ближайшей лампе")

func _toggle_selected_lock() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	_record_undo()
	var cur_locked = bool(selected_node.get_meta("is_locked", false))
	var new_locked = not cur_locked
	selected_node.set_meta("is_locked", new_locked)
	if new_locked:
		is_grabbing_selected = false
		is_mouse_dragging = false
		pending_mouse_drag = false
		show_notification("🔒 Объект зафиксирован (защищен от любых изменений)")
	else:
		show_notification("🔓 Фиксация снята — объект можно редактировать")
	_update_selection_box()
	_update_inspector()

func _set_selected_coord_x(val: float) -> void:
	if _updating_inspector or not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован!")
		_update_inspector()
		return
	_record_undo()
	selected_node.position.x = val
	_update_selection_box()
	if insp_pos_lbl:
		insp_pos_lbl.text = "Позиция: (%.2f, %.2f, %.2f)" % [selected_node.position.x, selected_node.position.y, selected_node.position.z]

func _set_selected_coord_y(val: float) -> void:
	if _updating_inspector or not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован!")
		_update_inspector()
		return
	_record_undo()
	selected_node.position.y = val
	_update_selection_box()
	if insp_pos_lbl:
		insp_pos_lbl.text = "Позиция: (%.2f, %.2f, %.2f)" % [selected_node.position.x, selected_node.position.y, selected_node.position.z]

func _set_selected_coord_z(val: float) -> void:
	if _updating_inspector or not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован!")
		_update_inspector()
		return
	_record_undo()
	selected_node.position.z = val
	_update_selection_box()
	if insp_pos_lbl:
		insp_pos_lbl.text = "Позиция: (%.2f, %.2f, %.2f)" % [selected_node.position.x, selected_node.position.y, selected_node.position.z]

func _set_selected_rot_x(val: float) -> void:
	if _updating_inspector or not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован!")
		_update_inspector()
		return
	_record_undo()
	selected_node.rotation_degrees.x = fposmod(val, 360.0)
	selected_node.set_meta("obj_rotation", selected_node.rotation_degrees)
	_update_selection_box()
	if insp_rot_lbl:
		insp_rot_lbl.text = "Поворот: (%.0f°, %.0f°, %.0f°)" % [selected_node.rotation_degrees.x, selected_node.rotation_degrees.y, selected_node.rotation_degrees.z]

func _set_selected_rot_y(val: float) -> void:
	if _updating_inspector or not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован!")
		_update_inspector()
		return
	_record_undo()
	selected_node.rotation_degrees.y = fposmod(val, 360.0)
	selected_node.set_meta("obj_rotation", selected_node.rotation_degrees)
	_update_selection_box()
	if insp_rot_lbl:
		insp_rot_lbl.text = "Поворот: (%.0f°, %.0f°, %.0f°)" % [selected_node.rotation_degrees.x, selected_node.rotation_degrees.y, selected_node.rotation_degrees.z]

func _set_selected_rot_z(val: float) -> void:
	if _updating_inspector or not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован!")
		_update_inspector()
		return
	_record_undo()
	selected_node.rotation_degrees.z = fposmod(val, 360.0)
	selected_node.set_meta("obj_rotation", selected_node.rotation_degrees)
	_update_selection_box()
	if insp_rot_lbl:
		insp_rot_lbl.text = "Поворот: (%.0f°, %.0f°, %.0f°)" % [selected_node.rotation_degrees.x, selected_node.rotation_degrees.y, selected_node.rotation_degrees.z]

func _reset_selected_rotation() -> void:
	if not selected_node or not is_instance_valid(selected_node):
		return
	if selected_node.get_meta("is_locked", false):
		show_notification("🔒 Объект зафиксирован!")
		return
	_record_undo()
	selected_node.rotation_degrees = Vector3.ZERO
	selected_node.set_meta("obj_rotation", Vector3.ZERO)
	_update_selection_box()
	_update_inspector()
	show_notification("🔄 Поворот сброшен в 0° (0, 0, 0)")

# ──────────────────────────────────────────────────────────────────────────────
#  Подсказка горячих клавиш внизу экрана
# ──────────────────────────────────────────────────────────────────────────────
func _build_hotkeys_hint() -> void:
	hotkeys_hint = Label.new()
	hotkeys_hint.text = "[1] Ставить | [2] Удалить | [3] Взять | [R/Q] Поворот Y | [T] Наклон X | [Y] Крен Z | [Стрелки/PgUp/PgDn] X/Y/Z | [End] На пол | [Tab] Каталог | [7] ТЕСТ"
	hotkeys_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hotkeys_hint.set_anchor_and_offset(SIDE_BOTTOM, 1, -3)
	hotkeys_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hotkeys_hint.add_theme_font_size_override("font_size", 10)
	hotkeys_hint.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	ui_layer.add_child(hotkeys_hint)

# ──────────────────────────────────────────────────────────────────────────────
#  Всплывающее уведомление
# ──────────────────────────────────────────────────────────────────────────────
func _build_notification() -> void:
	notification_label = Label.new()
	notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notification_label.set_anchor_and_offset(SIDE_TOP, 0, 52)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.add_theme_font_size_override("font_size", 13)
	notification_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	notification_label.visible = false
	ui_layer.add_child(notification_label)

func show_notification(text: String, duration: float = 3.5) -> void:
	if not notification_label:
		return
	notification_label.text = text
	notification_label.visible = true
	notif_timer = duration

func _exit_tree() -> void:
	get_window().theme = null
