class_name Companion
extends Resource
# Terra Battle companion: a support creature/item equipped by a character.
# Grants flat stats (wiki damage-calc order: "Companion stats — e.g. Earth
# Sword at max level gives +80 ATK") and may cast its skill during pincers the
# owner participates in. While the Powered Point boost is active, the skill
# frequency is treated as if the companion were at max level (wiki rule).

# Localizable string
@export var companion_name: String = ""

# Flat stat grants (treated as the companion's max-level values)
@export var health_bonus: int = 0
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var spiritual_attack_bonus: int = 0
@export var spiritual_defense_bonus: int = 0

# Skill the companion may cast when the owner activates skills in a pincer
@export var skill: Resource = null

# Chance per pincer that the skill fires
@export var frequency: float = 0.3 # (float, 0, 1, 0.05)

# Frequency while the Powered Point boost is active (max-level treatment)
@export var max_frequency: float = 0.8 # (float, 0, 1, 0.05)

# Coin price to acquire in the market. 0 means not sold (owned by default, e.g.
# companions that come baked onto a starting hero).
@export var shop_price: int = 0
