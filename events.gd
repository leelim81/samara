extends Node


signal scene_summoned(scene_path, target_cell)

signal unit_escaped(unit, target_cell)

# Large character art cut-in (pincers, chains, deaths).
# textures: Array of 1 (single) or 2 (dual) Texture2D
# vertical_band: true for a tall band (horizontal pincer), false for wide
signal cutin_requested(textures, text, allied, tint, vertical_band)
