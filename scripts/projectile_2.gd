extends Area2D
class_name Projectile2

@export var speed: float = 300.0
@export var max_distance: float = 4000.0
@export var damage: int = 15

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _start: Vector2 = Vector2.ZERO
var _alive: bool = true
var _initialized: bool = false
var _blocked: bool = false  # ← NUEVO: estado bloqueado

func _ready() -> void:
	z_index = 20
	collision_layer = 4      # proyectil del enemigo
	collision_mask  = 3      # golpea al jugador (Mage_1 en layer 3)
	monitoring = true

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	add_to_group("enemy_projectile")

func _physics_process(delta: float) -> void:
	if not _alive:
		return

	if not _initialized:
		_start = global_position
		_initialized = true

	# Si fue bloqueado, no avanza (queda “congelado” durante la animación)
	if _blocked:
		return

	# Viaje recto hacia la izquierda
	global_position.x -= speed * delta

	# Vida útil por distancia
	if global_position.distance_to(_start) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not _alive or _blocked:
		return
	var actor := body.get_parent() if body and body.get_parent() else body
	if actor and actor.has_method("take_dmg"):
		actor.take_dmg(damage)
	_alive = false
	queue_free()

# ---------- NUEVO: API de bloqueo ----------
func disable() -> void:
	# Llamada cuando el jugador bloquea con DirectionsPanel
	if _blocked: return
	_blocked = true
	_alive = false

	# Evita más colisiones y saca del grupo para que el HUD pase a "Danger Free" al instante
	set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask  = 0
	if is_in_group("enemy_projectile"):
		remove_from_group("enemy_projectile")

	# Reproduce animación "disabled" si existe, luego se destruye
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("disabled"):
		anim.play("disabled")
		await anim.animation_finished
	queue_free()
