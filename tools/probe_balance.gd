extends SceneTree
# Probe: print both sides' stats and formula damage for a battle so the
# balance can be judged numerically.
#   godot --headless --script res://tools/probe_balance.gd -- <battle.tscn>


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://battles/terra/laws_of_the_jungle.tscn"

	var battle = (load(path) as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")

	for i in 3000:
		await process_frame

		if board._current_turn == board.Turn.PLAYER:
			break

	var p = board.get_player_units()[0]
	var ps = p.get_stats()

	print("PLAYER %s L%d: HP %d ATK %d DEF %d SATK %d SDEF %d" % [
		p.get_job().job_name, p.get_level(), ps.health, ps.attack, ps.defense, ps.spiritual_attack, ps.spiritual_defense])

	var all_enemies: Array = []

	for phase in board._enemy_phases_queue:
		all_enemies.append_array(phase.get_children())

	if all_enemies.is_empty():
		all_enemies = board._enemy_units_node.get_children()

	for e in all_enemies:
		var es = e.get_stats()
		var dmg_to_enemy: int = int(1.395 * pow(ps.attack, 1.7) / pow(es.defense, 0.7))
		var dmg_to_player: int = int(1.395 * pow(es.attack, 1.7) / pow(ps.defense, 0.7))

		print("ENEMY %s L%d: HP %d ATK %d DEF %d | player hit deals %d (%d%% of enemy HP) | enemy hit deals %d (%d%% of player HP)" % [
			e.get_job().job_name, e.get_level(), es.health, es.attack, es.defense,
			dmg_to_enemy, 100 * dmg_to_enemy / max(1, es.health),
			dmg_to_player, 100 * dmg_to_player / max(1, ps.health)])

	quit(0)
