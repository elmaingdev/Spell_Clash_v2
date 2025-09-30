extends Node
class_name ModeSwitcher

@export_node_path("Control") var typing_path: NodePath = NodePath("")
@export_node_path("Control") var defend_path: NodePath = NodePath("")
@export_node_path("Control") var bottom_path: NodePath = NodePath("")
@export_node_path("Control") var timer_path: NodePath  = NodePath("")

var typing: TypingPanel = null
var defend: DirectionsPanel = null
var bottom: BottomPanel = null
var timer: TurnTimer = null

@export var round_time: float = 5.0
@export var inter_round_delay: float = 0.25

var _is_attack: bool = true  # Attack por defecto

func _ready() -> void:
	set_process_input(true)
	call_deferred("_wire_up")

func _wire_up() -> void:
	typing = _resolve_node(typing_path, "TypingPanel") as TypingPanel
	defend = _resolve_node(defend_path, "DirectionsPanel") as DirectionsPanel
	bottom = _resolve_node(bottom_path, "BottomPanel") as BottomPanel
	timer  = _resolve_node(timer_path,  "TurnTimer") as TurnTimer

	_connect_bottom_inputs()

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
	if path != NodePath(""):
		var n: Node = get_node_or_null(path)
		if n:
			return n
	return get_tree().root.find_child(name_fallback, true, false)

# ----------------- Wiring robusto de botones -----------------
func _connect_bottom_inputs() -> void:
	# 1) Si el BottomPanel expone señales personalizadas, úsalas
	if bottom:
		if bottom.has_signal("attack_clicked") and not bottom.attack_clicked.is_connected(_on_attack):
			bottom.attack_clicked.connect(_on_attack)
		if bottom.has_signal("defend_clicked") and not bottom.defend_clicked.is_connected(_on_defend):
			bottom.defend_clicked.connect(_on_defend)

	# 2) Unique Name global (%Attackbtn / %Defbtn)
	var atk_btn_n: Node = get_node_or_null(NodePath("%Attackbtn"))
	var def_btn_n: Node = get_node_or_null(NodePath("%Defbtn"))
	if atk_btn_n is BaseButton:
		var atk_btn := atk_btn_n as BaseButton
		if not atk_btn.pressed.is_connected(_on_attack):
			atk_btn.pressed.connect(_on_attack)
	if def_btn_n is BaseButton:
		var def_btn := def_btn_n as BaseButton
		if not def_btn.pressed.is_connected(_on_defend):
			def_btn.pressed.connect(_on_defend)

	# 3) Fallback: buscar por nombre dentro del BottomPanel
	if bottom:
		_autoconnect_buttons_by_name(bottom)

func _autoconnect_buttons_by_name(root: Node) -> void:
	var candidates: Array[BaseButton] = []
	_collect_buttons(root, candidates)
	for btn in candidates:
		var name_l := btn.name.to_lower()
		if _is_attack_button_name(name_l):
			if not btn.pressed.is_connected(_on_attack):
				btn.pressed.connect(_on_attack)
		elif _is_defend_button_name(name_l):
			if not btn.pressed.is_connected(_on_defend):
				btn.pressed.connect(_on_defend)

func _collect_buttons(n: Node, out: Array[BaseButton]) -> void:
	for c in n.get_children():
		if c is BaseButton:
			out.append(c as BaseButton)
		_collect_buttons(c, out)

func _is_attack_button_name(n: String) -> bool:
	# incluye exactamente "attackbtn" por si acaso
	return n.find("attack") != -1 or n.find("atk") != -1 or n == "attackbtn"

func _is_defend_button_name(n: String) -> bool:
	return n.find("defend") != -1 or n.find("def") != -1 or n.find("guard") != -1 or n == "defbtn"

# ----------------- Entrada (teclado) -----------------
# Tab para alternar modos (Action: “mode_toggle”)
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("mode_toggle"):
		_set_attack_mode(not _is_attack)
		_restart_cycle()
		get_viewport().set_input_as_handled()

# ----------------- Callbacks de botones -----------------
func _on_attack() -> void:
	_set_attack_mode(true)
	_restart_cycle()

func _on_defend() -> void:
	_set_attack_mode(false)
	get_viewport().gui_release_focus() # por si LineEdit tenía el foco
	_restart_cycle()

# ----------------- Lógica de switching -----------------
func _set_attack_mode(is_attack: bool) -> void:
	if _is_attack == is_attack:
		if bottom:
			bottom.highlight_mode(is_attack)
		return
	_is_attack = is_attack
	if typing:
		typing.visible = is_attack
		if typing.has_method("set_mode_enabled"):
			typing.set_mode_enabled(is_attack)
	if defend:
		defend.visible = not is_attack
		if defend.has_method("set_mode_enabled"):
			defend.set_mode_enabled(not _is_attack)
	if bottom:
		bottom.highlight_mode(is_attack)

func _restart_cycle() -> void:
	# NO tocamos el timer (es autónomo)
	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()

func _start_round() -> void:
	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()

# ----- Ciclo ATTACK (spell) -----
func _on_score_ready(_rating: String) -> void:
	await get_tree().create_timer(inter_round_delay).timeout
	if _is_attack and typing:
		typing.start_round()

func _on_turn_timeout() -> void:
	if _is_attack and typing and typing.has_method("on_timeout"):
		typing.on_timeout()
		await get_tree().create_timer(inter_round_delay).timeout
		typing.start_round()
	# En DEFEND, el timeout no afecta DirectionsPanel.
