extends HBoxContainer


signal change_button_clicked
signal unit_selected
signal unit_dropped_on_unit(target_unit_item, dropped_unit_item)
signal unit_double_clicked()

var job: Job

var _is_draggable: bool = false

@onready var _unit_icon := $Card/H/UnitIcon
@onready var _name_label: Label = $Card/H/Body/NameRow/NameLabel
@onready var _weapon_icon: TextureRect = $Card/H/Body/NameRow/WeaponIcon
@onready var _lv_label: Label = $Card/H/Body/NameRow/LvLabel
@onready var _stats_container := $Card/H/Body/UnitStatsContainer
@onready var _change_button := $Card/H/ChangeButton


func initialize(_job: Job, is_draggable: bool = false, compare_job: Job = null) -> void:
	job = _job
	_is_draggable = is_draggable

	_name_label.text = tr(job.job_name)

	_unit_icon.initialize(job, _is_draggable)

	# The thumbnail's built-in weapon stamp renders oversized; show a tidy
	# inline weapon glyph next to the name instead
	_unit_icon.get_node("WeaponTypeTexture").visible = false
	_weapon_icon.texture = load(Enums.WEAPON_TYPE_TEXTURES[job.stats.weapon_type])

	_lv_label.text = "Lv %d" % job.level

	var compare_job_stats: Stats = null

	if compare_job != null:
		compare_job_stats = compare_job.stats

	_stats_container.initialize(job.stats, compare_job_stats)


func set_change_button_as_choose_button() -> void:
	_change_button.text = tr("CHOOSE")


func highlight() -> void:
	if $AnimationPlayer.current_animation.is_empty():
		$AnimationPlayer.play("highlight")

		$HighlightAudio.play()


# This method is untyped because it returns a Variant
func _get_drag_data(_position: Vector2):
	if _is_draggable:
		set_drag_preview(_build_drag_preview())

		return self
	else:
		return null


func _can_drop_data(_position: Vector2, data) -> bool:
	return _is_draggable and data is HBoxContainer and data != self


func _drop_data(_position: Vector2, data) -> void:
	emit_signal("unit_dropped_on_unit", self, data)


# Builds a drag preview using the unit's icon
func _build_drag_preview() -> Control:
	_unit_icon.get_node("TextureRect2").hide()

	var nine_patch_rect = _unit_icon.duplicate()

	nine_patch_rect.modulate.a = 0.75

	return nine_patch_rect


func hide_change_button() -> void:
	_change_button.hide()


func _on_ChangeButton_pressed() -> void:
	emit_signal("change_button_clicked")


func _on_UnitIcon_mouse_entered() -> void:
	_unit_icon.show_glow()


func _on_UnitIcon_mouse_exited()  -> void:
	_unit_icon.hide_glow()


func _on_UnitIcon_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"):
		emit_signal("unit_selected")

	if event is InputEventMouseButton and event.doubleclick:
		emit_signal("unit_double_clicked")
