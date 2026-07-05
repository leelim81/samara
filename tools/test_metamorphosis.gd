extends SceneTree
# Tests Metamorphosis / Awaken (G4): the one-way stat boost and idempotence.
#   godot --headless --script res://tools/test_metamorphosis.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var job = load("res://jobs/terra/bahl_job.tres").duplicate()
	job.stats = job.stats.duplicate()
	job.stats.uses_growth_curve = true
	job.level = 50

	var base_atk: int = job.stats.attack
	var base_hp: int = job.stats.health

	job.metamorphose()

	_check("awakened flag set", job.awakened)
	_check("attack boosted", job.stats.attack > base_atk)
	_check("health boosted", job.stats.health > base_hp)

	var awakened_atk: int = job.stats.attack

	job.metamorphose()
	_check("second metamorphose is a no-op", job.stats.attack == awakened_atk)

	print("test_metamorphosis: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)
