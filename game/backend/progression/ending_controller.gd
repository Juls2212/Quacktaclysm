class_name EndingController
extends Control
## The ending scene. The ending is chosen ONLY by the majority of the three decisions (EndingSelector:
## more souls kept than released = «Estrellas que suben», otherwise «El acantilado»). It plays the ending's cinematic (EndingCinematic: a
## beat list over a scene drawn by code, hold confirm to skip) and then shows the summary card: the counters and the NAMES of the souls
## released and kept, with a button back to the main menu. It never writes GameState (the "ending"
## checkpoint marker stays, so "Continuar" reopens this scene) and needs no network. All texts live
## in StoryTexts. Automated (headless) runs go straight to the card unless `skip_reel_when_headless`
## is turned off.
## Phase 15t: after the cinematic that finishes by itself comes the credits and statistics sequence (EndingCredits: the night sky, the credits,
## the animated summary of the statistics); then the final card (the line of support and the way back). A skip goes straight to the final card.

signal reel_finished
signal card_shown
## The credits sequence began / ended (Phase 15t).
signal credits_started
signal credits_finished

@export var texts: StoryTexts
@export var skip_reel_when_headless: bool = true

## The ending id shown (ending_kept / ending_released).
var shown_variant: String = ""
## The summary sentence of that ending.
var shown_text: String = ""
## The closing text of the epilogue variant (Phase 16c) and the variant (0 to 2): it never changes which ending plays.
var shown_epilogue: String = ""
var shown_epilogue_variant: int = 0
var epilogue_label: Label = null
## The line of support of the final card (only the ending «El acantilado» has one).
var support_label: Label = null
var released_names: Array[String] = []
var kept_names: Array[String] = []
var reel: EndingCinematic = null
## The credits and statistics sequence (null before it starts and in automated runs that go straight to the card).
var credits: EndingCredits = null
var credits_played: bool = false
var _music_slot: EndingMusicSlot = null
var card_visible: bool = false

@onready var title_label: Label = $Center/Box/TitleLabel
@onready var ending_label: Label = $Center/Box/EndingLabel
@onready var released_label: Label = $Center/Box/ReleasedLabel
@onready var kept_label: Label = $Center/Box/KeptLabel
@onready var released_names_label: Label = $Center/Box/ReleasedNamesLabel
@onready var kept_names_label: Label = $Center/Box/KeptNamesLabel
@onready var back_button: Button = $Center/Box/BackButton
@onready var box: Control = $Center


func _ready() -> void:
	if texts == null:
		texts = load(StoryTexts.DEFAULT_PATH) as StoryTexts
	shown_variant = EndingSelector.ending_id_for(GameState.souls_released, GameState.souls_kept)
	var story: EndingStory = texts.get_ending(shown_variant)
	released_names = EndingSelector.soul_names(GameState.decisions, texts, GameState.CHOICE_RELEASED)
	kept_names = EndingSelector.soul_names(GameState.decisions, texts, GameState.CHOICE_KEPT)
	shown_text = story.summary_line if story != null else ""
	title_label.text = story.title if story != null else ""
	ending_label.text = shown_text
	released_label.text = texts.summary_released_format % GameState.souls_released
	kept_label.text = texts.summary_kept_format % GameState.souls_kept
	released_names_label.text = texts.summary_released_names_format % _names_text(released_names)
	kept_names_label.text = texts.summary_kept_names_format % _names_text(kept_names)
	back_button.text = texts.summary_back_text
	shown_epilogue_variant = GameState.director.epilogue_variant()
	shown_epilogue = texts.epilogue_text(shown_variant, shown_epilogue_variant)
	_build_epilogue_label()
	_build_support_label(story)
	back_button.pressed.connect(_on_back_pressed)
	if skip_reel_when_headless and DisplayServer.get_name() == "headless":
		_show_card()
	else:
		box.visible = false
		_play_reel(story)


## The subtitle lines of the shown ending (names filled in), as the sequence plays them.
func get_reel_lines() -> Array[String]:
	var short_released: Array[String] = EndingSelector.soul_names(GameState.decisions, texts, GameState.CHOICE_RELEASED, true)
	var short_kept: Array[String] = EndingSelector.soul_names(GameState.decisions, texts, GameState.CHOICE_KEPT, true)
	return texts.ending_lines(shown_variant, short_released, short_kept)


