extends Node
class_name ProjectilePool

@export var projectile_scene: PackedScene
@export var initial_size: int = 10

var _free: Array[Node2D] = []

func _ready() -> void:
	if projectile_scene == null:
		return
	# Precalienta el pool sin reproducir SFX (los proyectiles no deben sonar en _ready)
	for i in initial_size:
		var p: Node2D = projectile_scene.instantiate() as Node2D
		add_child(p)
		_deactivate_node(p)
		_free.append(p)

## Tomar un nodo listo para usar.
func acquire() -> Node2D:
	if projectile_scene == null:
		return null
	var p: Node2D = null
	if _free.is_empty():
		p = projectile_scene.instantiate() as Node2D
		add_child(p)
	else:
		p = _free.pop_back()
	_activate_node(p)
	return p

## Devolver un nodo al pool.
func recycle(node: Node2D) -> void:
	if node == null:
		return
	_deactivate_node(node)
	if node.get_parent() != self:
		add_child(node)
	_free.append(node)

## Atajo por si el propio proyectil quiere devolverse.
func recycle_self(node: Node2D) -> void:
	recycle(node)

# ---------- helpers ----------
func _deactivate_node(n: Node2D) -> void:
	n.visible = false
	n.set_process(false)
	n.set_physics_process(false)
	if n is Area2D:
		# Propiedades sensibles, siempre con set_deferred
		(n as Area2D).set_deferred("monitoring", false)

func _activate_node(n: Node2D) -> void:
	n.visible = true
	n.set_process(true)
	n.set_physics_process(true)
	if n is Area2D:
		(n as Area2D).set_deferred("monitoring", true)
