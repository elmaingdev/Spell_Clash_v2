extends Control
class_name TypingPanel

signal spell_success(phrase: String)

@onready var _label: Label    = %PhraseLabel
@onready var _input: LineEdit = %InputLine

@export var total_time: float = 5.0
@export var timer_ref: TurnTimer
@export_node_path("Control") var timer_path

var _current: String = ""
var _rng := RandomNumberGenerator.new()
var _round_active := false

func _ready() -> void:
	_rng.randomize()
	_resolve_timer()

	# Conexiones por script
	if _input and not _input.text_changed.is_connected(_on_InputLine_text_changed):
		_input.text_changed.connect(_on_InputLine_text_changed)
	if timer_ref and not timer_ref.timeout.is_connected(_on_timer_timeout):
		timer_ref.timeout.connect(_on_timer_timeout)

	_set_new_spell()

func _resolve_timer() -> void:
	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer:
			timer_ref = n

func _on_InputLine_text_changed(new_text: String) -> void:
	if not _round_active:
		return
	if _normalize(new_text) == _normalize(_current):
		_round_active = false
		# detener y reiniciar el turno
		if timer_ref: timer_ref.stop()
		spell_success.emit(_current)
		_set_new_spell()  # ← esto llama a timer_ref.start(total_time)

func _on_timer_timeout() -> void:
	# Se acabaron los 5s → cambiar conjuro y reiniciar turno
	if not _round_active:
		return
	_round_active = false
	_set_new_spell()

func _set_new_spell() -> void:
	_current = _pick_spell()
	_label.text = _current
	_input.text = ""
	_input.grab_focus()

	_round_active = true
	if timer_ref:
		# reinicia la barra/tiempo para el nuevo spell
		await get_tree().process_frame  # evita carreras si el TurnTimer acaba de entrar en escena
		timer_ref.start(total_time)

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
