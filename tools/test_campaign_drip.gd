extends SceneTree
# Campaign integration test: plays ALL 42 chapters in story order with the real
# recruitment drip - 3 starters, heroes joining via chapter_data.unlocked_job_paths
# as chapters clear - using the same teleport-pincer bot as test_playthrough.gd.
# The squad before each battle is the first up-to-6 units the player owns at that
# point in the story, so this is the campaign as a new player actually meets it.
# Never calls GameData.save().
#   godot --headless --script res://tools/test_campaign_drip.gd

var _victory := false
var _defeat := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# Fresh drip save, built from the default resource (3 starters).
	var default_save: SaveData = load("res://save_data/default_save_data.tres")
	var sd: SaveData = default_save.duplicate()

	sd.jobs = []

	for job in default_save.jobs:
		var j: Job = job.duplicate()
		j.stats = j.stats.duplicate()
		j.source_path = job.source_path if job.source_path != "" else job.resource_path
		sd.jobs.push_back(j)

	# Autoload globals are not compile-time identifiers in --script entry
	# scripts; fetch the singleton node at runtime instead.
	var game_data = root.get_node("/root/GameData")
	game_data.save_data = sd

	var cl: ChapterList = load("res://chapter_data/main_story_chapter_list.tres")
	sd.unlock_chapter(cl.chapters[0].title)

	var results: Array = []
	var fails := 0

	for i in cl.chapters.size():
		var chapter: ChapterData = cl.chapters[i]

		sd.active_units = []
		for u in range(min(6, sd.jobs.size())):
			sd.active_units.push_back(u)

		var squad_size: int = sd.active_units.size()
		var verdict: String = await _play_chapter(chapter)

		results.push_back("%2d  %-22s %-18s squad=%d roster=%d" % [
			i + 1, chapter.title, verdict, squad_size, sd.jobs.size()])

		if not verdict.begins_with("PASS"):
			fails += 1

		# Progress the story either way so later chapters see their drip roster.
		sd.clear_chapter_and_unlock_next(chapter.title)

	print("=== CAMPAIGN DRIP PLAYTEST ===")
	for r in results:
		print(r)
	print("==============================")

	if fails == 0 and sd.jobs.size() == 25:
		print("CAMPAIGN DRIP: PASS (42/42 chapters, roster ends at 25)")
		quit(0)
	else:
		print("CAMPAIGN DRIP: FAIL (%d chapter failures, roster %d)" % [fails, sd.jobs.size()])
		quit(1)


func _play_chapter(chapter: ChapterData) -> String:
	_victory = false
	_defeat = false

	var battle = (load(chapter.battle_scene_path) as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")

	board.victory.connect(func(): _victory = true)
	board.defeat.connect(func(): _defeat = true)

	var rounds := 0
	var no_flank_streak := 0
	var verdict := "TIMEOUT"

	for i in 20000:
		await process_frame

		if _victory:
			verdict = "PASS (%d rounds)" % rounds
			break

		if _defeat:
			verdict = "FAIL defeat"
			break

		if board._current_turn != board.Turn.PLAYER:
			continue

		for j in 20:
			await process_frame

		if _victory or _defeat:
			continue

		var players := _alive_players(board)

		if players.size() < 2:
			continue

		var flanks := []
		var scan := _alive_enemies(board)
		scan.sort_custom(func(a, b): return a.is2x2() and not b.is2x2())

		for enemy in scan:
			var f := _find_flank_cells(grid, enemy)

			if not f.is_empty():
				flanks = f
				break

		if flanks.is_empty():
			no_flank_streak += 1

			if no_flank_streak > 40:
				verdict = "FAIL no-flank"
				break

			continue

		no_flank_streak = 0

		_teleport(grid, players[0], flanks[0])
		_teleport(grid, players[1], flanks[1])

		rounds += 1

		await board._execute_pincers(players[0])

	battle.queue_free()

	for j in 5:
		await process_frame

	return verdict


func _alive_players(board) -> Array:
	var result := []

	for unit in board._player_units_node.get_children():
		if unit.is_alive():
			result.push_back(unit)

	return result


func _alive_enemies(board) -> Array:
	var result := []

	for unit in board._enemy_units_node.get_children():
		if unit.is_alive() and not unit.is_escaped:
			result.push_back(unit)

	return result


# Real pincers work at ANY distance along a row/column with enemies between,
# so walk outward past enemy runs to the first free (or player-held) cell on
# each side. Handles clustered enemies and wall-hugging bosses the adjacent-only
# variant in test_playthrough.gd cannot flank.
func _find_flank_cells(grid, enemy) -> Array:
	var cell = _cell_of(grid, enemy)

	if cell == null:
		return []

	var c: Vector2 = cell.coordinates
	var w := 2 if enemy.is2x2() else 1

	var walks := [
		[c + Vector2(-1, 0), Vector2(-1, 0), c + Vector2(w, 0), Vector2(1, 0)],
		[c + Vector2(0, -1), Vector2(0, -1), c + Vector2(0, w), Vector2(0, 1)],
	]

	for walk in walks:
		var a = _walk_to_free(grid, walk[0], walk[1])
		var b = _walk_to_free(grid, walk[2], walk[3])

		if a != null and b != null:
			return [a, b]

	return []


# First cell from `start` along `step` that is empty or player-held; walking
# past other enemies is fine (they get pincered too). Null if a wall comes first.
func _walk_to_free(grid, start: Vector2, step: Vector2):
	var p := start

	while grid._is_in_range(p):
		var cell = grid.get_cell_from_coordinates(p)

		if cell == null:
			return null

		if cell.unit == null or cell.unit.faction == 1:
			return cell

		p += step

	return null


func _is_free(cell, enemy) -> bool:
	if cell == null or cell.unit == enemy:
		return false

	return cell.unit == null or cell.unit.faction == 1


func _cell_of(grid, unit):
	for x in grid.width:
		for y in grid.height:
			var cell = grid.get_cell_from_coordinates(Vector2(x, y))

			if cell != null and cell.unit == unit:
				return cell

	return null


func _teleport(grid, unit, target_cell) -> void:
	if target_cell == null:
		return

	var current_cell = _cell_of(grid, unit)

	if current_cell == target_cell:
		return

	var displaced = target_cell.unit

	if current_cell != null:
		current_cell.unit = displaced

		if displaced != null:
			displaced.position = current_cell.position

	target_cell.unit = unit
	unit.position = target_cell.position
