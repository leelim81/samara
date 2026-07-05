extends SceneTree
# Tests the luck drop model (C3): tier thresholds and the seeded roll.
#   godot --headless --script res://tools/test_luck_drops.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	_check("tier 0 at zero luck", LuckDrops.luck_tier(0) == 0)
	_check("tier grows with luck", LuckDrops.luck_tier(150) == 3)
	_check("tier caps at 4", LuckDrops.luck_tier(9999) == 4)

	var rng := RandomNumberGenerator.new()

	rng.seed = 12345
	var low = LuckDrops.roll(0, rng)
	_check("low luck: 1 chest", int(low.chests) == 1)
	_check("low luck: some coins", int(low.coins) > 0)

	rng.seed = 12345
	var high = LuckDrops.roll(250, rng)
	_check("high luck: 5 chests", int(high.chests) == 5)
	_check("high luck coins exceed low luck", int(high.coins) > int(low.coins))

	rng.seed = 777
	var a = LuckDrops.roll(150, rng)
	rng.seed = 777
	var b = LuckDrops.roll(150, rng)
	_check("roll is deterministic for a seed", int(a.coins) == int(b.coins))

	print("test_luck_drops: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)
