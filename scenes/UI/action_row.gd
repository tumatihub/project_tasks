class_name ActionRow
extends MarginContainer

@export var name_label: Label
@export var type_label: Label
@export var coins_label: Label
@export var hide_color: Color
@export var hbox: HBoxContainer

func update(action: Dictionary, action_panel: ActionPanel) -> void:
	name_label.text = action["name"]
	type_label.text = action["type"]
	coins_label.text = str(action["coins"])
	
	if action["type"] == NotionAPI.ACTION_TYPE_HABIT and !NotionAPI.collect_habits:
		hbox.modulate = hide_color
	action_panel.collect_habits_checkbox_pressed.connect(_on_collect_habits_checkbox_pressed)

func _on_collect_habits_checkbox_pressed() -> void:
	if type_label.text == NotionAPI.ACTION_TYPE_HABIT and !NotionAPI.collect_habits:
		hbox.modulate = hide_color
	else:
		hbox.modulate = Color.WHITE
