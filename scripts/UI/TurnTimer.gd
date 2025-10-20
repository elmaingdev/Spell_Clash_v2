# res://scripts/UI/TurnTimer.gd
extends Control
class_name TurnTimer

signal timeout
signal started(total_time: float)

@onready var left_time: ProgressBar  = null   # "LeftTime" (Fill: End→Begin)
@onready var right_time: ProgressBar = null   # "RightTime" (Fill: Begin→End)
@onready var limit: Timer            = null   # "Limit" (Timer)
@onready var book: AnimatedSprite2D  = null   # "Book" (opcional)

@export var total_time: float = 5.0
@export var autostart_on_ready: bool = false

# Bucle autónomo
@export var loop: bool = true
@export var loop_delay: float = 0.0

# (Opcional) para animar el libro
@export_node_path("Control") var typing_panel_path: NodePath = NodePath("")
@export var book_next_anim: String = "next"
@export var book_mode_anim: String = "previous"

var _running: bool = false

# Ventana anti-race (ignora timeout si acabas de resolver el turno)
const RESOLVE_WINDOW_MS: int = 30
var _resolved_until_msec: int = 0

func _ready() -> void:
	# Resolver hijos
	left_time  = (find_child("LeftTime",  true, false)  as ProgressBar)
	right_time = (find_child("RightTime", true, false)  as ProgressBar)
	limit      = (find_child("Limit",     true, false)  as Timer)
	book       = (find_child("Book",      true, false)  as AnimatedSprite2D)

	if left_time == null or right_time == null or limit == null:
		push_error("TurnTimer: faltan hijos requeridos: LeftTime/RightTime/Limit.")
		return

	# Config inicial de barras
	for bar in [left_time, right_time]:
		bar.show_percentage = false
		bar.min_value = 0.0
		bar.max_value = total_time
		bar.value = total_time

	# Timer
	limit.one_shot = true
	limit.autostart = false
	limit.wait_time = total_time
	if not limit.timeout.is_connected(_on_limit_timeout):
		limit.timeout.connect(_on_limit_timeout)

	# (Opcional) Detectar TypingPanel para animar el libro en cada nueva ronda
	if typing_panel_path != NodePath(""):
		var tp := get_node_or_null(typing_panel_path)
		if tp is TypingPanel and not tp.round_started.is_connected(_on_round_started):
			tp.round_started.connect(_on_round_started)
	else:
		var maybe_tp := get_tree().root.find_child("TypingPanel", true, false)
		if maybe_tp is TypingPanel and not maybe_tp.round_started.is_connected(_on_round_started):
			maybe_tp.round_started.connect(_on_round_started)

	if autostart_on_ready:
		start(total_time)

	set_process(true)

func _process(_d: float) -> void:
	if _running and limit != null:
		var tl := time_left()
		# Ambas barras muestran el mismo tiempo restante
		left_time.value  = tl
		right_time.value = tl

# =================== API ===================

func start(duration: float = -1.0) -> void:
	if left_time == null or right_time == null or limit == null:
		return
	if duration > 0.0:
		total_time = duration
	for bar in [left_time, right_time]:
		bar.max_value = total_time
		bar.value = total_time
	limit.stop()
	limit.wait_time = total_time
	limit.start()
	_running = true
	started.emit(total_time)

func restart() -> void:
	restart_safe()

func restart_safe() -> void:
	mark_resolved_for_next_frame()
	start(total_time)

func mark_resolved_for_next_frame() -> void:
	_resolved_until_msec = Time.get_ticks_msec() + RESOLVE_WINDOW_MS

func is_resolve_window_open() -> bool:
	return Time.get_ticks_msec() < _resolved_until_msec

func resolve_window_ms_left() -> int:
	return max(_resolved_until_msec - Time.get_ticks_msec(), 0)

func stop() -> void:
	if limit != null:
		limit.stop()
	_running = false

func is_running() -> bool:
	return _running and limit != null and not limit.is_stopped()

func time_left() -> float:
	return (limit.time_left if limit != null else 0.0)

func stop_and_restart_after(delay_sec: float) -> void:
	stop()
	await get_tree().create_timer(delay_sec).timeout
	restart()

# ============== Libro (opcional) ==============

func play_book_next() -> void:
	if book and book.sprite_frames and book.sprite_frames.has_animation(book_next_anim):
		book.play(book_next_anim)

func play_book_mode(_is_attack: bool=true) -> void:
	if book and book.sprite_frames:
		# puedes tener dos anims distintas, p.ej. "mode_attack" / "mode_defend"
		var anim := book_mode_anim
		if book.sprite_frames.has_animation("mode_attack") and book.sprite_frames.has_animation("mode_defend"):
			anim = ("mode_attack" if _is_attack else "mode_defend")
		if book.sprite_frames.has_animation(anim):
			book.play(anim)

# ============== Internos ==============

func _on_limit_timeout() -> void:
	# Evita timeout si el turno acaba de resolverse (score o bloqueo justo al borde)
	if is_resolve_window_open():
		return

	_running = false
	timeout.emit()

	# Bucle autónomo
	if loop:
		if loop_delay > 0.0:
			await get_tree().create_timer(loop_delay).timeout
		start(total_time)

func _on_round_started() -> void:
	# Animación “Next” cuando comienza una nueva palabra en TypingPanel
	play_book_next()
