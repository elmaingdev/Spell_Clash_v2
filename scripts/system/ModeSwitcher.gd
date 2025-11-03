# res://scripts/system/ModeSwitcher.gd
extends Node
class_name ModeSwitcher

@export_node_path("Control") var typing_path: NodePath = NodePath("")
@export_node_path("Control") var defend_path: NodePath = NodePath("")
@export_node_path("Control") var mode_buttons_path: NodePath = NodePath("")
@export_node_path("Control") var timer_path: NodePath  = NodePath("")

var typing: TypingPanel = null
var defend: DirectionsPanel = null
var timer: TurnTimer = null
var mode_buttons: Control = null

# Referencias visuales dentro de ModeButtons
var atk_btn: TextureButton = null
var def_btn: TextureButton = null
var atk_box: TextureRect = null
var def_box: TextureRect = null
var atk_wand: TextureRect = null
var def_wand: TextureRect = null
var _book_cache: AnimatedSprite2D = null

@export var round_time: float = 5.0
@export var inter_round_delay: float = 0.25

var _is_attack: bool = true            # Attack por defecto
var _forced_attack_lock: bool = false  # lock mientras esperamos NEXT

func _ready() -> void:
	set_process_input(true)
	call_deferred("_wire_up")

func _wire_up() -> void:
	typing = _resolve_node(typing_path, "TypingPanel") as TypingPanel
	defend = _resolve_node(defend_path, "DirectionsPanel") as DirectionsPanel
	mode_buttons = _resolve_node(mode_buttons_path, "ModeButtons") as Control
	timer  = _resolve_node(timer_path,  "TurnTimer") as TurnTimer

	# Conexiones con TypingPanel / TurnTimer
	_connect_typing_signals()
	_connect_enemy_died()
	if typing and not typing.score_ready.is_connected(_on_score_ready):
		typing.score_ready.connect(_on_score_ready)
	if timer and not timer.timeout.is_connected(_on_turn_timeout):
		timer.timeout.connect(_on_turn_timeout)

	# Preparar los botones visuales (solo indicadores, sin interacción de mouse)
	_setup_mode_buttons()

	_set_attack_mode(true)

	# Arranque: si el timer no corre, arráncalo una vez
	if timer and not timer.is_running():
		timer.start(round_time)

	_start_round()

func _resolve_node(path: NodePath, name_fallback: String) -> Node:
	if path != NodePath(""):
		var n: Node = get_node_or_null(path)
		if n:
			return n
	return get_tree().root.find_child(name_fallback, true, false)

func _connect_typing_signals() -> void:
	if typing and not typing.next_requested.is_connected(_on_next_requested):
		typing.next_requested.connect(_on_next_requested)

func _connect_enemy_died() -> void:
	var enemy := get_node_or_null("%Enemy")
	if enemy == null:
		var list := get_tree().get_nodes_in_group("enemy")
		if not list.is_empty():
			enemy = list[0]
	if enemy and enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)

# ---------- Preparar/actualizar ModeButtons ----------
func _setup_mode_buttons() -> void:
	if mode_buttons == null:
		return

	# Encuentra nodos por nombre dentro de ModeButtons
	atk_btn = mode_buttons.find_child("AtkBtn", true, false) as TextureButton
	def_btn = mode_buttons.find_child("DefBtn", true, false) as TextureButton
	atk_box = mode_buttons.find_child("AtkBox", true, false) as TextureRect
	def_box = mode_buttons.find_child("DefBox", true, false) as TextureRect
	atk_wand = mode_buttons.find_child("AtkWand", true, false) as TextureRect
	def_wand = mode_buttons.find_child("DefWand", true, false) as TextureRect

	# Los botones solo son indicadores: sin foco, deshabilitados y consumen clicks
	for btn in [atk_btn, def_btn]:
		if btn:
			btn.toggle_mode = true
			btn.disabled = true
			btn.focus_mode = Control.FOCUS_NONE
			if not btn.gui_input.is_connected(_swallow_gui_input):
				btn.gui_input.connect(_swallow_gui_input)

	_update_mode_visuals()  # sincroniza estado inicial

func _swallow_gui_input(_event: InputEvent) -> void:
	# Consume cualquier intento de click/touch en los botones
	get_viewport().set_input_as_handled()

