extends SkillEffect


const _SIMPLE_HIT_PATH := "res://skills/effects/simple_hit_animation.tscn"

# Frame at which the skill is activated
@export var activation_frame: int = 0
@export var animation_packed_scene: PackedScene

# Per-element variants of the generic hit burst, keyed by Enums.Attribute.
# When a skill using the generic burst is elemental, its element's own burst
# plays instead; weapon-shaped animations (shots, spears, sweeps) keep their
# silhouette and take the element's tint.
var _element_animations := {
	Enums.Attribute.FIRE: preload("res://skills/effects/fire_hit_animation.tscn"),
	Enums.Attribute.ICE: preload("res://skills/effects/ice_hit_animation.tscn"),
	Enums.Attribute.LIGHTNING: preload("res://skills/effects/lightning_hit_animation.tscn"),
	Enums.Attribute.DARKNESS: preload("res://skills/effects/shadow_hit_animation.tscn"),
}

var _element_tints := {
	Enums.Attribute.FIRE: Color(1.0, 0.72, 0.32),
	Enums.Attribute.ICE: Color(0.55, 0.85, 1.0),
	Enums.Attribute.LIGHTNING: Color(1.0, 0.95, 0.5),
	Enums.Attribute.DARKNESS: Color(0.78, 0.55, 1.0),
}


func _start(unit: Unit, skill: Skill, target_cells: Array) -> void:
	var scene: PackedScene = _animation_scene_for(skill)

	for cell in target_cells:
		if scene == null:
			_update_count(unit)
			_apply_skill(unit, skill, cell)

			return

		var animated_sprite: AnimatedSprite2D = scene.instantiate()

		add_child(animated_sprite)
		animated_sprite.position = cell.position
		animated_sprite.frame = 0

		# A weapon-shaped animation that carries an element gets tinted; the
		# swapped elemental bursts already bake their colors in.
		if scene == animation_packed_scene and _element_tints.has(skill.primary_attribute):
			animated_sprite.modulate = _element_tints[skill.primary_attribute]

		if skill.is_targeted_individually() and cell.unit != null:
			animated_sprite.position = cell.unit.get_offset_origin()
		
		if activation_frame > 0:
			var _error = animated_sprite.frame_changed.connect(
					_on_AnimatedSprite_frame_changed.bind(animated_sprite, unit, skill, cell))
		else:
			_apply_skill(unit, skill, cell)

		var _error = animated_sprite.animation_finished.connect(
				_on_AnimatedSprite_animation_finished.bind(unit),
				CONNECT_ONE_SHOT)
		
		animated_sprite.play()


# The generic burst swaps to the skill's own elemental burst; anything else
# (weapon-shaped or bespoke animations) is kept as assigned.
func _animation_scene_for(skill: Skill) -> PackedScene:
	if animation_packed_scene == null:
		return null

	if animation_packed_scene.resource_path == _SIMPLE_HIT_PATH \
			and _element_animations.has(skill.primary_attribute):
		return _element_animations[skill.primary_attribute]

	return animation_packed_scene


func _on_AnimatedSprite_frame_changed(animated_sprite: AnimatedSprite2D, unit: Unit, skill: Skill, target_cell: Cell) -> void:
	if animated_sprite.frame == activation_frame:
		_apply_skill(unit, skill, target_cell)


func _on_AnimatedSprite_animation_finished(unit: Unit) -> void:
	_update_count(unit)
