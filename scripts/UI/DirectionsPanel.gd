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

@export var total_time: float = 5.0
@export var mode_enabled: bool = false

@export var timer_ref: TurnTimer
@export_node_path("Control") var timer_path

@export var tex_up: Texture2D
@export var tex_right: Texture2D
@export var tex_down: Texture2D
@export var tex_left: Texture2D

@export var poll_interval: float = 0.02

@export_node_path("Node2D") var player_path
var _player: Node2D

# === NUEVO ===
@export var show_result_ms: int = 300                
@export var max_tracked_projectiles: int = 4         # cola máx 4

var _rng := RandomNumberGenerator.new()

# Secuencia mostrada y tipeada
var _seq: PackedStringArray = []
var _typed: PackedStringArray = []

# Cola de proyectiles y mapa id->secuencia
var _pq: Array[Area2D] = []        # proyectiles activos ordenados por distancia
var _seq_map: Dictionary = {}      # { instance_id:int : PackedStringArray }

var _active := false
var _round_start_msec := 0
var _poll_accum := 0.0

var _danger := false
var _danger_target := false
var _danger_change_stamp_ms := 0

const HIT_LOCK_MS := 120
var _hit_lock_until_msec := 0
const INPUT_IGNORE_MS := 90
var _ignore_input_until_msec := 0

@export var danger_stable_ms := 40

func _ready() -> void:
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer: timer_ref = n

	if player_path != NodePath():
		var p := get_node_or_null(player_path)
		if p is Node2D: _player = p
	if _player == null:
		_player = get_node_or_null("%Mage_1") as Node2D

	if is_instance_valid(_player) and _player.has_signal("got_hit"):
		if not _player.got_hit.is_connected(_on_player_got_hit):
			_player.got_hit.connect(_on_player_got_hit)

	set_process_input(mode_enabled)
	set_process(true)
	call_deferred("_initial_resync")

func _initial_resync() -> void:
	_update_queue()
	_update_danger_target(_pq.size() > 0)
	_apply_danger_if_stable(true)
	if visible:
		if _danger: start_round()
		else: _show_danger_free()

func set_mode_enabled(active: bool) -> void:
	mode_enabled = active
	set_process_input(active)
	_active = false
	if not active: return
	_update_queue()
	_update_danger_target(_pq.size() > 0)
	_apply_danger_if_stable(true)
	if _danger: start_round()
	else: _show_danger_free()

func start_round() -> void:
	_update_queue()
	if _pq.is_empty():
		_show_danger_free()
		_active = false
		_round_start_msec = Time.get_ticks_msec()
		return

	# Secuencia del proyectil frontal (más cercano)
	var front: Area2D = _pq[0]
	var front_id: int = int(front.get_instance_id())

	var seq_val: PackedStringArray
	if _seq_map.has(front_id):
		seq_val = _seq_map[front_id] as PackedStringArray
	else:
		seq_val = _make_seq()
		_seq_map[front_id] = seq_val

	_seq = seq_val

	_typed.clear()
	_clear_icons()
	_render_line()
	_active = mode_enabled
	_round_start_msec = Time.get_ticks_msec()

func _process(delta: float) -> void:
	if not mode_enabled: return
	_poll_accum += delta
	if _poll_accum < poll_interval: return
	_poll_accum = 0.0

	_update_queue()
	var now_target := (_pq.size() > 0)
	_update_danger_target(now_target)
	_apply_danger_if_stable(false)

	if _danger and not _active and mode_enabled:
		start_round()

func _update_danger_target(now_target: bool) -> void:
	if now_target != _danger_target:
		_danger_target = now_target
		_danger_change_stamp_ms = Time.get_ticks_msec()

func _apply_danger_if_stable(force: bool) -> void:
	if force or (Time.get_ticks_msec() - _danger_change_stamp_ms) >= danger_stable_ms:
		if _danger != _danger_target:
			_danger = _danger_target
			if _danger: start_round()
			else: _show_danger_free()

