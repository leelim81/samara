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

	sd.ensure_uids()
	var uid0: String = sd.jobs[0].uid
	var uid1: String = sd.jobs[1].uid
	_check("uids minted non-empty", uid0 != "" and uid1 != "")
	_check("uids are distinct", uid0 != uid1)

	sd.tutorial_seen = true
	sd.mark_enemy_defeated("res://jobs/terra/golem_job.tres")
	sd.mark_enemy_seen("res://jobs/terra/mantle_slime_job.tres")
	sd.add_account_exp(5000)
	sd.add_item("scrap", 3)
	sd.add_item("alloy", 1)
	sd.add_owned_companion("res://companions/resources/terra/striker_module.tres")
	sd.equipped_companions[uid0] = "res://companions/resources/terra/striker_module.tres"

	for _n in 8:
		j0.register_skill_use(0)

	j0.add_luck(7)
	j0.metamorphose()

	var gained: int = j0.gain_exp(20000)
	var awakened_atk: int = j0.stats.attack
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
	_check("job0 uid restored", r.jobs[0].uid == uid0)
	_check("job1 uid restored", r.jobs[1].uid == uid1)
	_check("next_uid persisted (>= 3)", r.next_uid >= 3)
	_check("tutorial_seen restored", r.tutorial_seen == true)
	_check("enemy defeated state restored", r.enemy_encounter_state("res://jobs/terra/golem_job.tres") == SaveData.ENCOUNTER_DEFEATED)
	_check("enemy seen state restored", r.enemy_encounter_state("res://jobs/terra/mantle_slime_job.tres") == SaveData.ENCOUNTER_SEEN)
	_check("account_exp restored", r.account_exp == 5000)
	_check("account_level derived (>1)", r.account_level() > 1)
	_check("inventory scrap restored", r.item_count("scrap") == 3)
	_check("inventory alloy restored", r.item_count("alloy") == 1)
	_check("remove_item succeeds when enough", r.remove_item("scrap", 2) == true)
	_check("remove_item leaves remainder", r.item_count("scrap") == 1)
	_check("remove_item fails when short", r.remove_item("scrap", 5) == false)
	_check("owned companion restored", r.is_companion_owned("res://companions/resources/terra/striker_module.tres"))
	_check("baked companion seeded as owned", r.is_companion_owned("res://companions/resources/terra/earth_sword.tres"))
	_check("equipped companion applied to job0", r.jobs[0].companion != null and r.jobs[0].companion.resource_path == "res://companions/resources/terra/striker_module.tres")
	_check("skill_uses restored", r.jobs[0].skill_uses.size() > 0 and int(r.jobs[0].skill_uses[0]) == 8)
	_check("skill_boost restored", is_equal_approx(r.jobs[0].get_skill_boost(0), 0.02))
	_check("luck restored", r.jobs[0].luck == 7)
	_check("awakened restored", r.jobs[0].awakened == true)
	_check("awakened stats re-applied on load", r.jobs[0].stats.attack == awakened_atk)

	print("test_save_roundtrip: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _mk_job(path: String):
	var j = load(path).duplicate()
	j.stats = j.stats.duplicate()
	j.stats.uses_growth_curve = true
	j.source_path = path
	j.level = 1
	return j


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
