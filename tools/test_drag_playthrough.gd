extends SceneTree
# REAL-DRAG playthrough oracle. Drives a battle to victory using ONLY the engine's
# genuine one-unit-drag move path (pick up -> glide the unit cell-by-cell over
# PHYSICS frames so its SwapArea2D sweeps Cells -> release -> snap -> auto pincer).
# It never teleports and never touches _active_unit, so a clean sweep proves the
# real player-input path is race-free end to end (unlike test_playthrough.gd, the
# teleport smoke test, which bypasses the drag machinery).
#
# Race-freedom rests on three structural guarantees, derived from an exhaustive
# map of board.gd's drag/swap/cell-area/pincer/turn state machine:
#   1. PICKUP GATE — never pick up a unit until the board is a STABLE quiescent
#      PLAYER turn (turn==PLAYER, _is_player_interactive, no open active-cell
#      context, every unit IDLE) held for 8 consecutive frames. This defeats the
#      prior failure where a no-pincer move synchronously handed the turn to the
#      enemy (board.gd:535/545) while the player's snap area_exited signals were
#      still queued, tripping the assert at board.gd:585.
#   2. EMPTY CORRIDOR — every glide step (incl. the target) is an in-range, empty
#      cell, so _on_Cell_area_exited never calls a real _swap_units (board.gd:613)
#      and no unit ever enters STATE.SWAPPING to fire a stray cross-unit exit.
#   3. SINGLE-TILE STEPS — 5-substep lerp per orthogonal cell keeps the SwapArea2D
#      sweeping one boundary at a time (no >1-tile jump warning, board.gd:603).
#
# Move selection prefers a single drag that COMPLETES a pincer (routes the safe
# await-rich _execute_pincers path); else a SETUP drag that walks an ally onto an
# empty enemy flank; else any clean adjacent drag (liveness). Single Godot process
# per battle (driven by tools/run_drag_playtest.sh), mirroring the proven harness.
#   godot --headless --script res://tools/test_drag_playthrough.gd -- <battle.tscn>

var _victory := false
var _defeat := false

# Coordinate deltas matching grid.gd:_set_neighbors (UP=-y, DOWN=+y, RIGHT=+x).
const NEG_H := Vector2(-1, 0)
const POS_H := Vector2(1, 0)
const NEG_V := Vector2(0, -1)
const POS_V := Vector2(0, 1)

var _moves := 0
var _completing := 0
var _setup := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0] if args.size() > 0 else "res://battles/terra/borderlands.tscn"

	var battle = (load(scene_path) as PackedScene).instantiate()
	root.add_child(battle)

	var board = battle.get_node("Board")
	var grid = board.get_node("Grid")

	board.victory.connect(func(): _victory = true)
	board.defeat.connect(func(): _defeat = true)

	# Speed up combat/enemy resolution (never the interactive window).
	if board.has_method("set_fast_forward"):
		board.set_fast_forward(true)

	var max_moves := 600
	# Livelock guard counts consecutive player moves that dealt NO damage and did
	# not change the enemy roster. It resets on any damage or roster change, so a
	# legitimately high-HP boss (e.g. Ch42's 99999-HP 2x2) grinds without tripping.
	var no_progress := 0
	var last_total_hp := -1
	var last_enemy_count := -1
	const NO_PROGRESS_LIMIT := 40

	while _moves < max_moves:
		var reached = await _await_quiescent(board)

		if _victory:
			print("TEST PASS: victory after %d drag-moves (%d completing, %d setup)" % [_moves, _completing, _setup])
			quit(0)
			return
		if _defeat:
			printerr("TEST FAIL: defeat after %d drag-moves (%d completing, %d setup)" % [_moves, _completing, _setup])
			quit(1)
			return
		if not reached:
			if board._is_battle_finished:
				# victory/defeat signal will be caught on the next loop spin
				await process_frame
				continue
			printerr("TEST FAIL: could not reach a quiescent player turn (moves %d)" % _moves)
			quit(1)
			return

		# Progress detection: damage dealt or roster change => making progress.
		var total_hp := _total_enemy_hp(board)
		var enemy_count := _alive_enemies(board).size()
		if last_total_hp == -1 or total_hp < last_total_hp or enemy_count != last_enemy_count:
			no_progress = 0
		last_total_hp = total_hp
		last_enemy_count = enemy_count

		if no_progress > NO_PROGRESS_LIMIT:
			printerr("TEST FAIL: no damage/progress for %d turns; %d enemies, %d HP left (moves %d)" % [NO_PROGRESS_LIMIT, enemy_count, total_hp, _moves])
			quit(1)
			return

		var move = _select_move(board, grid)

		if move == null:
			no_progress += 1
			# Nothing legal this instant; let the board breathe and re-scan.
			await process_frame
			continue

		var did = await _drag_move(board, grid, move.mover, move.target, move.path)
		_moves += 1
		no_progress += 1

		if move.kind == "complete":
			_completing += 1
		elif move.kind == "setup":
			_setup += 1

	printerr("TEST FAIL: move cap reached (%d moves), victory=%s, enemies left=%d" % [max_moves, _victory, _alive_enemies(board).size()])
	quit(1)


