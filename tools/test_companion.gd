extends SceneTree
# Companion tests (Terra Battle): stat grants scale with the owner's growth
# curve — the wiki's "Earth Sword at max level gives +80 ATK" is the value at
# the L90 cap; lower-level heroes receive level^0.53/90^0.53 of it (a flat
# max-strength grant one-shot the early campaign). Also: the companion skill
# fires at its frequency — max-level frequency under the Powered Point boost.
#   godot --headless --script res://tools/test_companion.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var events = root.get_node("/root/Events")
	events.power_boost_active = false

	# --- Stat grants: same job with and without its companion ---
	var with_unit = load("res://units/unit.tscn").instantiate()
	var without_unit = load("res://units/unit.tscn").instantiate()
	root.add_child(with_unit)
	root.add_child(without_unit)
	await process_frame

	var job_with = (load("res://jobs/terra/bahl_job.tres") as Resource).duplicate()
	job_with.stats = job_with.stats.duplicate()
	var job_without = (load("res://jobs/terra/bahl_job.tres") as Resource).duplicate()
	job_without.stats = job_without.stats.duplicate()
	job_without.companion = null

	with_unit.set_job(job_with)
	without_unit.set_job(job_without)

	var level: int = with_unit.get_stats().level
	var expected: int = int(round(80.0 * pow(float(level), 0.53) / pow(90.0, 0.53)))

	var atk_delta: int = with_unit.get_stats().attack - without_unit.get_stats().attack
	_check("Earth Sword grants +%d ATK at L%d (got %+d)" % [expected, level, atk_delta], atk_delta == expected)
	_check("max HP unchanged by an ATK-only companion",
			with_unit.get_max_health() == without_unit.get_max_health())

	# The grant reaches the full wiki value at the level cap
	var capped_job = (load("res://jobs/terra/bahl_job.tres") as Resource).duplicate()
	capped_job.stats = capped_job.stats.duplicate()
	var capped_bare = (load("res://jobs/terra/bahl_job.tres") as Resource).duplicate()
	capped_bare.stats = capped_bare.stats.duplicate()
	capped_bare.companion = null
	capped_job.stats.set_level(90)
	capped_bare.stats.set_level(90)
	var cap_unit = load("res://units/unit.tscn").instantiate()
	var cap_bare_unit = load("res://units/unit.tscn").instantiate()
	root.add_child(cap_unit)
	root.add_child(cap_bare_unit)
	await process_frame
	cap_unit.set_job(capped_job)
	cap_bare_unit.set_job(capped_bare)
	cap_unit.set_battle_level(90)
	cap_bare_unit.set_battle_level(90)
	_check("companion grants the full +80 at the L90 cap",
			cap_unit.get_stats().attack - cap_bare_unit.get_stats().attack == 80)

	# Buff caps still key off the companion-inclusive base: recalculating
	# stats must keep the grant (companion applies on every reset).
	with_unit.recalculate_stats()
	var atk_after_recalc: int = with_unit.get_stats().attack - without_unit.get_stats().attack
	_check("companion ATK survives recalculate_stats", atk_after_recalc == expected)

	# --- Skill frequency ---
	var companion = job_with.companion.duplicate()
	job_with.companion = companion
	# Distinct instance: Bahl's own skill list contains the same sever.tres
	# resource, and `in` compares object identity
	companion.skill = companion.skill.duplicate()
	var companion_skill = companion.skill

	companion.frequency = 0.0
	var fired_at_zero := false
	for i in 40:
		if companion_skill in with_unit.activate_skills():
			fired_at_zero = true
	_check("companion skill never fires at frequency 0", not fired_at_zero)

	companion.frequency = 1.0
	var fired_every_time := true
	for i in 40:
		if not (companion_skill in with_unit.activate_skills()):
			fired_every_time = false
	_check("companion skill always fires at frequency 1", fired_every_time)

	# Powered boost: uses max_frequency instead of frequency (wiki rule)
	companion.frequency = 0.0
	companion.max_frequency = 1.0
	events.power_boost_active = true
	var fired_boosted := true
	for i in 40:
		if not (companion_skill in with_unit.activate_skills()):
			fired_boosted = false
	_check("Powered boost uses max-level frequency", fired_boosted)
	events.power_boost_active = false

	print("test_companion: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
