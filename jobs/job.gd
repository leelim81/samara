class_name Job
extends Resource


# Job levels at which skill slots unlock (Terra Battle: 1 / 15 / 35 / 65)
const _SKILL_UNLOCK_LEVELS: Array = [1, 15, 35, 65]

# Stats
# Has to be unique (duplicated)
@export var stats: Resource = null

# Array<Skill>
@export var skills: Array = [] # (Array, Resource)

# Per-skill Skill Boost (Terra Battle "Skill Up"), parallel to `skills`.
# skill_uses counts activations; skill_boosts is the earned bonus activation
# rate. Grown via register_skill_use and persisted per unit.
@export var skill_boosts: Array = [] # (Array, float)
@export var skill_uses: Array = [] # (Array, int)

# Terra Battle Luck: drives the end-of-battle luck drops. Grows a little each
# time the unit is in the active squad for a first chapter clear. Capped at 99.
@export var luck: int = 0

# Metamorphosis / Awakening: a one-way permanent power-up that boosts the unit's
# stat percentages.
const AWAKEN_MULTIPLIER: float = 1.3

@export var awakened: bool = false

# Terra Battle jobs: a character has up to 3 jobs, each with its own stats, skills,
# and artwork (jobs/terra/subjobs/<slug>_job2.tres, _job3.tres). active_job is the
# active job index (0 = base, 1, 2); unlocked_jobs is how many are unlocked (1..3),
# added in order. The active job's content is rebuilt into this Job in place so the
# roster array stays index-stable.
@export var active_job: int = 0
@export var unlocked_jobs: int = 1

# Equipped companion (Terra Battle): grants flat stats and may cast its skill
# during pincers — see units/job.gd _apply_companion and unit.activate_skills
@export var companion: Resource = null

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

# Stable per-roster-slot id, minted when the unit joins the roster and persisted
# across saves. Per-unit growth state (equipped companion, unlocked job variants,
# metamorphosis) keys off this so it survives the jobs-array index model. Empty
# until assigned by SaveData.generate_uid / ensure_uids.
var uid: String = ""


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


# Earned bonus activation rate for the skill at `index` (0 if none / out of range).
func get_skill_boost(index: int) -> float:
	if index >= 0 and index < skill_boosts.size():
		return float(skill_boosts[index])

	return 0.0


# Records a use of skill `index`. Returns true if it crossed a Skill Up threshold
# (the activation bonus increased this call).
func register_skill_use(index: int) -> bool:
	if index < 0 or index >= skills.size():
		return false

	_ensure_skill_arrays()

	skill_uses[index] = int(skill_uses[index]) + 1

	var new_boost: float = SkillGrowth.boost_for_uses(int(skill_uses[index]))

	if new_boost > float(skill_boosts[index]):
		skill_boosts[index] = new_boost

		return true

	return false


func _ensure_skill_arrays() -> void:
	while skill_boosts.size() < skills.size():
		skill_boosts.append(0.0)

	while skill_uses.size() < skills.size():
		skill_uses.append(0)


func add_luck(amount: int) -> void:
	luck = clampi(luck + amount, 0, 99)


# One-way Metamorphosis: permanently awakens the unit's stats. Idempotent.
func metamorphose() -> void:
	if awakened:
		return

	awakened = true

	rebuild_from_job()


# ---- Jobs (Terra Battle: up to 3 per character, added in order) ----

# How many jobs this character actually has (1..3), by which variant files exist.
func job_count() -> int:
	var count: int = 1

	for n in [2, 3]:
		if ResourceLoader.exists(variant_path(source_path, n)):
			count = n
		else:
			break

	return count


# Switches to an already-unlocked job (0-based index). Resets earned skill boosts
# since each job has its own skills.
func switch_job(index: int) -> void:
	if index < 0 or index >= unlocked_jobs or index >= job_count():
		return

	active_job = index
	skill_boosts = []
	skill_uses = []

	rebuild_from_job()


# Unlocks the next job in order (2, then 3) and switches to it.
func unlock_next_job() -> void:
	if unlocked_jobs < job_count():
		unlocked_jobs += 1

		switch_job(unlocked_jobs - 1)


static func variant_path(base_path: String, n: int) -> String:
	if n <= 1 or base_path == "":
		return base_path

	var slug: String = base_path.get_file().replace("_job.tres", "")

	return "res://jobs/terra/subjobs/%s_job%d.tres" % [slug, n]


func _active_job_resource():
	var path: String = variant_path(source_path, active_job + 1)

	return load(path) if (path != "" and ResourceLoader.exists(path)) else null


# Rebuilds this Job's stats, skills, name, and artwork from the ACTIVE job variant,
# then re-applies awaken. The single source of truth for a unit's form. Per-unit
# state (level, exp, uid, luck, companion, skill boosts) is preserved.
func rebuild_from_job() -> void:
	var active = _active_job_resource()

	if active == null or active.stats == null:
		return

	stats = active.stats.duplicate()
	stats.uses_growth_curve = true
	skills = active.skills.duplicate()
	job_name = active.job_name
	portrait = active.portrait
	full_portrait = active.full_portrait
	description = active.description

	if awakened:
		_apply_awaken_transform()

	set_level(level)
	resolve_portraits()


# Awakened units show their awakened-form art (assets/terra/awakened/...),
# falling back to the base if a variant file is missing. Called on metamorphose
# and re-applied after load.
func resolve_portraits() -> void:
	if not awakened:
		return

	var full_variant = _variant_texture(full_portrait)
	if full_variant != null:
		full_portrait = full_variant

	var token_variant = _variant_texture(portrait)
	if token_variant != null:
		portrait = token_variant


func _variant_texture(texture: Texture2D):
	if texture == null:
		return null

	var path: String = texture.resource_path

	if path == "":
		return null

	var variant_path: String = path.replace("res://assets/terra/", "res://assets/terra/awakened/")

	if variant_path == path or not ResourceLoader.exists(variant_path):
		return null

	return load(variant_path)


func _apply_awaken_transform() -> void:
	stats.health_percentage *= AWAKEN_MULTIPLIER
	stats.attack_percentage *= AWAKEN_MULTIPLIER
	stats.defense_percentage *= AWAKEN_MULTIPLIER
	stats.spiritual_attack_percentage *= AWAKEN_MULTIPLIER
	stats.spiritual_defense_percentage *= AWAKEN_MULTIPLIER


func set_level(_level: int) -> void:
	level = _level
	
	stats.level = level
