class_name ActionRow
extends MarginContainer

@export var name_label: Label
@export var type_label: Label
@export var coins_label: Label

func update(action: Dictionary) -> void:
	name_label.text = action["name"]
	type_label.text = action["type"]
	coins_label.text = str(action["coins"])
