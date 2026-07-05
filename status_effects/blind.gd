extends StatusEffect
# Blind: with no accuracy system in the damage model, this is modeled as a heavy
# cut to both physical and spiritual attack. It is not a StatsModifier, so it is
# applied after the debuff caps and can reduce below the normal -30% floor.


func modify_stats(base_stats: Stats, modified_stats: Stats) -> void:
	modified_stats.attack -= int(base_stats.attack * 0.5)
	modified_stats.spiritual_attack -= int(base_stats.spiritual_attack * 0.5)
