extends Control
class_name GameOverPanel

@onready var _yes: Button = $PanelContainer/VBoxContainer/HBoxContainer/Yesbtn
@onready var _no: Button  = $PanelContainer/VBoxContainer/HBoxContainer/Nobtn

@onready var _enemy:  Mage2 = %Mage_2
@onready var _player: Mage1 = %Mage_1
@onready var _bgm: AudioStreamPlayer = %BGM
@onready var _bottom: Control = %BottomPanel   # marca #BottomPanel en Battle

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# asegúralo por encima de todo
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
	# evita que el BottomPanel (Full Rect) capture el mouse
	if _bottom:
		_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# trae este panel al frente (reemplaza a raise())
	move_to_front()

	get_tree().paused = true
	if _bgm: _bgm.stop()
	visible = true
	_yes.grab_focus()

func _on_yes() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_no() -> void:
	get_tree().paused = false
	get_tree().quit()
