extends Control
class_name ComboPanel

## Apariencia / comportamiento
@export var autohide: bool = true                 # Ocultar todo cuando combo = 0
@export var play_anim_name: String = "on"         # Animación en cada Icon*
@export var pulse_new_icon: bool = true
@export var pulse_scale: float = 1.12
@export var pulse_time: float = 0.12

## Referencias (se auto-resuelven si las dejas vacías)
@export_node_path("HBoxContainer") var icons_box_path: NodePath
@export_node_path("HBoxContainer") var strike_box_path: NodePath
@export_node_path("Label") var count_label_path: NodePath
@export_node_path("Node") var combo_counter_path: NodePath  # Nodo que emite combo_changed/combo_reset

@onready var icons_box: HBoxContainer = null
@onready var strike_box: HBoxContainer = null
@onready var count_lbl: Label = null

var _icons: Array[Node] = []                # Icon1..Icon5 (AnimatedSprite2D o TextureRect)
var _combo_current: int = 0
var _tween_per_icon: Dictionary = {}        # Node -> Tween

func _ready() -> void:
	_wire_nodes()
	_collect_icons()
	# Visibilidad inicial: todo oculto
	_set_all_hidden()
	_sync(0)

func _wire_nodes() -> void:
	# Icons (HBox con Icon1..Icon5)
	if icons_box_path != NodePath():
		icons_box = get_node_or_null(icons_box_path) as HBoxContainer
	if icons_box == null:
		icons_box = ($ComboIcons if has_node("ComboIcons") else (find_child("ComboIcons", true, false) as HBoxContainer))

	# Barra inferior del contador (xN + "Combo")
	if strike_box_path != NodePath():
		strike_box = get_node_or_null(strike_box_path) as HBoxContainer
	if strike_box == null:
		strike_box = ($ComboStrike if has_node("ComboStrike") else (find_child("ComboStrike", true, false) as HBoxContainer))

	# Label del contador
	if count_label_path != NodePath():
		count_lbl = get_node_or_null(count_label_path) as Label
	if count_lbl == null:
		if has_node("ComboStrike/Combo_count"):
			count_lbl = $"ComboStrike/Combo_count"
		else:
			count_lbl = find_child("Combo_count", true, false) as Label

	# Fuente de señales (autoload o nodo en escena)
	var cc: Node = null
	if combo_counter_path != NodePath():
		cc = get_node_or_null(combo_counter_path)
	if cc == null:
		cc = get_node_or_null("/root/ComboCounter")  # autoload (sin class_name)
	if cc == null:
		var g := get_tree().get_nodes_in_group("combo_counter") # por si pusiste al autoload en un grupo
		if not g.is_empty(): cc = g[0]
	if cc == null:
		cc = get_tree().root.find_child("ComboCounter", true, false)

	if cc and cc.has_signal("combo_changed") and not cc.combo_changed.is_connected(_on_combo_changed):
		cc.combo_changed.connect(_on_combo_changed)
	if cc and cc.has_signal("combo_reset") and not cc.combo_reset.is_connected(_on_combo_reset):
		cc.combo_reset.connect(_on_combo_reset)

func _collect_icons() -> void:
	_icons.clear()
	_tween_per_icon.clear()
	if icons_box == null:
		return
	for child: Node in icons_box.get_children():
		if child is AnimatedSprite2D or child is TextureRect or child is CanvasItem:
			_icons.append(child)
	# apaga todo al inicio
	for i in _icons.size():
		_set_icon_on(_icons[i], false, false, false, 0, 0.0)

func _set_all_hidden() -> void:
	if icons_box: icons_box.visible = false
	if strike_box: strike_box.visible = false
	for ic: Node in _icons:
		if ic is CanvasItem:
			(ic as CanvasItem).visible = false
		if ic is AnimatedSprite2D:
			var spr := ic as AnimatedSprite2D
			spr.stop()
			spr.frame = 0
			spr.frame_progress = 0.0

func _on_combo_changed(current: int, _best: int) -> void:
	_sync(current)

func _on_combo_reset() -> void:
	_sync(0)

func _sync(current: int) -> void:
	_combo_current = max(0, current)

	# Ocultar todo si combo = 0
	if _combo_current == 0:
		if autohide:
			_set_all_hidden()
		else:
			# Si no quieres ocultar todo, al menos apaga los iconos
			for ic in _icons:
				_set_icon_on(ic, false, false, false, 0, 0.0)
			if strike_box:
				strike_box.visible = true
			if icons_box:
				icons_box.visible = true
		if count_lbl:
			count_lbl.text = "x0"
		return

	# Mostrar contenedores
	if icons_box: icons_box.visible = true
	if strike_box: strike_box.visible = true

	# Cantidad de iconos encendidos (1..N)
	var should_on: int = min(_combo_current, _icons.size())

	# Busca un icono reproduciendo para sincronizar fase
	var ref_frame: int = 0
	var ref_prog: float = 0.0
	var ref_found: bool = false
	for ic: Node in _icons:
		if ic is AnimatedSprite2D:
			var spr: AnimatedSprite2D = ic as AnimatedSprite2D
			if spr.is_playing():
				ref_frame = spr.frame
				ref_prog  = spr.frame_progress
				ref_found = true
				break

	for i in _icons.size():
		var ic: Node = _icons[i]
		var turn_on: bool = i < should_on
		var is_new: bool = false
		if turn_on and ic is CanvasItem:
			is_new = not (ic as CanvasItem).visible
		_set_icon_on(ic, turn_on, is_new, ref_found, ref_frame, ref_prog)

	# contador
	if count_lbl:
		count_lbl.text = "x" + str(_combo_current)

func _set_icon_on(icon: Node, turn_on: bool, is_new: bool, sync_from_ref: bool, ref_frame: int, ref_prog: float) -> void:
	# Visibilidad
	if icon is CanvasItem:
		(icon as CanvasItem).visible = turn_on

	# AnimatedSprite2D → reproducir / detener y (opcional) sincronizar fase
	if icon is AnimatedSprite2D:
		var spr: AnimatedSprite2D = icon as AnimatedSprite2D
		if turn_on:
			if spr.sprite_frames and spr.sprite_frames.has_animation(play_anim_name):
				spr.play(play_anim_name)
			else:
				spr.play() # anim por defecto si no existe "on"
			if sync_from_ref:
				spr.frame = ref_frame
				spr.frame_progress = ref_prog
		else:
			spr.stop()
			spr.frame = 0
			spr.frame_progress = 0.0

	# Pulso leve al encender NUEVO icono
	if turn_on and is_new and pulse_new_icon and icon is Node2D:
		var n2d: Node2D = icon as Node2D
		# mata tween previo si había
		if _tween_per_icon.has(icon):
			var tw_old: Tween = _tween_per_icon.get(icon)
			if is_instance_valid(tw_old):
				tw_old.kill()
		var tw: Tween = create_tween()
		_tween_per_icon[icon] = tw
		var base: Vector2 = n2d.scale
		tw.tween_property(n2d, "scale", base * pulse_scale, pulse_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(n2d, "scale", base, pulse_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
