class_name DecisionPanel
extends CanvasLayer
## Release/Keep panel for a soul fragment. Pauses the tree while open; works with ui_left/ui_right/
## ui_accept and the mouse. Emits exactly one `choice_selected` per opening.
## Look: the game under a night-blue veil and a vignette; a dark burnt-paper card drops in with a
## small bounce, the fragment's gem glowing on top (halo tinted by its data), the name and the
## description, a blue LIBERAR sign and a red CONSERVAR sign with a short line under each.

signal choice_selected(choice: String)

@export var release_text: String = "Liberar"
@export var keep_text: String = "Conservar"
@export var release_caption: String = "su alma vuelve al cielo"
@export var keep_caption: String = "su poder será tuyo"

var _paused_by_panel: bool = false
var _choice_locked: bool = true

@onready var root: Control = $Root
@onready var name_label: Label = $Root/Center/Panel/Margin/Box/NameLabel
@onready var description_label: Label = $Root/Center/Panel/Margin/Box/DescriptionLabel
@onready var release_button: Button = $Root/Center/Panel/Margin/Box/Buttons/ReleaseButton
@onready var keep_button: Button = $Root/Center/Panel/Margin/Box/Buttons/KeepButton
@onready var gem: DecisionDecor = $Root/Center/Panel/Margin/Box/Gem
@onready var center: Control = $Root/Center


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	release_button.text = release_text
	keep_button.text = keep_text
	($Root/Center/Panel/Margin/Box/Captions/ReleaseCaption as Label).text = release_caption
	($Root/Center/Panel/Margin/Box/Captions/KeepCaption as Label).text = keep_caption
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
	gem.tint = data.tint
	_drop_in()


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


## The card drops in with a short fall and a small bounce. Visual only: it is usable at once.
func _drop_in() -> void:
	# Both offsets move together so the full-screen container keeps its size.
	var tween := create_tween()
	tween.tween_method(_set_drop, -70.0, 0.0, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _set_drop(y: float) -> void:
	center.offset_top = y
	center.offset_bottom = y
