extends Control
class_name InfoPanel

@export var auto_init: bool = true
@export var default_enemy_max_hp: int = 50
@export var default_player_max_hp: int = 100

@onready var enemy_hp: ProgressBar  = %EnemyHP
@onready var player_hp: ProgressBar = %PlayerHP

func _ready() -> void:
	# Inicializa barras (por si la señal tarda en llegar)
	if auto_init:
		if enemy_hp:
			enemy_hp.min_value = 0.0
			enemy_hp.max_value = float(default_enemy_max_hp)
			enemy_hp.value = float(default_enemy_max_hp)
		if player_hp:
			player_hp.min_value = 0.0
			player_hp.max_value = float(default_player_max_hp)
			player_hp.value = float(default_player_max_hp)

	# Conecta cuando todo el árbol esté listo
	call_deferred("_auto_connect_both")

func _auto_connect_both() -> void:
	# ---- ENEMY ----
	var enemy := _find_enemy()
	if enemy and not enemy.hp_changed.is_connected(set_enemy_hp):
		enemy.hp_changed.connect(set_enemy_hp)
		set_enemy_hp(enemy.HP, enemy.max_hp)

	# ---- PLAYER ----
	var player := _find_player()
	if player and not player.hp_changed.is_connected(set_player_hp):
		player.hp_changed.connect(set_player_hp)
		set_player_hp(player.HP, player.max_hp)

# ---------- búsquedas robustas ----------
func _find_enemy() -> EnemyBase:
	# 1) Unique Name
	var n := get_node_or_null("%Enemy")
	if n is EnemyBase:
		return n as EnemyBase

	# 2) Grupo 'enemy'
	var list := get_tree().get_nodes_in_group("enemy")
	for e in list:
		if e is EnemyBase:
			return e as EnemyBase

	# 3) Fallback: por clase_name en el árbol
	var by_class := get_tree().root.find_children("", "EnemyBase", true, false)
	if by_class.size() > 0 and by_class[0] is EnemyBase:
		return by_class[0] as EnemyBase

	return null

func _find_player() -> Mage1:
	# 1) Unique Name recomendado
	var p := get_node_or_null("%Mage_1")
	if p is Mage1:
		return p as Mage1
	# 2) Fallback: búsqueda por nombre/clase
	var found := get_tree().root.find_child("Mage_1", true, false)
	return found as Mage1

# ---- API desde señales ----
func set_enemy_hp(current: int, maxv: int) -> void:
	if not enemy_hp:
		return
	enemy_hp.min_value = 0.0
	enemy_hp.max_value = float(maxv)
	enemy_hp.value = _display_value(current, maxv)
	enemy_hp.tooltip_text = "%d / %d" % [current, maxv]

func set_player_hp(current: int, maxv: int) -> void:
	if not player_hp:
		return
	player_hp.min_value = 0.0
	player_hp.max_value = float(maxv)
	player_hp.value = _display_value(current, maxv)
	player_hp.tooltip_text = "%d / %d" % [current, maxv]

# ---- Mostrar mínimo 1% si sigue con vida (>0) ----
func _display_value(current: int, maxv: int) -> float:
	if maxv <= 0:
		return 0.0
	if current <= 0:
		return 0.0
	var valf: float = float(current)
	var min_display: float = float(maxv) * 0.01
	if valf < min_display:
		valf = min_display
	return clampf(valf, 0.0, float(maxv))
