extends SceneTree
# Generates PLACEHOLDER Job 2 + Job 3 for every hero: a rebalanced stats resource
# (higher caps, a distinct role) + a job resource referencing the subjob art and
# a distinct skill set. Run after tools/gen_subjob_art.py (art must be imported):
#   godot --headless --script res://tools/gen_subjobs.gd

# Placeholder skill sets (existing skills), documented for real design later.
const JOB2_SKILLS := [
	"res://skills/resources/terra/slash.tres",
	"res://skills/resources/terra/counterattack.tres",
]
const JOB3_SKILLS := [
	"res://skills/resources/terra/fire.tres",
	"res://skills/resources/terra/ice.tres",
	"res://skills/resources/terra/heal.tres",
]

const STAFF := 3


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await process_frame

	var dir := DirAccess.open("res://jobs/terra")
	var count := 0

	for file in dir.get_files():
		if not file.ends_with("_job.tres"):
			continue

		var base = load("res://jobs/terra/" + file)

		if base == null or base.stats == null:
			continue

		if base.stats.unit_type == "MONSTER" or base.stats.unit_type == "HANIWA":
			continue

		var slug: String = file.replace("_job.tres", "")

		# Job 2 - Vanguard: tankier physical build (keeps the base weapon).
		_make_variant(base, slug, 2, [1.4, 1.15, 1.4, 1.0, 1.25], base.stats.weapon_type, JOB2_SKILLS)
		# Job 3 - Adept: a magic build (staff, high spiritual attack).
		_make_variant(base, slug, 3, [1.2, 0.9, 1.1, 1.7, 1.4], STAFF, JOB3_SKILLS)

		count += 1

	print("generated jobs 2+3 for %d heroes" % count)
	quit(0)


func _make_variant(base, slug: String, n: int, mult: Array, weapon: int, skill_paths: Array) -> void:
	var s = base.stats.duplicate()
	s.health_percentage *= mult[0]
	s.attack_percentage *= mult[1]
	s.defense_percentage *= mult[2]
	s.spiritual_attack_percentage *= mult[3]
	s.spiritual_defense_percentage *= mult[4]
	s.weapon_type = weapon

	# The stats are inlined into the job .tres below (self-contained placeholder).
	var skills := []
	for path in skill_paths:
		var sk = load(path)
		if sk != null:
			skills.append(sk)

	var job = Job.new()
	job.stats = s
	job.skills = skills
	job.job_name = base.job_name
	job.description = base.description
	job.portrait = load("res://assets/terra/subjobs/%s_job%d_token.png" % [slug, n])
	job.full_portrait = load("res://assets/terra/subjobs/%s_job%d_full.png" % [slug, n])

	ResourceSaver.save(job, "res://jobs/terra/subjobs/%s_job%d.tres" % [slug, n])
