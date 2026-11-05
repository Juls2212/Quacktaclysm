class_name MainMenu
extends Control
## Main menu: the ruined town after the stars fell, the title painted on a cracked board and broken
## planks nailed to a post for new game, continue, options, credits and quit. Never deletes the save
## file; a new game only replaces it at the next automatic save. Options live in their own settings
## file. Panels open with a splash of ink (visual only: buttons and focus change at once).
## All texts are exported.

@export var title_text: String = "QUACKTACLYSM"
@export var tagline_text: String = "Las estrellas cayeron. Los muertos volvieron. Solo queda una katana."
@export var new_game_text: String = "Nueva partida"
@export var continue_text: String = "Continuar"
@export var options_text: String = "Opciones"
@export var credits_text: String = "Créditos"
@export var quit_text: String = "Salir"
@export var back_text: String = "Volver"
@export var fullscreen_text: String = "Pantalla completa"
@export var volume_text: String = "Volumen general"
@export var music_text: String = "Música"
@export var sfx_text: String = "Efectos"
@export var shake_text: String = "Sacudida de cámara"
@export var controls_text: String = "Controles"
@export_group("Credits")
## Masthead under the credits title, like the front page of the last newspaper.
@export_multiline var credits_body: String = "EDICIÓN ESPECIAL · ÚLTIMO NÚMERO ANTES DEL FIN"
@export var credits_title: String = "QUACKTACLYSM"
@export var credits_dev_line: String = "Desarrollo y sistemas: Juliana Peñafiel"
@export var credits_art_line: String = "Diseño visual, interfaces y escenarios: Laura Escobar"
@export var credits_engine_line: String = "Hecho con Godot 4 y GDScript"
@export var credits_resources_title: String = "Recursos externos"
## One line per external asset (empty for now).
@export var credits_resources: PackedStringArray = PackedStringArray()
@export var credits_thanks_title: String = "Agradecimientos"
@export_multiline var credits_thanks: String = "A quien juegue hasta el final.\nA los patos que no lo lograron."
## Pixels per second the credits roll up.
@export var credits_speed: float = 26.0
@export_group("")
@export var version_text: String = "Versión de desarrollo"
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

@onready var title_label: InkLabel = $Title
@onready var tagline_label: Label = $Tagline
@onready var signs: VBoxContainer = $Signs
@onready var new_game_button: Button = $Signs/NewGameButton
@onready var continue_button: Button = $Signs/ContinueButton
@onready var options_button: Button = $Signs/OptionsButton
@onready var credits_button: Button = $Signs/CreditsButton
@onready var quit_button: Button = $Signs/QuitButton
@onready var message_label: Label = $MessageLabel
@onready var confirm_panel: PanelContainer = $ConfirmPanel
@onready var confirm_label: Label = $ConfirmPanel/Margin/Box/ConfirmLabel
@onready var confirm_yes_button: Button = $ConfirmPanel/Margin/Box/ConfirmYesButton
@onready var confirm_cancel_button: Button = $ConfirmPanel/Margin/Box/ConfirmCancelButton
@onready var options_panel: PanelContainer = $OptionsPanel
@onready var fullscreen_check: CheckButton = $OptionsPanel/Margin/Box/FullscreenCheck
@onready var volume_label: Label = $OptionsPanel/Margin/Box/VolumeRow/VolumeLabel
@onready var volume_slider: HSlider = $OptionsPanel/Margin/Box/VolumeRow/VolumeSlider
@onready var options_back_button: Button = $OptionsPanel/Margin/Box/OptionsBackButton
@onready var credits_panel: PanelContainer = $CreditsPanel
@onready var credits_label: Label = $CreditsPanel/Margin/Box/CreditsLabel
@onready var credits_back_button: Button = $CreditsPanel/Margin/Box/CreditsBackButton
@onready var version_label: Label = $VersionLabel
@onready var music_label: Label = $OptionsPanel/Margin/Box/MusicRow/MusicLabel
@onready var music_slider: HSlider = $OptionsPanel/Margin/Box/MusicRow/MusicSlider
@onready var sfx_label: Label = $OptionsPanel/Margin/Box/SfxRow/SfxLabel
@onready var sfx_slider: HSlider = $OptionsPanel/Margin/Box/SfxRow/SfxSlider
@onready var shake_check: CheckButton = $OptionsPanel/Margin/Box/ShakeCheck
@onready var controls_title: Label = $OptionsPanel/Margin/Box/ControlsTitle
@onready var controls_grid: GridContainer = $OptionsPanel/Margin/Box/ControlsGrid
@onready var credits_scroll: Control = $CreditsPanel/Margin/Box/CreditsScroll
@onready var credits_roll: VBoxContainer = $CreditsPanel/Margin/Box/CreditsScroll/CreditsRoll
@onready var ink_wipe: UiFx = $InkWipe
@onready var title_board: Control = $TitleBoard
@onready var title_crack: Control = $TitleCrack

