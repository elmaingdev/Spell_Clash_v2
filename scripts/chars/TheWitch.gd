# res://scripts/chars/TheWitch.gd
extends EnemyBase
class_name TheWitch

# Valores por defecto (según la tabla de balance)
@export var custom_hp: int = 280
@export var custom_damage: int = 14
@export var custom_shoot_interval: float = 4.2
@export_range(0.0, 1.0, 0.01) var custom_block_chance: float = 0.18
@export var custom_block_interval: float = 0.3  # opcional; si quieres que herede el de EnemyBase, pon 0.0

func _apply_custom_stats() -> void:
	max_hp = custom_hp
	HP = custom_hp
	projectile_damage = custom_damage
	shoot_interval = custom_shoot_interval
	block_chance = custom_block_chance
	if custom_block_interval > 0.0:
		block_interval = custom_block_interval
