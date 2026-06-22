extends SceneTree
# Dev-only unit test for the Leveling EXP curve. Run:
#   godot --headless --script res://tools/test_leveling.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame
	var lv = load("res://stats/leveling.gd")

	_check("L1 needs 0 exp", lv.exp_for_level(1) == 0)
	_check("exp is strictly increasing 1..90", _monotonic(lv))
	_check("level_for_exp inverts exp_for_level at 40", lv.level_for_exp(lv.exp_for_level(40)) == 40)
	_check("level_for_exp just-below 40 == 39", lv.level_for_exp(lv.exp_for_level(40) - 1) == 39)
	_check("exp caps at level 90", lv.level_for_exp(lv.exp_for_level(90) + 999999999) == 90)
	_check("exp_to_next(90) == 0 (capped)", lv.exp_to_next(90) == 0)
	_check("progress mid-level in (0,1)", _mid_progress(lv) > 0.0 and _mid_progress(lv) < 1.0)

	print("test_leveling: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)


func _monotonic(lv) -> bool:
	for l in range(1, 90):
		if lv.exp_for_level(l + 1) <= lv.exp_for_level(l):
			return false
	return true


func _mid_progress(lv) -> float:
	var exp_mid: int = lv.exp_for_level(10) + lv.exp_to_next(10) / 2
	return lv.progress(10, exp_mid)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_failures += 1
	print(("  PASS " if cond else "  FAIL ") + label)
