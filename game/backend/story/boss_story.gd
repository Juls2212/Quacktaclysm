class_name BossStory
extends Resource
## What a guardian says (Phase 15n): ONE short line when the player first sees it (`pre_lines`, at most 80 characters) and at most one short
## line from the duck (`duck_lines`, at most 80), then the fight; and a slightly longer talk of 2 to 3 lines when it falls (`defeat_lines`, each at
## most 120 characters: its backstory and last words), before the fragment decision. The speaker's name comes from BossNames.

@export var level: int = 1
@export var pre_lines: Array[String] = []
## Adaptive profile id (compassionate / corrupt; neutral has none) -> one extra line after `pre_lines`.
@export var variant_lines: Dictionary = {}
## 2 to 3 lines the guardian says when it is defeated (backstory and last words), each at most 120 characters.
@export var defeat_lines: Array[String] = []
## The name shown for the guardian soul spirit that says them (Phase 15r), for example "Alma del Leñador".
@export var spirit_speaker: String = ""
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
