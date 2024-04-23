class_name ActionPanel
extends PanelContainer

signal collect_habits_checkbox_pressed

@export var action_row_scene: PackedScene
@export var action_container: VBoxContainer
@export var refresh_button: Button
@export var collect_button: Button
@export var coins_label: Label
@export var bonus_label: Label
@export var collect_habits_checkbox: CheckBox

var collect_habits: bool:
	get:
		return collect_habits_checkbox.is_pressed()

func _ready() -> void:
	update_footer()
	collect_button.set_disabled(true)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	collect_button.pressed.connect(_on_collect_button_pressed)
	collect_habits_checkbox.pressed.connect(_on_collect_habits_checkbox_pressed)

func refresh_actions() -> void:
	_clear_action_container()
	NotionAPI.update_actions_to_collect()
	await NotionAPI.updated_actions_to_collect
	
	if NotionAPI.actions_to_collect.size() == 0:
		update_footer()
		return
	
	for action in NotionAPI.actions_to_collect:
		var action_row = action_row_scene.instantiate() as ActionRow
		action_container.add_child(action_row)
		action_row.update(action, self)
	
	update_footer()
	
	collect_button.set_disabled(false)

func collect_actions() -> void:
	await NotionAPI.collect_all_actions()
	_clear_action_container()
	refresh_actions()
	collect_button.set_disabled(true)

func update_footer() -> void:
	coins_label.text = "Coins: " + str(NotionAPI.get_total_coins())
	bonus_label.text = "Bonus: " + str(NotionAPI.get_total_bonus())

func _clear_action_container() -> void:
	for child in action_container.get_children():
		child.queue_free()

func _on_refresh_button_pressed() -> void:
	refresh_actions()

func _on_collect_button_pressed() -> void:
	collect_actions()

func _on_collect_habits_checkbox_pressed() -> void:
	NotionAPI.collect_habits = collect_habits_checkbox.is_pressed()
	update_footer()
	collect_habits_checkbox_pressed.emit()
