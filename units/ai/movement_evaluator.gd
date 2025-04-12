extends Node


class MovementEvaluationResult extends Reference:
	var cell: Cell = null
	
	var neighboring_enemies: int = 0
	var neighboring_allies: int = 0
	
	var squared_distance_to_enemies: float = 0


# Sorts results by count of neighboring units or enemies
class HugSorter:
	var can_count_enemies: bool = false
	
	func sort_descending(a: MovementEvaluationResult, b: MovementEvaluationResult) -> bool:
		if a.cell.unit == null and b.cell.unit != null:
			# Prefer a if it is empty. Otherwise, prefer b if it is empty instead
			return true
		elif a.cell.unit != null and b.cell.unit == null:
			return false
		
		if can_count_enemies:
			return a.neighboring_enemies > b.neighboring_enemies
		else:
			return a.neighboring_allies > b.neighboring_allies


class DistanceSorter:
	static func sort_descending(a: MovementEvaluationResult, b: MovementEvaluationResult) -> bool:
		if a.cell.unit == null and b.cell.unit != null:
			return true
		elif a.cell.unit != null and b.cell.unit == null:
			return false
		
		return a.squared_distance_to_enemies > b.squared_distance_to_enemies


func find_cells(var unit: Enemy,
				var enemies: Array,
				var action: Action,
				var navigation_graph: Dictionary) -> Array:
	var results: Array = []
	
	for cell in navigation_graph:
		var result: MovementEvaluationResult = _evaluate_cell(
			unit, enemies, action, cell
		)
		
		results.append(result)
	
	_sort_by_preference(action.movement_preference, results)
	
	return results


func _evaluate_cell(var unit: Enemy,
					var enemies: Array,
					var action: Action,
					var cell: Cell) -> MovementEvaluationResult:
	
	var result: MovementEvaluationResult = MovementEvaluationResult.new()
	
	result.cell = cell
	
	match action.movement_preference:
		Enums.MovementPreference.HUG_ENEMIES:
			result.neighboring_enemies = _count_neighboring_units(unit.faction, cell.neighbors, true)
		Enums.MovementPreference.HUG_ALLIES:
			result.neighboring_allies = _count_neighboring_units(unit.faction, cell.neighbors, false)
		Enums.MovementPreference.ORBIT_ENEMIES:
			result.neighboring_enemies = _count_neighboring_units(unit.faction, cell.get_diagonal_neighbors(), true) -  _count_neighboring_units(unit.faction, cell.neighbors, true)
		Enums.MovementPreference.ORBIT_ALLIES:
			result.neighboring_allies = _count_neighboring_units(unit.faction, cell.get_diagonal_neighbors(), false)
		Enums.MovementPreference.FLEE:
			result.squared_distance_to_enemies = _get_squared_distance_to_enemies(cell, enemies)
	
	return result


func _count_neighboring_units(unit_faction: int, neighbors: Array, is_enemy: bool) -> int:
	var count: int = 0
	
	for neighbor in neighbors:
		if neighbor.unit != null:
			if is_enemy and neighbor.unit.is_enemy(unit_faction):
				count += 1
			elif not is_enemy and neighbor.unit.is_ally(unit_faction):
				count += 1
	
	return count


func _get_squared_distance_to_enemies(start_cell: Cell, var enemies: Array) -> float:
	var distance_squared: float = 0
	
	# Do cells and units share the same coordinates?
	for enemy in enemies:
		distance_squared += start_cell.position.distance_squared_to(enemy.position)
	
	return distance_squared


func _sort_by_preference(preference: int, movement_evaluation_results: Array) -> void:
	match(preference):
		Enums.MovementPreference.HUG_ENEMIES:
			var hug_sorter: HugSorter = HugSorter.new()
			
			hug_sorter.can_count_enemies = true
			
			movement_evaluation_results.sort_custom(hug_sorter, "sort_descending")
		Enums.MovementPreference.HUG_ALLIES:
			var hug_sorter: HugSorter = HugSorter.new()
			
			hug_sorter.can_count_enemies = false
			
			movement_evaluation_results.sort_custom(hug_sorter, "sort_descending")
		Enums.MovementPreference.ORBIT_ENEMIES:
			var hug_sorter: HugSorter = HugSorter.new()
			
			hug_sorter.can_count_enemies = true
			
			movement_evaluation_results.sort_custom(hug_sorter, "sort_descending")
		Enums.MovementPreference.ORBIT_ALLIES:
			var hug_sorter: HugSorter = HugSorter.new()
			
			hug_sorter.can_count_enemies = false
			
			movement_evaluation_results.sort_custom(hug_sorter, "sort_descending")
		Enums.MovementPreference.FLEE:
			movement_evaluation_results.sort_custom(DistanceSorter, "sort_descending")
		Enums.MovementPreference.RANDOM:
			movement_evaluation_results.shuffle()
