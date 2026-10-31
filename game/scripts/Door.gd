extends Node3D

# ══════════════════════════════════════════════════════════════════════════════
#  Door.gd — Интерактивная реалистичная дверь
#  • Распахивание на боковых петлях (открывается в сторону ОТ игрока)
#  • Плавный поворот с физическим скрипом петель и защёлкиванием
#  • Единая настраиваемая выходная дверь (4 цвета ключей, доски, энергосчетчик)
#  • Поддержка обычных межкомнатных дверей, электро-дверей и выходной двери
#  • Возможность для врага выбивать/открывать дверь на бегу
# ══════════════════════════════════════════════════════════════════════════════

@export var lock_id: int = 0                      ## ID замка (0 = без замка, 1, 2, 3... - для открытия нужен ключ с таким же ID)
@export var required_key_color: String = "none"   ## "gold", "silver", "rusty", "emerald", "none" (для совместимости)
@export var requires_dual_keys: bool = false     ## Требуются оба ключа (Золотой + Серебряный)
@export var requires_boards: bool = false        ## Нужен лом для срывания досок
@export var requires_wire_panel: bool = false    ## Электрощиток с миниигрой проводов (Among Us)
@export var is_hatch: bool = false               ## Дверной люк (распахивается вверх/вниз)
@export var requires_power: bool = false         ## Требуется питание от энергосчетчика
@export var has_electric_meter: bool = false     ## Наличие энергосчетчика на косяке
@export var is_powered: bool = false             ## Подано ли питание
@export var is_exit: bool = false                ## Выходная дверь (переход между уровнями/побег)

var boards_node: Node3D = null   # Доски на двери выхода (Main.gd)
var door_body:   Node3D = null   # Полотно двери
var is_open:     bool   = false

var door_boards_broken: bool = false
var door_key_unlocked:  bool = false
var wire_panel_solved:  bool = false
var wire_panel_node:    Node3D = null

var transition_started: bool = false
var is_animating:       bool = false

var hinge_node:         Node3D = null
var audio_player:       AudioStreamPlayer3D = null
var padlock_node:       Node3D = null
var padlock_shackle:    Node3D = null
var current_open_angle: float = 0.0
var peek_swing_sign:    float = 1.0

# ──────────────────────────────────────────────────────────────────────────────
#  Таблица цветов, названий и параметров замков и ключей по ID
# ──────────────────────────────────────────────────────────────────────────────
static func get_lock_theme(id: int) -> Dictionary:
	match id:
		1:
			return {
				"name": "Золотой",
				"color": Color(0.98, 0.82, 0.15),
				"emission": Color(0.98, 0.75, 0.10),
				"icon": "",
				"metallic": 0.90,
				"roughness": 0.25
			}
		2:
			return {
				"name": "Серебряный",
				"color": Color(0.88, 0.92, 0.96),
				"emission": Color(0.65, 0.80, 0.95),
				"icon": "",
				"metallic": 0.95,
				"roughness": 0.18
			}
		3:
			return {
				"name": "Изумрудный",
				"color": Color(0.12, 0.88, 0.42),
				"emission": Color(0.10, 0.95, 0.35),
				"icon": "",
				"metallic": 0.40,
				"roughness": 0.20
			}
		4:
			return {
				"name": "Рубиновый",
				"color": Color(0.92, 0.18, 0.22),
				"emission": Color(0.95, 0.12, 0.15),
				"icon": "",
				"metallic": 0.50,
				"roughness": 0.20
			}
		5:
			return {
				"name": "Сапфировый",
				"color": Color(0.20, 0.52, 0.98),
				"emission": Color(0.15, 0.45, 0.95),
				"icon": "",
				"metallic": 0.55,
				"roughness": 0.20
			}
		6:
			return {
				"name": "Ржавый",
				"color": Color(0.60, 0.35, 0.18),
				"emission": Color(0.35, 0.18, 0.08),
				"icon": "",
				"metallic": 0.25,
				"roughness": 0.85
			}
		7:
			return {
				"name": "Аметистовый",
				"color": Color(0.72, 0.22, 0.88),
				"emission": Color(0.70, 0.15, 0.90),
				"icon": "",
				"metallic": 0.45,
				"roughness": 0.25
			}
		8:
			return {
				"name": "Бирюзовый",
				"color": Color(0.15, 0.88, 0.85),
				"emission": Color(0.10, 0.90, 0.88),
				"icon": "",
				"metallic": 0.60,
				"roughness": 0.20
			}
		9:
			return {
				"name": "Обсидиановый",
				"color": Color(0.14, 0.14, 0.16),
				"emission": Color(0.25, 0.25, 0.30),
				"icon": "",
				"metallic": 0.80,
				"roughness": 0.15
			}
		10:
			return {
				"name": "Платиновый",
				"color": Color(0.95, 0.95, 1.0),
				"emission": Color(0.90, 0.92, 1.0),
				"icon": "",
				"metallic": 0.98,
				"roughness": 0.10
			}
		_:
			var hue = fposmod(float(id) * 0.381966, 1.0)
			var c = Color.from_hsv(hue, 0.85, 0.95)
			return {
				"name": "Цветной #%d" % id,
				"color": c,
				"emission": c * 0.8,
				"icon": "",
				"metallic": 0.70,
				"roughness": 0.30
			}

static func color_to_lock_id(col_name: String) -> int:
	match col_name.to_lower():
		"gold": return 1
		"silver": return 2
		"emerald": return 3
		"ruby": return 4
		"sapphire": return 5
		"rusty": return 6
		"amethyst": return 7
		"cyan": return 8
		"black": return 9
		"white": return 10
		_: return 0

func _ready() -> void:
	if name != "Panel":
		add_to_group("doors")
	# Считываем метаданные
	if has_meta("lock_id"):
		lock_id = int(get_meta("lock_id"))
	elif has_meta("key_id"):
		lock_id = int(get_meta("key_id"))
	elif has_meta("required_key_color"):
		var c = str(get_meta("required_key_color"))
		if c != "" and c != "none":
			lock_id = color_to_lock_id(c)
	elif has_meta("key_color"):
		var c = str(get_meta("key_color"))
		if c != "" and c != "none":
			lock_id = color_to_lock_id(c)

	if has_meta("requires_boards"):
		requires_boards = bool(get_meta("requires_boards"))
	elif has_meta("has_boards"):
		requires_boards = bool(get_meta("has_boards"))
	elif has_meta("boards"):
		requires_boards = bool(get_meta("boards"))

	if has_meta("requires_wire_panel"):
		requires_wire_panel = bool(get_meta("requires_wire_panel"))
	elif has_meta("has_wire_panel"):
		requires_wire_panel = bool(get_meta("has_wire_panel"))

	if has_meta("is_hatch"):
		is_hatch = bool(get_meta("is_hatch"))

	if has_meta("requires_power"):
		requires_power = bool(get_meta("requires_power"))
	if has_meta("has_electric_meter"):
		has_electric_meter = bool(get_meta("has_electric_meter"))
	if has_meta("is_powered"):
		is_powered = bool(get_meta("is_powered"))

	_find_hinge()
	_setup_door_audio()
	_update_meter_visual(is_powered)

	# Применение текстуры двери
	var d_tex_key := ""
	if has_meta("door_texture"):
		d_tex_key = str(get_meta("door_texture"))
	elif get_parent() and get_parent().has_meta("door_texture"):
		d_tex_key = str(get_parent().get_meta("door_texture"))
	if d_tex_key != "" and d_tex_key != "none":
		call_deferred("_apply_saved_door_texture", d_tex_key)

	# Чистая модель: доски ТОЛЬКО если requires_boards == true
	if requires_boards and not door_boards_broken:
		call_deferred("_setup_boards")
	else:
		if boards_node and is_instance_valid(boards_node):
			boards_node.visible = false
		var b = find_child("Boards", true, false)
		if b:
			b.visible = false
		if get_parent():
			var pb = get_parent().find_child("Boards", true, false)
			if pb: pb.visible = false

	# Чистая модель: энергосчетчик ТОЛЬКО если дверь электрическая или requires_power
	var is_elec = (_get_door_type() == "electric" or requires_power or has_electric_meter)
	var m = find_child("ElectricMeter", true, false)
	if not m and get_parent():
		m = get_parent().find_child("ElectricMeter", true, false)
	if m:
		m.visible = is_elec

	# Электромагнитный замок ТОЛЬКО на электрических дверях
	var ml = _get_maglock()
	if ml:
		ml.visible = is_elec

	if requires_wire_panel:
		call_deferred("_setup_wire_panel")

	# Чистая модель: навесной замок ТОЛЬКО если есть lock_id > 0
	var eff_lid = get_effective_lock_id()
	if eff_lid <= 0 and _is_level_1() and _is_exit_door():
		eff_lid = 1
	if eff_lid > 0 and not door_key_unlocked:
		lock_id = eff_lid
		call_deferred("_setup_padlock")
	else:
		if padlock_node and is_instance_valid(padlock_node):
			padlock_node.queue_free()

