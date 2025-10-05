# res://scripts/chars/EnemyBase.gd
extends Node2D
class_name EnemyBase

signal hp_changed(current: int, max_value: int)
signal died

@onready var body: CharacterBody2D    = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var apoint: Marker2D         = $CharacterBody2D/APoint
@onready var shoot_timer: Timer       = $ShootTimer

# --- SFX locales (bus FX) ---
@onready var sfx_damage: AudioStreamPlayer2D = $Sfx/Damage
@onready var sfx_death:  AudioStreamPlayer2D = $Sfx/Death

const DMG_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/dmg1_sfx.wav"),
	preload("res://assets/sfx/dmg2_sfx.wav"),
]

# Disparo
@export var projectile_scene: PackedScene      # fallback si no hay pool
@export var projectile_pool: ProjectilePool    # pool de proyectiles enemigos (opcional)
@export var shoot_interval: float = 7.0
@export var cast_delay: float = 0.3

# Vida
@export var max_hp: int = 40
@export var HP: int = 40

var is_dead: bool = false
var _fire_sfx_idx: int = 0

func _ready() -> void:
	add_to_group("enemy")

	if body:
		body.collision_layer = 2

	if sprite:
		sprite.play("idle")
		if not sprite.animation_finished.is_connected(_on_anim_finished):
			sprite.animation_finished.connect(_on_anim_finished)

	HP = clampi(HP, 0, max_hp)
	call_deferred("_emit_initial_hp")

	if shoot_timer:
		shoot_timer.wait_time = shoot_interval
		shoot_timer.one_shot = false
		shoot_timer.autostart = true
		if not shoot_timer.timeout.is_connected(_on_shoot_timer_timeout):
			shoot_timer.timeout.connect(_on_shoot_timer_timeout)

func _emit_initial_hp() -> void:
	hp_changed.emit(HP, max_hp)

func _on_shoot_timer_timeout() -> void:
	attack_and_cast()

# ---------- Loop de ataque (se puede sobreescribir) ----------
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

	# SFX de disparo secuenciado (si el proyectil lo soporta)
	if "sfx_index" in proj:
		proj.sfx_index = _fire_sfx_idx
		_fire_sfx_idx = (_fire_sfx_idx + 1) % 3

	# Reactivar estados (añade al grupo, activa colisiones y reproduce SFX)
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
	if shoot_timer:
		shoot_timer.stop()
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	died.emit()

func _on_anim_finished() -> void:
	if is_dead:
		return
	if sprite and (sprite.animation == "attack" or sprite.animation == "hurt"):
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

# ====== Hooks de personalización (override en subclases) ======
func _before_shoot() -> void:
	# Ej.: cargar un “tell”, cambiar animación, aplicar estados, etc.
	pass

func _after_shoot(_proj: Node2D) -> void:
	# Ej.: modificar velocidad/daño del proyectil, aplicar patrones, etc.
	pass
