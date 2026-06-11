extends Area2D


# Returns the unit that owns this area 2D
func get_unit() -> CharacterBody2D:
	return get_parent() as CharacterBody2D
