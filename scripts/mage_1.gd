extends Node2D
class_name Mage1

signal hp_changed(current: int, max_value: int)
signal died

@onready var body: CharacterBody2D    = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var spoint: Marker2D         = $CharacterBody2D/SPoint

@export var projectile_scene: PackedScene
@export var shoot_delay: float = 0.2
@export_node_path("Control") var typing_panel_path

# Daño según rating (ataque del jugador)
@export var dmg: int = 10
var _last_rating: String = "Good"

# Vida del jugador
@export var max_hp: int = 100
@export var HP: int = 100

var typing_panel: TypingPanel
var is_dead := false

func _ready() -> void:
	if body: body.collision_layer = 3
	if sprite:
		sprite.play("idle")
		sprite.animation_finished.connect(_on_anim_finished)

	# Señales del TypingPanel
	if String(typing_panel_path) != "":
		var n := get_node_or_null(typing_panel_path)
		if n is TypingPanel:
			typing_panel = n
	if typing_panel:
		if not typing_panel.score_ready.is_connected(_on_TypingPanel_score_ready):
			typing_panel.score_ready.connect(_on_TypingPanel_score_ready)
		if not typing_panel.spell_success.is_connected(_on_TypingPanel_spell_success):
			typing_panel.spell_success.connect(_on_TypingPanel_spell_success)

	# Estado inicial de HP hacia la UI (deferido por orden de carga)
	HP = clamp(HP, 0, max_hp)
	call_deferred("_emit_initial_hp")

func _emit_initial_hp() -> void:
	hp_changed.emit(HP, max_hp)

func _physics_process(_delta: float) -> void:
	if body:
		body.velocity = Vector2.ZERO
		body.move_and_slide()

# ---- rating -> daño propio ----
func projectile_dmg(rating: String) -> int:
	match rating:
		"Perfect": return 20
		"Nice":    return 15
		"Good":    return 10
		_:         return 0  # Fail

func _on_TypingPanel_score_ready(rating: String) -> void:
	_last_rating = rating
	dmg = projectile_dmg(rating)

func _on_TypingPanel_spell_success(_phrase: String) -> void:
	shoot()

func shoot() -> void:
	if is_dead: return
	if sprite: sprite.play("attack")
	await get_tree().create_timer(shoot_delay).timeout
	_spawn_projectile()

func _spawn_projectile() -> void:
	if dmg <= 0:
		return
	if projectile_scene == null:
		push_warning("Mage1: projectile_scene no asignado.")
		return
	var p := projectile_scene.instantiate() as Projectile1
	if p == null:
		push_warning("Mage1: projectile no es Projectile1.")
		return
	var start_pos: Vector2 = spoint.global_position if is_instance_valid(spoint) else global_position
	p.global_position = start_pos
	p.damage = dmg
	get_parent().add_child(p)

# ---- daño recibido del enemigo ----
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
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		if sprite: sprite.stop()
	died.emit()

func _on_anim_finished() -> void:
	if is_dead: return
	if sprite and (sprite.animation == "attack" or sprite.animation == "hurt"):
		sprite.play("idle")
