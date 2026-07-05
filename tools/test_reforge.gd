extends SceneTree
# Tests Reforge / sub-jobs (G5): toggling the build, clean revert, and combining
# with awaken. Run:
#   godot --headless --script res://tools/test_reforge.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var job = load("res://jobs/terra/bahl_job.tres").duplicate()
	job.stats = job.stats.duplicate()
	job.source_path = "res://jobs/terra/bahl_job.tres"
	job.level = 50
	job.rebuild_stats()

	var base_weapon: int = job.stats.weapon_type
	var base_atk: int = job.stats.attack
	var base_satk: int = job.stats.spiritual_attack

	job.unlock_reforge()
	_check("reforge unlocked", job.reforge_unlocked)
	_check("reforged active after unlock", job.reforged)
	_check("weapon type changed", job.stats.weapon_type != base_weapon)
	_check("attack power shifted", job.stats.attack != base_atk or job.stats.spiritual_attack != base_satk)

	job.set_reforged(false)
	_check("weapon restored on revert", job.stats.weapon_type == base_weapon)
	_check("attack restored exactly", job.stats.attack == base_atk)
	_check("spiritual attack restored exactly", job.stats.spiritual_attack == base_satk)
	_check("still unlocked after revert", job.reforge_unlocked)

	job.set_reforged(true)
	var reforged_hp: int = job.stats.health
	job.metamorphose()
	_check("awaken boosts the reforged build", job.stats.health > reforged_hp)
	_check("reforge survives awaken", job.reforged and job.stats.weapon_type != base_weapon)

	print("test_reforge: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)
