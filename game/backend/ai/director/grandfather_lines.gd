class_name GrandfatherLines
extends Resource
## The grandfather's voice (Phase 16c): the limits and banned words every line must respect and the LOCAL bank of lines (the
## fallback of the remote line). Default instance: res://backend/ai/director/default_grandfather_lines.tres, the source of truth;
## docs/STORY.md has a readable copy. The grandfather is a samurai who calls the duck "nieto" and speaks short and tender: a line
## is a gentle, proverb-like piece of advice about a theme, never a report ("moriste", "fallaste"), never a number.

const DEFAULT_PATH: String = "res://backend/ai/director/default_grandfather_lines.tres"

@export_group("Rules")
@export_range(1, 30, 1) var min_words: int = 8
@export_range(1, 40, 1) var max_words: int = 18
@export_range(20, 300, 1) var max_chars: int = 110
## Words and phrases (written without accents, lower case) no line may contain: reproach, statistics and game mechanics.
@export var banned_words: PackedStringArray = PackedStringArray()
## Pieces of a link or markup that are rejected, compared without accents.
@export var url_marks: PackedStringArray = PackedStringArray(["http", "www", ".com", ".net", ".org", "://"])

@export_group("Bank")
## Theme -> Array of lines (at least 3 per theme). Untyped on purpose (a Dictionary of arrays).
@export var themes: Dictionary = {}
## The lines of level 1: sayings of the grandfather remembered by the duck (theme equilibrio).
@export var memory_lines: Array[String] = []
@export var memory_theme: String = "equilibrio"


static func get_default() -> GrandfatherLines:
	var lines := load(DEFAULT_PATH) as GrandfatherLines
	return lines if lines != null else GrandfatherLines.new()


## The bank lines of a theme (an unknown theme uses the memory theme).
func lines_for(theme: String) -> Array:
	var entry: Variant = themes.get(theme, themes.get(memory_theme, []))
	return (entry as Array).duplicate() if entry is Array else []