func _apply_saved_door_texture(tex_key: String) -> void:
	var target: Node = self
	if get_parent() and get_parent().has_node("Hinge"):
		target = get_parent()
	TextureHelper.apply_door_texture_to_node(target, tex_key)

func _find_hinge() -> void:
	hinge_node = find_child("Hinge", true, false)
	if not hinge_node:
		var p = get_parent()
		if p:
			hinge_node = p.find_child("Hinge", true, false)
			if not hinge_node and p.name == "Hinge":
				hinge_node = p
	if not hinge_node and get_parent() and get_parent().get_parent():
		var gp = get_parent().get_parent()
		hinge_node = gp.find_child("Hinge", true, false)

func _setup_door_audio() -> void:
	audio_player = AudioStreamPlayer3D.new()
	audio_player.name = "DoorAudio"
	audio_player.max_distance = 25.0
	audio_player.unit_size = 5.0
	add_child(audio_player)

# ──────────────────────────────────────────────────────────────────────────────
#  Вспомогательные методы замков и электропитания
# ──────────────────────────────────────────────────────────────────────────────
func get_effective_lock_id() -> int:
	var lid: int = lock_id
	if lid <= 0 and has_meta("lock_id"):
		lid = int(get_meta("lock_id"))
	if lid <= 0 and has_meta("key_id"):
		lid = int(get_meta("key_id"))
	if lid <= 0 and (required_key_color != "none" and required_key_color != ""):
		lid = color_to_lock_id(required_key_color)
	if lid <= 0 and has_meta("required_key_color"):
		lid = color_to_lock_id(str(get_meta("required_key_color")))
	if lid <= 0 and has_meta("key_color"):
		lid = color_to_lock_id(str(get_meta("key_color")))

	if lid <= 0:
		var ctrl = _door_controller()
		if ctrl and ctrl != self and is_instance_valid(ctrl):
			if "lock_id" in ctrl and int(ctrl.get("lock_id")) > 0:
				lid = int(ctrl.get("lock_id"))
			elif ctrl.has_meta("lock_id") and int(ctrl.get_meta("lock_id")) > 0:
				lid = int(ctrl.get_meta("lock_id"))
			elif ctrl.has_meta("key_id") and int(ctrl.get_meta("key_id")) > 0:
				lid = int(ctrl.get_meta("key_id"))

	if lid <= 0:
		var pnl = find_child("Panel", true, false)
		if pnl and pnl != self:
			if "lock_id" in pnl and int(pnl.get("lock_id")) > 0:
				lid = int(pnl.get("lock_id"))
			elif pnl.has_meta("lock_id") and int(pnl.get_meta("lock_id")) > 0:
				lid = int(pnl.get_meta("lock_id"))
	return lid

func player_has_key_for_lock(lid: int, opener: Node3D = null) -> bool:
	if lid <= 0:
		return true

	# 1. GameManager (глобальный инвентарь ключей)
	if GameManager.has_key_id(lid):
		return true
	if lid == 1 and GameManager.has_key:
		return true

	# 2. Рюкзак игрока
	var bp_items = GameManager.get_backpack_items()
	for it in bp_items:
		if not it or it.is_empty():
			continue
		var i_id = str(it.get("id", ""))
		if i_id == "key_id_%d" % lid:
			return true
		if int(it.get("key_id", 0)) == lid:
			return true
		if lid == 1 and (i_id == "key_gold" or i_id == "key"):
			return true
		if lid == 2 and i_id == "key_silver":
			return true
		if lid == 3 and i_id == "key_emerald":
			return true
		if lid == 4 and i_id == "key_ruby":
			return true
		if lid == 5 and i_id == "key_sapphire":
			return true
		if lid == 6 and i_id == "key_rusty":
			return true

	# 3. Физически удерживаемый в руках предмет
	var pl = opener if opener else GameManager.player_ref
	if pl and is_instance_valid(pl):
		if pl.has_method("get_held_key_id"):
			if int(pl.call("get_held_key_id")) == lid:
				return true
		if pl.has_method("get_held_item_type"):
			var held_t = str(pl.call("get_held_item_type")).to_lower()
			if held_t == "key_id_" + str(lid) or held_t == "key_" + str(lid):
				return true
			if held_t == "key" and (lid == 1 or GameManager.keys_by_id.has(lid)):
				return true
		var ho = pl.get("held_object")
		if ho and is_instance_valid(ho):
			if ho.has_meta("key_id") and int(ho.get_meta("key_id")) == lid:
				return true
			if ho.has_meta("lock_id") and int(ho.get_meta("lock_id")) == lid:
				return true
			if ho.get("key_id") != null and int(ho.get("key_id")) == lid:
				return true
			var ho_type = str(ho.get_meta("item_type", "")).to_lower()
			if (ho_type == "key" or ho_type == "item_key") and lid == 1:
				return true
	return false

func _has_power_item(opener: Node3D = null) -> bool:
	if GameManager.battery_cells >= 1:
		return true
	if GameManager.has_fuse_red or GameManager.has_fuse_blue or GameManager.has_fuse_green:
		return true
	var pl = opener if opener else GameManager.player_ref
	if pl and is_instance_valid(pl):
		if pl.has_method("get_held_item_type"):
			var held_t = str(pl.call("get_held_item_type")).to_lower()
			if held_t in ["battery", "fuse", "fuse_red", "fuse_blue", "fuse_green"]:
				return true
		var ho = pl.get("held_object")
		if ho and is_instance_valid(ho):
			var ho_type = str(ho.get_meta("item_type", "")).to_lower()
			if ho_type in ["battery", "fuse", "fuse_red", "fuse_blue", "fuse_green"]:
				return true
	var bp_items = GameManager.get_backpack_items()
	for it in bp_items:
		if it and (it.get("id") == "battery" or str(it.get("id")).begins_with("fuse")):
			return true
	return false

func _consume_power_item(opener: Node3D = null) -> bool:
	if GameManager.battery_cells >= 1:
		GameManager.battery_cells -= 1
		GameManager.emit_signal("battery_changed", GameManager.battery_cells)
		GameManager.emit_signal("inventory_changed")
		return true
	if GameManager.has_fuse_red:
		GameManager.has_fuse_red = false
		GameManager.emit_signal("inventory_changed")
		return true
	if GameManager.has_fuse_blue:
		GameManager.has_fuse_blue = false
		GameManager.emit_signal("inventory_changed")
		return true
	if GameManager.has_fuse_green:
		GameManager.has_fuse_green = false
		GameManager.emit_signal("inventory_changed")
		return true
	var pl = opener if opener else GameManager.player_ref
	if pl and is_instance_valid(pl):
		var ho = pl.get("held_object")
		if ho and is_instance_valid(ho):
			var ho_type = str(ho.get_meta("item_type", "")).to_lower()
			if ho_type in ["battery", "fuse", "fuse_red", "fuse_blue", "fuse_green"]:
				pl.set("held_object", null)
				ho.queue_free()
				GameManager.emit_signal("inventory_changed")
				return true
	var bp_items = GameManager.get_backpack_items()
	for i in range(bp_items.size()):
		var it = bp_items[i]
		if it and (it.get("id") == "battery" or str(it.get("id")).begins_with("fuse")):
			GameManager.drop_backpack_slot(i)
			GameManager.emit_signal("inventory_changed")
			return true
	return false

