extends StackBasedMenuScreen
## Debug gallery detail page. Shows every art asset for one unit: the base form,
## each job variant (job2 / job3) that exists, and the awakened form if present —
## each with its full art and token. Opened from gallery_menu with the unit's
## Job passed as data (its source_path drives variant resolution).

@onready var _name_label: Label = $MarginContainer/VBoxContainer/HeaderLabel
@onready var _content: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/MarginContainer/VBoxContainer
@onready var _return_button: Button = $MarginContainer/VBoxContainer/ReturnButton

var _job: Job = null


func _ready() -> void:
	ButtonIcons.apply(_return_button, "return")


func on_add_to_tree(data: Object) -> void:
	if data is Job:
		_job = data

	if _job != null:
		_render(_job)


func on_load() -> void:
	super.on_load()

	_return_button.grab_focus()


func _render(job: Job) -> void:
	_name_label.text = tr(job.job_name)

	for child in _content.get_children():
		child.queue_free()

	# Base form comes straight off the job; variants and awakened are resolved
	# the same way the game resolves them at runtime (jobs/job.gd).
	_add_form_section("BASE", job.full_portrait, job.portrait)

	for n in [2, 3]:
		var vpath := Job.variant_path(job.source_path, n)

		if vpath != "" and vpath != job.source_path and ResourceLoader.exists(vpath):
			var variant = load(vpath)

			if variant != null:
				_add_form_section("JOB %d" % n, variant.full_portrait, variant.portrait)

	var awk_full := _awakened_variant(job.full_portrait)
	var awk_token := _awakened_variant(job.portrait)

	if awk_full != null or awk_token != null:
		_add_form_section("AWAKENED", awk_full, awk_token)


# Mirrors Job._variant_texture(): the awakened art lives under the parallel
# assets/terra/awakened/ tree; returns null when there is no awakened file.
func _awakened_variant(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null

	var path: String = texture.resource_path

	if path == "":
		return null

	var variant_path: String = path.replace("res://assets/terra/", "res://assets/terra/awakened/")

	if variant_path == path or not ResourceLoader.exists(variant_path):
		return null

	return load(variant_path)


func _add_form_section(label_text: String, full: Texture2D, token: Texture2D) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	_content.add_child(section)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.753, 0.627, 0.384))
	section.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	section.add_child(row)

	if full != null:
		var full_rect := TextureRect.new()
		full_rect.texture = full
		full_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		full_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		# 1414:2000 aspect kept; scaled to a readable preview size.
		full_rect.custom_minimum_size = Vector2(300, 424)
		row.add_child(full_rect)

	var meta := VBoxContainer.new()
	meta.add_theme_constant_override("separation", 6)
	row.add_child(meta)

	var token_caption := Label.new()
	token_caption.text = "Token"
	token_caption.add_theme_font_size_override("font_size", 15)
	token_caption.add_theme_color_override("font_color", Color(0.604, 0.64, 0.667))
	meta.add_child(token_caption)

	if token != null:
		var token_rect := TextureRect.new()
		token_rect.texture = token
		token_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		token_rect.custom_minimum_size = Vector2(120, 120)
		meta.add_child(token_rect)
	else:
		var none := Label.new()
		none.text = "—"
		none.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		meta.add_child(none)


func _on_ReturnButton_pressed() -> void:
	go_back()
