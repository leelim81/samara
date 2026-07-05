class_name SkillGrowth
# Terra Battle "Skill Up": using a skill sometimes permanently raises its
# activation rate. This maps a skill's total use count to a bonus activation
# rate, added on top of the skill's base rate and capped. Kept as a small static
# helper (like Leveling) so it is easy to unit-test.

const MAX_BOOST: float = 0.20
const _STEP: float = 0.02
const _USES_PER_STEP: int = 8


static func boost_for_uses(uses: int) -> float:
	var steps: int = int(uses / _USES_PER_STEP)

	return minf(float(steps) * _STEP, MAX_BOOST)
