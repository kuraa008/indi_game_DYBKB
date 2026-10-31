class_name FuseBox
extends StaticBody3D

# ══════════════════════════════════════════════════════════════════════════════
#  FuseBox.gd — Распределительный электрощиток с цветными предохранителями
#  • 3 гнезда для питания (батарейки или предохранители)
#  • Привязана к ID цепи (lock_id): питает электродвери с таким же ID
#  • При установке 3/3 питания и включении рубильника обесточивает
#    все электро-замки (ElectricMaglock) на связанных дверях и отпирает их
# ══════════════════════════════════════════════════════════════════════════════

signal fuses_completed
signal switch_pulled

@export var lock_id: int = 1   ## ID цепи питания (питает электродвери с совпадающим ID)

var has_red:   bool = false
var has_blue:  bool = false
var has_green: bool = false
var is_switch_on: bool = false

var red_mesh:   MeshInstance3D = null
var blue_mesh:  MeshInstance3D = null
var green_mesh: MeshInstance3D = null
var switch_arm: Node3D = null
var sfx_player: AudioStreamPlayer3D = null

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	set_meta("item_type", "fusebox")
	add_to_group("fuseboxes")
	if has_meta("lock_id"):
		lock_id = int(get_meta("lock_id"))
	elif has_meta("key_id"):
		lock_id = int(get_meta("key_id"))
	elif get_parent() and get_parent().has_meta("lock_id"):
		lock_id = int(get_parent().get_meta("lock_id"))
	elif get_parent() and get_parent().has_meta("key_id"):
		lock_id = int(get_parent().get_meta("key_id"))
	elif get_parent() and "lock_id" in get_parent():
		lock_id = int(get_parent().get("lock_id"))
	_find_parts()
	_setup_audio()
	_update_visuals()

func reset_fusebox() -> void:
	has_red = false
	has_blue = false
	has_green = false
	is_switch_on = false
	if switch_arm:
		switch_arm.rotation_degrees.x = -35.0
	_update_visuals()

func _find_parts() -> void:
	red_mesh   = find_child("FuseRed", true, false) as MeshInstance3D
	blue_mesh  = find_child("FuseBlue", true, false) as MeshInstance3D
	green_mesh = find_child("FuseGreen", true, false) as MeshInstance3D
	switch_arm = find_child("SwitchArm", true, false) as Node3D

func _setup_audio() -> void:
	sfx_player = AudioStreamPlayer3D.new()
	sfx_player.max_distance = 24.0
	sfx_player.unit_size = 4.5
	add_child(sfx_player)

func get_interaction_hint() -> String:
	var cur_pwr = GameManager.get_power_count(lock_id)
	if cur_pwr >= 3:
		return "[ЛКМ / RT]  Электрощиток цепи №%d: Линия замкнута (3/3)" % lock_id
	var item_name = _get_held_or_available_power_item_name()
	if item_name != "":
		return "[ЛКМ / RT]  Вставить %s в электрощиток цепи №%d [%d/3]" % [item_name, lock_id, cur_pwr]
	return "[ЛКМ / RT]  Электрощиток цепи №%d: Обесточен (%d/3 питания)" % [lock_id, cur_pwr]

func _get_held_or_available_power_item_name(opener: Node3D = null) -> String:
	var pl = opener if opener else GameManager.player_ref
	if pl and is_instance_valid(pl):
		var ho = pl.get("held_object")
		if ho and is_instance_valid(ho):
			var ho_type = str(ho.get_meta("item_type", "")).to_lower()
			if "red" in ho_type: return "красный предохранитель"
			if "blue" in ho_type: return "синий предохранитель"
			if "green" in ho_type: return "зелёный предохранитель"
			if "fuse" in ho_type: return "предохранитель"
			if "battery" in ho_type: return "батарею"
	if GameManager.has_fuse_red: return "красный предохранитель"
	if GameManager.has_fuse_blue: return "синий предохранитель"
	if GameManager.has_fuse_green: return "зелёный предохранитель"
	if GameManager.battery_cells >= 1: return "батарею"
	var bp_items = GameManager.get_backpack_items()
	for it in bp_items:
		if it:
			var id_str = str(it.get("id", "")).to_lower()
			if "red" in id_str: return "красный предохранитель"
			if "blue" in id_str: return "синий предохранитель"
			if "green" in id_str: return "зелёный предохранитель"
			if "fuse" in id_str: return "предохранитель"
			if "battery" in id_str: return "батарею"
	return ""

func interact(opener: Node3D = null) -> void:
	var cur_pwr = GameManager.get_power_count(lock_id)

	# 1. Если все 3 питания уже поданы — рубильник включен
	if cur_pwr >= 3:
		if not is_switch_on:
			_pull_switch()
			_power_up_electric_doors_with_id(lock_id)
		else:
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Электрощиток цепи №%d: Линия замкнута, питание на электродверь подано." % lock_id, 3.0)
		return

	# 2. Проверяем, есть ли у игрока предмет питания (батарейка или предохранитель)
	var consumed_type = _consume_power_item(opener)
	if consumed_type != "":
		cur_pwr = GameManager.add_power(lock_id, 1)
		_play_sfx("res://assets/audio/fuse_insert.wav")

		# Отображаем визуальные индикаторы гнезд
		if consumed_type == "fuse_red":
			has_red = true
		elif consumed_type == "fuse_blue":
			has_blue = true
		elif consumed_type == "fuse_green":
			has_green = true
		else:
			if not has_red: has_red = true
			elif not has_blue: has_blue = true
			else: has_green = true

		_update_visuals()

		if cur_pwr < 3:
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Питание [%d/3] установлено в щиток цепи №%d! Вставьте ещё %d шт." % [cur_pwr, lock_id, 3 - cur_pwr], 3.5)
		else:
			# 3/3 Питание собрано! Автоматически опускаем рубильник и запитываем двери
			_pull_switch()
			_power_up_electric_doors_with_id(lock_id)
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Все 3 питания установлены! Щиток цепи №%d замкнут, электродверь разблокирована!" % lock_id, 4.5)
		return

	# 3. У игрока нет батареи или предохранителя
	if GameManager.ui_ref:
		GameManager.ui_ref.call("show_hint",
			"Электрощиток цепи №%d: Обесточен (%d/3 питания).\nТребуются предохранители или батареи!" % [lock_id, cur_pwr], 4.0)

