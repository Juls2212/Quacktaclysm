extends Node
## Headless smoke test for Phase 14b-2 (remappable controls): ControlsConfig (two bindings per
## action, keys and mouse buttons, file round trip, defaults, corrupt / partial files, conflicts,
## the protected primary slot, reserved Esc), the ControlsEditor page, the options menus that host
## it, the live key hints of the tutorial, and the unchanged save keys and autoloads.
## Development only. Run:
##   <godot> --headless --path game res://frontend/scenes/test/phase14b2_smoke_test.tscn
## Uses user://test_controls_phase14b2.cfg and a redirected save path; the player's real controls
## file (user://controls.cfg) and the real save are never touched. The InputMap is put back to the
## project defaults at the end.

const TEST_CFG: String = "user://test_controls_phase14b2.cfg"
const TEST_SAVE: String = "user://test_save_phase14b2.json"
const REAL_CONTROLS: String = "user://controls.cfg"
const SAVE_KEYS: Array[String] = ["save_version", "current_level", "checkpoint", "souls_released", "souls_kept", "decisions", "adaptive_profile"]
const MAIN_MENU: PackedScene = preload("res://frontend/ui/main_menu.tscn")
const PAUSE_MENU: PackedScene = preload("res://frontend/ui/pause_menu.tscn")
const TUTORIAL: PackedScene = preload("res://frontend/levels/tutorial.tscn")

var failures: int = 0
var real_save_before: String = ""
var real_controls_before: String = ""


func _ready() -> void:
	SaveSystem.set_save_path(TEST_SAVE)
	real_save_before = _read_file(SaveSystem.DEFAULT_PATH)
	real_controls_before = _read_file(REAL_CONTROLS)
	_run.call_deferred()


func _check(check_name: String, condition: bool, detail: String = "") -> void:
	if condition:
		print("PASS: %s %s" % [check_name, detail])
	else:
		failures += 1
		print("FAIL: %s %s" % [check_name, detail])


