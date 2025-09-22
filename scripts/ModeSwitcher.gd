extends Node
class_name ModeSwitcher

@export_node_path("Control") var typing_path
@export_node_path("Control") var defend_path
@export_node_path("Control") var bottom_path
@export_node_path("Control") var timer_path

var typing: TypingPanel = null
var defend: DirectionsPanel = null
var bottom: BottomPanel = null
var timer: TurnTimer = null

@export var round_time: float = 5.0
@export var inter_round_delay: float = 0.25

var _is_attack := true  # Attack por defecto

func _ready() -> void:
	set_process_input(true)
	call_deferred("_wire_up")

func _wire_up() -> void:
	typing = _resolve_node(typing_path, "TypingPanel") as TypingPanel
	defend = _resolve_node(defend_path, "DirectionsPanel") as DirectionsPanel
	bottom = _resolve_node(bottom_path, "BottomPanel") as BottomPanel
	timer  = _resolve_node(timer_path,  "TurnTimer") as TurnTimer

	# Botones
	if bottom:
		if not bottom.attack_clicked.is_connected(_on_attack): bottom.attack_clicked.connect(_on_attack)
		if not bottom.defend_clicked.is_connected(_on_defend): bottom.defend_clicked.connect(_on_defend)

	# Solo ATTACK avanza rondas con el timer
	if typing and not typing.score_ready.is_connected(_on_score_ready):
		typing.score_ready.connect(_on_score_ready)

	if timer and not timer.timeout.is_connected(_on_turn_timeout):
		timer.timeout.connect(_on_turn_timeout)

	_set_attack_mode(true)

	# Arranque: si el timer no corre, arráncalo una vez
	if timer and not timer.is_running():
		timer.start(round_time)

	_start_round()

func _resolve_node(path: NodePath, name_fallback: String) -> Node:
	if path != NodePath():
		var n := get_node_or_null(path)
		if n: return n
	return get_tree().root.find_child(name_fallback, true, false)

# Tab para alternar modos (Action: “mode_toggle”)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("mode_toggle"):
		_set_attack_mode(not _is_attack)
		_restart_cycle()
		get_viewport().set_input_as_handled()

func _on_attack() -> void:
	_set_attack_mode(true)
	_restart_cycle()

func _on_defend() -> void:
	_set_attack_mode(false)
	get_viewport().gui_release_focus()
	_restart_cycle()

func _set_attack_mode(is_attack: bool) -> void:
	if _is_attack == is_attack:
		if bottom: bottom.highlight_mode(is_attack)
		return
	_is_attack = is_attack
	if typing:
		typing.visible = is_attack
		if typing.has_method("set_mode_enabled"): typing.set_mode_enabled(is_attack)
	if defend:
		defend.visible = not is_attack
		if defend.has_method("set_mode_enabled"): defend.set_mode_enabled(not is_attack)
	if bottom:
		bottom.highlight_mode(is_attack)

func _restart_cycle() -> void:
	# NO tocamos el timer (ahora es autónomo)
	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()

func _start_round() -> void:
	if _is_attack and typing: typing.start_round()
	elif not _is_attack and defend: defend.start_round()

# ----- Ciclo ATTACK (spell) -----
func _on_score_ready(_rating: String) -> void:
	# Pequeña pausa visual del spell; el timer sigue su propio loop
	await get_tree().create_timer(inter_round_delay).timeout
	if _is_attack and typing:
		typing.start_round()

func _on_turn_timeout() -> void:
	# En ATTACK, al acabarse el tiempo: Fail y nuevo spell tras pausa.
	# El Timer sigue su loop autónomo, NO lo tocamos aquí.
	if _is_attack and typing and typing.has_method("on_timeout"):
		typing.on_timeout()
		await get_tree().create_timer(inter_round_delay).timeout
		typing.start_round()
	# En DEFEND, el timeout no afecta DirectionsPanel.
