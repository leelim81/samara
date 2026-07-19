extends StackBasedMenuScreen
## Debug art gallery. Lists every unit in the game — playable characters and
## enemies — from the generated manifest (bestiary/gallery_list.tres, built by
## tools/build_gallery.gd). Selecting a unit opens its detail page, which shows
## all of that unit's art assets (base / job2 / job3 / awakened, full + token).
## Reached from the title screen; only shown while Global.DEBUG is true.

@export var gallery_detail_scene: String # (String, FILE, "*.tscn")

@onready var _list: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _header: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

const _MANIFEST_PATH: String = "res://bestiary/gallery_list.tres"

var _entries: Array = []


func _ready() -> void:
	_load_entries()
	_build_list()

	ButtonIcons.apply(_return_button, "return")


func on_load() -> void:
	super.on_load()

	_return_button.grab_focus()


func _load_entries() -> void:
	var manifest = load(_MANIFEST_PATH)

	_entries = manifest.entries if manifest != null else []


func _build_list() -> void:
	for child in _list.get_children():
		child.queue_free()

	var heroes: Array = []
	var enemies: Array = []

	for entry in _entries:
		if bool(entry.get("is_enemy", false)):
			enemies.append(entry)
		else:
			heroes.append(entry)

	_add_section("CHARACTERS", heroes)
	_add_section("ENEMIES", enemies)

	_header.text = "GALLERY  (%d)" % _entries.size()


func _add_section(title: String, entries: Array) -> void:
	if entries.is_empty():
		return

	var header := Label.new()
	header.text = "%s  (%d)" % [title, entries.size()]
	header.custom_minimum_size = Vector2(0, 44)
	header.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.753, 0.627, 0.384))

	_list.add_child(header)

	for entry in entries:
		_list.add_child(_make_row(entry))


func _make_row(entry: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 80)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.expand_icon = true
	btn.clip_text = true
	btn.add_theme_font_size_override("font_size", 20)

	var token_path := String(entry.get("token_path", ""))

	if token_path != "" and ResourceLoader.exists(token_path):
		btn.icon = load(token_path)

	btn.text = "  " + tr(String(entry.get("name_key", "?")))

	var path := String(entry.get("path", ""))

	btn.pressed.connect(func() -> void: _on_entry_selected(path))

	return btn


func _on_entry_selected(path: String) -> void:
	var job = load(path)

	if job == null:
		return

	# Duplicate so the shared cached resource is never mutated; set source_path
	# so the detail page can resolve this unit's job2/job3 variant art.
	var shown: Job = job.duplicate()
	shown.source_path = path

	navigate(gallery_detail_scene, shown)


func _on_ReturnButton_pressed() -> void:
	go_back()
