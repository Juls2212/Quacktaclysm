class_name EndingSelector
extends RefCounted
## Picks the ending from the number of souls released (deterministic; the adaptive profile and the
## AI have no say). 3 = full compassion, 2 = compassion with a scar, 1 = power with doubt, 0 = the
## duck becomes the new corruption. Reads the decisions GameState already saves; adds no data.


static func ending_id_for(released: int) -> String:
	if released >= 3:
		return StoryTexts.ENDING_FULL
	match released:
		2:
			return StoryTexts.ENDING_SCAR
		1:
			return StoryTexts.ENDING_DOUBT
	return StoryTexts.ENDING_CORRUPT


## Names of the souls decided with `choice`, in the order they were decided (the full name, or the
## short one for use inside a sentence). A fragment without a story is left out, never shown as a raw id.
static func soul_names(decisions: Array, texts: StoryTexts, choice: String, short: bool = false) -> Array[String]:
	var names: Array[String] = []
	for entry: Variant in decisions:
		if not entry is Dictionary or String((entry as Dictionary).get("choice", "")) != choice:
			continue
		var soul: SoulStory = texts.get_soul(String((entry as Dictionary).get("fragment_id", "")))
		if soul != null:
			names.append(soul.short_name if short else soul.soul_name)
	return names
