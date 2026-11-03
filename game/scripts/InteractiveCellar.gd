extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  InteractiveCellar.gd — Интерактивный наклонный уличный вход в подвал
#  • Двустворчатые распашные деревянные створки на кованых петлях
#  • Плавный поворот створок наружу под наклоном (Twin Hinge Tween)
#  • Аутентичный звук тяжелого скрипа векового дерева и чугунного лязга
#  • Оповещение монстра (слух) при распахивании
# ══════════════════════════════════════════════════════════════════════════════

@export var is_open: bool = false
@export var open_angle: float = 100.0
@export var move_duration: float = 0.65
@export var make_sound_alert: bool = true
@export var alert_radius: float = 18.0

var left_hinge: Node3D = null
var right_hinge: Node3D = null
var is_animating: bool = false
var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("cellar_entrances")
	_setup_hinges()
	_setup_audio()

func _setup_hinges() -> void:
	left_hinge = get_node_or_null("LeftHinge")
	right_hinge = get_node_or_null("RightHinge")
	if not left_hinge or not right_hinge:
		# Поиск в подузлах (например, внутри DoorAssembly)
		var da = get_node_or_null("DoorAssembly")
		if da:
			left_hinge = da.get_node_or_null("LeftHinge")
			right_hinge = da.get_node_or_null("RightHinge")

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "CellarAudio"
	audio_player.max_distance = 32.0
	audio_player.unit_size = 6.0
	add_child(audio_player)

func _is_locked_on_map2() -> bool:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("is_level_2"):
		return bool(gm.call("is_level_2"))
	elif gm and "active_map_path" in gm:
		var p = str(gm.get("active_map_path")).to_lower()
		if "карта_2" in p or "karta_2" in p or "карта_6" in p or "karta_6" in p or "level2" in p or "level_2" in p or "2level" in p:
			return true
	var tree = get_tree()
	if tree and tree.current_scene and "map_json_path" in tree.current_scene:
		var p2 = str(tree.current_scene.get("map_json_path")).to_lower()
		if "карта_2" in p2 or "karta_2" in p2 or "карта_6" in p2 or "karta_6" in p2 or "level2" in p2 or "level_2" in p2 or "2level" in p2:
			return true
	return false

func _play_locked_sound() -> void:
	if not audio_player:
		return
	var sample_count = int(44100 * 0.25)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for idx in range(sample_count):
		var t = float(idx) / 44100.0
		var env = exp(-t * 22.0)
		var rattle = sin(t * 310.0 * TAU) * 0.45 + sin(t * 760.0 * TAU) * 0.35 + (randf() * 2.0 - 1.0) * 0.15
		var sample = rattle * env
		var val16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(idx * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()

func get_interaction_hint() -> String:
	if _is_locked_on_map2():
		return "[] Земной люк заперт снаружи"
	var action = "Закрыть подвал" if is_open else "Открыть двери подвала"
	return "[ЛКМ / RT] " + action

func interact(opener: Node = null) -> void:
	if _is_locked_on_map2():
		_play_locked_sound()
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.ui_ref and gm.ui_ref.has_method("show_hint"):
			gm.ui_ref.call("show_hint", "Земной люк наглухо заперт снаружи и пока не открывается...", 3.0)
		return

	if is_animating:
		return
	is_open = not is_open
	_play_audio(is_open)

	if make_sound_alert:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("emit_noise"):
			gm.call("emit_noise", global_position, alert_radius)

	_animate(is_open)

func _animate(opening: bool) -> void:
	if not left_hinge or not right_hinge:
		return
	is_animating = true
	var tw = create_tween()
	tw.set_parallel(true)

	var left_target = -open_angle if opening else 0.0
	var right_target = open_angle if opening else 0.0

	tw.tween_property(left_hinge, "rotation_degrees:z", left_target, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(right_hinge, "rotation_degrees:z", right_target, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.finished.connect(func(): is_animating = false)

func _play_audio(opening: bool) -> void:
	if not audio_player:
		return
	var sample_count = int(44100 * (0.60 if opening else 0.35))
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)

	for idx in range(sample_count):
		var t = float(idx) / 44100.0
		var env = exp(-t * (4.2 if opening else 9.5))
		var sample = 0.0
		if opening:
			# Тяжелый гулкий скрип вековых досок и ржавых чугунных петель
			var f_creak = 115.0 + sin(t * 24.0) * 80.0 + sin(t * 115.0) * 40.0
			var creak = sin(t * f_creak * TAU) * 0.55 + sin(t * (f_creak * 2.2) * TAU) * 0.35
			var friction = (randf() * 2.0 - 1.0) * 0.30
			sample = (creak + friction) * env
		else:
			# Оглушительный глухой удар тяжелых створок и лязг засова
			var thud = sin(t * 65.0 * TAU) * 0.85
			var iron_clang = sin(t * 880.0 * TAU) * 0.45 * exp(-t * 22.0)
			sample = (thud + iron_clang) * env

		var val16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(idx * 2, val16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.pitch_scale = randf_range(0.92, 1.08)
	audio_player.play()
