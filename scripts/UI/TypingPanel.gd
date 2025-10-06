# res://scripts/UI/TypingPanel.gd
extends Control
class_name TypingPanel

signal score_ready(rating: String)
signal round_started
signal next_requested      # se emite cuando el jugador escribe NEXT/END RUN
signal spell_success(phrase: String)

@onready var _label: Label    = %PhraseLabel
@onready var _input: LineEdit = %InputLine

@export var total_time: float = 5.0
@export var timer_ref: TurnTimer
@export_node_path("Control") var timer_path

@export var mode_enabled: bool = true
@export var next_keyword: String = "NEXT"   # se sincroniza dinámicamente

var _current: String = ""
var _rng := RandomNumberGenerator.new()
var _round_active := false
var _round_start_msec := 0
var _awaiting_next := false

func _ready() -> void:
	_rng.randomize()

	# Resolver TurnTimer si fue expuesto por path
	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer: timer_ref = n

	# Conectar entrada del LineEdit
	if _input and not _input.text_changed.is_connected(_on_text):
		_input.text_changed.connect(_on_text)

	# Escuchar muerte del enemigo de la escena
	_wire_enemy_died()

	if visible:
		call_deferred("start_round")

# --- Sincroniza la palabra de avance según si es última stage ---
func _sync_next_keyword_to_stage() -> void:
	var flow := get_node_or_null("/root/StageFlow")
	if flow and flow.has_method("is_last_stage") and bool(flow.call("is_last_stage")):
		next_keyword = "END RUN"
	else:
		next_keyword = "NEXT"

func _wire_enemy_died() -> void:
	var enemy := get_node_or_null("%Enemy")
	if enemy == null:
		var list := get_tree().get_nodes_in_group("enemy")
		if not list.is_empty():
			enemy = list[0]
	if enemy and enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	# Ajusta la palabra y muestra el prompt correcto
	_sync_next_keyword_to_stage()
	set_mode_enabled(true)   # fuerza ATTACK activo
	visible = true
	show_next_prompt()

# ---------------- Modo / rondas ----------------
func set_mode_enabled(active: bool) -> void:
	# Si estamos esperando NEXT/END RUN, mantenemos ATTACK y el prompt
	if _awaiting_next and active:
		mode_enabled = true
		show_next_prompt()
		return

	mode_enabled = active
	_round_active = active
	if _input:
		_input.editable = active
		if active: _input.grab_focus()
		else: _input.release_focus()

func start_round() -> void:
	if _awaiting_next:
		show_next_prompt()
		return
	_current = _pick_spell()
	if _label: _label.text = _current
	if _input:
		_input.text = ""
		if mode_enabled: _input.grab_focus()
	_round_active = mode_enabled
	_round_start_msec = Time.get_ticks_msec()
	round_started.emit()

func show_next_prompt() -> void:
	_awaiting_next = true
	_current = next_keyword
	if _label: _label.text = next_keyword
	if _input:
		_input.text = ""
		_input.editable = true
		_input.grab_focus()
	_round_active = true
	_round_start_msec = Time.get_ticks_msec()
	round_started.emit()

func on_timeout() -> void:
	if not mode_enabled: return
	_round_active = false
	score_ready.emit("Fail")

# ---------------- Input ----------------
func _on_text(new_text: String) -> void:
	if not mode_enabled or not _round_active:
		return

	if _input and _input.has_focus():
		Sfx.key_click_sfx()

	var typed := _normalize(new_text)
	var target := _normalize(_current)
	var is_next_word := (target == _normalize(next_keyword))

	if typed != target:
		return

	_round_active = false

	if is_next_word:
		_awaiting_next = false
		next_requested.emit()
		var flow := get_node_or_null("/root/StageFlow")
		if flow and flow.has_method("go_next"):
			flow.call("go_next")  # en última stage hará finalize_and_return_to_menu()
		return

	# Acierto normal
	var elapsed := _elapsed()
	var rating := _rate(elapsed)
	score_ready.emit(rating)
	spell_success.emit(_current)
	if timer_ref:
		timer_ref.restart()

# ---------------- Utilidades ----------------
func _elapsed() -> float:
	if timer_ref and timer_ref.is_running():
		var tl: float = timer_ref.time_left()
		return clampf(total_time - tl, 0.0, total_time)
	var secs: float = float(Time.get_ticks_msec() - _round_start_msec) / 1000.0
	return clampf(secs, 0.0, total_time)

func _normalize(s: String) -> String:
	var parts := s.strip_edges().to_lower().split(" ", false)
	return " ".join(parts)

func _rate(e: float) -> String:
	if e <= 2.0: return "Perfect"
	elif e < 4.0: return "Nice"
	elif e <= 5.0: return "Good"
	else: return "Fail"

func _pick_spell() -> String:
	if typeof(WordBank) != TYPE_NIL and WordBank.has_method("random_spell"):
		return WordBank.random_spell()
	var fb: Array[String] = [
		"ignis orbis","aegis lucis","umbra nexus","glacies hasta","fulgor arcano",
		"terra spina","ventus celer","runas vivas","draco minor","nova runica"
	]
	return fb[_rng.randi_range(0, fb.size() - 1)]
