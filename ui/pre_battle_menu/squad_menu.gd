extends StackBasedMenuScreen

@export var unit_item_packed_scene: PackedScene

@export var change_unit_item_menu_scene: String # (String, FILE, "*.tscn")
@export var view_unit_menu_scene: String # (String, FILE, "*.tscn")

var _changed_job: Job = null
var _index_of_changed_job: int = -1
var _unit_item_to_highlight: Control = null
var _number_of_units_before_change: int = -1

@onready var _list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer

@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton
@onready var _squad_name_edit: LineEdit = $MarginContainer/VBoxContainer/SquadNameEdit
@onready var _squad_bar: HBoxContainer = $MarginContainer/VBoxContainer/SquadBar

const _SLOT_NORMAL := preload("res://assets/ui/btn_dark_normal.tres")
const _SLOT_HOVER := preload("res://assets/ui/btn_dark_hover.tres")
const _SLOT_PRESSED := preload("res://assets/ui/btn_dark_pressed.tres")


func _ready() -> void:
	var save_data: SaveData = GameData.save_data
	
	_number_of_units_before_change = save_data.active_units.size()
	
	_show_active_units()
	_refresh_squad_ui()


func on_load() -> void:
	super.on_load()
	
	_return_button.grab_focus()
	
	_highlight_changed_unit()
	_refresh_squad_ui()


func on_add_to_tree(data: Object) -> void:
	super.on_add_to_tree(data)
	
	_show_active_units()


func _show_active_units() -> void:
	print("Showing active units")
	
	var save_data: SaveData = GameData.save_data
	
	for child in _list_container.get_children():
		child.queue_free()
	
	if save_data.active_units.size() < SaveData.MAX_SQUAD_SIZE:
		$MarginContainer/VBoxContainer/AddUnitButton.show()
	else:
		$MarginContainer/VBoxContainer/AddUnitButton.hide()
	
	# store job reference and index in active units (0 - 6)
	# when showing active units
	# check if active_units[index of changed job] != job reference
	# if so then the unit was changed and you should highlight it
	# and set the parameters back to null and -1
	
	for i in save_data.active_units.size():
		var index: int = save_data.active_units[i]
		
		# TODO: Check if index is valid
		var job: Job = save_data.jobs[index]
		
		var unit_item: Control = unit_item_packed_scene.instantiate()
		
		_list_container.add_child(unit_item)
		
		unit_item.initialize(job, true) # Is draggable
		
		if unit_item.connect("change_button_clicked", Callable(self, "_on_UnitItem_change_button_clicked").bind(job, i)) != OK:
			printerr("Failed to connect signal")
		
		if unit_item.connect("unit_dropped_on_unit", Callable(self, "_on_UnitItem_unit_dropped_on_unit")) != OK:
			printerr("Failed to connect signal")
			
		if unit_item.connect("unit_double_clicked", Callable(self, "_on_UnitItem_unit_double_clicked").bind(job)) != OK:
			printerr("Failed to connect signal")
		
		if _changed_job != null && _index_of_changed_job != -1:
			if _index_of_changed_job == i and _changed_job != job:
				_unit_item_to_highlight = unit_item
	
	# TODO: Show empty spaces to show that player can have up to six units
	$MarginContainer/VBoxContainer/ReturnButton.disabled = save_data.active_units.size() < SaveData.MIN_SQUAD_SIZE


func _on_UnitItem_change_button_clicked(job: Job, container_index: int) -> void:
	_changed_job = job
	_index_of_changed_job = container_index
	
	var save_data: SaveData = GameData.save_data
	
	_number_of_units_before_change = save_data.active_units.size()
	
	navigate(change_unit_item_menu_scene, job)


func _on_UnitItem_unit_dropped_on_unit(target_unit_item: Control, dropped_unit_item: Control) -> void:
	var target_unit_item_position: int = _get_index_of_child(_list_container, target_unit_item)
	var dropped_unit_item_position: int = _get_index_of_child(_list_container, dropped_unit_item)
	
	assert(target_unit_item_position != -1)
	assert(dropped_unit_item_position != -1)
	
	_list_container.move_child(dropped_unit_item, target_unit_item_position)
	_list_container.move_child(target_unit_item, dropped_unit_item_position)
	
	var save_data: SaveData = GameData.save_data
	
	save_data.swap_jobs(target_unit_item.job, dropped_unit_item.job)
	
	$PlaceSound.play()


