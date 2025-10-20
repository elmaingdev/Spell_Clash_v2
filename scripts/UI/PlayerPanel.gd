# res://scripts/UI/PlayerPanel.gd
extends Control
class_name PlayerPanel

@onready var life_bar: PlayerHealthBar = null
@onready var charge_bar: ChargeBar = null
@onready var turn_timer: TurnTimer = null

func _ready() -> void:
	# LifeBar
	var lb := find_child("LifeBar", true, false)
	if lb is PlayerHealthBar:
		life_bar = lb
	else:
		life_bar = get_node_or_null("%LifeBar") as PlayerHealthBar

	# ChargeBar
	var cb := find_child("ChargeBar", true, false)
	if cb is ChargeBar:
		charge_bar = cb
	else:
		charge_bar = get_node_or_null("%ChargeBar") as ChargeBar

	# TurnTimer
	var tt := find_child("TurnTimer", true, false)
	if tt is TurnTimer:
		turn_timer = tt
	else:
		turn_timer = get_node_or_null("%TurnTimer") as TurnTimer
