extends Control
class_name GameOverPanel

const SM := preload("res://autoloads/SpeedManager.gd")
const MENU_PATH_PRIMARY := "res://scenes/UI/Menu.tscn"
const MENU_PATH_FALLBACK := "res://scenes/ui/Menu.tscn" # por si difiere en minúsculas

@onready var _yes: Button = $PanelContainer/VBoxContainer/HBoxContainer/Yesbtn
@onready var _no: Button  = $PanelContainer/VBoxContainer/HBoxContainer/Nobtn

@onready var _this_lbl: Label = $PanelContainer/VBoxContainer/This_lbl
@onready var _pb_lbl: Label   = $PanelContainer/VBoxContainer/personal_best_lbl

@onready var _enemy: EnemyBase = get_node_or_null("%Enemy") as EnemyBase
@onready var _player: Mage1 = %Mage_1
@onready var _bgm: AudioStreamPlayer = %BGM
@onready var _bottom: Control = %BottomPanel

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	z_as_relative = false
	z_index = 1000
	top_level = true

	# Resolver nodos (por si %Enemy no estaba listo aún)
	_resolve_enemy_player()

	_yes.pressed.connect(_on_yes)
	_no.pressed.connect(_on_no)

	if _enemy and not _enemy.died.is_connected(_on_any_died):
		_enemy.died.connect(_on_any_died)
	if _player and not _player.died.is_connected(_on_any_died):
		_player.died.connect(_on_any_died)

func _resolve_enemy_player() -> void:
	if _enemy == null:
		# 1) Unique Name
		var n := get_node_or_null("%Enemy")
		if n is EnemyBase:
			_enemy = n as EnemyBase
	# 2) Grupo 'enemy'
	if _enemy == null:
		var list := get_tree().get_nodes_in_group("enemy")
		for e in list:
			if e is EnemyBase:
				_enemy = e as EnemyBase
				break
	# 3) Fallback por clase_name
	if _enemy == null:
		var by_class := get_tree().root.find_children("", "EnemyBase", true, false)
		if by_class.size() > 0 and by_class[0] is EnemyBase:
			_enemy = by_class[0] as EnemyBase

	if _player == null:
		var p := get_node_or_null("%Mage_1")
		if p is Mage1:
			_player = p as Mage1
		else:
			_player = get_tree().root.find_child("Mage_1", true, false) as Mage1

func _on_any_died() -> void:
	if visible:
		return

	# 1) Tomamos el tiempo de la run
	var elapsed_ms: int = _get_run_time_ms()

	# 2) Actualizamos SpeedManager y guardamos
	var sm: Node = get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_run_time", elapsed_ms)
		sm.call("update_personal_best_if_better", elapsed_ms)
		var saver: Node = get_node_or_null("/root/SaveManager")
		if saver:
			saver.call("save_from_speed_manager")
		var pb: int = int(sm.get("personal_best"))
		if _pb_lbl:
			_pb_lbl.text = "Top Time: %s" % SM.fmt_ms(pb)

	if _this_lbl:
		_this_lbl.text = "Run Time: %s" % _fmt_ms(elapsed_ms)

	# 3) Pausa y muestra panel
	if _bottom:
		_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_to_front()
	get_tree().paused = true
	if _bgm:
		_bgm.stop()
	visible = true
	_yes.grab_focus()

func _on_yes() -> void:
	# Guardamos antes de salir
	var saver: Node = get_node_or_null("/root/SaveManager")
	if saver:
		saver.call("save_from_speed_manager")
	# Despausamos y recargamos la batalla actual
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_no() -> void:
	# Guardamos antes de salir
	var saver: Node = get_node_or_null("/root/SaveManager")
	if saver:
		saver.call("save_from_speed_manager")

	get_tree().paused = false

	# Volver al menú (con fallback si cambió la ruta)
	var menu_path: String = MENU_PATH_PRIMARY
	if not ResourceLoader.exists(menu_path):
		menu_path = MENU_PATH_FALLBACK
	get_tree().change_scene_to_file(menu_path)

# -------- helpers --------
func _get_run_time_ms() -> int:
	var rt: RunTimer = get_tree().root.find_child("RunTimer", true, false) as RunTimer
	return int(rt.get_elapsed_ms()) if rt else 0

static func _fmt_ms(ms: int) -> String:
	if ms < 0:
		ms = 0
	var msf: float = float(ms)
	var minutes: int    = int(floor(msf / 60000.0))
	var seconds: int    = int(floor(fmod(msf, 60000.0) / 1000.0))
	var hundredths: int = int(floor(fmod(msf, 1000.0) / 10.0))
	return "%02d:%02d.%02d" % [minutes, seconds, hundredths]
