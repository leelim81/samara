extends Node


const _UNIT_DATA_SECTION: String = "unit_data"
const _SETTINGS_SECTION: String = "settings"

const _JOBS_KEY: String = "jobs"

const _PASSWORD: String = "SkIHn2y08Z6RKbsFAU1axABs6GHf00qUmY0OP5SKfZMG1g9pzQ"

var save_data: SaveData

var config_file := ConfigFile.new()


func _ready() -> void:
	load_data()
	apply_settings()


# Loads data into globals
func load_data():
	if save_data != null:
		return
	
	if FileAccess.file_exists(_get_config_file_path()):
		if _load_config_file() != OK:
			push_error("Failed to load save data")
			
			_load_data_from_default_resource()
		else:
			_load_data_from_configs_file()
	else:
		_load_data_from_default_resource()

	# Ensure the multi-squad model exists and active_units reflects the active
	# squad (also migrates pre-multi-squad saves into squads[0]).
	save_data.ensure_squads()
	save_data.active_units = save_data.squads[save_data.active_squad_index]["units"].duplicate()


# True once the player has progress on disk (used to show "Continue").
func has_save_file() -> bool:
	return FileAccess.file_exists(_get_config_file_path())


# Applies persisted audio volumes and locale on boot.
func apply_settings() -> void:
	_apply_bus_volume("Music", save_data.music_volume)
	_apply_bus_volume("Sound effects", save_data.sound_effects_volume)

	if save_data.locale != "":
		TranslationServer.set_locale(save_data.locale)


func _apply_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)

	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


# Returns Error
func _load_config_file():
	if OS.is_debug_build():
		return config_file.load(_get_config_file_path())
	else:
		return config_file.load_encrypted_pass(_get_config_file_path(), _PASSWORD)


func _load_data_from_configs_file() -> void:
	save_data = SaveData.new()
	
	var unit_data: Array = config_file.get_value(_UNIT_DATA_SECTION, _JOBS_KEY, null)
	
	for serialized_job in unit_data:
		save_data.jobs.push_back(_deserialize_job(serialized_job))
	
	save_data.active_units = config_file.get_value(_UNIT_DATA_SECTION, "active_units", save_data.active_units)
	save_data.squads = config_file.get_value(_UNIT_DATA_SECTION, "squads", [])
	save_data.active_squad_index = config_file.get_value(_UNIT_DATA_SECTION, "active_squad_index", 0)

	save_data.music_volume = config_file.get_value(_SETTINGS_SECTION, "music_volume", 1.0)
	save_data.sound_effects_volume = config_file.get_value(_SETTINGS_SECTION, "sound_effects_volume", 1.0)
	save_data.locale = config_file.get_value(_SETTINGS_SECTION, "locale", "")
	
	save_data.unlocked_chapters = config_file.get_value("levels", "unlocked_chapters", null)
	
	if save_data.unlocked_chapters == null:
		unlock_default_chapters()


func _load_data_from_default_resource() -> void:
	var default_save_data: SaveData = load("res://save_data/default_save_data.tres")
	
	save_data = default_save_data.duplicate()
	
	unlock_default_chapters()
	
	var duplicated_jobs: Array = []
	
	for job in save_data.jobs:
		duplicated_jobs.push_back(_duplicate_job(job, 1))
	
	save_data.jobs = duplicated_jobs


func unlock_default_chapters() -> void:
	# Real progression: only the first chapter is unlocked at the start; clearing
	# a chapter unlocks the next (see SaveData.clear_chapter_and_unlock_next).
	var chapter_list: ChapterList = load("res://chapter_data/main_story_chapter_list.tres")
	if not chapter_list.chapters.is_empty():
		save_data.unlock_chapter(chapter_list.chapters[0].title)

	save_data.current_chapter = save_data.unlocked_chapters.back()


# TODO: Test save and load functions
func save() -> void:
	# Mirror the live squad edits into the saved-squads list before persisting.
	save_data.sync_active_squad()

	var serialized_jobs := []

	# Save jobs as an array of dictionaries. Preserve the order so that the
	# squad unit indices keep pointing at the correct units.
	for job in save_data.jobs:
		serialized_jobs.push_back(_serialize_job(job))

	config_file.set_value(_UNIT_DATA_SECTION, _JOBS_KEY, serialized_jobs)
	config_file.set_value(_UNIT_DATA_SECTION, "active_units", save_data.active_units)
	config_file.set_value(_UNIT_DATA_SECTION, "squads", save_data.squads)
	config_file.set_value(_UNIT_DATA_SECTION, "active_squad_index", save_data.active_squad_index)

	config_file.set_value(_SETTINGS_SECTION, "music_volume", save_data.music_volume)
	config_file.set_value(_SETTINGS_SECTION, "sound_effects_volume", save_data.sound_effects_volume)
	config_file.set_value(_SETTINGS_SECTION, "locale", save_data.locale)
	
	config_file.set_value("levels", "unlocked_chapters", save_data.unlocked_chapters)
	
	_save_config_file()


func _save_config_file() -> void:
	if OS.is_debug_build():
		if config_file.save(_get_config_file_path()) != OK:
			push_error("Failed to save data")
	else:
		if config_file.save_encrypted_pass(_get_config_file_path(), _PASSWORD) != OK:
			push_error("Failed to save data")


func _get_config_file_path() -> String:
	if OS.get_name() == "Web":
		return "user://" + _build_config_file_path()
	else:
		return _build_config_file_path()


func _build_config_file_path() -> String:
	if OS.is_debug_build():
		return "save-data-debug.sav"
	else:
		return "save-data.sav"


func _serialize_job(job: Job) -> Dictionary:
	var path: String = job.source_path if job.source_path != "" else job.resource_path

	return {
		"job_resource_path": path,
		"level": job.level,
		"current_exp": job.current_exp,
	}


func _deserialize_job(dictionary: Dictionary) -> Job:
	var job: Job = _duplicate_job(load(dictionary.job_resource_path), dictionary.get("level", 1))

	job.current_exp = dictionary.get("current_exp", 0)

	# Migrate legacy saves that stored only level: seed EXP from the level so
	# subsequent EXP gains continue from the right place.
	if job.current_exp == 0 and job.level > 1:
		job.current_exp = Leveling.exp_for_level(job.level)

	return job


func _duplicate_job(job: Job, level: int) -> Job:
	# Duplicates job and stats (to update stats according to the level),
	# but does not duplicate other resources of Job
	var new_job: Job = job.duplicate()
	new_job.stats = job.stats.duplicate()

	# Preserve the original path for save serialization (duplicates lose it).
	new_job.source_path = job.source_path if job.source_path != "" else job.resource_path

	# Sets the level to update the stats
	new_job.level = level

	return new_job
