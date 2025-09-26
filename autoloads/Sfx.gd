extends Node

const BUS_SFX: String   = "SFX"    # bus “grupo” (KEY/SCORE/FX le envían a éste)
const BUS_KEY: String   = "KEY"    # clics de teclado
const BUS_SCORE: String = "SCORE"  # perfect/good/nice/fail

const POOL_SIZE_PER_BUS: int = 8

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
var _bus_clicks: String = "Master"
var _bus_scores: String = "Master"
var _pools: Dictionary = {}                    # String (bus) -> Array[AudioStreamPlayer]
var _click_pattern: Array[int] = [0, 1, 2, 3, 2, 1, 0, 1]
var _click_idx: int = 0

# Debounce (tag -> last_ms)
var _last_play_ms: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	randomize()

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
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.bus = bus_name
		p.volume_db = volume_db
		add_child(p)
		arr.append(p)
	_pools[bus_name] = arr

# ================= API =================

## Clic de teclado con patrón y DEBOUNCE (por defecto 18 ms)
func key_click_sfx(cooldown_ms: int = 18) -> void:
	if clicks.is_empty():
		return
	var idx: int = _click_pattern[_click_idx]
	_click_idx = (_click_idx + 1) % _click_pattern.size()
	var pitch: float = _rnd_pitch(click_pitch_jitter)
	_play(clicks[idx], pitch, _bus_clicks, "KEY", cooldown_ms)

## Sonidos de score (Perfect/Nice/Good/Fail) con DEBOUNCE (por defecto 120 ms)
func score_sfx(kind: String, cooldown_ms: int = 120) -> void:
	var k: String = kind.to_lower()
	if not score.has(k):
		return
	var jitter: float = (0.0 if k == "fail" else score_pitch_jitter)
	var pitch: float = _rnd_pitch(jitter)
	_play(score[k], pitch, _bus_scores, "SCORE_" + k, cooldown_ms)

## (Opcional) Reproductor genérico con tag y cooldown
func play_stream_on_bus(stream: AudioStream, bus_name: String, tag: String, pitch: float = 1.0, cooldown_ms: int = 60) -> void:
	if stream == null:
		return
	var bus: String = _best_bus([bus_name, BUS_SFX, "Master"])
	_play(stream, pitch, bus, tag, cooldown_ms)

# =============== Utilidades internas ===============

func _play(stream: AudioStream, pitch: float, bus_name: String, tag: String, cooldown_ms: int) -> void:
	if stream == null:
		return
	if not _can_play(tag, cooldown_ms):
		return
	_init_pool_for_bus(bus_name)
	var pool: Array = _pools[bus_name]  # Diccionario -> Array (usamos Array genérico)
	var p: AudioStreamPlayer = _get_free_player_from_pool(pool, bus_name)
	p.stop()
	p.stream = stream
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

func _get_free_player_from_pool(pool: Array, bus_name: String) -> AudioStreamPlayer:
	for i in pool.size():
		var p: AudioStreamPlayer = pool[i]
		if not p.playing:
			return p
	var np: AudioStreamPlayer = AudioStreamPlayer.new()
	np.bus = bus_name
	np.volume_db = volume_db
	add_child(np)
	pool.append(np)
	return np

func _can_play(tag: String, cooldown_ms: int) -> bool:
	var now: int = Time.get_ticks_msec()
	var last: int = int(_last_play_ms.get(tag, -cooldown_ms))
	if now - last >= cooldown_ms:
		_last_play_ms[tag] = now
		return true
	return false

func _rnd_pitch(amount: float) -> float:
	return 1.0 + randf_range(-amount, amount)
