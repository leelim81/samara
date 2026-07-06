extends NinePatchRect

@onready var texture_rect: TextureRect = $MarginContainer/TextureRect
@onready var glow_texture_rect: TextureRect = $GlowTextureRect
@onready var weapon_type_texture_rect: TextureRect = $WeaponTypeTexture


@onready var _icon_background: TextureRect = $IconBackground


func initialize(job: Job, is_draggable: bool = false) -> void:
	if not is_draggable:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

	texture_rect.texture = job.portrait
	weapon_type_texture_rect.texture = load(Enums.WEAPON_TYPE_TEXTURES[job.stats.weapon_type])

	# The dark backing tile and the portrait both fill the framed square exactly
	# (the legacy scene left them at native size, so the 98px backing spilled a
	# faint second rounded rectangle past the 84px jade frame). Pin the Godot 4
	# stretch semantics here so they always match the border.
	_icon_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_background.stretch_mode = TextureRect.STRETCH_SCALE

	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED


func show_glow() -> void:
	glow_texture_rect.show()


func hide_glow() -> void:
	glow_texture_rect.hide()
