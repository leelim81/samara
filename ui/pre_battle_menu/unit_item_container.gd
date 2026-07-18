extends HBoxContainer


signal change_button_clicked
signal unit_selected
signal unit_dropped_on_unit(target_unit_item, dropped_unit_item)
signal unit_double_clicked()

var job: Job

var _is_draggable: bool = false

var _card_style_normal: StyleBox
var _card_style_hover: StyleBoxFlat

@onready var _card: PanelContainer = $Card
@onready var _unit_icon := $Card/H/UnitIcon
@onready var _name_label: Label = $Card/H/Body/NameRow/NameLabel
@onready var _weapon_icon: TextureRect = $Card/H/Body/NameRow/WeaponIcon
@onready var _lv_label: Label = $Card/H/Body/NameRow/LvLabel
@onready var _stats_container := $Card/H/Body/UnitStatsContainer
@onready var _change_button := $Card/H/ChangeButton


func _ready() -> void:
	# Same glyph whether the button reads CHANGE or CHOOSE.
	ButtonIcons.apply(_change_button, "swap")
	_build_hover_style()


# A clean box highlight on hover, matching the stage-selection cells: the whole
# card brightens (gold border + a faint fill lift) instead of the old red-orange
# glow that sat misaligned behind the portrait.
func _build_hover_style() -> void:
	var base := _card.get_theme_stylebox("panel") as StyleBoxFlat
	if base == null:
		return

	_card_style_normal = base
	_card_style_hover = base.duplicate()
	_card_style_hover.bg_color = Color(0.16, 0.185, 0.223, 0.97)
	_card_style_hover.border_color = Color(0.95, 0.82, 0.5, 0.7)
	_card_style_hover.set_border_width_all(2)


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

	_configure_click_targets()


# Makes the whole card a single tap / hover target instead of just the
# portrait: every visual child is transparent to the mouse so clicks reach the
# Card, except the CHANGE button which keeps its own hit area. The Card stays
# the drag entry point (drag & drop walks up to this container's handlers).
func _configure_click_targets() -> void:
	_pass_mouse_through(_card)

	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_change_button.mouse_filter = Control.MOUSE_FILTER_STOP


func _pass_mouse_through(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

		_pass_mouse_through(child)


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


func _on_Card_mouse_entered() -> void:
	if _card_style_hover != null:
		_card.add_theme_stylebox_override("panel", _card_style_hover)


func _on_Card_mouse_exited() -> void:
	if _card_style_normal != null:
		_card.add_theme_stylebox_override("panel", _card_style_normal)


func _on_Card_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_select"):
		emit_signal("unit_selected")
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if event.double_click:
			emit_signal("unit_double_clicked")
		elif not _is_draggable:
			# A draggable row (squad reorder) reserves single clicks for the
			# drag; browse / attach rows open the detail page on a single tap.
			emit_signal("unit_selected")
