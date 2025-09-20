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

@export var total_time := 5.0
@export var mode_enabled := false
@export var timer_ref: TurnTimer
@export_node_path("Control") var timer_path

@export var tex_up: Texture2D
@export var tex_right: Texture2D
@export var tex_down: Texture2D
@export var tex_left: Texture2D
@export_node_path("Node2D") var player_path
var _player: Node2D

var _rng := RandomNumberGenerator.new()
var _seq: PackedStringArray = []
var _typed: PackedStringArray = []
var _active := false
var _round_start_msec := 0

# Poll para “Danger Free”
@export var poll_interval: float = 0.02
var _poll_accum := 0.0
var _danger := false  # hay proyectiles en escena

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer: timer_ref = n

	# Auto-start suave si está visible (por seguridad)
	if visible and has_method("start_round"):
		call_deferred("start_round")

	# Resolver jugador
	if player_path != NodePath():
		var p := get_node_or_null(player_path)
		if p is Node2D: _player = p
	if _player == null:
		_player = get_node_or_null("%Mage_1") as Node2D

	set_process_input(mode_enabled)
	set_process(true)

func set_mode_enabled(active: bool) -> void:
	mode_enabled = active
	set_process_input(active)
	_active = false
	if not active:
		return
	# Al activar, sincroniza inmediatamente según peligro actual
	_danger = _has_enemy_projectiles()
	if _danger:
		start_round()          # ← antes llamabas _new_sequence(true)
	else:
		_show_danger_free()    # ← antes llamabas _enter_danger_free()

func start_round() -> void:
	# Si no hay proyectiles, muestra "Danger Free"
	if not _has_enemy_projectiles():
		_show_danger_free()
		_active = false
		_round_start_msec = Time.get_ticks_msec()
		return

	# Genera secuencia de 4 flechas
	_seq = _make_seq()
	_typed.clear()
	_clear_icons()
	_render_line()
	_active = mode_enabled
	_round_start_msec = Time.get_ticks_msec()

func on_timeout() -> void:
	if not mode_enabled: return
	_active = false
	score_ready.emit("Fail")

func _process(delta: float) -> void:
	if not mode_enabled:
		return

	_poll_accum += delta
	if _poll_accum < poll_interval:
		return
	_poll_accum = 0.0

	var now_danger := _has_enemy_projectiles()

	# Reacciona SIEMPRE al cambio de estado (sin chequear _active)
	if now_danger and not _danger:
		_danger = true
		start_round()           # ← antes: _new_sequence(true)
	elif not now_danger and _danger:
		_danger = false
		_show_danger_free()     # ← antes: _enter_danger_free()

func _input(event: InputEvent) -> void:
	if not mode_enabled or not _active: return
	if event is InputEventKey and event.pressed and not event.echo:
		var sym := _map_event(event)
		if sym == "": return
		accept_event()

		if _typed.size() < 4:
			_typed.append(sym)
			_set_icon(_typed.size()-1, sym)

		if _typed.size() >= 4:
			_active = false
			var elapsed := _elapsed()
			if _typed == _seq:
				score_ready.emit(_rate(elapsed))
				_destroy_nearest_enemy_projectile()
				block_success.emit()
			else:
				score_ready.emit("Fail")
				block_fail.emit()

func _elapsed() -> float:
	if timer_ref and timer_ref.is_running():
		return clamp(total_time - timer_ref.time_left(), 0.0, total_time)
	return clamp(float(Time.get_ticks_msec() - _round_start_msec) / 1000.0, 0.0, total_time)

func _make_seq() -> PackedStringArray:
	var dirs := ["↑","→","↓","←"]
	var out: PackedStringArray = []
	for i in 4:
		out.append(dirs[_rng.randi_range(0, dirs.size()-1)])
	return out

func _render_line() -> void:
	if seq_line: seq_line.text = " ".join(_seq)

func _show_danger_free() -> void:
	if seq_line: seq_line.text = "Danger Free"
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
		_: return null

func _map_event(e: InputEventKey) -> String:
	if e.is_action_pressed("ui_up"):    return "↑"
	if e.is_action_pressed("ui_right"): return "→"
	if e.is_action_pressed("ui_down"):  return "↓"
	if e.is_action_pressed("ui_left"):  return "←"
	return ""

func _has_enemy_projectiles() -> bool:
	return not get_tree().get_nodes_in_group("enemy_projectile").is_empty()

func _destroy_nearest_enemy_projectile() -> void:
	var list := get_tree().get_nodes_in_group("enemy_projectile")
	if list.is_empty(): return

	var origin: Vector2 = (_player.global_position if _player != null else global_position)
	var nearest: Node2D = null
	var best := INF
	for n in list:
		var n2 := n as Node2D
		if n2:
			var d := (n2.global_position - origin).length()
			if d < best:
				best = d; nearest = n2

	if nearest:
		# Si el proyectil implementa disable(), úsalo; si no, destruye directo
		if nearest.has_method("disable"):
			(nearest as Object).call("disable")
		else:
			nearest.queue_free()

func _rate(e: float) -> String:
	if e <= 2.0: return "Perfect"
	elif e < 4.0: return "Nice"
	elif e <= 5.0: return "Good"
	else: return "Fail"
