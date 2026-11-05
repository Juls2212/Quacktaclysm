class_name OptionsBoard
extends PanelContainer
## Options as a cork board with an old sheet of paper pinned on it: fullscreen, master / music /
## effects volume, camera shake, and the controls read from the InputMap (read only). Values go
## through GameSettings (user://settings.cfg), never the save game. Builds its own rows, so it can
## be dropped into any menu (the pause menu uses it). Esc or "Volver" emits `closed`.

signal closed

@export var title_text: String = "Opciones"
@export var fullscreen_text: String = "Pantalla completa"
@export var volume_text: String = "Volumen general"
@export var music_text: String = "Música"
@export var sfx_text: String = "Efectos"
@export var shake_text: String = "Sacudida de cámara"
@export var controls_text: String = "Controles"
@export var back_text: String = "Volver"

## InputMap action(s) -> label shown in the controls list, in display order.
const CONTROLS: Array = [
	[["move_left", "move_right"], "Mover"],
	[["jump"], "Saltar"],
	[["dash"], "Esquivar (dash)"],
	[["attack"], "Ataque"],
	[["wave"], "Onda de espada"],
	[["heavy_attack"], "Golpe pesado"],
	[["pause"], "Pausa"],
]

var fullscreen_check: CheckButton
var volume_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var shake_check: CheckButton
var back_button: Button

var _settings: Dictionary = {}


func _ready() -> void:
	theme_type_variation = &"CorkPanel"
	var decor := UiFx.new()
	decor.mode = UiFx.Mode.CORK
	add_child(decor)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
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
	var controls_title := Label.new()
	controls_title.text = controls_text
	controls_title.theme_type_variation = &"KeyLabel"
	box.add_child(controls_title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	box.add_child(grid)
	fill_controls(grid)
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
	fullscreen_check.toggled.connect(_store.bind("fullscreen"))
	volume_slider.value_changed.connect(_store.bind("volume"))
	music_slider.value_changed.connect(_store.bind("music_volume"))
	sfx_slider.value_changed.connect(_store.bind("sfx_volume"))
	shake_check.toggled.connect(_store.bind("camera_shake"))
	back_button.pressed.connect(close)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return visible


func open() -> void:
	_settings = GameSettings.load_settings()
	visible = true
	fullscreen_check.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


## Fills a 2-column grid (action, keys) from the InputMap.
static func fill_controls(grid: GridContainer) -> void:
	for entry in CONTROLS:
		var action_label := Label.new()
		action_label.text = String(entry[1])
		action_label.theme_type_variation = &"NoteLabel"
		grid.add_child(action_label)
		var keys := Label.new()
		keys.text = keys_text(entry[0])
		keys.theme_type_variation = &"KeyLabel"
		grid.add_child(keys)


## Human-readable keys bound to `actions` (keyboard and mouse), e.g. "A / D".
static func keys_text(actions: Array) -> String:
	var parts: PackedStringArray = []
	for action in actions:
		if not InputMap.has_action(StringName(action)):
			continue
		var names: PackedStringArray = []
		for ev in InputMap.action_get_events(StringName(action)):
			var key := ev as InputEventKey
			if key != null:
				var code: Key = key.physical_keycode if key.keycode == KEY_NONE else key.keycode
				names.append(OS.get_keycode_string(code))
				continue
			var mouse := ev as InputEventMouseButton
			if mouse != null:
				match mouse.button_index:
					MOUSE_BUTTON_LEFT:
						names.append("Clic izq.")
					MOUSE_BUTTON_RIGHT:
						names.append("Clic der.")
					MOUSE_BUTTON_MIDDLE:
						names.append("Clic central")
		if not names.is_empty():
			parts.append(" o ".join(names.slice(0, 2)))
	return " / ".join(parts) if not parts.is_empty() else "—"


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
