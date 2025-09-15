extends Node2D
class_name Battle

@onready var enemy: Mage2    = %Mage_2
@onready var player: Mage1   = %Mage_1
@onready var info: InfoPanel = %InfoPanel

func _ready() -> void:
	call_deferred("_wire_up")

func _wire_up() -> void:
	if enemy and info and not enemy.hp_changed.is_connected(info.set_enemy_hp):
		enemy.hp_changed.connect(info.set_enemy_hp)
		info.set_enemy_hp(enemy.HP, enemy.max_hp)

	if player and info and not player.hp_changed.is_connected(info.set_player_hp):
		player.hp_changed.connect(info.set_player_hp)
		info.set_player_hp(player.HP, player.max_hp)
