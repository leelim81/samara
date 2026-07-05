extends StatusEffect
# Terra Battle Venom: a stronger Poison that deals more damage each turn.


var random := RandomNumberGenerator.new()


func initialize(inflicting_unit_stats: Stats) -> void:
	random.randomize()

	# Roughly 1.8x Poison's per-turn base (Poison uses 0.5 x spiritual attack).
	base_damage = int(inflicting_unit_stats.spiritual_attack * 0.9)


func calculate_damage(_affected_unit_stats: Stats) -> int:
	return int(float(base_damage) * random.randf_range(1.0, 1.3))
