class_name Unit
extends CharacterBody2D


enum STATE {
	# Idle
	IDLE = 0,
	
	# Picked up, being dragged by the player or being moved by the AI
	PICKED_UP = 1,
	
	SNAPPING_TO_GRID = 2,
	
	SWAPPING = 3
}

enum Size {
	SINGLE_1X1,
	DOUBLE_2X2
}

const INVALID_FACTION: int = -1
const PLAYER_FACTION: int = 1
const ENEMY_FACTION: int = 2

signal picked_up(unit)
signal released(unit)
signal snapped_to_grid(unit)
signal dead(unit)
signal death_animation_finished(unit)
signal selected_for_view(unit)

@export var damage_numbers_packed_scene: PackedScene
@export var death_effect_packed_scene: PackedScene

@export var size: Size = Size.SINGLE_1X1

@export var velocity_pixels_per_second: float = 15.0
@export var snap_velocity_pixels_per_second: float = 420.0
@export var swap_velocity_pixels_per_second: float = 800.0

# Max velocity when dragging the unit. It can't be too fast or the unit
# will tunnel through cells and other units.
@export var max_velocity_pixels_per_second: float = 2048.0 # 2048

# Proportional control constant
@export var kp: float = 1.4

@export var is_click_to_drag: bool = true
@export var is_controlled_by_player: bool = true

@export var level: int = 10 # (int, 1, 50, 1)

@export var can_flee_when_enemy_enters_nearby_cell: bool = false

var current_state = STATE.IDLE: set = set_current_state

var faction: int = INVALID_FACTION

# Says if a unit has escaped or used a escape skill
var is_escaped: bool = false

var _random := RandomNumberGenerator.new()

# Array<StatusEffect>
var _status_effects: Array = []

var _has_entered_cell: bool = false

@onready var _is2x2: bool = (size == Size.DOUBLE_2X2)

var _position_tween: Tween
var _scale_tween: Tween
var _lunge_tween: Tween
var _flash_tween: Tween

@onready var _sprite := $Sprite2D


func _ready() -> void:
	_random.randomize()
	
	self.current_state = STATE.IDLE
	
	_load_job_textures()
	
	if not is_click_to_drag:
		set_process_input(false)


func _physics_process(_delta: float) -> void:
	match(current_state):
		STATE.IDLE:
			pass
		STATE.PICKED_UP:
			if is_controlled_by_player:
				_move_towards_mouse()
			
			if is_click_to_drag and Input.is_action_just_released("ui_accept"):
				if is_controlled_by_player:
					release()
				
				$LongPressTimer.stop()


func appear() -> void:
	disable_selection_area()
	
	disable_swap_area()
	
	$Sound/AppearAudio.play()
	
	$AnimationPlayer.play("appear")


func hide_name() -> void:
	$AnimationPlayer.play("hide name")


func play_death_animation() -> void:
	$AnimationPlayer.play("death")
	$Sound/DeathAudio.play()

	var death_effect: Node2D = death_effect_packed_scene.instantiate()

	add_child_at_offset(death_effect)
	death_effect.play()
	
	disable_selection_area()
	disable_swap_area()
	Utils.disable_object($CollisionShape2D)
	
	emit_signal("dead", self)


func is_death_animation_playing() -> bool:
	return $AnimationPlayer.current_animation == "death"


func play_flee_animation() -> void:
	# TODO: Show exclamation sign
	
	$Sound/FleeAudio.play()


func play_escape_animation() -> void:
	# Set the health to 0 and the flag so this unit is picked up the PincerExecutor
	# in the next call to check_dead_units(), and the unit is removed from play
	get_stats().health = 0
	is_escaped = true
	
	$Sound/EscapeAudio.play()
	
	$AnimationPlayer.play("disappear")


func play_scale_up_and_down_animation() -> void:
	if _scale_tween != null:
		_scale_tween.kill()

	$AnimationPlayer.play("scale up and down")


func stop_scale_up_and_down_animation() -> void:
	$AnimationPlayer.stop()

	_tween_sprite_scale(Vector2.ONE, 0.15, Tween.TRANS_LINEAR)


# Displaced units dart out of the way with a quick ease-out slide.
func move_to_new_cell(target_position: Vector2) -> void:
	var tween_time_seconds: float = Utils.calculate_time(position, target_position, swap_velocity_pixels_per_second)

	_start_position_tween(target_position, tween_time_seconds, Tween.TRANS_CUBIC, Tween.EASE_OUT)

	self.current_state = STATE.SWAPPING


