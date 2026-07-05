extends SceneTree
# Tests Skill Boost growth (C2): the use-count curve and Job.register_skill_use.
#   godot --headless --script res://tools/test_skill_growth.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	# Use-count -> boost curve.
	_check("0 uses -> 0 boost", is_equal_approx(SkillGrowth.boost_for_uses(0), 0.0))
	_check("7 uses -> 0 boost", is_equal_approx(SkillGrowth.boost_for_uses(7), 0.0))
	_check("8 uses -> 0.02 boost", is_equal_approx(SkillGrowth.boost_for_uses(8), 0.02))
	_check("16 uses -> 0.04 boost", is_equal_approx(SkillGrowth.boost_for_uses(16), 0.04))
	_check("boost caps at MAX_BOOST", is_equal_approx(SkillGrowth.boost_for_uses(100000), SkillGrowth.MAX_BOOST))

	# Job registration crosses a threshold at 8 uses.
	var job = load("res://jobs/terra/bahl_job.tres").duplicate()
	job.skills = job.skills.duplicate()

	var upped := false
	for _n in 8:
		upped = job.register_skill_use(0)

	_check("skill up after 8 uses", upped)
	_check("skill_uses recorded", int(job.skill_uses[0]) == 8)
	_check("skill_boost is 0.02", is_equal_approx(float(job.skill_boosts[0]), 0.02))
	_check("get_skill_boost matches", is_equal_approx(job.get_skill_boost(0), 0.02))
	_check("no skill up between thresholds (9th use)", not job.register_skill_use(0))
	_check("register out of range is false", not job.register_skill_use(999))

	print("test_skill_growth: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)
