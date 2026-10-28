class_name AdaptiveInput
extends RefCounted
## Sanitized snapshot of the run that the classifier (local) and the remote service (later) consume.

const POINT_AFTER_DECISION: String = "after_decision"
const POINT_LEVEL_START: String = "level_start"
const POINT_ENDING: String = "ending"

var released: int = 0
var kept: int = 0
## Entries: {fragment_id: String, boss_id: String, level: int, choice: String}
var decisions: Array = []
var current_level: int = 1
var evaluation_point: String = POINT_AFTER_DECISION


## Tolerant builder. Invalid or duplicate decision entries are ignored; released/kept are
## recomputed from the valid decisions, which are the source of truth.
static func from_state_dict(state: Dictionary, point: String) -> AdaptiveInput:
	var input := AdaptiveInput.new()
	input.evaluation_point = point
	var level: Variant = _as_int(state.get("current_level"))
	if level != null:
		input.current_level = level
	var raw_decisions: Variant = state.get("decisions")
	if not raw_decisions is Array:
		return input
	var seen: Dictionary = {}
	for raw_entry: Variant in raw_decisions:
		var entry: Dictionary = _sanitize(raw_entry, seen)
		if entry.is_empty():
			continue
		seen[entry["fragment_id"]] = true
		input.decisions.append(entry)
		if entry["choice"] == AdaptiveIds.CHOICE_RELEASED:
			input.released += 1
		else:
			input.kept += 1
	return input


static func _sanitize(raw_entry: Variant, seen: Dictionary) -> Dictionary:
	if not raw_entry is Dictionary:
		return {}
	var raw: Dictionary = raw_entry
	var id: Variant = raw.get("fragment_id")
	var boss: Variant = raw.get("boss_id")
	var level: Variant = _as_int(raw.get("level"))
	var choice: Variant = raw.get("choice")
	if not id is String or (id as String).is_empty() or seen.has(id):
		return {}
	if not boss is String or level == null or not choice is String or not AdaptiveIds.is_valid_choice(choice):
		return {}
	return {"fragment_id": id, "boss_id": boss, "level": level, "choice": choice}


static func _as_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and floorf(value) == value:
		return int(value)
	return null
