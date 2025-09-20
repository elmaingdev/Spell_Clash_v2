extends Node
class_name ModeSwitcher

# Arrastra estos NodePaths en el Inspector para evitar sorpresas
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
	# Defer para que todo el UI esté en el árbol
	call_deferred("_wire_up")

func _wire_up() -> void:
	# -------- Resolver referencias --------
	typing = _resolve_node(typing_path, "TypingPanel") as TypingPanel
	defend = _resolve_node(defend_path, "DirectionsPanel") as DirectionsPanel
	bottom = _resolve_node(bottom_path, "BottomPanel") as BottomPanel
	timer  = _resolve_node(timer_path,  "TurnTimer") as TurnTimer

	print("[ModeSwitcher] typing=", typing, " defend=", defend, " bottom=", bottom, " timer=", timer)

	# -------- Conexiones --------
	if bottom:
		if not bottom.attack_clicked.is_connected(_on_attack):
			bottom.attack_clicked.connect(_on_attack)
		if not bottom.defend_clicked.is_connected(_on_defend):
			bottom.defend_clicked.connect(_on_defend)
	else:
		push_warning("[ModeSwitcher] BottomPanel no encontrado (atajos de modo deshabilitados).")

	if typing and not typing.score_ready.is_connected(_on_score_ready):
		typing.score_ready.connect(_on_score_ready)
	if defend and not defend.score_ready.is_connected(_on_score_ready):
		defend.score_ready.connect(_on_score_ready)

	if timer and not timer.timeout.is_connected(_on_turn_timeout):
		timer.timeout.connect(_on_turn_timeout)

	# -------- Estado inicial --------
	_set_attack_mode(true)   # Typing visible por defecto

	# Si algún panel está visible pero vacío, fuerza contenido
	if typing and typing.visible:
		if typing.has_method("start_round"):
			typing.start_round()
	if defend and defend.visible:
		if defend.has_method("start_round"):
			defend.start_round()

	# Arranca timer si existe
	if timer:
		timer.start(round_time)
	else:
		push_warning("[ModeSwitcher] TurnTimer no encontrado: el juego funcionará sin cuenta regresiva.")

func _resolve_node(path: NodePath, name_fallback: String) -> Node:
	# 1) Si hay NodePath en el Inspector
	if path != NodePath():
		var n := get_node_or_null(path)
		if n: return n
	# 2) Busca por nombre en todo el árbol (incluye instancias dentro de sub-escenas)
	var found := get_tree().root.find_child(name_fallback, true, false)
	return found

# ---- UI: cambiar de modo ----
func _on_attack() -> void:
	_set_attack_mode(true)
	_restart_cycle()

func _on_defend() -> void:
	_set_attack_mode(false)
	get_viewport().gui_release_focus()
	_restart_cycle()

func _set_attack_mode(is_attack: bool) -> void:
	_is_attack = is_attack
	if typing:
		typing.visible = is_attack
		if typing.has_method("set_mode_enabled"):
			typing.set_mode_enabled(is_attack)
	if defend:
		defend.visible = not is_attack
		if defend.has_method("set_mode_enabled"):
			defend.set_mode_enabled(not is_attack)

# ---- Ciclo de rondas ----
func _restart_cycle() -> void:
	# Prepara contenido del panel activo
	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()
	# Reinicia timer si existe
	if timer:
		timer.restart()
	else:
		print("[ModeSwitcher] Sin TurnTimer; solo mostrando contenido.")

# ---- Callbacks ----
func _on_score_ready(_rating: String) -> void:
	if timer:
		await timer.stop_and_restart_after(inter_round_delay)
	# Pide nuevo contenido
	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()

func _on_turn_timeout() -> void:
	# Notifica FAIL visual al panel activo (si define on_timeout)
	if _is_attack and typing and typing.has_method("on_timeout"):
		typing.on_timeout()
	elif not _is_attack and defend and defend.has_method("on_timeout"):
		defend.on_timeout()
	# Pausa breve y vuelve a empezar
	if timer:
		await timer.stop_and_restart_after(inter_round_delay)
	# Nuevo contenido
	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()
