extends Node

const SAVE_PATH: String = "user://savegame.json"
const FILE_VERSION: int = 1

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	var sm: Node = get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_run_time", 0)
		sm.call("set_personal_best", -1)
		sm.call("set_personal_best_splits", {}) # limpia splits PB
	_save_from_speed_manager()

func load_into_speed_manager() -> bool:
	if not has_save(): return false

	var fa: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if fa == null: return false

	var txt: String = fa.get_as_text()
	fa.close()

	var data_any: Variant = JSON.parse_string(txt)
	if not (data_any is Dictionary): return false
	var dict: Dictionary = data_any as Dictionary

	var pb: int = int(dict.get("personal_best_ms", -1))
	var pb_splits: Dictionary = {}
	var loaded_splits: Variant = dict.get("pb_splits", {})
	if loaded_splits is Dictionary:
		pb_splits = loaded_splits as Dictionary

	var sm: Node = get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_personal_best", pb)
		sm.call("set_personal_best_splits", pb_splits)
		sm.call("set_run_time", 0) # al cargar, siempre 0

	return true

func save_from_speed_manager() -> bool:
	return _save_from_speed_manager()

# -------- internos --------
func _save_from_speed_manager() -> bool:
	var sm: Node = get_node_or_null("/root/SpeedManager")
	var pb: int = -1
	var pb_splits: Dictionary = {}
	if sm:
		pb = int(sm.get("personal_best"))
		var v: Variant = sm.get("personal_best_splits")
		if v is Dictionary:
			pb_splits = v as Dictionary

	var payload: Dictionary = {
		"version": FILE_VERSION,
		"personal_best_ms": pb,
		"pb_splits": pb_splits,
	}

	var fa: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if fa == null: return false
	fa.store_string(JSON.stringify(payload))
	fa.close()
	return true
