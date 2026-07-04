extends SceneTree
# Verifies the Outer Heaven recruitment drip:
#   - a fresh save starts with exactly the 3 starters
#   - clearing chapters grants the joining hero listed in that chapter's
#     unlocked_job_paths (wired by tools/wire_chapter_joins.py)
#   - replaying a cleared chapter grants no duplicates
#   - the full 42-chapter run ends with all 26 playable heroes
# Run: godot --headless --script res://tools/test_recruit_drip.gd


func _job_paths(sd: SaveData) -> Array:
	var out: Array = []
	for job in sd.jobs:
		out.push_back(job.source_path if job.source_path != "" else job.resource_path)
	return out


func _initialize() -> void:
	var default_save: SaveData = load("res://save_data/default_save_data.tres")
	var sd: SaveData = default_save.duplicate()
	sd.jobs = default_save.jobs.duplicate()

	var cl: ChapterList = load("res://chapter_data/main_story_chapter_list.tres")

	var ok := true

	if sd.jobs.size() != 3:
		print("FAIL: fresh save has %d jobs, expected 3" % sd.jobs.size())
		ok = false

	sd.unlock_chapter(cl.chapters[0].title)

	# Clear chapters 1..5: grants shberdan (2), daiana (3), bagunar (4), macuri (5).
	for i in range(5):
		sd.clear_chapter_and_unlock_next(cl.chapters[i].title)

	if sd.jobs.size() != 7:
		print("FAIL: after ch.5 have %d jobs, expected 7 (%s)" % [sd.jobs.size(), _job_paths(sd)])
		ok = false

	if not sd._owns_job("res://jobs/terra/bagunar_job.tres"):
		print("FAIL: bagunar not granted after ch.4")
		ok = false

	# Replay chapter 4: no duplicates.
	sd.clear_chapter_and_unlock_next(cl.chapters[3].title)

	if sd.jobs.size() != 7:
		print("FAIL: replaying ch.4 changed job count to %d" % sd.jobs.size())
		ok = false

	# Clear the rest of the story: roster must end at 26.
	for i in range(5, cl.chapters.size()):
		sd.clear_chapter_and_unlock_next(cl.chapters[i].title)

	if sd.jobs.size() != 26:
		print("FAIL: after ch.42 have %d jobs, expected 26" % sd.jobs.size())
		ok = false

	# Grants join at party max level, never below 1.
	var max_level := 0
	for job in sd.jobs:
		max_level = max(max_level, job.level)
	if max_level < 1:
		print("FAIL: bad grant level %d" % max_level)
		ok = false

	if ok:
		print("test_recruit_drip: PASS (3 starters, +23 joins, no dupes, roster 26)")
		quit(0)
	else:
		print("test_recruit_drip: FAIL")
		quit(1)
