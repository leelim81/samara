extends StatusEffect


var random := RandomNumberGenerator.new()


func initialize(inflicting_unit_stats: Stats) -> void:
	random.randomize()

	# Terra Battle poison formula: base = MATK x [power] x 0.5 (power 1 here)
	base_damage = int(inflicting_unit_stats.spiritual_attack * 0.5)


func calculate_damage(_affected_unit_stats: Stats) -> int:
	# Actual poison damage = base x RANDOM(1, 1.2) (Terra Battle)
	return int(float(base_damage) * random.randf_range(1.0, 1.2))
