extends Node2D
class_name Main

# Opcional: así puedes asignar escenas desde el Inspector si quieres.
@export var menu_scene: PackedScene
@export var stage1_scene: PackedScene   # AdeptBattle
@export var stage2_scene: PackedScene   # SkMageBattle (a futuro)

func _ready() -> void:
	# Si no se asignó por Inspector, intentamos rutas conocidas.
	if menu_scene == null:
		menu_scene = _safe_load_scene([
			"res://scenes/UI/menu.tscn",
			"res://scenes/UI/Menu.tscn",
			"res://scenes/menu.tscn",
		])

	if menu_scene == null:
		push_error("Main: no pude cargar el menú. Revisa la ruta en scenes/UI/menu.tscn")
		return

	_show_menu()

func _show_menu() -> void:
	_clear_children()
	var inst := menu_scene.instantiate()
	add_child(inst)

	# Si tu Menu.gd emite señales (new_game, load_game…), puedes conectarlas aquí.
	# Ejemplo:
	# if inst.has_signal("new_game"):
	#     inst.new_game.connect(func(): _start_stage_1())
	# if inst.has_signal("load_game"):
	#     inst.load_game.connect(func(): _start_stage_1())

func _start_stage_1() -> void:
	if stage1_scene == null:
		stage1_scene = _safe_load_scene([
			"res://scenes/stages/AdeptBattle.tscn",
			"res://scenes/battle.tscn",
		])
	if stage1_scene == null:
		push_error("Main: no pude cargar AdeptBattle (stage 1).")
		return
	_clear_children()
	add_child(stage1_scene.instantiate())

func _start_stage_2() -> void:
	if stage2_scene == null:
		stage2_scene = _safe_load_scene([
			"res://scenes/stages/SkMageBattle.tscn",
		])
	if stage2_scene == null:
		push_error("Main: no pude cargar SkMageBattle (stage 2).")
		return
	_clear_children()
	add_child(stage2_scene.instantiate())

func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()

func _safe_load_scene(candidates: Array[String]) -> PackedScene:
	for p in candidates:
		if ResourceLoader.exists(p):
			var ps := load(p)
			if ps is PackedScene:
				return ps
	return null
