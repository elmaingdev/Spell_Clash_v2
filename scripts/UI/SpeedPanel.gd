# res://scripts/UI/SpeedPanel.gd
extends Control
class_name SpeedPanel

const SM := preload("res://autoloads/SpeedManager.gd")

@export var title_text: String = "RUN TIME"

const LEVEL_TO_LABEL_NODE := {
	"Sk Mage":   "SkMageTime",
	"Witch":     "WitchTime",
	"Adept":     "AdeptTime",
	"Demon Eye": "DemonEyeTime",
}

var _title: Label = null
var _current: Label = null
var _pb_label: Label = null
var _splits_box: VBoxContainer = null
var _split_labels: Dictionary = {}
var _run_timer: RunTimer = null

# ===== Flags (bool) de progreso de la run actual =====
var skmage_done: bool = false
var witch_done: bool = false
var adept_done: bool = false
var demoneye_done: bool = false

# ===== Flags (bool) “mejor que el PB” por split =====
var split_skmage_better_time: bool = false
var split_witch_better_time: bool = false
var split_adept_better_time: bool = false
var split_demoneye_better_time: bool = false

# Color base de cada Label (para restaurar al mostrar PB)
var _base_font_colors: Dictionary = {}  # stage_name -> Color

# Cache de StageFlow
var _flow: Node = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_nodes()

	if _title: _title.text = title_text
	if _current and (_current.text == "" or _current.text == null):
		_current.text = "00:00.00"

	_map_split_labels()

	# 1) Pinta PB (por defecto, sin colores)
	_refresh_all_split_rows()
	_refresh_pb_from_manager()
	_refresh_pb_splits_from_manager()

	# 2) Conecta StageFlow y adopta lo ya completado en esta run
	_flow = get_node_or_null("/root/StageFlow")
	if _flow:
		if _flow.has_signal("stage_cleared") and not _flow.stage_cleared.is_connected(_on_stage_cleared):
			_flow.stage_cleared.connect(_on_stage_cleared)
	_adopt_existing_clears_from_stageflow()

	# 3) Señales de PB (por si el PB cambia)
	var sm := get_node_or_null("/root/SpeedManager")
	if sm:
		if sm.has_signal("personal_best_changed") and not sm.personal_best_changed.is_connected(_on_pb_changed):
			sm.personal_best_changed.connect(_on_pb_changed)
		if sm.has_signal("personal_best_splits_changed") and not sm.personal_best_splits_changed.is_connected(_on_pb_splits_changed):
			sm.personal_best_splits_changed.connect(_on_pb_splits_changed)

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
	if _run_timer == null: return
	var sm := get_node_or_null("/root/SpeedManager")
	var ms := 0
	if sm: ms = int(sm.get("run_time"))
	if ms <= 0:
		if not _run_timer.is_running():
			_run_timer.start_run()
	else:
		_run_timer.continue_from(ms)

func _resolve_nodes() -> void:
	_title      = find_child("TitleLabel", true, false) as Label
	_current    = find_child("CurrentTimeLabel", true, false) as Label
	_pb_label   = find_child("PBLabel", true, false) as Label
	_splits_box = find_child("SplitsBox", true, false) as VBoxContainer
	_run_timer  = find_child("RunTimer", true, false) as RunTimer

func _map_split_labels() -> void:
	_split_labels.clear()
	_base_font_colors.clear()
	if _splits_box == null: return

	for level_name in LEVEL_TO_LABEL_NODE.keys():
		var node_name: String = LEVEL_TO_LABEL_NODE[level_name]
		var lab := _splits_box.get_node_or_null(node_name) as Label
		if lab == null: continue

		# Asegura LabelSettings único por Label
		var base_col: Color = lab.get_theme_color("font_color", "Label")
		if lab.label_settings != null:
			base_col = lab.label_settings.font_color
			var ls := lab.label_settings.duplicate() as LabelSettings
			ls.resource_local_to_scene = true
			lab.label_settings = ls
		else:
			var ls_new := LabelSettings.new()
			ls_new.resource_local_to_scene = true
			ls_new.font_color = base_col
			lab.label_settings = ls_new

		_split_labels[level_name] = lab
		_base_font_colors[level_name] = base_col

# ---------- PB (base) ----------
func _refresh_all_split_rows() -> void:
	for level_name in _split_labels.keys():
		_set_split_row(level_name, -1)

func _set_split_row(level_name: String, best_ms: int) -> void:
	var lab := _split_labels.get(level_name, null) as Label
	if lab == null: return
	lab.text = "%s: %s" % [level_name, _fmt_ms(best_ms)]
	_reset_label_color(level_name)

