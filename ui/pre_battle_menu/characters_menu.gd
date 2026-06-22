extends StackBasedMenuScreen
# Terra-Battle-style character collection: a scrollable list of every unit the
# player owns. Tap a unit to open its detail page (the shared view_unit_menu).
# Browse-only: no swapping or removing here (that lives in the squad flow).


@export var unit_item_container_packed_scene: PackedScene

@export var view_unit_menu_scene: String # (String, FILE, "*.tscn")

@onready var _list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _header_label: Label = $MarginContainer/VBoxContainer/HeaderLabel


func _ready() -> void:
	_show_units()


func on_add_to_tree(_data: Object) -> void:
	_show_units()


func on_load() -> void:
	super.on_load()

	_show_units()

	$MarginContainer/VBoxContainer/ReturnButton.grab_focus()


func _show_units() -> void:
	for child in _list_container.get_children():
		child.queue_free()

	var save_data: SaveData = GameData.save_data

	for job in save_data.jobs:
		var row: Control = unit_item_container_packed_scene.instantiate()

		_list_container.add_child(row)

		# false: not draggable; no comparison stats
		row.initialize(job, false, null)
		row.hide_change_button()

		if row.connect("unit_selected", Callable(self, "_on_unit_chosen").bind(job)) != OK:
			printerr("Failed to connect unit_selected")

	_header_label.text = "%s  (%d)" % [tr("CHARACTERS"), save_data.jobs.size()]


func _on_unit_chosen(job: Job) -> void:
	navigate(view_unit_menu_scene, job)


func _on_ReturnButton_pressed() -> void:
	go_back()
