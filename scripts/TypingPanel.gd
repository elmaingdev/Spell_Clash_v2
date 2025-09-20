extends Control
class_name TypingPanel

signal spell_success(phrase: String)
signal score_ready(rating: String)

@onready var _label: Label    = %PhraseLabel
@onready var _input: LineEdit = %InputLine

@export var total_time: float = 5.0
@export var timer_ref: TurnTimer
@export_node_path("Control") var timer_path

var _current := ""
var _rng := RandomNumberGenerator.new()
var _round_active := false
var _round_start_msec := 0
@export var mode_enabled := true

func _ready() -> void:
	_rng.randomize()
	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer: timer_ref = n
	if _input and not _input.text_changed.is_connected(_on_text):
		_input.text_changed.connect(_on_text)
	# No arrancamos timer aquí. Lo hace ModeSwitcher.
	# Auto-start si está visible y aún no tiene texto
	if visible and has_method("start_round"):
		call_deferred("start_round")

func set_mode_enabled(active: bool) -> void:
	mode_enabled = active
	_round_active = active
	if _input:
		_input.editable = active
		if active: _input.grab_focus() 
		else: _input.release_focus()

func start_round() -> void:
	_current = _pick_spell()
	if _label: _label.text = _current
	if _input:
		_input.text = ""
		if mode_enabled: _input.grab_focus()
	_round_active = mode_enabled
	_round_start_msec = Time.get_ticks_msec()

func on_timeout() -> void:
	if not mode_enabled: return
	_round_active = false
	score_ready.emit("Fail")

func _on_text(new_text: String) -> void:
	if not mode_enabled or not _round_active: return
	if _normalize(new_text) == _normalize(_current):
		var elapsed := _elapsed()
		var rating := _rate(elapsed)
		score_ready.emit(rating)
		spell_success.emit(_current)
		_round_active = false

func _elapsed() -> float:
	if timer_ref and timer_ref.is_running():
		return clamp(total_time - timer_ref.time_left(), 0.0, total_time)
	return clamp(float(Time.get_ticks_msec() - _round_start_msec) / 1000.0, 0.0, total_time)

func _normalize(s: String) -> String:
	var parts: PackedStringArray = s.strip_edges().to_lower().split(" ", false)
	return " ".join(parts)

func _rate(e: float) -> String:
	if e <= 2.0: return "Perfect"
	elif e < 4.0: return "Nice"
	elif e <= 5.0: return "Good"
	else: return "Fail"

func _pick_spell() -> String:
	if typeof(WordBank) != TYPE_NIL and WordBank.has_method("random_spell"):
		return WordBank.random_spell()
	var fb := ["ignis orbis","aegis lucis","umbra nexus","glacies hasta","fulgor arcano","terra spina","ventus celer","runas vivas","draco minor","nova runica"]
	return fb[_rng.randi_range(0, fb.size() - 1)]
