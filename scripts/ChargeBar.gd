extends ProgressBar
class_name ChargeBar

signal charge_changed(current: float, max_value: float)
signal charged  # emitida al llegar a 100%

@export_node_path("Control") var typing_panel_path: NodePath
var typing: TypingPanel = null

@export var max_charge: float = 100.0
@export var inc_fail: float = 0.0
@export var inc_good: float = 10.0
@export var inc_nice: float = 15.0
@export var inc_perfect: float = 20.0

@export var animate_fill: bool = true
@export var anim_time: float = 0.15

var _tween: Tween = null

func _ready() -> void:
	min_value = 0.0
	max_value = max_charge
	value = clamp(float(value), 0.0, max_charge)
	show_percentage = true
	call_deferred("_wire_typing")

func _wire_typing() -> void:
	# 1) Path (opcional)
	if typing_panel_path != NodePath():
		var n_by_path: Node = get_node_or_null(typing_panel_path)
		if n_by_path is TypingPanel:
			typing = n_by_path as TypingPanel

	# 2) Unique Name %TypingPanel
	if typing == null:
		var n_by_unique: Node = get_node_or_null("%TypingPanel")
		if n_by_unique is TypingPanel:
			typing = n_by_unique as TypingPanel

	# 3) Búsqueda global
	if typing == null:
		var found: Node = get_tree().root.find_child("TypingPanel", true, false)
		if found is TypingPanel:
			typing = found as TypingPanel

	if typing and not typing.score_ready.is_connected(_on_attack_score_ready):
		typing.score_ready.connect(_on_attack_score_ready)
	else:
		push_warning("ChargeBar: no se encontró TypingPanel; no se actualizará la carga.")

func _on_attack_score_ready(rating: String) -> void:
	var delta: float = _inc_for_rating(rating)
	if delta <= 0.0:
		return

	var old: float = float(value)
	var target: float = min(old + delta, max_charge)

	if animate_fill:
		if is_instance_valid(_tween):
			_tween.kill()
		_tween = create_tween()
		_tween.tween_property(self, "value", target, anim_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		value = target

	charge_changed.emit(target, max_charge)

	if old < max_charge and target >= max_charge:
		charged.emit()

func _inc_for_rating(r: String) -> float:
	match r:
		"Perfect": return inc_perfect
		"Nice":    return inc_nice
		"Good":    return inc_good
		"Fail":    return inc_fail
		_:         return 0.0

func is_full() -> bool:
	return float(value) >= max_charge

func consume_full() -> void:
	value = 0.0
	charge_changed.emit(0.0, max_charge)
