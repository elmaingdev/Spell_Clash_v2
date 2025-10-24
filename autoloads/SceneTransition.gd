extends CanvasLayer

@export var layer_index: int = 128
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var rect: ColorRect      = $dissolve_rect

var _busy := false

func _ready() -> void:
	layer = layer_index
	# Asegura estado inicial invisible (si existe RESET, úsalo)
	if anim.has_animation("RESET"):
		anim.play("RESET")
	else:
		var c := rect.modulate
		c.a = 0.0
		rect.modulate = c

func is_busy() -> bool:
	return _busy

# API principal (por ahora solo "dissolve")
func change_scene(target: String, transition: StringName = &"dissolve") -> void:
	if _busy:
		return
	_busy = true

	# 1) Fade-out
	if anim.has_animation(transition):
		anim.play(transition)
		await anim.animation_finished

	# 2) Cambio de escena
	get_tree().change_scene_to_file(target)

	# 3) Espera 1 frame para que la nueva escena dibuje
	await get_tree().process_frame

	# 4) Fade-in (play_backwards)
	if anim.has_animation(transition):
		anim.play_backwards(transition)
		await anim.animation_finished

	_busy = false

# Accesos directos si alguna vez quieres solo abrir/cerrar sin cambiar escena:
func fade_out(transition: StringName = &"dissolve") -> void:
	if anim.has_animation(transition):
		anim.play(transition)
		await anim.animation_finished

func fade_in(transition: StringName = &"dissolve") -> void:
	if anim.has_animation(transition):
		anim.play_backwards(transition)
		await anim.animation_finished
