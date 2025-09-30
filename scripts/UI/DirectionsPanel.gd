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

var _rng := RandomNumberGenerator.new()
var _seq: PackedStringArray = []
var _typed: PackedStringArray = []
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
	_update_danger_target(_has_enemy_projectiles_active())
	_apply_danger_if_stable(true)
	if visible:
		if _danger: start_round()
		else: _show_danger_free()

func set_mode_enabled(active: bool) -> void:
	mode_enabled = active
	set_process_input(active)
	_active = false
	if not active: return
	_update_danger_target(_has_enemy_projectiles_active())
	_apply_danger_if_stable(true)
	if _danger: start_round()
	else: _show_danger_free()

func start_round() -> void:
	if not _has_enemy_projectiles_active():
		_show_danger_free()
		_active = false
		_round_start_msec = Time.get_ticks_msec()
		return
	_seq = _make_seq()
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
	var now_target := _has_enemy_projectiles_active()
	_update_danger_target(now_target)
	_apply_danger_if_stable(false)

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
			if _typed == _seq:
				if Time.get_ticks_msec() < _hit_lock_until_msec:
					score_ready.emit("Fail"); block_fail.emit(); _resync_soon(); return
				score_ready.emit("PROTECTION")
				_destroy_nearest_enemy_projectile()
				block_success.emit()
				if is_instance_valid(_player) and _player.has_method("play_block_sfx"):
					_player.play_block_sfx()
				if timer_ref:
					if timer_ref.has_method("restart_safe"): timer_ref.restart_safe()
					else: timer_ref.restart()
				_resync_soon()
			else:
				score_ready.emit("Fail"); block_fail.emit(); _resync_soon()

func _on_player_got_hit() -> void:
	var now := Time.get_ticks_msec()
	_hit_lock_until_msec = now + HIT_LOCK_MS
	_ignore_input_until_msec = now + INPUT_IGNORE_MS
	_typed.clear()
	_clear_icons()
	_active = false
	_resync_soon()

# ---------- Helpers ----------
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

func _has_enemy_projectiles_active() -> bool:
	var list := get_tree().get_nodes_in_group("enemy_projectile")
	for n in list:
		var a := n as Area2D
		if a == null: continue
		if a.has_method("is_active"):
			if bool(a.call("is_active")): return true
		else:
			if a.is_inside_tree() and a.monitoring and a.visible and a.collision_layer != 0:
				return true
	return false

func _destroy_nearest_enemy_projectile() -> void:
	var list := get_tree().get_nodes_in_group("enemy_projectile")
	if list.is_empty(): return

	var origin: Vector2 = ( _player.global_position if (is_instance_valid(_player) and _player != null) else global_position )
	var nearest: Area2D = null
	var best := INF

	for n in list:
		var a := n as Area2D
		if a == null: continue
		var active := false
		if a.has_method("is_active"):
			active = bool(a.call("is_active"))
		else:
			active = a.is_inside_tree() and a.monitoring and a.visible and a.collision_layer != 0
		if not active: continue

		var host := n as Node2D
		if host == null: continue
		var d := host.global_position.distance_to(origin)
		if d < best:
			best = d
			nearest = a

	if nearest:
		if nearest.has_method("neutralize_now"):
			(nearest as Object).call("neutralize_now")
		elif nearest.has_method("disable"):
			(nearest as Object).call("disable")
		else:
			nearest.queue_free()

func _resync_soon() -> void:
	call_deferred("_resync_now")

func _resync_now() -> void:
	_update_danger_target(_has_enemy_projectiles_active())
	_apply_danger_if_stable(false)
