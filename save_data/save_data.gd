class_name SaveData
extends Resource


const MAX_SQUAD_SIZE: int = 6
const MIN_SQUAD_SIZE: int = 2

# Terra Battle lets the player save & switch up to 10 named squads.
const MAX_SQUADS: int = 10
const SQUAD_NAME_MAX_LENGTH: int = 10

@export var version: int = 1

# Array<Job>
# Jobs that the player has
@export var jobs: Array = [] # (Array, Resource)

# Array<int> — the currently-active squad's unit indices (live working set that
# the squad/battle code reads directly). Mirrored into squads[active_squad_index]
# on save / squad switch.
@export var active_units: Array = [] # (Array, int)

# Array<Dictionary{name:String, units:Array[int]}> — up to MAX_SQUADS saved squads.
@export var squads: Array = []
@export var active_squad_index: int = 0

@export var music_volume: float = 1.0
@export var sound_effects_volume: float = 1.0

@export var locale: String = "" # (String, "en", "es")
@export var drag_mode: int = Enums.DragMode.CLICK # (Enums.DragMode)

# Dictionary<String (Pair), int (support level, 1 - 4)>
# TODO: Save and load from file
var supports: Dictionary = {}

# Banked coins (battle spoils accumulate here on victory; spent on training).
@export var coins: int = 0

# Monotonic counter for minting stable per-unit ids (see Job.uid). Persisted so
# ids stay globally unique across sessions.
@export var next_uid: int = 1

# True once the player has seen the How to Play screen (shown once automatically
# on the first visit to the pre-battle menu; always reachable from its button).
@export var tutorial_seen: bool = false

# Bestiary: enemy job path -> encounter state (SEEN or DEFEATED; defeated implies
# seen). Keyed by the enemy job's resource path (jobs/terra/<slug>_job.tres).
@export var enemies_encountered: Dictionary = {}

# Array<ChapterSaveData>
var unlocked_chapters: Array = []

var current_chapter: ChapterSaveData


func unlock_chapter(title: String) -> void:
	var chapter: ChapterData = find_chapter_data_by_title(title)
	
	assert(chapter != null)
	
	var chapter_save_data = find_unlocked_chapter_by_title(title)
	
	if chapter_save_data != null:
		print("Chapter %s already unlocked" % title)
	else:
		var unlocked_chapter: ChapterSaveData = ChapterSaveData.new()
		
		unlocked_chapter.title = chapter.title
		
		unlocked_chapters.push_back(unlocked_chapter)


func find_chapter_data_by_title(title: String) -> ChapterData:
	var chapter_list: ChapterList = load("res://chapter_data/main_story_chapter_list.tres")
	
	return chapter_list.find_by_title(title)


func find_unlocked_chapter_by_title(title: String) -> ChapterSaveData:
	for chapter_save_data in unlocked_chapters:
		if chapter_save_data.title == title:
			return chapter_save_data
	
	return null


func is_chapter_unlocked(title: String) -> bool:
	return find_unlocked_chapter_by_title(title) != null


func is_chapter_cleared(title: String) -> bool:
	var chapter_save_data: ChapterSaveData = find_unlocked_chapter_by_title(title)

	return chapter_save_data != null && chapter_save_data.is_cleared


# Marks a chapter cleared and unlocks the next chapter in the story list.
func clear_chapter_and_unlock_next(title: String) -> void:
	var chapter_save_data: ChapterSaveData = find_unlocked_chapter_by_title(title)

	if chapter_save_data == null:
		unlock_chapter(title)
		chapter_save_data = find_unlocked_chapter_by_title(title)

	chapter_save_data.is_cleared = true

	var chapter_list: ChapterList = load("res://chapter_data/main_story_chapter_list.tres")

	for i in chapter_list.chapters.size():
		if chapter_list.chapters[i].title == title:
			_grant_chapter_jobs(chapter_list.chapters[i])

			if i + 1 < chapter_list.chapters.size():
				unlock_chapter(chapter_list.chapters[i + 1].title)

			break


# Story recruitment: grant the chapter's joining hero(es), skipping any the
# player already owns (so replays and old saves never create duplicates).
# New units join at the party's highest level so they arrive battle-ready.
func _grant_chapter_jobs(chapter_data: ChapterData) -> void:
	if chapter_data.unlocked_job_paths.is_empty():
		return

	var level: int = 1

	for job in jobs:
		level = max(level, job.level)

	for path in chapter_data.unlocked_job_paths:
		if _owns_job(path):
			continue

		var job: Job = load(path)

		if job == null:
			push_warning("Chapter grant: missing job resource %s" % path)
			continue

		add_job(job, level)

		print("New ally joined the roster: %s" % path)


func _owns_job(path: String) -> bool:
	for job in jobs:
		var owned_path: String = job.source_path if job.source_path != "" else job.resource_path

		if owned_path == path:
			return true

	return false


