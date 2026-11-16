extends RefCounted

# Голос для реплик в игре (мысли Итана вслух, записи, голоса из леса).
# Файл ищется по самому тексту реплики: assets/audio/voice/lines/<md5 текста, 10 знаков>.wav.
# Нет файла — реплика остаётся только субтитром. Файлы делает voicegen/make_thoughts.mjs.
#   hold = maxf(hold, GameVoice.play(self, text) + 0.3)

const DIR := "res://assets/audio/voice/lines/"

static var _last: WeakRef


static func key(text: String) -> String:
	return text.strip_edges().md5_text().substr(0, 10)


# Играет голос реплики (предыдущая реплика обрывается). Возвращает длину в секундах, 0 — голоса нет.
static func play(owner: Node, text: String, db: float = 0.0) -> float:
	if owner == null or not owner.is_inside_tree() or text.strip_edges() == "":
		return 0.0
	var path := DIR + key(text) + ".wav"
	if not ResourceLoader.exists(path):
		return 0.0
	var st := load(path) as AudioStream
	if st == null:
		return 0.0
	stop()
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	owner.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	_last = weakref(p)
	return st.get_length()


# Сколько секунд ещё звучит текущая реплика — чтобы следующая не обрывала её:
#   await get_tree().create_timer(maxf(3.8, GameVoice.left() + 0.3), false).timeout
static func left() -> float:
	var p = _last.get_ref() if _last else null
	if p and is_instance_valid(p) and p.playing and p.stream:
		return maxf(0.0, p.stream.get_length() - p.get_playback_position())
	return 0.0


static func stop() -> void:
	if _last == null:
		return
	var p = _last.get_ref()
	if p and is_instance_valid(p):
		p.queue_free()
	_last = null
