class_name ControlsEditor
extends VBoxContainer
## The "Controles" page of the options menus: one row per rebindable action with its primary and
## alternative binding. Click a slot and press a key or a mouse button to rebind it; "×" clears the
## alternative; a used input asks "Intercambiar / Cancelar"; "Restaurar valores por defecto" resets.
## Works with keyboard (focus + Intro) and mouse, and while the game is paused. While it waits for
## an input it consumes the event in `_input`, so the key never reaches the game or the menus.
## Changes are applied to the InputMap and written to user://controls.cfg at once (ControlsConfig).
## All texts come from the ControlsCatalog resource.

signal closed
signal changed

const SLOT_SIZE: Vector2 = Vector2(120, 28)

@export var catalog: ControlsCatalog

## The bindings being edited; tests inject one that points at a temporary file.
var config: ControlsConfig = null

var message_label: Label
var swap_button: Button
var cancel_button: Button
var reset_button: Button
var back_button: Button

var _slot_buttons: Dictionary = {}
var _clear_buttons: Dictionary = {}
var _capture_action: String = ""
var _capture_slot: int = -1
## {action, slot, event, owner_action, owner_slot} while a conflict waits for swap / cancel.
var _pending: Dictionary = {}
var _conflict_row: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_theme_constant_override("separation", 6)
	if catalog == null:
		catalog = load(ControlsConfig.CATALOG_PATH) as ControlsCatalog
	if config == null:
		config = ControlsConfig.new(ControlsConfig.DEFAULT_PATH, catalog)
		config.load_file()
	var title := Label.new()
	title.text = catalog.section_title
	title.theme_type_variation = &"HeaderLabel"
	add_child(title)
	var hint := Label.new()
	hint.text = catalog.hint_text
	hint.theme_type_variation = &"NoteLabel"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(400, 0)
	add_child(hint)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	_add_header(grid)
	for action in catalog.action_ids:
		var action_label := Label.new()
		action_label.text = catalog.get_action_name(action)
		action_label.theme_type_variation = &"NoteLabel"
		action_label.custom_minimum_size = Vector2(130, 0)
		grid.add_child(action_label)
		_slot_buttons[action] = []
		for slot in ControlsConfig.SLOT_COUNT:
			var button := Button.new()
			button.custom_minimum_size = SLOT_SIZE
			button.clip_text = true
			button.pressed.connect(begin_capture.bind(action, slot))
			grid.add_child(button)
			(_slot_buttons[action] as Array).append(button)
		var clear := Button.new()
		clear.text = catalog.clear_text
		clear.tooltip_text = catalog.clear_tooltip
		clear.custom_minimum_size = Vector2(28, 28)
		clear.pressed.connect(clear_alternative.bind(action))
		grid.add_child(clear)
		_clear_buttons[action] = clear
	message_label = Label.new()
	message_label.theme_type_variation = &"NoteLabel"
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.custom_minimum_size = Vector2(400, 40)
	add_child(message_label)
	_conflict_row = HBoxContainer.new()
	_conflict_row.add_theme_constant_override("separation", 10)
	_conflict_row.visible = false
	add_child(_conflict_row)
	swap_button = Button.new()
	swap_button.text = catalog.swap_text
	swap_button.pressed.connect(swap_pending)
	_conflict_row.add_child(swap_button)
	cancel_button = Button.new()
	cancel_button.text = catalog.cancel_text
	cancel_button.pressed.connect(cancel_pending)
	_conflict_row.add_child(cancel_button)
	reset_button = Button.new()
	reset_button.text = catalog.reset_text
	reset_button.pressed.connect(reset_defaults)
	add_child(reset_button)
	back_button = Button.new()
	back_button.text = catalog.back_text
	back_button.pressed.connect(close)
	add_child(back_button)
	refresh()
	visible = false


func _add_header(grid: GridContainer) -> void:
	grid.add_child(Control.new())
	for text in [catalog.primary_header, catalog.alternative_header]:
		var label := Label.new()
		label.text = text
		label.theme_type_variation = &"HeaderLabel"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(label)
	grid.add_child(Control.new())


# ---------------------------------------------------------------------------------------------
# Opening and closing
# ---------------------------------------------------------------------------------------------

func open() -> void:
	config.load_file()
	_end_capture()
	_clear_pending()
	_set_message("")
	refresh()
	visible = true
	(_slot_buttons[catalog.action_ids[0]][0] as Button).grab_focus()


func close() -> void:
	if not visible:
		return
	_end_capture()
	_clear_pending()
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func is_capturing() -> bool:
	return not _capture_action.is_empty()


func has_pending_conflict() -> bool:
	return not _pending.is_empty()


# ---------------------------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if visible and is_capturing() and process_capture(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if has_pending_conflict():
		cancel_pending()
	else:
		close()
	get_viewport().set_input_as_handled()