func _has_power_item(opener: Node3D = null) -> bool:
	return _get_held_or_available_power_item_name(opener) != ""

func _consume_power_item(opener: Node3D = null) -> String:
	var pl = opener if opener else GameManager.player_ref
	if pl and is_instance_valid(pl):
		var ho = pl.get("held_object")
		if ho and is_instance_valid(ho):
			var ho_type = str(ho.get_meta("item_type", "")).to_lower()
			if "fuse" in ho_type or "battery" in ho_type:
				pl.set("held_object", null)
				ho.queue_free()
				GameManager.emit_signal("inventory_changed")
				if "red" in ho_type: return "fuse_red"
				if "blue" in ho_type: return "fuse_blue"
				if "green" in ho_type: return "fuse_green"
				if "battery" in ho_type: return "battery"
				return "fuse"

	# Активный слот рюкзака
	var cur_slot = GameManager.active_item_index
	var bp_items = GameManager.get_backpack_items()
	if cur_slot >= 0 and cur_slot < bp_items.size():
		var it = bp_items[cur_slot]
		if it:
			var id_str = str(it.get("id", "")).to_lower()
			if "fuse" in id_str or "battery" in id_str:
				GameManager.drop_backpack_slot(cur_slot)
				GameManager.emit_signal("inventory_changed")
				if "red" in id_str: return "fuse_red"
				if "blue" in id_str: return "fuse_blue"
				if "green" in id_str: return "fuse_green"
				if "battery" in id_str: return "battery"
				return "fuse"

	if GameManager.has_fuse_red:
		GameManager.has_fuse_red = false
		GameManager.emit_signal("inventory_changed")
		return "fuse_red"
	if GameManager.has_fuse_blue:
		GameManager.has_fuse_blue = false
		GameManager.emit_signal("inventory_changed")
		return "fuse_blue"
	if GameManager.has_fuse_green:
		GameManager.has_fuse_green = false
		GameManager.emit_signal("inventory_changed")
		return "fuse_green"
	if GameManager.battery_cells >= 1:
		GameManager.battery_cells -= 1
		GameManager.emit_signal("battery_changed", GameManager.battery_cells)
		GameManager.emit_signal("inventory_changed")
		return "battery"

	for i in range(bp_items.size()):
		var it = bp_items[i]
		if it:
			var id_str = str(it.get("id", "")).to_lower()
			if "fuse" in id_str or "battery" in id_str:
				GameManager.drop_backpack_slot(i)
				GameManager.emit_signal("inventory_changed")
				if "red" in id_str: return "fuse_red"
				if "blue" in id_str: return "fuse_blue"
				if "green" in id_str: return "fuse_green"
				if "battery" in id_str: return "battery"
				return "fuse"

	return ""

func _power_up_electric_doors_with_id(p_id: int) -> void:
	if not is_inside_tree():
		return
	for d in get_tree().get_nodes_in_group("doors"):
		if is_instance_valid(d):
			var ctrl = d.call("_door_controller") if d.has_method("_door_controller") else d
			if ctrl and ctrl.has_method("get_effective_lock_id"):
				var c_id = ctrl.call("get_effective_lock_id")
				if c_id <= 0: c_id = 1
				if c_id == p_id or p_id <= 0:
					ctrl.set("is_powered", true)
					ctrl.set_meta("is_powered", true)
					ctrl.set("door_key_unlocked", true)
					ctrl.set_meta("door_key_unlocked", true)
					ctrl.set_meta("is_locked", false)
					var pnl = ctrl.find_child("Panel", true, false)
					if pnl:
						pnl.set_meta("is_locked", false)
						pnl.set("door_key_unlocked", true)
						pnl.set_meta("door_key_unlocked", true)
					var ml = ctrl.call("_get_maglock") if ctrl.has_method("_get_maglock") else null
					if ml and ml.has_method("deactivate"):
						ml.call("deactivate")
					if ctrl.has_method("_update_meter_visual"):
						ctrl.call("_update_meter_visual", true)

func _pull_switch() -> void:
	is_switch_on = true
	_play_sfx("res://assets/audio/switch_pull.wav")

	# Анимация поворота рукояти рубильника
	if switch_arm:
		var tw = create_tween()
		tw.tween_property(switch_arm, "rotation_degrees:x", 45.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	emit_signal("fuses_completed")
	emit_signal("switch_pulled")

func _update_visuals() -> void:
	var cur_p = GameManager.get_power_count(lock_id)
	if cur_p >= 1 and not has_red and not has_blue and not has_green:
		has_red = true
	if cur_p >= 2 and not has_blue and not has_green:
		has_blue = true
	if cur_p >= 3:
		has_red = true
		has_blue = true
		has_green = true

	if red_mesh:
		red_mesh.visible = has_red
	if blue_mesh:
		blue_mesh.visible = has_blue
	if green_mesh:
		green_mesh.visible = has_green

func _play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var s = ResourceLoader.load(path)
	if s and sfx_player:
		sfx_player.stream = s
		sfx_player.pitch_scale = randf_range(0.95, 1.05)
		sfx_player.play()
