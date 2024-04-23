class_name XPRow
extends MarginContainer

@export var name_label: Label
@export var type_label: Label
@export var aof_label: Label
@export var xp_label: Label

func update(xp_item: Dictionary) -> void:
	name_label.text = xp_item["name"]
	type_label.text = xp_item["type"]
	aof_label.text = xp_item["aof"]
	xp_label.text = str(xp_item["exp"])
