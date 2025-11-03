extends Node

@onready var text_box_scene: PackedScene = preload("res://scenes/UI/TextBox.tscn")

# Instancia actual del TextBox y un id para saber si el timer corresponde a la instancia viva
var text_box: Node = null
var _current_box_id: int = 0

func _ready() -> void:
	# Conecta a todos los TypingPanel existentes
	_wire_typing_panels()
	# Y a los que aparezcan después (al cambiar de escena, etc.)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _on_node_added(n: Node) -> void:
	if n is TypingPanel:
		var tp := n as TypingPanel
		if not tp.spell_success.is_connected(_on_spell_success):
			tp.spell_success.connect(_on_spell_success)

func _wire_typing_panels() -> void:
	var panels := get_tree().root.find_children("", "TypingPanel", true, false)
	for p in panels:
		var tp := p as TypingPanel
		if tp and not tp.spell_success.is_connected(_on_spell_success):
			tp.spell_success.connect(_on_spell_success)

# ----- llamado por TypingPanel cuando el spell fue correcto -----
func _on_spell_success(phrase: String) -> void:
	# Muestra un popup de 1.0s; si llega otro antes, se reemplaza
	_show_spell_popup(phrase, 1.0)

# Crea/posiciona el TextBox, reemplazando el anterior si existía
func _show_spell_popup(text: String, duration: float) -> void:
	var pos := _get_player_dialog_position()

	_kill_current_box()

	text_box = text_box_scene.instantiate()
	_current_box_id = text_box.get_instance_id()

	get_tree().root.add_child(text_box)
	text_box.global_position = pos
	text_box.call("display_text", text)

	# Autocierre en 'duration' segundos, solo si sigue siendo la misma instancia
	_autoclose_after(_current_box_id, duration)

# Espera 'secs' y cierra si no fue reemplazado por otro TextBox
func _autoclose_after(box_id: int, secs: float) -> void:
	await get_tree().create_timer(max(0.0, secs)).timeout
	if is_instance_valid(text_box) and text_box.get_instance_id() == box_id:
		text_box.queue_free()
		text_box = null

# Elimina el TextBox actual si existe
func _kill_current_box() -> void:
	if is_instance_valid(text_box):
		text_box.queue_free()
	text_box = null

# Ubicación del cuadro: usa Mage1 → CharacterBody2D/DialogPoint; si no, fallbacks limpios
func _get_player_dialog_position() -> Vector2:
	# 1) Busca un Mage1 en el árbol
	var mages := get_tree().root.find_children("", "Mage1", true, false)
	if mages.size() > 0:
		var m := mages[0]

		# Si tu script de Mage1 tiene el helper, úsalo
		if m.has_method("get_dialog_global_pos"):
			return Vector2(m.call("get_dialog_global_pos"))

		# Si no, intenta hallar el Marker2D
		var marker := (m as Node).get_node_or_null("CharacterBody2D/DialogPoint")
		if marker == null:
			marker = (m as Node).find_child("DialogPoint", true, false)
		if marker is Marker2D:
			return (marker as Marker2D).global_position

		# Fallback: la posición del propio nodo (un poco más arriba)
		if m is Node2D:
			return (m as Node2D).global_position + Vector2(0, -32)

	# 2) Grupo "player" como alternativa
	var list := get_tree().get_nodes_in_group("player")
	if not list.is_empty():
		var pn := list[0]
		var mk := (pn as Node).find_child("DialogPoint", true, false)
		if mk is Marker2D:
			return (mk as Marker2D).global_position
		if pn is Node2D:
			return (pn as Node2D).global_position + Vector2(0, -32)

	# 3) Último recurso: centro de pantalla
	return get_viewport().get_visible_rect().size * 0.5
