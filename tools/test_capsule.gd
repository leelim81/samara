extends SceneTree
# Capsule test through the real combat pipeline (Terra Battle): plant a
# RECOVERY and a COIN capsule on the pincering unit's column so the chain
# collects them, run a real pincer, and assert the squad was healed, the coins
# were granted, and both capsules were consumed (capsule phase after healing).
#   godot --headless --script res://tools/test_capsule.gd

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
	var players: Array = board._player_units_node.get_children()

	var enemy = null
	for c in board._enemy_units_node.get_children():
		if c.is_alive() and not c.is2x2():
			enemy = c
			break
	if enemy == null or players.size() < 2:
		printerr("FAIL: not enough units")
		quit(1)
		return

	# Park the enemy mid-board and flank it.
	var enemy_cell = grid.get_cell_from_position(enemy.position)
	var mid = grid.get_cell_from_coordinates(Vector2(2, 4))
	if mid.unit == null:
		enemy_cell.unit = null
		mid.unit = enemy
		enemy.position = mid.position
		enemy_cell = mid
	var coords: Vector2 = enemy_cell.coordinates
	var a = players[0]
	var b = players[1]
	_teleport(grid, a, grid.get_cell_from_coordinates(coords + Vector2.LEFT))
	_teleport(grid, b, grid.get_cell_from_coordinates(coords + Vector2.RIGHT))

	# Plant capsules on A's column (row 2 recovery, row 1 coin) — both lie on
	# the chain line from A, with an empty gap in between (gaps don't break).
	var recovery_cell = grid.get_cell_from_coordinates(Vector2(coords.x - 1, 2))
	var coin_cell = grid.get_cell_from_coordinates(Vector2(coords.x - 1, 1))
	_plant(board, recovery_cell, 1) # CapsuleType.RECOVERY
	_plant(board, coin_cell, 2) # CapsuleType.COIN
	board._capsule_coin_amounts[coin_cell] = 77

	# Wound A so the recovery capsule has something to heal.
	a.inflict_damage(int(a.get_max_health() * 0.5))
	var hp_before: int = a.get_stats().health
	var coins_before: int = board._battle_coins

	await board._execute_pincers(a)

	_check("A was healed by the recovery capsule", a.get_stats().health > hp_before)
	_check("coin capsule granted its coins", board._battle_coins >= coins_before + 77)
	_check("recovery capsule consumed", recovery_cell.capsule_type == 0)
	_check("coin capsule consumed", coin_cell.capsule_type == 0)
	_check("capsule discs cleaned up", board._capsule_discs.is_empty())

	print("test_capsule: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _plant(board, cell, capsule_type: int) -> void:
	cell.capsule_type = capsule_type
	var disc = board.CAPSULE_SCENE.instantiate()
	board._capsules_node.add_child(disc)
	disc.position = cell.position
	disc.initialize(capsule_type)
	board._capsule_discs[cell] = disc


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