# ---------------------------------------------------------------------------
# QUIESCENCE GATE
# ---------------------------------------------------------------------------
func _board_quiescent_for_player(board) -> bool:
	if board._current_turn != board.Turn.PLAYER:
		return false
	if board._is_battle_finished:
		return false
	# True only after _enable_unit_selection runs at player-turn start, i.e. after
	# all pincer/enemy resolution from the previous move has fully drained.
	if not board._is_player_interactive:
		return false
	# A non-null active-cell context means a drag is still open. (_active_unit
	# itself is intentionally left as a stale enemy ref at rest, so we do NOT
	# gate on it — see board.gd:539 _clear_active_cells leaving _active_unit.)
	if board._active_unit_current_cell != null:
		return false
	for u in board._player_units_node.get_children():
		if u.current_state != u.STATE.IDLE:
			return false
	for u in board._enemy_units_node.get_children():
		if u.current_state != u.STATE.IDLE:
			return false
	return true


func _await_quiescent(board) -> bool:
	for _i in 7200:
		if _victory or _defeat or board._is_battle_finished:
			return false
		if _board_quiescent_for_player(board):
			# Require stability so deferred Area2D enter/exit callbacks from the
			# previous move have all dispatched before we touch the board again.
			var stable := 0
			while stable < 8:
				await process_frame
				if _victory or _defeat or board._is_battle_finished:
					return false
				if _board_quiescent_for_player(board):
					stable += 1
				else:
					stable = 0
			return true
		await process_frame
	return false


