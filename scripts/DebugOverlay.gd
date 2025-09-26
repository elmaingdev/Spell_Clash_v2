extends CanvasLayer
class_name DebugOverlay

@export var battle: Node = null
@export var turn_timer: TurnTimer = null          # tu TurnTimer.gd
@export var combo_provider: Node = null           # algo que exponga get_current()
@export var enemy_projectiles_group: StringName = &"enemy_projectile"
@export_node_path("Label") var label_path: NodePath

var _visible: bool = false
var _label: Label = null

func _ready() -> void:
	# Arranca oculto, independiente de cómo se guardó la escena
	_visible = false
	visible = false
	_resolve_label()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_debug"): # F3 -> ui_debug
		_visible = not _visible
		visible = _visible
		get_viewport().set_input_as_handled()  # evita propagación

func _process(_dt: float) -> void:
	if not visible:
		return

	# --- Combo ---
	var combo: int = 1
	if combo_provider and combo_provider.has_method("get_current"):
		combo = int(combo_provider.call("get_current"))
	else:
		var cc: Node = get_node_or_null("/root/ComboCounter")
		if cc and cc.has_method("get_current"):
			combo = int(cc.call("get_current"))

	# --- Proyectiles enemigos ACTIVOS ---
	var proj_count: int = _count_active_enemy_projectiles()

	# --- Timer (método time_left()) ---
	var time_left: float = 0.0
	if turn_timer and turn_timer.has_method("time_left"):
		time_left = float(turn_timer.time_left())

	# --- Candado anti-doble-evento (desde TurnTimer) ---
	var guard_on: bool = false
	var guard_ms_left: int = 0
	if turn_timer:
		if turn_timer.has_method("is_resolve_window_open"):
			guard_on = bool(turn_timer.is_resolve_window_open())
		if turn_timer.has_method("resolve_window_ms_left"):
			guard_ms_left = int(turn_timer.resolve_window_ms_left())

	if _label:
		_label.text = "Timer: %.2f\nCombo: %d\nEnemy Proj: %d\nCandado: %s (%dms)" % [
			time_left, combo, proj_count, str(guard_on), guard_ms_left
		]

# ---------- helpers ----------
func _resolve_label() -> void:
	# 1) Por export
	if label_path != NodePath(""):
		var n: Node = get_node_or_null(label_path)
		if n is Label:
			_label = n as Label
			return

	# 2) Hijo llamado "Label"
	var direct: Node = get_node_or_null("Label")
	if direct is Label:
		_label = direct as Label
		return

	# 3) Primer Label entre mis hijos
	for c in get_children():
		if c is Label:
			_label = c as Label
			return

	# 4) Fallback: crear uno
	var l := Label.new()
	l.name = "Label"
	l.text = "DebugOverlay"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 0.0
	l.anchor_top = 0.0
	l.anchor_right = 0.0
	l.anchor_bottom = 0.0
	l.position = Vector2(12, 12)
	add_child(l)
	_label = l

func _count_active_enemy_projectiles() -> int:
	var cnt: int = 0
	var list: Array = get_tree().get_nodes_in_group(String(enemy_projectiles_group))
	for n in list:
		var a: Area2D = n as Area2D
		if a and a.is_inside_tree() and a.monitoring and a.visible and a.collision_layer != 0:
			cnt += 1
	return cnt
