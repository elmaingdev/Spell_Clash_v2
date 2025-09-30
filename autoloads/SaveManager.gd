# res://autoloads/SaveManager.gd
extends Node

const SAVE_PATH: String = "user://savegame.json"
const FILE_VERSION: int = 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	# Resetea SpeedManager y guarda archivo base
	var sm: Node = get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_run_time", 0)
		sm.call("set_personal_best", -1)
	_save_from_speed_manager()

func load_into_speed_manager() -> bool:
	if not has_save():
		return false
	var fa: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if fa == null:
		return false
	var txt: String = fa.get_as_text()
	fa.close()

	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var dict: Dictionary = data
	var pb: int = int(dict.get("personal_best_ms", -1))

	var sm: Node = get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_personal_best", pb)
	return true

func save_from_speed_manager() -> bool:
	return _save_from_speed_manager()

# -------- internos --------
func _save_from_speed_manager() -> bool:
	var sm: Node = get_node_or_null("/root/SpeedManager")
	var pb: int = -1
	if sm:
		pb = int(sm.get("personal_best"))

	var payload: Dictionary = {
		"version": FILE_VERSION,
		"personal_best_ms": pb,
	}

	var fa: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa == null:
		return false
	fa.store_string(JSON.stringify(payload))
	fa.close()
	return true