# ──────────────────────────────────────────────────────────────────────────────
#  Основное взаимодействие
# ──────────────────────────────────────────────────────────────────────────────
func interact(opener: Node3D = null) -> void:
	var controller := _door_controller()
	if controller != self:
		controller.call("interact", opener)
		return

	var maglock = _get_maglock()
	var is_exit = _is_exit_door()
	var d_type = _get_door_type()
	var is_electric_door = (d_type == "electric" or requires_power or (has_electric_meter and requires_power) or (maglock != null and maglock.is_inside_tree()))

	# 1. Проверка досок (на ЛЮБОЙ двери, если requires_boards)
	if requires_boards and not door_boards_broken and not (is_exit and GameManager.door_boards_broken):
		var has_crowbar = GameManager.has_crowbar
		if not has_crowbar and opener and opener.has_method("get_held_item_type"):
			if str(opener.call("get_held_item_type")) == "crowbar":
				has_crowbar = true
		if has_crowbar:
			door_boards_broken = true
			if is_exit:
				GameManager.door_boards_broken = true
			_smash_boards()
			GameManager.add_score("player", 100, "Доски сорваны ломом")
			GameManager.emit_signal("inventory_changed")
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Доски сорваны! Дверь заперта на ключ. Найдите ключ от выхода!", 3.5)
		else:
			_play_locked_sound()
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Дверь заколочена досками. Нужен лом!", 3.0)
		return

	# 1.5. Проверка ключа для выходной двери на 1 уровне
	if _is_level_1() and is_exit and not door_key_unlocked:
		var eff_lid = get_effective_lock_id()
		if eff_lid <= 0:
			eff_lid = 1
		var has_key = player_has_key_for_lock(eff_lid, opener) or GameManager.has_key or GameManager.has_key_id(eff_lid)
		if not has_key and opener and opener.has_method("get_held_item_type"):
			var ht = str(opener.call("get_held_item_type")).to_lower()
			if "key" in ht:
				has_key = true
		if has_key:
			door_key_unlocked = true
			set_meta("is_locked", false)
			set_meta("door_key_unlocked", true)
			if get_parent():
				get_parent().set_meta("is_locked", false)
				get_parent().set_meta("door_key_unlocked", true)
			if opener and is_instance_valid(opener):
				var ho = opener.get("held_object")
				if ho and is_instance_valid(ho):
					var ho_kid = int(ho.get_meta("key_id", 0))
					var ho_t = str(ho.get_meta("item_type", "")).to_lower()
					var ho_nm = ho.name.to_lower()
					if ho_kid == eff_lid or ho_kid == 0 or "key" in ho_t or "key" in ho_nm:
						opener.set("held_object", null)
						ho.queue_free()
			_unlock_padlock()
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Выходная дверь отперта ключом!", 2.5)
			_open_door()
			_teleport_to_level_2()
			return
		else:
			_play_locked_sound()
			if GameManager.ui_ref:
				GameManager.ui_ref.call("show_hint", "Дверь заперта на ключ! Найдите ключ от выхода.", 3.0)
			return

	# 2. Проверка электрощитка с проводами (миниигра Among Us)
	if requires_wire_panel and not wire_panel_solved:
		_open_wire_puzzle()
		return

	# 3. Проверка электропитания двери (требуется 3 питания по ID)
	var eff_power_id = get_effective_lock_id()
	if eff_power_id <= 0:
		eff_power_id = 1
	var cur_power = GameManager.get_power_count(eff_power_id)
	var needs_power = (is_electric_door and cur_power < 3 and not is_powered) or (maglock and maglock.is_powered and cur_power < 3)

	if needs_power:
		_play_locked_sound()
		if GameManager.ui_ref:
			GameManager.ui_ref.call("show_hint", "Электродверь цепи №%d обесточена (%d/3 питания)!\nВставьте 3 предохранителя или батареи в электрощиток цепи №%d." % [eff_power_id, cur_power, eff_power_id], 4.0)
		return
	elif is_electric_door:
		# Питание подано (3/3 через электрощиток) — дверь запитана и разблокирована!
		is_powered = true
		door_key_unlocked = true
		set_meta("is_locked", false)
		set_meta("door_key_unlocked", true)
		if maglock and maglock.is_powered:
			maglock.deactivate()
		_update_meter_visual(true)
		if not is_exit and (required_key_color == "none" or required_key_color == ""):
			_toggle_simple_door(opener)
			_open_paired_doors_with_id(eff_power_id, opener)
			if _is_exit_door() or not _is_level_1():
				_trigger_alpha_end()
			return

	# 4. Проверка замков по ID (только для дверей с ключом, не для чисто электрических!)
	var eff_lock_id = get_effective_lock_id()
	if eff_lock_id > 0 and not door_key_unlocked and not is_electric_door:
		var has_key = player_has_key_for_lock(eff_lock_id, opener)
		if has_key:
			door_key_unlocked = true
			set_meta("is_locked", false)
			set_meta("door_key_unlocked", true)
			if get_parent():
				get_parent().set_meta("is_locked", false)
				get_parent().set_meta("door_key_unlocked", true)
				if "door_key_unlocked" in get_parent():
					get_parent().set("door_key_unlocked", true)
			var pnl = find_child("Panel", true, false)
			if pnl:
				pnl.set_meta("is_locked", false)
				pnl.set_meta("door_key_unlocked", true)
				pnl.set("door_key_unlocked", true)
			if opener and is_instance_valid(opener):
				var ho = opener.get("held_object")
				if ho and is_instance_valid(ho):
					var ho_kid = int(ho.get_meta("key_id", 0))
					if ho_kid == 0 and ho.get("key_id") != null:
						ho_kid = int(ho.get("key_id"))
					var ho_t = str(ho.get_meta("item_type", "")).to_lower()
					var ho_nm = ho.name.to_lower()
					if ho_kid == eff_lock_id or (ho_kid == 0 and ("key" in ho_t or "key" in ho_nm)):
						opener.set("held_object", null)
						ho.queue_free()
			_unlock_padlock()
			# Разблокируем ВСЕ двери на карте с таким же lock_id ("при одинаковом айди они друг друга открывали")
			_unlock_all_doors_with_id(eff_lock_id)
			if GameManager.ui_ref:
				var th = get_lock_theme(eff_lock_id)
				GameManager.ui_ref.call("show_hint", "Замок №%d (%s) открыт ключом!" % [eff_lock_id, th["name"]], 2.5)
			if not is_exit:
				_toggle_simple_door(opener)
				_open_paired_doors_with_id(eff_lock_id, opener)
				return
		else:
			_play_locked_sound()
			if GameManager.ui_ref:
				var th = get_lock_theme(eff_lock_id)
				GameManager.ui_ref.call("show_hint", "Дверь заперта на замок №%d (%s). Нужен ключ №%d." % [eff_lock_id, th["name"], eff_lock_id], 3.0)
			return

	# 5. Проверка устаревших цветных замков (для совместимости)
	if required_key_color != "none" and required_key_color != "" and not door_key_unlocked:
		var has_key = GameManager.has_key_color(required_key_color)
		if not has_key and opener and opener.has_method("get_held_item_type"):
			var held_t = str(opener.call("get_held_item_type"))
			if held_t == "key_" + required_key_color or held_t == required_key_color or held_t == "key":
				has_key = true
		if has_key:
			door_key_unlocked = true
			set_meta("is_locked", false)
			if get_parent():
				get_parent().set_meta("is_locked", false)
			_unlock_padlock()
			if not is_exit:
				_toggle_simple_door(opener)
				return
		else:
			_play_locked_sound()
			return

	# 6. Побег через выходную дверь
	if is_exit:
		_unlock_padlock()
		_open_door()
		GameManager.add_score("player", 500, "Побег из особняка совершен")
		if _is_level_1():
			_teleport_to_level_2()
			return
		_trigger_alpha_end()
		return

	# Иначе обычная дверь
	_toggle_simple_door(opener)
	_open_paired_doors_with_id(eff_lock_id, opener)

func _unlock_all_doors_with_id(lid: int) -> void:
	if lid <= 0 or not is_inside_tree():
		return
	for d in get_tree().get_nodes_in_group("doors"):
		if is_instance_valid(d):
			var ctrl = d.call("_door_controller") if d.has_method("_door_controller") else d
			if ctrl and ctrl.has_method("get_effective_lock_id"):
				if ctrl.call("get_effective_lock_id") == lid:
					ctrl.set("door_key_unlocked", true)
					ctrl.set_meta("is_locked", false)
					ctrl.set_meta("door_key_unlocked", true)
					if ctrl.has_method("_unlock_padlock"):
						ctrl.call("_unlock_padlock")

func _open_paired_doors_with_id(lid: int, opener: Node3D = null) -> void:
	if lid <= 0 or not is_inside_tree():
		return
	for d in get_tree().get_nodes_in_group("doors"):
		if is_instance_valid(d) and d != self:
			var ctrl = d.call("_door_controller") if d.has_method("_door_controller") else d
			if ctrl != self and is_instance_valid(ctrl) and ctrl.has_method("get_effective_lock_id"):
				if ctrl.call("get_effective_lock_id") == lid:
					if global_position.distance_to(ctrl.global_position) < 3.2:
						if not ctrl.get("is_open") and not ctrl.get("is_animating"):
							ctrl.call("_toggle_simple_door", opener)

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
					ctrl.set_meta("is_locked", false)
					var ml = ctrl.call("_get_maglock") if ctrl.has_method("_get_maglock") else null
					if ml and ml.has_method("deactivate"):
						ml.call("deactivate")
					if ctrl.has_method("_update_meter_visual"):
						ctrl.call("_update_meter_visual", true)

