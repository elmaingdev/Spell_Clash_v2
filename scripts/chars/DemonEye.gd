# res://scripts/chars/DemonEye.gd
extends EnemyBase

@export var volley_count: int = 5
@export var volley_spacing: float = 0.10   # seg. entre balas de la ráfaga
@export var proj_speed: float = 110.0
@export var proj_damage: int = 8

func attack_and_cast() -> void:
	if is_dead:
		return

	# Opcional: hook antes de atacar (por si personalizas VFX/tells)
	_before_shoot()

	# Anim de ataque (si existe)
	if sprite:
		sprite.play("attack")

	# Pequeña “carga” antes del primer disparo
	await get_tree().create_timer(cast_delay).timeout

	# Dispara en ráfaga
	for i in volley_count:
		if is_dead:
			break

		var p := _create_projectile()
		if p:
			# Posición de salida
			var start_pos: Vector2 = (apoint.global_position if is_instance_valid(apoint) else global_position)
			p.global_position = start_pos

			# Ajustes dinámicos sin warnings (usa set con guardas)
			if "speed" in p:
				(p as Object).set("speed", proj_speed)
			if "damage" in p:
				(p as Object).set("damage", proj_damage)
			if "sfx_index" in p:
				(p as Object).set("sfx_index", _fire_sfx_idx)
				_fire_sfx_idx = (_fire_sfx_idx + 1) % 3

			# Reactiva si viene del pool
			if p.has_method("reactivate"):
				p.reactivate()

			# Hook post-disparo (por si quieres patrones extra)
			_after_shoot(p)

		# Espaciado entre balas de la ráfaga
		if i < volley_count - 1:
			await get_tree().create_timer(volley_spacing).timeout