func _play_reel(story: EndingStory) -> void:
	reel = EndingCinematic.new()
	reel.style = story.style if story != null else "kept"
	reel.beats = story.beats if story != null else null
	reel.title_text = title_label.text
	reel.lines = get_reel_lines()
	reel.skip_hint_text = texts.hold_skip_hint
	reel.hold_seconds = 1.2
	# The corruption the duck shows scales with the fragments kept.
	reel.corruption_scale = clampf(float(GameState.souls_kept) / 3.0, 0.34, 1.0)
	# Each ending has its own music, processed by code (the slots of the audio table).
	var audio: AudioEvents = AudioEvents.get_default()
	reel.music_slot = audio.ending_kept_music if shown_variant == StoryTexts.ENDING_KEPT else audio.ending_released_music
	_music_slot = reel.music_slot
	reel.line_changed.connect(_on_reel_line)
	reel.finished.connect(_on_reel_finished)
	add_child(reel)


## The grandfather's lines are marked with a soft sound (an existing event), except after the cut: there only the wind is heard.
func _on_reel_line(_index: int, text: String) -> void:
	var beat: EndingBeat = reel.current_beat() if reel != null else null
	if text.begins_with(texts.elder_speaker + ":") and (beat == null or beat.voiced):
		AudioDirector.play_event(&"grandfather_voice")


func _on_reel_finished(skipped: bool) -> void:
	reel = null
	reel_finished.emit()
	if skipped:
		_show_card()
	else:
		_play_credits()


## The credits and the statistics (Phase 15t): the white of the cut clears into the night sky of the ending, the credits roll, the numbers count up.
func _play_credits() -> void:
	credits = EndingCredits.new()
	credits.style = "kept" if shown_variant == StoryTexts.ENDING_KEPT else "released"
	credits.music_slot = _music_slot
	credits.stats_title = title_label.text
	credits.stat_rows = stat_rows()
	credits.skip_hint_text = texts.hold_skip_hint
	credits.start_white = true
	credits.finished.connect(_on_credits_finished)
	add_child(credits)
	credits_played = true
	credits_started.emit()


## The statistics the card always showed, as the rows of the animated summary: the two counters (they count up) and the two lists of names.
func stat_rows() -> Array:
	return [
		{"format": texts.summary_released_format, "value": GameState.souls_released},
		{"format": texts.summary_kept_format, "value": GameState.souls_kept},
		{"text": released_names_label.text},
		{"text": kept_names_label.text},
	]


func _on_credits_finished(_skipped: bool) -> void:
	credits_finished.emit()
	_show_card()


func _show_card() -> void:
	# After the animated summary the statistics are not shown twice: the card is the ending sentence, the epilogue, the line of support and the way back.
	if credits_played:
		for stat: Control in [released_label, kept_label, released_names_label, kept_names_label]:
			stat.visible = false
	box.visible = true
	card_visible = true
	back_button.grab_focus()
	card_shown.emit()


## A closing line under the ending sentence of the card (built in code, hidden when the ending has no epilogue text).
func _build_epilogue_label() -> void:
	epilogue_label = Label.new()
	epilogue_label.name = "EpilogueLabel"
	epilogue_label.text = shown_epilogue
	epilogue_label.visible = not shown_epilogue.is_empty()
	epilogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	epilogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	epilogue_label.custom_minimum_size = Vector2(640.0, 0.0)
	epilogue_label.add_theme_font_override(&"font", ending_label.get_theme_font(&"font"))
	epilogue_label.add_theme_font_size_override(&"font_size", maxi(ending_label.get_theme_font_size(&"font_size") - 2, 12))
	ending_label.get_parent().add_child(epilogue_label)
	ending_label.get_parent().move_child(epilogue_label, ending_label.get_index() + 1)


## The line of support under the epilogue on the card of the ending that needs it (built in code, hidden when the ending has none).
func _build_support_label(story: EndingStory) -> void:
	support_label = Label.new()
	support_label.name = "SupportLabel"
	var line: String = story.support_line if story != null else ""
	support_label.text = line
	support_label.visible = not line.is_empty()
	support_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	support_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	support_label.custom_minimum_size = Vector2(640.0, 0.0)
	support_label.add_theme_font_override(&"font", ending_label.get_theme_font(&"font"))
	support_label.add_theme_font_size_override(&"font_size", maxi(ending_label.get_theme_font_size(&"font_size") - 4, 12))
	ending_label.get_parent().add_child(support_label)
	ending_label.get_parent().move_child(support_label, epilogue_label.get_index() + 1)


func _names_text(names: Array[String]) -> String:
	return ", ".join(names) if not names.is_empty() else texts.summary_none_text


func _on_back_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	SceneManager.go_to_main_menu()
