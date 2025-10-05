extends Node2D
class_name Battle

@onready var enemy: EnemyBase = get_node_or_null("%Enemy") as EnemyBase
@onready var player: Mage1    = get_node_or_null("%Mage_1")
@onready var info: InfoPanel  = get_node_or_null("%InfoPanel")

# Referencias opcionales por Inspector (para evitar búsquedas)
@export_node_path("Control") var typing_panel_path: NodePath     = NodePath("")
@export_node_path("Control") var directions_panel_path: NodePath = NodePath("")
@export_node_path("Control") var timer_path: NodePath            = NodePath("")

var typing: TypingPanel = null
var defend: DirectionsPanel = null
var timer_ref: TurnTimer = null

func _ready() -> void:
	# Reset combo al entrar a Battle
	var cc: Node = get_node_or_null("/root/ComboCounter")
	if cc:
		cc.call_deferred("start_new_match")
		cc.call_deferred("rewire")
		cc.call_deferred("emit_now")

	# Cargar PB desde disco a SpeedManager (vía SaveManager)
	var saver: Node = get_node_or_null("/root/SaveManager")
	if saver and saver.has_method("load_into_speed_manager"):
		saver.call_deferred("load_into_speed_manager")

	call_deferred("_wire_up")

func _wire_up() -> void:
	# Resolver enemigo si no está (por si el Unique Name no se asignó)
	_resolve_enemy_if_needed()

	# --- UI HP wiring ---
	if enemy and info and info.has_method("set_enemy_hp"):
		var cb_e: Callable = Callable(info, "set_enemy_hp")
		if not enemy.hp_changed.is_connected(cb_e):
			enemy.hp_changed.connect(cb_e)
		info.set_enemy_hp(enemy.HP, enemy.max_hp)

	if player and info and info.has_method("set_player_hp"):
		var cb_p: Callable = Callable(info, "set_player_hp")
		if not player.hp_changed.is_connected(cb_p):
			player.hp_changed.connect(cb_p)
		info.set_player_hp(player.HP, player.max_hp)

	# --- Resolver Timer / Panels y conectar candado ---
	_resolve_timer_and_panels()
	_connect_candado_events()
	_connect_timeout_if_needed()

# ============================================================
#        Candado anti “doble evento” (Timer vs. éxito)
# ============================================================

func _resolve_enemy_if_needed() -> void:
	if enemy != null:
		return
	# 1) Unique Name
	var n := get_node_or_null("%Enemy")
	if n is EnemyBase:
		enemy = n as EnemyBase
		return
	# 2) Grupo
	var list := get_tree().get_nodes_in_group("enemy")
	for e in list:
		if e is EnemyBase:
			enemy = e as EnemyBase
			return
	# 3) Fallback por clase_name
	var by_class := get_tree().root.find_children("", "EnemyBase", true, false)
	if by_class.size() > 0 and by_class[0] is EnemyBase:
		enemy = by_class[0] as EnemyBase

func _resolve_timer_and_panels() -> void:
	# --- TurnTimer ---
	if timer_path != NodePath(""):
		var t: Node = get_node_or_null(timer_path)
		if t is TurnTimer:
			timer_ref = t
	if timer_ref == null:
		timer_ref = get_node_or_null("%TurnTimer") as TurnTimer   # Unique Name recomendado
	if timer_ref == null:
		timer_ref = get_tree().root.find_child("TurnTimer", true, false) as TurnTimer

	# --- TypingPanel ---
	if typing_panel_path != NodePath(""):
		var tp: Node = get_node_or_null(typing_panel_path)
		if tp is TypingPanel:
			typing = tp
	if typing == null:
		typing = get_node_or_null("%TypingPanel") as TypingPanel
	if typing == null:
		typing = get_tree().root.find_child("TypingPanel", true, false) as TypingPanel

	# --- DirectionsPanel ---
	if directions_panel_path != NodePath(""):
		var dp: Node = get_node_or_null(directions_panel_path)
		if dp is DirectionsPanel:
			defend = dp
	if defend == null:
		defend = get_node_or_null("%DirectionsPanel") as DirectionsPanel
	if defend == null:
		defend = get_tree().root.find_child("DirectionsPanel", true, false) as DirectionsPanel

func _connect_candado_events() -> void:
	# Éxitos de ataque/defensa marcan el Timer como “resuelto este frame”
	if typing:
		if not typing.score_ready.is_connected(_on_typing_score_ready):
			typing.score_ready.connect(_on_typing_score_ready)
		if not typing.spell_success.is_connected(_on_spell_success):
			typing.spell_success.connect(_on_spell_success)

	if defend:
		if not defend.score_ready.is_connected(_on_defense_score_ready):
			defend.score_ready.connect(_on_defense_score_ready)

func _connect_timeout_if_needed() -> void:
	# Si el TurnTimer no está cableado al TypingPanel, lo conectamos acá
	if timer_ref and typing and typing.has_method("on_timeout"):
		var cb: Callable = Callable(typing, "on_timeout")
		if not timer_ref.timeout.is_connected(cb):
			timer_ref.timeout.connect(cb)

# ---------- Handlers de “éxito” ----------
func _on_typing_score_ready(rating: String) -> void:
	if rating == "Perfect" or rating == "Nice" or rating == "Good":
		_mark_timer_safely()

func _on_spell_success(_phrase: String) -> void:
	_mark_timer_safely()

func _on_defense_score_ready(rating: String) -> void:
	if rating == "PROTECTION":
		_mark_timer_safely()

func _mark_timer_safely() -> void:
	if timer_ref and timer_ref.has_method("mark_resolved_for_next_frame"):
		timer_ref.mark_resolved_for_next_frame()
