extends Node2D
class_name Mage2

@onready var body: CharacterBody2D    = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var apoint: Marker2D         = $CharacterBody2D/APoint
@onready var shoot_timer: Timer       = $ShootTimer

@export var projectile_scene: PackedScene          # asigna res://scenes/Projectile_2.tscn
@export var shoot_interval: float = 2.0            # cada 7 s
@export var cast_delay: float = 0.3                # espera antes de crear la bala

var is_dead := false

func _ready() -> void:
	add_to_group("enemy")                 # para que Projectile_1 lo identifique
	if body:
		body.collision_layer = 2          # capa “enemigo” para colisiones
	if sprite:
		sprite.play("idle")
		sprite.animation_finished.connect(_on_anim_finished)

	# Timer: se reinicia solo (one_shot=false + autostart=true)
	if shoot_timer:
		shoot_timer.wait_time = shoot_interval
		shoot_timer.one_shot = false
		shoot_timer.autostart = true
		if not shoot_timer.timeout.is_connected(_on_shoot_timer_timeout):
			shoot_timer.timeout.connect(_on_shoot_timer_timeout)
	else:
		push_warning("Mage2: no se encontró ShootTimer como hijo directo de Mage_2.")

func _physics_process(_delta: float) -> void:
	if body:
		body.velocity = Vector2.ZERO
		body.move_and_slide()

func _on_shoot_timer_timeout() -> void:
	attack_and_cast()

func attack_and_cast() -> void:
	if is_dead or projectile_scene == null:
		return
	# Animación de ataque
	if sprite:
		sprite.play("attack")
	# Espera 0.3 s y dispara
	await get_tree().create_timer(cast_delay).timeout
	_spawn_projectile()

func _spawn_projectile() -> void:
	if projectile_scene == null:
		return
	var p := projectile_scene.instantiate() as Area2D
	if p == null:
		return
	var start_pos: Vector2 = apoint.global_position if is_instance_valid(apoint) else global_position
	p.global_position = start_pos
	# cuelga la bala en el mismo padre (Battle)
	get_parent().add_child(p)

func take_dmg(_amount: int = 1) -> void:
	if not is_dead and sprite:
		sprite.play("hurt")

func _on_anim_finished() -> void:
	# Volver a idle tras "attack" o "hurt"
	if not is_dead and sprite and (sprite.animation == "attack" or sprite.animation == "hurt"):
		sprite.play("idle")
