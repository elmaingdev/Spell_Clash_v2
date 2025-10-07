# res://autoloads/StageFlow.gd
extends Node

const STAGES := [
	"res://scenes/stages/SkMageBattle.tscn",
	"res://scenes/stages/WitchBattle.tscn",
	"res://scenes/stages/AdeptBattle.tscn",
	"res://scenes/stages/DemonEyeBattle.tscn",
]

const STAGE_NAMES := [
	"Sk Mage",
	"Witch",
	"Adept",
	"Demon Eye",
]

const MENU_CANDIDATES := [
	"res://scenes/UI/Menu.tscn",
	"res://scenes/ui/Menu.tscn",
	"res://scenes/menu.tscn",
]

var current_splits: Dictionary = {} # { "Sk Mage": ms, ... }
var _in_transition: bool = false     # ← candado contra dobles llamadas

# ---------- helpers ----------
func _first_existing(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(p):
			return String(p)
	return ""

func _current_scene_path() -> String:
	var cs := get_tree().current_scene
	return cs.get_scene_file_path() if cs else ""

func _index_for_path(p: String) -> int:
	if p == "":
		return -1
	for i in STAGES.size():
		if ResourceLoader.exists(STAGES[i]) and STAGES[i] == p:
			return i
	return -1

func stage_index() -> int:
	return _index_for_path(_current_scene_path())

func is_last_stage() -> bool:
	var last := -1
	for i in STAGES.size():
		if ResourceLoader.exists(STAGES[i]):
			last = i
	return stage_index() == last and last != -1

func _record_split_for_index(idx: int) -> void:
	if idx < 0 or idx >= STAGE_NAMES.size():
		return
	var stage_name: String = STAGE_NAMES[idx]
	var sm: Node = get_node_or_null("/root/SpeedManager")
	var ms: int = (int(sm.get("run_time")) if sm else 0)
	current_splits[stage_name] = ms

# ---------- flujo ----------
func go_next() -> void:
	# Evita reentradas por múltiples señales/teclas o cambios en curso
	if _in_transition:
		return
	_in_transition = true

	# Captura la escena ACTUAL antes del cambio y registra el split
	var cur_path := _current_scene_path()
	var idx := _index_for_path(cur_path)
	_record_split_for_index(idx)

	# Decide siguiente índice con la info capturada
	if idx == -1:
		var start := _first_existing(STAGES)
		if start != "":
			get_tree().change_scene_to_file(start)
	else:
		# ¿última stage?
		var last := -1
		for i in STAGES.size():
			if ResourceLoader.exists(STAGES[i]):
				last = i
		if idx == last and last != -1:
			finalize_and_return_to_menu()
		else:
			var j := idx + 1
			while j < STAGES.size() and not ResourceLoader.exists(STAGES[j]):
				j += 1
			if j < STAGES.size():
				get_tree().change_scene_to_file(STAGES[j])
			else:
				finalize_and_return_to_menu()

	# Suelta el candado en el siguiente frame (cuando el cambio ya arrancó)
	await get_tree().process_frame
	_in_transition = false

func finalize_and_return_to_menu() -> void:
	# split final por seguridad
	_record_split_for_index(_index_for_path(_current_scene_path()))

	var sm: Node = get_node_or_null("/root/SpeedManager")
	var saver: Node = get_node_or_null("/root/SaveManager")

	if sm:
		var run_ms := int(sm.get("run_time"))
		var improved: bool = false
		if sm.has_method("update_personal_best_if_better"):
			improved = bool(sm.call("update_personal_best_if_better", run_ms))

		if improved:
			if sm.has_method("set_personal_best_splits"):
				sm.call("set_personal_best_splits", current_splits)
			if saver and saver.has_method("save_from_speed_manager"):
				saver.call("save_from_speed_manager")
		else:
			if saver and saver.has_method("save_from_speed_manager"):
				saver.call("save_from_speed_manager")

		sm.call("set_run_time", 0)

	current_splits.clear()

	var menu_path := _first_existing(MENU_CANDIDATES)
	if menu_path != "":
		get_tree().change_scene_to_file(menu_path)
