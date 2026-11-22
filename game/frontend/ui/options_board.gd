class_name OptionsBoard
extends PanelContainer
## Options as a cork board with an old sheet of paper pinned on it: fullscreen, master / music /
## effects volume, camera shake, and a button to the editable controls page (ControlsEditor). Values go
## through GameSettings (user://settings.cfg), never the save game. Builds its own rows, so it can
## be dropped into any menu (the pause menu uses it). Esc or "Volver" emits `closed`.

signal closed

## Group of the level's ProfilePresenter (a literal: referencing its class from here makes a script cycle).
const PRESENTER_GROUP: StringName = &"profile_presenter"
const PRESENTATION_PATH: String = "res://frontend/presentation/default_profile_presentation.tres"

@export var title_text: String = "Opciones"
@export var fullscreen_text: String = "Pantalla completa"
@export var volume_text: String = "Volumen general"
@export var music_text: String = "Música"
@export var sfx_text: String = "Efectos"
@export var shake_text: String = "Sacudida de cámara"
@export var back_text: String = "Volver"

var fullscreen_check: CheckButton
var volume_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var shake_check: CheckButton
var corruption_check: CheckButton
var back_button: Button
var controls_button: Button
## The editable controls page; it takes the place of the settings while it is open.
var controls_editor: ControlsEditor = null

var _settings_box: VBoxContainer

var _settings: Dictionary = {}


func _ready() -> void:
	theme_type_variation = &"CorkPanel"
	var decor := UiFx.new()
	decor.mode = UiFx.Mode.CORK
	add_child(decor)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_settings_box = box
	var title := InkLabel.new()
	title.text = title_text
	title.cap_height = 30.0
	box.add_child(title)
	fullscreen_check = CheckButton.new()
	fullscreen_check.text = fullscreen_text
	box.add_child(fullscreen_check)
	volume_slider = _slider_row(box, volume_text)
	music_slider = _slider_row(box, music_text)
	sfx_slider = _slider_row(box, sfx_text)
	shake_check = CheckButton.new()
	shake_check.text = shake_text
	box.add_child(shake_check)
	corruption_check = CheckButton.new()
	corruption_check.text = (load(PRESENTATION_PATH) as ProfilePresentation).toggle_text
	box.add_child(corruption_check)
	controls_button = Button.new()
	controls_button.text = (load(ControlsConfig.CATALOG_PATH) as ControlsCatalog).open_button_text
	controls_button.custom_minimum_size = Vector2(240, 40)
	controls_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(controls_button)
	controls_editor = ControlsEditor.new()
	add_child(controls_editor)
	controls_button.pressed.connect(_open_controls)
	controls_editor.closed.connect(_close_controls)
	var back := SignButton.new()
	back.ropes = false
	back.look = SignButton.Look.CARDBOARD
	back.cap_height = 20.0
	back.tilt = -1.0
	back_button = back
	back_button.custom_minimum_size = Vector2(220, 52)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.text = back_text
	box.add_child(back_button)
	_settings = GameSettings.load_settings()
	fullscreen_check.button_pressed = _settings["fullscreen"]
	volume_slider.value = _settings["volume"]
	music_slider.value = _settings["music_volume"]
	sfx_slider.value = _settings["sfx_volume"]
	shake_check.button_pressed = _settings["camera_shake"]
	corruption_check.button_pressed = _settings["corruption_effects"]
	fullscreen_check.toggled.connect(_store.bind("fullscreen"))
	volume_slider.value_changed.connect(_store.bind("volume"))
	music_slider.value_changed.connect(_store.bind("music_volume"))
	sfx_slider.value_changed.connect(_store.bind("sfx_volume"))
	shake_check.toggled.connect(_store.bind("camera_shake"))
	corruption_check.toggled.connect(_store.bind("corruption_effects"))
	back_button.pressed.connect(close)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if controls_editor != null and controls_editor.is_open():
		return
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func _open_controls() -> void:
	_settings_box.visible = false
	controls_editor.open()


func _close_controls() -> void:
	_settings_box.visible = true
	controls_button.grab_focus()


func open() -> void:
	_settings = GameSettings.load_settings()
	_settings_box.visible = true
	controls_editor.visible = false
	visible = true
	fullscreen_check.grab_focus()


func close() -> void:
	if not visible:
		return
	if controls_editor.is_open():
		controls_editor.close()
	visible = false
	closed.emit()


func _slider_row(box: VBoxContainer, label_text: String) -> HSlider:
	var row := HBoxContainer.new()
	box.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(170, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	return slider


func _store(value: Variant, key: String) -> void:
	_settings[key] = value
	GameSettings.apply(_settings)
	GameSettings.save_settings(_settings)
	# A level in the background re-reads the corruption effects option (no polling).
	get_tree().call_group(PRESENTER_GROUP, "refresh_settings")
