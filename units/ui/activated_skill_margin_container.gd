extends MarginContainer


# Board-local center of the grid, used to decide which way the card opens
const BOARD_CENTER := Vector2(301.0, 401.0)

# Gap between the tile edge / neighboring cards and this card
const CARD_GAP := 8.0

# Half a tile plus the border ring
const TILE_HALF := 52.0

# Display pacing: a slower, readable beat
const FADE_IN_SECONDS := 0.18
const HOLD_SECONDS := 1.7
const FADE_OUT_SECONDS := 0.35

@export var activated_skill_hbox_container_packed_scene: PackedScene

# Cards currently on screen, so new ones can dodge instead of overlap
static var _live_cards: Array = []

var _card_tween: Tween

@onready var _vbox_container := $MarginContainer/VBoxContainer


func play(activated_skills: Array, unit_position: Vector2) -> void:
	for child in _vbox_container.get_children():
		_vbox_container.remove_child(child)

		child.queue_free()

	if activated_skills.is_empty():
		return

	for skill in activated_skills:
		print("Activated skill %s " % skill.skill_name)

		var activated_skill_hbox_container: HBoxContainer = activated_skill_hbox_container_packed_scene.instantiate()

		activated_skill_hbox_container.initialize(skill)

		_vbox_container.add_child(activated_skill_hbox_container)

		# White-on-dark styling for the floating combat popup; the same
		# label scene is also used on parchment menus, so style it here
		var label: Label = activated_skill_hbox_container.get_node("Label")

		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color(0.227451, 0.211765, 0.188235))
		label.add_theme_constant_override("outline_size", 8)

		activated_skill_hbox_container.get_node("TextureRect").modulate = Color(0.937255, 0.909804, 0.847059)

	# Defer placement one frame so the container reports its real size
	call_deferred("_place_and_animate", unit_position)


func _place_and_animate(unit_position: Vector2) -> void:
	_place_card(unit_position)
	_animate_card()


# Centers the card just above its unit (below for top-row units), stacking
# clear of any card already on screen so callouts never overlap or hide a unit.
func _place_card(unit_position: Vector2) -> void:
	var card_size: Vector2 = size
	var anchor: Vector2 = get_parent().global_position
	var viewport_size: Vector2 = get_viewport_rect().size

	# Top-half units open downward, lower-half upward, so the card sits on
	# the board-center side and never covers the acting unit
	var opens_down: bool = unit_position.y <= BOARD_CENTER.y

	var x: float = anchor.x - card_size.x * 0.5
	x = clampf(x, 8.0, viewport_size.x - card_size.x - 8.0)

	var y: float

	if opens_down:
		y = anchor.y + TILE_HALF + CARD_GAP
	else:
		y = anchor.y - TILE_HALF - CARD_GAP - card_size.y

	var rect := Rect2(Vector2(x, y), card_size)

	_live_cards = _live_cards.filter(
		func(card): return is_instance_valid(card) and card.visible and card != self
	)

	# Slide along the open axis until clear of every live card
	var moved := true

	while moved:
		moved = false

		for card in _live_cards:
			var other: Rect2 = card.get_meta("card_rect", card.get_global_rect()).grow(CARD_GAP * 0.5)

			if rect.intersects(other):
				if opens_down:
					rect.position.y = other.end.y + CARD_GAP
				else:
					rect.position.y = other.position.y - card_size.y - CARD_GAP

				moved = true

	rect.position.y = clampf(rect.position.y, 8.0, viewport_size.y - card_size.y - 8.0)

	grow_horizontal = Control.GROW_DIRECTION_END
	grow_vertical = Control.GROW_DIRECTION_END

	offset_left = rect.position.x - anchor.x
	offset_top = rect.position.y - anchor.y
	offset_right = offset_left + card_size.x
	offset_bottom = offset_top + card_size.y

	pivot_offset = card_size * 0.5

	set_meta("card_rect", rect)

	_live_cards.push_back(self)


# Pop in, hold long enough to read, drift up slightly, then fade
func _animate_card() -> void:
	if _card_tween != null:
		_card_tween.kill()

	visible = true
	modulate = Color(1, 1, 1, 0)
	scale = Vector2(0.82, 0.82)

	var base_top: float = offset_top

	$ActivationAudio.play()

	_card_tween = create_tween()

	# Scale-and-fade in with a gentle overshoot
	_card_tween.tween_property(self, "scale", Vector2.ONE, FADE_IN_SECONDS) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)
	_card_tween.parallel().tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)

	# Hold, drifting up a touch so it feels alive
	_card_tween.parallel().tween_property(self, "offset_top", base_top - 10.0, FADE_IN_SECONDS + HOLD_SECONDS) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_OUT)

	# Fade out
	_card_tween.tween_interval(HOLD_SECONDS)
	_card_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN)
	_card_tween.tween_callback(func(): visible = false)
