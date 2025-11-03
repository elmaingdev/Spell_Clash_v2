extends MarginContainer

@onready var label: Label = $MarginContainer/Label
@onready var timer: Timer = $LetterDisplayTimer

const MAX_WIDTH := 256

var text_to_show: String = ""
var letter_index: int = 0

@export var letter_time: float = 0.03
@export var space_time: float = 0.06
@export var punctuation_time: float = 0.20

signal finished_displaying

func _ready() -> void:
	# Asegura conexión del timer
	if timer and not timer.timeout.is_connected(_on_letter_display_timer_timeout):
		timer.timeout.connect(_on_letter_display_timer_timeout)

func display_text(s: String) -> void:
	text_to_show = s
	letter_index = 0

	# 1) Medimos el tamaño con el texto completo
	label.text = s
	await resized
	custom_minimum_size.x = min(size.x, MAX_WIDTH)

	# 2) Si excede ancho, activamos autowrap y esperamos recalculos
	if size.x > MAX_WIDTH:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		await resized # x
		await resized # y
		custom_minimum_size.y = size.y

	# 3) Reposiciona (centrado horizontal y sobre el nodo)
	global_position.x -= size.x * 0.5
	global_position.y -= size.y + 24.0

	# 4) Comienza el tipeo
	label.text = ""
	if text_to_show.length() > 0:
		_display_letter()
	else:
		finished_displaying.emit()

func _display_letter() -> void:
	# Agrega el siguiente carácter visible
	label.text += text_to_show.substr(letter_index, 1)
	letter_index += 1

	# Si ya terminamos, emitir señal y salir
	if letter_index >= text_to_show.length():
		finished_displaying.emit()
		return

	# Miramos el **próximo** carácter para decidir la pausa
	var ch := text_to_show.substr(letter_index, 1)
	match ch:
		"!", ".", ",", "?", ":", ";":
			timer.start(punctuation_time)
		" ":
			timer.start(space_time)
		_:
			timer.start(letter_time)

func _on_letter_display_timer_timeout() -> void:
	_display_letter()
