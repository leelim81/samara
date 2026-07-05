extends Button
# One row in the bestiary list. Discovered enemies show their token, name, and a
# state marker, and open the shared detail page when pressed. Undiscovered ones
# render as a dim silhouette with a "???" name and are disabled (no action).

signal selected(path)

@onready var _token: TextureRect = $Margin/H/Token
@onready var _name_label: Label = $Margin/H/Body/NameLabel
@onready var _state_label: Label = $Margin/H/Body/StateLabel
@onready var _weapon_icon: TextureRect = $Margin/H/WeaponIcon

const _NAME_COLOR: Color = Color(0.863, 0.878, 0.894)
const _LOCKED_NAME_COLOR: Color = Color(0.5, 0.54, 0.6)
const _DEFEATED_COLOR: Color = Color(0.85, 0.72, 0.42)
const _SEEN_COLOR: Color = Color(0.6, 0.64, 0.667)
const _SILHOUETTE: Color = Color(0.05, 0.055, 0.075, 0.92)

var _path: String = ""


func configure(entry: Dictionary, state: int) -> void:
	_path = String(entry.get("path", ""))

	var token_path: String = String(entry.get("token_path", ""))
	_token.texture = load(token_path) if token_path != "" else null

	if state >= SaveData.ENCOUNTER_SEEN:
		_show_discovered(entry, state)
	else:
		_show_undiscovered()


func _show_discovered(entry: Dictionary, state: int) -> void:
	disabled = false
	modulate = Color(1, 1, 1, 1)
	_token.modulate = Color(1, 1, 1, 1)

	_name_label.text = tr(String(entry.get("name_key", "")))
	_name_label.add_theme_color_override("font_color", _NAME_COLOR)

	var defeated: bool = state >= SaveData.ENCOUNTER_DEFEATED
	_state_label.text = tr("BESTIARY_DEFEATED") if defeated else tr("BESTIARY_ENCOUNTERED")
	_state_label.add_theme_color_override("font_color", _DEFEATED_COLOR if defeated else _SEEN_COLOR)

	_weapon_icon.visible = true
	_weapon_icon.texture = load(Enums.WEAPON_TYPE_TEXTURES[int(entry.get("weapon_type", 0))])


func _show_undiscovered() -> void:
	disabled = true
	modulate = Color(1, 1, 1, 0.55)
	_token.modulate = _SILHOUETTE

	_name_label.text = "???"
	_name_label.add_theme_color_override("font_color", _LOCKED_NAME_COLOR)
	_state_label.text = ""
	_weapon_icon.visible = false


func _on_pressed() -> void:
	$PressedAudio.play()

	if _path != "":
		emit_signal("selected", _path)
