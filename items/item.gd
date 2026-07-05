class_name Item
extends Resource
# A material or consumable the player can hold. Materials drop from battles and
# are spent on upgrades in the shop (training, job changes, metamorphosis). The
# full set of items lives in items/material_list.tres, which also acts as the
# battle drop pool.

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export var icon: Texture2D = null
@export var category: int = Enums.ItemCategory.MATERIAL # (Enums.ItemCategory)

# 1 (common) .. 5 (rare). Drives the tint of the rarity pip and sort order.
@export var rarity: int = 1 # (int, 1, 5, 1)
@export var sort_order: int = 0

# Battle drop tuning: the item can drop from enemies at or above drop_min_level,
# chosen by drop_weight among all eligible items.
@export var drop_min_level: int = 1
@export var drop_weight: float = 1.0
