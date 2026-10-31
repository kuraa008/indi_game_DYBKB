class_name ElectricMaglock
extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  ElectricMaglock.gd — Электромагнитный замок и барьер высокого напряжения
#  • Крепится к любой двери, блокируя её электромагнитом под высоким напряжением
#  • Периодически искрит, издаёт гул трансформатора 50 Гц
#  • Бьёт током неосторожного игрока (вспышка, урон, отбрасывание)
#  • Оглушает и отпугивает Скинвокера высоковольтными искрами
#  • Обесточивается через щиток с предохранителями или рубильник
# ══════════════════════════════════════════════════════════════════════════════

@export var is_powered: bool = true
@export var shock_damage: float = 15.0

var door_parent: Node3D = null
var led_mesh: MeshInstance3D = null
var led_light: OmniLight3D = null
var spark_particles: CPUParticles3D = null
var hum_player: AudioStreamPlayer3D = null
var sfx_player: AudioStreamPlayer3D = null

var spark_timer: float = 0.0
var next_spark_time: float = 2.0
var shock_cooldown: float = 0.0

func _ready() -> void:
	door_parent = get_parent() as Node3D
	_setup_visuals()
	_setup_audio()

func _setup_visuals() -> void:
	# Корпус электромагнитного замка
	var box = MeshInstance3D.new()
	var bm = BoxMesh.new()
	bm.size = Vector3(0.28, 0.12, 0.14)
	var mat_metal = StandardMaterial3D.new()
	mat_metal.albedo_color = Color(0.22, 0.24, 0.28)
	mat_metal.metallic = 0.85
	mat_metal.roughness = 0.35
	box.mesh = bm
	box.set_surface_override_material(0, mat_metal)
	add_child(box)

	# Светодиодный индикатор статуса
	led_mesh = MeshInstance3D.new()
	var sm = SphereMesh.new()
	sm.radius = 0.02
	sm.height = 0.04
	led_mesh.mesh = sm
	led_mesh.position = Vector3(0.08, 0.0, 0.075)
	add_child(led_mesh)

	led_light = OmniLight3D.new()
	led_light.omni_range = 1.2
	led_light.light_energy = 1.4
	led_light.position = Vector3(0.08, 0.0, 0.10)
	add_child(led_light)
	_update_led_status()

	# Искры высокого напряжения
	spark_particles = CPUParticles3D.new()
	spark_particles.emitting = false
	spark_particles.amount = 16
	spark_particles.lifetime = 0.25
	spark_particles.one_shot = true
	spark_particles.explosiveness = 0.9
	spark_particles.direction = Vector3(0, -1, 1).normalized()
	spark_particles.spread = 60.0
	spark_particles.initial_velocity_min = 2.5
	spark_particles.initial_velocity_max = 5.0
	spark_particles.color = Color(0.6, 0.85, 1.0)
	var p_mesh = BoxMesh.new()
	p_mesh.size = Vector3(0.02, 0.02, 0.02)
	var p_mat = StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = Color(0.8, 0.95, 1.0)
	p_mesh.surface_set_material(0, p_mat)
	spark_particles.mesh = p_mesh
	spark_particles.position = Vector3(0, -0.05, 0.06)
	add_child(spark_particles)

func _setup_audio() -> void:
	hum_player = AudioStreamPlayer3D.new()
	hum_player.max_distance = 15.0
	hum_player.unit_size = 3.0
	var hum_stream = ResourceLoader.load("res://assets/audio/electric_hum.wav")
	if hum_stream:
		hum_player.stream = hum_stream
		if hum_stream is AudioStreamWAV:
			hum_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	add_child(hum_player)

	sfx_player = AudioStreamPlayer3D.new()
	sfx_player.max_distance = 25.0
	sfx_player.unit_size = 5.0
	add_child(sfx_player)

	if is_powered and hum_player.stream:
		hum_player.play()

func _process(delta: float) -> void:
	if shock_cooldown > 0.0:
		shock_cooldown -= delta

	if not is_powered:
		return

	# Периодические искры
	spark_timer += delta
	if spark_timer >= next_spark_time:
		spark_timer = 0.0
		next_spark_time = randf_range(2.0, 4.5)
		_trigger_spark()

	# Проверка приближения монстра (защитный барьер)
	if GameManager.enemy_ref and is_instance_valid(GameManager.enemy_ref):
		var dist_to_enemy = global_position.distance_to(GameManager.enemy_ref.global_position)
		if dist_to_enemy < 2.0 and shock_cooldown <= 0.0:
			shock_monster(GameManager.enemy_ref)

func _trigger_spark() -> void:
	if not is_powered:
		return
	if spark_particles:
		spark_particles.restart()
	var spark_sfx = ResourceLoader.load("res://assets/audio/electric_spark.wav")
	if spark_sfx and sfx_player:
		sfx_player.stream = spark_sfx
		sfx_player.pitch_scale = randf_range(0.9, 1.2)
		sfx_player.play()

func shock_player(_player: Node3D) -> void:
	# Двери больше НИКОГДА не бьют игрока током!
	return

func shock_monster(monster: Node3D) -> void:
	if not is_powered:
		return
	shock_cooldown = 2.5
	_trigger_spark()

	var shock_sfx = ResourceLoader.load("res://assets/audio/electric_shock.wav")
	if shock_sfx and sfx_player:
		sfx_player.stream = shock_sfx
		sfx_player.play()

	# Оглушение и отбрасывание монстра
	if monster and is_instance_valid(monster):
		var knock_dir = (monster.global_position - global_position).normalized()
		knock_dir.y = 0.0
		if monster is CharacterBody3D:
			monster.velocity = knock_dir * 12.0

		# Вызываем шок у монстра (отступление на 8 секунд)
		if monster.has_method("shock_by_electricity"):
			monster.call("shock_by_electricity", 8.0)
		elif monster.has_method("_stun"):
			monster.call("_stun", 8.0)

		if GameManager.ui_ref:
			GameManager.ui_ref.call("show_hint", "Скинвокер получил удар током и отступает!", 3.0)

func deactivate() -> void:
	if not is_powered:
		return
	is_powered = false

	if hum_player and hum_player.playing:
		hum_player.stop()

	var release_sfx = ResourceLoader.load("res://assets/audio/maglock_release.wav")
	if release_sfx and sfx_player:
		sfx_player.stream = release_sfx
		sfx_player.play()

	_update_led_status()

	# Разблокировка двери
	if door_parent:
		door_parent.set_meta("door_type", "simple")
		door_parent.set_meta("is_electrified", false)

	if GameManager.ui_ref:
		GameManager.ui_ref.call("show_hint", "ЩЕЛЧОК! Электромагнитный замок обесточен! Дверь свободна.", 4.0)

func _update_led_status() -> void:
	var col = Color(0.95, 0.15, 0.10) if is_powered else Color(0.15, 0.95, 0.25)
	if led_light:
		led_light.light_color = col
	if led_mesh:
		var l_mat = StandardMaterial3D.new()
		l_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		l_mat.albedo_color = col
		l_mat.emission_enabled = true
		l_mat.emission = col
		l_mat.emission_energy_multiplier = 2.0
		led_mesh.set_surface_override_material(0, l_mat)
