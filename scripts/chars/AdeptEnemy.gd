# res://scripts/chars/AdeptEnemy.gd
extends EnemyBase
class_name AdeptEnemy

# ---------- Stats CUSTOM (se aplican si custom_enemy = true en la instancia) ----------
@export var custom_hp: int = 100
@export var custom_damage: int = 10
@export var custom_shoot_interval: float = 5.0
@export_range(0.0, 1.0, 0.01) var custom_block_chance: float = 0.0
# Nota: block_interval ya NO es custom; usa el de EnemyBase (0.3s)

# ---------- Patrón especial ----------
@export var normal_shots_before_triple: int = 3   # tras 3 tiros normales → secuencia
@export var triple_gap: float = 2.0               # 2s entre cada tiro especial
@export var hp_threshold_ratio: float = 0.5       # 50% de vida
@export var shoot_interval_after_half: float = 4.0

# ---------- Estado interno ----------
var _special_sequence_active: bool = false
var _normal_shots_since_special: int = 0
var _phase_two_applied: bool = false

func _apply_custom_stats() -> void:
	max_hp = custom_hp
	HP = custom_hp
	projectile_damage = custom_damage
	shoot_interval = custom_shoot_interval
	block_chance = custom_block_chance
	# (no tocamos block_interval: se usa el de EnemyBase)

# Ignora timeouts mientras corre la secuencia especial
func _should_fire_on_timer() -> bool:
	return not _special_sequence_active

# Contar tiros normales para “cada 3 → triple con gap 2s”
func _after_shoot(_proj: Node2D) -> void:
	if not custom_enemy or is_dead:
		return
	if _special_sequence_active:
		return
	_normal_shots_since_special += 1
	if _normal_shots_since_special >= max(1, normal_shots_before_triple):
		_normal_shots_since_special = 0
		_start_sequence(3, triple_gap, triple_gap)  # con pre-delay

# Umbral de 50% de vida → reduce intervalo a 4s (fase 2)
func take_dmg(amount: int = 1) -> void:
	var threshold := int(round(max_hp * hp_threshold_ratio))
	var was_above_half := (HP > threshold)
	super.take_dmg(amount)

	if is_dead:
		return

	if not _phase_two_applied and was_above_half and HP <= threshold:
		_phase_two_applied = true
		shoot_interval = shoot_interval_after_half
		# Reconfigura el timer de inmediato si no hay secuencia en curso
		if shoot_timer and not _special_sequence_active:
			shoot_timer.stop()
			shoot_timer.wait_time = shoot_interval
			shoot_timer.start(shoot_interval)
		elif shoot_timer:
			shoot_timer.wait_time = shoot_interval

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

	# Pre-delay para que no se pegue al último tiro normal
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
