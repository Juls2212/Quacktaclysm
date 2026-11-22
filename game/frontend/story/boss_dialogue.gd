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
var _defeat_said: bool = false
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
	var typed: int = int(_line_time * (INTRO_TYPE_SPEED if _line_intro else TYPE_SPEED))
	_label.visible_characters = mini(typed, _label.text.length())
	if _line_time >= _line_hold:
		_next_line()


func _input(event: InputEvent) -> void:
	# Not consumed: the player keeps full control while the guardian talks.
	if _line_active and _grace_left <= 0.0 and event.is_action_pressed("ui_accept"):
		skip()


## Drops every pending line and hides the subtitle.
func skip() -> void:
	_queue.clear()
	_line_active = false
	_label.visible = false
	AudioDirector.release_music_duck(self)
	_close_sequence(true)


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
	if story != null and not story.defeat_line.is_empty():
		_say([story.defeat_line])


func _level_number() -> int:
	return BossNames.level_number_of(_level)


## Phase 15b: the guardian's greeting followed by the duck's story, as ONE skippable sequence. Returns false
## if there is nothing to say. `sequence_finished` is emitted at the end.
func play_intro(greeting: Array[String], duck_lines: Array[String], duck_speaker: String) -> bool:
	if greeting.is_empty() and duck_lines.is_empty():
		return false
	var info: Dictionary = BossNames.info_for(_boss, _level)
	_speaker = String(info.get("name", ""))
	_queue.clear()
	_queue.append_array(greeting)
	for line in duck_lines:
		_queue.append({"speaker": duck_speaker, "text": line, "intro": true})
	_sequence_open = true
	_grace_left = INTRO_INPUT_GRACE
	sequence_count += 1
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
	_grace_left = 0.0
	# The music steps back while the guardian talks.
	AudioDirector.set_music_duck(self, AudioEvents.get_default().duck_dialogue_db)
	_next_line()


func _next_line() -> void:
	if _queue.is_empty():
		_line_active = false
		_label.visible = false
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
