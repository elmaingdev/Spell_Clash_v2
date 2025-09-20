extends Control
class_name BottomPanel

signal attack_clicked
signal defend_clicked

@onready var attack_btn: TextureButton = $Panel/MarginContainer/HBoxContainer/Attackbtn
@onready var defend_btn: TextureButton = $Panel/MarginContainer/HBoxContainer/Defbtn

func _ready() -> void:
	# Que este panel quede siempre encima y reciba clicks
	z_as_relative = false
	z_index = 500
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Evita que las flechas naveguen entre botones
	if attack_btn: attack_btn.focus_mode = Control.FOCUS_NONE
	if defend_btn: defend_btn.focus_mode = Control.FOCUS_NONE

	if attack_btn and not attack_btn.pressed.is_connected(_on_attack):
		attack_btn.pressed.connect(_on_attack)
	if defend_btn and not defend_btn.pressed.is_connected(_on_defend):
		defend_btn.pressed.connect(_on_defend)

	_refresh_ui_state(true) # por defecto: Attack activo

func _on_attack() -> void:
	attack_clicked.emit()
	_refresh_ui_state(true)

func _on_defend() -> void:
	defend_clicked.emit()
	_refresh_ui_state(false)

func _refresh_ui_state(is_attack: bool) -> void:
	if attack_btn: attack_btn.disabled = is_attack
	if defend_btn: defend_btn.disabled = not is_attack
