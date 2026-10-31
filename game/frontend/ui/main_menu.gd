class_name MainMenu
extends Control
## Placeholder main menu: new game, continue, quit. Never deletes the save file; a new game only
## replaces it at the next automatic save. All texts are exported placeholders.

@export var title_text: String = "Quacktaclysm"
@export var new_game_text: String = "Nueva partida"
@export var continue_text: String = "Continuar"
@export var quit_text: String = "Salir"
@export var confirm_text: String = "Ya existe una partida guardada. Se reemplazará en el próximo guardado automático."
@export var confirm_yes_text: String = "Sí, empezar de nuevo"
@export var confirm_cancel_text: String = "Cancelar"
@export var recovered_note: String = "Partida recuperada desde la copia de seguridad."
@export var message_no_save: String = "No hay ninguna partida guardada."
@export var message_corrupt: String = "La partida guardada está dañada y no se puede cargar."
@export var message_unsupported: String = "La partida guardada es de una versión más nueva del juego."
@export var message_invalid: String = "La partida guardada no es válida."
@export var message_scene_failed: String = "No se pudo abrir la escena."
@export var message_ending_failed: String = "No se pudo abrir el final; se retoma el último nivel."
@export var ending_scene_id: String = "ending"

@onready var title_label: Label = $Center/Box/TitleLabel
@onready var new_game_button: Button = $Center/Box/NewGameButton
@onready var continue_button: Button = $Center/Box/ContinueButton
@onready var quit_button: Button = $Center/Box/QuitButton
@onready var message_label: Label = $Center/Box/MessageLabel
@onready var confirm_panel: PanelContainer = $Center/Box/ConfirmPanel
@onready var confirm_label: Label = $Center/Box/ConfirmPanel/Margin/Box/ConfirmLabel
@onready var confirm_yes_button: Button = $Center/Box/ConfirmPanel/Margin/Box/ConfirmYesButton
@onready var confirm_cancel_button: Button = $Center/Box/ConfirmPanel/Margin/Box/ConfirmCancelButton


func _ready() -> void:
	title_label.text = title_text
	new_game_button.text = new_game_text
	continue_button.text = continue_text
	quit_button.text = quit_text
	confirm_label.text = confirm_text
	confirm_yes_button.text = confirm_yes_text
	confirm_cancel_button.text = confirm_cancel_text
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	confirm_yes_button.pressed.connect(_on_confirm_yes_pressed)
	confirm_cancel_button.pressed.connect(_on_confirm_cancel_pressed)
	_show_main_buttons()
	message_label.text = ""


func _show_main_buttons() -> void:
	confirm_panel.visible = false
	new_game_button.disabled = false
	continue_button.disabled = not SaveSystem.has_save()
	quit_button.disabled = false
	for button: Button in [new_game_button, continue_button, quit_button]:
		if not button.disabled:
			button.grab_focus()
			return


func _on_new_game_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	if SaveSystem.has_save() or not GameState.save_blocked_reason.is_empty():
		_set_main_buttons_disabled(true)
		confirm_panel.visible = true
		confirm_yes_button.disabled = false
		confirm_cancel_button.disabled = false
		confirm_cancel_button.grab_focus()
		return
	_start_new_game()


func _on_confirm_yes_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	_start_new_game()


func _on_confirm_cancel_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	_show_main_buttons()


func _start_new_game() -> void:
	GameState.start_new_game()
	var registry: SceneRegistry = SceneManager.get_registry()
	var scene_id: String = registry.new_game_scene_id if registry != null else ""
	if SceneManager.go_to(scene_id):
		_set_main_buttons_disabled(true)
		confirm_yes_button.disabled = true
		confirm_cancel_button.disabled = true
	else:
		_show_main_buttons()
		message_label.text = message_scene_failed


func _on_continue_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	var result: Dictionary = GameState.load_from_disk()
	var status: String = result["status"]
	match status:
		SaveSystem.STATUS_OK, SaveSystem.STATUS_RECOVERED:
			var note: String = recovered_note if status == SaveSystem.STATUS_RECOVERED else ""
			var opened: bool = false
			if GameState.is_game_completed():
				opened = SceneManager.go_to(ending_scene_id)
				if not opened:
					note = (note + " " + message_ending_failed).strip_edges()
			if not opened:
				opened = SceneManager.go_to_level(GameState.current_level)
			if opened:
				message_label.text = note
				_set_main_buttons_disabled(true)
			else:
				message_label.text = (note + " " + message_scene_failed).strip_edges()
		SaveSystem.STATUS_NO_SAVE:
			message_label.text = message_no_save
		SaveSystem.STATUS_CORRUPT:
			message_label.text = message_corrupt
		SaveSystem.STATUS_UNSUPPORTED:
			message_label.text = message_unsupported
		_:
			message_label.text = message_invalid
	if not SceneManager.is_transitioning():
		continue_button.disabled = not SaveSystem.has_save()


func _on_quit_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	SceneManager.quit_game()


func _set_main_buttons_disabled(disabled: bool) -> void:
	new_game_button.disabled = disabled
	continue_button.disabled = disabled
	quit_button.disabled = disabled
