# res://scripts/DamageCalculator.gd
class_name DamageCalculator

## Bonus según combo mostrado en pantalla:
## x1 = +0%, x2 = +10%, x3 = +25%, x4 = +40%, x5+ = +65%
static func combo_bonus_percent(combo_count: int) -> float:
	var lvl: int = clampi(combo_count, 1, 5) # <- tipado explícito + clampi para int
	match lvl:
		1: return 0.0
		2: return 0.10
		3: return 0.25
		4: return 0.40
		5: return 0.65
	return 0.0

## Daño base según rating del spell (antes de combo)
static func base_damage_from_rating(rating: String) -> int:
	match rating:
		"Perfect": return 15
		"Nice":    return 10
		"Good":    return 5
		_:         return 0

## Daño final = base * (1 + bonus_combo)
## - Si envías base_override >= 0, ignora base_por_rating y usa ese valor fijo.
static func final_damage(rating: String, combo_count: int, base_override: int = -1) -> int:
	var base: int = base_override if base_override >= 0 else base_damage_from_rating(rating)
	var bonus: float = combo_bonus_percent(combo_count)
	return int(round(base * (1.0 + bonus)))
