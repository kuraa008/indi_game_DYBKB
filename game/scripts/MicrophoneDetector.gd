extends Node

# ─────────────────────────────────────────────────────────
#  MicrophoneDetector.gd
#  Захват реального звука с микрофона игрока в Godot 4.
#  Если игрок говорит, кричит или громко вздыхает —
#  Скинвокер слышит реальный звук и идет на источник шума!
#  Клавиша [M] — быстрое включение / отключение микрофона.
# ─────────────────────────────────────────────────────────

var bus_name: String = "MicrophoneCapture"
var bus_index: int = -1
var capture_effect: AudioEffectCapture = null
var mic_player: AudioStreamPlayer = null

var smoothed_volume: float = 0.0
var noise_cooldown: float = 0.0
var is_capturing: bool = false
var noise_floor: float = 0.25
var loud_time: float = 0.0
const MIN_LOUD_TIME: float = 0.22

func _ready() -> void:
	call_deferred("_setup_microphone_bus")

func _setup_microphone_bus() -> void:
	# 1. Проверяем или создаем отдельную шину для микрофона
	bus_index = AudioServer.get_bus_index(bus_name)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, bus_name)
		# ОБЯЗАТЕЛЬНО заглушаем шину, чтобы микрофон не транслировался в колонки игрока (нет эха и свиста!)
		AudioServer.set_bus_mute(bus_index, true)

	# 2. Ищем или добавляем AudioEffectCapture
	for i in range(AudioServer.get_bus_effect_count(bus_index)):
		var eff = AudioServer.get_bus_effect(bus_index, i)
		if eff is AudioEffectCapture:
			capture_effect = eff
			break

	if not capture_effect:
		capture_effect = AudioEffectCapture.new()
		AudioServer.add_bus_effect(bus_index, capture_effect)

	# 3. Создаем AudioStreamPlayer для микрофонного ввода
	mic_player = AudioStreamPlayer.new()
	mic_player.name = "MicAudioPlayer"
	mic_player.bus = bus_name
	mic_player.stream = AudioStreamMicrophone.new()
	add_child(mic_player)

	# Запускаем захват
	if GameManager.mic_enabled:
		mic_player.play()
		is_capturing = true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			var active = GameManager.toggle_mic()
			if mic_player:
				if active:
					if not mic_player.playing:
						mic_player.play()
					is_capturing = true
				else:
					mic_player.stop()
					is_capturing = false
					if capture_effect:
						capture_effect.clear_buffer()
			if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
				var desc = "ВКЛЮЧЕН (Монстр слышит ваш голос!)" if active else "ВЫКЛЮЧЕН (Тишина)"
				GameManager.ui_ref.call("show_hint", "Микрофон: %s [M]" % desc, 2.8)
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if noise_cooldown > 0.0:
		noise_cooldown -= delta

	if not GameManager.mic_enabled or not capture_effect or not is_capturing:
		smoothed_volume = lerp(smoothed_volume, 0.0, delta * 10.0)
		GameManager.mic_volume = smoothed_volume
		return

	var frames_avail = capture_effect.get_frames_available()
	var peak: float = 0.0

	if frames_avail > 0:
		var buffer = capture_effect.get_buffer(frames_avail)
		# Сканируем буфер с шагом для максимальной производительности
		var step = max(1, buffer.size() / 128)
		for i in range(0, buffer.size(), step):
			var sample = buffer[i]
			var mag = max(abs(sample.x), abs(sample.y))
			if mag > peak:
				peak = mag

	_process_level(peak, delta)

# Вынесено отдельно, чтобы логику порога можно было проверить без настоящего микрофона
func _process_level(peak: float, delta: float) -> void:
	# Плавная фильтрация громкости для HUD
	if peak > smoothed_volume:
		smoothed_volume = lerp(smoothed_volume, peak, 0.65)
	else:
		smoothed_volume = lerp(smoothed_volume, peak, delta * 12.0)

	GameManager.mic_volume = smoothed_volume

	# Шум комнаты: быстро опускаемся к тишине и медленно привыкаем к постоянному гулу
	var follow: float = 2.0 if smoothed_volume < noise_floor else 0.12
	noise_floor = lerpf(noise_floor, smoothed_volume, minf(1.0, delta * follow))

	# Срабатываем на звук заметно громче фона, и только если он длится, а не на щелчок
	var threshold: float = maxf(GameManager.mic_threshold, noise_floor * 2.2 + 0.035)
	var triggered: bool = smoothed_volume >= threshold
	loud_time = loud_time + delta if triggered else 0.0

	var player = GameManager.player_ref
	var in_cutscene: bool = is_instance_valid(player) and player.get("is_in_cutscene") == true
	if triggered and loud_time >= MIN_LOUD_TIME and noise_cooldown <= 0.0 and not in_cutscene:
		noise_cooldown = 0.35
		_on_mic_noise_detected(smoothed_volume)

	# Отправляем статус в UI
	GameManager.emit_signal("mic_status_changed", GameManager.mic_enabled, smoothed_volume, triggered)

func _on_mic_noise_detected(vol: float) -> void:
	if not is_instance_valid(GameManager.player_ref) or GameManager.is_godmode:
		return
	var player = GameManager.player_ref
	if player.get("is_dead") == true:
		return

	var player_pos = player.global_position
	var sound_radius = clamp((vol - noise_floor) * 150.0, 8.0, 48.0)

	# Оповещаем монстра и создаем визуальную акустическую волну!
	GameManager.emit_noise(player_pos, sound_radius, "mic")
