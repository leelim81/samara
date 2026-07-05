class_name BestiaryList
extends Resource
# Generated manifest of every enemy in the game, for the bestiary collection
# screen. Built by tools/build_bestiary.gd (scans jobs/terra for MONSTER and
# HANIWA units). Each entry is a lightweight Dictionary so the list renders
# without loading full enemy jobs and their large portraits; the full job is
# loaded only when the player opens a discovered enemy's detail page.
#
# Entry keys: "path" (job .tres), "name_key" (name / translation key),
# "token_path" (thumbnail .png), "weapon_type" (int), "attribute" (int).

@export var entries: Array = []
