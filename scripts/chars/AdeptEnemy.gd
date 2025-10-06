# res://scripts/chars/AdeptEnemy.gd
extends EnemyBase
class_name AdeptEnemy

# De momento NO añadimos comportamiento custom; usamos el del EnemyBase.
# Si más adelante quieres algo especial para el Adept, activa "activate_custom"
# en el Inspector y sobreescribe aquí la lógica.

func attack_and_cast() -> void:
	# Con activate_custom == false, esto sólo llama al ataque base.
	# Si algún día activas el custom, puedes poner lógica especial antes/después.
	await super.attack_and_cast()
