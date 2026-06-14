extends SceneTree
# Verifies clear-to-unlock-next progression. Run:
#   godot --headless --script res://tools/test_unlock_chain.gd


func _initialize() -> void:
	var sd := SaveData.new()
	var cl: ChapterList = load("res://chapter_data/main_story_chapter_list.tres")
	var c1: String = cl.chapters[0].title
	var c2: String = cl.chapters[1].title
	var c3: String = cl.chapters[2].title

	sd.unlock_chapter(c1)

	var before := sd.is_chapter_unlocked(c2)

	sd.clear_chapter_and_unlock_next(c1)

	var c1_cleared := sd.is_chapter_cleared(c1)
	var c2_now := sd.is_chapter_unlocked(c2)
	var c3_still_locked := not sd.is_chapter_unlocked(c3)

	print("c2 unlocked before clearing c1: %s (expect false)" % before)
	print("c1 cleared: %s (expect true)" % c1_cleared)
	print("c2 unlocked after clearing c1: %s (expect true)" % c2_now)
	print("c3 still locked: %s (expect true)" % c3_still_locked)

	if not before and c1_cleared and c2_now and c3_still_locked:
		print("UNLOCK CHAIN: PASS")
		quit(0)
	else:
		print("UNLOCK CHAIN: FAIL")
		quit(1)
