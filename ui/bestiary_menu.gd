extends StackBasedMenuScreen
# Terra-Battle-style enemy collection. Lists every enemy from the generated
# manifest (bestiary/enemy_list.tres); discovered ones show their token, name,
# and defeat state and open the shared detail page, while undiscovered ones stay
# as dim silhouettes. Encounters are recorded in battle (board.gd) and persisted
# at victory.

@export var bestiary_row_packed_scene: PackedScene
@export var view_unit_menu_scene: String # (String, FILE, "*.tscn")

@onready var _list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _header: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

const _MANIFEST_PATH: String = "res://bestiary/enemy_list.tres"

var _entries: Array = []
var _level_by_path: Dictionary = {}


func _ready() -> void:
	_load_entries()
	_build_list()


func on_add_to_tree(_data: Object) -> void:
	_build_list()


func on_load() -> void:
	super.on_load()

	_return_button.grab_focus()


func _load_entries() -> void:
	var manifest = load(_MANIFEST_PATH)

	_entries = manifest.entries if manifest != null else []


func _build_list() -> void:
	for child in _list.get_children():
		child.queue_free()

	var save_data: SaveData = GameData.save_data
	var discovered_count: int = 0

	for entry in _entries:
		var state: int = 0

		if save_data != null:
			state = save_data.enemy_encounter_state(String(entry.get("path", "")))

		if state >= SaveData.ENCOUNTER_SEEN:
			discovered_count += 1

		_level_by_path[String(entry.get("path", ""))] = int(entry.get("level", 1))

		var row = bestiary_row_packed_scene.instantiate()

		_list.add_child(row)

		row.configure(entry, state)

		if row.connect("selected", Callable(self, "_on_entry_selected")) != OK:
			printerr("Failed to connect bestiary row selected signal")

	_header.text = "%s  (%d / %d)" % [tr("BESTIARY"), discovered_count, _entries.size()]


func _on_entry_selected(path: String) -> void:
	var job = load(path)

	if job == null:
		return

	# Duplicate so we can show the enemy at its representative battle level
	# without mutating the shared job resource used in battles.
	var shown: Job = job.duplicate()
	shown.stats = job.stats.duplicate()
	shown.source_path = path
	shown.level = int(_level_by_path.get(path, 1))

	navigate(view_unit_menu_scene, shown)


func _on_ReturnButton_pressed() -> void:
	go_back()
