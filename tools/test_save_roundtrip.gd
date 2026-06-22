extends SceneTree
# Dev-only end-to-end test of GameData save/load with persistent EXP and the
# multi-squad model + migration. Writes to the real debug save path, so the
# caller must back it up first. Run:
#   godot --headless --script res://tools/test_save_roundtrip.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var gd = root.get_node("/root/GameData")
	var save_data_script = load("res://save_data/save_data.gd")

	var sd = save_data_script.new()
	var j0 = _mk_job("res://jobs/terra/bahl_job.tres")
	var j1 = _mk_job("res://jobs/terra/grace_job.tres")
	sd.jobs = [j0, j1]
	sd.active_units = [0, 1]

	var gained: int = j0.gain_exp(20000)
	_check("gain_exp returned levels gained > 0", gained > 0)

	sd.ensure_squads()              # squad 0 = [0, 1]
	var idx: int = sd.create_squad() # squad 1
	_check("create_squad returned index 1", idx == 1)
	sd.switch_to_squad(idx)
	sd.active_units = [1]            # squad 1 = [1]
	sd.rename_active_squad("ALPHA")
	sd.switch_to_squad(0)            # back to squad 0

	gd.save_data = sd
	gd.save()

	# Reload from disk into a fresh SaveData.
	gd.save_data = null
	gd.load_data()
	var r = gd.save_data

	_check("save() did not crash & reloaded", r != null)
	_check("2 jobs restored", r.jobs.size() == 2)
	_check("job0 EXP restored (20000)", r.jobs[0].current_exp == 20000)
	_check("job0 level derived from EXP (>1)", r.jobs[0].level > 1)
	_check("2 squads restored", r.squads.size() == 2)
	_check("squad 1 renamed ALPHA", r.squads[1]["name"] == "ALPHA")
	_check("squad 1 units = [1]", r.squads[1]["units"] == [1])
	_check("active squad index 0", r.active_squad_index == 0)
	_check("active_units = [0, 1]", r.active_units == [0, 1])

	print("test_save_roundtrip: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _mk_job(path: String):
	var j = load(path).duplicate()
	j.stats = j.stats.duplicate()
	j.source_path = path
	j.level = 1
	return j


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