func push_to_cell(target_position: Vector2) -> void:
	move_to_new_cell(target_position)

	Utils.disable_object($CollisionShape2D)


func enable_swap_area() -> void:
	Utils.enable_object($SwapArea2D/CollisionShape2D)


func disable_swap_area() -> void:
	Utils.disable_object($SwapArea2D/CollisionShape2D)


func enable_selection_area() -> void:
	_has_entered_cell = false
	
	Utils.enable_object($SelectionArea2D/CollisionShape2D)
	
	$SelectionArea2D.monitorable = true


func disable_selection_area() -> void:
	Utils.disable_object($SelectionArea2D/CollisionShape2D)
	
	$SelectionArea2D.monitorable = false


func _move_towards_mouse() -> void:
	var error: Vector2 = get_global_mouse_position() - global_position

	velocity = (error * kp * velocity_pixels_per_second).limit_length(max_velocity_pixels_per_second)

	move_and_slide()


func _input(event: InputEvent):
	if not is_click_to_drag:
		if event.is_action_released("ui_select"):
			release()
		elif event is InputEventScreenTouch and not event.pressed:
			release()


func snap_to_grid(cell_origin: Vector2) -> void:
	self.current_state = STATE.SNAPPING_TO_GRID

	var tween_time_seconds: float = Utils.calculate_time(position, cell_origin, snap_velocity_pixels_per_second)

	_start_position_tween(cell_origin, tween_time_seconds, Tween.TRANS_QUAD, Tween.EASE_OUT)


func is_picked_up() -> bool:
	return current_state == STATE.PICKED_UP


func is_snapping() -> bool:
	return current_state == STATE.SNAPPING_TO_GRID


func is_idle() -> bool:
	return current_state == STATE.IDLE


func _pick_up() -> void:
	if current_state == STATE.IDLE:
		self.current_state = STATE.PICKED_UP
		
		if is2x2():
			Utils.disable_object($CollisionShape2D)


func release() -> void:
	if is_picked_up():
		$LongPressTimer.stop()
		
		self.current_state = STATE.IDLE
		
		emit_signal("released", self)


func _load_job_textures() -> void:
	$CanvasLayer/Control/WeaponType.texture = load(Enums.WEAPON_TYPE_TEXTURES[$Job.job.stats.weapon_type])
	$Sprite2D/Icon.texture = $Job.job.portrait
	
	$CanvasLayer/UnitName.text = tr($Job.job.job_name)


## Setters

func set_job(job: Job) -> void:
	$Job.set_job(job)
	
	_load_job_textures()
	
	apply_equip_skills()


func set_drag_mode(drag_mode: int) -> void:
	if drag_mode == Enums.DragMode.CLICK:
		is_click_to_drag = true
		
		set_process_input(false)
	else:
		is_click_to_drag = false
		
		set_process_input(true)


# Setter function for current_state.
func set_current_state(new_state) -> void:
	current_state = new_state
	
	match(new_state):
		STATE.IDLE:
			disable_swap_area()
			
			set_physics_process(false)
			
			_restore_sprite_size()
			
			Utils.enable_object($CollisionShape2D)
		STATE.PICKED_UP:
			enable_swap_area()
			
			set_physics_process(true)
			
			emit_signal("picked_up", self)
			
			_increase_sprite_size()
			
			$Sound/PickUpAudio.play()
			
			_has_entered_cell = false
		STATE.SNAPPING_TO_GRID:
			disable_swap_area()
		STATE.SWAPPING:
			disable_swap_area()
			
			$Sound/SwapAudio.play()


# Quick pop on pickup, like lifting a piece off the board.
func _increase_sprite_size() -> void:
	_tween_sprite_scale(Vector2(1.18, 1.18), 0.12, Tween.TRANS_BACK, Tween.EASE_OUT)


func _restore_sprite_size() -> void:
	_tween_sprite_scale(Vector2.ONE, 0.12, Tween.TRANS_CUBIC, Tween.EASE_OUT)


