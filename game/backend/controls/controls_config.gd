class_name ControlsConfig
extends RefCounted
## The player's key and mouse bindings for the rebindable actions (see ControlsCatalog): up to two
## per action (primary and alternative), kept in a ConfigFile (user://controls.cfg, never the save
## game) and applied to the InputMap. Plain class, not an autoload: SceneManager calls
## `ControlsConfig.apply_saved()` once at startup.
##
## Rules: an input can belong to only one slot of one action (rebinding to a used input is reported
## as a conflict, and the caller can swap or cancel); the primary slot can never be empty; Esc is
## reserved (it cancels a capture and always pauses) and is only bound by default to `pause`; a
## missing, corrupt or partial file falls back to the defaults per action.
## Defaults come from the project's InputMap settings, never from the live InputMap.

const DEFAULT_PATH: String = "user://controls.cfg"
const SECTION: String = "controls"
const CATALOG_PATH: String = "res://backend/controls/default_controls_catalog.tres"
const SLOT_PRIMARY: int = 0
const SLOT_ALTERNATIVE: int = 1
const SLOT_COUNT: int = 2
## Spaces inside a key name are written as this character in hints so that a name stays one word.
const HINT_SPACE: String = " "
const RESERVED_ACTION: String = "pause"

enum Result { OK, CONFLICT, UNCHANGED, RESERVED, INVALID, LAST_BINDING, CANNOT_SWAP }
enum FileStatus { NOT_LOADED, MISSING, OK, PARTIAL, CORRUPT }

var catalog: ControlsCatalog
var path: String = DEFAULT_PATH
var file_status: FileStatus = FileStatus.NOT_LOADED
## action (String) -> Array of SLOT_COUNT entries, each an InputEvent or null.
var _bindings: Dictionary = {}


func _init(p_path: String = DEFAULT_PATH, p_catalog: ControlsCatalog = null) -> void:
	path = p_path
	catalog = p_catalog if p_catalog != null else (load(CATALOG_PATH) as ControlsCatalog)
	reset_to_defaults()


# ---------------------------------------------------------------------------------------------
# Startup helper
# ---------------------------------------------------------------------------------------------

## Loads the controls file and applies it to the InputMap. Called once from an existing autoload.
## Automated headless runs (the test suite) skip the player's real file so it cannot change them.
static func apply_saved(p_path: String = DEFAULT_PATH, force: bool = false) -> ControlsConfig:
	if not force and p_path == DEFAULT_PATH and DisplayServer.get_name() == "headless":
		return null
	var config := ControlsConfig.new(p_path)
	config.load_file()
	config.apply_to_input_map()
	return config


## Puts the project's own bindings (the defaults) back into the InputMap.
static func restore_input_map_defaults() -> void:
	var config := ControlsConfig.new("")
	config.apply_to_input_map()


# ---------------------------------------------------------------------------------------------
# Defaults, events and tokens
# ---------------------------------------------------------------------------------------------

## The project's own events of an action (first = primary, second = alternative).
static func default_events(action: String) -> Array:
	var setting: Variant = ProjectSettings.get_setting("input/" + action, null)
	var out: Array = []
	if setting is Dictionary:
		for event: Variant in (setting as Dictionary).get("events", []):
			var clean: InputEvent = make_event(event_token(event as InputEvent))
			if clean != null and out.size() < SLOT_COUNT:
				out.append(clean)
	return out