func get_interaction_hint() -> String:
	var controller := _door_controller()
	if controller != self:
		return str(controller.call("get_interaction_hint"))
	if is_open:
		if is_hatch:
			return "[ЛКМ / RT]  Закрыть люк"
		if _is_exit_door():
			return "[ЛКМ / RT]  Открыть выход"
		if absf(current_open_angle) < 45.0:
			return "[ЛКМ / RT] Закрыть  •  [Колесико] Щель: %d°" % int(abs(current_open_angle))
		return "[ЛКМ / RT]  Закрыть дверь  •  [Колесико] Прикрыть"

	var is_exit = _is_exit_door()
	var d_type = _get_door_type()
	var maglock = _get_maglock()

	# 1. Проверка досок
	if requires_boards and not door_boards_broken and not (is_exit and GameManager.door_boards_broken):
		if GameManager.has_crowbar:
			return "[ЛКМ / RT]  Сорвать доски ломом"
		else:
			return "[ЛКМ / RT]  Заколочено досками (нужен лом)"

	# 1.5. Проверка ключа для выходной двери на 1 уровне
	if _is_level_1() and is_exit and not door_key_unlocked:
		var eff_lid = get_effective_lock_id()
		if eff_lid <= 0:
			eff_lid = 1
		var has_key = player_has_key_for_lock(eff_lid) or GameManager.has_key or GameManager.has_key_id(eff_lid)
		var player = GameManager.player_ref
		if not has_key and player and player.has_method("get_held_item_type"):
			if "key" in str(player.call("get_held_item_type")).to_lower():
				has_key = true
		if has_key:
			return "[ЛКМ / RT]  Открыть выход ключом"
		else:
			return "[ЛКМ / RT]  Заперто на ключ (нужен ключ от выхода)"

	# 2. Проверка электрощитка
	if requires_wire_panel and not wire_panel_solved:
		return "[ЛКМ / RT]  Открыть электрощиток"

	# 3. Проверка питания (электро-дверь, счетчик или maglock)
	var is_electric_door = (d_type == "electric" or requires_power or (has_electric_meter and requires_power) or (maglock != null and maglock.is_inside_tree()))
	var eff_power_id = get_effective_lock_id()
	if eff_power_id <= 0: eff_power_id = 1
	var cur_power = GameManager.get_power_count(eff_power_id)
	if (is_electric_door and cur_power < 3 and not is_powered) or (maglock and maglock.is_powered and cur_power < 3):
		return "[ЛКМ / RT]  Электродверь цепи №%d: Обесточена (%d/3 питания — нужен щиток №%d)" % [eff_power_id, cur_power, eff_power_id]

	# 4. Проверка замка по ID (только для дверей с ключом)
	var eff_lock_id = get_effective_lock_id()
	if eff_lock_id > 0 and not door_key_unlocked and not is_electric_door:
		var th = get_lock_theme(eff_lock_id)
		if player_has_key_for_lock(eff_lock_id):
			return "[ЛКМ / RT]  Отпереть замок №%d (%s ключ)" % [eff_lock_id, th["name"]]
		else:
			return "[ЛКМ / RT]  Замок №%d (%s) — заперт (нужен ключ №%d)" % [eff_lock_id, th["name"], eff_lock_id]

	# 5. Устаревший цветной замок
	if required_key_color != "none" and required_key_color != "" and not door_key_unlocked:
		if GameManager.has_key_color(required_key_color):
			return "[ЛКМ / RT]  Отпереть замок (%s)" % _key_name_ru(required_key_color)
		else:
			return "[ЛКМ / RT]  Замок заперт (нужен %s ключ)" % _key_name_ru(required_key_color)

	if _check_meta_locked():
		return "[ЛКМ / RT]  Дверь заперта"

	if is_exit:
		return "[ЛКМ / RT]  Открыть выход"

	if is_hatch:
		if _is_level_2():
			return "[🔒] Земной люк заперт снаружи"
		return "[ЛКМ / RT]  Открыть люк"

	return "[ЛКМ / RT] Открыть  •  [Колесико] Приоткрыть"

func get_escape_checklist() -> Dictionary:
	var boards_done = not requires_boards or door_boards_broken or GameManager.door_boards_broken
	var power_done = not (requires_power or has_electric_meter) or is_powered
	var key_done = required_key_color == "none" or door_key_unlocked or GameManager.has_key_color(required_key_color)

	return {
		"is_exit": has_meta("is_exit") or get_meta("door_type", "boards") == "boards",
		"boards_needed": requires_boards,
		"boards_done": boards_done,
		"power_needed": requires_power or has_electric_meter,
		"power_done": power_done,
		"key_needed": required_key_color != "none",
		"key_color": required_key_color,
		"key_name_ru": _key_name_ru(required_key_color),
		"key_done": key_done,
		"is_ready_to_open": boards_done and power_done and key_done,
		"is_open": is_open
	}

func get_door_info() -> Dictionary:
	var controller := _door_controller()
	if controller != self and controller.has_method("get_door_info"):
		return controller.call("get_door_info")

	var is_exit = _is_exit_door()
	var bds_needed = requires_boards and not door_boards_broken and not (is_exit and GameManager.door_boards_broken)
	var has_cb = GameManager.has_crowbar
	var player = GameManager.player_ref
	if not has_cb and player and player.has_method("get_held_item_type"):
		if str(player.call("get_held_item_type")) == "crowbar":
			has_cb = true

	var has_k = false
	if lock_id > 0:
		has_k = door_key_unlocked or GameManager.has_key_id(lock_id)
		if not has_k and player and player.has_method("get_held_key_id"):
			if int(player.call("get_held_key_id")) == lock_id:
				has_k = true
	elif required_key_color != "none" and required_key_color != "":
		has_k = door_key_unlocked or GameManager.has_key_color(required_key_color)

	var th = get_lock_theme(lock_id) if lock_id > 0 else {}
	var d_name = "ВЫХОДНАЯ ДВЕРЬ" if is_exit else ("ДВЕРЬ №%d" % lock_id if lock_id > 0 else ("ДВЕРНОЙ ЛЮК" if is_hatch else "ДВЕРЬ"))

	return {
		"is_exit": is_exit,
		"is_open": is_open,
		"is_hatch": is_hatch,
		"door_name": d_name,
		"lock_id": lock_id,
		"lock_theme": th,
		"door_key_unlocked": door_key_unlocked,
		"has_key": has_k,
		"requires_boards": requires_boards,
		"boards_needed": bds_needed,
		"boards_broken": door_boards_broken or (is_exit and GameManager.door_boards_broken),
		"has_crowbar": has_cb,
		"requires_wire_panel": requires_wire_panel,
		"wire_panel_solved": wire_panel_solved,
		"requires_power": (requires_power or has_electric_meter),
		"is_powered": is_powered,
		"power_cells_have": GameManager.battery_cells,
		"is_locked_meta": _check_meta_locked()
	}

func _setup_boards() -> void:
	if not requires_boards or door_boards_broken or (_is_exit_door() and GameManager.door_boards_broken):
		return
	if boards_node:
		boards_node.visible = true
		return
	var existing = get_node_or_null("Boards")
	if existing:
		boards_node = existing
		boards_node.visible = true
		return

	boards_node = Node3D.new()
	boards_node.name = "Boards"

	var plank_mat = StandardMaterial3D.new()
	plank_mat.albedo_color = Color(0.38, 0.24, 0.14)
	plank_mat.roughness = 0.88

	var nail_mat = StandardMaterial3D.new()
	nail_mat.albedo_color = Color(0.22, 0.22, 0.24)
	nail_mat.metallic = 0.9
	nail_mat.roughness = 0.35

	var heights = [0.55, 1.15, 1.72]
	var tilts = [0.0, 0.0, 0.0]
	for idx in range(3):
		var plank = MeshInstance3D.new()
		plank.name = "Plank_%d" % idx
		var pm = BoxMesh.new()
		pm.size = Vector3(1.15, 0.16, 0.04)
		pm.material = plank_mat
		plank.mesh = pm
		plank.position = Vector3(0.0, heights[idx], -0.065)
		plank.rotation_degrees = Vector3.ZERO
		boards_node.add_child(plank)

		for nx in [-0.46, 0.46]:
			var nail = MeshInstance3D.new()
			var nm = CylinderMesh.new()
			nm.top_radius = 0.016
			nm.bottom_radius = 0.016
			nm.height = 0.045
			nm.material = nail_mat
			nail.mesh = nm
			nail.rotation_degrees = Vector3(90, 0, 0)
			nail.position = Vector3(nx, 0, -0.02)
			plank.add_child(nail)

	add_child(boards_node)

