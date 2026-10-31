extends Node

# ──────────────────────────────────────────────
#  BreathSystem — Задержка дыхания (Q / RMB / Space)
#  • 15 секунд запаса кислорода
#  • При зажатии: полная тишина (враг не слышит дыхания)
#  • При отпускании: обязательная передышка (выдох и вдох 1.8с) — нельзя спамить нажал-отпустил!
#  • При окончании кислорода (0с): принудительный шоковый выдох с шумом,
#    игрок ВЫВАЛИВАЕТСЯ из укрытия наружу и привлекает монстра!
# ──────────────────────────────────────────────

const MAX_OXYGEN:          float = 15.0
const OXYGEN_REGEN:        float = 2.6
const HOLD_DRAIN:          float = 1.0
const RECOVERY_COOLDOWN:    float = 1.8
const EXHAUSTION_DURATION: float = 3.0

const NOISE_SILENT:  float = 0.0
const NOISE_NORMAL:  float = 0.45
const NOISE_EXHALE:  float = 0.95

var oxygen:          float = MAX_OXYGEN
var is_holding:      bool  = false
var hold_duration:   float = 0.0
var recovery_timer:  float = 0.0
var exhale_active:   bool  = false
var exhale_timer:    float = 0.0
var noise_level:     float = NOISE_NORMAL

var breath_timer:    float = 0.0
var audio_player:    AudioStreamPlayer = null

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "BreathAudio"
	audio_player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	add_child(audio_player)

func _process(delta: float) -> void:
	var p = GameManager.player_ref if GameManager else null
	var is_player_hiding: bool = (p != null and is_instance_valid(p) and p.get("is_hiding") == true)

	# 1. Если активен принудительный шоковый выдох (кислород кончился)
	if exhale_active:
		exhale_timer -= delta
		recovery_timer = maxf(recovery_timer, exhale_timer)
		noise_level = NOISE_EXHALE
		is_holding = false
		hold_duration = 0.0
		# Кислород начинает плавно восстанавливаться только во второй половине выдоха
		if exhale_timer < EXHAUSTION_DURATION * 0.5:
			oxygen = minf(MAX_OXYGEN, oxygen + OXYGEN_REGEN * delta * 0.8)
		if exhale_timer <= 0.0:
			exhale_active = false
			noise_level = NOISE_NORMAL
		return

	# 2. Таймер передышки (кулдаун после отпускания кнопки):
	# Нельзя мгновенно снова задержать дыхание — нужно сделать вдох!
	if recovery_timer > 0.0:
		recovery_timer -= delta
		noise_level = NOISE_NORMAL
		is_holding = false
		hold_duration = 0.0
		oxygen = minf(MAX_OXYGEN, oxygen + OXYGEN_REGEN * delta)
		return

	# ТОЛЬКО В ШКАФУ / УКРЫТИИ! Вне укрытия задержка дыхания не активируется
	if not is_player_hiding:
		if is_holding:
			is_holding = false
			hold_duration = 0.0
			noise_level = NOISE_NORMAL
		oxygen = minf(MAX_OXYGEN, oxygen + OXYGEN_REGEN * delta)
		return

	# 3. Считывание клавиш задержки дыхания (Q на ПК / Y на геймпаде) — ТОЛЬКО В УКРЫТИИ
	var joy_holding = Input.is_joy_button_pressed(0, JOY_BUTTON_Y)
	var wants_hold = Input.is_action_pressed("hold_breath") or Input.is_key_pressed(KEY_Q) or joy_holding

	if wants_hold:
		if not is_holding and oxygen < 0.6:
			# Слишком мало кислорода, чтобы начать новую задержку дыхания без передышки
			pass
		else:
			# Игрок задерживает дыхание
			is_holding = true
			hold_duration += delta
			noise_level = NOISE_SILENT
			oxygen = maxf(0.0, oxygen - HOLD_DRAIN * delta)

			if oxygen <= 0.0:
				oxygen = 0.0
				_involuntary_exhale()
				return
	else:
		# Если игрок отпустил клавишу ПОСЛЕ того, как держал её:
		if is_holding and hold_duration > 0.3:
			recovery_timer = RECOVERY_COOLDOWN
			_play_exhale_sound()
		is_holding = false
		hold_duration = 0.0
		noise_level = NOISE_NORMAL
		oxygen = minf(MAX_OXYGEN, oxygen + OXYGEN_REGEN * delta)

