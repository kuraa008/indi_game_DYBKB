class_name Cutscene
extends Node3D

# Основа сюжетных кат-сцен (Jan-ky). Одна сцена = одна кат-сцена.
#
# Запуск из любого места:
#   Cutscene.play(get_tree(), "res://scenes/cutscenes/Ch3Mine.tscn", "res://scenes/Next.tscn")
# Третий аргумент — куда перейти после конца. Если его нет, берётся next_scene сцены.
# Четвёртый — настройки, например {"from_gameplay": true} или {"part": "talk"}.
# По концу испускается finished; Esc, Enter, Пробел или Start пропускают кат-сцену.
#
# Наследник переопределяет build() (декорации, свет, актёры), run() (раскадровка
# через await) и, если нужно, tick(delta) — покадровые обновления.
# Реплики берутся из assets/audio/cutscenes/voice/<id>.wav: если файл заменить
# записью актёра, кат-сцена сама подстроится под новую длину.

signal finished

const SFX_DIR := "res://assets/audio/cutscenes/"
const VOICE_DIR := "res://assets/audio/cutscenes/voice/"
const BUS_WORLD := "CutWorld"     # мир: глохнет через muffle()
const BUS_VOICE := "CutVoice"     # реплики и голоса существа

const LID_SHADER := """
shader_type canvas_item;
uniform float open_amount = 1.0;
uniform float soft = 0.08;
void fragment() {
	float half_open = open_amount * 0.62;
	float d = abs(UV.y - 0.5);
	float a = smoothstep(half_open - soft, half_open + soft * 0.4, d);
	a = max(a, step(open_amount, 0.001));
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float amount = 0.0;
uniform float split = 0.0;
uniform float vignette = 0.0;
uniform vec3 tint = vec3(1.0);
void fragment() {
	vec3 c = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			c += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * amount * 2.0, amount * 140.0).rgb;
		}
	}
	c /= 9.0;
	if (split > 0.0005) {
		vec3 g = textureLod(screen_tex, SCREEN_UV + vec2(split, split * 0.3), 1.5).rgb;
		c = mix(c, g, 0.4);
	}
	vec2 q = SCREEN_UV - 0.5;
	float v = 1.0 - vignette * smoothstep(0.25, 0.75, length(q * vec2(1.0, 0.8)));
	COLOR = vec4(c * tint * v, 1.0);
}
"""

static var _request_next := ""
static var _request_args := {}
# Для автотестов: подсказки («Назвать имя») нажимаются сами через 1.5 с
static var autoplay := false

@export var next_scene := "res://scenes/Menu.tscn"

var args := {}
var t := 0.0
var skipping := false
var cam: Camera3D
var env: Environment
var world_env: WorldEnvironment

# Камера: положение и точка взгляда плавно тянутся твинами
var cam_pos := Vector3(0, 1.6, 0)
var cam_look := Vector3(0, 1.6, -1)
var cam_fov := 55.0
var cam_roll := 0.0
var handheld := 0.0       # 0…1: дрожь ручной камеры
var breathe := 0.0        # 0…1: дыхание от первого лица
var _shake := 0.0
var _cam_tween: Tween
var _look_tween: Tween

var _ui: CanvasLayer
var _bars: Array[ColorRect] = []
var _black: ColorRect
var _flash: ColorRect
var _lids: ColorRect
var _lid_mat: ShaderMaterial
var _blur: ColorRect
var _blur_mat: ShaderMaterial
var _sub_box: VBoxContainer
var _sub_back: ColorRect
var _speaker: Label
var _line: Label
var _card_box: VBoxContainer
var _card_title: Label
var _card_sub: Label
var _prompt_box: PanelContainer
var _prompt_label: Label
var _skip_label: Label
var _sub_tween: Tween
var _fade_tween: Tween
var _card_tween: Tween
var _fx_tween: Tween

var _muffle: AudioEffectLowPassFilter
var _muffle_tween: Tween
var _streams := {}
var _loops: Array[Node] = []
var _prompt_action := ""
var _prompt_waiting := false
var _prompt_t := 0.0
var _done := false
var _lid_open := 1.0
var _blur_amt := 0.0
var _blur_split := 0.0
var _vignette := 0.0
var _vig_rect: TextureRect


