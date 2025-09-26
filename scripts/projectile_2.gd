extends Area2D
class_name Projectile2

@export var speed: float = 100.0
@export var max_distance: float = 4000.0
@export var damage: int = 5

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# --- SFX ---
@export var sfx_index: int = -1
@onready var sfx_fire: AudioStreamPlayer2D = $Sfx/Fire
const FIRE_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/fire_1.wav"),
	preload("res://assets/sfx/fire_2.wav"),
	preload("res://assets/sfx/fire_3.wav"),
]

var _start: Vector2 = Vector2.ZERO
var _alive: bool = true
var _initialized: bool = false
var _blocked: bool = false

func _ready() -> void:
	z_index = 20
	collision_layer = 4
	collision_mask  = 3
	monitoring = true

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# IMPORTANTE: no añadir al grupo ni reproducir SFX en _ready()
	# (los pools precalientan instancias aquí).

func _physics_process(delta: float) -> void:
	if not _alive:
		return

	if not _initialized:
		_start = global_position
		_initialized = true

	if _blocked:
		return

	global_position.x -= speed * delta

	if global_position.distance_to(_start) > max_distance:
		_recycle()

func _on_body_entered(body: Node) -> void:
	if not _alive or _blocked:
		return
	var actor := body.get_parent() if body and body.get_parent() else body
	if actor and actor.has_method("take_dmg"):
		actor.take_dmg(damage)
	_alive = false
	# Evita cambios durante la señal:
	call_deferred("_recycle")

# ---------- Pool / Estado ----------
func reactivate() -> void:
	_alive = true
	_blocked = false
	_initialized = false
	set_deferred("monitoring", true)
	collision_layer = 4
	collision_mask  = 3
	if not is_in_group("enemy_projectile"):
		call_deferred("add_to_group", "enemy_projectile")  # ← alta diferida
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")
	_play_fire_sfx()

func _recycle() -> void:
	# Usar una implementación diferida para evitar el error de “in/out signal”
	call_deferred("_recycle_impl")

func _recycle_impl() -> void:
	set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask  = 0
	if is_in_group("enemy_projectile"):
		remove_from_group("enemy_projectile")

	var pool := get_parent() as ProjectilePool
	if pool:
		pool.recycle_self(self)
	else:
		queue_free()

# ---------- Bloqueo por PROTECTION ----------
func disable() -> void:
	if _blocked:
		return
	_blocked = true
	_alive = false

	set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask  = 0
	if is_in_group("enemy_projectile"):
		remove_from_group("enemy_projectile")

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("disabled"):
		anim.play("disabled")
		await anim.animation_finished
	_recycle()

# ====== SFX ======
func _play_fire_sfx() -> void:
	if not sfx_fire or FIRE_STREAMS.is_empty():
		return
	var idx: int = sfx_index
	if idx < 0 or idx >= FIRE_STREAMS.size():
		idx = 0
	sfx_fire.stream = FIRE_STREAMS[idx]
	sfx_fire.pitch_scale = 1.0 + randf_range(-0.015, 0.015)
	sfx_fire.play()
