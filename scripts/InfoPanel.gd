extends Control
class_name InfoPanel

@export var auto_init: bool = true
@export var default_enemy_max_hp: int = 250
@export var default_player_max_hp: int = 100

@onready var enemy_hp: ProgressBar  = %EnemyHP
@onready var player_hp: ProgressBar = %PlayerHP

func _ready() -> void:
	# Inicializa barras (por si no llega la señal de inmediato)
	if auto_init:
		if enemy_hp:
			enemy_hp.min_value = 0.0
			enemy_hp.max_value = float(default_enemy_max_hp)
			enemy_hp.value = float(default_enemy_max_hp)
		if player_hp:
			player_hp.min_value = 0.0
			player_hp.max_value = float(default_player_max_hp)
			player_hp.value = float(default_player_max_hp)

	# Conecta a ambos magos cuando todo el árbol esté listo
	call_deferred("_auto_connect_both")

func _auto_connect_both() -> void:
	# ---- ENEMY (Mage_2) ----
	var enemy: Mage2 = get_node_or_null("%Mage_2") as Mage2
	if enemy == null:
		enemy = get_tree().root.find_child("Mage_2", true, false) as Mage2
	if enemy == null:
		var enemies: Array = get_tree().root.find_children("", "Mage2", true, false)
		if enemies.size() > 0:
			enemy = enemies[0] as Mage2
	if enemy and not enemy.hp_changed.is_connected(set_enemy_hp):
		enemy.hp_changed.connect(set_enemy_hp)
		set_enemy_hp(enemy.HP, enemy.max_hp)

	# ---- PLAYER (Mage_1) ----
	var player: Mage1 = get_node_or_null("%Mage_1") as Mage1
	if player == null:
		player = get_tree().root.find_child("Mage_1", true, false) as Mage1
	if player == null:
		var players: Array = get_tree().root.find_children("", "Mage1", true, false)
		if players.size() > 0:
			player = players[0] as Mage1
	if player and not player.hp_changed.is_connected(set_player_hp):
		player.hp_changed.connect(set_player_hp)
		set_player_hp(player.HP, player.max_hp)

# ---- API usada por las señales ----
func set_enemy_hp(current: int, maxv: int) -> void:
	if not enemy_hp:
		return
	enemy_hp.min_value = 0.0
	enemy_hp.max_value = float(maxv)
	enemy_hp.value = _display_value(current, maxv)
	enemy_hp.tooltip_text = "%d / %d" % [current, maxv]  # opcional, útil para depurar

func set_player_hp(current: int, maxv: int) -> void:
	if not player_hp:
		return
	player_hp.min_value = 0.0
	player_hp.max_value = float(maxv)
	player_hp.value = _display_value(current, maxv)
	player_hp.tooltip_text = "%d / %d" % [current, maxv]  # opcional, útil para depurar

# ---- Mostrar mínimo 1% si sigue con vida (>0) ----
func _display_value(current: int, maxv: int) -> float:
	if maxv <= 0:
		return 0.0
	if current <= 0:
		return 0.0
	var valf: float = float(current)
	var min_display: float = float(maxv) * 0.01  # 1% exacto
	if valf < min_display:
		valf = min_display
	return clampf(valf, 0.0, float(maxv))
