extends Node2D
class_name Mage2

signal hp_changed(current: int, max_value: int)
signal died                                   # ← NUEVA

@onready var body: CharacterBody2D    = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var apoint: Marker2D         = $CharacterBody2D/APoint
@onready var shoot_timer: Timer       = $ShootTimer

@export var projectile_scene: PackedScene
@export var shoot_interval: float = 7.0
@export var cast_delay: float = 0.3

@export var max_hp: int = 100
@export var HP: int = 100

var is_dead := false

func _ready() -> void:
	add_to_group("enemy")
	if body: body.collision_layer = 2
	if sprite:
		sprite.play("idle")
		sprite.animation_finished.connect(_on_anim_finished)

	HP = clamp(HP, 0, max_hp)
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

func attack_and_cast() -> void:
	if is_dead or projectile_scene == null: return
	if sprite: sprite.play("attack")
	await get_tree().create_timer(cast_delay).timeout
	var p := projectile_scene.instantiate() as Area2D
	if p:
		p.global_position = apoint.global_position if is_instance_valid(apoint) else global_position
		get_parent().add_child(p)

func take_dmg(amount: int = 1) -> void:
	if is_dead: return
	HP = max(HP - amount, 0)
	hp_changed.emit(HP, max_hp)
	if HP <= 0:
		_die()
	else:
		if sprite:
			sprite.play("hurt")

func _die() -> void:
	if is_dead: return
	is_dead = true
	if shoot_timer: shoot_timer.stop()
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	died.emit()

func _on_anim_finished() -> void:
	if is_dead: return
	if sprite and (sprite.animation == "attack" or sprite.animation == "hurt"):
		sprite.play("idle")
