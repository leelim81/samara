extends SceneTree
# Tests the luck chest model against the Terra Battle wiki thresholds:
# A chest guaranteed at 40 average Luck, B at 85, C 50% and D 25% at 100.
#   godot --headless --script res://tools/test_luck_drops.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var zero: Array = LuckDrops.chest_chances(0)
	_check("no chests are guaranteed at zero luck", zero[0] == 0.0 and zero[1] == 0.0)

	var forty: Array = LuckDrops.chest_chances(40)
	_check("A chest guaranteed at 40 luck (wiki)", forty[0] >= 1.0)
	_check("B chest not yet guaranteed at 40 luck", forty[1] < 1.0)

	var eighty_five: Array = LuckDrops.chest_chances(85)
	_check("B chest guaranteed at 85 luck (wiki)", eighty_five[1] >= 1.0)
	_check("D chest never drops below 100 luck", LuckDrops.chest_chances(99)[3] == 0.0)

	var cap: Array = LuckDrops.chest_chances(100)
	_check("C chest is 50% at 100 luck (wiki)", is_equal_approx(cap[2], 0.5))
	_check("D chest is 25% at 100 luck (wiki)", is_equal_approx(cap[3], 0.25))

	var rng := RandomNumberGenerator.new()

	# At the cap, A and B always drop; over many rolls C and D land near their
	# wiki rates.
	rng.seed = 12345
	var c_hits := 0
	var d_hits := 0
	var rolls := 800
	for i in rolls:
		var drop: Dictionary = LuckDrops.roll(100, rng)
		_check_quiet(int(drop.chests) >= 2, "A and B guaranteed at cap")
		if int(drop.chests) >= 3:
			c_hits += 1
		if int(drop.chests) == 4:
			d_hits += 1

	var c_rate := float(c_hits) / float(rolls)
	var d_rate := float(d_hits) / float(rolls)
	_check("C-or-better rate near 62.5%% at cap (got %.2f)" % c_rate, absf(c_rate - 0.625) < 0.06)
	_check("D rate near 12.5%% of rolls at cap (got %.2f)" % d_rate, absf(d_rate - 0.125) < 0.05)

	rng.seed = 42
	var low = LuckDrops.roll(0, rng)
	_check("zero luck drops nothing", int(low.chests) == 0 and int(low.coins) == 0)

	rng.seed = 777
	var a = LuckDrops.roll(90, rng)
	rng.seed = 777
	var b = LuckDrops.roll(90, rng)
	_check("roll is deterministic for a seed", int(a.coins) == int(b.coins))

	print("test_luck_drops: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)


func _check_quiet(cond: bool, label: String) -> void:
	if not cond:
		_f += 1
		print("  FAIL " + label)
