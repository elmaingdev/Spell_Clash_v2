extends Area2D
class_name Projectile2

@export var speed: float = 300.0
@export var max_distance: float = 4000.0
@export var damage: int = 15

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _start: Vector2 = Vector2.ZERO
var _alive: bool = true
var _initialized: bool = false

func _ready() -> void:
	z_index = 20
	# Capas/máscaras para NO chocar con Projectile_1 y SÍ chocar con el jugador
	collision_layer = 4      # proyectil del enemigo
	collision_mask  = 3      # golpea al jugador (Mage_1 en layer 3)
	monitoring = true

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	# Fija el punto de inicio en el primer frame de física (posición ya válida)
	if not _initialized:
		_start = global_position
		_initialized = true

	# Viaje recto hacia la izquierda
	global_position.x -= speed * delta

	# Vida útil por distancia
	if global_position.distance_to(_start) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not _alive:
		return
	var actor := body.get_parent() if body and body.get_parent() else body
	if actor and actor.has_method("take_dmg"):
		actor.take_dmg(damage)  # ← aplica 100
	_alive = false
	queue_free()
