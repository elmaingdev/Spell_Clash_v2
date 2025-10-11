extends Area2D
class_name Projectile1

@export var speed: float = 300.0
@export var max_distance: float = 4000.0
@export var damage: int = 10

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# --- SFX ---
@export var sfx_index: int = -1
@onready var sfx_spell: AudioStreamPlayer2D = null
const SPELL_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/spell_1.wav"),
	preload("res://assets/sfx/spell_2.wav"),
	preload("res://assets/sfx/spell_3.wav"),
]

var _start: Vector2 = Vector2.ZERO
var _alive: bool = true
var _initialized: bool = false
var launch_msec: int = -1

func _ready() -> void:
	z_index = 20
	collision_layer = 1
	collision_mask  = 2
	monitoring = true

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_ensure_spell_player()
	# OJO: ya NO reproducimos SFX en _ready(); se hace al reactivarse.

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	if not _initialized:
		_start = global_position
		_initialized = true
	global_position.x += speed * delta
	if global_position.distance_to(_start) > max_distance:
		_recycle()

func _on_body_entered(body: Node) -> void:
	if not _alive:
		return
	var actor := body.get_parent() if body and body.get_parent() else body
	if actor and actor.has_method("take_dmg"):
		actor.take_dmg(damage)
	_alive = false
	# Evita cambios durante la señal:
	call_deferred("_recycle")

# ---------- API ----------
func set_damage(value: int) -> void:
	damage = max(0, value)

func get_damage() -> int:
	return damage

func reactivate() -> void:
	_alive = true
	_initialized = false
	set_deferred("monitoring", true)
	collision_layer = 1
	collision_mask  = 2
	launch_msec = Time.get_ticks_msec()

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")

	# Asegura pertenecer al grupo para que los enemigos puedan “verlo”
	if not is_in_group("player_projectile"):
		add_to_group("player_projectile")

	_play_spell_sfx()

func _recycle() -> void:
	# Desactivar de forma segura y devolver al pool si existe
	set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask  = 0
	var pool := get_parent() as ProjectilePool
	if pool:
		pool.recycle_self(self)
	else:
		queue_free()

func vanish_blocked() -> void:
	# Llamado por enemigos que bloquean el proyectil
	if not _alive:
		return
	_alive = false
	set_deferred("monitoring", false)
	collision_layer = 0
	collision_mask  = 0

	# Intenta reproducir animación de “desaparecer” si existe
	var played := false
	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation("disappear"):
			anim.play("disappear"); played = true
		elif anim.sprite_frames.has_animation("disapear"): # por si tu anim se llama así
			anim.play("disapear"); played = true

	if played:
		await anim.animation_finished

	_recycle()

# ================== SFX ==================
func _ensure_spell_player() -> void:
	sfx_spell = get_node_or_null("Sfx/Spell") as AudioStreamPlayer2D
	if sfx_spell == null:
		for c in get_children():
			if c is AudioStreamPlayer2D:
				sfx_spell = c
				break
	if sfx_spell == null:
		var sfx := get_node_or_null("Sfx")
		if sfx == null:
			sfx = Node.new()
			sfx.name = "Sfx"
			add_child(sfx)
		var ap: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		ap.name = "Spell"
		ap.bus = _best_bus(["FX", "SFX", "Master"])
		sfx.add_child(ap)
		sfx_spell = ap

func _play_spell_sfx() -> void:
	if sfx_spell == null or SPELL_STREAMS.is_empty():
		return
	var idx: int = sfx_index
	if idx < 0 or idx >= SPELL_STREAMS.size():
		idx = 0
	sfx_spell.stream = SPELL_STREAMS[idx]
	sfx_spell.pitch_scale = 1.0 + randf_range(-0.015, 0.015)
	sfx_spell.play()

func _best_bus(candidates: Array[String]) -> String:
	for b in candidates:
		if AudioServer.get_bus_index(b) != -1:
			return b
	return "Master"
