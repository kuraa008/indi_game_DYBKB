extends Cutscene

# ПРОЛОГ · «Предыстория» — текстом на чёрном экране (так разрешает сюжет).
# Отец и два брата в хижине за городом; отец заболел, Сэм отпустил Итана учиться,
# Итан уехал и так ни разу больше и не приехал. Прошло четыре года.
# Дальше — геймплей «Обычный день» (квартира Итана).

const PAGES := [
	["Когда-то в старой хижине за городом жили трое: отец и два брата.\nСтарший — Сэм, младший — Итан.", 6.0],
	["Однажды отец тяжело заболел, и за ним нужно было присматривать каждый день.\nА Итану пора было уезжать учиться.", 6.0],
	["", 0.0],
	["Итан послушал брата и уехал в город.", 3.6],
	["Сначала он иногда навещал их. Потом всё реже.\nДни сменялись неделями, недели — годами,\nи Итан так ни разу больше и не приехал.", 7.0],
]

var _text: Label


func build() -> void:
	set_env(Color(0, 0, 0), Color(0, 0, 0), 0.0)
	_text = _label("", 24, Color(0.86, 0.87, 0.9), 1)
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = 160
	_text.offset_right = -160
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.modulate.a = 0.0
	_ui.add_child(_text)


func _page(text: String, hold: float) -> void:
	if skipping:
		return
	_text.text = text
	var tw := create_tween()
	tw.tween_property(_text, "modulate:a", 1.0, 1.2)
	tw.tween_interval(hold)
	tw.tween_property(_text, "modulate:a", 0.0, 1.0)
	await wait(hold + 2.4)


func run() -> void:
	black(1.0)
	var wind := loop("amb_night_wind", -24.0, 3.0)
	var clock := loop("clock_tick", -30.0, 3.0)
	await wait(1.2)
	for i in PAGES.size():
		if i == 2:
			# — Езжай, брат. Учись. За отцом я сам присмотрю.
			await line("sam_go", "СЭМ", "Езжай, брат. Учись. За отцом я сам присмотрю.", 1.0)
			continue
		await _page(PAGES[i][0], PAGES[i][1])
	stop(clock, 2.0)
	await card("ПРОШЛО ЧЕТЫРЕ ГОДА", "", 2.6, 1.2)
	stop(wind, 1.5)
	await wait(1.0)
