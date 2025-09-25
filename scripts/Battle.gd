extends Node2D
class_name Battle

@onready var enemy: Mage2    = get_node_or_null("%Mage_2")
@onready var player: Mage1   = get_node_or_null("%Mage_1")
@onready var info: InfoPanel = get_node_or_null("%InfoPanel")

func _ready() -> void:
	# Asegura “partida nueva” y rewire cuando esta escena entra
	var cc: Node = get_node_or_null("/root/ComboCounter")
	if cc:
		cc.call_deferred("start_new_match")
		cc.call_deferred("rewire")
		cc.call_deferred("emit_now")

	call_deferred("_wire_up")

func _wire_up() -> void:
	if enemy and info and info.has_method("set_enemy_hp"):
		var cb_e := Callable(info, "set_enemy_hp")
		if not enemy.hp_changed.is_connected(cb_e):
			enemy.hp_changed.connect(cb_e)
		info.set_enemy_hp(enemy.HP, enemy.max_hp)

	if player and info and info.has_method("set_player_hp"):
		var cb_p := Callable(info, "set_player_hp")
		if not player.hp_changed.is_connected(cb_p):
			player.hp_changed.connect(cb_p)
		info.set_player_hp(player.HP, player.max_hp)
