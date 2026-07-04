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

# True from the moment a Powered Point is chained until the end of the player
# turn (Terra Battle): ALL damage and healing are boosted x1.5 and every skill
# is guaranteed to activate. Board sets and clears this flag.
var power_boost_active: bool = false