func _read_file(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "<missing>"


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


func _mouse(button: MouseButton, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func _fresh() -> ControlsConfig:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	ControlsConfig.restore_input_map_defaults()
	return ControlsConfig.new(TEST_CFG)


func _tokens(config: ControlsConfig, action: String) -> Array:
	var out: Array = []
	for slot in ControlsConfig.SLOT_COUNT:
		var event: InputEvent = config.get_binding(action, slot)
		out.append(ControlsConfig.event_token(event) if event != null else "")
	return out


func _input_map_tokens(action: String) -> Array:
	var out: Array = []
	for event in InputMap.action_get_events(StringName(action)):
		out.append(ControlsConfig.event_token(event))
	return out


func _write_cfg(text: String) -> void:
	var file := FileAccess.open(TEST_CFG, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _run() -> void:
	SaveSystem.purge()
	_test_defaults()
	_test_round_trip()
	_test_conflicts()
	_test_primary_protected()
	_test_reset()
	_test_files()
	_test_reserved_and_mouse()
	await _test_input_map_actions()
	await _test_editor()
	await _test_hosts()
	await _test_tutorial_hints()
	_test_invariants()
	ControlsConfig.restore_input_map_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	SaveSystem.purge()
	_check("the real controls file was not touched", _read_file(REAL_CONTROLS) == real_controls_before)
	_check("the real save file was not touched", _read_file(SaveSystem.DEFAULT_PATH) == real_save_before)
	print("RESULT: %s (%d failure(s))" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(1 if failures > 0 else 0)


# ---------------------------------------------------------------------------------------------
# ControlsConfig (the free keys used for rebinding are B and N: E and Q belong to the heal action since Phase 15a)
# ---------------------------------------------------------------------------------------------

func _test_defaults() -> void:
	var config: ControlsConfig = _fresh()
	var expected: Dictionary = {
		"move_left": ["k:%d" % KEY_A, "k:%d" % KEY_LEFT], "move_right": ["k:%d" % KEY_D, "k:%d" % KEY_RIGHT],
		"jump": ["k:%d" % KEY_SPACE, "k:%d" % KEY_UP], "dash": ["k:%d" % KEY_SHIFT, "k:%d" % KEY_K],
		"attack": ["k:%d" % KEY_J, "m:%d" % MOUSE_BUTTON_LEFT], "wave": ["k:%d" % KEY_U, "m:%d" % MOUSE_BUTTON_RIGHT],
		"heavy_attack": ["k:%d" % KEY_I, "m:%d" % MOUSE_BUTTON_MIDDLE], "pause": ["k:%d" % KEY_ESCAPE, "k:%d" % KEY_P],
		"heal": ["k:%d" % KEY_E, "k:%d" % KEY_Q],
	}
	var ok: bool = true
	for action: String in expected:
		ok = ok and _tokens(config, action) == expected[action]
	_check("defaults: up to two bindings per action, keys and mouse buttons, as in the project", ok)
	_check("catalog: the nine gameplay actions (heal added in Phase 15a), no debug or ui_ action, Spanish names with accents",
		config.get_actions().size() == 9 and not "ui_accept" in config.get_actions() and config.catalog.get_action_name("heavy_attack") == "Golpe pesado"
		and config.catalog.get_action_name("move_left").contains("izquierda"))
	var matches: bool = true
	for action in config.get_actions():
		matches = matches and _input_map_tokens(action) == _tokens(config, action)
	_check("defaults: the live InputMap matches them", matches)
	_check("names: readable", config.event_text(config.get_binding("jump", 0)) == "Barra espaciadora"
		and config.event_text(config.get_binding("dash", 0)) == "Shift"
		and config.event_text(config.get_binding("attack", 1)) == "Clic izquierdo"
		and config.event_text(config.get_binding("wave", 1)) == "Clic derecho"
		and config.event_text(config.get_binding("heavy_attack", 1)) == "Clic central")


func _test_round_trip() -> void:
	var config: ControlsConfig = _fresh()
	var first: Dictionary = config.try_bind("jump", 0, _key(KEY_B))
	var second: Dictionary = config.try_bind("jump", 1, _key(KEY_F))
	var mouse: Dictionary = config.try_bind("dash", 1, _mouse(MOUSE_BUTTON_XBUTTON1))
	_check("rebind: free inputs are accepted (two bindings, keyboard and extra mouse button)",
		first["result"] == ControlsConfig.Result.OK and second["result"] == ControlsConfig.Result.OK and mouse["result"] == ControlsConfig.Result.OK)
	_check("rebind: an action can hold two bindings", _tokens(config, "jump") == ["k:%d" % KEY_B, "k:%d" % KEY_F])
	config.apply_to_input_map()
	_check("rebind: applied to the InputMap", _input_map_tokens("jump") == ["k:%d" % KEY_B, "k:%d" % KEY_F]
		and _input_map_tokens("dash") == ["k:%d" % KEY_SHIFT, "m:%d" % MOUSE_BUTTON_XBUTTON1])
	_check("save: written", config.save_file() and FileAccess.file_exists(TEST_CFG))
	var reloaded := ControlsConfig.new(TEST_CFG)
	var read: bool = reloaded.load_file()
	_check("reload: the same bindings come back", read and reloaded.file_status == ControlsConfig.FileStatus.OK
		and _tokens(reloaded, "jump") == _tokens(config, "jump") and _tokens(reloaded, "dash") == _tokens(config, "dash")
		and _tokens(reloaded, "attack") == ["k:%d" % KEY_J, "m:%d" % MOUSE_BUTTON_LEFT])
	ControlsConfig.restore_input_map_defaults()
	var applied: ControlsConfig = ControlsConfig.apply_saved(TEST_CFG)
	_check("startup helper: applies a saved file to the InputMap", applied != null and _input_map_tokens("jump") == ["k:%d" % KEY_B, "k:%d" % KEY_F])
	_check("startup helper: the player's real file is skipped in headless runs", ControlsConfig.apply_saved() == null)
	var text: String = _read_file(TEST_CFG)
	_check("save: a ConfigFile of its own, no save-game data", text.contains("[controls]") and not text.contains("souls_released") and not text.contains("checkpoint"))


func _test_conflicts() -> void:
	var config: ControlsConfig = _fresh()
	var outcome: Dictionary = config.try_bind("attack", 0, _key(KEY_K))
	_check("conflict: an input used by another action is reported (nothing changes)", outcome["result"] == ControlsConfig.Result.CONFLICT
		and outcome["action"] == "dash" and outcome["slot"] == 1 and _tokens(config, "attack")[0] == "k:%d" % KEY_J and _tokens(config, "dash")[1] == "k:%d" % KEY_K)
	var swapped: Dictionary = config.swap("attack", 0, _key(KEY_K))
	_check("conflict: swap gives the input to the new slot and the old one to the other", swapped["result"] == ControlsConfig.Result.OK
		and _tokens(config, "attack")[0] == "k:%d" % KEY_K and _tokens(config, "dash")[1] == "k:%d" % KEY_J)
	var dupes: Dictionary = {}
	var unique: bool = true
	for action in config.get_actions():
		for token in _tokens(config, action):
			if token != "" and dupes.has(token):
				unique = false
			dupes[token] = true
	_check("conflict: no input ends up bound twice", unique)
	var own: Dictionary = config.try_bind("jump", 1, _key(KEY_SPACE))
	_check("conflict: the other slot of the same action counts too", own["result"] == ControlsConfig.Result.CONFLICT and own["action"] == "jump")
	config = _fresh()
	config.clear_slot("jump", 1)
	config.clear_slot("dash", 1)
	var blocked: Dictionary = config.swap("dash", 1, _key(KEY_SPACE))
	_check("conflict: a swap that would leave an action without primary is refused and changes nothing",
		blocked["result"] == ControlsConfig.Result.CANNOT_SWAP and _tokens(config, "jump") == ["k:%d" % KEY_SPACE, ""] and _tokens(config, "dash")[1] == "")


func _test_primary_protected() -> void:
	var config: ControlsConfig = _fresh()
	_check("primary: cannot be cleared", config.clear_slot("jump", 0) == ControlsConfig.Result.LAST_BINDING and config.get_binding("jump", 0) != null)
	_check("alternative: can be cleared", config.clear_slot("jump", 1) == ControlsConfig.Result.OK and config.get_binding("jump", 1) == null)
	for action in config.get_actions():
		config.clear_slot(action, 1)
	var all_have_one: bool = true
	for action in config.get_actions():
		all_have_one = all_have_one and config.get_binding(action, 0) != null and not config.get_events(action).is_empty()
	_check("primary: every action keeps a binding after clearing every alternative", all_have_one)
	config.apply_to_input_map()
	var map_ok: bool = true
	for action in config.get_actions():
		map_ok = map_ok and InputMap.action_get_events(StringName(action)).size() == 1
	_check("primary: and so does the InputMap", map_ok)
	config = _fresh()
	config.clear_slot("dash", 1)
	var promoted: Dictionary = config.swap("dash", 1, _key(KEY_U))
	_check("primary: when a swap takes an action's primary, its alternative is promoted", promoted["result"] == ControlsConfig.Result.OK
		and _tokens(config, "wave") == ["m:%d" % MOUSE_BUTTON_RIGHT, ""] and _tokens(config, "dash") == ["k:%d" % KEY_SHIFT, "k:%d" % KEY_U])


func _test_reset() -> void:
	var config: ControlsConfig = _fresh()
	config.try_bind("jump", 0, _key(KEY_B))
	config.try_bind("wave", 1, _mouse(MOUSE_BUTTON_XBUTTON2))
	config.clear_slot("dash", 1)
	config.apply_to_input_map()
	config.reset_to_defaults()
	config.apply_to_input_map()
	_check("reset: back to the project defaults, in memory and in the InputMap",
		_tokens(config, "jump") == ["k:%d" % KEY_SPACE, "k:%d" % KEY_UP] and _tokens(config, "dash") == ["k:%d" % KEY_SHIFT, "k:%d" % KEY_K]
		and _input_map_tokens("wave") == ["k:%d" % KEY_U, "m:%d" % MOUSE_BUTTON_RIGHT])


func _test_files() -> void:
	# Corrupt: not a ConfigFile at all.
	var garbage: String = "this is [not a { config file\n\u0000\u0001 = = ="
	_write_cfg(garbage)
	var config := ControlsConfig.new(TEST_CFG)
	var read: bool = config.load_file()
	_check("corrupt file: defaults, no crash", not read and config.file_status == ControlsConfig.FileStatus.CORRUPT
		and _tokens(config, "jump") == ["k:%d" % KEY_SPACE, "k:%d" % KEY_UP])
	_check("corrupt file: loading does not erase or rewrite it", _read_file(TEST_CFG) == garbage)
	# Missing.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))
	config = ControlsConfig.new(TEST_CFG)
	_check("missing file: defaults", not config.load_file() and config.file_status == ControlsConfig.FileStatus.MISSING)
	# Partial and damaged: valid entries survive, the others fall back per action.
	var partial: String = "[controls]\njump=PackedStringArray(\"k:%d\", \"\")\ndash=\"oops\"\nattack=PackedStringArray(\"m:%d\", \"\")\nwave=PackedStringArray(\"k:%d\", \"m:2\")\n" % [KEY_B, MOUSE_BUTTON_WHEEL_UP, KEY_Z]
	_write_cfg(partial)
	config = ControlsConfig.new(TEST_CFG)
	_check("partial file: read", config.load_file() and config.file_status == ControlsConfig.FileStatus.PARTIAL)
	_check("partial file: valid entries kept", _tokens(config, "jump") == ["k:%d" % KEY_B, ""] and _tokens(config, "wave") == ["k:%d" % KEY_Z, "m:2"])
	_check("partial file: a wrong value, a wheel button and missing actions fall back to their defaults",
		_tokens(config, "dash") == ["k:%d" % KEY_SHIFT, "k:%d" % KEY_K] and _tokens(config, "attack") == ["k:%d" % KEY_J, "m:%d" % MOUSE_BUTTON_LEFT]
		and _tokens(config, "heavy_attack") == ["k:%d" % KEY_I, "m:%d" % MOUSE_BUTTON_MIDDLE])
	_check("partial file: loading does not rewrite it", _read_file(TEST_CFG) == partial)
	# An input claimed by two actions in the file: the first keeps it, the other action uses its defaults.
	_write_cfg("[controls]\njump=PackedStringArray(\"k:%d\", \"\")\ndash=PackedStringArray(\"k:%d\", \"k:%d\")\n" % [KEY_K, KEY_K, KEY_L])
	config = ControlsConfig.new(TEST_CFG)
	config.load_file()
	var seen: Dictionary = {}
	var unique: bool = true
	for action in config.get_actions():
		for token in _tokens(config, action):
			if token != "" and seen.has(token):
				unique = false
			seen[token] = true
	_check("file with a repeated input: no duplicates survive and every action has a primary", unique and _tokens(config, "jump")[0] == "k:%d" % KEY_K
		and config.get_binding("dash", 0) != null)
	# Esc in an action that is not `pause`, and an action with no usable binding.
	_write_cfg("[controls]\njump=PackedStringArray(\"k:%d\", \"\")\ndash=PackedStringArray(\"\", \"\")\npause=PackedStringArray(\"k:%d\", \"k:%d\")\n" % [KEY_ESCAPE, KEY_O, KEY_ESCAPE])
	config = ControlsConfig.new(TEST_CFG)
	config.load_file()
	_check("file: Esc is refused outside pause, an empty action gets its defaults, pause may keep Esc",
		_tokens(config, "jump") == ["k:%d" % KEY_SPACE, "k:%d" % KEY_UP] and _tokens(config, "dash") == ["k:%d" % KEY_SHIFT, "k:%d" % KEY_K]
		and _tokens(config, "pause") == ["k:%d" % KEY_O, "k:%d" % KEY_ESCAPE])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))


func _test_reserved_and_mouse() -> void:
	var config: ControlsConfig = _fresh()
	_check("Esc: cannot be assigned to an action", config.try_bind("jump", 0, _key(KEY_ESCAPE))["result"] == ControlsConfig.Result.RESERVED
		and config.try_bind("pause", 1, _key(KEY_ESCAPE))["result"] == ControlsConfig.Result.RESERVED)
	_check("mouse: left, right, middle and extra buttons are valid, the wheel is not",
		ControlsConfig.is_bindable(_mouse(MOUSE_BUTTON_LEFT)) and ControlsConfig.is_bindable(_mouse(MOUSE_BUTTON_RIGHT))
		and ControlsConfig.is_bindable(_mouse(MOUSE_BUTTON_MIDDLE)) and ControlsConfig.is_bindable(_mouse(MOUSE_BUTTON_XBUTTON1))
		and not ControlsConfig.is_bindable(_mouse(MOUSE_BUTTON_WHEEL_UP)) and not ControlsConfig.is_bindable(_mouse(MOUSE_BUTTON_WHEEL_DOWN)))
	_check("mouse: the wheel is refused as a binding", config.try_bind("jump", 1, _mouse(MOUSE_BUTTON_WHEEL_UP))["result"] == ControlsConfig.Result.INVALID)
	config.try_bind("pause", 0, _key(KEY_O))
	config.clear_slot("pause", 1)
	config.apply_to_input_map()
	var esc: InputEventKey = _key(KEY_ESCAPE)
	_check("Esc: still pauses after `pause` was rebound away from it", not InputMap.event_is_action(esc, "pause") and PauseMenu.is_pause_event(esc))
	var released: InputEventKey = _key(KEY_ESCAPE)
	released.pressed = false
	_check("Esc: a key release does not pause", not PauseMenu.is_pause_event(released))
	ControlsConfig.restore_input_map_defaults()


func _test_input_map_actions() -> void:
	await _frames(3)
	var config: ControlsConfig = _fresh()
	config.try_bind("jump", 1, _mouse(MOUSE_BUTTON_XBUTTON1))
	config.try_bind("jump", 0, _key(KEY_B))
	config.apply_to_input_map()
	Input.parse_input_event(_mouse(MOUSE_BUTTON_XBUTTON1))
	await _frames(1)
	_check("mouse binding: the extra mouse button triggers its action", Input.is_action_pressed("jump"), str(_input_map_tokens("jump")))
	Input.parse_input_event(_mouse(MOUSE_BUTTON_XBUTTON1, false))
	await _frames(1)
	_check("mouse binding: and releases it", not Input.is_action_pressed("jump"))
	_check("mouse binding: the old primary key no longer jumps", not InputMap.event_is_action(_key(KEY_SPACE), "jump") and InputMap.event_is_action(_key(KEY_B), "jump"))
	Input.parse_input_event(_mouse(MOUSE_BUTTON_LEFT))
	await _frames(1)
	_check("mouse binding: the default left click still attacks", Input.is_action_pressed("attack"))
	Input.parse_input_event(_mouse(MOUSE_BUTTON_LEFT, false))
	await _frames(1)
	ControlsConfig.restore_input_map_defaults()


# ---------------------------------------------------------------------------------------------
# ControlsEditor (the page) and its hosts
# ---------------------------------------------------------------------------------------------

func _make_editor() -> ControlsEditor:
	var config: ControlsConfig = _fresh()
	var editor := ControlsEditor.new()
	editor.config = config
	add_child(editor)
	return editor


func _test_editor() -> void:
	var editor: ControlsEditor = _make_editor()
	var closed_count: Array[int] = [0]
	editor.closed.connect(func() -> void: closed_count[0] += 1)
	editor.open()
	await _frames(1)
	_check("editor: shows a readable name per slot", editor.get_slot_text("jump", 0) == "Barra espaciadora" and editor.get_slot_text("attack", 1) == "Clic izquierdo"
		and editor.get_slot_text("dash", 0) == "Shift" and editor.is_open())
	editor.begin_capture("jump", 0)
	_check("editor: a clicked slot waits for an input", editor.is_capturing() and editor.get_slot_text("jump", 0) == "Pulsa una tecla…")
	var consumed: bool = editor.process_capture(_key(KEY_B))
	_check("editor: the captured key is consumed (it never reaches the game)", consumed and not editor.is_capturing())
	_check("editor: rebound, applied and saved at once", editor.get_slot_text("jump", 0) == "B" and _input_map_tokens("jump")[0] == "k:%d" % KEY_B
		and _read_file(TEST_CFG).contains("k:%d" % KEY_B))
	editor.begin_capture("attack", 0)
	editor.process_capture(_key(KEY_ESCAPE))
	_check("editor: Esc cancels a capture and changes nothing", not editor.is_capturing() and editor.get_slot_text("attack", 0) == "J"
		and editor.message_label.text == editor.catalog.capture_cancelled_text)
	editor.begin_capture("attack", 0)
	editor.process_capture(_key(KEY_K))
	_check("editor: a used input asks to swap or cancel", editor.has_pending_conflict() and editor.message_label.text.contains("Esquivar") and editor.get_slot_text("attack", 0) == "J")
	editor.cancel_pending()
	_check("editor: cancel leaves everything as it was", not editor.has_pending_conflict() and editor.get_slot_text("attack", 0) == "J" and editor.get_slot_text("dash", 1) == "K")
	editor.begin_capture("attack", 0)
	editor.process_capture(_key(KEY_K))
	editor.swap_pending()
	_check("editor: swap exchanges the two inputs", editor.get_slot_text("attack", 0) == "K" and editor.get_slot_text("dash", 1) == "J" and not editor.has_pending_conflict())
	editor.clear_alternative("jump")
	_check("editor: the alternative can be cleared, the primary stays", editor.get_slot_text("jump", 1) == "—" and editor.get_slot_text("jump", 0) == "B")
	editor.begin_capture("wave", 1)
	editor.process_capture(_mouse(MOUSE_BUTTON_XBUTTON2))
	_check("editor: extra mouse buttons can be assigned", editor.get_slot_text("wave", 1) == "Botón lateral 2")
	editor.reset_defaults()
	_check("editor: reset restores the defaults", editor.get_slot_text("jump", 0) == "Barra espaciadora" and editor.get_slot_text("attack", 0) == "J"
		and editor.get_slot_text("wave", 1) == "Clic derecho" and editor.message_label.text == editor.catalog.reset_done_text)
	# Keyboard path of the same page.
	editor.begin_capture("jump", 0)
	_check("editor: a wheel scroll is not accepted as a binding", editor.process_capture(_mouse(MOUSE_BUTTON_WHEEL_UP)) and editor.get_slot_text("jump", 0) == "Barra espaciadora")
	# While the game is paused.
	get_tree().paused = true
	editor.begin_capture("jump", 0)
	var event: InputEventKey = _key(KEY_G)
	Input.parse_input_event(event)
	await _frames(2)
	get_tree().paused = false
	_check("editor: captures through the real input path while the game is paused", editor.get_slot_text("jump", 0) == "G", editor.get_slot_text("jump", 0))
	editor.close()
	_check("editor: closing emits `closed`", closed_count[0] == 1 and not editor.is_open())
	editor.free()
	ControlsConfig.restore_input_map_defaults()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))


