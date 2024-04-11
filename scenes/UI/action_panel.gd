class_name ActionPanel
extends PanelContainer

@export var action_row_scene: PackedScene
@export var action_container: VBoxContainer
@export var refresh_button: Button
@export var collect_button: Button
@export var coins_label: Label
@export var bonus_label: Label

func _ready() -> void:
	coins_label.text = ""
	bonus_label.text = ""
	collect_button.set_disabled(true)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	collect_button.pressed.connect(_on_collect_button_pressed)

func refresh_actions() -> void:
	_clear_action_container()
	NotionAPI.update_actions_to_collect()
	await NotionAPI.updated_actions_to_collect
	
	if NotionAPI.actions_to_collect.size() == 0:
		return
	
	for action in NotionAPI.actions_to_collect:
		var action_row = action_row_scene.instantiate() as ActionRow
		action_container.add_child(action_row)
		action_row.update(action)
	
	coins_label.text = "Coins: " + str(NotionAPI.get_total_coins())
	bonus_label.text = "Bonus: " + str(NotionAPI.get_total_bonus())
	
	collect_button.set_disabled(false)

func collect_actions() -> void:
	await NotionAPI.collect_all_actions()
	_clear_action_container()
	coins_label.text = ""
	bonus_label.text = ""
	collect_button.set_disabled(true)

func _clear_action_container() -> void:
	for child in action_container.get_children():
		child.queue_free()

func _on_refresh_button_pressed() -> void:
	refresh_actions()

func _on_collect_button_pressed() -> void:
	collect_actions()
