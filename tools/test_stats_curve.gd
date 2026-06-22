extends SceneTree
# Dev-only unit test for the Stats level curve. Verifies:
#   - legacy linear growth is unchanged when uses_growth_curve = false (enemies)
#   - the TB sub-linear curve matches L1 exactly and reaches ~11x by L90 (players)
# Run: godot --headless --script res://tools/test_stats_curve.gd

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var stats_script = load("res://stats/stats.gd")

	# Legacy linear unit (enemy default): L90 should be exactly 90x L1.
	var legacy = stats_script.new()
	legacy.health_percentage = 2.0
	legacy.uses_growth_curve = false
	legacy.level = 1
	var legacy_l1: int = legacy.health
	legacy.level = 90
	var legacy_l90: int = legacy.health
	_check("legacy L1 health > 0", legacy_l1 > 0)
	_check("legacy is linear (L90 == 90x L1)", _approx(float(legacy_l90) / float(legacy_l1), 90.0, 0.02))

	# Curve unit (player): L1 matches the legacy L1, L90 ~= 10.9x (TB anchor).
	var curve = stats_script.new()
	curve.health_percentage = 2.0
	curve.uses_growth_curve = true
	curve.level = 1
	var curve_l1: int = curve.health
	curve.level = 90
	var curve_l90: int = curve.health
	_check("curve L1 == legacy L1 (no L1 change)", curve_l1 == legacy_l1)
	_check("curve L90 ~= 10.9x L1 (TB sub-linear)", _approx(float(curve_l90) / float(curve_l1), 10.9, 0.2))
	_check("curve L90 << legacy L90 (sub-linear, not 90x)", curve_l90 < legacy_l90 / 5)

	print("test_stats_curve: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)


func _approx(a: float, b: float, tol: float) -> bool:
	return abs(a - b) < tol * b


func _check(label: String, cond: bool) -> void:
	if not cond:
		_failures += 1
	print(("  PASS " if cond else "  FAIL ") + label)
