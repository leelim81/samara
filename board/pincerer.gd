class_name Pincerer
extends Node
# Finds pincers and chains by walking through the grid.


# Finds pincers without chains. The chains must be found before Board executes
# the pincer, in case that a pincer cleared up enemy units and thus the next
# pincer can now chain with units that were previously blocked.
func find_pincers(grid: Grid, active_unit: Unit) -> Array:
	# List of pincers with the active unit. Horizontal, vertical, and corners
	# Array<Pincer>
	var leading_pincers := []
	
	# All remaining pincers
	# Array<Pincer>
	var pincers := []
	
	var grid_width: int = grid.width
	var grid_height: int = grid.height
	var faction = active_unit.faction
	
	# Check left to right, down to up
	# from height - 1, step -1, while > -1
	for y in range(grid_height - 1, -1, -1):
		var x: int = 0
		
		while x < grid_width:
			var pincer: Pincer = _check_neighbors_for_pincers(grid, x, y, faction, Enums.DIRECTION.RIGHT, Enums.PincerOrientation.HORIZONTAL)
			
			if pincer == null:
				x += 1
			else:
				x += pincer.size() - 1
				
				_add_pincer(active_unit, leading_pincers, pincers, pincer)
	
	# Check vertical pincers
	for x in grid_width:
		var y: int = grid_height - 1
		
		while y > -1:
			var pincer: Pincer = _check_neighbors_for_pincers(grid, x, y, faction, Enums.DIRECTION.UP, Enums.PincerOrientation.VERTICAL)
			
			if pincer == null:
				y -= 1
			else:
				y = y - pincer.size() + 1
				
				_add_pincer(active_unit, leading_pincers, pincers, pincer)
	
	# Check corners
	_find_corner_pincers(grid, active_unit, leading_pincers, pincers)
	
	var all_pincers := []
	
	all_pincers.append_array(leading_pincers)
	all_pincers.append_array(pincers)
	
	return all_pincers


# Finds and sets a pincer's chains
func find_chains(grid:Grid, pincer: Pincer) -> void:
	var pincering_units: Array = pincer.pincering_units
	
	var faction: int = pincering_units.front().faction
	
	var chain_families: Dictionary = {}
	
	for pincering_unit in pincering_units:
		assert(pincering_unit != null)
		
		chain_families[pincering_unit] = []
	
	# Get the cells from the recorded positions because if the unit is being
	# pushed while checking the chains then you may get the wrong cell
	var cells: Array = [grid.get_cell_from_position(pincer.start_position), grid.get_cell_from_position(pincer.end_position)]

	# Powered Points and capsules chained per SIDE (per pincering unit), so
	# the Extend Chain pass below only branches from the side holding the skill
	var side_pickups: Array = [_new_pickups(), _new_pickups()]

	for i in cells.size():
		var cell: Cell = cells[i]

		# A pincering unit standing on a Powered Point / capsule chains it too
		_collect_pickups(cell, side_pickups[i])

		_find_chain(cell, Enums.DIRECTION.RIGHT, chain_families, pincering_units[i], faction, side_pickups[i])
		_find_chain(cell, Enums.DIRECTION.LEFT, chain_families, pincering_units[i], faction, side_pickups[i])
		_find_chain(cell, Enums.DIRECTION.UP, chain_families, pincering_units[i], faction, side_pickups[i])
		_find_chain(cell, Enums.DIRECTION.DOWN, chain_families, pincering_units[i], faction, side_pickups[i])

	# Extend Chain (TB): if a side of the chain includes a unit with the
	# skill, every unit, Powered Point and capsule chained on that side acts
	# as an additional chaining point, recursively.
	for i in pincering_units.size():
		if _side_has_extend_chain(pincering_units[i], chain_families):
			_extend_side(grid, pincering_units[i], chain_families, faction, side_pickups[i])

	pincer.chained_powered_cells = []
	pincer.chained_capsule_cells = []

	for pickups in side_pickups:
		for cell in pickups.powered:
			if not pincer.chained_powered_cells.has(cell):
				pincer.chained_powered_cells.push_back(cell)

		for cell in pickups.capsules:
			if not pincer.chained_capsule_cells.has(cell):
				pincer.chained_capsule_cells.push_back(cell)

	pincer.chain_families = chain_families


