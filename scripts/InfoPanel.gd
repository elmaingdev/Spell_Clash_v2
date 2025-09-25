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
			enemy_hp.min_value = 0
			enemy_hp.max_value = default_enemy_max_hp
			enemy_hp.value = default_enemy_max_hp
		if player_hp:
			player_hp.min_value = 0
			player_hp.max_value = default_player_max_hp
			player_hp.value = default_player_max_hp

	# Conecta a ambos magos cuando todo el árbol esté listo
	call_deferred("_auto_connect_both")

func _auto_connect_both() -> void:
	# ---- ENEMY (Mage_2) ----
	var enemy := get_node_or_null("%Mage_2") as Mage2
	if enemy == null:
		enemy = get_tree().root.find_child("Mage_2", true, false) as Mage2
	if enemy == null:
		var enemies := get_tree().root.find_children("", "Mage2", true, false)
		if enemies.size() > 0: enemy = enemies[0] as Mage2
	if enemy and not enemy.hp_changed.is_connected(set_enemy_hp):
		enemy.hp_changed.connect(set_enemy_hp)
		set_enemy_hp(enemy.HP, enemy.max_hp)

	# ---- PLAYER (Mage_1) ----
	var player := get_node_or_null("%Mage_1") as Mage1
	if player == null:
		player = get_tree().root.find_child("Mage_1", true, false) as Mage1
	if player == null:
		var players := get_tree().root.find_children("", "Mage1", true, false)
		if players.size() > 0: player = players[0] as Mage1
	if player and not player.hp_changed.is_connected(set_player_hp):
		player.hp_changed.connect(set_player_hp)
		set_player_hp(player.HP, player.max_hp)

# ---- API usada por las señales ----
func set_enemy_hp(current: int, maxv: int) -> void:
	if not enemy_hp: return
	enemy_hp.min_value = 0
	enemy_hp.max_value = maxv
	enemy_hp.value = clamp(current, 0, maxv)

func set_player_hp(current: int, maxv: int) -> void:
	if not player_hp: return
	player_hp.min_value = 0
	player_hp.max_value = maxv
	player_hp.value = clamp(current, 0, maxv)
