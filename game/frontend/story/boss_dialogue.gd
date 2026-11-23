class_name BossDialogue
extends Node
## The guardian speaks: 2-3 subtitle lines when the fight starts (plus at most one extra line that
## depends on the player's adaptive profile) and one line when it falls. A subtitle at the bottom of
## the screen, no new UI system: the confirm action (Enter) just skips the lines and the event is NOT
## consumed. Said once per encounter: after a retry or a respawn mid-fight the lines are not repeated
## (they come back in a new run). Text lives in StoryTexts. Presentation only.
## Phase 15b: when the level has an active BossIntro the guardian's lines are NOT said here: the intro
## calls `play_intro` (the guardian's greeting, then the duck's story, in the same subtitle) while the boss
## is still inactive and the player is locked, and waits for `sequence_finished`.
## Phase 15f: EVERY line of that intro (the guardian's and the duck's) waits for the player: a typewriter types the line, the
## confirm action first completes it and then moves to the next, a prompt ("Enter ▸", with the key the player has bound) shows
## when the line is complete, and holding the confirm action skips the whole intro. No timer ever advances an intro line (the
## lines said at other moments, like the guardian's last words, keep their timing).

const LAYER: int = 62
const TYPE_SPEED: float = 35.0
## A typed line stays HOLD_BASE s plus 1 s per HOLD_CHARS characters, HOLD_MIN-HOLD_MAX s.
const HOLD_BASE: float = 0.8
const HOLD_CHARS: float = 20.0
const HOLD_MIN: float = 2.0
const HOLD_MAX: float = 4.0
## The duck's story is paced faster so that 6 lines of at most 110 characters last about 25 s.
const INTRO_TYPE_SPEED: float = 42.0
const INTRO_HOLD: float = 1.2
## Presses are ignored this long after an intro sequence starts (a leftover press must not skip it).
const INTRO_INPUT_GRACE: float = 0.4

## Emitted when a sequence of lines ends (all said, or skipped with the confirm action).
signal sequence_finished(skipped: bool)

## Scene file path -> true while that level's boss lines were already said in this run.
static var _spoken: Dictionary = {}

@export var texts: StoryTexts

## How many lines of a sequence have been shown (the tests read it).
var lines_shown: int = 0
var sequence_count: int = 0
## How many defeat dialogues played (it is at most one per defeat).
var defeat_sequences: int = 0

var _level: Node = null
var _boss: Node = null
var _speaker: String = ""
## Pending lines: a String (the guardian) or a Dictionary {speaker, text, intro} (the duck's story).
var _queue: Array = []
var _sequence_open: bool = false
var _grace_left: float = 0.0
var _line_intro: bool = false
var _line_time: float = 0.0
var _line_hold: float = 0.0
var _line_active: bool = false
## The intro sequence is advanced by the player only (see the class comment).
var _manual: bool = false
var _typed_done: bool = false
var _hold_time: float = 0.0
var _prompt_label: Label = null
var _hint_label: Label = null
var _defeat_said: bool = false
## The player and the fragment drop that the defeat dialogue holds while it plays.
var _held_player: Player = null
var _held_drop: SoulFragmentDrop = null
## The soul spirit of the fallen guardian (Phase 15r): it says the last words, then dissolves into the fragment. At most one per defeat.
var _spirit: GuardianSpirit = null
var _spirit_speaker: String = ""
## How many spirits appeared (the tests read it; it is at most one per defeat).
var spirits_spawned: int = 0
var _layer: CanvasLayer = null
var _label: Label = null


## Forgets which boss lines were said (a new run starts).
static func forget_all() -> void:
	_spoken.clear()


func _ready() -> void:
	if texts == null:
		texts = load(StoryTexts.DEFAULT_PATH) as StoryTexts
	_level = get_parent()
	if _level == null:
		return
	_boss = _level.get(&"boss") as Node
	var encounter: Node = _level.get(&"encounter") as Node
	if _boss == null or encounter == null:
		set_process(false)
		set_process_input(false)
		return
	encounter.connect(&"encounter_started", _on_encounter_started)
	_boss.connect(&"defeated", _on_boss_defeated)
	_build()


