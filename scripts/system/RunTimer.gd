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

	# Auto-tick (este Timer sólo “tiquea” la UI; no controla el tiempo de juego)
	wait_time = tick_interval
	one_shot = false
	autostart = true
	if not timeout.is_connected(_on_tick):
		timeout.connect(_on_tick)

	# Pinta el tiempo actual si viene de SpeedManager (por ejemplo al entrar a otra stage)
	var sm := get_node_or_null("/root/SpeedManager")
	if sm:
		var ms0: int = int(sm.get("run_time"))
		_elapsed_before_pause = ms0
		_set_label(ms0)

	start() # inicia el tiqueo del label

func _on_tick() -> void:
	if not _running:
		return
	var ms: int = _elapsed_before_pause + (Time.get_ticks_msec() - _start_msec)
	_set_label(ms)

	# Sincroniza con SpeedManager para que las nuevas stages continúen
	var sm := get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_run_time", ms)

# ===== API =====
func start_run() -> void:
	# Comienzo de run → resetea el acumulado tanto local como en SpeedManager
	_elapsed_before_pause = 0
	_start_msec = Time.get_ticks_msec()
	_running = true
	var sm := get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_run_time", 0)
	if is_stopped():
		start()

func continue_from(ms: int) -> void:
	# Continúa una run ya en progreso (p.ej. tras cambiar de escena)
	_elapsed_before_pause = max(0, ms)
	_start_msec = Time.get_ticks_msec()
	_running = true
	_set_label(ms)
	if is_stopped():
		start()

func stop_run() -> void:
	if not _running: return
	_elapsed_before_pause += (Time.get_ticks_msec() - _start_msec)
	_running = false
	# No tocamos SpeedManager: queda con el último valor

func reset_run() -> void:
	_running = false
	_elapsed_before_pause = 0
	_start_msec = Time.get_ticks_msec()
	_set_label(0)
	var sm := get_node_or_null("/root/SpeedManager")
	if sm:
		sm.call("set_run_time", 0)

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
