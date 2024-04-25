class_name XPPanel
extends PanelContainer

@export var xp_row_scene: PackedScene
@export var xp_container: VBoxContainer
@export var refresh_button: Button
@export var collect_button: Button
@export var project_xp_label: Label
@export var objective_xp_label: Label

func _ready() -> void:
	update_footer()
	collect_button.set_disabled(true)
	refresh_button.pressed.connect(_on_refresh_button_pressed)
	collect_button.pressed.connect(_on_collect_button_pressed)

func refresh_xp() -> void:
	_clear_xp_container()
	NotionAPI.update_xp_to_collect()
	await NotionAPI.updated_xp_to_collect
	
	if NotionAPI.projects_to_collect.size() == 0 and NotionAPI.objectives_to_collect.size() == 0:
		update_footer()
		return
	
	for project in NotionAPI.projects_to_collect:
		var xp_row = xp_row_scene.instantiate() as XPRow
		xp_container.add_child(xp_row)
		var xp_item: Dictionary = {
			"name": project["name"],
			"aof": project["aof"],
			"exp": project["exp"],
			"type": "project"
		}
		xp_row.update(xp_item)
	
	for objective in NotionAPI.objectives_to_collect:
		var xp_row = xp_row_scene.instantiate() as XPRow
		xp_container.add_child(xp_row)
		var xp_item: Dictionary = {
			"name": objective["name"],
			"aof": objective["aof"],
			"exp": objective["exp"],
			"type": "objective"
		}
		xp_row.update(xp_item)

	update_footer()
	
	collect_button.set_disabled(false)

func _clear_xp_container() -> void:
	for child in xp_container.get_children():
		child.queue_free()

func _on_refresh_button_pressed() -> void:
	refresh_xp()

func _on_collect_button_pressed() -> void:
	await NotionAPI.collect_all_xp()
	_clear_xp_container()
	refresh_xp()
	collect_button.set_disabled(true)

func update_footer() -> void:
	project_xp_label.text = "Projects: " + str(NotionAPI.get_total_projects_xp()) + " xp"
	objective_xp_label.text = "Objectives: " + str(NotionAPI.get_total_objectives_xp()) + " xp"
