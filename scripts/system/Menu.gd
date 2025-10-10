extends Node
class_name Menu

@onready var new_btn:  Button = %Newbtn
@onready var load_btn: Button = %Loadbtn
@onready var quit_btn: Button = %Quitbtn

const STAGE1_PATHS := [
	"res://scenes/stages/PoisonSkullBattle.tscn",
]

func _ready() -> void:
	if new_btn and not new_btn.pressed.is_connected(_on_new):
		new_btn.pressed.connect(_on_new)
	if load_btn and not load_btn.pressed.is_connected(_on_load):
		load_btn.pressed.connect(_on_load)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit):
		quit_btn.pressed.connect(_on_quit)

	var saver := get_node_or_null("/root/SaveManager")
	load_btn.disabled = true
	if saver and saver.has_method("has_save"):
		load_btn.disabled = not bool(saver.call("has_save"))

func _on_new() -> void:
	var saver := get_node_or_null("/root/SaveManager")
	if saver and saver.has_method("new_game"):
		saver.call("new_game")
	_go_stage1()

func _on_load() -> void:
	var saver := get_node_or_null("/root/SaveManager")
	if saver and saver.has_method("load_into_speed_manager"):
		var ok: bool = bool(saver.call("load_into_speed_manager"))
		if not ok:
			return
	# Cinturón y tirantes: asegura run_time=0
	var sm := get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_run_time", 0)
	_go_stage1()

func _on_quit() -> void:
	get_tree().quit()

func _go_stage1() -> void:
	var path := _first_existing(STAGE1_PATHS)
	if path == "":
		push_error("Menu: no encontré Stage 1.")
		return
	var flow := get_node_or_null("/root/StageFlow")
	if flow and flow.has_method("start_new_run"):
		flow.call("start_new_run")
	get_tree().change_scene_to_file(path)

func _first_existing(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(String(p)):
			return String(p)
	return ""
