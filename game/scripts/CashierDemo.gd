extends Node3D

# Демо кассирши: клавиши 1 — стоит, 2 — говорит, 3 — ходит туда-сюда, Esc — выход.

var model: CashierModel
var cam: Camera3D
var label: Label
var mode := "stand"
# Выключается, если кадрами управляет другой скрипт
var auto := true


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.1, 0.11)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.58)
	e.ambient_light_energy = 0.18
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0.6, 3.0, 3.0)
	lamp.spot_range = 9.0
	lamp.spot_angle = 55.0
	lamp.light_energy = 11.0
	lamp.light_color = Color(1.0, 0.93, 0.8)
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.look_at(Vector3(0, 1.0, 0))
	var floor_box := CSGBox3D.new()
	floor_box.size = Vector3(12, 0.1, 8)
	floor_box.position = Vector3(0, -0.05, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.19, 0.19, 0.2)
	floor_box.material = fm
	add_child(floor_box)
	model = CashierModel.new()
	add_child(model)
	cam = Camera3D.new()
	cam.position = Vector3(0, 1.15, 5.2)
	cam.fov = 34.0
	add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0))
	cam.make_current()
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector3(24, 20, 0) if false else Vector2(24, 20)
	label.add_theme_font_size_override("font_size", 22)
	ui.add_child(label)
	set_mode("stand")


func set_mode(new_mode: String) -> void:
	mode = new_mode
	label.text = "1 — стоит   2 — говорит   3 — ходит   Esc — выход\nСейчас: " + {"stand": "стоит", "talk": "говорит", "walk": "ходит"}[mode]


func _process(delta: float) -> void:
	if auto:
		model.update_motion(delta, mode)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	match (event as InputEventKey).keycode:
		KEY_1:
			set_mode("stand")
		KEY_2:
			set_mode("talk")
		KEY_3:
			set_mode("walk")
		KEY_ESCAPE:
			get_tree().quit()