func _exit_tree() -> void:
	_release_defeat_holds()
	if is_instance_valid(_spirit):
		_spirit.queue_free()
	_queue.clear()
	AudioDirector.release_music_duck(self)


## The seconds a line of the duck's story stays on screen (the tests add them up).
static func intro_line_seconds(text: String) -> float:
	return float(text.length()) / INTRO_TYPE_SPEED + INTRO_HOLD


## True if the boss lines of the scene file `key` were already said in this run.
static func was_spoken(key: String) -> bool:
	return bool(_spoken.get(key, false))


static func mark_spoken(key: String) -> void:
	_spoken[key] = true


func _process(delta: float) -> void:
	_grace_left = maxf(_grace_left - delta, 0.0)
	if not _line_active:
		return
	_line_time += delta
	if _manual:
		_process_manual(delta)
		return
	var typed: int = int(_line_time * (INTRO_TYPE_SPEED if _line_intro else TYPE_SPEED))
	_label.visible_characters = mini(typed, _label.text.length())
	if _line_time >= _line_hold:
		_next_line()


func _input(event: InputEvent) -> void:
	# Not consumed: the player keeps full control while the guardian talks.
	if not _line_active or _grace_left > 0.0 or not event.is_action_pressed("ui_accept"):
		return
	if _manual:
		advance()
	else:
		skip()


## The intro line types itself; there is no timer to move on (see the class comment).
func _process_manual(delta: float) -> void:
	if not _typed_done:
		var typed: int = int(_line_time * INTRO_TYPE_SPEED)
		_label.visible_characters = mini(typed, _label.text.length())
		if typed >= _label.text.length():
			_finish_typing()
	elif _prompt_label != null:
		var blink: float = 1.0 if not GameSettings.is_corruption_effects_enabled() else 0.65 + 0.35 * sin(_line_time * TAU * 1.2)
		_prompt_label.modulate.a = blink
	# Holding the confirm action skips the whole intro.
	if _grace_left <= 0.0 and Input.is_action_pressed("ui_accept"):
		_hold_time += delta
		if _hold_time >= texts.intro_skip_hold_seconds:
			skip()
	else:
		_hold_time = 0.0


## One confirm press: completes the line being typed, or moves to the next line when it is complete.
func advance() -> void:
	if not _line_active or not _manual:
		return
	if not _typed_done:
		_label.visible_characters = -1
		_finish_typing()
	else:
		_next_line()


func _finish_typing() -> void:
	_typed_done = true
	_prompt_label.text = texts.advance_prompt_format % confirm_key_name()
	_prompt_label.visible = true


## The name of the key bound to the confirm action (follows any remap of the InputMap).
static func confirm_key_name() -> String:
	for input_event in InputMap.action_get_events(&"ui_accept"):
		var key := input_event as InputEventKey
		if key != null:
			var code: int = int(key.keycode) if key.keycode != KEY_NONE else int(key.physical_keycode)
			return OS.get_keycode_string(code as Key)
	return "Enter"


## Drops every pending line and hides the subtitle.
func skip() -> void:
	_queue.clear()
	_line_active = false
	_manual = false
	_label.visible = false
	_hide_prompts()
	AudioDirector.release_music_duck(self)
	_close_sequence(true)


func _hide_prompts() -> void:
	if _prompt_label != null:
		_prompt_label.visible = false
	if _hint_label != null:
		_hint_label.visible = false


func is_speaking() -> bool:
	return _line_active


func current_text() -> String:
	return _label.text if _line_active else ""


func _on_encounter_started() -> void:
	# An active boss intro says the greeting itself (before the boss wakes up).
	var intro: Node = _level.get_node_or_null(^"BossIntro")
	if intro != null and intro.get(&"active") == true:
		return
	var key: String = _level.scene_file_path
	if bool(_spoken.get(key, false)):
		return
	_spoken[key] = true
	var story: BossStory = texts.get_boss(_level_number())
	if story == null:
		return
	_say(story.lines_for(GameState.adaptive_profile))


