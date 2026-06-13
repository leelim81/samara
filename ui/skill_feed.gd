extends Control
# Shared skill-activation feed. Each activated skill slides in as one box-less
# callout (star + glowing name) stacked at the lower-left, so they never
# scatter across the board or overlap. Newest sits at the bottom; older rows
# slide up; each self-expires.


const MAX_ROWS := 5
const LEFT_X := 40.0
const BOTTOM_OFFSET := 156.0
const ROW_STEP := 46.0

@export var row_scene: PackedScene

var _rows: Array = []


func _ready() -> void:
	var events: Node = get_node_or_null("/root/Events")

	if events != null:
		var _error = events.connect("skill_activated", Callable(self, "_on_skill_activated"))


func _on_skill_activated(skill) -> void:
	# Retire the oldest callout if the stack gets tall
	while _rows.size() >= MAX_ROWS:
		var oldest = _rows.pop_front()

		if is_instance_valid(oldest):
			oldest.dismiss_now()

	var row = row_scene.instantiate()

	add_child(row)

	row.setup(skill)
	row.expired.connect(_on_row_expired.bind(row))

	_rows.push_back(row)

	_reflow(row)


func _on_row_expired(row) -> void:
	_rows.erase(row)

	_reflow(null)


# Stack rows from the bottom up (newest lowest); slide the new one in, glide
# the rest to their new heights
func _reflow(new_row) -> void:
	var screen: Vector2 = get_viewport_rect().size

	for i in _rows.size():
		var from_bottom: int = _rows.size() - 1 - i
		var y: float = screen.y - BOTTOM_OFFSET - from_bottom * ROW_STEP

		if _rows[i] == new_row:
			_rows[i].play(Vector2(LEFT_X, y))
		else:
			_rows[i].move_to_y(y)
