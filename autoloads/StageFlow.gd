# res://autoloads/StageFlow.gd
extends Node

signal stage_cleared(stage_name: String, run_time_ms: int)

# ---- Orden completo de la run (minions + bosses) ----
const STAGES: Array[String] = [
	"res://scenes/stages/PoisonSkullBattle.tscn",
	"res://scenes/stages/SkMageBattle.tscn",
	"res://scenes/stages/ImpBattle.tscn",
	"res://scenes/stages/AdeptBattle.tscn",
	"res://scenes/stages/MedusaBattle.tscn",
	"res://scenes/stages/WitchBattle.tscn",
	"res://scenes/stages/FlyingDevilBattle.tscn",
	"res://scenes/stages/DemonEyeBattle.tscn",
]

# Solo estos aportan split (nombres deben calzar con SpeedPanel)
const BOSS_SCENE_TO_NAME := {
	"res://scenes/stages/SkMageBattle.tscn":   "Sk Mage",
	"res://scenes/stages/AdeptBattle.tscn":    "Adept",
	"res://scenes/stages/WitchBattle.tscn":    "Witch",
	"res://scenes/stages/DemonEyeBattle.tscn": "Demon Eye",
}

const MENU_CANDIDATES: Array[String] = [
	"res://scenes/UI/Menu.tscn",
	"res://scenes/ui/Menu.tscn",
	"res://scenes/menu.tscn",
]

var current_splits: Dictionary = {} # { "Sk Mage": ms acumulados, ... }
var _in_transition: bool = false    # candado anti dobles llamadas

# ---------- helpers ----------
func _first_existing(paths: Array[String]) -> String:
	for p: String in paths:
		if ResourceLoader.exists(p):
			return p
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

func _record_split_if_boss(idx: int) -> void:
	if idx < 0 or idx >= STAGES.size():
		return
	var path: String = STAGES[idx]
	if not BOSS_SCENE_TO_NAME.has(path):
		return # minion → no registra split
	var stage_name: String = String(BOSS_SCENE_TO_NAME[path])
	var sm: Node = get_node_or_null("/root/SpeedManager")
	var ms: int = (int(sm.get("run_time")) if sm else 0)
	current_splits[stage_name] = ms
	stage_cleared.emit(stage_name, ms)

# ---------- flujo ----------
func go_next() -> void:
	if _in_transition:
		return
	_in_transition = true

	var cur_path: String = _current_scene_path()
	var idx: int = _index_for_path(cur_path)

	# Si no estamos en una stage (p.ej. venimos del menú), ir a la primera existente
	if idx == -1:
		var start: String = _first_existing(STAGES)
		if start != "":
			get_tree().change_scene_to_file(start)
		await get_tree().process_frame
		_in_transition = false
		return

	# Calcular la última stage disponible
	var last: int = -1
	for i in STAGES.size():
		if ResourceLoader.exists(STAGES[i]):
			last = i

	# Si estamos en la última, delegar en finalize (ahí se registra split final si es boss)
	if idx == last and last != -1:
		finalize_and_return_to_menu()
		await get_tree().process_frame
		_in_transition = false
		return

	# Stage intermedia: si es boss, registrar split; luego avanzar a la siguiente existente
	_record_split_if_boss(idx)

	var j: int = idx + 1
	while j < STAGES.size() and not ResourceLoader.exists(STAGES[j]):
		j += 1
	if j < STAGES.size():
		get_tree().change_scene_to_file(STAGES[j])
	else:
		finalize_and_return_to_menu()

	await get_tree().process_frame
	_in_transition = false

func finalize_and_return_to_menu() -> void:
	# split final por seguridad (si la última es boss)
	_record_split_if_boss(_index_for_path(_current_scene_path()))

	var sm: Node = get_node_or_null("/root/SpeedManager")
	var saver: Node = get_node_or_null("/root/SaveManager")

	if sm:
		var run_ms: int = int(sm.get("run_time"))
		var improved: bool = false
		if sm.has_method("update_personal_best_if_better"):
			improved = bool(sm.call("update_personal_best_if_better", run_ms))

		if improved:
			if sm.has_method("set_personal_best_splits"):
				sm.call("set_personal_best_splits", current_splits)
		# Guardamos siempre el archivo (sea o no PB) para persistir el PB vigente
		if saver and saver.has_method("save_from_speed_manager"):
			saver.call("save_from_speed_manager")

		# Dejar el run-time en 0 para la próxima partida/carga
		sm.call("set_run_time", 0)

	current_splits.clear()

	var menu_path: String = _first_existing(MENU_CANDIDATES)
	if menu_path != "":
		get_tree().change_scene_to_file(menu_path)
