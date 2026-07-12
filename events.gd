extends Node


signal scene_summoned(scene_path, target_cell)

signal unit_escaped(unit, target_cell)

# Large character art cut-in (pincers, chains, deaths). Slides over the
# visible grid — no opaque band.
# textures: Array of 1 (single) or 2 (dual) Texture2D
# enter_from_sides: true = art enters from left/right (vertical pincer),
#   false = from top/bottom (horizontal pincer)
signal cutin_requested(textures, text, allied, tint, enter_from_sides)

# A unit's skill activated during a pincer; the shared skill feed shows its
# name as one row so callouts stack instead of scattering across the board.
signal skill_activated(skill)

# A player attack dealt damage to an enemy that SURVIVED the hit. Charges the
# Power Gauge (Terra Battle charges per surviving hit, not per pincer).
signal enemy_survived_player_hit

signal power_boost_changed(active)

# True from the moment a Powered Point is chained until the end of the player
# turn (Terra Battle): ALL damage and healing are boosted x1.5 and every skill
# is guaranteed to activate. Board sets and clears this flag.
var power_boost_active: bool = false:
	set(value):
		var changed: bool = power_boost_active != value
		power_boost_active = value
		if changed:
			power_boost_changed.emit(value)

# Guided-tutorial input gate. When non-null, ONLY this unit may be picked up
# and moved; every other unit ignores selection input. The tutorial guide sets
# it per step and clears it (null) when it finishes. null = no restriction.
var tutorial_locked_unit: Node = null


# A unit may act this frame if the tutorial is not gating input, or if it is
# the unit the tutorial currently allows.
func tutorial_allows(unit: Node) -> bool:
	return tutorial_locked_unit == null or tutorial_locked_unit == unit
