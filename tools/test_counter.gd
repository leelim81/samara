extends SceneTree
# End-to-end counterattack test through the real combat pipeline: give the
# first enemy a guaranteed COUNTER skill and unkillable HP, run a real player
# pincer, and assert the pincering units got hit back ("Enemy counter" phase,
# Terra Battle turn order). Also asserts no counter fires when the enemy has
# no COUNTER skill.
#   godot --headless --script res://tools/test_counter.gd

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

	var enemy = null
	for c in enemies:
		if c.is_alive() and not c.is2x2():
			enemy = c
			break
	if enemy == null or players.size() < 2:
		printerr("FAIL: not enough units")
		quit(1)
		return

	# Make the enemy unkillable so it survives the pincer and counters.
	var enemy_job = enemy.get_node("Job")
	enemy_job.base_stats.health = 9999999
	enemy_job.current_stats.health = 9999999

	# Give it a guaranteed counterattack. Enemies read skills from the Job
	# NODE's `skills` array (see enemy.gd get_skills), not the job resource.
	var counter: Skill = (load("res://skills/resources/terra/counterattack.tres") as Skill).duplicate()
	counter.activation_rate = 1.0
	enemy_job.skills.insert(0, counter)

	_check("enemy has a counter skill", enemy.get_counter_skill() != null)

	# Park the enemy mid-board and flank it.
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

	var a = players[0]
	var b = players[1]
	_teleport(grid, a, left)
	_teleport(grid, b, right)

	var hp_a_before: int = a.get_stats().health
	var hp_b_before: int = b.get_stats().health

	# Check immediately on return: counters resolve inside _execute_pincers,
	# and waiting frames would let the (just-started) enemy turn contaminate
	# the player HP readings.
	await board._execute_pincers(a)

	_check("enemy survived the pincer (counter precondition)", enemy.is_alive())
	_check("pincering unit A was hit by the counter", a.get_stats().health < hp_a_before)
	_check("pincering unit B was hit by the counter", b.get_stats().health < hp_b_before)

	print("test_counter: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
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
