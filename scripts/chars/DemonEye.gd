# res://scripts/chars/DemonEye.gd
extends EnemyBase

@export var volley_count: int = 5
@export var volley_spacing: float = 0.10
@export var proj_speed: float = 110.0
@export var proj_damage: int = 8

func attack_and_cast() -> void:
	# Sin custom → base
	if not activate_custom:
		await super.attack_and_cast()
		return

	if is_dead:
		return

	_before_shoot()
	if sprite:
		sprite.play("attack")
	await get_tree().create_timer(cast_delay).timeout

	for i in volley_count:
		if is_dead:
			break
		var p := _create_projectile()
		if p:
			var start_pos: Vector2 = (apoint.global_position if is_instance_valid(apoint) else global_position)
			p.global_position = start_pos
			if "speed" in p:  (p as Object).set("speed", proj_speed)
			if "damage" in p: (p as Object).set("damage", proj_damage)
			if "sfx_index" in p:
				(p as Object).set("sfx_index", _fire_sfx_idx)
				_fire_sfx_idx = (_fire_sfx_idx + 1) % 3
			if p.has_method("reactivate"):
				p.reactivate()
			_after_shoot(p)
		if i < volley_count - 1:
			await get_tree().create_timer(volley_spacing).timeout
