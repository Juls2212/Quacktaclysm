class_name MainMenu
extends Control
## Main menu: the ruined town after the stars fell, the title painted on a cracked board and broken
## planks nailed to a post for new game, continue, options, credits and quit. Never deletes the save
## file; a new game only replaces it at the next automatic save. Options live in their own settings
## file. Panels open with a splash of ink (visual only: buttons and focus change at once).
## All texts are exported.

@export var title_text: String = "QUACKTACLYSM"
## No longer shown under the title (it became the opening below); kept for the label.
@export var tagline_text: String = "Las estrellas cayeron. Los muertos volvieron. Solo queda una katana."
## Opening shown the first time the menu opens in a run: one line after another, typed out.
@export var intro_lines: PackedStringArray = PackedStringArray(["Las estrellas cayeron.", "Los muertos volvieron.", "Solo queda una katana."])
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
## The credits (names, technology, audio, thanks) live in ONE resource shared with the end of the game (Phase 15t).
@export var credits_content: CreditsContent
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
## "Efectos de corrupción" toggle; built in code next to the camera shake one.
var corruption_check: CheckButton
var ai_check: CheckButton
var blood_check: CheckButton
@onready var controls_button: Button = $OptionsPanel/Margin/Box/ControlsButton
@onready var options_box: VBoxContainer = $OptionsPanel/Margin/Box
## The editable controls page; it takes the place of the options while it is open.
var controls_editor: ControlsEditor = null
@onready var credits_scroll: Control = $CreditsPanel/Margin/Box/CreditsScroll
@onready var credits_roll: VBoxContainer = $CreditsPanel/Margin/Box/CreditsScroll/CreditsRoll
@onready var ink_wipe: UiFx = $InkWipe
@onready var title_board: Control = $TitleBoard
@onready var title_crack: Control = $TitleCrack

## Title pieces that step aside while a big panel is open, with their resting positions.
## Seconds each opening line takes to type, and the pause before the next one.
const INTRO_TYPE_TIME: float = 1.2
const INTRO_GAP: float = 0.35

## The opening plays once per run (not again when coming back from a level).
static var _intro_seen: bool = false

var _intro: Control = null
var _intro_time: float = 0.0
var _intro_leaving: float = -1.0
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
	# Phase 15h: the content notice goes with the credits (never a pop-up, never in the way of play).
	if credits_content == null:
		credits_content = CreditsContent.get_default()
	credits_label.text = credits_content.masthead + "\n\n" + StoryTexts.get_default().content_notice
	version_label.text = version_text
	music_label.text = music_text
	sfx_label.text = sfx_text
	shake_check.text = shake_text
	corruption_check = CheckButton.new()
	corruption_check.text = (load(OptionsBoard.PRESENTATION_PATH) as ProfilePresentation).toggle_text
	shake_check.get_parent().add_child(corruption_check)
	shake_check.get_parent().move_child(corruption_check, shake_check.get_index() + 1)
	blood_check = CheckButton.new()
	blood_check.text = (load(OptionsBoard.PRESENTATION_PATH) as ProfilePresentation).blood_toggle_text
	corruption_check.get_parent().add_child(blood_check)
	corruption_check.get_parent().move_child(blood_check, corruption_check.get_index() + 1)
	ai_check = CheckButton.new()
	ai_check.text = (load(OptionsBoard.PRESENTATION_PATH) as ProfilePresentation).ai_toggle_text
	corruption_check.get_parent().add_child(ai_check)
	corruption_check.get_parent().move_child(ai_check, corruption_check.get_index() + 1)
	controls_button.text = (load(ControlsConfig.CATALOG_PATH) as ControlsCatalog).open_button_text
	controls_editor = ControlsEditor.new()
	$OptionsPanel/Margin.add_child(controls_editor)
	controls_button.pressed.connect(_open_controls)
	controls_editor.closed.connect(_close_controls)
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
	corruption_check.button_pressed = _settings["corruption_effects"]
	blood_check.button_pressed = _settings["blood"]
	ai_check.button_pressed = _settings["ai_adaptation"]
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)
	music_slider.value_changed.connect(_on_setting_changed.bind("music_volume"))
	sfx_slider.value_changed.connect(_on_setting_changed.bind("sfx_volume"))
	shake_check.toggled.connect(_on_setting_changed.bind("camera_shake"))
	corruption_check.toggled.connect(_on_setting_changed.bind("corruption_effects"))
	blood_check.toggled.connect(_on_setting_changed.bind("blood"))
	ai_check.toggled.connect(_on_setting_changed.bind("ai_adaptation"))
	GameSettings.apply(_settings)
	_show_main_buttons()
	message_label.text = ""
	# The tagline under the title became the opening.
	tagline_label.visible = false
	if not _intro_seen and DisplayServer.get_name() != "headless" and not intro_lines.is_empty():
		_intro_seen = true
		_start_opening()
	else:
		_play_intro()