# ════════════════════════════════════════════════════════════
#  Запуск и конец
# ════════════════════════════════════════════════════════════
static func play(tree: SceneTree, scene_path: String, next_path: String = "", extra: Dictionary = {}) -> void:
	_request_next = next_path
	_request_args = extra
	tree.change_scene_to_file(scene_path)


func _ready() -> void:
	args = _request_args.duplicate()
	if args.get("autoplay", false):
		autoplay = true
	_request_args = {}
	if _request_next != "":
		next_scene = _request_next
		_request_next = ""
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_setup_buses()
	_build_ui()
	cam = Camera3D.new()
	cam.name = "CutsceneCamera"
	cam.near = 0.03
	cam.far = 900.0
	add_child(cam)
	cam.make_current()
	world_env = WorldEnvironment.new()
	env = Environment.new()
	world_env.environment = env
	add_child(world_env)
	set_env(Color(0.02, 0.02, 0.03), Color(0.1, 0.1, 0.12), 0.3)
	build()
	_apply_quality()
	_update_camera(0.0)
	_go()


func _go() -> void:
	await get_tree().process_frame
	await run()
	end()


# Переопределить: декорации, свет, актёры
func build() -> void:
	pass


# Переопределить: раскадровка (await wait(), await line(), …)
func run() -> void:
	await wait(1.0)


# Переопределить при необходимости: покадровые обновления
func tick(_delta: float) -> void:
	pass


func end() -> void:
	if _done:
		return
	_done = true
	if skipping:
		await get_tree().create_timer(0.35).timeout
	finished.emit()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if next_scene != "" and next_scene != "none" and is_inside_tree():
		get_tree().change_scene_to_file(next_scene)


func skip() -> void:
	if skipping or _done:
		return
	skipping = true
	_prompt_waiting = false
	_fade_to(1.0, 0.3)
	for n in _loops:
		if is_instance_valid(n):
			fade(n, -60.0, 0.3)


func _exit_tree() -> void:
	for b in [BUS_VOICE, BUS_WORLD]:
		var i := AudioServer.get_bus_index(b)
		if i >= 0:
			AudioServer.remove_bus(i)
	if vhs():
		vhs().call("set_fear", 0.0)


func _process(delta: float) -> void:
	t += delta
	if _prompt_waiting:
		_prompt_t += delta
		if autoplay and _prompt_t > 1.5:
			_prompt_waiting = false
	tick(delta)
	_update_camera(delta)
	_update_fx()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if _prompt_waiting and _prompt_action != "" and event.is_action_pressed(_prompt_action):
		_prompt_waiting = false
		get_viewport().set_input_as_handled()
		return
	if t < 0.6:
		return
	var want := event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		want = true
	if want:
		get_viewport().set_input_as_handled()
		skip()


# ════════════════════════════════════════════════════════════
#  Ожидание (пропуск обрывает его сразу)
# ════════════════════════════════════════════════════════════
func wait(sec: float) -> void:
	var until := t + sec
	while t < until and not skipping and is_inside_tree():
		await get_tree().process_frame


func wait_until(at: float) -> void:
	while t < at and not skipping and is_inside_tree():
		await get_tree().process_frame


# Ждёт нажатия действия (например, interact). Текст — подсказка на экране.
func prompt(text: String, action: String = "interact") -> void:
	if skipping:
		return
	_prompt_action = action
	_prompt_waiting = true
	_prompt_t = 0.0
	var key := ""
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			key = OS.get_keycode_string((ev as InputEventKey).physical_keycode if (ev as InputEventKey).keycode == 0 else (ev as InputEventKey).keycode)
			break
	_prompt_label.text = ("[%s]  %s" % [key, text]) if key != "" else text
	var tw := create_tween()
	_prompt_box.modulate.a = 0.0
	_prompt_box.visible = true
	tw.tween_property(_prompt_box, "modulate:a", 1.0, 0.25)
	while _prompt_waiting and not skipping and is_inside_tree():
		_prompt_box.scale = Vector2.ONE * (1.0 + 0.03 * sin(t * 6.0))
		await get_tree().process_frame
	_prompt_box.visible = false


