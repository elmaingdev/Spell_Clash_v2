extends Node2D
class_name Battle

@onready var player: Mage1 = %Mage_1
@onready var enemy: Mage2 = %Mage_2
@onready var typing: TypingPanel = %TypingPanel
@onready var projectile_container: Node2D = %ProjectileContainer

func _ready() -> void:
	# Opcional: asegúrate de que los proyectiles queden por delante del escenario
	projectile_container.z_index = 20

	if typing and not typing.spell_success.is_connected(_on_spell_success):
		typing.spell_success.connect(_on_spell_success)

func _on_spell_success(_phrase: String) -> void:
	if player and player.has_method("attack"):
		player.attack()
	_spawn_projectile_from_player()

func _spawn_projectile_from_player() -> void:
	if player == null or enemy == null:
		return

	var ps: PackedScene = player.projectile_scene
	if ps == null:
		ps = preload("res://scenes/Projectile_1.tscn")

	var p: Projectile1 = ps.instantiate() as Projectile1

	# 1) Usa el SPoint del mago
	var start_pos: Vector2 = player.get_muzzle_global()
	var dir: Vector2 = (enemy.global_position - start_pos).normalized()

	# 2) Configura ANTES de agregar al árbol (para que _ready del proyectil lea bien su pos)
	p.global_position = start_pos
	p.direction = dir
	p.team = "player"

	# 3) Agrega al contenedor (delante del escenario)
	projectile_container.add_child(p)

	# 4) Orientación de sprite (opcional)
	var spr: AnimatedSprite2D = p.get_node_or_null("AnimatedSprite2D")
	if spr:
		spr.flip_h = dir.x < 0

	# 5) Conecta impacto
	if not p.hit_enemy.is_connected(_on_projectile_hit_enemy):
		p.hit_enemy.connect(_on_projectile_hit_enemy)

	# DEBUG (temporal): confirma spawn
	print("Projectile spawned at: ", start_pos, " dir: ", dir)

func _on_projectile_hit_enemy(target: Node) -> void:
	if target and target.has_method("hurt"):
		target.hurt()
