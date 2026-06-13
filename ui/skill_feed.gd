extends Control
# Shared skill-activation feed. As units activate skills during a pincer,
# each name appears as one row in a single bottom-centered stack — so the
# callouts never scatter across the board or overlap each other.


const MAX_ROWS := 5

@export var row_scene: PackedScene

@onready var _vbox: VBoxContainer = $VBox


func _ready() -> void:
	var events: Node = get_node_or_null("/root/Events")

	if events != null:
		var _error = events.connect("skill_activated", Callable(self, "_on_skill_activated"))


func _on_skill_activated(skill) -> void:
	# Drop the oldest row if the stack gets tall
	while _vbox.get_child_count() >= MAX_ROWS:
		var oldest: Node = _vbox.get_child(0)

		_vbox.remove_child(oldest)
		oldest.queue_free()

	var row = row_scene.instantiate()

	_vbox.add_child(row)

	row.setup(skill)
	row.play()