func _new_pickups() -> Dictionary:
	return {"powered": [], "capsules": []}


# Records a chained Powered Point or capsule lying on this cell
func _collect_pickups(cell: Cell, pickups: Dictionary) -> void:
	if cell.is_powered and not pickups.powered.has(cell):
		pickups.powered.push_back(cell)

	if cell.capsule_type != Enums.CapsuleType.NONE and not pickups.capsules.has(cell):
		pickups.capsules.push_back(cell)


# True if the pincering unit or any unit chained to it has an Extend Chain skill
func _side_has_extend_chain(pincering_unit: Unit, chain_families: Dictionary) -> bool:
	if pincering_unit.has_extend_chain():
		return true

	for chain in chain_families[pincering_unit]:
		for unit in chain:
			if unit.has_extend_chain():
				return true

	return false


# Walks perpendicular chains from every chained unit, Powered Point and
# capsule on this side, repeatedly, until no new chaining points appear
# (Extend Chain rule).
func _extend_side(grid: Grid, owner: Unit, chain_families: Dictionary, faction: int, pickups: Dictionary) -> void:
	var processed := {}

	while true:
		var anchors: Array = []

		for chain in chain_families[owner]:
			for unit in chain:
				var cell: Cell = grid.get_cell_from_position(unit.position)

				if cell != null and not processed.has(cell):
					anchors.push_back(cell)

		for cell in pickups.powered:
			if not processed.has(cell):
				anchors.push_back(cell)

		for cell in pickups.capsules:
			if not processed.has(cell):
				anchors.push_back(cell)

		if anchors.is_empty():
			break

		for anchor in anchors:
			processed[anchor] = true

			_find_chain(anchor, Enums.DIRECTION.RIGHT, chain_families, owner, faction, pickups)
			_find_chain(anchor, Enums.DIRECTION.LEFT, chain_families, owner, faction, pickups)
			_find_chain(anchor, Enums.DIRECTION.UP, chain_families, owner, faction, pickups)
			_find_chain(anchor, Enums.DIRECTION.DOWN, chain_families, owner, faction, pickups)


func _find_corner_pincers(grid: Grid, active_unit: Unit, leading_pincers: Array, pincers: Array) -> void:
	var corner_pincers := []
	
	var faction: int = active_unit.faction
	
	corner_pincers.push_back(_find_corner_pincer(grid.get_bottom_left_corner(), faction, Enums.PincerOrientation.BOTTOM_LEFT_CORNER))
	corner_pincers.push_back(_find_corner_pincer(grid.get_bottom_right_corner(), faction, Enums.PincerOrientation.BOTTOM_RIGHT_CORNER))
	corner_pincers.push_back(_find_corner_pincer(grid.get_top_left_corner(), faction, Enums.PincerOrientation.TOP_LEFT_CORNER))
	corner_pincers.push_back(_find_corner_pincer(grid.get_top_right_corner(), faction, Enums.PincerOrientation.TOP_RIGHT_CORNER))
	
	for pincer in corner_pincers:
		if pincer != null:
			_add_pincer(active_unit, leading_pincers, pincers, pincer)


func _find_corner_pincer(corner: Cell, faction: int, pincer_orientation: int) -> Pincer:
	var neighbors: Array = corner.neighbors
	
	assert(neighbors.size() == 2, "Corner should have 2 neighbors")
	
	var pincer: Pincer = Pincer.new()
	
	var is_pincer: bool = false
	
	if corner.unit != null and corner.unit.is_enemy(faction):
		for neighbor in neighbors:
			if neighbor.unit != null and neighbor.unit.is_ally(faction) and neighbor.unit.can_act():
				# This _will_ set the flag to true prematurely, before the other
				# neighbor is evaluated, but that's why the flag is set to false
				# in the other branch
				is_pincer = true
			else:
				is_pincer = false
				
				break
	
	if is_pincer:
		for neighbor in neighbors:
			pincer.pincering_units.push_back(neighbor.unit)
		
		pincer.pincered_units.push_back(corner.unit)
		
		pincer.pincer_orientation = pincer_orientation
		
		pincer.start_position = neighbors[0].position
		pincer.end_position = neighbors[1].position
		
		return pincer
	else:
		return null