func _process(delta: float) -> void:
	if _intro != null:
		_advance_opening(delta)
	if credits_panel.visible:
		# The front page scrolls up slowly and starts over once it has gone past.
		credits_roll.position.y -= credits_content.menu_speed * delta
		if credits_roll.position.y < -credits_roll.size.y:
			credits_roll.position.y = credits_scroll.size.y


func _input(event: InputEvent) -> void:
	if _intro == null:
		return
	# While the opening runs the menu takes no input; any key, click or button skips it.
	var press: bool = (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) \
			or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed)
	if press and _intro_leaving < 0.0:
		_end_opening(0.3)
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Esc / back closes an open panel (the controls page handles its own Esc).
	if event.is_action_pressed("ui_cancel"):
		if controls_editor != null and controls_editor.is_open():
			return
		if options_panel.visible:
			_on_back_pressed(options_button)
		elif credits_panel.visible:
			_on_back_pressed(credits_button)
		elif confirm_panel.visible:
			_on_confirm_cancel_pressed()
		else:
			return
		get_viewport().set_input_as_handled()


func _open_controls() -> void:
	options_box.visible = false
	controls_editor.open()


func _close_controls() -> void:
	options_box.visible = true
	controls_button.grab_focus()


func _show_main_buttons() -> void:
	if controls_editor != null and controls_editor.is_open():
		controls_editor.close()
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


## The credits roll: the same content as the end of the game (the notice stays apart, always visible above the roll).
func _build_credits() -> void:
	CreditsRoll.fill(credits_roll, credits_content, credits_scroll.custom_minimum_size.x, false, {"header_variation": "HeaderLabel", "note_variation": "NoteLabel"})
	var headline := credits_roll.get_child(0) as Label
	headline.add_theme_font_size_override(&"font_size", 34)
	headline.add_theme_color_override(&"font_color", Color(0.2, 0.15, 0.12))


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


# =====================================================================================
# Opening (first time the menu opens in a run)
# =====================================================================================

## Black screen with a fine grain; the lines appear one by one in the centre, typed out on an old
## typewriter, the last one sealed by a small red star; then they fade and the menu makes its
## usual entrance. Nothing in the menu reacts meanwhile.
func _start_opening() -> void:
	_intro = Control.new()
	_intro.name = "Opening"
	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro.z_index = 100
	add_child(_intro)
	_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro.draw.connect(_draw_opening)
	_intro_time = 0.0
	_intro_leaving = -1.0
	get_viewport().gui_release_focus()


func _opening_typed_end() -> float:
	return 0.4 + float(intro_lines.size()) * (INTRO_TYPE_TIME + INTRO_GAP)


func _advance_opening(delta: float) -> void:
	_intro_time += delta
	if _intro_leaving < 0.0 and _intro_time > _opening_typed_end() + 1.2:
		_end_opening(1.0)
	if _intro_leaving >= 0.0:
		_intro_leaving -= delta
		if _intro_leaving <= 0.0:
			_intro.queue_free()
			_intro = null
			return
	_intro.queue_redraw()


