extends "res://scripts/ApartmentKit.gd"

# Пасхалки: пять казахских книг спрятаны по квартире Итана.
# Навёл прицел → [ЛКМ / E] → открывается карточка книги, внизу счётчик найденных.

const BOOKS := [
	{
		"title": "Абай жолы",
		"author": "Мұхтар Әуезов",
		"text": "Толстый том с потёртым корешком. Роман-эпопея о жизни поэта Абая Кунанбаева и казахской степи XIX века.",
		"cover": Color(0.42, 0.12, 0.1),
		"size": Vector3(0.15, 0.225, 0.05),
		# Книжная полка в комнате, третья полка снизу, стоит корешком наружу
		"pos": Vector3(2.075, 1.2325, -2.12),
		"rot": Vector3(0, 90, 0),
		"stand": true,
	},
	{
		"title": "Қара сөздер",
		"author": "Абай Құнанбайұлы",
		"text": "Тонкая книжка «Слова назидания». Сорок пять коротких размышлений Абая о людях, труде и совести.",
		"cover": Color(0.12, 0.2, 0.34),
		"size": Vector3(0.13, 0.2, 0.018),
		# Кухонный стол
		"pos": Vector3(6.42, 0.76, -3.26),
		"rot": Vector3(0, 28, 0),
		"stand": false,
	},
	{
		"title": "Көшпенділер",
		"author": "Ілияс Есенберлин",
		"text": "Первый том трилогии «Кочевники». Ханы, батыры и войны казахских жузов.",
		"cover": Color(0.5, 0.36, 0.14),
		"size": Vector3(0.14, 0.21, 0.04),
		# Тумбочка у кровати, рядом с лампой
		"pos": Vector3(-0.31, 0.61, -5.96),
		"rot": Vector3(0, -12, 0),
		"stand": false,
	},
	{
		"title": "Қан мен тер",
		"author": "Әбдіжәміл Нұрпейісов",
		"text": "Трилогия «Кровь и пот» о рыбаках Арала. Кто-то читал её на ночь и уронил под кровать.",
		"cover": Color(0.36, 0.08, 0.08),
		"size": Vector3(0.14, 0.215, 0.045),
		# На полу, наполовину под кроватью
		"pos": Vector3(-1.02, 0.012, -4.07),
		"rot": Vector3(0, 63, 0),
		"stand": false,
	},
	{
		"title": "Менің атым Қожа",
		"author": "Бердібек Соқпақбаев",
		"text": "Повесть «Меня зовут Кожа» про озорного мальчишку. Обложка зачитана до дыр, видно, любимая с детства.",
		"cover": Color(0.16, 0.36, 0.22),
		"size": Vector3(0.13, 0.2, 0.022),
		# Комод с телевизором, на краю справа
		"pos": Vector3(0.9, 0.562, -2.02),
		"rot": Vector3(0, -14, 0),
		"stand": false,
	},
]

static var found := {}


func _ready() -> void:
	name = "ApartmentBooks"
	for i in range(BOOKS.size()):
		_build_book(i)
	var scene := get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("Main.tscn"):
		found.clear()
		_add_spots.call_deferred()


func _book_xf(b: Dictionary) -> Transform3D:
	var sz: Vector3 = b["size"]
	var rot: Vector3 = b["rot"]
	if b["stand"]:
		# Стоит на полке: высота вверх, обложки смотрят по ±X, корешок (-X книги) — в комнату (+Z)
		return _xf(b["pos"], rot) * _xf(Vector3(0, sz.y * 0.5, 0))
	return _xf(b["pos"], rot) * _xf(Vector3(0, sz.z * 0.5, 0), Vector3(-90, 0, 0))