## "k:<physical keycode>" or "m:<mouse button>"; "" for anything else.
static func event_token(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		var code: int = int(key.physical_keycode) if key.physical_keycode != KEY_NONE else int(key.keycode)
		return "k:%d" % code if code != 0 else ""
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return "m:%d" % int(mouse.button_index)
	return ""


static func make_event(token: String) -> InputEvent:
	if token.begins_with("k:") and token.substr(2).is_valid_int():
		var key := InputEventKey.new()
		key.physical_keycode = int(token.substr(2)) as Key
		return key
	if token.begins_with("m:") and token.substr(2).is_valid_int():
		var mouse := InputEventMouseButton.new()
		mouse.button_index = int(token.substr(2)) as MouseButton
		return mouse
	return null


## Keyboard keys and the left, right, middle and extra (side) mouse buttons; not the wheel, not Esc.
static func is_bindable(event: InputEvent) -> bool:
	var token: String = event_token(event)
	if token.begins_with("k:"):
		return int(token.substr(2)) != KEY_NONE
	if token.begins_with("m:"):
		var button: int = int(token.substr(2))
		return button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT or button == MOUSE_BUTTON_MIDDLE or button >= MOUSE_BUTTON_XBUTTON1
	return false


static func is_reserved(event: InputEvent) -> bool:
	return event_token(event) == "k:%d" % KEY_ESCAPE


# ---------------------------------------------------------------------------------------------
# Queries
# ---------------------------------------------------------------------------------------------

func get_actions() -> PackedStringArray:
	return catalog.action_ids


func get_binding(action: String, slot: int) -> InputEvent:
	var slots: Array = _bindings.get(action, [])
	return slots[slot] as InputEvent if slot >= 0 and slot < slots.size() else null


## The events of an action that are set (primary first).
func get_events(action: String) -> Array:
	var out: Array = []
	for slot in SLOT_COUNT:
		var event: InputEvent = get_binding(action, slot)
		if event != null:
			out.append(event)
	return out


## {action, slot} of whoever already uses `event` (ignoring one slot), or an empty dictionary.
func find_owner(event: InputEvent, ignore_action: String = "", ignore_slot: int = -1) -> Dictionary:
	var token: String = event_token(event)
	if token.is_empty():
		return {}
	for action in catalog.action_ids:
		for slot in SLOT_COUNT:
			if action == ignore_action and slot == ignore_slot:
				continue
			var other: InputEvent = get_binding(action, slot)
			if other != null and event_token(other) == token:
				return {"action": action, "slot": slot}
	return {}


## Readable name of an event ("Clic izquierdo", "Shift", "Barra espaciadora").
func event_text(event: InputEvent) -> String:
	return ControlsConfig.describe_event(event, catalog)


static func describe_event(event: InputEvent, p_catalog: ControlsCatalog) -> String:
	var key := event as InputEventKey
	if key != null:
		var code: int = int(key.physical_keycode) if key.physical_keycode != KEY_NONE else int(key.keycode)
		var godot_name: String = OS.get_keycode_string(code as Key)
		return String(p_catalog.key_names.get(godot_name, godot_name))
	var mouse := event as InputEventMouseButton
	if mouse != null:
		var button: int = int(mouse.button_index)
		if p_catalog.mouse_names.has(button):
			return String(p_catalog.mouse_names[button])
		return p_catalog.mouse_other_format % button
	return p_catalog.empty_slot_text


## What the player should read for an action RIGHT NOW, from the live InputMap: the bound inputs
## joined with " o " ("J o Clic izquierdo"). Names are one word each (non-breaking spaces) so a
## hint can be split on spaces. Falls back to the action name when nothing is bound.
static func input_map_hint(action: StringName, p_catalog: ControlsCatalog = null) -> String:
	var used: ControlsCatalog = p_catalog if p_catalog != null else (load(CATALOG_PATH) as ControlsCatalog)
	var names: PackedStringArray = PackedStringArray()
	if InputMap.has_action(action):
		for event in InputMap.action_get_events(action):
			if is_bindable(event) and names.size() < SLOT_COUNT:
				names.append(describe_event(event, used).replace(" ", HINT_SPACE))
	return " o ".join(names) if not names.is_empty() else String(action)


## Every input bound to a rebindable action in the live InputMap, as hint words (see above).
static func input_map_hint_words(p_catalog: ControlsCatalog = null) -> Dictionary:
	var used: ControlsCatalog = p_catalog if p_catalog != null else (load(CATALOG_PATH) as ControlsCatalog)
	var words: Dictionary = {}
	for action in used.action_ids:
		if not InputMap.has_action(StringName(action)):
			continue
		for event in InputMap.action_get_events(StringName(action)):
			if is_bindable(event):
				words[describe_event(event, used).replace(" ", HINT_SPACE)] = true
	return words


# ---------------------------------------------------------------------------------------------
# Changes
# ---------------------------------------------------------------------------------------------

func reset_to_defaults() -> void:
	_bindings.clear()
	for action in catalog.action_ids:
		var events: Array = ControlsConfig.default_events(action)
		var slots: Array = [null, null]
		for i in mini(events.size(), SLOT_COUNT):
			slots[i] = events[i]
		_bindings[action] = slots


## Binds `event` to a slot. Returns {"result": Result, "action": other, "slot": other_slot}. A used
## input is a CONFLICT (nothing changed): follow up with swap() or leave it.
func try_bind(action: String, slot: int, event: InputEvent) -> Dictionary:
	if not _bindings.has(action) or slot < 0 or slot >= SLOT_COUNT:
		return {"result": Result.INVALID}
	if is_reserved(event):
		return {"result": Result.RESERVED}
	if not is_bindable(event):
		return {"result": Result.INVALID}
	var current: InputEvent = get_binding(action, slot)
	if current != null and event_token(current) == event_token(event):
		return {"result": Result.UNCHANGED}
	var owner: Dictionary = find_owner(event, action, slot)
	if not owner.is_empty():
		return {"result": Result.CONFLICT, "action": owner["action"], "slot": owner["slot"]}
	_set_slot(action, slot, make_event(event_token(event)))
	_fix_primary(action)
	return {"result": Result.OK}


## Gives `event` to (action, slot) and hands that slot's previous input to the slot that held `event`.
## Refused (nothing changes) if that would leave an action without a primary binding.
func swap(action: String, slot: int, event: InputEvent) -> Dictionary:
	var owner: Dictionary = find_owner(event, action, slot)
	if owner.is_empty():
		return try_bind(action, slot, event)
	var previous: InputEvent = get_binding(action, slot)
	var backup: Dictionary = _snapshot()
	_set_slot(String(owner["action"]), int(owner["slot"]), make_event(event_token(previous)) if previous != null else null)
	_set_slot(action, slot, make_event(event_token(event)))
	_fix_primary(String(owner["action"]))
	_fix_primary(action)
	for other_action in catalog.action_ids:
		if get_binding(other_action, SLOT_PRIMARY) == null:
			_bindings = backup
			return {"result": Result.CANNOT_SWAP}
	return {"result": Result.OK, "action": owner["action"], "slot": owner["slot"]}


## Empties the alternative slot. The primary slot can never be cleared.
func clear_slot(action: String, slot: int) -> Result:
	if not _bindings.has(action) or slot < 0 or slot >= SLOT_COUNT:
		return Result.INVALID
	if slot == SLOT_PRIMARY:
		return Result.LAST_BINDING
	if get_binding(action, slot) == null:
		return Result.UNCHANGED
	_set_slot(action, slot, null)
	return Result.OK


func _set_slot(action: String, slot: int, event: InputEvent) -> void:
	var slots: Array = _bindings[action]
	slots[slot] = event


## An action whose primary slot got emptied promotes its alternative to primary.
func _fix_primary(action: String) -> void:
	if get_binding(action, SLOT_PRIMARY) == null and get_binding(action, SLOT_ALTERNATIVE) != null:
		var slots: Array = _bindings[action]
		slots[SLOT_PRIMARY] = slots[SLOT_ALTERNATIVE]
		slots[SLOT_ALTERNATIVE] = null


func _snapshot() -> Dictionary:
	var copy: Dictionary = {}
	for action: String in _bindings:
		var slots: Array = []
		for event: Variant in _bindings[action]:
			slots.append(make_event(event_token(event as InputEvent)) if event != null else null)
		copy[action] = slots
	return copy


# ---------------------------------------------------------------------------------------------
# InputMap and file
# ---------------------------------------------------------------------------------------------

## Replaces the events of every rebindable action with the current bindings.
func apply_to_input_map() -> void:
	for action in catalog.action_ids:
		var action_name := StringName(action)
		if not InputMap.has_action(action_name):
			continue
		InputMap.action_erase_events(action_name)
		for event in get_events(action):
			InputMap.action_add_event(action_name, make_event(event_token(event as InputEvent)))


func save_file() -> bool:
	if path.is_empty():
		return false
	var file := ConfigFile.new()
	for action in catalog.action_ids:
		var tokens: PackedStringArray = PackedStringArray()
		for slot in SLOT_COUNT:
			var event: InputEvent = get_binding(action, slot)
			tokens.append(event_token(event) if event != null else "")
		file.set_value(SECTION, action, tokens)
	return file.save(path) == OK


## Reads the file. A missing or corrupt file leaves the defaults; in a partial or damaged one every
## valid action keeps its entry and the rest fall back to their defaults. Never raises and never
## rewrites the file (only a later save does). Returns true if the file was read.
func load_file() -> bool:
	reset_to_defaults()
	if path.is_empty() or not FileAccess.file_exists(path):
		file_status = FileStatus.MISSING
		return false
	# Garbage is refused before ConfigFile sees it (its parser would print engine errors).
	if not _looks_like_config(FileAccess.get_file_as_string(path)):
		file_status = FileStatus.CORRUPT
		return false
	var file := ConfigFile.new()
	if file.load(path) != OK:
		file_status = FileStatus.CORRUPT
		return false
	var valid: int = 0
	var parsed: Dictionary = {}
	for action in catalog.action_ids:
		if not file.has_section_key(SECTION, action):
			continue
		var slots: Variant = _parse_entry(action, file.get_value(SECTION, action))
		if slots != null:
			parsed[action] = slots
			valid += 1
	# Saved entries win over defaults. An input claimed by two saved entries keeps its first owner (the
	# other action goes back to its defaults); a default that would repeat a saved input is dropped.
	var used: Dictionary = {}
	var saved: Dictionary = {}
	for action in catalog.action_ids:
		if parsed.has(action) and not _collides(parsed[action], used):
			saved[action] = parsed[action]
			_claim(parsed[action], used)
		elif parsed.has(action):
			valid -= 1
	for action in catalog.action_ids:
		if saved.has(action):
			_bindings[action] = saved[action]
			continue
		var slots: Array = _without_used(_bindings[action], used)
		_bindings[action] = slots
		_claim(slots, used)
	for action in catalog.action_ids:
		if get_binding(action, SLOT_PRIMARY) == null:
			reset_to_defaults()
			file_status = FileStatus.CORRUPT
			return false
	file_status = FileStatus.OK if valid == catalog.action_ids.size() else FileStatus.PARTIAL
	return true


func _claim(slots: Array, used: Dictionary) -> void:
	for event: Variant in slots:
		if event != null:
			used[event_token(event as InputEvent)] = true


## The slots without the inputs already `used`; an alternative alone becomes the primary.
func _without_used(slots: Array, used: Dictionary) -> Array:
	var kept: Array = [null, null]
	for i in SLOT_COUNT:
		var event: Variant = slots[i]
		if event != null and not used.has(event_token(event as InputEvent)):
			kept[i] = event
	if kept[SLOT_PRIMARY] == null and kept[SLOT_ALTERNATIVE] != null:
		kept[SLOT_PRIMARY] = kept[SLOT_ALTERNATIVE]
		kept[SLOT_ALTERNATIVE] = null
	return kept


## True if every line is blank, a comment, a [section] or `name = value`, and [controls] is there.
func _looks_like_config(text: String) -> bool:
	if not text.contains("[" + SECTION + "]"):
		return false
	var line_pattern := RegEx.new()
	line_pattern.compile("^(\\[[A-Za-z0-9_]+\\]|[A-Za-z0-9_]+\\s*=\\s*\\S.*)$")
	for raw in text.split("\n"):
		var line: String = raw.strip_edges()
		if line.is_empty() or line.begins_with(";") or line.begins_with("#"):
			continue
		if line_pattern.search(line) == null:
			return false
	return true


func _collides(slots: Array, used: Dictionary) -> bool:
	for event: Variant in slots:
		if event != null and used.has(event_token(event as InputEvent)):
			return true
	return false


## Two tokens ("k:32", "m:1" or "") of a file entry -> [primary, alternative]; null if unusable.
func _parse_entry(action: String, value: Variant) -> Variant:
	if not (value is PackedStringArray or value is Array):
		return null
	var tokens: Array = []
	for token: Variant in value:
		tokens.append(String(token) if token is String else "")
	if tokens.is_empty():
		return null
	var slots: Array = [null, null]
	var seen: Dictionary = {}
	for i in mini(tokens.size(), SLOT_COUNT):
		var token: String = tokens[i]
		if token.is_empty():
			continue
		var event: InputEvent = make_event(token)
		if event == null or not is_bindable(event) or seen.has(token):
			return null
		if is_reserved(event) and action != RESERVED_ACTION:
			return null
		seen[token] = true
		slots[i] = event
	if slots[SLOT_PRIMARY] == null:
		if slots[SLOT_ALTERNATIVE] == null:
			return null
		slots[SLOT_PRIMARY] = slots[SLOT_ALTERNATIVE]
		slots[SLOT_ALTERNATIVE] = null
	return slots
