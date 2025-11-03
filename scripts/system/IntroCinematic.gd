extends Control
signal finished

# === Ajustes ===
@export var slide_texts: Array[String] = [
	"El anciano escribía sus observaciones y estudios en su grimorio como cada noche",
	"Pero de pronto, un destello rojo cubrió los cielos y el grimorio comenzó a brillar",
	"Del grimorio surgió un portal, y el mago fue arrastrado hacia él",
	"Y así, el anciano comenzó su carrera por la guarida de la secta"
]
@export var auto_advance: bool = false
@export var default_duration: float = 3.5
@export var type_speed: float = 0.02
@export var crossfade_time: float = 0.35

# === Rutas a Stage 1 (ajústalas si cambian) ===
@export var stage1_paths: Array[String] = [
	"res://scenes/stages/PoisonSkullBattle.tscn",
]

# === Nodos ===
@onready var lore: Control = $Lore
@onready var textbox: PanelContainer = $TextBox
@onready var rtext: RichTextLabel = $TextBox/MarginContainer/VBoxContainer/RichTextLabel
@onready var hint_box: HBoxContainer = $TextBox/MarginContainer/VBoxContainer/HBoxContainer

# === Estado ===
var slides: Array[Sprite2D] = []
var current: int = -1
var typing: bool = false
var abort_all: bool = false
var accept: bool = false
var hint_tween: Tween = null

func _ready() -> void:
	_collect_slides()
	_show_only(-1)
	textbox.modulate.a = 0.0
	hint_box.visible = false
	await _fade(textbox, 0.0, 1.0, 0.30)
	await _run_sequence()

func _collect_slides() -> void:
	for c: Node in lore.get_children():
		if c is Sprite2D:
			var s: Sprite2D = c as Sprite2D
			slides.append(s)
			_fit_sprite_to_viewport(s)
			s.modulate.a = 0.0
			s.visible = false

func _fit_sprite_to_viewport(s: Sprite2D) -> void:
	var tex: Texture2D = s.texture
	if tex == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var tex_sz_v2: Vector2 = Vector2(tex.get_size())
	if tex_sz_v2.x <= 0.0 or tex_sz_v2.y <= 0.0:
		return
	var scale_x: float = vp.x / tex_sz_v2.x
	var scale_y: float = vp.y / tex_sz_v2.y
	var sc: float = max(scale_x, scale_y)
	s.scale = Vector2(sc, sc)
	s.position = vp * 0.5

func _show_only(index: int) -> void:
	for i in slides.size():
		var s: Sprite2D = slides[i]
		s.visible = (i == index)
		s.modulate.a = (1.0 if i == index else 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed):
		if typing:
			typing = false
		else:
			accept = true
	elif event.is_action_pressed("ui_cancel"):
		abort_all = true
		typing = false
		accept = true

func _blink_hint(on: bool) -> void:
	if hint_tween and hint_tween.is_running():
		hint_tween.kill()
	hint_box.visible = on
	if on:
		hint_box.modulate.a = 1.0
		hint_tween = create_tween().set_loops()
		hint_tween.tween_property(hint_box, "modulate:a", 0.4, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		hint_tween.tween_property(hint_box, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _fade(node: CanvasItem, from_a: float, to_a: float, t: float) -> Signal:
	node.modulate.a = from_a
	return create_tween().tween_property(node, "modulate:a", to_a, t).finished

func _crossfade_to(index: int) -> void:
	var prev: Sprite2D = null
	if current >= 0:
		prev = slides[current]
	var next: Sprite2D = slides[index]
	if prev:
		prev.visible = true
		create_tween().tween_property(prev, "modulate:a", 0.0, crossfade_time)
	next.visible = true
	next.modulate.a = 0.0
	create_tween().tween_property(next, "modulate:a", 1.0, crossfade_time)

func _type_text(s: String) -> void:
	rtext.bbcode_enabled = false
	rtext.text = s
	rtext.visible_characters = 0
	typing = true
	var total: int = rtext.get_total_character_count()
	while rtext.visible_characters < total and typing:
		rtext.visible_characters += 1
		await get_tree().create_timer(type_speed).timeout
	rtext.visible_characters = total
	typing = false

func _wait_for_accept_or_time(seconds: float) -> void:
	accept = false
	if auto_advance:
		await get_tree().create_timer(seconds).timeout
	else:
		_blink_hint(true)
		while not accept and not abort_all:
			await get_tree().process_frame
		_blink_hint(false)

func _run_sequence() -> void:
	var limit: int = min(slides.size(), slide_texts.size())
	while current + 1 < limit and not abort_all:
		current += 1
		_crossfade_to(current)
		await get_tree().create_timer(crossfade_time).timeout
		await _type_text(slide_texts[current])
		await _wait_for_accept_or_time(default_duration)

	await _fade(textbox, textbox.modulate.a, 0.0, 0.25)
	finished.emit()               # por si algún autoload la escucha
	_go_stage1()                  # y luego pasamos a Stage 1

func _go_stage1() -> void:
	var flow := get_node_or_null("/root/StageFlow")
	if flow and flow.has_method("start_new_run"):
		flow.call("start_new_run")
	var path: String = _first_existing(stage1_paths)
	if path == "":
		push_error("IntroCinematic: no encontré Stage 1.")
		return
	get_tree().change_scene_to_file(path)

func _first_existing(paths: Array[String]) -> String:
	for p: String in paths:
		if ResourceLoader.exists(p):
			return p
	return ""
