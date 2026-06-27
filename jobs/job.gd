class_name Job
extends Resource


# Job levels at which skill slots unlock (Terra Battle: 1 / 15 / 35 / 65)
const _SKILL_UNLOCK_LEVELS: Array = [1, 15, 35, 65]

# Stats
# Has to be unique (duplicated)
@export var stats: Resource = null

# Array<Skill>
@export var skills: Array = [] # (Array, Resource)

@export var job_name: String = ""

@export var portrait: Texture2D = null

@export var full_portrait: Texture2D = null

# Flavor bio (heroes) or appearance (enemies), shown on the unit detail screen.
@export_multiline var description: String = ""

# Total accumulated EXP (player characters only; enemies set level directly).
# The level is derived from this via Leveling.level_for_exp().
@export var current_exp: int = 0

var level: int = 1: set = set_level

# Original .tres path, preserved across duplication so the player's roster can
# be re-serialized (duplicated resources lose their resource_path).
var source_path: String = ""


# Adds EXP and re-derives the level from the new total. Returns levels gained.
func gain_exp(amount: int) -> int:
	if amount <= 0:
		return 0

	var previous_level: int = level
	current_exp += amount
	set_level(Leveling.level_for_exp(current_exp))

	return level - previous_level


func get_unlocked_skills(_level: int) -> Array:
	var skills_unlocked_count: int = 0

	for unlock_level in _SKILL_UNLOCK_LEVELS:
		if _level >= unlock_level:
			skills_unlocked_count += 1

	return skills.slice(0, skills_unlocked_count)


func set_level(_level: int) -> void:
	level = _level
	
	stats.level = level
