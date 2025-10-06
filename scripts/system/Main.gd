# res://scripts/system/Main.gd
extends Node2D
class_name Main

@export var menu_scene: PackedScene

func _ready() -> void:
	if menu_scene == null:
		menu_scene = _safe_load_scene([
			"res://scenes/UI/Menu.tscn",
			"res://scenes/ui/Menu.tscn",
			"res://scenes/menu.tscn",
		])
	if menu_scene == null:
		push_error("Main: no pude cargar el menú.")
		return
	_show_menu()

func _show_menu() -> void:
	_clear_children()
	var inst := menu_scene.instantiate()
	add_child(inst)

func _clear_children() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()

func _safe_load_scene(candidates: Array) -> PackedScene:
	for p in candidates:
		if ResourceLoader.exists(str(p)):
			var ps := load(str(p))
			if ps is PackedScene:
				return ps
	return null
