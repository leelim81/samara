extends SceneTree
# Tests the advanced status effects added in C1. Run:
#   godot --headless --script res://tools/test_status_advanced.gd

var _f := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var stats_script = load("res://stats/stats.gd")

	# Venom deals more per-turn base damage than Poison for the same caster.
	var caster = stats_script.new()
	caster.spiritual_attack = 100

	var poison = load("res://status_effects/poison.tres").duplicate()
	poison.initialize(caster)
	var venom = load("res://status_effects/venom.tres").duplicate()
	venom.initialize(caster)
	_check("venom base > poison base", venom.base_damage > poison.base_damage)

	# Weakness raises the elemental damage multiplier from 1.0 to 1.5.
	var w_modified = stats_script.new()
	_check("weakness multiplier defaults to 1.0", is_equal_approx(w_modified.elemental_weakness_multiplier, 1.0))
	load("res://status_effects/weakness.tres").modify_stats(stats_script.new(), w_modified)
	_check("weakness sets multiplier to 1.5", is_equal_approx(w_modified.elemental_weakness_multiplier, 1.5))

	# Blind cuts both physical and spiritual attack.
	var b_base = stats_script.new()
	b_base.attack = 200
	b_base.spiritual_attack = 100
	var b_mod = stats_script.new()
	b_mod.attack = 200
	b_mod.spiritual_attack = 100
	load("res://status_effects/blind.tres").modify_stats(b_base, b_mod)
	_check("blind reduces attack", b_mod.attack < 200)
	_check("blind reduces spiritual attack", b_mod.spiritual_attack < 100)

	# Every new resource loads with the right type and a real icon (the icon
	# assert in status_effects_icons.gd fires otherwise).
	var expected := {
		"res://status_effects/venom.tres": Enums.StatusEffectType.VENOM,
		"res://status_effects/deep_sleep.tres": Enums.StatusEffectType.DEEP_SLEEP,
		"res://status_effects/petrify.tres": Enums.StatusEffectType.PETRIFY,
		"res://status_effects/icebind.tres": Enums.StatusEffectType.ICEBIND,
		"res://status_effects/blind.tres": Enums.StatusEffectType.BLIND,
		"res://status_effects/weakness.tres": Enums.StatusEffectType.WEAKNESS,
	}

	for path in expected:
		var res = load(path)
		_check("%s loads" % path, res != null)

		if res != null:
			_check("%s has correct type" % path, res.status_effect_type == expected[path])
			_check("%s has icon" % path, res.icon != null)

	print("test_status_advanced: %s" % ("PASS" if _f == 0 else "FAIL (%d)" % _f))
	quit(1 if _f > 0 else 0)


func _check(label: String, cond: bool) -> void:
	if not cond:
		_f += 1

	print(("  PASS " if cond else "  FAIL ") + label)
