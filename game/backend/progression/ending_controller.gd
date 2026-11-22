class_name EndingController
extends Control
## The ending scene. The ending is chosen ONLY by the number of souls released (EndingSelector:
## 3 = full compassion, 2 = compassion with a scar, 1 = power with doubt, 0 = the duck becomes the
## new corruption). It plays a short subtitle sequence (StoryReel over the prologue's shot system,
## hold confirm to skip) and then shows the summary card: the counters and the NAMES of the souls
## released and kept, with a button back to the main menu. It never writes GameState (the "ending"
## checkpoint marker stays, so "Continuar" reopens this scene) and needs no network. All texts live
## in StoryTexts. Automated (headless) runs go straight to the card unless `skip_reel_when_headless`
## is turned off.

signal reel_finished
signal card_shown

@export var texts: StoryTexts
@export var skip_reel_when_headless: bool = true
## Reading-time multiplier of the sequence (see StoryReel.hold_scale).
@export var reel_hold_scale: float = 0.8

## The ending id shown (ending_full / ending_scar / ending_doubt / ending_corrupt).
var shown_variant: String = ""
## The summary sentence of that ending.
var shown_text: String = ""
## The closing text of the epilogue variant (Phase 16c) and the variant (0 to 2): it never changes which ending plays.
var shown_epilogue: String = ""
var shown_epilogue_variant: int = 0
var epilogue_label: Label = null
var released_names: Array[String] = []
var kept_names: Array[String] = []
var reel: StoryReel = null
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
	shown_variant = EndingSelector.ending_id_for(GameState.souls_released)
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
	back_button.pressed.connect(_on_back_pressed)
	if story != null and not story.music.is_empty():
		AudioDirector.play_music(story.music)
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
	reel = StoryReel.new()
	reel.shot = PrologueShots.Shot.EPILOGUE
	reel.epilogue_style = story.style if story != null else "full"
	reel.title_text = title_label.text
	reel.lines = get_reel_lines()
	reel.skip_mode = StoryReel.SkipMode.HOLD
	reel.skip_hint_text = texts.hold_skip_hint
	reel.hold_seconds = 1.2
	reel.hold_scale = reel_hold_scale
	reel.finished.connect(_on_reel_finished)
	add_child(reel)


func _on_reel_finished(_skipped: bool) -> void:
	reel = null
	reel_finished.emit()
	_show_card()


func _show_card() -> void:
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


func _names_text(names: Array[String]) -> String:
	return ", ".join(names) if not names.is_empty() else texts.summary_none_text


func _on_back_pressed() -> void:
	if SceneManager.is_transitioning():
		return
	SceneManager.go_to_main_menu()
