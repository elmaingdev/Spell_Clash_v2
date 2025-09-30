extends Control
class_name ScorePanel

@onready var score1: Control = $Score1
@onready var score2: Control = $Score2
@onready var score3: Control = $Score3
@onready var lbl1: Label = $Score1/Score_lbl1
@onready var lbl2: Label = $Score2/Score_lbl2
@onready var lbl3: Label = $Score3/Score_lbl3
# NUEVO: panel de protección
@onready var lbl_protect: Label = $"Protect/Protect_lbl"

@export_node_path("Control") var typing_panel_path
@export var auto_hide: bool = true
@export var hide_delay: float = 1.0

# Paleta (ajustada)
@export var color_fail:    Color = Color8(255, 80, 80)      # rojo
@export var color_good:    Color = Color8(46, 204, 113)     # verde
@export var color_nice:    Color = Color8(140, 33, 142)     # #8c218e
@export var color_perfect: Color = Color8(232, 146, 0)      # #e89200

var _toggle_side := false

func _ready() -> void:
	_hide_all_labels()
	_connect_sources()

func _connect_sources() -> void:
	# TypingPanel
	var tp: Node = null
	if String(typing_panel_path) != "":
		tp = get_node_or_null(typing_panel_path)
	if tp == null:
		tp = get_tree().root.find_child("TypingPanel", true, false)
	if tp is TypingPanel and not tp.score_ready.is_connected(_on_score_ready):
		tp.score_ready.connect(_on_score_ready)

	# DirectionsPanel
	var dp := get_node_or_null("%DirectionsPanel")
	if dp == null:
		dp = get_tree().root.find_child("DirectionsPanel", true, false)
	if dp and dp.has_signal("score_ready") and not dp.score_ready.is_connected(_on_score_ready):
		dp.score_ready.connect(_on_score_ready)

func _on_score_ready(rating: String) -> void:
	# SFX: si no existe entrada (ej. PROTECTION), Sfx.score_sfx no sonará, es correcto.
	Sfx.score_sfx(rating)
	show_score(rating)

func _hide_all_labels() -> void:
	if lbl1: lbl1.visible = false
	if lbl2: lbl2.visible = false
	if lbl3: lbl3.visible = false
	if lbl_protect: lbl_protect.visible = false

func show_score(rating: String) -> void:
	_hide_all_labels()

	var target: Label = null
	match rating:
		"PROTECTION":
			target = lbl_protect
		"Perfect", "Fail":
			target = lbl2
		"Good", "Nice":
			target = (lbl1 if not _toggle_side else lbl3)
			_toggle_side = not _toggle_side
		_:
			return

	if target:
		target.text = rating.to_upper()
		# No sobreescribimos el estilo de PROTECTION (usa el que diste en la escena)
		if rating != "PROTECTION":
			_apply_rating_style(target, rating)
		target.visible = true
		if auto_hide:
			await get_tree().create_timer(hide_delay).timeout
			target.visible = false

func _apply_rating_style(label: Label, rating: String) -> void:
	var col := _color_for_rating(rating)
	if label.label_settings:
		var ls := label.label_settings.duplicate() as LabelSettings
		ls.font_color = col
		label.label_settings = ls
	else:
		label.add_theme_color_override("font_color", col)

func _color_for_rating(r: String) -> Color:
	match r:
		"Fail":    return color_fail
		"Good":    return color_good
		"Nice":    return color_nice
		"Perfect": return color_perfect
		_:         return Color.WHITE
