extends Node3D

# Заправка днём: окружение карты «Заправка» для финала (Досым).
# Ставит Main.gd на карте, у которой в имени есть «заправка» (_is_gas_station()).
#
# Кто что строит на этой карте:
#   • FinaleStation.gd (Jan-ky): сама заправка GasStation.gd (магазин, прилавок с кассиршей
#     CashierModel, полки, колонки, навес, лес вокруг), отцовский пикап FatherCar у колонки,
#     чёрный олень, невидимые стены (магазин, прилавок, полки, колонки, машина), дневной свет
#     и весь геймплей финала. Дверь магазина там работает как переход: затемнение, и ты внутри.
#   • этот скрипт: вид карты днём. Main.gd на всех картах кладёт ярко-зелёный газон, он закрывает
#     лесную землю заправки. Здесь газон прячется (пол для ног остаётся), и вокруг видна
#     тёмная лесная земля, как в кат-сцене Finale.
#
# Точки финала для Jan-ky (те же числа стоят в Finale.gd и FinaleStation.gd; если меняешь их там,
# поменяй и здесь). Шоссе идёт вдоль Z при x = 0, заправка справа, магазин при x = 22…33.
#   PLAYER_START (13.0, 0.3, -3.8)   старт у водительской двери (marker_player в Заправка.json)
#   CAR_AT       (11.3, 0.0, -3.4)   пикап у рабочей колонки, нос на юг (+Z, обратно в город)
#   CAR_DOOR     (12.2, 0.0, -3.1)   водительская дверь пикапа, со стороны островка и магазина
#   SHOP_OUTSIDE (20.9, 0.15, -3.3)  перед дверью магазина
#   SHOP_INSIDE  (22.85, 0.2, -3.3)  сразу за дверью, внутри
#   COUNTER      (24.05, 0.13, 1.3)  у прилавка, где Итан кладёт деньги (глаза на высоте 1.6)
#   CASHIER      (25.72, 0.12, 1.8)  бабушка за прилавком (GasStation.CASHIER_POS)
#   FOREST_EDGE  (37.5, 0.0, -21.0)  опушка за забором магазина, там стоит олень
#   FOREST_VOICE (40.0, 2.0, -12.0)  откуда из леса зовёт голос «Марта…»

const PLAYER_START := Vector3(13.0, 0.3, -3.8)
const CAR_AT := Vector3(11.3, 0.0, -3.4)
const CAR_DOOR := Vector3(12.2, 0.0, -3.1)
const SHOP_OUTSIDE := Vector3(20.9, 0.15, -3.3)
const SHOP_INSIDE := Vector3(22.85, 0.2, -3.3)
const COUNTER := Vector3(24.05, 0.13, 1.3)
const CASHIER := Vector3(25.72, 0.12, 1.8)
const FOREST_EDGE := Vector3(37.5, 0.0, -21.0)
const FOREST_VOICE := Vector3(40.0, 2.0, -12.0)


func _ready() -> void:
	name = "GasStationDay"
	_hide_lawn()


# Газон общей сцены лежит на высоте 0, а земля заправки на 3 см ниже, поэтому его не видно.
# Прячем только картинку: пол для ног и сетка навигации остаются
func _hide_lawn() -> void:
	var region = get_parent().get("nav_region")
	if not (region is Node):
		return
	for chunk in (region as Node).get_children():
		if not String(chunk.name).begins_with("GrassChunk"):
			continue
		for c in chunk.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
