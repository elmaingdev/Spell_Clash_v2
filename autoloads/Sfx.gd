extends Node

const BUS_SFX   := "SFX"    # bus “grupo” (KEY/SCORE/FX le envían a éste)
const BUS_KEY   := "KEY"    # clics de teclado
const BUS_SCORE := "SCORE"  # perfect/good/nice/fail

const POOL_SIZE_PER_BUS := 8

var volume_db: float = 0.0
var score_pitch_jitter: float = 0.02
var click_pitch_jitter: float = 0.03

var score: Dictionary = {
	"fail":    preload("res://assets/sfx/fail_sfx.wav"),
	"good":    preload("res://assets/sfx/good_sfx.wav"),
	"nice":    preload("res://assets/sfx/nice_sfx.wav"),
	"perfect": preload("res://assets/sfx/perfect_sfx.wav"),
}

var clicks: Array[AudioStream] = [
	preload("res://assets/sfx/click_1.wav"),
	preload("res://assets/sfx/click_2.wav"),
	preload("res://assets/sfx/click_3.wav"),
	preload("res://assets/sfx/click_4.wav"),
]

# --- Internos ---
var _bus_clicks := "Master"
var _bus_scores := "Master"
var _pools := {}  # String (bus) -> Array[AudioStreamPlayer]
var _click_pattern: Array[int] = [0,1,2,3,2,1,0,1]
var _click_idx: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	randomize()

	# Si existen KEY/SCORE los usamos; si no, caemos a SFX; si tampoco, Master.
	_bus_clicks = _best_bus([BUS_KEY, BUS_SFX, "Master"])
	_bus_scores = _best_bus([BUS_SCORE, BUS_SFX, "Master"])

	_init_pool_for_bus(_bus_clicks)
	_init_pool_for_bus(_bus_scores)

func _best_bus(candidates: Array[String]) -> String:
	for b in candidates:
		if AudioServer.get_bus_index(b) != -1:
			return b
	return "Master"

func _init_pool_for_bus(bus_name: String) -> void:
	if _pools.has(bus_name):
		return
	var arr: Array[AudioStreamPlayer] = []
	for i in range(POOL_SIZE_PER_BUS):
		var p := AudioStreamPlayer.new()
		p.bus = bus_name
		p.volume_db = volume_db
		add_child(p)
		arr.append(p)
	_pools[bus_name] = arr

# ================= API =================
func key_click_sfx() -> void:
	if clicks.is_empty(): return
	var idx: int = _click_pattern[_click_idx]
	_click_idx = (_click_idx + 1) % _click_pattern.size()
	_play(clicks[idx], _rnd_pitch(click_pitch_jitter), _bus_clicks)

func score_sfx(kind: String) -> void:
	var k := kind.to_lower()
	if not score.has(k): return
	var jitter := 0.0 if k == "fail" else score_pitch_jitter
	_play(score[k], _rnd_pitch(jitter), _bus_scores)

# =============== Utilidades ===============
func _play(stream: AudioStream, pitch: float, bus_name: String) -> void:
	if stream == null: return
	_init_pool_for_bus(bus_name)
	var p := _get_free_player(bus_name)
	p.stop()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func _get_free_player(bus_name: String) -> AudioStreamPlayer:
	var pool: Array = _pools[bus_name]
	for p in pool:
		if not p.playing:
			return p
	var np := AudioStreamPlayer.new()
	np.bus = bus_name
	np.volume_db = volume_db
	add_child(np)
	pool.append(np)
	return np

func _rnd_pitch(amount: float) -> float:
	return 1.0 + randf_range(-amount, amount)