# ---------------- Input ----------------
func _input(event: InputEvent) -> void:
	if not mode_enabled or not _active: return
	if event is InputEventKey and event.pressed and not event.echo:
		if Time.get_ticks_msec() < _ignore_input_until_msec:
			accept_event(); return
		var sym := _map_event(event)
		if sym == "": return
		accept_event()
		Sfx.key_click_sfx()
		if _typed.size() < 4:
			_typed.append(sym)
			_set_icon(_typed.size() - 1, sym)

		if _typed.size() >= 4:
			_active = false
			if _pq.is_empty():
				score_ready.emit("Fail"); block_fail.emit()
				await _pause_result()
				_continue_after_result()
				return

			var front: Area2D = _pq[0]
			if not _proj_active(front):
				await _pause_result()
				_continue_after_result()
				return

			var front_id: int = int(front.get_instance_id())
			var expected: PackedStringArray = (_seq_map.get(front_id, _seq) as PackedStringArray)

			if _typed == expected:
				if Time.get_ticks_msec() < _hit_lock_until_msec:
					score_ready.emit("Fail"); block_fail.emit()
					await _pause_result()
					_continue_after_result()
					return

				score_ready.emit("PROTECTION")
				_neutralize_projectile(front)
				block_success.emit()

				if is_instance_valid(_player) and _player.has_method("play_block_sfx"):
					_player.play_block_sfx()

				if timer_ref:
					if timer_ref.has_method("restart_safe"): timer_ref.restart_safe()
					else: timer_ref.restart()

				_seq_map.erase(front_id)
				_pq.remove_at(0)

				await _pause_result()
				_continue_after_result()
			else:
				score_ready.emit("Fail"); block_fail.emit()
				await _pause_result()
				_continue_after_result()

func _on_player_got_hit() -> void:
	var now := Time.get_ticks_msec()
	_hit_lock_until_msec = now + HIT_LOCK_MS
	_ignore_input_until_msec = now + INPUT_IGNORE_MS
	_typed.clear()
	_clear_icons()
	_active = false
	await _pause_result()
	_continue_after_result()

# ---------- Helpers ----------
func _pause_result() -> void:
	var secs: float = float(show_result_ms) * 0.001
	if secs <= 0.0:
		return
	await get_tree().create_timer(secs).timeout

func _continue_after_result() -> void:
	_typed.clear()
	_clear_icons()
	_update_queue()

	if _pq.is_empty():
		_show_danger_free()
		_active = false
	else:
		var front: Area2D = _pq[0]
		var front_id: int = int(front.get_instance_id())
		var seq_val: PackedStringArray
		if _seq_map.has(front_id):
			seq_val = _seq_map[front_id] as PackedStringArray
		else:
			seq_val = _make_seq()
			_seq_map[front_id] = seq_val
		_seq = seq_val
		_render_line()
		_active = mode_enabled

func _make_seq() -> PackedStringArray:
	var dirs: Array[String] = ["↑","→","↓","←"]
	var out: PackedStringArray = []
	for i in 4:
		out.append(dirs[_rng.randi_range(0, dirs.size() - 1)])
	return out

func _render_line() -> void:
	if seq_line: seq_line.text = " ".join(_seq)

func _show_danger_free() -> void:
	if seq_line: seq_line.text = "Danger Free"
	_seq.clear(); _typed.clear(); _clear_icons()

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

# ---------- Gestión de proyectiles enemigos ----------
func _update_queue() -> void:
	var actives: Array[Area2D] = _get_active_enemy_projectiles_sorted()
	while actives.size() > max_tracked_projectiles:
		actives.remove_at(actives.size() - 1)

	var active_ids := {}
	for a in actives:
		active_ids[int(a.get_instance_id())] = true

	for id in _seq_map.keys():
		if not active_ids.has(int(id)):
			_seq_map.erase(int(id))

	for a in actives:
		var id := int(a.get_instance_id())
		if not _seq_map.has(id):
			_seq_map[id] = _make_seq()

	_pq = actives

func _get_active_enemy_projectiles_sorted() -> Array[Area2D]:
	var out: Array[Area2D] = []
	var list := get_tree().get_nodes_in_group("enemy_projectile")
	if list.is_empty(): return out

	for n in list:
		var a := n as Area2D
		if a == null: continue
		if _proj_active(a):
			out.append(a)

	if out.is_empty():
		return out

	out.sort_custom(Callable(self, "_cmp_proj_by_distance"))
	return out

func _cmp_proj_by_distance(a: Area2D, b: Area2D) -> bool:
	if a == null or b == null:
		return false
	var origin: Vector2 = ( _player.global_position if (is_instance_valid(_player) and _player != null) else global_position )
	var da := a.global_position.distance_to(origin)
	var db := b.global_position.distance_to(origin)
	return da < db

func _proj_active(a: Area2D) -> bool:
	if a == null: return false
	var active := false
	if a.has_method("is_active"):
		active = bool(a.call("is_active"))
	else:
		active = a.is_inside_tree() and a.monitoring and a.visible and a.collision_layer != 0
	return active

func _neutralize_projectile(p: Area2D) -> void:
	if p == null: return
	if p.has_method("neutralize_now"):
		(p as Object).call("neutralize_now")
	elif p.has_method("disable"):
		(p as Object).call("disable")
	else:
		p.queue_free()
