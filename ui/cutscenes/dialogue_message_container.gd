extends HBoxContainer


# Speaker (translation key OR re-skin display name) -> portrait token.
# TODO: Use a resource. The Water Margin re-skin authors banter with the
# re-skin display name as the speaker (see tools/wire_reskin_into_game.py),
# so the display names below map back to the original roster art. Speakers
# without an entry (the "(new recruit)" heroes that have no token art yet)
# render with the blank unit square.
const _ICONS: Dictionary = {
	# Original roster translation keys (used by non-reskinned dialogues)
	"BAHL": "res://assets/terra/tokens/bahl_token.png",
	"GRACE": "res://assets/terra/tokens/grace_token.png",
	"KUSCAH": "res://assets/terra/tokens/kuscah_token.png",
	"SHBERDAN": "res://assets/terra/tokens/shberdan_token.png",
	"DAIANA": "res://assets/terra/tokens/daiana_token.png",
	"MACURI": "res://assets/terra/tokens/macuri_token.png",
	# Water Margin re-skin display names -> original roster tokens
	"Gan Jiang": "res://assets/terra/tokens/bahl_token.png",
	"Mo Ye": "res://assets/terra/tokens/grace_token.png",
	"Saen": "res://assets/terra/tokens/kuscah_token.png",
	"Jiao": "res://assets/terra/tokens/shberdan_token.png",
	"Dragon in the Clouds": "res://assets/terra/tokens/daiana_token.png",
	"Mu": "res://assets/terra/tokens/macuri_token.png",
	"the Tattooed Monk": "res://assets/terra/tokens/gegonago_token.png",
	"the Skilled Doctor": "res://assets/terra/tokens/amimari_token.png",
	"Timely Rain": "res://assets/terra/tokens/mizell_token.png",
	"Black Whirlwind": "res://assets/terra/tokens/zan_token.png",
	"the Pilgrim": "res://assets/terra/tokens/korin_token.png",
	"Ten Feet of Steel": "res://assets/terra/tokens/samupi_token.png",
	"Jade Unicorn": "res://assets/terra/tokens/bagunar_token.png",
	"Blue-Faced Beast": "res://assets/terra/tokens/burbaba_token.png",
	"Fiery Thunderbolt": "res://assets/terra/tokens/maralme_token.png",
	"Twin Rods": "res://assets/terra/tokens/nakupi_token.png",
	"the Witch": "res://assets/terra/tokens/amazora_token.png",
	"Panther Head": "res://assets/terra/tokens/kem_token.png",
	"the Nine-Dragoned": "res://assets/terra/tokens/zenzoze_token.png",
	"the Living Death-God": "res://assets/terra/tokens/unasag_token.png",
	"Lord of the Beautiful Beard": "res://assets/terra/tokens/raprow_token.png",
	"Little Li Guang": "res://assets/terra/tokens/harold_token.png",
	"the Wanderer": "res://assets/terra/tokens/iskar_token.png",
	"Featherless Arrow": "res://assets/terra/tokens/manmer_token.png",
	"Lan": "res://assets/terra/tokens/lan_token.png",
	"the Wisdom Star": "res://assets/terra/tokens/eileen_token.png",
	"Marvelous Traveler": "res://assets/terra/tokens/sorman_token.png",
	"White Streak in the Waves": "res://assets/terra/tokens/gigojago_token.png"
}

signal text_fully_visible

@export var new_character_every_x_seconds: float = 0

@export var dim_color: Color

var _accumulated_time_seconds: float = 0

@onready var _name_label := $VBoxContainer/NameLabel
@onready var _message_label := $MarginContainer/MarginContainer/MessageLabel
@onready var _character_icon := $VBoxContainer/PortraitFrame/Portrait
@onready var _nine_patch := $MarginContainer/NinePatchRect


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	_slowly_make_text_visible(delta, _message_label)


# texture
# name
# nine patch texture ?
# Make a generic one and make character specific ones
# Dialogue: who says it, expression ?, and what they are saying
func initialize(dialogue_message) -> void:
	var speaker: String = dialogue_message.speaker
	
	_name_label.text = tr(speaker)
	_message_label.text = tr(dialogue_message.line)
	
	if _ICONS.has(speaker):
		_character_icon.texture = load(_ICONS[speaker])
	
	_message_label.visible_ratio = 0
	_accumulated_time_seconds = 0
	
	$DialogueAudio.play()


func start_showing_text() -> void:
	if _message_label.visible_ratio < 1.0:
		set_process(true)


func _slowly_make_text_visible(delta: float, label: Label) -> void:
	_accumulated_time_seconds += delta
	
	if _accumulated_time_seconds > new_character_every_x_seconds:
		label.visible_characters += 1
		_accumulated_time_seconds = 0
	
	if label.visible_ratio >= 1.0:
		set_text_fully_visible()


func is_text_fully_visible() -> bool:
	return is_equal_approx(_message_label.visible_ratio, 1.0)


func set_text_fully_visible() -> void:
	_message_label.visible_ratio = 1
	
	emit_signal("text_fully_visible")
	
	set_process(false)


func dim_text() -> void:
	modulate = dim_color
