extends SceneTree
# Extend Chain rule test (Terra Battle): units chained on a side act as
# additional chaining points when that side includes an Extend Chain holder.
# Board layout (x,y):
#   P1(1,4)  E(2,4)  P2(3,4)   — leading horizontal pincer
#   C(3,1)                     — chained to P2 through the empty column gap
#   D(5,1)                     — in line with C only (row 1), NOT with P1/P2
# Without Extend Chain on C: D is not chained. With it: D chains through C.
#   godot --headless --script res://tools/test_extend_chain.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle = (load("res://battles/terra/borderlands.tscn") as PackedScene).instantiate()
	root.add_child(battle)
	var board = battle.get_node("Board")

	var reached := false
	for i in 1200:
		await process_frame
		if board._current_turn == board.Turn.PLAYER:
			reached = true
			break
	if not reached:
		printerr("FAIL: player turn never started")
		quit(1)
		return

	var grid = board.get_node("Grid")
	var pincerer = board.get_node("Pincerer")
	var players: Array = board._player_units_node.get_children()
	var enemies: Array = []
	for e in board._enemy_units_node.get_children():
		if e.is_alive() and not e.is2x2():
			enemies.push_back(e)

	if enemies.is_empty():
		printerr("FAIL: need at least 1 enemy")
		quit(1)
		return

	# The starter squad has only 3 units; clone one so we have the 4 the
	# layout needs (clone gets its own duplicated job, player faction kept).
	# NOTE: no Unit/Skill type annotations here — typing them makes Godot
	# compile unit.gd in --script context, where autoloads don't resolve.
	while players.size() < 4:
		var template = players[0]
		var clone = template.duplicate()
		board._player_units_node.add_child(clone)
		clone.faction = template.PLAYER_FACTION
		clone.set_job(template.get_node("Job").job.duplicate())
		await process_frame
		players = board._player_units_node.get_children()

	# Clear the lines we care about: park spare enemies on rows 5/6.
	var parking := [Vector2(0, 6), Vector2(5, 6), Vector2(0, 5), Vector2(5, 5), Vector2(4, 6), Vector2(1, 6)]
	for i in range(1, enemies.size()):
		if i - 1 < parking.size():
			_teleport(grid, enemies[i], grid.get_cell_from_coordinates(parking[i - 1]))

	var a = players[0]
	var b = players[1]
	var c = players[2]
	var d = players[3]

	_teleport(grid, enemies[0], grid.get_cell_from_coordinates(Vector2(2, 4)))
	_teleport(grid, a, grid.get_cell_from_coordinates(Vector2(1, 4)))
	_teleport(grid, b, grid.get_cell_from_coordinates(Vector2(3, 4)))
	_teleport(grid, c, grid.get_cell_from_coordinates(Vector2(3, 1)))
	_teleport(grid, d, grid.get_cell_from_coordinates(Vector2(5, 1)))
	for i in range(4, players.size()):
		_teleport(grid, players[i], grid.get_cell_from_coordinates(Vector2(i - 4, 7)))

	# --- Without Extend Chain ---
	var pincer = _leading_pincer(pincerer, grid, a)
	if pincer == null:
		printerr("FAIL: no leading pincer found")
		quit(1)
		return
	pincerer.find_chains(grid, pincer)

	_check("C chains to P2 across the column gap", _is_chained(pincer, c))
	_check("D is NOT chained without Extend Chain", not _is_chained(pincer, d))

	# --- Give C Extend Chain (slot 1 so it is unlocked at any level) ---
	var ec = (load("res://skills/resources/terra/extend_chain.tres") as Resource).duplicate()
	var c_job = c.get_node("Job")
	c_job.job = c_job.job.duplicate()
	c_job.job.skills = [ec] + c_job.job.skills.duplicate()

	_check("C now has Extend Chain", c.has_extend_chain())

	pincer = _leading_pincer(pincerer, grid, a)
	pincerer.find_chains(grid, pincer)

	_check("C still chained", _is_chained(pincer, c))
	_check("D chains through C with Extend Chain", _is_chained(pincer, d))

	print("test_extend_chain: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _leading_pincer(pincerer, grid, active_unit):
	var pincers: Array = pincerer.find_pincers(grid, active_unit)
	for pincer in pincers:
		if pincer.pincering_units.has(active_unit):
			return pincer
	return null


func _is_chained(pincer, unit) -> bool:
	for chains in pincer.chain_families.values():
		for chain in chains:
			if chain.has(unit):
				return true
	return false


func _teleport(grid, unit, target_cell) -> void:
	var current_cell = grid.get_cell_from_position(unit.position)
	if current_cell != null and current_cell.unit == unit:
		current_cell.unit = null
	if target_cell.unit != null and target_cell.unit != unit:
		var displaced = target_cell.unit
		displaced.position = current_cell.position
		current_cell.unit = displaced
	target_cell.unit = unit
	unit.position = target_cell.position


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
