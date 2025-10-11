# res://scripts/chars/EnemyBase.gd
extends Node2D
class_name EnemyBase

signal hp_changed(current: int, max_value: int)
signal died

@onready var body: CharacterBody2D    = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var apoint: Marker2D         = $CharacterBody2D/APoint
@onready var shoot_timer: Timer       = $ShootTimer

# --- SFX ---
@onready var sfx_damage: AudioStreamPlayer2D = $Sfx/Damage
@onready var sfx_death:  AudioStreamPlayer2D = $Sfx/Death

const DMG_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/dmg1_sfx.wav"),
	preload("res://assets/sfx/dmg2_sfx.wav"),
]

@export var debug_log_stats: bool = true
# -------- Config base (EDITABLES) --------
@export var max_hp: int = 100
@export var HP: int = 100

@export var projectile_scene: PackedScene
@export var projectile_pool: ProjectilePool

@export var projectile_damage: int = 10
@export var shoot_interval: float = 5.0
@export var cast_delay: float = 0.3

# Bloqueo (0 → nunca, 1 → siempre)
@export_range(0.0, 1.0, 0.01) var block_chance: float = 0
@export var block_interval: float = 0.3  # segundos tras el spawn del proyectil del jugador

# MODO CUSTOM ENEMIGOS
@export var custom_enemy: bool = true 

var is_dead: bool = false
var _fire_sfx_idx: int = 0
var _rng := RandomNumberGenerator.new()

# Una sola tirada por proyectil
var _block_pending: Dictionary = {}  # proj_id (int) -> true

func _ready() -> void:
	add_to_group("enemy")
	_rng.randomize()

	if body:
		body.collision_layer = 2

	if sprite:
		sprite.play("idle")
		if not sprite.animation_finished.is_connected(_on_anim_finished):
			sprite.animation_finished.connect(_on_anim_finished)

	# Delega en el hijo la aplicación de stats custom si corresponde
	_apply_custom_if_enabled()

	HP = clampi(HP, 0, max_hp)
	call_deferred("_emit_initial_hp")

	if shoot_timer:
		shoot_timer.wait_time = shoot_interval
		shoot_timer.one_shot = false
		shoot_timer.autostart = true
		if not shoot_timer.timeout.is_connected(_on_shoot_timer_timeout):
			shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _apply_custom_if_enabled() -> void:
	if custom_enemy and has_method("_apply_custom_stats"):
		call("_apply_custom_stats")
		if shoot_timer:
			shoot_timer.wait_time = shoot_interval

	# 🔎 Depuración: ver qué quedó realmente
	if debug_log_stats:
		_debug_dump_stats()

func _emit_initial_hp() -> void:
	hp_changed.emit(HP, max_hp)

func _on_shoot_timer_timeout() -> void:
	# Permite que los derivados bloqueen el disparo normal si están en modo especial
	if has_method("_should_fire_on_timer"):
		if not call("_should_fire_on_timer"):
			return
	attack_and_cast()

# ---------- Ataque base ----------
func attack_and_cast() -> void:
	if is_dead:
		return

	_before_shoot()

	if sprite:
		sprite.play("attack")
	await get_tree().create_timer(cast_delay).timeout

	var proj := _create_projectile()
	if proj == null:
		return

	var start_pos: Vector2 = (apoint.global_position if is_instance_valid(apoint) else global_position)
	proj.global_position = start_pos

	# SFX index (si el proyectil lo soporta)
	if "sfx_index" in proj:
		proj.sfx_index = _fire_sfx_idx
		_fire_sfx_idx = (_fire_sfx_idx + 1) % 3

	# Daño si el proyectil lo soporta
	if proj.has_method("set_damage"):
		proj.call("set_damage", projectile_damage)
	elif "damage" in proj:
		proj.set("damage", projectile_damage)

	# (Re)activar
	if proj.has_method("reactivate"):
		proj.reactivate()

	_after_shoot(proj)

func _create_projectile() -> Node2D:
	var p: Node2D = null
	if projectile_pool:
		p = projectile_pool.acquire() as Node2D
	else:
		if projectile_scene == null:
			return null
		p = projectile_scene.instantiate() as Node2D
		if p == null:
			return null
		get_parent().add_child(p)
	return p

# ---------- Daño ----------
func take_dmg(amount: int = 1) -> void:
	if is_dead:
		return
	HP = maxi(0, HP - amount)
	hp_changed.emit(HP, max_hp)
	if HP <= 0:
		_play_death_sfx()
		_die()
	else:
		_play_damage_sfx()
		if sprite:
			sprite.play("hurt")