func _setup_padlock() -> void:
	if lock_id <= 0:
		lock_id = get_effective_lock_id()
	if lock_id <= 0 and (required_key_color == "none" or required_key_color == ""):
		return
	if is_open or padlock_node:
		return

	if lock_id <= 0:
		lock_id = color_to_lock_id(required_key_color)
	if lock_id <= 0:
		return

	var th = get_lock_theme(lock_id)

	padlock_node = Node3D.new()
	padlock_node.name = "DoorPadlock"
	padlock_node.position = Vector3(0.44, 1.06, -0.08)

	var steel_mat = StandardMaterial3D.new()
	steel_mat.albedo_color = Color(0.72, 0.75, 0.80)
	steel_mat.metallic = 0.95
	steel_mat.roughness = 0.18

	var dark_iron = StandardMaterial3D.new()
	dark_iron.albedo_color = Color(0.18, 0.20, 0.22)
	dark_iron.metallic = 0.92
	dark_iron.roughness = 0.40

	# 1. Тяжёлая стальная проушина/петля на двери (Hasp plate & loop)
	var hasp_plate = MeshInstance3D.new()
	var hpm = BoxMesh.new()
	hpm.size = Vector3(0.15, 0.048, 0.016)
	hpm.material = dark_iron
	hasp_plate.mesh = hpm
	hasp_plate.position = Vector3(0, 0.038, 0.02)
	padlock_node.add_child(hasp_plate)

	# 4 болта крепления планки
	for bx in [-0.055, 0.055]:
		for by in [-0.014, 0.014]:
			var bolt = MeshInstance3D.new()
			var bm_b = CylinderMesh.new()
			bm_b.top_radius = 0.006
			bm_b.bottom_radius = 0.006
			bm_b.height = 0.008
			bm_b.material = steel_mat
			bolt.mesh = bm_b
			bolt.rotation_degrees = Vector3(90, 0, 0)
			bolt.position = Vector3(bx, 0.038 + by, 0.028)
			padlock_node.add_child(bolt)

	# 2. Мощная хромированная U-образная дужка замка (Hardened steel shackle)
	padlock_shackle = Node3D.new()
	padlock_shackle.name = "Shackle"
	padlock_shackle.position = Vector3(0, 0.032, 0)
	padlock_node.add_child(padlock_shackle)

	# Верхняя арка дужки
	var shackle_arch = MeshInstance3D.new()
	var sam = TorusMesh.new()
	sam.inner_radius = 0.026
	sam.outer_radius = 0.046
	sam.material = steel_mat
	shackle_arch.mesh = sam
	padlock_shackle.add_child(shackle_arch)

	# Вертикальные ножки дужки, входящие в корпус
	for sx in [-0.036, 0.036]:
		var leg = MeshInstance3D.new()
		var lm = CylinderMesh.new()
		lm.top_radius = 0.010
		lm.bottom_radius = 0.010
		lm.height = 0.045
		lm.material = steel_mat
		leg.mesh = lm
		leg.position = Vector3(sx, -0.022, 0)
		padlock_shackle.add_child(leg)

	# 3. Массивный фигурный корпус замка (Основной блок + скругленный низ)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = th["color"]
	body_mat.metallic = th["metallic"]
	body_mat.roughness = th["roughness"]
	body_mat.emission_enabled = true
	body_mat.emission = th["emission"]
	body_mat.emission_energy_multiplier = 0.35

	var body = MeshInstance3D.new()
	body.name = "LockBody"
	var bm = BoxMesh.new()
	bm.size = Vector3(0.11, 0.09, 0.044)
	bm.material = body_mat
	body.mesh = bm
	body.position = Vector3(0, -0.035, 0)
	padlock_node.add_child(body)

	# Скругленная нижняя часть корпуса
	var round_bottom = MeshInstance3D.new()
	var rbm = CylinderMesh.new()
	rbm.top_radius = 0.055
	rbm.bottom_radius = 0.055
	rbm.height = 0.044
	rbm.material = body_mat
	round_bottom.mesh = rbm
	round_bottom.rotation_degrees = Vector3(90, 0, 0)
	round_bottom.position = Vector3(0, -0.08, 0)
	padlock_node.add_child(round_bottom)

	# Верхняя бронепластина с отверстиями под дужку
	var top_armor = MeshInstance3D.new()
	var tam = BoxMesh.new()
	tam.size = Vector3(0.115, 0.012, 0.048)
	tam.material = dark_iron
	top_armor.mesh = tam
	top_armor.position = Vector3(0, 0.012, 0)
	padlock_node.add_child(top_armor)

	# Заклёпки на углах корпуса
	for rx in [-0.042, 0.042]:
		for ry in [-0.015, -0.055]:
			var rivet = MeshInstance3D.new()
			var rvm = CylinderMesh.new()
			rvm.top_radius = 0.005
			rvm.bottom_radius = 0.005
			rvm.height = 0.004
			rvm.material = steel_mat
			rivet.mesh = rvm
			rivet.rotation_degrees = Vector3(90, 0, 0)
			rivet.position = Vector3(rx, ry, -0.023)
			padlock_node.add_child(rivet)

	# 4. Замочная скважина внизу
	var keyhole = MeshInstance3D.new()
	var khm = BoxMesh.new()
	khm.size = Vector3(0.008, 0.022, 0.010)
	var black_mat = StandardMaterial3D.new()
	black_mat.albedo_color = Color(0.04, 0.04, 0.05)
	khm.material = black_mat
	keyhole.mesh = khm
	keyhole.position = Vector3(0, -0.115, 0)
	padlock_node.add_child(keyhole)

	# 5. Контрастная металлическая шильда/табличка по центру с номером
	var plaque = MeshInstance3D.new()
	var pqm = BoxMesh.new()
	pqm.size = Vector3(0.078, 0.048, 0.006)
	var pq_mat = StandardMaterial3D.new()
	pq_mat.albedo_color = Color(0.12, 0.14, 0.16)
	pq_mat.metallic = 0.90
	pq_mat.roughness = 0.30
	pqm.material = pq_mat
	plaque.mesh = pqm
	plaque.position = Vector3(0, -0.038, -0.023)
	padlock_node.add_child(plaque)

	# 3D номер замка (например "№1", "№2")
	var num_label = Label3D.new()
	num_label.name = "LockNumber"
	num_label.text = "№%d" % lock_id
	num_label.font_size = 36
	num_label.pixel_size = 0.0014
	num_label.outline_size = 5
	num_label.outline_modulate = Color(0.05, 0.05, 0.05, 1.0)
	num_label.modulate = Color(1.0, 1.0, 0.95, 1.0)
	num_label.position = Vector3(0, -0.038, -0.028)
	padlock_node.add_child(num_label)

	var glow = OmniLight3D.new()
	glow.light_color = th["emission"]
	glow.light_energy = 0.75
	glow.omni_range = 1.6
	padlock_node.add_child(glow)

	var panel = find_child("Panel", true, false)
	if panel:
		var target_x: float = 0.44
		var target_y: float = 1.06
		var target_z: float = -0.08
		var leaf = panel.find_child("DoorLeaf", true, false)
		if leaf and leaf is MeshInstance3D and leaf.mesh is BoxMesh:
			var leaf_box: BoxMesh = leaf.mesh as BoxMesh
			if leaf.position.x > 0.1:
				target_x = leaf.position.x + (leaf_box.size.x * 0.5) - 0.14
				target_y = leaf.position.y * 0.95
				target_z = -leaf_box.size.z * 0.5 - 0.04
			else:
				target_x = (leaf_box.size.x * 0.5) - 0.14
				target_y = 0.0
				target_z = -leaf_box.size.z * 0.5 - 0.04
		elif panel.has_node("Handle_front") or panel.has_node("Handle_back"):
			var h = panel.get_node_or_null("Handle_front")
			if not h: h = panel.get_node_or_null("Handle_back")
			if h:
				target_x = h.position.x - 0.04
				target_y = h.position.y - 0.05
				target_z = h.position.z - 0.04
		padlock_node.position = Vector3(target_x, target_y, target_z)
		panel.add_child(padlock_node)
	else:
		add_child(padlock_node)

