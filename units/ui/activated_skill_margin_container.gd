extends MarginContainer


# Board-local center of the grid, used to decide which way cards open
const BOARD_CENTER := Vector2(301.0, 401.0)

# Gap between the tile edge / neighboring cards and this card
const CARD_GAP := 6.0

# Half a tile plus the border ring
const TILE_HALF := 52.0

@export var activated_skill_hbox_container_packed_scene: PackedScene

# Cards currently on screen, so new ones can dodge instead of overlap
static var _live_cards: Array = []

@onready var _vbox_container := $MarginContainer/VBoxContainer


func play(activated_skills: Array, unit_position: Vector2) -> void:
	for child in _vbox_container.get_children():
		_vbox_container.remove_child(child)

		child.queue_free()

	if not activated_skills.is_empty():
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

		_place_card(unit_position)

		$AnimationPlayer.play("Fade in and then out")


# Positions the card beside its unit without covering the tile, sliding
# past any other card already on screen so callouts never overlap.
func _place_card(unit_position: Vector2) -> void:
	var card_size: Vector2 = get_combined_minimum_size()
	var anchor: Vector2 = get_parent().global_position
	var viewport_size: Vector2 = get_viewport_rect().size

	# Upper-half units show the card below their tile, lower-half above,
	# so the card never hides the unit that is acting
	var opens_down: bool = unit_position.y <= BOARD_CENTER.y

	# Hug the tile's near edge and open toward the board center
	var x: float

	if unit_position.x > BOARD_CENTER.x:
		x = anchor.x + 22.0 - card_size.x
	else:
		x = anchor.x - 22.0

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

	# Slide away from existing cards until nothing intersects. Compare
	# against each card's recorded rect; layout of cards placed this same
	# frame may not have settled yet.
	var moved := true

	while moved:
		moved = false

		for card in _live_cards:
			var other: Rect2 = card.get_meta("card_rect", card.get_global_rect())

			other = other.grow(CARD_GAP * 0.5)

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

	set_meta("card_rect", rect)

	_live_cards.push_back(self)
