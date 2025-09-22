extends Control
class_name DirectionsPanel

signal score_ready(rating: String)
signal block_success
signal block_fail

@onready var seq_line: Label    = %SeqLine
@onready var seq1: TextureRect  = $Panel/VBox/SeqContainer/Seq1
@onready var seq2: TextureRect  = $Panel/VBox/SeqContainer/Seq2
@onready var seq3: TextureRect  = $Panel/VBox/SeqContainer/Seq3
@onready var seq4: TextureRect  = $Panel/VBox/SeqContainer/Seq4

# Config
@export var total_time: float = 5.0
@export var mode_enabled: bool = false

# TurnTimer (solo lectura + reinicio cuando hay PROTECTION)
@export var timer_ref: TurnTimer
@export_node_path("Control") var timer_path

# Iconos
@export var tex_up: Texture2D
@export var tex_right: Texture2D
@export var tex_down: Texture2D
@export var tex_left: Texture2D

# Poll de “peligro” (proyectiles enemigos en escena)
@export var poll_interval: float = 0.02

# Jugador (para distancia al proyectil y SFX de bloqueo)
@export_node_path("Node2D") var player_path
var _player: Node2D

# Estado interno
var _rng := RandomNumberGenerator.new()
var _seq: PackedStringArray = []
var _typed: PackedStringArray = []
var _active := false                         # acepta input para la secuencia actual
var _round_start_msec: int = 0               # por si luego mides velocidad
var _poll_accum := 0.0
var _danger := false                         # hay proyectiles enemigos

# Ventana anti-race: evita PROTECTION si te golpearon “en el mismo instante”
const HIT_LOCK_MS := 120
var _hit_lock_until_msec: int = 0

# NUEVO: pequeña ventana en la que se ignoran teclas tras el impacto
# (evita que la tecla tardía cuente como la 1ª de la siguiente secuencia)
const INPUT_IGNORE_MS := 90
var _ignore_input_until_msec: int = 0

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Resolver TurnTimer
	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer:
			timer_ref = n

	# Resolver jugador
	if player_path != NodePath():
		var p := get_node_or_null(player_path)
		if p is Node2D:
			_player = p
	if _player == null:
		_player = get_node_or_null("%Mage_1") as Node2D

	# Escucha cuando el jugador recibe golpe
	if is_instance_valid(_player) and _player != null and _player.has_signal("got_hit"):
		if not _player.got_hit.is_connected(_on_player_got_hit):
			_player.got_hit.connect(_on_player_got_hit)

	set_process_input(mode_enabled)
	set_process(true)

	# Auto-start suave si está visible al entrar en escena
	if visible:
		call_deferred("start_round")

# ---------- API desde fuera (ModeSwitcher) ----------
func set_mode_enabled(active: bool) -> void:
	mode_enabled = active
	set_process_input(active)
	_active = false
	if not active:
		return

	# Sincroniza inmediatamente con el estado de peligro actual
	_danger = _has_enemy_projectiles()
	if _danger:
		start_round()
	else:
		_show_danger_free()

func start_round() -> void:
	# Si no hay proyectiles, entra a "Danger Free"
	if not _has_enemy_projectiles():
		_show_danger_free()
		_active = false
		_round_start_msec = Time.get_ticks_msec()
		return

	# Nueva secuencia
	_seq = _make_seq()
	_typed.clear()
	_clear_icons()
	_render_line()

	_active = mode_enabled
	_round_start_msec = Time.get_ticks_msec()

# DEFEND NO reacciona al timeout del TurnTimer → NO on_timeout()

# ---------- Loop: detecta (des)aparición de proyectiles ----------
func _process(delta: float) -> void:
	if not mode_enabled:
		return

	_poll_accum += delta
	if _poll_accum < poll_interval:
		return
	_poll_accum = 0.0

	var now_danger := _has_enemy_projectiles()

	if now_danger and not _danger:
		_danger = true
		start_round()             # aparece proyectil → genera secuencia
	elif not now_danger and _danger:
		_danger = false
		_show_danger_free()       # ya no hay proyectiles → Danger Free

