class_name EndingSelector
extends RefCounted
## Picks the ending (Phase 15h): EXACTLY TWO, by the majority of the three fragment decisions. More souls KEPT than released ->
## ENDING KEPT («Estrellas que suben»); otherwise (released >= kept, which includes the edge case of no decision) -> ENDING RELEASED
## («El acantilado»). Deterministic: the adaptive profile, the AI and the epilogue variant have no say. Reads the decisions GameState
## already saves; adds no data.


static func ending_id_for(released: int, kept: int) -> String:
	return StoryTexts.ENDING_KEPT if kept > released else StoryTexts.ENDING_RELEASED


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
