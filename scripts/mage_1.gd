extends Node2D
class_name Mage1

signal hp_changed(current: int, max_value: int)
signal died
signal got_hit

@onready var body: CharacterBody2D    = $CharacterBody2D
@onready var sprite: AnimatedSprite2D = $CharacterBody2D/AnimatedSprite2D
@onready var spoint: Marker2D         = $CharacterBody2D/SPoint

# SFX locales
@onready var sfx_damage: AudioStreamPlayer2D = $Sfx/Damage
@onready var sfx_block:  AudioStreamPlayer2D = $Sfx/Block
@onready var sfx_death:  AudioStreamPlayer2D = $Sfx/Death

const DMG_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/dmg1_sfx.wav"),
	preload("res://assets/sfx/dmg2_sfx.wav"),
]

@export var projectile_scene: PackedScene               # fallback si no hay pool
@export var shoot_delay: float = 0.2
@export_node_path("Control") var typing_panel_path: NodePath = NodePath("")

# Pool de proyectiles del jugador
@export var projectile_pool: ProjectilePool

# Triple cast config
@export var burst_count: int = 3
@export var burst_spacing: float = 0.12

# Compat: valor informativo (puede leerlo algún panel)
@export var dmg: int = 10
var _last_rating: String = "Good"

# Vida jugador
@export var max_hp: int = 100
@export var HP: int = 100

var typing_panel: TypingPanel
var charge: ChargeBar = null

var is_dead: bool = false
var _player_spell_sfx_idx: int = 0

# Estados de carga (ChargeBar)
var _burst_pending: bool = false
var _burst_ready: bool = false

# Daño calculado (con combo) para el próximo disparo (se establece en score_ready)
var _pending_shot_damage: int = -1

func _ready() -> void:
	if body:
		body.collision_layer = 3
	if sprite:
		sprite.play("idle")
		sprite.animation_finished.connect(_on_anim_finished)

	_wire_typing_panel()
	_wire_chargebar()

	HP = clampi(HP, 0, max_hp)
	call_deferred("_emit_initial_hp")

func _wire_typing_panel() -> void:
	if not typing_panel_path.is_empty():
		var n: Node = get_node_or_null(typing_panel_path)
		if n is TypingPanel:
			typing_panel = n
	if typing_panel == null:
		var tp: Node = get_tree().root.find_child("TypingPanel", true, false)
		if tp is TypingPanel:
			typing_panel = tp

	if typing_panel:
		if not typing_panel.score_ready.is_connected(_on_TypingPanel_score_ready):
			typing_panel.score_ready.connect(_on_TypingPanel_score_ready)
		if not typing_panel.spell_success.is_connected(_on_TypingPanel_spell_success):
			typing_panel.spell_success.connect(_on_TypingPanel_spell_success)
		if not typing_panel.round_started.is_connected(_on_round_started):
			typing_panel.round_started.connect(_on_round_started)

func _wire_chargebar() -> void:
	var n: Node = get_node_or_null("%Chargebar")
	if n is ChargeBar:
		charge = n as ChargeBar
	if charge == null:
		var found: Node = get_tree().root.find_child("Chargebar", true, false)
		if found is ChargeBar:
			charge = found as ChargeBar

	if charge and not charge.charged.is_connected(_on_charge_full):
		charge.charged.connect(_on_charge_full)
	elif charge == null:
		push_warning("Mage1: no encontré #Chargebar (Unique Name). Marca la ProgressBar en BottomPanel como Unique Name 'Chargebar'.")

func _emit_initial_hp() -> void:
	hp_changed.emit(HP, max_hp)

func _physics_process(_delta: float) -> void:
	if body:
		body.velocity = Vector2.ZERO
		body.move_and_slide()

# ---------- LECTURA DE COMBO ----------
func _get_combo_current() -> int:
	var cc: Node = get_node_or_null("/root/ComboCounter")
	if cc:
		if cc.has_method("get_current"):
			return int(cc.call("get_current"))
		elif "current" in cc:
			return int(cc.current)
	var list: Array = get_tree().get_nodes_in_group("combo_counter")
	if not list.is_empty():
		var node: Node = list[0]
		if node and node.has_method("get_current"):
			return int(node.call("get_current"))
		elif node and "current" in node:
			return int(node.current)
	return 0

