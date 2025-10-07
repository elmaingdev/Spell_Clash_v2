extends Node

signal personal_best_changed(ms: int)
signal personal_best_splits_changed(splits: Dictionary)

var run_time: int = 0                     # ms de la run en curso
var personal_best: int = -1               # ms del PB (−1 si no existe)
var personal_best_splits: Dictionary = {} # { "Sk Mage": ms, "Witch": ms, ... }

# ---------- Utils ----------
static func fmt_ms(ms: int) -> String:
	if ms < 0: return "--:--.--"
	var msf := float(ms)
	var minutes := int(floor(msf / 60000.0))
	var seconds := int(floor(fmod(msf, 60000.0) / 1000.0))
	var hundredths := int(floor(fmod(msf, 1000.0) / 10.0))
	return "%02d:%02d.%02d" % [minutes, seconds, hundredths]

# ---------- Run time ----------
func set_run_time(ms: int) -> void:
	run_time = max(0, ms)

func get_run_time() -> int:
	return run_time

# ---------- PB total ----------
func set_personal_best(ms: int) -> void:
	personal_best = ms
	personal_best_changed.emit(ms)

func update_personal_best_if_better(ms: int) -> bool:
	var improved := (personal_best < 0 or ms < personal_best)
	if improved:
		personal_best = ms
		personal_best_changed.emit(ms)
	return improved

# ---------- PB splits ----------
func set_personal_best_splits(splits: Dictionary) -> void:
	# Clonamos para no compartir referencias
	personal_best_splits = splits.duplicate(true)
	personal_best_splits_changed.emit(personal_best_splits)

func get_personal_best_splits() -> Dictionary:
	return personal_best_splits
