extends SceneTree
# Board-level status rules from the Terra Battle wiki:
#   - Icebind: a frozen unit dies when pincered.
#   - Petrify: blocks acting but NOT chaining; Sleep blocks both.
#   godot --headless --script res://tools/test_status_board.gd

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
	var enemies: Array = board._enemy_units_node.get_children()

	if players.size() < 3:
		printerr("FAIL: need at least 3 player units")
		quit(1)
		return

	# Chain eligibility rules on a live unit.
	var chain_probe = players[2]
	# No StatusEffect type hints here: a typed cast would force the resource
	# script to compile before autoloads register in --script mode.
	var petrify = load("res://status_effects/petrify.tres").duplicate()
	chain_probe.get_status_effects().append(petrify)
	_check("petrified unit cannot act", not chain_probe.can_act())
	_check("petrified unit still passes chains (wiki)", chain_probe.can_chain())
	chain_probe.get_status_effects().clear()

	var sleep = load("res://status_effects/sleep.tres").duplicate()
	chain_probe.get_status_effects().append(sleep)
	_check("sleeping unit cannot act", not chain_probe.can_act())
	_check("sleeping unit cannot chain", not chain_probe.can_chain())
	chain_probe.get_status_effects().clear()

	# Icebind shatter: pincering a frozen, otherwise unkillable enemy kills it.
	var enemy = null
	for c in enemies:
		if c.is_alive() and not c.is2x2():
			enemy = c
			break
	if enemy == null or players.size() < 2:
		printerr("FAIL: not enough units")
		quit(1)
		return

	var enemy_job = enemy.get_node("Job")
	enemy_job.base_stats.health = 9999999
	enemy_job.current_stats.health = 9999999

	var icebind = load("res://status_effects/icebind.tres").duplicate()
	enemy.get_status_effects().append(icebind)
	_check("enemy is icebound", enemy.has_status_effect_of_type(Enums.StatusEffectType.ICEBIND))

	var enemy_cell = grid.get_cell_from_position(enemy.position)
	var mid = grid.get_cell_from_coordinates(Vector2(2, 4))
	if mid.unit == null:
		enemy_cell.unit = null
		mid.unit = enemy
		enemy.position = mid.position
		enemy_cell = mid
	var coords: Vector2 = enemy_cell.coordinates
	var left = grid.get_cell_from_coordinates(coords + Vector2.LEFT)
	var right = grid.get_cell_from_coordinates(coords + Vector2.RIGHT)

	_teleport(grid, players[0], left)
	_teleport(grid, players[1], right)

	await board._execute_pincers(players[0])

	_check("icebound enemy shattered when pincered (wiki)", enemy.is_dead())

	print("test_status_board: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


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
