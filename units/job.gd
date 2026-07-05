extends Node

# TODO: Merge with unit script

# Job
@export var job: Resource

@export var level: int = 0

var base_stats: Stats

# Stats after buffs and debuffs
var current_stats: Stats

# Array<Skill>
var skills: Array

signal health_changed(current_health, max_health)


func get_unlocked_skills() -> Array:
	return job.get_unlocked_skills(level)


func set_job(_job: Job) -> void:
	job = _job
	level = job.level
	
	_reset_base_stats()
	_reset_current_stats()


func set_level(value: int) -> void:
	level = value
	
	_reset_base_stats()
	_reset_current_stats()


func reset_stats() -> void:
	var current_health: int = current_stats.health
	
	_reset_current_stats()
	
	current_stats.health = int(min(base_stats.health, current_health))


func decrease_health(value: int) -> void:
	current_stats.health = int(clamp(current_stats.health - value, 0, base_stats.health))
	
	emit_signal("health_changed", current_stats.health, base_stats.health)


func _reset_base_stats() -> void:
	base_stats = job.stats.duplicate()
	base_stats.level = level

	_apply_companion(base_stats)


func _reset_current_stats() -> void:
	current_stats = base_stats.duplicate()
	current_stats.level = level

	_apply_companion(current_stats)

	skills = job.skills.duplicate()


# Companion flat stat grants (Terra Battle). Applied AFTER the level is set:
# Stats.set_level recomputes every field from its percentages, which would
# wipe direct additions. Applied to base AND current so max HP includes the
# companion's health bonus and buffs/caps stay consistent.
func _apply_companion(stats: Stats) -> void:
	var companion = job.companion if job != null else null

	if companion == null:
		return

	# Companions grow alongside their owner (TB levels them separately; here
	# they ride the hero's growth curve and reach full listed strength at the
	# L90 cap). A flat max-strength +80 ATK on a level-7 hero nearly doubled
	# their attack and one-shot the early campaign.
	var growth: float = pow(float(clampi(stats.level, 1, Leveling.MAX_LEVEL)), 0.53) / pow(float(Leveling.MAX_LEVEL), 0.53)

	stats.health += int(round(companion.health_bonus * growth))
	stats.attack += int(round(companion.attack_bonus * growth))
	stats.defense += int(round(companion.defense_bonus * growth))
	stats.spiritual_attack += int(round(companion.spiritual_attack_bonus * growth))
	stats.spiritual_defense += int(round(companion.spiritual_defense_bonus * growth))
