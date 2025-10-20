extends Control
class_name ComboPanel

## Apariencia / comportamiento
@export var autohide: bool = true         # Ocultar contenedores cuando combo = 0
@export var play_anim_name: String = "on" # Animación de Icon1..Icon5
@export var pulse_new_icon: bool = true
@export var pulse_scale: float = 1.12
@export var pulse_time: float = 0.12
@export var debug_log: bool = false

## Referencias (opcionalmente asignables por Inspector)
@export_node_path("VBoxContainer") var icons_box_path: NodePath
@export_node_path("HBoxContainer") var strike_box_path: NodePath
@export_node_path("Label") var count_label_path: NodePath
@export_node_path("Label") var combo_label_path: NodePath
@export_node_path("Node") var combo_counter_path: NodePath  # Autoload o nodo en escena

@onready var icons_box: VBoxContainer = null
@onready var strike_box: HBoxContainer = null
@onready var count_lbl: Label = null
@onready var combo_lbl: Label = null

var _icons: Array[AnimatedSprite2D] = []   # Icon1..Icon5
var _combo_current: int = 0
var _tween_per_icon: Dictionary = {}       # Node2D -> Tween

func _ready() -> void:
	_wire_nodes()
	_collect_icons()
	_set_all_hidden()
	_connect_combo_counter()
	_sync(0)

# ---------------- Wiring de nodos hijos ----------------
func _wire_nodes() -> void:
	# ComboIcons (VBoxContainer)
	if icons_box_path != NodePath():
		icons_box = get_node_or_null(icons_box_path) as VBoxContainer
	if icons_box == null:
		if has_node("ComboIcons"):
			icons_box = $"ComboIcons"
		else:
			icons_box = find_child("ComboIcons", true, false) as VBoxContainer

	# ComboStrike (HBoxContainer)
	if strike_box_path != NodePath():
		strike_box = get_node_or_null(strike_box_path) as HBoxContainer
	if strike_box == null:
		if has_node("ComboStrike"):
			strike_box = $"ComboStrike"
		else:
			strike_box = find_child("ComboStrike", true, false) as HBoxContainer

	# Label del número (Combo_count)
	if count_label_path != NodePath():
		count_lbl = get_node_or_null(count_label_path) as Label
	if count_lbl == null:
		if has_node("ComboStrike/Combo_count"):
			count_lbl = $"ComboStrike/Combo_count"
		else:
			count_lbl = find_child("Combo_count", true, false) as Label

	# Label del texto “Combo” (Combo_label)
	if combo_label_path != NodePath():
		combo_lbl = get_node_or_null(combo_label_path) as Label
	if combo_lbl == null:
		if has_node("ComboStrike/Combo_label"):
			combo_lbl = $"ComboStrike/Combo_label"
		else:
			combo_lbl = find_child("Combo_label", true, false) as Label

func _collect_icons() -> void:
	_icons.clear()
	_tween_per_icon.clear()
	if icons_box == null:
		return
	for child in icons_box.get_children():
		if child is AnimatedSprite2D:
			_icons.append(child as AnimatedSprite2D)
	for spr in _icons:
		_icon_set_visible(spr, false)

func _set_all_hidden() -> void:
	if icons_box: icons_box.visible = false
	if strike_box: strike_box.visible = false
	if count_lbl: count_lbl.visible = false
	if combo_lbl: combo_lbl.visible = false
	for spr in _icons:
		_icon_set_visible(spr, false)

# ---------------- Conexión a ComboCounter (autoload) ----------------
func _connect_combo_counter() -> void:
	var cc: Node = null
	# 1) Path directo (Inspector)
	if combo_counter_path != NodePath():
		cc = get_node_or_null(combo_counter_path)
	# 2) Autoload por ruta absoluta
	if cc == null:
		cc = get_node_or_null("/root/ComboCounter")
	# 3) Grupo alternativo
	if cc == null:
		var g := get_tree().get_nodes_in_group("combo_counter")
		if not g.is_empty():
			cc = g[0]
	# 4) Búsqueda por nombre/clase
	if cc == null:
		cc = get_tree().root.find_child("ComboCounter", true, false)

	if cc:
		# Forma robusta por string (evita problemas de tipado de señal)
		var cb1 := Callable(self, "_on_combo_changed")
		var cb2 := Callable(self, "_on_combo_reset")
		if not cc.is_connected("combo_changed", cb1):
			cc.connect("combo_changed", cb1)
		if not cc.is_connected("combo_reset", cb2):
			cc.connect("combo_reset", cb2)

		if debug_log:
			print("[ComboPanel] Conectado a ComboCounter =", cc)
	else:
		push_warning("ComboPanel: no encontré ComboCounter (autoload). El panel no se actualizará.")

# ---------------- Callbacks del contador ----------------
func _on_combo_changed(current: int, _best: int) -> void:
	_sync(current)

func _on_combo_reset() -> void:
	_sync(0)

# ---------------- Render del estado ----------------
func _sync(current: int) -> void:
	_combo_current = max(0, current)
	var has_combo: bool = (_combo_current > 0)

	# Contenedores
	if strike_box:
		strike_box.visible = (has_combo or not autohide)
	if icons_box:
		icons_box.visible = (has_combo or not autohide)

	# Labels
	if combo_lbl:
		combo_lbl.visible = has_combo
	if count_lbl:
		count_lbl.visible = true
		count_lbl.text = "x" + str(_combo_current)

	# Iconos encendidos según combo actual
	var should_on: int = min(_combo_current, _icons.size())

	# Referencia de fase (si alguno ya está reproduciendo)
	var ref_found: bool = false
	var ref_frame: int = 0
	var ref_prog: float = 0.0
	for spr in _icons:
		if spr.is_playing():
			ref_found = true
			ref_frame = spr.frame
			ref_prog = spr.frame_progress
			break

	for i in _icons.size():
		var spr: AnimatedSprite2D = _icons[i]
		var turn_on: bool = (i < should_on)
		var was_visible: bool = spr.visible
		_icon_set_visible(spr, turn_on)

		if turn_on:
			if spr.sprite_frames and spr.sprite_frames.has_animation(play_anim_name):
				spr.play(play_anim_name)
			else:
				spr.play()
			if ref_found and not was_visible:
				spr.frame = ref_frame
				spr.frame_progress = ref_prog
			if pulse_new_icon and not was_visible:
				_pulse(spr)
		else:
			spr.stop()
			spr.frame = 0
			spr.frame_progress = 0.0

# ---------------- Utilidades ----------------
func _icon_set_visible(spr: AnimatedSprite2D, on: bool) -> void:
	spr.visible = on

func _pulse(node: Node2D) -> void:
	if _tween_per_icon.has(node):
		var old: Tween = (_tween_per_icon[node] as Tween)
		if is_instance_valid(old):
			old.kill()
	var tw: Tween = create_tween()
	_tween_per_icon[node] = tw
	var base: Vector2 = node.scale
	tw.tween_property(node, "scale", base * pulse_scale, pulse_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base,           pulse_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
