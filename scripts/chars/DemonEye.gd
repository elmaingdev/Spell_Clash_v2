# res://scripts/chars/DemonEye.gd
extends EnemyBase
class_name DemonEye

# ---------- Stats CUSTOM ----------
@export var custom_hp: int = 360
@export var custom_damage: int = 16
@export var custom_shoot_interval: float = 3.8
@export_range(0.0, 1.0, 0.01) var custom_block_chance: float = 0.30

# ---------- Patrón especial: tras 3 tiros propios → 3 con gap 2s ----------
@export var normal_shots_before_triplet: int = 3
@export var triplet_gap: float = 2.0

# ---------- Blindaje reactivo: tras 3 impactos → bloquear 2 al 100% ----------
@export var hits_to_trigger_forced_blocks: int = 3
@export var forced_blocks_count: int = 2

# ---------- Fase 2 (50% de vida) ----------
@export var hp_threshold_ratio: float = 0.5
@export var phase2_block_chance: float = 0.40
@export var phase2_shoot_interval: float = 3.4

# ---------- Estado interno ----------
var _special_sequence_active: bool = false
var _normal_shots_since_special: int = 0

var _impacts_count: int = 0
var _forced_blocks_remaining: int = 0
var _forced_block_pending: Dictionary = {}  # proj_id -> true

var _phase_two_applied: bool = false

func _apply_custom_stats() -> void:
	max_hp = custom_hp
	HP = custom_hp
	projectile_damage = custom_damage
	shoot_interval = custom_shoot_interval
	block_chance = custom_block_chance

# Evita que el timer dispare durante la secuencia
func _should_fire_on_timer() -> bool:
	return not _special_sequence_active

# Disparos propios → cada 3, tripleta con gap 2s (y pre-gap 2s)
func _after_shoot(_proj: Node2D) -> void:
	if not custom_enemy or is_dead:
		return
	if _special_sequence_active:
		return
	_normal_shots_since_special += 1
	if _normal_shots_since_special >= max(1, normal_shots_before_triplet):
		_normal_shots_since_special = 0
		_start_sequence(3, triplet_gap, triplet_gap)  # pre-gap=2s, gap=2s

# Impactos recibidos → activar bloqueos forzados (100%) para N proyectiles
# + Fase 2 (50%): más bloqueo y cadencia más rápida
func take_dmg(amount: int = 1) -> void:
	var threshold := int(round(max_hp * hp_threshold_ratio))
	var was_above_half: bool = (HP > threshold)

	if amount > 0:
		_impacts_count += 1
		if _impacts_count >= max(1, hits_to_trigger_forced_blocks):
			_impacts_count = 0
			_forced_blocks_remaining = forced_blocks_count

	super.take_dmg(amount)
	if is_dead:
		return

	if not _phase_two_applied and was_above_half and HP <= threshold:
		_phase_two_applied = true
		block_chance = phase2_block_chance
		shoot_interval = phase2_shoot_interval
		if shoot_timer and not _special_sequence_active:
			shoot_timer.stop()
			shoot_timer.wait_time = shoot_interval
			shoot_timer.start(shoot_interval)
		elif shoot_timer:
			shoot_timer.wait_time = shoot_interval

# Hook del spawn de proyectil del jugador → bloqueos forzados primero
func on_player_projectile_spawned(proj: Node) -> void:
	if is_dead or proj == null or not is_instance_valid(proj):
		return

	if _forced_blocks_remaining > 0:
		var id: int = proj.get_instance_id()
		if _forced_block_pending.has(id):
			return
		_forced_block_pending[id] = true
		_schedule_forced_block(proj, id)
		return

	super.on_player_projectile_spawned(proj)

func _schedule_forced_block(proj: Node, proj_id: int) -> void:
	await get_tree().create_timer(max(0.0, block_interval)).timeout
	_forced_block_pending.erase(proj_id)
	if is_dead or proj == null or not is_instance_valid(proj):
		return
	await _play_block_anim()
	_block_projectile(proj)
	if _forced_blocks_remaining > 0:
		_forced_blocks_remaining -= 1

# ---------- Secuencias especiales (idéntico enfoque que Adept) ----------
func _start_sequence(count: int, gap: float, pre_gap: float = -1.0) -> void:
	if is_dead or _special_sequence_active:
		return
	_run_sequence(count, gap, pre_gap)

func _run_sequence(count: int, gap: float, pre_gap: float = -1.0) -> void:
	_special_sequence_active = true

	if shoot_timer:
		shoot_timer.stop()

	if pre_gap > 0.0:
		await get_tree().create_timer(pre_gap).timeout

	for i in count:
		if is_dead:
			break
		await attack_and_cast()
		if i < count - 1 and not is_dead:
			await get_tree().create_timer(max(0.0, gap)).timeout

	if shoot_timer and not is_dead:
		shoot_timer.start(shoot_interval)

	_special_sequence_active = false
	_normal_shots_since_special = 0
