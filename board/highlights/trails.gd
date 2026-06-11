extends Node2D


@export var trail_2d_packed_scene: PackedScene

@export var player_trail_gradient: Gradient
@export var enemy_trail_gradient: Gradient


func build_trail(is_player_turn: bool) -> Node2D:
	var trail: Node2D = trail_2d_packed_scene.instantiate()
	
	trail.set_gradient(_get_gradient(is_player_turn))
	
	add_child(trail)
	
	return trail


func _get_gradient(is_player_turn: bool) -> Gradient:
	if is_player_turn:
		return player_trail_gradient
	else:
		return enemy_trail_gradient
