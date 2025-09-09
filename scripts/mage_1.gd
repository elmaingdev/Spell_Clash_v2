extends Node2D
class_name Mage1

@onready var body: CharacterBody2D    = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var spoint: Marker2D         = $CharacterBody2D/SPoint

@export var projectile_scene: PackedScene                 # asigna Projectile_1.tscn
@export var shoot_delay: float = 0.2
@export_node_path("Control") var typing_panel_path        # arrastra UI/TypingPanel

var typing_panel: TypingPanel
var is_dead := false

func _ready() -> void:
	# Capa de colisión del jugador (para proyectil del enemigo)
	if body:
		body.collision_layer = 3
	if sprite:
		sprite.play("idle")
		sprite.animation_finished.connect(_on_anim_finished)

	# Conectar TypingPanel por script
	if String(typing_panel_path) != "":
		var n := get_node_or_null(typing_panel_path)
		if n is TypingPanel:
			typing_panel = n
	if typing_panel and not typing_panel.spell_success.is_connected(_on_TypingPanel_spell_success):
		typing_panel.spell_success.connect(_on_TypingPanel_spell_success)

func _physics_process(_delta: float) -> void:
	if body:
		body.velocity = Vector2.ZERO
		body.move_and_slide()

func _on_TypingPanel_spell_success(_phrase: String) -> void:
	shoot()

func shoot() -> void:
	if is_dead:
		return
	if sprite:
		sprite.play("attack")
	await get_tree().create_timer(shoot_delay).timeout
	_spawn_projectile()

func _spawn_projectile() -> void:
	if projectile_scene == null:
		push_warning("Mage1: projectile_scene no asignado.")
		return
	var p := projectile_scene.instantiate() as Area2D
	if p == null:
		push_warning("Mage1: projectile_scene no es Area2D.")
		return
	var start_pos: Vector2 = spoint.global_position if is_instance_valid(spoint) else global_position
	p.global_position = start_pos
	get_parent().add_child(p)

func take_dmg(_amount: int = 1) -> void:
	if not is_dead and sprite:
		sprite.play("hurt")

func _on_anim_finished() -> void:
	if not is_dead and sprite and (sprite.animation == "attack" or sprite.animation == "hurt"):
		sprite.play("idle")
