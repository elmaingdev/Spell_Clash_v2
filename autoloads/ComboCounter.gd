extends Node

signal combo_changed(current: int, best: int)
signal combo_reset()

@export_node_path("Control") var typing_panel_path: NodePath
@export_node_path("Control") var directions_panel_path: NodePath
@export_node_path("Node")   var player_path: NodePath   # Mage_1
@export_node_path("Node")   var enemy_path: NodePath    # Mage_2

var _typing: TypingPanel = null
var _direc: DirectionsPanel = null
var _player: Node = null
var _enemy: Node = null

var current: int = 0          # combo actual de la partida
var best: int = 0             # récord de sesión (opcional)
var best_combo: int = 0       # mejor combo de la partida actual

func _ready() -> void:
	add_to_group("combo_counter")
	# Observa el árbol: cuando aparezcan los nodos de la nueva escena, me conecto.
	if not get_tree().node_added.is_connected(_on_tree_node_added):
		get_tree().node_added.connect(_on_tree_node_added)
	# Primer cableado (por si ya están en escena)
	_scan_tree_for_sources()
	_emit()

# ---------- API pública ----------
func start_new_match() -> void:
	# Llamar al cargar la escena Battle o antes de recargarla desde GameOverPanel.
	current = 0
	best_combo = 0
	_emit()

func rewire() -> void:
	_disconnect_sources()
	_scan_tree_for_sources()
	_emit()

func emit_now() -> void:
	combo_changed.emit(current, best)

func get_best_combo() -> int:
	return best_combo

func reset(all: bool = false) -> void:
	current = 0
	if all: best = 0
	combo_reset.emit()
	_emit()

# ---------- Wiring ----------
func _disconnect_sources() -> void:
	# Typing
	if _typing and _typing.is_inside_tree():
		if _typing.score_ready.is_connected(_on_attack_score):
			_typing.score_ready.disconnect(_on_attack_score)
	_typing = null
	# Directions
	if _direc and _direc.is_inside_tree():
		if _direc.score_ready.is_connected(_on_defend_score):
			_direc.score_ready.disconnect(_on_defend_score)
	_direc = null
	# Player
	if _player and _player.is_inside_tree():
		if _player.has_signal("got_hit") and _player.got_hit.is_connected(_on_player_hit):
			_player.got_hit.disconnect(_on_player_hit)
		if _player.has_signal("died") and _player.died.is_connected(_on_any_died):
			_player.died.disconnect(_on_any_died)
	_player = null
	# Enemy
	if _enemy and _enemy.is_inside_tree():
		if _enemy.has_signal("died") and _enemy.died.is_connected(_on_any_died):
			_enemy.died.disconnect(_on_any_died)
	_enemy = null

func _scan_tree_for_sources() -> void:
	# TypingPanel
	if typing_panel_path != NodePath():
		var n1 := get_node_or_null(typing_panel_path)
		if n1 is TypingPanel: _typing = n1
	if _typing == null:
		_typing = get_tree().root.find_child("TypingPanel", true, false) as TypingPanel
	if _typing and not _typing.score_ready.is_connected(_on_attack_score):
		_typing.score_ready.connect(_on_attack_score)

	# DirectionsPanel
	if directions_panel_path != NodePath():
		var n2 := get_node_or_null(directions_panel_path)
		if n2 is DirectionsPanel: _direc = n2
	if _direc == null:
		_direc = get_tree().root.find_child("DirectionsPanel", true, false) as DirectionsPanel
	if _direc and not _direc.score_ready.is_connected(_on_defend_score):
		_direc.score_ready.connect(_on_defend_score)

	# Player
	if player_path != NodePath():
		var n3 := get_node_or_null(player_path)
		if n3: _player = n3
	if _player == null:
		_player = get_tree().root.find_child("Mage_1", true, false)
	if _player:
		if _player.has_signal("got_hit") and not _player.got_hit.is_connected(_on_player_hit):
			_player.got_hit.connect(_on_player_hit)
		if _player.has_signal("died") and not _player.died.is_connected(_on_any_died):
			_player.died.connect(_on_any_died)

	# Enemy
	if enemy_path != NodePath():
		var n4 := get_node_or_null(enemy_path)
		if n4: _enemy = n4
	if _enemy == null:
		_enemy = get_tree().root.find_child("Mage_2", true, false)
	if _enemy and _enemy.has_signal("died") and not _enemy.died.is_connected(_on_any_died):
		_enemy.died.connect(_on_any_died)

func _on_tree_node_added(n: Node) -> void:
	# Si aparece alguno de los nodos que nos interesan tras un reload, nos conectamos.
	if _typing == null and n is TypingPanel:
		_typing = n
		if not _typing.score_ready.is_connected(_on_attack_score):
			_typing.score_ready.connect(_on_attack_score)
	if _direc == null and n is DirectionsPanel:
		_direc = n
		if not _direc.score_ready.is_connected(_on_defend_score):
			_direc.score_ready.connect(_on_defend_score)
	if _player == null and (n.name == "Mage_1" or (n.has_signal("got_hit") and n.has_signal("died"))):
		_player = n
		if _player.has_signal("got_hit") and not _player.got_hit.is_connected(_on_player_hit):
			_player.got_hit.connect(_on_player_hit)
		if _player.has_signal("died") and not _player.died.is_connected(_on_any_died):
			_player.died.connect(_on_any_died)
	if _enemy == null and (n.name == "Mage_2" or n.has_signal("died")):
		_enemy = n
		if _enemy.has_signal("died") and not _enemy.died.is_connected(_on_any_died):
			_enemy.died.connect(_on_any_died)

# ---------- Handlers ----------
func _on_attack_score(rating: String) -> void:
	match rating:
		"Perfect", "Nice", "Good":
			_inc()
		"Fail":
			_reset_combo()

func _on_defend_score(rating: String) -> void:
	match rating:
		"PROTECTION":
			_inc()
		"Fail":
			_reset_combo()

func _on_player_hit() -> void:
	_reset_combo()

func _on_any_died() -> void:
	# Fin de la partida → dejamos best_combo intacto (ya quedó en el máximo de la partida)
	_reset_combo()

# ---------- Lógica ----------
func _inc() -> void:
	current += 1
	if current > best: best = current
	if current > best_combo: best_combo = current
	_emit()

func _reset_combo() -> void:
	if current != 0:
		current = 0
		combo_reset.emit()
	_emit()

func _emit() -> void:
	combo_changed.emit(current, best)

func get_current() -> int:
	return current