func _test_hosts() -> void:
	# The pause menu's options board.
	var board := OptionsBoard.new()
	add_child(board)
	await _frames(1)
	board.open()
	_check("options board: has a Controles button and an editor page", board.controls_button != null and board.controls_editor != null and board.controls_button.text == "Controles…")
	board.controls_button.pressed.emit()
	_check("options board: the button opens the page in place of the settings", board.controls_editor.is_open() and not board._settings_box.visible)
	board.controls_editor.close()
	_check("options board: back returns to the settings", board._settings_box.visible and not board.controls_editor.is_open())
	board.controls_button.pressed.emit()
	board.close()
	_check("options board: closing it closes the page too", not board.controls_editor.is_open() and not board.is_open())
	board.free()
	# The pause menu itself.
	var pause: PauseMenu = PAUSE_MENU.instantiate() as PauseMenu
	add_child(pause)
	await _frames(1)
	_check("pause menu: its options host the controls page", pause.options.controls_editor != null and pause.options.controls_button != null)
	pause.free()
	# The main menu.
	var menu: Node = MAIN_MENU.instantiate()
	add_child(menu)
	await _frames(2)
	_check("main menu: the options panel has a Controles button and an editor page", menu.controls_button != null and menu.controls_editor != null)
	menu.controls_button.pressed.emit()
	_check("main menu: the button opens the page in place of the options", menu.controls_editor.is_open() and not menu.options_box.visible)
	menu.controls_editor.close()
	_check("main menu: back returns to the options", menu.options_box.visible and menu.controls_button.has_focus())
	menu.free()
	ControlsConfig.restore_input_map_defaults()
	SaveSystem.purge()


