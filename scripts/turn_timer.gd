extends Control
class_name TurnTimer

signal timeout
signal started(total_time: float)

@onready var bar: ProgressBar = %Bar
@onready var limit: Timer     = %Limit

@export var total_time: float = 5.0
@export var autostart_on_ready: bool = false  # ← importante: el panel controla el inicio

func _ready() -> void:
	if bar == null:
		push_error("TurnTimer: %Bar no encontrado.")
		return
	if limit == null:
		push_error("TurnTimer: %Limit no encontrado.")
		return

	bar.min_value = 0.0
	bar.max_value = total_time
	bar.value = total_time
	bar.show_percentage = false

	limit.one_shot = true
	limit.autostart = false
	limit.wait_time = total_time
	if not limit.timeout.is_connected(_on_limit_timeout):
		limit.timeout.connect(_on_limit_timeout)

	if autostart_on_ready:
		start(total_time)

func _process(_delta: float) -> void:
	if limit and not limit.is_stopped():
		bar.value = limit.time_left

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
	started.emit(total_time)

func stop() -> void:
	if limit:
		limit.stop()
	if bar:
		bar.value = 0.0

func is_running() -> bool:
	return limit != null and not limit.is_stopped()

func time_left() -> float:
	return limit.time_left if limit else 0.0

func _on_limit_timeout() -> void:
	timeout.emit()
