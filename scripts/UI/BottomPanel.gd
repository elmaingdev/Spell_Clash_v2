extends Control
class_name BottomPanel

signal attack_clicked
signal defend_clicked

@onready var attack_btn: TextureButton = $Panel/MarginContainer/HBoxContainer/Attackbtn
@onready var defend_btn: TextureButton = $Panel/MarginContainer/HBoxContainer/Defbtn
@onready var charge_bar: ProgressBar   = $Panel/MarginContainer/HBoxContainer/Chargebar

@export var bounce_scale: float = 1.12
@export var bounce_time: float = 0.12

func _ready() -> void:
	if attack_btn and not attack_btn.pressed.is_connected(_on_attack):
		attack_btn.pressed.connect(_on_attack)
	if defend_btn and not defend_btn.pressed.is_connected(_on_defend):
		defend_btn.pressed.connect(_on_defend)
	# Estado inicial visual (Attack activo)
	_refresh_ui_state(true)

func _on_attack() -> void:
	attack_clicked.emit()
	highlight_mode(true)

func _on_defend() -> void:
	defend_clicked.emit()
	highlight_mode(false)

func highlight_mode(is_attack: bool) -> void:
	_refresh_ui_state(is_attack)
	# Animar el botón activo (tipado explícito para evitar Variant)
	var btn: TextureButton = attack_btn if is_attack else defend_btn
	_bounce(btn)

func _refresh_ui_state(is_attack: bool) -> void:
	if attack_btn: attack_btn.disabled = is_attack
	if defend_btn: defend_btn.disabled = not is_attack

func _bounce(btn: TextureButton) -> void:
	if btn == null: return
	btn.pivot_offset = btn.size * 0.5
	btn.scale = Vector2.ONE

	# Matar tween previo (tipado explícito para evitar Variant)
	var old: Tween = null
	if btn.has_meta("bounce_tween"):
		old = btn.get_meta("bounce_tween") as Tween
	if is_instance_valid(old):
		old.kill()

	# Nuevo tween (tipado)
	var tw: Tween = create_tween()
	btn.set_meta("bounce_tween", tw)
	tw.tween_property(btn, "scale", Vector2(bounce_scale, bounce_scale), bounce_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, bounce_time)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
