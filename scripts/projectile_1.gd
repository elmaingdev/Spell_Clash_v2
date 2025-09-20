extends Area2D
class_name Projectile1

@export var speed: float = 300.0
@export var max_distance: float = 4000.0
@export var damage: int = 10             # ← recibido desde Mage1

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

# --- SFX de disparo del jugador ---
@export var sfx_index: int = -1  # ← lo setea Mage_1 (0,1,2). Si queda -1, usa 0.
@onready var sfx_spell: AudioStreamPlayer2D = null
const SPELL_STREAMS: Array[AudioStream] = [
	preload("res://assets/sfx/spell_1.wav"),
	preload("res://assets/sfx/spell_2.wav"),
	preload("res://assets/sfx/spell_3.wav"),
]

var _start: Vector2 = Vector2.ZERO
var _alive: bool = true
var _initialized: bool = false

func _ready() -> void:
	z_index = 20
	collision_layer = 1      # proyectil del jugador
	collision_mask  = 2      # golpea enemigo (Mage_2 layer 2)
	monitoring = true

	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("fly"):
		anim.play("fly")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# SFX: localizar/crear player y reproducir
	_ensure_spell_player()
	_play_spell_sfx()

func _physics_process(delta: float) -> void:
	if not _alive: return
	if not _initialized:
		_start = global_position
		_initialized = true
	global_position.x += speed * delta
	if global_position.distance_to(_start) > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if not _alive: return
	var actor := body.get_parent() if body and body.get_parent() else body
	if actor and actor.has_method("take_dmg"):
		actor.take_dmg(damage)  # ← aplicar daño
	_alive = false
	queue_free()

# ================== SFX ==================
func _ensure_spell_player() -> void:
	# 1) Sfx/Spell si existe
	sfx_spell = get_node_or_null("Sfx/Spell") as AudioStreamPlayer2D
	# 2) algún AudioStreamPlayer2D ya presente (compat)
	if sfx_spell == null:
		for c in get_children():
			if c is AudioStreamPlayer2D:
				sfx_spell = c
				break
	# 3) crearlo
	if sfx_spell == null:
		var sfx := get_node_or_null("Sfx")
		if sfx == null:
			sfx = Node.new()
			sfx.name = "Sfx"
			add_child(sfx)
		var ap := AudioStreamPlayer2D.new()
		ap.name = "Spell"
		ap.bus = _best_bus(["FX", "SFX", "Master"])
		sfx.add_child(ap)
		sfx_spell = ap

func _play_spell_sfx() -> void:
	if sfx_spell == null or SPELL_STREAMS.is_empty():
		return
	var idx := sfx_index
	if idx < 0 or idx >= SPELL_STREAMS.size():
		idx = 0
	sfx_spell.stream = SPELL_STREAMS[idx]
	sfx_spell.pitch_scale = 1.0 + randf_range(-0.015, 0.015) # leve variación
	sfx_spell.play()

func _best_bus(candidates: Array[String]) -> String:
	for b in candidates:
		if AudioServer.get_bus_index(b) != -1:
			return b
	return "Master"
