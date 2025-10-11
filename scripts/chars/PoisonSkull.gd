# res://scripts/chars/PoisonSkull.gd
extends EnemyBase
class_name PoisonSkull

# Stats CUSTOM de este enemigo (se aplican sólo si custom_enemy = true en la instancia)
@export var custom_hp: int = 110
@export var custom_damage: int = 8
@export var custom_shoot_interval: float = 5.5
@export_range(0.0, 1.0, 0.01) var custom_block_chance: float = 0.05

func _apply_custom_stats() -> void:
	# Llamado desde EnemyBase._apply_custom_if_enabled() si custom_enemy == true
	max_hp = custom_hp
	HP = custom_hp
	projectile_damage = custom_damage
	shoot_interval = custom_shoot_interval
	block_chance = custom_block_chance
	# block_interval queda heredado (0.8s), modifícalo aquí si quieres otro valor