## Fades the opening out over `seconds` while the menu makes its entrance; focus on the first button.
func _end_opening(seconds: float) -> void:
	_intro_leaving = seconds
	_intro.set_meta("leave_total", seconds)
	_play_intro()
	for button: Button in [new_game_button, continue_button, quit_button]:
		if not button.disabled:
			button.grab_focus()
			break


func _draw_opening() -> void:
	var s: Vector2 = _intro.size
	var alpha: float = 1.0
	var words: float = 1.0
	if _intro_leaving >= 0.0:
		var total: float = float(_intro.get_meta("leave_total", 1.0))
		var k: float = 1.0 - _intro_leaving / maxf(total, 0.01)
		words = 1.0 - clampf(k * 2.0, 0.0, 1.0)
		alpha = 1.0 - clampf(k * 1.6 - 0.4, 0.0, 1.0)
	_intro.draw_rect(Rect2(Vector2.ZERO, s), Color(0.02, 0.02, 0.03, alpha))
	# Fine film grain, different every frame.
	var seed_t: int = int(_intro_time * 24.0)
	for i in 260:
		var h1: float = fposmod(sin(float(i * 7 + seed_t * 131) * 12.9898) * 43758.5453, 1.0)
		var h2: float = fposmod(sin(float(i * 13 + seed_t * 71) * 78.233) * 43758.5453, 1.0)
		var shade: float = 0.25 + 0.5 * fposmod(h1 * 7.0, 1.0)
		_intro.draw_rect(Rect2(Vector2(h1 * s.x, h2 * s.y), Vector2(2, 2)), Color(shade, shade, shade, 0.08 * alpha))
	if words <= 0.0:
		return
	var font: Font = GameFonts.TYPEWRITER
	var size: int = 34
	var line_h: float = 58.0
	var top: float = s.y * 0.5 - line_h * float(intro_lines.size() - 1) * 0.5
	for i in intro_lines.size():
		var line: String = intro_lines[i]
		var start: float = 0.4 + float(i) * (INTRO_TYPE_TIME + INTRO_GAP)
		var shown: float = clampf((_intro_time - start) / INTRO_TYPE_TIME, 0.0, 1.0) * float(line.length())
		if _intro_leaving >= 0.0:
			shown = float(line.length())
		if shown <= 0.0:
			continue
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var x: float = (s.x - w) * 0.5
		var y: float = top + float(i) * line_h
		for c in line.length():
			var a: float = clampf(shown - float(c), 0.0, 1.0)
			var ch: String = line[c]
			if a > 0.0:
				var ink: float = 0.8 + 0.2 * fposmod(sin(float(c * 31 + i * 7) * 12.9898) * 43758.5453, 1.0)
				_intro.draw_char(font, Vector2(x, y), ch, size, Color(0.92, 0.88, 0.8, a * ink * words))
			x += font.get_char_size(ch.unicode_at(0), size).x
		if i == intro_lines.size() - 1 and shown >= float(line.length()):
			# A small red star glowing after the last word.
			var since: float = _intro_time - (start + INTRO_TYPE_TIME)
			var glow: float = clampf(since / 0.3, 0.0, 1.0) * (0.75 + 0.25 * sin(_intro_time * 5.0))
			if _intro_leaving >= 0.0:
				glow = 1.0
			var c := Vector2(x + 22.0, y - 11.0)
			for k in 4:
				_intro.draw_circle(c, 6.0 + float(k) * 6.0, Color(1.0, 0.2, 0.12, 0.08 * glow * words))
			var star := PackedVector2Array()
			for k in 10:
				var r: float = 9.0 if k % 2 == 0 else 3.8
				star.append(c + Vector2.from_angle(-PI * 0.5 + float(k) * PI / 5.0) * r * maxf(glow, 0.2))
			_intro.draw_colored_polygon(star, Color(1.0, 0.24, 0.16, glow * words))

