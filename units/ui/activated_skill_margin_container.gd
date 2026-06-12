extends MarginContainer


@export var activated_skill_hbox_container_packed_scene: PackedScene

@onready var _vbox_container := $MarginContainer/VBoxContainer


func play(activated_skills: Array, unit_position: Vector2) -> void:
	for child in _vbox_container.get_children():
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
		
		_set_growth_position(unit_position)
		
		$AnimationPlayer.play("Fade in and then out")


func _set_growth_position(unit_position: Vector2) -> void:
	# TODO: Get dimensoins from the grid (this is the size of the grid image)
	var screen_center: Vector2 = Vector2(602.0, 802.0) / 2.0
	
	var position_relative_to_center: Vector2 = unit_position - screen_center
	
	print(position_relative_to_center)
	
	if position_relative_to_center.x > 0:
		# Unit on the right side of the screen, grow towards the left
		grow_horizontal = Control.GROW_DIRECTION_BEGIN
	else:
		# Unit on the left side of the screen, grow towards the right
		grow_horizontal = Control.GROW_DIRECTION_END
	
	if position_relative_to_center.y > 0:
		# Unit on the lower part of the screen, grow upwards
		grow_vertical = Control.GROW_DIRECTION_BEGIN
	else:
		grow_vertical = Control.GROW_DIRECTION_BOTH
