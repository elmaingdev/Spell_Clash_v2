# res://scripts/UI/PlayerHealthBar.gd
extends Control
class_name PlayerHealthBar

@export_node_path("TextureProgressBar") var bar_path: NodePath = NodePath("%PlayerHP")
@export_node_path("Node") var player_path: NodePath = NodePath("")   # opcional

@onready var bar: TextureProgressBar = null
var _player: Mage1 = null

func _ready() -> void:
	# barra
	if bar_path != NodePath(""):
		bar = get_node_or_null(bar_path) as TextureProgressBar
	if bar == null:
		bar = find_child("PlayerHP", true, false) as TextureProgressBar
	if bar == null:
		push_error("PlayerHealthBar: no encontré PlayerHP (TextureProgressBar).")
		return

	# jugador
	_player = _resolve_player()
	_wire_player(_player)

func _resolve_player() -> Mage1:
	# 1) Path directo
	if player_path != NodePath(""):
		var n := get_node_or_null(player_path)
		if n is Mage1: return n
	# 2) Unique Name
	var by_unique := get_node_or_null("%Mage_1")
	if by_unique is Mage1: return by_unique
	# 3) Grupo "player"
	var g := get_tree().get_nodes_in_group("player")
	if not g.is_empty() and g[0] is Mage1: return g[0]
	# 4) Búsqueda por nombre/clase
	var found := get_tree().root.find_children("", "Mage1", true, false)
	if found.size() > 0 and found[0] is Mage1: return found[0]
	return null

func _wire_player(p: Mage1) -> void:
	if p == null: return
	if p.has_signal("hp_changed") and not p.hp_changed.is_connected(_on_hp_changed):
		p.hp_changed.connect(_on_hp_changed)
	# estado inicial
	_on_hp_changed(p.HP, p.max_hp)

func _on_hp_changed(current: int, max_value: int) -> void:
	if bar == null: return
	bar.min_value = 0
	bar.max_value = max(1, max_value)
	bar.value = float(clamp(current, 0, max_value))  # TextureProgressBar usa float
