extends Control
class_name TurnTimer

signal timeout
signal started(total_time: float)

var bar: ProgressBar
var limit: Timer
var _running := false

@export var total_time := 5.0
@export var autostart_on_ready := false

func _ready() -> void:
	# Resolver nodos por rutas RELATIVAS
	if has_node("Bar"):
		bar = $"Bar"
	else:
		bar = find_child("Bar", true, false) as ProgressBar

	if has_node("Limit"):
		limit = $"Limit"
	else:
		limit = find_child("Limit", true, false) as Timer

	if bar == null or limit == null:
		push_error("TurnTimer: no encontré 'Bar'(ProgressBar) o 'Limit'(Timer). Revisa nombres o la escena.")
		return

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
	if _running and limit:
		bar.value = time_left()

# ---- API ----
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
	start(total_time)

func stop() -> void:
	if limit:
		limit.stop()
	_running = false

func is_running() -> bool:
	return _running and limit and not limit.is_stopped()

func time_left() -> float:
	return limit.time_left if limit else 0.0

func stop_and_restart_after(delay_sec: float) -> void:
	stop()
	await get_tree().create_timer(delay_sec).timeout
	restart()

func _on_limit_timeout() -> void:
	_running = false
	timeout.emit()
