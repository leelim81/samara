extends Node2D


@export var chain_preview_line_2d_packed_scene: PackedScene


func update_preview(unit: Unit, cell: Cell) -> void:
	clear()
	
	if unit.faction != Unit.PLAYER_FACTION:
		return
	
	# Could be a dictionary, but it's not too important
	var last_cells_with_ally_for_each_direction: Array = []

	# This code is similar to find_chains() in Pincerer. The line extends to the
	# farthest chainable ally OR Powered Point; only enemies break the chain.
	for direction in Enums.DIRECTION.values():
		var neighbor: Cell = cell.get_neighbor(direction)

		var last_cell_with_ally: Cell = null

		while neighbor != null:
			if neighbor.unit != null and neighbor.unit.is_enemy(unit.faction):
				# Found an enemy unit, stop searching
				break

			if neighbor.is_powered:
				last_cell_with_ally = neighbor

			if neighbor.unit != null and neighbor.unit.is_ally(unit.faction) and neighbor.unit.can_act():
				last_cell_with_ally = neighbor

			neighbor = neighbor.get_neighbor(direction)

		if last_cell_with_ally != null:
			last_cells_with_ally_for_each_direction.push_back(last_cell_with_ally)
	
	for last_cell in last_cells_with_ally_for_each_direction:
		var chain_preview_line_2d: Line2D = chain_preview_line_2d_packed_scene.instantiate()
		
		chain_preview_line_2d.add_point(cell.position)
		chain_preview_line_2d.add_point(last_cell.position)
		
		add_child(chain_preview_line_2d)


func clear() -> void:
	for child in get_children():
		child.queue_free()
