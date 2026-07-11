extends SceneTree
# Regression test for the skill-activation roll convention: a POSITIVE
# skill_activation_rate_modifier must make skills fire MORE often, and
# Demoralize's -1 must make them never fire (unit.gd activate_skills and the
# counter queue in attacker.gd share the convention).
#   godot --headless --script res://tools/test_activation.gd

var _fails := 0


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

	var players: Array = board._player_units_node.get_children()
	var unit = players[0]
	var job_node = unit.get_node("Job")

	# Isolate the roll: no companion procs, no Powered Point guarantee.
	# (Autoloads are fetched by node path: --script SceneTree tools cannot
	# always resolve autoload identifiers at compile time.)
	job_node.job.companion = null
	root.get_node("/root/Events").power_boost_active = false

	# Give every unlocked skill a base rate of 0.5 so the modifier's sign is
	# observable in both directions.
	for skill in unit.get_unlocked_skills():
		skill.activation_rate = 0.5

	# Demoralize convention: -1 disables all skills, always.
	job_node.current_stats.skill_activation_rate_modifier = -1.0
	var fired_with_minus_one := 0
	for i in 200:
		fired_with_minus_one += unit.activate_skills().size()
	_check("modifier -1 never activates skills", fired_with_minus_one == 0)

	# A +0.5 modifier on a 0.5 base rate reaches certainty.
	job_node.current_stats.skill_activation_rate_modifier = 0.5
	var always := true
	for i in 200:
		if unit.activate_skills().is_empty():
			always = false
			break
	_check("modifier +0.5 on rate 0.5 always activates", always)

	# Sanity: a positive modifier fires at least as often as no modifier.
	job_node.current_stats.skill_activation_rate_modifier = 0.0
	var base_fires := 0
	for i in 400:
		base_fires += unit.activate_skills().size()

	job_node.current_stats.skill_activation_rate_modifier = 0.4
	var boosted_fires := 0
	for i in 400:
		boosted_fires += unit.activate_skills().size()
	_check("positive modifier raises activation frequency (%d > %d)" % [boosted_fires, base_fires],
			boosted_fires > base_fires)

	if _fails == 0:
		print("ALL ACTIVATION TESTS PASS")
		quit(0)
	else:
		printerr("%d ACTIVATION TESTS FAILED" % _fails)
		quit(1)


func _check(what: String, ok: bool) -> void:
	if ok:
		print("PASS: %s" % what)
	else:
		printerr("FAIL: %s" % what)
		_fails += 1
