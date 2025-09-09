extends Node

@export_file("*.json") var spells_path := "res://data/spells.json"

var spells: Array[String] = []
var _last := ""
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	load_spells()

func load_spells() -> void:
	spells.clear()
	if not FileAccess.file_exists(spells_path): return
	var f := FileAccess.open(spells_path, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_ARRAY: return
	for s in data:
		if typeof(s) == TYPE_STRING and s.strip_edges() != "":
			spells.append(s)

func random_spell(no_repeat := true) -> String:
	if spells.is_empty(): return "fuego"
	var choice := spells[_rng.randi_range(0, spells.size()-1)]
	if no_repeat and spells.size() > 1:
		var tries := 0
		while choice == _last and tries < 6:
			choice = spells[_rng.randi_range(0, spells.size()-1)]
			tries += 1
	_last = choice
	return choice
