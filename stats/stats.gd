extends Resource

class_name Stats

const _DEFAULT_HP: int = 1500
const _DEFAULT_STAT: int = 50
const _STAT_GROWTH_PER_LEVEL: float = 0.1


@export var unit_name: String
@export var unit_type: String

@export var health_percentage: float = 1

@export var attack_percentage: float = 1
@export var defense_percentage: float = 1
@export var spiritual_attack_percentage: float = 1
@export var spiritual_defense_percentage: float = 1

# General status ailment vulnerability. The greater it is the
# more vulnerable to status ailments. If it's zero then the unit
# is immune (besides exceptions in status_ailment_vulnerabilities).
# If it's greater than 1 then that status effect should cause extra damage
@export var status_ailment_vulnerability: float = 1.0 # (float, 0, 5, 0.1)

# Dictionary<StatusAilmentType (String), float>
# Vulnerabilities to specific status ailments
# 0: immune. 1: completely vulnerable
@export var status_ailment_vulnerabilities: Dictionary = {}

# Same attribute resistance. If it's > 1 then attacks with same attribute
# should heal the unit
@export var same_attribute_resistance: float = 0.0 # (float, 0, 2, 0.1)

# Attribute of unit
@export var attribute: int = Enums.Attribute.NONE # (Enums.Attribute)

# Weapon type of unit
@export var weapon_type: int = Enums.WeaponType.SWORD # (Enums.WeaponType)

# Max turn counter (only applies to AI-controlled characters)
@export var max_turn_counter: int = 3 # (int, 0, 10, 1)

# Says if turn counter can be randomized from [1, max_turn_counter] after
# it reaches 0.
@export var can_randomize_turn_counter: bool = false

# How many cells this unit can move (only applies to AI-controlled characters)
@export var movement_range: int = 5 # (int, 0, 15, 1)

# Skill activation rate modifier, used to change activation rate of all
# skills used by a unit, additively.
# -1 -> skills are never activated
# 0 -> no effect
# > 0 -> skills are activated more often
@export var skill_activation_rate_modifier: float = 0.0 # (float, -1, 1, 0.1)

# These stats are calculated from the percentages above and the unit level,
# using a linear growth per level. The percentages represent the stats differences
# in relation to a unit with _DEFAULT_STAT in all stats and _DEFAULT_HP. This
# allows way you can balance player and enemy units around a default "standard" unit
# (e.g 110% stronger than base unit, 50% less defense than base unit, kills base unit
# in X turns, etc).
var health: int = 0

var attack: int = 0
var defense: int = 0
var spiritual_attack: int = 0
var spiritual_defense: int = 0

var level: int = 1: set = set_level


func _init() -> void:
	_update_stats()


func is_physical() -> bool:
	return weapon_type != Enums.WeaponType.STAFF


# Gets the vulnerability of the given status effect, or the general vulnerability
# if there is no value associated to the given status effect
func get_vulnerability(status_effect_type: int) -> float:
	var status_effect_type_str: String = Enums.status_effect_type_to_string(status_effect_type)
	
	if status_ailment_vulnerabilities.has(status_effect_type_str):
		return status_ailment_vulnerabilities[status_effect_type_str]
	else:
		return status_ailment_vulnerability


func set_level(_level: int) -> void:
	level = _level
	
	_update_stats()


func _update_stats() -> void:
	health = _get_stat(_DEFAULT_HP, health_percentage)
	
	attack = _get_stat(_DEFAULT_STAT, attack_percentage)
	defense = _get_stat(_DEFAULT_STAT, defense_percentage)
	spiritual_attack = _get_stat(_DEFAULT_STAT, spiritual_attack_percentage)
	spiritual_defense = _get_stat(_DEFAULT_STAT, spiritual_defense_percentage)


func _get_stat(base_value: int, modifier: float) -> int:
	return int(round(float(level * base_value) * _STAT_GROWTH_PER_LEVEL * modifier))
