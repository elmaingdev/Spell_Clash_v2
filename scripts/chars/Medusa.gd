# res://scripts/chars/Medusa.gd
extends EnemyBase
class_name Medusa

@export var custom_hp: int = 130
@export var custom_damage: int = 12
@export var custom_shoot_interval: float = 5.0
@export_range(0.0, 1.0, 0.01) var custom_block_chance: float = 0.0


func _apply_custom_stats() -> void:
	max_hp = custom_hp
	HP = custom_hp
	projectile_damage = custom_damage
	shoot_interval = custom_shoot_interval
	block_chance = custom_block_chance
