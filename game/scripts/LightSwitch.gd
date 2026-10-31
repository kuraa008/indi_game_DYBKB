class_name LightSwitch
extends Area3D

# ══════════════════════════════════════════════════════════════════════════════
#  LightSwitch.gd — Умный настенный выключатель света
#  • Автоматическая привязка к ближайшей лампе в радиусе (search_radius)
#  • Возможность ручной привязки к конкретной лампе по ID или пути
#  • Анимация щелчка тумблера, реалистичный звук переключения и реакция окружения
# ══════════════════════════════════════════════════════════════════════════════

@export var target_light_id: int = -1
@export var target_light_path: NodePath = NodePath("")
@export var auto_bind_nearest: bool = true
@export var search_radius: float = 14.0
@export var is_light_on: bool = true

var bound_light: Light3D = null
var toggle_mesh: Node3D = null
var audio_player: AudioStreamPlayer3D = null

func _ready() -> void:
	collision_layer = 1 | 4
	collision_mask = 0
	set_meta("item_type", "light_switch")

	_find_toggle_mesh()
	_setup_audio()
	
	# Небольшая задержка, чтобы все лампы успели появиться на сцене
	call_deferred("_bind_light")

func _find_toggle_mesh() -> void:
	toggle_mesh = get_node_or_null("Toggle")
	if not toggle_mesh:
		toggle_mesh = get_node_or_null("Tog")
	if not toggle_mesh:
		for ch in get_children():
			if ch is MeshInstance3D and ("toggle" in ch.name.to_lower() or "tog" in ch.name.to_lower()):
				toggle_mesh = ch
				break

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "SwitchAudio"
	audio_player.max_distance = 18.0
	audio_player.unit_size = 3.0
	add_child(audio_player)

func _bind_light() -> void:
	# 1. Попытка привязать по NodePath
	if target_light_path != NodePath(""):
		var n = get_node_or_null(target_light_path)
		if n is Light3D:
			bound_light = n

	# 2. Попытка привязать по target_light_id (из MapForge / DebugEditor)
	if not bound_light and target_light_id >= 0:
		bound_light = _find_light_by_id(get_tree().root, target_light_id)

	# 3. Автоматический поиск ближайшей лампы в радиусе
	if not bound_light and auto_bind_nearest:
		bound_light = _find_nearest_light()

	# Синхронизируем состояние лампы и тумблера
	if bound_light and is_instance_valid(bound_light):
		bound_light.visible = is_light_on
		_toggle_fixture_emission(bound_light, is_light_on)

	_update_toggle_visual(false)

func _find_light_by_id(root_node: Node, target_id: int) -> Light3D:
	if not root_node:
		return null
	if root_node.get_meta("obj_id", -1) == target_id and root_node is Light3D:
		return root_node
	for ch in root_node.get_children():
		if ch.get_meta("obj_id", -1) == target_id:
			if ch is Light3D:
				return ch
			for sub in ch.get_children():
				if sub is Light3D:
					return sub
		var found = _find_light_by_id(ch, target_id)
		if found:
			return found
	return null

func _find_nearest_light() -> Light3D:
	var cur_scene = get_tree().current_scene
	if not cur_scene:
		return null

	var candidates: Array[Light3D] = []
	_collect_candidate_lights(cur_scene, candidates)

	var nearest: Light3D = null
	var min_dist: float = search_radius

	for l in candidates:
		if not is_instance_valid(l):
			continue
		var d = global_position.distance_to(l.global_position)
		if d < min_dist:
			min_dist = d
			nearest = l

	return nearest

func _collect_candidate_lights(node: Node, out_arr: Array[Light3D]) -> void:
	if not node:
		return
	if (node is OmniLight3D or node is SpotLight3D) and node != self:
		var n_name = node.name.to_lower()
		var p_name = node.get_parent().name.to_lower() if node.get_parent() else ""
		# Исключаем фонарик игрока, уличную луну, подсветку двери и свечи
		if not ("flash" in n_name or "door_light" in n_name or "moon" in n_name or "candle" in n_name or "player" in p_name):
			out_arr.append(node)
	for ch in node.get_children():
		_collect_candidate_lights(ch, out_arr)

func interact(_opener: Node3D = null) -> void:
	is_light_on = not is_light_on

	# Если лампа потерялась — пробуем переподвязать
	if not bound_light or not is_instance_valid(bound_light):
		_bind_light()

	if bound_light and is_instance_valid(bound_light):
		bound_light.visible = is_light_on
		_toggle_fixture_emission(bound_light, is_light_on)

	_update_toggle_visual(true)
	_play_switch_click()

	# Щелчок выключателя привлекает внимание монстра, если он рядом
	GameManager.emit_noise(global_position, 10.0)
	GameManager.emit_signal("light_state_changed", is_light_on)
	if GameManager.enemy_ref and GameManager.enemy_ref.has_method("on_light_altered"):
		GameManager.enemy_ref.call("on_light_altered", is_light_on)

	if GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
		var light_info = ""
		if bound_light and is_instance_valid(bound_light):
			light_info = " (Лампа: %s)" % bound_light.name
		GameManager.ui_ref.call("show_hint",
			"Свет " + ("ВКЛЮЧЕН" if is_light_on else "ВЫКЛЮЧЕН") + light_info, 2.0)

func _update_toggle_visual(animate: bool) -> void:
	if not toggle_mesh:
		return
	var target_deg = 24.0 if is_light_on else -24.0
	if animate:
		var tw = create_tween()
		tw.tween_property(toggle_mesh, "rotation_degrees:x", target_deg, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		toggle_mesh.rotation_degrees.x = target_deg

func _toggle_fixture_emission(light: Light3D, enabled: bool) -> void:
	var p = light.get_parent()
	if not p:
		return
	for ch in p.get_children():
		if ch is MeshInstance3D and "bulb" in ch.name.to_lower():
			if ch.mesh and ch.mesh.get_surface_count() > 0:
				var mat = ch.mesh.surface_get_material(0)
				if mat is StandardMaterial3D:
					mat.emission_enabled = enabled
					if enabled:
						mat.emission = light.light_color
						mat.emission_energy_multiplier = 1.6

func _play_switch_click() -> void:
	if ResourceLoader.exists("res://assets/audio/switch_pull.wav"):
		var s = ResourceLoader.load("res://assets/audio/switch_pull.wav")
		if s and audio_player:
			audio_player.stream = s
			audio_player.pitch_scale = randf_range(0.95, 1.05)
			audio_player.play()
			return

	# Синтетический щелчок переключателя (тугой пластиковый щелчок)
	if not audio_player:
		return
	var sample_count = int(44100 * 0.08)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 90.0)
		var click = (sin(t * 1800.0 * TAU) * 0.6 + sin(t * 4200.0 * TAU) * 0.4) * env
		var val16 = int(clamp(click, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.pitch_scale = randf_range(0.95, 1.05)
	audio_player.play()
