class_name LoginPanel
extends PanelContainer

@export var login_button: Button
@export var logout_button: Button
@export var secret_input: LineEdit
@export var loading_icon: Control

func _ready() -> void:
	NotionAPI.logged_in.connect(_on_logged_in)
	NotionAPI.cant_log_in.connect(_on_cant_log_in)
	login_button.set_disabled(NotionAPI.is_logged_in)
	if not NotionAPI.header_secret.is_empty():
		secret_input.text = NotionAPI.header_secret
		login(NotionAPI.header_secret)

func login(secret: String) -> void:
	loading_icon.visible = true
	login_button.set_disabled(true)
	NotionAPI.login(secret)

func _on_logged_in() -> void:
	login_button.set_disabled(true)
	logout_button.set_disabled(false)
	loading_icon.visible = false

func _on_login_button_pressed() -> void:
	if secret_input.text.is_empty():
		return
	login(secret_input.text)

func _on_cant_log_in() -> void:
	login_button.set_disabled(false)
	logout_button.set_disabled(true)
	loading_icon.visible = false
	secret_input.text = ""

func _on_logout_button_pressed() -> void:
	NotionAPI.logout()
	login_button.set_disabled(false)
	logout_button.set_disabled(true)
	secret_input.text = ""
