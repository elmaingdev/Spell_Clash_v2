# res://scripts/chars/TheWitch.gd
extends EnemyBase

@export_range(0.0, 1.0, 0.01) var block_chance: float = 0.25
@export var block_ms: int = 700

var _blocking: bool = false

# Si está bloqueando, ignora daño
func take_dmg(amount: int = 1) -> void:
	if _blocking:
		return
	super.take_dmg(amount)

# ⚠️ Este es el que hay que sobreescribir (no _do_attack)
func attack_and_cast() -> void:
	if is_dead:
		return

	# A veces bloquea en lugar de atacar
	if randf() < block_chance:
		await _block_now()
		return

	# Si no bloquea, hace el ataque estándar del EnemyBase
	await super.attack_and_cast()

func _block_now() -> void:
	_blocking = true
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
		sprite.play("block")
	await get_tree().create_timer(float(block_ms) / 1000.0).timeout
	_blocking = false
	# Vuelve a idle para no “quedarse” en pose de bloqueo
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")
