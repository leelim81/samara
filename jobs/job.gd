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

# Reforge (sub-job): a toggleable alternate build that flips the unit between a
# physical and a magic role, moving this fraction of its primary attack to the
# other side and swapping the weapon. Both transforms are re-applied after load
# (and on toggle) by rebuild_stats, since stats are always derived from the base.
const REFORGE_SHIFT: float = 0.5

@export var awakened: bool = false
@export var reforge_unlocked: bool = false
@export var reforged: bool = false

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

	rebuild_stats()


func unlock_reforge() -> void:
	reforge_unlocked = true

	set_reforged(true)


func set_reforged(value: bool) -> void:
	if reforged == value:
		return

	reforged = value

	rebuild_stats()


# Rebuilds stats from the base job, then re-applies the active transforms
# (reforge, then awaken). The single source of truth for a unit's stats, so
# toggling reforge is always clean and re-applies awaken correctly.
func rebuild_stats() -> void:
	if source_path == "":
		return

	var base = load(source_path)

	if base == null or base.stats == null:
		return

	stats = base.stats.duplicate()
	stats.uses_growth_curve = true

	if reforged:
		_apply_reforge_transform()

	if awakened:
		_apply_awaken_transform()

	set_level(level)


func _apply_awaken_transform() -> void:
	stats.health_percentage *= AWAKEN_MULTIPLIER
	stats.attack_percentage *= AWAKEN_MULTIPLIER
	stats.defense_percentage *= AWAKEN_MULTIPLIER
	stats.spiritual_attack_percentage *= AWAKEN_MULTIPLIER
	stats.spiritual_defense_percentage *= AWAKEN_MULTIPLIER


func _apply_reforge_transform() -> void:
	if stats.weapon_type == Enums.WeaponType.STAFF:
		# Magic build -> physical (sword): move attack power to ATK.
		stats.weapon_type = Enums.WeaponType.SWORD
		stats.attack_percentage += stats.spiritual_attack_percentage * REFORGE_SHIFT
		stats.spiritual_attack_percentage *= (1.0 - REFORGE_SHIFT)
	else:
		# Physical build -> magic (staff): move attack power to S.ATK.
		stats.weapon_type = Enums.WeaponType.STAFF
		stats.spiritual_attack_percentage += stats.attack_percentage * REFORGE_SHIFT
		stats.attack_percentage *= (1.0 - REFORGE_SHIFT)


func set_level(_level: int) -> void:
	level = _level
	
	stats.level = level