func _reset_label_color(level_name: String) -> void:
	var lab := _split_labels.get(level_name, null) as Label
	if lab == null: return
	var base_col: Color = _base_font_colors.get(level_name, Color.WHITE)
	# Restauramos color base en LabelSettings (sin tocar fuente/outline)
	lab.label_settings.font_color = base_col

func _apply_label_color(lab: Label, better: bool) -> void:
	# Verde si mejor, rojo si peor
	var col := (Color(0.30, 1.00, 0.30) if better else Color(1.00, 0.30, 0.30))
	lab.label_settings.font_color = col

func _refresh_pb_from_manager() -> void:
	if _pb_label == null: return
	var sm := get_node_or_null("/root/SpeedManager")
	var txt := "TOP: --:--.--"
	if sm:
		var pb := int(sm.get("personal_best"))
		if pb >= 0:
			txt = "TOP: %s" % SM.fmt_ms(pb)
	_pb_label.text = txt

func _refresh_pb_splits_from_manager() -> void:
	var sm := get_node_or_null("/root/SpeedManager")
	if sm == null:
		for k in _split_labels.keys(): _set_split_row(k, -1)
		return
	var v: Variant = sm.get("personal_best_splits")
	if not (v is Dictionary):
		for k in _split_labels.keys(): _set_split_row(k, -1)
		return
	var splits: Dictionary = v as Dictionary
	for name_key in _split_labels.keys():
		var ms_val: int = int(splits.get(name_key, -1))
		_set_split_row(name_key, ms_val)

# ---------- Overlay de la run actual (con colores) ----------
func _adopt_existing_clears_from_stageflow() -> void:
	if _flow == null: return
	var v: Variant = _flow.get("current_splits")
	if not (v is Dictionary): return
	var splits: Dictionary = v as Dictionary
	for stage_name in splits.keys():
		var ms := int(splits[stage_name])
		_mark_done(stage_name, true)
		_update_better_flag(stage_name, ms)
		_show_current_split(stage_name, ms)

func _on_stage_cleared(stage_name: String, run_time_ms: int) -> void:
	_mark_done(stage_name, true)
	_update_better_flag(stage_name, run_time_ms)
	_show_current_split(stage_name, run_time_ms)

func _show_current_split(stage_name: String, ms: int) -> void:
	var lab := _split_labels.get(stage_name, null) as Label
	if lab == null: return
	lab.text = "%s: %s" % [stage_name, _fmt_ms(ms)]
	_apply_label_color(lab, _get_better_flag(stage_name))

func _update_better_flag(stage_name: String, current_ms: int) -> void:
	var pb_ms := _get_pb_split_ms(stage_name)
	var better := false
	if pb_ms >= 0:
		better = (current_ms < pb_ms)
	else:
		better = false
	_set_better_flag(stage_name, better)

func _get_pb_split_ms(stage_name: String) -> int:
	var sm := get_node_or_null("/root/SpeedManager")
	if sm == null: 
		return -1
	var v: Variant = sm.get("personal_best_splits")
	if not (v is Dictionary): 
		return -1
	var splits: Dictionary = v as Dictionary
	return int(splits.get(stage_name, -1))

func _set_better_flag(stage_name: String, better: bool) -> void:
	match stage_name:
		"Sk Mage":   split_skmage_better_time   = better
		"Witch":     split_witch_better_time    = better
		"Adept":     split_adept_better_time    = better
		"Demon Eye": split_demoneye_better_time = better
		_: pass

func _get_better_flag(stage_name: String) -> bool:
	match stage_name:
		"Sk Mage":   return split_skmage_better_time
		"Witch":     return split_witch_better_time
		"Adept":     return split_adept_better_time
		"Demon Eye": return split_demoneye_better_time
		_:           return false

func _mark_done(stage_name: String, v: bool) -> void:
	match stage_name:
		"Sk Mage":   skmage_done   = v
		"Witch":     witch_done    = v
		"Adept":     adept_done    = v
		"Demon Eye": demoneye_done = v
		_: pass

# ---------- PB callbacks ----------
func _on_pb_changed(_ms: int) -> void:
	_refresh_pb_from_manager()

func _on_pb_splits_changed(_splits: Dictionary) -> void:
	# Redibuja PB y vuelve a superponer lo avanzado de esta run (con colores)
	_refresh_pb_splits_from_manager()
	_adopt_existing_clears_from_stageflow()

# ---------- utils ----------
static func _fmt_ms(ms: int) -> String:
	if ms < 0: return "--:--.--"
	var msf: float = float(ms)
	var minutes: int    = int(floor(msf / 60000.0))
	var seconds: int    = int(floor(fmod(msf, 60000.0) / 1000.0))
	var hundredths: int = int(floor(fmod(msf, 1000.0) / 10.0))
	return "%02d:%02d.%02d" % [minutes, seconds, hundredths]