func _on_boss_defeated(_defeated: Node) -> void:
	if _defeat_said:
		return
	_defeat_said = true
	_spoken.erase(_level.scene_file_path)
	var story: BossStory = texts.get_boss(_level_number())
	if story == null or story.defeat_lines.is_empty():
		return
	# The guardian's last words come BEFORE the fragment decision: the fragment waits, the player is locked and safe, the lines advance
	# only with the confirm action (hold to skip), and everything is given back when they end (or the node goes away).
	_held_drop = _level.get(&"fragment_drop") as SoulFragmentDrop
	if _held_drop != null:
		_held_drop.hold(self)
	_held_player = _level.get(&"player") as Player
	if _held_player != null:
		_held_player.set_input_locked(true)
		_held_player.story_invulnerable = true
	_spirit_speaker = story.spirit_speaker
	_spawn_spirit()
	get_tree().create_timer(texts.defeat_dialogue_delay).timeout.connect(_start_defeat_dialogue.bind(story))


func _start_defeat_dialogue(story: BossStory) -> void:
	if not is_inside_tree() or not _defeat_said:
		_release_defeat_holds()
		return
	var none: Array[String] = []
	var lines: Array[String] = []
	lines.append_array(story.defeat_lines)
	if not play_intro(lines, none, texts.duck_speaker, _spirit_speaker):
		_release_defeat_holds()
		return
	defeat_sequences += 1
	if not sequence_finished.is_connected(_on_defeat_finished):
		sequence_finished.connect(_on_defeat_finished, CONNECT_ONE_SHOT)


func _on_defeat_finished(skipped: bool) -> void:
	if is_instance_valid(_spirit) and not _spirit.is_done():
		if skipped:
			# A skip goes straight to the crystal.
			_spirit.vanish_now()
			_release_defeat_holds()
		else:
			# The spirit comes apart into particles that stream into the fragment; the fragment appears when they arrive.
			_spirit.dissolved.connect(_release_defeat_holds, CONNECT_ONE_SHOT)
			_spirit.dissolve()
		return
	_release_defeat_holds()


## Gives back the player and lets the fragment appear (idempotent).
func _release_defeat_holds() -> void:
	if is_instance_valid(_held_drop):
		_held_drop.release(self)
		_held_drop.expedite()
	_held_drop = null
	if is_instance_valid(_held_player):
		_held_player.set_input_locked(false)
		_held_player.story_invulnerable = false
	_held_player = null


## The soul of the guardian appears where it fell (its body fades meanwhile): the same figure in translucent blue.
func _spawn_spirit() -> void:
	if is_instance_valid(_spirit) or _boss == null or _level == null:
		return
	var at: Vector2 = (_boss as Node2D).global_position
	var rig_scale: Vector2 = Vector2.ONE * DuckRig.BOSS_SCALE
	var look: DuckRig.Look = DuckRig.Look.BOSS_WOODCUTTER
	var visual: Node = _boss.get_node_or_null(^"Visual")
	if visual != null:
		var rig: DuckRig = visual.get(&"rig") as DuckRig
		if rig != null:
			at = rig.global_position
			rig_scale = rig.global_scale.abs()
			look = rig.look
	var target: Vector2 = (_boss as Node2D).global_position
	if _held_drop != null:
		target += _held_drop.spawn_offset
	_spirit = GuardianSpirit.new()
	_spirit.setup(look, at, rig_scale, not GameSettings.is_corruption_effects_enabled(), target)
	_level.add_child(_spirit)
	spirits_spawned += 1


func _level_number() -> int:
	return BossNames.level_number_of(_level)


