# res://scripts/chars/mage_1.gd
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
const BLOCK_STREAM: AudioStream = preload("res://assets/sfx/block_sfx.wav")

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

# ---- Daño por combo (propuesta) ----
const BASE_GOOD: int = 10
const BASE_NICE: int = 16
const BASE_PERFECT: int = 24
const COMBO_SCALE: float = 0.22     # +22% por stack
const COMBO_CAP: float = 3.0        # tope x3.0

# Delay para sync de anim de bloqueo con la desaparición del proyectil enemigo
@export var block_anim_delay: float = 0.2

var typing_panel: TypingPanel
var charge: ChargeBar = null

var is_dead: bool = false
var _player_spell_sfx_idx: int = 0

# Estados de carga (ChargeBar)
var _burst_pending: bool = false
var _burst_ready: bool = false

# Daño calculado (con combo) para el próximo disparo (se establece en score_ready)
var _pending_shot_damage: int = -1

var defend_panel: DirectionsPanel = null

func _ready() -> void:
	if body:
		body.collision_layer = 3
	if sprite:
		sprite.play("idle")
		sprite.animation_finished.connect(_on_anim_finished)

	# Asegura el stream/bus/volumen del sfx de bloqueo
	if sfx_block:
		if sfx_block.stream == null:
			sfx_block.stream = BLOCK_STREAM
		var sfx_bus_idx: int = AudioServer.get_bus_index("SFX")
		if sfx_bus_idx >= 0:
			sfx_block.bus = "SFX"
		if sfx_block.volume_db < -40.0:
			sfx_block.volume_db = 0.0

	_wire_typing_panel()
	_wire_chargebar()
	_wire_defend_panel()

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
	# 1) Unique Name %Chargebar
	var n1: Node = get_node_or_null("%Chargebar")
	if n1 is ChargeBar:
		charge = n1 as ChargeBar

	# 2) Búsqueda por clase en todo el árbol (UI nueva)
	if charge == null:
		var found: Array[Node] = get_tree().root.find_children("", "ChargeBar", true, false)
		if found.size() > 0 and found[0] is ChargeBar:
			charge = found[0] as ChargeBar

	# 3) Fallback por nombre
	if charge == null:
		var any: Node = get_tree().root.find_child("ChargeBar", true, false)
		if any is ChargeBar:
			charge = any as ChargeBar

	# Conexión de señal
	if charge and not charge.charged.is_connected(_on_charge_full):
		charge.charged.connect(_on_charge_full)
	elif charge == null:
		push_warning("Mage1: no se encontró una ChargeBar en la UI (ni %Chargebar, ni por clase/nombre).")

func _wire_defend_panel() -> void:
	var n: Node = get_node_or_null("%DirectionsPanel")
	if n is DirectionsPanel:
		defend_panel = n
	if defend_panel == null:
		var found2: Node = get_tree().root.find_child("DirectionsPanel", true, false)
		if found2 is DirectionsPanel:
			defend_panel = found2
	if defend_panel and not defend_panel.block_success.is_connected(_on_block_from_defend):
		defend_panel.block_success.connect(_on_block_from_defend)

func _on_block_from_defend() -> void:
	# Sonido inmediato de bloqueo
	_play_block_sfx()
	# Pequeño delay para sincronizar con la desaparición del proyectil enemigo
	await get_tree().create_timer(max(0.0, block_anim_delay)).timeout
	play_block_anim()

func play_block_anim() -> void:
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("block"):
		sprite.play("block")

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

# ---------- Cálculo de daño (base + combo) ----------
func _base_damage_from_rating(rating: String) -> int:
	match rating:
		"Perfect": return BASE_PERFECT
		"Nice":    return BASE_NICE
		"Good":    return BASE_GOOD
		_:         return 0

func _final_damage(rating: String, combo_count: int) -> int:
	var base: int = _base_damage_from_rating(rating)
	if base <= 0:
		return 0
	var stacks: int = max(0, combo_count - 1)
	var mul: float = 1.0 + COMBO_SCALE * float(stacks)
	if mul > COMBO_CAP:
		mul = COMBO_CAP
	return int(round(float(base) * mul))

# Se emite apenas terminas de teclear la palabra (antes del spell_success)
func _on_TypingPanel_score_ready(rating: String) -> void:
	_last_rating = rating
	dmg = _base_damage_from_rating(rating)
	_pending_shot_damage = -1
	if dmg > 0:
		var next_combo: int = _get_combo_current() + 1
		_pending_shot_damage = _final_damage(rating, next_combo)

# Al finalizar el spell (palabra correcta) se dispara
func _on_TypingPanel_spell_success(_phrase: String) -> void:
	var combo_now: int = maxi(1, _get_combo_current())
	var shot_dmg: int = (_pending_shot_damage if _pending_shot_damage >= 0 else _final_damage(_last_rating, combo_now))

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

	# Reactiva estado y SFX (también fija launch_msec y añade al grupo 'player_projectile')
	if p.has_method("reactivate"):
		p.reactivate()

	# Notificar a todos los enemigos para el sistema de bloqueos temporizados
	get_tree().call_group("enemy", "on_player_projectile_spawned", p)

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
	if sprite and (sprite.animation == "attack" or sprite.animation == "hurt" or sprite.animation == "block"):
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
	# Intenta con el nodo dedicado; si falta, crea un one-shot
	if sfx_block:
		if sfx_block.stream == null:
			sfx_block.stream = BLOCK_STREAM
		# re-dispara aunque estuviera sonando
		if sfx_block.playing:
			sfx_block.stop()
		sfx_block.pitch_scale = 1.0 + randf_range(-0.02, 0.02)
		# asegura bus/volumen
		var sfx_bus_idx: int = AudioServer.get_bus_index("SFX")
		if sfx_bus_idx >= 0:
			sfx_block.bus = "SFX"
		if sfx_block.volume_db < -40.0:
			sfx_block.volume_db = 0.0
		sfx_block.play()
	else:
		var one: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		one.stream = BLOCK_STREAM
		one.pitch_scale = 1.0 + randf_range(-0.02, 0.02)
		var sfx_bus_idx2: int = AudioServer.get_bus_index("SFX")
		if sfx_bus_idx2 >= 0:
			one.bus = "SFX"
		one.volume_db = 0.0
		add_child(one)
		one.finished.connect(func(): one.queue_free())
		one.play()

func _play_death_sfx() -> void:
	if sfx_death:
		sfx_death.play()

func play_block_sfx() -> void:
	_play_block_sfx()