# Книга в своей системе: обложка в плоскости XY (X — ширина, Y — высота), толщина по Z
func _build_book(i: int) -> void:
	var b: Dictionary = BOOKS[i]
	var sz: Vector3 = b["size"]
	var cover: Color = b["cover"]
	var paper := Color(0.84, 0.79, 0.66)
	var gold := Color(0.78, 0.62, 0.28)
	_base = _book_xf(b)
	var c := 0.0025
	_bx(Vector3(sz.x, sz.y, c), Vector3(0, 0, sz.z * 0.5 - c * 0.5), cover)
	_bx(Vector3(sz.x, sz.y, c), Vector3(0, 0, -sz.z * 0.5 + c * 0.5), cover)
	_bx(Vector3(c * 1.6, sz.y, sz.z), Vector3(-sz.x * 0.5 + c * 0.8, 0, 0), cover.darkened(0.12))
	_bx(Vector3(sz.x - 0.008, sz.y - 0.008, sz.z - c * 2.0), Vector3(0.002, 0, 0), paper)
	# Золотой орнамент: рамка на обложке и полосы на корешке
	for y in [-1.0, 1.0]:
		_bx(Vector3(sz.x - 0.026, 0.004, 0.0008), Vector3(0.004, y * (sz.y * 0.5 - 0.016), sz.z * 0.5 + 0.0004), gold)
		_bx(Vector3(0.0008, sz.y * 0.9, 0.004), Vector3(-sz.x * 0.5 - 0.0004, 0, y * (sz.z * 0.5 - 0.004)), gold)
		_bx(Vector3(0.0009, 0.005, sz.z * 0.8), Vector3(-sz.x * 0.5 - 0.0005, y * (sz.y * 0.5 - 0.02), 0), gold)
	for x in [-1.0, 1.0]:
		_bx(Vector3(0.004, sz.y - 0.032, 0.0008), Vector3(0.004 + x * (sz.x * 0.5 - 0.017), 0, sz.z * 0.5 + 0.0004), gold)
	_flush(_vmat(0.75))
	var at := _book_xf(b)
	var title := Label3D.new()
	title.text = str(b["title"]).to_upper()
	title.font_size = 56
	title.pixel_size = 0.00042 * clampf(sz.x / 0.14, 0.85, 1.1)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.width = (sz.x - 0.035) / title.pixel_size
	title.modulate = gold.lightened(0.2)
	title.outline_size = 0
	title.shaded = true
	title.double_sided = false
	add_child(title)
	title.transform = at * Transform3D(Basis.IDENTITY, Vector3(0.004, sz.y * 0.12, sz.z * 0.5 + 0.0012))
	var author := Label3D.new()
	author.text = str(b["author"])
	author.font_size = 32
	author.pixel_size = title.pixel_size
	author.modulate = gold
	author.outline_size = 0
	author.shaded = true
	author.double_sided = false
	add_child(author)
	author.transform = at * Transform3D(Basis.IDENTITY, Vector3(0.004, -sz.y * 0.3, sz.z * 0.5 + 0.0012))
	# Название вдоль корешка
	var spine := Label3D.new()
	spine.text = str(b["title"]).to_upper()
	spine.font_size = 36
	spine.pixel_size = minf(0.00045, sz.z * 0.55 / 36.0)
	spine.modulate = gold.lightened(0.15)
	spine.outline_size = 0
	spine.shaded = true
	spine.double_sided = false
	add_child(spine)
	spine.transform = at * Transform3D(Basis(Vector3.UP, -PI * 0.5) * Basis(Vector3.BACK, PI * 0.5), Vector3(-sz.x * 0.5 - 0.0012, 0, 0))


func _add_spots() -> void:
	var spot_script := load("res://scripts/StorySpot.gd")
	for i in range(BOOKS.size()):
		var b: Dictionary = BOOKS[i]
		var sz: Vector3 = b["size"]
		var spot: Area3D = spot_script.new()
		var side := Vector3(maxf(sz.x, 0.16), maxf(sz.y, 0.16), maxf(sz.z, 0.08))
		spot.setup("Посмотреть книгу «%s»" % b["title"], _read.bind(i), side)
		spot.set_meta("instant_use", true)
		add_child(spot)
		spot.transform = _book_xf(b)


func _read(i: int) -> void:
	var b: Dictionary = BOOKS[i]
	found[i] = true
	var text := "«%s»\n%s\n\n%s\n\nПасхалка: найдено %d из %d" % [b["title"], b["author"], b["text"], found.size(), BOOKS.size()]
	if found.size() == BOOKS.size():
		text += "\nВсе казахские книги найдены!"
	GameManager.open_note(text, null)
	var st: AudioStream = load("res://assets/audio/cutscenes/sheet_flutter.wav")
	if st:
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.volume_db = -12.0
		add_child(p)
		p.play()
		p.finished.connect(p.queue_free)