## Title pieces that step aside while a big panel is open, with their resting positions.
var _header: Array[Control] = []
var _header_home: Array[Vector2] = []
var _header_tween: Tween = null
var _header_hidden: bool = false

var _settings: Dictionary = {}


func _ready() -> void:
	title_label.text = title_text
	tagline_label.text = tagline_text
	new_game_button.text = new_game_text
	continue_button.text = continue_text
	options_button.text = options_text
	credits_button.text = credits_text
	quit_button.text = quit_text
	confirm_label.text = confirm_text
	confirm_yes_button.text = confirm_yes_text
	confirm_cancel_button.text = confirm_cancel_text
	fullscreen_check.text = fullscreen_text
	volume_label.text = volume_text
	options_back_button.text = back_text
	credits_back_button.text = back_text
	credits_label.text = credits_body
	version_label.text = version_text
	music_label.text = music_text
	sfx_label.text = sfx_text
	shake_check.text = shake_text
	controls_title.text = controls_text
	OptionsBoard.fill_controls(controls_grid)
	_build_credits()
	_header = [title_board, title_label, title_crack, tagline_label]
	for piece in _header:
		_header_home.append(piece.position)
	new_game_button.pressed.connect(_on_new_game_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	options_button.pressed.connect(_open_panel.bind(options_panel, fullscreen_check))
	credits_button.pressed.connect(_open_panel.bind(credits_panel, credits_back_button))
	quit_button.pressed.connect(_on_quit_pressed)
	confirm_yes_button.pressed.connect(_on_confirm_yes_pressed)
	confirm_cancel_button.pressed.connect(_on_confirm_cancel_pressed)
	options_back_button.pressed.connect(_on_back_pressed.bind(options_button))
	credits_back_button.pressed.connect(_on_back_pressed.bind(credits_button))
	_settings = GameSettings.load_settings()
	fullscreen_check.button_pressed = _settings["fullscreen"]
	volume_slider.value = _settings["volume"]
	music_slider.value = _settings["music_volume"]
	sfx_slider.value = _settings["sfx_volume"]
	shake_check.button_pressed = _settings["camera_shake"]
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	music_slider.value_changed.connect(_on_setting_changed.bind("music_volume"))
	sfx_slider.value_changed.connect(_on_setting_changed.bind("sfx_volume"))
	shake_check.toggled.connect(_on_setting_changed.bind("camera_shake"))
	GameSettings.apply(_settings)
	_show_main_buttons()
	message_label.text = ""
	_play_intro()


func _process(delta: float) -> void:
	if credits_panel.visible:
		# The front page scrolls up slowly and starts over once it has gone past.
		credits_roll.position.y -= credits_speed * delta
		if credits_roll.position.y < -credits_roll.size.y:
			credits_roll.position.y = credits_scroll.size.y


func _unhandled_input(event: InputEvent) -> void:
	# Esc / back closes an open panel.
	if event.is_action_pressed("ui_cancel"):
		if options_panel.visible:
			_on_back_pressed(options_button)
		elif credits_panel.visible:
			_on_back_pressed(credits_button)
		elif confirm_panel.visible:
			_on_confirm_cancel_pressed()
		else:
			return
		get_viewport().set_input_as_handled()


func _show_main_buttons() -> void:
	for panel: Control in [confirm_panel, options_panel, credits_panel]:
		if panel.visible:
			_splash(panel)
	confirm_panel.visible = false
	options_panel.visible = false
	credits_panel.visible = false
	_show_header(true)
	signs.visible = true
	new_game_button.disabled = false
	continue_button.disabled = not SaveSystem.has_save()
	options_button.disabled = false
	credits_button.disabled = false
	quit_button.disabled = false
	for button: Button in [new_game_button, continue_button, quit_button]:
		if not button.disabled:
			button.grab_focus()
			return


## The title drops in and the signs swing down from the beam: the menu's one entrance.
func _play_intro() -> void:
	var title_home: Vector2 = title_label.position
	title_label.position = title_home + Vector2(0, -60)
	title_label.modulate.a = 0.0
	var signs_home: Vector2 = signs.position
	signs.position = signs_home + Vector2(0, -260)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(title_label, "position", title_home, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(title_label, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(signs, "position", signs_home, 0.8).set_delay(0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _open_panel(panel: PanelContainer, focus: Control) -> void:
	if SceneManager.is_transitioning():
		return
	signs.visible = false
	panel.visible = true
	message_label.text = ""
	if panel == credits_panel:
		credits_roll.position.y = credits_scroll.size.y * 0.35
	# Options and credits are big: the title and tagline lift away so the panel never cuts them.
	_show_header(false)
	_pop_in(panel)
	focus.grab_focus()


func _on_back_pressed(return_focus: Button) -> void:
	_show_main_buttons()
	return_focus.grab_focus()


func _on_fullscreen_toggled(on: bool) -> void:
	_settings["fullscreen"] = on
	GameSettings.apply(_settings)
	GameSettings.save_settings(_settings)


func _on_volume_changed(value: float) -> void:
	_settings["volume"] = value
	GameSettings.apply(_settings)
	GameSettings.save_settings(_settings)


func _on_setting_changed(value: Variant, key: String) -> void:
	_settings[key] = value
	GameSettings.apply(_settings)
	GameSettings.save_settings(_settings)


## A panel lands with a splash of ink and a small bounce. Purely visual: it is already usable.
func _pop_in(panel: Control) -> void:
	_splash(panel)
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.9, 0.9)
	panel.rotation = deg_to_rad(-2.5)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "rotation", 0.0, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Title, board, crack and tagline rise and fade out (or come back). Short, never blocks input.
func _show_header(shown: bool) -> void:
	if _header.is_empty() or shown == not _header_hidden:
		return
	_header_hidden = not shown
	if _header_tween != null and _header_tween.is_valid():
		_header_tween.kill()
	_header_tween = create_tween().set_parallel(true)
	for i in _header.size():
		var piece: Control = _header[i]
		var target: Vector2 = _header_home[i] + (Vector2.ZERO if shown else Vector2(0, -40))
		_header_tween.tween_property(piece, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_header_tween.tween_property(piece, "modulate:a", 1.0 if shown else 0.0, 0.18)


func _splash(panel: Control) -> void:
	ink_wipe.play(panel.position + panel.size * 0.5, maxf(panel.size.x, panel.size.y) * 0.75)


## Front page of the credits: headline, the team, the engine, external resources and thanks.
func _build_credits() -> void:
	for child in credits_roll.get_children():
		child.queue_free()
	var headline := InkLabel.new()
	headline.text = credits_title
	headline.cap_height = 30.0
	headline.fill = Color(0.2, 0.15, 0.12)
	headline.extrude = Color(0.6, 0.55, 0.44)
	credits_roll.add_child(headline)
	for line in [credits_dev_line, credits_art_line, credits_engine_line]:
		_credit_line(line, &"")
	_credit_line(credits_resources_title, &"KeyLabel")
	for line in credits_resources:
		_credit_line(line, &"NoteLabel")
	if credits_resources.is_empty():
		_credit_line("—", &"NoteLabel")
	_credit_line(credits_thanks_title, &"KeyLabel")
	_credit_line(credits_thanks, &"NoteLabel")


func _credit_line(text: String, variation: StringName) -> void:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(credits_scroll.custom_minimum_size.x, 0)
	credits_roll.add_child(label)


func _on_new_game_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	if SaveSystem.has_save() or not GameState.save_blocked_reason.is_empty():
		_set_main_buttons_disabled(true)
		signs.visible = false
		confirm_panel.visible = true
		_pop_in(confirm_panel)
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
	options_button.disabled = disabled
	credits_button.disabled = disabled
	quit_button.disabled = disabled