func _setup_wire_panel() -> void:
	if not requires_wire_panel or wire_panel_solved or wire_panel_node:
		return

	wire_panel_node = Node3D.new()
	wire_panel_node.name = "WirePanelBox"
	wire_panel_node.position = Vector3(0.38, 1.35, -0.08)

	var box_m = BoxMesh.new()
	box_m.size = Vector3(0.24, 0.28, 0.08)
	var box_mat = StandardMaterial3D.new()
	box_mat.albedo_color = Color(0.28, 0.30, 0.34)
	box_mat.metallic = 0.8
	box_mat.roughness = 0.35
	box_m.material = box_mat
	var box = MeshInstance3D.new()
	box.mesh = box_m
	wire_panel_node.add_child(box)

	var sign_m = BoxMesh.new()
	sign_m.size = Vector3(0.12, 0.12, 0.01)
	var sign_mat = StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.95, 0.80, 0.10)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.95, 0.80, 0.10)
	sign_mat.emission_energy_multiplier = 0.5
	sign_m.material = sign_mat
	var sign_mesh = MeshInstance3D.new()
	sign_mesh.mesh = sign_m
	sign_mesh.position = Vector3(0, 0.02, -0.042)
	wire_panel_node.add_child(sign_mesh)

	var led_m = SphereMesh.new()
	led_m.radius = 0.02
	led_m.height = 0.04
	var led_mat = StandardMaterial3D.new()
	led_mat.albedo_color = Color(0.9, 0.1, 0.1) if not wire_panel_solved else Color(0.1, 0.9, 0.2)
	led_mat.emission_enabled = true
	led_mat.emission = led_mat.albedo_color
	led_mat.emission_energy_multiplier = 1.2
	led_m.material = led_mat
	var led = MeshInstance3D.new()
	led.name = "PanelLED"
	led.mesh = led_m
	led.position = Vector3(0, -0.08, -0.042)
	wire_panel_node.add_child(led)

	var panel = find_child("Panel", true, false)
	if panel:
		panel.add_child(wire_panel_node)
	else:
		add_child(wire_panel_node)

func _open_wire_puzzle() -> void:
	var existing = get_tree().root.find_child("WirePuzzleUI", true, false)
	if existing:
		return
	var puzzle_script = load("res://scripts/WirePuzzleUI.gd")
	var puzzle = puzzle_script.new()
	get_tree().root.add_child(puzzle)
	puzzle.open_for_door(self)
	puzzle.solved.connect(func():
		wire_panel_solved = true
		if wire_panel_node:
			var led = wire_panel_node.find_child("PanelLED", true, false)
			if led and led.mesh and led.mesh.material:
				var m: StandardMaterial3D = led.mesh.material
				m.albedo_color = Color(0.1, 0.95, 0.2)
				m.emission = Color(0.1, 0.95, 0.2)
	)

