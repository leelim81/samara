extends SceneTree
# Verifies the Powered-Point rule: while the turn-wide power boost is active
# (Events.power_boost_active, set when a Powered Point is chained), every unit
# activates its active skills 100% (even a 0%-rate skill), while EQUIP/COUNTER
# skills stay excluded; with the boost off, a 0%-rate skill never fires.
# Run: godot --headless --script res://tools/test_powered_point.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var unit = load("res://units/unit.tscn").instantiate()
	root.add_child(unit)
	await process_frame

	var job = load("res://jobs/terra/bahl_job.tres").duplicate()
	job.stats = job.stats.duplicate()

	var skill_script = load("res://skills/skill.gd")

	var atk = skill_script.new() # ATTACK(0), PINCER(2), 0% base activation
	atk.skill_name = "TEST_ATK"
	atk.skill_type = 0
	atk.area_of_effect = 2
	atk.activation_rate = 0.0

	var equip = skill_script.new() # EQUIP(1) — must never appear in activations
	equip.skill_name = "TEST_EQUIP"
	equip.skill_type = 0
	equip.area_of_effect = 1
	equip.activation_rate = 0.0

	job.skills = [atk, equip]
	job.level = 90
	unit.set_job(job)

	# --script SceneTree scripts can't resolve autoload globals at compile
	# time, so fetch the Events singleton by node path.
	var events = root.get_node("/root/Events")

	# Not powered: a 0%-rate skill never fires.
	events.power_boost_active = false
	var fired_when_off := false
	for i in 60:
		if atk in unit.activate_skills():
			fired_when_off = true
	_check("0%-rate skill never fires when NOT on a powered point", not fired_when_off)

	# Powered: the 0%-rate skill fires every single time.
	events.power_boost_active = true
	var fired_every_time := true
	for i in 60:
		if not (atk in unit.activate_skills()):
			fired_every_time = false
	_check("0%-rate skill fires 100% on a powered point", fired_every_time)

	# EQUIP skill excluded even when powered.
	var equip_ever := false
	for i in 30:
		if equip in unit.activate_skills():
			equip_ever = true
	_check("EQUIP skill stays excluded even when powered", not equip_ever)

	print("test_powered_point: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1
	print(("  PASS " if cond else "  FAIL ") + label)
