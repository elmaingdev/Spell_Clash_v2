extends Control
class_name SpeedPanel

# Usa el tipo del script (no la instancia autoload)
const SM := preload("res://autoloads/SpeedManager.gd")

@export var title_text: String = "RUN TIME"

const LEVEL_TO_LABEL_NODE := {
	"Red Adept": "RedAdeptTime",
	"Sk Mage": "SkMageTime",
}

var _title: Label = null
var _current: Label = null
var _pb_label: Label = null
var _splits_box: VBoxContainer = null
var _split_labels: Dictionary = {}
var _run_timer: RunTimer = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_nodes()

	if _title:
		_title.text = title_text
	if _current and (_current.text == "" or _current.text == null):
		_current.text = "00:00.00"

	_map_split_labels()
	_refresh_all_split_rows()
	_refresh_pb_from_manager()

	var sm := get_node_or_null("/root/SpeedManager")
	if sm and not sm.personal_best_changed.is_connected(_on_pb_changed):
		sm.personal_best_changed.connect(_on_pb_changed)

	call_deferred("_auto_start_run")

func start_run() -> void:
	if _run_timer: _run_timer.start_run()

func stop_run() -> void:
	if _run_timer: _run_timer.stop_run()

func reset_run() -> void:
	if _run_timer:
		_run_timer.reset_run()
		if _current: _current.text = "00:00.00"

func _auto_start_run() -> void:
	if _run_timer:
		_run_timer.start_run()

func _resolve_nodes() -> void:
	_title      = find_child("TitleLabel", true, false) as Label
	_current    = find_child("CurrentTimeLabel", true, false) as Label
	_pb_label   = find_child("PBLabel", true, false) as Label
	_splits_box = find_child("SplitsBox", true, false) as VBoxContainer

	_run_timer = get_node_or_null("RunTimer") as RunTimer
	if _run_timer == null:
		var rt := find_child("RunTimer", true, false)
		if rt is RunTimer:
			_run_timer = rt as RunTimer

func _map_split_labels() -> void:
	_split_labels.clear()
	if _splits_box == null: return
	for level_name in LEVEL_TO_LABEL_NODE.keys():
		var node_name: String = LEVEL_TO_LABEL_NODE[level_name]
		var n := _splits_box.get_node_or_null(node_name)
		if n is Label:
			_split_labels[level_name] = n

func _refresh_all_split_rows() -> void:
	for level_name in _split_labels.keys():
		_set_split_row(level_name, -1, 0, false)

func _set_split_row(level_name: String, best_ms: int, delta_ms: int, improved: bool) -> void:
	var lab := _split_labels.get(level_name, null) as Label
	if lab == null: return
	var base := "%s: %s" % [level_name, (_fmt_ms(best_ms) if best_ms >= 0 else "--:--.--")]
	if improved and delta_ms > 0:
		lab.add_theme_color_override("font_color", Color(0.30, 1.00, 0.30))
		base += "  ( -%s )" % _fmt_ms(delta_ms)
	else:
		if lab.has_theme_color_override("font_color"):
			lab.remove_theme_color_override("font_color")
	lab.text = base

func _refresh_pb_from_manager() -> void:
	if _pb_label == null: return
	var sm := get_node_or_null("/root/SpeedManager")
	var txt := "TOP: --:--.--"
	if sm:
		var pb := int(sm.get("personal_best"))
		if pb >= 0:
			# Llamamos a la función estática desde el TIPO (script preloaded)
			txt = "TOP: %s" % SM.fmt_ms(pb)
	_pb_label.text = txt

func _on_pb_changed(_ms: int) -> void:
	_refresh_pb_from_manager()

# Utilidad local para splits (puedes mantenerla)
static func _fmt_ms(ms: int) -> String:
	if ms < 0: return "--:--.--"
	var msf: float = float(ms)
	var minutes: int    = int(floor(msf / 60000.0))
	var seconds: int    = int(floor(fmod(msf, 60000.0) / 1000.0))
	var hundredths: int = int(floor(fmod(msf, 1000.0) / 10.0))
	return "%02d:%02d.%02d" % [minutes, seconds, hundredths]