func _unlock_padlock() -> void:
	if not padlock_node:
		return
	_play_unlock_sfx()
	if padlock_shackle:
		var tw_shackle = create_tween()
		tw_shackle.tween_property(padlock_shackle, "rotation_degrees:z", -40.0, 0.12)
	var tw = create_tween()
	tw.tween_interval(0.12)
	tw.tween_property(padlock_node, "position:y", padlock_node.position.y - 0.7, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(padlock_node, "rotation_degrees:x", 65.0, 0.35)
	tw.tween_callback(padlock_node.queue_free)

func _play_unlock_sfx() -> void:
	if not audio_player:
		return
	var unlock_paths = [
		"res://assets/audio/door_unlock_1.mp3",
		"res://assets/audio/door_unlock_2.mp3",
		"res://assets/audio/door_unlock_3.mp3"
	]
	var pick_path: String = unlock_paths.pick_random()
	if ResourceLoader.exists(pick_path):
		var st = load(pick_path)
		if st:
			audio_player.stream = st
			audio_player.volume_db = 2.5
			audio_player.pitch_scale = randf_range(0.96, 1.04)
			audio_player.play()
			return

	var sample_count = int(44100 * 0.18)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 22.0)
		var click = (sin(t * 1200.0 * TAU) * 0.5 + sin(t * 3100.0 * TAU) * 0.5) * env
		var val16 = int(clamp(click, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.play()

func _key_name_ru(color: String) -> String:
	match color.to_lower():
		"gold": return "Золотой"
		"silver": return "Серебряный"
		"rusty": return "Ржавый"
		"emerald": return "Изумрудный"
		_: return "подходящий"

func _update_meter_visual(powered: bool) -> void:
	var led = find_child("MeterLED", true, false)
	if not led:
		led = find_child("Led", true, false)
	if led and led is MeshInstance3D:
		var mat = led.get_surface_override_material(0)
		if not mat and led.mesh and "material" in led.mesh:
			mat = led.mesh.material
		if not mat:
			mat = StandardMaterial3D.new()
			led.set_surface_override_material(0, mat)
		if mat is StandardMaterial3D:
			mat.albedo_color = Color(0.1, 0.95, 0.2) if powered else Color(0.9, 0.1, 0.1)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.95, 0.2) if powered else Color(0.9, 0.1, 0.1)
			mat.emission_energy_multiplier = 2.0 if powered else 0.8

	var light = find_child("MeterLight", true, false)
	if light and light is OmniLight3D:
		light.light_color = Color(0.2, 1.0, 0.3) if powered else Color(1.0, 0.1, 0.1)
		light.light_energy = 1.2 if powered else 0.4

func _play_meter_power_sfx() -> void:
	if ResourceLoader.exists("res://assets/audio/electric_spark.wav"):
		var s = ResourceLoader.load("res://assets/audio/electric_spark.wav")
		if s and audio_player:
			audio_player.stream = s
			audio_player.play()

# ──────────────────────────────────────────────────────────────────────────────
#  Обычная дверь (распахивание от открывающего на петлях)
# ──────────────────────────────────────────────────────────────────────────────
func _toggle_simple_door(opener: Node3D = null) -> void:
	var ctrl = _door_controller()
	if ctrl != self and is_instance_valid(ctrl):
		ctrl.call("_toggle_simple_door", opener)
		return

	if is_animating:
		return
	is_animating = true

	if is_hatch:
		if _is_level_2():
			is_animating = false
			_play_locked_sound()
			if GameManager and GameManager.ui_ref and GameManager.ui_ref.has_method("show_hint"):
				GameManager.ui_ref.call("show_hint", "🔒 Люк заперт снаружи и пока не открывается...", 3.0)
			return
		is_open = not is_open
		var target_rot_node: Node3D = hinge_node if hinge_node else find_child("Panel", true, false)
		if not target_rot_node and name == "Panel":
			target_rot_node = self
		if not target_rot_node:
			target_rot_node = find_child("DoorLeaf", true, false)
		if not target_rot_node:
			target_rot_node = self
		var target_x: float = -88.0 if is_open else 0.0
		_play_door_sound(is_open, 0.78)
		var tween = create_tween()
		tween.tween_property(target_rot_node, "rotation_degrees:x", target_x, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func(): is_animating = false)
		GameManager.notify_door_opened(self, is_open)
		return

	if not hinge_node:
		_find_hinge()

	var target_rot_node: Node3D = hinge_node
	if not target_rot_node:
		target_rot_node = find_child("Panel", true, false)
	if not target_rot_node and name == "Panel":
		target_rot_node = self
	if not target_rot_node:
		var child_h = find_child("Hinge", true, false)
		if child_h:
			target_rot_node = child_h

	if not target_rot_node:
		is_animating = false
		return

	# Вычисляем направление распахивания ОТ того, кто открывает
	var swing_sign: float = 1.0
	var actor = opener
	if not actor:
		actor = GameManager.player_ref

	if actor and is_instance_valid(actor):
		var local_actor = global_transform.affine_inverse() * actor.global_position
		# Если игрок находится спереди (Z > 0), распахиваем вперёд (+95°), если сзади — назад (-95°)
		if local_actor.z < 0.0:
			swing_sign = -1.0

	peek_swing_sign = swing_sign

	# Если дверь уже приоткрыта в щель или распахнута — закрываем полностью!
	if is_open or absf(current_open_angle) > 5.0:
		is_open = false
		current_open_angle = 0.0
	else:
		is_open = true
		current_open_angle = 95.0 * swing_sign

	_play_door_sound(is_open)

	var tween = create_tween()
	tween.tween_property(target_rot_node, "rotation_degrees:y", current_open_angle, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_animating = false)

	GameManager.notify_door_opened(self, is_open)

# ──────────────────────────────────────────────────────────────────────────────
#  Скрытное плавное приоткрывание двери (колесиком мыши)
# ──────────────────────────────────────────────────────────────────────────────
func stealth_peek_adjust(step_degrees: float, actor: Node3D = null) -> bool:
	var controller := _door_controller()
	if controller != self:
		return bool(controller.call("stealth_peek_adjust", step_degrees, actor))

	if is_door_locked():
		_play_locked_sound()
		return false

	if is_hatch:
		return false

	if not hinge_node:
		_find_hinge()

	var target_rot_node: Node3D = hinge_node
	if not target_rot_node:
		target_rot_node = get_node_or_null("Panel")
	if not target_rot_node:
		target_rot_node = self

	if not actor:
		actor = GameManager.player_ref

	var swing_sign: float = 1.0
	if actor and is_instance_valid(actor):
		var local_actor = global_transform.affine_inverse() * actor.global_position
		if local_actor.z < 0.0:
			swing_sign = -1.0

	peek_swing_sign = swing_sign
	var old_angle = current_open_angle
	if swing_sign > 0.0:
		current_open_angle = clampf(current_open_angle + step_degrees, 0.0, 95.0)
	else:
		current_open_angle = clampf(current_open_angle - step_degrees, -95.0, 0.0)

	if absf(old_angle - current_open_angle) < 0.2:
		return false

	is_open = absf(current_open_angle) > 8.0

	var tween = create_tween()
	tween.tween_property(target_rot_node, "rotation_degrees:y", current_open_angle, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Очень тихий шепот петель без привлечения внимания врагов
	_play_quiet_peek_sfx(absf(current_open_angle) > absf(old_angle))

	GameManager.notify_door_opened(self, is_open)
	return true

# ──────────────────────────────────────────────────────────────────────────────
#  Координаты замочной скважины для подглядывания [C]
# ──────────────────────────────────────────────────────────────────────────────
func get_keyhole_global_transform(from_front: bool = true) -> Transform3D:
	var controller := _door_controller()
	if controller != self and controller.has_method("get_keyhole_global_transform"):
		return controller.call("get_keyhole_global_transform", from_front)

	var panel = find_child("Panel", true, false)
	var base_node: Node3D = panel if panel else self

	var offset_x: float = 0.44
	var offset_y: float = 1.05
	var offset_z: float = 0.24 if from_front else -0.24

	var local_pos = Vector3(offset_x, offset_y, offset_z)
	var xform = base_node.global_transform * Transform3D(Basis(), local_pos)
	return xform

func _play_quiet_peek_sfx(opening: bool) -> void:
	if not audio_player:
		return
	var sample_count = int(44100 * (0.16 if opening else 0.12))
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)

	for idx in range(sample_count):
		var time = float(idx) / 44100.0
		var env = exp(-time * (12.0 if opening else 22.0))
		var f_creak = 220.0 + sin(time * 50.0) * 80.0
		var creak = sin(time * f_creak * TAU) * 0.25 + (randf() * 2.0 - 1.0) * 0.08
		var sample = creak * env * 0.30
		var val16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(idx * 2, val16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm

	audio_player.stream = wav
	audio_player.pitch_scale = randf_range(0.9, 1.1)
	audio_player.play()

# ──────────────────────────────────────────────────────────────────────────────
#  Проверка: заперта ли дверь замками, досками или обесточена
# ──────────────────────────────────────────────────────────────────────────────
func is_door_locked() -> bool:
	var controller := _door_controller()
	if controller != self:
		return bool(controller.call("is_door_locked"))
	if is_open:
		return false

	var maglock = _get_maglock()
	if maglock and maglock.is_powered:
		return true

	# Доски на двери
	if requires_boards and not door_boards_broken and not (_is_exit_door() and GameManager.door_boards_broken):
		return true

	# Замок по ID
	var eff_lid = get_effective_lock_id()
	if eff_lid > 0 and not door_key_unlocked:
		return true

	# Электрощиток с проводами
	if requires_wire_panel and not wire_panel_solved:
		return true

	# Замок с ключом
	if required_key_color != "" and required_key_color != "none" and not door_key_unlocked:
		return true

	# Электропитание двери / энергосчетчик
	var d_type = _get_door_type()
	if (d_type == "electric" or requires_power or (has_electric_meter and requires_power)) and not is_powered:
		return true

	return false

func _get_door_type() -> String:
	if has_meta("door_type"):
		return str(get_meta("door_type"))
	if has_meta("item_type"):
		var it_self = str(get_meta("item_type"))
		if it_self == "door_simple": return "simple"
		if it_self == "door_electric": return "electric"
	var ctrl = _door_controller()
	if ctrl and ctrl != self and is_instance_valid(ctrl):
		if ctrl.has_meta("door_type"):
			return str(ctrl.get_meta("door_type"))
		if ctrl.has_meta("item_type"):
			var it = str(ctrl.get_meta("item_type"))
			if it == "door_simple": return "simple"
			if it == "door_electric": return "electric"
	return "boards" if _is_exit_door() else "simple"

func _is_exit_door() -> bool:
	if is_exit:
		return true
	if has_meta("is_exit") and bool(get_meta("is_exit")):
		return true
	var nm = name.to_lower()
	if "выход" in nm or "exit" in nm:
		return true
	var ctrl = _door_controller()
	if ctrl and ctrl != self and is_instance_valid(ctrl):
		if "is_exit" in ctrl and bool(ctrl.get("is_exit")):
			return true
		if ctrl.has_meta("is_exit") and bool(ctrl.get_meta("is_exit")):
			return true
		var c_nm = ctrl.name.to_lower()
		if "выход" in c_nm or "exit" in c_nm:
			return true
	return false

func _check_meta_locked() -> bool:
	var eff_lid = get_effective_lock_id()
	if eff_lid > 0 and not door_key_unlocked:
		return true
	return false

# ──────────────────────────────────────────────────────────────────────────────
#  Открытие двери врагом (выбивание с размаху при погоне)
#  Возвращает true если дверь открыта, false если намертво заперта
# ──────────────────────────────────────────────────────────────────────────────
func open_by_enemy(enemy_node: Node3D) -> bool:
	var controller := _door_controller()
	if controller != self:
		return bool(controller.call("open_by_enemy", enemy_node))
	var maglock = _get_maglock()
	if maglock and maglock.is_powered:
		maglock.shock_monster(enemy_node)
		return false

	# ЗАПЕРТАЯ ДВЕРЬ — монстр не может ее открыть!
	if is_door_locked():
		_play_locked_sound()
		return false

	if is_open:
		return true
	is_animating = true
	is_open = true

	# Синхронизация статуса с родителем и дочерними узлами
	var p_node = get_parent()
	if p_node and p_node.has_method("open_by_enemy"):
		p_node.set("is_open", true)
	for ch in get_children():
		if ch.has_method("open_by_enemy"):
			ch.set("is_open", true)

	if not hinge_node:
		_find_hinge()

	var target_rot_node: Node3D = hinge_node if hinge_node else self
	var swing_sign: float = 1.0
	if enemy_node and is_instance_valid(enemy_node):
		var local_e = global_transform.affine_inverse() * enemy_node.global_position
		if local_e.z < 0.0:
			swing_sign = -1.0

	_play_door_sound(true, 1.4) # Громкий скрип/удар

	var tween = create_tween()
	tween.tween_property(target_rot_node, "rotation_degrees:y", 110.0 * swing_sign, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): is_animating = false)

	GameManager.notify_door_opened(self, true)
	return true

func _door_controller() -> Node:
	# Legacy prefabs attach this script to both root and leaf. Share one state.
	if name == "Panel":
		var ancestor := get_parent()
		for i in range(3):
			if not is_instance_valid(ancestor):
				break
			if ancestor.has_method("open_by_enemy"):
				return ancestor
			ancestor = ancestor.get_parent()
	return self

# ──────────────────────────────────────────────────────────────────────────────
#  Звуки скрипа и защелкивания двери
# ──────────────────────────────────────────────────────────────────────────────
func _play_door_sound(opening: bool, pitch_mod: float = 1.0) -> void:
	if not audio_player:
		return

	var s_path = "res://assets/door_open.mp3" if opening else "res://assets/door_close.mp3"
	if ResourceLoader.exists(s_path):
		var stream = load(s_path)
		if stream:
			audio_player.stream = stream
			audio_player.pitch_scale = randf_range(0.95, 1.05) * pitch_mod
			audio_player.volume_db = 0.0
			audio_player.play()
			return

	var sample_count = int(44100 * (0.35 if opening else 0.22))
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)

	for idx in range(sample_count):
		var time = float(idx) / 44100.0
		var env = exp(-time * (7.0 if opening else 16.0))
		var sample = 0.0
		if opening:
			# Деревянный скрип петель
			var f_creak = 180.0 + sin(time * 35.0) * 120.0 + sin(time * 180.0) * 45.0
			var creak = sin(time * f_creak * TAU) * 0.5 + sin(time * (f_creak * 2.1) * TAU) * 0.3
			var friction = (randf() * 2.0 - 1.0) * 0.2
			sample = (creak + friction) * env
		else:
			# Глухой щелчок и удар дверного полотна в косяк
			var thud = sin(time * 95.0 * TAU) * 0.6
			var click = sin(time * 2400.0 * TAU) * 0.35 * exp(-time * 45.0)
			sample = (thud + click) * env

		var val16 = int(clamp(sample, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(idx * 2, val16)

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm

	audio_player.stream = wav
	audio_player.pitch_scale = pitch_mod
	audio_player.play()

# ──────────────────────────────────────────────────────────────────────────────
#  Выходная заколоченная дверь (с переходом на Street.tscn)
# ──────────────────────────────────────────────────────────────────────────────
func _smash_boards() -> void:
	door_boards_broken = true
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("emit_noise"):
		gm.emit_noise(global_position, 22.0, "boards_break")
	_play_boards_break_sound()
	if not boards_node:
		var b = get_node_or_null("Boards")
		if b: boards_node = b
	if not boards_node:
		return
	for child in boards_node.get_children():
		var t = create_tween()
		var rand_dir = Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-0.5, 0.5)).normalized()
		t.tween_property(child, "position", child.position + rand_dir * 1.5, 0.3)
		t.parallel().tween_property(child, "rotation_degrees",
			Vector3(randf_range(-90,90), randf_range(-90,90), randf_range(-90,90)), 0.3)
		t.tween_property(child, "scale", Vector3.ZERO, 0.2)
		t.tween_callback(child.queue_free)