func add_job(job: Job, level: int) -> void:
	var new_job: Job = job.duplicate()
	new_job.stats = new_job.stats.duplicate()
	new_job.source_path = job.source_path if job.source_path != "" else job.resource_path
	new_job.uid = generate_uid(new_job.source_path)

	# Player heroes grow on TB's sub-linear curve (see game_data._duplicate_job).
	new_job.stats.uses_growth_curve = true

	new_job.level = level

	jobs.push_back(new_job)


# Mints a stable, unique id for a roster slot. Combines the source file name (for
# readability) with a monotonic counter (for uniqueness).
func generate_uid(job_path: String) -> String:
	var base: String = job_path.get_file().get_basename() if job_path != "" else "unit"
	var minted: String = "%s_%d" % [base, next_uid]

	next_uid += 1

	return minted


# Backfills a uid onto any roster slot missing one (legacy saves, hand-built
# rosters). Safe to call every load: slots that already have a uid keep it.
func ensure_uids() -> void:
	for job in jobs:
		if job.uid == "":
			var path: String = job.source_path if job.source_path != "" else job.resource_path

			job.uid = generate_uid(path)


func swap_jobs(old_job: Job, new_job: Job) -> void:
	if old_job != null:
		var index_of_old_job: int = jobs.find(old_job)
		
		assert(index_of_old_job != -1)
		
		var index_of_old_job_in_active_units: int = active_units.find(index_of_old_job)
		
		assert(index_of_old_job_in_active_units != -1)
		
		var index_of_new_job: int = jobs.find(new_job)
		
		assert(index_of_new_job != -1)
		
		var index_of_new_job_in_active_units: int = active_units.find(index_of_new_job)
		
		active_units[index_of_old_job_in_active_units] = index_of_new_job
		
		if index_of_new_job_in_active_units != -1:
			active_units[index_of_new_job_in_active_units] = index_of_old_job
	else:
		var index_of_new_job: int = jobs.find(new_job)
		
		assert(index_of_new_job != -1)
		
		active_units.push_back(index_of_new_job)
		
		assert(active_units.size() <= MAX_SQUAD_SIZE)


func remove_job(job: Job) -> void:
	if job != null:
		var index: int = jobs.find(job)
		
		assert(index != -1)
		
		active_units.erase(index)


func add_support_level(pair: String) -> void:
	var current_support_level: int = supports.get(pair, 0)

	supports[pair] = current_support_level + 1


# ---- Bestiary encounter tracking ----

const ENCOUNTER_SEEN: int = 1
const ENCOUNTER_DEFEATED: int = 2


# Records that an enemy appeared in battle. Never downgrades a defeated mark.
func mark_enemy_seen(path: String) -> void:
	if path == "":
		return

	if int(enemies_encountered.get(path, 0)) < ENCOUNTER_SEEN:
		enemies_encountered[path] = ENCOUNTER_SEEN


# Records that an enemy was defeated (the strongest encounter state).
func mark_enemy_defeated(path: String) -> void:
	if path == "":
		return

	enemies_encountered[path] = ENCOUNTER_DEFEATED


func enemy_encounter_state(path: String) -> int:
	return int(enemies_encountered.get(path, 0))


# ---- Squad save/switch (Terra Battle: up to 10 named squads) ----

# Guarantees at least one squad exists, seeded from the legacy active_units list
# (handles fresh saves and migration of pre-multi-squad saves).
func ensure_squads() -> void:
	if squads.is_empty():
		squads.append({"name": "SQUAD 1", "units": active_units.duplicate()})

	active_squad_index = clampi(active_squad_index, 0, squads.size() - 1)


# Mirrors the live active_units into the active saved squad (call before saving).
func sync_active_squad() -> void:
	ensure_squads()
	squads[active_squad_index]["units"] = active_units.duplicate()


func active_squad_name() -> String:
	ensure_squads()
	return squads[active_squad_index]["name"]


func rename_active_squad(new_name: String) -> void:
	ensure_squads()
	squads[active_squad_index]["name"] = new_name.substr(0, SQUAD_NAME_MAX_LENGTH)


# Persists current edits, then makes squad `index` active and loads its units.
func switch_to_squad(index: int) -> void:
	ensure_squads()

	if index < 0 or index >= squads.size():
		return

	sync_active_squad()

	active_squad_index = index
	active_units = squads[index]["units"].duplicate()


# Creates a new empty squad (up to MAX_SQUADS). Returns its index, or -1 if full.
func create_squad() -> int:
	ensure_squads()

	if squads.size() >= MAX_SQUADS:
		return -1

	sync_active_squad()

	squads.append({"name": "SQUAD %d" % (squads.size() + 1), "units": []})

	return squads.size() - 1