## Starts waiting for the next key or mouse button for (action, slot).
func begin_capture(action: String, slot: int) -> void:
	if has_pending_conflict() or not _slot_buttons.has(action):
		return
	_capture_action = action
	_capture_slot = slot
	_set_message("")
	refresh()


## Feeds one event to the capture. Returns true if the event was used (and must not go anywhere else).
func process_capture(event: InputEvent) -> bool:
	if not is_capturing():
		return false
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return key.pressed
		if key.physical_keycode == KEY_ESCAPE or key.keycode == KEY_ESCAPE:
			_end_capture()
			_set_message(catalog.capture_cancelled_text)
			refresh()
			return true
		_bind_captured(event)
		return true
	var mouse := event as InputEventMouseButton
	if mouse != null:
		if not mouse.pressed:
			return false
		_bind_captured(event)
		return true
	return false


func _bind_captured(event: InputEvent) -> void:
	var action: String = _capture_action
	var slot: int = _capture_slot
	var outcome: Dictionary = config.try_bind(action, slot, event)
	_end_capture()
	match int(outcome["result"]):
		ControlsConfig.Result.OK:
			_persist()
			_set_message(catalog.changed_format % [catalog.get_action_name(action), config.event_text(event)])
		ControlsConfig.Result.CONFLICT:
			_pending = {"action": action, "slot": slot, "event": event, "owner_action": outcome["action"], "owner_slot": outcome["slot"]}
			_set_message(catalog.conflict_format % [config.event_text(event), catalog.get_action_name(String(outcome["action"]))])
			_conflict_row.visible = true
			swap_button.grab_focus()
		ControlsConfig.Result.RESERVED:
			_set_message(catalog.esc_reserved_text)
		ControlsConfig.Result.UNCHANGED:
			_set_message("")
		_:
			_set_message(catalog.invalid_text)
	refresh()


func swap_pending() -> void:
	if not has_pending_conflict():
		return
	var pending: Dictionary = _pending
	var outcome: Dictionary = config.swap(String(pending["action"]), int(pending["slot"]), pending["event"] as InputEvent)
	_clear_pending()
	if int(outcome["result"]) == ControlsConfig.Result.OK:
		_persist()
		_set_message(catalog.changed_format % [catalog.get_action_name(String(pending["action"])), config.event_text(pending["event"] as InputEvent)])
	else:
		_set_message(catalog.cannot_swap_text)
	refresh()
	_focus_slot(String(pending["action"]), int(pending["slot"]))


func cancel_pending() -> void:
	if not has_pending_conflict():
		return
	var pending: Dictionary = _pending
	_clear_pending()
	_set_message(catalog.cancelled_text)
	refresh()
	_focus_slot(String(pending["action"]), int(pending["slot"]))


func clear_alternative(action: String) -> void:
	if has_pending_conflict():
		return
	_end_capture()
	if config.clear_slot(action, ControlsConfig.SLOT_ALTERNATIVE) == ControlsConfig.Result.OK:
		_persist()
		_set_message(catalog.cleared_format % catalog.get_action_name(action))
	refresh()


func reset_defaults() -> void:
	_end_capture()
	_clear_pending()
	config.reset_to_defaults()
	_persist()
	_set_message(catalog.reset_done_text)
	refresh()


# ---------------------------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------------------------

## Redraws every slot: the readable binding, "Pulsa una tecla…" for the one being captured.
func refresh() -> void:
	var locked: bool = has_pending_conflict()
	for action in catalog.action_ids:
		var buttons: Array = _slot_buttons[action]
		for slot in ControlsConfig.SLOT_COUNT:
			var button: Button = buttons[slot]
			if is_capturing() and _capture_action == action and _capture_slot == slot:
				button.text = catalog.capture_prompt
			else:
				var event: InputEvent = config.get_binding(action, slot)
				button.text = config.event_text(event) if event != null else catalog.empty_slot_text
			button.disabled = locked
		var clear: Button = _clear_buttons[action]
		clear.disabled = locked or config.get_binding(action, ControlsConfig.SLOT_ALTERNATIVE) == null
	reset_button.disabled = locked
	back_button.disabled = locked


func get_slot_text(action: String, slot: int) -> String:
	return (_slot_buttons[action][slot] as Button).text


func _set_message(text: String) -> void:
	message_label.text = text


func _persist() -> void:
	config.apply_to_input_map()
	if not config.save_file():
		_set_message(catalog.save_failed_text)
	changed.emit()


func _end_capture() -> void:
	_capture_action = ""
	_capture_slot = -1


func _clear_pending() -> void:
	_pending = {}
	_conflict_row.visible = false


func _focus_slot(action: String, slot: int) -> void:
	if visible and _slot_buttons.has(action):
		(_slot_buttons[action][slot] as Button).grab_focus()
