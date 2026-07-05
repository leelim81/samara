extends StatusEffect
# Weakness: the unit takes extra elemental damage. Read by
# SkillApplier._get_attribute_multiplier, which multiplies elemental damage by
# the defender's elemental_weakness_multiplier.


func modify_stats(_base_stats: Stats, modified_stats: Stats) -> void:
	modified_stats.elemental_weakness_multiplier = 1.5
