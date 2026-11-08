extends "res://scripts/ApartmentKit.gd"

# Свет квартиры: люстры, лампы и выключатели у дверей.
# Выключатель гасит всю комнату; торшер и настольные лампы щёлкаются сами по себе.

const CEIL := FL + 2.7
const BRASS := Color(0.62, 0.48, 0.24)
const WARM := Color(1.0, 0.8, 0.58)
const SHADE := Color(0.95, 0.8, 0.56)

const GLOW_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform float power = 1.0;
void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c;
	EMISSION = c * power;
	ROUGHNESS = 0.6;
}
"""


# Лампы одной группы гаснут и загораются вместе
class LightGroup extends RefCounted:
	var lights: Array = []
	var glows: Array = []

	func set_on(on: bool) -> void:
		for l in lights:
			l.visible = on
		for g in glows:
			g[0].set_shader_parameter("power", g[1] if on else 0.0)


class RoomSwitch extends LightSwitch:
	var group: LightGroup

	func _bind_light() -> void:
		_update_toggle_visual(false)

	func interact(_opener: Node3D = null) -> void:
		is_light_on = not is_light_on
		group.set_on(is_light_on)
		_update_toggle_visual(true)
		_play_switch_click()

	func _update_toggle_visual(animate: bool) -> void:
		if not toggle_mesh:
			return
		var deg := -8.0 if is_light_on else 8.0
		if animate:
			create_tween().tween_property(toggle_mesh, "rotation_degrees:x", deg, 0.07)
		else:
			toggle_mesh.rotation_degrees.x = deg


func _ready() -> void:
	name = "ApartmentLights"
	var room := LightGroup.new()
	_chandelier(Vector3(0.0, CEIL, 0.1), room)
	_omni(room, Vector3(0.0, CEIL - 0.34, 0.1), 0.85, 6.5)
	_switch(Vector3(2.64, FL + 1.25, 0.32), -90.0, room)

	var floor_lamp := LightGroup.new()
	_floor_lamp(Vector3(-1.4, FL, 1.9), floor_lamp)
	_omni(floor_lamp, Vector3(-1.4, FL + 1.5, 1.8), 0.5, 3.6)

	var bedroom := LightGroup.new()
	_drum_pendant(Vector3(0.0, CEIL, -4.4), bedroom)
	_omni(bedroom, Vector3(0.0, CEIL - 0.56, -4.4), 0.75, 6.0)
	_switch(Vector3(2.64, FL + 1.25, -3.74), -90.0, bedroom)

	var bedside := LightGroup.new()
	_table_lamp(Vector3(-0.5, FL + 0.6, -6.05), bedside)
	_omni(bedside, Vector3(-0.5, FL + 0.98, -5.98), 0.42, 2.6)

	var desk := LightGroup.new()
	_desk_lamp(Vector3(-2.43, FL + 0.75, -2.88), desk)
	_omni(desk, Vector3(-2.26, FL + 1.02, -2.9), 0.35, 1.8)

	var kitchen := LightGroup.new()
	_kitchen_pendant(Vector3(6.6, CEIL, -3.4), kitchen)
	_omni(kitchen, Vector3(6.6, CEIL - 0.97, -3.4), 1.0, 6.0)
	_under_cabinet(kitchen)
	_omni(kitchen, Vector3(6.67, FL + 1.38, -6.1), 0.5, 2.2)
	_switch(Vector3(4.26, FL + 1.25, -2.72), 90.0, kitchen)

	var hall := LightGroup.new()
	for z in [1.0, -3.4]:
		_ceiling_dome(Vector3(3.45, CEIL, z), 0.15, hall)
		_omni(hall, Vector3(3.45, CEIL - 0.2, z), 0.55, 3.4)
	_switch(Vector3(2.76, FL + 1.25, 1.62), 90.0, hall)

	var bath := LightGroup.new()
	_ceiling_dome(Vector3(5.7, CEIL, 0.7), 0.19, bath)
	_omni(bath, Vector3(5.7, CEIL - 0.25, 0.7), 0.95, 5.5)
	_mirror_bar(bath)
	_omni(bath, Vector3(5.2, FL + 2.02, -0.72), 0.42, 2.6)
	_switch(Vector3(4.262, FL + 1.25, 0.1), 90.0, bath)


func _omni(group: LightGroup, pos: Vector3, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = WARM
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = false
	add_child(l)
	l.position = pos
	group.lights.append(l)


func _c(r: float, y: float) -> Array:
	return _rg(r, r, r, y)


func _flush_glow(group: LightGroup, power: float) -> void:
	var m := _shader(GLOW_SHADER)
	m.set_shader_parameter("power", power)
	_flush(m)
	group.glows.append([m, power])


# Клавиша на стене; yaw поворачивает лицо выключателя от стены в комнату
func _switch(pos: Vector3, yaw: float, group: LightGroup) -> void:
	var at := _xf(pos, Vector3(0, yaw, 0))
	_base = at
	_loft([
		_rg(0.043, 0.043, 0.012, 0.0),
		_rg(0.043, 0.043, 0.012, 0.007),
		_rg(0.04, 0.04, 0.01, 0.0095),
		_rg(0.0, 0.0, 0.0, 0.0095),
	], Color(0.84, 0.83, 0.79), Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), 2)
	_flush(_vmat(0.35))

	var sw := RoomSwitch.new()
	sw.group = group
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.16, 0.16, 0.08)
	col.shape = shape
	sw.add_child(col)
	var key := CutsceneKit.box(sw, Vector3(0.056, 0.058, 0.01), Vector3(0, 0, 0.012), CutsceneKit.mat(Color(0.9, 0.89, 0.85), 0.3))
	key.name = "Toggle"
	add_child(sw)
	sw.transform = at


# Невидимая зона на самой лампе: щелчок включает или гасит её
func _lamp_toggle(centre: Vector3, size: Vector3, group: LightGroup) -> void:
	var sw := RoomSwitch.new()
	sw.group = group
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sw.add_child(col)
	add_child(sw)
	sw.position = centre


# Люстра: розетка, стержень, ваза и пять рожков со стеклянными плафонами
func _chandelier(at: Vector3, group: LightGroup) -> void:
	_base = _xf(at)
	_loft([_c(0.0, -0.035), _c(0.075, -0.035), _c(0.095, -0.012), _c(0.1, 0.0)], BRASS, Transform3D.IDENTITY, 5)
	_tube([Vector3.ZERO, Vector3(0, -0.15, 0), Vector3(0, -0.3, 0)], 0.0075, BRASS, 8)
	_bl(Vector3.ONE * 0.022, Vector3(0, -0.12, 0), BRASS)
	_bl(Vector3.ONE * 0.017, Vector3(0, -0.22, 0), BRASS)
	_loft([_c(0.0, -0.47), _c(0.012, -0.47), _c(0.03, -0.45), _c(0.07, -0.41), _c(0.08, -0.38), _c(0.06, -0.34),
		_c(0.025, -0.31), _c(0.012, -0.29), _c(0.0, -0.285)], BRASS, Transform3D.IDENTITY, 6)
	_bl(Vector3.ONE * 0.02, Vector3(0, -0.49, 0), BRASS)
	var tips := []
	for k in range(5):
		var a := TAU * float(k) / 5.0
		var d := Vector3(cos(a), 0, sin(a))
		_tube(_smooth([d * 0.05 + Vector3(0, -0.39, 0), d * 0.16 + Vector3(0, -0.485, 0), d * 0.29 + Vector3(0, -0.475, 0),
			d * 0.36 + Vector3(0, -0.4, 0), d * 0.365 + Vector3(0, -0.335, 0)], 6), 0.0085, BRASS, 8)
		var tip := d * 0.365
		tips.append(tip)
		_loft([_c(0.0, -0.34), _c(0.014, -0.34), _c(0.044, -0.32), _c(0.05, -0.31), _c(0.036, -0.305)], BRASS, _xf(tip), 5)
	_flush(_vmat(0.36, 0.65, true))

	_base = _xf(at)
	var low := SHADE
	var high := SHADE.darkened(0.2)
	for tip in tips:
		_loft([_c(0.03, -0.312), _c(0.052, -0.285), _c(0.078, -0.22), _c(0.092, -0.168)], low, _xf(tip), 6, [low, low, low.lerp(high, 0.5), high])
		_bl(Vector3.ONE * 0.022, tip + Vector3(0, -0.255, 0), Color(1.0, 0.92, 0.75))
	_flush_glow(group, 2.4)


# Торшер: тяжёлое основание, тонкая стойка, абажур
func _floor_lamp(at: Vector3, group: LightGroup) -> void:
	_base = _xf(at)
	_loft([_c(0.0, 0.0), _c(0.15, 0.0), _c(0.155, 0.012), _c(0.12, 0.03), _c(0.03, 0.05), _c(0.014, 0.08)], BRASS, Transform3D.IDENTITY, 6)
	_tube([Vector3(0, 0.05, 0), Vector3(0, 0.7, 0), Vector3(0, 1.4, 0)], 0.0115, BRASS, 8)
	_bl(Vector3.ONE * 0.022, Vector3(0, 0.82, 0), BRASS)
	_cy(0.03, 0.03, 0.07, Vector3(0, 1.385, 0), BRASS, Vector3.ZERO, 12)
	_torus(0.238, 0.246, Vector3(0, 1.36, 0), BRASS)
	_torus(0.138, 0.146, Vector3(0, 1.67, 0), BRASS)
	_flush(_vmat(0.36, 0.65))
	_base = _xf(at)
	_loft([_c(0.242, 1.36), _c(0.142, 1.67)], SHADE, Transform3D.IDENTITY, 7, [SHADE, SHADE.darkened(0.22)])
	_bl(Vector3.ONE * 0.04, Vector3(0, 1.48, 0), Color(1.0, 0.93, 0.78))
	_flush_glow(group, 1.5)
	_solid(at + Vector3(0, 0.8, 0), Vector3(0.18, 1.6, 0.18))
	_lamp_toggle(at + Vector3(0, 1.5, 0), Vector3(0.5, 0.36, 0.5), group)


# Подвесной светильник с большим тканевым абажуром
func _drum_pendant(at: Vector3, group: LightGroup) -> void:
	_base = _xf(at)
	_loft([_c(0.0, -0.03), _c(0.05, -0.03), _c(0.06, 0.0)], BRASS, Transform3D.IDENTITY, 5)
	_tube([Vector3.ZERO, Vector3(0, -0.2, 0), Vector3(0, -0.4, 0)], 0.0055, BRASS, 6)
	_torus(0.268, 0.277, Vector3(0, -0.4, 0), BRASS)
	_torus(0.268, 0.277, Vector3(0, -0.64, 0), BRASS)
	for k in range(3):
		var a := TAU * float(k) / 3.0
		_pipe(Vector3(0, -0.4, 0), Vector3(cos(a) * 0.27, -0.4, sin(a) * 0.27), 0.004, BRASS)
	_flush(_vmat(0.36, 0.65))
	_base = _xf(at)
	var edge := SHADE.darkened(0.14)
	_loft([_c(0.272, -0.64), _c(0.272, -0.4)], SHADE, Transform3D.IDENTITY, 10, [SHADE, edge])
	_loft([_c(0.0, -0.625), _c(0.268, -0.625)], Color(1.0, 0.92, 0.74), Transform3D.IDENTITY, 10)
	_flush_glow(group, 1.5)


# Настольная лампа у кровати: керамическая ножка и абажур
func _table_lamp(at: Vector3, group: LightGroup) -> void:
	var ceramic := Color(0.2, 0.36, 0.38)
	_base = _xf(at)
	_loft([_c(0.0, 0.0), _c(0.07, 0.0), _c(0.08, 0.02), _c(0.095, 0.1), _c(0.08, 0.18), _c(0.03, 0.24), _c(0.018, 0.27), _c(0.0, 0.27)],
		ceramic, Transform3D.IDENTITY, 6)
	_flush(_vmat(0.16))
	_base = _xf(at)
	_cy(0.012, 0.012, 0.13, Vector3(0, 0.33, 0), BRASS, Vector3.ZERO, 8)
	_flush(_vmat(0.36, 0.65))
	_base = _xf(at)
	_loft([_c(0.165, 0.27), _c(0.105, 0.5)], SHADE, Transform3D.IDENTITY, 7, [SHADE, SHADE.darkened(0.22)])
	_bl(Vector3.ONE * 0.03, Vector3(0, 0.36, 0), Color(1.0, 0.93, 0.78))
	_flush_glow(group, 1.5)
	_lamp_toggle(at + Vector3(0, 0.3, 0), Vector3(0.36, 0.56, 0.36), group)


# Рабочая лампа на столе: основание, два колена, колпак
func _desk_lamp(at: Vector3, group: LightGroup) -> void:
	var black := Color(0.08, 0.08, 0.09)
	var elbow := Vector3(0.02, 0.24, -0.02)
	var head := Vector3(0.17, 0.33, -0.02)
	_base = _xf(at)
	_loft([_c(0.0, 0.0), _c(0.085, 0.0), _c(0.085, 0.012), _c(0.06, 0.024), _c(0.015, 0.03)], black, Transform3D.IDENTITY, 6)
	_pipe(Vector3(0, 0.02, 0), elbow, 0.0075, black)
	_pipe(elbow, head, 0.0075, black)
	_bl(Vector3.ONE * 0.014, elbow, BRASS)
	_loft([_c(0.078, head.y - 0.1), _c(0.07, head.y - 0.06), _c(0.03, head.y - 0.015), _c(0.0, head.y)], black,
		_xf(Vector3(head.x, 0, head.z)), 6)
	_flush(_vmat(0.4, 0.3, true))
	_base = _xf(at)
	_bl(Vector3.ONE * 0.03, head + Vector3(0, -0.07, 0), Color(1.0, 0.94, 0.8))
	_flush_glow(group, 3.0)
	_lamp_toggle(at + Vector3(0.1, 0.22, -0.02), Vector3(0.34, 0.44, 0.2), group)


# Кухонный светильник над столом: эмалированный купол на шнуре
func _kitchen_pendant(at: Vector3, group: LightGroup) -> void:
	var enamel := Color(0.16, 0.3, 0.28)
	_base = _xf(at)
	_loft([_c(0.0, -0.03), _c(0.05, -0.03), _c(0.06, 0.0)], Color(0.1, 0.1, 0.11), Transform3D.IDENTITY, 5)
	_tube([Vector3.ZERO, Vector3(0, -0.4, 0), Vector3(0, -0.72, 0)], 0.0045, Color(0.08, 0.08, 0.09), 6)
	_loft([_c(0.2, -0.93), _c(0.192, -0.89), _c(0.13, -0.8), _c(0.052, -0.74), _c(0.03, -0.72), _c(0.0, -0.712)], enamel, Transform3D.IDENTITY, 8)
	_flush(_vmat(0.2))
	_base = _xf(at)
	var bright := Color(1.0, 0.9, 0.7)
	_loft([_c(0.197, -0.928), _c(0.125, -0.81), _c(0.046, -0.75), _c(0.0, -0.745)], bright.darkened(0.25), Transform3D.IDENTITY, 8)
	_bl(Vector3.ONE * 0.042, Vector3(0, -0.86, 0), bright)
	_flush_glow(group, 2.2)


# Светящаяся полоса под навесными шкафами
func _under_cabinet(group: LightGroup) -> void:
	_bx(Vector3(1.76, 0.008, 0.03), Vector3(6.67, FL + 1.496, -6.14), Color(1.0, 0.9, 0.72))
	_flush_glow(group, 2.4)


# Плоский плафон на потолке
func _ceiling_dome(at: Vector3, r: float, group: LightGroup) -> void:
	_base = _xf(at)
	_loft([_c(r * 0.96, -0.025), _c(r * 1.08, -0.018), _c(r * 1.1, 0.0)], BRASS, Transform3D.IDENTITY, 8)
	_flush(_vmat(0.36, 0.65))
	_base = _xf(at)
	var edge := SHADE.darkened(0.24)
	_loft([_c(0.0, -r * 0.62), _c(r * 0.5, -r * 0.56), _c(r * 0.82, -r * 0.34), _c(r * 0.97, -0.022)], SHADE, Transform3D.IDENTITY, 8,
		[Color(1.0, 0.92, 0.74), SHADE, SHADE.lerp(edge, 0.5), edge])
	_flush_glow(group, 1.8)


# Хромированная планка с тремя шарами над зеркалом
func _mirror_bar(group: LightGroup) -> void:
	var chrome := Color(0.8, 0.81, 0.84)
	var y := FL + 2.1
	var z := -0.94 + 0.075
	_tube([Vector3(4.92, y, z), Vector3(5.2, y, z), Vector3(5.48, y, z)], 0.0095, chrome, 8)
	_pipe(Vector3(5.2, y, -0.94), Vector3(5.2, y, z), 0.009, chrome)
	_cy(0.032, 0.036, 0.008, Vector3(5.2, y, -0.932), chrome, Vector3(90, 0, 0), 14)
	var xs := [4.96, 5.2, 5.44]
	for x in xs:
		_cy(0.018, 0.022, 0.025, Vector3(x, y - 0.018, z), chrome, Vector3.ZERO, 10)
	_flush(_vmat(0.26, 0.6))
	for x in xs:
		_bl(Vector3.ONE * 0.05, Vector3(x, y - 0.075, z), SHADE)
	_flush_glow(group, 2.0)
