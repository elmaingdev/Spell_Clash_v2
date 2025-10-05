extends Node2D
class_name Main

# Opcional: asigná escenas desde el Inspector si querés.
@export var menu_scene: PackedScene
@export var stage1_scene: PackedScene   # SkMageBattle (tu Stage 1)
@export var stage2_scene: PackedScene   # (reservado / opcional)

func _ready() -> void:
	# Si no se asignó por Inspector, probamos rutas conocidas.
	if menu_scene == null:
		menu_scene = _safe_load_scene([
			"res://scenes/UI/Menu.tscn",
			"res://scenes/ui/Menu.tscn",
			"res://scenes/menu.tscn",
		])

	if menu_scene == null:
		push_error("Main: no pude cargar el menú. Revisa scenes/UI/Menu.tscn")
		return

	_show_menu()

func _show_menu() -> void:
	_clear_children()
	var inst := menu_scene.instantiate()
	add_child(inst)

	# (Opcional) Si tu Menu emite señales propias, podés conectarlas acá.
	# if inst.has_signal("new_game"):
	# 	inst.new_game.connect(func(): _start_stage_1())

func _start_stage_1() -> void:
	if stage1_scene == null:
		stage1_scene = _safe_load_scene([
			"res://scenes/stages/SkMageBattle.tscn",
			"res://scenes/stages/AdeptBattle.tscn",
		])
	if stage1_scene == null:
		push_error("Main: no pude cargar Stage 1 (SkMageBattle/AdeptBattle).")
		return
	_clear_children()
	add_child(stage1_scene.instantiate())

func _start_stage_2() -> void:
	if stage2_scene == null:
		stage2_scene = _safe_load_scene([
			"res://scenes/stages/WitchBattle.tscn",
		])
	if stage2_scene == null:
		push_error("Main: no pude cargar Stage 2 (WitchBattle).")
		return
	_clear_children()
	add_child(stage2_scene.instantiate())

func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()

func _safe_load_scene(candidates: Array) -> PackedScene:
	for p in candidates:
		if ResourceLoader.exists(p):
			var ps := load(str(p))
			if ps is PackedScene:
				return ps
	return null