## Phase 15b: the guardian's greeting followed by the duck's story, as ONE skippable sequence. Returns false
## if there is nothing to say. `sequence_finished` is emitted at the end.
func play_intro(greeting: Array[String], duck_lines: Array[String], duck_speaker: String, guardian_speaker: String = "") -> bool:
	if greeting.is_empty() and duck_lines.is_empty():
		return false
	var info: Dictionary = BossNames.info_for(_boss, _level)
	_speaker = guardian_speaker if not guardian_speaker.is_empty() else String(info.get("name", ""))
	_queue.clear()
	_queue.append_array(greeting)
	for line in duck_lines:
		_queue.append({"speaker": duck_speaker, "text": line, "intro": true})
	_sequence_open = true
	_manual = true
	_hold_time = 0.0
	_grace_left = INTRO_INPUT_GRACE
	sequence_count += 1
	_hint_label.text = texts.intro_skip_hint_format % confirm_key_name()
	_hint_label.visible = true
	# The music steps back while somebody talks.
	AudioDirector.set_music_duck(self, AudioEvents.get_default().duck_dialogue_db)
	_next_line()
	return true


func _close_sequence(skipped: bool) -> void:
	if not _sequence_open:
		return
	_sequence_open = false
	sequence_finished.emit(skipped)


func _say(lines: Array[String]) -> void:
	if lines.is_empty():
		return
	var info: Dictionary = BossNames.info_for(_boss, _level)
	_speaker = String(info.get("name", ""))
	_queue.clear()
	_queue.append_array(lines)
	sequence_count += 1
	_sequence_open = true
	_manual = false
	_grace_left = 0.0
	# The music steps back while the guardian talks.
	AudioDirector.set_music_duck(self, AudioEvents.get_default().duck_dialogue_db)
	_next_line()


func _next_line() -> void:
	if _queue.is_empty():
		_line_active = false
		_manual = false
		_label.visible = false
		_hide_prompts()
		AudioDirector.release_music_duck(self)
		_close_sequence(false)
		return
	var entry: Variant = _queue.pop_front()
	var text: String = ""
	var speaker: String = _speaker
	_line_intro = false
	if entry is Dictionary:
		text = String((entry as Dictionary)["text"])
		speaker = String((entry as Dictionary)["speaker"])
		_line_intro = bool((entry as Dictionary).get("intro", false))
	else:
		text = String(entry)
	_label.text = "%s: %s" % [speaker, text] if not speaker.is_empty() else text
	_label.visible_characters = 0
	_label.visible = true
	_line_time = 0.0
	_typed_done = false
	_hold_time = 0.0
	if _prompt_label != null:
		_prompt_label.visible = false
	if _line_intro:
		_line_hold = BossDialogue.intro_line_seconds(text)
	else:
		_line_hold = float(text.length()) / TYPE_SPEED + clampf(HOLD_BASE + float(text.length()) / HOLD_CHARS, HOLD_MIN, HOLD_MAX)
	_line_active = true
	lines_shown += 1


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = LAYER
	add_child(_layer)
	_label = Label.new()
	_label.theme_type_variation = &"SceneLabel"
	_label.add_theme_font_size_override("font_size", 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 160.0
	_label.offset_right = -160.0
	_label.offset_top = -150.0
	_label.offset_bottom = -70.0
	_label.visible = false
	_layer.add_child(_label)
	_label.theme = load("res://frontend/ui/theme/quack_theme.tres") as Theme
	# The prompt after each intro line and the hold-to-skip hint (visible only while an intro sequence plays).
	_prompt_label = Label.new()
	_prompt_label.theme_type_variation = &"SceneLabel"
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.anchor_left = 0.0
	_prompt_label.anchor_right = 1.0
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = 160.0
	_prompt_label.offset_right = -160.0
	_prompt_label.offset_top = -66.0
	_prompt_label.offset_bottom = -36.0
	_prompt_label.visible = false
	_layer.add_child(_prompt_label)
	_prompt_label.theme = _label.theme
	_hint_label = Label.new()
	_hint_label.theme_type_variation = &"SceneLabel"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.anchor_left = 0.0
	_hint_label.anchor_right = 1.0
	_hint_label.anchor_top = 1.0
	_hint_label.anchor_bottom = 1.0
	_hint_label.offset_left = 160.0
	_hint_label.offset_right = -160.0
	_hint_label.offset_top = -34.0
	_hint_label.offset_bottom = -10.0
	_hint_label.visible = false
	_layer.add_child(_hint_label)
	_hint_label.theme = _label.theme