# Se emite apenas terminas de teclear la palabra (antes del spell_success)
func _on_TypingPanel_score_ready(rating: String) -> void:
	_last_rating = rating
	dmg = DamageCalculator.base_damage_from_rating(rating)
	_pending_shot_damage = -1
	if dmg > 0:
		var next_combo: int = _get_combo_current() + 1
		_pending_shot_damage = DamageCalculator.final_damage(rating, next_combo)

# Al finalizar el spell (palabra correcta) se dispara
func _on_TypingPanel_spell_success(_phrase: String) -> void:
	var combo_now: int = maxi(1, _get_combo_current())
	var shot_dmg: int = (_pending_shot_damage if _pending_shot_damage >= 0 else DamageCalculator.final_damage(_last_rating, combo_now))

	if _burst_ready and charge and charge.is_full():
		await _shoot_burst(burst_count, burst_spacing, shot_dmg)
		charge.consume_full()
		_burst_ready = false
	else:
		await shoot(shot_dmg)

	_pending_shot_damage = -1

# TypingPanel avisa que empezó un nuevo spell → si la barra sigue 100% y venía “pending”, arma el triple
func _on_round_started() -> void:
	if _burst_pending and charge and charge.is_full():
		_burst_ready = true
		_burst_pending = false

func _on_charge_full() -> void:
	_burst_pending = true

# ---------- Disparo ----------
func shoot(damage_override: int = -1) -> void:
	if is_dead:
		return
	if sprite:
		sprite.play("attack")
	await get_tree().create_timer(shoot_delay).timeout
	_spawn_projectile(damage_override)

func _spawn_projectile(damage_override: int = -1) -> void:
	var use_dmg: int = (damage_override if damage_override >= 0 else dmg)
	if use_dmg <= 0:
		return

	var p: Projectile1 = null
	if projectile_pool:
		p = projectile_pool.acquire() as Projectile1
	else:
		if projectile_scene == null:
			return
		p = projectile_scene.instantiate() as Projectile1
		if p == null:
			return
		get_parent().add_child(p)

	var start_pos: Vector2 = (spoint.global_position if is_instance_valid(spoint) else global_position)
	p.global_position = start_pos

	if p.has_method("set_damage"):
		p.set_damage(use_dmg)
	else:
		p.damage = use_dmg

	p.sfx_index = _player_spell_sfx_idx
	_player_spell_sfx_idx = (_player_spell_sfx_idx + 1) % 3

	# 🔁 IMPORTANTE: aunque no venga del pool, reactivamos (reproduce SFX y resetea estado)
	if p.has_method("reactivate"):
		p.reactivate()

func _shoot_burst(count: int = 3, spacing: float = 0.12, damage_override: int = -1) -> void:
	if is_dead:
		return
	if sprite:
		sprite.play("attack")
	await get_tree().create_timer(shoot_delay).timeout
	for i in count:
		_spawn_projectile(damage_override)
		if i < count - 1:
			await get_tree().create_timer(spacing).timeout

# ---------- Daño recibido ----------
func take_dmg(amount: int = 1) -> void:
	if is_dead:
		return
	HP = maxi(0, HP - amount)
	hp_changed.emit(HP, max_hp)
	got_hit.emit()
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
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	else:
		if sprite:
			sprite.stop()
	died.emit()

func _on_anim_finished() -> void:
	if is_dead:
		return
	if sprite and (sprite.animation == "attack" or sprite.animation == "hurt"):
		sprite.play("idle")

# ====== SFX locales ======
func _play_damage_sfx() -> void:
	if not sfx_damage:
		return
	if DMG_STREAMS.size() > 0:
		sfx_damage.stream = DMG_STREAMS[randi() % DMG_STREAMS.size()]
	sfx_damage.pitch_scale = 1.0 + randf_range(-0.02, 0.02)
	sfx_damage.play()

func _play_block_sfx() -> void:
	if sfx_block:
		sfx_block.play()

func _play_death_sfx() -> void:
	if sfx_death:
		sfx_death.play()

func play_block_sfx() -> void:
	_play_block_sfx()
