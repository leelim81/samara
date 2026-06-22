extends PanelContainer


signal pressed


func set_values(chapter_data: ChapterData) -> void:
	$VBoxContainer/TitleRow/AudioButton.text = tr(chapter_data.title)
	$VBoxContainer/TitleRow/DifficultyLabel.text = "Lv %s" % chapter_data.difficulty
	$VBoxContainer/CaptionLabel.text = tr(chapter_data.caption)

	if chapter_data.locked:
		modulate = Color(1, 1, 1, 0.45)
		$VBoxContainer/TitleRow/AudioButton.disabled = true
		$VBoxContainer/CaptionLabel.text = tr("COMING_SOON")
	elif GameData.save_data.is_chapter_cleared(chapter_data.title):
		# Cleared chapters show their difficulty in green as a progress cue.
		$VBoxContainer/TitleRow/DifficultyLabel.add_theme_color_override("font_color", Color(0.45, 0.85, 0.45))

	var battle_info: BattleInfo = chapter_data.battle_info

	$VBoxContainer/InfoRow/SwordEnemyCountLabel.text = str(battle_info.sword_enemy_count)
	$VBoxContainer/InfoRow/SpearEnemyCountLabel.text = str(battle_info.spear_enemy_count)
	$VBoxContainer/InfoRow/GunEnemyCountLabel.text = str(battle_info.gun_enemy_count)
	$VBoxContainer/InfoRow/StaffEnemyCountLabel.text = str(battle_info.staff_enemy_count)

	$VBoxContainer/InfoRow/BattleCountLabel.text = "%s: %d" % [tr("BATTLES"), battle_info.phases_count]


func _on_AudioButton_pressed() -> void:
	emit_signal("pressed")
