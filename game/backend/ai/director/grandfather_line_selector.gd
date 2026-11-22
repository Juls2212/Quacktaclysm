class_name GrandfatherLineSelector
extends RefCounted
## Picks a bank line deterministically (Phase 16c): the same theme, level and saved decisions always start at the same line, so
## continuing from disk still shows a valid, stable line without anything extra being saved. A line already shown in the
## session is skipped; when every line of the set was shown the set starts over.


## A number made only of data the save already holds (theme, level, the decisions made).
static func seed_for(theme: String, level: int, decisions: Array) -> int:
	var parts: PackedStringArray = PackedStringArray()
	for entry: Variant in decisions:
		if entry is Dictionary:
			parts.append("%s:%s" % [String((entry as Dictionary).get("fragment_id", "")), String((entry as Dictionary).get("choice", ""))])
	return ("%s|%d|%s" % [theme, level, ",".join(parts)]).hash()


## The first candidate, from a seeded start, that is not in `shown`; "" when there is no candidate. If all were shown, the
## seeded one (the caller clears `shown` for that set).
static func pick(candidates: Array, seed_value: int, shown: Array) -> String:
	if candidates.is_empty():
		return ""
	var count: int = candidates.size()
	var start: int = absi(seed_value) % count
	for step in count:
		var candidate: String = String(candidates[(start + step) % count])
		if not shown.has(candidate):
			return candidate
	return String(candidates[start])
