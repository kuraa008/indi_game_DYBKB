extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  InteractiveStorage.gd — Интерактивные ящики, полки, тумбочки и шкафчики
#  • Плавное выдвижение ящиков вперед (Translation Tween)
#  • Распахивание дверок на петлях (Rotation Tween)
#  • Процедурный реалистичный звук скольжения дерева и закрытия
#  • Оповещение ИИ (слух врага) при открытии
# ══════════════════════════════════════════════════════════════════════════════

@export var is_open: bool = false
@export var open_offset: Vector3 = Vector3(0.0, 0.0, 0.28)   ## Смещение при открытии (для выдвижных ящиков)
@export var open_rotation: Vector3 = Vector3.ZERO             ## Поворот при открытии (для распашных дверок)
@export var item_label: String = "ящик"                       ## "ящик", "комод", "шкафчик", "полку"
@export var move_duration: float = 0.32
@export var make_sound_alert: bool = true
@export var alert_radius: float = 9.0

var target_node: Node3D = null
var initial_pos: Vector3 = Vector3.ZERO
var initial_rot: Vector3 = Vector3.ZERO
var is_animating: bool = false
var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	add_to_group("interactive_storage")
	_setup_target()
	_setup_audio()

func _setup_target() -> void:
	if target_node == null:
		if has_node("Drawer"):
			target_node = get_node("Drawer") as Node3D
		elif has_node("Door"):
			target_node = get_node("Door") as Node3D
		elif has_node("Movable"):
			target_node = get_node("Movable") as Node3D
		else:
			target_node = self

	if target_node:
		initial_pos = target_node.position
		initial_rot = target_node.rotation_degrees

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "StorageAudio"
	audio_player.max_distance = 18.0
	audio_player.unit_size = 3.5
	add_child(audio_player)

func get_interaction_hint() -> String:
	var action = "Закрыть " if is_open else "Открыть "
	return "[ЛКМ / RT] " + action + item_label

func interact(opener: Node = null) -> void:
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
	if not target_node:
		return
	is_animating = true
	var tw = create_tween()
	tw.set_parallel(true)

	var dest_pos = initial_pos + (open_offset if opening else Vector3.ZERO)
	var dest_rot = initial_rot + (open_rotation if opening else Vector3.ZERO)

	tw.tween_property(target_node, "position", dest_pos, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if open_rotation != Vector3.ZERO:
		tw.tween_property(target_node, "rotation_degrees", dest_rot, move_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	tw.finished.connect(func(): is_animating = false)

func _play_audio(opening: bool) -> void:
	if not audio_player:
		return
	var sample_count = int(44100 * (0.32 if opening else 0.22))
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)

	for idx in range(sample_count):
		var t = float(idx) / 44100.0
		var env = exp(-t * (7.5 if opening else 16.0))
		var sample = 0.0
		if opening:
			# Деревянный шелест / трение выдвигающегося ящика
			var f1 = 200.0 + sin(t * 35.0) * 75.0
			var tone = sin(t * f1 * TAU) * 0.35
			var noise = (randf() * 2.0 - 1.0) * 0.30
			sample = (tone + noise) * env
		else:
			# Мягкий щелчок и глухой стук закрытия фасада
			var thud = sin(t * 110.0 * TAU) * 0.75
			var click = sin(t * 1600.0 * TAU) * 0.35 * exp(-t * 45.0)
			sample = (thud + click) * env

		var val16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(idx * 2, val16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()
