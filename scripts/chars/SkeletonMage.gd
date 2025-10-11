# res://scripts/chars/SkeletonMage.gd
extends EnemyBase
class_name SkeletonMage

@export var custom_hp: int = 100
@export var custom_damage: int = 10
@export var custom_shoot_interval: float = 3.0
@export_range(0.0, 1.0, 0.01) var custom_block_chance: float = 0.5
@export var custom_block_interval: float = 0.3

func _apply_custom_stats() -> void:
	max_hp = custom_hp
	HP = custom_hp
	projectile_damage = custom_damage
	shoot_interval = custom_shoot_interval
	block_chance = custom_block_chance
	if custom_block_interval > 0.0:
		block_interval = custom_block_interval

# Si más adelante querés volver a su “ráfaga”, la activamos acá
# func _before_shoot() -> void: pass
# func _after_shoot(_proj: Node2D) -> void: pass
