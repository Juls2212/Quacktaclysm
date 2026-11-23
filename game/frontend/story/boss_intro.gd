class_name BossIntro
extends Node
## The opening of a boss fight, the first time only (Phase 15b). When the player enters the arena the boss
## stays INACTIVE (it cannot move, attack or hurt anybody and its hurtbox is off), the player is locked and
## invulnerable, and the scenes play in this ORDER through the level's PresentationQueue:
##   1. the VS presentation (BossFightFx, as before: names the guardian; it pauses the game while it plays),
##   2. the guardian's greeting lines (BossStory.pre_lines + the profile line),
##   3. the DUCK's story, 5-7 lines (BossStory.duck_lines, one chapter per boss),
##   4. combat begins: the lock and the invulnerability end and the encounter wakes the boss.
## The confirm action skips the subtitles (greeting and story) in one press. The music ducks while somebody
## talks (BossDialogue). It is shown ONLY the first time: not again after the player dies and retries the fight
## (BossDialogue's per-run memory), and never when the level was loaded from its arena checkpoint (a game
## continued from there, which mirrors the rule of the grandfather's scene). Nothing is saved.
## BossEncounter calls `begin` before it would wake the boss; if it returns true the boss waits for `finished`.
## Automated (headless) runs skip it unless `play_when_headless`.

signal started
## `skipped` is true when the player pressed confirm during the subtitles.
signal finished(skipped: bool)

@export var texts: StoryTexts
@export var play_when_headless: bool = false

## True from `begin` until the fight starts (BossDialogue and the tests read it).
var active: bool = false
var skipped: bool = false
## Steps of the last run in order (the tests read it).
var order: Array = []

var _level: LevelBase = null
var _boss: BossBase = null
var _encounter: BossEncounter = null
var _dialogue: BossDialogue = null
var _fx: Node = null
var _queue: PresentationQueue = null
var _player: Player = null


func _ready() -> void:
	if texts == null:
		texts = load(StoryTexts.DEFAULT_PATH) as StoryTexts
	_level = get_parent() as LevelBase
	if _level == null:
		return
	_boss = _level.boss
	_encounter = _level.encounter
	if _boss == null or _encounter == null:
		return
	_encounter.intro = self
	_dialogue = _level.get_node_or_null(^"BossDialogue") as BossDialogue
	_fx = _level.get_node_or_null(^"BossFightFx")
	_queue = _level.get_node_or_null(^"PresentationQueue") as PresentationQueue
	_level.level_ready.connect(_on_level_ready)


## A level opened from its ARENA checkpoint (a continued game) never plays the intro: that boss was already met.
func _on_level_ready() -> void:
	var arena: Checkpoint = _arena_checkpoint()
	if arena != null and String(arena.checkpoint_id) == GameState.checkpoint:
		BossDialogue.mark_spoken(_level.scene_file_path)


## The checkpoint of the arena: the one with the highest order in the level.
func _arena_checkpoint() -> Checkpoint:
	var best: Checkpoint = null
	for checkpoint in _level.get_level_checkpoints():
		if best == null or checkpoint.order > best.order:
			best = checkpoint
	return best


## True if the intro would play for this level now (the tests ask).
func should_play() -> bool:
	if _level == null or _dialogue == null or _queue == null or active:
		return false
	if DisplayServer.get_name() == "headless" and not play_when_headless:
		return false
	if BossDialogue.was_spoken(_level.scene_file_path):
		return false
	var story: BossStory = texts.get_boss(BossNames.level_number_of(_level))
	return story != null and not story.duck_lines.is_empty()


## Called by BossEncounter when the player enters the arena, before the boss would wake. Returns true when the
## intro takes over (the boss must wait for `finished`).
func begin(player: Node2D) -> bool:
	if not should_play() or not (player is Player):
		return false
	BossDialogue.mark_spoken(_level.scene_file_path)
	_player = player as Player
	active = true
	skipped = false
	order.clear()
	_player.set_input_locked(true)
	_player.story_invulnerable = true
	_boss.hurtbox.set_enabled(false)
	if not _player.died.is_connected(_abort):
		_player.died.connect(_abort)
	started.emit()
	_queue.enqueue("boss_vs", _step_vs, 10.0)
	_queue.enqueue("boss_lines", _step_lines, texts.intro_step_timeout)
	_queue.enqueue("boss_fight", _step_fight)
	return true


# Queue steps: each returns the Signal to wait for (or a null Signal when there is nothing to wait for).

func _step_vs() -> Variant:
	order.append("vs")
	if active and _fx != null and _fx.has_method(&"is_presenting") and bool(_fx.call(&"is_presenting")):
		return Signal(_fx, &"presentation_finished")
	return Signal()


func _step_lines() -> Variant:
	if not active:
		return Signal()
	var story: BossStory = texts.get_boss(BossNames.level_number_of(_level))
	order.append("guardian")
	order.append("duck")
	if story == null or not _dialogue.play_intro(story.lines_for(GameState.adaptive_profile), story.duck_lines, texts.duck_speaker):
		return Signal()
	_dialogue.sequence_finished.connect(_on_lines_finished, CONNECT_ONE_SHOT)
	return Signal(_dialogue, &"sequence_finished")


func _on_lines_finished(was_skipped: bool) -> void:
	skipped = was_skipped


func _step_fight() -> Variant:
	if active:
		order.append("fight")
		_end()
		finished.emit(skipped)
	return Signal()


func _end() -> void:
	active = false
	if is_instance_valid(_player):
		_player.set_input_locked(false)
		_player.story_invulnerable = false
		if _player.died.is_connected(_abort):
			_player.died.disconnect(_abort)
	_release_boss()


func _release_boss() -> void:
	if is_instance_valid(_boss) and _boss.state != BossBase.State.DEAD:
		_boss.hurtbox.set_enabled(true)


## Ends the intro at once (a developer action): the presentation and the lines stop and the fight begins.
func finish_now() -> void:
	if not active:
		return
	_queue.clear()
	if _fx != null and _fx.has_method(&"skip_presentation"):
		_fx.call(&"skip_presentation")
	if _dialogue != null:
		_dialogue.skip()
	order.append("fight")
	_end()
	finished.emit(true)


## The player died (a kill zone) before the fight began: everything stops and the boss never wakes.
func _abort() -> void:
	if not active:
		return
	_queue.clear()
	_end()
	if _dialogue != null:
		_dialogue.skip()
