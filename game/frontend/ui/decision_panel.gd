class_name DecisionPanel
extends CanvasLayer
## Placeholder Release/Keep panel. Pauses the tree while open; works with ui_left/ui_right/
## ui_accept and the mouse. Emits exactly one `choice_selected` per opening.

signal choice_selected(choice: String)

@export var release_text: String = "Liberar"
@export var keep_text: String = "Conservar"

var _paused_by_panel: bool = false
var _choice_locked: bool = true

@onready var root: Control = $Root
@onready var name_label: Label = $Root/Center/Panel/Margin/Box/NameLabel
@onready var description_label: Label = $Root/Center/Panel/Margin/Box/DescriptionLabel
@onready var release_button: Button = $Root/Center/Panel/Margin/Box/Buttons/ReleaseButton
@onready var keep_button: Button = $Root/Center/Panel/Margin/Box/Buttons/KeepButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	release_button.text = release_text
	keep_button.text = keep_text
	release_button.pressed.connect(_on_choice_pressed.bind(GameState.CHOICE_RELEASED))
	keep_button.pressed.connect(_on_choice_pressed.bind(GameState.CHOICE_KEPT))
	root.visible = false


func _exit_tree() -> void:
	# Never leave the game paused if the panel disappears while open (scene change/reload).
	if _paused_by_panel:
		_paused_by_panel = false
		PauseLock.release(self, get_tree())


func is_open() -> bool:
	return root.visible


func open(data: SoulFragmentData) -> void:
	name_label.text = data.display_name
	description_label.text = data.description
	release_button.text = release_text
	keep_button.text = keep_text
	release_button.disabled = false
	keep_button.disabled = false
	_choice_locked = false
	root.visible = true
	if not get_tree().paused:
		_paused_by_panel = true
		PauseLock.request(self, get_tree())
	release_button.grab_focus()


func close() -> void:
	root.visible = false
	_choice_locked = true
	_paused_by_panel = false
	PauseLock.release(self, get_tree())


func _on_choice_pressed(choice: String) -> void:
	if _choice_locked:
		return
	_choice_locked = true
	release_button.disabled = true
	keep_button.disabled = true
	choice_selected.emit(choice)
