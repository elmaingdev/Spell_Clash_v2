# res://scripts/chars/SkeletonMage.gd
extends EnemyBase
class_name SkeletonMage

# ---------- Stats CUSTOM (se aplican si custom_enemy = true en la instancia) ----------
@export var custom_hp: int = 90
@export var custom_damage: int = 10
@export var custom_shoot_interval: float = 5.0
@export_range(0.0, 1.0, 0.01) var custom_block_chance: float = 0.06

# ---------- Parámetros de comportamiento ----------
@export var hp_burst_threshold_ratio: float = 0.5     # 50% de vida
@export var normal_shots_before_pair: int = 3         # tras 3 tiros normales → par especial
@export var special_pair_gap: float = 2.0             # 2s entre cada tiro especial
@export var block_after_half: float = 0.25            # al 50% vida, sube a 25%

# ---------- Estado interno ----------
var _special_sequence_active: bool = false
var _phase_two_on: bool = false
var _half_burst_pending: bool = false
var _normal_shots_since_special: int = 0

func _apply_custom_stats() -> void:
	max_hp = custom_hp
	HP = custom_hp
	projectile_damage = custom_damage
	shoot_interval = custom_shoot_interval
	block_chance = custom_block_chance

# Mientras haya secuencia especial, ignora timeouts del timer normal
func _should_fire_on_timer() -> bool:
	return not _special_sequence_active

# Contar tiros normales para “cada 3 → par especial”
func _after_shoot(_proj: Node2D) -> void:
	if not custom_enemy or is_dead:
		return
	if _special_sequence_active:
		return
	if not _phase_two_on:
		# Antes del 50% no hay repetición periódica del par
		return
	_normal_shots_since_special += 1
	if _normal_shots_since_special >= max(1, normal_shots_before_pair):
		_normal_shots_since_special = 0
		_start_sequence(2, special_pair_gap, special_pair_gap)  # con pre-delay

# Al cruzar el 50%: sube block_chance y lanza un par con gap 2s
func take_dmg(amount: int = 1) -> void:
	var threshold := int(round(max_hp * hp_burst_threshold_ratio))
	var was_above_half := (HP > threshold)
	super.take_dmg(amount)
	if is_dead:
		return

	if not _phase_two_on and was_above_half and HP <= threshold:
		_phase_two_on = true
		block_chance = block_after_half
		# Disparo inicial de fase 2: un par con pre-delay
		if _special_sequence_active:
			_half_burst_pending = true
		else:
			_start_sequence(2, special_pair_gap, special_pair_gap)

# ---------- Secuencias especiales ----------
func _start_sequence(count: int, gap: float, pre_gap: float = -1.0) -> void:
	if is_dead or _special_sequence_active:
		return
	_run_sequence(count, gap, pre_gap)

func _run_sequence(count: int, gap: float, pre_gap: float = -1.0) -> void:
	_special_sequence_active = true

	# Pausa el timer normal (si un timeout ya estaba encolado, _should_fire_on_timer lo ignora)
	if shoot_timer:
		shoot_timer.stop()

	# Pre-delay (evita que el primer tiro especial quede pegado al último tiro normal)
	if pre_gap > 0.0:
		await get_tree().create_timer(pre_gap).timeout

	# Dispara N veces con separación 'gap'
	for i in count:
		if is_dead:
			break
		await attack_and_cast()
		if i < count - 1 and not is_dead:
			await get_tree().create_timer(max(0.0, gap)).timeout

	# Reactiva ciclo normal
	if shoot_timer and not is_dead:
		shoot_timer.start(shoot_interval)

	_special_sequence_active = false
	_normal_shots_since_special = 0

	# Si el burst del 50% quedó pendiente, ejecútalo ahora con pre-delay
	if _half_burst_pending and not is_dead:
		_half_burst_pending = false
		_start_sequence(2, special_pair_gap, special_pair_gap)
