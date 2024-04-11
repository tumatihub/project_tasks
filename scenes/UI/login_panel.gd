class_name LoginPanel
extends PanelContainer

@export var login_button: Button
@export var secret_input: LineEdit

func _ready() -> void:
	NotionAPI.logged_in.connect(_on_logged_in)
	login_button.set_disabled(NotionAPI.is_logged_in)

func login(secret: String) -> void:
	NotionAPI.login(secret)

func _on_logged_in() -> void:
	login_button.set_disabled(true)

func _on_login_button_pressed() -> void:
	if secret_input.text.is_empty():
		return
	login(secret_input.text)
