extends Node2D


signal target_reached

@export var trail_velocity_pixels_per_second := 1200.0
@export var displacement_time_seconds := 0.2

# If true, the tween time is fixed and the velocity of the trail will
# be determined by the tween automatically.
@export var is_tween_fixed_time := true

@export var arc_height := 100.0

@export var particles_node_path: NodePath

var _particles: CPUParticles2D
var _total_tween_time_seconds: float


func _ready() -> void:
	_particles = get_node(particles_node_path)


func play(start_position: Vector2, target_position: Vector2) -> void:
	_particles.emitting = true

	var distance: float = start_position.distance_to(target_position)

	if is_tween_fixed_time:
		_total_tween_time_seconds = displacement_time_seconds
	else:
		_total_tween_time_seconds = distance / trail_velocity_pixels_per_second

	# Must be in this order
	rotation = target_position.angle_to_point(start_position)

	# Arc: rise during the first half of the travel, fall during the second.
	var height_tween := create_tween()
	height_tween.tween_method(_update_arc_height, _particles.position.y, arc_height, _total_tween_time_seconds / 2) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	height_tween.tween_method(_update_arc_height, arc_height, 0.0, _total_tween_time_seconds / 2) \
			.set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)

	# Travel runs for the full duration, so it finishes together with the arc.
	var travel_tween := create_tween()
	travel_tween.tween_method(_update_horizontal_position, _particles.position.x, distance, _total_tween_time_seconds) \
			.set_trans(Tween.TRANS_LINEAR) \
			.set_ease(Tween.EASE_IN)

	travel_tween.finished.connect(_on_travel_tween_finished)


func _update_arc_height(height: float) -> void:
	_particles.position.y = height


func _update_horizontal_position(horizontal_position: float) -> void:
	_particles.position.x = horizontal_position


func _on_travel_tween_finished() -> void:
	emit_signal("target_reached")

	_particles.emitting = false

	$Timer.start()

	await $Timer.timeout

	queue_free()