func _get_index_of_child(parent_node: Node, child_node: Node) -> int:
	var index: int = 0
	
	for child in parent_node.get_children():
		if child == child_node:
			return index
		
		index += 1
	
	return -1


func _highlight_changed_unit() -> void:
	var save_data: SaveData = GameData.save_data
	
	var number_of_units_after_change: int = save_data.active_units.size()
	
	if _unit_item_to_highlight != null:
		if _number_of_units_before_change > number_of_units_after_change:
			print("Unit removed")
		else:
			_unit_item_to_highlight.highlight()
		
		_unit_item_to_highlight = null
		
		_changed_job = null
		_index_of_changed_job = -1
		_number_of_units_before_change = number_of_units_after_change
	else:
		# If a unit was added, highlight the last child
		if _number_of_units_before_change < number_of_units_after_change:
			assert(_list_container.get_child_count() > 0)
			
			_list_container.get_child(_list_container.get_child_count() - 1).highlight()


func _on_ReturnButton_pressed() -> void:
	GameData.save_data.sync_active_squad()
	GameData.save()

	go_back()


func _on_AddUnitButton_pressed() -> void:
	_on_UnitItem_change_button_clicked(null, -1)


func _on_UnitItem_unit_double_clicked(job: Job) -> void:
	navigate(view_unit_menu_scene, job)


# ---- Multi-squad bar (Terra Battle: save & switch up to 10 named squads) ----

func _refresh_squad_ui() -> void:
	var save_data: SaveData = GameData.save_data
	save_data.ensure_squads()

	if not _squad_name_edit.text_submitted.is_connected(_on_squad_name_submitted):
		_squad_name_edit.text_submitted.connect(_on_squad_name_submitted)
		_squad_name_edit.focus_exited.connect(_on_squad_name_focus_exited)

	_squad_name_edit.text = save_data.active_squad_name()
	_refresh_squad_bar()


func _refresh_squad_bar() -> void:
	var save_data: SaveData = GameData.save_data

	for child in _squad_bar.get_children():
		child.queue_free()

	for i in save_data.squads.size():
		var slot := _make_slot_button(str(i + 1), i == save_data.active_squad_index)
		slot.pressed.connect(_on_squad_slot_pressed.bind(i))
		_squad_bar.add_child(slot)

	if save_data.squads.size() < SaveData.MAX_SQUADS:
		var add_button := _make_slot_button("+", false)
		add_button.pressed.connect(_on_add_squad_pressed)
		_squad_bar.add_child(add_button)


func _make_slot_button(label: String, is_active: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(46, 46)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _SLOT_NORMAL)
	button.add_theme_stylebox_override("hover", _SLOT_HOVER)
	button.add_theme_stylebox_override("pressed", _SLOT_PRESSED)
	button.add_theme_stylebox_override("focus", _SLOT_HOVER)

	if is_active:
		button.modulate = Color(1.0, 0.85, 0.4)
		button.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78))
	else:
		button.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))

	return button


func _on_squad_slot_pressed(index: int) -> void:
	var save_data: SaveData = GameData.save_data

	if index == save_data.active_squad_index:
		return

	save_data.switch_to_squad(index)
	GameData.save()

	_number_of_units_before_change = save_data.active_units.size()
	_changed_job = null
	_index_of_changed_job = -1
	_unit_item_to_highlight = null

	_show_active_units()
	_refresh_squad_ui()
	$PlaceSound.play()


func _on_add_squad_pressed() -> void:
	var save_data: SaveData = GameData.save_data

	var index: int = save_data.create_squad()

	if index == -1:
		return

	save_data.switch_to_squad(index)
	GameData.save()

	_number_of_units_before_change = 0

	_show_active_units()
	_refresh_squad_ui()
	$PlaceSound.play()


func _on_squad_name_submitted(_text: String) -> void:
	_commit_squad_name()
	_squad_name_edit.release_focus()


func _on_squad_name_focus_exited() -> void:
	_commit_squad_name()


func _commit_squad_name() -> void:
	var save_data: SaveData = GameData.save_data
	save_data.rename_active_squad(_squad_name_edit.text)
	save_data.sync_active_squad()
	GameData.save()
