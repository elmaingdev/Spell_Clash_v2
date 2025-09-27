extends Timer
class_name RunTimer

@export_node_path("Label") var current_label_path: NodePath
var _label: Label = null

@export var tick_interval: float = 0.05  # 50 ms

var _running: bool = false
var _start_msec: int = 0
var _elapsed_before_pause: int = 0

func _ready() -> void:
	# Resolver label destino
	if current_label_path != NodePath(""):
		var n: Node = get_node_or_null(current_label_path)
		if n is Label:
			_label = n as Label
	if _label == null:
		var parent_ctrl := get_parent()
		if parent_ctrl:
			_label = parent_ctrl.find_child("CurrentTimeLabel", true, false) as Label

	# Auto-tick
	wait_time = tick_interval
	one_shot = false
	autostart = true
	if not timeout.is_connected(_on_tick):
		timeout.connect(_on_tick)

	reset_run()
	start()

func _on_tick() -> void:
	if not _running:
		return
	var ms: int = _elapsed_before_pause + (Time.get_ticks_msec() - _start_msec)
	_set_label(ms)

# ===== API =====
func start_run() -> void:
	_elapsed_before_pause = 0
	_start_msec = Time.get_ticks_msec()
	_running = true
	if is_stopped():
		start()

func stop_run() -> void:
	if not _running: return
	_elapsed_before_pause += (Time.get_ticks_msec() - _start_msec)
	_running = false

func reset_run() -> void:
	_running = false
	_elapsed_before_pause = 0
	_start_msec = Time.get_ticks_msec()
	_set_label(0)

func get_elapsed_ms() -> int:
	return _elapsed_before_pause + (Time.get_ticks_msec() - _start_msec) if _running else _elapsed_before_pause

func is_running() -> bool:
	return _running

# ===== util =====
func _set_label(ms: int) -> void:
	if _label:
		_label.text = _fmt_ms(ms)

static func _fmt_ms(ms: int) -> String:
	if ms < 0: ms = 0
	var msf: float = float(ms)
	var minutes: int    = int(floor(msf / 60000.0))
	var seconds: int    = int(floor(fmod(msf, 60000.0) / 1000.0))
	var hundredths: int = int(floor(fmod(msf, 1000.0) / 10.0))
	return "%02d:%02d.%02d" % [minutes, seconds, hundredths]