func _involuntary_exhale() -> void:
	exhale_active = true
	exhale_timer = EXHAUSTION_DURATION
	recovery_timer = EXHAUSTION_DURATION
	is_holding = false
	hold_duration = 0.0
	noise_level = NOISE_EXHALE

	_play_gasp_sound()

	var p = GameManager.player_ref if GameManager else null
	if p and is_instance_valid(p):
		var cough_pos = p.global_position
		# 1. Принудительно выталкиваем игрока из укрытия наружу
		if p.get("is_hiding") == true:
			if p.has_method("force_eject_from_hiding"):
				p.call("force_eject_from_hiding")
			else:
				p.call("exit_hiding")
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "💥 КИСЛОРОД ЗАКОНЧИЛСЯ! Вы с громким кашлем вывалились из укрытия!", 4.0)

		# 2. Громкий звук удушья и кашля, слышный на 50 метров
		GameManager.emit_noise(cough_pos, 50.0, "player_cough")

		# 3. Привлекаем Скинвокера напрямую к месту кашля
		if GameManager.enemy_ref and is_instance_valid(GameManager.enemy_ref):
			if GameManager.enemy_ref.has_method("alert_player_cough"):
				GameManager.enemy_ref.call("alert_player_cough", cough_pos)

		# 4. Привлекаем Деда-Лесопила к месту кашля
		if GameManager.lumberjack_ref and is_instance_valid(GameManager.lumberjack_ref):
			if GameManager.lumberjack_ref.has_method("alert_player_cough"):
				GameManager.lumberjack_ref.call("alert_player_cough", cough_pos)

func _play_gasp_sound() -> void:
	if not audio_player:
		return
	if ResourceLoader.exists("res://assets/audio/player_cough_gasp.wav"):
		var stream = load("res://assets/audio/player_cough_gasp.wav")
		if stream:
			audio_player.stream = stream
			audio_player.volume_db = 6.0
			audio_player.pitch_scale = randf_range(0.96, 1.04)
			audio_player.play()
			return
	var sample_rate = 44100
	var duration = 1.15
	var sample_count = int(sample_rate * duration)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var env = 0.0
		if t < 0.35:
			env = sin((t / 0.35) * PI) * 0.95
		else:
			var t2 = (t - 0.35) / 0.80
			env = sin(t2 * PI) * 0.75 * exp(-t2 * 1.5)
		var noise = (randf() * 2.0 - 1.0) * 0.65
		var tone = sin(t * 220.0 * TAU) * 0.20 + sin(t * 110.0 * TAU) * 0.15
		var sample = (noise + tone) * env
		var s16 = int(clampf(sample, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, s16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = pcm
	audio_player.stream = wav
	audio_player.volume_db = 4.0
	audio_player.play()

func _play_exhale_sound() -> void:
	if not audio_player:
		return
	var sample_rate = 44100
	var duration = 0.45
	var sample_count = int(sample_rate * duration)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / float(sample_rate)
		var env = sin((t / duration) * PI) * exp(-t * 3.5)
		var noise = (randf() * 2.0 - 1.0) * 0.35
		var s16 = int(clampf(noise * env, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, s16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.data = pcm
	audio_player.stream = wav
	audio_player.volume_db = -8.0
	audio_player.play()

func get_noise_level() -> float: return noise_level
func get_oxygen_ratio() -> float: return oxygen / MAX_OXYGEN
func get_oxygen_seconds() -> float: return oxygen
func get_recovery_timer() -> float: return recovery_timer
func is_breath_held() -> bool: return is_holding and not exhale_active and recovery_timer <= 0.0 and oxygen > 0.0
func is_in_recovery() -> bool: return recovery_timer > 0.0 or exhale_active