# ---------------------------------------------------------------------------------------------
# Live hints
# ---------------------------------------------------------------------------------------------

func _test_tutorial_hints() -> void:
	ControlsConfig.restore_input_map_defaults()
	GameState.start_new_game()
	GameState.autosave_enabled = false
	var level: LevelBase = TUTORIAL.instantiate() as LevelBase
	add_child(level)
	await _frames(2)
	var controller: TutorialController = level.get_node("TutorialController")
	var heavy_step: String = ""
	for step in controller.steps:
		if String(step["id"]) == "heavy":
			heavy_step = String(step["text"])
	_check("tutorial: the heavy prompt does not hardcode the mouse button (Phase 15m: the wave is no longer a tutorial step)", not heavy_step.to_lower().contains("clic") and heavy_step.contains("{heavy_attack}"))
	var before: String = controller.build_text("{jump}")
	_check("tutorial: default hint shows both bindings by name", before.replace(ControlsConfig.HINT_SPACE, " ") == "Barra espaciadora o Flecha arriba", before)
	_check("tutorial: mouse bindings read as names, not keys", controller.build_text("{attack}").replace(ControlsConfig.HINT_SPACE, " ") == "J o Clic izquierdo"
		and controller.build_text("{wave}").replace(ControlsConfig.HINT_SPACE, " ") == "U o Clic derecho")
	var config := ControlsConfig.new(TEST_CFG)
	config.try_bind("jump", 0, _key(KEY_B))
	config.try_bind("jump", 1, _mouse(MOUSE_BUTTON_XBUTTON1))
	config.try_bind("move_left", 0, _key(KEY_N))
	config.apply_to_input_map()
	var after: String = controller.build_text("{jump}")
	_check("tutorial: the hint follows a remap, mouse button included", after.replace(ControlsConfig.HINT_SPACE, " ") == "B o Botón lateral 1", after)
	controller._hint_check_left = 0.0
	controller._refresh_hints()
	_check("tutorial: the prompt on screen is refreshed after a remap", controller.prompt_label.text.contains("N") and not controller.prompt_label.text.contains("{"), controller.prompt_label.text)
	var sign: TutorialSign = null
	for node in level.find_children("*", "Control", true, false):
		if node is TutorialSign:
			sign = node
			break
	if sign != null:
		sign._refresh_keys()
		_check("tutorial: the sign draws the new names as keys", sign._keys.has("B") and sign._keys.has("Botón%slateral%s1" % [ControlsConfig.HINT_SPACE, ControlsConfig.HINT_SPACE]))
	level.free()
	ControlsConfig.restore_input_map_defaults()
	GameState.start_new_game()
	GameState.autosave_enabled = true
	SaveSystem.purge()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CFG))


func _test_invariants() -> void:
	var keys: Array = GameState.to_dict().keys()
	keys.sort()
	var expected: Array = SAVE_KEYS.duplicate()
	expected.sort()
	_check("save: still exactly the seven keys", keys == expected, str(keys))
	var autoloads: PackedStringArray = PackedStringArray()
	for property in ProjectSettings.get_property_list():
		var property_name: String = property["name"]
		if property_name.begins_with("autoload/"):
			autoloads.append(property_name.trim_prefix("autoload/"))
	autoloads.sort()
	_check("autoloads: still exactly GameState, SceneManager and AudioDirector", autoloads == PackedStringArray(["AudioDirector", "GameState", "SceneManager"]), str(autoloads))
	_check("game code: gameplay reads actions, not keycodes (the player script has no raw key checks)",
		not FileAccess.get_file_as_string("res://backend/player/player.gd").contains("is_key_pressed")
		and not FileAccess.get_file_as_string("res://backend/player/player.gd").contains("InputEventKey"))