func _play_boards_break_sound() -> void:
	if not audio_player:
		return
	var sample_count = int(44100 * 0.35)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for i in range(sample_count):
		var t = float(i) / 44100.0
		var env = exp(-t * 14.0)
		var crack = ((randf() * 2.0 - 1.0) * 0.75 + sin(t * 110.0 * TAU) * 0.4) * env
		var val16 = int(clamp(crack, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(i * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.play()

func _open_door() -> void:
	if is_open:
		return
	is_open = true

	# Отключаем коллизию дверного полотна
	for child in find_children("*", "StaticBody3D", true, false):
		var col = child.get_node_or_null("Col")
		if col:
			col.disabled = true

	_play_door_sound(true)

	if not hinge_node:
		_find_hinge()

	var rot_target = hinge_node
	if not rot_target:
		rot_target = find_child("Hinge", true, false)
	if not rot_target:
		rot_target = find_child("Panel", true, false)
	if rot_target:
		var tween = create_tween()
		tween.tween_property(rot_target, "rotation_degrees:y", 95.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Триггер перехода / побега
	var exit_area = Area3D.new()
	exit_area.name = "ExitTrigger"
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(2.2, 2.6, 2.2)
	col_shape.shape = box
	col_shape.position = Vector3(0, 1.3, 0.8)
	exit_area.add_child(col_shape)
	add_child(exit_area)
	exit_area.body_entered.connect(_on_exit_entered)

	if get_tree():
		var exit_timer = get_tree().create_timer(1.2 if _is_level_1() else 0.8)
		exit_timer.timeout.connect(func():
			if is_open and not transition_started:
				if _is_level_1():
					_teleport_to_level_2()
				else:
					_trigger_alpha_end()
		)

func _is_level_1() -> bool:
	if GameManager and GameManager.active_map_path != "":
		var p = GameManager.active_map_path.to_lower()
		if "1level" in p or "level1" in p or "1_level" in p:
			return true
	var cur = get_tree().current_scene if get_tree() else null
	if cur and "map_json_path" in cur:
		var p2 = str(cur.get("map_json_path")).to_lower()
		if "1level" in p2 or "level1" in p2 or "1_level" in p2:
			return true
	return false

func _is_level_2() -> bool:
	if GameManager and GameManager.has_method("is_level_2"):
		if GameManager.is_level_2():
			return true
	if GameManager and GameManager.active_map_path != "":
		var p = GameManager.active_map_path.to_lower()
		if "карта_2" in p or "karta_2" in p or "карта_6" in p or "karta_6" in p or "level2" in p or "level_2" in p or "2level" in p:
			return true
	var cur = get_tree().current_scene if get_tree() else null
	if cur and "map_json_path" in cur:
		var p2 = str(cur.get("map_json_path")).to_lower()
		if "карта_2" in p2 or "karta_2" in p2 or "карта_6" in p2 or "karta_6" in p2 or "level2" in p2 or "level_2" in p2 or "2level" in p2:
			return true
	return false

func _teleport_to_level_2() -> void:
	if transition_started:
		return
	transition_started = true

	var tree = get_tree()
	if not tree:
		return

	# 1. Воспроизведение звука перехода opennext.mp3 через корень сцены
	var s: AudioStream = null
	if ResourceLoader.exists("res://assets/opennext.mp3"):
		s = load("res://assets/opennext.mp3")
	elif ResourceLoader.exists("res://assets/audio/opennext.mp3"):
		s = load("res://assets/audio/opennext.mp3")
	if s and tree.root:
		var asp = AudioStreamPlayer.new()
		asp.name = "LevelTransitionAudio"
		asp.stream = s
		asp.volume_db = 2.0
		tree.root.add_child(asp)
		asp.play()
		asp.finished.connect(func(): if is_instance_valid(asp): asp.queue_free())

	# 2. Подсказка на экране
	if GameManager and GameManager.ui_ref and is_instance_valid(GameManager.ui_ref) and GameManager.ui_ref.has_method("show_hint"):
		GameManager.ui_ref.call("show_hint", "🚪 Дверь открыта! Переход на следующий уровень...", 4.0)

	# 3. Экранное затемнение
	var cv = CanvasLayer.new()
	cv.layer = 150
	var cr = ColorRect.new()
	cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cr.color = Color(0, 0, 0, 0)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(cr)
	if tree.root:
		tree.root.add_child(cv)

	var tw = tree.create_tween() if tree else null
	if tw:
		tw.tween_property(cr, "color:a", 1.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_interval(0.3)
		tw.tween_callback(func():
			if GameManager:
				GameManager.reset_state(true)
				GameManager.active_map_path = "res://scenes/Карта_6_fix.json"
				GameManager.intro_cutscene_played = true
			if is_instance_valid(tree):
				tree.change_scene_to_file("res://scenes/Main.tscn")
			if is_instance_valid(cv):
				var tw2 = cv.create_tween()
				if tw2:
					tw2.tween_interval(0.2)
					tw2.tween_property(cr, "color:a", 0.0, 0.8)
					tw2.tween_callback(func(): if is_instance_valid(cv): cv.queue_free())
				else:
					cv.queue_free()
		)
	else:
		if GameManager:
			GameManager.reset_state(true)
			GameManager.active_map_path = "res://scenes/Карта_6_fix.json"
			GameManager.intro_cutscene_played = true
		tree.change_scene_to_file("res://scenes/Main.tscn")

func _on_exit_entered(body: Node) -> void:
	if transition_started:
		return
	if body is CharacterBody3D and (body == GameManager.player_ref or body.name == "Player"):
		if _is_level_1():
			_teleport_to_level_2()
		else:
			_trigger_alpha_end()

func _transition_to_street() -> void:
	if transition_started:
		return
	if _is_level_1():
		_teleport_to_level_2()
		return
	_trigger_alpha_end()

func _trigger_alpha_end() -> void:
	if transition_started:
		return
	transition_started = true
	if GameManager:
		GameManager.game_ended = true
	if get_tree():
		var t = get_tree().create_timer(0.5)
		t.timeout.connect(func():
			if GameManager and GameManager.ui_ref and is_instance_valid(GameManager.ui_ref):
				if GameManager.ui_ref.has_method("show_alpha_end_screen"):
					GameManager.ui_ref.call("show_alpha_end_screen")
				elif GameManager.ui_ref.has_method("_on_win"):
					GameManager.ui_ref.call("_on_win")
		)

func _shake() -> void:
	pass

func _play_locked_sound() -> void:
	if not audio_player:
		return
	var sample_count = int(44100 * 0.28)
	var pcm = PackedByteArray()
	pcm.resize(sample_count * 2)
	for idx in range(sample_count):
		var time = float(idx) / 44100.0
		var env = exp(-time * 18.0)
		var rattle = (sin(time * 340.0 * TAU) * 0.5 + sin(time * 980.0 * TAU) * 0.35 + (randf() * 2.0 - 1.0) * 0.25) * env
		var val16 = int(clamp(rattle, -1.0, 1.0) * 32767.0)
		pcm.encode_s16(idx * 2, val16)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 44100
	wav.data = pcm
	audio_player.stream = wav
	audio_player.pitch_scale = randf_range(0.85, 1.15)
	audio_player.play()

func _get_maglock() -> Node:
	# Maglock может находиться ТОЛЬКО внутри этой конкретной двери (self или root контроллера)
	var ml = find_child("ElectricMaglock", true, false)
	if ml:
		return ml
	if name == "Panel" and get_parent():
		var p = get_parent()
		if p.name == "Hinge" and p.get_parent():
			p = p.get_parent()
		var r_ml = p.find_child("ElectricMaglock", true, false)
		if r_ml:
			return r_ml
	return null
