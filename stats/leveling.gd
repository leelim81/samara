class_name Leveling
extends RefCounted
# Terra Battle-style EXP -> level progression for player characters. Units cap
# at level 90 (the TB max). Cumulative EXP to reach a level follows a smooth
# super-linear curve; the constants are tunable to pace the campaign grind.
#
# This is a pure, static utility — no engine/autoload dependencies — so it is
# safe to use from menus, the victory flow, and headless tests alike.

const MAX_LEVEL: int = 90

# Cumulative EXP to reach `level` = _BASE * (level - 1) ^ _POW.
const _BASE: float = 80.0
const _POW: float = 2.4


# Total accumulated EXP required to BE at `level` (level 1 == 0 EXP).
static func exp_for_level(level: int) -> int:
	var lvl: int = clampi(level, 1, MAX_LEVEL)
	return int(round(_BASE * pow(float(lvl - 1), _POW)))


# The level a unit is at given its total accumulated EXP (capped at MAX_LEVEL).
static func level_for_exp(total_exp: int) -> int:
	var lvl: int = 1
	while lvl < MAX_LEVEL and total_exp >= exp_for_level(lvl + 1):
		lvl += 1
	return lvl


# EXP needed to advance from `level` to `level + 1` (0 once at the cap).
static func exp_to_next(level: int) -> int:
	if level >= MAX_LEVEL:
		return 0
	return exp_for_level(level + 1) - exp_for_level(level)


# Progress (0..1) from the start of `level` toward the next level.
static func progress(level: int, total_exp: int) -> float:
	if level >= MAX_LEVEL:
		return 1.0
	var span: int = exp_to_next(level)
	if span <= 0:
		return 1.0
	var into: int = total_exp - exp_for_level(level)
	return clampf(float(into) / float(span), 0.0, 1.0)
