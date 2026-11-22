class_name StoryTexts
extends Resource
## Every story text added in Phase 14d: the three souls, the guardians' lines, the grandfather's scene
## before the last boss, the four endings and the summary card. This resource
## (default_story_texts.tres) is the source of truth; docs/STORY.md is a readable copy of it.

const ENDING_FULL: String = "ending_full"
const ENDING_SCAR: String = "ending_scar"
const ENDING_DOUBT: String = "ending_doubt"
const ENDING_CORRUPT: String = "ending_corrupt"
const DEFAULT_PATH: String = "res://backend/story/default_story_texts.tres"

## SoulStory entries (an untyped Array on purpose: typed arrays of script classes make Godot leak at exit).
@export var souls: Array = []
## BossStory entries.
@export var bosses: Array = []
## EndingStory entries.
@export var endings: Array = []
@export_group("Grandfather before the last boss")
@export var elder_speaker: String = "Abuelo"
@export var elder_lines: Array[String] = []
## Index of `elder_lines` before which the mood line goes (it depends on the souls released so far).
@export var elder_mood_index: int = 3
## Mood line by souls released before the last boss (0, 1, 2).
@export var elder_mood_lines: Array[String] = []
@export_group("Boss intro")
## Who speaks the duck's monologue (BossStory.duck_lines) in the subtitle.
@export var duck_speaker: String = "Pato"
@export_group("Summary card")
@export var summary_released_format: String = "Almas liberadas: %d"
@export var summary_kept_format: String = "Almas guardadas: %d"
@export var summary_released_names_format: String = "Liberadas: %s"
@export var summary_kept_names_format: String = "Guardadas: %s"
@export var summary_none_text: String = "ninguna"
@export var summary_back_text: String = "Volver al menú principal"
@export_group("Hints")
@export var skip_hint: String = "Pulsa Enter para saltar"
@export var hold_skip_hint: String = "Mantén Enter para saltar"

## The shared default resource (the engine caches the loaded resource).
static func get_default() -> StoryTexts:
	return load(DEFAULT_PATH) as StoryTexts


func get_soul(fragment_id: String) -> SoulStory:
	for entry: Variant in souls:
		var soul := entry as SoulStory
		if soul != null and soul.fragment_id == fragment_id:
			return soul
	return null


func get_boss(level: int) -> BossStory:
	for entry: Variant in bosses:
		var boss := entry as BossStory
		if boss != null and boss.level == level:
			return boss
	return null


func get_ending(ending_id: String) -> EndingStory:
	for entry: Variant in endings:
		var ending := entry as EndingStory
		if ending != null and ending.ending_id == ending_id:
			return ending
	return null


## The grandfather's whole scene for a player who has released `released` souls so far.
func elder_script(released: int) -> Array[String]:
	var result: Array[String] = []
	result.append_array(elder_lines)
	if not elder_mood_lines.is_empty():
		var mood: String = elder_mood_lines[clampi(released, 0, elder_mood_lines.size() - 1)]
		result.insert(clampi(elder_mood_index, 0, result.size()), mood)
	return result


## The lines of an ending with `{released}` / `{kept}` replaced by soul names (joined by " y ").
func ending_lines(ending_id: String, released_names: Array[String], kept_names: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var story: EndingStory = get_ending(ending_id)
	if story == null:
		return result
	var released_text: String = " y ".join(released_names)
	var kept_text: String = " y ".join(kept_names)
	for line in story.lines:
		result.append(line.replace("{released}", released_text).replace("{kept}", kept_text))
	return result
