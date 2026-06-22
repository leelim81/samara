extends StackBasedMenuScreen
# Terra-Battle-style character collection: a scrollable list of every unit the
# player owns. Tap a unit to open its detail page (the shared view_unit_menu).
# Browse-only: no swapping or removing here (that lives in the squad flow).


@export var unit_item_container_packed_scene: PackedScene

@export var view_unit_menu_scene: String # (String, FILE, "*.tscn")

@onready var _list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _header_label: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var _sort_option: OptionButton = $MarginContainer/VBoxContainer/SortOption

# Sort keys (Terra Battle sorts the collection by these).
enum _Sort { LEVEL, HP, ATK, DEF, MATK, MDEF }


func _ready() -> void:
	_setup_sort()
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

	for job in _sorted_jobs():
		var row: Control = unit_item_container_packed_scene.instantiate()

		_list_container.add_child(row)

		# false: not draggable; no comparison stats
		row.initialize(job, false, null)
		row.hide_change_button()

		if row.connect("unit_selected", Callable(self, "_on_unit_chosen").bind(job)) != OK:
			printerr("Failed to connect unit_selected")

		# Mouse users open the detail page via double-click (keyboard uses ui_select)
		if row.connect("unit_double_clicked", Callable(self, "_on_unit_chosen").bind(job)) != OK:
			printerr("Failed to connect unit_double_clicked")

	_header_label.text = "%s  (%d)" % [tr("CHARACTERS"), save_data.jobs.size()]


func _on_unit_chosen(job: Job) -> void:
	navigate(view_unit_menu_scene, job)


func _on_ReturnButton_pressed() -> void:
	go_back()


# ---- Sorting (Terra Battle: Level / HP / ATK / DEF / MATK / MDEF) ----

func _setup_sort() -> void:
	if _sort_option.item_count == 0:
		_sort_option.add_item("LV", _Sort.LEVEL)
		_sort_option.add_item("HP", _Sort.HP)
		_sort_option.add_item("ATK", _Sort.ATK)
		_sort_option.add_item("DEF", _Sort.DEF)
		_sort_option.add_item("S.ATK", _Sort.MATK)
		_sort_option.add_item("S.DEF", _Sort.MDEF)
		_sort_option.item_selected.connect(_on_sort_selected)


func _on_sort_selected(_index: int) -> void:
	_show_units()


func _sorted_jobs() -> Array:
	var jobs: Array = GameData.save_data.jobs.duplicate()
	var key: int = _sort_option.get_selected_id() if _sort_option.item_count > 0 else _Sort.LEVEL

	jobs.sort_custom(func(a, b): return _sort_value(a, key) > _sort_value(b, key))

	return jobs


func _sort_value(job, key: int) -> int:
	match key:
		_Sort.HP:
			return job.stats.health
		_Sort.ATK:
			return job.stats.attack
		_Sort.DEF:
			return job.stats.defense
		_Sort.MATK:
			return job.stats.spiritual_attack
		_Sort.MDEF:
			return job.stats.spiritual_defense
		_:
			return job.level