func _die() -> void:
	if is_dead:
		return
	is_dead = true

	# Detén su cadencia
	if shoot_timer:
		shoot_timer.stop()

	# Purga inmediata de proyectiles (enemigos y jugador)
	_purge_all_projectiles()

	# Anim de muerte (si existe) y luego señal
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished

	died.emit()

func _on_anim_finished() -> void:
	if is_dead:
		return
	if sprite and (sprite.animation == "attack" or sprite.animation == "hurt" or sprite.animation == "block"):
		sprite.play("idle")

# ====== SFX ======
func _play_damage_sfx() -> void:
	if sfx_damage and DMG_STREAMS.size() > 0:
		sfx_damage.stream = DMG_STREAMS[randi() % DMG_STREAMS.size()]
		sfx_damage.pitch_scale = 1.0 + randf_range(-0.02, 0.02)
		sfx_damage.play()

func _play_death_sfx() -> void:
	if sfx_death:
		sfx_death.play()

# ====== Hooks de personalización (override en derivados) ======
func _before_shoot() -> void:
	pass

func _after_shoot(_proj: Node2D) -> void:
	pass

# ====== Bloqueo centralizado ======
# Mage1 debe llamar: get_tree().call_group("enemy", "on_player_projectile_spawned", projectile)
func on_player_projectile_spawned(proj: Node) -> void:
	if is_dead or proj == null or not is_instance_valid(proj):
		return
	if block_chance <= 0.0:
		return
	var id := proj.get_instance_id()
	if _block_pending.has(id):
		return
	_block_pending[id] = true
	# Programar chequeo después de block_interval
	call_deferred("_block_check_after_delay", proj, id)

func _block_check_after_delay(proj: Node, proj_id: int) -> void:
	await get_tree().create_timer(max(0.0, block_interval)).timeout
	_block_pending.erase(proj_id)

	if is_dead or block_chance <= 0.0:
		return
	if proj == null or not is_instance_valid(proj):
		return

	if _rng.randf() < block_chance:
		await _play_block_anim()
		_block_projectile(proj)

func _play_block_anim() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
		sprite.play("block")
		# Pequeña espera por si la anim no tiene fin declarado
		await get_tree().create_timer(0.18).timeout
		if not is_dead and sprite.animation == "block" and sprite.sprite_frames.has_animation("idle"):
			sprite.play("idle")

func _block_projectile(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	# Preferencia: API del proyectil
	if p.has_method("vanish_blocked"):
		p.call_deferred("vanish_blocked")
		return
	# Fallbacks
	if p.has_method("set_deferred"):
		p.set_deferred("monitoring", false)
	if "collision_layer" in p: p.set("collision_layer", 0)
	if "collision_mask"  in p: p.set("collision_mask", 0)
	if p.has_method("queue_free"):
		p.queue_free()

func _debug_dump_stats() -> void:
	print("Enemy <", name, "> stats → HP:", max_hp, 
		" DMG:", projectile_damage, 
		" ShootInt:", str("%.2f" % shoot_interval), 
		" Block:", str("%.2f" % block_chance), 
		" BlockInt:", str("%.2f" % block_interval),
		" custom_enemy:", custom_enemy)

# Elimina/neutraliza todos los proyectiles activos de ambos bandos con anim si es posible.
func _purge_all_projectiles() -> void:
	var to_clean: Array = []
	# Recoge ambos grupos
	to_clean.append_array(get_tree().get_nodes_in_group("enemy_projectile"))
	to_clean.append_array(get_tree().get_nodes_in_group("player_projectile"))

	for n in to_clean:
		if n == null or not is_instance_valid(n):
			continue

		# Preferimos APIs “amables” que ya animan y reciclan
		if n.has_method("neutralize_now"):        # p.ej. Projectile2 (enemigo)
			n.call_deferred("neutralize_now")
			continue
		if n.has_method("vanish_blocked"):        # p.ej. Projectile1 (jugador)
			n.call_deferred("vanish_blocked")
			continue
		if n.has_method("disable"):               # compat: algunos usan 'disable'
			n.call_deferred("disable")
			continue

		# Fallback seguro
		if "monitoring" in n: n.set_deferred("monitoring", false)
		if "collision_layer" in n: n.set("collision_layer", 0)
		if "collision_mask"  in n: n.set("collision_mask", 0)
		if n.has_method("queue_free"):
			n.call_deferred("queue_free")
