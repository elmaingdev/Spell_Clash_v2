# res://scripts/chars/AdeptEnemy.gd
extends EnemyBase
class_name AdeptEnemy

@export var default_max_hp: int = 40
@export var default_hp: int = 40
@export var default_shoot_interval: float = 7.0
@export var default_cast_delay: float = 0.3

func _ready() -> void:
	# Aplica valores por defecto SOLO si no fueron configurados por Inspector
	if max_hp <= 0:
		max_hp = default_max_hp
	if HP <= 0:
		HP = default_hp
	if shoot_interval <= 0.0:
		shoot_interval = default_shoot_interval
	if cast_delay <= 0.0:
		cast_delay = default_cast_delay

	super._ready()