# ════════════════════════════════════════════════════════════
#  Камера
# ════════════════════════════════════════════════════════════
# Резкая склейка
func shot(pos: Vector3, look: Vector3, fov: float = -1.0, roll: float = 0.0) -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	if _look_tween and _look_tween.is_valid():
		_look_tween.kill()
	cam_pos = pos
	cam_look = look
	cam_roll = roll
	if fov > 0.0:
		cam_fov = fov


# Плавный проезд (не ждёт конца — для ожидания добавьте await wait(dur))
func glide(pos: Vector3, look: Vector3, dur: float, fov: float = -1.0, trans: int = Tween.TRANS_SINE, ease_type: int = Tween.EASE_IN_OUT) -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	if _look_tween and _look_tween.is_valid():
		_look_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(trans).set_ease(ease_type)
	_cam_tween.tween_property(self, "cam_pos", pos, dur)
	_cam_tween.tween_property(self, "cam_look", look, dur)
	if fov > 0.0:
		_cam_tween.tween_property(self, "cam_fov", fov, dur)


# Только поворот взгляда
func look_to(look: Vector3, dur: float, trans: int = Tween.TRANS_SINE, ease_type: int = Tween.EASE_IN_OUT) -> void:
	if _look_tween and _look_tween.is_valid():
		_look_tween.kill()
	_look_tween = create_tween().set_trans(trans).set_ease(ease_type)
	_look_tween.tween_property(self, "cam_look", look, dur)


func move_to(pos: Vector3, dur: float, trans: int = Tween.TRANS_SINE, ease_type: int = Tween.EASE_IN_OUT) -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_trans(trans).set_ease(ease_type)
	_cam_tween.tween_property(self, "cam_pos", pos, dur)


func tween_prop(obj: Object, prop: String, value: Variant, dur: float, trans: int = Tween.TRANS_SINE, ease_type: int = Tween.EASE_IN_OUT) -> Tween:
	var tw := create_tween().set_trans(trans).set_ease(ease_type)
	tw.tween_property(obj, prop, value, dur)
	return tw


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_camera(delta: float) -> void:
	if cam == null:
		return
	var p := cam_pos
	var k := t
	if handheld > 0.0:
		p += Vector3(sin(k * 1.31) * 0.6 + sin(k * 2.93 + 1.0) * 0.3, sin(k * 1.73 + 2.0) * 0.5 + sin(k * 3.71) * 0.2, sin(k * 1.07 + 0.5) * 0.3) * 0.011 * handheld
	if breathe > 0.0:
		p.y += sin(k * 1.55) * 0.009 * breathe
	var sh := Vector3.ZERO
	if _shake > 0.0:
		sh = Vector3(sin(k * 53.1) * sin(k * 7.3 + 1.0), sin(k * 47.7 + 2.0) * sin(k * 5.9), sin(k * 41.3 + 4.0)) * 0.035 * _shake
		_shake = maxf(0.0, _shake - delta * 2.4)
	p += sh
	var target := cam_look
	var dist := maxf(0.5, p.distance_to(cam_look))
	if handheld > 0.0:
		target += Vector3(sin(k * 0.91 + 1.0), sin(k * 1.23 + 2.0) * 0.7, 0.0) * 0.012 * handheld * dist
	target += sh * 0.6 * dist
	cam.global_position = p
	var fwd := target - p
	if fwd.length_squared() > 1e-6:
		var up := Vector3.UP
		if absf(fwd.normalized().dot(up)) > 0.985:
			up = Vector3.BACK
		cam.look_at(target, up)
	if absf(cam_roll) > 0.0001:
		cam.rotate_object_local(Vector3(0, 0, 1), cam_roll)
	cam.fov = cam_fov


# ════════════════════════════════════════════════════════════
#  Экран: затемнение, вспышка, веки, размытие, полосы, титры
# ════════════════════════════════════════════════════════════
func fade_out(dur: float) -> void:
	_fade_to(1.0, dur)


func fade_in(dur: float) -> void:
	_fade_to(0.0, dur)


func black(alpha: float = 1.0) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_black.color.a = alpha


func _fade_to(alpha: float, dur: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	if dur <= 0.0:
		_black.color.a = alpha
		return
	_fade_tween = create_tween()
	_fade_tween.tween_property(_black, "color:a", alpha, dur)


func flash(col: Color, dur: float) -> void:
	_flash.color = Color(col.r, col.g, col.b, col.a)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, dur)


