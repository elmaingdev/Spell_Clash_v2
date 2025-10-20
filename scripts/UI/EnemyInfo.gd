# res://scripts/UI/EnemyInfo.gd
extends Control
class_name EnemyInfo

@export_node_path("Node") var enemy_path: NodePath = NodePath("")
@export_node_path("Label") var enemy_name_path: NodePath = NodePath("%EnemyName")
@export_node_path("TextureProgressBar") var enemy_hp_path: NodePath = NodePath("%EnemyHP")

@onready var name_lbl: Label = null
@onready var hp_bar: TextureProgressBar = null

var _enemy: EnemyBase = null

func _ready() -> void:
	# Name label
	if enemy_name_path != NodePath(""):
		var n := get_node_or_null(enemy_name_path)
		if n is Label: name_lbl = n
	if name_lbl == null:
		var f1 := find_child("EnemyName", true, false)
		if f1 is Label: name_lbl = f1

	# HP bar
	if enemy_hp_path != NodePath(""):
		var h := get_node_or_null(enemy_hp_path)
		if h is TextureProgressBar: hp_bar = h
	if hp_bar == null:
		var f2 := find_child("EnemyHP", true, false)
		if f2 is TextureProgressBar: hp_bar = f2

	_enemy = _resolve_enemy()
	_wire_enemy(_enemy)
	if _enemy == null:
		call_deferred("_retry_wire")

func _retry_wire() -> void:
	if _enemy == null:
		_enemy = _resolve_enemy()
		_wire_enemy(_enemy)

func _resolve_enemy() -> EnemyBase:
	if enemy_path != NodePath(""):
		var n := get_node_or_null(enemy_path)
		if n is EnemyBase: return n
	var n2 := get_node_or_null("%Enemy")
	if n2 is EnemyBase: return n2
	var g := get_tree().get_nodes_in_group("enemy")
	for e in g:
		if e is EnemyBase: return e
	var by_class := get_tree().root.find_children("", "EnemyBase", true, false)
	if by_class.size() > 0 and by_class[0] is EnemyBase:
		return by_class[0] as EnemyBase
	return null

func _wire_enemy(n: EnemyBase) -> void:
	if n == null: return
	if name_lbl:
		var pretty_name: String = n.name
		if "display_name" in n:
			pretty_name = str(n.display_name)
		name_lbl.text = pretty_name

	if n.has_signal("hp_changed") and not n.hp_changed.is_connected(_on_hp_changed):
		n.hp_changed.connect(_on_hp_changed)

	var cur := (n.HP if "HP" in n else 0)
	var mx  := (n.max_hp if "max_hp" in n else 1)
	_on_hp_changed(cur, mx)

func _on_hp_changed(current: int, max_value: int) -> void:
	if hp_bar == null: return
	hp_bar.min_value = 0.0
	hp_bar.max_value = float(max(1, max_value))
	hp_bar.value     = float(clamp(current, 0, max_value))