func _update_mode_visuals() -> void:
	# Estado "burbuja" (usamos pressed + modulate como refuerzo visual)
	if atk_btn:
		atk_btn.set_pressed_no_signal(_is_attack)
		atk_btn.modulate = Color(1,1,1, 1.0 if _is_attack else 0.5)
	if def_btn:
		def_btn.set_pressed_no_signal(not _is_attack)
		def_btn.modulate = Color(1,1,1, 1.0 if not _is_attack else 0.5)

	# Si quieres reforzar con cajas/varitas (opcionales)
	if atk_box:  atk_box.modulate  = Color(1,1,1, 1.0 if _is_attack else 0.35)
	if def_box:  def_box.modulate  = Color(1,1,1, 1.0 if not _is_attack else 0.35)
	if atk_wand: atk_wand.modulate = Color(1,1,1, 1.0 if _is_attack else 0.6)
	if def_wand: def_wand.modulate = Color(1,1,1, 1.0 if not _is_attack else 0.6)

# ----------------- Entrada (teclado) -----------------
func _input(event: InputEvent) -> void:
	# Debes tener una acción "mode_toggle" en el Input Map (asigna la tecla Tab)
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("mode_toggle"):
		# Si hay lock, ignora el toggle
		if _forced_attack_lock:
			get_viewport().set_input_as_handled()
			return
		_set_attack_mode(not _is_attack)
		_restart_cycle()
		get_viewport().set_input_as_handled()

# ----------------- Lógica de switching -----------------
func _set_attack_mode(is_attack: bool) -> void:
	# Si estamos bloqueados en ataque, fuerza true
	if _forced_attack_lock:
		is_attack = true

	if _is_attack == is_attack:
		_update_mode_visuals()
		return

	# ← Aquí sabemos que SÍ cambia el modo
	_book_play(&"previous")

	_is_attack = is_attack

	if typing:
		typing.visible = is_attack
		if typing.has_method("set_mode_enabled"):
			typing.set_mode_enabled(is_attack)

	if defend:
		defend.visible = not is_attack
		if defend.has_method("set_mode_enabled"):
			defend.set_mode_enabled(not _is_attack)

	_update_mode_visuals()

func _restart_cycle() -> void:
	if _forced_attack_lock:
		# Mantén el prompt NEXT si estamos bloqueados
		if typing:
			typing.show_next_prompt()
		return

	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()

func _start_round() -> void:
	if _forced_attack_lock:
		if typing:
			typing.show_next_prompt()
		return

	if _is_attack and typing:
		typing.start_round()
	elif not _is_attack and defend:
		defend.start_round()

# ----- Ciclo ATTACK (spell) -----
func _on_score_ready(_rating: String) -> void:
	await get_tree().create_timer(inter_round_delay).timeout
	if _forced_attack_lock:
		if typing:
			typing.show_next_prompt()
		return
	if _is_attack and typing:
		typing.start_round()

func _on_turn_timeout() -> void:
	if _is_attack and typing and typing.has_method("on_timeout"):
		typing.on_timeout()
		await get_tree().create_timer(inter_round_delay).timeout
		if _forced_attack_lock:
			if typing:
				typing.show_next_prompt()
			return
		typing.start_round()
	# En DEFEND, el timeout no afecta DirectionsPanel.

# ======= Eventos de flujo =======
func _on_enemy_died() -> void:
	# Bloquea el modo en ATTACK y detén el timer
	_forced_attack_lock = true
	_set_attack_mode(true)
	if timer:
		timer.stop()
	if typing:
		typing.show_next_prompt()

func _on_next_requested() -> void:
	# Mantén el lock hasta que StageFlow cambie de escena.
	# Si no hay StageFlow, lo liberamos después de un micro-tiempo de seguridad.
	var flow := get_node_or_null("/root/StageFlow")
	if flow and flow.has_method("go_next"):
		flow.call("go_next")
	else:
		await get_tree().create_timer(0.1).timeout
		_forced_attack_lock = false

func _get_book() -> AnimatedSprite2D:
	if _book_cache and is_instance_valid(_book_cache):
		return _book_cache
	var nodes := get_tree().get_nodes_in_group("ui_book")
	if nodes.size() > 0:
		_book_cache = nodes[0] as AnimatedSprite2D
		return _book_cache
	return null

func _book_play(anim: StringName) -> void:
	var b := _get_book()
	if b == null:
		return

	var anim_name := String(anim)            # ← renombrada; evita sombrear Node.name
	var frames := b.sprite_frames            # AnimatedSprite2D usa SpriteFrames
	if frames and frames.has_animation(anim_name):
		# Evita re-tocar una animación ya en curso (opcional)
		if String(b.animation) != anim_name or not b.is_playing():
			b.play(anim_name)
	else:
		# Debug opcional para detectar typos
		# print_debug("[Book] Animación no encontrada: ", anim_name)
		pass
