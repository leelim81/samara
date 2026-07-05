class_name ItemRegistry
extends Resource
# Registry of every item, and the battle drop pool. See items/material_list.tres.
# (Named ItemRegistry rather than ItemList to avoid Godot's built-in ItemList.)

@export var items: Array = [] # (Array, Resource)


func get_by_id(item_id: String) -> Item:
	for item in items:
		if item.id == item_id:
			return item

	return null


func materials() -> Array:
	var result := []

	for item in items:
		if item.category == Enums.ItemCategory.MATERIAL:
			result.append(item)

	return result
