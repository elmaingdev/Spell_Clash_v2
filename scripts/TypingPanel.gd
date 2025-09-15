extends Control
class_name TypingPanel

signal spell_success(phrase: String)
signal score_ready(rating: String) # ← NUEVA

@onready var _label: Label    = %PhraseLabel
@onready var _input: LineEdit = %InputLine

@export var total_time: float = 5.0
@export var timer_ref: TurnTimer
@export_node_path("Control") var timer_path

var _current: String = ""
var _rng := RandomNumberGenerator.new()
var _round_active := false
var _round_start_msec: int = 0

func _ready() -> void:
	_rng.randomize()
	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer:
			timer_ref = n

	if _input and not _input.text_changed.is_connected(_on_InputLine_text_changed):
		_input.text_changed.connect(_on_InputLine_text_changed)
	if timer_ref and not timer_ref.timeout.is_connected(_on_timer_timeout):
		timer_ref.timeout.connect(_on_timer_timeout)

	_set_new_spell()

func _on_InputLine_text_changed(new_text: String) -> void:
	if not _round_active:
		return
	if _normalize(new_text) == _normalize(_current):
		var elapsed := _get_elapsed_time()
		var rating := _rate(elapsed)
		print("Score:", rating, " (", str(snapped(elapsed, 0.01)), "s)")
		score_ready.emit(rating)           # ← avisa al ScorePanel
		_round_active = false
		if timer_ref: timer_ref.stop()
		spell_success.emit(_current)
		_set_new_spell()

func _on_timer_timeout() -> void:
	if not _round_active:
		return
	_round_active = false
	print("Score: Fail (", str(total_time), "s)")
	score_ready.emit("Fail")               # ← avisa al ScorePanel
	_set_new_spell()

func _set_new_spell() -> void:
	_current = _pick_spell()
	_label.text = _current
	_input.text = ""
	_input.grab_focus()
	_round_active = true
	if timer_ref:
		await get_tree().process_frame
		timer_ref.start(total_time)
	_round_start_msec = Time.get_ticks_msec()

func _pick_spell() -> String:
	if typeof(WordBank) != TYPE_NIL and WordBank.has_method("random_spell"):
		return WordBank.random_spell()
	var fallback := [
		"ignis orbis","aegis lucis","umbra nexus","glacies hasta","fulgor arcano",
		"terra spina","ventus celer","runas vivas","draco minor","nova runica"
	]
	return fallback[_rng.randi_range(0, fallback.size() - 1)]

func _normalize(s: String) -> String:
	var parts: PackedStringArray = s.strip_edges().to_lower().split(" ", false)
	return " ".join(parts)

func _get_elapsed_time() -> float:
	if timer_ref:
		return clamp(total_time - timer_ref.time_left(), 0.0, total_time)
	return clamp(float(Time.get_ticks_msec() - _round_start_msec) / 1000.0, 0.0, total_time)

func _rate(elapsed: float) -> String:
	if elapsed <= 2.0:      return "Perfect"
	elif elapsed < 4.0:     return "Nice"
	elif elapsed <= 5.0:    return "Good"
	else:                   return "Fail"