# Adds the given pincer to the leading_pincers or pincers arrays
func _add_pincer(active_unit: Unit, leading_pincers: Array, pincers: Array, pincer: Pincer) -> void:
	if pincer == null:
		return
	
	if pincer.pincering_units.find(active_unit) != -1:
		leading_pincers.push_back(pincer)
	else:
		pincers.push_back(pincer)


func _check_neighbors_for_pincers(grid: Grid, start_x: int, start_y: int, faction: int, direction: int, pincer_orientation: int) -> Pincer:
	var cell: Cell = grid.get_cell_from_coordinates(Vector2(start_x, start_y))
	
	var unit = cell.unit
	
	var pincer: Pincer = Pincer.new()
	
	pincer.start_position = cell.position
	
	# Flag enabled if a pincer is detected
	var is_pincer := false
	
	if unit != null and unit.can_act() and unit.is_ally(faction):
		# Start unit
		pincer.pincering_units.push_back(unit)
		
		var neighbor: Cell = cell.get_neighbor(direction)
		
		while neighbor != null:
			var next_unit = neighbor.unit
			
			if next_unit == null:
				# No unit, so we can't make a pincer
				break
			elif next_unit.is_enemy(faction):
				# Is an enemy
				
				# Check if the unit has not been added before, to avoid adding
				# 2x2 units twice
				if not pincer.pincered_units.has(next_unit):
					pincer.pincered_units.push_back(next_unit)
				
				neighbor = neighbor.get_neighbor(direction)
			else:
				# Is an ally
				# Check if the last unit added to the list was an enemy
				if (not pincer.pincered_units.is_empty()) and pincer.pincered_units.back().is_enemy(faction) and next_unit.can_act():
					is_pincer = true
					
					# End unit
					pincer.pincering_units.push_back(next_unit)
					
					pincer.end_position = neighbor.position
				
				# Else, it's an ally followed by another ally,
				# we can't make a pincer. Either way you have to break
				
				break
	
	if is_pincer:
		assert(pincer.pincering_units.size() == 2, "Pincer should have 2 pincering/leading units")
		
		pincer.pincer_orientation = pincer_orientation
		
		return pincer
	else:
		return null


# Finds a chain from a given cell.
# Terra Battle rule: a unit is chained if it is in the same row or column as a
# pincering unit and there are no ENEMIES (or obstacles) between them — empty
# cells and allies that can't act do NOT break the chain. Powered Points and
# capsules lying on the line are chained too (collected into `pickups`).
func _find_chain(cell: Cell, direction: int, chain_families: Dictionary, family_owner: Unit, faction: int, pickups: Dictionary) -> void:
	var neighbor = cell.get_neighbor(direction)

	var chain_level: int = 0

	while(neighbor != null):
		var chained_unit: Unit = neighbor.unit

		if chained_unit != null and chained_unit.is_enemy(faction):
			# Enemies break the chain, stop searching
			break

		_collect_pickups(neighbor, pickups)

		if chained_unit != null and chained_unit.is_ally(faction) and chained_unit.can_act() \
				and not chain_families.has(chained_unit):
			var chains: Array = chain_families[family_owner]

			if chains.size() < chain_level + 1:
				chains.push_back([])

			var chain: Array = chains[chain_level]

			if not _is_in_any_chain(chained_unit, chain_families):
				chain_level += 1

				chain.push_back(chained_unit)

		neighbor = neighbor.get_neighbor(direction)


func _is_in_any_chain(unit: Unit, chain_families: Dictionary) -> bool:
	for chains in chain_families.values():
		for chain in chains:
			if chain.find(unit) != -1:
				return true
	
	return false