# ---------------------------------------------------------------------------
# MOVE SELECTION
# ---------------------------------------------------------------------------
# Returns {mover, target (Cell), path (Array of step coords), kind} or null.
func _select_move(board, grid):
	var movers := _alive_movers(board)
	if movers.is_empty():
		return null

	var faction = movers[0].faction

	# Collect candidate enemy flank pairs (one entry per contiguous enemy run,
	# both axes; 2x2 bodies are handled naturally because all body cells hold the
	# same enemy unit). Each entry: {a (coord), b (coord)} outer flank cells.
	var flanks := _enemy_flanks(grid, faction)

	# 1) COMPLETING move: one flank already holds an actable ally, the other is an
	#    empty in-range cell reachable by a different ally through a clean corridor.
	var best_complete = null
	for fl in flanks:
		var a_cell = _cell_at(grid, fl.a)
		var b_cell = _cell_at(grid, fl.b)
		if a_cell == null or b_cell == null:
			continue
		var a_ally = _is_actable_ally(a_cell, faction)
		var b_ally = _is_actable_ally(b_cell, faction)
		var existing = null
		var target = null
		if a_ally and b_cell.unit == null:
			existing = a_cell.unit
			target = b_cell
		elif b_ally and a_cell.unit == null:
			existing = b_cell.unit
			target = a_cell
		else:
			continue
		var cand = _reach(grid, movers, target, existing)
		if cand != null and (best_complete == null or cand.path.size() < best_complete.path.size()):
			best_complete = {"mover": cand.mover, "target": target, "path": cand.path, "kind": "complete"}
	if best_complete != null:
		return best_complete

	# 2) SETUP move: walk an ally onto an empty flank of an enemy (no pincer yet),
	#    so a later turn can complete it. Prefer the shortest reachable flank.
	var best_setup = null
	for fl in flanks:
		for coord in [fl.a, fl.b]:
			var cell = _cell_at(grid, coord)
			if cell == null or cell.unit != null:
				continue
			var cand = _reach(grid, movers, cell, null)
			if cand != null and (best_setup == null or cand.path.size() < best_setup.path.size()):
				best_setup = {"mover": cand.mover, "target": cell, "path": cand.path, "kind": "setup"}
	if best_setup != null:
		return best_setup

	# 3) LIVENESS fallback: any clean single-tile drag into an adjacent empty cell.
	for mover in movers:
		var start_cell = _cell_of(grid, mover)
		if start_cell == null:
			continue
		for delta in [POS_H, NEG_H, POS_V, NEG_V]:
			var nc = start_cell.coordinates + delta
			var cell = _cell_at(grid, nc)
			if cell != null and cell.unit == null:
				return {"mover": mover, "target": cell, "path": [nc], "kind": "nudge"}

	return null


# Find a mover (alive, actable, 1x1, != excluded) with a clean empty corridor to
# target_cell. Returns {mover, path} (shortest) or null.
func _reach(grid, movers, target_cell, excluded):
	var best = null
	for mover in movers:
		if mover == excluded:
			continue
		var start_cell = _cell_of(grid, mover)
		if start_cell == null or start_cell == target_cell:
			continue
		var path = _empty_path(grid, start_cell.coordinates, target_cell.coordinates, mover)
		if not path.is_empty() and (best == null or path.size() < best.path.size()):
			best = {"mover": mover, "path": path}
	return best


# All outer flank-cell pairs for every contiguous enemy run on both axes.
func _enemy_flanks(grid, faction) -> Array:
	var seen := {}
	var out := []
	for x in grid.width:
		for y in grid.height:
			var coord := Vector2(x, y)
			if not _is_enemy_cell(grid, coord, faction):
				continue
			for axis in [[NEG_H, POS_H], [NEG_V, POS_V]]:
				var run = _enemy_run(grid, coord, axis[0], axis[1], faction)
				var key := "%s|%s|%s" % [run.a, run.b, axis[1]]
				if seen.has(key):
					continue
				seen[key] = true
				out.push_back({"a": run.a, "b": run.b})
	return out


# Walk the contiguous enemy run through `coord` along an axis; return the two
# outer flank coords just past each end.
func _enemy_run(grid, coord: Vector2, neg: Vector2, pos: Vector2, faction) -> Dictionary:
	var lo := coord
	while _is_enemy_cell(grid, lo + neg, faction):
		lo += neg
	var hi := coord
	while _is_enemy_cell(grid, hi + pos, faction):
		hi += pos
	return {"a": lo + neg, "b": hi + pos}


