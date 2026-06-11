class_name Job
extends Resource


# Unlock skills every X levels
const _UNLOCK_SKILL_LEVEL_MULTIPLE: int = 10

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
	var skills_unlocked_count := int(floor(float(_level) / float(_UNLOCK_SKILL_LEVEL_MULTIPLE)))
	
	if skills_unlocked_count == 0:
		return []
	else:
		return skills.slice(0, skills_unlocked_count - 1)


func set_level(_level: int) -> void:
	level = _level
	
	stats.level = level
