extends Node


signal personal_best_changed(ms: int)
signal run_time_changed(ms: int)

# -------- persistencia --------
const SAVE_FILE: String   = "user://speed_time.sav"
const SAVE_SECTION: String = "speed"

# -------- estado --------
var run_time: int = 0              # tiempo de la run actual en ms
var personal_best: int = -1        # -1 = aún no hay PB

func _ready() -> void:
	# Carga al iniciar el juego (si el archivo existe)
	load_from_disk()

# ================= API =================
func set_run_time(ms: int) -> void:
	run_time = max(0, int(ms))
	run_time_changed.emit(run_time)
	# opcional: si quieres que siempre quede persistido el último tiempo:
	_save_current_to_disk()

func set_personal_best(ms: int) -> void:
	personal_best = (int(ms) if ms >= 0 else -1)
	personal_best_changed.emit(personal_best)
	# guarda inmediatamente el nuevo PB
	_save_current_to_disk()

func update_personal_best_if_better(current_ms: int) -> bool:
	if current_ms < 0:
		return false
	if personal_best < 0 or current_ms < personal_best:
		set_personal_best(current_ms) # ya guarda
		return true
	return false

# ======== formateo util ========
static func fmt_ms(ms: int) -> String:
	if ms < 0:
		return "--:--.--"
	var msf: float = float(ms)
	var minutes: int    = int(floor(msf / 60000.0))
	var seconds: int    = int(floor(fmod(msf, 60000.0) / 1000.0))
	var hundredths: int = int(floor(fmod(msf, 1000.0) / 10.0))
	return "%02d:%02d.%02d" % [minutes, seconds, hundredths]

# ============= persistencia interna =============
func _save_current_to_disk() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SAVE_SECTION, "personal_best", personal_best)
	cfg.set_value(SAVE_SECTION, "run_time_last", run_time)
	var err := cfg.save(SAVE_FILE)
	if err != OK:
		push_warning("SpeedManager: error al guardar (%s)" % error_string(err))

func load_from_disk() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(SAVE_FILE)
	if err != OK:
		# primera vez o no existe; nada que cargar
		return

	var pb_val := int(cfg.get_value(SAVE_SECTION, "personal_best", -1))
	var last_run := int(cfg.get_value(SAVE_SECTION, "run_time_last", 0))

	# Usa los setters para emitir señales y actualizar UI suscrita
	set_personal_best(pb_val)
	set_run_time(last_run)
