extends Node


signal scene_summoned(scene_path, target_cell)

signal unit_escaped(unit, target_cell)

# Large character art cut-in (pincers, chains, deaths). Slides over the
# visible grid — no opaque band.
# textures: Array of 1 (single) or 2 (dual) Texture2D
# enter_from_sides: true = art enters from left/right (vertical pincer),
#   false = from top/bottom (horizontal pincer)
signal cutin_requested(textures, text, allied, tint, enter_from_sides)
