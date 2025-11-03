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
var _next_sent: bool = false                 # evita reentradas al pasar de stage
var _flow: Node = null                       # ← StageFlow cacheado
var _book_cache: AnimatedSprite2D = null

func _ready() -> void:
	_rng.randomize()

	# Resolver TurnTimer si fue expuesto por path
	if timer_ref == null and timer_path != NodePath():
		var n := get_node_or_null(timer_path)
		if n is TurnTimer: timer_ref = n

	# Conectar entrada del LineEdit
	if _input and not _input.text_changed.is_connected(_on_text):
		_input.text_changed.connect(_on_text)

	# Cachear StageFlow una vez dentro del árbol
	_flow = _resolve_stage_flow()

	# Escuchar muerte del enemigo de la escena
	_wire_enemy_died()

	if visible:
		call_deferred("start_round")

func _exit_tree() -> void:
	# Evita que entren callbacks cuando ya no estamos en el árbol
	if _input and _input.text_changed.is_connected(_on_text):
		_input.text_changed.disconnect(_on_text)
	_next_sent = false

# -------- helpers de autoload --------
func _resolve_stage_flow() -> Node:
	var root := (get_tree().root if get_tree() != null else null)
	return root.get_node_or_null("StageFlow") if root else null

# --- Sincroniza la palabra de avance según si es última stage ---
func _sync_next_keyword_to_stage() -> void:
	if _flow == null: _flow = _resolve_stage_flow()
	if _flow and _flow.has_method("is_last_stage") and bool(_flow.call("is_last_stage")):
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
	_sync_next_keyword_to_stage()
	set_mode_enabled(true)   # fuerza ATTACK activo
	visible = true
	show_next_prompt()

# ---------------- Modo / rondas ----------------
func set_mode_enabled(active: bool) -> void:
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
	# ← Añade esta línea para animar el libro cuando cambiamos de spell
	_book_play(&"next")

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
	# Si ya no pertenecemos al árbol activo, no busques nada global
	if not is_inside_tree():
		return
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
		if _next_sent:
			return
		_next_sent = true
		_awaiting_next = false
		if _input: _input.editable = false
		next_requested.emit()

		# Usa la referencia cacheada (sin get_node con ruta absoluta)
		if _flow == null: _flow = _resolve_stage_flow()
		if _flow and _flow.has_method("go_next"):
			_flow.call_deferred("go_next")
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

func _get_book() -> AnimatedSprite2D:
	if _book_cache and is_instance_valid(_book_cache):
		return _book_cache
	var nodes := get_tree().get_nodes_in_group("ui_book")
	if nodes.size() > 0:
		_book_cache = nodes[0] as AnimatedSprite2D
		return _book_cache
	return null

func _book_play(anim: StringName) -> void:
	var b := _get_book()
	if b == null:
		return

	var anim_name := String(anim)            # ← renombrada; evita sombrear Node.name
	var frames := b.sprite_frames            # AnimatedSprite2D usa SpriteFrames
	if frames and frames.has_animation(anim_name):
		# Evita re-tocar una animación ya en curso (opcional)
		if String(b.animation) != anim_name or not b.is_playing():
			b.play(anim_name)
	else:
		# Debug opcional para detectar typos
		# print_debug("[Book] Animación no encontrada: ", anim_name)
		pass
