extends Node
class_name Menu

@onready var new_btn:  Button = %Newbtn
@onready var load_btn: Button = %Loadbtn
@onready var quit_btn: Button = %Quitbtn

# Rutas posibles del primer nivel (usa la que exista)
const STAGE1_PATHS := [
	"res://scenes/stages/SkMageBattle.tscn",  # Stage 1
	"res://scenes/stages/AdeptBattle.tscn",   # fallback
]

func _ready() -> void:
	# Conexiones (evita duplicados)
	if new_btn and not new_btn.pressed.is_connected(_on_new):
		new_btn.pressed.connect(_on_new)
	if load_btn and not load_btn.pressed.is_connected(_on_load):
		load_btn.pressed.connect(_on_load)
	if quit_btn and not quit_btn.pressed.is_connected(_on_quit):
		quit_btn.pressed.connect(_on_quit)

	# Habilitar/deshabilitar Load según exista save
	var saver: Node = get_node_or_null("/root/SaveManager")
	load_btn.disabled = true
	if saver and saver.has_method("has_save"):
		load_btn.disabled = not bool(saver.call("has_save"))

func _on_new() -> void:
	var saver: Node = get_node_or_null("/root/SaveManager")
	if saver and saver.has_method("new_game"):
		saver.call("new_game")
	_go_stage1()

func _on_load() -> void:
	var saver: Node = get_node_or_null("/root/SaveManager")
	if saver and saver.has_method("load_into_speed_manager"):
		var ok: bool = bool(saver.call("load_into_speed_manager"))
		if not ok:
			return
	_go_stage1()

func _on_quit() -> void:
	get_tree().quit()

func _go_stage1() -> void:
	var path := _first_existing(STAGE1_PATHS)
	if path == "":
		push_error("Menu: no encontré Stage 1. Revisa scenes/stages/SkMageBattle.tscn")
		return
	get_tree().change_scene_to_file(path)

func _first_existing(paths: Array) -> String:
	for p in paths:
		if ResourceLoader.exists(p):
			return String(p)
	return ""
