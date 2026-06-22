extends SceneTree
# Verifies the clear-to-unlock chain reaches all 42 chapters and that no
# chapter is still flagged locked (a placeholder). Run:
#   godot --headless --script res://tools/test_full_chain.gd


func _initialize() -> void:
	var cl: ChapterList = load("res://chapter_data/main_story_chapter_list.tres")
	var n: int = cl.chapters.size()

	var locked_titles: Array = []
	var empty_scene: Array = []
	for c in cl.chapters:
		if c.locked:
			locked_titles.push_back(c.title)
		if c.battle_scene_path == "" or not ResourceLoader.exists(c.battle_scene_path):
			empty_scene.push_back(c.title)

	# Walk the chain: start with only chapter 1 unlocked, then only clear a
	# chapter if it is already unlocked (so a broken link leaves a gap).
	var sd := SaveData.new()
	sd.unlock_chapter(cl.chapters[0].title)
	for i in range(n):
		var t: String = cl.chapters[i].title
		if sd.is_chapter_unlocked(t):
			sd.clear_chapter_and_unlock_next(t)

	var unlocked: int = 0
	for c in cl.chapters:
		if sd.is_chapter_unlocked(c.title):
			unlocked += 1

	print("chapters=%d  unlocked_via_chain=%d  locked_flag=%s  missing_scene=%s"
		% [n, unlocked, locked_titles, empty_scene])

	if n == 42 and unlocked == 42 and locked_titles.is_empty() and empty_scene.is_empty():
		print("FULL CHAIN: PASS")
		quit(0)
	else:
		print("FULL CHAIN: FAIL")
		quit(1)