# Веки: 0 — закрыты, 1 — открыты
func lids(open_amount: float, dur: float) -> void:
	if dur <= 0.0:
		_lid_open = open_amount
		return
	tween_prop(self, "_lid_open", open_amount, dur)


func blink(hold: float = 0.06) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_lid_open", 0.0, 0.08)
	tw.tween_interval(hold)
	tw.tween_property(self, "_lid_open", 1.0, 0.16)


func blur(amount: float, dur: float, split: float = 0.0) -> void:
	if _fx_tween and _fx_tween.is_valid():
		_fx_tween.kill()
	_fx_tween = create_tween().set_parallel(true)
	_fx_tween.tween_property(self, "_blur_amt", amount, maxf(dur, 0.01))
	_fx_tween.tween_property(self, "_blur_split", split, maxf(dur, 0.01))


func vignette(amount: float, dur: float) -> void:
	tween_prop(self, "_vignette", amount, maxf(dur, 0.01))


func _update_fx() -> void:
	_lid_mat.set_shader_parameter("open_amount", _lid_open)
	_lids.visible = _lid_open < 0.999
	# Размытие читает экран — включаем его только когда оно правда нужно.
	# Виньетка — дешёвый градиент поверх, без чтения экрана.
	var on := _blur_amt > 0.0002 or _blur_split > 0.0002
	_blur.visible = on
	if on:
		_blur_mat.set_shader_parameter("amount", _blur_amt)
		_blur_mat.set_shader_parameter("split", _blur_split)
		_blur_mat.set_shader_parameter("vignette", 0.0)
	if _vig_rect == null:
		_vig_rect = TextureRect.new()
		var g := Gradient.new()
		g.set_color(0, Color(0, 0, 0, 0))
		g.set_color(1, Color(0, 0, 0, 1))
		g.add_point(0.55, Color(0, 0, 0, 0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.05, 0.5)
		gt.width = 256
		gt.height = 256
		_vig_rect.texture = gt
		_vig_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_vig_rect.stretch_mode = TextureRect.STRETCH_SCALE
		_full(_vig_rect)
		_ui.add_child(_vig_rect)
		_ui.move_child(_vig_rect, _blur.get_index() + 1)
	_vig_rect.visible = _vignette > 0.002
	_vig_rect.modulate.a = clampf(_vignette, 0.0, 1.0)


func letterbox(on: bool, dur: float = 0.8) -> void:
	for i in _bars.size():
		var b := _bars[i]
		var target := (0.1 if on else 0.0)
		var tw := create_tween().set_trans(Tween.TRANS_SINE)
		if i == 0:
			tw.tween_property(b, "anchor_bottom", target, dur)
		else:
			tw.tween_property(b, "anchor_top", 1.0 - target, dur)


# Субтитр: говорящий + строка
func say(speaker: String, text: String, hold: float, thought: bool = false) -> void:
	_speaker.text = speaker
	_line.text = text
	_line.add_theme_color_override("font_color", Color(0.72, 0.74, 0.78) if thought else Color(0.95, 0.95, 0.96))
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub_box.modulate.a = 0.0
	_sub_back.modulate.a = 0.0
	_sub_tween = create_tween().set_parallel(true)
	_sub_tween.tween_property(_sub_box, "modulate:a", 1.0, 0.2)
	_sub_tween.tween_property(_sub_back, "modulate:a", 1.0, 0.2)
	_sub_tween.chain().tween_interval(hold)
	_sub_tween.chain().tween_property(_sub_box, "modulate:a", 0.0, 0.3)
	_sub_tween.parallel().tween_property(_sub_back, "modulate:a", 0.0, 0.3)


func clear_subtitle() -> void:
	if _sub_tween and _sub_tween.is_valid():
		_sub_tween.kill()
	_sub_box.modulate.a = 0.0
	_sub_back.modulate.a = 0.0


# Реплика: звук voice/<id>.wav (если есть) + субтитр; ждёт конца реплики.
# at — точка в мире для голоса издалека (за дверью, из дома, из леса).
func line(id: String, speaker: String, text: String, pause: float = 0.35, at: Variant = null, db: float = 0.0, unit: float = 6.0) -> void:
	if skipping:
		return
	var dur := say_line(id, speaker, text, at, db, unit)
	await wait(dur + pause)


# То же без ожидания: запускает реплику и возвращает её длину в секундах
func say_line(id: String, speaker: String, text: String, at: Variant = null, db: float = 0.0, unit: float = 6.0) -> float:
	if skipping:
		return 0.0
	var st := voice_stream(id)
	var dur := reading_time(text) if st == null else st.get_length()
	if st != null:
		if at is Vector3:
			_play3d(st, at, db, unit, BUS_VOICE)
		else:
			_play2d(st, db, 1.0, BUS_VOICE)
	say(speaker, text, dur + 0.1)
	return dur


# Мысль: без голоса, бледнее
func thought(text: String, hold: float = -1.0) -> void:
	if skipping:
		return
	var h := reading_time(text) if hold < 0.0 else hold
	say("ИТАН", text, h, true)
	await wait(h + 0.4)


func reading_time(text: String) -> float:
	return clampf(0.9 + text.length() * 0.055, 1.4, 7.0)


func voice_stream(id: String) -> AudioStream:
	return _load_stream(VOICE_DIR + id + ".wav")


# Титр по центру: конец главы, «Семья в сборе», «КОНЕЦ»
func card(title: String, sub: String = "", hold: float = 3.0, fade_t: float = 1.0) -> void:
	if skipping:
		return
	_card_title.text = title
	_card_sub.text = sub
	_card_sub.visible = sub != ""
	if _card_tween and _card_tween.is_valid():
		_card_tween.kill()
	_card_box.modulate.a = 0.0
	_card_tween = create_tween()
	_card_tween.tween_property(_card_box, "modulate:a", 1.0, fade_t)
	_card_tween.tween_interval(hold)
	_card_tween.tween_property(_card_box, "modulate:a", 0.0, fade_t)
	await wait(fade_t * 2.0 + hold)


# ════════════════════════════════════════════════════════════
#  Звук
# ════════════════════════════════════════════════════════════
func _load_stream(path: String) -> AudioStream:
	if _streams.has(path):
		return _streams[path]
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
	else:
		push_warning("Cutscene: нет звука " + path)
	_streams[path] = st
	return st


func _stream(sound_name: String) -> AudioStream:
	if sound_name.begins_with("res://"):
		return _load_stream(sound_name)
	return _load_stream(SFX_DIR + sound_name + ".wav")


func _play2d(st: AudioStream, db: float, pitch: float, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func _play3d(st: AudioStream, at: Vector3, db: float, unit: float, bus: String) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 80.0
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 9000.0
	add_child(p)
	p.global_position = at
	p.play()
	p.finished.connect(p.queue_free)
	return p


# Разовый звук без места (или с местом at)
func sfx(sound_name: String, db: float = 0.0, pitch: float = 1.0, at: Variant = null, unit: float = 5.0) -> Node:
	if skipping:
		return null
	var st := _stream(sound_name)
	if st == null:
		return null
	if at is Vector3:
		var p3 := _play3d(st, at, db, unit, BUS_WORLD)
		p3.pitch_scale = pitch
		return p3
	return _play2d(st, db, pitch, BUS_WORLD)


# Петля; fade_in — плавное появление
func loop(sound_name: String, db: float = 0.0, fade_in_t: float = 0.0, at: Variant = null, unit: float = 6.0) -> Node:
	var st := _stream(sound_name)
	if st == null:
		return null
	st = _looped(st)
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.stream = st
		p3.unit_size = unit
		p3.max_distance = 80.0
		p3.bus = BUS_WORLD
		add_child(p3)
		p3.global_position = at
		p = p3
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = st
		p2.bus = BUS_WORLD
		add_child(p2)
		p = p2
	p.set("volume_db", -50.0 if fade_in_t > 0.0 else db)
	p.call("play")
	if fade_in_t > 0.0:
		fade(p, db, fade_in_t)
	_loops.append(p)
	return p


func _looped(st: AudioStream) -> AudioStream:
	if st is AudioStreamWAV:
		var w := st as AudioStreamWAV
		if w.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			var c := w.duplicate() as AudioStreamWAV
			c.loop_mode = AudioStreamWAV.LOOP_FORWARD
			c.loop_begin = 0
			var bytes_per := (2 if c.format == AudioStreamWAV.FORMAT_16_BITS else 1) * (2 if c.stereo else 1)
			c.loop_end = c.data.size() / maxi(1, bytes_per)
			return c
	return st


func fade(p: Node, db: float, dur: float) -> void:
	if p == null or not is_instance_valid(p):
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, maxf(dur, 0.01))
	if db <= -59.0:
		tw.tween_callback(p.queue_free)


func stop(p: Node, dur: float = 0.0) -> void:
	if p == null or not is_instance_valid(p):
		return
	if dur <= 0.0:
		p.queue_free()
	else:
		fade(p, -60.0, dur)


# Мир глохнет (звон в ушах, шок): cutoff в Гц, 20000 — снять
func muffle(cutoff: float, dur: float) -> void:
	if _muffle == null:
		return
	if _muffle_tween and _muffle_tween.is_valid():
		_muffle_tween.kill()
	_muffle_tween = create_tween()
	_muffle_tween.tween_property(_muffle, "cutoff_hz", cutoff, maxf(dur, 0.01))


func silence(dur: float) -> void:
	for n in _loops:
		if is_instance_valid(n):
			fade(n, -60.0, dur)
	_loops.clear()


# Стук копыт: n шагов с интервалом gap, громче или тише к концу
func hooves(kind: String, n: int, gap: float, db_from: float, db_to: float, at_from: Variant = null, at_to: Variant = null) -> void:
	for i in n:
		if skipping:
			return
		var u := float(i) / maxf(1.0, float(n - 1))
		var at: Variant = null
		if at_from is Vector3 and at_to is Vector3:
			at = (at_from as Vector3).lerp(at_to as Vector3, u)
		var db := lerpf(db_from, db_to, u)
		sfx("%s_%d" % [kind, (i % 4) + 1], db, randf_range(0.96, 1.04), at, 7.0)
		await wait(gap * randf_range(0.9, 1.12))


func _setup_buses() -> void:
	for b in [BUS_WORLD, BUS_VOICE]:
		if AudioServer.get_bus_index(b) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b)
		AudioServer.set_bus_send(i, "Master")
	var wi := AudioServer.get_bus_index(BUS_WORLD)
	_muffle = AudioEffectLowPassFilter.new()
	_muffle.cutoff_hz = 20000.0
	_muffle.resonance = 0.6
	AudioServer.add_bus_effect(wi, _muffle)


