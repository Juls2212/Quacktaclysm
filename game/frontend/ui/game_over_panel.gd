class_name GameOverPanel
extends CanvasLayer
## Placeholder Game Over panel. Holds the PauseLock while open and emits exactly one of
## `retry_requested` / `menu_requested` per opening (buttons lock after the first press).

signal retry_requested
signal menu_requested

@export var title_text: String = "Has caído"
@export var retry_text: String = "Reintentar"
@export var main_menu_text: String = "Menú principal"

var _holds_lock: bool = false
var _choice_locked: bool = true

@onready var root: Control = $Root
@onready var title_label: Label = $Root/Center/Panel/Margin/Box/TitleLabel
@onready var retry_button: Button = $Root/Center/Panel/Margin/Box/RetryButton
@onready var main_menu_button: Button = $Root/Center/Panel/Margin/Box/MainMenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	title_label.text = title_text
	retry_button.text = retry_text
	main_menu_button.text = main_menu_text
	retry_button.pressed.connect(_on_choice_pressed.bind(retry_requested))
	main_menu_button.pressed.connect(_on_choice_pressed.bind(menu_requested))
	root.visible = false


func _exit_tree() -> void:
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func is_open() -> bool:
	return root.visible


func open() -> void:
	if root.visible:
		return
	root.visible = true
	_choice_locked = false
	retry_button.disabled = false
	main_menu_button.disabled = false
	_holds_lock = true
	PauseLock.request(self, get_tree())
	retry_button.grab_focus()


func close() -> void:
	root.visible = false
	_choice_locked = true
	if _holds_lock:
		_holds_lock = false
		PauseLock.release(self, get_tree())


func _on_choice_pressed(choice_signal: Signal) -> void:
	if _choice_locked:
		return
	_choice_locked = true
	retry_button.disabled = true
	main_menu_button.disabled = true
	choice_signal.emit()
