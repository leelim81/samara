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
		if chapter_list.chapters[i].title == title and i + 1 < chapter_list.chapters.size():
			unlock_chapter(chapter_list.chapters[i + 1].title)

			break


func add_job(job: Job, level: int) -> void:
	var new_job: Job = job.duplicate()
	new_job.stats = new_job.stats.duplicate()
	new_job.source_path = job.source_path if job.source_path != "" else job.resource_path

	new_job.level = level

	jobs.push_back(new_job)


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
