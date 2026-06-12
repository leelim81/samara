extends Node


signal scene_summoned(scene_path, target_cell)

signal unit_escaped(unit, target_cell)

# Large character art cut-in (skills, chains, deaths).
# textures: Array of 1 (single) or 2 (dual) Texture2D
signal cutin_requested(textures, text, from_left, tint)
