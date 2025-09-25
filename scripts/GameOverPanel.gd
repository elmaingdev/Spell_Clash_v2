extends Control
class_name GameOverPanel

@onready var _yes: Button = $PanelContainer/VBoxContainer/HBoxContainer/Yesbtn
@onready var _no: Button  = $PanelContainer/VBoxContainer/HBoxContainer/Nobtn
@onready var _this_lbl: Label = $PanelContainer/VBoxContainer/This_lbl

@onready var _enemy:  Mage2 = %Mage_2
@onready var _player: Mage1 = %Mage_1
@onready var _bgm: AudioStreamPlayer = %BGM
@onready var _bottom: Control = %BottomPanel

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	z_as_relative = false
	z_index = 1000
	top_level = true

	_yes.pressed.connect(_on_yes)
	_no.pressed.connect(_on_no)

	if _enemy and not _enemy.died.is_connected(_on_any_died):
		_enemy.died.connect(_on_any_died)
	if _player and not _player.died.is_connected(_on_any_died):
		_player.died.connect(_on_any_died)

func _on_any_died() -> void:
	if visible: return
	if _bottom:
		_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	move_to_front()
	get_tree().paused = true
	if _bgm: _bgm.stop()

	# Mostrar mejor combo de la PARTIDA actual
	var cc := get_node_or_null("/root/ComboCounter")
	var best_in_match := 0
	if cc:
		if cc.has_method("get_best_combo"):
			best_in_match = int(cc.call("get_best_combo"))
		elif "best_combo" in cc:
			best_in_match = int(cc.best_combo)
	if _this_lbl:
		_this_lbl.text = str(best_in_match, " combo")

	visible = true
	_yes.grab_focus()

func _on_yes() -> void:
	# Resetea estado de partida ANTES de recargar
	var cc := get_node_or_null("/root/ComboCounter")
	if cc: cc.call_deferred("start_new_match")
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_no() -> void:
	get_tree().paused = false
	get_tree().quit()
