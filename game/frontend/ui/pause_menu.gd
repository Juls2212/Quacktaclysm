class_name PauseMenu
extends CanvasLayer
## Placeholder pause menu. Opens on the `pause` action through PauseLock and closes itself on
## `pause` or "Continuar". Does not open if another system already holds the lock (decision
## panel, game over), a scene transition is running, or the optional `player` is dead.
## "Menú principal" does not save: progress since the last autosave is lost.

@export var player: Player
@export var title_text: String = "Pausa"
@export var resume_text: String = "Continuar"
@export var main_menu_text: String = "Menú principal"

var _holds_lock: bool = false

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/Box/TitleLabel
@onready var resume_button: Button = $Root/Center/Panel/Margin/Box/ResumeButton
@onready var main_menu_button: Button = $Root/Center/Panel/Margin/Box/MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	title_label.text = title_text
	resume_button.text = resume_text
	main_menu_button.text = main_menu_text
	resume_button.pressed.connect(close_menu)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	root.visible = false


func _exit_tree() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause") or event.is_echo():
		return
	if _holds_lock:
		close_menu()
	else:
		open_menu()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _holds_lock


func can_open() -> bool:
	if _holds_lock or PauseLock.is_locked() or SceneManager.is_transitioning():
		return false
	return not (player != null and is_instance_valid(player) and player.is_dead)


## Returns false (and does nothing) when the rules above forbid opening.
func open_menu() -> bool:
	if not can_open():
		return false
	_holds_lock = true
	PauseLock.request(self, get_tree())
	root.visible = true
	resume_button.grab_focus()
	return true


func close_menu() -> void:
	if not _holds_lock:
		return
	_holds_lock = false
	root.visible = false
	PauseLock.release(self, get_tree())


func _on_main_menu_pressed() -> void:
	if not _holds_lock or SceneManager.is_transitioning():
		return
	close_menu()
	SceneManager.go_to_main_menu()
