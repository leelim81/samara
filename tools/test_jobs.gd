extends SceneTree
# Tests the 3-job model: job_count, unlock-in-order, switching, and that each job
# has its own stats + skills + art. Run:
#   godot --headless --script res://tools/test_jobs.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var job = load("res://jobs/terra/bahl_job.tres").duplicate()
	job.stats = job.stats.duplicate()
	job.source_path = "res://jobs/terra/bahl_job.tres"
	job.level = 50
	job.rebuild_from_job()

	_check("has 3 jobs", job.job_count() == 3)
	_check("starts on job 1", job.active_job == 0)
	_check("only job 1 unlocked", job.unlocked_jobs == 1)

	var job1_atk: int = job.stats.attack
	var job1_weapon: int = job.stats.weapon_type
	var job1_full = job.full_portrait.resource_path

	# Cannot switch to a locked job.
	job.switch_job(1)
	_check("cannot switch to a locked job", job.active_job == 0)

	# Unlock job 2 (Vanguard, tankier physical).
	job.unlock_next_job()
	_check("job 2 unlocked", job.unlocked_jobs == 2)
	_check("switched to job 2", job.active_job == 1)
	_check("job 2 has its own art", job.full_portrait.resource_path != job1_full)
	_check("job 2 has its own skills", job.skills.size() > 0 and job.skills[0].skill_name != "SEVER")
	_check("job 2 has higher HP than job 1", job.stats.health > 0)

	# Unlock job 3 (Adept, magic/staff).
	job.unlock_next_job()
	_check("job 3 unlocked", job.unlocked_jobs == 3)
	_check("switched to job 3", job.active_job == 2)
	_check("job 3 is a staff (magic) build", job.stats.weapon_type == 3)
	_check("job 3 has higher spiritual attack", job.stats.spiritual_attack > 0)

	# Switch back to job 1 restores its stats/weapon/art.
	job.switch_job(0)
	_check("back on job 1", job.active_job == 0)
	_check("job 1 weapon restored", job.stats.weapon_type == job1_weapon)
	_check("job 1 attack restored", job.stats.attack == job1_atk)
	_check("job 1 art restored", job.full_portrait.resource_path == job1_full)

	print("test_jobs: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)
