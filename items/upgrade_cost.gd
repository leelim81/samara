class_name UpgradeCost
extends Resource
# The price of an upgrade: coins plus a set of materials. Used by job changes,
# metamorphosis, and companion acquisition so pricing stays data-driven.

@export var coin_cost: int = 0

# item id -> required count.
@export var materials: Dictionary = {}