# ---------------------------------------------------------------------------
# REAL DRAG-MOVE PRIMITIVE (validated path from tools/test_drag_move.gd, with a
# precomputed all-empty corridor)
# ---------------------------------------------------------------------------
func _drag_move(board, grid, unit, target_cell, path: Array) -> bool:
	if target_cell == null or path.is_empty():
		return false
	if unit.current_state != unit.STATE.IDLE:
		return false

	# Headless: a PICKED_UP player unit chases get_global_mouse_position() (=> 0,0)
	# in _physics_process. Disable input control so we drive its position directly.
	var was_controlled = unit.is_controlled_by_player
	unit.is_controlled_by_player = false

	unit._pick_up()
	await physics_frame
	await process_frame
	if board._active_unit != unit:
		if unit.is_picked_up():
			unit.release()
		unit.is_controlled_by_player = was_controlled
		return false

	for step_coord in path:
		var step_cell = grid.get_cell_from_coordinates(step_coord)
		var from_pos = unit.position
		for s in range(1, 6):
			unit.position = from_pos.lerp(step_cell.position, float(s) / 5.0)
			await physics_frame
		if board._active_unit != unit or not unit.is_picked_up():
			break

	if unit.is_picked_up():
		unit.release()

	unit.is_controlled_by_player = was_controlled

	# Confirm the move was consumed (turn handed off or battle ended).
	for _k in 120:
		await process_frame
		if board._current_turn != board.Turn.PLAYER or board._is_battle_finished or not board._is_player_interactive:
			break
	return true


# ---------------------------------------------------------------------------
# GRID / PATHING HELPERS
# ---------------------------------------------------------------------------
# BFS over in-range, currently-EMPTY cells from start to target. The start cell
# (which holds the mover) is the source; every other step incl. target must be
# empty. Returns step coords (excluding start, including target) or [].
func _empty_path(grid, start: Vector2, target: Vector2, mover) -> Array:
	if not grid._is_in_range(start) or not grid._is_in_range(target):
		return []
	var target_cell = grid.get_cell_from_coordinates(target)
	if target_cell == null or target_cell.unit != null:
		return []

	var frontier := [start]
	var came_from := {start: null}
	while not frontier.is_empty():
		var cur: Vector2 = frontier.pop_front()
		if cur == target:
			break
		for delta in [POS_H, NEG_H, POS_V, NEG_V]:
			var nxt: Vector2 = cur + delta
			if came_from.has(nxt):
				continue
			if not grid._is_in_range(nxt):
				continue
			var cell = grid.get_cell_from_coordinates(nxt)
			if cell == null:
				continue
			# Every node except the source must be an empty cell.
			if cell.unit != null and nxt != target:
				continue
			if cell.unit != null and nxt == target:
				# target must be empty (already checked) — defensive.
				continue
			came_from[nxt] = cur
			frontier.push_back(nxt)

	if not came_from.has(target):
		return []
	# Reconstruct path start->target, drop the start node.
	var rev := [target]
	var node = came_from[target]
	while node != null:
		rev.push_back(node)
		node = came_from[node]
	rev.reverse()
	rev.remove_at(0)  # drop start
	return rev


func _cell_at(grid, coord: Vector2):
	if not grid._is_in_range(coord):
		return null
	return grid.get_cell_from_coordinates(coord)


func _is_enemy_cell(grid, coord: Vector2, faction) -> bool:
	var cell = _cell_at(grid, coord)
	if cell == null or cell.unit == null:
		return false
	return cell.unit.is_enemy(faction) and cell.unit.is_alive()


func _is_actable_ally(cell, faction) -> bool:
	if cell == null or cell.unit == null:
		return false
	return cell.unit.is_player() and cell.unit.can_act() and cell.unit.is_alive()


func _alive_movers(board) -> Array:
	var out := []
	for u in board._player_units_node.get_children():
		if u.is_alive() and u.can_act() and u.current_state == u.STATE.IDLE and not u.is2x2():
			out.push_back(u)
	return out


func _alive_enemies(board) -> Array:
	var out := []
	for u in board._enemy_units_node.get_children():
		if u.is_alive() and not u.is_escaped:
			out.push_back(u)
	return out


func _total_enemy_hp(board) -> int:
	var total := 0
	for u in board._enemy_units_node.get_children():
		if u.is_alive() and not u.is_escaped:
			total += u.get_stats().health
	return total


# Authoritative cell of a unit (the cell that actually holds it), robust to pixel
# position drift.
func _cell_of(grid, unit):
	for x in grid.width:
		for y in grid.height:
			var cell = grid.get_cell_from_coordinates(Vector2(x, y))
			if cell != null and cell.unit == unit:
				return cell
	return null
