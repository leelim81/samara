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

var level: int = 1: set = set_level


func get_unlocked_skills(_level: int) -> Array:
	var skills_unlocked_count: int = 0

	for unlock_level in _SKILL_UNLOCK_LEVELS:
		if _level >= unlock_level:
			skills_unlocked_count += 1

	return skills.slice(0, skills_unlocked_count)


func set_level(_level: int) -> void:
	level = _level
	
	stats.level = level
