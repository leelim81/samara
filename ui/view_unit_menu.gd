extends StackBasedMenuScreen


@export var skill_pill_packed_scene: PackedScene
@export var status_row_packed_scene: PackedScene

@onready var _name_label: Label = $Margin/Root/NameLabel
@onready var _art: TextureRect = $Margin/Root/Header/FullArt
@onready var _token: TextureRect = $Margin/Root/Header/Info/ThumbRow/JobThumb/Token
@onready var _weapon_icon: TextureRect = $Margin/Root/Header/Info/ThumbRow/ThumbMeta/SpeciesRow/WeaponIcon
@onready var _species_label: Label = $Margin/Root/Header/Info/ThumbRow/ThumbMeta/SpeciesRow/SpeciesLabel
@onready var _lv_label: Label = $Margin/Root/Header/Info/ThumbRow/ThumbMeta/LVLabel
@onready var _hp_value: Label = $Margin/Root/Header/Info/HPBlock/HPRow/HPValue
@onready var _hp_bar: ProgressBar = $Margin/Root/Header/Info/HPBlock/HPBar
@onready var _atk_value: Label = $Margin/Root/Header/Info/StatsGrid/AtkStat/Value
@onready var _def_value: Label = $Margin/Root/Header/Info/StatsGrid/DefStat/Value
@onready var _satk_value: Label = $Margin/Root/Header/Info/StatsGrid/SatkStat/Value
@onready var _sdef_value: Label = $Margin/Root/Header/Info/StatsGrid/SdefStat/Value
@onready var _skills_vbox: VBoxContainer = $Margin/Root/SkillsScroll/SkillsVBox
@onready var _skills_header: Label = $Margin/Root/SkillsHeader
@onready var _return_button: Button = $Margin/Root/ReturnButton


# Called from squad menu
func initialize(job: Job, level: int) -> void:
	# Show activation rate, is not in battle, don't ignore locked skills
	initialize_from_data(job, job.stats, null, level, job.skills, [], true, false, false)


func initialize_from_data(job: Job, base_stats: Stats, current_stats: Stats, level: int, skills: Array, status_effects: Array, can_show_activation_rate: bool, is_in_battle: bool, can_ignore_locked_skills: bool) -> void:
	_set_focus()

	for child in _skills_vbox.get_children():
		child.queue_free()

	_name_label.text = tr(job.job_name)
	_art.texture = job.full_portrait
	_token.texture = job.portrait

	_species_label.text = base_stats.unit_type.capitalize()
	_weapon_icon.texture = load(Enums.WEAPON_TYPE_TEXTURES[base_stats.weapon_type])

	_lv_label.text = "LV %d" % level

	# In battle the panel reflects the unit's live stats; otherwise its base
	var display_stats: Stats = current_stats if (is_in_battle and current_stats != null) else base_stats

	if is_in_battle and current_stats != null:
		_hp_value.text = "%d / %d" % [current_stats.health, base_stats.health]
		_hp_bar.value = 100.0 * float(current_stats.health) / max(1.0, float(base_stats.health))
	else:
		_hp_value.text = str(base_stats.health)
		_hp_bar.value = 100.0

	_atk_value.text = str(display_stats.attack)
	_def_value.text = str(display_stats.defense)
	_satk_value.text = str(display_stats.spiritual_attack)
	_sdef_value.text = str(display_stats.spiritual_defense)

	var unlocked_skills: Array = job.get_unlocked_skills(level)

	for skill in skills:
		var is_skill_locked: bool = false

		if not can_ignore_locked_skills:
			is_skill_locked = not skill in unlocked_skills

		var pill: PanelContainer = skill_pill_packed_scene.instantiate()

		_skills_vbox.add_child(pill)

		pill.setup(skill, can_show_activation_rate, is_skill_locked)

	if is_in_battle and not status_effects.is_empty():
		var status_header := Label.new()
		status_header.text = tr("STATUS_EFFECTS_TAB")
		status_header.add_theme_color_override("font_color", Color(0.56, 0.63, 0.74))
		status_header.add_theme_font_override("font", _skills_header.get_theme_font("font"))
		status_header.add_theme_font_size_override("font_size", 16)

		_skills_vbox.add_child(status_header)

		for status_effect in status_effects:
			var row: HBoxContainer = status_row_packed_scene.instantiate()

			_skills_vbox.add_child(row)

			row.initialize_from_status_effect(status_effect)
			row.get_node("Label").add_theme_color_override("font_color", Color(0.9, 0.93, 1.0))


func on_add_to_tree(data: Object) -> void:
	var job: Job = data as Job

	initialize(job, job.level)


func _set_focus() -> void:
	_return_button.grab_focus()


func _on_ReturnButton_pressed() -> void:
	_return_button.disabled = true

	go_back()
