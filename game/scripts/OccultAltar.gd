class_name OccultAltar
extends StaticBody3D

# ══════════════════════════════════════════════════════════════════════════════
#  OccultAltar.gd — Ритуальный алтарь со свечами, черепом и дневником
#  • Свечи можно задувать [E], погружая комнату в спасительную тьму
#  • Дневник исследователя содержит ключевые подсказки (шифр сейфа и слабости монстра)
# ══════════════════════════════════════════════════════════════════════════════

@export var candles_lit: bool = true
@export var safe_code_clue: String = "742"

var candle_lights: Array[OmniLight3D] = []
var candle_flames: Array[MeshInstance3D] = []
var sfx_player: AudioStreamPlayer3D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta("item_type", "occult_altar")
	if GameManager and GameManager.safe_code != "":
		safe_code_clue = GameManager.safe_code
	_find_candles()
	_setup_audio()
	_update_candles()

func _find_candles() -> void:
	for ch in get_children():
		if ch is OmniLight3D and "candle" in ch.name.to_lower():
			candle_lights.append(ch)
		elif ch is MeshInstance3D and "flame" in ch.name.to_lower():
			candle_flames.append(ch)
		for sub in ch.get_children():
			if sub is OmniLight3D and "candle" in sub.name.to_lower():
				candle_lights.append(sub)
			elif sub is MeshInstance3D and "flame" in sub.name.to_lower():
				candle_flames.append(sub)

func _setup_audio() -> void:
	sfx_player = AudioStreamPlayer3D.new()
	sfx_player.max_distance = 15.0
	sfx_player.unit_size = 3.0
	add_child(sfx_player)

func interact(_opener: Node3D = null) -> void:
	if candles_lit:
		candles_lit = false
		_play_sfx("res://assets/audio/blow_candle.wav")
		_update_candles()

		var note_text = "ДНЕВНИК ИССЛЕДОВАТЕЛЯ:\n\n«Оно чувствует каждый вздох, но слепо к тем, кто затаил дыхание... Его плоть горит от электрических искр! А в железном сейфе заперт синий предохранитель. Шифр от сейфа: [ %s ]. Не оглядывайся...»" % safe_code_clue
		if GameManager.ui_ref and GameManager.ui_ref.has_method("show_note"):
			GameManager.ui_ref.call("show_note", note_text)
		elif GameManager.ui_ref:
			GameManager.ui_ref.call("show_hint", note_text, 8.0)
	else:
		candles_lit = true
		_update_candles()
		if GameManager.ui_ref:
			GameManager.ui_ref.call("show_hint", "Свечи на алтаре снова зажжены.", 2.5)

func _update_candles() -> void:
	for l in candle_lights:
		l.visible = candles_lit
	for f in candle_flames:
		f.visible = candles_lit

func _play_sfx(path: String) -> void:
	var s = ResourceLoader.load(path)
	if s and sfx_player:
		sfx_player.stream = s
		sfx_player.play()
