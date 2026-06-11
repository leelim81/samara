extends Node


# At what HP percentage this condition is true
# Setting 1.0 is equivalent to ignoring this value
@export var max_hp_percentage: float = 1.0 # (float, 0.1, 1, 0.1)

# Minimum HP percentage required so this condition is true.
# Has to be lower than max HP percentage
@export var minimum_hp_percentage: float = 0.0 # (float, 0.0, 1, 0.1)

# Whether this condition should only activate once
@export var is_one_shot: bool = false

# If true, check turn offset and turn steps, otherwise don't use
# turns to determine if condition can be activated
@export var can_check_turn_counter: bool = true

# At which specific enemy turn this condition is true
@export var turn_offset: int = 1

# This condition repeats every X turns
# turn_offset + turn_steps * counter
@export var turn_steps: int = 1 # (int, 0, 20, 1)

# How many times this condition can trigger
@export var max_uses: int = -1 # (int, -1, 20)

# How many units can be alive after which this condition won't trigger
@export var max_units_alive: int = -1 # (int, -1, 20, 1)

# How many units must be alive for this condition to trigger
@export var min_units_alive: int = -1 # (int, 0, 20, 1)

# Set after a one-shot condition is activated and the corresponding action
# is performed
var _is_activated: bool = false

# Turn counter, increased every time the turn check matches, even if the
# rest of the checks do not pass.
var _counter: int = 0

var _usage_count: int = 0


func _ready() -> void:
	assert(minimum_hp_percentage < max_hp_percentage)


func is_true(current_hp_percentage: float, current_turn: int, can_use_turn_counter: bool) -> bool:
	var is_current_counter_valid: bool = _is_current_counter_valid(current_turn)
	
	if is_current_counter_valid:
		# Keep track of the counter even if the condition is not fulfilled
		_counter += 1
	
	if max_uses != -1:
		_usage_count += 1
		
		if _usage_count >= max_uses:
			return false
	
	if current_hp_percentage < minimum_hp_percentage or current_hp_percentage > max_hp_percentage:
		return false
	
	if is_one_shot and _is_activated:
		return false
	
	if can_use_turn_counter and can_check_turn_counter and not is_current_counter_valid:
		return false
	
	return true


func reset_turn_counter() -> void:
	_counter = 0


func _is_current_counter_valid(current_turn: int) -> bool:
	return turn_offset + (_counter * turn_steps) == current_turn
