extends Node


func make_unit_flee(unit: Unit, neighboring_cell: Cell, neighboring_unit: Unit) -> void:
	# Don't allow 2x2 units to flee, just to simplify cell assignment
	if neighboring_unit == null or neighboring_unit.is2x2() or neighboring_unit.is_ally(unit.faction):
		return
	
	if not neighboring_unit.can_flee_when_enemy_enters_nearby_cell:
		return
	
	if unit.velocity.length_squared() < 5000:
		return
	
	var direction: int = Enums.get_direction(unit.position, neighboring_unit.position)
	var initial_direction: int = direction
	
	var cell_to_move_to: Cell = neighboring_cell.get_neighbor(direction)
	
	# If the cell is null, pick another one
	# Move just one cell
	while not _is_cell_free(cell_to_move_to):
		direction = Enums.get_next_direction(direction)
		
		if direction == initial_direction:
			cell_to_move_to = null
			
			break
		else:
			cell_to_move_to = neighboring_cell.get_neighbor(direction)
	
	if cell_to_move_to == null:
		return
	
	assert(neighboring_cell.unit == neighboring_unit)
	assert(cell_to_move_to.unit == null)
	
	neighboring_cell.unit = null
	cell_to_move_to.unit = neighboring_unit
	
	neighboring_unit.play_flee_animation()
	neighboring_unit.move_to_new_cell(cell_to_move_to.position)
	
	cell_to_move_to.activate_trap()


func _is_cell_free(cell: Cell) -> bool:
	return cell != null and cell.unit == null
