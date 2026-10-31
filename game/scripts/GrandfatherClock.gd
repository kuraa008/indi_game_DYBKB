class_name GrandfatherClock
extends StaticBody3D

# ══════════════════════════════════════════════════════════════════════════════
#  GrandfatherClock.gd — Дедушкины напольные часы с маятником и тайником
#  • Качающийся латунный маятник с непрерывным механическим тиканьем
#  • Глухой набат колоколов раз в 2.5 минуты, созывающий Скинвокера на звук
#  • Застеклённая дверца-тайник: при открытии игрок находит спрятанный предмет
# ══════════════════════════════════════════════════════════════════════════════

@export var has_fuse_loot: bool = true
@export var chime_interval: float = 140.0

var pendulum: Node3D = null
var clock_door: Node3D = null
var tick_audio: AudioStreamPlayer3D = null
var bell_audio: AudioStreamPlayer3D = null

var elapsed: float = 0.0
var chime_timer: float = 0.0
var is_door_open: bool = false
var is_looted: bool = false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta("item_type", "grandfather_clock")
	pendulum = get_node_or_null("Pendulum")
	clock_door = get_node_or_null("ClockDoor")
	_setup_audio()

func _setup_audio() -> void:
	tick_audio = AudioStreamPlayer3D.new()
	tick_audio.max_distance = 16.0
	tick_audio.unit_size = 2.5
	var tick_s = ResourceLoader.load("res://assets/audio/clock_tick.wav")
	if tick_s:
		tick_audio.stream = tick_s
		if tick_s is AudioStreamWAV:
			tick_s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(tick_audio)

	bell_audio = AudioStreamPlayer3D.new()
	bell_audio.max_distance = 45.0
	bell_audio.unit_size = 8.0
	var bell_s = ResourceLoader.load("res://assets/audio/clock_bell.wav")
	if bell_s:
		bell_audio.stream = bell_s
	add_child(bell_audio)

	if tick_audio.stream:
		tick_audio.play()

func _process(delta: float) -> void:
	elapsed += delta
	chime_timer += delta

	# Качание маятника
	if pendulum:
		pendulum.rotation_degrees.z = sin(elapsed * 3.14159) * 16.0

	# Периодический бой колоколов
	if chime_timer >= chime_interval:
		chime_timer = 0.0
		_chime_bell()

func _chime_bell() -> void:
	if bell_audio:
		bell_audio.pitch_scale = randf_range(0.95, 1.05)
		bell_audio.play()

	# Создаем звуковое событие для монстра
	GameManager.emit_signal("noise_made", global_position, 40.0)

	if GameManager.ui_ref:
		GameManager.ui_ref.call("show_hint", "БОЙ ЧАСОВ! Гул набата разносится по особняку...", 4.0)

func interact(_opener: Node3D = null) -> void:
	if not is_door_open:
		is_door_open = true
		if clock_door:
			var tw = create_tween()
			tw.tween_property(clock_door, "rotation_degrees:y", 85.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		if has_fuse_loot and not is_looted:
			is_looted = true
			GameManager.pick_up_fuse("green")
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "В тайнике напольных часов найден ЗЕЛЁНЫЙ предохранитель!", 4.5)
		else:
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Дверца часов открыта. Внутри пусто.", 2.5)
	else:
		is_door_open = false
		if clock_door:
			var tw = create_tween()
			tw.tween_property(clock_door, "rotation_degrees:y", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if GameManager.ui_ref:
			GameManager.ui_ref.call("show_hint", "Дверца часов закрыта.", 2.0)
