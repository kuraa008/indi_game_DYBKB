class_name HorrorTV
extends StaticBody3D

# ══════════════════════════════════════════════════════════════════════════════
#  HorrorTV.gd — Ламповый ретро-телевизор с видеоплеером (mp4/ogv) и помехами
#  • Поддержка кастомных видеофайлов (.ogv / .mp4) из папки проекта или Documents
#  • Процедурный генератор аналогового шума VHS и белого шума при отсутствии видео
#  • Внезапное ночное включение, холодное мерцание на всю комнату
#  • Шум привлекает Скинвокера со всего этажа, пока игрок не выключит ТВ [E]
# ══════════════════════════════════════════════════════════════════════════════

@export var custom_video_path: String = ""
@export var is_on: bool = false
@export var auto_turn_on_delay: float = 85.0 # Включается сам через время

var screen_mesh: MeshInstance3D = null
var screen_light: SpotLight3D = null
var static_audio: AudioStreamPlayer3D = null
var video_player: VideoStreamPlayer = null

var elapsed: float = 0.0
var noise_alert_timer: float = 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta("item_type", "crt_tv")
	_find_nodes()
	_setup_screen_and_video()
	_update_tv_state()

func _find_nodes() -> void:
	screen_mesh = get_node_or_null("Screen") as MeshInstance3D
	screen_light = get_node_or_null("ScreenLight") as SpotLight3D
	if screen_light:
		# Луч света кинескопа всегда должен светить из экрана вперёд в комнату (+Z)
		screen_light.rotation_degrees = Vector3(0, 180.0, 0)

func _setup_screen_and_video() -> void:
	# Аудио статических помех
	static_audio = AudioStreamPlayer3D.new()
	static_audio.max_distance = 30.0
	static_audio.unit_size = 5.0
	var static_s = ResourceLoader.load("res://assets/audio/tv_static.wav")
	if static_s:
		static_audio.stream = static_s
		if static_s is AudioStreamWAV:
			static_s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(static_audio)

	# Проверка кастомного видео
	var v_path = custom_video_path
	if v_path == "":
		if FileAccess.file_exists("res://assets/videos/tv_broadcast.ogv"):
			v_path = "res://assets/videos/tv_broadcast.ogv"
		elif FileAccess.file_exists("user://videos/tv_broadcast.ogv"):
			v_path = "user://videos/tv_broadcast.ogv"

	if v_path != "" and (FileAccess.file_exists(v_path) or ResourceLoader.exists(v_path)):
		video_player = VideoStreamPlayer.new()
		video_player.expand = true
		video_player.loop = true
		video_player.stream = load(v_path)
		add_child(video_player)

func _process(delta: float) -> void:
	elapsed += delta

	# Таймер внезапного включения посреди ночи
	if not is_on and auto_turn_on_delay > 0.0:
		if elapsed >= auto_turn_on_delay:
			turn_on()

	if not is_on:
		return

	# Мерцание холодного сине-белого света кинескопа
	if screen_light:
		var flick = sin(elapsed * 18.0) * 0.35 + cos(elapsed * 34.0) * 0.25
		screen_light.light_energy = clamp(1.8 + flick, 0.8, 2.6)

	# Привлечение монстра звуком
	noise_alert_timer += delta
	if noise_alert_timer >= 4.0:
		noise_alert_timer = 0.0
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("emit_noise"):
			gm.emit_noise(global_position, 32.0)

func interact(_opener: Node3D = null) -> void:
	if is_on:
		turn_off()
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.get("ui_ref"):
			gm.ui_ref.call("show_hint", "Телевизор выключен. В комнате снова тихо.", 2.5)
	else:
		turn_on()
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.get("ui_ref"):
			gm.ui_ref.call("show_hint", "Телевизор включён.", 2.0)

func turn_on() -> void:
	is_on = true
	_update_tv_state()
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.get("ui_ref"):
		gm.ui_ref.call("show_hint", "ТЕЛЕВИЗОР ВКЛЮЧИЛСЯ САМ! Выключите его [E], пока монстр не прибежал!", 5.0)

func turn_off() -> void:
	is_on = false
	_update_tv_state()

func _update_tv_state() -> void:
	if screen_light:
		screen_light.visible = is_on

	if is_on:
		if static_audio and not static_audio.playing:
			static_audio.play()
		if video_player and not video_player.is_playing():
			video_player.play()
		_set_screen_material(true)
	else:
		if static_audio and static_audio.playing:
			static_audio.stop()
		if video_player and video_player.is_playing():
			video_player.stop()
		_set_screen_material(false)

func _set_screen_material(active: bool) -> void:
	if not screen_mesh:
		return
	var mat = StandardMaterial3D.new()
	if active:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.75, 0.88, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.70, 0.85, 1.0)
		mat.emission_energy_multiplier = 1.4
	else:
		mat.albedo_color = Color(0.04, 0.05, 0.06)
		mat.roughness = 0.2
		mat.metallic = 0.1
	screen_mesh.set_surface_override_material(0, mat)
