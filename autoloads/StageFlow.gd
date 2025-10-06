# res://autoloads/StageFlow.gd
extends Node

# Orden de tus stages
const STAGES := [
	"res://scenes/stages/SkMageBattle.tscn",
	"res://scenes/stages/WitchBattle.tscn",
	"res://scenes/stages/AdeptBattle.tscn",
	"res://scenes/stages/DemonEyeBattle.tscn",
]

const MENU_CANDIDATES := [
	"res://scenes/UI/Menu.tscn",
	"res://scenes/ui/Menu.tscn",
	"res://scenes/menu.tscn",
]

func _first_existing(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(p):
			return String(p)
	return ""

func _current_scene_path() -> String:
	var cs := get_tree().current_scene
	return cs.get_scene_file_path() if cs else ""

func stage_index() -> int:
	var cur := _current_scene_path()
	if cur == "":
		return -1
	for i in STAGES.size():
		if ResourceLoader.exists(STAGES[i]) and STAGES[i] == cur:
			return i
	return -1

func is_last_stage() -> bool:
	var last := -1
	for i in STAGES.size():
		if ResourceLoader.exists(STAGES[i]):
			last = i
	return stage_index() == last and last != -1

func go_next() -> void:
	var idx := stage_index()
	if idx == -1:
		var start := _first_existing(STAGES)
		if start != "":
			get_tree().change_scene_to_file(start)
		return
	if is_last_stage():
		finalize_and_return_to_menu()
		return
	var j := idx + 1
	while j < STAGES.size() and not ResourceLoader.exists(STAGES[j]):
		j += 1
	if j < STAGES.size():
		get_tree().change_scene_to_file(STAGES[j])
	else:
		finalize_and_return_to_menu()

func finalize_and_return_to_menu() -> void:
	# 1) Tomar tiempo actual y actualizar PB si corresponde
	var sm := get_node_or_null("/root/SpeedManager")
	var saver := get_node_or_null("/root/SaveManager")
	if sm:
		var run_ms := int(sm.get("run_time"))
		sm.call("update_personal_best_if_better", run_ms)
		if saver and saver.has_method("save_from_speed_manager"):
			saver.call("save_from_speed_manager")
		# Deja el run-time en 0 para la próxima partida/carga
		sm.call("set_run_time", 0)

	# 2) Volver al menú
	var menu_path := _first_existing(MENU_CANDIDATES)
	if menu_path != "":
		get_tree().change_scene_to_file(menu_path)