# ════════════════════════════════════════════════════════════
#  Окружение
# ════════════════════════════════════════════════════════════
func set_env(bg: Color, ambient: Color, ambient_energy: float, fog_density: float = 0.0, fog_color: Color = Color(0.05, 0.06, 0.08), exposure: float = 1.0) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = exposure
	env.fog_enabled = fog_density > 0.0
	env.fog_density = fog_density
	env.fog_light_color = fog_color
	env.fog_sky_affect = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.85
	env.adjustment_contrast = 1.06


func sky_env(top: Color, horizon: Color, ground: Color, ambient_energy: float = 0.6, sun_dir: Vector3 = Vector3.ZERO) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.3)
	sky_mat.ground_bottom_color = ground
	sky_mat.sun_angle_max = 18.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient_energy
	env.ambient_light_sky_contribution = 1.0


func _apply_quality() -> void:
	var q := "high"
	if gm():
		q = String(gm().get("graphics_quality"))
	if q == "low":
		env.glow_enabled = false
		env.ssao_enabled = false
		for n in find_children("*", "Light3D", true, false):
			if not (n is DirectionalLight3D):
				(n as Light3D).shadow_enabled = false
	# SSAO не включаем: на встроенной графике он съедает треть кадров
	# Солнце/луна: две каскадные тени вместо четырёх и короткая дальность — тени остаются у камеры
	for n in find_children("*", "DirectionalLight3D", true, false):
		var dl := n as DirectionalLight3D
		dl.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		dl.directional_shadow_max_distance = minf(dl.directional_shadow_max_distance, 45.0)


