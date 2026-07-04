class_name Attack
extends RefCounted


# Array<Unit>
var targeted_units: Array = []

var attacking_unit: Unit

# When in a chain
var pincering_unit: Unit

# Set when this attack is a counterattack: a pincered unit striking back with
# its COUNTER skill (power/weapon/attribute come from the skill, not the unit)
var counter_skill: Skill = null
