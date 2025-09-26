extends Control
class_name TurnTimer

signal timeout
signal started(total_time: float)

@onready var bar: ProgressBar = null
@onready var limit: Timer = null

@export var total_time: float = 5.0
@export var autostart_on_ready: bool = false

# Modo bucle independiente
@export var loop: bool = true
@export var loop_delay: float = 0.0  # si quieres una micro-pausa visual (p.ej. 0.25)

var _running: bool = false

# --- Ventana anti-race (ignora timeout si acabas de resolver el turno) ---
const RESOLVE_WINDOW_MS: int = 30
var _resolved_until_msec: int = 0

func _ready() -> void:
	# Resolver nodos hijos
	if has_node("Bar"):
		bar = $"Bar"
	else:
		var b: Node = find_child("Bar", true, false)
		if b is ProgressBar:
			bar = b

	if has_node("Limit"):
		limit = $"Limit"
	else:
		var t: Node = find_child("Limit", true, false)
		if t is Timer:
			limit = t

	if bar == null or limit == null:
		push_error("TurnTimer: no encontré 'Bar'(ProgressBar) o 'Limit'(Timer).")
		return

	# Config inicial
	bar.show_percentage = false
	bar.min_value = 0.0
	bar.max_value = total_time
	bar.value = total_time

	limit.one_shot = true
	limit.autostart = false
	limit.wait_time = total_time

	if not limit.timeout.is_connected(_on_limit_timeout):
		limit.timeout.connect(_on_limit_timeout)

	if autostart_on_ready:
		start(total_time)

func _process(_d: float) -> void:
	if _running and limit != null:
		bar.value = time_left()

# =================== API ===================

func start(duration: float = -1.0) -> void:
	if bar == null or limit == null:
		return
	if duration > 0.0:
		total_time = duration
	bar.max_value = total_time
	bar.value = total_time
	limit.stop()
	limit.wait_time = total_time
	limit.start()
	_running = true
	started.emit(total_time)

func restart() -> void:
	# Compat: usa la versión segura
	restart_safe()

func restart_safe() -> void:
	# Marca resuelto para ignorar un posible timeout “cruzado”
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

# ============== Internos ==============

func _on_limit_timeout() -> void:
	# Si el turno quedó “resuelto” hace nada, ignora este timeout
	if is_resolve_window_open():
		return

	_running = false
	timeout.emit()

	# Bucle autónomo
	if loop:
		if loop_delay > 0.0:
			await get_tree().create_timer(loop_delay).timeout
		start(total_time)
