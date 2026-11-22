class_name BossStory
extends Resource
## What a guardian says: lines before the fight, at most one extra line that depends on the player's
## adaptive profile, and one line when it falls. The speaker's name comes from BossNames.

@export var level: int = 1
@export var pre_lines: Array[String] = []
## Adaptive profile id (compassionate / corrupt; neutral has none) -> one extra line after `pre_lines`.
@export var variant_lines: Dictionary = {}
@export var defeat_line: String = ""
## The duck's story told before the first fight with this guardian (Phase 15b): 5-7 subtitle lines, each at most
## 110 characters, about 25 s in total. A chapter of his story per boss.
@export var duck_lines: Array[String] = []


## The lines said before the fight for `profile`: the fixed ones plus that profile's variant, if any.
func lines_for(profile: String) -> Array[String]:
	var result: Array[String] = []
	result.append_array(pre_lines)
	var extra: String = String(variant_lines.get(profile, ""))
	if not extra.is_empty():
		result.append(extra)
	return result
