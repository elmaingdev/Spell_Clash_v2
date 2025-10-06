# res://scripts/chars/TheWitch.gd
extends EnemyBase

@export_range(0.0, 1.0, 0.01) var block_chance: float = 0.25
@export var block_ms: int = 700

var _blocking: bool = false

func take_dmg(amount: int = 1) -> void:
	if _blocking:
		return
	super.take_dmg(amount)

func attack_and_cast() -> void:
	# Sin custom → base
	if not activate_custom:
		await super.attack_and_cast()
		return

	if is_dead:
		return

	if randf() < block_chance:
		await _block_now()
		return

	await super.attack_and_cast()

func _block_now() -> void:
	_blocking = true
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
		sprite.play("block")
	await get_tree().create_timer(float(block_ms) / 1000.0).timeout
	_blocking = false
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
