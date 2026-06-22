extends SceneTree
# Dev-only unit test for skill_applier.calculate_damage. Verifies the Terra
# Battle damage rules: one-directional weapon triangle, opposed-element x2, and
# that BOTH multipliers stack on an elemental physical weapon. Run with:
#   godot --headless --script res://tools/test_damage.gd
# Everything Enums-dependent (Stats, SkillApplier) is loaded at RUNTIME inside
# _run (deferred), because autoload identifiers like Enums are not available at
# this script's compile time in a --script SceneTree.

const SWORD := 0
const GUN := 1
const SPEAR := 2
const STAFF := 3

const NONE := 0
const FIRE := 2
const ICE := 3

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _make_stats(stats_script, level: int, atk_pct: float, def_pct: float, weapon: int, attr: int):
	var s = stats_script.new()
	s.attack_percentage = atk_pct
	s.defense_percentage = def_pct
	s.spiritual_attack_percentage = atk_pct
	s.spiritual_defense_percentage = def_pct
	s.weapon_type = weapon
	s.attribute = attr
	s.level = level # setter triggers stat recompute from the percentages above
	return s


func _run() -> void:
	await process_frame

	var stats_script = load("res://stats/stats.gd")
	var sa = load("res://units/skill_applier.gd").new()

	var attacker = _make_stats(stats_script, 40, 2.0, 1.0, SWORD, NONE)

	var def_sword_none = _make_stats(stats_script, 40, 1.0, 1.0, SWORD, NONE)
	var def_gun_none = _make_stats(stats_script, 40, 1.0, 1.0, GUN, NONE)
	var def_spear_none = _make_stats(stats_script, 40, 1.0, 1.0, SPEAR, NONE)
	var def_gun_ice = _make_stats(stats_script, 40, 1.0, 1.0, GUN, ICE)
	var def_sword_ice = _make_stats(stats_script, 40, 1.0, 1.0, SWORD, ICE)

	var P := 1.0
	var base: int = sa.calculate_damage(attacker, def_sword_none, P, SWORD, NONE)
	var sword_vs_gun: int = sa.calculate_damage(attacker, def_gun_none, P, SWORD, NONE)
	var sword_vs_spear: int = sa.calculate_damage(attacker, def_spear_none, P, SWORD, NONE)
	var fire_sword_vs_ice_gun: int = sa.calculate_damage(attacker, def_gun_ice, P, SWORD, FIRE)
	var fire_sword_vs_ice_sword: int = sa.calculate_damage(attacker, def_sword_ice, P, SWORD, FIRE)
	var staff_base: int = sa.calculate_damage(attacker, def_sword_none, P, STAFF, NONE)
	var staff_fire_vs_ice: int = sa.calculate_damage(attacker, def_sword_ice, P, STAFF, FIRE)

	_check("base damage > 0", base > 0)
	_check("sword>gun = 2x (one-directional triangle)", _ratio(sword_vs_gun, base, 2.0))
	_check("sword vs spear = 1x (no reverse advantage)", _ratio(sword_vs_spear, base, 1.0))
	_check("fire sword vs ice gun = 4x (weapon x element stack)", _ratio(fire_sword_vs_ice_gun, base, 4.0))
	_check("fire sword vs ice sword = 2x (element only)", _ratio(fire_sword_vs_ice_sword, base, 2.0))
	_check("staff base > 0 (magical path)", staff_base > 0)
	_check("staff fire vs ice = 2x staff base (element, no triangle)", _ratio(staff_fire_vs_ice, staff_base, 2.0))

	print("test_damage: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)


func _ratio(value: int, base: int, expected: float) -> bool:
	if base == 0:
		return false
	return abs(float(value) / float(base) - expected) < 0.02


func _check(label: String, cond: bool) -> void:
	if not cond:
		_failures += 1
	print(("  PASS " if cond else "  FAIL ") + label)