# ---------- Input ----------
func _input(event: InputEvent) -> void:
	if not mode_enabled or not _active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		# Ignorar cualquier tecla durante la ventana tras el impacto
		if Time.get_ticks_msec() < _ignore_input_until_msec:
			accept_event()
			return

		var sym := _map_event(event)
		if sym == "":
			return

		accept_event()
		Sfx.key_click_sfx()

		if _typed.size() < 4:
			_typed.append(sym)
			_set_icon(_typed.size() - 1, sym)

		if _typed.size() >= 4:
			_active = false

			if _typed == _seq:
				# Si te golpearon "justo ahora", NO hay PROTECTION (anti-race)
				if Time.get_ticks_msec() < _hit_lock_until_msec:
					score_ready.emit("Fail")
					block_fail.emit()
					if _has_enemy_projectiles():
						start_round()
					else:
						_show_danger_free()
					return

				# ÉXITO → PROTECTION
				score_ready.emit("PROTECTION")
				_destroy_nearest_enemy_projectile()
				block_success.emit()

				# SFX de bloqueo (en el propio jugador)
				if is_instance_valid(_player) and _player != null and _player.has_method("play_block_sfx"):
					_player.play_block_sfx()

				# SOLO en éxito reiniciamos el TurnTimer
				if timer_ref:
					timer_ref.restart()

				_show_danger_free()    # no generes nueva secuencia
			else:
				# FAIL → NO reiniciar timer
				score_ready.emit("Fail")
				block_fail.emit()
				if _has_enemy_projectiles():
					start_round()
				else:
					_show_danger_free()

# ---------- Handler: el jugador fue golpeado ----------
func _on_player_got_hit() -> void:
	var now := Time.get_ticks_msec()
	_hit_lock_until_msec = now + HIT_LOCK_MS
	_ignore_input_until_msec = now + INPUT_IGNORE_MS  # ← ignorar teclas “tardías”

	# Limpia lo escrito y freezea entrada actual
	_typed.clear()
	_clear_icons()
	_active = false

	# Si todavía hay proyectiles, prepara NUEVA secuencia; si no, Danger Free
	if _has_enemy_projectiles():
		start_round()
	else:
		_show_danger_free()

# ---------- Helpers ----------
func _make_seq() -> PackedStringArray:
	var dirs := ["↑","→","↓","←"]
	var out: PackedStringArray = []
	for i in 4:
		out.append(dirs[_rng.randi_range(0, dirs.size() - 1)])
	return out

func _render_line() -> void:
	if seq_line:
		seq_line.text = " ".join(_seq)

func _show_danger_free() -> void:
	if seq_line:
		seq_line.text = "Danger Free"
	_clear_icons()

func _clear_icons() -> void:
	if seq1: seq1.texture = null
	if seq2: seq2.texture = null
	if seq3: seq3.texture = null
	if seq4: seq4.texture = null

func _set_icon(idx: int, sym: String) -> void:
	var tex := _tex(sym)
	match idx:
		0: if seq1: seq1.texture = tex
		1: if seq2: seq2.texture = tex
		2: if seq3: seq3.texture = tex
		3: if seq4: seq4.texture = tex

func _tex(sym: String) -> Texture2D:
	match sym:
		"↑": return tex_up
		"→": return tex_right
		"↓": return tex_down
		"←": return tex_left
		_:  return null

func _map_event(e: InputEventKey) -> String:
	if e.is_action_pressed("ui_up"):    return "↑"
	if e.is_action_pressed("ui_right"): return "→"
	if e.is_action_pressed("ui_down"):  return "↓"
	if e.is_action_pressed("ui_left"):  return "←"
	return ""

func _has_enemy_projectiles() -> bool:
	var list := get_tree().get_nodes_in_group("enemy_projectile")
	return not list.is_empty()

func _destroy_nearest_enemy_projectile() -> void:
	var list := get_tree().get_nodes_in_group("enemy_projectile")
	if list.is_empty():
		return
	var origin: Vector2 = _player.global_position if (is_instance_valid(_player) and _player != null) else global_position
	var nearest: Node2D = null
	var best: float = INF
	for n in list:
		var n2 := n as Node2D
		if n2:
			var d := (n2.global_position - origin).length()
			if d < best:
				best = d
				nearest = n2
	if nearest:
		if nearest.has_method("disable"):
			(nearest as Object).call("disable")
		else:
			nearest.queue_free()
