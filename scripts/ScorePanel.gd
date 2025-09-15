extends Control
class_name ScorePanel

@onready var score1: Control = $Score1
@onready var score2: Control = $Score2
@onready var score3: Control = $Score3
@onready var lbl1: Label = $Score1/Score_lbl1
@onready var lbl2: Label = $Score2/Score_lbl2
@onready var lbl3: Label = $Score3/Score_lbl3

@export_node_path("Control") var typing_panel_path
@export var auto_hide: bool = true
@export var hide_delay: float = 1.0

# Paleta (puedes ajustarla en el Inspector)
@export var color_fail:    Color = Color8(255, 80, 80)     # rojo
@export var color_good:    Color = Color8(46, 204, 113)    # verde
@export var color_nice:    Color = Color8(52, 152, 219)    # azul
@export var color_perfect: Color = Color8(155, 89, 182)    # morado

var _toggle_side := false  # alterna Good/Nice entre lbl1 y lbl3

func _ready() -> void:
	_hide_all_labels()
	_connect_typing()

func _connect_typing() -> void:
	var tp: Node = null
	if String(typing_panel_path) != "":
		tp = get_node_or_null(typing_panel_path)
	if tp == null:
		tp = get_tree().root.find_child("TypingPanel", true, false)
	if tp is TypingPanel and not tp.score_ready.is_connected(_on_score_ready):
		tp.score_ready.connect(_on_score_ready)
	elif tp == null:
		push_warning("ScorePanel: no se encontró TypingPanel.")

func _on_score_ready(rating: String) -> void:
	show_score(rating)

func _hide_all_labels() -> void:
	if lbl1: lbl1.visible = false
	if lbl2: lbl2.visible = false
	if lbl3: lbl3.visible = false

func show_score(rating: String) -> void:
	_hide_all_labels()

	var target: Label = null
	match rating:
		"Perfect", "Fail":
			target = lbl2
		"Good", "Nice":
			target = (lbl1 if not _toggle_side else lbl3)
			_toggle_side = not _toggle_side
		_:
			return

	if target:
		target.text = rating.to_upper()
		_apply_rating_style(target, rating)
		target.visible = true
		if auto_hide:
			await get_tree().create_timer(hide_delay).timeout
			target.visible = false

# -------- helpers --------

func _apply_rating_style(label: Label, rating: String) -> void:
	var col := _color_for_rating(rating)
	# Si el Label usa LabelSettings, duplícalo para no afectar a otros
	if label.label_settings:
		var ls := label.label_settings.duplicate() as LabelSettings
		ls.font_color = col
		label.label_settings = ls
	else:
		# Fallback: override de tema si no tiene LabelSettings asignado
		label.add_theme_color_override("font_color", col)

func _color_for_rating(r: String) -> Color:
	match r:
		"Fail":    return color_fail
		"Good":    return color_good
		"Nice":    return color_nice
		"Perfect": return color_perfect
		_:         return Color.WHITE
