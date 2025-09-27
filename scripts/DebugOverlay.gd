extends CanvasLayer
class_name DebugOverlay

@export var battle: Node = null
@export var turn_timer: TurnTimer = null
@export var combo_provider: Node = null
@export var enemy_projectiles_group: StringName = &"enemy_projectile"

@export_node_path("Timer") var run_timer_path: NodePath = NodePath("") # SpeedPanel/RunTimer
@export_node_path("Label") var label_path: NodePath = NodePath("")

var _visible: bool = false
var _label: Label = null
var _run_timer: Timer = null

func _ready() -> void:
	visible = false
	_resolve_label()
	_resolve_run_timer()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_debug"):
		_visible = not _visible
		visible = _visible
		get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
	if not visible: return

	var combo: int = 1
	if combo_provider and combo_provider.has_method("get_current"):
		combo = int(combo_provider.call("get_current"))
	else:
		var cc: Node = get_node_or_null("/root/ComboCounter")
		if cc and cc.has_method("get_current"):
			combo = int(cc.call("get_current"))

	var proj_count: int = _count_active_enemy_projectiles()

	var time_left: float = 0.0
	if turn_timer and turn_timer.has_method("time_left"):
		time_left = float(turn_timer.time_left())

	var run_elapsed_ms: int = 0
	var run_active_txt: String = "—"
	if _run_timer:
		if _run_timer.has_method("get_elapsed_ms"):
			run_elapsed_ms = int(_run_timer.call("get_elapsed_ms"))
		if _run_timer.has_method("is_running"):
			run_active_txt = str(bool(_run_timer.call("is_running")))

	if _label:
		_label.text = \
			"Timer: %.2f  |  Combo: %d  |  Enemy Proj: %d\n" % [time_left, combo, proj_count] + \
			"Run: %s  (active: %s)" % [_fmt_ms(run_elapsed_ms), run_active_txt]

# ---- helpers ----
func _resolve_label() -> void:
	if label_path != NodePath(""):
		var n: Node = get_node_or_null(label_path)
		if n is Label:
			_label = n as Label
			return
	var direct: Node = get_node_or_null("Label")
	if direct is Label:
		_label = direct as Label
		return
	for c in get_children():
		if c is Label:
			_label = c as Label
			return
	var l := Label.new()
	l.name = "Label"
	l.text = "DebugOverlay"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = Vector2(12, 12)
	add_child(l)
	_label = l

func _resolve_run_timer() -> void:
	if run_timer_path != NodePath(""):
		var n: Node = get_node_or_null(run_timer_path)
		if n is Timer:
			_run_timer = n as Timer
			return
	# Descubrimiento automático (#RunTimer como Unique Name)
	var rt := get_tree().root.find_child("RunTimer", true, false)
	if rt is Timer:
		_run_timer = rt as Timer

func _count_active_enemy_projectiles() -> int:
	var cnt: int = 0
	var list: Array = get_tree().get_nodes_in_group(String(enemy_projectiles_group))
	for n in list:
		var a: Area2D = n as Area2D
		if a and a.is_inside_tree() and a.monitoring and a.visible and a.collision_layer != 0:
			cnt += 1
	return cnt

static func _fmt_ms(ms: int) -> String:
	if ms < 0: return "--:--.--"
	var msf: float = float(ms)
	var minutes: int    = int(floor(msf / 60000.0))
	var seconds: int    = int(floor(fmod(msf, 60000.0) / 1000.0))
	var hundredths: int = int(floor(fmod(msf, 1000.0) / 10.0))
	return "%02d:%02d.%02d" % [minutes, seconds, hundredths]
