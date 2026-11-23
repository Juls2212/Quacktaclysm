class_name ElderScene
extends Node
## The grandfather returns before the last boss: when level 3 is entered fresh (its start checkpoint,
## no decision for its fragment yet) a short subtitle scene in the prologue's cave tells the duck what
## the prophecy really meant. Max ~20 s, press confirm to skip. His mood line depends on how many
## souls were released so far. It pauses the game while it plays (StoryReel) and never writes game
## state. Text lives in StoryTexts. Automated (headless) runs skip it unless `play_when_headless`.

signal scene_finished(skipped: bool)

const LAST_LEVEL_FRAGMENT: String = "fragment_level_3"

@export var texts: StoryTexts
@export var play_when_headless: bool = false

var reel: StoryReel = null
var played: bool = false

var _level: LevelBase = null


func _ready() -> void:
	if texts == null:
		texts = load(StoryTexts.DEFAULT_PATH) as StoryTexts
	_level = get_parent() as LevelBase
	if _level != null:
		_level.level_ready.connect(_on_level_ready)


## True when this level load should open with the scene.
func should_play() -> bool:
	if _level == null or _level.level_number != 3 or played:
		return false
	if DisplayServer.get_name() == "headless" and not play_when_headless:
		return false
	if GameState.is_game_completed() or GameState.has_decision(LAST_LEVEL_FRAGMENT):
		return false
	return GameState.checkpoint == _level.start_checkpoint_id


func _on_level_ready() -> void:
	if should_play():
		play()


## Builds and starts the scene (the lines include the speaker's name).
func play() -> StoryReel:
	played = true
	var script_lines: Array[String] = []
	for line in texts.elder_script(GameState.souls_released):
		script_lines.append("%s: %s" % [texts.elder_speaker, line])
	reel = StoryReel.new()
	reel.shot = PrologueShots.Shot.CAVE
	reel.lines = script_lines
	reel.skip_mode = StoryReel.SkipMode.PRESS
	reel.skip_hint_text = texts.skip_hint
	reel.hold_scale = 0.3
	reel.pause_game = true
	reel.cave_light = true
	reel.finished.connect(func(skipped: bool) -> void: scene_finished.emit(skipped))
	add_child(reel)
	return reel