# Squash-and-settle pulse played when a unit lands on its cell.
func play_settle_animation() -> void:
	if _scale_tween != null:
		_scale_tween.kill()

	_scale_tween = create_tween()
	_scale_tween.tween_property(_sprite, "scale", Vector2(1.08, 0.92), 0.06) \
			.set_trans(Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _tween_sprite_scale(target_scale: Vector2, duration_seconds: float, transition: Tween.TransitionType, easing: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if _scale_tween != null:
		_scale_tween.kill()

	_scale_tween = create_tween()
	_scale_tween.tween_property(_sprite, "scale", target_scale, duration_seconds) \
			.set_trans(transition) \
			.set_ease(easing)


# Tweens this unit's position, killing any previous position tween. The
# finished callback drives the snap/swap state transitions.
func _start_position_tween(target_position: Vector2, duration_seconds: float, transition: Tween.TransitionType = Tween.TRANS_SINE, easing: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if _position_tween != null:
		_position_tween.kill()

	_position_tween = create_tween()
	_position_tween.tween_property(self, "position", target_position, duration_seconds) \
			.set_trans(transition) \
			.set_ease(easing)

	_position_tween.finished.connect(_on_position_tween_finished)


# Returns once the current position tween (if any) has finished playing.
func wait_until_movement_finished() -> void:
	if _position_tween != null and _position_tween.is_running():
		await _position_tween.finished


func is_player() -> bool:
	return faction == PLAYER_FACTION


func is_ally(unit_faction: int) -> bool:
	return (faction & unit_faction) != 0


func is_enemy(unit_faction: int) -> bool:
	return not is_ally(unit_faction)


func get_base_stats() -> Stats:
	return $Job.base_stats


func get_stats() -> Stats:
	return $Job.current_stats


func get_max_health() -> int:
	return $Job.base_stats.health


func get_job() -> Job:
	return $Job.job


func get_level() -> int:
	return $Job.level


func get_skills() -> Array:
	return $Job.skills


func get_unlocked_skills() -> Array:
	return $Job.get_unlocked_skills()


func get_status_effects() -> Array:
	return _status_effects


func calculate_attack_damage(attacker_stats: Stats) -> int:
	return calculate_damage(attacker_stats, get_stats(), 1.0, attacker_stats.weapon_type, attacker_stats.attribute)


func inflict_damage(damage: int) -> void:
	$Job.decrease_health(damage)

	if damage > 0:
		$AnimationPlayer.play("shake")

		flash_hit()

	var damage_numbers: Node2D = damage_numbers_packed_scene.instantiate()

	add_child_at_offset(damage_numbers)

	damage_numbers.play(damage)


# Quick lunge toward an attack target and back; the visual punch of a
# pincer attack. Only the sprite moves, so cell lookups stay untouched.
func play_attack_lunge(target_global_position: Vector2) -> void:
	var direction: Vector2 = (target_global_position - global_position).normalized()

	if _lunge_tween != null:
		_lunge_tween.kill()

	_lunge_tween = create_tween()
	_lunge_tween.tween_property(_sprite, "position", direction * 22.0, 0.08) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)
	_lunge_tween.tween_property(_sprite, "position", Vector2.ZERO, 0.18) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_IN_OUT)


# Additive white flash over the tile when this unit takes a hit.
func flash_hit() -> void:
	var flash: Sprite2D = $Sprite2D/Flash

	# Mirror the tile background so the flash fits 1x1 and 2x2 tiles alike
	flash.texture = _sprite.texture

	if _flash_tween != null:
		_flash_tween.kill()

	flash.modulate.a = 0.0

	_flash_tween = create_tween()
	_flash_tween.tween_property(flash, "modulate:a", 0.85, 0.04)
	_flash_tween.tween_property(flash, "modulate:a", 0.0, 0.22) \
			.set_trans(Tween.TRANS_CUBIC) \
			.set_ease(Tween.EASE_OUT)


func activate_skills() -> Array:
	var activated_skills := []
	
	for skill in get_unlocked_skills():
		# Activation rules
		if skill.area_of_effect == Enums.AreaOfEffect.EQUIP or skill.skill_type == Enums.SkillType.COUNTER:
			continue
		
		var activation: float = _random.randf() + $Job.current_stats.skill_activation_rate_modifier
		
		if activation < skill.activation_rate:
			activated_skills.push_back(skill)
	
	return activated_skills


func play_skill_activation_animation(activated_skills: Array, layer_z_index: int) -> void:
	$CanvasLayer/ActivatedSkillMarginContainer.play(activated_skills, position)
	$CanvasLayer.z_index = layer_z_index
	
	$Sound/SkillActivationAudio.play()


func apply_skill(unit: Unit, skill: Skill, on_damage_absorbed_callback: Callable) -> void:
	$SkillApplier.apply_skill(unit, skill, on_damage_absorbed_callback, _status_effects)


func calculate_damage(attacker_stats: Stats,
			defender_stats: Stats,
			power: float,
			weapon_type: int,
			attribute: int) -> int:
	return $SkillApplier.calculate_damage(attacker_stats, defender_stats, power, weapon_type, attribute)


# Removes Sleep status effects when unit is pincered
func on_attacked() -> void:
	_remove_all_status_effects_of_type(Enums.StatusEffectType.SLEEP)


func recalculate_stats() -> void:
	$Job.reset_stats()
	
	for status_effect in _status_effects:
		status_effect.modify_stats($Job.base_stats, $Job.current_stats)


func is_dead() -> bool:
	return get_stats().health <= 0


func is_alive() -> bool:
	return not is_dead()


func is2x2() -> bool:
	return _is2x2


func get_offset_origin() -> Vector2:
	return position + _sprite.position


func add_child_at_offset(node: Node2D) -> void:
	add_child(node)
	
	node.position = _sprite.position


func update_status_effects_icons() -> void:
	if is_alive():
		$CanvasLayer/StatusEffectsIcons.update_icon(_status_effects)


func _remove_all_status_effects_of_type(status_effect_type: int) -> void:
	if has_status_effect_of_type(status_effect_type):
		var status_effects_to_remove: Array = _status_effects.duplicate()
		
		for status_effect in status_effects_to_remove:
			if status_effect.status_effect_type == status_effect_type:
				$SkillApplier.remove_status_effect(_status_effects, status_effect)
		
		recalculate_stats()


func apply_equip_skills() -> void:
	for skill in get_unlocked_skills():
		if skill.area_of_effect != Enums.AreaOfEffect.EQUIP:
			continue
		
		apply_skill(self, skill, Callable())


## Animation playback


func _appear_animation_finished() -> void:
	self.current_state = STATE.IDLE


func _death_animation_finished() -> void:
	emit_signal("death_animation_finished", self)


func _on_snap_to_grid() -> void:
	self.current_state = STATE.IDLE

	play_settle_animation()

	emit_signal("snapped_to_grid", self)

	$Sound/SnapAudio.play()


func inflict(status_effect_type: int) -> void:
	$SkillApplier.inflict(status_effect_type, _status_effects)


func has_status_effect_of_type(status_effect_type: int) -> bool:
	for effect in _status_effects:
		if effect.status_effect_type == status_effect_type:
			return true
	
	return false


func on_enter_cell() -> void:
	_has_entered_cell = true
	
	$LongPressTimer.stop()


func on_select_for_view() -> void:
	if not _has_entered_cell:
		print("Unit selected!")
		
		emit_signal("selected_for_view", self)
	
	if is_controlled_by_player and current_state == STATE.PICKED_UP:
		release()


func can_act() -> bool:
	return not (is_dead() or _has_blocking_status_effect())


func _has_blocking_status_effect() -> bool:
	return has_status_effect_of_type(Enums.StatusEffectType.SLEEP) or \
			has_status_effect_of_type(Enums.StatusEffectType.PARALYZE) or \
			has_status_effect_of_type(Enums.StatusEffectType.CONFUSE)


## Signals

func _on_SelectionArea2D_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.double_click and is_click_to_drag:
		on_select_for_view()
	elif event is InputEventMouseButton and event.pressed:
		if not is_click_to_drag:
			$LongPressTimer.start()
		
		if is_controlled_by_player and can_act():
			match(current_state):
				STATE.IDLE:
					_pick_up()
				STATE.PICKED_UP:
					release()


func _on_position_tween_finished() -> void:
	match(current_state):
		STATE.SNAPPING_TO_GRID:
			_on_snap_to_grid()
		STATE.SWAPPING:
			self.current_state = STATE.IDLE


func _on_SelectionArea2D_mouse_entered() -> void:
	if is_controlled_by_player and current_state == STATE.IDLE and can_act():
		$Sprite2D/Glow.show()

		_tween_sprite_scale(Vector2(1.08, 1.08), 0.1, Tween.TRANS_CUBIC, Tween.EASE_OUT)


func _on_SelectionArea2D_mouse_exited() -> void:
	if is_controlled_by_player and current_state == STATE.IDLE and can_act():
		_tween_sprite_scale(Vector2.ONE, 0.1, Tween.TRANS_CUBIC, Tween.EASE_OUT)


func _on_LongPressTimer_timeout() -> void:
	on_select_for_view()