# ════════════════════════════════════════════════════════════
#  Интерфейс
# ════════════════════════════════════════════════════════════
func _label(text: String, px: int, col: Color, spacing: int = 2) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vhs():
		l.add_theme_font_override("font", vhs().call("tracked_font", spacing))
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l


func _full(c: Control) -> Control:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "CutsceneUI"
	_ui.layer = 40
	add_child(_ui)

	_blur_mat = ShaderMaterial.new()
	var bs := Shader.new()
	bs.code = BLUR_SHADER
	_blur_mat.shader = bs
	_blur = _full(ColorRect.new()) as ColorRect
	_blur.material = _blur_mat
	_blur.visible = false
	_ui.add_child(_blur)

	var grain := _full(TextureRect.new()) as TextureRect
	grain.texture = TextureHelper.get_texture("res://assets/textures/ui/horror_film_grunge_overlay.png")
	grain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	grain.stretch_mode = TextureRect.STRETCH_SCALE
	grain.modulate = Color(0.72, 0.78, 0.88, 0.12)
	_ui.add_child(grain)

	_lid_mat = ShaderMaterial.new()
	var ls := Shader.new()
	ls.code = LID_SHADER
	_lid_mat.shader = ls
	_lids = _full(ColorRect.new()) as ColorRect
	_lids.material = _lid_mat
	_lids.visible = false
	_ui.add_child(_lids)

	for is_top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if is_top else 1.0
		bar.anchor_bottom = 0.0 if is_top else 1.0
		_ui.add_child(bar)
		_bars.append(bar)

	_flash = _full(ColorRect.new()) as ColorRect
	_flash.color = Color(1, 1, 1, 0)
	_ui.add_child(_flash)

	_black = _full(ColorRect.new()) as ColorRect
	_black.color = Color(0, 0, 0, 1)
	_ui.add_child(_black)

	_card_box = _full(VBoxContainer.new()) as VBoxContainer
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_card_box.add_theme_constant_override("separation", 12)
	_card_box.modulate.a = 0.0
	_card_title = _label("", 40, Color(0.9, 0.91, 0.93), 6)
	_card_sub = _label("", 18, Color(0.6, 0.64, 0.72), 3)
	_card_box.add_child(_card_title)
	_card_box.add_child(_card_sub)
	_ui.add_child(_card_box)

	_sub_back = ColorRect.new()
	_sub_back.color = Color(0, 0, 0, 0.62)
	_sub_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_back.anchor_left = 0.08
	_sub_back.anchor_right = 0.92
	_sub_back.anchor_top = 0.74
	_sub_back.anchor_bottom = 0.885
	_sub_back.modulate.a = 0.0
	_ui.add_child(_sub_back)
	_sub_box = VBoxContainer.new()
	_sub_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_box.anchor_left = 0.11
	_sub_box.anchor_right = 0.89
	_sub_box.anchor_top = 0.72
	_sub_box.anchor_bottom = 0.87
	_sub_box.alignment = BoxContainer.ALIGNMENT_END
	_sub_box.add_theme_constant_override("separation", 4)
	_sub_box.modulate.a = 0.0
	_speaker = _label("", 15, Color(0.62, 0.7, 0.82), 3)
	_line = _label("", 23, Color(0.95, 0.95, 0.96), 1)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_box.add_child(_speaker)
	_sub_box.add_child(_line)
	_ui.add_child(_sub_box)

	_prompt_box = PanelContainer.new()
	_prompt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.02, 0.02, 0.78)
	sb.border_color = Color(0.85, 0.2, 0.15, 0.9)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(14)
	_prompt_box.add_theme_stylebox_override("panel", sb)
	_prompt_box.anchor_left = 0.35
	_prompt_box.anchor_right = 0.65
	_prompt_box.anchor_top = 0.56
	_prompt_box.anchor_bottom = 0.64
	_prompt_label = _label("", 26, Color(0.98, 0.9, 0.86), 4)
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_box.add_child(_prompt_label)
	_prompt_box.visible = false
	_ui.add_child(_prompt_box)

	_skip_label = _label("Esc — пропустить", 13, Color(0.6, 0.62, 0.66, 0.55), 2)
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.anchor_left = 0.5
	_skip_label.anchor_right = 0.97
	_skip_label.anchor_top = 0.93
	_skip_label.anchor_bottom = 0.98
	_ui.add_child(_skip_label)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(_skip_label, "modulate:a", 0.0, 1.5)


# Автозагрузки берём по пути: так скрипт компилируется и без них (тесты, редактор)
func vhs() -> Node:
	return get_node_or_null("/root/VHSOverlay")


func gm() -> Node:
	return get_node_or_null("/root/GameManager")
